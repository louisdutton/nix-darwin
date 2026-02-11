return {
  "kylechui/nvim-surround",
  dependencies = "windwp/nvim-autopairs",
  config = function()
    require("nvim-surround").setup({
      keymaps = {
        normal = "s",
        normal_cur = "ss",
        normal_line = "S",
        normal_cur_line = "SS",
        visual = "s",
        visual_line = "S",
        change = "cs",
        change_line = "cS",
        delete = "ds",
        delete_line = "dS",
      },
    })
  end,
}
