local M = {
  win_id = nil,
  buf_id = nil,
  source_win = nil,
  filter = {
    active = false,
    query = {},
    caret = 1,
  },
  pinned_buffers = {},
  cursor_line = nil,
}

M.toggle_pin = function(buf_id)
  -- not true -> nil (remove), not nil -> true (add)
  M.pinned_buffers[buf_id] = not M.pinned_buffers[buf_id] or nil
end

M.clear_filter = function()
  M.filter.active = false
  M.filter.query = {}
  M.filter.caret = 1
end

return M
