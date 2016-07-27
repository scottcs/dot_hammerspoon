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
local uapp = require('utils.app')

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
local FROMMENU = 'Create New From Menu Items'
local AX = {
  MENUBARITEM = 'AXMenuBarItem',
  MENUITEM = 'AXMenuItem',
}

local commandEnum = {
  [0] = '⌘',
        '⇧⌘',
        '⌥⌘',
        '⌥⇧⌘',
        '⌃⌘',
        '⌃⇧⌘',
        '⌃⌥⌘',
        '⌃⌥⇧⌘',
        '⌦',
        '⇧',
        '⌥',
        '⌥⇧',
        '⌃',
        '⌃⇧',
        '⌃⌥',
        '⌃⌥⇧',
}

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
-- I've got my shell set up to change the window title to the currently running
-- command.
--
-- For iTerm/tmux, I currently set this using tmux's set-titles-string
-- configuration set to:
--    set -g set-titles on
--    set -g set-titles-string '#S|#W|#T'
--
-- This results in a title string that looks something like this for most
-- commands:
--    'session|window|command arg arg arg'
-- (Note that commands with pipes could also potentially be parsed here.)
--
-- Further, in my vimrc, I use titlestring to provide even more info such as
-- filename and filetype of the currently focused file:
--    set title
--    set titlestring=nvim\|%Y\|%t\|%{expand(\"%:p:h\")}
--
-- So within a tmux pane that's running neovim and editing this file, I end up
-- with a window title that looks like:
--    'session|window|nvim|LUA|cheatsheet.lua|/full/path/to/parent/dir'
--
-- Note: using iTerm, I disabled all "Window & Tab Titles" options under
-- Appearance in the preferences.
--
local function parseTitle(title)
  local parts = {}
  local titles = ustr.split(title, '|')
  -- m.log.d('titles', hs.inspect(titles))

  for i,t in ipairs(titles) do
    local subtitles = ustr.split(t, '[ /:]')
    for _,subt in ipairs(subtitles) do
      subt = ustr.trim(subt)
      subt = hs.http.encodeForQuery(subt:gsub('[:%%%.%?/%[%]%(%)%+%$]', '_'))
      if subt and subt ~= '' then
        parts[#parts+1] = string.lower(subt)
      end
    end
  end

  -- m.log.d('parts', hs.inspect(parts))
  return parts
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
  -- m.log.d('looking for id:', id, ufile.exists(toPath(id)))
  return ufile.exists(toPath(id)) and id or default
end

-- returns a set of names to look for within the current application context.
local function allNamesFromContext(existing)
  -- names is an array where items are the names, ordered by least specific
  -- to most specific.
  local app = hs.application.frontmostApplication()
  local id = app:bundleID()
  local names = {}
  for _,name in ipairs{m.cfg.defaultName, id} do
    if findCheatsheet(name, false) then names[#names+1] = name end
  end

  -- TODO: make this better. I'm not happy with it. It works ok for my
  -- particular tmux/nvim setup.
  local mainWindow = app:mainWindow()
  if mainWindow ~= nil then
    local url = uapp.getFocusedBrowserURL()
    local title = mainWindow:title()

    if url ~= nil then
      local urlParts = ustr.split(url, '/')
      -- skip 1 and 2, which are the protocol and empty string due to the split
      title = urlParts[3]
      for i=4,#urlParts,1 do
        title = title..'|'..urlParts[i]
      end
    end

    local parts = parseTitle(title)
    local name = id
    local terminals = {
      ['com.apple.Terminal'] = true,
      ['com.googlecode.iterm2'] = true,
    }

    -- special handling of terminals;
    --     tmux_session|tmux_pane|command|sub1|sub2|sub3|...
    --   We want:
    --     tmux_session
    --     tmux_session.tmux_pane
    --     command
    --     command.sub1
    --     command.sub1.sub2
    --     etc
    -- for everything else, we just want a hierarchy progression:
    --     part1
    --     part1.part2
    --     part1.part2.part3
    --     etc
    local numParts = 1
    for i,part in ipairs(parts) do
      -- if a terminal then reset to id when we get to command (parts[3])
      if i == 3 and terminals[id] then
        name = id
        numParts = 1
      end

      -- don't add more than maxParts from config
      if numParts > m.cfg.maxParts then break end

      name = toID(name, part)
      if not existing or (existing and findCheatsheet(name, false)) then
        names[#names+1] = name
      end

      numParts = numParts + 1
    end
  end

  -- m.log.d('names', hs.inspect(names))
  return names
end

-- find the name for the current cheatsheet based on focused window, and
-- potentially extra data about the focused window (e.g. current tmux tab or
-- currently running command in a terminal window).
local function findNameFromContext()
  local names = allNamesFromContext(true)
  return names[#names]
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
  view:setLevel(hs.drawing.windowLevels.overlay)
  view:html(html)
end

local function getMenuItems(items)
  local lines = {}

  for _,item in ipairs(items) do
    if type(item) == 'table' then
      if item.AXRole == AX.MENUBARITEM and item.AXChildren then
        local childLines = getMenuItems(item.AXChildren[1])
        if #childLines > 0 then
          lines[#lines+1] = ''
          lines[#lines+1] = '| '..item.AXTitle..' | |'
          lines[#lines+1] = '| ---: | --- |'
          for i=1,#childLines do lines[#lines+1] = childLines[i] end
          lines[#lines+1] = ''
        end
      elseif item.AXRole == AX.MENUITEM and item.AXMenuItemCmdChar ~= '' then
        local commandGlyph = commandEnum[item.AXMenuItemCmdModifiers] or ''
        lines[#lines+1] = commandGlyph..' '..item.AXMenuItemCmdChar..' | '..item.AXTitle
      end
    end
  end

  return lines
end

local function getShortcutMenuItems(bundleID)
  local lines = {}
  local apps = hs.application.applicationsForBundleID(bundleID)
  if apps and #apps > 0 then
    lines = getMenuItems(apps[1]:getMenuItems())
  end
  return lines
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
local function showCheatsheet(name, visibleValue)
  visibleValue = visibleValue or 1
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
          visible = visibleValue
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
  visible = nil
end

-- edit a cheatsheet
local function editCheatsheet(name)
  if not name then return end
  local file = toPath(name)
  if not ufile.exists(file) then ufile.create(file) end
  hs.task.new('/usr/bin/open', nil, {'-t', file}):start()
end

-- create a new cheatsheet, filling its contents with menu items
local function createCheatsheetFromMenu(name)
  if not name then return end
  local file = toPath(name)
  if not ufile.exists(file) then
    if ufile.makeParentDir(file) then
      local f = io.open(file, 'w')
      for _,line in ipairs(getShortcutMenuItems(name)) do
        f:write(tostring(line) .. '\n')
      end
      f:close()
    end
  end
end

-- show the chooser
local function showChooser()
  if chooser ~= nil then
    lastApp = hs.application.frontmostApplication()

    chooser:query('')
    local names = allNamesFromContext()
    local choices = {}

    for weight, name in ipairs(names) do
      local exists = findCheatsheet(name, false) ~= false
      choices[#choices+1] = {
        text = name,
        subText = exists and 'Edit' or 'Create New',
        exists = exists,
        weight = weight,
      }
      -- extra entry for bundleID only, to generate default sheet
      if not exists and weight == 2 then
        choices[#choices+1] = {
          text = name,
          subText = FROMMENU,
          exists = exists,
          weight = weight,
        }
      end
    end

    -- sort by existing, then by weight
    table.sort(choices, function(a, b)
      if a.exists == b.exists then
        if a.weight == b.weight then
          return a.subText < b.subText
        end
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
  if choice ~= nil then
    if choice.subText == FROMMENU then
      createCheatsheetFromMenu(choice.text)
    else
      editCheatsheet(choice.text)
    end
  end
end

local function loadOrShowCheatsheet(name, visibleValue)
  if shouldUpdate(name) then
    loadCheatsheet(name, function()
      showCheatsheet(name, visibleValue)
    end)
  else
    showCheatsheet(name, visibleValue)
  end
end

local function errNoCheatsheets()
  m.log.e('No cheatsheets found! Please check that:\n',
  'the directory exists:', m.cfg.path.dir, '\n',
  'the default file exists:', toPath(m.cfg.defaultName))
end

-- show/hide the named sheet (if name is given), else the sheet determined from
-- the currently focused application.
function m.toggle(name)
  if visible then
    hideCheatsheet()
  else
    name = name or findNameFromContext()
    if name == nil then
      errNoCheatsheets()
    else
      loadOrShowCheatsheet(name)
    end
  end
end

-- cycle through relevant sheets, determined from the currently focused
-- application.
function m.cycle()
  local names = allNamesFromContext(true)
  if #names == 0 then
    errNoCheatsheets()
  else
    local lastSheet = visible or #names+1
    if visible then hideCheatsheet() end

    if lastSheet > 1 then
      local nextSheet = lastSheet - 1
      loadOrShowCheatsheet(names[nextSheet], nextSheet)
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
  css = nil
end

return m
