-- Application-related utilities
local lib = {}

local ustr = require('utils.string')

-- osascript to tell an application to do something
function lib.tell(app, appCmd)
  local cmd = 'tell application "'..app..'" to '..appCmd
  local ok, result = hs.applescript(cmd)
  if ok then return result else return nil end
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

return lib
