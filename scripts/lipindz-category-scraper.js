#!/usr/bin/env node
/**
 * 按分类抓取产品
 * 用法: node lipindz-category-scraper.js [分类ID1] [分类ID2] ...
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const DATA_DIR = path.join(__dirname, '..', 'data');
const COOKIES_FILE = '/tmp/lipindz-cookies.json';

// 默认抓取的分类
const DEFAULT_CATEGORIES = [
  { id: '14519', name: '家居日用' },
  { id: '14520', name: '家用电器' },
  { id: '14735', name: '保温杯' },
  { id: '14698', name: '茶具' },
  { id: '14723', name: '毛巾浴巾A' },
  { id: '14687', name: '厨具配件' }
];

async function scrapeCategory(page, catId, catName, maxPages = 10) {
  console.log(`\n📂 抓取分类: ${catName} (${catId})`);
  const products = [];
  
  for (let p = 1; p <= maxPages; p++) {
    const url = `https://lipindz.miniappss.com/list/classify_id/${catId}.html?page=${p}`;
    console.log(`  📄 第 ${p} 页...`);
    
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      
      const items = await page.evaluate(() => {
        const result = [];
        document.querySelectorAll('a[href*="/goodsInfo/"]').forEach(a => {
          const id = a.href.match(/goodsInfo\/(\d+)/)?.[1];
          const name = a.title || a.textContent?.trim();
          const parent = a.closest('.goods-list-item, .item, li, div');
          const priceEl = parent?.querySelector('.show_price, [class*=price]');
          const imgEl = parent?.querySelector('img') || a.querySelector('img');
          
          if (id && name && name.length > 3 && name.length < 100) {
            result.push({
              id,
              name: name.substring(0, 80),
              url: a.href,
              price: priceEl?.textContent?.replace(/[^\d.]/g, ''),
              image: imgEl?.src
            });
          }
        });
        return result;
      });
      
      if (items.length === 0) {
        console.log(`  ⚠️ 无产品，停止`);
        break;
      }
      
      products.push(...items);
      console.log(`  ✅ 找到 ${items.length} 个`);
      
      // 检查是否还有下一页
      const hasNext = await page.$('.next-page:not(.disabled), a:has-text("下一页"):not(.disabled)');
      if (!hasNext && p > 1) {
        console.log(`  📄 已到最后一页`);
        break;
      }
      
      await page.waitForTimeout(500);
    } catch (err) {
      console.log(`  ❌ 错误: ${err.message}`);
      break;
    }
  }
  
  // 去重
  const unique = [...new Map(products.map(p => [p.id, { ...p, categoryId: catId, categoryName: catName }])).values()];
  console.log(`  📊 ${catName}: ${unique.length} 个唯一产品`);
  return unique;
}

async function main() {
  console.log('🚀 启动浏览器...');
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const context = await browser.newContext();
  
  if (fs.existsSync(COOKIES_FILE)) {
    const cookies = JSON.parse(fs.readFileSync(COOKIES_FILE, 'utf-8'));
    await context.addCookies(cookies);
    console.log(`🍪 已加载 ${cookies.length} 个 cookies`);
  }
  
  const page = await context.newPage();
  const allProducts = [];
  
  // 从命令行参数或使用默认分类
  let categories = DEFAULT_CATEGORIES;
  if (process.argv.length > 2) {
    categories = process.argv.slice(2).map(id => ({ id, name: `分类${id}` }));
  }
  
  for (const cat of categories) {
    const products = await scrapeCategory(page, cat.id, cat.name);
    allProducts.push(...products);
  }
  
  // 最终去重
  const finalProducts = [...new Map(allProducts.map(p => [p.id, p])).values()];
  
  console.log(`\n📊 总计: ${finalProducts.length} 个唯一产品`);
  
  // 保存
  const timestamp = new Date().toISOString().slice(0, 10);
  const filename = path.join(DATA_DIR, `products-by-category-${timestamp}.json`);
  fs.writeFileSync(filename, JSON.stringify(finalProducts, null, 2));
  console.log(`💾 保存到 ${filename}`);
  
  await browser.close();
  console.log('🏁 完成');
  
  return { total: finalProducts.length, file: filename };
}

main().then(r => console.log('\n结果:', r));
