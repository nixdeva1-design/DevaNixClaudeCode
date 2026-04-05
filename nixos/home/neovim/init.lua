-- ─── Basis instellingen ──────────────────────────────────────────────────────
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.updatetime = 50
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ─── Thema ───────────────────────────────────────────────────────────────────
require("catppuccin").setup({ flavour = "mocha" })
vim.cmd.colorscheme("catppuccin")

-- ─── Bestandsboom ────────────────────────────────────────────────────────────
require("nvim-tree").setup({
  view = { width = 30 },
  filters = { dotfiles = false },
})
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Bestandsboom" })

-- ─── Statusbalk ──────────────────────────────────────────────────────────────
require("lualine").setup({ options = { theme = "catppuccin" } })

-- ─── Telescope (zoeken) ──────────────────────────────────────────────────────
local telescope = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", telescope.find_files, { desc = "Zoek bestand" })
vim.keymap.set("n", "<leader>fg", telescope.live_grep,  { desc = "Zoek in bestanden" })
vim.keymap.set("n", "<leader>fb", telescope.buffers,    { desc = "Zoek buffer" })
vim.keymap.set("n", "<leader>fk", telescope.keymaps,    { desc = "Zoek keymaps" })

-- ─── LSP ─────────────────────────────────────────────────────────────────────
local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Rust
lspconfig.rust_analyzer.setup({
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = { command = "clippy" },
    },
  },
})

-- Python
lspconfig.pyright.setup({ capabilities = capabilities })

-- Lua
lspconfig.lua_ls.setup({
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
    },
  },
})

-- LSP keymaps
vim.keymap.set("n", "gd",  vim.lsp.buf.definition,     { desc = "Ga naar definitie" })
vim.keymap.set("n", "gr",  vim.lsp.buf.references,      { desc = "Referenties" })
vim.keymap.set("n", "K",   vim.lsp.buf.hover,           { desc = "Hover info" })
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,   { desc = "Hernoem" })
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actie" })
vim.keymap.set("n", "<leader>f",  vim.lsp.buf.format,   { desc = "Formateer" })

-- ─── Autocomplete ────────────────────────────────────────────────────────────
local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  snippet = {
    expand = function(args) luasnip.lsp_expand(args.body) end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"]      = cmp.mapping.confirm({ select = true }),
    ["<Tab>"]     = cmp.mapping.select_next_item(),
    ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "buffer" },
    { name = "path" },
  }),
})

-- ─── Git ─────────────────────────────────────────────────────────────────────
require("gitsigns").setup()
vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })

-- ─── Autopairs ───────────────────────────────────────────────────────────────
require("nvim-autopairs").setup()

-- ─── Commentaar ──────────────────────────────────────────────────────────────
require("Comment").setup()

-- ─── Rust tools ──────────────────────────────────────────────────────────────
require("rust-tools").setup({
  tools = {
    autoSetHints = true,
    inlay_hints = { show_parameter_hints = true },
  },
})

-- ─── Keymaps algemeen ────────────────────────────────────────────────────────
vim.keymap.set("n", "<leader>q",  "<cmd>q<cr>",   { desc = "Sluit" })
vim.keymap.set("n", "<leader>w",  "<cmd>w<cr>",   { desc = "Opslaan" })
vim.keymap.set("n", "<leader>bd", "<cmd>bd<cr>",  { desc = "Sluit buffer" })
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
