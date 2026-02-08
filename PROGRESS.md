# PrintShop 进度

## 2026-02-08

- [x] 礼品商城数据模型 gift-mall.sql
  - 商品、分类、品牌、场景、供应商、工商信息表
  - 支持5个筛选维度（价格/分类/品牌/场景/特殊标签）
- [x] 登录后台成功（playwright 脚本）
- [x] 抓取产品数据
  - 分类: 373 个
  - 首页产品: 178 个
  - 数据保存到 `data/` 目录

## 数据文件

- `data/categories-2026-02-08.json` - 373 个分类
- `data/products-homepage-2026-02-08.json` - 178 个产品
- `data/summary.json` - 抓取汇总

## 登录信息

- URL: https://lipindz.miniappss.com/
- 手机号: 18217244555
- Cookies: /tmp/lipindz-cookies.json

## 脚本位置

- 数据模型: `scripts/gift-mall.sql`
- 登录脚本: `scripts/lipindz-login.js`
- 抓取脚本: `scripts/lipindz-scraper.js`

## 下一步

- [ ] 抓取更多分类下的产品
- [ ] 抓取产品详情（规格、供应商信息）
- [ ] 导入数据到 PostgreSQL
