-- Table related utils
local lib = {}

-- Return the sorted keys of a table
function lib.sortedkeys(tab)
   local keys={}
   -- create sorted list of keys
   for k,_ in pairs(tab) do table.insert(keys, k) end
   table.sort(keys)
   return keys
end

return lib
