local M = {}
local utils = require('speed-motion.utils')

local menu_window_id = nil
local menu_buffer_id = nil
local selected_index = 1
local languages = {}

--- Maps buffer line numbers to language indices
local line_to_language = {}

--- Renders the menu content
local function render_menu()
  local lines = {}
  line_to_language = {} -- Reset mapping

  -- Title
  table.insert(lines, "")
  table.insert(lines, "  ╔════════════════════════════════════════╗")
  table.insert(lines, "  ║      Speed Motion - Language Select    ║")
  table.insert(lines, "  ╚════════════════════════════════════════╝")
  table.insert(lines, "")
  table.insert(lines, "  Select a language to practice typing:")
  table.insert(lines, "")

  -- Language options
  for i, lang in ipairs(languages) do
    local prefix = "     "
    if i == selected_index then
      prefix = "  →  "
    end
    table.insert(lines, prefix .. i .. ". " .. lang.name)
    -- Map this line number (1-indexed) to language index
    -- Current line number is #lines
    line_to_language[#lines] = i
  end

  table.insert(lines, "")
  table.insert(lines, "")
  table.insert(lines, "  Navigation: j/k or ↑/↓")
  table.insert(lines, "  Select: Enter, number key, or dd to delete the line")
  table.insert(lines, "  Quit: q or Esc")

  -- Update buffer content
  vim.api.nvim_buf_set_option(menu_buffer_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(menu_buffer_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(menu_buffer_id, 'modifiable', false)

  -- Position cursor on the selected language line
  -- Language lines start at line 8 (1-indexed)
  -- selected_index 1 = line 8, selected_index 2 = line 9, etc.
  local cursor_line = 7 + selected_index

  -- Ensure cursor position is valid (within buffer bounds)
  if cursor_line > #lines then
    cursor_line = #lines
  end

  vim.api.nvim_win_set_cursor(menu_window_id, {cursor_line, 0})
end

--- Creates and displays the language selection menu
--- @param callback function Function to call with selected language_id when user makes selection
function M.show(callback)
  -- Get available languages
  languages = utils.get_languages()
  selected_index = 1

  -- Create a new scratch buffer
  menu_buffer_id = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(menu_buffer_id, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(menu_buffer_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(menu_buffer_id, 'swapfile', false)
  vim.api.nvim_buf_set_option(menu_buffer_id, 'modifiable', false)

  -- Open full-screen window
  vim.cmd('enew')
  vim.cmd('only')
  menu_window_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(menu_window_id, menu_buffer_id)

  -- Render the menu
  render_menu()

  -- Set up keymaps for navigation
  local opts = { noremap = true, silent = true, buffer = menu_buffer_id }

  -- Navigate down
  vim.keymap.set('n', 'j', function()
    selected_index = selected_index + 1
    if selected_index > #languages then
      selected_index = 1
    end
    render_menu()
  end, opts)

  -- Navigate up
  vim.keymap.set('n', 'k', function()
    selected_index = selected_index - 1
    if selected_index < 1 then
      selected_index = #languages
    end
    render_menu()
  end, opts)

  -- Select with Enter
  vim.keymap.set('n', '<CR>', function()
    local selected_language = languages[selected_index]
    M.close()
    callback(selected_language.id)
  end, opts)

  -- Select with number keys (1, 2, 3, etc.)
  for i = 1, #languages do
    vim.keymap.set('n', tostring(i), function()
      M.close()
      callback(languages[i].id)
    end, opts)
  end

  -- Close with q or Esc
  vim.keymap.set('n', 'q', function()
    M.close()
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, opts)

  -- Delete line with dd to select language
  vim.keymap.set('n', 'dd', function()
    -- Get current cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(menu_window_id)
    local current_line = cursor_pos[1] -- 1-indexed line number

    -- Check if this line corresponds to a language option
    local lang_index = line_to_language[current_line]

    if lang_index then
      -- User deleted a language line - select it!
      local selected_language = languages[lang_index]
      M.close()
      callback(selected_language.id)
    else
      -- Not a language line, show a message
      vim.notify("Use dd on a language line to select it", vim.log.levels.INFO)
    end
  end, opts)
end

--- Closes the menu window
function M.close()
  -- Instead of closing the window (which fails if it's the last window),
  -- just wipe the buffer. The game will reuse the window.
  if menu_buffer_id and vim.api.nvim_buf_is_valid(menu_buffer_id) then
    vim.api.nvim_buf_delete(menu_buffer_id, { force = true })
  end
  menu_window_id = nil
  menu_buffer_id = nil
end

return M
