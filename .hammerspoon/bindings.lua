--
-- Key binding setup for all modules and misc functionality
--
local bindings = {}

local uapp = require('utils.app')

-- define some modifier key combinations
local mod = {
  cc     = {'cmd', 'ctrl'},
  ca     = {'cmd', 'alt'},
  as     = {'alt', 'shift'},
  cas    = {'cmd', 'alt', 'shift'},
  hyper  = {'cmd', 'alt', 'ctrl'},  -- mapped to L_CTRL with Karabiner and Seil
  shyper = {'cmd', 'alt', 'ctrl', 'shift'},
}

function bindings.bind()
  -- launch and focus applications
  -- (all use hyper key)
  hs.fnutils.each({
    {key = 'b',  app = 'Google Chrome'},   -- "b"rowser
    {key = 'c',  app = 'Slack'},           -- "c"hat
    {key = 'f',  app = 'Finder'},
    {key = 'i',  app = 'iTunes'},
    {key = 'm',  app = 'Messages'},
    {key = 'q',  app = 'Qbserve'},
    {key = 's',  app = 'Spotify'},
    {key = 't',  app = 'iTerm'},           -- "t"erminal
    {key = 'v',  app = 'nvimOpen'},        -- "v"im
    {key = '\'', app = 'Color Picker'},
  }, function(item)
    local appActivation = function()
      hs.application.launchOrFocus(item.app)

      local app = hs.appfinder.appFromName(item.app)
      if app then
        app:activate()
        app:unhide()
      end
    end

    hs.hotkey.bind(mod.hyper, item.key, appActivation)
  end)

  -- toggle the hammerspoon console, focusing on the previous app when hidden
  local lastApp = nil
  local function toggleConsole()
    local frontmost = hs.application.frontmostApplication()
    hs.toggleConsole()
    if frontmost:bundleID() == 'org.hammerspoon.Hammerspoon' then
      if lastApp ~= nil then
        lastApp:activate()
        lastApp = nil
      end
    else
      lastApp = frontmost
    end
  end

  -- module key bindings
  -- (all using shift-hyper)
  hs.fnutils.each({
    {key = '0',  fn = hsm.worktime.nextMode},
    {key = '1',  fn = hsm.songs.rateSong1},
    {key = '2',  fn = hsm.songs.rateSong2},
    {key = '3',  fn = hsm.songs.rateSong3},
    {key = '4',  fn = hsm.songs.rateSong4},
    {key = '5',  fn = hsm.songs.rateSong5},
    {key = '8',  fn = hsm.worktime.pauseUnpause},
    {key = '9',  fn = hsm.worktime.reset},
    {key = '[',  fn = hsm.songs.prevTrack},
    {key = '\\', fn = hsm.caffeine.toggle},
    {key = ']',  fn = hsm.songs.nextTrack},
    {key = '`',  fn = hsm.songs.rateSong0},
    {key = 'c',  fn = hsm.cheatsheet.toggle},
    {key = 'm',  fn = uapp.toggleSkypeMute},
    {key = 'p',  fn = hsm.songs.playPause},
    {key = 'r',  fn = hs_reload},
    {key = 't',  fn = hsm.songs.getInfo},
    {key = 'v',  fn = uapp.forcePaste},
    {key = 'x',  fn = hsm.cheatsheet.chooserToggle},
    {key = 'y',  fn = toggleConsole},
  }, function(object)
    hs.hotkey.bind(mod.shyper, object.key, object.fn)
  end)

  -- bindings for the spacebar
  hs.hotkey.bind({'alt'},    hs.keycodes.map.space, hsm.scratchpad.toggle)
  hs.hotkey.bind(mod.as,     hs.keycodes.map.space, hsm.timer.toggle)
  hs.hotkey.bind(mod.hyper,  hs.keycodes.map.space, hsm.notational.toggle)
  hs.hotkey.bind(mod.shyper, hs.keycodes.map.space, function()
    hsm.notational.toggle(hsm.notational.cfg.path.til)
  end)
end

return bindings
