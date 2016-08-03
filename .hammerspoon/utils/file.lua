-- File and directory related utilities
local lib = {}

-- Return true if the file exists, else false
function lib.exists(name)
  local f = io.open(name,'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

-- Takes a list of path parts, returns a string with the parts delimited by '/'
function lib.toPath(...) return table.concat({...}, '/') end

-- Splits a string by '/', returning the parent dir, filename (with extension),
-- and the extension alone.
function lib.splitPath(file)
  local parent = file:match('(.+)/[^/]+$')
  if parent == nil then parent = '.' end
  local filename = file:match('/([^/]+)$')
  if filename == nil then filename = file end
  local ext = filename:match('%.([^.]+)$')
  return parent, filename, ext
end

-- Make a parent dir for a file. Does not error if it exists already.
function lib.makeParentDir(path)
  local parent, _, _ = lib.splitPath(path)
  local ok, err = hs.fs.mkdir(parent)
  if ok == nil then
    if err == 'File exists' then
      ok = true
    end
  end
  return ok, err
end

-- Create a file (making parent directories if necessary).
function lib.create(path)
  if lib.makeParentDir(path) then
    io.open(path, 'w'):close()
  end
end

-- Append a line of text to a file.
function lib.append(file, text)
  if text == '' then return end

  local f = io.open(file, 'a')
  f:write(tostring(text) .. '\n')
  f:close()
end

-- Move a file. This calls task (so runs asynchronously), so calls onSuccess
-- and onFailure callback functions depending on the result. Set force to true
-- to overwrite.
function lib.move(from, to, force, onSuccess, onFailure)
  force = force and '-f' or '-n'

  local function callback(exitCode, stdOut, stdErr)
    if exitCode == 0 then
      onSuccess(stdOut)
    else
      onFailure(stdErr)
    end
  end

  if lib.exists(from) then
    hs.task.new('/bin/mv', callback, {force, from, to}):start()
  end
end

-- If the given file is older than the given time (in epoch seconds), return
-- true. This checks the inode change time, not the original file creation
-- time.
function lib.isOlderThan(file, seconds)
  local age = os.time() - hs.fs.attributes(file, 'change')
  if age > seconds then return true end
  return false
end

-- Return the last modified time of a file in epoch seconds.
function lib.lastModified(file)
  local when = os.time()
  if lib.exists(file) then when = hs.fs.attributes(file, 'modification') end
  return when
end

-- If any files are found in the given path, make a list of them and call the
-- given callback function with that list.
function lib.runOnFiles(path, callback)
  local iter, data = hs.fs.dir(path)
  local files = {}
  repeat
    local item = iter(data)
    if item ~= nil then table.insert(files, lib.toPath(path, item)) end
  until item == nil
  if #files > 0 then callback(files) end
end

-- Unhide the extension on the given file, if it matches the extension given,
-- and that extension does not exist in the given hiddenExtensions table.
function lib.unhideExtension(file, ext, hiddenExtensions)
  if ext == nil or hiddenExtensions == nil or hiddenExtensions[ext] == nil then
    local function unhide(exitCode, stdOut, stdErr)
      if exitCode == 0 and tonumber(stdOut) == 1 then
        hs.task.new('/usr/bin/SetFile', nil, {'-a', 'e', file}):start()
      end
    end
    hs.task.new('/usr/bin/GetFileInfo', unhide, {'-aE', file}):start()
  end
end

-- Returns true if the file has any default OS X color tag enabled.
function lib.isColorTagged(file)
  local colors = {
    Red = true,
    Orange = true,
    Yellow = true,
    Green = true,
    Blue = true,
    Purple = true,
    Gray = true,
  }
  local tags = hs.fs.tagsGet(file)

  if tags ~= nil then
    for _,tag in ipairs(tags) do
      if colors[tag] then return true end
    end
  end
  return false
end

-- Simply set a single tag on a file
function lib.setTag(file, tag) hs.fs.tagsAdd(file, {tag}) end

-- Return a string that ensures the given file ends with the given extension.
function lib.withExtension(filePath, ext)
  local path = filePath
  local extMatch = '%.'..ext..'$'
  if not string.find(path, extMatch) then path = path..'.'..ext end
  return path
end

-- load a json file into a lua table and return it
function lib.loadJSON(file)
  local data = nil
  local f = io.open(file, 'r')
  if f then
    local content = f:read('*all')
    f:close()
    if content then
      ok, data = pcall(function() return hs.json.decode(content) end)
      if not ok then
        hsm.log.e('loadJSON:', data)
        data = nil
      end
    end
  end
  return data
end

-- Find the most recent path in a directory
-- attr should be one of: access, change, modification, creation
function lib.mostRecent(parent, attr)
  if not lib.exists(parent) then return nil end

  -- make sure attr is valid and default to modification
  local attrs = {access=true, change=true, modification=true, creation=true}
  if not attrs[attr] then attr = 'modification' end

  local max = 0
  local mostRecent = nil
  local iterFn, dirObj = hs.fs.dir(parent)
  local child = iterFn(dirObj)
  while child do
    -- ignore dotfiles
    if string.find(child, '^[^%.]') then
      local path = lib.toPath(parent, child)
      local last = hs.fs.attributes(path, attr)
      if last > max then
        mostRecent = path
        max = last
      end
    end
    child = iterFn(dirObj)
  end

  return mostRecent
end

return lib
