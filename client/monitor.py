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

class SmartPasteClient:
    def __init__(self, config_path='config.json'):
        self.load_config(config_path)
        self.last_clipboard_hash = None
        self.running = True
        
    def load_config(self, config_path):
        """加载配置文件"""
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config = json.load(f)
            
            self.server_url = config.get('server_url', 'http://localhost:3000')
            self.check_interval = config.get('check_interval', 1.0)
            self.supported_formats = config.get('supported_formats', ['.png', '.jpg', '.jpeg'])
            self.max_file_size = config.get('max_file_size', 10 * 1024 * 1024)
            
            print(f"配置加载成功：服务器地址 {self.server_url}")
            
        except FileNotFoundError:
            print("配置文件未找到，使用默认配置")
            self.server_url = 'http://localhost:3000'
            self.check_interval = 1.0
            self.supported_formats = ['.png', '.jpg', '.jpeg']
            self.max_file_size = 10 * 1024 * 1024
            
        except json.JSONDecodeError:
            print("配置文件格式错误，使用默认配置")
            sys.exit(1)

    def calculate_image_hash(self, image_data):
        """计算图片的MD5哈希"""
        return hashlib.md5(image_data).hexdigest()

    def get_clipboard_image(self):
        """从剪贴板获取图片数据"""
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
                    
                return image_data, self.calculate_image_hash(image_data)
                
        except Exception as e:
            print(f"获取剪贴板图片时出错: {e}")
            
        return None, None

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
            pyperclip.copy(url)
            self.last_clipboard_hash = image_hash
            return True
            
        # 上传新图片
        print("正在上传图片...")
        success, url, was_existing = self.upload_image(image_data)
        
        if success and url:
            if was_existing:
                print(f"图片已存在于服务器: {url}")
            else:
                print(f"图片上传成功: {url}")
                
            # 将URL复制到剪贴板
            pyperclip.copy(url)
            self.last_clipboard_hash = image_hash
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

    def run(self):
        """运行监控循环"""
        print("Smart Paste URL 客户端启动")
        print("=" * 50)
        
        # 测试服务器连接
        if not self.test_server_connection():
            print("请先启动服务器，然后重新运行客户端")
            return
            
        print("🎯 开始监控剪贴板...")
        print("💡 复制图片后会自动上传并替换为URL")
        print("⌨️  按 Ctrl+C 退出")
        print("=" * 50)
        
        try:
            while self.running:
                try:
                    if self.process_clipboard_image():
                        print("📋 剪贴板已更新为分享链接")
                        
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