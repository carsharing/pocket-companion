const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: Number(process.argv[4] || 1000), height: 400 }, deviceScaleFactor: 1 });
  await p.goto('file://' + process.argv[2]);
  await p.screenshot({ path: process.argv[3], fullPage: true });
  await b.close();
})();
