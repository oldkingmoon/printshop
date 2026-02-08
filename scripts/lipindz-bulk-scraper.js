#!/usr/bin/env node
/**
 * 批量抓取全部商品
 * 用法: node lipindz-bulk-scraper.js [maxPages]
 */

const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const MAX_PAGES = parseInt(process.argv[2]) || 500;
const DATA_DIR = path.join(__dirname, "..", "data");
const COOKIES_FILE = "/tmp/lipindz-cookies.json";

async function main() {
  console.log("🚀 启动浏览器...");
  const browser = await chromium.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"]
  });
  
  const context = await browser.newContext();
  
  if (fs.existsSync(COOKIES_FILE)) {
    const cookies = JSON.parse(fs.readFileSync(COOKIES_FILE, "utf-8"));
    await context.addCookies(cookies);
    console.log(`🍪 已加载 ${cookies.length} 个 cookies`);
  }
  
  const page = await context.newPage();
  const allProducts = new Map();
  let emptyPages = 0;
  
  console.log(`📦 开始抓取全部商品（最多 ${MAX_PAGES} 页）...\n`);
  
  for (let p = 1; p <= MAX_PAGES; p++) {
    const url = `https://lipindz.miniappss.com/list?page=${p}`;
    
    try {
      await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
      
      const products = await page.evaluate(() => {
        const items = [];
        document.querySelectorAll("a[href*=goodsInfo]").forEach(a => {
          const id = a.href.match(/goodsInfo\/(\d+)/)?.[1];
          const name = a.title || a.textContent?.trim();
          const parent = a.closest("li, div, .item, .goods");
          const priceEl = parent?.querySelector(".show_price, [class*=price]");
          const imgEl = a.querySelector("img") || parent?.querySelector("img");
          
          if (id && name && name.length > 3 && name.length < 100) {
            items.push({
              id,
              name: name.substring(0, 80),
              url: a.href,
              price: priceEl?.textContent?.replace(/[^\d.]/g, ""),
              image: imgEl?.src
            });
          }
        });
        return items;
      });
      
      // 去重并添加
      let newCount = 0;
      products.forEach(prod => {
        if (!allProducts.has(prod.id)) {
          allProducts.set(prod.id, prod);
          newCount++;
        }
      });
      
      if (p % 10 === 0 || newCount > 0) {
        console.log(`📄 第 ${p} 页: 找到 ${products.length} 个, 新增 ${newCount} 个, 累计 ${allProducts.size} 个`);
      }
      
      // 如果连续 5 页没有新产品，停止
      if (newCount === 0) {
        emptyPages++;
        if (emptyPages >= 5) {
          console.log(`\n⚠️ 连续 ${emptyPages} 页无新产品，停止抓取`);
          break;
        }
      } else {
        emptyPages = 0;
      }
      
      await page.waitForTimeout(300); // 礼貌延迟
      
    } catch (err) {
      console.log(`❌ 第 ${p} 页错误: ${err.message}`);
    }
  }
  
  // 保存结果
  const products = Array.from(allProducts.values());
  console.log(`\n📊 总计: ${products.length} 个唯一产品`);
  
  const timestamp = new Date().toISOString().slice(0, 10);
  const filename = path.join(DATA_DIR, `products-bulk-${timestamp}.json`);
  fs.writeFileSync(filename, JSON.stringify(products, null, 2));
  console.log(`💾 保存到 ${filename}`);
  
  await browser.close();
  console.log("🏁 完成");
  
  return { total: products.length, file: filename };
}

main().then(r => console.log("\n结果:", r)).catch(console.error);
