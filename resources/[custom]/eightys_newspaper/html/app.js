'use strict';

const TYPE_LABELS = {
    death:    'Faits Divers',
    arrest:   'Chronique Judiciaire',
    drugbust: 'Sécurité Publique',
    robbery:  'Faits Divers',
    generic:  'Actualités Locales',
};

window.addEventListener('message', (e) => {
    if (e.data.type === 'OPEN_PAPER') showPaper(e.data.data);
    if (e.data.type === 'CLOSE')      hidePaper();
});

function showPaper(data) {
    document.getElementById('paper-edition').textContent = 'N° ' + (data.number || 1);
    document.getElementById('paper-date').textContent    = data.date || '1987';

    const container = document.getElementById('articles-container');
    container.innerHTML = '';

    const articles = data.articles || [];
    articles.forEach((article, idx) => {
        const div = document.createElement('div');
        div.className = idx === 0 ? 'article article-featured' : 'article';

        const typeLabel = TYPE_LABELS[article.event_type] || TYPE_LABELS.generic;

        div.innerHTML = `
            <div class="article-type">${typeLabel}</div>
            <div class="article-headline">${esc(article.headline)}</div>
            <div class="article-body">${esc(article.body)}</div>
            ${article.location ? `<div class="article-location">— ${esc(article.location)}</div>` : ''}
        `;
        container.appendChild(div);
    });

    document.getElementById('overlay').classList.remove('hidden');
}

function hidePaper() {
    document.getElementById('overlay').classList.add('hidden');
}

function esc(str) {
    if (!str) return '';
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

document.getElementById('btn-close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

function close() {
    hidePaper();
    fetch('https://eightys_newspaper/close', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
}
