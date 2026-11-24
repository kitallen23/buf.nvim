local H = {}

local DISABLED_KEYS = {
  -- Enter insert or replace mode
  "i",
  "a",
  "o",
  "I",
  "A",
  "O",
  "s",
  "S",
  "c",
  "C",
  "R",
  "gi",
  "gI",
  "gR",
  "gr",
  "<Insert>",

  -- Edit text
  "x",
  "X",
  "<Del>",
  "D",
  "r",
  "J",
  "gJ",
  "~",
  "p",
  "P",
  "gp",
  "gP",
  "]p",
  "[p",

  -- Operators
  ">",
  "<",
  "=",
  "!",
  "g~",
  "gu",
  "gU",
  "g?",
  "gq",
  "gw",

  -- Undo, redo, repeat
  "u",
  "U",
  "<C-r>",
  ".",
  "&",
  "g&",

  -- Number increments
  "<C-a>",
  "<C-x>",
}

H.disable_edit_keys = function(buf)
  for _, key in ipairs(DISABLED_KEYS) do
    vim.keymap.set("n", key, "<Nop>", { buffer = buf })
  end
end

H.open_buffer = function ()
  local state = require("buf.state")
  local cursor_row = vim.api.nvim_win_get_cursor(state.win_id)[1]
  local entry = state.line_map[cursor_row]

  H.close()
  vim.api.nvim_win_set_buf(state.source_win, entry.buf)
  vim.api.nvim_set_current_win(state.source_win)
end

H.close = function ()
  local state = require("buf.state")
  vim.api.nvim_win_close(state.win_id, false)
end

H.map = function(buf, mode, lhs, rhs, desc)
  if lhs == "" then
    return
  end
  vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
end

H.set_mappings = function(buf, mappings_config)
  H.map(buf, "n", mappings_config.open, H.open_buffer, "Open buffer")
  H.map(buf, "n", mappings_config.close, H.close, "Close")
end

local M = {}
M._H = H

M.attach = function (buf)
  H.disable_edit_keys(buf)
  H.set_mappings(buf, require("buf.config").default_config.mappings)
end

return M
