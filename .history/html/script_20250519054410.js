let currentAmount = 1;
const maxAmount = 999999;
let previousState = null;

// UI Elements
const app = document.getElementById('app');
const backgroundEffect = document.getElementById('background-effect');
const listContainer = document.getElementById('list-container');
const amountContainer = document.getElementById('amount-container');
const listTitle = document.getElementById('list-title');
const listOptions = document.getElementById('list-options');
const amountTitle = document.getElementById('amount-title');
const amountInput = document.getElementById('amount-input');
const decreaseBtn = document.getElementById('decrease-amount');
const increaseBtn = document.getElementById('increase-amount');
const confirmBtn = document.getElementById('confirm-amount');
const cancelBtn = document.getElementById('cancel-amount');

// Event Listeners
decreaseBtn.addEventListener('click', () => updateAmount(-1));
increaseBtn.addEventListener('click', () => updateAmount(1));
amountInput.addEventListener('change', (e) => {
    const value = parseInt(e.target.value);
    if (!isNaN(value)) {
        currentAmount = Math.min(Math.max(1, value), maxAmount);
        amountInput.value = currentAmount;
    }
});
confirmBtn.addEventListener('click', () => {
    if (previousState) {
        // If there's a previous state, return to it
        showList(previousState.title, previousState.options);
        previousState = null;
    } else {
        // Otherwise, send the amount and exit
        sendNUIMessage('amount', currentAmount);
        hideUI();
    }
});
cancelBtn.addEventListener('click', () => {
    sendNUIMessage('cancel');
    hideUI();
});

// Functions
function updateAmount(change) {
    currentAmount = Math.min(Math.max(1, currentAmount + change), maxAmount);
    amountInput.value = currentAmount;
}

function sendNUIMessage(type, data) {
    fetch(`https://${GetParentResourceName()}/${type}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    });
}

function showList(title, options) {
    listTitle.textContent = title;
    listOptions.innerHTML = '';
    
    options.forEach((option, index) => {
        const optionElement = document.createElement('div');
        optionElement.className = 'option-item';
        optionElement.textContent = option;
        optionElement.addEventListener('click', () => {
            // Store current state before showing amount
            previousState = {
                title: title,
                options: options
            };
            sendNUIMessage('select', index);
        });
        listOptions.appendChild(optionElement);
    });

    app.classList.remove('hidden');
    backgroundEffect.classList.remove('hidden');
    listContainer.classList.remove('hidden');
    amountContainer.classList.add('hidden');
}

function showAmount(title, initialAmount = 1) {
    amountTitle.textContent = title;
    currentAmount = Math.min(Math.max(1, initialAmount), maxAmount);
    amountInput.value = currentAmount;

    app.classList.remove('hidden');
    backgroundEffect.classList.remove('hidden');
    listContainer.classList.add('hidden');
    amountContainer.classList.remove('hidden');
}

function hideUI() {
    app.classList.add('hidden');
    backgroundEffect.classList.add('hidden');
    listContainer.classList.add('hidden');
    amountContainer.classList.add('hidden');
    previousState = null;
}

// NUI Message Handler
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.type) {
        case 'showList':
            showList(data.title, data.options);
            break;
        case 'showAmount':
            showAmount(data.title, data.initialAmount);
            break;
        case 'hide':
            hideUI();
            break;
    }
}); 