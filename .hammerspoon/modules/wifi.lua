-- module: wifi - notify on wifi changes
local m = {}

-- keep track of the previously connected network
local lastNetwork = hs.wifi.currentNetwork()

-- callback called when wifi network changes
local function ssidChangedCallback()
    local newNetwork = hs.wifi.currentNetwork()

    -- send notification if we're on a different network than we were before
    if lastNetwork ~= newNetwork then
      hs.notify.new({
        title = 'Wi-Fi Status',
        subTitle = newNetwork and 'Network:' or 'Disconnected',
        informativeText = newNetwork,
        contentImage = m.cfg.icon,
        autoWithdraw = true,
        hasActionButton = false,
      }):send()

      lastNetwork = newNetwork
    end
end

function m.start()
  m.watcher = hs.wifi.watcher.new(ssidChangedCallback)
  m.watcher:start()
end

function m.stop()
  m.watcher:stop()
  m.watcher = nil
end

return m
