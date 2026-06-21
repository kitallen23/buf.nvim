---@class HighlightSpec
---@field line integer
---@field col_start integer
---@field col_end integer
---@field hl_group string

local H = {}

---@param tree TreeNode[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
---@param depth number
H.render_tree = function(tree, lines, line_map, depth, width)
  for _, node in ipairs(tree) do
    if node.type == "dir" then
      table.insert(lines, H.format_line(node.name, "dir", depth, width))
      H.render_tree(node.children, lines, line_map, depth + 1, width)
    else
      table.insert(lines, H.format_line(node.name, node.kind, depth, width))
      line_map[#lines] = { buf = node.buf, path = node.path, kind = node.kind }
    end
  end
end

---@param other_bufs BufEntry[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
H.render_other = function(other_bufs, lines, line_map, width)
  table.insert(lines, "  other")
  for _, buf_entry in ipairs(other_bufs) do
    table.insert(lines, H.format_line(buf_entry.path, buf_entry.kind, 0, width))
    line_map[#lines] = buf_entry
  end
end

  -- TODO: Finish this fn
---@param name string
---@param kind string
---@param depth integer
---@return string
H.format_line = function(name, kind, depth, width)
  local indent_width = depth * 2
  local icon_width = 0

  local line_str = name

  ---@diagnostic disable-next-line: undefined-field
  if _G.MiniIcons ~= nil then
    icon_width = 2
  -- else
    -- if #line_str > width then
    --   line_str = "<" .. string.sub(line_str, #line_str - width + 2)
    -- end
  end
  local name_width = width - indent_width - icon_width

  -- if #line_str > name_width then
  -- end
  -- line_str = 
  return line_str
end

local M = {}

---@param tree TreeNode[]
---@param other_bufs BufEntry[]
---@param width integer
---@return string[], table<integer, BufEntry>, HighlightSpec[]
M.render = function(tree, other_bufs, width)
  local lines = {}
  local line_map = {}
  local highlights = {}
  H.render_tree(tree, lines, line_map, 0, width)
  H.render_other(other_bufs, lines, line_map, width)

  return lines, line_map, highlights
end

return M
