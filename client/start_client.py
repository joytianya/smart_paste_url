#!/usr/bin/env python3
"""
Smart Paste URL 客户端启动脚本
"""

import sys
import os
import subprocess

def main():
    print("Smart Paste URL 客户端")
    print("=" * 50)
    
    # 检查依赖
    try:
        import pyperclip, PIL.Image, PIL.ImageGrab, requests
        print("✅ Python依赖检查通过")
    except ImportError as e:
        print(f"❌ 缺少依赖: {e}")
        print("请运行: pip3 install Pillow pyperclip requests")
        return
    
    # 启动客户端
    client_path = "monitor.py"
    if os.path.exists(client_path):
        print("🚀 启动客户端监控...")
        subprocess.run([sys.executable, client_path])
    else:
        print("❌ 找不到客户端文件")

if __name__ == "__main__":
    main()