// scripts/pwa-screenshot-authenticated.js
// Captures PWA screenshots with authentication for visual comparison with iOS app
//
// Usage: node scripts/pwa-screenshot-authenticated.js <page> <wishlist-name> [output-path]
// Example: node scripts/pwa-screenshot-authenticated.js wishlist-items "Manual" screenshots/pwa/items_list.png

const { chromium } = require('playwright');

const BASE_URL = process.env.PWA_URL || 'https://wishwith.me';

// iPhone 16 dimensions
const VIEWPORT = { width: 390, height: 844 };
const DEVICE_SCALE_FACTOR = 3;

// Test credentials
const TEST_EMAIL = 'test@test.ru';
const TEST_PASSWORD = '1qaz!QAZ';

(async () => {
  const pageName = process.argv[2];
  const wishlistName = process.argv[3];
  const outputPath = process.argv[4] || `screenshots/pwa/${pageName}.png`;

  if (!pageName) {
    console.error('Usage: node pwa-screenshot-authenticated.js <page> <wishlist-name> [output-path]');
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
    // Step 1: Navigate to login page
    console.log('Navigating to login page...');
    await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(1000);

    // Step 2: Login
    console.log('Logging in...');
    await page.fill('input[type="email"]', TEST_EMAIL);
    await page.fill('input[type="password"]', TEST_PASSWORD);
    await page.click('button[type="submit"]');

    // Wait for navigation to wishlists page
    await page.waitForURL('**/wishlists', { timeout: 10000 });
    console.log('Login successful');
    await page.waitForTimeout(2000);

    // Step 3: Find and click the specified wishlist
    if (wishlistName) {
      console.log(`Looking for wishlist: ${wishlistName}`);

      // Wait for wishlists to load
      await page.waitForSelector('.q-card, [class*="wishlist"]', { timeout: 10000 });

      // Try to find and click the wishlist by name
      const wishlistCard = await page.locator(`text="${wishlistName}"`).first();
      if (await wishlistCard.isVisible()) {
        console.log(`Found wishlist "${wishlistName}", clicking...`);
        await wishlistCard.click();
        await page.waitForTimeout(2000);
      } else {
        console.error(`Wishlist "${wishlistName}" not found`);
      }
    }

    // Step 4: Take screenshot
    console.log(`Taking screenshot...`);
    await page.waitForTimeout(1000);
    await page.screenshot({ path: outputPath, fullPage: false });
    console.log(`Screenshot saved: ${outputPath}`);

  } catch (error) {
    console.error('Error:', error.message);
    // Take error screenshot for debugging
    await page.screenshot({ path: `${outputPath}.error.png`, fullPage: true });
    console.log(`Error screenshot saved: ${outputPath}.error.png`);
  } finally {
    await browser.close();
  }
})();
