-- module: send clicked links to the most recently used browser
-- Note: this requires setting the default web browser to Hammerspoon
-- in OS X System Preferences -> General.
local m = {}

-- keeps track of the most recently used browser
local currentHandler = nil

-- callback, called when a url is clicked. Sends the url to the currentHandler.
local function httpCallback(scheme, _, _, fullURL)
  local allHandlers = hs.urlevent.getAllHandlersForScheme(scheme)
  local handler = hs.fnutils.find(allHandlers, function(v)
    return v == currentHandler
  end)

  if not handler then
    m.log.e('Invalid browser handler: ' .. (currentHandler or 'nil'))
    return
  end

  if not fullURL then
    m.log.e('Attempt to open browser without url')
    return
  end

  hs.urlevent.openURLWithBundle(fullURL, handler)
end

-- application watcher callback. This looks for the configured browsers being
-- activated, and switches the currentHandler accordingly.
local function watch(_, eventType, appObject)
  if eventType == hs.application.watcher.activated then
    local bundleID = appObject:bundleID()
    if m.cfg.apps[bundleID] ~= nil then currentHandler = bundleID end
  end
end

function m.start()
  -- set Hammerspoon as the default system URL handler for http and https (both
  -- are set even if only one is specified)
  hs.urlevent.setDefaultHandler('http')
  m.watcher = hs.application.watcher.new(watch)
  m.watcher:start()
  hs.urlevent.httpCallback = httpCallback
  currentHandler = m.cfg.defaultApp
end

function m.stop()
  hs.urlevent.httpCallback = nil
  if m.watcher then m.watcher:stop() end
  m.watcher = nil
  currentHandler = nil
end

return m
