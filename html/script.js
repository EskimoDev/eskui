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
    document.getElementById('amount-ui').style.display = 'flex';
    document.getElementById('list-ui').style.display = 'none';
    document.querySelector('#amount-ui .titlebar-title').textContent = title;
    document.getElementById('amount-input').value = '';
    document.getElementById('amount-input').focus();
}

function showListUI(title, items) {
    currentUI = 'list';
    document.getElementById('list-ui').style.display = 'flex';
    document.getElementById('amount-ui').style.display = 'none';
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