-- module: WorkTime - combination Awareness and Pomodoro
-- (Inspired by many Pomodoro modules and apps out there, as well as the
-- Awareness app by Futureproof (which seems to no longer exist).)
local m = {}

local ucounter = require('utils.counter')
local utime = require('utils.time')
local ustr = require('utils.string')
local uapp = require('utils.app')
local sound = hs.sound

-- constants
local ID = 'worktime'
local K = {
  MODE = {
    AWARENESS = 'awareness',
    POMODORO = {
      WORK = 'Work',
      REST = 'Rest',
    },
  },
  STATE = {
    RUNNING = 'running',
    PAUSED = 'paused',
  },
  ANTI_IDLE = {
    EVENTS = {
      hs.eventtap.event.types.leftMouseDown,
      hs.eventtap.event.types.rightMouseDown,
      hs.eventtap.event.types.mouseMoved,
      hs.eventtap.event.types.keyDown,
      hs.eventtap.event.types.flagsChanged,
      hs.eventtap.event.types.scrollWheel,
    },
    RETRIES = 2,
  },
  TIMING = {
    IDLE = 1,
    TICK = hs.timer.minutes(1),
    EVENT_THROTTLE = 15,
    ACTIVITY_TIMEOUT = hs.timer.minutes(2),
  },
}

-- menubar/alert glyphs
local GLYPH = {
  [K.MODE.AWARENESS] = '/,\\',
  [K.MODE.POMODORO.WORK] = '(*)',
  [K.MODE.POMODORO.REST] = '( )',
  [K.STATE.PAUSED] = '==',
  CHIME = '( ( (  /,\\  ) ) )',
}

local mode = nil
local state = nil
local menu = nil
local timer = nil
local counter = nil
local chime = nil
local idleTime = nil

-----------------------------------------
-- helpers
-----------------------------------------
-- play a chime, stop other playing chimes.
local function ringChime(worktimeChime, num)
  -- m.log.d('CHIME')
  num = num or 1
  audio = hs.audiodevice.current()

  for i=1,num,1 do
    chime.timer[#chime.timer+1] = hs.timer.doAfter((i-1)*m.cfg.awareness.time.chimeRepeat, function()
      if uapp.getiTunesPlayerState() == ustr.unquote(hs.itunes.state_playing)
        or uapp.getSpotifyPlayerState() == ustr.unquote(hs.spotify.state_playing)
        or audio.volume == 0
        or audio.muted == true then
        hs.alert.show(GLYPH.CHIME, m.cfg.awareness.time.chimeRepeat)
      else
        local snd = sound.getByFile(worktimeChime.file)
        snd:volume(worktimeChime.volume)
        chime.sound[#chime.sound+1] = snd
        snd:play()
      end
    end)
  end
end

-- stop and remove all chime sounds
local function chimeCleanup()
  for i=#chime.timer,1,-1 do
    chime.timer[i]:stop()
    table.remove(chime.timer, i)
  end
  for i=#chime.sound,1,-1 do
    chime.sound[i]:stop()
    table.remove(chime.sound, i)
  end
end

-- send a notification
local function notify(title, message, buttonTitle)
  hs.notify.new(ID, {
    title = title,
    informativeText = message,
    actionButtonTitle = buttonTitle,
    hasActionButton = true,
  }):send()
end

-----------------------------------------
-- menu functions
-----------------------------------------
-- callback when updating the menu
local function menuUpdate()
  -- m.log.d('menu update')
  if menu ~= nil then
    local time = GLYPH[K.STATE.PAUSED]
    if state == K.STATE.RUNNING then
      time = string.format('%dm', counter.tick.get())
    end
    menu:setTitle(GLYPH[mode] .. ' ' .. time)
  end
end

-- callback when the menu is clicked. ctrl switches to the next mode, shift
-- resets the current mode, otherwise, pause/unpause the current mode.
local function menuClickCallback(mods)
  -- m.log.d('menu click callback')
  if mods.ctrl then
    m.nextMode()
  elseif mods.shift then
    chimeCleanup()
    m.reset()
  else
    m.pauseUnpause()
  end
end

-- callback called when a notification button is pressed, used to run the next
-- stage of pomodoro, for instance.
local function onNotificationClick(notification)
  local act = hs.notify.activationTypes[notification:activationType()]
  -- contentsClicked or actionButtonClicked
  if string.lower(act) == 'actionbuttonclicked' then
    m.run()
  end
end

-----------------------------------------
-- timer callbacks
-----------------------------------------
-- called every K.TIMING.TICK seconds
local function onTick()
  -- m.log.d('on tick', counter.tick.asString())
  counter.tick.incr()
  menuUpdate()

  if mode == K.MODE.AWARENESS then
    -- ring the chime if we've reached the end of the current time chunk
    if utime.timesUp(counter.tick.get(), m.cfg.awareness.time.chimeAfter) then
      local num = math.floor(counter.tick.get() / m.cfg.awareness.time.chimeAfter)
      ringChime(m.cfg.awareness.chime, num)
    end

  elseif mode == K.MODE.POMODORO.WORK then
    -- if time's up and we're in work mode, alert and prepare for rest mode
    if counter.tick.get() <= 0 then
      notify('Pomodoro', 'Work Complete!', K.MODE.POMODORO.REST)
      ringChime(m.cfg.pomodoro.chime)
      mode = K.MODE.POMODORO.REST
      m.reset()
    end

  elseif mode == K.MODE.POMODORO.REST then
    -- if time's up and we're in rest mode, alert and prepare for work mode
    if counter.tick.get() <= 0 then
      notify('Pomodoro', 'Done Resting!', K.MODE.POMODORO.WORK)
      ringChime(m.cfg.pomodoro.chime)
      mode = K.MODE.POMODORO.WORK
      m.reset()
    end
  end
end

-- callback called every K.TIMING.IDLE seconds to check for inactivity
local function onIdle()
  if mode == K.MODE.AWARENESS then
    local idleSeconds = os.time() - idleTime
    -- m.log.d('idleSeconds', idleSeconds)
    -- if we've reached the inactivity threshold, reset to 0
    if idleSeconds > K.TIMING.ACTIVITY_TIMEOUT then
      chimeCleanup()
      m.reset()
    end
  end
end

-- callback called by throttle timer to slow down anti-idle event listening
local function onThrottle()
  -- m.log.d('on throttle', counter.retries.asString())
  if timer.eventtap then timer.eventtap:start()
  else
    -- Avoid recursing infinitely
    if counter.retries.get() > K.ANTI_IDLE.RETRIES then
      m.log.e(ID..': Exceeded max throttle retries')
    else
      counter.retries.incr()
      hs.timer.doAfter(K.TIMING.EVENT_THROTTLE, onThrottle)
    end
  end
end

-- callback called from all anti-idle events
local function keepAlive()
  -- m.log.d('keep alive')
  idleTime = os.time()
  timer.eventtap:stop()
  timer.throttle = hs.timer.doAfter(K.TIMING.EVENT_THROTTLE, onThrottle)
end

-----------------------------------------
-- init/cleanup
-----------------------------------------
local function init()
  -- m.log.d('init')
  timer = {}
  counter = {}
  chime = {
    timer = {},
    sound = {},
  }

  timer.tick = hs.timer.new(K.TIMING.TICK, onTick)

  if mode == K.MODE.AWARENESS then
    idleTime = os.time()
    state = K.STATE.RUNNING
    timer.idle = hs.timer.new(K.TIMING.IDLE, onIdle)
    timer.eventtap = hs.eventtap.new(K.ANTI_IDLE.EVENTS, keepAlive)
    counter.retries = ucounter.new('retries')
    counter.tick = ucounter.new('tick')
    m.run()
  elseif mode == K.MODE.POMODORO.WORK then
    state = K.STATE.PAUSED
    counter.tick = ucounter.new('tick', m.cfg.pomodoro.time.work)
  elseif mode == K.MODE.POMODORO.REST then
    state = K.STATE.PAUSED
    counter.tick = ucounter.new('tick', m.cfg.pomodoro.time.rest)
  end

  menuUpdate()
end

local function deInit()
  -- m.log.d('deInit')
  for k,_ in pairs(timer) do
    timer[k]:stop()
    timer[k] = nil
  end
  for k,_ in pairs(counter) do counter[k] = nil end
end

-----------------------------------------
-- module functions
-----------------------------------------
function m.pause()
  -- m.log.d('worktime pause')
  --
  -- Reset timer to 0 on Awareness pause, because it doesn't make sense
  -- to resume with a time on the clock.
  if mode == K.MODE.AWARENESS then
    chimeCleanup()
    m.reset()
  end

  for _,t in pairs(timer) do t:stop() end
  state = K.STATE.PAUSED
end

function m.run()
  -- m.log.d('worktime run')
  for _,t in pairs(timer) do t:start() end
  state = K.STATE.RUNNING
end

function m.pauseUnpause()
  -- m.log.d('worktime pausunpause')
  if state == K.STATE.RUNNING then
    m.pause()
  else
    m.run()
  end
  menuUpdate()
end

function m.reset()
  -- m.log.d('worktime reset')
  deInit()
  init()
end

function m.nextMode()
  -- m.log.d('worktime nextmode')
  chimeCleanup()
  deInit()
  mode = mode == K.MODE.AWARENESS and K.MODE.POMODORO.WORK or K.MODE.AWARENESS
  init()
end

function m.start()
  mode = K.MODE.AWARENESS
  menu = hs.menubar.newWithPriority(m.cfg.menupriority)
  menu:setClickCallback(menuClickCallback)
  hs.notify.register(ID, onNotificationClick)
  init()
end

function m.stop()
  hs.notify.unregister(ID)

  if menu then menu:delete() end
  menu = nil

  chimeCleanup()
  deInit()

  timer = nil
  counter = nil
  chime = nil
  idleTime = nil
end

return m
