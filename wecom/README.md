# 企业微信 Webhook 对接

## 文件说明

| 文件 | 用途 |
|------|------|
| `webhook_bot.py` | 发送消息到企微群（主动推送） |
| `webhook_server.py` | 接收企微消息回调（被动响应） |

## 快速开始

### 1. 安装依赖

```bash
pip install fastapi uvicorn httpx
```

### 2. 配置 Webhook URL

在 `webhook_server.py` 中设置：
```python
WEBHOOK_URL = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
```

### 3. 启动服务

```bash
# 确保知识库 API 在运行（端口 8001）
python webhook_server.py
# 服务运行在 8002 端口
```

### 4. 测试

```bash
# 测试知识库查询
curl -X POST "http://localhost:8002/test?question=名片报价"
```

## 企微配置步骤

### 方式一：群机器人（简单）

1. 在企微群里添加机器人
2. 获取 Webhook URL
3. 配置到 `WEBHOOK_URL`
4. 只能发消息，不能接收

### 方式二：自建应用（完整）

1. 登录企业微信管理后台
2. 创建自建应用
3. 配置回调 URL（需要公网 HTTPS）
4. 获取 CorpID、AgentID、Secret
5. 可以双向通信

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/webhook` | POST | 接收企微回调 |
| `/test` | POST | 测试知识库查询 |

## 下一步

- [ ] 配置实际的 Webhook URL
- [ ] 添加消息签名验证
- [ ] 添加消息加解密
- [ ] 对接 AI Agent 进行智能回复
