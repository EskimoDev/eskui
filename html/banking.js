// Banking UI for ESKUI
// Handles banking interface with account info, transaction history, and actions

// Banking UI event handlers
const bankingEventHandlers = {
    // Main banking UI display
    showBanking(data) {
        console.log('Processing showBanking event', data);
        state.currentUI = 'banking';
        ui.show('banking-ui');
        
        // Set bank title and account holder name
        if (data.bankName) {
            document.querySelector('#banking-ui .titlebar-title span').textContent = data.bankName;
        }
        
        if (data.accountHolder) {
            document.getElementById('account-holder-name').textContent = data.accountHolder;
        }
        
        if (data.accountNumber) {
            document.getElementById('account-number').textContent = data.accountNumber;
        }
        
        // Set balance values
        this.updateBalances(data.cash || 0, data.bank || 0);
        
        // Populate transaction history if available
        if (data.transactions && Array.isArray(data.transactions)) {
            this.populateTransactions(data.transactions);
        } else {
            // Populate with sample data for demonstration
            this.populateTransactions([
                { type: 'deposit', amount: 2500, date: 'Today, 2:30 PM', description: 'Salary Deposit', category: 'income' },
                { type: 'withdraw', amount: 350, date: 'Today, 10:15 AM', description: 'ATM Withdrawal', category: 'cash' },
                { type: 'transfer', amount: 500, date: 'Yesterday, 6:45 PM', description: 'Transfer to John Doe', category: 'transfer' },
                { type: 'deposit', amount: 150, date: 'Yesterday, 2:20 PM', description: 'Refund - Store Purchase', category: 'refund' },
                { type: 'withdraw', amount: 75, date: '2 days ago', description: 'Coffee Shop', category: 'food' }
            ]);
        }
        
        // Setup UI event listeners
        this.setupEventListeners();
        
        // Add ESC handler
        ui.addEscapeHandler(() => closeUI());
        
        // Notify that UI is now visible
        notifyUIVisibilityChange(true);
    },
    
    // Update account balances
    updateBalances(cash, bank) {
        // Update individual balance displays
        document.getElementById('cash-balance-display').textContent = `$${this.formatCurrency(cash)}`;
        document.getElementById('checking-balance').textContent = `$${this.formatCurrency(bank)}`;
        
        // Update total balance
        const total = cash + bank;
        document.getElementById('total-balance').textContent = `$${this.formatCurrency(total)}`;
    },
    
    // Populate transaction history
    populateTransactions(transactions) {
        const container = document.getElementById('transaction-history');
        container.innerHTML = '';
        
        if (transactions.length === 0) {
            const emptyState = document.createElement('div');
            emptyState.className = 'transaction-empty';
            emptyState.innerHTML = `
                <div class="transaction-empty-icon">📄</div>
                <div class="transaction-empty-text">No recent transactions</div>
            `;
            container.appendChild(emptyState);
            return;
        }
        
        // Show only the most recent 5 transactions
        const recentTransactions = transactions.slice(0, 5);
        
        recentTransactions.forEach((transaction, index) => {
            const transactionEl = document.createElement('div');
            transactionEl.className = `transaction-item ${transaction.type}`;
            
            // Determine icon based on transaction type
            let icon = '💸';
            if (transaction.type === 'deposit') icon = '📥';
            else if (transaction.type === 'withdraw') icon = '📤';
            else if (transaction.type === 'transfer') icon = '↔️';
            
            // Determine amount prefix and styling
            let amountPrefix = '';
            let amountClass = transaction.type;
            if (transaction.type === 'withdraw' || transaction.type === 'transfer') {
                amountPrefix = '-';
            } else if (transaction.type === 'deposit') {
                amountPrefix = '+';
            }
            
            transactionEl.innerHTML = `
                <div class="transaction-icon">${icon}</div>
                <div class="transaction-details">
                    <div class="transaction-description">${transaction.description}</div>
                    <div class="transaction-date">${transaction.date}</div>
                </div>
                <div class="transaction-amount ${amountClass}">${amountPrefix}$${this.formatCurrency(transaction.amount)}</div>
            `;
            
            container.appendChild(transactionEl);
        });
    },
    
    // Setup event listeners for buttons
    setupEventListeners() {
        // Deposit button
        const depositBtn = document.getElementById('deposit-btn');
        if (depositBtn) {
            depositBtn.onclick = () => {
                this.showActionMenu('deposit');
            };
        }
        
        // Withdraw button
        const withdrawBtn = document.getElementById('withdraw-btn');
        if (withdrawBtn) {
            withdrawBtn.onclick = () => {
                this.showActionMenu('withdraw');
            };
        }
        
        // Transfer button
        const transferBtn = document.getElementById('transfer-btn');
        if (transferBtn) {
            transferBtn.onclick = () => {
                this.showActionMenu('transfer');
            };
        }
        
        // Statement button
        const statementBtn = document.getElementById('statement-btn');
        if (statementBtn) {
            statementBtn.onclick = () => {
                this.showStatement();
            };
        }
        
        // View all transactions button
        const viewAllBtn = document.querySelector('.view-all-btn');
        if (viewAllBtn) {
            viewAllBtn.onclick = () => {
                this.showAllTransactions();
            };
        }
        
        // Close button
        const closeBtn = document.querySelector('#banking-ui .close-button');
        if (closeBtn) {
            closeBtn.onclick = closeUI;
        }
    },
    
    // Show action menu (deposit, withdraw, transfer)
    showActionMenu(action) {
        // Using the existing amount input UI
        let title = 'Enter Amount';
        if (action === 'deposit') title = 'Deposit Cash to Bank';
        else if (action === 'withdraw') title = 'Withdraw from Bank';
        else if (action === 'transfer') title = 'Transfer Amount';
        
        menuHandlers.showAmount(title);
        
        // Override the submit function to handle banking actions
        const originalSubmit = window.submitAmount;
        window.submitAmount = () => {
            const amount = document.getElementById('amount-input').value;
            if (amount && parseInt(amount) > 0) {
                // Close the amount UI
                ui.closeAndSendData('amount-ui', 'bankingAction', {
                    action: action,
                    amount: parseInt(amount)
                });
                
                // Show success notification
                this.showActionNotification(action, amount);
                
                // Reset submitAmount to original function
                window.submitAmount = originalSubmit;
            }
        };
    },
    
    // Show statement (placeholder)
    showStatement() {
        notifications.create({
            type: 'info',
            title: 'Account Statement',
            message: 'Your monthly statement has been generated and will be available shortly.',
            duration: 3000
        });
    },
    
    // Show all transactions (placeholder)
    showAllTransactions() {
        notifications.create({
            type: 'info',
            title: 'Transaction History',
            message: 'Opening detailed transaction history...',
            duration: 2000
        });
    },
    
    // Show notification after banking action
    showActionNotification(action, amount) {
        let message = '';
        let title = '';
        let type = 'success';
        
        if (action === 'deposit') {
            title = 'Deposit Successful';
            message = `Successfully deposited $${this.formatCurrency(amount)} to your checking account.`;
        } else if (action === 'withdraw') {
            title = 'Withdrawal Successful';
            message = `Successfully withdrew $${this.formatCurrency(amount)} from your checking account.`;
        } else if (action === 'transfer') {
            title = 'Transfer Initiated';
            message = `Transfer of $${this.formatCurrency(amount)} has been initiated.`;
        }
        
        notifications.create({
            type: type,
            title: title,
            message: message,
            duration: 4000
        });
    },
    
    // Helper function to format currency with proper commas and decimals
    formatCurrency(number) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(number);
    },
    
    // Helper function to format numbers with commas (legacy support)
    formatNumber(number) {
        return this.formatCurrency(number);
    }
};

// Register banking handlers in window object for script.js to access
window.bankingEventHandlers = bankingEventHandlers; 