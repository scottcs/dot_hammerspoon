-- module: Cheatsheet - show text file popup overlays on-demand
-- (Inspired by the CheatSheet app by Stefan Fürst)
--
-- Cheatsheets live in the config.cheatsheet.path directory.
-- For cheatsheets to be determined by application context, cheatsheet
-- filenames must match the application bundle ID (e.g.
-- org.hammerspoon.Hammerspoon.txt for Hammerspoon).
--
local m = {}

local ustr  = require('utils.string')
local ufile = require('utils.file')
local draw  = require('hs.drawing')
local geom  = require('hs.geometry')

local lastApp = nil
local chooser = nil
local chooserVisible = nil
local cheat_sheets = nil
local last_changed = nil
local visible = nil

-- refocus on the app that was focused before the chooser was invoked
local function refocus()
  if lastApp ~= nil then
    lastApp:activate()
    lastApp = nil
  end
end

-- Get current tmux window name, pane name, and shell command by parsing the
-- tmux title. I currently set this using tmux's set-titles-string
-- configuration set to '|#S|#W|#T' which, in iTerm, results in something like:
-- '1. |session|window|hostname: command arg arg arg'
local function parseTmuxTitle(title)
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
  end
  return window, pane, cmd
end

-- show the given named cheatsheet (if it exists) on-screen
local function showCheatsheet(name)
  if cheat_sheets[name] == nil then return end
  -- m.log.d('drawing:', name)
  for _,obj in ipairs(cheat_sheets[name]) do obj:show() end
  visible = true
end

-- convert a cheatsheet name to a full path string
local function toPath(filename)
  return ufile.toPath(m.cfg.path, filename..'.txt')
end

-- return true if the cheatsheet has changed since the last time we've looked
-- at it, false otherwise.
local function hasChanged(name)
  local modified = ufile.lastModified(toPath(name))
  return last_changed[name] == nil or last_changed[name] < modified
end

-- return true if the cheat_sheet[name] needs updating
local function shouldUpdate(name)
  return cheat_sheets[name] == nil or hasChanged(name)
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

  if id == 'com.googlecode.iterm2' then
    local window, pane, cmd = parseTmuxTitle(app:mainWindow():title())
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

-- TODO: make stylized text with color codes from cheat files
--       or possibly markdown/webview
--
-- parse the given cheatsheet file and prepare for drawing, splitting it into
-- two pages for side-by-side rendering. This also saves the file's
-- modification time in last_changed.
local function parseCheatFile(name)
  local llines = {}
  local rlines = {}
  local path = toPath(name)

  local i = 1
  local lines = llines
  for line in io.lines(path) do
    if i > m.cfg.maxLines then lines = rlines end
    i = i + 1
    table.insert(lines, line)
  end

  last_changed[name] = ufile.lastModified(path)

  return table.concat(llines, '\n'), table.concat(rlines, '\n')
end

-- create a new cheatsheet object to be drawn, and cache it
local function makeCheatsheet(name)
  -- m.log.d('making:', name)
  local screen = hs.screen.mainScreen()
  local bgrect = screen:frame():scale(0.94):move({x=0, y=-20})

  -- set up left and right text areas
  local ltextrect = hs.geometry.copy(bgrect)
  ltextrect.w = ltextrect.w / 2
  local rtextrect = hs.geometry.copy(ltextrect)
  rtextrect.x = ltextrect.x + ltextrect.w + 1
  ltextrect = ltextrect:scale(0.99)
  rtextrect = rtextrect:scale(0.99)

  -- get the text for left and right areas
  local ltext, rtext = parseCheatFile(name)

  -- draw the sheets
  local sheet = draw.rectangle(bgrect)
  local lsheet_text = draw.text(ltextrect, ltext)
  local rsheet_text = draw.text(rtextrect, rtext)

  -- set colors and styles
  sheet:setStrokeColor(m.cfg.colors.border)
  sheet:setFill(true)
  sheet:setFillColor(m.cfg.colors.bg)
  sheet:setStrokeWidth(3)
  sheet:bringToFront(true)

  lsheet_text:setTextStyle(m.cfg.style)
  lsheet_text:bringToFront(true)
  rsheet_text:setTextStyle(m.cfg.style)
  rsheet_text:bringToFront(true)

  -- cache the layers of the cheatsheet
  cheat_sheets[name] = {sheet, lsheet_text, rsheet_text}
end

-- hide all cheatsheets
local function hideCheatSheets()
  for _,sheet in pairs(cheat_sheets) do
    for _,obj in ipairs(sheet) do obj:hide() end
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
local function chooserShow()
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
local function chooserHide()
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
    hideCheatSheets()
  else
    name = name or findNameFromContext()
    if shouldUpdate(name) then makeCheatsheet(name) end
    showCheatsheet(name)
  end
end

-- toggle chooser visibility
function m.chooserToggle()
  if chooser ~= nil then
    if chooserVisible then chooserHide() else chooserShow() end
  end
end

function m.start()
  cheat_sheets = {}
  last_changed = {}
  chooser = hs.chooser.new(choiceCallback)
  chooser:width(m.cfg.chooserWidth)
end

function m.stop()
  if chooser then chooser:delete() end
  for name,sheet in pairs(cheat_sheets) do
    for _,obj in ipairs(sheet) do obj:delete() end
    cheat_sheets[name] = nil
    last_changed[name] = nil
  end
  cheat_sheets = nil
  last_changed = nil
  chooser = nil
  visible = nil
end

return m
