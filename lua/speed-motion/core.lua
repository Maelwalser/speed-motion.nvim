local M = {}

-- State variables for the plugin
local window_id = nil
local buffer_id = nil
local target_text = "The quick brown fox jumps over the lazy dog."
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

--- Handles input and provides real-time highlighting using Extmarks.
function M.check_input()
  -- Ensure we have a valid namespace and buffer
  if not buffer_id or game_status == "FINISHED" or not EXTMARK_NS then return end

  -- 1. Get user input (now reading line 2)
  local typed_lines = vim.api.nvim_buf_get_lines(buffer_id, 2, 3, false)
  local current_line_content = typed_lines[1] or ""

  local target_len = #target_text
  local current_index = #current_line_content

  -- Determine the actual correctly typed prefix and first error
  local typed_text = ""
  local has_error = false
  local actual_typed_length = current_index

  for i = 1, current_index do
    local target_char = string.sub(target_text, i, i)
    local typed_char = string.sub(current_line_content, i, i)
   
    if target_char == typed_char and not has_error then
      typed_text = typed_text .. typed_char
    else
      has_error = true
      -- Set the length to the last correct character's position
      actual_typed_length = i - 1
      break
    end
  end
    
    -- Recalculate based on the actual correct length
    current_index = actual_typed_length
    typed_text = string.sub(current_line_content, 1, current_index)
    
  -- Determine the full content to display (typed + remaining target)
  local remaining_text = string.sub(target_text, current_index + 1)
  local new_line_content = typed_text .. remaining_text
 
  -- Reset the buffer line content to prevent shift and display remaining text correctly
  vim.api.nvim_buf_set_lines(buffer_id, 2, 3, false, { new_line_content })
 
  -- Move the cursor back to the correct position (after the typed text)
  vim.api.nvim_win_set_cursor(window_id, {3, current_index}) -- Line 3 (0-based)

  -- Clear all previous highlights
  vim.api.nvim_buf_clear_namespace(buffer_id, EXTMARK_NS, 2, 3)

  -- 2. Update Progress and Apply Extmarks
  has_error = false -- Reset for highlighting loop

  -- We now loop over the target text length
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
      -- This is the text remaining to be typed 
      hl_group = HL_REMAINING
    end
   
    -- Apply the Extmark to the target line (line 2 of the buffer, 0-based index)
    vim.api.nvim_buf_set_extmark(
      buffer_id, EXTMARK_NS, 2, i - 1, -- Line 2, character index (0-based)
      { end_col = i, hl_group = hl_group }
    )
  end
 
  -- 3. Check for Game Completion
  if current_index >= target_len then
    if typed_text == target_text then
      game_status = "FINISHED"
      vim.api.nvim_echo({{"Game Complete! Press q to close.", "Title"}}, true, {})
      -- Disable autocmd and set buffer to read-only after completion
      vim.api.nvim_del_augroup_by_name("CodeTyperGame")
      vim.api.nvim_buf_set_option(buffer_id, 'modifiable', false)
    else
      -- Prevent over-typing (already handled by the logic above, but safety cap)
      -- We only allow typing up to the target length
    end
  end

  -- Update Status Line
  local progress = math.floor((current_index / target_len) * 100)
  vim.api.nvim_buf_set_lines(buffer_id, 0, 1, false, {
    "Code Typer - Progress: " .. progress .. "% | Errors: " .. (has_error and "Yes" or "No")
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

-- Reset game state
game_status = "PLAYING"

-- 1. Create a new scratch buffer (no window association yet)
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

-- 2. Open the exclusive full-screen window
vim.cmd('enew') -- Opens a new window with a new, temporary buffer.
vim.cmd('only') -- Closes all other windows, maximizing the current one.

-- Get the ID of the newly maximized window
window_id = vim.api.nvim_get_current_win()

-- Set the buffer of the new window to be our structured scratch buffer.
vim.api.nvim_win_set_buf(window_id, buffer_id)

-- 3. Initial content setup:
vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {
 "Speed Motion - Progress: 0% | Errors: No", -- Line 0: Status Line
   "--------------------------------------------------------------------------------", -- Line 1: Separator
    target_text, -- Line 2: Target Text/User Input Line
    "Press 'i' to start typing. Use Vim motions in Normal Mode to correct mistakes.", -- Line 3: Instructions
})

-- Make the input line modifiable, and move cursor there
vim.api.nvim_buf_set_option(buffer_id, 'modifiable', true)
vim.api.nvim_win_set_cursor(window_id, {3, 0}) -- Cursor on line 3 (0-based index 2), column 0

-- 4. Set up Autocommand for continuous input checking
vim.api.nvim_create_autocmd("TextChangedI", {
 group = AUGROUP,
 buffer = buffer_id,
 callback = M.check_input,
 desc = "Real-time input checking for typing game",
})

-- 5. Enable Vim Motions but prevent destructive actions on the game buffer
local destructive_maps = { 'd', 'c', 'y', 'x', '>', '<' }
for _, key in ipairs(destructive_maps) do
 vim.api.nvim_buf_set_keymap(buffer_id, 'n', key, '<Nop>', { silent = true, noremap = true })
end

-- Map <C-c> to close
local close_cmd = ':lua require("code-typer.core").close()<CR>'
vim.api.nvim_buf_set_keymap(buffer_id, 'n', '<C-c>', close_cmd, { noremap = true, silent = true })

vim.api.nvim_set_current_win(window_id)
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
end
end

-- Export the module
return M
