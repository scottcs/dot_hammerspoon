-- Application-related utilities
local lib = {}

local ustr = require('utils.string')

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
  local url = nil
  local browsers = {
    ['Google Chrome'] = 'URL of active tab of front window',
    Safari = 'URL of front document',
    Firefox = function()
      local ff_dir = os.getenv('HOME')..'/Library/Application Support/Firefox'
      local prof_dir = ff_dir..'/Profiles'
      -- TODO:
      -- get most recent Profiles/*/sessionstore-backups/recovery.js
      -- load and parse as json
      -- find selectedWindow
      -- get window data from data['windows'][selectedWindow]
      -- get selected tab (windowdata['selected'])
      -- get tab data (windowdata['tabs'][selectedTab])
      -- get last entry of tab (tabdata['entries'][numEntries])
      -- return the url (entry['url'])
      return nil
    end,
  }

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
