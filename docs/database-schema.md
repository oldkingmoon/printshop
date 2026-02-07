# PrintShop 知识库数据模型设计

> 版本: v0.1 (Draft)
> 作者: 员工2号
> 日期: 2026-02-06

## 架构概述

采用 **云端 + 本地** 双层架构：

```
┌─────────────────────────────────────────────────────────┐
│                    云端知识库 (Cloud)                    │
│  - 行业通用知识（材料、工艺、礼品目录）                    │
│  - 所有门店共享                                          │
│  - 由平台统一维护更新                                    │
└─────────────────────────────────────────────────────────┘
                           │
                           │ 同步/引用
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   本地知识库 (Local)                     │
│  - 门店私有数据（供应商、本地价格、客户）                  │
│  - 仅本店可见                                            │
│  - 门店自行维护                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 一、云端知识库 (Cloud Database)

### 1.1 材料表 (materials)

存储印刷材料的通用信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | VARCHAR(100) | 材料名称（如"157g铜版纸"） |
| category | VARCHAR(50) | 分类（纸张/喷绘材料/板材/其他） |
| subcategory | VARCHAR(50) | 子分类（如"铜版纸"、"特种纸"） |
| description | TEXT | 材料描述 |
| properties | JSONB | 属性（克重、厚度、尺寸规格等） |
| use_cases | TEXT[] | 适用场景 |
| pros | TEXT[] | 优点 |
| cons | TEXT[] | 缺点 |
| indoor_outdoor | ENUM | 室内/室外/通用 |
| durability | VARCHAR(50) | 耐久性（如"户外1年"） |
| price_range | VARCHAR(50) | 参考价格区间（如"中等"、"高端"） |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

**索引**: category, subcategory, indoor_outdoor

### 1.2 工艺表 (crafts)

存储印刷工艺信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | VARCHAR(100) | 工艺名称（如"覆哑膜"、"烫金"） |
| category | VARCHAR(50) | 分类（表面处理/装订/特殊效果） |
| description | TEXT | 工艺描述 |
| effect | TEXT | 效果说明 |
| applicable_materials | UUID[] | 适用材料ID列表 |
| min_quantity | INT | 最小起订量 |
| process_time | VARCHAR(50) | 加工时间（如"1-2天"） |
| cost_level | ENUM | 成本等级（低/中/高） |
| notes | TEXT | 注意事项 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

**索引**: category, cost_level

### 1.3 产品模板表 (product_templates)

常见产品的标准配置模板。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | VARCHAR(100) | 产品名称（如"企业画册"、"名片"） |
| category | VARCHAR(50) | 分类（印刷品/广告/包装/礼品） |
| description | TEXT | 产品描述 |
| default_specs | JSONB | 默认规格（尺寸、页数、材料等） |
| recommended_materials | UUID[] | 推荐材料ID |
| recommended_crafts | UUID[] | 推荐工艺ID |
| design_tips | TEXT | 设计建议 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 1.4 礼品目录表 (gifts)

礼品商城产品目录。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | VARCHAR(200) | 礼品名称 |
| category | VARCHAR(50) | 分类（办公/家居/数码/食品/定制） |
| description | TEXT | 产品描述 |
| images | TEXT[] | 图片URL列表 |
| specs | JSONB | 规格参数 |
| customizable | BOOLEAN | 是否可定制 |
| customization_options | JSONB | 定制选项（印LOGO位置、颜色等） |
| min_order_qty | INT | 最小起订量 |
| reference_price | DECIMAL | 参考价格 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 1.5 礼品季节标签表 (gift_seasons)

礼品的季节性/节日标签。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| gift_id | UUID | 礼品ID (FK → gifts) |
| season_type | ENUM | 类型（节日/节气/季节/通用） |
| season_name | VARCHAR(50) | 名称（春节/中秋/端午/夏季等） |
| start_recommend | DATE | 开始推荐日期（如春节前4周） |
| end_recommend | DATE | 结束推荐日期 |
| priority | INT | 推荐优先级 |
| year | INT | 年份（NULL表示每年循环） |

**索引**: gift_id, season_type, season_name, (start_recommend, end_recommend)

### 1.6 行业知识表 (industry_knowledge)

FAQ、行业术语、常见问题解答。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| type | ENUM | 类型（FAQ/术语/案例/技巧） |
| question | TEXT | 问题/术语 |
| answer | TEXT | 回答/解释 |
| keywords | TEXT[] | 关键词（用于搜索匹配） |
| related_materials | UUID[] | 相关材料 |
| related_crafts | UUID[] | 相关工艺 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

**索引**: type, keywords (GIN)

---

## 二、本地知识库 (Local Database)

### 2.1 本地供应商表 (local_suppliers)

门店的供应商信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| store_id | UUID | 门店ID |
| name | VARCHAR(200) | 供应商名称 |
| contact_person | VARCHAR(100) | 联系人 |
| phone | VARCHAR(50) | 电话 |
| wechat | VARCHAR(100) | 微信 |
| address | TEXT | 地址 |
| specialties | TEXT[] | 主营业务（如"大幅面喷绘"、"画册印刷"） |
| equipment | TEXT | 设备情况 |
| price_level | ENUM | 价格水平（低/中/高） |
| quality_rating | INT | 质量评分 (1-5) |
| delivery_rating | INT | 交期评分 (1-5) |
| notes | TEXT | 备注 |
| is_active | BOOLEAN | 是否启用 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |
| source | ENUM | 数据来源（chat_extract/excel_import/manual） |

**索引**: store_id, specialties (GIN), is_active

### 2.2 本地产品价格表 (local_products)

门店自定义的产品和价格。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| store_id | UUID | 门店ID |
| cloud_template_id | UUID | 关联云端产品模板（可选） |
| name | VARCHAR(200) | 产品名称 |
| category | VARCHAR(50) | 分类 |
| specs | JSONB | 规格 |
| base_price | DECIMAL | 基础价格 |
| price_tiers | JSONB | 阶梯价格（数量→单价） |
| cost | DECIMAL | 成本价（内部） |
| supplier_id | UUID | 供应商ID（如外协） |
| production_time | VARCHAR(50) | 生产周期 |
| notes | TEXT | 备注 |
| is_active | BOOLEAN | 是否上架 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |
| source | ENUM | 数据来源 |

**索引**: store_id, category, is_active

### 2.3 本地礼品库存表 (local_gift_inventory)

门店的礼品库存和本地价格。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| store_id | UUID | 门店ID |
| cloud_gift_id | UUID | 关联云端礼品（可选） |
| name | VARCHAR(200) | 礼品名称（本地可改名） |
| local_price | DECIMAL | 本地售价 |
| cost | DECIMAL | 成本价 |
| stock_qty | INT | 库存数量 |
| supplier_id | UUID | 供应商ID |
| is_active | BOOLEAN | 是否上架 |
| valid_from | DATE | 上架日期 |
| valid_until | DATE | 下架日期 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

**索引**: store_id, is_active, (valid_from, valid_until)

### 2.4 聊天摘录记录表 (chat_extracts)

从聊天中提取的结构化数据（审计追踪）。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| store_id | UUID | 门店ID |
| raw_text | TEXT | 原始聊天文本 |
| extracted_type | ENUM | 提取类型（supplier/product/price/other） |
| extracted_data | JSONB | 提取的结构化数据 |
| target_table | VARCHAR(50) | 写入的目标表 |
| target_id | UUID | 写入的记录ID |
| confidence | DECIMAL | AI 提取置信度 |
| confirmed | BOOLEAN | 是否人工确认 |
| extracted_at | TIMESTAMP | 提取时间 |
| confirmed_at | TIMESTAMP | 确认时间 |
| confirmed_by | VARCHAR(100) | 确认人 |

**索引**: store_id, extracted_type, confirmed

---

## 三、数据录入方式

### 3.1 聊天摘录流程

```
用户消息 → AI 解析 → 结构化数据 → chat_extracts 表
                                      ↓
                              [待确认] 或 [自动写入]
                                      ↓
                              目标表（suppliers/products/gifts）
```

**解析示例**：
```
输入: "记住：张三印刷厂，联系人李四，电话138xxx，主营大幅面喷绘"

提取:
{
  "type": "supplier",
  "data": {
    "name": "张三印刷厂",
    "contact_person": "李四",
    "phone": "138xxx",
    "specialties": ["大幅面喷绘"]
  }
}
```

### 3.2 Excel 批量导入

提供标准模板：
- `suppliers_template.xlsx` - 供应商导入
- `products_template.xlsx` - 产品价格导入
- `gifts_template.xlsx` - 礼品导入

### 3.3 后台管理界面

- 查看/编辑/删除所有本地数据
- 审核聊天摘录的提取结果
- 批量上下架产品

---

## 四、礼品季节性处理

### 4.1 节日/节气日历

预置常见节日（每年自动计算日期）：
- 春节（农历正月初一前4周开始推荐）
- 元宵节
- 端午节
- 中秋节
- 国庆节
- 元旦
- 情人节
- 妇女节
- 母亲节/父亲节
- 教师节
- 圣诞节
- ...

### 4.2 自动推荐逻辑

```sql
-- 获取当前应推荐的礼品
SELECT g.* FROM gifts g
JOIN gift_seasons gs ON g.id = gs.gift_id
WHERE CURRENT_DATE BETWEEN gs.start_recommend AND gs.end_recommend
ORDER BY gs.priority DESC;
```

### 4.3 更新策略

- 云端礼品目录：平台定期更新（节前1-2月）
- 本地库存：门店自行维护上下架时间
- 过期礼品：自动下架或提醒

---

## 五、技术选型建议

| 组件 | 推荐方案 | 备选 |
|------|---------|------|
| 云端数据库 | PostgreSQL + Supabase | MySQL |
| 本地数据库 | SQLite（单店）/ PostgreSQL（连锁） | - |
| 全文搜索 | PostgreSQL FTS / Meilisearch | Elasticsearch |
| 向量搜索（语义） | pgvector | Pinecone |
| 缓存 | Redis | - |
| 文件存储 | S3 / 阿里云 OSS | - |

---

## 六、待讨论问题

1. **云端-本地同步策略**：实时同步还是定期拉取？
2. **多门店数据隔离**：是否需要支持连锁店？
3. **历史价格追踪**：是否需要记录价格变更历史？
4. **权限控制**：谁能编辑云端知识库？
5. **向量嵌入**：是否需要为语义搜索预生成 embedding？

---

## 更新日志

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.1 | 2026-02-06 | 初稿，基础表结构设计 |
