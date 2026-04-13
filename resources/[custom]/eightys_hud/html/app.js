/* ================================================================
   LOS SANTOS 1987 — HUD App.js
   Gestion du HUD rétro côté NUI
   ================================================================ */

'use strict';

// Config par défaut (surchargée par SET_CONFIG depuis Lua)
let hudConfig = {
    PrimaryColor  : '#FF7700',
    SecondaryColor: '#00FFFF',
    DangerColor   : '#FF0033',
    SpeedUnit     : 'MPH',
    ScanlineEffect: true,
};

// Éléments DOM
const dom = {
    container : document.getElementById('hud-container'),
    barHealth  : document.getElementById('bar-health'),
    barArmor   : document.getElementById('bar-armor'),
    valHealth  : document.getElementById('val-health'),
    valArmor   : document.getElementById('val-armor'),
    valCash    : document.getElementById('val-cash'),
    valJob     : document.getElementById('val-job'),
    valSpeed   : document.getElementById('val-speed'),
    valStreet  : document.getElementById('val-street'),
    speedometer: document.getElementById('speedometer'),
    wantedStars: document.querySelectorAll('.star'),
    scanlines  : document.getElementById('scanlines'),
};

// ================================================================
// UTILITAIRES
// ================================================================

/**
 * Formater un nombre en dollars 80s avec séparateurs
 * Ex: 12500 → $12,500
 */
function formatCash(amount) {
    return amount.toLocaleString('en-US');
}

/**
 * Mettre à jour une barre de progression
 */
function updateBar(barEl, percent) {
    barEl.style.width = Math.max(0, Math.min(100, percent)) + '%';
}

/**
 * Mettre à jour les étoiles de recherche
 */
function updateWantedStars(level) {
    dom.wantedStars.forEach((star, i) => {
        if (i < level) {
            star.classList.add('active');
        } else {
            star.classList.remove('active');
        }
    });
}

/**
 * Effet de flash sur le cash (quand la valeur change)
 */
let lastCash = 0;
function flashCash(newAmount) {
    const cashEl = document.getElementById('val-cash');
    if (newAmount !== lastCash) {
        cashEl.style.transition = 'none';
        cashEl.style.transform  = 'scale(1.15)';
        cashEl.style.color      = newAmount > lastCash ? '#39FF14' : '#FF0033';
        setTimeout(() => {
            cashEl.style.transition = 'all 0.3s ease';
            cashEl.style.transform  = 'scale(1)';
            cashEl.style.color      = '';
        }, 300);
        lastCash = newAmount;
    }
}

// ================================================================
// MISE À JOUR DU HUD
// ================================================================
function updateHUD(data) {
    // --- Santé ---
    const hp = Math.max(0, Math.min(100, data.health || 0));
    updateBar(dom.barHealth, hp);
    dom.valHealth.textContent = hp;

    if (hp <= 25) {
        dom.barHealth.classList.add('danger');
    } else {
        dom.barHealth.classList.remove('danger');
    }

    // --- Armure ---
    const arm = Math.max(0, Math.min(100, data.armor || 0));
    updateBar(dom.barArmor, arm);
    dom.valArmor.textContent = arm;

    // --- Cash ---
    const cash = data.cash || 0;
    flashCash(cash);
    dom.valCash.textContent = formatCash(cash);

    // --- Job ---
    dom.valJob.textContent = (data.job || 'Chômeur').toUpperCase();

    // --- Vitesse ---
    const speed = data.speed || 0;
    if (speed > 0) {
        dom.speedometer.classList.remove('hidden-speed');
        dom.valSpeed.textContent = speed;
    } else {
        dom.speedometer.classList.add('hidden-speed');
    }

    // --- Rue ---
    dom.valStreet.textContent = (data.street || '').toUpperCase();

    // --- Wanted ---
    updateWantedStars(data.wanted || 0);
}

// ================================================================
// VISIBILITÉ DU HUD
// ================================================================
function setHUDVisible(visible) {
    if (visible) {
        dom.container.classList.remove('hidden');
    } else {
        dom.container.classList.add('hidden');
    }
}

// ================================================================
// APPLIQUER LA CONFIGURATION
// ================================================================
function applyConfig(cfg) {
    hudConfig = { ...hudConfig, ...cfg };

    // Scanlines
    if (dom.scanlines) {
        dom.scanlines.style.display = hudConfig.ScanlineEffect ? 'block' : 'none';
    }

    // Unité de vitesse
    const unitEl = document.querySelector('.speed-unit');
    if (unitEl) {
        unitEl.textContent = hudConfig.SpeedUnit || 'MPH';
    }
}

// ================================================================
// ÉCOUTE DES MESSAGES FIVEM
// ================================================================
window.addEventListener('message', function(event) {
    const msg = event.data;
    if (!msg || !msg.type) return;

    switch (msg.type) {
        case 'UPDATE_HUD':
            updateHUD(msg.data);
            break;

        case 'SET_VISIBLE':
            setHUDVisible(msg.visible);
            break;

        case 'SET_CONFIG':
            applyConfig(msg.config);
            break;
    }
});

// ================================================================
// INITIALISATION
// ================================================================
document.addEventListener('DOMContentLoaded', function() {
    // Signaler que le NUI est prêt
    fetch(`https://${GetParentResourceName()}/hudReady`, {
        method : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body   : JSON.stringify({}),
    }).catch(() => {
        // Fonction native FiveM — silencieux si hors contexte
    });
});

// Fallback : compatibilité navigateur hors FiveM (dev)
function GetParentResourceName() {
    return typeof window.GetParentResourceName === 'function'
        ? window.GetParentResourceName()
        : 'eightys_hud';
}
