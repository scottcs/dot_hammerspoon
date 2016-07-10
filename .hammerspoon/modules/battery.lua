-- module: Battery notifications
local m = {}

local utime = require('utils.time')

local isCharged   = hs.battery.isCharged()
local percentage  = hs.battery.percentage()
local powerSource = hs.battery.powerSource()

local notifiedAt = {
  [20] = false,
  [15] = false,
  [10] = false,
  [5]  = false,
}

-- send a notification about the battery status
local function batteryNotify(statusType, subTitle, message)
  hs.notify.new({
    title = statusType .. ' Status',
    subTitle = subTitle,
    informativeText = message,
    contentImage = m.cfg.icon,
    hasActionButton = false,
    autoWithdraw = true,
  }):send()
end

-- battery watching callback, which sends a notification if charging status
-- has changed, or power thresholds have been reached.
local function watchFunc()
  local newPercentage  = hs.battery.percentage()
  local newIsCharged   = hs.battery.isCharged()
  local newPowerSource = hs.battery.powerSource()

  if newPercentage < 100 then
    isCharged = false
  end

  if newIsCharged ~= isCharged
    and newPercentage == 100
    and newPowerSource == 'AC Power'
  then
    batteryNotify('Battery', 'Charged Completely!')
    isCharged = true
  end

  local shouldNotifyTime = false
  for threshold, notified in pairs(notifiedAt) do
    if newPercentage > threshold then
      -- reset because we've gone above this threshold
      notifiedAt[threshold] = false
    elseif not notified then
      -- newPercentage <= threshold so we should notify
      notifiedAt[threshold] = true
      shouldNotifyTime = true
    end
  end
  if shouldNotifyTime then
    local timeRemaining = utime.prettyMinutes(hs.battery.timeRemaining())
    batteryNotify('Battery', 'Time Remaining:', timeRemaining)
  end

  if newPowerSource ~= powerSource then
    batteryNotify('Power Source', 'Current Source:', newPowerSource)
    powerSource = newPowerSource
  end
end

function m.start()
  m.watcher = hs.battery.watcher.new(watchFunc)
  m.watcher:start()
end

function m.stop()
  m.watcher:stop()
  m.watcher = nil
end

return m
