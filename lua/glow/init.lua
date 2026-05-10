local M = {}

-- Compatibility: nvim_set_option_value (0.9+) vs deprecated nvim_buf_set_option
local set_buf_opt = vim.api.nvim_set_option_value or function(name, value, opts)
  vim.api.nvim_buf_set_option(opts.buf, name, value)
end

local config = {
  glow_path = "glow",
  width = 0.8,
  height = 0.8,
  border = "rounded",
  pager = false,
  style = "dark",
}

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

local function close_window(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

local function create_preview_buffer(content)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Use nvim_set_option_value (modern API, stable in 0.9+)
  -- nvim_buf_set_option is deprecated as of 0.10 and will be removed in future versions
  set_buf_opt("bufhidden", "wipe", { buf = buf })
  set_buf_opt("filetype", "glow", { buf = buf })
  set_buf_opt("modifiable", false, { buf = buf })

  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  return buf
end

function M.glow(file_path)
  file_path = file_path or vim.fn.expand("%:p")

  if not file_path or file_path == "" then
    vim.notify("[glow] No file specified", vim.log.levels.ERROR)
    return
  end

  -- Verify glow is executable
  if vim.fn.executable(config.glow_path) == 0 then
    vim.notify(
      "[glow] Binary not found: '" .. config.glow_path .. "'",
      vim.log.levels.ERROR
    )
    return
  end

  local cmd = { config.glow_path, file_path }
  if config.pager then
    table.insert(cmd, "-p")
  end
  if config.style then
    table.insert(cmd, "-s")
    table.insert(cmd, config.style)
  end

  local stdout = {}
  local stderr = {}

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stdout, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr, line)
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          local err = table.concat(stderr, "\n")
          if err == "" then
            err = "glow exited with code " .. exit_code
          end
          vim.notify("[glow] " .. err, vim.log.levels.ERROR)
          return
        end

        local content = table.concat(stdout, "\n")
        -- Remove trailing empty line from job output
        content = content:gsub("\n$", "")

        local buf = create_preview_buffer(content)
        local win = vim.api.nvim_open_win(buf, true, get_window_config())

        -- Keymaps for the preview window
        local opts = { buffer = buf, silent = true, nowait = true }
        vim.keymap.set("n", "q", function()
          close_window(win, buf)
        end, opts)
        vim.keymap.set("n", "<Esc>", function()
          close_window(win, buf)
        end, opts)
        vim.keymap.set("n", "<C-c>", function()
          close_window(win, buf)
        end, opts)

        -- Close on BufLeave
        local augroup = vim.api.nvim_create_augroup("GlowPreview_" .. buf, { clear = true })
        vim.api.nvim_create_autocmd("BufLeave", {
          group = augroup,
          buffer = buf,
          once = true,
          callback = function()
            close_window(win, buf)
          end,
        })
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify("[glow] Failed to start job", vim.log.levels.ERROR)
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

return M
