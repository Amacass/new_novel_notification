const SUPABASE_URL = 'https://zrxsapgvlflxitddeqcn.supabase.co';
const APP_BUNDLE_ID = 'com.amacass.novelNotification';

const SUPPORTED_PATTERNS = [
  /syosetu\.com/,
  /syosetu\.org/,
  /mai-net\.net/,
];

function isSupportedUrl(url) {
  return url && SUPPORTED_PATTERNS.some((p) => p.test(url));
}

async function showBadge(tabId, text, color) {
  try {
    await browser.action.setBadgeText({ text, tabId });
    await browser.action.setBadgeBackgroundColor({ color, tabId });
    setTimeout(async () => {
      try {
        await browser.action.setBadgeText({ text: '', tabId });
      } catch (_) { /* ignore */ }
    }, 2500);
  } catch (_) { /* ignore */ }
}

browser.action.onClicked.addListener(async (tab) => {
  const url = tab.url;

  if (!isSupportedUrl(url)) {
    await showBadge(tab.id, '?', '#FF9800');
    return;
  }

  // ネイティブ側（App Group）からアクセストークンを取得
  let token;
  try {
    const response = await browser.runtime.sendNativeMessage(APP_BUNDLE_ID, {
      action: 'getToken',
    });
    token = response?.token;
  } catch (e) {
    console.error('Native message error:', e);
  }

  if (!token) {
    // 未ログイン
    await showBadge(tab.id, '!', '#FF5722');
    return;
  }

  // Supabase に直接 API コール
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/register-bookmark`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ url }),
    });

    if (res.ok) {
      await showBadge(tab.id, '✓', '#4CAF50');
    } else {
      const body = await res.json().catch(() => ({}));
      console.error('Registration failed:', body);
      await showBadge(tab.id, '✗', '#F44336');
    }
  } catch (e) {
    console.error('Fetch error:', e);
    await showBadge(tab.id, '✗', '#F44336');
  }
});
