local core = require('speed-motion.core')

-- Define the command to open the window
vim.api.nvim_create_user_command(
    'SpeedMotion',
        core.open,
    { nargs = 0, desc = 'Open the main plugin window' }
)

-- Define the command to close the window
vim.api.nvim_create_user_command(
    'SlowMotion',
        core.close,
    { nargs = 0, desc = 'Close the main plugin window' }
)
