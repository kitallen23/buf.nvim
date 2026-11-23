---@class HighlightSpec
---@field line integer
---@field col_start integer
---@field col_end integer
---@field hl_group string

local H = {}

-- Appends one line per tree node, depth-first, so children appear directly
-- under their directory. Accumulates into the passed-in tables rather than
-- returning new ones, so recursive calls and `render_other` all add to the
-- same lines, keyed by the same line numbers. For each line it adds:
-- - `line_map`: the buffer entry, for files only. Directories can't be opened.
-- - `highlights`: the icon highlight, if MiniIcons is available.
-- - `name_offsets`: the byte offset where the name starts.
---@param tree TreeNode[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
---@param highlights HighlightSpec[]
---@param name_offsets table<integer, integer>
---@param depth number
---@param width integer
H.render_tree = function(
  tree,
  lines,
  line_map,
  highlights,
  name_offsets,
  depth,
  width
)
  for _, node in ipairs(tree) do
    if node.is_dir then
      -- Dirs display as (possibly collapsed) paths, e.g. "lua/buf" - truncate
      -- from the start so the innermost, most specific segment stays visible.
      local line_str, highlight, name_offset =
        H.format_line(node.name, true, node.path, depth, width, "left")
      table.insert(lines, line_str)
      name_offsets[#lines] = name_offset
      if highlight ~= nil then
        highlight.line = #lines
        table.insert(highlights, highlight)
      end
      H.render_tree(
        node.children,
        lines,
        line_map,
        highlights,
        name_offsets,
        depth + 1,
        width
      )
    else
      -- Files display as bare names - truncate from the end, matching how
      -- names are normally read left-to-right.
      local line_str, highlight, name_offset =
        H.format_line(node.name, false, node.path, depth, width, "right")
      table.insert(lines, line_str)
      name_offsets[#lines] = name_offset
      if highlight ~= nil then
        highlight.line = #lines
        table.insert(highlights, highlight)
      end
      line_map[#lines] = { buf = node.buf, path = node.path, kind = node.kind }
    end
  end
end

-- Appends one flat (depth 0) line per buffer outside cwd or without a file.
-- Adds to the same tables as `render_tree`, keyed by line number. Every entry
-- is openable, so each line also goes into `line_map`.
---@param other_bufs BufEntry[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
---@param highlights HighlightSpec[]
---@param name_offsets table<integer, integer>
---@param width integer
H.render_other = function(
  other_bufs,
  lines,
  line_map,
  highlights,
  name_offsets,
  width
)
  for _, buf_entry in ipairs(other_bufs) do
    -- Other-section entries show their full absolute path (they live outside
    -- cwd), so they truncate left like dirs, not right like tree files.
    local line_str, highlight, name_offset =
      H.format_line(buf_entry.path, false, buf_entry.path, 0, width, "left")
    table.insert(lines, line_str)
    name_offsets[#lines] = name_offset
    if highlight ~= nil then
      highlight.line = #lines
      table.insert(highlights, highlight)
    end
    line_map[#lines] = buf_entry
  end
end

-- Shortens `name` with an ellipsis if it overflows the space left after
-- indent and icon are accounted for. `truncate_side` picks which end gets
-- cut: "left" keeps the tail (for path-like strings, where the rightmost
-- segment is the most identifying part), "right" keeps the front (for bare
-- names, read left-to-right as usual). Measured in display columns rather
-- than bytes: some characters take multiple bytes but one column (e.g.
-- "é"), others take two columns despite being one character (e.g. many CJK
-- characters and emoji), so byte length can't stand in for width in either
-- direction.
---@param name string
---@param line_width integer
---@param indent_width integer
---@param icon_width integer
---@param truncate_side "left" | "right"
---@return string
H.fit_to_width = function(
  name,
  line_width,
  indent_width,
  icon_width,
  truncate_side
)
  local name_width = line_width - indent_width - icon_width

  if name_width <= 0 then
    return ""
  end

  if vim.fn.strwidth(name) <= name_width then
    return name
  end

  -- The ellipsis itself occupies one column of the budget.
  local char_budget = name_width - 1
  if char_budget <= 0 then
    return "…"
  end

  if truncate_side == "right" then
    local kept = ""
    local width = 0
    local idx = 1
    while idx <= #name do
      local char_end = idx + vim.str_utf_end(name, idx)
      local char = string.sub(name, idx, char_end)
      local char_width = vim.fn.strwidth(char)
      if width + char_width > char_budget then
        break
      end
      kept = kept .. char
      width = width + char_width
      idx = char_end + 1
    end
    return kept .. "…"
  else
    local kept = ""
    local width = 0
    local idx = #name
    while idx >= 1 do
      local char_start = idx + vim.str_utf_start(name, idx)
      local char = string.sub(name, char_start, idx)
      local char_width = vim.fn.strwidth(char)
      if width + char_width > char_budget then
        break
      end
      kept = char .. kept
      width = width + char_width
      idx = char_start - 1
    end
    return "…" .. kept
  end
end

-- Builds one display line for a tree or other-section entry. Returns:
--   1. the line string: indent, then icon and a space (if MiniIcons is
--      available), then the (possibly truncated) name
--   2. a HighlightSpec for the icon, or nil without MiniIcons. Its `line` is
--      left unset because only the caller knows which row the line lands on
--   3. the 0-based byte offset where the name starts, i.e. the number of bytes
--      before it. Bytes, not display columns, because nvim_win_set_cursor
--      takes byte columns and icons are multi-byte
---@param name string
---@param is_dir boolean
---@param path string
---@param depth integer
---@param width integer
---@param truncate_side "left" | "right"
---@return string, HighlightSpec|nil, number
H.format_line = function(name, is_dir, path, depth, width, truncate_side)
  local indent_width = depth * 2

  ---@diagnostic disable-next-line: undefined-field
  if _G.MiniIcons == nil then
    return string.rep(" ", indent_width) .. H.fit_to_width(
      name,
      width,
      indent_width,
      0,
      truncate_side
    ),
      nil,
      indent_width
  end

  local category = is_dir and "directory" or "file"
  local icon, hl = _G.MiniIcons.get(category, path)
  local truncated_name =
    H.fit_to_width(name, width, indent_width, 2, truncate_side)
  local line_str = string.rep(" ", indent_width)
    .. icon
    .. " "
    .. truncated_name

  local highlight = {
    col_start = indent_width,
    col_end = indent_width + #icon,
    hl_group = hl,
  }
  return line_str, highlight, indent_width + #icon + 1
end

local M = {}
M._H = H

-- Turns the output of `tree.build()` into everything the float needs to
-- display it, with each line truncated to fit `width` display columns. The
-- `other` section, with its blank separator and header, is only added when
-- there are other buffers. Returns:
--   1. lines: the text for each row, in display order
--   2. line_map: line number -> buffer entry, for openable rows only
--   3. highlights: icon highlights, each with its line number set
--   4. name_offsets: line number -> 0-based byte offset of the name. Header
--      and separator rows have no entry, so lookups there return nil
---@param tree TreeNode[]
---@param other_bufs BufEntry[]
---@param width integer
---@return string[], table<integer, BufEntry>, HighlightSpec[], table<integer, integer>
M.render = function(tree, other_bufs, width)
  local lines = {}
  local line_map = {}
  local highlights = {}
  local name_offsets = {}
  H.render_tree(tree, lines, line_map, highlights, name_offsets, 0, width)
  if #other_bufs > 0 then
    table.insert(lines, "")
    table.insert(lines, "other")
    H.render_other(other_bufs, lines, line_map, highlights, name_offsets, width)
  end

  return lines, line_map, highlights, name_offsets
end

return M
