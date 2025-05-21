Config = {}

-- Framework settings
Config.Framework = 'esx' -- Options: 'esx', 'qbcore', 'standalone'

-- Debug mode
Config.Debug = true -- Set to false in production

-- Money settings
Config.MoneyTypes = {
    cash = "cash",
    bank = "bank"
}
Config.DefaultMoneyType = Config.MoneyTypes.cash -- Which account to use by default