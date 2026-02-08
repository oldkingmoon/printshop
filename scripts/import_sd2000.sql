-- 盛大印刷知识库入库脚本
-- 生成时间: 2026-02-08
-- 数据来源: sd2000.com

-- 1. 插入供应商
INSERT INTO suppliers (name, contact, phone, website, notes) VALUES
('河南盛大智能印刷集团有限责任公司', '盛大印刷/大崔', '400-8076-999', 'https://www.sd2000.com', 
 '成立于2000年，26年经验，30万+客户，100+生产线，覆盖200+城市，服务时间08:00-22:00');

-- 2. 插入分类
INSERT INTO categories (name, parent_id, type) VALUES
('名片/卡片', NULL, 'product'),
('单张', NULL, 'product'),
('标签/不干胶', NULL, 'product'),
('书籍画册', NULL, 'product'),
('广告物料', NULL, 'product'),
('包装周边', NULL, 'product'),
('办公用品', NULL, 'product'),
('家居日常', NULL, 'product'),
('动漫文创', NULL, 'product'),
('季节产品', NULL, 'product'),
('通版现货', NULL, 'product');

-- 3. 插入产品 (71个SKU)
-- 名片/卡片 (8个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('名片', '专业形象，一卡传递', 1, 1),
('PVC会员卡', '高档耐用，需设计88.5x57MM', 1, 1),
('彩芯名片', '夹心式立体设计', 1, 1),
('臻彩名片', '触感系列/多巴胺系列', 1, 1),
('NFC芯片卡', '碰一碰即刻分享，营销互动', 1, 1),
('PVC金属卡', '金属质感会员卡', 1, 1),
('数码透字卡', '隐于无形，显于光影', 1, 1),
('PVC一体扇', '防水防油易清洁', 1, 1);

-- 单张 (5个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('宣传单', '单张印刷', 1, 2),
('数码单张', '澜达印刷', 1, 2),
('折页', '二折/三折/四折', 1, 2),
('海报', '大幅面印刷', 1, 2),
('DM单', '广告宣传单', 1, 2);

-- 标签/不干胶 (6个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('铜版不干胶', '得世印刷', 1, 3),
('牛皮纸不干胶', '复古风格', 1, 3),
('书写纸不干胶', '可书写标签', 1, 3),
('平张打印标签', '即打即用，精准高效', 1, 3),
('卷筒不干胶', '量大专用', 1, 3),
('透明不干胶', 'PET材质', 1, 3);

-- 书籍画册 (6个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('画册', '企业宣传册', 1, 4),
('喷胶画册', '新品上线', 1, 4),
('书砖', '新品', 1, 4),
('骑马钉画册', '页数少的画册', 1, 4),
('精装画册', '高档装帧', 1, 4),
('说明书', '产品说明书印刷', 1, 4);

-- 广告物料 (8个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('X展架', '展会必备', 1, 5),
('易拉宝', '可收卷展架', 1, 5),
('抽画灯箱', '新品', 1, 5),
('荧光板', '新品', 1, 5),
('背胶对联', '可移白胶车贴材质', 1, 5),
('广告宣传杯', '新品', 1, 5),
('串旗', '新品上线', 1, 5),
('地垫', '天然橡胶，家用地垫', 1, 5);

-- 包装周边 (7个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('扣底箱', '扣底彩箱 TOP01', 1, 6),
('手提袋', '纸质/无纺布', 1, 6),
('无纺布大礼包袋', '80克无纺布，承重3kg', 1, 6),
('彩色淋膜大礼包袋', '凹版印刷，高档品质', 1, 6),
('PP透明胶盒', '磨砂胶盒 TOP07', 1, 6),
('透明礼盒', 'PET材质 TOP04', 1, 6),
('复合揉纹袋', '新品', 1, 6);

-- 办公用品 (6个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('便利贴', '5本起做，8折优惠', 1, 7),
('书本式便利贴', '新品', 1, 7),
('信封', '企业信封', 1, 7),
('信纸', '公司抬头纸', 1, 7),
('文件夹', '办公文件夹', 1, 7),
('机打联单', '告别手写，9折特惠', 1, 7);

-- 家居日常 (9个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('竹丝灯笼', '天然竹丝手作 TOP', 1, 8),
('雪弗板壁画', '立体家居装饰 TOP05', 1, 8),
('框画影像级', '定格永恒艺术', 1, 8),
('无框油画', '新品', 1, 8),
('摆台广告级', '定格时光', 1, 8),
('折叠投影灯', '新品', 1, 8),
('竹质抽纸盒', '匠心环保 TOP03', 1, 8),
('沙拉碗', '清新设计 TOP09', 1, 8),
('汤桶', 'TOP12', 1, 8);

-- 动漫文创 (6个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('零钱包', '零钱收纳 TOP02', 1, 9),
('无料邮票', '新品，一份珍贵回忆', 1, 9),
('个性化文创笔记本', '新品', 1, 9),
('贴画', '新品', 1, 9),
('梅妃腰扇', '轻巧便携 TOP08', 1, 9),
('掼蛋扑克牌', '新年社交神器', 1, 9);

-- 季节产品 (6个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('台历卡盒', '印刷工艺与实用设计', 1, 10),
('福字(永城)', '传统福字，纳福迎春', 1, 10),
('异形对联', '独特设计', 1, 10),
('宣纸对联', '新品', 1, 10),
('红包', '新年红包', 1, 10),
('窗花', '节日装饰', 1, 10);

-- 通版现货 (4个)
INSERT INTO products (name, description, supplier_id, category_id) VALUES
('通版名片', '标准模板', 1, 11),
('通版宣传单', '现货快发', 1, 11),
('通版不干胶', '即买即用', 1, 11),
('不印刷PP透明袋', '环保材料 TOP06', 1, 11);

-- 统计
SELECT '入库完成' as status, 
       (SELECT COUNT(*) FROM suppliers) as suppliers,
       (SELECT COUNT(*) FROM categories) as categories,
       (SELECT COUNT(*) FROM products) as products;
