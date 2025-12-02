local M = {}
local language_menu = require('speed-motion.menu')
local core = require('speed-motion.core')
local normal_mode = require('speed-motion.normal_mode')

local menu_window_id = nil
local menu_buffer_id = nil
local selected_index = 1

--- Mode options
local modes = {
  { id = "normal", name = "Normal Mode - Word Typing Test (30s)" },
  { id = "code", name = "Code Mode - Practice Code Snippets" },
}

--- Renders the main menu content
local function render_menu()
  local lines = {}

  -- Title
  table.insert(lines, "")
  table.insert(lines, "  ╔════════════════════════════════════════╗")
  table.insert(lines, "  ║          Speed Motion v1.0             ║")
  table.insert(lines, "  ╚════════════════════════════════════════╝")
  table.insert(lines, "")
  table.insert(lines, "  Select a mode:")
  table.insert(lines, "")

  -- Mode options
  for i, mode in ipairs(modes) do
    local prefix = "     "
    if i == selected_index then
      prefix = "  →  "
    end
    table.insert(lines, prefix .. i .. ". " .. mode.name)
  end

  table.insert(lines, "")
  table.insert(lines, "")
  table.insert(lines, "  Navigation: j/k or ↑/↓")
  table.insert(lines, "  Select: Enter or number key")
  table.insert(lines, "  Quit: q or Esc")

  -- Update buffer content
  vim.api.nvim_buf_set_option(menu_buffer_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(menu_buffer_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(menu_buffer_id, 'modifiable', false)

  -- Position cursor on the selected mode line
  local cursor_line = 7 + selected_index

  if cursor_line > #lines then
    cursor_line = #lines
  end

  vim.api.nvim_win_set_cursor(menu_window_id, {cursor_line, 0})
end

--- Handles mode selection
local function select_mode(mode_id)
  M.close()

  if mode_id == "normal" then
    -- Start normal mode directly
    normal_mode.open()
  elseif mode_id == "code" then
    -- Show language selection menu
    language_menu.show(function(language_id)
      core.open(language_id)
    end)
  end
end

--- Creates and displays the main menu
function M.show()
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
    if selected_index > #modes then
      selected_index = 1
    end
    render_menu()
  end, opts)

  vim.keymap.set('n', '<Down>', function()
    selected_index = selected_index + 1
    if selected_index > #modes then
      selected_index = 1
    end
    render_menu()
  end, opts)

  -- Navigate up
  vim.keymap.set('n', 'k', function()
    selected_index = selected_index - 1
    if selected_index < 1 then
      selected_index = #modes
    end
    render_menu()
  end, opts)

  vim.keymap.set('n', '<Up>', function()
    selected_index = selected_index - 1
    if selected_index < 1 then
      selected_index = #modes
    end
    render_menu()
  end, opts)

  -- Select with Enter
  vim.keymap.set('n', '<CR>', function()
    local selected_mode = modes[selected_index]
    select_mode(selected_mode.id)
  end, opts)

  -- Select with number keys (1, 2)
  for i = 1, #modes do
    vim.keymap.set('n', tostring(i), function()
      select_mode(modes[i].id)
    end, opts)
  end

  -- Close with q or Esc
  vim.keymap.set('n', 'q', function()
    M.close()
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    M.close()
  end, opts)
end

--- Closes the menu window
function M.close()
  if menu_buffer_id and vim.api.nvim_buf_is_valid(menu_buffer_id) then
    vim.api.nvim_buf_delete(menu_buffer_id, { force = true })
  end
  menu_window_id = nil
  menu_buffer_id = nil
end

return M
