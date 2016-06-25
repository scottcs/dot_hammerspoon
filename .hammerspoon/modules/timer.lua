-- module: timer - quickly create timers with reminders
-- (Inspired by Timer.app, by Michael Villar, though not *nearly* as pretty)
--
local m = {}

local ustr = require('utils.string')
local utime = require('utils.time')
local ucounter = require('utils.counter')
local sound = hs.sound

local alertSound = nil
local lastApp = nil
local chooser = nil
local menu = nil
local visible = false
local timers = nil
local tickTimer = nil

-- constants
local TICK = 1

-- COMMANDS
local commands = {
  {
    ['text'] = 'New...',
    ['subText'] = 'Create a Timer',
    ['command'] = 'new',
  },
}
--------------------

-- refocus on the app that was focused before the chooser was invoked
local function refocus()
  if lastApp ~= nil then
    lastApp:activate()
    lastApp = nil
  end
end

-- play the alert sound, if defined
local function playAlertSound()
  if alertSound == nil then return end
  alertSound:stop()
  alertSound:play()
end

-- send a notification to the user, with the message from the expired timer
local function notify(index)
  if timers[index] == nil then return end
  local subTitle = timers[index].message
  local infoText = utime.prettyMinutes(timers[index].seconds) .. ' Elapsed'
  hs.notify.new(m.name, {
    title = 'Timer Expired',
    subTitle = subTitle,
    informativeText = infoText,
    contentImage = m.cfg.icon,
    hasActionButton = false,
    autoWithdraw = true,
  }):send()
end

-- update the menubar icon, removing it from the menubar if no timers are left,
-- or returning it to the menubar if timers are started.
local function update()
  if timers == nil or #timers == 0 then
    if tickTimer then tickTimer:stop() end
    if menu then menu:removeFromMenuBar() end
  else
    if menu then menu:returnToMenuBar():priority(m.cfg.menupriority) end
    if tickTimer and not tickTimer:running() then tickTimer:start() end
  end
end

-- destroy a timer
local function killTimer(index)
  if timers[index] == nil then return end
  timers[index].counter = nil
  table.remove(timers, index)
  update()
end

-- callback called when a timer expires. send a notification, play a sound, and
-- destroy the timer.
local function onTimerExpire(index)
  if timers[index] == nil then return end
  notify(index)
  playAlertSound()
  killTimer(index)
end

-- timer callback, called every TICK. decrements running timers and determines
-- when they ought to expire.
local function onTick()
  for i,timer in ipairs(timers) do
    timer.counter.incr()
    if timer.counter.get() > timer.seconds then
      onTimerExpire(i)
    end
  end
end

-- create a new timer that will expire in 'seconds' seconds and will notify
-- with 'message' on expiration.
local function createNewTimer(seconds, message)
  table.insert(timers, {
    seconds = seconds,
    message = message,
    counter = ucounter.new(message),
  })
  update()
end

-- parse the query string from the chooser, to determine the length of the
-- timer and the message. if the string starts with a number, minutes are
-- assumed. if the string doesn't start with a number, the default time is
-- used.
local function parseLine(line)
  local message
  local seconds = m.cfg.defaultTime
  local parts = ustr.split(line, ' ')
  local first = table.remove(parts, 1)
  local rest = table.concat(parts, ' ')

  -- TODO: allow 10s, 10m, 1h, etc???
  if tonumber(first) ~= nil then
    local minutes = tonumber(first)
    seconds = math.max(1, math.floor(minutes * 60))
    message = rest
  else
    message = first .. ' ' .. rest
  end

  createNewTimer(seconds, message)
end

-- callback when a chooser choice is selected (in this case, only commands)
local function choiceCallback(choice)
  refocus()
  visible = false

  if choice.command == 'new' then
    parseLine(tostring(chooser:query()))
  end

  chooser:query('')
end

-- callback when the menu icon is clicked. show timers in a menu. clicking a
-- timer resets it to its original time. ctrl-clicking a timer deletes it.
local function menuClickCallback(--[[mods]])
  local options = {}
  for k,timer in ipairs(timers) do
    local timeLeft = utime.prettyMinutes(timer.seconds - timer.counter.get())
    local timeReset = utime.prettyMinutes(timer.seconds)
    local title = '[' .. timeReset .. '/-' .. timeLeft .. '] ' .. timer.message

    local function timerClickCallback(mods)
      if mods.ctrl then
        killTimer(k)
      else
        timer.counter.reset()
      end
    end

    options[#options+1] = {title=title, fn=timerClickCallback}
  end
  return options
end

-- toggle the chooser
function m.toggle()
  if chooser ~= nil then
    if visible then
      m.hide()
    else
      m.show()
    end
  end
end

-- show the chooser
function m.show()
  if chooser ~= nil then
    lastApp = hs.application.frontmostApplication()
    chooser:show()
    visible = true
  end
end

-- hide the chooser
function m.hide()
  if chooser ~= nil then
    -- hide calls choiceCallback
    chooser:hide()
  end
end

function m.start()
  timers = {}

  alertSound = sound.getByFile(m.cfg.sound)
  alertSound:volume(m.cfg.volume)

  menu = hs.menubar.new(false)
  menu:setTitle('(<)')
  menu:setMenu(menuClickCallback)

  tickTimer = hs.timer.new(TICK, onTick)

  chooser = hs.chooser.new(choiceCallback)
  chooser:width(m.cfg.width)
  chooser:rows(#commands)
  -- disable built-in search
  chooser:queryChangedCallback(function() end)

  -- add commands
  local choices = {}
  for _, command in ipairs(commands) do
    choices[#choices+1] = command
  end
  chooser:choices(choices)
end

function m.stop()
  if chooser then chooser:delete() end
  if menu then menu:delete() end
  if tickTimer then tickTimer:stop() end

  alertSound:stop()

  for k,_ in ipairs(timers) do killTimer(k) end

  tickTimer = nil
  chooser = nil
  menu = nil
  lastApp = nil
  alertSound = nil
  timers = nil
end

return m
