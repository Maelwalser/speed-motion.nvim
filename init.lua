local core = require('speed-motion.core')

-- Command to open the language selection menu and start the game
vim.api.nvim_create_user_command(
    'SpeedMotion',
        core.start,
    { nargs = 0, desc = 'Open language selection and start typing game' }
)

-- command to close the window
vim.api.nvim_create_user_command(
    'SlowMotion',
        core.close,
    { nargs = 0, desc = 'Close the main plugin window' }
)
