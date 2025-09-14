#!/usr/bin/env python3
"""
测试客户端与远程服务器连接
"""

import json
import requests
from monitor import SmartPasteClient

def test_remote_server():
    print("🔌 测试远程服务器连接...")
    
    # 加载配置
    try:
        with open('config.json', 'r') as f:
            config = json.load(f)
        server_url = config['server_url']
        print(f"📡 服务器地址: {server_url}")
    except Exception as e:
        print(f"❌ 配置文件错误: {e}")
        return False
    
    # 测试健康检查
    try:
        response = requests.get(f"{server_url}/health", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 健康检查通过: {data}")
            return True
        else:
            print(f"❌ 健康检查失败: HTTP {response.status_code}")
            return False
    except requests.exceptions.Timeout:
        print("❌ 连接超时，请检查网络或服务器状态")
        return False
    except requests.exceptions.ConnectionError:
        print("❌ 无法连接到服务器，请检查地址和端口")
        return False
    except Exception as e:
        print(f"❌ 连接错误: {e}")
        return False

def test_client():
    print("\n🧪 测试客户端功能...")
    
    try:
        client = SmartPasteClient()
        if client.test_server_connection():
            print("✅ 客户端配置正确，可以启动监控")
            return True
        else:
            print("❌ 客户端连接失败")
            return False
    except Exception as e:
        print(f"❌ 客户端测试错误: {e}")
        return False

if __name__ == "__main__":
    print("Smart Paste URL 客户端连接测试")
    print("=" * 50)
    
    # 测试服务器
    server_ok = test_remote_server()
    
    # 测试客户端
    client_ok = test_client() if server_ok else False
    
    print("\n" + "=" * 50)
    if server_ok and client_ok:
        print("🎉 所有测试通过！可以开始使用客户端")
        print("\n启动方法：")
        print("python3 monitor.py")
    else:
        print("❌ 测试失败，请检查配置和网络连接")