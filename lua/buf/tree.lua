local H = {}

H.get_buffers = function()
  return vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())
end

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
---@field type "file"|"dir"
---@field name string
---@field children TreeNode[]|nil
---@field buf integer|nil
---@field path string|nil
---@field kind string|nil

-- Builds a nested tree from a flat list of BufEntry items.
-- Example output for src/components/Button.lua, src/utils/foo.lua, README.md:
-- {
--   { type = "dir", name = "src/", children = {
--       { type = "dir", name = "components/", children = {
--           { type = "file", name = "Button.lua", buf = 1, path = "...", kind = "file" },
--       }},
--       { type = "dir", name = "utils/", children = {
--           { type = "file", name = "foo.lua", buf = 2, path = "...", kind = "file" },
--       }},
--   }},
--   { type = "file", name = "README.md", buf = 3, path = "...", kind = "file" },
-- }
---@param tree_bufs BufEntry[]
---@param cwd string
---@return TreeNode[]
H.build_tree = function(tree_bufs, cwd)
  local root = { type = "dir", name = "", children = {} }

  for _, buf_item in ipairs(tree_bufs) do
    local current = root.children
    local relative_path = string.sub(buf_item.path, #cwd + 2)
    local parts = vim.split(relative_path, "/", { trimempty = true })

    for i, path_part in ipairs(parts) do
      if i == #parts then
        table.insert(current, {
          type = "file",
          name = path_part,
          buf = buf_item.buf,
          path = relative_path,
          kind = buf_item.kind,
        })
      else
        local existing_dir = nil
        for _, node in ipairs(current) do
          if node.type == "dir" and node.name == path_part then
            existing_dir = node
            break
          end
        end

        if existing_dir then
          current = existing_dir.children
        else
          table.insert(
            current,
            { type = "dir", name = path_part, children = {} }
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
    if node.type == "dir" then
      local children = H.collapse_tree(node.children)
      if #children == 1 and children[1].type == "dir" then
        table.insert(result, {
          type = node.type,
          name = node.name .. "/" .. children[1].name,
          children = children[1].children,
        })
      else
        table.insert(result, {
          type = node.type,
          name = node.name,
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
    if a.type ~= b.type then
      return a.type == "dir"
    end
    return a.name < b.name
  end)
  local result = {}
  for _, node in ipairs(sorted) do
    if node.type == "dir" then
      table.insert(result, {
        type = node.type,
        name = node.name,
        children = H.sort_tree(node.children),
      })
    else
      table.insert(result, node)
    end
  end
  return result
end

local M = {}
M.build = function()
  local cwd = assert(vim.uv.cwd())
  local buffers = H.get_buffers()
  local tree_bufs, other_bufs = H.classify_buffers(buffers, cwd)

  local tree = H.build_tree(tree_bufs, cwd)
  local collapsed_tree = H.collapse_tree(tree)

  return H.sort_tree(collapsed_tree), other_bufs
end
return M
