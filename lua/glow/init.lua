local M = {}

local config = {
  glow_path = vim.fn.exepath("glow"),
  width = 120,
  height_ratio = 0.8,
  border = "rounded",
  position = "float",
  pager = false,
  style = "dark",
}

local active_tmpfile = nil

local function cleanup()
  if active_tmpfile then
    vim.fn.delete(active_tmpfile)
    active_tmpfile = nil
  end
end

local function is_md_file(path)
  local ext = vim.fn.fnamemodify(path, ":e"):lower()
  local md_exts = {
    md = true,
    markdown = true,
    mkd = true,
    mkdn = true,
    mdwn = true,
    mdown = true,
    mdtxt = true,
    mdtext = true,
    rmd = true,
    wiki = true,
  }
  return md_exts[ext] or false
end

local function tmp_file()
  local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
  if vim.tbl_isempty(lines) then
    vim.notify("[glow] Buffer is empty", vim.log.levels.ERROR)
    return nil
  end
  local tmp = vim.fn.tempname() .. ".md"
  vim.fn.writefile(lines, tmp)
  return tmp
end

local function get_float_config()
  local max_height = math.floor(vim.o.lines * config.height_ratio)
  local height = math.min(max_height, vim.o.lines - 4)
  return {
    relative = "editor",
    width = config.width,
    height = height,
    col = math.floor((vim.o.columns - config.width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = config.border,
  }
end

local function open_glow_preview(file)
  local buf = vim.api.nvim_create_buf(false, true)
  local win

  if config.position == "right" then
    vim.cmd("rightbelow vnew")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_width(win, config.width)
  else
    win = vim.api.nvim_open_win(buf, true, get_float_config())
  end

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "glow", { buf = buf })

  local win_width = vim.api.nvim_win_get_width(win)
  local cmd = { config.glow_path, "-s", config.style, "-w", win_width }
  if config.pager then
    table.insert(cmd, "-p")
  end
  table.insert(cmd, file)

  local function close_fn()
    cleanup()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local opts = { silent = true, buffer = buf, nowait = true }
  vim.keymap.set("n", "q", close_fn, opts)
  vim.keymap.set("n", "<Esc>", close_fn, opts)
  vim.keymap.set("n", "<C-c>", close_fn, opts)
  vim.keymap.set("t", "<C-c>", close_fn, opts)

  local augroup = vim.api.nvim_create_augroup("GlowPreview_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    buffer = buf,
    once = true,
    callback = close_fn,
  })

  vim.api.nvim_buf_call(buf, function()
    vim.fn.jobstart(cmd, {
      on_exit = function()
        vim.schedule(function()
          cleanup()
          if not config.pager and vim.api.nvim_buf_is_valid(buf) then
            -- Enter normal mode so user can scroll the rendered output
            vim.api.nvim_feedkeys(
              vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
              "n",
              false
            )
            -- Move cursor to top of buffer
            vim.api.nvim_buf_call(buf, function()
              vim.cmd("normal! gg")
            end)
          end
        end)
      end,
      term = true,
    })
  end)

  if config.pager then
    vim.cmd("startinsert")
  end
end

function M.glow(file_path)
  local glow_bin = config.glow_path
  if glow_bin == "" then
    glow_bin = vim.fn.exepath("glow")
  end

  if vim.fn.executable(glow_bin) == 0 then
    vim.notify(
      "[glow] glow binary not found. Install it: https://github.com/charmbracelet/glow",
      vim.log.levels.ERROR
    )
    return
  end

  local file
  if file_path and file_path ~= "" then
    if vim.fn.filereadable(file_path) == 0 then
      vim.notify("[glow] File not readable: " .. file_path, vim.log.levels.ERROR)
      return
    end
    if not is_md_file(file_path) then
      vim.notify("[glow] Not a markdown file: " .. file_path, vim.log.levels.ERROR)
      return
    end
    file = file_path
  else
    local buf_path = vim.fn.expand("%:p")
    if buf_path ~= "" and vim.fn.filereadable(buf_path) == 1 and is_md_file(buf_path) then
      file = buf_path
    else
      local md_fts = { markdown = true, ["markdown.pandoc"] = true, ["markdown.gfm"] = true }
      if not md_fts[vim.bo.filetype] then
        vim.notify("[glow] Current buffer is not markdown", vim.log.levels.ERROR)
        return
      end
      file = tmp_file()
      if not file then
        return
      end
      active_tmpfile = file
    end
  end

  cleanup()
  open_glow_preview(file)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

return M
