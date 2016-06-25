-- module: quick note taking/searching
-- (Inspired by Notational Velocity, by Zachary Schneirov)
--
-- Can pass in a directory, so it's easy to bind different keys to different
-- directories of files. (I use a general "notes" as well as "til" for
-- today-I-learned technical notes).
local m = {}

local ufile = require('utils.file')
local ustring = require('utils.string')

local lastApp = nil
local chooser = nil
local matchCache = {}
local rankCache = {}
local allChoices = nil
local currentPath = nil
local lastQueries = {}
local visible = false


-- COMMANDS
local commands = {
  {
    ['text'] = 'Create...',
    ['subText'] = 'Create a new note with the query as filename',
    ['command'] = 'create',
  }
}

-- command filters can't be placed in the command table above because chooser
-- choice tables must be serializable, so we create a separate table for them.
local commandFilters = {
  ['create'] = function()
    local filePath = ufile.toPath(currentPath, chooser:query())
    return not ufile.exists(ufile.withExtension(filePath, 'md'))
  end,
}
--------------------

-- sort by rank and then by alphabet
local function choiceSort(a, b)
  if a.rank == b.rank then return a.text < b.text end
  return a.rank > b.rank
end

-- retrieve the last query string that was used in the chooser
local function getLastQuery()
  return lastQueries[currentPath] or ''
end

-- get a sorted table of all available choices for the current path
local function getAllChoices()
  local iterFn, dirObj = hs.fs.dir(currentPath)
  local item = iterFn(dirObj)
  local choices = {}

  while item do
    local filePath = ufile.toPath(currentPath, item)
    -- we only care about markdown files (*.md)
    if string.find(item, '^[^%.].-%.md') then
      local paragraph = {}

      -- read the file to provide additional text for searching
      -- as well as a bit of subtext in the chooser item.
      local f = io.open(filePath)
      local line = f:read()
      while line ~= nil do
        if string.len(line) > 0 then
          paragraph[#paragraph+1] = line
        end
        line = f:read()
      end
      f:close()
      local contents = table.concat(paragraph, '\n')

      choices[#choices+1] = {
        ['text'] = item,
        ['additionalSearchText'] = contents,
        ['subText'] = paragraph[1],
        ['rank'] = 0,
        ['path'] = filePath,
      }
    end
    item = iterFn(dirObj)
  end

  table.sort(choices, choiceSort)
  return choices
end

-- refocus on the app that was focused before the chooser was invoked
local function refocus()
  if lastApp ~= nil then
    lastApp:activate()
    lastApp = nil
  end
end

-- open the given file in the default OS X text editor for .md files
-- (You can change this in OS X by selecting a .md file, hitting cmd-i, finding
-- the "open with" panel, changing the app to whatever app you want, and then
-- hitting the "Change all" button.)
local function launchEditor(path)
  path = ufile.withExtension(path, 'md')
  if not ufile.exists(path) then
    ufile.create(path)
  end
  local task = hs.task.new('/usr/bin/open', nil, {'-t', path})
  task:start()
end

-- callback when a choice is made from the chooser
local function choiceCallback(choice)
  local query = chooser:query()
  local path

  refocus()
  visible = false
  lastQueries[currentPath] = query

  -- create a new file and open it, if the create command was chosen, otherwise
  -- open the chosen filename.
  if choice.command == 'create' then
    path = ufile.toPath(currentPath, query)
  else
    path = choice.path
  end

  if path ~= nil then
    launchEditor(path)
  end
end

-- determine the rank for a given file based on the search query string. this
-- gives more weight to filenames (a.k.a. titles) that match the query
-- directly, than content text that matches, specified by
-- config.notational.titleWeight. Results are cached while typing, to speed
-- things up a bit (but the cache is emptied when the chooser is hidden).
local function getRank(queries, choice)
  local rank = 0
  local choiceText = choice.text:lower()

  for _, q in ipairs(queries) do
    local qq = q:lower()
    local cacheKey = qq .. '|' .. choiceText

    if rankCache[cacheKey] == nil then
      local _, count1 = string.gsub(choiceText, qq, qq)
      local _, count2 = string.gsub(choice.additionalSearchText:lower(), qq, qq)
      -- title match is much more likely to be relevant
      rankCache[cacheKey] = count1 * m.cfg.titleWeight + count2
    end

    -- If any single query term doesn't match then we don't match at all
    if rankCache[cacheKey] == 0 then return 0 end

    rank = rank + rankCache[cacheKey]
  end

  return rank
end

-- callback while the user is typing in the chooser window. This determines
-- which files to show in the chooser list by ranking files that match the
-- query string. The "Create" command is always shown at the bottom. Matches
-- are cached while typing to speed things up a little, but the cache is
-- emptied when the chooser window is hidden.
local function queryChangedCallback(query)
  if query == '' then
    chooser:choices(allChoices)
  else
    local choices = {}

    if matchCache[query] == nil then
      local queries = ustring.split(query, ' ')

      for _, aChoice in ipairs(allChoices) do
        aChoice.rank = getRank(queries, aChoice)
        if aChoice.rank > 0 then
          choices[#choices+1] = aChoice
        end
      end

      table.sort(choices, choiceSort)

      -- add commands last, after sorting
      for _, aCommand in ipairs(commands) do
        local filter = commandFilters[aCommand.command]
        if filter ~= nil and filter() then
          choices[#choices+1] = aCommand
        end
      end

      matchCache[query] = choices
    end

    chooser:choices(matchCache[query])
  end
end

-- toggle the chooser window for the given path
function m.toggle(path)
  if chooser ~= nil then
    if visible then
      m.hide()
    else
      m.show(path)
    end
  end
end

-- show the chooser window for the given path
function m.show(path)
  if chooser ~= nil then
    lastApp = hs.application.frontmostApplication()
    matchCache = {}
    rankCache = {}
    currentPath = path or m.cfg.path.notes
    chooser:query(getLastQuery())
    allChoices = getAllChoices()
    chooser:show()
    visible = true
  end
end

-- hide the chooser window
function m.hide()
  if chooser ~= nil then
    -- hide calls choiceCallback
    chooser:hide()
  end
end

function m.start()
  chooser = hs.chooser.new(choiceCallback)
  chooser:width(m.cfg.width)
  chooser:rows(m.cfg.rows)
  chooser:queryChangedCallback(queryChangedCallback)
  chooser:choices(allChoices)
  currentPath = m.cfg.path.notes
end

function m.stop()
  if chooser then chooser:delete() end
  chooser = nil
  lastApp = nil
  matchCache = nil
  rankCache = nil
  allChoices = nil
  lastQueries = nil
  commands = nil
  currentPath = nil
end

return m
