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
        case 'showSubMenu':
            showSubMenu(data.title, data.items);
            break;
        case 'showDropdown':
            showDropdownUI(data.title, data.options, data.selectedIndex);
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
        
        const contentDiv = document.createElement('div');
        contentDiv.className = 'list-item-content';
        
        // Force a reflow to get accurate measurements
        contentDiv.style.visibility = 'hidden';
        div.appendChild(contentDiv);
        listContainer.appendChild(div);
        
        // Check if text is too long
        let isLong = false;
        let span = null;
        contentDiv.textContent = item.label;
        if (contentDiv.scrollWidth > contentDiv.clientWidth) {
            isLong = true;
            contentDiv.classList.add('scroll');
            contentDiv.textContent = '';
            span = document.createElement('span');
            span.textContent = item.label;
            contentDiv.appendChild(span);
        }
        contentDiv.style.visibility = 'visible';
        
        if (isLong && span) {
            div.addEventListener('mouseenter', function() {
                span.classList.add('scroll-animate');
            });
            div.addEventListener('mouseleave', function() {
                span.classList.remove('scroll-animate');
                span.style.transform = 'translateX(0)'; // Reset position
            });
        }
        
        if (item.price) {
            const priceDiv = document.createElement('div');
            priceDiv.style.fontSize = '0.9em';
            priceDiv.style.opacity = '0.7';
            priceDiv.textContent = `$${item.price}`;
            div.appendChild(priceDiv);
        }
        
        div.addEventListener('click', () => selectListItem(index, item));
    });
}

function showSubMenu(title, items) {
    showListUI(title, items);
}

function selectListItem(index, item) {
    const listUI = document.getElementById('list-ui');
    const window = listUI.querySelector('.window');
    
    window.classList.remove('open');
    window.classList.add('close');
    
    // Wait for animation to complete before sending data
    setTimeout(() => {
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
    }, 300);
}

function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        const amountUI = document.getElementById('amount-ui');
        const window = amountUI.querySelector('.window');
        
        window.classList.remove('open');
        window.classList.add('close');
        
        // Wait for animation to complete before submitting
        setTimeout(() => {
            fetch(`https://${GetParentResourceName()}/amountSubmit`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    amount: amount
                })
            });
        }, 300);
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
    }, 300);
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function showDropdownUI(title, options, selectedIndex) {
    currentUI = 'dropdown';
    document.getElementById('dropdown-ui').style.display = 'flex';
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('list-ui').style.display = 'none';
    document.querySelector('#dropdown-ui .titlebar-title').textContent = title;
    const label = document.getElementById('dropdown-label');
    const list = document.getElementById('dropdown-list');
    let currentSelected = typeof selectedIndex === 'number' ? selectedIndex : -1;
    label.textContent = currentSelected >= 0 ? options[currentSelected] : 'Select an option';
    list.innerHTML = '';
    options.forEach((opt, idx) => {
        const item = document.createElement('div');
        item.className = 'dropdown-item' + (idx === currentSelected ? ' selected' : '');
        item.textContent = opt;
        item.onclick = function() {
            label.textContent = opt;
            list.style.display = 'none';
            fetch(`https://${GetParentResourceName()}/dropdownSelect`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ index: idx, value: opt })
            });
        };
        list.appendChild(item);
    });
    label.onclick = function(e) {
        e.stopPropagation();
        list.style.display = list.style.display === 'block' ? 'none' : 'block';
    };
    // Hide dropdown if clicking outside
    document.body.onclick = function() {
        list.style.display = 'none';
    };
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