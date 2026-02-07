-- PrintShop 数据库初始化脚本
-- 版本: v0.2
-- 作者: 员工2号
-- 日期: 2026-02-06
-- 
-- 架构: 云端(cloud) + 本地(tenant) 双层
-- 云端只读（总部维护），本地可读写（门店独立）
-- 多租户隔离：每个门店/品牌独立，数据完全隔离

-- ============================================
-- 启用扩展
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";

-- ============================================
-- 枚举类型
-- ============================================

CREATE TYPE indoor_outdoor_type AS ENUM ('indoor', 'outdoor', 'both');
CREATE TYPE cost_level_type AS ENUM ('low', 'medium', 'high');
CREATE TYPE season_type AS ENUM ('festival', 'solar_term', 'season', 'universal');
CREATE TYPE price_level_type AS ENUM ('low', 'medium', 'high');
CREATE TYPE data_source_type AS ENUM ('chat_extract', 'excel_import', 'manual', 'api');
CREATE TYPE extract_type AS ENUM ('supplier', 'product', 'price', 'gift', 'other');
CREATE TYPE knowledge_type AS ENUM ('faq', 'term', 'case', 'tip');
CREATE TYPE tenant_type AS ENUM ('chain', 'independent');  -- 连锁门店 / 独立品牌

-- ============================================
-- 云端知识库 (Cloud Schema) - 总部维护，所有租户只读
-- ============================================

CREATE SCHEMA IF NOT EXISTS cloud;

-- 1. 材料表
CREATE TABLE cloud.materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    description TEXT,
    properties JSONB DEFAULT '{}',
    use_cases TEXT[] DEFAULT '{}',
    pros TEXT[] DEFAULT '{}',
    cons TEXT[] DEFAULT '{}',
    indoor_outdoor indoor_outdoor_type DEFAULT 'both',
    durability VARCHAR(50),
    price_range VARCHAR(50),
    embedding vector(1536),  -- OpenAI embedding 维度
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_materials_category ON cloud.materials(category);
CREATE INDEX idx_materials_subcategory ON cloud.materials(subcategory);
CREATE INDEX idx_materials_indoor_outdoor ON cloud.materials(indoor_outdoor);
CREATE INDEX idx_materials_embedding ON cloud.materials USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 2. 工艺表
CREATE TABLE cloud.crafts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    effect TEXT,
    applicable_materials UUID[] DEFAULT '{}',
    min_quantity INT DEFAULT 1,
    process_time VARCHAR(50),
    cost_level cost_level_type DEFAULT 'medium',
    notes TEXT,
    embedding vector(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_crafts_category ON cloud.crafts(category);
CREATE INDEX idx_crafts_cost_level ON cloud.crafts(cost_level);
CREATE INDEX idx_crafts_embedding ON cloud.crafts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 3. 产品模板表
CREATE TABLE cloud.product_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    default_specs JSONB DEFAULT '{}',
    recommended_materials UUID[] DEFAULT '{}',
    recommended_crafts UUID[] DEFAULT '{}',
    design_tips TEXT,
    embedding vector(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_product_templates_category ON cloud.product_templates(category);
CREATE INDEX idx_product_templates_embedding ON cloud.product_templates USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 4. 礼品目录表
CREATE TABLE cloud.gifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    images TEXT[] DEFAULT '{}',
    specs JSONB DEFAULT '{}',
    customizable BOOLEAN DEFAULT false,
    customization_options JSONB DEFAULT '{}',
    min_order_qty INT DEFAULT 1,
    reference_price DECIMAL(10, 2),
    embedding vector(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_gifts_category ON cloud.gifts(category);
CREATE INDEX idx_gifts_customizable ON cloud.gifts(customizable);
CREATE INDEX idx_gifts_embedding ON cloud.gifts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 5. 礼品季节标签表
CREATE TABLE cloud.gift_seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gift_id UUID NOT NULL REFERENCES cloud.gifts(id) ON DELETE CASCADE,
    season_type season_type NOT NULL,
    season_name VARCHAR(50) NOT NULL,
    start_recommend DATE,
    end_recommend DATE,
    priority INT DEFAULT 0,
    year INT,  -- NULL 表示每年循环
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_gift_seasons_gift_id ON cloud.gift_seasons(gift_id);
CREATE INDEX idx_gift_seasons_type ON cloud.gift_seasons(season_type);
CREATE INDEX idx_gift_seasons_name ON cloud.gift_seasons(season_name);
CREATE INDEX idx_gift_seasons_date_range ON cloud.gift_seasons(start_recommend, end_recommend);

-- 6. 行业知识表
CREATE TABLE cloud.industry_knowledge (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type knowledge_type NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    keywords TEXT[] DEFAULT '{}',
    related_materials UUID[] DEFAULT '{}',
    related_crafts UUID[] DEFAULT '{}',
    embedding vector(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_industry_knowledge_type ON cloud.industry_knowledge(type);
CREATE INDEX idx_industry_knowledge_keywords ON cloud.industry_knowledge USING GIN(keywords);
CREATE INDEX idx_industry_knowledge_embedding ON cloud.industry_knowledge USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================
-- 租户知识库 (Tenant Schema) - 多租户隔离
-- ============================================

CREATE SCHEMA IF NOT EXISTS tenant;

-- 1. 租户表（品牌/连锁总部）
CREATE TABLE tenant.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,           -- 品牌名称
    type tenant_type NOT NULL DEFAULT 'independent',  -- 连锁/独立
    contact_person VARCHAR(100),
    contact_phone VARCHAR(50),
    contact_email VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_tenants_type ON tenant.tenants(type);
CREATE INDEX idx_tenants_is_active ON tenant.tenants(is_active);

-- 2. 门店表（属于某个租户）
CREATE TABLE tenant.stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    code VARCHAR(50),                     -- 门店编码
    address TEXT,
    phone VARCHAR(50),
    wechat_corp_id VARCHAR(100),          -- 企业微信 ID
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_stores_tenant_id ON tenant.stores(tenant_id);
CREATE INDEX idx_stores_code ON tenant.stores(code);
CREATE INDEX idx_stores_is_active ON tenant.stores(is_active);

-- 3. 供应商表（门店级别，完全隔离）
CREATE TABLE tenant.suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(50),
    wechat VARCHAR(100),
    address TEXT,
    specialties TEXT[] DEFAULT '{}',
    equipment TEXT,
    price_level price_level_type DEFAULT 'medium',
    quality_rating INT CHECK (quality_rating >= 1 AND quality_rating <= 5),
    delivery_rating INT CHECK (delivery_rating >= 1 AND delivery_rating <= 5),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    source data_source_type DEFAULT 'manual',
    embedding vector(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_suppliers_tenant_id ON tenant.suppliers(tenant_id);
CREATE INDEX idx_suppliers_store_id ON tenant.suppliers(store_id);
CREATE INDEX idx_suppliers_specialties ON tenant.suppliers USING GIN(specialties);
CREATE INDEX idx_suppliers_is_active ON tenant.suppliers(is_active);
CREATE INDEX idx_suppliers_embedding ON tenant.suppliers USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 4. 产品价格表（门店级别，完全隔离）
CREATE TABLE tenant.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    cloud_template_id UUID,               -- 关联云端产品模板（可选）
    name VARCHAR(200) NOT NULL,
    category VARCHAR(50),
    specs JSONB DEFAULT '{}',
    base_price DECIMAL(10, 2),            -- 当前价格，直接覆盖
    price_tiers JSONB DEFAULT '[]',       -- [{qty: 100, price: 10}, {qty: 500, price: 8}]
    cost DECIMAL(10, 2),
    supplier_id UUID REFERENCES tenant.suppliers(id) ON DELETE SET NULL,
    production_time VARCHAR(50),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    source data_source_type DEFAULT 'manual',
    embedding vector(1536),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_products_tenant_id ON tenant.products(tenant_id);
CREATE INDEX idx_products_store_id ON tenant.products(store_id);
CREATE INDEX idx_products_category ON tenant.products(category);
CREATE INDEX idx_products_is_active ON tenant.products(is_active);
CREATE INDEX idx_products_embedding ON tenant.products USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 5. 礼品库存表（门店级别，完全隔离）
CREATE TABLE tenant.gift_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    cloud_gift_id UUID,                   -- 关联云端礼品（可选）
    name VARCHAR(200) NOT NULL,
    local_price DECIMAL(10, 2),           -- 当前价格，直接覆盖
    cost DECIMAL(10, 2),
    stock_qty INT DEFAULT 0,
    supplier_id UUID REFERENCES tenant.suppliers(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    valid_from DATE,
    valid_until DATE,
    source data_source_type DEFAULT 'manual',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_gift_inventory_tenant_id ON tenant.gift_inventory(tenant_id);
CREATE INDEX idx_gift_inventory_store_id ON tenant.gift_inventory(store_id);
CREATE INDEX idx_gift_inventory_is_active ON tenant.gift_inventory(is_active);
CREATE INDEX idx_gift_inventory_valid_range ON tenant.gift_inventory(valid_from, valid_until);

-- 6. 聊天摘录记录表（门店级别，完全隔离）
CREATE TABLE tenant.chat_extracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    raw_text TEXT NOT NULL,
    extracted_type extract_type NOT NULL,
    extracted_data JSONB NOT NULL,
    target_table VARCHAR(50),
    target_id UUID,
    confidence DECIMAL(3, 2) CHECK (confidence >= 0 AND confidence <= 1),
    confirmed BOOLEAN DEFAULT false,
    extracted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    confirmed_at TIMESTAMP WITH TIME ZONE,
    confirmed_by VARCHAR(100)
);

CREATE INDEX idx_chat_extracts_tenant_id ON tenant.chat_extracts(tenant_id);
CREATE INDEX idx_chat_extracts_store_id ON tenant.chat_extracts(store_id);
CREATE INDEX idx_chat_extracts_type ON tenant.chat_extracts(extracted_type);
CREATE INDEX idx_chat_extracts_confirmed ON tenant.chat_extracts(confirmed);

-- ============================================
-- 行级安全策略 (Row Level Security) - 多租户隔离
-- ============================================

-- 启用 RLS
ALTER TABLE tenant.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.gift_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.chat_extracts ENABLE ROW LEVEL SECURITY;

-- 创建策略：只能访问自己租户的数据
-- 注意：需要在应用层设置 current_setting('app.current_tenant_id')

CREATE POLICY tenant_isolation_stores ON tenant.stores
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::UUID);

CREATE POLICY tenant_isolation_suppliers ON tenant.suppliers
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::UUID);

CREATE POLICY tenant_isolation_products ON tenant.products
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::UUID);

CREATE POLICY tenant_isolation_gift_inventory ON tenant.gift_inventory
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::UUID);

CREATE POLICY tenant_isolation_chat_extracts ON tenant.chat_extracts
    FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::UUID);

-- ============================================
-- 触发器：自动更新 updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 云端表
CREATE TRIGGER trg_materials_updated_at BEFORE UPDATE ON cloud.materials FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_crafts_updated_at BEFORE UPDATE ON cloud.crafts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_product_templates_updated_at BEFORE UPDATE ON cloud.product_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_gifts_updated_at BEFORE UPDATE ON cloud.gifts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_industry_knowledge_updated_at BEFORE UPDATE ON cloud.industry_knowledge FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 租户表
CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenant.tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_stores_updated_at BEFORE UPDATE ON tenant.stores FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_suppliers_updated_at BEFORE UPDATE ON tenant.suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON tenant.products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_gift_inventory_updated_at BEFORE UPDATE ON tenant.gift_inventory FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- 语义搜索辅助函数
-- ============================================

-- 搜索材料（云端，所有租户可用）
CREATE OR REPLACE FUNCTION cloud.search_materials(
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    name VARCHAR(100),
    category VARCHAR(50),
    description TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.name,
        m.category,
        m.description,
        1 - (m.embedding <=> query_embedding) AS similarity
    FROM cloud.materials m
    WHERE 1 - (m.embedding <=> query_embedding) > match_threshold
    ORDER BY m.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- 搜索工艺（云端，所有租户可用）
CREATE OR REPLACE FUNCTION cloud.search_crafts(
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    name VARCHAR(100),
    category VARCHAR(50),
    description TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.category,
        c.description,
        1 - (c.embedding <=> query_embedding) AS similarity
    FROM cloud.crafts c
    WHERE 1 - (c.embedding <=> query_embedding) > match_threshold
    ORDER BY c.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- 搜索行业知识（云端，所有租户可用）
CREATE OR REPLACE FUNCTION cloud.search_knowledge(
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    type knowledge_type,
    question TEXT,
    answer TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        k.id,
        k.type,
        k.question,
        k.answer,
        1 - (k.embedding <=> query_embedding) AS similarity
    FROM cloud.industry_knowledge k
    WHERE 1 - (k.embedding <=> query_embedding) > match_threshold
    ORDER BY k.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- 搜索供应商（租户隔离）
CREATE OR REPLACE FUNCTION tenant.search_suppliers(
    p_tenant_id UUID,
    p_store_id UUID,
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    name VARCHAR(200),
    specialties TEXT[],
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.name,
        s.specialties,
        1 - (s.embedding <=> query_embedding) AS similarity
    FROM tenant.suppliers s
    WHERE s.tenant_id = p_tenant_id
      AND s.store_id = p_store_id
      AND s.is_active = true
      AND 1 - (s.embedding <=> query_embedding) > match_threshold
    ORDER BY s.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- 搜索产品（租户隔离）
CREATE OR REPLACE FUNCTION tenant.search_products(
    p_tenant_id UUID,
    p_store_id UUID,
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    name VARCHAR(200),
    category VARCHAR(50),
    base_price DECIMAL(10, 2),
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.category,
        p.base_price,
        1 - (p.embedding <=> query_embedding) AS similarity
    FROM tenant.products p
    WHERE p.tenant_id = p_tenant_id
      AND p.store_id = p_store_id
      AND p.is_active = true
      AND 1 - (p.embedding <=> query_embedding) > match_threshold
    ORDER BY p.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 获取当季推荐礼品（云端，所有租户可用）
-- ============================================

CREATE OR REPLACE FUNCTION cloud.get_seasonal_gifts(
    check_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    gift_id UUID,
    gift_name VARCHAR(200),
    category VARCHAR(50),
    season_name VARCHAR(50),
    priority INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.id AS gift_id,
        g.name AS gift_name,
        g.category,
        gs.season_name,
        gs.priority
    FROM cloud.gifts g
    JOIN cloud.gift_seasons gs ON g.id = gs.gift_id
    WHERE check_date BETWEEN gs.start_recommend AND gs.end_recommend
    ORDER BY gs.priority DESC, g.name;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 完成
-- ============================================

COMMENT ON SCHEMA cloud IS '云端知识库 - 行业通用数据，总部维护，所有租户只读';
COMMENT ON SCHEMA tenant IS '租户知识库 - 门店私有数据，完全隔离，各自读写';

-- 打印完成信息
DO $$
BEGIN
    RAISE NOTICE 'PrintShop 数据库初始化完成！';
    RAISE NOTICE '';
    RAISE NOTICE '云端表 (cloud.*): materials, crafts, product_templates, gifts, gift_seasons, industry_knowledge';
    RAISE NOTICE '租户表 (tenant.*): tenants, stores, suppliers, products, gift_inventory, chat_extracts';
    RAISE NOTICE '';
    RAISE NOTICE '多租户隔离: 已启用 RLS，通过 tenant_id 隔离';
    RAISE NOTICE '向量搜索: 已启用 pgvector，embedding 维度 1536';
    RAISE NOTICE '';
    RAISE NOTICE '使用方法:';
    RAISE NOTICE '  1. 应用层设置: SET app.current_tenant_id = ''租户UUID''';
    RAISE NOTICE '  2. 所有租户表查询自动按 tenant_id 过滤';
END $$;
