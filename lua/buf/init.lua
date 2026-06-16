local M = {}

M.config = require('buf.config').default_config

M.setup = function(config)
  M.config = require('buf.config').validate_config(config)
end

return M
