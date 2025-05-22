// Shop system for ESKUI
// This file contains all shop-related functionality

// Shop event handlers
const shopEventHandlers = {
    showShop(data) {
        console.log("shopEventHandlers.showShop called", data);
        state.currentUI = 'shop';
        ui.show('shopping-ui');
        
        // Set the shop title
        document.querySelector('#shopping-ui .titlebar-title').textContent = data.title || 'Shop';
        
        // Clear current state
        state.cart = [];
        state.currentCategory = null;
        state.shopItems = data.items || [];
        
        // Populate categories
        this.populateCategories(data.categories || []);
        
        // Initially select the first category
        if (data.categories && data.categories.length > 0) {
            this.selectCategory(data.categories[0].id);
        } else {
            // If no categories, show all items
            this.populateItems(state.shopItems);
        }
        
        // Update cart UI
        this.updateCartUI();
        
        // Add event listeners
        document.getElementById('shop-cart-clear').onclick = () => this.clearCart();
        document.getElementById('shop-checkout-btn').onclick = () => this.checkout();
        
        // Add escape handler
        ui.addEscapeHandler(() => {
            closeUI();
            // Explicitly send close message to ensure NUI focus is reset
            sendNUIMessage('close');
        });
        
        // Add close button handler
        document.querySelector('#shopping-ui .close-button').onclick = () => {
            closeUI();
            // Explicitly send close message to ensure NUI focus is reset
            sendNUIMessage('close');
        };
        
        // Notify that UI is now visible
        notifyUIVisibilityChange(true);
    },
    
    populateCategories(categories) {
        const container = document.getElementById('shop-categories');
        container.innerHTML = '';
        
        // Check if we have valid categories
        if (!categories || categories.length === 0) {
            console.warn('No shop categories provided');
            return;
        }
        
        categories.forEach(category => {
            const categoryEl = document.createElement('div');
            categoryEl.className = 'shop-category';
            categoryEl.dataset.categoryId = category.id;
            
            const iconHtml = category.icon ? `<div class="shop-category-icon">${category.icon}</div>` : '';
            categoryEl.innerHTML = `
                ${iconHtml}
                <div class="shop-category-name">${category.label}</div>
            `;
            
            categoryEl.onclick = () => this.selectCategory(category.id);
            
            container.appendChild(categoryEl);
        });
    },
    
    selectCategory(categoryId) {
        // Update selected category
        state.currentCategory = categoryId;
        
        // Update category UI
        const categories = document.querySelectorAll('.shop-category');
        categories.forEach(el => {
            if (el.dataset.categoryId === categoryId) {
                el.classList.add('active');
            } else {
                el.classList.remove('active');
            }
        });
        
        // Filter items by category
        const filteredItems = state.shopItems.filter(item => item.category === categoryId);
        
        // Populate items
        this.populateItems(filteredItems);
    },
    
    populateItems(items) {
        const container = document.getElementById('shop-items');
        container.innerHTML = '';
        
        // Check if we have valid items
        if (!items || items.length === 0) {
            container.innerHTML = '<div class="shop-empty">No items available in this category</div>';
            return;
        }
        
        items.forEach(item => {
            const itemEl = document.createElement('div');
            itemEl.className = 'shop-item';
            
            // Format price for display
            const formattedPrice = typeof item.price === 'number' 
                ? '$' + item.price.toLocaleString() 
                : item.price;
            
            // Use item icon or default icon
            const iconHtml = item.icon 
                ? `<div class="shop-item-image">${item.icon}</div>`
                : `<div class="shop-item-image">📦</div>`;
            
            itemEl.innerHTML = `
                ${iconHtml}
                <div class="shop-item-name">${item.name}</div>
                <div class="shop-item-price">${formattedPrice}</div>
                ${item.description ? `<div class="shop-item-desc">${item.description}</div>` : ''}
                <button class="shop-item-add">+</button>
            `;
            
            // Add click handler
            itemEl.querySelector('.shop-item-add').onclick = () => this.addToCart(item);
            
            container.appendChild(itemEl);
        });
    },
    
    addToCart(item) {
        // Check if item is already in cart
        const existingItem = state.cart.find(cartItem => cartItem.id === item.id);
        
        if (existingItem) {
            // Increment quantity
            existingItem.quantity += 1;
        } else {
            // Add new item to cart
            state.cart.push({
                id: item.id,
                name: item.name,
                price: item.price,
                icon: item.icon,
                quantity: 1,
                inventoryName: item.inventoryName || item.id
            });
        }
        
        // Update cart UI
        this.updateCartUI();
        
        // Show notification
        notifications.create({
            type: 'success',
            title: 'Added to Cart',
            message: `Added ${item.name} to your cart`,
            duration: 2000
        });
    },
    
    removeFromCart(itemId) {
        // Remove item from cart
        state.cart = state.cart.filter(item => item.id !== itemId);
        
        // Update cart UI
        this.updateCartUI();
    },
    
    updateItemQuantity(itemId, delta) {
        // Find item in cart
        const item = state.cart.find(item => item.id === itemId);
        
        if (item) {
            // Update quantity
            item.quantity += delta;
            
            // Remove if quantity is 0
            if (item.quantity <= 0) {
                this.removeFromCart(itemId);
                return;
            }
            
            // Update cart UI
            this.updateCartUI();
        }
    },
    
    updateCartUI() {
        const container = document.getElementById('shop-cart-items');
        const totalElement = document.getElementById('shop-cart-total-amount');
        
        // Clear container
        container.innerHTML = '';
        
        // Calculate total
        let total = 0;
        
        // Check if cart is empty
        if (state.cart.length === 0) {
            // Show empty cart message
            container.innerHTML = `
                <div class="shop-cart-empty">
                    <div class="shop-cart-empty-icon">🛒</div>
                    <div class="shop-cart-empty-text">Your cart is empty</div>
                </div>
            `;
            totalElement.textContent = '$0';
            return;
        }
        
        // Add cart items
        state.cart.forEach(item => {
            const itemTotal = item.price * item.quantity;
            total += itemTotal;
            
            const itemEl = document.createElement('div');
            itemEl.className = 'shop-cart-item';
            
            // Use item icon or default icon
            const iconHtml = item.icon 
                ? `<div class="shop-cart-item-icon">${item.icon}</div>`
                : `<div class="shop-cart-item-icon">📦</div>`;
            
            itemEl.innerHTML = `
                ${iconHtml}
                <div class="shop-cart-item-details">
                    <div class="shop-cart-item-name">${item.name}</div>
                    <div class="shop-cart-item-price">$${item.price}</div>
                </div>
                <div class="shop-cart-item-quantity">
                    <button class="shop-cart-item-quantity-btn decrease">-</button>
                    <span class="shop-cart-item-quantity-value">${item.quantity}</span>
                    <button class="shop-cart-item-quantity-btn increase">+</button>
                </div>
                <button class="shop-cart-item-remove">×</button>
            `;
            
            // Add event listeners
            itemEl.querySelector('.shop-cart-item-remove').onclick = () => this.removeFromCart(item.id);
            itemEl.querySelector('.shop-cart-item-quantity-btn.decrease').onclick = () => this.updateItemQuantity(item.id, -1);
            itemEl.querySelector('.shop-cart-item-quantity-btn.increase').onclick = () => this.updateItemQuantity(item.id, 1);
            
            container.appendChild(itemEl);
        });
        
        // Update total
        totalElement.textContent = '$' + total.toLocaleString();
    },
    
    clearCart() {
        // Confirm dialog
        if (state.cart.length > 0) {
            // Simple confirmation
            if (confirm('Are you sure you want to clear your cart?')) {
                state.cart = [];
                this.updateCartUI();
            }
        }
    },
    
    checkout() {
        // Check if cart is empty
        if (state.cart.length === 0) {
            notifications.create({
                type: 'warning',
                title: 'Empty Cart',
                message: 'Your cart is empty',
                duration: 3000
            });
            return;
        }
        
        // Calculate total
        const total = state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        
        // Show payment method selection
        this.showPaymentMethodSelection(total);
    },
    
    showPaymentMethodSelection(total) {
        // Create payment method selection UI
        const paymentUI = document.createElement('div');
        paymentUI.className = 'payment-method-overlay';
        paymentUI.innerHTML = `
            <div class="payment-method-modal">
                <div class="payment-method-header">
                    <h3>Select Payment Method</h3>
                    <div class="payment-total">Total: $${total.toLocaleString()}</div>
                </div>
                <div class="payment-methods">
                    <button class="payment-method-btn" data-method="money">
                        <div class="payment-method-icon">💵</div>
                        <div class="payment-method-label">Cash</div>
                        <div class="payment-method-desc">Pay with cash on hand</div>
                    </button>
                    <button class="payment-method-btn" data-method="bank">
                        <div class="payment-method-icon">🏦</div>
                        <div class="payment-method-label">Bank</div>
                        <div class="payment-method-desc">Pay with bank account</div>
                    </button>
                </div>
                <div class="payment-method-footer">
                    <button class="button cancel" id="payment-cancel">Cancel</button>
                </div>
            </div>
        `;
        
        // Add to document
        document.body.appendChild(paymentUI);
        
        // Add event listeners
        const paymentButtons = paymentUI.querySelectorAll('.payment-method-btn');
        paymentButtons.forEach(btn => {
            btn.onclick = () => {
                const method = btn.dataset.method;
                this.processCheckout(total, method);
                document.body.removeChild(paymentUI);
            };
        });
        
        document.getElementById('payment-cancel').onclick = () => {
            document.body.removeChild(paymentUI);
        };
        
        // Add escape key handler
        const escapeHandler = (e) => {
            if (e.key === 'Escape') {
                document.body.removeChild(paymentUI);
                document.removeEventListener('keydown', escapeHandler);
            }
        };
        document.addEventListener('keydown', escapeHandler);
    },
    
    processCheckout(total, paymentMethod) {
        // Prepare checkout data
        const checkoutData = {
            items: state.cart,
            total: total,
            paymentMethod: paymentMethod || 'money' // Default to cash if not specified
        };
        
        // Close UI and send checkout data
        ui.closeAndSendData('shopping-ui', 'shopCheckout', checkoutData);
    }
};

// Export functionality to global scope
window.shopEventHandlers = shopEventHandlers; 