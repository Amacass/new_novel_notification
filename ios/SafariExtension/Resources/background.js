browser.runtime.onMessage.addListener(async (request) => {
    if (request.action !== 'register') return;

    try {
        await browser.runtime.sendNativeMessage(
            'application.com.amacass.novelNotification',
            { action: 'register', url: request.url }
        );
    } catch (e) {
        console.error('[bg] native messaging failed:', e);
        throw e;
    }
});
