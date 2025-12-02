# Speed Motion.nvim
***Still in development, might have bugs or unexpected behaviours***


**Speed Motion** is a Neovim plugin designed to practice typing directly inside your favorite editor. Whether you want to improve your raw typing speed with common English words or build muscle memory for specific programming language syntax, Speed Motion has a mode for you.

<img width="678" height="466" alt="screenshot-2025-12-02_15-57-20" src="https://github.com/user-attachments/assets/24e71d10-212a-473e-9b67-3a6e8d89dc3e" />

## Features
- **Two Distinct Game Modes:**
  - **Normal Mode:** A classic 30-second typing sprint using common English words.
  - **Code Mode:** Practice real-world code snippets with syntax highlighting and virtual text guides.
- **Real-time Feedback:** Instant visual cues for correct (green) and incorrect (red) characters.
- **Language Support:** specialized snippets for **Rust**, **Go**, and **Java**.
- **Performance Stats:** Calculates WPM (Words Per Minute) and tracks errors.

## Installation

You can install `speed-motion.nvim` using [lazy.nvim](https://github.com/folke/lazy.nvim).

```lua
return {
  "maelwalser/speed-motion.nvim",
  cmd = "SpeedMotion", -- Lazy load when the command is used
}
```

## Usage
Start the plugin by running the following command in Neovim:

```Vim Script
:SpeedMotion
```
This will open the Main Menu where you can select your game mode using j/k to navigate and Enter to select.

To force-close the game window at any time, you can use:

```Vim Script
:SlowMotion
```

## Game Modes
**1. Normal Mode (Speed Test)**
<img width="1806" height="340" alt="screenshot-2025-12-02_16-03-06" src="https://github.com/user-attachments/assets/f58463ab-2170-4c34-8f52-1155e561b2b9" />

Focus on raw speed. You have 30 seconds to type as many words as possible from a randomized sequence of the 200 most common English words.

- Goal: Type as fast as you can.

- Result: Displays your **WPM** and total words typed upon time expiration.

**2. Code Mode (Syntax Practice)**
<img width="783" height="495" alt="screenshot-2025-12-02_16-01-51" src="https://github.com/user-attachments/assets/c7cd1a28-90aa-4fd4-bf7f-643b6ab77cb3" />

Focus on accuracy and special character muscle memory. You will be presented with random code snippets (Structs, Interfaces, Loops, etc.) in your chosen language.

- Goal: Complete the snippet accurately. The timer counts up to track how long it takes you.

- Visuals: Uses virtual text (ghost text) to show the remaining characters on the line.
<img width="579" height="328" alt="screenshot-2025-12-02_16-02-28" src="https://github.com/user-attachments/assets/86858df8-2ec3-4fe7-9a38-5e15fd14725d" />


**Controls:**

\<Enter>: Moves to the next line (Smart navigation—does not break the snippet layout).

\<Tab>: Inserts 2 spaces.

dd: Clears the current line's input (retries the line).

cc: Clears the line and enters Insert mode.

**Vim motions like ce or de should also work!**

**Supported Languages (Code Mode)**
- Go
- Rust
- Java
