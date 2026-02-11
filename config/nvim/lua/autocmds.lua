-- Autocmds configuration

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Filetype detection for grit files
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.grit',
  callback = function()
    vim.bo.filetype = 'grit'
    vim.bo.commentstring = '// %s'
  end,
})

-- Filetype detection for berlioz dsl
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.brl',
  callback = function()
    vim.bo.filetype = 'berlioz'
    vim.bo.commentstring = '// %s'
  end,
})
