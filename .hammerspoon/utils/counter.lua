-- Provides a counter object for counting things
local lib = {}

-- Create a new counter with the given name and first value.
-- If the first value is 0 (default), the counter will count upward,
-- otherwise the counter will count downward.
function lib.new(name, begin)
  local first = begin or 0
  local amt = first == 0 and 1 or -1
  local i = first
  local repr = 'counter (' .. (name or 'unnamed') .. '): '

  return {
    -- increment/decrement the counter (depending on first value == 0 or not)
    incr = function() i = i + amt end,
    -- reset the counter to the first value
    reset = function() i = first end,
    -- get the current count
    get = function() return i end,
    -- get a string representation of the counter (useful for debugging)
    asString = function() return repr .. i end,
  }
end

return lib
