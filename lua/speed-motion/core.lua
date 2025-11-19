local M = {}
local utils = require('speed-motion.utils')
local menu = require('speed-motion.menu')

-- State variables for the plugin
local window_id = nil
local buffer_id = nil
-- Refactored State Variables for Multi-line support:
local target_lines = {}       -- All lines of the current snippet (table of strings)
local current_line_idx = 1    -- 1-based index of the line the user is currently typing
local target_text = ""        -- The content of the *current* line being typed (string)
local completed_lines = {}    -- Track completion status per line: {[1] = true, [2] = false, ...}
local typed_lengths = {}      -- Track how many characters typed on each line: {[1] = 7, [2] = 0, ...}

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

--- Helper function to update highlights and virtual text for a specific line
local function update_line_display(snippet_line_idx, buffer_line_idx, is_current_line)
  local target_text_for_line = target_lines[snippet_line_idx]
  local target_len = #target_text_for_line

  -- Get what user has typed from buffer
  local buffer_lines = vim.api.nvim_buf_get_lines(buffer_id, buffer_line_idx, buffer_line_idx + 1, false)
  local typed_text = buffer_lines[1] or ""
  local typed_len = #typed_text

  -- Limit typed length to target length
  if typed_len > target_len then
    typed_text = string.sub(typed_text, 1, target_len)
    typed_len = target_len
    vim.api.nvim_buf_set_lines(buffer_id, buffer_line_idx, buffer_line_idx + 1, false, { typed_text })
  end

  -- Clear all extmarks on this line
  vim.api.nvim_buf_clear_namespace(buffer_id, EXTMARK_NS, buffer_line_idx, buffer_line_idx + 1)

  -- Apply character-by-character highlights to typed text
  local has_error = false
  for i = 1, typed_len do
    local target_char = string.sub(target_text_for_line, i, i)
    local typed_char = string.sub(typed_text, i, i)

    local hl_group
    if target_char == typed_char then
      hl_group = HL_CORRECT
    else
      hl_group = HL_ERROR
      has_error = true
    end

    vim.api.nvim_buf_set_extmark(
      buffer_id, EXTMARK_NS, buffer_line_idx, i - 1,
      { end_col = i, hl_group = hl_group }
    )
  end

  -- Add virtual text for remaining characters
  local remaining_text = string.sub(target_text_for_line, typed_len + 1)
  if #remaining_text > 0 then
    vim.api.nvim_buf_set_extmark(
      buffer_id, EXTMARK_NS, buffer_line_idx, typed_len,
      {
        virt_text = {{remaining_text, HL_REMAINING}},
        virt_text_pos = 'overlay',
        hl_mode = 'combine'
      }
    )
  end

  -- Update completion status and typed length for this line
  if typed_len >= target_len and not has_error then
    completed_lines[snippet_line_idx] = true
  else
    completed_lines[snippet_line_idx] = false
  end
  typed_lengths[snippet_line_idx] = typed_len

  return has_error
end

--- Handles input and provides real-time highlighting using Extmarks.
function M.check_input()
  -- Ensure we have a valid namespace and buffer, and game is active
  if not buffer_id or game_status == "FINISHED" or not EXTMARK_NS then return end

  -- Get current cursor position to detect which line user is actually on
  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1] -- 1-indexed line number
  local cursor_col = cursor_pos[2] -- 0-indexed column position

  -- Calculate which snippet line we're on
  -- Buffer: Line 1 = Status, Line 2 = Separator, Line 3+ = Snippet lines
  -- So: cursor_line 3 = snippet index 1, cursor_line 4 = snippet index 2, etc.
  if cursor_line < 3 or cursor_line - 2 > #target_lines then
    -- User is on status/separator or beyond snippet lines, ignore
    return
  end

  local snippet_line_idx = cursor_line - 2 -- 1-based snippet index
  local current_buffer_line = cursor_line - 1 -- Buffer line index (0-based)

  -- Update display for current line
  local has_error = update_line_display(snippet_line_idx, current_buffer_line, true)

  -- Update all other lines
  for idx = 1, #target_lines do
    if idx ~= snippet_line_idx then
      local line_buffer_idx = 1 + idx -- 0-indexed
      update_line_display(idx, line_buffer_idx, false)
    end
  end

  -- Check if all lines are complete
  local all_complete = true
  local num_completed = 0
  for idx = 1, #target_lines do
    if completed_lines[idx] then
      num_completed = num_completed + 1
    else
      all_complete = false
    end
  end

  -- Finish game if all lines complete
  if all_complete and game_status ~= "FINISHED" then
    game_status = "FINISHED"
    vim.api.nvim_echo({{"Game Complete! Press q to close.", "Title"}}, true, {})
    vim.api.nvim_del_augroup_by_name("CodeTyperGame")
    vim.api.nvim_buf_set_option(buffer_id, 'modifiable', false)
  end

  -- Update Status Line
  local progress = math.floor((num_completed / #target_lines) * 100)

  vim.api.nvim_buf_set_lines(buffer_id, 0, 1, false, {
    "Code Typer - Line Progress: " .. progress .. "% | Errors: " .. (has_error and "Yes" or "No")
  })
end

--- Handles Enter key press to move to the next line
function M.move_to_next_line()
  if not buffer_id or not window_id or game_status == "FINISHED" then return end

  -- Get current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1] -- 1-indexed line number

  -- Calculate which snippet line we're on
  if cursor_line < 3 then
    -- On status or separator, move to first snippet line
    vim.api.nvim_win_set_cursor(window_id, {3, 0})
    return
  end

  local snippet_line_idx = cursor_line - 2

  -- Check if there's a next line
  if snippet_line_idx < #target_lines then
    local next_line = cursor_line + 1
    local next_snippet_idx = snippet_line_idx + 1

    -- Move cursor to the next line at the position of typed characters
    local next_typed_len = typed_lengths[next_snippet_idx] or 0
    vim.api.nvim_win_set_cursor(window_id, {next_line, next_typed_len})
  else
    -- Already on last line, wrap to first line
    vim.api.nvim_win_set_cursor(window_id, {3, typed_lengths[1] or 0})
  end
end

--- Shows the language selection menu, then starts the game
function M.start()
  menu.show(function(language_id)
    M.open(language_id)
  end)
end

--- Creates the full-screen, exclusive window and its associated buffer.
--- @param language_id string The language identifier (e.g., "golang", "java", "rust")
function M.open(language_id)
-- Check if the game is already open in a valid window.
if window_id and vim.api.nvim_win_is_valid(window_id) then
 vim.api.nvim_set_current_win(window_id)
 return
end

EXTMARK_NS = vim.api.nvim_create_namespace('CodeTyperExtmarks')

-- 1. Select the random snippet for the chosen language and update state
target_lines = utils.get_random_snippet(language_id)
current_line_idx = 1
target_text = target_lines[1] -- Initialize with the first line
game_status = "PLAYING"

-- Initialize completion tracking and typed lengths for all lines
completed_lines = {}
typed_lengths = {}
for i = 1, #target_lines do
  completed_lines[i] = false
  typed_lengths[i] = 0
end

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
-- Create buffer content with status, separator, and empty lines for typing
local buffer_content = {
  "Code Typer - Line Progress: 0% | Errors: No", -- Line 0: Status Line
  "--------------------------------------------------------------------------------", -- Line 1: Separator
}

-- Add empty lines for each snippet line (virtual text will show target)
for _ = 1, #target_lines do
  table.insert(buffer_content, "")
end

vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, buffer_content)

-- Make the buffer modifiable, and move cursor to first snippet line
vim.api.nvim_buf_set_option(buffer_id, 'modifiable', true)
vim.api.nvim_win_set_cursor(window_id, {3, 0}) -- Cursor on line 3 (first snippet line), column 0

-- 5. Set up Autocommands for continuous input checking
vim.api.nvim_create_autocmd("TextChangedI", {
  group = AUGROUP,
  buffer = buffer_id,
  callback = M.check_input,
  desc = "Real-time input checking for typing game in insert mode",
})

vim.api.nvim_create_autocmd("TextChanged", {
  group = AUGROUP,
  buffer = buffer_id,
  callback = M.check_input,
  desc = "Real-time input checking for typing game in normal mode",
})

vim.api.nvim_create_autocmd({"CursorMovedI", "CursorMoved"}, {
  group = AUGROUP,
  buffer = buffer_id,
  callback = M.check_input,
  desc = "Update display when cursor moves between lines",
})

-- 6. Custom mappings to handle line operations without deleting buffer lines
-- dd - clear line content (don't delete the line itself)
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'dd', '0D', { noremap = true, silent = true })

-- cc - clear line and enter insert mode
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'cc', '0C', { noremap = true, silent = true })

-- S - same as cc (substitute line)
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'S', '0C', { noremap = true, silent = true })

-- Disable operations that would delete lines from buffer
-- These would break the buffer structure where each line = one snippet line
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'J', '<Nop>', { noremap = true, silent = true })  -- join lines
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'gJ', '<Nop>', { noremap = true, silent = true }) -- join lines without space
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'o', '<Nop>', { noremap = true, silent = true })  -- open line below
vim.api.nvim_buf_set_keymap(buffer_id, 'n', 'O', '<Nop>', { noremap = true, silent = true })  -- open line above

-- Map Enter to move to next line instead of inserting newline
vim.api.nvim_buf_set_keymap(buffer_id, 'i', '<CR>', '<Esc>:lua require("speed-motion.core").move_to_next_line()<CR>a', { noremap = true, silent = true })
vim.api.nvim_buf_set_keymap(buffer_id, 'i', '<S-CR>', '<Nop>', { noremap = true, silent = true })

-- Map  <C-c> to close
local close_cmd = ':lua require("speed-motion.core").close()<CR>'
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
 completed_lines = {}
 typed_lengths = {}
end
end

-- Export the module
return M
