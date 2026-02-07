# PrintShop - 图文快印 AI 助理系统

> 让每家图文快印店都有自己的 AI 员工

## 项目概述

PrintShop 是一个面向图文快印行业的 AI 助理系统，通过企业微信为门店提供智能客服、报价、设计建议等服务。

### 核心功能

- 🤖 **智能客服** - 4 个专业 AI Agent 协作服务
- 💰 **自动报价** - 名片/喷绘/画册阶梯定价
- 📚 **知识库** - 云端行业知识 + 本地门店数据
- 💬 **对话录入** - 聊天中自动提取结构化数据
- 🏪 **多租户** - 支持连锁门店和独立品牌

### 技术架构

- **AI**: OpenClaw + Claude/GPT
- **数据库**: PostgreSQL + pgvector
- **客户端**: 企业微信
- **多租户**: RLS 行级安全隔离

---

## 文件清单

### Agent 定义 (`agents/`)

| 文件 | 角色 | 职责 |
|------|------|------|
| `store-assistant-agent.md` | 店长助理（小印） | 接待、推荐、促单 |
| `designer-agent.md` | 设计师（小艺） | 方案、创意、视觉建议 |
| `craft-expert-agent.md` | 工艺专家（老张） | 材料、工艺、技术解答 |
| `supplier-agent.md` | 供应商代理（老李） | 询价、比价、交期 |

### 文档 (`docs/`)

| 文件 | 说明 |
|------|------|
| `architecture-overview.md` | 整体架构图 |
| `database-schema.md` | 数据库设计说明 |
| `pricing-logic.md` | 报价规则说明 |
| `chat-extract-guide.md` | 聊天摘录使用指南 |

### SQL 脚本 (`scripts/`)

| 文件 | 说明 | 依赖 |
|------|------|------|
| `init-db.sql` | 数据库初始化（表结构） | - |
| `pricing-engine.sql` | 报价引擎函数 | init-db.sql |
| `chat-extract.sql` | 聊天摘录解析 | init-db.sql |

---

## 快速开始

### 1. 初始化数据库

```bash
# 按顺序执行
psql -d printshop -f scripts/init-db.sql
psql -d printshop -f scripts/pricing-engine.sql
psql -d printshop -f scripts/chat-extract.sql
```

### 2. 创建租户和门店

```sql
-- 创建租户
INSERT INTO tenant.tenants (name, type) 
VALUES ('我的品牌', 'independent');

-- 创建门店
INSERT INTO tenant.stores (tenant_id, name, address)
VALUES ('租户ID', '总店', '地址');
```

### 3. 配置 AI Agent

将 `agents/*.md` 中的 System Prompt 配置到 OpenClaw。

---

## 开发日志

### 2026-02-06

**Phase 1: 数据模型设计** ✅
- 设计云端/本地双层知识库架构
- 创建 PostgreSQL DDL 脚本
- 支持多租户隔离（tenant_id + RLS）

**Phase 2: AI Agent Prompt** ✅
- 店长助理、设计师、工艺专家、供应商代理
- 定义角色、性格、能力边界
- 编写知识库调用示例

**Phase 3: 报价引擎** ✅
- 名片报价（数量阶梯 + 材质系数 + 工艺附加）
- 喷绘报价（面积计价 + 室内外区分）
- 画册报价（封面 + 内页 + 装订 + 数量折扣）

**Phase 4: 聊天摘录** ✅
- 从对话提取供应商/产品/礼品信息
- 待确认机制（先暂存，确认后写入）
- 供应商群场景（区分云端/本地）

**Phase 5: 文档整理** ✅
- 架构概览图
- 文件清单
- 项目日志

---

## 下一步计划

- [ ] 企业微信对接
- [ ] 向量嵌入生成（embedding）
- [ ] 云端知识库初始数据
- [ ] 管理后台界面
- [ ] 礼品商城模块

---

## 团队

- **项目推进**: @oldking
- **执行开发**: 员工2号 🔧

---

*最后更新: 2026-02-06 23:15*
