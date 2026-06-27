-- lua/custom/plugins/dotnet.lua
-- .NET development layer for kickstart (uses Neovim's built-in `vim.pack`).
--
-- easy-dotnet.nvim provides:
--   * Roslyn LSP  -> IntelliSense, go-to-definition, rename, diagnostics, formatting
--   * a Rider-like test runner, plus build / run / test commands
--   * debugging via nvim-dap (keymaps come from `kickstart.plugins.debug`; press <F5>)
--
-- The Roslyn language server AND the netcoredbg debugger are bundled inside the
-- `dotnet-easydotnet` global tool, so no separate LSP/debugger installs are needed.
-- Install that tool with the .NET 8 SDK (the .NET 10 SDK mis-reads its package layout):
--
--   echo '{ "sdk": { "version": "8.0.128", "rollForward": "latestFeature" } }' > /tmp/gj/global.json
--   (cd /tmp/gj && dotnet tool install --global easydotnet)
--
-- and make sure ~/.dotnet/tools is on your PATH (added to ~/.bashrc and ~/.profile).

local function gh(repo)
  return 'https://github.com/' .. repo
end

vim.pack.add {
  gh 'nvim-lua/plenary.nvim', -- already added by Telescope; vim.pack.add is idempotent
  gh 'GustavEikaas/easy-dotnet.nvim',
}

-- Guarded so a transient server-tool hiccup never breaks the rest of the editor.
local ok, err = pcall(function()
  require('easy-dotnet').setup {
    lsp = {
      -- Don't nag/try to auto-update the Roslyn tool: this machine's .NET 10 SDK
      -- `dotnet tool install/update` is broken, and the working roslyn-language-server
      -- was installed manually under the .NET 8 SDK (see install-roslyn-ls.sh). An
      -- update would replace it with a non-installable package.
      suggest_updates = false,
    },
  }
end)
if not ok then
  vim.notify('easy-dotnet setup failed: ' .. tostring(err), vim.log.levels.WARN)
end
