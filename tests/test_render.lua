local MiniTest = require("mini.test")
local T = MiniTest.new_set()

local render = require("buf.render")

T["fit_to_width"] = MiniTest.new_set()
T["fit_to_width"]["truncates left, keeping the tail"] = function()
  local truncated = render._H.fit_to_width(
    "a_very_long_filename_that_needs_to_wrap",
    20,
    0,
    0,
    "left"
  )
  MiniTest.expect.equality(truncated, "…_that_needs_to_wrap")
end
T["fit_to_width"]["truncates right, keeping the head"] = function()
  local truncated = render._H.fit_to_width(
    "a_very_long_filename_that_needs_to_wrap",
    20,
    0,
    0,
    "right"
  )
  MiniTest.expect.equality(truncated, "a_very_long_filenam…")
end
T["fit_to_width"]["doesn't truncate left or right with short strings"] = function()
  local test_str = "short"
  local truncated_left = render._H.fit_to_width(test_str, 20, 0, 0, "left")
  local truncated_right = render._H.fit_to_width(test_str, 20, 0, 0, "right")
  MiniTest.expect.equality(truncated_left, test_str)
  MiniTest.expect.equality(truncated_right, test_str)
end

T["fit_to_width"]["boundary conditions"] = MiniTest.new_set()
local boundary = T["fit_to_width"]["boundary conditions"]
boundary["doesn't truncate when the name is exactly the width of the budget"] = function()
  local test_str = "123456789"
  local truncated = render._H.fit_to_width(test_str, 9, 0, 0, "left")
  MiniTest.expect.equality(truncated, test_str)
end
boundary["truncates when the name is exactly one character over the budget"] = function()
  local test_str = "123456789"
  local truncated_left = render._H.fit_to_width(test_str, 8, 0, 0, "left")
  local truncated_right = render._H.fit_to_width(test_str, 8, 0, 0, "right")
  MiniTest.expect.equality(truncated_left, "…3456789")
  MiniTest.expect.equality(truncated_right, "1234567…")
end

-- icon_width and indent_width actually eating into the budget
--- "accounts for icon width when computing how much of the name fits" — a case
--- with icon_width > 0 and indent_width = 0, checking the truncation point
--- shifts accordingly.
--- "accounts for indent and icon width together when computing how much of the
--- name fits" — both non-zero at once, since they're summed together in
--- name_width and could mask a bug in either one alone.
T["fit_to_width"]["icon_width and indent_width use budget"] = MiniTest.new_set()
local icon_and_indent_width =
  T["fit_to_width"]["icon_width and indent_width use budget"]
icon_and_indent_width["accounts for icon width when computing how much of the name fits"] = function() end
icon_and_indent_width["accounts for indent and icon width together when computing how much of the name fits"] = function() end

-- Extreme/narrow widths
--- "truncates down to just the ellipsis when the budget leaves no room for any
--- characters" — name_width at 1 or 0, checking it doesn't error or produce
--- something malformed.
--- "doesn't error when indent and icon width alone exceed the line width" —
--- name_width computes negative; worth knowing what actually happens (crash?
--- empty string? something weird) rather than assuming.
T["fit_to_width"]["extreme_widths"] = MiniTest.new_set()
local extreme_widths = T["fit_to_width"]["extreme_widths"]
extreme_widths["truncates down to just the ellipsis when the budget leaves no room for any characters"] = function() end
extreme_widths["doesn't error when indent and icon width alone exceed the line width"] = function() end

-- Input edge cases
--- "returns an empty string unchanged" — trivial, but worth locking in
--- since "" is a plausible real input (e.g. an unnamed buffer).

-- Multi-byte characters (this one might actually surface a real bug, not just
-- confirm existing behavior)
--- "doesn't mangle a multi-byte character when truncating near it" — a name
--- with a non-ASCII character (e.g. an accented letter or emoji) positioned
--- right at the truncation boundary. #name counts bytes, not display columns,
--- and string.sub cuts on byte offsets — so a truncation point landing
--- mid-character could produce invalid UTF-8. Worth writing even if you expect
--- it to fail, since that tells you something real about current behavior.

-- That last category is the one I'd prioritize if you only pick a few — it's
-- testing something you haven't reasoned through by hand yet, unlike the others
-- which mostly confirm formulas you already derived.

return T
