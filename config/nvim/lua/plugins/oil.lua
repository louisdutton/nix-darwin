return {
  "stevearc/oil.nvim",
  config = function()
    require("oil").setup({
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true
      }
    })
  end,
}
