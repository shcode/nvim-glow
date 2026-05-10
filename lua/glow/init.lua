local M = {}

-- Forward compatibility: vim.uv (0.10+) vs vim.loop (legacy)
local uv = vim.uv or vim.loop

-- Compatibility: nvim_set_option_value (0.9+) vs deprecated nvim_buf_set_option
local set_buf_opt = vim.api.nvim_set_option_value or function(name, value, opts)
  vim.api.nvim_buf_set_option(opts.buf, name, value)
end

local config = {
  glow_path = vim.fn.exepath("glow"),
  width = 0.8,
  height = 0.8,
  border = "rounded",
  pager = false,
  style = "dark",
}

local active_job = nil
local active_tmpfile = nil

local function safe_close(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

local function stop_job()
  if not active_job then
    return
  end
  if active_job.stdout then
    active_job.stdout:read_stop()
    safe_close(active_job.stdout)
  end
  if active_job.stderr then
    active_job.stderr:read_stop()
    safe_close(active_job.stderr)
  end
  if active_job.handle then
    safe_close(active_job.handle)
  end
  active_job = nil
end

local function cleanup()
  stop_job()
  if active_tmpfile then
    vim.fn.delete(active_tmpfile)
    active_tmpfile = nil
  end
end

local function get_window_config()
  local width = math.floor(vim.o.columns * config.width)
  local height = math.floor(vim.o.lines * config.height)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = config.border,
  }
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

local function open_glow_window(cmd_args)
  -- Create preview buffer and floating window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, get_window_config())

  set_buf_opt("bufhidden", "wipe", { buf = buf })
  set_buf_opt("filetype", "glow", { buf = buf })

  -- Keymaps
  local keymap_opts = { silent = true, buffer = buf, nowait = true }
  local function close_fn()
    cleanup()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close_fn, keymap_opts)
  vim.keymap.set("n", "<Esc>", close_fn, keymap_opts)
  vim.keymap.set("n", "<C-c>", close_fn, keymap_opts)

  -- Close on BufLeave
  local augroup = vim.api.nvim_create_augroup("GlowPreview_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    buffer = buf,
    once = true,
    callback = close_fn,
  })

  -- Create terminal channel in the buffer to receive glow's ANSI output
  local chan = vim.api.nvim_open_term(buf, {})

  -- Output callback: send glow's stdout/stderr to the terminal channel
  local function on_output(err, data)
    if err then
      vim.schedule(function()
        vim.notify("[glow] " .. vim.inspect(err), vim.log.levels.ERROR)
      end)
      return
    end
    if data then
      -- nvim_chan_send expects data with \r\n line endings for terminal display
      local lines = vim.split(data, "\n", {})
      for _, line in ipairs(lines) do
        vim.api.nvim_chan_send(chan, line .. "\r\n")
      end
    end
  end

  -- Setup pipes
  active_job = {}
  active_job.stdout = uv.new_pipe(false)
  active_job.stderr = uv.new_pipe(false)

  -- Process exit callback
  local function on_exit()
    stop_job()
    if active_tmpfile then
      vim.fn.delete(active_tmpfile)
      active_tmpfile = nil
    end
  end

  -- Spawn glow process
  local cmd = table.remove(cmd_args, 1)
  local spawn_opts = {
    args = cmd_args,
    stdio = { nil, active_job.stdout, active_job.stderr },
  }

  active_job.handle = uv.spawn(cmd, spawn_opts, vim.schedule_wrap(on_exit))

  if not active_job.handle then
    vim.notify("[glow] Failed to spawn process: " .. cmd, vim.log.levels.ERROR)
    cleanup()
    return
  end

  -- Start reading from pipes
  uv.read_start(active_job.stdout, vim.schedule_wrap(on_output))
  uv.read_start(active_job.stderr, vim.schedule_wrap(on_output))

  if config.pager then
    vim.cmd("startinsert")
  end
end

function M.glow(file_path)
  -- Resolve glow binary path
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

  -- Determine the file to preview
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
    -- Current buffer: use file path if saved, else write to temp file
    local buf_path = vim.fn.expand("%:p")
    if buf_path ~= "" and vim.fn.filereadable(buf_path) == 1 and is_md_file(buf_path) then
      file = buf_path
    else
      local ft = vim.bo.filetype
      local md_fts = { markdown = true, ["markdown.pandoc"] = true, ["markdown.gfm"] = true }
      if not md_fts[ft] then
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

  -- Build command arguments
  local win_width = math.floor(vim.o.columns * config.width)
  local cmd_args = { glow_bin, "-s", config.style, "-w", win_width }
  if config.pager then
    table.insert(cmd_args, "-p")
  end
  table.insert(cmd_args, file)

  -- Stop any existing preview job
  cleanup()

  open_glow_window(cmd_args)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

return M
