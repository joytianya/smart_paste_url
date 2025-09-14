#!/usr/bin/env python3
"""
Smart Paste URL - 剪贴板监控客户端
自动检测剪贴板中的图片并上传到服务器，返回可分享的URL
"""

import time
import hashlib
import json
import os
import sys
import threading
from io import BytesIO
import requests
import pyperclip
from PIL import Image, ImageGrab
from pynput import keyboard
from pynput.keyboard import Key, Listener

class SmartPasteClient:
    def __init__(self, config_path='config.json'):
        self.load_config(config_path)
        self.last_clipboard_hash = None
        self.running = True
        self.pressed_keys = set()
        self.last_url = None  # 存储最后生成的图片URL
        self.original_image_data = None  # 存储原始图片数据
        self.last_image_object = None  # 存储原始 PIL Image 对象
        self.last_paste_time = 0  # 防止重复触发
        
    def load_config(self, config_path):
        """加载配置文件"""
        # 尝试多个可能的配置文件路径
        possible_paths = [
            config_path,  # 当前目录
            os.path.join('..', config_path),  # 上级目录
            os.path.join('client', config_path)  # client子目录
        ]
        
        config = None
        for path in possible_paths:
            try:
                if os.path.exists(path):
                    with open(path, 'r', encoding='utf-8') as f:
                        config = json.load(f)
                    print(f"配置文件加载成功：{path}")
                    break
            except (FileNotFoundError, json.JSONDecodeError):
                continue
        
        if config:
            self.server_url = config.get('server_url', 'https://smart-paste.matrixtools.me')
            self.check_interval = config.get('check_interval', 1.0)
            self.supported_formats = config.get('supported_formats', ['.png', '.jpg', '.jpeg'])
            self.max_file_size = config.get('max_file_size', 10 * 1024 * 1024)
            print(f"服务器地址: {self.server_url}")
        else:
            print("配置文件未找到，使用默认配置")
            self.server_url = 'https://smart-paste.matrixtools.me'
            self.check_interval = 1.0
            self.supported_formats = ['.png', '.jpg', '.jpeg']
            self.max_file_size = 10 * 1024 * 1024
            print(f"默认服务器地址: {self.server_url}")

    def calculate_image_hash(self, image_data):
        """计算图片的MD5哈希"""
        return hashlib.md5(image_data).hexdigest()

    def get_clipboard_image(self):
        """从剪贴板获取图片数据（非破坏性读取）"""
        try:
            # 尝试从剪贴板获取图片
            image = ImageGrab.grabclipboard()
            
            if image is not None:
                # 将图片转换为字节流
                buffer = BytesIO()
                # 保存为PNG格式确保质量
                image.save(buffer, format='PNG')
                image_data = buffer.getvalue()
                
                # 检查文件大小
                if len(image_data) > self.max_file_size:
                    print(f"图片太大 ({len(image_data)} bytes)，跳过上传")
                    return None, None
                
                # 保存原始 PIL Image 对象用于恢复
                self.last_image_object = image.copy()  # 复制一份保存
                
                # 立即将原图片放回剪贴板（这是关键！）
                self.put_image_to_clipboard(image)
                    
                return image_data, self.calculate_image_hash(image_data)
                
        except Exception as e:
            print(f"获取剪贴板图片时出错: {e}")
            
        return None, None
    
    def put_image_to_clipboard(self, image):
        """将PIL图片对象放回剪贴板"""
        try:
            # 对于macOS，使用临时文件和osascript
            import tempfile
            import os
            import subprocess
            
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
                image.save(tmp.name, 'PNG')
                tmp_path = tmp.name
            
            # 使用AppleScript将图片放回剪贴板
            script = f'set the clipboard to (read (POSIX file "{tmp_path}") as PNG picture)'
            subprocess.run(['osascript', '-e', script], check=False, capture_output=True)
            
            # 清理临时文件
            try:
                os.unlink(tmp_path)
            except:
                pass
                
        except Exception as e:
            print(f"将图片放回剪贴板失败: {e}")

    def check_image_exists(self, image_hash):
        """检查服务器上是否已存在该图片"""
        try:
            response = requests.get(
                f"{self.server_url}/check/{image_hash}",
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get('exists', False), data.get('url')
            else:
                print(f"检查图片存在性失败: HTTP {response.status_code}")
                return False, None
                
        except requests.RequestException as e:
            print(f"检查图片存在性时网络错误: {e}")
            return False, None

    def upload_image(self, image_data, filename='clipboard_image.png'):
        """上传图片到服务器"""
        try:
            files = {
                'image': (filename, BytesIO(image_data), 'image/png')
            }
            
            response = requests.post(
                f"{self.server_url}/upload",
                files=files,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get('success', False), data.get('url'), data.get('exists', False)
            else:
                print(f"上传失败: HTTP {response.status_code}")
                return False, None, False
                
        except requests.RequestException as e:
            print(f"上传时网络错误: {e}")
            return False, None, False

    def on_key_press(self, key):
        """键盘按下事件处理"""
        try:
            self.pressed_keys.add(key)
        except:
            pass
    
    def on_key_release(self, key):
        """键盘释放事件处理"""
        try:
            # 检测 Cmd + V （粘贴URL）
            if (Key.cmd in self.pressed_keys and 
                hasattr(key, 'char') and key.char == 'v' and
                Key.ctrl not in self.pressed_keys):  # 确保不是Ctrl+V
                
                # 防止重复触发（500ms内只能触发一次）
                current_time = time.time()
                if current_time - self.last_paste_time > 0.5:
                    print("\n🔗 检测到 Cmd+V （URL模式）")
                    self.last_paste_time = current_time
                    self.paste_image_url()
            
            # Ctrl + V 让系统正常处理（粘贴图片）
            # 不需要特殊处理，系统会自动粘贴剪贴板中的图片
                
            self.pressed_keys.discard(key)
        except:
            pass
    
    def paste_image_url(self):
        """处理Cmd+V - 直接输入图片URL"""
        if self.last_url:
            # 使用 pynput 直接输入URL文本，不依赖剪贴板
            from pynput.keyboard import Controller
            controller = Controller()
            
            # 直接输入URL文本
            controller.type(self.last_url)
            
            print(f"🔗 已输入图片URL: {self.last_url}")
            print("📋 剪贴板仍保持原图片，Ctrl+V 可粘贴图片")
        else:
            print("📋 没有可用的图片URL")
    
    def process_clipboard_image(self):
        """处理剪贴板中的图片"""
        image_data, image_hash = self.get_clipboard_image()
        
        if image_data is None or image_hash is None:
            return False
            
        # 检查是否与上次处理的图片相同
        if image_hash == self.last_clipboard_hash:
            return False
            
        print(f"检测到新图片，Hash: {image_hash}")
        
        # 检查服务器上是否已存在
        exists, url = self.check_image_exists(image_hash)
        
        if exists and url:
            print(f"图片已存在，使用现有URL: {url}")
            # 不直接替换剪贴板，保持原始图片数据
            self.last_clipboard_hash = image_hash
            self.last_url = url  # 保存URL用于快捷键粘贴
            self.original_image_data = image_data  # 保存原始图片数据
            print(f"🔗 图片URL已准备就绪: {url}")
            print("📋 Ctrl+V 粘贴图片 | 🔗 Cmd+V 粘贴URL")
            return True
            
        # 上传新图片
        print("正在上传图片...")
        success, url, was_existing = self.upload_image(image_data)
        
        if success and url:
            if was_existing:
                print(f"图片已存在于服务器: {url}")
            else:
                print(f"图片上传成功: {url}")
                
            # 不直接替换剪贴板，保持原始图片数据
            self.last_clipboard_hash = image_hash
            self.last_url = url  # 保存URL用于快捷键粘贴
            self.original_image_data = image_data  # 保存原始图片数据
            print(f"🔗 图片URL已准备就绪: {url}")
            print("📋 Ctrl+V 粘贴图片 | 🔗 Cmd+V 粘贴URL")
            return True
        else:
            print("图片上传失败")
            return False

    def test_server_connection(self):
        """测试服务器连接"""
        try:
            response = requests.get(f"{self.server_url}/health", timeout=5)
            if response.status_code == 200:
                print("✅ 服务器连接正常")
                return True
            else:
                print(f"❌ 服务器响应异常: HTTP {response.status_code}")
                return False
                
        except requests.RequestException as e:
            print(f"❌ 无法连接到服务器: {e}")
            print(f"请确保服务器在 {self.server_url} 上运行")
            return False

    def start_keyboard_listener(self):
        """启动键盘监听器"""
        self.keyboard_listener = Listener(
            on_press=self.on_key_press,
            on_release=self.on_key_release
        )
        self.keyboard_listener.start()
    
    def run(self):
        """运行监控循环"""
        print("Smart Paste URL 客户端启动")
        print("=" * 50)
        
        # 测试服务器连接
        if not self.test_server_connection():
            print("请先启动服务器，然后重新运行客户端")
            return
            
        print("🎯 开始监控剪贴板...")
        print("💡 复制图片后会自动上传生成URL")
        print("📋 Ctrl+V - 粘贴图片（保持原剪贴板内容）")
        print("🔗 Cmd+V - 粘贴URL链接（直接输入，不修改剪贴板）")
        print("⌨️  按 Ctrl+C 退出")
        print("=" * 50)
        
        # 启动键盘监听器
        self.start_keyboard_listener()
        
        try:
            while self.running:
                try:
                    if self.process_clipboard_image():
                        print("✅ 图片处理完成，URL已准备就绪")
                        
                    time.sleep(self.check_interval)
                    
                except KeyboardInterrupt:
                    print("\n👋 正在退出...")
                    self.running = False
                    break
                    
                except Exception as e:
                    print(f"❌ 处理过程中出错: {e}")
                    time.sleep(self.check_interval)
                    
        except KeyboardInterrupt:
            print("\n👋 已退出监控")
        finally:
            # 停止键盘监听器
            if hasattr(self, 'keyboard_listener'):
                self.keyboard_listener.stop()

def main():
    """主函数"""
    client = SmartPasteClient()
    
    try:
        client.run()
    except Exception as e:
        print(f"程序异常退出: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()