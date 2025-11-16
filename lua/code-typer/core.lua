-- The main table for your plugin's logic
local M = {}

-- State variables for the plugin
local window_id = nil
local buffer_id = nil
local target_text = "The quick brown fox jumps over the lazy dog."
local game_status = "READY" -- READY, PLAYING, FINISHED
local EXTMARK_NS = nil -- NEW: Variable to hold the unique Extmark Namespace ID

-- Define highlight groups (you need these groups defined in your Neovim colorscheme, but these defaults are usually fine)
local HL_CORRECT = 'TypingCorrect' -- Green
local HL_ERROR = 'TypingError'     -- Red
local HL_REMAINING = 'TypingRemaining' -- Faint white/gray

-- Setup custom highlight groups if they don't exist (optional, but robust)
vim.cmd('highlight ' .. HL_CORRECT .. ' guifg=#6AA84F') -- Green
vim.cmd('highlight ' .. HL_ERROR .. ' guifg=#CC0000')   -- Red
vim.cmd('highlight ' .. HL_REMAINING .. ' guifg=#888888') -- Gray

--- Configuration for the floating window
local WINDOW_CONFIG = {
    relative = 'editor',
    width = 80,
    height = 5, -- Very small window focusing only on text
    row = math.floor((vim.o.lines - 5) / 2),
    col = math.floor((vim.o.columns - 80) / 2),
    style = 'minimal',
    border = 'rounded',
    focusable = true,
}

-- Autocmd Group for cleanup
local AUGROUP = vim.api.nvim_create_augroup("CodeTyperGame", { clear = true })

--- Handles input and provides real-time highlighting using Extmarks.
function M.check_input()
    -- Ensure we have a valid namespace and buffer
    if not buffer_id or game_status == "FINISHED" or not EXTMARK_NS then return end

    -- 1. Get user input (always line 3, as the buffer is short)
    local typed_lines = vim.api.nvim_buf_get_lines(buffer_id, 3, 4, false)
    local typed_text = typed_lines[1] or ""
    
    local current_index = #typed_text
    local target_len = #target_text

    -- Clear all previous highlights (Extmarks on the target line, line 2)
    -- FIX: Using the created namespace ID (EXTMARK_NS) instead of 0
    vim.api.nvim_buf_clear_namespace(buffer_id, EXTMARK_NS, 2, 3)

    -- 2. Update Progress and Apply Extmarks
    local has_error = false
    
    for i = 1, target_len do
        local target_char = string.sub(target_text, i, i)
        local typed_char = string.sub(typed_text, i, i)
        
        -- Determine highlight group based on typing progress and correctness
        local hl_group
        if i <= current_index then
            if target_char == typed_char and not has_error then
                hl_group = HL_CORRECT
            else
                hl_group = HL_ERROR
                has_error = true -- Lock into error state if one is found
            end
        else
            hl_group = HL_REMAINING
        end
        
        -- Apply the Extmark to the target line (line 2 of the buffer)
        -- FIX: Using the created namespace ID (EXTMARK_NS) instead of 0
        vim.api.nvim_buf_set_extmark(
            buffer_id, EXTMARK_NS, 2, i - 1, -- Line 2, character index (0-based)
            { end_col = i, hl_group = hl_group }
        )
    end
    
    -- 3. Update Status Line (Buffer line 0)
    local progress = math.floor((current_index / target_len) * 100)
    vim.api.nvim_buf_set_lines(buffer_id, 0, 1, false, {
        "Code Typer - Progress: " .. progress .. "% | Errors: " .. (has_error and "Yes" or "No")
    })

    -- 4. Check for Game Completion
    if current_index >= target_len then
        if typed_text == target_text then
            game_status = "FINISHED"
            vim.api.nvim_echo({{"Game Complete! Press q to close.", "Title"}}, true, {})
            -- Disable autocmd and set buffer to read-only after completion
            vim.api.nvim_del_augroup_by_name("CodeTyperGame")
            vim.api.nvim_buf_set_option(buffer_id, 'modifiable', false)
        else
            -- Prevent over-typing (if user types past the target length)
            vim.api.nvim_buf_set_lines(buffer_id, 3, 4, false, {string.sub(typed_text, 1, target_len)})
        end
    end
end

--- Creates the floating window and its associated buffer.
function M.open()
    if window_id and vim.api.nvim_win_is_valid(window_id) then
        vim.api.nvim_set_current_win(window_id)
        return
    end
    
    -- CRITICAL FIX: Create the unique Extmark namespace ID for the plugin
    EXTMARK_NS = vim.api.nvim_create_namespace('CodeTyperExtmarks')

    -- Reset game state
    game_status = "PLAYING" 

    -- 1. Create a new scratch buffer
    buffer_id = vim.api.nvim_create_buf(false, true)

    -- Set buffer options for typing interface
    vim.api.nvim_buf_set_option(buffer_id, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buffer_id, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buffer_id, 'swapfile', false)
    vim.api.nvim_buf_set_option(buffer_id, 'filetype', 'code_typer')
    vim.api.nvim_buf_set_option(buffer_id, 'number', false)
    vim.api.nvim_buf_set_option(buffer_id, 'relativenumber', false)
    vim.api.nvim_buf_set_option(buffer_id, 'signcolumn', 'no')
    vim.api.nvim_buf_set_option(buffer_id, 'wrap', false)
    
    -- 2. Open the floating window
    window_id = vim.api.nvim_open_win(buffer_id, true, WINDOW_CONFIG)

    -- 3. Initial content setup: 
    -- Line 0: Status Line
    -- Line 1: Separator
    -- Line 2: Target Text
    -- Line 3: User Input (Start typing here)
    vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {
        "Code Typer - Progress: 0% | Errors: No",
        "--------------------------------------------------------------------------------",
        target_text,
        "", -- The line the user will type on (Line 3)
        "Press 'i' to start typing. Use Vim motions in Normal Mode to correct mistakes.",
    })
    
    -- Make Target Text line read-only (optional)
    vim.api.nvim_buf_set_option(buffer_id, 'readonly', true)
    
    -- Make only the user input line modifiable, and move cursor there
    vim.api.nvim_buf_set_option(buffer_id, 'modifiable', true)
    vim.api.nvim_win_set_cursor(window_id, {4, 0}) -- Cursor on line 4 (0-based)
    
    -- 4. Set up Autocommand for continuous input checking
    vim.api.nvim_create_autocmd("TextChangedI", {
        group = AUGROUP,
        buffer = buffer_id,
        callback = M.check_input,
        desc = "Real-time input checking for typing game",
    })

    -- 5. Enable Vim Motions but prevent destructive actions on the game buffer
    -- This allows j, k, h, l, w, b, 0, $ etc., to work naturally.
    local destructive_maps = { 'd', 'c', 'y', 'x', '>', '<' }
    for _, key in ipairs(destructive_maps) do
        vim.api.nvim_buf_set_keymap(buffer_id, 'n', key, '<Nop>', { silent = true, noremap = true })
    end
    
    -- Map 'q' and <C-c> to close
    local close_cmd = ':lua require("code-typer.core").close()<CR>'
    vim.api.nvim_buf_set_keymap(buffer_id, 'n', '<C-c>', close_cmd, { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'q', close_cmd, { noremap = true, silent = true })

    vim.api.nvim_set_current_win(window_id)
end

--- Closes the floating window and cleans up the resources.
function M.close()
    if window_id and vim.api.nvim_win_is_valid(window_id) then
        vim.api.nvim_win_close(window_id, true)
        
        -- Clean up the Autocmd group when closing the window
        vim.api.nvim_del_augroup_by_name("CodeTyperGame")
        
        window_id = nil
        buffer_id = nil
        EXTMARK_NS = nil -- Clear the namespace reference on close
    end
end

-- Export the module
return M
