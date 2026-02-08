#!/usr/bin/env node
/**
 * 企业微信 Webhook 机器人测试脚本
 * 用法: node webhook-test.js <webhook_url>
 */

const https = require('https');
const http = require('http');

const webhookUrl = process.argv[2];

if (!webhookUrl) {
  console.error('用法: node webhook-test.js <webhook_url>');
  console.error('示例: node webhook-test.js https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxx');
  process.exit(1);
}

/**
 * 发送消息到企微 webhook
 */
function sendMessage(url, payload) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const client = urlObj.protocol === 'https:' ? https : http;
    
    const data = JSON.stringify(payload);
    
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    };

    const req = client.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          resolve({ raw: body });
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  console.log('🚀 企微 Webhook 测试开始\n');
  console.log(`目标: ${webhookUrl.substring(0, 60)}...`);
  console.log('---');

  // 1. 发送文本消息
  console.log('\n📝 发送文本消息...');
  const textMsg = {
    msgtype: 'text',
    text: {
      content: `🔧 Webhook 测试消息\n\n发送时间: ${new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' })}\n发送者: employee2 测试脚本`
    }
  };
  
  try {
    const textResult = await sendMessage(webhookUrl, textMsg);
    if (textResult.errcode === 0) {
      console.log('✅ 文本消息发送成功');
    } else {
      console.log('❌ 文本消息发送失败:', textResult);
    }
  } catch (err) {
    console.log('❌ 文本消息发送错误:', err.message);
  }

  // 2. 发送 Markdown 报价单
  console.log('\n📋 发送 Markdown 报价单...');
  const markdownMsg = {
    msgtype: 'markdown',
    markdown: {
      content: `## 📦 PrintShop 报价单示例

**客户**: 测试客户
**日期**: ${new Date().toLocaleDateString('zh-CN')}

---

| 项目 | 规格 | 数量 | 单价 | 小计 |
|:-----|:-----|-----:|-----:|-----:|
| 名片印刷 | 90x54mm 铜版纸 | 500张 | ¥0.15 | ¥75 |
| 宣传单页 | A4 157g 双面 | 1000张 | ¥0.35 | ¥350 |
| 海报 | A1 200g 覆膜 | 50张 | ¥8.00 | ¥400 |

---

**合计**: <font color="warning">¥825.00</font>

> 以上报价有效期 7 天
> 如有疑问请联系客服`
    }
  };

  try {
    const mdResult = await sendMessage(webhookUrl, markdownMsg);
    if (mdResult.errcode === 0) {
      console.log('✅ Markdown 报价单发送成功');
    } else {
      console.log('❌ Markdown 报价单发送失败:', mdResult);
    }
  } catch (err) {
    console.log('❌ Markdown 报价单发送错误:', err.message);
  }

  console.log('\n---');
  console.log('🏁 测试完成');
}

main().catch(console.error);
