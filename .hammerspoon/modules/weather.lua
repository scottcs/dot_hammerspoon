-- module: weather
-- Use the darksky.net API to grab local weather info and display it in a
-- menubar item.
--
local m = {}

local ufile = require('utils.file')
local utime = require('utils.time')

local next = next

-- constants
local OPENURLBASE = 'http://darksky.net/#/f/'
local APIURL = 'https://api.darksky.net/forecast'
local APICALLSHEADER = 'X-Forecast-API-Calls'
local GEOAPIURL = 'https://maps.googleapis.com/maps/api/geocode/json?'
local GEOAPICALLSHEADER = 'X-API-Calls'
local DUMMYITEM = {title='...', disabled=true}

local menu = nil
local loc = nil
local fetchTimer = nil
local locTimer = nil
local pathWatcher = nil

-- get a styledtext style based on the given temperature
local function getStyle(temp)
  local style = m.cfg.styles.tooDamnCold
  -- round our temp
  temp = math.floor(temp + 0.5)
  if temp >= m.cfg.tempThresholds.alert then
    style = m.cfg.styles.alert
  elseif temp >= m.cfg.tempThresholds.tooDamnHot then
    style = m.cfg.styles.tooDamnHot
  elseif temp >= m.cfg.tempThresholds.tooHot then
    style = m.cfg.styles.tooHot
  elseif temp >= m.cfg.tempThresholds.hot then
    style = m.cfg.styles.hot
  elseif temp >= m.cfg.tempThresholds.warm then
    style = m.cfg.styles.warm
  elseif temp >= m.cfg.tempThresholds.default then
    style = m.cfg.styles.default
  elseif temp >= m.cfg.tempThresholds.cool then
    style = m.cfg.styles.cool
  elseif temp >= m.cfg.tempThresholds.cold then
    style = m.cfg.styles.cold
  elseif temp >= m.cfg.tempThresholds.tooCold then
    style = m.cfg.styles.tooCold
  end
  return style
end

-- return a string representing a float 'deg' in degrees
local function totemp(deg) return string.format('%.0f°', deg) end

-- return a string representing the chance of precipitation
local function toprecip(dataPoint)
  -- assumes precipProbability is > 0 and precipType exists
  local prob = dataPoint.precipProbability * 100
  return string.format('%.0f%% chance of %s',
    prob,
    dataPoint.precipType)
end

-- open the darksky.net web page with the current location
local function openForecast()
  if loc == nil then return end

  local url = OPENURLBASE..loc.latitude..','..loc.longitude
  local task = hs.task.new('/usr/bin/open', nil, {url})
  task:start()
end

-- return a labeled hs.styledtext line for the given weather dataPoint, colored
-- by the temperature thresholds defined in the config.
local function makeWeatherLine(label, dataPoint, summary)
  local line = string.format('% 4s:', label)
  local style = m.cfg.styles.default
  -- use the dataPoint's summary if one was not provided
  summary = summary or dataPoint.summary

  -- prefer apparentTemperature over actual temperatures
  if dataPoint.apparentTemperature ~= nil then
    local prefix = ''
    -- if apparentTemperature is not the actual temperature, prepend with ~
    if totemp(dataPoint.apparentTemperature) ~= totemp(dataPoint.temperature) then prefix = '~' end
    line = string.format('%s % 1s% 5s', line, prefix,
      totemp(dataPoint.apparentTemperature))
    style = getStyle(dataPoint.apparentTemperature)

  elseif dataPoint.temperature ~= nil then
    line = string.format('%s % 6s', line,
      totemp(dataPoint.temperature))
    style = getStyle(dataPoint.temperature)

  elseif dataPoint.temperatureMin ~= nil then
    -- if temperatureMin is defined, assume temperatureMax is also
    line = string.format('%s % 5s/% 5s', line,
      totemp(dataPoint.temperatureMax),
      totemp(dataPoint.temperatureMin))
    style = getStyle(dataPoint.temperatureMax)
  end

  line = string.format('%s ∶ %s', line, summary)

  -- add precipitation probability if above configured threshold
  if dataPoint.precipProbability > m.cfg.minPrecipProbability then
    line = string.format('%s ∶ %s', line,
    toprecip(dataPoint))
  end

  return hs.styledtext.new(line, style)
end

-- return a table of weather alert menu items if any exist in the data.
-- clicking on an alert item will open the alert page in a browser.
-- alert text is also added as a tooltip.
local function getAlerts(data)
  local alerts = {}
  if data.alerts ~= nil then
    for _,alert in ipairs(data.alerts) do
      local function openURI()
        hs.task.new('/usr/bin/open', nil, {alert.uri}):start()
      end
      table.insert(alerts, {
        title=hs.styledtext.new('«‼»  '..alert.title, m.cfg.styles.alert),
        tooltip=alert.description,
        fn=openURI,
      })
    end
    table.insert(alerts, {title='-'})
  end
  return alerts
end

-- return a menu item representing the current temperature
local function currently(data)
  if not data.currently then return DUMMYITEM end

  local dataPoint = data.currently
  local title

  if data.minutely then
    title = makeWeatherLine('    Now', dataPoint, data.minutely.summary)
  else
    title = makeWeatherLine('    Now', dataPoint)
  end

  return {
    title=title,
    fn=openForecast,
  }
end

-- return a menu item representing the sun rise and set times for today
local function sunTimes(data)
  if not (data.daily and #data.daily.data > 0) then return DUMMYITEM end

  local today = data.daily.data[1]
  local title = string.format('Suntime: %s —— %s',
    utime.tohourmin(today.sunriseTime),
    utime.tohourmin(today.sunsetTime))

  return {
    title=hs.styledtext.new(title, m.cfg.styles.default),
    fn=openForecast,
  }
end

-- return a menu item with current hour weather, and a submenu of the next 24
-- individual hours.
local function hourly(data)
  if not data.hourly then return DUMMYITEM end

  local dataBlock = data.hourly
  local hourlyMenu = {}

  for i,dataPoint in ipairs(dataBlock.data) do
    if i > 24 then break end
    local time = utime.tohour(dataPoint.time)
    if time == '12am' then hourlyMenu[#hourlyMenu+1] = {title='-'} end
    hourlyMenu[#hourlyMenu+1] = {
      title=makeWeatherLine(time, dataPoint),
      fn=openForecast,
    }
  end

  return {
    title=hs.styledtext.new(dataBlock.summary, m.cfg.styles.default),
    menu=hourlyMenu,
    fn=openForecast,
  }
end

-- return a menu item of daily weather information
local function daily(data)
  if not data.daily then return DUMMYITEM end

  local dataBlock = data.daily
  return {
    title=hs.styledtext.new(dataBlock.summary, m.cfg.styles.default),
    fn=openForecast,
  }
end

-- return a menu item of the next few days of weather information
local function nextDays(data)
  if not data.daily then return {DUMMYITEM} end

  local dataBlock = data.daily
  local days = {}

  for _,dataPoint in ipairs(dataBlock.data) do
    days[#days+1] = {
      title=makeWeatherLine(utime.todayname(dataPoint.time), dataPoint),
      fn=openForecast,
    }
  end

  return days
end

-- build the entire menu table for the weather module
local function buildMenuTable(data)
  local menuTable = {
    currently(data),
    sunTimes(data),
    {title='-'},
    hourly(data),
    {title='-'},
    daily(data),
  }

  for _,line in ipairs(nextDays(data)) do
    menuTable[#menuTable+1] = line
  end

  -- put all weather alerts at the top
  for i,alert in ipairs(getAlerts(data)) do
    table.insert(menuTable, i, alert)
  end

  return menuTable
end

-- get the icon path for the given icon
local function getIconPath(icon)
  local iconPath = ufile.toPath(m.cfg.iconPath, icon..'.pdf')
  if ufile.exists(iconPath) then return iconPath end
  return nil
end

-- update the menu item tooltip
local function updateMenuTooltip()
  if menu == nil then return end

  local tip = 'Location Unknown'

  if loc ~= nil then
    if loc.name ~= nil then
      tip = string.format('%s', loc.name)
    else
      tip = string.format('%s,%s', loc.latitude, loc.longitude)
    end
  end

  menu:setTooltip(tip)
end

-- update the menu item
local function updateMenu(data)
  if menu == nil then return end
  local iconPath = ufile.toPath(m.cfg.iconPath, 'default.pdf')
  local nowtemp = nil
  local nowsumm = ''
  local prefix = ''

  if data ~= nil and next(data) ~= nil then
    local menuTable = buildMenuTable(data)
    if menuTable ~= nil and next(menuTable) ~= nil then
      menu:setMenu(menuTable)
      iconPath = getIconPath(data.currently.icon) or iconPath
    end
    if data.currently ~= nil then
      if data.currently.apparentTemperature ~= nil then
        nowtemp = data.currently.apparentTemperature
        if totemp(nowtemp) ~= totemp(data.currently.temperature) then prefix = '~' end
      elseif data.currently.temperature ~= nil then
        nowtemp = data.currently.temperature
      end
      nowsumm = data.currently.summary or ''
    end
  end

  menu:setIcon(iconPath)

  if nowtemp ~= nil then
    local style = getStyle(nowtemp)
    menu:setTitle(hs.styledtext.new(string.format('%s%-7s', prefix, totemp(nowtemp)), style))
  end

  updateMenuTooltip()
end

-- asynchronously contact the darksky.net api to get new weather data via http
local function onAsyncGet(status, body, headers)
  if headers[APICALLSHEADER] then
    local calls = tonumber(headers[APICALLSHEADER])
    -- make sure we don't go over our maximum allowed api calls per day
    if calls > m.cfg.api.maxCalls then
      m.log.w('DarkSky API calls today: '..tostring(calls))
      m.log.w('Above maximum ('..tostring(m.cfg.api.maxCalls)..'), shutting down weather module.')
      m.stop()
    end
  end

  if status < 0 then
    m.log.e(body)
    return
  end

  -- write out the weather.json
  if ufile.makeParentDir(m.cfg.file) then
    local f = io.open(m.cfg.file, 'w')
    if f then
      f:write(body..'\n')
      f:close()
    end
  end
end

local function onAsyncReverseGeo(status, body, headers)
  -- Unfortunately, no way to currently get number of queries from headers,
  -- but since we only call after calling darksky.net, and google's api is much
  -- more generous, we shouldn't run into trouble. Right??
  -- m.log.d('hs.inspect(headers)', hs.inspect(headers))

  if status < 0 then
    m.log.e(body)
    return
  end

  -- save location (find longest formatted address)
  local data = hs.json.decode(body)
  local longest = ''
  for i,result in ipairs(data.results) do
    if result.formatted_address ~= nil then
      if string.len(result.formatted_address) > string.len(longest) then
        longest = result.formatted_address
      end
    end
  end
  if longest ~= '' then loc.name = longest end
end

-- callback called when we want to download new weather data
local function onFetchTick()
  if loc == nil then return end

  local url = APIURL..'/'..m.cfg.api.key
  url = url..'/'..loc.latitude..','..loc.longitude
  url = url..'?exclude=flags'
  hs.http.asyncGet(url, nil, onAsyncGet)

  url = GEOAPIURL..'latlng='
  url = url..loc.latitude..','..loc.longitude
  url = url..'&key='..m.cfg.geoapi.key
  hs.http.asyncGet(url, nil, onAsyncReverseGeo)
end

-- callback called when we want to grab our current latitude/longitude
local function onLocTick()
  hs.location.start()
  -- wait a sec to get location after starting (otherwise we tend to run into
  -- 'location not found' issues).
  hs.timer.doAfter(1, function()
    loc = hs.location.get()
    if loc == nil then m.log.w('Location not found!') end
    hs.location.stop()
    updateMenuTooltip()
  end):start()
end

-- callback called whenever our weather data file is updated. updates the menu
-- item if the data is valid.
local function onDataChanged(files)
  if not files or #files < 1 then
    m.log.e('no files watched')
    return
  end

  if not ufile.exists(files[1]) then
    m.log.e('data file missing: '..files[1])
    return
  end

  local data = ufile.loadJSON(files[1])
  if not data then
    m.log.e('could not decode json, perhaps bad api key?')
    data = {}
  end
  updateMenu(data)
end

function m.start()
  menu = hs.menubar.newWithPriority(m.cfg.menupriority)
  fetchTimer = hs.timer.new(m.cfg.fetchTimeout, onFetchTick)
  locTimer = hs.timer.new(m.cfg.locationTimeout, onLocTick)
  pathWatcher = hs.pathwatcher.new(m.cfg.file, onDataChanged)

  fetchTimer:start()
  locTimer:start()
  pathWatcher:start()

  onLocTick()
  onDataChanged({m.cfg.file})
end

function m.stop()
  if menu then menu:delete() end
  if fetchTimer then fetchTimer:stop() end
  if locTimer then locTimer:stop() end
  if pathWatcher then pathWatcher:stop() end

  menu = nil
  fetchTimer = nil
  locTimer = nil
  pathWatcher = nil
  loc = nil
end

return m
