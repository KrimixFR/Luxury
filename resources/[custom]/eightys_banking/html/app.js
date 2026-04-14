// ================================================================
// FLEECA ATM — NUI JavaScript
// 80s green phosphor CRT interface
// ================================================================

'use strict';

// State
let currentCards   = [];
let selectedCard   = null;
let pinBuffer      = '';
let amountBuffer   = '';
let currentBalance = 0;
let currentPin     = '';
let pendingAction  = null; // 'pin' | 'withdraw'

// ================================================================
// Message handler (from Lua)
// ================================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.type) {
        case 'OPEN_ATM':
            openATM(data.cards);
            break;

        case 'ATM_RESULT':
            handleResult(data.result);
            break;
    }
});

// ================================================================
// Open / Close
// ================================================================
function openATM(cards) {
    currentCards = cards || [];
    resetAll();
    document.getElementById('atm-overlay').classList.remove('hidden');
    buildCardList();
    showScreen('screen-cards');
}

function closeATM() {
    document.getElementById('atm-overlay').classList.add('hidden');
    resetAll();
    fetch('https://eightys_banking/atm_close', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
}

function resetAll() {
    selectedCard   = null;
    pinBuffer      = '';
    amountBuffer   = '';
    currentBalance = 0;
    currentPin     = '';
    pendingAction  = null;
    updatePinDisplay();
    updateAmountDisplay();
    hideError('pin-error');
    hideError('withdraw-error');
}

// ================================================================
// Screen management
// ================================================================
function showScreen(id) {
    document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
    const el = document.getElementById(id);
    if (el) el.classList.add('active');
}

// ================================================================
// Card list
// ================================================================
function buildCardList() {
    const list = document.getElementById('card-list');
    list.innerHTML = '';

    if (currentCards.length === 0) {
        list.innerHTML = '<div style="color:#004415;text-align:center;font-size:11px;letter-spacing:2px;padding:20px;">AUCUNE CARTE DÉTECTÉE</div>';
        return;
    }

    currentCards.forEach((card, idx) => {
        const div = document.createElement('div');
        div.className = 'card-item';

        const label  = card.account_type === 'business'
            ? (card.business_name || 'ENTREPRISE').toUpperCase()
            : (card.owner || 'TITULAIRE').toUpperCase();

        const last4  = card.last4 || '????';
        const typeStr = card.account_type === 'business' ? 'COMPTE ENTREPRISE' : 'COMPTE PERSONNEL';

        div.innerHTML = `
            <div class="card-name">${label}</div>
            <div class="card-number">**** **** **** ${last4}</div>
            <div class="card-type">${typeStr}</div>
        `;

        div.addEventListener('click', () => selectCard(idx));
        list.appendChild(div);
    });
}

function selectCard(idx) {
    selectedCard = currentCards[idx];
    pinBuffer    = '';
    updatePinDisplay();
    hideError('pin-error');

    const last4  = selectedCard.last4 || '????';
    const typeStr = selectedCard.account_type === 'business' ? 'ENTREPRISE' : 'PERSONNEL';
    document.getElementById('pin-card-info').textContent = `CARTE **** ${last4} — ${typeStr}`;

    showScreen('screen-pin');
}

// ================================================================
// PIN entry
// ================================================================
function updatePinDisplay() {
    for (let i = 1; i <= 4; i++) {
        const dot = document.getElementById('dot-' + i);
        dot.textContent = i <= pinBuffer.length ? '●' : '○';
        dot.classList.toggle('filled', i <= pinBuffer.length);
    }
}

document.getElementById('keypad').addEventListener('click', (e) => {
    const btn = e.target.closest('.key');
    if (!btn) return;

    const val = btn.dataset.val;

    if (btn.id === 'key-clear') {
        pinBuffer = pinBuffer.slice(0, -1);
        updatePinDisplay();
        return;
    }

    if (btn.id === 'key-ok') {
        submitPin();
        return;
    }

    if (val !== undefined && pinBuffer.length < 4) {
        pinBuffer += val;
        updatePinDisplay();
        if (pinBuffer.length === 4) {
            // Auto-submit after full PIN entered
            setTimeout(submitPin, 300);
        }
    }
});

function submitPin() {
    if (pinBuffer.length !== 4) {
        showError('pin-error', 'CODE PIN INCOMPLET (4 CHIFFRES)');
        return;
    }

    currentPin    = pinBuffer;
    pendingAction = 'pin';
    hideError('pin-error');

    fetch('https://eightys_banking/atm_verifyPin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ card: selectedCard, pin: currentPin }),
    });
}

document.getElementById('pin-back').addEventListener('click', () => {
    pinBuffer = '';
    updatePinDisplay();
    showScreen('screen-cards');
});

// ================================================================
// Main menu
// ================================================================
function showMainMenu(balance) {
    currentBalance = balance;
    const last4    = selectedCard.last4 || '????';
    const typeStr  = selectedCard.account_type === 'business' ? 'ENTREPRISE' : 'PERSONNEL';
    document.getElementById('menu-card-info').textContent = `CARTE **** ${last4} — ${typeStr}`;
    document.getElementById('menu-balance').textContent   = '$' + formatAmount(balance);
    showScreen('screen-menu');
}

document.getElementById('btn-withdraw').addEventListener('click', () => {
    amountBuffer = '';
    updateAmountDisplay();
    hideError('withdraw-error');
    document.getElementById('withdraw-balance').textContent = `SOLDE DISPONIBLE : $${formatAmount(currentBalance)}`;
    showScreen('screen-withdraw');
});

document.getElementById('btn-balance').addEventListener('click', () => {
    showResult({
        ok      : true,
        message : 'SOLDE CONSULTÉ',
        balance : currentBalance,
    });
});

document.getElementById('menu-back').addEventListener('click', () => {
    closeATM();
});

// ================================================================
// Withdraw screen
// ================================================================
function updateAmountDisplay() {
    document.getElementById('amount-value').textContent =
        amountBuffer.length > 0 ? formatAmount(parseInt(amountBuffer)) : '0';
}

document.getElementById('amount-presets').addEventListener('click', (e) => {
    const btn = e.target.closest('.preset-btn');
    if (!btn) return;
    const amount = parseInt(btn.dataset.amount);
    processWithdraw(amount);
});

document.getElementById('amount-keypad').addEventListener('click', (e) => {
    const btn = e.target.closest('.key');
    if (!btn) return;

    const val = btn.dataset.val;

    if (btn.id === 'amount-clear') {
        amountBuffer = amountBuffer.slice(0, -1);
        updateAmountDisplay();
        return;
    }

    if (btn.id === 'amount-ok') {
        const amount = parseInt(amountBuffer) || 0;
        processWithdraw(amount);
        return;
    }

    if (val !== undefined && amountBuffer.length < 6) {
        amountBuffer += val;
        // Prevent leading zeros
        amountBuffer = String(parseInt(amountBuffer) || 0);
        updateAmountDisplay();
    }
});

document.getElementById('withdraw-back').addEventListener('click', () => {
    showScreen('screen-menu');
});

function processWithdraw(amount) {
    hideError('withdraw-error');

    if (!amount || amount <= 0) {
        showError('withdraw-error', 'MONTANT INVALIDE');
        return;
    }
    if (amount < 50) {
        showError('withdraw-error', 'MINIMUM : $50');
        return;
    }
    if (amount > 50000) {
        showError('withdraw-error', 'MAXIMUM : $50 000');
        return;
    }
    if (amount > currentBalance) {
        showError('withdraw-error', 'SOLDE INSUFFISANT');
        return;
    }

    pendingAction = 'withdraw';
    fetch('https://eightys_banking/atm_withdraw', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ card: selectedCard, pin: currentPin, amount: amount }),
    });
}

// ================================================================
// Result screen
// ================================================================
function handleResult(result) {
    if (!result) return;

    if (result.ok) {
        // Success
        if (pendingAction === 'pin') {
            // PIN verified → go to main menu
            showMainMenu(result.balance || 0);
        } else {
            // Withdrawal or balance consult → result screen
            showResult(result);
        }
    } else {
        // Failure — show error on the appropriate screen
        const msg = result.msg || 'OPÉRATION REFUSÉE';
        if (pendingAction === 'pin') {
            showError('pin-error', msg);
            pinBuffer = '';
            updatePinDisplay();
        } else if (pendingAction === 'withdraw') {
            showError('withdraw-error', msg);
        } else {
            showResult(result);
        }
    }
    pendingAction = null;
}

function showResult(result) {
    const isOk  = !!result.ok;
    const icon  = document.getElementById('result-icon');
    const title = document.getElementById('result-title');
    const msg   = document.getElementById('result-message');
    const bal   = document.getElementById('result-new-balance');

    icon.textContent  = isOk ? '✓' : '✗';
    icon.style.color  = isOk ? '#00ff50' : '#ff4400';
    icon.style.textShadow = isOk
        ? '0 0 20px #00ff50'
        : '0 0 20px #ff4400';

    title.textContent = result.message || (isOk ? 'OPÉRATION RÉUSSIE' : 'OPÉRATION REFUSÉE');
    title.style.color = isOk ? '#00ff50' : '#ff4400';

    if (result.withdrawn) {
        msg.textContent = `VOUS AVEZ RETIRÉ $${formatAmount(result.withdrawn)} EN ESPÈCES`;
    } else {
        msg.textContent = '';
    }

    if (result.balance !== undefined) {
        bal.textContent = `NOUVEAU SOLDE : $${formatAmount(result.balance)}`;
        currentBalance  = result.balance;
    } else {
        bal.textContent = '';
    }

    showScreen('screen-result');
}

document.getElementById('result-continue').addEventListener('click', () => {
    if (selectedCard) {
        showMainMenu(currentBalance);
    } else {
        closeATM();
    }
});

// ================================================================
// Keyboard: ESC to close
// ================================================================
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const overlay = document.getElementById('atm-overlay');
        if (!overlay.classList.contains('hidden')) {
            closeATM();
        }
    }
});

// ================================================================
// Helpers
// ================================================================
function showError(id, msg) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = msg;
    el.classList.remove('hidden');
}

function hideError(id) {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
}

function formatAmount(n) {
    if (isNaN(n)) return '0';
    return Math.floor(n).toLocaleString('fr-FR');
}
