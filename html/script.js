let currentUI = null;

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        case 'showAmount':
            showAmountUI(data.title);
            break;
        case 'showList':
            showListUI(data.title, data.items);
            break;
    }
});

function showAmountUI(title) {
    currentUI = 'amount';
    const amountUI = document.getElementById('amount-ui');
    const listUI = document.getElementById('list-ui');
    
    amountUI.style.display = 'flex';
    listUI.style.display = 'none';
    
    const window = amountUI.querySelector('.window');
    window.classList.remove('close');
    window.classList.add('open');
    
    document.querySelector('#amount-ui .titlebar-title').textContent = title;
    document.getElementById('amount-input').value = '';
    document.getElementById('amount-input').focus();
}

function showListUI(title, items) {
    currentUI = 'list';
    const listUI = document.getElementById('list-ui');
    const amountUI = document.getElementById('amount-ui');
    
    listUI.style.display = 'flex';
    amountUI.style.display = 'none';
    
    const window = listUI.querySelector('.window');
    window.classList.remove('close');
    window.classList.add('open');
    
    document.querySelector('#list-ui .titlebar-title').textContent = title;
    
    const listContainer = document.getElementById('list-items');
    listContainer.innerHTML = '';
    
    items.forEach((item, index) => {
        const div = document.createElement('div');
        div.className = 'list-item';
        div.innerHTML = `
            <div style="font-weight: 500;">${item.label}</div>
            ${item.price ? `<div style="font-size: 0.9em; opacity: 0.7;">$${item.price}</div>` : ''}
        `;
        
        div.addEventListener('click', () => selectListItem(index, item));
        listContainer.appendChild(div);
    });
}

function selectListItem(index, item) {
    fetch(`https://${GetParentResourceName()}/listSelect`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            index: index,
            item: item
        })
    });
}

function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        fetch(`https://${GetParentResourceName()}/amountSubmit`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                amount: amount
            })
        });
    }
}

function closeUI() {
    const amountUI = document.getElementById('amount-ui');
    const listUI = document.getElementById('list-ui');
    
    const amountWindow = amountUI.querySelector('.window');
    const listWindow = listUI.querySelector('.window');
    
    amountWindow.classList.remove('open');
    amountWindow.classList.add('close');
    listWindow.classList.remove('open');
    listWindow.classList.add('close');
    
    // Wait for animation to complete before hiding
    setTimeout(() => {
        amountUI.style.display = 'none';
        listUI.style.display = 'none';
    }, 300); // Match animation duration
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

// Handle Enter key for amount input
document.getElementById('amount-input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        submitAmount();
    }
});

// Handle Escape key for both UIs
document.addEventListener('keyup', function(e) {
    if (e.key === 'Escape') {
        closeUI();
    }
}); 