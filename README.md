# nvim-glow

Neovim plugin to preview Markdown files using [glow](https://github.com/charmbracelet/glow) — a stylish terminal-based Markdown renderer.

## Requirements

- [Neovim](https://neovim.io/) >= 0.7 (tested up to 0.12/nightly)
- [glow](https://github.com/charmbracelet/glow) installed and available in `$PATH`

## How It Works

The plugin runs `glow` inside a `:terminal` buffer, so ANSI colors and styles render natively. The `-w` flag is passed with the actual window width, so the output always fits without wrapping. After glow finishes rendering, the buffer switches to normal mode — you can scroll up and down with `j/k`, `<C-d>`, `<C-u>`, etc.

Choose between a floating window (default) or a vertical split on the right. Works with unsaved buffers too.

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

### Scrolling

After glow renders, the preview window is in normal mode. Use any vim motion to scroll:
- `j/k` — line by line
- `<C-d>/<C-u>` — half page
- `gg/G` — top/bottom

## Configuration

```lua
require("glow").setup({
  glow_path = "",       -- Auto-detected from $PATH; override if needed
  width = 120,          -- Window width in characters (also passed to glow -w)
  height_ratio = 0.8,   -- Max window height as ratio of screen (float only)
  border = "rounded",   -- Border style (float only)
  position = "float",   -- "float" or "right" (vertical split)
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
