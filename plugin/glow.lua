if vim.g.loaded_glow then
  return
end
vim.g.loaded_glow = 1

local glow = require("glow")

vim.api.nvim_create_user_command("Glow", function(opts)
  local file = opts.args ~= "" and opts.args or nil
  glow.glow(file)
end, { nargs = "?", complete = "file" })

vim.api.nvim_create_user_command("GlowSetup", function(opts)
  local ok, cfg = pcall(vim.fn.json_decode, opts.args)
  if not ok then
    vim.notify("[glow] Invalid JSON: " .. tostring(cfg), vim.log.levels.ERROR)
    return
  end
  glow.setup(cfg)
end, { nargs = 1 })
