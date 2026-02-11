// scripts/pwa-screenshot-auth.js
// Captures authenticated PWA screenshots for visual comparison with iOS app
//
// Usage: node scripts/pwa-screenshot-auth.js <page> [output-path]
// Example: node scripts/pwa-screenshot-auth.js wishlist-detail screenshots/pwa/wishlist-detail.png

const { chromium } = require('playwright');

const BASE_URL = process.env.PWA_URL || 'https://wishwith.me';
const TEST_EMAIL = 'test@test.ru';
const TEST_PASSWORD = '1qaz!QAZ';

// iPhone 16 dimensions
const VIEWPORT = { width: 390, height: 844 };
const DEVICE_SCALE_FACTOR = 3;

async function login(page) {
  console.log('Logging in...');
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' });

  await page.fill('input[type="email"]', TEST_EMAIL);
  await page.fill('input[type="password"]', TEST_PASSWORD);
  await page.click('button:has-text("Sign In")');

  // Wait for navigation to complete
  await page.waitForURL(/wishlists/, { timeout: 10000 });
  console.log('Logged in successfully');
}

async function captureWishlistDetail(page, outputPath) {
  // Get the first wishlist from the list
  await page.goto(`${BASE_URL}/wishlists`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);

  // Click on the first wishlist
  const firstWishlist = await page.locator('[class*="wishlist"], [data-testid*="wishlist"], a[href*="/wishlists/"]').first();
  if (await firstWishlist.count() > 0) {
    await firstWishlist.click();
    await page.waitForTimeout(2000);
  } else {
    console.log('No wishlists found, staying on wishlists page');
  }

  await page.screenshot({ path: outputPath, fullPage: false });
  console.log(`Screenshot saved: ${outputPath}`);
}

async function captureWishlists(page, outputPath) {
  await page.goto(`${BASE_URL}/wishlists`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  await page.screenshot({ path: outputPath, fullPage: false });
  console.log(`Screenshot saved: ${outputPath}`);
}

(async () => {
  const pageName = process.argv[2];
  const outputPath = process.argv[3] || `screenshots/pwa/${pageName}.png`;

  if (!pageName) {
    console.error('Usage: node pwa-screenshot-auth.js <page> [output-path]');
    console.error('Available pages: wishlists, wishlist-detail');
    process.exit(1);
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: DEVICE_SCALE_FACTOR,
    isMobile: true,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
  });

  const page = await context.newPage();

  try {
    await login(page);

    if (pageName === 'wishlist-detail') {
      await captureWishlistDetail(page, outputPath);
    } else if (pageName === 'wishlists') {
      await captureWishlists(page, outputPath);
    } else {
      console.error(`Unknown page: ${pageName}`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: outputPath.replace('.png', '-error.png') });
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
