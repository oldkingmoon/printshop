#!/usr/bin/env node
/**
 * 礼品定制平台产品数据抓取脚本
 * 用法: node lipindz-scraper.js [maxPages]
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const MAX_PAGES = parseInt(process.argv[2]) || 10;
const DATA_DIR = path.join(__dirname, '..', 'data');
const COOKIES_FILE = '/tmp/lipindz-cookies.json';

async function scrape() {
  console.log('🚀 启动浏览器...');
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const context = await browser.newContext();
  
  // 加载 cookies
  if (fs.existsSync(COOKIES_FILE)) {
    const cookies = JSON.parse(fs.readFileSync(COOKIES_FILE, 'utf-8'));
    await context.addCookies(cookies);
    console.log(`🍪 已加载 ${cookies.length} 个 cookies`);
  }
  
  const page = await context.newPage();
  const allProducts = [];
  const categories = [];
  
  try {
    // 1. 先抓分类
    console.log('📂 抓取分类...');
    await page.goto('https://lipindz.miniappss.com/', { waitUntil: 'networkidle' });
    
    const categoryLinks = await page.$$eval('a[href*="/list/classify_id/"]', links => 
      links.map(a => ({
        name: a.textContent.trim(),
        url: a.href,
        id: a.href.match(/classify_id\/(\d+)/)?.[1]
      })).filter(c => c.name && c.id)
    );
    
    // 去重
    const uniqueCategories = [...new Map(categoryLinks.map(c => [c.id, c])).values()];
    categories.push(...uniqueCategories);
    console.log(`📂 找到 ${categories.length} 个分类`);
    
    // 2. 抓取产品列表
    console.log(`📦 开始抓取产品（最多 ${MAX_PAGES} 页）...`);
    
    for (let pageNum = 1; pageNum <= MAX_PAGES; pageNum++) {
      const listUrl = `https://lipindz.miniappss.com/list/classify_id/1000.html?page=${pageNum}`;
      console.log(`  📄 第 ${pageNum} 页...`);
      
      await page.goto(listUrl, { waitUntil: 'networkidle', timeout: 30000 });
      
      // 提取产品
      const products = await page.$$eval('.goods-item, .product-item, [class*="goods"]', items => {
        return items.map(item => {
          const link = item.querySelector('a[href*="/goodsInfo/"]');
          const img = item.querySelector('img');
          const priceEl = item.querySelector('[class*="price"], .show_price');
          const nameEl = item.querySelector('[class*="name"], [class*="title"], h3, h4');
          
          return {
            id: link?.href?.match(/goodsInfo\/(\d+)/)?.[1],
            name: nameEl?.textContent?.trim() || link?.title,
            url: link?.href,
            image: img?.src,
            price: priceEl?.textContent?.replace(/[^\d.]/g, '')
          };
        }).filter(p => p.id && p.name);
      });
      
      if (products.length === 0) {
        console.log(`  ⚠️ 第 ${pageNum} 页无产品，尝试其他选择器...`);
        
        // 备用方案：直接找所有商品链接
        const altProducts = await page.$$eval('a[href*="/goodsInfo/"]', links => {
          return links.map(a => ({
            id: a.href.match(/goodsInfo\/(\d+)/)?.[1],
            name: a.title || a.textContent?.trim(),
            url: a.href
          })).filter(p => p.id && p.name && p.name.length > 2);
        });
        
        // 去重
        const uniqueAlt = [...new Map(altProducts.map(p => [p.id, p])).values()];
        allProducts.push(...uniqueAlt);
        console.log(`  ✅ 备用方案找到 ${uniqueAlt.length} 个产品`);
      } else {
        allProducts.push(...products);
        console.log(`  ✅ 找到 ${products.length} 个产品`);
      }
      
      // 检查是否还有下一页
      const hasNext = await page.$('a:has-text("下一页"), .next-page, [class*="next"]');
      if (!hasNext && pageNum > 1) {
        console.log('  📄 已到最后一页');
        break;
      }
      
      await page.waitForTimeout(1000); // 礼貌延迟
    }
    
    // 3. 去重
    const uniqueProducts = [...new Map(allProducts.map(p => [p.id, p])).values()];
    console.log(`\n📊 总计: ${uniqueProducts.length} 个唯一产品`);
    
    // 4. 保存数据
    const timestamp = new Date().toISOString().slice(0, 10);
    
    // 保存分类
    const categoriesFile = path.join(DATA_DIR, `categories-${timestamp}.json`);
    fs.writeFileSync(categoriesFile, JSON.stringify(categories, null, 2));
    console.log(`💾 分类保存到 ${categoriesFile}`);
    
    // 保存产品
    const productsFile = path.join(DATA_DIR, `products-${timestamp}.json`);
    fs.writeFileSync(productsFile, JSON.stringify(uniqueProducts, null, 2));
    console.log(`💾 产品保存到 ${productsFile}`);
    
    // 保存汇总
    const summary = {
      scrapeTime: new Date().toISOString(),
      totalCategories: categories.length,
      totalProducts: uniqueProducts.length,
      pagesScraped: MAX_PAGES,
      files: {
        categories: categoriesFile,
        products: productsFile
      }
    };
    fs.writeFileSync(path.join(DATA_DIR, 'summary.json'), JSON.stringify(summary, null, 2));
    
    return summary;
    
  } catch (err) {
    console.error('❌ 错误:', err.message);
    await page.screenshot({ path: '/tmp/lipindz-scraper-error.png' });
  } finally {
    await browser.close();
    console.log('🏁 完成');
  }
}

scrape().then(summary => {
  if (summary) {
    console.log('\n📋 汇总:');
    console.log(`  - 分类: ${summary.totalCategories} 个`);
    console.log(`  - 产品: ${summary.totalProducts} 个`);
  }
});
