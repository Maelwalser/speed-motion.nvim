local M = {}
local words = require('speed-motion.words')

-- State variables
local window_id = nil
local buffer_id = nil
local target_text = ""
local game_status = "READY" -- READY, PLAYING, FINISHED
local EXTMARK_NS = nil
local start_time = nil
local end_time = nil
local status_timer = nil
local countdown_timer = nil
local time_remaining = 30 -- 30 seconds

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

--- Updates highlights for the typed text
local function update_display()
  if not buffer_id or game_status == "FINISHED" or not EXTMARK_NS then
    return
  end

  -- Get what user has typed
  local buffer_lines = vim.api.nvim_buf_get_lines(buffer_id, 2, 3, false)
  local typed_text = buffer_lines[1] or ""
  local typed_len = #typed_text
  local target_len = #target_text

  -- Clear all extmarks on the typing line
  vim.api.nvim_buf_clear_namespace(buffer_id, EXTMARK_NS, 2, 3)

  -- Apply character-by-character highlights
  local has_error = false
  for i = 1, math.min(typed_len, target_len) do
    local target_char = string.sub(target_text, i, i)
    local typed_char = string.sub(typed_text, i, i)

    local hl_group
    if target_char == typed_char then
      hl_group = HL_CORRECT
    else
      hl_group = HL_ERROR
      has_error = true
    end

    vim.api.nvim_buf_set_extmark(
      buffer_id, EXTMARK_NS, 2, i - 1,
      { end_col = i, hl_group = hl_group }
    )
  end

  -- Add virtual text for remaining characters
  local remaining_text = string.sub(target_text, typed_len + 1)
  if #remaining_text > 0 then
    vim.api.nvim_buf_set_extmark(
      buffer_id, EXTMARK_NS, 2, typed_len,
      {
        virt_text = {{remaining_text, HL_REMAINING}},
        virt_text_pos = 'overlay',
        hl_mode = 'combine'
      }
    )
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

  -- Get typed text
  local buffer_lines = vim.api.nvim_buf_get_lines(buffer_id, 2, 3, false)
  local typed_text = buffer_lines[1] or ""

  -- Calculate statistics
  local correct_words = words.count_correct_words(typed_text, target_text)
  local total_time = 30 -- Always 30 seconds for normal mode
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

  -- Generate random word sequence (about 100 words - more than can be typed in 30s)
  target_text = words.generate_word_sequence(100)
  game_status = "PLAYING"
  start_time = vim.loop.hrtime()
  end_time = nil
  time_remaining = 30

  -- Create scratch buffer
  buffer_id = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buffer_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buffer_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buffer_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(buffer_id, 'filetype', 'typing_game')
  vim.api.nvim_buf_set_option(buffer_id, 'wrap', true)
  vim.api.nvim_buf_set_option(buffer_id, 'linebreak', true)

  -- Open full-screen window
  vim.cmd('enew')
  vim.cmd('only')

  window_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(window_id, buffer_id)

  -- Initial buffer content
  local buffer_content = {
    "Normal Mode - Time Remaining: 00:30",
    "────────────────────────────────────────────────────────────────────────────────",
    "",
  }

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

  -- Map <C-c> to close
  vim.api.nvim_buf_set_keymap(buffer_id, 'n', '<C-c>', ':lua require("speed-motion.normal_mode").close()<CR>', { noremap = true, silent = true })

  -- Start countdown timer (ticks every second)
  countdown_timer = vim.loop.new_timer()
  countdown_timer:start(1000, 1000, vim.schedule_wrap(function()
    countdown_tick()
  end))

  -- Start status bar update timer (updates every 100ms for smooth display)
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
    target_text = ""
    game_status = "READY"
    start_time = nil
    end_time = nil
    time_remaining = 30
  end
end

return M
