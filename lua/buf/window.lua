local H = {}

H.get_border_size = function(border)
  if border == "none" or border == "" then
    return 0
  end
  return 2
end

H.resolve_border = function(window_config)
  if window_config.border ~= nil then
    return window_config.border
  elseif vim.o.winborder ~= "" then
    return vim.o.winborder
  end
  return "single"
end

-- Reads vim.o.*, returns available rows/cols. Side-effect free but
-- impure (reads global state).
--@return number, number
H.get_editor_space = function() end

H.compute_height = function(num_lines, min, max, available_rows)
  -- CHECK: Do we need both max and available_rows? What's the diff?
end

-- Pure, returns row, col
H.compute_position = function(
  position,
  win_width,
  win_height,
  available_rows,
  available_cols
)
end

-- TODO
-- M.compute_config(window_config, n_lines)   -- glues the above into an nvim_open_win table
-- M.create_buf(lines, highlights)            -- side effects: buffer + extmarks
-- M.open(buf_id, win_config)                 -- side effects: nvim_open_win, window options
-- M.close(win_id)                            -- side effects

local M = {}
M._H = H

return M
