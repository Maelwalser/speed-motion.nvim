local main_menu = require('speed-motion.main_menu')
local core = require('speed-motion.core')
local normal_mode = require('speed-motion.normal_mode')

-- Command to open the main menu
vim.api.nvim_create_user_command(
    'SpeedMotion',
    function()
        main_menu.show()
    end,
    { nargs = 0, desc = 'Open Speed Motion main menu' }
)

-- Command to close any active game window
vim.api.nvim_create_user_command(
    'SlowMotion',
    function()
        -- Try to close both modes
        core.close()
        normal_mode.close()
    end,
    { nargs = 0, desc = 'Close any active Speed Motion window' }
)
