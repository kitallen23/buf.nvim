local H = {}
local ns_id = vim.api.nvim_create_namespace("buf.nvim")

H.get_border_size = function(border)
  if border == "none" or border == "" then
    return 0
  end
  return 2
end

H.resolve_border = function(window_config)
  local border = window_config.border or vim.o.winborder
  if border == "" or border == "shadow" or border == "none" then
    return "single"
  end
  return border
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

-- Moves the cursor to the start of the buffer name on its current row, so it
-- never rests on the tree indent or icon. Rows without an entry in
-- name_offsets (e.g. section headers) are left alone.
---@param win integer window handle
---@param name_offsets table<integer, integer> 1-based row -> 0-based byte col
H.snap_cursor_to_name = function(win, name_offsets)
  local row = unpack(vim.api.nvim_win_get_cursor(win))
  local offset = name_offsets[row]

  if offset == nil then
    return
  end

  vim.api.nvim_win_set_cursor(win, { row, offset })
end

local M = {}
M._H = H

-- TODO
-- M.compute_config(window_config, n_lines)   -- glues the above into an nvim_open_win table
-- M.create_buf(lines, highlights)            -- side effects: buffer + extmarks
-- M.open(buf_id, win_config)                 -- side effects: nvim_open_win, window options
-- M.close(win_id)                            -- side effects

-- TODO
-- 1. **Silence Insert-mode keys:** remove the `InsertEnter` autocmd. Add
-- buffer-local `<Nop>` mappings (`buffer = buf`) for `i a o I A O s S c C R`,
-- and `v V <C-v>` if you also want to block Visual mode, so those keys do
-- nothing instead of showing `E21`.
-- 2. **`bufhidden = "wipe"` on the float's buffer:** without it, every open
-- leaves an old buffer and its autocmds behind.
-- 3. **Position and size:** replace the hard-coded `row`, `col` and `width`,
-- and the uncapped height, with `get_editor_space`, `compute_height` and
-- `compute_position`. Use `config.window.width` for the width and pass it
-- to `render`.

-- Builds the buffer tree, renders it into a scratch buffer and opens it in a
-- floating window. Currently does everything inline; the TODO above splits
-- this into compute_config / create_buf / open.
---@param window_config table user window options (border, height_min, height_max)
---@return integer window handle of the opened float
M.open = function(window_config)
  local tree = require("buf.tree")
  local render = require("buf.render")
  local state = require("buf.state")

  state.source_win = vim.api.nvim_get_current_win()

  -- Build and render content
  local t, other = tree.build()
  local lines, line_map, highlights, name_offsets = render.render(t, other, 40)
  state.line_map = line_map

  -- Populate a scratch buffer (lines + highlight extmarks), then lock it
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(
      buf,
      ns_id,
      highlight.line - 1,
      highlight.col_start,
      {
        end_col = highlight.col_end,
        hl_group = highlight.hl_group,
      }
    )
  end
  vim.bo[buf].modifiable = false

  -- Mappings
  require("buf.keymaps").attach(buf)

  -- Window config: height fits content, clamped to [height_min, height_max]
  local height = math.max(
    window_config.height_min,
    math.min(#lines, window_config.height_max)
  )
  local config = {
    relative = "editor",
    border = H.resolve_border(window_config),
    title = " Buffers ",
    title_pos = "left",
    row = 5,
    col = 10,
    width = 40,
    height = height,
    style = "minimal",
  }
  -- Open the float and set window-local options
  local window = vim.api.nvim_open_win(buf, true, config)
  vim.wo[window].cursorline = true

  -- Keep the cursor on buffer names: snap once now, then on every move
  H.snap_cursor_to_name(window, name_offsets)
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    desc = "Keep cursor off the indent and icon",
    callback = function()
      H.snap_cursor_to_name(window, name_offsets)
    end,
  })

  state.buf_id = buf
  state.win_id = window
  return window
end

return M
