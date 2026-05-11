'use strict';

function getRes() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ox_lib';
}
function nui(cb, data) {
    fetch(`https://${getRes()}/${cb}`, {
        method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data||{})
    }).catch(()=>{});
}

/* ============================================================
   NOTIFICATIONS
   ============================================================ */
function notify(data) {
    const c = document.getElementById('notify-container');
    const el = document.createElement('div');
    el.className = `notify-item ${data.style||'inform'}`;
    el.innerHTML = `<div class="notify-title">${esc(data.title||'')}</div><div class="notify-msg">${esc(data.message||'')}</div>`;
    c.appendChild(el);
    const dur = data.duration || 4000;
    setTimeout(()=>{ el.style.animation='slideOut 0.3s ease forwards'; setTimeout(()=>el.remove(), 300); }, dur);
}

/* ============================================================
   PROGRESS BAR
   ============================================================ */
let progressTimer = null;
function progressStart(data) {
    const wrapper = document.getElementById('progress-wrapper');
    const fill    = document.getElementById('progress-fill');
    const label   = document.getElementById('progress-label');
    wrapper.classList.remove('hidden');
    label.textContent = data.label || '';
    fill.style.transition = `width ${data.duration}ms linear`;
    fill.style.width = '0%';
    requestAnimationFrame(()=>{ fill.style.width = '100%'; });
    progressTimer = setTimeout(()=>progressStop(), data.duration);
}
function progressStop() {
    clearTimeout(progressTimer);
    document.getElementById('progress-wrapper').classList.add('hidden');
    document.getElementById('progress-fill').style.width = '0%';
}

/* ============================================================
   CONTEXT MENU
   ============================================================ */
let currentCtx = null;
function openContext(ctx) {
    currentCtx = ctx;
    document.getElementById('context-title').textContent = ctx.title || '';
    const opts = document.getElementById('context-options');
    opts.innerHTML = '';
    (ctx.options||[]).forEach((opt, i) => {
        const div = document.createElement('div');
        div.className = 'context-option' + (opt.disabled?' disabled':'');
        div.innerHTML = `<div><div class="ctx-title">${esc(opt.title||'')}</div>${opt.description?`<div class="ctx-desc">${esc(opt.description)}</div>`:''}</div>`;
        if (!opt.disabled) div.onclick = ()=>{ nui('contextSelect',{index:i+1}); };
        opts.appendChild(div);
    });
    document.getElementById('context-overlay').classList.remove('hidden');
}
function closeContext() {
    document.getElementById('context-overlay').classList.add('hidden');
    nui('contextClose', {});
    currentCtx = null;
}

/* ============================================================
   INPUT DIALOG
   ============================================================ */
let inputFields = [];
function openInput(title, fields) {
    inputFields = fields || [];
    document.getElementById('input-title').textContent = title || '';
    const container = document.getElementById('input-fields');
    container.innerHTML = '';
    fields.forEach((f, i) => {
        const wrap = document.createElement('div');
        wrap.className = 'input-field-wrap';
        const type = f.type === 'number' ? 'number' : 'text';
        wrap.innerHTML = `<div class="input-field-label">${esc(f.label||'')}</div>
            <input class="input-field-el" id="input-field-${i}" type="${type}"
            placeholder="${esc(f.placeholder||f.label||'')}"
            ${f.maxLength?`maxlength="${f.maxLength}"`:''}
            ${f.min!==undefined?`min="${f.min}"`:''}
            ${f.max!==undefined?`max="${f.max}"`:''}
            value="${f.default!==undefined?esc(String(f.default)):''}">`;
        container.appendChild(wrap);
    });
    document.getElementById('input-overlay').classList.remove('hidden');
    const first = document.querySelector('.input-field-el');
    if (first) setTimeout(()=>first.focus(), 50);
}
function submitInput() {
    const values = inputFields.map((f, i) => {
        const el = document.getElementById(`input-field-${i}`);
        if (!el) return null;
        return f.type === 'number' ? (parseFloat(el.value) || null) : el.value;
    });
    document.getElementById('input-overlay').classList.add('hidden');
    nui('inputSubmit', { values });
}
function cancelInput() {
    document.getElementById('input-overlay').classList.add('hidden');
    nui('inputCancel', {});
}

/* ============================================================
   ALERT DIALOG
   ============================================================ */
function openAlert(data) {
    document.getElementById('alert-header').textContent = data.header || '';
    document.getElementById('alert-content').textContent = data.content || '';
    const cancelBtn = document.getElementById('btn-alert-cancel');
    cancelBtn.style.display = data.cancel !== false ? '' : 'none';
    document.getElementById('alert-overlay').classList.remove('hidden');
}
function confirmAlert() { document.getElementById('alert-overlay').classList.add('hidden'); nui('alertConfirm',{}); }
function cancelAlert()  { document.getElementById('alert-overlay').classList.add('hidden'); nui('alertCancel',{}); }

/* ============================================================
   KEYBOARD
   ============================================================ */
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
        if (!document.getElementById('context-overlay').classList.contains('hidden')) closeContext();
        else if (!document.getElementById('input-overlay').classList.contains('hidden')) cancelInput();
        else if (!document.getElementById('alert-overlay').classList.contains('hidden')) cancelAlert();
    }
    if (e.key === 'Enter') {
        if (!document.getElementById('input-overlay').classList.contains('hidden')) submitInput();
        else if (!document.getElementById('alert-overlay').classList.contains('hidden')) confirmAlert();
    }
});

/* ============================================================
   MESSAGES FIVEM
   ============================================================ */
window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;
    switch(d.type) {
        case 'NOTIFY':        notify(d);                         break;
        case 'PROGRESS_START':progressStart(d);                  break;
        case 'PROGRESS_STOP': progressStop();                    break;
        case 'CONTEXT_OPEN':  openContext(d.context);            break;
        case 'CONTEXT_CLOSE': closeContext();                    break;
        case 'INPUT_OPEN':    openInput(d.title, d.fields);      break;
        case 'ALERT_OPEN':    openAlert(d);                      break;
    }
});

function esc(s) {
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
