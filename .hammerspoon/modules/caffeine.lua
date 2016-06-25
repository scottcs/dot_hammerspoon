-- module: Caffeine - menubar icon to keep Mac from sleeping
local m = {}

local utime = require('utils.time')

-- constants
local ID = 'caffeine'
local K = {
  ENABLED = 'enabled',
  MINSACTIVE = 'minsActive',
  IDLE = 'displayIdle',
}

local menu = nil
local timer = nil
local enabled = nil
local minsActive = nil

-- enable caffeine mode / disallow sleeping
function m.enable()
  hs.caffeinate.set(K.IDLE, true)
  menu:setIcon(m.cfg.icons.on)
  timer:start()
  if minsActive == nil then minsActive = 0 end
  enabled = true
end

-- disable caffeine mode / allow sleeping
function m.disable()
  hs.caffeinate.set(K.IDLE, false)
  enabled = false
  minsActive = nil
  menu:setIcon(m.cfg.icons.off)
  if timer then timer:stop() end
end

-- explicitly set whether enabled or disabled
function m.setState(state)
  if state then
    m.enable()
  else
    m.disable()
  end
  return hs.caffeinate.get(K.IDLE)
end

-- toggle enabled/disabled
function m.toggle()
  local state = m.setState(not hs.caffeinate.get(K.IDLE))
  hs.alert.show(state and 'Caffeine ON' or 'Caffeine off', 1)
end

-- called every tick of the timer
-- notifies the user every notifyMinsActive minutes when caffeine is still
-- enabled (to help the user remember to disable it).
local function onTick()
  local minsActive = minsActive + 1

  if utime.timesUp(minsActive, m.cfg.notifyMinsActive) then
    hs.notify.new(ID, {
      title = 'Caffeine is Still Active',
      informativeText = 'Caffeine has been active for '..minsActive..' minutes',
      actionButtonTitle = 'Deactivate',
    }):send()
  end
end

-- called when the user clicks on the notification, potentially disabling
-- caffeine.
local function onNotificationClick(notification)
  local act = hs.notify.activationTypes[notification:activationType()]
  -- contentsClicked or actionButtonClicked
  if string.lower(act) == 'actionbuttonclicked' then
    m.setState(false)
  end
end

function m.start()
  timer = hs.timer.new(hs.timer.minutes(1), onTick)
  menu = hs.menubar.newWithPriority(m.cfg.menupriority)

  if menu then
    menu:setClickCallback(m.toggle)
    m.setState(false)
    minsActive = 0
    hs.notify.register(ID, onNotificationClick)
  end
end

function m.stop()
  if menu then menu:delete() end
  if timer then timer:stop() end
  hs.caffeinate.set(K.IDLE, false)
  menu = nil
  timer = nil
end

return m
