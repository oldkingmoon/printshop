#!/usr/bin/env node
/**
 * 礼品定制平台登录脚本
 * 用法: node lipindz-login.js <手机号> <验证码>
 */

const { chromium } = require('playwright');

const phone = process.argv[2] || '18217244555';
const code = process.argv[3];

async function login() {
  console.log('🚀 启动浏览器...');
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    console.log('📄 打开登录页...');
    await page.goto('https://lipindz.miniappss.com/', { waitUntil: 'networkidle' });
    
    // 查找登录入口
    console.log('🔍 查找登录入口...');
    const loginBtn = await page.$('text=登录') || await page.$('a[href*="login"]');
    if (loginBtn) {
      await loginBtn.click();
      await page.waitForTimeout(2000);
    }
    
    // 切换到手机验证码登录
    const phoneTab = await page.$('text=手机验证码登录') || await page.$('text=验证码登录');
    if (phoneTab) {
      console.log('📱 切换到手机验证码登录...');
      await phoneTab.click();
      await page.waitForTimeout(1000);
    }
    
    // 输入手机号
    console.log(`📞 输入手机号: ${phone}`);
    const phoneInput = await page.$('input[type="tel"]') || await page.$('input[placeholder*="手机"]');
    if (phoneInput) {
      await phoneInput.fill(phone);
    }
    
    if (!code) {
      // 点击获取验证码
      console.log('📨 点击获取验证码...');
      const getCodeBtn = await page.$('text=获取验证码') || await page.$('button:has-text("验证码")');
      if (getCodeBtn) {
        await getCodeBtn.click();
        console.log('✅ 验证码已发送，等待用户提供验证码...');
        console.log('用法: node lipindz-login.js 18217244555 <验证码>');
      }
      
      // 截图当前状态
      await page.screenshot({ path: '/tmp/lipindz-login-step1.png' });
      console.log('📸 截图保存到 /tmp/lipindz-login-step1.png');
      
    } else {
      // 输入验证码并登录
      console.log(`🔑 输入验证码: ${code}`);
      const codeInput = await page.$('input[placeholder*="验证码"]') || await page.$('input[type="number"]');
      if (codeInput) {
        await codeInput.fill(code);
      }
      
      // 点击登录
      const submitBtn = await page.$('button[type="submit"]') || await page.$('text=登录');
      if (submitBtn) {
        await submitBtn.click();
        await page.waitForTimeout(3000);
      }
      
      // 检查是否登录成功
      const cookies = await context.cookies();
      console.log(`🍪 Cookies: ${cookies.length} 个`);
      
      // 保存 cookies
      const fs = require('fs');
      fs.writeFileSync('/tmp/lipindz-cookies.json', JSON.stringify(cookies, null, 2));
      console.log('💾 Cookies 保存到 /tmp/lipindz-cookies.json');
      
      // 截图
      await page.screenshot({ path: '/tmp/lipindz-login-success.png' });
      console.log('📸 截图保存到 /tmp/lipindz-login-success.png');
      
      // 获取页面标题
      const title = await page.title();
      console.log(`📄 页面标题: ${title}`);
    }
    
  } catch (err) {
    console.error('❌ 错误:', err.message);
    await page.screenshot({ path: '/tmp/lipindz-error.png' });
  } finally {
    await browser.close();
    console.log('🏁 完成');
  }
}

login();
