
# My Hammerspoon configuration

[`init.lua`](.hammerspoon/init.lua) loads and configures each module. [`bindings.lua`](.hammerspoon/bindings.lua) defines all of the keybindings. There are a number of utility functions defined in [`utils/`](.hammerspoon/utils), and all of the modules live in [`modules/`](.hammerspoon/modules).

See the [example_config.lua](.hammerspoon/example_config.lua) for configuration options for each module.

## Modules

### [appwindows](.hammerspoon/modules/appwindows.lua)

Map application events to actions to be taken automatically, such as putting an app in fullscreen mode as soon as it's launched.

### [battery](.hammerspoon/modules/battery.lua)

Battery status notifications.

### [browser](.hammerspoon/modules/browser.lua)

Send URL clicks to the most recently focused browser. (Will attempt to set Hammerspoon as the default URL handler when started, if it's not already.)

### [caffeine](.hammerspoon/modules/caffeine.lua)

Replacement for Caffeine, Amphetamine, etc. Menubar icon to toggle whether the mac can go to sleep when idle.

### [cheatsheet](.hammerspoon/modules/cheatsheet.lua)

Inspired by Stefan Fürst's CheatSheet app, but taken in a different direction. Rather than showing an overlay of the focused app's keyboard shortcuts, this module renders a custom markdown file in a WebView overlay, based on the focused app (or even window title, tmux pane, or shell command). Additionally, you can bind a key to a chooser toggle function that makes it easy to open and edit any of the possible markdown files for the current window.

Note: The webview overlay is split into 2 columns, and the markdown file will fill both columns as it grows in length (left first, then right).

See [`cheatsheets/`](cheatsheets) for examples.

Requires [pandoc](http://pandoc.org/) but would be pretty easy to modify to work with a different markdown-to-html converter, like discount.

### [hazel](.hammerspoon/modules/hazel.lua)

Filesystem watcher module, which is probably useless to anyone but me. I replaced my old Hazel rules with this module (and no longer use Hazel). You'd probably want to modify it heavily if you use it at all.

### [notational](.hammerspoon/modules/notational.lua)

Inspired by Notational Velocity. Bring up a chooser via keybinding that lists markdown files in a directory and allows for quick searching of filename and file contents, then edit the file that's selected. If the file doesn't exist, create a new one and edit that instead. Great for quickly writing notes or finding old notes. Can be bound to multiple keys for different directories. (For example, I have one for general notes, and one for "Today I Learned" notes that are more specific to computing.)

### [scratchpad](.hammerspoon/modules/scratchpad.lua)

Scratchpad for jotting down random notes or reminders. I use this for short-lived notes throughout the day. I usually don't have more than 5-10 lines in it at a time. A keybinding brings up a chooser where you can enter a single line, which is appended to the scratchpad file. The contents of the file can be seen by clicking the menubar icon. Clicking on a line in the menu will copy the line to the clipboard. Ctrl-clicking on a line in the menubar will remove it from the file.

### [songs](.hammerspoon/modules/songs.lua)

Controls for playback of songs in Spotify and iTunes. Also provides bindings for rating songs via [`track`](bin/track), a script that keeps song information in a sqlite database.

### [timer](.hammerspoon/modules/timer.lua)

Provides timers on demand. A keybinding brings up a chooser that lets you type a time (in minutes) and/or a short message. When the time's up, a notification with sound will pop up, and display the message.

Parsing the chooser string is very simple: if the first word is a number, the timer will be set for that many minutes. The rest of the string (if anything) is used as a subtitle for the notification. (Default time is 5 minutes.)

For example:

* `Eggs are done` - 5 minute timer, notifies "Eggs are done"
* `20 Wake up!` - 20 minute timer, notifies "Wake up!"
* `12` - 12 minute timer, notifies generic Timer Expired message.

When a timer is active, it'll show up in the menubar. Click a timer to reset it (start countdown again), ctrl-click a timer to delete it.

### [weather](.hammerspoon/modules/weather.lua)

Menubar icon with current temp and weather. Click to show details. Uses [forecast.io](http://forecast.io) for data (which requires a (free) API key to use). Temperatures turn yellow to red as they get hotter (can be configured in the `config.lua` file). Weather alerts will appear at the top if they exist.

This module also requires that Hammerspoon be given Location Services access in System Settings.

### [wifi](.hammerspoon/modules/wifi.lua)

Notify when wifi network changes.

### [worktime](.hammerspoon/modules/worktime.lua)

Combination of Awareness and Pomodoro timers (mutually exclusive modes). Awareness will chime after 30 minutes of constant activity, and each 30 minutes thereafter with an additional chime. Pomodoro emulates a pomodoro timer, with a 25 minute work phase and 5 minute rest phase. Switch between the two modes by Ctrl-clicking the menubar icon. Clicking the icon pauses/starts the timers. Shift-clicking resets.
