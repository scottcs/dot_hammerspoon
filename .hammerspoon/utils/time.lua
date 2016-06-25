-- Time and date related utils
local lib = {}

-- Sleep for (possibly fractional) number of seconds
local clock = os.clock
function lib.sleep(n)  -- seconds
   local t0 = clock()
   while clock() - t0 <= n do end
end

-- Helper for timers that returns true if "time" has reached "when"
function lib.timesUp(time, when)
  return time > 0 and time % when == 0
end

-- Return a string that represents a date based on the given epoch seconds.
function lib.todate(secs)
  local date = os.date('*t', secs)
  local hour = date.hour
  local ap = 'am'

  if date.hour > 11 then ap = 'pm' end
  if date.hour == 0 then hour = 12 end
  if date.hour > 12 then hour = date.hour - 12 end

  date.hour12 = hour
  date.ap = ap

  return date
end

-- Return a string that represents an hour based on the given epoch seconds.
function lib.tohour(secs)
  local date = lib.todate(secs)
  -- if date.hour == 0 then return 'Midnight' end
  -- if date.hour == 12 then return 'Noon' end
  return string.format('%d%s', date.hour12, date.ap)
end

-- Return a string that represents an hour with minutes, based on the given
-- epoch seconds.
function lib.tohourmin(secs)
  local date = lib.todate(secs)
  -- if date.hour == 0 and date.min == 0 then return 'Midnight' end
  -- if date.hour == 12 and date.min == 0 then return 'Noon' end
  return string.format('%d:%02d%s', date.hour12, date.min, date.ap)
end

-- Return a string of the name of the day represented by the given epoch
-- seconds.
function lib.todayname(secs) return os.date('%a', secs) end

-- Return a string that converts a number of minutes into MM:SS format.
function lib.prettyMinutes(minutes)
  return string.format('%02d:%02d', math.floor(minutes/60), minutes%60)
end

return lib
