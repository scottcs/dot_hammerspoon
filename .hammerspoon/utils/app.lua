-- Application-related utilities
local lib = {}

local ustr = require('utils.string')
local ufile = require('utils.file')

-- osascript to tell an application to do something
function lib.tell(app, appCmd)
  local cmd = 'tell application "'..app..'" to '..appCmd
  local ok, result = hs.applescript(cmd)
  if ok and result == nil then result = true end
  if not ok then result = nil end
  return result
end

-- get iTunes player status
function lib.getiTunesPlayerState()
  local state = nil
  if hs.itunes.isRunning() then
    state = ustr.unquote(hs.itunes.getPlaybackState())
  end
  return state
end

-- get Spotify player status
function lib.getSpotifyPlayerState()
  local state = nil
  if hs.spotify.isRunning() then
    state = ustr.unquote(hs.spotify.getPlaybackState())
  end
  return state
end

-- Toggle Skype between muted/unmuted, whether it is focused or not
function lib.toggleSkypeMute()
  local skype = hs.appfinder.appFromName('Skype')
  if not skype then return end

  local lastapp = nil
  if not skype:isFrontmost() then
    lastapp = hs.application.frontmostApplication()
    skype:activate()
  end

  if not skype:selectMenuItem({'Conversations', 'Mute Microphone'}) then
    skype:selectMenuItem({'Conversations', 'Unmute Microphone'})
  end

  if lastapp then lastapp:activate() end
end

-- Easy notify
function lib.notify(title, message)
  hs.notify.new({title=title, informativeText=message}):send()
end

-- Defeat paste blocking by typing clipboard contents
-- (doesn't always work)
function lib.forcePaste()
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end

-- get the current URL of the focused browser window
function lib.getFocusedBrowserURL()
  -- values for this table are either applescript strings to pass to
  -- lib.tell(), or functions to be called. In either case, the return
  -- value should be the URL of the frontmost window/tab.
  local browsers = {
    ['Google Chrome'] = 'URL of active tab of front window',
    Safari = 'URL of front document',
    Firefox = function()
      -- NOTE: Unfortunately, Firefox isn't scriptable with AppleScript.
      -- Also unfortunately, it seems like the only way to get the current URL
      -- is to either send keystrokes to the app to copy the location bar to
      -- the clipboard (which messes with keybindings as well as overwriting
      -- the clipboard), or to read from a recovery.js file. I'm choosing to go
      -- with the latter, here, but the recovery.js file is only written every
      -- 20 minutes or so, which might mean it's useless.
      local ffDir = ufile.toPath(os.getenv('HOME'), 'Library/Application Support/Firefox/Profiles')
      local recoveryFile = ufile.toPath(
        ufile.mostRecent(ffDir, 'modification'),
        'sessionstore-backups',
        'recovery.js'
      )
      if not ufile.exists(recoveryFile) then return nil end

      local json = ufile.loadJSON(recoveryFile)
      if not json then return nil end

      -- keeping this somewhat brittle for now because if the format of the
      -- file changes, I want to know about it by seeing errors.
      local windowData = json.windows[json.selectedWindow]
      local tabData = windowData.tabs[windowData.selected]
      local lastEntry = tabData.entries[#tabData.entries]
      return lastEntry.url
    end,
  }
  local url = nil

  local app = hs.application.frontmostApplication()
  local title = app:title()
  if browsers[title] ~= nil then
    if type(browsers[title]) == 'string' then
      url = lib.tell(title, browsers[title])
    elseif type(browsers[title] == 'function') then
      url = browsers[title]()
    end
  end

  return url
end

return lib
