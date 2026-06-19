local H = {}

---@param tree TreeNode[]
---@param lines string[]
---@param line_map table<integer, BufEntry>
---@param depth number
H.render_tree = function(tree, lines, line_map, depth, width)
  for _, node in ipairs(tree) do
    if node.type == "dir" then
      table.insert(lines, H.format_line(node.name, depth, width))
      H.render_tree(node.children, lines, line_map, depth + 1, width)
    else
      table.insert(lines, H.format_line(node.name, depth, width))
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
    table.insert(lines, H.format_line(buf_entry.path, 0, width))
    line_map[#lines] = buf_entry
  end
end

---@param str string
---@param depth integer
---@return string
H.format_line = function(str, depth, width)
  local line_str = string.rep(" ", depth * 2) .. str
  if #line_str > width then
    line_str = "<" .. string.sub(line_str, #line_str - width + 2)
  end
  return line_str
end

local M = {}

---@param tree TreeNode[]
---@param other_bufs BufEntry[]
---@param width number
---@return string[], table<integer, BufEntry>
M.render = function(tree, other_bufs, width)
  local lines = {}
  local line_map = {}
  H.render_tree(tree, lines, line_map, 0, width)
  H.render_other(other_bufs, lines, line_map, width)

  return lines, line_map
end

return M
