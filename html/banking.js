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
        
        // Store the values for later use
        this.currentCash = cash;
        this.currentBank = bank;
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
                this.showTransferUI();
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
        
        // Transfer UI event listeners
        this.setupTransferEventListeners();
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
    
    // Show the transfer UI
    showTransferUI() {
        // Hide banking UI and show transfer UI
        ui.hide('banking-ui');
        state.currentUI = 'transfer';
        ui.show('transfer-ui');
        
        // Update the account balance display
        document.getElementById('transfer-from-balance').textContent = `$${this.formatCurrency(this.currentBank || 0)}`;
        
        // Reset the transfer form
        document.getElementById('transfer-recipient-id').value = '';
        document.getElementById('transfer-amount').value = '';
        document.getElementById('transfer-description').value = '';
        
        // Ensure the main transfer form is visible (not the success screen)
        document.querySelector('.transfer-container .transfer-success').style.display = 'none';
        document.querySelector('.transfer-container .transfer-form').style.display = 'flex';
        document.querySelector('.transfer-container .transfer-header').style.display = 'flex';
        document.querySelector('.transfer-container .transfer-actions').style.display = 'flex';
        
        // Add ESC handler for transfer UI
        ui.addEscapeHandler(() => this.closeTransferUI());
        
        // Notify that transfer UI is now visible
        notifyUIVisibilityChange(true);
    },
    
    // Setup event listeners for the transfer UI
    setupTransferEventListeners() {
        // Cancel button
        const cancelBtn = document.getElementById('transfer-cancel-btn');
        if (cancelBtn) {
            cancelBtn.onclick = () => {
                this.closeTransferUI();
            };
        }
        
        // Confirm button
        const confirmBtn = document.getElementById('transfer-confirm-btn');
        if (confirmBtn) {
            confirmBtn.onclick = () => {
                this.processTransfer();
            };
        }
        
        // Done button (on success screen)
        const doneBtn = document.getElementById('transfer-done-btn');
        if (doneBtn) {
            doneBtn.onclick = () => {
                this.closeTransferUI();
            };
        }
        
        // Close button
        const closeBtn = document.querySelector('#transfer-ui .close-button');
        if (closeBtn) {
            closeBtn.onclick = () => {
                this.closeTransferUI();
            };
        }
    },
    
    // Process the transfer
    processTransfer() {
        const recipientId = document.getElementById('transfer-recipient-id').value;
        const amount = document.getElementById('transfer-amount').value;
        const description = document.getElementById('transfer-description').value || 'Transfer';
        
        // Basic validation
        if (!recipientId || isNaN(recipientId) || parseInt(recipientId) <= 0) {
            this.showTransferError('Please enter a valid recipient ID');
            return;
        }
        
        if (!amount || isNaN(amount) || parseFloat(amount) <= 0) {
            this.showTransferError('Please enter a valid amount');
            return;
        }
        
        const transferAmount = parseFloat(amount);
        
        // Check if player has enough money
        if (transferAmount > (this.currentBank || 0)) {
            this.showTransferError('You do not have enough money in your account');
            return;
        }
        
        // Format the data
        const transferData = {
            action: 'transfer',
            recipientId: parseInt(recipientId),
            amount: transferAmount,
            description: description
        };
        
        // In a real implementation, this would send the data to the server
        console.log('Transfer data:', transferData);
        
        // For demonstration, show success screen
        this.showTransferSuccess(transferData);
        
        // In a real implementation, you would wait for server response before showing success
        // ui.closeAndSendData('transfer-ui', 'bankingTransfer', transferData);
    },
    
    // Show transfer success screen
    showTransferSuccess(data) {
        // Hide the form and show success screen
        document.querySelector('.transfer-container .transfer-form').style.display = 'none';
        document.querySelector('.transfer-container .transfer-header').style.display = 'none';
        document.querySelector('.transfer-container .transfer-actions').style.display = 'none';
        document.querySelector('.transfer-container .transfer-success').style.display = 'flex';
        
        // Update success screen data
        document.getElementById('success-amount').textContent = this.formatCurrency(data.amount);
        document.getElementById('success-recipient').textContent = data.recipientId;
        
        // Set current date/time
        const now = new Date();
        const formattedTime = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        document.getElementById('success-date').textContent = `Today, ${formattedTime}`;
        
        // Update local balances for display
        if (this.currentBank) {
            this.currentBank -= data.amount;
        }
        
        // Simulated transaction for the history
        const newTransaction = {
            type: 'transfer',
            amount: data.amount,
            date: `Today, ${formattedTime}`,
            description: `Transfer to ID: ${data.recipientId}`,
            category: 'transfer'
        };
        
        // Store the transaction for when we return to banking UI
        if (!this.pendingTransactions) this.pendingTransactions = [];
        this.pendingTransactions.unshift(newTransaction);
    },
    
    // Show transfer error notification
    showTransferError(message) {
        notifications.create({
            type: 'error',
            title: 'Transfer Failed',
            message: message,
            duration: 4000
        });
    },
    
    // Close the transfer UI and return to banking
    closeTransferUI() {
        ui.hide('transfer-ui');
        state.currentUI = 'banking';
        ui.show('banking-ui');
        
        // If we have pending transactions, update the transaction history
        if (this.pendingTransactions && this.pendingTransactions.length > 0) {
            this.populateTransactions(this.pendingTransactions);
            this.pendingTransactions = [];
            
            // Update balances
            this.updateBalances(this.currentCash || 0, this.currentBank || 0);
        }
        
        // Add ESC handler for banking
        ui.addEscapeHandler(() => closeUI());
        
        // Notify that banking UI is now visible
        notifyUIVisibilityChange(true);
    },
    
    // Show statement (placeholder)
    showStatement() {
        // Hide banking UI and show statement UI
        ui.hide('banking-ui');
        state.currentUI = 'statement';
        ui.show('statement-ui');
        
        // Populate statement with data
        this.populateStatement();
        
        // Setup statement event listeners
        this.setupStatementEventListeners();
        
        // Add ESC handler for statement
        ui.addEscapeHandler(() => closeUI());
        
        // Notify that statement UI is now visible
        notifyUIVisibilityChange(true);
    },
    
    // Populate statement with transaction data
    populateStatement() {
        // Sample transaction data for the statement
        const statementTransactions = [
            { date: '2024-12-31', description: 'Year-end Bonus', type: 'deposit', amount: 5000.00, balance: 15420.50 },
            { date: '2024-12-30', description: 'Grocery Store', type: 'withdraw', amount: 125.75, balance: 10420.50 },
            { date: '2024-12-29', description: 'Gas Station', type: 'withdraw', amount: 65.00, balance: 10546.25 },
            { date: '2024-12-28', description: 'Salary Deposit', type: 'deposit', amount: 2500.00, balance: 10611.25 },
            { date: '2024-12-27', description: 'Transfer to Savings', type: 'transfer', amount: 500.00, balance: 8111.25 },
            { date: '2024-12-26', description: 'Restaurant', type: 'withdraw', amount: 85.50, balance: 8611.25 },
            { date: '2024-12-25', description: 'Christmas Gift', type: 'withdraw', amount: 200.00, balance: 8696.75 },
            { date: '2024-12-24', description: 'ATM Withdrawal', type: 'withdraw', amount: 100.00, balance: 8896.75 },
            { date: '2024-12-23', description: 'Freelance Payment', type: 'deposit', amount: 750.00, balance: 8996.75 },
            { date: '2024-12-22', description: 'Coffee Shop', type: 'withdraw', amount: 12.50, balance: 8246.75 },
            { date: '2024-12-21', description: 'Online Purchase', type: 'withdraw', amount: 89.99, balance: 8259.25 },
            { date: '2024-12-20', description: 'Rent Payment', type: 'transfer', amount: 1200.00, balance: 8349.24 },
            { date: '2024-12-19', description: 'Utility Bill', type: 'withdraw', amount: 150.00, balance: 9549.24 },
            { date: '2024-12-18', description: 'Refund - Store Return', type: 'deposit', amount: 45.75, balance: 9699.24 },
            { date: '2024-12-17', description: 'Pharmacy', type: 'withdraw', amount: 25.50, balance: 9653.49 },
            { date: '2024-12-16', description: 'Salary Deposit', type: 'deposit', amount: 2500.00, balance: 9678.99 },
            { date: '2024-12-15', description: 'Movie Theater', type: 'withdraw', amount: 35.00, balance: 7178.99 },
            { date: '2024-12-14', description: 'Gas Station', type: 'withdraw', amount: 70.00, balance: 7213.99 },
            { date: '2024-12-13', description: 'Grocery Store', type: 'withdraw', amount: 145.25, balance: 7283.99 },
            { date: '2024-12-12', description: 'ATM Withdrawal', type: 'withdraw', amount: 200.00, balance: 7429.24 }
        ];
        
        this.populateStatementTable(statementTransactions);
        this.setupStatementFilters(statementTransactions);
    },
    
    // Populate the statement transaction table
    populateStatementTable(transactions) {
        const tbody = document.getElementById('statement-transactions-body');
        tbody.innerHTML = '';
        
        transactions.forEach(transaction => {
            const row = document.createElement('tr');
            
            // Format date
            const date = new Date(transaction.date);
            const formattedDate = date.toLocaleDateString('en-US', { 
                month: 'short', 
                day: 'numeric', 
                year: 'numeric' 
            });
            
            // Determine amount class and prefix
            let amountClass = '';
            let amountPrefix = '';
            if (transaction.type === 'deposit') {
                amountClass = 'amount-positive';
                amountPrefix = '+';
            } else {
                amountClass = 'amount-negative';
                amountPrefix = '-';
            }
            
            row.innerHTML = `
                <td>${formattedDate}</td>
                <td>${transaction.description}</td>
                <td><span class="transaction-type ${transaction.type}">${transaction.type}</span></td>
                <td class="${amountClass}">${amountPrefix}$${this.formatCurrency(transaction.amount)}</td>
                <td>$${this.formatCurrency(transaction.balance)}</td>
            `;
            
            tbody.appendChild(row);
        });
    },
    
    // Setup statement filters and sorting
    setupStatementFilters(transactions) {
        const typeFilter = document.getElementById('transaction-type-filter');
        const sortFilter = document.getElementById('transaction-sort');
        
        if (typeFilter) {
            typeFilter.addEventListener('change', () => {
                this.filterAndSortTransactions(transactions);
            });
        }
        
        if (sortFilter) {
            sortFilter.addEventListener('change', () => {
                this.filterAndSortTransactions(transactions);
            });
        }
    },
    
    // Filter and sort transactions based on user selection
    filterAndSortTransactions(transactions) {
        const typeFilter = document.getElementById('transaction-type-filter');
        const sortFilter = document.getElementById('transaction-sort');
        
        let filteredTransactions = [...transactions];
        
        // Apply type filter
        if (typeFilter && typeFilter.value !== 'all') {
            filteredTransactions = filteredTransactions.filter(t => t.type === typeFilter.value);
        }
        
        // Apply sorting
        if (sortFilter) {
            switch (sortFilter.value) {
                case 'date-desc':
                    filteredTransactions.sort((a, b) => new Date(b.date) - new Date(a.date));
                    break;
                case 'date-asc':
                    filteredTransactions.sort((a, b) => new Date(a.date) - new Date(b.date));
                    break;
                case 'amount-desc':
                    filteredTransactions.sort((a, b) => b.amount - a.amount);
                    break;
                case 'amount-asc':
                    filteredTransactions.sort((a, b) => a.amount - b.amount);
                    break;
            }
        }
        
        this.populateStatementTable(filteredTransactions);
    },
    
    // Setup statement event listeners
    setupStatementEventListeners() {
        // Download PDF button
        const downloadBtn = document.querySelector('.statement-btn.download');
        if (downloadBtn) {
            downloadBtn.onclick = () => {
                notifications.create({
                    type: 'info',
                    title: 'Download Started',
                    message: 'Your statement PDF is being generated and will download shortly.',
                    duration: 3000
                });
            };
        }
        
        // Print button
        const printBtn = document.querySelector('.statement-btn.print');
        if (printBtn) {
            printBtn.onclick = () => {
                notifications.create({
                    type: 'info',
                    title: 'Print Dialog',
                    message: 'Opening print dialog for your statement.',
                    duration: 2000
                });
            };
        }
        
        // Close button
        const closeBtn = document.querySelector('#statement-ui .close-button');
        if (closeBtn) {
            closeBtn.onclick = closeUI;
        }
    },
    
    // Return to banking from statement
    returnToBanking() {
        ui.hide('statement-ui');
        state.currentUI = 'banking';
        ui.show('banking-ui');
        
        // Add ESC handler for banking
        ui.addEscapeHandler(() => closeUI());
        
        // Notify that banking UI is now visible
        notifyUIVisibilityChange(true);
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