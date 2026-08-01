---@class HighlightSpec
---@field line integer
---@field col_start integer
---@field col_end integer
---@field hl_group string

local H = {}

---@param tree TreeNode[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
---@param highlights HighlightSpec[]
---@param depth number
---@param width integer
H.render_tree = function(tree, lines, line_map, highlights, depth, width)
  for _, node in ipairs(tree) do
    if node.is_dir then
      -- Dirs display as (possibly collapsed) paths, e.g. "lua/buf" - truncate
      -- from the start so the innermost, most specific segment stays visible.
      local line_str, highlight =
        H.format_line(node.name, true, node.path, depth, width, "left")
      table.insert(lines, line_str)
      if highlight ~= nil then
        highlight.line = #lines
        table.insert(highlights, highlight)
      end
      H.render_tree(
        node.children,
        lines,
        line_map,
        highlights,
        depth + 1,
        width
      )
    else
      -- Files display as bare names - truncate from the end, matching how
      -- names are normally read left-to-right.
      local line_str, highlight =
        H.format_line(node.name, false, node.path, depth, width, "right")
      table.insert(lines, line_str)
      if highlight ~= nil then
        highlight.line = #lines
        table.insert(highlights, highlight)
      end
      line_map[#lines] = { buf = node.buf, path = node.path, kind = node.kind }
    end
  end
end

---@param other_bufs BufEntry[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
---@param highlights HighlightSpec[]
---@param width integer
H.render_other = function(other_bufs, lines, line_map, highlights, width)
  for _, buf_entry in ipairs(other_bufs) do
    -- Other-section entries show their full absolute path (they live outside
    -- cwd), so they truncate left like dirs, not right like tree files.
    local line_str, highlight =
      H.format_line(buf_entry.path, false, buf_entry.path, 0, width, "left")
    table.insert(lines, line_str)
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
-- names, read left-to-right as usual).
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

  if #name > name_width then
    if truncate_side == "left" then
      return "…" .. string.sub(name, #name - name_width + 2)
    else
      return string.sub(name, 1, name_width - 1) .. "…"
    end
  end
  return name
end

---@param name string
---@param is_dir boolean
---@param path string
---@param depth integer
---@param width integer
---@param truncate_side "left" | "right"
---@return string, HighlightSpec|nil
H.format_line = function(name, is_dir, path, depth, width, truncate_side)
  local indent_width = depth * 2

  ---@diagnostic disable-next-line: undefined-field
  if _G.MiniIcons == nil then
    return H.fit_to_width(name, width, indent_width, 0, truncate_side), nil
  end

  local category = is_dir and "directory" or "file"
  local icon, hl = _G.MiniIcons.get(category, path)
  local truncated_name =
    H.fit_to_width(name, width, indent_width, 2, truncate_side)
  local line_str = icon .. " " .. truncated_name

  local highlight = {
    col_start = indent_width,
    col_end = indent_width + #icon,
    hl_group = hl,
  }
  return line_str, highlight
end

local M = {}
M._H = H

---@param tree TreeNode[]
---@param other_bufs BufEntry[]
---@param width integer
---@return string[], table<integer, BufEntry>, HighlightSpec[]
M.render = function(tree, other_bufs, width)
  local lines = {}
  local line_map = {}
  local highlights = {}
  H.render_tree(tree, lines, line_map, highlights, 0, width)
  table.insert(lines, "  other")
  H.render_other(other_bufs, lines, line_map, highlights, width)

  return lines, line_map, highlights
end

return M
