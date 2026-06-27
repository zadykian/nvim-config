# Neovim .NET setup — notes

This Neovim config is **kickstart.nvim** (a single, commented `init.lua` using Neovim's
built-in `vim.pack` plugin manager) plus a small .NET + git layer. Optimised for occasional
use over SSH (Termius on iPad + Magic Keyboard).

## What's installed

| Piece | What it gives you |
|---|---|
| **Neovim 0.12.3** | editor (installed at `/opt/nvim-linux-x86_64`, symlinked to `/usr/local/bin/nvim`) |
| **kickstart.nvim** | Telescope (fuzzy find), Treesitter, completion, which-key, gitsigns, LSP scaffolding |
| **easy-dotnet.nvim** | C# IntelliSense (Roslyn LSP + Roslynator), test runner, build/run, debugging |
| **`dotnet-easydotnet`** tool | the easy-dotnet server (installed globally under the .NET 8 SDK) |
| **`roslyn-language-server`** tool | the actual C# language server (see the caveat below) |
| **nvim-dap + netcoredbg** | step debugging (netcoredbg is bundled inside easy-dotnet) |
| **lazygit** | single-window git TUI |
| **tree-sitter CLI** | builds syntax parsers (`/usr/local/bin/tree-sitter`); `c_sharp`,`json`,`xml` preinstalled |

`~/.dotnet/tools` is on PATH (added to `~/.bashrc` and `~/.profile`) so the tools resolve.

## Key bindings (leader = Space)

- `<Space>sf` find files, `<Space>sg` live grep, `<Space><Space>` open buffers (Telescope)
- `gd` go to definition, `grr` references, `K` hover docs, `<Space>rn` rename, `<Space>ca` code action
- `<Space>gg` lazygit, `<Space>gf` lazygit history for current file
- `<F5>` start/continue debug, `<Space>b` toggle breakpoint, `<F1/F2/F3>` step into/over/out, `<F7>` debug UI
- `:Dotnet` for easy-dotnet commands (build / run / test / secrets / new …)
- `jk` (in insert mode) = Esc — for the iPad Magic Keyboard which has no Esc key

Tip: which-key shows what's available — press `<Space>` and wait.

## iPad / Termius

- **Esc**: use `jk`, or remap Caps Lock → Esc in Termius's keyboard settings.
- **Clipboard**: yanks sync to the iOS clipboard via OSC 52 (configured in `init.lua`).
- **Icons** are disabled (`vim.g.have_nerd_font = false`) to avoid missing-glyph boxes; flip
  to `true` only if you get a Nerd Font rendering in Termius.

## ⚠️ Important caveat: the .NET 10 SDK tool installer is broken on this machine

`dotnet tool install --global <anything>` fails under the **.NET 10.0.203 SDK** with
`"DotnetToolSettings.xml was not found in the package"` — for *every* package (reproducible
with `dotnetsay`). The .NET 8 SDK installer works fine. Consequences:

- The two required tools were installed **under the .NET 8 SDK** (pin with a `global.json`
  containing `{ "sdk": { "version": "8.0.x" } }`, then run `dotnet tool install` from there).
- The `roslyn-language-server` tool is additionally a net10 / RID-specific / `executable`-runner
  package that *neither* SDK installs as-is, so it is **repackaged** as a plain net8 `dotnet`-runner
  tool. To (re)install or update it, run:

  ```bash
  bash ~/.config/nvim/install-roslyn-ls.sh
  ```

  easy-dotnet's own auto-install / `:Dotnet` update of Roslyn will **not** work here — always use
  that script. `lsp.suggest_updates = false` is set in `lua/custom/plugins/dotnet.lua` to avoid
  the broken update path.

If you later install a newer .NET 10 SDK that fixes the tool installer, this workaround can be
dropped.

## Security note

Your `~/.nuget/NuGet/NuGet.Config` stores a **plaintext** access token for a private feed
(`MPackage`). Consider replacing `ClearTextPassword` with an encrypted credential or an
environment-based token.

## Verify it works

```bash
cd ~/scratch/HelloNvim        # a sample console app + solution is already here
nvim HelloNvim/Program.cs
```
Then: `:LspInfo` shows `easy_dotnet` running; `K` shows hover; typing `Console.` gives completion;
`<F5>` then pick the project to debug; `<Space>gg` opens lazygit.
