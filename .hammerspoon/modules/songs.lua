-- module: songs - for ranking songs and manipulating players
--
-- The ranking relies partially on another program I've written called track,
-- that keeps a database of song information and rankings. Set
-- config.songs.trackBinary to nil to disable this.
local m = {}

local uapp = require('utils.app')
local ustr = require('utils.string')

-- constants
local K = {
  SPOTIFY = 'Spotify',
  ITUNES = 'iTunes',
}

local lastApi = nil

-- keep track of the last player by saving the api in a variable
local function setLastPlayer(name)
  lastApi = nil
  if name == K.SPOTIFY then
    if hs.spotify.isRunning() then
      lastApi = hs.spotify
      lastApi.scxGetPlaybackState = uapp.getSpotifyPlayerState
    end
  elseif name == K.ITUNES then
    if hs.itunes.isRunning() then
      lastApi = hs.itunes
      lastApi.scxGetPlaybackState = uapp.getiTunesPlayerState
    end
  end
end

-- get the correct api for the currently open player
function m.getApi()
  local spotifyState = uapp.getSpotifyPlayerState()
  local itunesState = uapp.getiTunesPlayerState()

  if spotifyState == ustr.unquote(hs.spotify.state_playing) then
    setLastPlayer(K.SPOTIFY)
  elseif itunesState == ustr.unquote(hs.itunes.state_playing) then
    setLastPlayer(K.ITUNES)
  elseif lastApi == nil then
    if spotifyState ~= nil then
      setLastPlayer(K.SPOTIFY)
    elseif itunesState ~= nil then
      setLastPlayer(K.ITUNES)
    else
      m.log.i('No players for songs.')
    end
  end
  return lastApi
end

-- play if paused, or pause if playing
function m.playPause()
  local api = m.getApi()
  if api ~= nil then
    local state = api.scxGetPlaybackState()
    if state == ustr.unquote(api.state_paused) then
      api.play()
    elseif state ~= nil then
      api.pause()
    end
  end
end

-- skip to the next track
function m.nextTrack()
  local api = m.getApi()
  if api ~= nil then
    local state = api.scxGetPlaybackState()
    api.next()
    if state == ustr.unquote(api.state_paused) then
      api.play()
    end
  end
end

-- skip to the previous track
function m.prevTrack()
  local api = m.getApi()
  if api ~= nil then
    local state = api.scxGetPlaybackState()
    api.previous()
    if state == ustr.unquote(api.state_paused) then
      api.play()
    end
  end
end

-- get info on the currently playing song (handles radio streams in iTunes)
local function getInfo(api)
  local state = nil
  local msg = nil
  local artist, track, album
  if api ~= nil then
    state = api.scxGetPlaybackState()
    if state == ustr.unquote(api.state_playing) then
      artist = api.getCurrentArtist()
      track = api.getCurrentTrack()
      album = api.getCurrentAlbum()
      if artist == '' and api == hs.itunes then
        local stream = uapp.tell('iTunes', 'current stream title as string')
        album = track
        local fields = ustr.split(stream, '%s%-%s')
        artist, track = fields[1] or '???', fields[2] or '???'
      end
    end
  end
  return artist, track, album, state
end

-- make a nicely formated string of song info
local function formatInfo(artist, track, album, rating)
  local msg = track .. '\n' .. artist .. '\n' .. '(' .. album .. ')'
  if rating and rating > 0 then
    msg = msg .. '\n' .. (string.rep('*', rating))
  end
  return msg
end

-- get info on the currently playing song and display in an alert
function m.getInfo()
  local api = m.getApi()
  local msg = '... silence ...'

  if api then
    local artist, track, album, state = getInfo(api)
    if state == ustr.unquote(api.state_playing) then
      msg = formatInfo(artist, track, album)
    end
  end
  hs.alert.show(msg, 3)
end

-- callback for track binary to parse its output and display it in an alert
local function trackCallback(exitCode, stdOut, stdErr)
  if exitCode ~= 0 then
    m.log.e(stdErr)
    hs.alert.show('Error running track task, see Hammerspoon log.', 3)
    return
  end

  hs.alert.show(string.gsub(stdOut, '%s+', ' '), 3)
end

-- rate a song in iTunes using hs.osascript
local function rateiTunesSong(rating)
  local api = m.getApi()
  if api == hs.itunes then
    local state = api.scxGetPlaybackState()
    if state == ustr.unquote(api.state_playing) then
      local cmd = 'set rating of current track to '..tostring(rating * 20)
      local result = uapp.tell('iTunes', cmd)
      if result == nil then
        m.log.e('could not set iTunes rating')
      else
        local artist, track, album, _ = getInfo(api)
        local msg = formatInfo(artist, track, album, rating)
        hs.alert.show(msg, 3)
      end
    end
  end
end

-- rate a song using the track binary if available,
-- otherwise rate directly in iTunes
local function rateSong(rating)
  if uapp.getiTunesPlayerState() == nil
    and uapp.getSpotifyPlayerState() == nil then return end

  if m.cfg.trackBinary == nil then
    rateiTunesSong(rating)
  else
    local task = hs.task.new(m.cfg.trackBinary, trackCallback, {'-r', ''..rating})
    local env = task:environment()
    env['PATH'] = '/usr/local/bin:' .. env['PATH']
    env['TRACK_DB'] = m.cfg.trackDB
    task:setEnvironment(env)
    if not task:start() then
      m.log.e('could not start task for trackBinary "'..m.cfg.trackBinary..'"')
    end
  end
end

-- helpers for easy song rating keybindings
function m.rateSong0() return rateSong(0) end
function m.rateSong1() return rateSong(1) end
function m.rateSong2() return rateSong(2) end
function m.rateSong3() return rateSong(3) end
function m.rateSong4() return rateSong(4) end
function m.rateSong5() return rateSong(5) end

return m
