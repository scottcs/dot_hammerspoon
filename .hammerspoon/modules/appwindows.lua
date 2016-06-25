-- module: Application window actions
local m = {}

-- App/window actions are defined in appactions.lua
local A = require('appactions')

-- table for converting events to strings when debugging
local DEBUG = {
  [0] = 'launching',
  [1] = 'launched',
  [2] = 'terminated',
  [3] = 'hidden',
  [4] = 'unhidden',
  [5] = 'activated',
  [6] = 'deactivated',
}

local watcher = nil

-- appwatcher callback
local function watch(appName, eventType, appObject)
  -- see config.appwindows for rule configuration
  if m.cfg.rules[appName] then

    local function hasNoMainWindow() return appObject:mainWindow() == nil end

    for _,rule in ipairs(m.cfg.rules[appName]) do
      -- if the current event matches one of our rules for this app,
      -- take the action defined by the rule.
      if rule.evt == eventType then
        if rule.act == A.fullscreen then
          -- set the main window to fullscreen
          hs.timer.waitWhile(hasNoMainWindow, function()
            appObject:mainWindow():setFullScreen(true)
          end)
        elseif rule.act == A.maximize then
          -- maximize the main window
          hs.timer.waitWhile(hasNoMainWindow, function()
            appObject:mainWindow():maximize()
          end)
        elseif rule.act == A.toFront then
          -- bring the application windows to the front
          appObject:selectMenuItem({'Window', 'Bring All to Front'})
        elseif rule.act == A.activate then
          -- activate (focus) the app
          appObject:activate()
        elseif rule.act == A.debug then
          -- print some debugging information about the app and events
          m.log.d(
            'appName:', appName,
            ', bundleID:', appObject:bundleID(),
            ', eventType:', DEBUG[eventType]
          )
        end
      end
    end
  end
end


function m.start()
  watcher = hs.application.watcher.new(watch)
  watcher:start()
end

function m.stop()
  watcher:stop()
  watcher = nil
end

return m
