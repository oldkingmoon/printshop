"""
企业微信 Webhook 服务器
接收企微群消息，调用知识库 API，返回回复
"""
import hashlib
import json
import httpx
from fastapi import FastAPI, Request, Response
from pydantic import BaseModel
from typing import Optional
import xml.etree.ElementTree as ET

app = FastAPI(title="PrintShop WeChat Webhook")

# 配置
KNOWLEDGE_API_URL = "http://localhost:8001"
WEBHOOK_URL = ""  # 需要配置：群机器人 webhook URL


class WebhookMessage(BaseModel):
    """企微 webhook 消息格式"""
    msgtype: str
    text: Optional[dict] = None
    markdown: Optional[dict] = None


async def query_knowledge(question: str, top_k: int = 3) -> list:
    """查询知识库"""
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{KNOWLEDGE_API_URL}/query",
                json={"question": question, "top_k": top_k},
                timeout=30.0
            )
            if response.status_code == 200:
                data = response.json()
                return data.get("results", [])
        except Exception as e:
            print(f"Knowledge API error: {e}")
    return []


async def send_webhook_reply(content: str, use_markdown: bool = True):
    """发送 webhook 回复"""
    if not WEBHOOK_URL:
        print("Warning: WEBHOOK_URL not configured")
        return
    
    async with httpx.AsyncClient() as client:
        if use_markdown:
            data = {"msgtype": "markdown", "markdown": {"content": content}}
        else:
            data = {"msgtype": "text", "text": {"content": content}}
        
        await client.post(WEBHOOK_URL, json=data)


def format_knowledge_response(question: str, results: list) -> str:
    """格式化知识库查询结果为 Markdown"""
    if not results:
        return f"抱歉，没有找到关于「{question}」的相关信息。请换个问法试试？"
    
    response = f"## 关于「{question}」\n\n"
    
    for i, item in enumerate(results, 1):
        title = item.get("title", "未知")
        content = item.get("content", "")[:200]  # 截取前200字
        category = item.get("category", "")
        similarity = item.get("similarity", 0)
        
        response += f"### {i}. {title}\n"
        response += f"> 分类: {category} | 相关度: {similarity:.0%}\n\n"
        response += f"{content}...\n\n"
    
    response += "---\n*如需更详细信息，请继续提问*"
    return response


@app.get("/health")
async def health():
    """健康检查"""
    return {"status": "ok", "service": "printshop-wecom-webhook"}


@app.post("/webhook")
async def receive_webhook(request: Request):
    """
    接收企微消息回调
    
    注意：这是简化版本，实际需要：
    1. 验证签名
    2. 解密消息
    3. 处理不同消息类型
    """
    try:
        body = await request.body()
        data = json.loads(body)
        
        # 提取消息内容
        msg_type = data.get("MsgType", "")
        content = ""
        
        if msg_type == "text":
            content = data.get("Content", "")
        
        if content:
            # 查询知识库
            results = await query_knowledge(content)
            
            # 格式化回复
            reply = format_knowledge_response(content, results)
            
            # 发送回复
            await send_webhook_reply(reply)
        
        return {"errcode": 0, "errmsg": "ok"}
    
    except Exception as e:
        print(f"Webhook error: {e}")
        return {"errcode": -1, "errmsg": str(e)}


@app.post("/test")
async def test_query(question: str = "名片报价"):
    """测试接口：模拟查询"""
    results = await query_knowledge(question)
    reply = format_knowledge_response(question, results)
    return {"question": question, "reply": reply, "raw_results": results}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
