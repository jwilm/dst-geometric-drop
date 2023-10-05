-- repository = https://github.com/jwilm/dst-geometric-drop
name = "Geometric Drop"
description = [[
Drop items aligned to the grid with a visual placer

Version 1.4.5

Restore quick dropping off grid using Shift+Control+Right Click inventory item.

Version 1.4

Grid Dropper: Pick a rotation point with Control + MODE. Rotate by holding Shift + MODE and moving the mouse.
Circle Dropper: Drop items in a circle. Activate with the MODE key. Select the center of the circle with Control+MODE

MODE key: Geo Drop `Mode` keybinding. Default: H
]]

author = "Chaosmonkey"
version = "1.4.5"
api_version_dst = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
all_clients_require_mod = false
client_only_mod = true

folder_name = folder_name or "geometric_drop"
if not folder_name:find("workshop-") then
    name = name.." [dev]"
end

local string = ""
local keys = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12","LAlt","RAlt","LCtrl","RCtrl","LShift","RShift","Tab","Capslock","Space","Minus","Equals","Backspace","Insert","Home","Delete","End","Pageup","Pagedown","Print","Scrollock","Pause","Period","Slash","Semicolon","LeftBracket","RightBracket","Backslash","Up","Down","Left","Right"}
local keylist = {}
for i = 1, #keys do
    keylist[i] = {description = keys[i], data = "KEY_"..string.upper(keys[i])}
end
keylist[#keylist + 1] = {description = "Disabled", data = false}

local function AddConfig(label, name, options, default, hover)
    return {label = label, name = name, options = options, default = default, hover = hover or ""}
end

local boolean = {{description = "Yes", data = true}, {description = "No", data = false}}
local resolution_options = {
    {description = "1/8 Tile", data = 0},
    {description = "1/5 Tile", data = 1},
    {description = "1/4 Tile", data = 2},
    {description = "1/2 Tile", data = 3},
    {description = "1 Tile",   data = 4},
}

local offset_options = {
    {description = "Normal", data = 0},
    {description = "Offset", data = 1},
}

local mode_options = {
    {description = "Grid",     data = "grid"},
    {description = "Circle",   data = "polar"},
    {description = "Disabled", data = "disabled"},
}

configuration_options = {
    -- Keys
    AddConfig("Toggle alignment offset",  "CYCLE_OFFSET_KEY",         keylist, "KEY_T",      "Toggle between aligning on (eg. tile) centers or corners"),
    AddConfig("Change resolution",        "CYCLE_RESOLUTION_KEY",     keylist, "KEY_G",      "Cycle between 1/5, 1/4, 1/2, and full tile spacing"),
    AddConfig("Reset defaults",           "RESTORE_DEFAULTS_KEY",     keylist, "KEY_EQUALS", "Disables the offset and restores spacing to 1/4 tile"),
    AddConfig("Toggle placer visibility", "TOGGLE_PLACERS_KEY",       keylist, "KEY_MINUS",  "Enables and disables placers being visible while holding an item"),
    AddConfig("Mode",                     "TOGGLE_ENABLED_KEY",       keylist, "KEY_H",      "Change mode between grid, circle, and disabled. Control+MODE sets origin. Shift+MODE rotates grid around origin."),

    -- Options
    AddConfig("Default visible placers", "PLACERS_START_VISIBLE",   boolean,            true,   "Toggle whether placers show up by default while holding an item"),
    AddConfig("Default grid spacing",    "DEFAULT_DROP_RESOLUTION", resolution_options, 2,      "Change which grid spacing is used upon entering game or using the Reset Defaults keybind"),
    AddConfig("Default offset grid",     "DEFAULT_DROP_OFFSET",     offset_options,     1,      "Change which grid spacing is used upon entering game or using the Reset Defaults keybind"),
    AddConfig("Default mode",            "DEFAULT_MODE",            mode_options,       "grid", "Select which dropper mode is enabled upon entering the game or using the Reset Defaults keybind"),
}
