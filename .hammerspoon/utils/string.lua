-- String related utils
local lib = {}

-- split a string
function lib.split(str, pat)
  local t = {}  -- NOTE: use {n = 0} in Lua-5.0
  local fpat = "(.-)" .. pat
  local lastEnd = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(t,cap)
    end
    lastEnd = e+1
    s, e, cap = str:find(fpat, lastEnd)
  end
  if lastEnd <= #str then
    cap = str:sub(lastEnd)
    table.insert(t, cap)
  end
  return t
end

-- trim a string
function lib.trim(str)
  return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
end

-- remove surrounding quotes from a string
function lib.unquote(str)
  local newStr = str:match("['\"](.-)['\"]")
  if newStr ~= nil then return newStr end
  return str
end

-- string begins with another string
function lib.beginsWith(str, other)
   return string.sub(str, 1, string.len(other)) == other
end

-- string ends with another string
function lib.endsWith(str, other)
   return string.sub(str, -string.len(other)) == other
end

-- chop off the beginning of a string if it matches the other string
function lib.chopBeginning(str, beginning)
  if lib.beginsWith(str, beginning) then
    return string.sub(str, string.len(beginning))
  end
  return str
end

return lib
