-- Treesitter
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua", "nix", "rust", "typescript", "javascript", "html", "css",
        "json", "markdown", "bash", "c", "kotlin", "go", "sql", "wgsl"
      },
      highlight = { enable = true },
      indent = { enable = true },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
        },
        swap = {
          enable = true,
          swap_next = {
            ["ma"] = "@parameter.inner",
          },
          swap_previous = {
            ["mA"] = "@parameter.outer",
          },
        },
      },
    })
  end,
}
