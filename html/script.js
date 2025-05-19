let currentUI = null;
let currentUIId = null;
let cleanupHandlers = [];

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

function showUI(containerId) {
    closeCurrentUI();
    const container = document.getElementById(containerId);
    if (!container) return;
    container.style.display = 'flex';
    const win = container.querySelector('.window');
    win.classList.remove('close');
    win.classList.add('open');
    currentUIId = containerId;
}

function hideUI(containerId, cb) {
    const container = document.getElementById(containerId);
    if (!container) return;
    const win = container.querySelector('.window');
    win.classList.remove('open');
    win.classList.add('close');
    setTimeout(() => {
        container.style.display = 'none';
        if (cb) cb();
    }, 300);
    if (currentUIId === containerId) currentUIId = null;
}

function closeCurrentUI() {
    if (currentUIId) {
        hideUI(currentUIId);
    }
    // Cleanup document-level handlers
    cleanupHandlers.forEach(fn => fn());
    cleanupHandlers = [];
}

function showAmountUI(title) {
    currentUI = 'amount';
    showUI('amount-ui');
    document.getElementById('list-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    document.querySelector('#amount-ui .titlebar-title').textContent = title;
    document.getElementById('amount-input').value = '';
    document.getElementById('amount-input').focus();
}

function showListUI(title, items) {
    currentUI = 'list';
    showUI('list-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    document.querySelector('#list-ui .titlebar-title').textContent = title;
    const listContainer = document.getElementById('list-items');
    listContainer.innerHTML = '';
    items.forEach((item, index) => {
        const div = document.createElement('div');
        div.className = 'list-item';
        const contentDiv = document.createElement('div');
        contentDiv.className = 'list-item-content';
        contentDiv.style.visibility = 'hidden';
        div.appendChild(contentDiv);
        listContainer.appendChild(div);
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
                span.style.transform = 'translateX(0)';
            });
        }
        if (item.price) {
            const priceDiv = document.createElement('div');
            priceDiv.style.fontSize = '0.9em';
            priceDiv.style.opacity = '0.7';
            priceDiv.textContent = `$${item.price}`;
            div.appendChild(priceDiv);
        }
        div.addEventListener('click', () => {
            // If eventType is server, send to client for NUI->server relay
            if (item.event && item.eventType === 'server') {
                fetch(`https://${GetParentResourceName()}/eskui_serverEvent`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ event: item.event, args: item.args || [] })
                });
            }
            selectListItem(index, item);
        });
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
    showUI('dropdown-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('list-ui').style.display = 'none';
    document.querySelector('#dropdown-ui .titlebar-title').textContent = title;
    const label = document.getElementById('dropdown-label');
    const labelText = document.getElementById('dropdown-label-text');
    const chevron = document.getElementById('dropdown-chevron');
    const list = document.getElementById('dropdown-list');
    const cancelBtn = document.getElementById('dropdown-cancel');
    const submitBtn = document.getElementById('dropdown-submit');
    let currentSelected = typeof selectedIndex === 'number' ? selectedIndex : -1;
    labelText.textContent = currentSelected >= 0 ? options[currentSelected] : 'Select an option';
    list.innerHTML = '';
    options.forEach((opt, idx) => {
        const item = document.createElement('div');
        item.className = 'dropdown-item' + (idx === currentSelected ? ' selected' : '');
        item.textContent = opt;
        item.onclick = function() {
            labelText.textContent = opt;
            currentSelected = idx;
            Array.from(list.children).forEach(child => child.classList.remove('selected'));
            item.classList.add('selected');
            list.classList.remove('open');
            label.classList.remove('open');
        };
        list.appendChild(item);
    });
    label.onclick = function(e) {
        e.stopPropagation();
        const isOpen = list.classList.contains('open');
        if (isOpen) {
            list.classList.remove('open');
            label.classList.remove('open');
        } else {
            list.classList.add('open');
            label.classList.add('open');
        }
    };
    // Hide dropdown if clicking outside
    const docClick = function(e) {
        if (!label.contains(e.target) && !list.contains(e.target)) {
            list.classList.remove('open');
            label.classList.remove('open');
        }
    };
    document.body.addEventListener('click', docClick);
    cleanupHandlers.push(() => document.body.removeEventListener('click', docClick));
    // Cancel button
    cancelBtn.onclick = function() {
        hideUI('dropdown-ui', () => {
            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        });
    };
    // Submit button
    submitBtn.onclick = function() {
        if (currentSelected >= 0) {
            fetch(`https://${GetParentResourceName()}/dropdownSelect`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ index: currentSelected, value: options[currentSelected] })
            });
        } else {
            fetch(`https://${GetParentResourceName()}/dropdownSelect`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ index: null, value: null })
            });
        }
        hideUI('dropdown-ui', () => {});
    };
    // Close button
    const closeBtn = document.querySelector('#dropdown-ui .close-button');
    closeBtn.onclick = function() {
        hideUI('dropdown-ui', () => {
            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        });
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