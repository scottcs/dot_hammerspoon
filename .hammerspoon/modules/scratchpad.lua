-- module: scratchpad - quick place to jot down info
-- I use this for short-term todos and reminders, mostly.
--
local m = {}

local ufile = require('utils.file')
local uapp = require('utils.app')

local lastApp = nil
local chooser = nil
local menu = nil
local visible = false

-- COMMANDS
local commands = {
  {
    ['text'] = 'Append...',
    ['subText'] = 'Append to Scratchpad',
    ['command'] = 'append',
  },
  {
    ['text'] = 'Edit',
    ['subText'] = 'Edit Scratchpad',
    ['command'] = 'edit',
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

-- This resets the choices to the command table, and has the desired side
-- effect of resetting the highlighted choice as well.
local function resetChoices()
  chooser:rows(#commands)
  -- add commands
  local choices = {}
  for _, command in ipairs(commands) do
    choices[#choices+1] = command
  end
  chooser:choices(choices)
end

-- remove a specific line from the scratchpad file
local function removeLine(line)
  -- write out the scratchpad file to a temp file, line by line, skipping the
  -- line we want to remove, then move the temp file to overwrite the
  -- scratchpad file. this makes things slightly more atomic, to try to avoid
  -- data corruption.
  local tmpfile = ufile.toPath(hsm.cfg.paths.tmp, 'scratchpad.md')
  local f = io.open(tmpfile, 'w+')
  for oldline in io.lines(m.cfg.file) do
    if oldline ~= line then f:write(oldline..'\n') end
  end
  f:close()

  ufile.move(tmpfile, m.cfg.file, true,
    function(output) end,
    function(err) uapp.notify('Error updating Scratchpad file', err) end
  )
end

-- callback when a chooser choice is made, which in this case will only be one
-- of the commands.
local function choiceCallback(choice)
  refocus()
  visible = false

  if choice.command == 'append' then
    -- append the query string to the scratchpad file
    ufile.append(m.cfg.file, chooser:query())
  elseif choice.command == 'edit' then
    -- open the scratchpad file in an editor
    m.edit()
  end

  -- set the chooser back to the default state
  resetChoices()
  chooser:query('')
end

-- callback when the menubar icon is clicked.
local function menuClickCallback(mods)
  local list = {}

  if mods.shift or mods.ctrl then
    -- edit the scratchpad
    m.edit()
  else
    -- show the contents of the scratchpad as a menu
    if ufile.exists(m.cfg.file) then
      for line in io.lines(m.cfg.file) do
        -- if a line is clicked, open the scratchpad for editing
        -- if a line is ctrl-clicked, remove that line from the scratchpad file
        local function menuItemClickCallback(itemmods)
          if itemmods.ctrl then
            removeLine(line)
          else
            hs.pasteboard.setContents(line)
          end
        end
        list[#list+1] = {title=tostring(line), fn=menuItemClickCallback}
      end
    end
  end

  return list
end

-- open the scratchpad file in the default .md editor
function m.edit()
  if not ufile.exists(m.cfg.file) then
    ufile.create(m.cfg.file)
  end
  local task = hs.task.new('/usr/bin/open', nil, {'-t', m.cfg.file})
  task:start()
end

-- toggle chooser visibility
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
  menu = hs.menubar.newWithPriority(m.cfg.menupriority)
  menu:setTitle('[?]')
  menu:setMenu(menuClickCallback)

  chooser = hs.chooser.new(choiceCallback)
  chooser:width(m.cfg.width)
  -- disable built-in search
  chooser:queryChangedCallback(function() end)

  resetChoices()
end

function m.stop()
  if chooser then chooser:delete() end
  if menu then menu:delete() end

  chooser = nil
  menu = nil
  lastApp = nil
end

return m
