"""
企业微信 Webhook 机器人
用于接收和发送群消息
"""
import httpx
import hashlib
import base64
from typing import Optional
from dataclasses import dataclass


@dataclass
class WebhookBot:
    """企业微信群机器人（Webhook 方式）"""
    
    webhook_url: str  # 群机器人 webhook 地址
    
    async def send_text(self, content: str, mentioned_list: Optional[list] = None) -> dict:
        """
        发送文本消息
        
        Args:
            content: 消息内容，最长不超过2048字节
            mentioned_list: @的成员列表，如 ["user1", "user2"] 或 ["@all"]
        """
        data = {
            "msgtype": "text",
            "text": {
                "content": content
            }
        }
        if mentioned_list:
            data["text"]["mentioned_list"] = mentioned_list
        
        return await self._send(data)
    
    async def send_markdown(self, content: str) -> dict:
        """
        发送 Markdown 消息
        
        Args:
            content: Markdown 内容，最长不超过4096字节
        """
        data = {
            "msgtype": "markdown",
            "markdown": {
                "content": content
            }
        }
        return await self._send(data)
    
    async def send_image(self, image_base64: str, image_md5: str) -> dict:
        """
        发送图片消息
        
        Args:
            image_base64: 图片 base64 编码
            image_md5: 图片 MD5 值
        """
        data = {
            "msgtype": "image",
            "image": {
                "base64": image_base64,
                "md5": image_md5
            }
        }
        return await self._send(data)
    
    async def send_news(self, articles: list) -> dict:
        """
        发送图文消息
        
        Args:
            articles: 图文列表，每个元素包含 title, description, url, picurl
        """
        data = {
            "msgtype": "news",
            "news": {
                "articles": articles
            }
        }
        return await self._send(data)
    
    async def _send(self, data: dict) -> dict:
        """发送消息到 webhook"""
        async with httpx.AsyncClient() as client:
            response = await client.post(self.webhook_url, json=data)
            return response.json()


# 使用示例
if __name__ == "__main__":
    import asyncio
    
    # 替换为实际的 webhook URL
    WEBHOOK_URL = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
    
    bot = WebhookBot(webhook_url=WEBHOOK_URL)
    
    async def test():
        # 发送文本
        result = await bot.send_text("Hello from PrintShop AI!")
        print(f"Text result: {result}")
        
        # 发送 Markdown
        md_content = """
## 报价单
**客户**: 测试客户
**产品**: 名片 500张

| 项目 | 单价 | 数量 | 小计 |
|------|------|------|------|
| 铜版纸名片 | ¥0.3 | 500 | ¥150 |
| 覆膜 | ¥0.1 | 500 | ¥50 |
| **合计** | | | **¥200** |
"""
        result = await bot.send_markdown(md_content)
        print(f"Markdown result: {result}")
    
    asyncio.run(test())
