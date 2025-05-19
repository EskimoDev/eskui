let currentUI = null;
let currentUIId = null;
let cleanupHandlers = [];
let listMenuStack = [];

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.type) {
        case 'showAmount':
            showAmountUI(data.title);
            break;
        case 'showList':
            showListUI(data.title, data.items, data.isSubmenu);
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
    console.log('showAmountUI called');
    currentUI = 'amount';
    showUI('amount-ui');
    document.getElementById('list-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    document.querySelector('#amount-ui .titlebar-title').textContent = title;
    document.getElementById('amount-input').value = '';
    document.getElementById('amount-input').focus();
    // Scoped Escape key handler
    const escHandler = function(e) {
        if (e.key === 'Escape') {
            closeUI();
        }
    };
    document.addEventListener('keyup', escHandler);
    cleanupHandlers.push(() => document.removeEventListener('keyup', escHandler));
}

function showListUI(title, items, isSubmenu) {
    currentUI = 'list';
    showUI('list-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('dropdown-ui').style.display = 'none';
    document.querySelector('#list-ui .titlebar-title').textContent = title;
    
    // Clear list items
    const listContainer = document.getElementById('list-items');
    listContainer.innerHTML = '';
    
    // Add items
    items.forEach((item, index) => {
        const itemElement = document.createElement('div');
        itemElement.className = 'list-item';
        
        if (item.disabled) {
            itemElement.classList.add('disabled');
        }
        
        const itemContent = document.createElement('div');
        itemContent.className = 'list-item-content';
        
        let innerContent = '';
        if (item.icon) {
            innerContent += `<div class="list-item-icon">${item.icon}</div>`;
        }
        innerContent += `<span>${item.label}</span>`;
        itemContent.innerHTML = innerContent;
        
        itemElement.appendChild(itemContent);
        
        // Add description if exists
        if (item.description) {
            const descElement = document.createElement('div');
            descElement.className = 'list-item-desc';
            descElement.textContent = item.description;
            itemElement.appendChild(descElement);
        }
        
        // Add click handler
        if (!item.disabled) {
            itemElement.onclick = function() {
                selectListItem(index, item);
            };
        }
        
        listContainer.appendChild(itemElement);
        
        // Check if the text is overflowing and add scroll animation
        setTimeout(() => {
            if (itemContent.scrollWidth > itemContent.clientWidth) {
                itemContent.classList.add('scroll');
                const textSpan = itemContent.querySelector('span');
                
                // Only animate on hover
                itemElement.addEventListener('mouseenter', () => {
                    textSpan.classList.add('scroll-animate');
                });
                
                itemElement.addEventListener('mouseleave', () => {
                    textSpan.classList.remove('scroll-animate');
                });
            }
        }, 10);
    });
    
    // Add escape key handler
    const escHandler = function(e) {
        if (e.key === 'Escape') {
            if (listMenuStack.length > 0 && !isSubmenu) {
                const prevMenu = listMenuStack.pop();
                showListUI(prevMenu.title, prevMenu.items, true);
            } else {
                closeUI();
            }
        }
    };
    document.addEventListener('keyup', escHandler);
    cleanupHandlers.push(() => document.removeEventListener('keyup', escHandler));
}

function showSubMenu(title, items) {
    showListUI(title, items);
}

function showDropdownUI(title, options, selectedIndex = -1) {
    currentUI = 'dropdown';
    showUI('dropdown-ui');
    document.getElementById('amount-ui').style.display = 'none';
    document.getElementById('list-ui').style.display = 'none';
    
    const titleEl = document.querySelector('#dropdown-ui .titlebar-title');
    titleEl.textContent = title;
    
    const label = document.getElementById('dropdown-label-text');
    const list = document.getElementById('dropdown-list');
    const dropdownLabel = document.getElementById('dropdown-label');
    const cancelBtn = document.getElementById('dropdown-cancel');
    const submitBtn = document.getElementById('dropdown-submit');
    
    // Clear previous dropdown items
    list.innerHTML = '';
    
    // Set default label
    label.textContent = selectedIndex >= 0 && selectedIndex < options.length 
        ? options[selectedIndex] 
        : 'Select an option';
    
    // Add dropdown options
    let currentSelected = selectedIndex;
    options.forEach((option, index) => {
        const item = document.createElement('div');
        item.className = 'dropdown-item';
        if (index === currentSelected) {
            item.classList.add('selected');
        }
        item.textContent = option;
        
        item.onclick = function() {
            // Unselect previous
            const previousSelected = list.querySelector('.selected');
            if (previousSelected) {
                previousSelected.classList.remove('selected');
            }
            
            // Select this item
            item.classList.add('selected');
            currentSelected = index;
            label.textContent = option;
            
            // Close dropdown list but not the whole UI
            list.classList.remove('open');
            dropdownLabel.classList.remove('open');
        };
        
        list.appendChild(item);
    });
    
    // Toggle dropdown on label click
    dropdownLabel.onclick = function() {
        dropdownLabel.classList.toggle('open');
        list.classList.toggle('open');
    };
    
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
        const sendClose = () => {
            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        };
        if (currentSelected >= 0) {
            fetch(`https://${GetParentResourceName()}/dropdownSelect`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ index: currentSelected, value: options[currentSelected] })
            }).then(() => {
                // Reset UI state
                currentUI = null;
                currentUIId = null;
                sendClose();
            });
        } else {
            sendClose();
        }
    };
    
    // Escape key handler
    const escHandler = function(e) {
        if (e.key === 'Escape') {
            // If dropdown list is open, just close it
            if (list.classList.contains('open')) {
                list.classList.remove('open');
                dropdownLabel.classList.remove('open');
            } else {
                // Otherwise close the whole UI
                closeUI();
            }
        }
    };
    document.addEventListener('keyup', escHandler);
    cleanupHandlers.push(() => document.removeEventListener('keyup', escHandler));
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
        
        // Reset UI state
        currentUI = null;
        currentUIId = null;
    }, 300);
}

function submitAmount() {
    const amount = document.getElementById('amount-input').value;
    if (amount && amount > 0) {
        console.log('Amount entered:', amount);
        const amountUI = document.getElementById('amount-ui');
        const window = amountUI.querySelector('.window');
        
        window.classList.remove('open');
        window.classList.add('close');
        
        // Wait for animation to complete before submitting
        setTimeout(() => {
            // Reset UI state before fetch
            currentUI = null;
            currentUIId = null;
            
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
    console.log('closeUI called');
    const amountUI = document.getElementById('amount-ui');
    const listUI = document.getElementById('list-ui');
    const dropdownUI = document.getElementById('dropdown-ui');
    const amountWindow = amountUI.querySelector('.window');
    const listWindow = listUI.querySelector('.window');
    const dropdownWindow = dropdownUI.querySelector('.window');
    
    amountWindow.classList.remove('open');
    amountWindow.classList.add('close');
    listWindow.classList.remove('open');
    listWindow.classList.add('close');
    dropdownWindow.classList.remove('open');
    dropdownWindow.classList.add('close');
    
    setTimeout(() => {
        amountUI.style.display = 'none';
        listUI.style.display = 'none';
        dropdownUI.style.display = 'none';
    }, 300);
    
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
    
    // Reset UI state
    currentUI = null;
    currentUIId = null;
}

// Handle Enter key for amount input
document.getElementById('amount-input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        submitAmount();
    }
}); 