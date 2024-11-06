{
  programs.nixvim.opts = {
    number = true;
    relativenumber = false;
    hlsearch = true;
    tabstop = 2;
    shiftwidth = 2;
    wrap = false;
    clipboard = "unnamedplus";
    breakindent = true;
    undofile = true;
    ignorecase = true;
    smartcase = true;
    signcolumn = "yes";
    updatetime = 250;
    timeoutlen = 300;
    completeopt = "menuone,noselect";
    termguicolors = true;
    fillchars = {
      eob = " ";
    };
  };
}
