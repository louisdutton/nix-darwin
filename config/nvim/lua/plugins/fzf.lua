-- Fuzzy finder
return {
  "ibhagwan/fzf-lua",
  config = function()
    require("fzf-lua").setup({ "fzf-native" })
  end,
}
