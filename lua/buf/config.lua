local M = {}
local H = {}

M.default_config = {
  -- General options
  options = {
    -- Whether to show file type icons next to buffer names
    icons = true,
  },

  -- Indicators shown next to buffers in special states.
  -- Set to '' to disable a particular indicator.
  indicators = {
    -- Shown next to buffers with unsaved changes
    modified = '[+]',
    -- Shown next to read-only buffers
    readonly = '[RO]',
  },

  -- Floating window appearance and placement
  window = {
    -- Position on screen. One of:
    -- 'top_left', 'top_center', 'top_right',
    -- 'center_left', 'center', 'center_right',
    -- 'bottom_left', 'bottom_center', 'bottom_right'
    position = 'center',

    -- Border style, passed to `nvim_open_win()`'s `border` option.
    -- Default: follows `vim.o.winborder`, falling back to 'single'
    -- if that is unset.
    border = nil,

    -- Window width, in columns
    width = 60,

    -- Minimum window height, in rows
    height_min = 6,

    -- Maximum window height, in rows. The rendered height is always
    -- `min(screen_height - padding, height_max)`, and the buffer list
    -- becomes scrollable if it exceeds this height.
    height_max = 20,
  },

  -- Key mappings for the floating window buffer.
  -- Set an entry to '' to disable that mapping.
  -- Every action is also exposed as a function (e.g. `M.toggle_pin()`), so a
  -- mapping can be disabled here and rebound to a custom function instead.
  mappings = {
    -- Enter filter mode
    filter = '/',

    -- Toggle pin on the buffer under the cursor
    toggle_pin = 'p',

    -- Close the floating window
    close = 'q',

    -- Delete (close) the buffer under the cursor
    delete = 'dd',

    -- Open the buffer under the cursor in the current window
    open = '<CR>',

    -- Open the buffer under the cursor in a vertical split
    open_vsplit = 'gv',

    -- Open the buffer under the cursor in a horizontal split
    open_split = 'gs',

    -- Show help with current keybindings
    help = 'g?',
  },
}

M.validate_config = function(config)
  H.check_type('config', config, 'table', true)
  config = vim.tbl_deep_extend('force', vim.deepcopy(M.default_config), config or {})

  H.check_type('options', config.options, 'table')
  H.check_type('options.icons', config.options.icons, 'boolean')

  H.check_type('indicators', config.indicators, 'table')
  H.check_type('indicators.modified', config.indicators.modified, 'string')
  H.check_type('indicators.readonly', config.indicators.readonly, 'string')

  H.check_type('window', config.window, 'table')
  H.check_type('window.position', config.window.position, 'string')
  H.check_type('window.border', config.window.border, 'string', true)
  H.check_type('window.width', config.window.width, 'number')
  H.check_type('window.height_min', config.window.height_min, 'number')
  H.check_type('window.height_max', config.window.height_max, 'number')

  H.check_type('mappings', config.mappings, 'table')
  H.check_type('mappings.filter', config.mappings.filter, 'string')
  H.check_type('mappings.toggle_pin', config.mappings.toggle_pin, 'string')
  H.check_type('mappings.close', config.mappings.close, 'string')
  H.check_type('mappings.delete', config.mappings.delete, 'string')
  H.check_type('mappings.open', config.mappings.open, 'string')
  H.check_type('mappings.open_vsplit', config.mappings.open_vsplit, 'string')
  H.check_type('mappings.open_split', config.mappings.open_split, 'string')
  H.check_type('mappings.help', config.mappings.help, 'string')

  return config
end

-- Raise an error prefixed with the plugin name, with no file:line info
-- (since the prefix already tells the user where the error came from).
H.error = function(msg) error('(buf.nvim) ' .. msg, 0) end

-- Check that `val` has the Lua type named by `ref` (e.g. 'string', 'boolean').
-- `allow_nil` lets the field be omitted/`nil` without erroring.
H.check_type = function(name, val, ref, allow_nil)
  if type(val) == ref or (allow_nil and val == nil) then return end
  H.error(string.format('`%s` should be %s, not %s', name, ref, type(val)))
end

return M
