-- UI enhancements
return {
  "folke/noice.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("noice").setup({
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = true,
      },
      views = {
        notify = {
          backend = "mini",
          relative = "editor",
          align = "message-right",
          timeout = 3000,
          reverse = true,
          focusable = false,
          position = {
            row = -2,
            col = "100%",
          },
          size = {
            width = "auto",
            height = "auto",
          },
          border = {
            style = "none",
          },
          win_options = {
            winblend = 0,
          },
        },
      },
    })
  end,
}
