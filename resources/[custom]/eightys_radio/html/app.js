'use strict';

function res() { return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'eightys_radio'; }
function nui(cb, data) {
    fetch(`https://${res()}/${cb}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

// ── Lecteur audio HTML5 (fichiers MP3 locaux) ──
let audioPlayer = new Audio();
audioPlayer.loop   = true;
audioPlayer.volume = 0.8;

function playAudio(audioFile) {
    const url = `https://${res()}/audio/${audioFile}`;
    if (audioPlayer.src !== url) {
        audioPlayer.src = url;
    }
    audioPlayer.play().then(() => startVU()).catch(() => {});
}

function stopAudio() {
    audioPlayer.pause();
    audioPlayer.currentTime = 0;
    audioPlayer.src = '';
    stopVU();
}

audioPlayer.addEventListener('playing', startVU);
audioPlayer.addEventListener('pause',   stopVU);
audioPlayer.addEventListener('ended',   stopVU);

// ── État ──
let state = {
    cassettes : [],
    inserted  : null,
    playing   : false,
};

// ── VU-mètre animé ──
let vuInterval = null;
const vuBars   = document.querySelectorAll('.vu-bar');

function startVU() {
    if (vuInterval) return;
    vuInterval = setInterval(() => {
        vuBars.forEach(b => {
            const h = Math.floor(Math.random() * 20) + 2;
            b.style.height  = h + 'px';
            b.style.opacity = (h / 22).toFixed(2);
        });
    }, 100);
}

function stopVU() {
    clearInterval(vuInterval);
    vuInterval = null;
    vuBars.forEach(b => { b.style.height = '2px'; b.style.opacity = '0.15'; });
}

// ── Rendu lecteur ──
function renderDeck() {
    const tapeVis  = document.getElementById('tape-vis');
    const tapeName = document.getElementById('tape-name');
    const display  = document.getElementById('display-text');
    const tapeLabel = document.querySelector('.tape-label');

    if (state.inserted) {
        const c = state.inserted;
        tapeVis.classList.remove('empty');
        tapeVis.classList.toggle('playing', state.playing);
        tapeName.textContent  = c.label;
        tapeName.style.color  = c.color;
        tapeLabel.style.borderColor = c.color;
        tapeLabel.style.background  = 'rgba(0,0,0,0.6)';

        // Appliquer la couleur aux bobines
        document.querySelectorAll('.reel').forEach(r => {
            r.style.borderColor = state.playing ? c.color : '#555';
        });

        display.textContent = state.playing ? '▶ ' + c.label.toUpperCase().slice(0, 14) : c.label.toUpperCase().slice(0, 16);
        display.style.color = c.color;

        if (state.playing) startVU(); else stopVU();
    } else {
        tapeVis.classList.add('empty');
        tapeVis.classList.remove('playing');
        tapeName.textContent   = '— NO TAPE —';
        tapeName.style.color   = '#555';
        tapeLabel.style.borderColor = '#333';
        tapeLabel.style.background  = '#1a1a1a';
        document.querySelectorAll('.reel').forEach(r => r.style.borderColor = '#555');
        display.textContent = 'INSERT CASSETTE';
        display.style.color = '#FF7700';
        stopVU();
    }
}

// ── Rendu liste cassettes ──
function renderCassetteList() {
    const container = document.getElementById('cassette-items');
    if (!state.cassettes || state.cassettes.length === 0) {
        container.innerHTML = '<div class="no-cassettes">AUCUNE CASSETTE</div>';
        return;
    }

    container.innerHTML = '';
    state.cassettes.forEach(c => {
        const isActive = state.inserted && state.inserted.name === c.name;
        const div = document.createElement('div');
        div.className = 'cassette-item' + (isActive ? ' active' : '');
        div.style.setProperty('--cc', c.color);
        if (isActive) div.style.borderColor = c.color;

        div.innerHTML = `
            <div class="cassette-dot" style="background:${esc(c.color)}"></div>
            <div class="cassette-label">${esc(c.label)}</div>
            <div class="cassette-qty">×${c.qty}</div>
            ${isActive ? '<div class="cassette-playing-badge">▶ PLAY</div>' : ''}
        `;

        div.addEventListener('click', () => {
            if (isActive) {
                // Éjecter si déjà insérée
                nui('ejectCassette', {});
            } else {
                nui('insertCassette', { name: c.name });
            }
        });

        container.appendChild(div);
    });
}

function render() {
    renderDeck();
    renderCassetteList();
}

// ── Messages depuis le client Lua ──
window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'OPEN_DECK') {
        document.getElementById('deck').classList.remove('hidden');
    }

    if (d.type === 'CLOSE_DECK') {
        document.getElementById('deck').classList.add('hidden');
        stopAudio();
    }

    if (d.type === 'UPDATE_DECK') {
        state.cassettes = d.cassettes || [];
        state.inserted  = d.inserted  || null;
        state.playing   = d.playing   || false;

        if (state.inserted && state.inserted.audioFile && state.playing) {
            playAudio(state.inserted.audioFile);
        } else {
            stopAudio();
        }

        render();
    }
});

// ── Fermer avec Escape ──
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') nui('closeDeck', {});
});

function esc(s) {
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
