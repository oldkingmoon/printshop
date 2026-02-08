-- ============================================
-- PrintShop 礼品商城数据模型
-- 设计: employee2
-- 日期: 2026-02-08
-- ============================================

-- ============================================
-- 供应商相关表
-- ============================================

-- 供应商表（供货商信息）
CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL PRIMARY KEY,
    
    -- 基本信息
    name VARCHAR(200) NOT NULL,                 -- 供应商名称
    
    -- 联系方式
    contact_person VARCHAR(50),                 -- 联系人
    contact_phone VARCHAR(20),                  -- 联系电话
    contact_email VARCHAR(100),                 -- 邮箱
    
    -- 发货地址
    ship_from_province VARCHAR(50),             -- 发货省份
    ship_from_city VARCHAR(50),                 -- 发货城市
    ship_from_address TEXT,                     -- 发货详细地址
    
    -- 合作状态
    cooperation_status VARCHAR(20) DEFAULT 'active',  -- active, suspended, blacklist
    rating INT DEFAULT 3,                       -- 评级 1-5
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_suppliers_name ON suppliers(name);
CREATE INDEX idx_suppliers_status ON suppliers(cooperation_status);
COMMENT ON TABLE suppliers IS '供应商表（供货商信息）';

-- 工商信息表（公司注册信息，独立于供应商）
CREATE TABLE IF NOT EXISTS business_info (
    id SERIAL PRIMARY KEY,
    
    -- 关联（可关联供应商，也可独立存在）
    supplier_id INT REFERENCES suppliers(id) ON DELETE SET NULL,
    
    -- 工商登记信息
    company_name VARCHAR(200) NOT NULL,         -- 公司全称
    credit_code VARCHAR(50) UNIQUE,             -- 统一社会信用代码
    legal_person VARCHAR(50),                   -- 法人代表
    registered_capital VARCHAR(50),             -- 注册资本
    establishment_date DATE,                    -- 成立日期
    company_type VARCHAR(50),                   -- 公司类型
    business_scope TEXT,                        -- 经营范围
    registration_authority VARCHAR(200),        -- 登记机关
    business_status VARCHAR(20),                -- 经营状态（存续、注销等）
    
    -- 注册地址
    registered_address TEXT,
    
    -- 数据来源
    data_source VARCHAR(50),                    -- 数据来源（天眼查、企查查等）
    last_sync_at TIMESTAMP,                     -- 最后同步时间
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_business_info_supplier ON business_info(supplier_id);
CREATE INDEX idx_business_info_credit_code ON business_info(credit_code);
COMMENT ON TABLE business_info IS '工商信息表（公司注册信息）';

-- 产品-供应商关联表（支持同产品多供应商不同报价）
CREATE TABLE IF NOT EXISTS product_suppliers (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    supplier_id INT REFERENCES suppliers(id) ON DELETE CASCADE,
    
    -- 供应商报价
    supply_price DECIMAL(10,2),                 -- 供货价
    min_order_qty INT DEFAULT 1,                -- 最小起订量
    lead_time_days INT,                         -- 货期（天）
    
    -- 供应商产品编码
    supplier_sku VARCHAR(50),                   -- 供应商内部SKU
    
    -- 是否主供应商
    is_primary BOOLEAN DEFAULT FALSE,
    
    -- 报价有效期
    quote_valid_until DATE,
    
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(product_id, supplier_id)
);

CREATE INDEX idx_product_suppliers_product ON product_suppliers(product_id);
CREATE INDEX idx_product_suppliers_supplier ON product_suppliers(supplier_id);
COMMENT ON TABLE product_suppliers IS '产品供应商关联（多供应商多报价）';

-- ============================================
-- 基础数据表
-- ============================================

-- 品牌表
CREATE TABLE IF NOT EXISTS brands (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    logo_url VARCHAR(500),
    description TEXT,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE brands IS '品牌表';

-- 分类表（支持多级）
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id INT REFERENCES categories(id) ON DELETE SET NULL,
    level INT DEFAULT 1,                    -- 层级: 1=大类, 2=子类, 3=三级
    icon_url VARCHAR(500),
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_parent ON categories(parent_id);
COMMENT ON TABLE categories IS '商品分类表（树形结构）';

-- 场景/标签表
CREATE TABLE IF NOT EXISTS scenes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,       -- 中秋、端午、商务、开业、年会等
    type VARCHAR(20) DEFAULT 'festival',    -- festival=节日, occasion=场合, theme=主题
    icon_url VARCHAR(500),
    color VARCHAR(20),                      -- 主题色 #RRGGBB
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE scenes IS '场景/节日标签表';

-- 商品表
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    external_id VARCHAR(50),                -- 外部系统商品ID（如 322765）
    name VARCHAR(200) NOT NULL,
    brand_id INT REFERENCES brands(id) ON DELETE SET NULL,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    
    -- 基本信息
    model VARCHAR(100),                     -- 型号规格 如 QD-DZ68
    description TEXT,
    
    -- 图片
    main_image VARCHAR(500),
    images JSONB DEFAULT '[]',              -- 图片数组 ["url1", "url2"]
    
    -- 规格参数
    specs JSONB DEFAULT '{}',               -- 规格参数 {"容量": "500ml", "材质": "不锈钢"}
    
    -- 价格（B2B场景，支持多种价格）
    retail_price DECIMAL(10,2),             -- 零售价
    wholesale_price DECIMAL(10,2),          -- 批发价
    cost_price DECIMAL(10,2),               -- 成本价
    
    -- 库存
    stock INT DEFAULT 0,
    min_order_qty INT DEFAULT 1,            -- 最小起订量
    
    -- 状态与标签
    status VARCHAR(20) DEFAULT 'active',    -- active, inactive, out_of_stock
    is_new BOOLEAN DEFAULT FALSE,           -- 新品标记
    is_dropship BOOLEAN DEFAULT FALSE,      -- 一件代发
    is_huicai BOOLEAN DEFAULT FALSE,        -- 阳光慧采
    is_customizable BOOLEAN DEFAULT FALSE,  -- 是否支持定制
    customization_options JSONB,            -- 定制选项
    
    -- 上架时间（用于新品排序）
    launched_at TIMESTAMP,
    
    -- SEO/搜索
    tags TEXT[],                            -- 标签数组
    search_keywords TEXT,                   -- 搜索关键词
    
    -- 统计
    view_count INT DEFAULT 0,
    order_count INT DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_brand ON products(brand_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_external_id ON products(external_id);
CREATE INDEX idx_products_retail_price ON products(retail_price);  -- 价格筛选
CREATE INDEX idx_products_is_new ON products(is_new) WHERE is_new = TRUE;
CREATE INDEX idx_products_is_dropship ON products(is_dropship) WHERE is_dropship = TRUE;
CREATE INDEX idx_products_launched_at ON products(launched_at DESC);
COMMENT ON TABLE products IS '商品表';

-- 商品-场景关联表（多对多）
CREATE TABLE IF NOT EXISTS product_scenes (
    product_id INT REFERENCES products(id) ON DELETE CASCADE,
    scene_id INT REFERENCES scenes(id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, scene_id)
);

COMMENT ON TABLE product_scenes IS '商品与场景关联';

-- ============================================
-- PPT方案相关表
-- ============================================

-- 客户表
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    company VARCHAR(200),
    phone VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    contact_person VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE customers IS '客户表';

-- 方案表
CREATE TABLE IF NOT EXISTS proposals (
    id SERIAL PRIMARY KEY,
    proposal_no VARCHAR(50) NOT NULL UNIQUE,    -- 方案编号 如 PPT-20260208-001
    title VARCHAR(200) NOT NULL,
    customer_id INT REFERENCES customers(id) ON DELETE SET NULL,
    
    -- 方案信息
    scene_id INT REFERENCES scenes(id),         -- 关联场景
    description TEXT,
    
    -- 状态流程
    status VARCHAR(20) DEFAULT 'draft',         -- draft, sent, reviewed, approved, rejected
    
    -- 金额统计
    total_amount DECIMAL(12,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    final_amount DECIMAL(12,2) DEFAULT 0,
    
    -- 有效期
    valid_until DATE,
    
    -- 备注
    internal_notes TEXT,                        -- 内部备注
    customer_notes TEXT,                        -- 给客户看的备注
    
    -- 生成的文件
    ppt_url VARCHAR(500),
    pdf_url VARCHAR(500),
    
    created_by VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_proposals_customer ON proposals(customer_id);
CREATE INDEX idx_proposals_status ON proposals(status);
COMMENT ON TABLE proposals IS 'PPT方案表';

-- 方案明细表
CREATE TABLE IF NOT EXISTS proposal_items (
    id SERIAL PRIMARY KEY,
    proposal_id INT REFERENCES proposals(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id) ON DELETE SET NULL,
    
    -- 快照（防止商品信息变更影响历史方案）
    product_name VARCHAR(200),
    product_image VARCHAR(500),
    product_specs JSONB,
    
    -- 数量价格
    quantity INT DEFAULT 1,
    unit_price DECIMAL(10,2),
    subtotal DECIMAL(12,2),
    
    -- 定制信息
    customization JSONB,                        -- 定制内容 {"logo": "xxx.png", "text": "XX公司"}
    
    sort_order INT DEFAULT 0,
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_proposal_items_proposal ON proposal_items(proposal_id);
COMMENT ON TABLE proposal_items IS '方案商品明细';

-- ============================================
-- 初始数据
-- ============================================

-- 插入场景
INSERT INTO scenes (name, type, sort_order) VALUES
('中秋礼品', 'festival', 1),
('端午礼品', 'festival', 2),
('春节礼品', 'festival', 3),
('商务礼品', 'occasion', 10),
('开业庆典', 'occasion', 11),
('年会礼品', 'occasion', 12),
('员工福利', 'occasion', 13),
('客户答谢', 'occasion', 14),
('保险礼品', 'theme', 20),
('高端礼品', 'theme', 21)
ON CONFLICT (name) DO NOTHING;

-- 插入一级分类
INSERT INTO categories (name, level, sort_order) VALUES
('家居厨具', 1, 1),
('家用电器', 1, 2),
('床品家纺', 1, 3),
('户外用品', 1, 4),
('个护健康', 1, 5),
('食品酒水', 1, 6),
('数码电子', 1, 7),
('办公文具', 1, 8);

-- 插入二级分类（家居厨具）
INSERT INTO categories (name, parent_id, level, sort_order)
SELECT sub.name, c.id, 2, sub.sort_order
FROM categories c
CROSS JOIN (VALUES 
    ('毛巾浴巾', 1),
    ('锅具炊具', 2),
    ('茶具茶器', 3),
    ('餐具杯碟', 4),
    ('刀具菜板', 5),
    ('咖啡杯具', 6),
    ('保温杯壶', 7),
    ('收纳整理', 8),
    ('台灯照明', 9),
    ('香薰摆件', 10)
) AS sub(name, sort_order)
WHERE c.name = '家居厨具';

-- 插入二级分类（家用电器）
INSERT INTO categories (name, parent_id, level, sort_order)
SELECT sub.name, c.id, 2, sub.sort_order
FROM categories c
CROSS JOIN (VALUES 
    ('厨房电器', 1),
    ('生活电器', 2),
    ('个护电器', 3),
    ('清洁电器', 4),
    ('按摩保健', 5)
) AS sub(name, sort_order)
WHERE c.name = '家用电器';

-- 插入示例品牌
INSERT INTO brands (name, sort_order) VALUES
('九阳', 1),
('美的', 2),
('苏泊尔', 3),
('膳魔师', 4),
('飞科', 5),
('康巴赫', 6),
('德铂', 7),
('洁丽雅', 8),
('富安娜', 9),
('博洋', 10)
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- 视图
-- ============================================

-- 商品完整信息视图
CREATE OR REPLACE VIEW v_products_full AS
SELECT 
    p.*,
    b.name AS brand_name,
    b.logo_url AS brand_logo,
    c.name AS category_name,
    pc.name AS parent_category_name,
    ARRAY_AGG(DISTINCT s.name) FILTER (WHERE s.name IS NOT NULL) AS scene_names
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN categories pc ON c.parent_id = pc.id
LEFT JOIN product_scenes ps ON p.id = ps.product_id
LEFT JOIN scenes s ON ps.scene_id = s.id
GROUP BY p.id, b.name, b.logo_url, c.name, pc.name;

-- 产品供应商报价视图
CREATE OR REPLACE VIEW v_product_suppliers AS
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    p.external_id,
    p.retail_price,
    s.id AS supplier_id,
    s.name AS supplier_name,
    s.business_license,
    s.legal_person,
    s.contact_person,
    s.contact_phone,
    ps.supply_price,
    ps.min_order_qty,
    ps.lead_time_days,
    ps.is_primary,
    ps.quote_valid_until,
    -- 利润率计算
    CASE WHEN ps.supply_price > 0 
         THEN ROUND((p.retail_price - ps.supply_price) / ps.supply_price * 100, 2)
         ELSE NULL 
    END AS margin_percent
FROM products p
JOIN product_suppliers ps ON p.id = ps.product_id
JOIN suppliers s ON ps.supplier_id = s.id
WHERE s.cooperation_status = 'active';

-- 方案统计视图
CREATE OR REPLACE VIEW v_proposal_stats AS
SELECT 
    p.id,
    p.proposal_no,
    p.title,
    p.status,
    p.final_amount,
    c.name AS customer_name,
    c.company AS customer_company,
    COUNT(pi.id) AS item_count,
    SUM(pi.quantity) AS total_quantity,
    p.created_at
FROM proposals p
LEFT JOIN customers c ON p.customer_id = c.id
LEFT JOIN proposal_items pi ON p.id = pi.proposal_id
GROUP BY p.id, c.name, c.company;
