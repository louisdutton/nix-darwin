-- Autocmds configuration

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Use Neovim's native Tree-sitter support for parsers supplied by the current
-- environment. Missing parsers are expected and leave the buffer unchanged.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('native-treesitter', { clear = true }),
  callback = function(event)
    local started = pcall(vim.treesitter.start, event.buf)
    if not started then
      return
    end

    local language = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
      or vim.bo[event.buf].filetype
    local query_ok, indent_query = pcall(vim.treesitter.query.get, language, 'indents')
    if query_ok and indent_query then
      vim.bo[event.buf].indentexpr = "v:lua.vim.treesitter.indentexpr()"
    end
  end,
})
