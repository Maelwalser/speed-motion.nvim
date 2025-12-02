# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

speed-motion.nvim is a Neovim plugin that provides a typing speed game/practice tool. Users select a programming language, then type code snippets character-by-character with real-time visual feedback using extmarks for highlighting correct, incorrect, and remaining characters.

## Architecture

### Core Components

**init.lua** (Entry point)
- Defines user commands: `:SpeedMotion` (open language menu and start game) and `:SlowMotion` (close game)
- Delegates to core module

**lua/speed-motion/core.lua** (Game logic & UI)
- Manages game state (`READY`, `PLAYING`, `FINISHED`)
- Creates full-screen exclusive window with scratch buffer
- Implements real-time character-by-character validation using extmarks and virtual text
- Multi-line snippet support: displays all snippet lines at once, user can type any line in any order
- Key state variables:
  - `target_lines`: All lines of current snippet (table of strings)
  - `completed_lines`: Tracks completion status per line (table: {[1] = true, [2] = false, ...})
  - `typed_lengths`: Tracks how many characters typed on each line (table: {[1] = 7, [2] = 0, ...})
  - `current_line_idx`: Legacy - still used for initial state
  - `target_text`: Legacy - still used for initial state
  - `window_id`, `buffer_id`: UI handles
  - `EXTMARK_NS`: Namespace for highlight extmarks
- Key functions:
  - `start()`: Shows language selection menu
  - `open(language_id)`: Starts game with selected language
  - `check_input()`: Real-time input validation on every keystroke
  - `move_to_next_line()`: Handles Enter key to move to next line
  - `close()`: Cleans up and closes game window

**lua/speed-motion/menu.lua** (Language selection)
- Displays full-screen language selection menu
- Supports navigation with j/k or arrow keys
- Selection methods:
  - Enter key on highlighted language
  - Number keys (1, 2, 3, etc.)
  - **dd** on a language line (vim-style "delete line" to select)
- Closes with q or Esc
- Tracks selected index and renders menu with arrow indicator (→)
- Maps buffer line numbers to language indices for dd functionality

**lua/speed-motion/utils.lua** (Data loading and language management)
- Manages available languages (Go, Java, Rust)
- Loads language-specific snippets with caching
- Key data structure:
  ```lua
  LANGUAGES = {
    { id = "golang", name = "Go", module = "speed-motion.snippets.golang" },
    { id = "java", name = "Java", module = "speed-motion.snippets.java" },
    { id = "rust", name = "Rust", module = "speed-motion.snippets.rust" },
  }
  ```
- Functions:
  - `get_random_snippet(language_id)`: Selects random snippet for specified language
  - `get_languages()`: Returns list of available languages
  - Uses `pcall` for robust error handling when loading snippet modules

**lua/speed-motion/snippets/*.lua** (Language-specific snippet data)
- **golang.lua**: Go code snippets (functions, structs, interfaces, goroutines, etc.)
- **java.lua**: Java code snippets
- **rust.lua**: Rust code snippets
- Each file returns a table of snippets
- Each snippet is a table of strings (one string per line)
- Example structure:
  ```lua
  return {
    {
      "func main() {",
      "  fmt.Println(\"Hello, World!\")",
      "}",
    },
    -- more snippets...
  }
  ```

**lua/speed-motion/snippets.lua** (Legacy snippet data)
- Contains generic Lua snippets for reference
- Not actively used by the language selection system

### Game Flow

1. `:SpeedMotion` opens full-screen language selection menu
2. User selects language using:
   - j/k or arrow keys to navigate + Enter to select
   - Number key (1, 2, 3)
   - **dd** on a language line
3. Game window opens with a random snippet from selected language
4. Buffer layout:
   - Line 0: Status bar (progress percentage and error indicator)
   - Line 1: Separator line
   - Lines 2+: All snippet lines (empty, with virtual text showing target)
5. User can navigate to any line and type in insert mode
6. `TextChangedI` and `TextChanged` autocmds trigger `check_input()` on every keystroke
7. `CursorMovedI` and `CursorMoved` autocmds also trigger `check_input()` to update display when moving between lines
8. `check_input()` detects which line cursor is on and processes that line:
   - Uses cursor line position to determine which snippet line is being typed
   - **Line being typed**: Highlights based on correctness
     - Correct chars: green extmarks (`HL_CORRECT`)
     - Incorrect chars: red extmarks (`HL_ERROR`)
     - Remaining chars: gray virtual text overlay (`HL_REMAINING`)
   - Updates all other lines based on their completion status
   - Uses cursor column position to determine how many chars typed
9. When line is complete AND all characters correct:
   - Marks line as completed in `completed_lines[idx] = true`
   - Updates highlights for all lines
10. User can press **Enter** to move to next line:
    - Exits insert mode, calls `move_to_next_line()`, re-enters insert mode
    - Cursor positioned at typed position on next line
    - Wraps to first line if on last line
    - Does NOT insert newline into buffer
11. When ALL lines complete, game finishes:
    - Status set to `FINISHED`
    - Buffer becomes read-only
    - Message displayed: "Game Complete! Press q to close."
12. User can type lines in any order - no need to go sequentially
13. `:SlowMotion` or `<C-c>` closes window and cleans up

### Highlighting System

Uses combination of Neovim's extmark API and virtual text:
- `EXTMARK_NS` namespace created per session
- **Typed characters**: Per-character extmarks with `hl_group` for green (correct) or red (error)
- **Remaining characters**: Virtual text overlay with `virt_text_pos = 'overlay'` in gray
- On every keystroke, highlights are reapplied via `update_line_display()`:
  - Clears all extmarks on the line with `nvim_buf_clear_namespace()`
  - Applies character-by-character extmarks to typed portion
  - Applies virtual text for remaining portion
- Three highlight groups defined:
  - `TypingCorrect` (guifg=#6AA84F) - Green for correct characters
  - `TypingError` (guifg=#CC0000) - Red for incorrect characters
  - `TypingRemaining` (guifg=#888888) - Gray for remaining characters

### Custom Keybindings

**Game Buffer (Normal Mode):**
- `dd`: Clear line content (mapped to `0D` - doesn't delete buffer line)
- `cc`: Clear line and enter insert mode (mapped to `0C`)
- `S`: Same as cc
- `J`, `gJ`: Disabled (would break buffer structure)
- `o`, `O`: Disabled (would create extra lines)
- `<C-c>`: Close game window

**Game Buffer (Insert Mode):**
- `<CR>` (Enter): Move to next snippet line without inserting newline
- `<S-CR>` (Shift-Enter): Disabled

**Menu Buffer (Normal Mode):**
- `j` / `↓`: Navigate down (wraps to top)
- `k` / `↑`: Navigate up (wraps to bottom)
- `<CR>`: Select highlighted language
- `1`, `2`, `3`, etc.: Select language by number
- `dd`: Select language on current line
- `q` / `<Esc>`: Close menu

## Development

### Testing the Plugin

```bash
# From repository root, test in Neovim
nvim --cmd "set rtp+=." -c "SpeedMotion"
```

This adds current directory to runtime path and opens the language selection menu.

### Key Implementation Details

#### Buffer Structure
- All snippet lines displayed in buffer starting at line 2 (buffer index 2)
- Line 0 (buffer index 0): Status bar
- Line 1 (buffer index 1): Separator
- Lines 2+ (buffer indices 2+): Snippet lines

#### Line Indexing
- **Free navigation**: User can move cursor to any snippet line and type it
- Current typing line detected from cursor position: `snippet_line_idx = cursor_line - 2`
- Buffer line index: `cursor_line - 1` (0-based for API calls)
- Example: cursor_line 3 → snippet_line_idx 1 → buffer_line_idx 2

#### Cursor Management
- Cursor position managed explicitly: `vim.api.nvim_win_set_cursor(window_id, {cursor_line, typed_len})`
- Cursor stays on the line being typed (no forced movement to sequential line)
- Cursor column position indicates how many characters user has typed on current line
- Enter key moves cursor to next line at appropriate typed position

#### Line Content Management
- Line content is NOT directly modified during typing
- Virtual text overlay shows remaining characters
- Typed content limited to target length to prevent overflow
- Users can type incorrect characters - they're kept and highlighted red

#### Persistent State Tracking
- **`typed_lengths` table**: Tracks typed character count per line
  - When highlighting non-current lines, uses `typed_lengths[idx]` to reconstruct proper highlights
  - Reads buffer content and compares first N characters (where N = typed_length) to target
  - Preserves green/red/gray highlighting even when cursor moves to another line
- **`completed_lines` table**: Tracks completion status per line
  - Line marked complete only when fully typed AND all characters are correct
  - Game finishes when all lines in `completed_lines` are true
  - Lines can be completed in any order

#### Enter Key Behavior
- Mapping: `<Esc>:lua require("speed-motion.core").move_to_next_line()<CR>a`
- Flow: Exit insert → Run function → Re-enter insert
- Function logic:
  - Calculates current snippet line from cursor position
  - Moves to next line (or wraps to first if on last)
  - Positions cursor at `typed_lengths[next_snippet_idx]`
  - Does NOT insert newline into buffer

#### Buffer Protection
- Destructive normal mode mappings disabled to prevent breaking buffer structure
- Buffer is modifiable but protected via custom keymaps
- Lines cannot be deleted, joined, or inserted via normal Vim operations

### Adding New Languages

1. Create snippet file: `lua/speed-motion/snippets/languagename.lua`
2. Add snippets in the format:
   ```lua
   return {
     {
       "line one of snippet",
       "line two of snippet",
     },
     {
       "another snippet",
       "with multiple lines",
     },
   }
   ```
3. Register language in `lua/speed-motion/utils.lua`:
   ```lua
   M.LANGUAGES = {
     { id = "languagename", name = "Language Display Name", module = "speed-motion.snippets.languagename" },
     -- ... existing languages
   }
   ```

### Adding Snippets to Existing Language

Edit the appropriate language file (e.g., `lua/speed-motion/snippets/golang.lua`) and add table entries:

```lua
{
  "line one",
  "line two",
  "line three",
},
```

Each snippet is a table of strings representing lines of code to type.

### Menu System Details

The menu uses a line-mapping system for the dd functionality:
- `line_to_language` table maps buffer line numbers to language indices
- When menu is rendered, each language option's line number is recorded
- When dd is pressed, cursor line is checked against this mapping
- If line corresponds to a language, that language is selected
- If not, a notification is shown
