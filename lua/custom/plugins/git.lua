-- lua/custom/plugins/git.lua
-- Git workflow: lazygit -- a single-window TUI (status / staging / commit /
-- branches / log / diff) launched from inside Neovim in a floating terminal.
--
-- Requires the `lazygit` binary on PATH (installed via `apt install lazygit`).
-- Gutter signs + line blame/annotate are already provided by kickstart's gitsigns.

local function gh(repo)
  return 'https://github.com/' .. repo
end

vim.pack.add {
  gh 'nvim-lua/plenary.nvim', -- already added; idempotent
  gh 'kdheepak/lazygit.nvim',
}

vim.keymap.set('n', '<leader>gg', '<cmd>LazyGit<cr>', { desc = 'Git: lazygit (status/commit/branches/log)' })
vim.keymap.set('n', '<leader>gf', '<cmd>LazyGitCurrentFile<cr>', { desc = 'Git: lazygit history (current file)' })
