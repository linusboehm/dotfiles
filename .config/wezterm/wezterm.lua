-- logging, can be checked with <ctrl>+<shift>+L
-- wezterm.log_warn(string.format("%s", "some message"))

local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- local is_linux = function()
-- 	return wezterm.target_triple:find("linux") ~= nil
-- end
--
-- local is_darwin = function()
-- 	return wezterm.target_triple:find("darwin") ~= nil
-- end

local is_windows = function()
  return wezterm.target_triple:find("windows") ~= nil
end

-- ----------------------------------------------------
-- misc
-- ----------------------------------------------------

config.audible_bell = "Disabled"
config.max_fps = 120

-- ----------------------------------------------------
-- Appearance
-- ----------------------------------------------------

config.window_decorations = "RESIZE"
config.font = wezterm.font("Hack Nerd Font")
-- config.font = wezterm.font("JetBrains Mono")
-- config.font = wezterm.font("Maple Mono")
config.font_size = 10.0
-- config.color_scheme = "nightfox" -- set colorscheme
config.color_scheme = "Tokyo Night Moon" -- set colorscheme
config.window_background_opacity = 1.0
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.scrollback_lines = 10000
local color_scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]
config.automatically_reload_config = true

-- -- order for ansi and brights: 1 black, 2 red, 3 green, 4 yellow, 5 blue, 6 magenta, 7 cyan, 8 white
--   "ansi": [ ], -- ansi: normal colors
--   "background": -- background of terminal
--   "brights": [ ], -- brights: bright/bold colors
--   "cursor_bg": -- cursor color
--   "cursor_border": -- cursor border color
--   "cursor_fg": "#192330", -- text behind curor
--   "foreground": "#cdcecf", -- default text color
--   "indexed": [], -- empty
--   "selection_bg": -- text behind selection
--   "selection_fg": -- selection

-- ----------------------------------------------------
-- Hyperlinks
-- ----------------------------------------------------

-- Use the defaults as a base
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- make username/project paths clickable. this implies paths like the following are for github.
-- ( "nvim-treesitter/nvim-treesitter" | `wez/wezterm` | "wez/wezterm.git" )
table.insert(config.hyperlink_rules, {
  regex = [[["'`]{1}([\w\d]{1}[-\w\d]+)(/){1}([-\w\d]+\.?(?!hp*")[-\w\d]*)["'`]{1}]],
  format = "https://www.github.com/$1/$3",
})
table.insert(config.hyperlink_rules, {
  regex = "(\\bwww[.]{1}\\S+[.]{1}[\\/a-zA-Z0-9-]*)",
  format = "https:$0",
})

-- ----------------------------------------------------
-- mouse stuff
-- ----------------------------------------------------

-- copy and paste with right mouse button
local act = wezterm.action
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action_callback(function(window, pane)
      local has_selection = window:get_selection_text_for_pane(pane) ~= ""
      if has_selection then
        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act({ PasteFrom = "Clipboard" }), pane)
      end
    end),
  },
}

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local hostname = wezterm.hostname()
  -- wezterm.log_warn(string.format("%s, %s", hostname, color_scheme["brights"][2]))
  local title = tab.active_pane.title

  local tab_format = tab.is_active and { { Background = { Color = "#23425B" } } } or {}
  table.insert(tab_format, { Text = " " .. title .. " " })
  local c = tab.is_active and "brights" or "ansi"

  if string.find(title, "core[-]dev6") then
    table.insert(tab_format, 1, { Foreground = { Color = color_scheme[c][3] } })
  elseif string.find(title, "-dev%d+:") then
    table.insert(tab_format, 1, { Foreground = { Color = color_scheme[c][7] } })
  elseif string.find(title, "prod-") or string.find(title, "-prod%d+:") then
    table.insert(tab_format, 1, { Foreground = { Color = color_scheme[c][2] } })
  end
  return tab_format
end)

wezterm.on("update-status", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  wezterm.log_warn(pane:get_domain_name())
  if pane:get_domain_name() == [[WSL:Ubuntu]] then
    wezterm.log_warn("Ubuntu!!!")
    overrides.colors = { background = "#26092b" }
  end
  window:set_config_overrides(overrides)
end)

if is_windows() then
  -- ----------------------------------------------------
  -- WSL
  -- ----------------------------------------------------
  config.wsl_domains = {
    {
      -- The name of this specific domain.  Must be unique amonst all types
      -- of domain in the configuration file.
      name = "WSL:AlmaLinux-8",
      -- The name of the distribution.  This identifies the WSL distribution.
      -- It must match a distribution from `wsl -l -v` output
      distribution = "AlmaLinux-8",
      default_cwd = "~",
    },
    {
      -- The name of this specific domain.  Must be unique amonst all types
      -- of domain in the configuration file.
      name = "WSL:Ubuntu",
      -- The name of the distribution.  This identifies the WSL distribution.
      -- It must match a distribution from `wsl -l -v` output
      distribution = "Ubuntu",
      default_cwd = "~",
    },
  }
  config.default_domain = "WSL:AlmaLinux-8"
end

-- ----------------------------------------------------
-- keys
-- ----------------------------------------------------
config.keys = {
  -- This will create a new split and run your default program inside it
  {
    key = "|",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "h",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Left"),
  },
  -- {
  --   key = "l",
  --   mods = "CTRL|SHIFT",
  --   action = act.ActivatePaneDirection("Right"),
  -- },
  {
    key = "k",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "j",
    mods = "CTRL|SHIFT",
    action = act.ActivatePaneDirection("Down"),
  },
}

return config
