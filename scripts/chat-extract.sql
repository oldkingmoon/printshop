-- PrintShop 聊天摘录解析
-- 版本: v1.0
-- 作者: 员工2号
-- 日期: 2026-02-06
--
-- 功能：从自然语言对话中提取结构化数据
-- 依赖: init-db.sql

-- ============================================
-- 辅助函数：提取电话号码
-- ============================================

CREATE OR REPLACE FUNCTION tenant.extract_phone(p_text TEXT)
RETURNS TEXT AS $$
DECLARE
    v_phone TEXT;
BEGIN
    -- 匹配手机号（11位）或座机（区号-号码）
    SELECT (regexp_matches(p_text, '1[3-9]\d{9}', 'g'))[1] INTO v_phone;
    IF v_phone IS NULL THEN
        SELECT (regexp_matches(p_text, '\d{3,4}[-\s]?\d{7,8}', 'g'))[1] INTO v_phone;
    END IF;
    RETURN v_phone;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 辅助函数：提取价格
-- ============================================

CREATE OR REPLACE FUNCTION tenant.extract_price(p_text TEXT)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_price TEXT;
BEGIN
    -- 匹配价格模式：¥35、35元、35块
    SELECT (regexp_matches(p_text, '(?:¥|￥)?(\d+(?:\.\d{1,2})?)\s*(?:元|块|/)', 'gi'))[1] 
    INTO v_price;
    RETURN v_price::DECIMAL(10, 2);
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 辅助函数：提取数量
-- ============================================

CREATE OR REPLACE FUNCTION tenant.extract_quantity(p_text TEXT)
RETURNS INT AS $$
DECLARE
    v_qty TEXT;
BEGIN
    -- 匹配数量模式：500张、100个、200本
    SELECT (regexp_matches(p_text, '(\d+)\s*(?:张|个|本|份|盒|箱)', 'gi'))[1] 
    INTO v_qty;
    RETURN v_qty::INT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 解析供应商信息
-- ============================================

CREATE OR REPLACE FUNCTION tenant.parse_supplier_text(p_text TEXT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::JSONB;
    v_name TEXT;
    v_contact TEXT;
    v_phone TEXT;
    v_wechat TEXT;
    v_address TEXT;
    v_specialties TEXT[];
    v_price TEXT;
    v_match TEXT[];
BEGIN
    -- 提取名称（XX厂、XX公司、XX店）
    SELECT (regexp_matches(p_text, '([^\s,，、]+(?:厂|公司|店|印刷|广告))', 'gi'))[1] INTO v_name;
    IF v_name IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('name', v_name);
    END IF;
    
    -- 提取联系人
    SELECT (regexp_matches(p_text, '(?:联系人|找|问|负责人)[：:\s]*([^\s,，、电话微信]+)', 'gi'))[1] INTO v_contact;
    IF v_contact IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('contact_person', v_contact);
    END IF;
    
    -- 提取电话
    v_phone := tenant.extract_phone(p_text);
    IF v_phone IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('phone', v_phone);
    END IF;
    
    -- 提取微信
    SELECT (regexp_matches(p_text, '(?:微信|wx)[：:\s]*([^\s,，、]+)', 'gi'))[1] INTO v_wechat;
    IF v_wechat IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('wechat', v_wechat);
    END IF;
    
    -- 提取地址
    SELECT (regexp_matches(p_text, '(?:地址|在|位于)[：:\s]*([^\s,，、]+(?:路|街|区|园|号|楼)[^\s,，、]*)', 'gi'))[1] INTO v_address;
    IF v_address IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('address', v_address);
    END IF;
    
    -- 提取主营业务
    SELECT ARRAY(
        SELECT (regexp_matches(p_text, '(?:主营|做|专门|专业)[：:\s]*([^\s,，、价格电话]+)', 'gi'))[1]
    ) INTO v_specialties;
    IF array_length(v_specialties, 1) > 0 AND v_specialties[1] IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('specialties', v_specialties);
    END IF;
    
    -- 提取参考价格
    v_price := (regexp_matches(p_text, '(?:价格|报价)?(\d+(?:\.\d{1,2})?)\s*(?:元|块)?[/每]\s*(?:平方|㎡|张|个)', 'gi'))[1];
    IF v_price IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('reference_price', v_price);
    END IF;
    
    -- 添加置信度（基于提取到的字段数量）
    v_result := v_result || jsonb_build_object(
        'confidence', 
        LEAST(1.0, (jsonb_object_keys(v_result)::INT * 0.15 + 0.1))
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 解析产品信息
-- ============================================

CREATE OR REPLACE FUNCTION tenant.parse_product_text(p_text TEXT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::JSONB;
    v_name TEXT;
    v_category TEXT;
    v_price_tiers JSONB := '[]'::JSONB;
    v_matches TEXT[];
    v_qty INT;
    v_price DECIMAL(10, 2);
BEGIN
    -- 识别产品类型
    IF p_text ~* '名片' THEN
        v_name := '名片';
        v_category := 'card';
    ELSIF p_text ~* '画册|宣传册' THEN
        v_name := '画册';
        v_category := 'booklet';
    ELSIF p_text ~* '海报|喷绘|写真' THEN
        v_name := '喷绘';
        v_category := 'print';
    ELSIF p_text ~* '单页|传单|DM' THEN
        v_name := '单页';
        v_category := 'flyer';
    END IF;
    
    IF v_name IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('name', v_name, 'category', v_category);
    END IF;
    
    -- 提取价格阶梯（如：500张150元，1000张200元）
    FOR v_matches IN 
        SELECT regexp_matches(p_text, '(\d+)\s*(?:张|本|个|份)[^\d]*?(\d+(?:\.\d{1,2})?)\s*(?:元|块)', 'gi')
    LOOP
        v_qty := v_matches[1]::INT;
        v_price := v_matches[2]::DECIMAL(10, 2);
        v_price_tiers := v_price_tiers || jsonb_build_object(
            'quantity', v_qty,
            'total_price', v_price,
            'unit_price', ROUND(v_price / v_qty, 4)
        );
    END LOOP;
    
    IF jsonb_array_length(v_price_tiers) > 0 THEN
        v_result := v_result || jsonb_build_object('price_tiers', v_price_tiers);
    END IF;
    
    -- 提取规格
    IF p_text ~* '16开|大16开' THEN
        v_result := v_result || jsonb_build_object('size', '16开');
    ELSIF p_text ~* 'A4' THEN
        v_result := v_result || jsonb_build_object('size', 'A4');
    ELSIF p_text ~* 'A3' THEN
        v_result := v_result || jsonb_build_object('size', 'A3');
    END IF;
    
    -- 提取页数
    SELECT (regexp_matches(p_text, '(\d+)\s*[Pp页]', 'gi'))[1]::INT INTO v_qty;
    IF v_qty IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('pages', v_qty);
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 解析礼品信息
-- ============================================

CREATE OR REPLACE FUNCTION tenant.parse_gift_text(p_text TEXT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::JSONB;
    v_name TEXT;
    v_cost DECIMAL(10, 2);
    v_price DECIMAL(10, 2);
    v_stock INT;
BEGIN
    -- 提取礼品名称（常见礼品关键词）
    SELECT (regexp_matches(p_text, '(保温杯|笔记本|签字笔|U盘|充电宝|雨伞|背包|礼盒|茶叶|坚果|[^\s,，、]+(?:杯|本|笔|盘|宝|伞|包|盒))', 'gi'))[1] 
    INTO v_name;
    IF v_name IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('name', v_name);
    END IF;
    
    -- 提取成本
    SELECT (regexp_matches(p_text, '(?:成本|进价|采购)[：:\s]*(?:¥|￥)?(\d+(?:\.\d{1,2})?)', 'gi'))[1]::DECIMAL(10, 2)
    INTO v_cost;
    IF v_cost IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('cost', v_cost);
    END IF;
    
    -- 提取售价
    SELECT (regexp_matches(p_text, '(?:卖|售价|零售|售)[：:\s]*(?:¥|￥)?(\d+(?:\.\d{1,2})?)', 'gi'))[1]::DECIMAL(10, 2)
    INTO v_price;
    IF v_price IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('local_price', v_price);
    END IF;
    
    -- 提取库存
    SELECT (regexp_matches(p_text, '(?:库存|有|到货|进了)[：:\s]*(\d+)\s*(?:个|件|套)?', 'gi'))[1]::INT
    INTO v_stock;
    IF v_stock IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('stock_qty', v_stock);
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 保存聊天摘录（待确认）
-- ============================================

CREATE OR REPLACE FUNCTION tenant.save_chat_extract(
    p_tenant_id UUID,
    p_store_id UUID,
    p_raw_text TEXT,
    p_extract_type extract_type,
    p_extracted_data JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_extract_id UUID;
    v_data JSONB;
    v_confidence DECIMAL(3, 2);
BEGIN
    -- 如果没有提供解析数据，自动解析
    IF p_extracted_data IS NULL THEN
        CASE p_extract_type
            WHEN 'supplier' THEN
                v_data := tenant.parse_supplier_text(p_raw_text);
            WHEN 'product' THEN
                v_data := tenant.parse_product_text(p_raw_text);
            WHEN 'gift' THEN
                v_data := tenant.parse_gift_text(p_raw_text);
            ELSE
                v_data := '{}'::JSONB;
        END CASE;
    ELSE
        v_data := p_extracted_data;
    END IF;
    
    -- 提取置信度
    v_confidence := COALESCE((v_data->>'confidence')::DECIMAL(3, 2), 0.5);
    v_data := v_data - 'confidence';  -- 从数据中移除置信度字段
    
    -- 插入记录
    INSERT INTO tenant.chat_extracts (
        tenant_id, store_id, raw_text, extracted_type, 
        extracted_data, confidence, confirmed
    ) VALUES (
        p_tenant_id, p_store_id, p_raw_text, p_extract_type,
        v_data, v_confidence, false
    )
    RETURNING id INTO v_extract_id;
    
    RETURN v_extract_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 确认摘录并写入目标表
-- ============================================

CREATE OR REPLACE FUNCTION tenant.confirm_chat_extract(
    p_extract_id UUID,
    p_confirmed_by VARCHAR(100) DEFAULT 'user'
)
RETURNS JSONB AS $$
DECLARE
    v_extract RECORD;
    v_target_id UUID;
    v_result JSONB;
BEGIN
    -- 获取摘录记录
    SELECT * INTO v_extract
    FROM tenant.chat_extracts
    WHERE id = p_extract_id AND confirmed = false;
    
    IF v_extract IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Extract not found or already confirmed');
    END IF;
    
    -- 根据类型写入目标表
    CASE v_extract.extracted_type
        WHEN 'supplier' THEN
            INSERT INTO tenant.suppliers (
                tenant_id, store_id, name, contact_person, phone, wechat,
                address, specialties, source
            ) VALUES (
                v_extract.tenant_id,
                v_extract.store_id,
                v_extract.extracted_data->>'name',
                v_extract.extracted_data->>'contact_person',
                v_extract.extracted_data->>'phone',
                v_extract.extracted_data->>'wechat',
                v_extract.extracted_data->>'address',
                COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(v_extract.extracted_data->'specialties')),
                    '{}'::TEXT[]
                ),
                'chat_extract'
            )
            RETURNING id INTO v_target_id;
            
        WHEN 'product' THEN
            INSERT INTO tenant.products (
                tenant_id, store_id, name, category, 
                base_price, price_tiers, source
            ) VALUES (
                v_extract.tenant_id,
                v_extract.store_id,
                v_extract.extracted_data->>'name',
                v_extract.extracted_data->>'category',
                (v_extract.extracted_data->'price_tiers'->0->>'total_price')::DECIMAL(10, 2),
                v_extract.extracted_data->'price_tiers',
                'chat_extract'
            )
            RETURNING id INTO v_target_id;
            
        WHEN 'gift' THEN
            INSERT INTO tenant.gift_inventory (
                tenant_id, store_id, name, local_price, cost, stock_qty, source
            ) VALUES (
                v_extract.tenant_id,
                v_extract.store_id,
                v_extract.extracted_data->>'name',
                (v_extract.extracted_data->>'local_price')::DECIMAL(10, 2),
                (v_extract.extracted_data->>'cost')::DECIMAL(10, 2),
                (v_extract.extracted_data->>'stock_qty')::INT,
                'chat_extract'
            )
            RETURNING id INTO v_target_id;
            
        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Unknown extract type');
    END CASE;
    
    -- 更新摘录记录
    UPDATE tenant.chat_extracts
    SET confirmed = true,
        confirmed_at = NOW(),
        confirmed_by = p_confirmed_by,
        target_table = v_extract.extracted_type::TEXT,
        target_id = v_target_id
    WHERE id = p_extract_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'extract_id', p_extract_id,
        'target_table', v_extract.extracted_type,
        'target_id', v_target_id
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 拒绝/删除摘录
-- ============================================

CREATE OR REPLACE FUNCTION tenant.reject_chat_extract(p_extract_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM tenant.chat_extracts WHERE id = p_extract_id AND confirmed = false;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 智能识别并保存（一步到位）
-- ============================================

CREATE OR REPLACE FUNCTION tenant.smart_extract(
    p_tenant_id UUID,
    p_store_id UUID,
    p_text TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_type extract_type;
    v_data JSONB;
    v_extract_id UUID;
BEGIN
    -- 智能识别类型
    IF p_text ~* '(?:厂|公司|印刷|供应商|联系人|电话.*主营|主营.*电话)' THEN
        v_type := 'supplier';
        v_data := tenant.parse_supplier_text(p_text);
    ELSIF p_text ~* '(?:名片|画册|海报|喷绘|单页).*(?:价格|元|块|\d+张)' THEN
        v_type := 'product';
        v_data := tenant.parse_product_text(p_text);
    ELSIF p_text ~* '(?:礼品|礼物|成本.*卖|卖.*成本|库存)' THEN
        v_type := 'gift';
        v_data := tenant.parse_gift_text(p_text);
    ELSE
        -- 尝试所有解析器，选择结果最丰富的
        v_data := tenant.parse_supplier_text(p_text);
        IF jsonb_object_keys(v_data)::INT <= 2 THEN
            v_data := tenant.parse_product_text(p_text);
            IF jsonb_object_keys(v_data)::INT <= 1 THEN
                v_data := tenant.parse_gift_text(p_text);
                v_type := 'gift';
            ELSE
                v_type := 'product';
            END IF;
        ELSE
            v_type := 'supplier';
        END IF;
    END IF;
    
    -- 保存摘录
    v_extract_id := tenant.save_chat_extract(
        p_tenant_id, p_store_id, p_text, v_type, v_data
    );
    
    RETURN jsonb_build_object(
        'extract_id', v_extract_id,
        'type', v_type,
        'data', v_data,
        'message', CASE v_type
            WHEN 'supplier' THEN '识别为供应商信息'
            WHEN 'product' THEN '识别为产品价格'
            WHEN 'gift' THEN '识别为礼品信息'
            ELSE '未能识别类型'
        END
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 使用示例
-- ============================================

/*
-- 示例1：解析供应商文本
SELECT tenant.parse_supplier_text(
    '记住张三印刷厂，联系人李四，电话13812345678，主营大幅面喷绘，价格35元/平方'
);
-- 返回: {"name": "张三印刷厂", "contact_person": "李四", "phone": "13812345678", "specialties": ["大幅面喷绘"], "reference_price": "35"}

-- 示例2：解析产品文本
SELECT tenant.parse_product_text(
    '名片价格更新，500张150元，1000张200元'
);
-- 返回: {"name": "名片", "category": "card", "price_tiers": [{"quantity": 500, "total_price": 150}, {"quantity": 1000, "total_price": 200}]}

-- 示例3：智能识别并保存
SELECT tenant.smart_extract(
    '租户ID'::UUID,
    '门店ID'::UUID,
    '记住张三印刷厂，电话13812345678，主营喷绘'
);

-- 示例4：确认摘录
SELECT tenant.confirm_chat_extract('摘录ID'::UUID, 'admin');
*/

-- ============================================
-- 供应商群场景：从供应商消息提取产品信息
-- ============================================

-- 解析供应商发来的产品信息
CREATE OR REPLACE FUNCTION tenant.parse_supplier_product(p_text TEXT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::JSONB;
    v_name TEXT;
    v_specs JSONB := '{}'::JSONB;
    v_price DECIMAL(10, 2);
    v_min_qty INT;
    v_delivery TEXT;
    v_unit TEXT;
BEGIN
    -- 提取产品名称（常见印刷品/礼品）
    SELECT (regexp_matches(p_text, 
        '(名片|画册|宣传册|海报|易拉宝|X展架|条幅|横幅|锦旗|奖牌|奖杯|' ||
        '保温杯|笔记本|签字笔|U盘|充电宝|雨伞|背包|礼盒|' ||
        '铜版纸|哑粉纸|白卡纸|牛皮纸|特种纸|' ||
        '写真|喷绘|背胶|灯布|车贴|KT板|PVC板|亚克力|' ||
        '[^\s,，、：:]+(?:纸|布|板|膜|杯|本|笔|盘|宝|伞|包|盒|牌|杯|架))', 
        'gi'))[1] 
    INTO v_name;
    
    IF v_name IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('name', v_name);
    END IF;
    
    -- 提取规格尺寸
    -- 纸张克重
    SELECT (regexp_matches(p_text, '(\d+)[gG克]', 'gi'))[1] INTO v_unit;
    IF v_unit IS NOT NULL THEN
        v_specs := v_specs || jsonb_build_object('weight', v_unit || 'g');
    END IF;
    
    -- 尺寸（如 90x54mm, 3m*2m）
    SELECT (regexp_matches(p_text, '(\d+(?:\.\d+)?)\s*[xX×*]\s*(\d+(?:\.\d+)?)\s*(mm|cm|m|米)?', 'gi'))[1:3]::TEXT
    INTO v_unit;
    IF v_unit IS NOT NULL THEN
        v_specs := v_specs || jsonb_build_object('size', v_unit);
    END IF;
    
    -- 开数
    SELECT (regexp_matches(p_text, '(大?16开|A[34]|对开|四开|八开)', 'gi'))[1] INTO v_unit;
    IF v_unit IS NOT NULL THEN
        v_specs := v_specs || jsonb_build_object('format', v_unit);
    END IF;
    
    IF v_specs != '{}'::JSONB THEN
        v_result := v_result || jsonb_build_object('specs', v_specs);
    END IF;
    
    -- 提取价格（支持多种格式）
    -- 格式1: ¥35/㎡, 35元/平方
    SELECT (regexp_matches(p_text, '(?:¥|￥)?(\d+(?:\.\d{1,2})?)\s*(?:元|块)?[/每]\s*(?:平方|㎡|张|个|本|米|m)', 'gi'))[1]::DECIMAL(10, 2)
    INTO v_price;
    
    -- 格式2: 单价35元
    IF v_price IS NULL THEN
        SELECT (regexp_matches(p_text, '(?:单价|价格|报价)[：:\s]*(?:¥|￥)?(\d+(?:\.\d{1,2})?)', 'gi'))[1]::DECIMAL(10, 2)
        INTO v_price;
    END IF;
    
    -- 格式3: 35元起
    IF v_price IS NULL THEN
        SELECT (regexp_matches(p_text, '(?:¥|￥)?(\d+(?:\.\d{1,2})?)\s*(?:元|块)?\s*起', 'gi'))[1]::DECIMAL(10, 2)
        INTO v_price;
    END IF;
    
    IF v_price IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('price', v_price);
        
        -- 提取计价单位
        SELECT (regexp_matches(p_text, '\d+(?:\.\d{1,2})?\s*(?:元|块)?[/每]\s*(平方|㎡|张|个|本|米|m)', 'gi'))[1]
        INTO v_unit;
        IF v_unit IS NOT NULL THEN
            v_result := v_result || jsonb_build_object('price_unit', v_unit);
        END IF;
    END IF;
    
    -- 提取起订量
    SELECT (regexp_matches(p_text, '(?:起订|最少|最低|MOQ)[：:\s]*(\d+)\s*(?:张|个|本|份|盒|箱|平方|㎡)?', 'gi'))[1]::INT
    INTO v_min_qty;
    IF v_min_qty IS NULL THEN
        SELECT (regexp_matches(p_text, '(\d+)\s*(?:张|个|本|份)?\s*起订', 'gi'))[1]::INT
        INTO v_min_qty;
    END IF;
    IF v_min_qty IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('min_order_qty', v_min_qty);
    END IF;
    
    -- 提取交期
    SELECT (regexp_matches(p_text, '(?:交期|工期|周期|发货)[：:\s]*(\d+[-~到至]\d+|\d+)\s*(?:天|个?工作日|小时|h)', 'gi'))[1]
    INTO v_delivery;
    IF v_delivery IS NULL THEN
        SELECT (regexp_matches(p_text, '(\d+[-~到至]\d+|\d+)\s*(?:天|个?工作日)\s*(?:交货|发货|出货)', 'gi'))[1]
        INTO v_delivery;
    END IF;
    IF v_delivery IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('delivery_time', v_delivery || '天');
    END IF;
    
    -- 提取供应商名称（如果消息里有）
    SELECT (regexp_matches(p_text, '([^\s,，、]+(?:厂|公司|店|印刷|广告))', 'gi'))[1] INTO v_unit;
    IF v_unit IS NOT NULL THEN
        v_result := v_result || jsonb_build_object('supplier_name', v_unit);
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- 从供应商消息提取产品（区分云端/本地）
-- ============================================

CREATE OR REPLACE FUNCTION tenant.extract_product_from_supplier(
    p_text TEXT,
    p_is_cloud BOOLEAN DEFAULT false,
    p_tenant_id UUID DEFAULT NULL,
    p_store_id UUID DEFAULT NULL,
    p_supplier_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_data JSONB;
    v_product_id UUID;
    v_target_schema TEXT;
BEGIN
    -- 解析产品信息
    v_data := tenant.parse_supplier_product(p_text);
    
    -- 如果提供了供应商名称，添加到数据中
    IF p_supplier_name IS NOT NULL AND v_data->>'supplier_name' IS NULL THEN
        v_data := v_data || jsonb_build_object('supplier_name', p_supplier_name);
    END IF;
    
    -- 确定目标 schema
    v_target_schema := CASE WHEN p_is_cloud THEN 'cloud' ELSE 'tenant' END;
    
    -- 如果是云端，直接写入 cloud.product_templates（需要管理员权限）
    IF p_is_cloud THEN
        INSERT INTO cloud.product_templates (
            name,
            category,
            description,
            default_specs
        ) VALUES (
            COALESCE(v_data->>'name', '未命名产品'),
            COALESCE(v_data->>'category', 'other'),
            p_text,  -- 原始文本作为描述
            COALESCE(v_data->'specs', '{}'::JSONB) || 
            jsonb_build_object(
                'price', v_data->>'price',
                'price_unit', v_data->>'price_unit',
                'min_order_qty', v_data->>'min_order_qty',
                'delivery_time', v_data->>'delivery_time',
                'supplier', v_data->>'supplier_name'
            )
        )
        RETURNING id INTO v_product_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'target', 'cloud.product_templates',
            'product_id', v_product_id,
            'data', v_data
        );
    ELSE
        -- 本地：先保存到 chat_extracts 待确认
        IF p_tenant_id IS NULL OR p_store_id IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'tenant_id and store_id required for local products',
                'data', v_data
            );
        END IF;
        
        -- 保存摘录
        INSERT INTO tenant.chat_extracts (
            tenant_id, store_id, raw_text, extracted_type,
            extracted_data, confidence, confirmed
        ) VALUES (
            p_tenant_id, p_store_id, p_text, 'product',
            v_data, 0.7, false
        )
        RETURNING id INTO v_product_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'target', 'tenant.chat_extracts',
            'extract_id', v_product_id,
            'data', v_data,
            'message', '已保存待确认，调用 confirm_chat_extract() 确认写入'
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 批量处理供应商群消息
-- ============================================

CREATE OR REPLACE FUNCTION tenant.batch_extract_supplier_products(
    p_messages JSONB,  -- [{"text": "...", "sender": "供应商A"}, ...]
    p_is_cloud BOOLEAN DEFAULT false,
    p_tenant_id UUID DEFAULT NULL,
    p_store_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_msg JSONB;
    v_result JSONB;
    v_results JSONB := '[]'::JSONB;
BEGIN
    FOR v_msg IN SELECT * FROM jsonb_array_elements(p_messages)
    LOOP
        v_result := tenant.extract_product_from_supplier(
            v_msg->>'text',
            p_is_cloud,
            p_tenant_id,
            p_store_id,
            v_msg->>'sender'
        );
        v_results := v_results || v_result;
    END LOOP;
    
    RETURN jsonb_build_object(
        'total', jsonb_array_length(p_messages),
        'results', v_results
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 供应商群消息示例
-- ============================================

/*
-- 示例1：解析供应商产品消息
SELECT tenant.parse_supplier_product(
    '【新品上架】157g铜版纸画册，16开，单价8元/本，100本起订，3-5天交货'
);
-- 返回: {"name": "画册", "specs": {"weight": "157g", "format": "16开"}, "price": 8, "price_unit": "本", "min_order_qty": 100, "delivery_time": "3-5天"}

-- 示例2：总部群消息 → 云端产品库
SELECT tenant.extract_product_from_supplier(
    '铜版纸名片，300g，90x54mm，0.3元/张，100张起订',
    true  -- is_cloud = true
);

-- 示例3：门店群消息 → 本地产品库（待确认）
SELECT tenant.extract_product_from_supplier(
    '户外写真 35元/平方，0.5㎡起订，当天出货',
    false,  -- is_cloud = false
    '租户ID'::UUID,
    '门店ID'::UUID,
    '张三广告'  -- 供应商名称
);

-- 示例4：批量处理
SELECT tenant.batch_extract_supplier_products(
    '[
        {"text": "名片0.3元/张，100张起", "sender": "印刷厂A"},
        {"text": "喷绘35元/㎡，当天出", "sender": "广告公司B"}
    ]'::JSONB,
    false,
    '租户ID'::UUID,
    '门店ID'::UUID
);
*/

-- ============================================
-- 完成
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '聊天摘录解析模块初始化完成！';
    RAISE NOTICE '';
    RAISE NOTICE '解析函数:';
    RAISE NOTICE '  - tenant.parse_supplier_text()     解析供应商';
    RAISE NOTICE '  - tenant.parse_product_text()      解析产品';
    RAISE NOTICE '  - tenant.parse_gift_text()         解析礼品';
    RAISE NOTICE '  - tenant.parse_supplier_product()  解析供应商产品消息';
    RAISE NOTICE '';
    RAISE NOTICE '业务函数:';
    RAISE NOTICE '  - tenant.save_chat_extract()              保存摘录';
    RAISE NOTICE '  - tenant.confirm_chat_extract()           确认写入';
    RAISE NOTICE '  - tenant.reject_chat_extract()            拒绝删除';
    RAISE NOTICE '  - tenant.smart_extract()                  智能识别';
    RAISE NOTICE '  - tenant.extract_product_from_supplier()  供应商产品提取';
    RAISE NOTICE '  - tenant.batch_extract_supplier_products() 批量处理';
END $$;
