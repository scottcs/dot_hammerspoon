-- module: Cheatsheet - show markdown file popup overlays on-demand
-- (Inspired by the CheatSheet app by Stefan Fürst, but rather than
-- automatically showing an app's hotkeys, this renders custom markdown files
-- based on the current app.)
--
-- Cheatsheets live in the config.cheatsheet.path.dir directory.
-- For cheatsheets to be determined by application context, cheatsheet
-- filenames must match the application bundle ID (e.g.
-- org.hammerspoon.Hammerspoon.md for Hammerspoon). This can be further narroed
-- down by window title (or even tmux window/pane/command if configured
-- correctly. See below for tmux settings.)
--
local m = {}

local ustr  = require('utils.string')
local ufile = require('utils.file')

local lastApp = nil
local chooser = nil
local chooserVisible = nil
local cheat_sheets = nil
local last_changed = nil
local visible = nil
local view = nil
local css = nil

-- constants
local FILE  = 'file://'
local HTTP  = 'http://'
local HTTPS = 'https://'

-- refocus on the app that was focused before the chooser was invoked
local function refocus()
  if lastApp ~= nil then
    lastApp:activate()
    lastApp = nil
  end
end

-- turn the clicked URL into an actual web url by removing the file://dir
-- prefix.
local function clickedURL(fullURL)
  local url = ustr.chopBeginning(fullURL, FILE..m.cfg.path.dir)
  if ustr.beginsWith(url, HTTP) or ustr.beginsWith(url, HTTPS) then
    return url
  else
    return HTTP..url
  end
end

-- Get current window name, tmux pane name (if applicable), and shell command
-- (if applicable) by parsing the window title.
--
-- For iTerm/tmux, I currently set this using tmux's set-titles-string
-- configuration set to '|#S|#W|#T' which results in something like:
-- '1. |session|window|hostname: command arg arg arg'
local function parseTitle(title)
  local window = nil
  local pane = nil
  local cmd = nil

  local titles = ustr.split(title, '|')
  if #titles >= 4 then
    window = titles[2]
    pane = titles[3]
    local cmds = ustr.split(titles[4], ':')
    if #cmds >= 2 then
      local words = ustr.split(ustr.trim(cmds[2]), '%s')
      if words ~= nil then cmd = words[1] end
    end
  else
    -- kind of a hack for non-terminal window titles.
    -- for example, split on ' ' for web pages named
    -- 'Hammerspoon docs: hs.chooser'
    local toSplit = #titles > 1 and titles[1] or title
    -- m.log.d('toSplit', toSplit)
    local parts = ustr.split(toSplit, '[ /]')
    if parts[1] then
      window = hs.http.encodeForQuery(parts[1]:gsub('[:%%%.%?/%[%]%(%)%+%$]', '_'))
    end
    if parts[2] then
      pane = hs.http.encodeForQuery(parts[2]:gsub('[:%%%.%?/%[%]%(%)%+%$]', '_'))
    end
    if parts[3] then
      cmd = hs.http.encodeForQuery(parts[3]:gsub('[:%%%.%?/%[%]%(%)%+%$]', '_'))
    end
  end
  -- m.log.d(window, pane, cmd)
  return window, pane, cmd
end

-- convert a cheatsheet name to a full path string
local function toPath(filename)
  if filename == nil then return nil end
  return ufile.toPath(m.cfg.path.dir, filename..'.md')
end

-- return true if the cheatsheet has changed since the last time we've looked
-- at it, false otherwise.
local function hasChanged(name)
  local modified = ufile.lastModified(toPath(name))
  return last_changed[name] == nil or last_changed[name] < modified
end

-- return true if the cheat_sheet[name] needs updating
local function shouldUpdate(name)
  local should = cheat_sheets[name] == nil or hasChanged(name)
  return should
end

-- make an id from the passed in args
local function toID(...) return table.concat({...}, '.') end

-- return valid id if the cheatsheet exists
local function findCheatsheet(id, default)
  -- m.log.d('looking for id:', id)
  return ufile.exists(toPath(id)) and id or default
end

-- returns a set of names to look for within the current application context.
local function allNamesFromContext()
  -- names is a table where keys are the names, and the values are the
  -- weights, so that the list is unique but sortable
  local names = {[m.cfg.defaultName] = 1}
  local app = hs.application.frontmostApplication()
  local id = app:bundleID()
  names[id] = 2

  local mainWindow = app:mainWindow()
  if mainWindow ~= nil then
    local window, pane, cmd = parseTitle(mainWindow:title())
    -- if any of these are nil, it doesn't matter. the names table will have
    -- unique keys, and the weights will still sort correctly even with gaps.
    names[toID(id, window)] = 3
    names[toID(id, pane)] = 4
    names[toID(id, cmd)] = 5
    names[toID(id, window, pane)] = 6
    names[toID(id, window, cmd)] = 7
    names[toID(id, pane, cmd)] = 8
    names[toID(id, window, pane, cmd)] = 9
  end

  -- m.log.d('names', hs.inspect(names))
  return names
end

-- find the name for the current cheatsheet based on focused window, and
-- potentially extra data about the focused window (e.g. current tmux tab or
-- currently running command in a terminal window).
local function findNameFromContext()
  local names = allNamesFromContext()
  local id = nil
  local heaviest = 0

  for name, weight in pairs(names) do
    if heaviest < weight then
      local found = findCheatsheet(name, id)
      if found ~= id then
        heaviest = weight
        id = found
      end
    end
  end

  return id
end

-- load the stylsheet for the webview
local function loadCSS(path)
  path = path or m.cfg.path.css
  local modified = ufile.lastModified(path)
  if last_changed[path] == nil or last_changed[path] < modified then
    last_changed[path] = modified
    local f = io.open(path, 'r')
    css = f:read("*all")
    f:close()
  end
end

-- load the markdown file and convert to html, calling the given callback with
-- the html.
local function markdownToHTML(name, callback)
  local filePath = toPath(name)
  last_changed[name] = ufile.lastModified(filePath)

  local function onTaskComplete(exitCode, stdOut, stdErr)
    if exitCode == 0 then
      local html = [[
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <style>
      ]]..css..[[
        </style>
      </head>
      <body>
      <div class="box">
      ]]..stdOut..[[
      </div>
      </body>
      </html>
      ]]

      -- m.log.d('html', html)

      callback(html)
    else
      m.log.e('error converting markdown to html:', stdErr)
    end
  end

  if ufile.exists(filePath) then
    hs.task.new(m.cfg.path.pandoc, onTaskComplete, {
      '-f', 'markdown_github+fenced_code_attributes',
      '-t', 'html5',
      filePath
    }):start()
  else
    m.log.w('path does not exist:', filePath)
  end
end

-- make link clicks go to the default system url handler
local function policy(event, webview, data)
  if event == 'navigationAction' or event == 'newWindow' then
    hs.task.new('/usr/bin/open', nil, {clickedURL(data.request.URL)}):start()
  end
  return false
end

-- create a new webview with the given html and title
local function createView(html, title)
  local screen = hs.screen.mainScreen()
  local viewRect = screen:frame():scale(0.94):move({x=0, y=-20})
  view = hs.webview.new(viewRect, {
    javaScriptEnabled=false,
    -- developerExtrasEnabled=true,
  })
  local masks = hs.webview.windowMasks
  view:windowStyle(
    masks.borderless |
    masks.utility |
    masks.HUD |
    masks.titled |
    masks.nonactivating
  )
  view:windowTitle(title)
  view:html(html)
end

-- load the html for a cheatsheet, then call the callback
local function loadCheatsheet(name, callback)
  -- m.log.d('loading cheatsheet', name)
  markdownToHTML(name, function(html)
    if html then
      cheat_sheets[name] = html
      callback()
    end
  end)
end

-- show the given named cheatsheet (if it exists) on-screen
local function showCheatsheet(name)
  if cheat_sheets[name] == nil then return end
  createView(cheat_sheets[name], name)
  hs.timer.waitUntil(
    function() return view ~= nil end,
    function()
      hs.timer.waitWhile(
        function() view:loading() end,
        function()
          -- m.log.d('done loading (showing view now)', name)
          view:show()
          view:policyCallback(policy)
          visible = true
        end,
        0.05
      )
    end,
    0.05
  )
end

-- hide all cheatsheets
local function hideCheatsheet()
  if view ~= nil then
    view:delete()
    view = nil
  end
  visible = false
end

-- edit a cheatsheet
local function editCheatsheet(name)
  if not name then return end
  local file = toPath(name)
  if not ufile.exists(file) then ufile.create(file) end
  hs.task.new('/usr/bin/open', nil, {'-t', file}):start()
end

-- show the chooser
local function showChooser()
  if chooser ~= nil then
    lastApp = hs.application.frontmostApplication()

    chooser:query('')
    local names = allNamesFromContext()
    local choices = {}

    for name, weight in pairs(names) do
      local exists = findCheatsheet(name, false) ~= false
      choices[#choices+1] = {
        text = name,
        subText = exists and 'Edit' or 'Create New',
        exists = exists,
        weight = weight,
      }
    end

    -- sort by existing, then by weight
    table.sort(choices, function(a, b)
      if a.exists == b.exists then
        return a.weight > b.weight
      end
      return a.exists and not b.exists
    end)
    chooser:rows(#choices)
    chooser:choices(choices)

    chooser:show()
    chooserVisible = true
  end
end

-- hide the chooser
local function hideChooser()
  if chooser ~= nil then
    -- hide calls choiceCallback
    chooser:hide()
  end
end

-- callback when a chooser choice is made
local function choiceCallback(choice)
  refocus()
  chooserVisible = false
  if choice ~= nil then editCheatsheet(choice.text) end
end

-- show/hide the named sheet (if name is given), else the sheet determined from
-- the currently focused application.
function m.toggle(name)
  if visible then
    hideCheatsheet()
  else
    name = name or findNameFromContext()
    if name == nil then
      m.log.e('No cheatsheets found! Please check that:\n',
      'the directory exists:', m.cfg.path.dir, '\n',
      'the default file exists:', toPath(m.cfg.defaultName))
    else
      if shouldUpdate(name) then
        loadCheatsheet(name, function()
          showCheatsheet(name)
        end)
      else
        showCheatsheet(name)
      end
    end
  end
end

-- toggle chooser visibility
function m.chooserToggle()
  if chooser ~= nil then
    if chooserVisible then hideChooser() else showChooser() end
  end
end

function m.start()
  cheat_sheets = {}
  last_changed = {}
  chooser = hs.chooser.new(choiceCallback)
  chooser:width(m.cfg.chooserWidth)
  loadCSS()
end

function m.stop()
  if chooser then chooser:delete() end
  hideCheatsheet()
  if (cheat_sheets and type(cheat_sheets) == "table") then
    for name,_ in pairs(cheat_sheets) do
      cheat_sheets[name] = nil
      last_changed[name] = nil
    end
  end
  cheat_sheets = nil
  last_changed = nil
  chooser = nil
  visible = nil
  css = nil
end

return m
