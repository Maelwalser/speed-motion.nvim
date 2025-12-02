# Project Overview

This is a Neovim plugin that provides a typing game to help users practice writing code in different languages. The plugin is written in Lua.

The main features are:

*   A language selection menu to choose from different programming languages.
*   A real-time typing interface that provides feedback on accuracy.
*   A scoring system to track progress.

## Architecture

The plugin is structured as follows:

*   `plugin/speed-motion.lua`: The main entry point of the plugin. It defines the user commands to start and stop the game.
*   `lua/speed-motion/core.lua`: This file contains the core logic of the game. It manages the game state, creates the user interface, and handles user input.
*   `lua/speed-motion/menu.lua`: This file is responsible for creating and managing the language selection menu.
*   `lua/speed-motion/utils.lua`: This file provides utility functions for loading code snippets from the `lua/speed-motion/snippets/` directory.
*   `lua/speed-motion/snippets/`: This directory contains the code snippets for each language, with each file representing a language.

# Building and Running

This is a Neovim plugin and doesn't require a separate build process. To use the plugin, the user needs to install it like any other Neovim plugin, for example, by using a plugin manager like `packer.nvim` or `vim-plug`.

Once installed, the user can start the game by running the following command in Neovim:

```
:SpeedMotion
```

# Development Conventions

The codebase is well-structured and follows standard Lua conventions. The code is modular, with clear separation of concerns between the different files.

The plugin uses Neovim's built-in LSP and Treesitter APIs for syntax highlighting and other language-specific features.
