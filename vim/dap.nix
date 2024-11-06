{
  programs.nixvim.plugins.dap = {
    enable = true;

    extensions = {
      dap-go.enable = true;
      dap-ui.enable = true;
      dap-virtual-text.enable = true;
    };

    signs = {
      dapBreakpoint = {
        text = "●";
        texthl = "DapBreakpoint";
      };
      dapBreakpointCondition = {
        text = "●";
        texthl = "DapBreakpointCondition";
      };
      dapLogPoint = {
        text = "◆";
        texthl = "DapLogPoint";
      };
    };

    adapters.executables = {
      gdb = {
        command = "gdb";
        args = [
          "--interpreter=dap"
          "--eval-command"
          "set print pretty on"
        ];
      };

      lldb = {
        command = "lldb";
      };
    };

    configurations.odin = [
      {
        name = "Launch";
        type = "lldb";
        request = "launch";
        program = "./src.bin"; # TODO lua picker
        cwd = "\${workspaceFolder}";
        stopAtBeginningOfMainSubprogram = false;
      }
    ];

    configurations.c = [
      {
        name = "Launch";
        type = "gdb";
        request = "launch";
        program = "./hollie";
        # ''
        #       function()
        #       	local path = vim.fn.input({
        #       		prompt = 'Path to executable: ',
        #       		default = vim.fn.getcwd() .. '/',
        #       		completion = 'file'
        #       	})
        #       	return (path and path ~= "") and path or dap.ABORT
        #       end
        #     '';
        cwd = "$${workspaceFolder}";
        stopAtBeginningOfMainSubprogram = false;
      }
      {
        name = "Select and attach to process";
        type = "gdb";
        request = "attach";
        program = "function() return vim.fn.input('Path to executable: '; vim.fn.getcwd() .. '/', 'file') end";
        pid = ''
          	function()
              local name = vim.fn.input('Executable name (filter): ')
              return require("dap.utils").pick_process({ filter = name })
            end
        '';
        cwd = "$${workspaceFolder}";
      }
      {
        name = "Attach to gdbserver :1234";
        type = "gdb";
        request = "attach";
        target = "localhost:1234";
        program = "function() return vim.fn.input('Path to executable: '; vim.fn.getcwd() .. '/', 'file') end";
        cwd = "$${workspaceFolder}";
      }
    ];
  };
}
