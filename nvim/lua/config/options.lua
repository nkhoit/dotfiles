-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ---------------------------------------------------------------------------
-- Neovide (GUI) — only applied when running under Neovide on any platform.
-- Keep this block self-contained so the same options.lua works in terminal
-- Neovim on Windows, macOS, and Linux without side effects.
-- ---------------------------------------------------------------------------
if vim.g.neovide then
  -- Font (Nerd Font is required for LazyVim icons to render)
  vim.o.guifont = "CaskaydiaCove Nerd Font:h11"

  -- Window chrome / padding
  vim.g.neovide_padding_top = 8
  vim.g.neovide_padding_bottom = 8
  vim.g.neovide_padding_left = 8
  vim.g.neovide_padding_right = 8

  -- Transparency / blur
  vim.g.neovide_opacity = 0.95
  vim.g.neovide_window_blurred = true

  -- Modest animations
  vim.g.neovide_cursor_animation_length = 0.05
  vim.g.neovide_cursor_trail_size = 0.3
  vim.g.neovide_cursor_vfx_mode = ""
  vim.g.neovide_scroll_animation_length = 0.2

  -- Refresh rates (active / idle) — save battery when unfocused
  vim.g.neovide_refresh_rate = 60
  vim.g.neovide_refresh_rate_idle = 5

  -- Hide the mouse while typing
  vim.g.neovide_hide_mouse_when_typing = true

  -- System clipboard shortcuts (Ctrl+Shift+C / Ctrl+Shift+V)
  vim.keymap.set({ "n", "v" }, "<C-S-c>", '"+y', { desc = "Copy to system clipboard" })
  vim.keymap.set({ "n", "v" }, "<C-S-v>", '"+p', { desc = "Paste from system clipboard" })
  vim.keymap.set("i", "<C-S-v>", "<C-r>+", { desc = "Paste from system clipboard" })
  vim.keymap.set("c", "<C-S-v>", "<C-r>+", { desc = "Paste from system clipboard" })
  vim.keymap.set("t", "<C-S-v>", [[<C-\><C-n>"+pi]], { desc = "Paste from system clipboard" })
end
