-- Keymapping configuration
local opts = { noremap = true, silent = true }

-- Helper function for keymaps
local function map(mode, lhs, rhs, desc)
  local options = vim.tbl_extend("force", opts, { desc = desc })
  vim.keymap.set(mode, lhs, rhs, options)
end

-- General mappings
map({ "n", "x" }, ";", ":", "Command")
map({ "n", "x" }, "H", "^", "Line start")
map({ "n", "x" }, "L", "$", "Line end")
map({ "n", "x" }, "K", "gg", "Buffer start")
map({ "n", "x" }, "J", "G", "Buffer end")

-- Redo
map("n", "U", "<C-r>", "Redo")

-- File operations
map("n", "<leader>f", ":FzfLua git_files<cr>", "Find files")
map("n", "<leader>/", ":FzfLua live_grep_native<cr>", "Find text")

-- LSP mappings
map("n", "<leader>k", vim.lsp.buf.hover, "Hover")
map("n", "<leader>a", vim.lsp.buf.code_action, "Action")
map("n", "<leader>r", vim.lsp.buf.rename, "Rename")
map("n", "<leader>d", vim.diagnostic.open_float, "Diagnostic")
map("n", "gr", ":FzfLua lsp_references<cr>", "Find references")
map("n", "gd", ":FzfLua lsp_definitions<cr>", "Find definitions")
map("n", "gD", ":FzfLua lsp_declarations<cr>", "Find declarations")
map("n", "gt", ":FzfLua lsp_typedefs<cr>", "Find type definitions")
map("n", "gI", ":FzfLua lsp_implementations<cr>", "Find implementations")

-- Oil
map("n", "-", ":Oil<cr>", "Oil")
