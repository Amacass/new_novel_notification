const SUPPORTED = /ncode\.syosetu\.com|syosetu\.org|mai-net\.net/;

async function run() {
    const el = document.getElementById('msg');

    try {
        const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
        const url = tab?.url ?? '';

        if (!SUPPORTED.test(url)) {
            show(el, 'このサイトは対応していません', false);
            return;
        }

        await browser.runtime.sendMessage({ action: 'register', url, tabId: tab.id });
        show(el, 'Novelmarkに登録しました', true);
    } catch (e) {
        show(el, '登録に失敗しました', false);
    }
}

function show(el, text, success) {
    el.textContent = text;
    el.className = 'msg ' + (success ? 'success' : 'error');

    setTimeout(() => {
        el.classList.add('fade');
        setTimeout(() => window.close(), 350);
    }, 1800);
}

run();
