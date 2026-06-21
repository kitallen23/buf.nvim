local H = {}

---@return integer[]
H.get_buffers = function()
  return vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())
end

---@return string
H.get_buf_kind = function(buf, path)
  local buftype = vim.bo[buf].buftype

  local kind
  if buftype == "terminal" then
    kind = "terminal"
  elseif buftype == "help" then
    kind = "help"
  elseif buftype == "quickfix" then
    kind = "quickfix"
  elseif buftype == "" and path ~= "" then
    kind = "file"
  else
    kind = "other"
  end

  return kind
end

---@class BufEntry
---@field buf integer
---@field path string
---@field kind string

---@param buffers integer[]
---@param cwd string
---@return BufEntry[], BufEntry[]
H.classify_buffers = function(buffers, cwd)
  local tree_bufs = {}
  local other_bufs = {}

  for _, buf in ipairs(buffers) do
    local path = vim.api.nvim_buf_get_name(buf)
    local kind = H.get_buf_kind(buf, path)
    if vim.startswith(path, cwd) then
      table.insert(tree_bufs, { buf = buf, path = path, kind = kind })
    else
      table.insert(other_bufs, { buf = buf, path = path, kind = kind })
    end
  end

  return tree_bufs, other_bufs
end

---@class TreeNode
---@field is_dir boolean
---@field name string
---@field path string
---@field children TreeNode[]|nil
---@field buf integer|nil
---@field kind string|nil

-- Builds a nested tree from a flat list of BufEntry items.
-- Example output for src/components/Button.lua, src/utils/foo.lua, README.md:
-- {
--   { is_dir = true, name = "src", path = "src", children = {
--       { is_dir = true, name = "components", path = "src/components", children = {
--           { is_dir = false, name = "Button.lua", buf = 1, path = "...", kind = "file" },
--       }},
--       { is_dir = true, name = "utils", path = "src/utils", children = {
--           { is_dir = false, name = "foo.lua", buf = 2, path = "...", kind = "file" },
--       }},
--   }},
--   { is_dir = false, name = "README.md", buf = 3, path = "...", kind = "file" },
-- }
---@param tree_bufs BufEntry[]
---@param cwd string
---@return TreeNode[]
H.build_tree = function(tree_bufs, cwd)
  local root = { is_dir = true, name = "", children = {} }

  for _, buf_item in ipairs(tree_bufs) do
    local current = root.children
    local relative_path = string.sub(buf_item.path, #cwd + 2)
    local parts = vim.split(relative_path, "/", { trimempty = true })

    for i, path_part in ipairs(parts) do
      if i == #parts then
        table.insert(current, {
          is_dir = false,
          name = path_part,
          buf = buf_item.buf,
          path = relative_path,
          kind = buf_item.kind,
        })
      else
        local existing_dir = nil
        for _, node in ipairs(current) do
          if node.is_dir and node.name == path_part then
            existing_dir = node
            break
          end
        end

        if existing_dir then
          current = existing_dir.children
        else
          local dir_path = table.concat(parts, "/", 1, i)
          table.insert(
            current,
            { is_dir = true, name = path_part, path = dir_path, children = {} }
          )
          current = current[#current].children
        end
      end
    end
  end

  return root.children
end

-- Collapses dir nodes that have only one child dir into a single node with a combined name.
-- e.g. { name = "lua", children = { { name = "buf", ... } } } -> { name = "lua/buf", ... }
-- Recurses bottom-up so deeply nested dirs are collapsed before their parents.
---@param tree TreeNode[]
---@return TreeNode[]
H.collapse_tree = function(tree)
  local result = {}
  for _, node in ipairs(tree) do
    if node.is_dir then
      local children = H.collapse_tree(node.children)
      if #children == 1 and children[1].is_dir then
        table.insert(result, {
          is_dir = node.is_dir,
          name = node.name .. "/" .. children[1].name,
          path = children[1].path,
          children = children[1].children,
        })
      else
        table.insert(result, {
          is_dir = node.is_dir,
          name = node.name,
          path = node.path,
          children = children,
        })
      end
    else
      table.insert(result, node)
    end
  end
  return result
end

-- Sorts tree nodes dirs-before-files, then alphabetically within each group.
-- Recurses into children.
---@param tree TreeNode[]
---@return TreeNode[]
H.sort_tree = function(tree)
  local sorted = vim.deepcopy(tree)
  table.sort(sorted, function(a, b)
    if a.is_dir ~= b.is_dir then
      return a.is_dir == true
    end
    return a.name < b.name
  end)
  local result = {}
  for _, node in ipairs(sorted) do
    if node.is_dir then
      table.insert(result, {
        is_dir = node.is_dir,
        name = node.name,
        path = node.path,
        children = H.sort_tree(node.children),
      })
    else
      table.insert(result, node)
    end
  end
  return result
end

local M = {}

---@return TreeNode[], BufEntry[]
M.build = function()
  local cwd = assert(vim.uv.cwd())
  local buffers = H.get_buffers()
  local tree_bufs, other_bufs = H.classify_buffers(buffers, cwd)

  local tree = H.build_tree(tree_bufs, cwd)
  local collapsed_tree = H.collapse_tree(tree)

  table.sort(other_bufs, function(a, b)
    return a.path < b.path
  end)

  return H.sort_tree(collapsed_tree), other_bufs
end

return M
