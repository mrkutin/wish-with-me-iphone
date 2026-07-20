// scripts/pwa-screenshot.js
// Captures PWA screenshots at iPhone 16 viewport for visual comparison with iOS app
//
// Usage: node scripts/pwa-screenshot.js <page> [output-path]
// Example: node scripts/pwa-screenshot.js login screenshots/pwa/login.png
//
// Prerequisites: npm install playwright (in this directory or globally)

const { chromium } = require('playwright');

const PAGES = {
  'login': '/login',
  'register': '/register',
  'wishlists': '/wishlists',
  'wishlist-detail': '/wishlists/__WISHLIST_ID__',
  'profile': '/profile',
  'settings': '/settings',
  'shared': '/s/__TOKEN__',
};

const BASE_URL = process.env.PWA_URL || 'https://wishwith.me';

// iPhone 16 dimensions
const VIEWPORT = { width: 390, height: 844 };
const DEVICE_SCALE_FACTOR = 3;

(async () => {
  const pageName = process.argv[2];
  const outputPath = process.argv[3] || `screenshots/pwa/${pageName}.png`;

  if (!pageName || !PAGES[pageName]) {
    console.error('Usage: node pwa-screenshot.js <page> [output-path]');
    console.error('Available pages:', Object.keys(PAGES).join(', '));
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
  const url = `${BASE_URL}${PAGES[pageName]}`;

  console.log(`Navigating to: ${url}`);
  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });

  // Wait extra 1s for animations to settle
  await page.waitForTimeout(1000);

  await page.screenshot({ path: outputPath, fullPage: false });
  console.log(`Screenshot saved: ${outputPath}`);

  await browser.close();
})();
