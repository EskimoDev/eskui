// Shop system for ESKUI
// This file contains all shop-related functionality

// Shop event handlers
const shopEventHandlers = {
    // Payment flow state
    paymentFlow: {
        currentScreen: 'shop', // 'shop', 'payment-method', 'payment-processing', 'payment-success', 'payment-failure'
        selectedMethod: null,
        processingTimeout: null,
        purchaseComplete: false // Track if the current purchase is complete
    },
    
    showShop(data) {
        console.log("shopEventHandlers.showShop called", data);
        state.currentUI = 'shop';
        this.paymentFlow.currentScreen = 'shop';
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
            this.exitShopping();
        });
        
        // Add close button handler
        document.querySelector('#shopping-ui .close-button').onclick = () => {
            this.exitShopping();
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
        const checkoutBtn = document.getElementById('shop-checkout-btn');
        
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
            
            // Disable checkout button when cart is empty
            checkoutBtn.disabled = true;
            checkoutBtn.classList.add('disabled');
            return;
        }
        
        // Enable checkout button when cart has items
        checkoutBtn.disabled = false;
        checkoutBtn.classList.remove('disabled');
        
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
    
    // Handle checkout and transition to payment method screen
    checkout() {
        console.log("Checkout button clicked - refreshing player balances");
        
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
        
        // Clear any running timers before starting a new checkout flow
        if (this.paymentFlow.processingTimeout) {
            clearTimeout(this.paymentFlow.processingTimeout);
            this.paymentFlow.processingTimeout = null;
        }
        
        // Reset payment flow state
        this.paymentFlow.selectedMethod = null;
        
        console.log("Starting payment flow - maintaining NUI focus throughout all screens");
        
        // Show the payment method selection screen
        // This will trigger a fresh server-side balance check
        // Important: NUI focus remains active during the entire payment flow
        this.showPaymentMethodScreen();
    },
    
    // New method to show the payment method screen
    showPaymentMethodScreen() {
        // Update payment flow state
        this.paymentFlow.currentScreen = 'payment-method';
        
        // Get shop main container
        const shopMain = document.querySelector('.shop-main');
        
        // Calculate total
        const total = state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        
        // Store the contents of shopMain before replacing
        if (!this.originalShopMain) {
            this.originalShopMain = shopMain.innerHTML;
        }
        
        // Always show payment method UI with loading state
        shopMain.innerHTML = `
            <div class="payment-method-screen">
                <h2>Select Payment Method</h2>
                <p class="payment-total">Total: $${total.toLocaleString()}</p>
                
                <div class="payment-methods">
                    <button class="payment-method-btn loading" data-method="cash">
                        <span class="payment-method-icon">💵</span>
                        <span class="payment-method-label">Cash</span>
                        <span class="payment-method-balance loading">Loading...</span>
                        <div class="payment-method-tax-container" id="cash-tax-container"></div>
                        <div class="payment-method-taxed-price" id="cash-taxed-price"></div>
                    </button>
                    <button class="payment-method-btn loading" data-method="bank">
                        <span class="payment-method-icon">🏦</span>
                        <span class="payment-method-label">Bank</span>
                        <span class="payment-method-balance loading">Loading...</span>
                        <div class="payment-method-tax-container" id="bank-tax-container"></div>
                        <div class="payment-method-taxed-price" id="bank-taxed-price"></div>
                    </button>
                </div>
                
                <div class="payment-actions">
                    <button class="button cancel" id="payment-cancel-btn">Cancel</button>
                </div>
            </div>
        `;
        
        // Update the shop title
        document.querySelector('#shopping-ui .titlebar-title').textContent = 'Payment Method';
        
        // Add event listener for the cancel button
        document.getElementById('payment-cancel-btn').addEventListener('click', () => {
            this.returnToShop();
        });
        
        // Fetch tax information
        fetch(`https://${GetParentResourceName()}/getTaxRates`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        })
        .then(response => response.json())
        .then(taxData => {
            // Update tax information in UI
            const cashTaxContainer = document.getElementById('cash-tax-container');
            const bankTaxContainer = document.getElementById('bank-tax-container');
            const cashTaxedPrice = document.getElementById('cash-taxed-price');
            const bankTaxedPrice = document.getElementById('bank-taxed-price');
            
            // Calculate and display taxed prices
            if (taxData && taxData.cash && taxData.cash !== false) {
                const taxRate = parseFloat(taxData.cash);
                const taxAmount = Math.floor(total * (taxRate / 100));
                const taxedTotal = total + taxAmount;
                
                cashTaxContainer.innerHTML = `
                    <div class="payment-method-tax">
                        <span class="payment-method-tax-icon">🧾</span>
                        <span class="payment-method-tax-text">${taxData.cash}% VAT tax applied</span>
                    </div>
                `;
                cashTaxContainer.style.display = 'block';
                
                // Add taxed price display
                cashTaxedPrice.innerHTML = `
                    <div class="payment-method-taxed-price-display">
                        <span class="payment-method-taxed-price-text">Final price: $${taxedTotal.toLocaleString()}</span>
                    </div>
                `;
                cashTaxedPrice.style.display = 'block';
            } else {
                cashTaxContainer.style.display = 'none';
                cashTaxedPrice.style.display = 'none';
            }
            
            if (taxData && taxData.bank && taxData.bank !== false) {
                const taxRate = parseFloat(taxData.bank);
                const taxAmount = Math.floor(total * (taxRate / 100));
                const taxedTotal = total + taxAmount;
                
                bankTaxContainer.innerHTML = `
                    <div class="payment-method-tax">
                        <span class="payment-method-tax-icon">🧾</span>
                        <span class="payment-method-tax-text">${taxData.bank}% VAT tax applied</span>
                    </div>
                `;
                bankTaxContainer.style.display = 'block';
                
                // Add taxed price display
                bankTaxedPrice.innerHTML = `
                    <div class="payment-method-taxed-price-display">
                        <span class="payment-method-taxed-price-text">Final price: $${taxedTotal.toLocaleString()}</span>
                    </div>
                `;
                bankTaxedPrice.style.display = 'block';
            } else {
                bankTaxContainer.style.display = 'none';
                bankTaxedPrice.style.display = 'none';
            }
        })
        .catch(error => {
            console.error('Error fetching tax rates:', error);
        });
        
        // Always fetch fresh player balances from the client
        // Never use cached values to ensure balances are current after purchases
        this.fetchPlayerBalances().then(balances => {
            // Format balances
            const cashBalance = balances.cash || 0;
            const bankBalance = balances.bank || 0;
            
            console.log('Fetched updated player balances:', { cash: cashBalance, bank: bankBalance });
            
            // Check if player can afford with each payment method
            const cashDisabled = cashBalance < total;
            const bankDisabled = bankBalance < total;
            
            // Update the UI with actual balances
            const cashBtn = shopMain.querySelector('.payment-method-btn[data-method="cash"]');
            const bankBtn = shopMain.querySelector('.payment-method-btn[data-method="bank"]');
            
            // Update cash button
            cashBtn.classList.remove('loading');
            if (cashDisabled) {
                cashBtn.classList.add('disabled');
                cashBtn.innerHTML = `
                    <span class="payment-method-icon">💵</span>
                    <span class="payment-method-label">Cash</span>
                    <span class="payment-method-balance insufficient">$${cashBalance.toLocaleString()}</span>
                    <span class="payment-method-insufficient">Insufficient Funds</span>
                    <div class="payment-method-tax-container" id="cash-tax-container"></div>
                    <div class="payment-method-taxed-price" id="cash-taxed-price"></div>
                `;
            } else {
                cashBtn.innerHTML = `
                    <span class="payment-method-icon">💵</span>
                    <span class="payment-method-label">Cash</span>
                    <span class="payment-method-balance">$${cashBalance.toLocaleString()}</span>
                    <div class="payment-method-tax-container" id="cash-tax-container"></div>
                    <div class="payment-method-taxed-price" id="cash-taxed-price"></div>
                `;
                cashBtn.addEventListener('click', () => {
                    this.selectPaymentMethod('cash');
                });
            }
            
            // Update bank button
            bankBtn.classList.remove('loading');
            if (bankDisabled) {
                bankBtn.classList.add('disabled');
                bankBtn.innerHTML = `
                    <span class="payment-method-icon">🏦</span>
                    <span class="payment-method-label">Bank</span>
                    <span class="payment-method-balance insufficient">$${bankBalance.toLocaleString()}</span>
                    <span class="payment-method-insufficient">Insufficient Funds</span>
                    <div class="payment-method-tax-container" id="bank-tax-container"></div>
                    <div class="payment-method-taxed-price" id="bank-taxed-price"></div>
                `;
            } else {
                bankBtn.innerHTML = `
                    <span class="payment-method-icon">🏦</span>
                    <span class="payment-method-label">Bank</span>
                    <span class="payment-method-balance">$${bankBalance.toLocaleString()}</span>
                    <div class="payment-method-tax-container" id="bank-tax-container"></div>
                    <div class="payment-method-taxed-price" id="bank-taxed-price"></div>
                `;
                bankBtn.addEventListener('click', () => {
                    this.selectPaymentMethod('bank');
                });
            }
            
            // Restore tax information after updating HTML
            fetch(`https://${GetParentResourceName()}/getTaxRates`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            })
            .then(response => response.json())
            .then(taxData => {
                // Update tax information in UI
                const cashTaxContainer = document.getElementById('cash-tax-container');
                const bankTaxContainer = document.getElementById('bank-tax-container');
                const cashTaxedPrice = document.getElementById('cash-taxed-price');
                const bankTaxedPrice = document.getElementById('bank-taxed-price');
                
                // Calculate and display taxed prices
                if (taxData && taxData.cash && taxData.cash !== false) {
                    const taxRate = parseFloat(taxData.cash);
                    const taxAmount = Math.floor(total * (taxRate / 100));
                    const taxedTotal = total + taxAmount;
                    
                    cashTaxContainer.innerHTML = `
                        <div class="payment-method-tax">
                            <span class="payment-method-tax-icon">🧾</span>
                            <span class="payment-method-tax-text">${taxData.cash}% VAT tax applied</span>
                        </div>
                    `;
                    cashTaxContainer.style.display = 'block';
                    
                    // Add taxed price display
                    cashTaxedPrice.innerHTML = `
                        <div class="payment-method-taxed-price-display">
                            <span class="payment-method-taxed-price-text">Final price: $${taxedTotal.toLocaleString()}</span>
                        </div>
                    `;
                    cashTaxedPrice.style.display = 'block';
                } else {
                    cashTaxContainer.style.display = 'none';
                    cashTaxedPrice.style.display = 'none';
                }
                
                if (taxData && taxData.bank && taxData.bank !== false) {
                    const taxRate = parseFloat(taxData.bank);
                    const taxAmount = Math.floor(total * (taxRate / 100));
                    const taxedTotal = total + taxAmount;
                    
                    bankTaxContainer.innerHTML = `
                        <div class="payment-method-tax">
                            <span class="payment-method-tax-icon">🧾</span>
                            <span class="payment-method-tax-text">${taxData.bank}% VAT tax applied</span>
                        </div>
                    `;
                    bankTaxContainer.style.display = 'block';
                    
                    // Add taxed price display
                    bankTaxedPrice.innerHTML = `
                        <div class="payment-method-taxed-price-display">
                            <span class="payment-method-taxed-price-text">Final price: $${taxedTotal.toLocaleString()}</span>
                        </div>
                    `;
                    bankTaxedPrice.style.display = 'block';
                } else {
                    bankTaxContainer.style.display = 'none';
                    bankTaxedPrice.style.display = 'none';
                }
            })
            .catch(error => {
                console.error('Error fetching tax rates:', error);
            });
            
            // Show notification if player can't afford either method
            if (cashDisabled && bankDisabled) {
                notifications.create({
                    type: 'error',
                    title: 'Insufficient Funds',
                    message: 'You cannot afford this purchase with any payment method.',
                    duration: 5000
                });
            }
        }).catch(error => {
            console.error('Error fetching player balances:', error);
            
            // Show error message and return to shop
            notifications.create({
                type: 'error',
                title: 'Error',
                message: 'Could not retrieve account balances. Please try again.',
                duration: 5000
            });
            
            // Go back to shop
            setTimeout(() => this.returnToShop(), 1000);
        });
    },
    
    // Helper method to fetch player balances
    fetchPlayerBalances() {
        return new Promise((resolve, reject) => {
            // Add a cache-busting parameter to ensure we get fresh data
            const cacheBuster = new Date().getTime();
            
            fetch(`https://${GetParentResourceName()}/getPlayerBalances`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ cacheBuster })
            })
            .then(response => response.json())
            .then(data => {
                console.log('Received player balances:', data);
                resolve(data);
            })
            .catch(error => {
                console.error('Error fetching player balances:', error);
                reject(error);
            });
        });
    },
    
    // New method to handle payment method selection
    selectPaymentMethod(method) {
        console.log(`Payment method selected: ${method} - maintaining NUI focus`);
        
        // Store selected method
        this.paymentFlow.selectedMethod = method;
        
        // Show processing screen without closing UI or resetting NUI focus
        this.showPaymentProcessingScreen();
    },
    
    // New method to show payment processing screen
    showPaymentProcessingScreen() {
        // Update payment flow state
        this.paymentFlow.currentScreen = 'payment-processing';
        
        // Get shop main container
        const shopMain = document.querySelector('.shop-main');
        
        // Replace with payment processing screen
        shopMain.innerHTML = `
            <div class="payment-processing-screen">
                <div class="payment-loader"></div>
                <h2>Processing Payment</h2>
                <p>Please wait while we process your payment...</p>
            </div>
        `;
        
        // Update the shop title
        document.querySelector('#shopping-ui .titlebar-title').textContent = 'Processing Payment';
        
        // Process the payment after a short delay (simulating network request)
        this.paymentFlow.processingTimeout = setTimeout(() => {
            this.processPayment();
        }, 2000);
    },
    
    // New method to process payment
    processPayment() {
        // Calculate total
        const total = state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        
        // Get selected payment method
        const paymentMethod = this.paymentFlow.selectedMethod;
        
        // Prepare checkout data
        const checkoutData = {
            items: state.cart,
            total: total,
            paymentMethod: paymentMethod
        };
        
        console.log("Processing payment - maintaining NUI focus");
        
        // Always show the processing screen for at least 1.5 seconds
        // to prevent UI flashing and improve user experience
        const minProcessingTime = 1500;
        const startTime = Date.now();
        
        // Send checkout data to server WITHOUT closing UI or resetting NUI focus
        // Use a custom endpoint that doesn't imply closing
        fetch(`https://${GetParentResourceName()}/shopCheckout`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(checkoutData)
        })
        .then(() => {
            // Always show success screen after processing
            // The server will handle the actual success/failure via notifications
            // Ensure we've displayed the processing screen for at least the minimum time
            const elapsed = Date.now() - startTime;
            const remainingTime = Math.max(0, minProcessingTime - elapsed);
            
            console.log(`Payment processed - transitioning to success screen in ${remainingTime}ms`);
            setTimeout(() => this.showPaymentSuccessScreen(), remainingTime);
        })
        .catch(error => {
            console.error('Error processing payment:', error);
            
            // Wait the minimum processing time before showing failure
            const elapsed = Date.now() - startTime;
            const remainingTime = Math.max(0, minProcessingTime - elapsed);
            
            console.log(`Payment failed - transitioning to failure screen in ${remainingTime}ms`);
            setTimeout(() => this.showPaymentFailureScreen(), remainingTime);
        });
    },
    
    // Method to show payment success screen
    showPaymentSuccessScreen() {
        // Update payment flow state
        this.paymentFlow.currentScreen = 'payment-success';
        
        // Get shop main container
        const shopMain = document.querySelector('.shop-main');
        
        // Calculate total
        const total = state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        const paymentMethod = this.paymentFlow.selectedMethod;
        
        // Get tax information
        fetch(`https://${GetParentResourceName()}/getTaxRates`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        })
        .then(response => response.json())
        .then(taxData => {
            // Calculate tax amount if applicable
            let taxRate = 0;
            let taxAmount = 0;
            let taxMessage = '';
            
            if (paymentMethod && taxData && taxData[paymentMethod] && taxData[paymentMethod] !== false) {
                taxRate = parseFloat(taxData[paymentMethod]);
                taxAmount = Math.floor(total * (taxRate / 100));
                taxMessage = `<p>Including ${taxRate}% VAT: $${taxAmount.toLocaleString()}</p>`;
            }
            
            const finalTotal = total + taxAmount;
            
            // Replace with payment success screen
            shopMain.innerHTML = `
                <div class="payment-result-screen payment-success">
                    <div class="payment-result-icon">✅</div>
                    <h2>Payment Successful</h2>
                    <p>Your payment of $${finalTotal.toLocaleString()} has been processed successfully.</p>
                    ${taxMessage}
                    <p>Thank you for your purchase!</p>
                    <div class="payment-actions">
                        <button class="button submit" id="continue-shopping-btn">Continue Shopping</button>
                        <button class="button cancel" id="exit-shopping-btn">Exit</button>
                    </div>
                </div>
            `;
            
            // Add event listeners for buttons
            document.getElementById('continue-shopping-btn').addEventListener('click', () => {
                // Clear the cart, this purchase is complete
                state.cart = [];
                
                // Important: The money has been spent, so any cached balance data should be cleared
                // This ensures that future checkout attempts will fetch fresh balance data
                this.originalShopMain = null; // Force complete rebuild of shop UI
                
                console.log("Payment successful - returning to shop to enable new purchase");
                
                // Signal that this purchase is complete
                this.paymentFlow.purchaseComplete = true;
                
                // Return to the shop for a new shopping experience
                this.returnToShop();
                
                // Show success notification
                notifications.create({
                    type: 'success',
                    title: 'Purchase Complete',
                    message: 'Your purchase was successful!',
                    duration: 3000
                });
            });
            
            document.getElementById('exit-shopping-btn').addEventListener('click', () => {
                this.exitShopping();
            });
        })
        .catch(error => {
            console.error('Error fetching tax rates:', error);
            
            // Fallback to showing success screen without tax info
            shopMain.innerHTML = `
                <div class="payment-result-screen payment-success">
                    <div class="payment-result-icon">✅</div>
                    <h2>Payment Successful</h2>
                    <p>Your payment of $${total.toLocaleString()} has been processed successfully.</p>
                    <p>Thank you for your purchase!</p>
                    <div class="payment-actions">
                        <button class="button submit" id="continue-shopping-btn">Continue Shopping</button>
                        <button class="button cancel" id="exit-shopping-btn">Exit</button>
                    </div>
                </div>
            `;
            
            // Add event listeners for buttons
            document.getElementById('continue-shopping-btn').addEventListener('click', () => {
                state.cart = [];
                this.originalShopMain = null;
                this.paymentFlow.purchaseComplete = true;
                this.returnToShop();
                
                notifications.create({
                    type: 'success',
                    title: 'Purchase Complete',
                    message: 'Your purchase was successful!',
                    duration: 3000
                });
            });
            
            document.getElementById('exit-shopping-btn').addEventListener('click', () => {
                this.exitShopping();
            });
        });
        
        // Update the shop title
        document.querySelector('#shopping-ui .titlebar-title').textContent = 'Payment Successful';
    },
    
    // New method to show payment failure screen
    showPaymentFailureScreen() {
        // Update payment flow state
        this.paymentFlow.currentScreen = 'payment-failure';
        
        // Get shop main container
        const shopMain = document.querySelector('.shop-main');
        
        // Calculate total
        const total = state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
        
        // Replace with payment failure screen
        shopMain.innerHTML = `
            <div class="payment-result-screen payment-failure">
                <div class="payment-result-icon">❌</div>
                <h2>Payment Failed</h2>
                <p>We couldn't process your payment of $${total.toLocaleString()}.</p>
                <p>Reason: Insufficient funds.</p>
                <div class="payment-actions">
                    <button class="button submit" id="try-another-method-btn">Try Another Method</button>
                    <button class="button" id="continue-shopping-failure-btn">Continue Shopping</button>
                    <button class="button cancel" id="exit-shopping-failure-btn">Exit</button>
                </div>
            </div>
        `;
        
        // Update the shop title
        document.querySelector('#shopping-ui .titlebar-title').textContent = 'Payment Failed';
        
        // Add event listeners for buttons
        document.getElementById('try-another-method-btn').addEventListener('click', () => {
            this.showPaymentMethodScreen();
        });
        
        document.getElementById('continue-shopping-failure-btn').addEventListener('click', () => {
            this.returnToShop();
        });
        
        document.getElementById('exit-shopping-failure-btn').addEventListener('click', () => {
            this.exitShopping();
        });
    },
    
    // Method to return to the shop screen
    returnToShop() {
        console.log("Returning to shop main screen - maintaining NUI focus");
        
        // Store if this was a completed purchase
        const wasSuccessfulPurchase = this.paymentFlow.purchaseComplete;
        
        // Update payment flow state
        this.paymentFlow.currentScreen = 'shop';
        this.paymentFlow.selectedMethod = null;
        this.paymentFlow.purchaseComplete = false; // Reset purchase completed flag
        
        // Get shop main container and restore original content
        const shopMain = document.querySelector('.shop-main');
        if (this.originalShopMain) {
            shopMain.innerHTML = this.originalShopMain;
        } else {
            shopMain.innerHTML = `<div class="shop-items-grid" id="shop-items"></div>`;
        }
        
        // Update the shop title back to "Shop"
        document.querySelector('#shopping-ui .titlebar-title').textContent = 'Shop';
        
        // Very important: Repopulate items and reattach event handlers
        if (state.currentCategory) {
            this.selectCategory(state.currentCategory);
        } else if (state.shopItems) {
            this.populateItems(state.shopItems);
        }
        
        // Update cart UI
        this.updateCartUI();
        
        // Re-add event listeners for checkout and clear cart
        document.getElementById('shop-cart-clear').onclick = () => this.clearCart();
        document.getElementById('shop-checkout-btn').onclick = () => this.checkout();
        
        // For successful purchases, explicitly tell the client that 
        // we've returned to shop and are ready for a new purchase
        if (wasSuccessfulPurchase) {
            console.log("Sending shopReadyForNewPurchase event to client after successful purchase");
            fetch(`https://${GetParentResourceName()}/shopReadyForNewPurchase`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            }).catch(error => {
                console.error('Error sending ready event:', error);
            });
        }
    },
    
    // Method to exit shopping completely
    exitShopping() {
        console.log("Explicitly exiting shopping UI and closing NUI focus");
        
        // Clear any running timers
        if (this.paymentFlow.processingTimeout) {
            clearTimeout(this.paymentFlow.processingTimeout);
            this.paymentFlow.processingTimeout = null;
        }
        
        // Reset payment flow state completely
        this.paymentFlow.currentScreen = 'shop';
        this.paymentFlow.selectedMethod = null;
        this.paymentFlow.purchaseComplete = false;
        
        // Clear cart and shop data
        state.cart = [];
        
        // Clear stored shop main content to force rebuild on next open
        this.originalShopMain = null;
        
        // Reset UI elements if they exist (without errors if not)
        try {
            const shopMain = document.querySelector('.shop-main');
            if (shopMain) {
                shopMain.innerHTML = `<div class="shop-items-grid" id="shop-items"></div>`;
            }
        } catch (e) {
            console.log("Couldn't reset shop UI elements:", e);
        }
        
        // Close UI and reset NUI focus - this is the ONLY place
        // where we should be closing the UI and resetting focus
        closeUI();
        
        // Explicitly send close message to ensure NUI focus is reset
        sendNUIMessage('close');
    }
};

// Export functionality to global scope
window.shopEventHandlers = shopEventHandlers;