-- PrintShop 报价引擎
-- 版本: v1.0
-- 作者: 员工2号
-- 日期: 2026-02-06
--
-- 依赖: init-db.sql (需要先执行)

-- ============================================
-- 报价配置表
-- ============================================

-- 材质价格配置
CREATE TABLE IF NOT EXISTS tenant.material_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    material_type VARCHAR(50) NOT NULL,      -- card/print/booklet
    material_name VARCHAR(100) NOT NULL,     -- 材质名称
    base_price DECIMAL(10, 2) NOT NULL,      -- 基础单价
    price_unit VARCHAR(20) NOT NULL,         -- 计价单位: piece/sqm/page
    coefficient DECIMAL(5, 2) DEFAULT 1.0,   -- 价格系数
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_material_prices_tenant ON tenant.material_prices(tenant_id, store_id);
CREATE INDEX idx_material_prices_type ON tenant.material_prices(material_type);

-- 数量阶梯配置
CREATE TABLE IF NOT EXISTS tenant.quantity_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    product_type VARCHAR(50) NOT NULL,       -- card/booklet
    min_qty INT NOT NULL,                    -- 最小数量
    max_qty INT,                             -- 最大数量 (NULL = 无上限)
    unit_price DECIMAL(10, 2),               -- 固定单价 (与 discount 二选一)
    discount DECIMAL(5, 2),                  -- 折扣系数 (与 unit_price 二选一)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_quantity_tiers_tenant ON tenant.quantity_tiers(tenant_id, store_id);
CREATE INDEX idx_quantity_tiers_type ON tenant.quantity_tiers(product_type);

-- 工艺价格配置
CREATE TABLE IF NOT EXISTS tenant.craft_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES tenant.stores(id) ON DELETE CASCADE,
    craft_name VARCHAR(100) NOT NULL,        -- 工艺名称
    price_type VARCHAR(20) NOT NULL,         -- fixed/per_piece/per_sqm/per_sqcm
    price DECIMAL(10, 2) NOT NULL,           -- 价格
    min_charge DECIMAL(10, 2) DEFAULT 0,     -- 最低收费
    plate_fee DECIMAL(10, 2) DEFAULT 0,      -- 制版费
    applicable_to TEXT[] DEFAULT '{}',       -- 适用产品类型
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_craft_prices_tenant ON tenant.craft_prices(tenant_id, store_id);
CREATE INDEX idx_craft_prices_name ON tenant.craft_prices(craft_name);

-- ============================================
-- 名片报价函数
-- ============================================

CREATE OR REPLACE FUNCTION tenant.calc_card_price(
    p_tenant_id UUID,
    p_store_id UUID,
    p_quantity INT,
    p_material VARCHAR(100) DEFAULT '300g铜版纸',
    p_crafts TEXT[] DEFAULT '{}'
)
RETURNS TABLE (
    total_price DECIMAL(10, 2),
    unit_price DECIMAL(10, 4),
    base_price DECIMAL(10, 2),
    material_fee DECIMAL(10, 2),
    craft_fee DECIMAL(10, 2),
    breakdown JSONB
) AS $$
DECLARE
    v_base_unit_price DECIMAL(10, 4);
    v_material_coef DECIMAL(5, 2);
    v_base_total DECIMAL(10, 2);
    v_craft_total DECIMAL(10, 2) := 0;
    v_craft_detail JSONB := '[]'::JSONB;
    v_craft TEXT;
    v_craft_price DECIMAL(10, 2);
    v_boxes INT;
    v_min_qty INT := 100;  -- 最低起订量
BEGIN
    -- 确保最低起订量
    IF p_quantity < v_min_qty THEN
        p_quantity := v_min_qty;
    END IF;
    
    -- 计算盒数（每盒100张）
    v_boxes := CEIL(p_quantity::DECIMAL / 100);
    
    -- 获取阶梯单价
    SELECT COALESCE(qt.unit_price, 0.30)  -- 默认 ¥0.30
    INTO v_base_unit_price
    FROM tenant.quantity_tiers qt
    WHERE qt.tenant_id = p_tenant_id
      AND qt.store_id = p_store_id
      AND qt.product_type = 'card'
      AND qt.is_active = true
      AND p_quantity >= qt.min_qty
      AND (qt.max_qty IS NULL OR p_quantity <= qt.max_qty)
    ORDER BY qt.min_qty DESC
    LIMIT 1;
    
    -- 如果没有配置，使用默认阶梯
    IF v_base_unit_price IS NULL THEN
        v_base_unit_price := CASE
            WHEN p_quantity >= 2000 THEN 0.15
            WHEN p_quantity >= 1000 THEN 0.20
            WHEN p_quantity >= 500 THEN 0.30
            WHEN p_quantity >= 200 THEN 0.40
            ELSE 0.50
        END;
    END IF;
    
    -- 获取材质系数
    SELECT COALESCE(mp.coefficient, 1.0)
    INTO v_material_coef
    FROM tenant.material_prices mp
    WHERE mp.tenant_id = p_tenant_id
      AND mp.store_id = p_store_id
      AND mp.material_type = 'card'
      AND mp.material_name = p_material
      AND mp.is_active = true;
    
    IF v_material_coef IS NULL THEN
        v_material_coef := CASE p_material
            WHEN '300g铜版纸' THEN 1.0
            WHEN '300g哑粉纸' THEN 1.1
            WHEN '280g白卡' THEN 0.9
            WHEN '特种纸' THEN 1.8
            WHEN 'PVC透明' THEN 2.5
            ELSE 1.0
        END;
    END IF;
    
    -- 计算基础价格
    v_base_total := p_quantity * v_base_unit_price * v_material_coef;
    
    -- 计算工艺附加费
    FOREACH v_craft IN ARRAY p_crafts
    LOOP
        -- 查询工艺价格
        SELECT COALESCE(cp.price, 0)
        INTO v_craft_price
        FROM tenant.craft_prices cp
        WHERE cp.tenant_id = p_tenant_id
          AND cp.store_id = p_store_id
          AND cp.craft_name = v_craft
          AND cp.is_active = true;
        
        -- 如果没有配置，使用默认价格
        IF v_craft_price IS NULL THEN
            v_craft_price := CASE v_craft
                WHEN '覆亮膜' THEN 10
                WHEN '覆哑膜' THEN 10
                WHEN '烫金' THEN 30
                WHEN '烫银' THEN 30
                WHEN 'UV局部' THEN 25
                WHEN '圆角' THEN 5
                ELSE 0
            END;
        END IF;
        
        -- 按盒计算
        v_craft_total := v_craft_total + (v_boxes * v_craft_price);
        v_craft_detail := v_craft_detail || jsonb_build_object(
            'craft', v_craft,
            'price_per_box', v_craft_price,
            'boxes', v_boxes,
            'subtotal', v_boxes * v_craft_price
        );
    END LOOP;
    
    -- 返回结果
    RETURN QUERY SELECT
        ROUND(v_base_total + v_craft_total, 2) AS total_price,
        ROUND((v_base_total + v_craft_total) / p_quantity, 4) AS unit_price,
        ROUND(p_quantity * v_base_unit_price, 2) AS base_price,
        ROUND(v_base_total - p_quantity * v_base_unit_price, 2) AS material_fee,
        ROUND(v_craft_total, 2) AS craft_fee,
        jsonb_build_object(
            'quantity', p_quantity,
            'material', p_material,
            'material_coefficient', v_material_coef,
            'base_unit_price', v_base_unit_price,
            'boxes', v_boxes,
            'crafts', v_craft_detail
        ) AS breakdown;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 喷绘报价函数
-- ============================================

CREATE OR REPLACE FUNCTION tenant.calc_print_price(
    p_tenant_id UUID,
    p_store_id UUID,
    p_width DECIMAL(10, 2),      -- 宽度（米）
    p_height DECIMAL(10, 2),     -- 高度（米）
    p_material VARCHAR(100) DEFAULT '写真纸',
    p_is_outdoor BOOLEAN DEFAULT false,
    p_crafts TEXT[] DEFAULT '{}'
)
RETURNS TABLE (
    total_price DECIMAL(10, 2),
    area DECIMAL(10, 2),
    material_price DECIMAL(10, 2),
    craft_fee DECIMAL(10, 2),
    breakdown JSONB
) AS $$
DECLARE
    v_area DECIMAL(10, 2);
    v_min_area DECIMAL(10, 2) := 0.5;  -- 最小面积
    v_unit_price DECIMAL(10, 2);
    v_material_total DECIMAL(10, 2);
    v_craft_total DECIMAL(10, 2) := 0;
    v_craft_detail JSONB := '[]'::JSONB;
    v_craft TEXT;
    v_craft_price DECIMAL(10, 2);
BEGIN
    -- 计算面积
    v_area := p_width * p_height;
    IF v_area < v_min_area THEN
        v_area := v_min_area;
    END IF;
    
    -- 获取材质单价
    SELECT COALESCE(mp.base_price, 35)
    INTO v_unit_price
    FROM tenant.material_prices mp
    WHERE mp.tenant_id = p_tenant_id
      AND mp.store_id = p_store_id
      AND mp.material_type = 'print'
      AND mp.material_name = p_material
      AND mp.is_active = true;
    
    -- 如果没有配置，使用默认价格
    IF v_unit_price IS NULL THEN
        IF p_is_outdoor THEN
            v_unit_price := CASE p_material
                WHEN '背胶' THEN 60
                WHEN '灯布' THEN 65
                WHEN '车贴' THEN 80
                WHEN '单透' THEN 90
                ELSE 60
            END;
        ELSE
            v_unit_price := CASE p_material
                WHEN '写真纸' THEN 35
                WHEN '背胶' THEN 40
                WHEN '灯布' THEN 45
                WHEN '油画布' THEN 60
                ELSE 35
            END;
        END IF;
    END IF;
    
    -- 计算材质费用
    v_material_total := v_area * v_unit_price;
    
    -- 计算工艺附加费
    FOREACH v_craft IN ARRAY p_crafts
    LOOP
        v_craft_price := CASE v_craft
            WHEN '覆亮膜' THEN 10
            WHEN '覆哑膜' THEN 10
            WHEN '冷裱' THEN 8
            WHEN '裱KT板' THEN 15
            WHEN '裱PVC板' THEN 35
            ELSE 0
        END;
        
        v_craft_total := v_craft_total + (v_area * v_craft_price);
        v_craft_detail := v_craft_detail || jsonb_build_object(
            'craft', v_craft,
            'price_per_sqm', v_craft_price,
            'subtotal', ROUND(v_area * v_craft_price, 2)
        );
    END LOOP;
    
    -- 返回结果
    RETURN QUERY SELECT
        ROUND(v_material_total + v_craft_total, 2) AS total_price,
        ROUND(v_area, 2) AS area,
        ROUND(v_material_total, 2) AS material_price,
        ROUND(v_craft_total, 2) AS craft_fee,
        jsonb_build_object(
            'width', p_width,
            'height', p_height,
            'area', ROUND(v_area, 2),
            'material', p_material,
            'is_outdoor', p_is_outdoor,
            'unit_price', v_unit_price,
            'crafts', v_craft_detail
        ) AS breakdown;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 画册报价函数
-- ============================================

CREATE OR REPLACE FUNCTION tenant.calc_booklet_price(
    p_tenant_id UUID,
    p_store_id UUID,
    p_quantity INT,
    p_size VARCHAR(20) DEFAULT '16开',       -- 16开/A4
    p_pages INT DEFAULT 16,                   -- 内页页数（不含封面）
    p_cover_paper VARCHAR(100) DEFAULT '250g铜版',
    p_inner_paper VARCHAR(100) DEFAULT '157g铜版',
    p_binding VARCHAR(50) DEFAULT '骑马钉'
)
RETURNS TABLE (
    total_price DECIMAL(10, 2),
    unit_price DECIMAL(10, 4),
    cover_price DECIMAL(10, 2),
    inner_price DECIMAL(10, 2),
    binding_price DECIMAL(10, 2),
    discount_rate DECIMAL(5, 2),
    breakdown JSONB
) AS $$
DECLARE
    v_min_qty INT := 50;
    v_cover_unit DECIMAL(10, 2);
    v_inner_unit DECIMAL(10, 4);
    v_binding_unit DECIMAL(10, 2);
    v_cover_total DECIMAL(10, 2);
    v_inner_total DECIMAL(10, 2);
    v_binding_total DECIMAL(10, 2);
    v_subtotal DECIMAL(10, 2);
    v_discount DECIMAL(5, 2);
    v_final_total DECIMAL(10, 2);
BEGIN
    -- 确保最低起订量
    IF p_quantity < v_min_qty THEN
        p_quantity := v_min_qty;
    END IF;
    
    -- 封面单价（含封底，4P）
    v_cover_unit := CASE 
        WHEN p_size = '16开' AND p_cover_paper = '250g铜版' THEN 3.0
        WHEN p_size = '16开' AND p_cover_paper = '300g铜版' THEN 3.5
        WHEN p_size = 'A4' AND p_cover_paper = '250g铜版' THEN 3.5
        WHEN p_size = 'A4' AND p_cover_paper = '300g铜版' THEN 4.0
        ELSE 3.5
    END;
    
    -- 内页单价（每P）
    v_inner_unit := CASE 
        WHEN p_size = '16开' AND p_inner_paper = '157g铜版' THEN 0.15
        WHEN p_size = '16开' AND p_inner_paper = '200g铜版' THEN 0.20
        WHEN p_size = 'A4' AND p_inner_paper = '157g铜版' THEN 0.18
        WHEN p_size = 'A4' AND p_inner_paper = '200g铜版' THEN 0.25
        ELSE 0.18
    END;
    
    -- 装订单价
    v_binding_unit := CASE p_binding
        WHEN '骑马钉' THEN 1.0
        WHEN '无线胶装' THEN 2.5
        WHEN '锁线胶装' THEN 4.0
        WHEN '精装' THEN 15.0
        ELSE 2.0
    END;
    
    -- 计算各部分费用
    v_cover_total := p_quantity * v_cover_unit;
    v_inner_total := p_quantity * p_pages * v_inner_unit;
    v_binding_total := p_quantity * v_binding_unit;
    v_subtotal := v_cover_total + v_inner_total + v_binding_total;
    
    -- 数量折扣
    v_discount := CASE
        WHEN p_quantity >= 1000 THEN 0.70
        WHEN p_quantity >= 500 THEN 0.80
        WHEN p_quantity >= 300 THEN 0.85
        WHEN p_quantity >= 100 THEN 0.90
        ELSE 1.0
    END;
    
    v_final_total := v_subtotal * v_discount;
    
    -- 返回结果
    RETURN QUERY SELECT
        ROUND(v_final_total, 2) AS total_price,
        ROUND(v_final_total / p_quantity, 4) AS unit_price,
        ROUND(v_cover_total * v_discount, 2) AS cover_price,
        ROUND(v_inner_total * v_discount, 2) AS inner_price,
        ROUND(v_binding_total * v_discount, 2) AS binding_price,
        v_discount AS discount_rate,
        jsonb_build_object(
            'quantity', p_quantity,
            'size', p_size,
            'pages', p_pages,
            'cover_paper', p_cover_paper,
            'inner_paper', p_inner_paper,
            'binding', p_binding,
            'cover_unit_price', v_cover_unit,
            'inner_unit_price', v_inner_unit,
            'binding_unit_price', v_binding_unit,
            'subtotal_before_discount', ROUND(v_subtotal, 2),
            'discount', v_discount
        ) AS breakdown;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 工艺附加费计算函数
-- ============================================

CREATE OR REPLACE FUNCTION tenant.calc_craft_fee(
    p_tenant_id UUID,
    p_store_id UUID,
    p_craft_name VARCHAR(100),
    p_area_sqcm DECIMAL(10, 2) DEFAULT NULL,  -- 面积（平方厘米）
    p_quantity INT DEFAULT 1
)
RETURNS TABLE (
    craft_fee DECIMAL(10, 2),
    plate_fee DECIMAL(10, 2),
    total_fee DECIMAL(10, 2),
    breakdown JSONB
) AS $$
DECLARE
    v_price_type VARCHAR(20);
    v_price DECIMAL(10, 2);
    v_min_charge DECIMAL(10, 2);
    v_plate_fee DECIMAL(10, 2);
    v_craft_fee DECIMAL(10, 2);
BEGIN
    -- 获取工艺配置
    SELECT cp.price_type, cp.price, cp.min_charge, cp.plate_fee
    INTO v_price_type, v_price, v_min_charge, v_plate_fee
    FROM tenant.craft_prices cp
    WHERE cp.tenant_id = p_tenant_id
      AND cp.store_id = p_store_id
      AND cp.craft_name = p_craft_name
      AND cp.is_active = true;
    
    -- 如果没有配置，使用默认值
    IF v_price IS NULL THEN
        CASE p_craft_name
            WHEN '烫金' THEN
                v_price_type := 'per_sqcm';
                v_price := 0.5;
                v_plate_fee := 150;
            WHEN '烫银' THEN
                v_price_type := 'per_sqcm';
                v_price := 0.5;
                v_plate_fee := 150;
            WHEN 'UV局部' THEN
                v_price_type := 'per_sqcm';
                v_price := 0.3;
                v_plate_fee := 0;
            WHEN '压纹' THEN
                v_price_type := 'per_sqcm';
                v_price := 0.4;
                v_plate_fee := 200;
            WHEN '击凸' THEN
                v_price_type := 'per_sqcm';
                v_price := 0.6;
                v_plate_fee := 200;
            WHEN '模切' THEN
                v_price_type := 'fixed';
                v_price := 0;
                v_plate_fee := 100;
            ELSE
                v_price_type := 'fixed';
                v_price := 0;
                v_plate_fee := 0;
        END CASE;
        v_min_charge := 0;
    END IF;
    
    -- 计算工艺费
    v_craft_fee := CASE v_price_type
        WHEN 'fixed' THEN v_price
        WHEN 'per_piece' THEN v_price * p_quantity
        WHEN 'per_sqcm' THEN v_price * COALESCE(p_area_sqcm, 0) * p_quantity
        WHEN 'per_sqm' THEN v_price * COALESCE(p_area_sqcm, 0) / 10000 * p_quantity
        ELSE 0
    END;
    
    -- 应用最低收费
    IF v_craft_fee < v_min_charge THEN
        v_craft_fee := v_min_charge;
    END IF;
    
    -- 返回结果
    RETURN QUERY SELECT
        ROUND(v_craft_fee, 2) AS craft_fee,
        ROUND(COALESCE(v_plate_fee, 0), 2) AS plate_fee,
        ROUND(v_craft_fee + COALESCE(v_plate_fee, 0), 2) AS total_fee,
        jsonb_build_object(
            'craft_name', p_craft_name,
            'price_type', v_price_type,
            'unit_price', v_price,
            'area_sqcm', p_area_sqcm,
            'quantity', p_quantity,
            'min_charge', v_min_charge
        ) AS breakdown;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 综合报价函数（便捷入口）
-- ============================================

CREATE OR REPLACE FUNCTION tenant.get_quote(
    p_tenant_id UUID,
    p_store_id UUID,
    p_product_type VARCHAR(20),  -- card/print/booklet
    p_params JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    CASE p_product_type
        WHEN 'card' THEN
            SELECT jsonb_build_object(
                'product_type', 'card',
                'total_price', r.total_price,
                'unit_price', r.unit_price,
                'breakdown', r.breakdown
            ) INTO v_result
            FROM tenant.calc_card_price(
                p_tenant_id,
                p_store_id,
                (p_params->>'quantity')::INT,
                COALESCE(p_params->>'material', '300g铜版纸'),
                COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(p_params->'crafts')),
                    '{}'::TEXT[]
                )
            ) r;
            
        WHEN 'print' THEN
            SELECT jsonb_build_object(
                'product_type', 'print',
                'total_price', r.total_price,
                'area', r.area,
                'breakdown', r.breakdown
            ) INTO v_result
            FROM tenant.calc_print_price(
                p_tenant_id,
                p_store_id,
                (p_params->>'width')::DECIMAL,
                (p_params->>'height')::DECIMAL,
                COALESCE(p_params->>'material', '写真纸'),
                COALESCE((p_params->>'is_outdoor')::BOOLEAN, false),
                COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(p_params->'crafts')),
                    '{}'::TEXT[]
                )
            ) r;
            
        WHEN 'booklet' THEN
            SELECT jsonb_build_object(
                'product_type', 'booklet',
                'total_price', r.total_price,
                'unit_price', r.unit_price,
                'discount_rate', r.discount_rate,
                'breakdown', r.breakdown
            ) INTO v_result
            FROM tenant.calc_booklet_price(
                p_tenant_id,
                p_store_id,
                (p_params->>'quantity')::INT,
                COALESCE(p_params->>'size', '16开'),
                COALESCE((p_params->>'pages')::INT, 16),
                COALESCE(p_params->>'cover_paper', '250g铜版'),
                COALESCE(p_params->>'inner_paper', '157g铜版'),
                COALESCE(p_params->>'binding', '骑马钉')
            ) r;
            
        ELSE
            v_result := jsonb_build_object('error', 'Unknown product type');
    END CASE;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 使用示例
-- ============================================

/*
-- 名片报价
SELECT * FROM tenant.calc_card_price(
    '租户ID'::UUID,
    '门店ID'::UUID,
    500,                    -- 数量
    '300g哑粉纸',           -- 材质
    ARRAY['覆哑膜', '烫金'] -- 工艺
);

-- 喷绘报价
SELECT * FROM tenant.calc_print_price(
    '租户ID'::UUID,
    '门店ID'::UUID,
    3.0,                    -- 宽度（米）
    2.0,                    -- 高度（米）
    '背胶',                 -- 材质
    true,                   -- 户外
    ARRAY['覆哑膜']         -- 工艺
);

-- 画册报价
SELECT * FROM tenant.calc_booklet_price(
    '租户ID'::UUID,
    '门店ID'::UUID,
    500,                    -- 数量
    '16开',                 -- 规格
    32,                     -- 页数
    '250g铜版',             -- 封面纸张
    '157g铜版',             -- 内页纸张
    '无线胶装'              -- 装订方式
);

-- 综合报价（JSON 入口）
SELECT tenant.get_quote(
    '租户ID'::UUID,
    '门店ID'::UUID,
    'card',
    '{"quantity": 500, "material": "300g哑粉纸", "crafts": ["覆哑膜", "烫金"]}'::JSONB
);
*/

-- ============================================
-- 完成
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '报价引擎初始化完成！';
    RAISE NOTICE '';
    RAISE NOTICE '可用函数:';
    RAISE NOTICE '  - tenant.calc_card_price()    名片报价';
    RAISE NOTICE '  - tenant.calc_print_price()   喷绘报价';
    RAISE NOTICE '  - tenant.calc_booklet_price() 画册报价';
    RAISE NOTICE '  - tenant.calc_craft_fee()     工艺附加费';
    RAISE NOTICE '  - tenant.get_quote()          综合报价入口';
END $$;
