local M = {}
local utils = require('speed-motion.utils') -- Import the utility module

-- State variables for the plugin
local window_id = nil
local buffer_id = nil
-- Refactored State Variables for Multi-line support:
local target_lines = {}       -- All lines of the current snippet (table of strings)
local current_line_idx = 1    -- 1-based index of the line the user is currently typing
local target_text = ""        -- The content of the *current* line being typed (string)

local game_status = "READY" -- READY, PLAYING, FINISHED
local EXTMARK_NS = nil -- Extmark Namespace ID

local HL_CORRECT = 'TypingCorrect' -- Green
local HL_ERROR = 'TypingError'-- Red
local HL_REMAINING = 'TypingRemaining' -- Faint white/gray

-- Setup custom highlight groups
vim.cmd('highlight ' .. HL_CORRECT .. ' guifg=#6AA84F') -- Green
vim.cmd('highlight ' .. HL_ERROR .. ' guifg=#CC0000')-- Red
vim.cmd('highlight ' .. HL_REMAINING .. ' guifg=#888888') -- Gray

-- Autocmd Group for cleanup
local AUGROUP = vim.api.nvim_create_augroup("CodeTyperGame", { clear = true })

-- Utility function to handle moving to the next line or finishing the game
local function advance_line_or_finish()
  current_line_idx = current_line_idx + 1 -- Advance line index
  
  if current_line_idx <= #target_lines then
    -- Load the next line as the new target
    target_text = target_lines[current_line_idx]
    
    -- Reset input line content (Line 2) and move cursor
    vim.api.nvim_buf_set_lines(buffer_id, 2, 3, false, { target_text })
    vim.api.nvim_win_set_cursor(window_id, {3, 0})
    
    -- Clear highlights for the new target
    vim.api.nvim_buf_clear_namespace(buffer_id, EXTMARK_NS, 2, 3)

  else
    -- Full Snippet Completion
    game_status = "FINISHED"
    vim.api.nvim_echo({{"Game Complete! Press q to close.", "Title"}}, true, {})
    
    -- Clean up and disable modifications
    vim.api.nvim_del_augroup_by_name("CodeTyperGame")
    vim.api.nvim_buf_set_option(buffer_id, 'modifiable', false)
  end
end

--- Handles input and provides real-time highlighting using Extmarks.
function M.check_input()
  -- Ensure we have a valid namespace and buffer, and game is active
  if not buffer_id or game_status == "FINISHED" or not EXTMARK_NS then return end

  local target_len = #target_text

  -- Get current cursor position - this tells us how many characters the user has typed
  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_col = cursor_pos[2] -- 0-indexed column position

  -- Get user input from line 2 (which may have inserted characters)
  local typed_lines = vim.api.nvim_buf_get_lines(buffer_id, 2, 3, false)
  local current_line_content = typed_lines[1] or ""

  -- The cursor position tells us how many characters have been typed
  -- Limit to target length to prevent overflow
  local typed_len = math.min(cursor_col, target_len)
  local typed_text = string.sub(current_line_content, 1, typed_len)

  -- Calculate remaining text that hasn't been typed yet
  local remaining_text = string.sub(target_text, typed_len + 1)
  local new_line_content = typed_text .. remaining_text

  -- Update buffer with typed characters + remaining target text
  vim.api.nvim_buf_set_lines(buffer_id, 2, 3, false, { new_line_content })

  -- Move cursor to correct position (after the typed text)
  vim.api.nvim_win_set_cursor(window_id, {3, typed_len}) -- Line 3 (0-based line 2)

  -- Clear all previous highlights
  vim.api.nvim_buf_clear_namespace(buffer_id, EXTMARK_NS, 2, 3)

  -- 2. Update Progress and Apply Extmarks
  local has_error = false

  -- Loop over each character in the target text
  for i = 1, target_len do
    local target_char = string.sub(target_text, i, i)

    -- Determine highlight group based on typing progress and correctness
    local hl_group
    if i <= typed_len then
      -- Character has been typed - check if it's correct
      local typed_char = string.sub(typed_text, i, i)
      if target_char == typed_char then
        hl_group = HL_CORRECT
      else
        hl_group = HL_ERROR
        has_error = true
      end
    else
      -- This is the text remaining to be typed
      hl_group = HL_REMAINING
    end

    -- Apply the Extmark to the target line (line 2 of the buffer, 0-based index)
    vim.api.nvim_buf_set_extmark(
      buffer_id, EXTMARK_NS, 2, i - 1, -- Line 2, character index (0-based)
      { end_col = i, hl_group = hl_group }
    )
  end

  -- 3. Check for Line/Snippet Completion
  -- Only advance if all characters are typed AND there are no errors
  if typed_len >= target_len and not has_error then
    -- Line successfully completed. Advance logic.
    advance_line_or_finish()
  end

  -- Update Status Line (now based on character progress, needs refinement for WPM)
  local total_chars = 0
  for _, line in ipairs(target_lines) do total_chars = total_chars + #line end

  -- NOTE: Character progress is complex to calculate accurately across lines
  -- without tracking previous lines. For simplicity, we use Line Progress:
  local progress = math.floor(((current_line_idx - 1) / #target_lines) * 100)
  if game_status == "FINISHED" then progress = 100 end

  vim.api.nvim_buf_set_lines(buffer_id, 0, 1, false, {
    "Code Typer - Line Progress: " .. progress .. "% | Errors: " .. (has_error and "Yes" or "No")
  })
end

--- Creates the full-screen, exclusive window and its associated buffer.
function M.open()
-- Check if the game is already open in a valid window.
if window_id and vim.api.nvim_win_is_valid(window_id) then
 vim.api.nvim_set_current_win(window_id)
 return
end

EXTMARK_NS = vim.api.nvim_create_namespace('CodeTyperExtmarks')

-- 1. Select the random text and update state
target_lines = utils.get_random_target_text()
current_line_idx = 1
target_text = target_lines[1] -- Initialize with the first line
game_status = "PLAYING"

-- 2. Create a new scratch buffer (no window association yet)
buffer_id = vim.api.nvim_create_buf(false, true)

-- Set buffer options for typing interface
vim.api.nvim_buf_set_option(buffer_id, 'buftype', 'nofile')
vim.api.nvim_buf_set_option(buffer_id, 'bufhidden', 'wipe')
vim.api.nvim_buf_set_option(buffer_id, 'swapfile', false)
vim.api.nvim_buf_set_option(buffer_id, 'filetype', 'code_typer')
vim.api.nvim_buf_set_option(buffer_id, 'number', true)
vim.api.nvim_buf_set_option(buffer_id, 'relativenumber', true)
vim.api.nvim_buf_set_option(buffer_id, 'signcolumn', 'yes')
vim.api.nvim_buf_set_option(buffer_id, 'wrap', false)

-- 3. Open the exclusive full-screen window
vim.cmd('enew') -- Opens a new window with a new, temporary buffer.
vim.cmd('only') -- Closes all other windows, maximizing the current one.

-- Get the ID of the newly maximized window
window_id = vim.api.nvim_get_current_win()

-- Set the buffer of the new window to be our structured scratch buffer.
vim.api.nvim_win_set_buf(window_id, buffer_id)

-- 4. Initial content setup:
-- The target lines are placed at line 2. We only place the *current* line (target_text) for typing.
vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {
  "Code Typer - Line Progress: 0% | Errors: No", -- Line 0: Status Line
  "--------------------------------------------------------------------------------", -- Line 1: Separator
  target_text, -- Line 2: Current Target/User Input Line (Initial content)
  "Press 'i' to start typing. Use Vim motions in Normal Mode to correct mistakes.", -- Line 3: Instructions
})

-- Make the input line modifiable, and move cursor there
vim.api.nvim_buf_set_option(buffer_id, 'modifiable', true)
vim.api.nvim_win_set_cursor(window_id, {3, 0}) -- Cursor on line 3 (0-based index 2), column 0

-- 5. Set up Autocommand for continuous input checking
vim.api.nvim_create_autocmd("TextChangedI", {
  group = AUGROUP,
  buffer = buffer_id,
  callback = M.check_input,
  desc = "Real-time input checking for typing game",
})

-- 6. Enable Vim Motions but prevent destructive actions on the game buffer
local destructive_maps = { 'd', 'c', 'y', 'x', '>', '<' }
for _, key in ipairs(destructive_maps) do
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', key, '<Nop>', { silent = true, noremap = true })
end

-- Map  <C-c> to close
local close_cmd = ':lua require("your_plugin.core").close()<CR>'
vim.api.nvim_buf_set_keymap(buffer_id, 'n', '<C-c>', close_cmd, { noremap = true, silent = true })

vim.api.nvim_set_current_win(window_id)

-- Call check_input once to set initial highlights
M.check_input()
end

--- Closes the window and cleans up the resources.
function M.close()
if window_id and vim.api.nvim_win_is_valid(window_id) then
 vim.api.nvim_win_close(window_id, true)

 -- Clean up the Autocmd group when closing the window
 vim.api.nvim_del_augroup_by_name("CodeTyperGame")

 window_id = nil
 buffer_id = nil
 EXTMARK_NS = nil -- Clear the namespace reference on close
 target_lines = {}
 current_line_idx = 1
 target_text = ""
end
end

-- Export the module
return M
