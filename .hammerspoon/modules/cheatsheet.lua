-- module: Cheatsheet - show text file popup overlays on-demand
-- (Inspired by the CheatSheet app by Stefan Fürst)
--
-- Note: due to cheatsheet caching, it is necessary to reload Hammerspoon to
-- see changes made to the cheatsheets themselves.
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

local cheat_sheets = nil
local visible = nil

-- Get current shell command by parsing the window title.
-- I currently set this using tmux's set-titles-string configuration set to
-- '#S:#I.#P #W|#T'
local function getCurrentShellCmd(title)
  local titles = ustr.split(title, '|')
  if #titles >= 2 then
    local cmds = ustr.split(titles[2], ':')
    if #cmds >= 2 then
      local words = ustr.split(ustr.trim(cmds[2]), '%s')
      if words ~= nil then
        return words[1]
      end
    end
  end
  return nil
end

-- show the given named cheatsheet (if it exists) on-screen
local function showCheatsheet(name)
  if cheat_sheets[name] == nil then return end
  m.log.d('drawing:', name)
  for _,obj in ipairs(cheat_sheets[name]) do obj:show() end
  visible = true
end

-- convert a cheatsheet name to a full path string
local function toPath(filename)
  return ufile.toPath(m.cfg.path, filename..'.txt')
end

-- find the name for the current cheatsheet based on focused window, and
-- potentially extra data about the focused window (e.g. current tmux tab or
-- currently running command in a terminal window).
local function nameFromContext()
  local app = hs.application.frontmostApplication()
  local id = app:bundleID()
  if id == 'com.googlecode.iterm2' then
    -- special case handler for iTerm2... check currently running command
    local cmd = getCurrentShellCmd(app:mainWindow():title())
    if cmd ~= nil then
      local new_id = id..'.'..cmd
      m.log.d('looking for special id:', new_id)
      if ufile.exists(toPath(new_id)) then id = new_id end
    end
  end
  m.log.d('looking for id:', id)
  if ufile.exists(toPath(id)) then return id end
  return m.cfg.defaultName
end

-- TODO: make stylized text with color codes from cheat files
--       or possibly markdown/webview
--
-- parse the given cheatsheet file and prepare for drawing, splitting it into
-- two pages for side-by-side rendering.
local function parseCheatFile(filename)
  local llines = {}
  local rlines = {}
  local path = toPath(filename)

  local i = 1
  local lines = llines
  for line in io.lines(path) do
    if i > m.cfg.maxLines then lines = rlines end
    i = i + 1
    table.insert(lines, line)
  end

  return table.concat(llines, '\n'), table.concat(rlines, '\n')
end

-- create a new cheatsheet object to be drawn, and cache it
local function makeCheatsheet(name)
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

-- show/hide the named sheet (if name is given), else the sheet determined from
-- the currently focused application.
function m.toggle(name)
  if visible then
    hideCheatSheets()
  else
    name = name or nameFromContext()
    if cheat_sheets[name] == nil then makeCheatsheet(name) end
    showCheatsheet(name)
  end
end

function m.start()
  cheat_sheets = {}
end

function m.stop()
  for name,sheet in pairs(cheat_sheets) do
    for _,obj in ipairs(sheet) do obj:delete() end
    cheat_sheets[name] = nil
  end
  cheat_sheets = nil
  visible = nil
end

return m
