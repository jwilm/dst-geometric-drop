-- repository = https://github.com/jwilm/dst-geometric-drop
name = "Geometric Drop"
description = "Drop items aligned to the grid with a visual placer"
author = "Chaosmonkey"
version = "0.2"
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

-- Option 1. [unimplemented] Toggle visual drop indicator
-- Option 2. Toggle grid spacing (1 tile (4 units), half tile, quarter tile)
-- Option 3. [unimplemented] Default grid spacing and offset
-- Option 4. Grid Spacing Offset (will optionally add 0.5 to the position)
configuration_options = {
    AddConfig("Toggle alignment offset", "CYCLE_OFFSET_KEY", keylist, "KEY_T", "Toggle between aligning on (eg. tile) centers or corners."),
    AddConfig("Change resolution", "CYCLE_RESOLUTION_KEY", keylist, "KEY_G", "Cycle between 1/5, 1/4, 1/2, and full tile spacing."),
    AddConfig("Reset defaults", "RESTORE_DEFAULTS_KEY", keylist, "KEY_EQUALS", "Disables the offset and restores spacing to 1/4 tile."),
    AddConfig("Toggle placer visibility", "TOGGLE_PLACERS_KEY", keylist, "KEY_MINUS", "Enables and disables placers being visible while holding an item")
}
