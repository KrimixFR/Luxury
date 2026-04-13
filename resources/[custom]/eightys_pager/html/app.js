/* ================================================================
   LOS SANTOS 1987 — Pager App.js
   Interface du biper Motorola Advisor
   ================================================================ */

'use strict';

let messages = [];
let composing = false;

// ================================================================
// UTILITAIRES
// ================================================================

function getResourceName() {
    return typeof window.GetParentResourceName === 'function'
        ? window.GetParentResourceName()
        : 'eightys_pager';
}

function fetchNUI(endpoint, data) {
    return fetch(`https://${getResourceName()}/${endpoint}`, {
        method  : 'POST',
        headers : { 'Content-Type': 'application/json' },
        body    : JSON.stringify(data || {}),
    }).catch(() => {});
}

function updateClock() {
    const now = new Date();
    const h   = String(now.getHours()).padStart(2, '0');
    const m   = String(now.getMinutes()).padStart(2, '0');
    const el  = document.getElementById('pager-time');
    if (el) el.textContent = `${h}:${m}`;
}

// ================================================================
// MESSAGES
// ================================================================

function renderMessages(msgs) {
    const list = document.getElementById('message-list');
    if (!list) return;

    if (!msgs || msgs.length === 0) {
        list.innerHTML = '<div class="no-messages">Aucun message.</div>';
        return;
    }

    list.innerHTML = '';
    msgs.forEach((msg, idx) => {
        const item = document.createElement('div');
        item.className = 'message-item';
        item.innerHTML = `
            <div class="msg-header">
                <span class="msg-from">${escapeHtml(msg.from || 'Inconnu')}</span>
                <span class="msg-time">${escapeHtml(String(msg.time || ''))}</span>
            </div>
            <div class="msg-text">${escapeHtml(msg.text || '')}</div>
            <button class="msg-delete" onclick="deleteMessage(${idx})">✕</button>
        `;
        list.appendChild(item);
    });
}

function deleteMessage(index) {
    fetchNUI('deleteMessage', { index: index + 1 }); // Lua 1-indexed
    messages.splice(index, 1);
    renderMessages(messages);
}

function clearAll() {
    messages = [];
    renderMessages(messages);
    document.getElementById('message-list').innerHTML =
        '<div class="no-messages">Aucun message.</div>';
}

function escapeHtml(text) {
    return String(text)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// ================================================================
// OUVRIR / FERMER
// ================================================================

function openPager() {
    const overlay = document.getElementById('pager-overlay');
    if (overlay) overlay.classList.remove('hidden');
    updateClock();
}

function closePager() {
    const overlay = document.getElementById('pager-overlay');
    if (overlay) overlay.classList.add('hidden');
    cancelCompose();
    fetchNUI('closePager', {});
}

// ================================================================
// COMPOSITION
// ================================================================

function composePager() {
    composing = true;
    document.getElementById('compose-panel').classList.remove('hidden');
    document.getElementById('input-dest').focus();
}

function cancelCompose() {
    composing = false;
    const panel = document.getElementById('compose-panel');
    if (panel) panel.classList.add('hidden');
    const dest = document.getElementById('input-dest');
    const msg  = document.getElementById('input-msg');
    if (dest) dest.value = '';
    if (msg)  msg.value  = '';
}

function sendFromUI() {
    const destEl = document.getElementById('input-dest');
    const msgEl  = document.getElementById('input-msg');

    const targetId = parseInt(destEl.value);
    const message  = (msgEl.value || '').trim();

    if (!targetId || targetId < 1) {
        destEl.style.borderColor = '#FF0033';
        setTimeout(() => destEl.style.borderColor = '', 1000);
        return;
    }

    if (!message) {
        msgEl.style.borderColor = '#FF0033';
        setTimeout(() => msgEl.style.borderColor = '', 1000);
        return;
    }

    fetchNUI('sendMessage', { targetId, message });
    cancelCompose();
}

// ================================================================
// ENTRÉE CLAVIER
// ================================================================

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closePager();
    }
    if (e.key === 'Enter' && composing) {
        sendFromUI();
    }
});

// ================================================================
// MESSAGES FIVEM
// ================================================================

window.addEventListener('message', function(event) {
    const msg = event.data;
    if (!msg || !msg.type) return;

    switch (msg.type) {
        case 'OPEN_PAGER':
        case 'INIT':
            messages = msg.messages || [];
            renderMessages(messages);
            openPager();
            break;

        case 'CLOSE_PAGER':
            closePager();
            break;

        case 'UPDATE_MESSAGES':
            messages = msg.messages || [];
            renderMessages(messages);
            break;
    }
});

// ================================================================
// INIT
// ================================================================

document.addEventListener('DOMContentLoaded', function() {
    updateClock();
    setInterval(updateClock, 30000);

    // Signaler que le NUI est prêt
    fetchNUI('pagerReady', {});
});
