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

return lib
