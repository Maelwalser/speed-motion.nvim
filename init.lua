local core = require('code-typer.core')

-- Define the command to open the window
vim.api.nvim_create_user_command(
    'OpenMyPluginWindow',
        core.open,
    { nargs = 0, desc = 'Open the main plugin window' }
)

-- Define the command to close the window
vim.api.nvim_create_user_command(
    'CloseMyPluginWindow',
        core.close,
    { nargs = 0, desc = 'Close the main plugin window' }
)
