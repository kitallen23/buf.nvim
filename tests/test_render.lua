local MiniTest = require("mini.test")
local T = MiniTest.new_set()

local render = require("buf.render")

-- Runs fit_to_width for both truncate_side values and asserts the results
-- against expected_left/expected_right in one call, since most cases test
-- both sides against the same input.
---@param name string
---@param line_width number
---@param indent_width number
---@param icon_width number
---@param expected_left string
---@param expected_right string
local function assert_fit(
  name,
  line_width,
  indent_width,
  icon_width,
  expected_left,
  expected_right
)
  local left =
    render._H.fit_to_width(name, line_width, indent_width, icon_width, "left")
  local right =
    render._H.fit_to_width(name, line_width, indent_width, icon_width, "right")
  MiniTest.expect.equality(left, expected_left)
  MiniTest.expect.equality(right, expected_right)
end

T["fit_to_width"] = MiniTest.new_set(nil, {
  ["truncates left, keeping the tail"] = function()
    local truncated = render._H.fit_to_width(
      "a_very_long_filename_that_needs_to_wrap",
      20,
      0,
      0,
      "left"
    )
    MiniTest.expect.equality(truncated, "…_that_needs_to_wrap")
  end,
  ["truncates right, keeping the head"] = function()
    local truncated = render._H.fit_to_width(
      "a_very_long_filename_that_needs_to_wrap",
      20,
      0,
      0,
      "right"
    )
    MiniTest.expect.equality(truncated, "a_very_long_filenam…")
  end,
  ["doesn't truncate left or right with short strings"] = function()
    local test_str = "short"
    assert_fit(test_str, 20, 0, 0, test_str, test_str)
  end,

  ["boundary conditions"] = MiniTest.new_set(nil, {
    ["doesn't truncate when the name is exactly the width of the budget"] = function()
      local test_str = "123456789"
      local truncated = render._H.fit_to_width(test_str, 9, 0, 0, "left")
      MiniTest.expect.equality(truncated, test_str)
    end,
    ["truncates when the name is exactly one character over the budget"] = function()
      assert_fit("123456789", 8, 0, 0, "…3456789", "1234567…")
    end,
  }),

  ["icon_width and indent_width use budget"] = MiniTest.new_set(nil, {
    ["accounts for icon width when computing how much of the name fits"] = function()
      assert_fit("123456789", 8, 0, 4, "…789", "123…")
    end,
    ["accounts for indent and icon width together when computing how much of the name fits"] = function()
      assert_fit("123456789", 8, 2, 1, "…6789", "1234…")
    end,
  }),

  ["extreme widths"] = MiniTest.new_set(nil, {
    ["truncates down to just the ellipsis when the budget leaves room for a single character"] = function()
      local test_str = "123456789"
      local ellipsis_only = render._H.fit_to_width(test_str, 9, 4, 4, "left")
      MiniTest.expect.equality(ellipsis_only, "…")
    end,
    ["truncates down to empty string when the budget leaves no room for any characters"] = function()
      local test_str = "123456789"
      local empty_string = render._H.fit_to_width(test_str, 9, 5, 4, "left")
      MiniTest.expect.equality(empty_string, "")
    end,
    ["doesn't error when indent and icon width alone exceed the line width"] = function()
      local test_str = "123456789"
      local empty_string = render._H.fit_to_width(test_str, 9, 10, 10, "left")
      MiniTest.expect.equality(empty_string, "")
    end,
  }),

  ["input edge cases"] = MiniTest.new_set(nil, {
    ["returns an empty string unchanged"] = function()
      assert_fit("", 9, 2, 2, "", "")
    end,
  }),

  ["multi-byte characters"] = MiniTest.new_set(nil, {
    ["doesn't mangle a multi-byte single-column character when truncating near it"] = function()
      -- bytes: a b c [0xC3 0xA9] x y z (8 bytes total)
      local name = "abc" .. "é" .. "xyz"
      -- with line_width = 5, name_width - 1 = 4, landing on byte 4 = 0xC3
      -- (é's first byte)
      assert_fit(name, 5, 0, 0, "…éxyz", "abcé…")
    end,
    ["doesn't mangle a multi-byte multi-column character when truncating near it"] = function()
      local name = "あabc" .. "中" .. "xyzあ"
      assert_fit(name, 8, 0, 0, "…中xyzあ", "あabc中…")
      assert_fit(name, 7, 0, 0, "…xyzあ", "あabc…")
    end,
  }),
})

-- 4 bytes, 2 display columns: makes byte vs. column mix-ups visible in offsets.
local STUB_ICON = "🔥"
-- Wide enough that no test name is truncated, so the name after the offset is
-- the name unchanged.
local WIDE_LINE = 40

-- Asserts the offset is exactly where the name starts, by checking the
-- 1-based substring after the 0-based offset.
---@param line string
---@param offset integer
---@param name string
local function expect_name_at_offset(line, offset, name)
  MiniTest.expect.equality(line:sub(offset + 1), name)
end

T["format_line"] = MiniTest.new_set(nil, {
  ["name offset with MiniIcons"] = MiniTest.new_set({
    hooks = {
      pre_case = function()
        _G.MiniIcons = {
          get = function(_, _)
            return STUB_ICON, "SomeHlGroup"
          end,
        }
      end,
      -- In a hook so the stub is removed even when an assertion fails.
      post_case = function()
        _G.MiniIcons = nil
      end,
    },
  }, {
    ["is icon bytes plus one space at depth 0"] = function()
      local line, _, offset =
        render._H.format_line("init.lua", false, "init.lua", 0, WIDE_LINE, "right")
      MiniTest.expect.equality(offset, #STUB_ICON + 1)
      expect_name_at_offset(line, offset, "init.lua")
    end,
    ["includes indent bytes when nested"] = function()
      local line, _, offset =
        render._H.format_line("init.lua", false, "a/b/init.lua", 2, WIDE_LINE, "right")
      MiniTest.expect.equality(offset, 4 + #STUB_ICON + 1)
      expect_name_at_offset(line, offset, "init.lua")
    end,
    ["points at the name for directories too"] = function()
      local line, _, offset =
        render._H.format_line("lua/buf", true, "lua/buf", 1, WIDE_LINE, "left")
      MiniTest.expect.equality(offset, 2 + #STUB_ICON + 1)
      expect_name_at_offset(line, offset, "lua/buf")
    end,
  }),

  ["name offset without MiniIcons"] = MiniTest.new_set(nil, {
    ["is 0 at depth 0"] = function()
      local line, _, offset =
        render._H.format_line("init.lua", false, "init.lua", 0, WIDE_LINE, "right")
      MiniTest.expect.equality(offset, 0)
      expect_name_at_offset(line, offset, "init.lua")
    end,
    ["is the indent width when nested"] = function()
      local line, _, offset =
        render._H.format_line("init.lua", false, "a/b/init.lua", 2, WIDE_LINE, "right")
      MiniTest.expect.equality(offset, 4)
      expect_name_at_offset(line, offset, "init.lua")
    end,
  }),
})

T["render_tree"] = MiniTest.new_set(nil, {
  ["adds a line for each directory"] = function() end,
  ["uses correct indentation for nested directories"] = function() end,
  ["adds a line for each file"] = function() end,
  ["uses correct indentation for files nested within directories"] = function() end,
  ["adds files into the line_map"] = function() end,

  ["doesn't add directories into the line_map"] = function() end,
  ["sets each highlight's line to the row its line was inserted at"] = function()
    _G.MiniIcons = {
      get = function(_, _)
        return "🔥", "SomeHlGroup"
      end,
    }

    -- build tree, call render_tree, run your assertions here

    _G.MiniIcons = nil
  end,
  ["doesn't modify lines, line_map or highlights when tree is empty"] = function() end,
})

return T
