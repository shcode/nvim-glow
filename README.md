# nvim-glow

Neovim plugin to preview Markdown files using [glow](https://github.com/charmbracelet/glow) — a stylish terminal-based Markdown renderer.

## Requirements

- [Neovim](https://neovim.io/) >= 0.7 (tested up to 0.12/nightly)
- [glow](https://github.com/charmbracelet/glow) installed and available in `$PATH`

## How It Works

The plugin opens a floating terminal buffer and runs `glow` inside it. This lets glow's ANSI colors and styles render natively, giving you the full glow experience inside Neovim. It also works on unsaved buffers by writing them to a temporary file.

## Installation

### lazy.nvim

```lua
{
  "shcode/nvim-glow",
  cmd = "Glow",
  opts = {},
  config = function(_, opts)
    require("glow").setup(opts)
  end,
}
```

### packer.nvim

```lua
use {
  "shcode/nvim-glow",
  config = function()
    require("glow").setup({})
  end
}
```

## Usage

Open a Markdown file and run:

```vim
:Glow
```

Or preview a specific file:

```vim
:Glow path/to/file.md
```

### Keymaps in Preview Window

| Key | Action |
|-----|--------|
| `q` | Close preview |
| `<Esc>` | Close preview |
| `<C-c>` | Close preview |

Preview also auto-closes when you leave the buffer.

## Configuration

```lua
require("glow").setup({
  glow_path = "",       -- Auto-detected from $PATH; override if needed
  width = 0.8,          -- Window width (0-1 ratio)
  height = 0.8,         -- Window height (0-1 ratio)
  border = "rounded",   -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
  pager = false,        -- Enable pager mode (-p flag)
  style = "dark",       -- Color style: "dark", "light", "notty"
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:Glow [file]` | Preview current or given Markdown file |
| `:GlowSetup <json>` | Update config at runtime (JSON string) |

## License

MIT
