local M = {}
local words = require('speed-motion.words')

-- State variables
local window_id = nil
local buffer_id = nil
local target_lines = {}  -- Multiple lines of text
local current_line_idx = 1
local typed_lengths = {}  -- Track how many chars typed on each line
local completed_lines = {}  -- Track which lines are complete
local game_status = "READY" -- READY, PLAYING, FINISHED
local EXTMARK_NS = nil
local start_time = nil
local end_time = nil
local status_timer = nil
local countdown_timer = nil
local time_remaining = 30 -- 30 seconds
local total_words_in_target = 0  -- Track total words generated

local HL_CORRECT = 'TypingCorrect'
local HL_ERROR = 'TypingError'
local HL_REMAINING = 'TypingRemaining'

-- Autocmd Group for cleanup
local AUGROUP = vim.api.nvim_create_augroup("NormalModeTypingGame", { clear = true })

--- Formats time in MM:SS format
local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d", mins, secs)
end

--- Splits word sequence into lines based on width
--- @param text string The full text to split
--- @param width number Maximum width per line
--- @return table Array of line strings
local function split_into_lines(text, width)
  local lines = {}
  local current_line = ""
  local text_words = vim.split(text, " ", { plain = true, trimempty = true })

  for _, word in ipairs(text_words) do
    -- Check if adding this word would exceed the width
    local test_line = current_line
    if #current_line > 0 then
      test_line = current_line .. " " .. word
    else
      test_line = word
    end

    if #test_line <= width then
      current_line = test_line
    else
      -- Current line is full, save it and start new line
      if #current_line > 0 then
        table.insert(lines, current_line)
      end
      current_line = word
    end
  end

  -- Add the last line if not empty
  if #current_line > 0 then
    table.insert(lines, current_line)
  end

  return lines
end

--- Updates the status bar with countdown timer
local function update_status_bar()
  if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) or game_status ~= "PLAYING" then
    return
  end

  local time_str = format_time(time_remaining)

  vim.api.nvim_buf_set_lines(buffer_id, 0, 1, false, {
    "Normal Mode - Time Remaining: " .. time_str
  })
end

--- Updates highlights for a specific line
local function update_line_display(line_idx, buffer_line_idx, is_current_line)
  local target_text_for_line = target_lines[line_idx]
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

  -- Apply character-by-character highlights
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
  local was_complete = completed_lines[line_idx]
  if typed_len >= target_len and not has_error then
    completed_lines[line_idx] = true
    -- Auto-advance to next line when current line is complete (only for the line being actively typed)
    if is_current_line and not was_complete and line_idx < #target_lines then
      vim.schedule(function()
        M.move_to_next_line()
      end)
    end
  else
    completed_lines[line_idx] = false
  end
  typed_lengths[line_idx] = typed_len
end

--- Updates all line displays
local function update_display()
  if not buffer_id or game_status == "FINISHED" or not EXTMARK_NS then
    return
  end

  -- Get current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1]

  -- Calculate which line we're on (line 3 = index 1, line 4 = index 2, etc.)
  if cursor_line < 3 then
    return
  end

  local line_idx = cursor_line - 2
  if line_idx > #target_lines then
    return
  end

  -- Update current line
  local buffer_line_idx = cursor_line - 1
  update_line_display(line_idx, buffer_line_idx, true)

  -- Update all other lines
  for idx = 1, #target_lines do
    if idx ~= line_idx then
      local buf_line_idx = 1 + idx
      update_line_display(idx, buf_line_idx, false)
    end
  end
end

--- Moves to the next line
function M.move_to_next_line()
  if not buffer_id or not window_id or game_status == "FINISHED" then
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(window_id)
  local cursor_line = cursor_pos[1]

  if cursor_line < 3 then
    vim.api.nvim_win_set_cursor(window_id, {3, 0})
    return
  end

  local line_idx = cursor_line - 2

  if line_idx < #target_lines then
    local next_line = cursor_line + 1
    local next_line_idx = line_idx + 1
    local next_typed_len = typed_lengths[next_line_idx] or 0
    vim.api.nvim_win_set_cursor(window_id, {next_line, next_typed_len})
  end
end

--- Handles the countdown timer
local function countdown_tick()
  if game_status ~= "PLAYING" then
    return
  end

  time_remaining = time_remaining - 1
  update_status_bar()

  if time_remaining <= 0 then
    M.finish_game()
  end
end

--- Finishes the game and shows results
function M.finish_game()
  if game_status == "FINISHED" then
    return
  end

  game_status = "FINISHED"
  end_time = vim.loop.hrtime()

  -- Stop timers
  if status_timer then
    status_timer:stop()
    status_timer:close()
    status_timer = nil
  end

  if countdown_timer then
    countdown_timer:stop()
    countdown_timer:close()
    countdown_timer = nil
  end

  -- Collect all typed text from all lines
  local all_typed = {}
  for i = 1, #target_lines do
    local buffer_line_idx = 1 + i
    local buffer_lines = vim.api.nvim_buf_get_lines(buffer_id, buffer_line_idx, buffer_line_idx + 1, false)
    local typed_line = buffer_lines[1] or ""
    table.insert(all_typed, typed_line)
  end

  local typed_text = table.concat(all_typed, " ")
  local target_text = table.concat(target_lines, " ")

  -- Calculate statistics
  local correct_words = words.count_correct_words(typed_text, target_text)
  local total_time = 30
  local wpm = words.calculate_wpm(correct_words, total_time)

  -- Show completion screen
  M.show_completion_screen(correct_words, wpm)
end

--- Shows the completion screen with results
function M.show_completion_screen(correct_words, wpm)
  if not buffer_id or not vim.api.nvim_buf_is_valid(buffer_id) then return end

  -- Make buffer modifiable temporarily
  vim.api.nvim_buf_set_option(buffer_id, 'modifiable', true)

  -- Create completion screen
  local completion_screen = {
    "",
    "╔════════════════════════════════════════════════════════════════════════════╗",
    "║                                                                            ║",
    "║                         🎉 TIME'S UP! 🎉                                  ║",
    "║                                                                            ║",
    "╠════════════════════════════════════════════════════════════════════════════╣",
    "║                                                                            ║",
    "║                         Words Typed: " .. string.format("%-4d", correct_words) .. "                              ║",
    "║                         Words Per Minute: " .. string.format("%-4d", wpm) .. "                        ║",
    "║                                                                            ║",
    "╚════════════════════════════════════════════════════════════════════════════╝",
    "",
  }

  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, completion_screen)

  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buffer_id, 'modifiable', false)

  -- Remove all autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "NormalModeTypingGame")

  -- Ensure we're in normal mode
  vim.cmd('stopinsert')
end

--- Opens the normal mode typing game
function M.open()
  -- Check if game is already open
  if window_id and vim.api.nvim_win_is_valid(window_id) then
    vim.api.nvim_set_current_win(window_id)
    return
  end

  EXTMARK_NS = vim.api.nvim_create_namespace('NormalModeExtmarks')

  -- Generate random word sequence
  local word_sequence = words.generate_word_sequence(200)
  total_words_in_target = 200

  -- Create scratch buffer
  buffer_id = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buffer_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buffer_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buffer_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(buffer_id, 'filetype', 'typing_game')
  vim.api.nvim_buf_set_option(buffer_id, 'wrap', false)

  -- Open full-screen window
  vim.cmd('enew')
  vim.cmd('only')

  window_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(window_id, buffer_id)

  -- Get window width and split text into lines
  local win_width = vim.api.nvim_win_get_width(window_id)
  local usable_width = win_width - 4  -- Account for padding
  target_lines = split_into_lines(word_sequence, usable_width)

  -- Initialize state
  game_status = "PLAYING"
  start_time = vim.loop.hrtime()
  end_time = nil
  time_remaining = 30
  current_line_idx = 1

  completed_lines = {}
  typed_lengths = {}
  for i = 1, #target_lines do
    completed_lines[i] = false
    typed_lengths[i] = 0
  end

  -- Initial buffer content
  local buffer_content = {
    "Normal Mode - Time Remaining: 00:30",
    "────────────────────────────────────────────────────────────────────────────────",
  }

  -- Add empty lines for each target line
  for _ = 1, #target_lines do
    table.insert(buffer_content, "")
  end

  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, buffer_content)
  vim.api.nvim_buf_set_option(buffer_id, 'modifiable', true)
  vim.api.nvim_win_set_cursor(window_id, {3, 0})

  -- Set up autocmds for input checking
  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
    group = AUGROUP,
    buffer = buffer_id,
    callback = function()
      -- Protect status line
      local status_line = vim.api.nvim_buf_get_lines(buffer_id, 0, 1, false)[1]
      if not status_line or not string.match(status_line, "^Normal Mode") then
        vim.api.nvim_buf_set_lines(buffer_id, 0, 1, false, {"Normal Mode - Time Remaining: " .. format_time(time_remaining)})
      end

      local separator_line = vim.api.nvim_buf_get_lines(buffer_id, 1, 2, false)[1]
      if not string.match(separator_line or "", "^──") then
        vim.api.nvim_buf_set_lines(buffer_id, 1, 2, false, {"────────────────────────────────────────────────────────────────────────────────"})
      end

      update_display()
    end,
    desc = "Real-time input checking for typing game",
  })

  vim.api.nvim_create_autocmd({"CursorMovedI", "CursorMoved"}, {
    group = AUGROUP,
    buffer = buffer_id,
    callback = update_display,
    desc = "Update display when cursor moves",
  })

  -- Map Enter to move to next line
  vim.api.nvim_buf_set_keymap(buffer_id, 'i', '<CR>', '<Esc>:lua require("speed-motion.normal_mode").move_to_next_line()<CR>a', { noremap = true, silent = true })

  -- Map <C-c> to close
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', '<C-c>', ':lua require("speed-motion.normal_mode").close()<CR>', { noremap = true, silent = true })

  -- Start countdown timer (ticks every second)
  countdown_timer = vim.loop.new_timer()
  countdown_timer:start(1000, 1000, vim.schedule_wrap(function()
    countdown_tick()
  end))

  -- Start status bar update timer
  status_timer = vim.loop.new_timer()
  status_timer:start(0, 100, vim.schedule_wrap(function()
    update_status_bar()
  end))

  vim.api.nvim_set_current_win(window_id)

  -- Initial display update
  update_display()

  -- Enter insert mode
  vim.cmd('startinsert')
end

--- Closes the window and cleans up
function M.close()
  if window_id and vim.api.nvim_win_is_valid(window_id) then
    vim.api.nvim_win_close(window_id, true)

    pcall(vim.api.nvim_del_augroup_by_name, "NormalModeTypingGame")

    -- Stop timers
    if status_timer then
      status_timer:stop()
      status_timer:close()
      status_timer = nil
    end

    if countdown_timer then
      countdown_timer:stop()
      countdown_timer:close()
      countdown_timer = nil
    end

    window_id = nil
    buffer_id = nil
    EXTMARK_NS = nil
    target_lines = {}
    current_line_idx = 1
    typed_lengths = {}
    completed_lines = {}
    game_status = "READY"
    start_time = nil
    end_time = nil
    time_remaining = 30
    total_words_in_target = 0
  end
end

return M
