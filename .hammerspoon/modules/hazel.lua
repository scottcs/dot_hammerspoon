-- module: Hazel - automatic file system actions
-- (Inspired by the Hazel app, by noodlesoft)
--
-- Configuring this module really entails modifying/writing new code within the
-- module. There is some configuration defined in config.lua, but that's only
-- useful if you want to use this module exactly as-is.
--
local m = {}

local ufile = require('utils.file')
local uapp = require('utils.app')

-- time constants
local TIME = {}
TIME.MINUTE = 60
TIME.HOUR = TIME.MINUTE * 60
TIME.DAY = TIME.HOUR * 24
TIME.WEEK = TIME.DAY * 7

-- directory watchers
local watch = {
  downloads = nil,
  dump = nil,
  desktop = nil,
  documents = nil,
}

local timer = nil

-- move a given file to toPath, overwriting the destination, with logging
local function moveFileToPath(file, toPath)
  local function onFileMoveSuccess(_)
    m.log.i('Moved '..file..' to '..toPath)
  end

  local function onFileMoveFailure(stdErr)
    m.log.e('Error moving '..file..' to '..toPath..': '..stdErr)
  end

  ufile.makeParentDir(toPath)
  ufile.move(file, toPath, true, onFileMoveSuccess, onFileMoveFailure)
end

-- a filter that returns true if the given file should be ignored
local function ignored(file)
  if file == nil then return true end

  local _, filename, _ = ufile.splitPath(file)

  -- ignore dotfiles
  if filename:match('^%.') then return true end

  return false
end

----------------------------------------------------------------------
----------------------------------------------------------------------
-- NOTE: Be careful not to modify a file each time it is watched.
-- This will cause the watch* function to be re-run every m.cfg.waitTime
-- seconds, since the file gets modified each time, which triggers the
-- watch* function again.
----------------------------------------------------------------------
----------------------------------------------------------------------

-- callback for watching a given directory
-- process_cb is given a single argument that is a table consisting of:
--   {file: the full file path, parent: the file's parent directory full path,
--   filename: the basename of the file with extension, ext: the extension}
local function watchPath(path, files, process_cb)
  -- m.log.d('watchPath', path, hs.inspect(files))

  -- wait a little while before doing anything, to give files a chance to
  -- settle down.
  hs.timer.doAfter(m.cfg.waitTime, function()
    -- loop through the files and call the process_cb function on any that are
    -- not ignored, still exist, and are found in the given path.
    for _,file in ipairs(files) do
      if not ignored(file) and ufile.exists(file) then
        local parent, filename, ext = ufile.splitPath(file)
        local data = {file=file, parent=parent, filename=filename, ext=ext}
        if parent == path then process_cb(data) end
      end
    end
  end):start()
end

-- callback for watching the downloads directory
local function watchDownloads(files)
  -- m.log.d('watchDownloads ----')
  watchPath(m.cfg.path.downloads, files, function(data)
    -- m.log.d('watchDownloads processing', hs.inspect(data))

    -- unhide extensions for files written here
    ufile.unhideExtension(data.file, data.ext, m.cfg.hiddenExtensions)

    -- send nzb and torrent files to the transfer directory
    if data.ext == 'nzb' or data.ext == 'torrent' then
      moveFileToPath(data.file, m.cfg.path.transfer)
    else
      -- ignore files with color tags
      if not ufile.isColorTagged(data.file) then
        -- move files older than a week into the dump directory
        if ufile.isOlderThan(data.file, TIME.WEEK) then
          moveFileToPath(data.file, m.cfg.path.dump)
        end
      end
    end
  end)
end

-- callback for watching the dump directory
local function watchDump(files)
  -- m.log.d('watchDump ----')
  watchPath(m.cfg.path.dump, files, function(data)
    -- m.log.d('watchDump processing', hs.inspect(data))

    -- for files older than six weeks
    if ufile.isOlderThan(data.file, TIME.WEEK * 6) then
      -- tag the file
      ufile.setTag(data.file, 'Needs Attention')
      -- move it to the desktop
      moveFileToPath(data.file, m.cfg.path.desktop)
      -- send a notification
      uapp.notify(m.name, data.filename..' has been ignored for 6 weeks!')
    end
  end)
end

-- callback for watching the desktop
local function watchDesktop(files)
  -- m.log.d('watchDesktop ----')
  watchPath(m.cfg.path.desktop, files, function(data)
    -- m.log.d('watchDesktop processing', hs.inspect(data))

    -- unhide extensions for files written here (notably, screenshots)
    ufile.unhideExtension(data.file, data.ext, m.cfg.hiddenExtensions)
  end)
end

-- callback for watching the documents directory
local function watchDocuments(files)
  -- m.log.d('watchDocuments ----')
  watchPath(m.cfg.path.documents, files, function(data)
    -- m.log.d('watchDocuments processing', hs.inspect(data))

    -- unhide extensions for files written here
    ufile.unhideExtension(data.file, data.ext, m.cfg.hiddenExtensions)
  end)
end

local function checkPaths()
  -- m.log.d('checkPaths (on the hour)')
  ufile.runOnFiles(m.cfg.path.downloads, watchDownloads)
  ufile.runOnFiles(m.cfg.path.dump, watchDump)
  ufile.runOnFiles(m.cfg.path.desktop, watchDesktop)
  ufile.runOnFiles(m.cfg.path.documents, watchDocuments)
end

function m.start()
  timer = hs.timer.new(TIME.HOUR, checkPaths)
  timer:start()

  watch.downloads = hs.pathwatcher.new(m.cfg.path.downloads, watchDownloads)
  watch.dump = hs.pathwatcher.new(m.cfg.path.dump, watchDump)
  watch.desktop = hs.pathwatcher.new(m.cfg.path.desktop, watchDesktop)
  watch.documents = hs.pathwatcher.new(m.cfg.path.documents, watchDocuments)
  for k,_ in pairs(watch) do watch[k]:start() end

  checkPaths()
end

function m.stop()
  if timer then timer:stop() end
  timer = nil

  for k,_ in pairs(watch) do
    watch[k]:stop()
    watch[k] = nil
  end
end

return m
