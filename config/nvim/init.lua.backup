-- Basic Neovim configuration
-- Replaces the nvf configuration from home/vim.nix

-- Set leader key early
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic options
local indent = 2
vim.opt.shiftwidth = indent
vim.opt.tabstop = indent
vim.opt.expandtab = true
vim.opt.wrap = false
vim.opt.clipboard = 'unnamedplus'
vim.opt.scrolloff = 10
vim.opt.breakindent = true
vim.opt.shortmess:append("I")
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.signcolumn = 'yes'
vim.opt.fillchars = { eob = " " }

-- inherit terminal colors
vim.opt.termguicolors = false
vim.cmd('colorscheme default')

-- Load plugin configuration
require('manager')
require('keymaps')
require('autocmds')
