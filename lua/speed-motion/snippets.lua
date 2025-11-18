-- lua/your_plugin/snippets.lua

return {
  -- SNIPPET 1: Single-line example (for comparison)
  {
    "local fn = vim.fn",
  },
  
  -- SNIPPET 2: Multi-line Lua table definition
  {
    "local hl_groups = {",
    "  correct = 'TypingCorrect',",
    "  error = 'TypingError',",
    "}",
  },
  
  -- SNIPPET 3: Multi-line function definition
  {
    "local function check_input()",
    "  local typed_lines = vim.api.nvim_buf_get_lines(buffer_id, 2, 3, false)",
    "  -- logic goes here...",
    "end",
  },
  
}
