-- Customize Mason plugins
--
-- NOTE: Issue - mason.nvim does not support NixOS:
-- https://github.com/williamboman/mason.nvim/issues/428

---@type LazySpec
return {
  -- use mason-lspconfig to configure LSP installations
  {
    "williamboman/mason-lspconfig.nvim",
    -- mason is unusable on NixOS, disable it.
    -- ensure_installed nothing
    opts = function(_, opts)
      opts.ensure_installed = nil
      opts.automatic_installation = false
    end,

  },
  -- use mason-null-ls to configure Formatters/Linter installation for null-ls sources
  {
    "jay-babu/mason-null-ls.nvim",
    -- mason is unusable on NixOS, disable it.
    -- ensure_installed nothing
    opts = function(_, opts)
      opts.ensure_installed = nil
      opts.automatic_installation = false
    end,

  },

  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      -- Where Mason should put its bin location in your PATH. Can be one of:
      -- - "prepend" (default, Mason's bin location is put first in PATH)
      -- - "append" (Mason's bin location is put at the end of PATH)
      -- - "skip" (doesn't modify PATH)
      ---@type '"prepend"' | '"append"' | '"skip"'
      opts.PATH = "append" -- use mason's package only when no other package is found
    end,
  },
}
