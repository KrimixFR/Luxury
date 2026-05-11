'use strict';

function res() { return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'eightys_radio'; }
function nui(cb, data) {
    fetch(`https://${res()}/${cb}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

// ── Lecteur audio local (cassette insérée par ce joueur) ──
const audioPlayer = new Audio();
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

// ── Lecteur ambiant (cassette d'un joueur proche) ──
const ambientPlayer = new Audio();
ambientPlayer.loop   = true;
ambientPlayer.volume = 0;

function playAmbient(audioFile, volume) {
    const url = `https://${res()}/audio/${audioFile}`;
    ambientPlayer.volume = Math.max(0, Math.min(1, volume));
    if (ambientPlayer.src !== url) {
        ambientPlayer.src = url;
        ambientPlayer.play().catch(() => {});
    } else if (ambientPlayer.paused) {
        ambientPlayer.play().catch(() => {});
    }
}

function stopAmbient() {
    if (!ambientPlayer.paused) {
        ambientPlayer.pause();
        ambientPlayer.currentTime = 0;
        ambientPlayer.src = '';
    }
}

// ── État ──
let state = {
    cassettes : [],
    inserted  : null,
    playing   : false,
    volume    : 0.8,
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

// ── Slider de volume ──
const volSlider = document.getElementById('vol-slider');
const volValue  = document.getElementById('vol-value');

volSlider.addEventListener('input', () => {
    const v = parseInt(volSlider.value, 10);
    volValue.textContent = v;
    audioPlayer.volume = v / 100;
});

// Envoyer au Lua uniquement au relâchement (évite le spam réseau)
volSlider.addEventListener('change', () => {
    const v = parseInt(volSlider.value, 10);
    nui('setVolume', { volume: v / 100 });
});

// ── Rendu lecteur ──
function renderDeck() {
    const tapeVis   = document.getElementById('tape-vis');
    const tapeName  = document.getElementById('tape-name');
    const display   = document.getElementById('display-text');
    const tapeLabel = document.querySelector('.tape-label');

    if (state.inserted) {
        const c = state.inserted;
        tapeVis.classList.remove('empty');
        tapeVis.classList.toggle('playing', state.playing);
        tapeName.textContent        = c.label;
        tapeName.style.color        = c.color;
        tapeLabel.style.borderColor = c.color;
        tapeLabel.style.background  = 'rgba(0,0,0,0.6)';

        document.querySelectorAll('.reel').forEach(r => {
            r.style.borderColor = state.playing ? c.color : '#555';
        });

        display.textContent = state.playing ? '▶ ' + c.label.toUpperCase().slice(0, 14) : c.label.toUpperCase().slice(0, 16);
        display.style.color = c.color;

        // Activer le slider
        volSlider.disabled = false;
        volSlider.style.opacity = '1';

        if (state.playing) startVU(); else stopVU();
    } else {
        tapeVis.classList.add('empty');
        tapeVis.classList.remove('playing');
        tapeName.textContent        = '— NO TAPE —';
        tapeName.style.color        = '#555';
        tapeLabel.style.borderColor = '#333';
        tapeLabel.style.background  = '#1a1a1a';
        document.querySelectorAll('.reel').forEach(r => r.style.borderColor = '#555');
        display.textContent = 'INSERT CASSETTE';
        display.style.color = '#FF7700';

        // Griser le slider
        volSlider.disabled = true;
        volSlider.style.opacity = '0.3';

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
        state.volume    = d.volume    != null ? d.volume : state.volume;

        // Synchroniser le slider avec le volume côté Lua
        const pct = Math.round(state.volume * 100);
        volSlider.value      = pct;
        volValue.textContent = pct;
        audioPlayer.volume   = state.volume;

        if (state.inserted && state.inserted.audioFile && state.playing) {
            playAudio(state.inserted.audioFile);
        } else {
            stopAudio();
        }

        render();
    }

    // Volume local uniquement (sans re-render complet)
    if (d.type === 'SET_VOLUME') {
        audioPlayer.volume = d.volume;
    }

    // Son ambiant (voiture proche)
    if (d.type === 'AMBIENT_PLAY') {
        playAmbient(d.audioFile, d.volume);
    }

    if (d.type === 'AMBIENT_STOP') {
        stopAmbient();
    }
});

// ── Fermer avec Escape ──
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') nui('closeDeck', {});
});

function esc(s) {
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
