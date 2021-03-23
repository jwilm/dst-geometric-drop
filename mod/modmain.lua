PrefabFiles = {
    "CirclePlacer",
}

Assets = {
    Asset("ANIM", "anim/circleplacer.zip")
}

-- -----------------------
-- Constants
-- -----------------------
local CIRCLE_PLACER = "circleplacer"

-- Drop resolution can be  1/8, 1/4, 1/2, or 1 tile (units are in 1/4 tile)
local DROP_RESOLUTION = {
    [0] = 0.50,
    [1] = 0.80,
    [2] = 1.0,
    [3] = 2.0,
    [4] = 4.0
}
local DROP_RESOLUTION_LENGTH = 5

-- Drop resolution selectors
local DROP_RESOLUTION_EIGTH = 0
local DROP_RESOLUTION_FIFTH = 1
local DROP_RESOLUTION_QUARTER = 2
local DROP_RESOLUTION_HALF = 3
local DROP_RESOLUTION_TILE = 4

-- The offsets are indexed by whether they are enabled. Offsets represent 1/2
-- of the drop resolution for each step.
local DROP_OFFSETS =  {
    [0] = { [0] = 0.0,  [1] = 0.0, [2] = 0.0, [3] = 0.0, [4] = 0.0},
    [1] = { [0] = 0.25, [1] = 0.4, [2] = 0.5, [3] = 1.0, [4] = 2.0 },
}
local DROP_OFFSETS_LENGTH = 2

-- Drop offset selectors
local DROP_OFFSET_DISABLED = 0
local DROP_OFFSET_ENABLED  = 1

-- -----------------------
-- Cached Globals
-- -----------------------
local SpawnPrefab = GLOBAL.SpawnPrefab
local TheInput = GLOBAL.TheInput
local BufferedAction = GLOBAL.BufferedAction
local SendRPCToServer = GLOBAL.SendRPCToServer
local ACTIONS = GLOBAL.ACTIONS
local CONTROL_FORCE_STACK = GLOBAL.CONTROL_FORCE_STACK
local CONTROL_FORCE_TRADE = GLOBAL.CONTROL_FORCE_TRADE
local CONTROL_FORCE_INSPECT = GLOBAL.CONTROL_FORCE_INSPECT
local CONTROL_SECONDARY = GLOBAL.CONTROL_SECONDARY
local RPC = GLOBAL.RPC
local ThePlayer
local TheWorld

-- -----------------------
-- Variables
-- -----------------------
local placersEnabled = GetModConfigData("PLACERS_START_VISIBLE")
local placersVisible = false
local defaultDropResolution = GetModConfigData("DEFAULT_DROP_RESOLUTION")
local defaultDropOffset = GetModConfigData("DEFAULT_DROP_OFFSET")
local dropResolution = defaultDropResolution
local dropOffset = defaultDropOffset

-- -----------------------
-- Implementation
-- -----------------------
local function GetKeyConfig(config)
    local key = GetModConfigData(config, true)
    if type(key) == "string" and GLOBAL:rawget(key) then
        key = GLOBAL[key]
    end
    return type(key) == "number" and key or -1
end

local CYCLE_OFFSET_KEY = GetKeyConfig("CYCLE_OFFSET_KEY", "KEY_LEFTBRACKET")
local CYCLE_RESOLUTION_KEY = GetKeyConfig("CYCLE_RESOLUTION_KEY", "KEY_RIGHTBRACKET")
local RESTORE_DEFAULTS_KEY = GetKeyConfig("RESTORE_DEFAULTS_KEY", "KEY_EQUALS")
local TOGGLE_PLACERS_KEY = GetKeyConfig("TOGGLE_PLACERS_KEY", "KEY_MINUS")

local function round(num)
    return math.floor(num + 0.5)
end

local function NewCirclePlacer(anim, scale)
    local placer = SpawnPrefab(CIRCLE_PLACER)
    placer.AnimState:PlayAnimation(anim, true)
    placer.Transform:SetScale(scale, scale, scale)
    placer:Hide()
    return placer
end

local CenterDropPlacer
local AdjacentDropPlacer

local function ShowPlacers()
    placersVisible = true
    CenterDropPlacer:Show()
    for i=0,7 do
        local placer = AdjacentDropPlacer[i]
        placer:Show()
    end
end

local function HidePlacers()
    placersVisible = false
    CenterDropPlacer:Hide()
    for i=0,7 do
        local placer = AdjacentDropPlacer[i]
        placer:Hide()
    end
end

local function InitializePlacers()
    CenterDropPlacer = NewCirclePlacer("on", 0.6)
    AdjacentDropPlacer = {
        [0] = NewCirclePlacer("off", 0.6),
        [1] = NewCirclePlacer("off", 0.6),
        [2] = NewCirclePlacer("off", 0.6),
        [3] = NewCirclePlacer("off", 0.6),
        [4] = NewCirclePlacer("off", 0.6),
        [5] = NewCirclePlacer("off", 0.6),
        [6] = NewCirclePlacer("off", 0.6),
        [7] = NewCirclePlacer("off", 0.6),
    }
end

local function AlignToGrid(pos)
	local x = pos.x
	local z = pos.z
	
    -- Lookup correct resolution and offset
    local resolution = DROP_RESOLUTION[dropResolution]
    local offset  = DROP_OFFSETS[dropOffset][dropResolution]

    -- Adjust coordinates based on resolution and offset
    pos.x = resolution * round((x + offset) / resolution) - offset
    pos.z = resolution * round((z + offset) / resolution) - offset

    return pos
end

local function UpdatePlacers()
    if not placersVisible then return end
    local center = AlignToGrid(TheInput:GetWorldPosition())

    local x = center.x
    local z = center.z
	
    local resolution = DROP_RESOLUTION[dropResolution]

    AdjacentDropPlacer[0].Transform:SetPosition(x - resolution, -0.1, z - resolution)
    AdjacentDropPlacer[1].Transform:SetPosition(x - resolution, -0.1, z             )
    AdjacentDropPlacer[2].Transform:SetPosition(x - resolution, -0.1, z + resolution)
    AdjacentDropPlacer[3].Transform:SetPosition(x             , -0.1, z - resolution)
    AdjacentDropPlacer[4].Transform:SetPosition(x             , -0.1, z + resolution)
    AdjacentDropPlacer[5].Transform:SetPosition(x + resolution, -0.1, z - resolution)
    AdjacentDropPlacer[6].Transform:SetPosition(x + resolution, -0.1, z             )
    AdjacentDropPlacer[7].Transform:SetPosition(x + resolution, -0.1, z + resolution)
    CenterDropPlacer.Transform:SetPosition(x, -0.1, z)
end

TheInput:AddKeyUpHandler(CYCLE_OFFSET_KEY, function ()
    dropOffset = math.fmod(dropOffset + 1, DROP_OFFSETS_LENGTH)
end)

TheInput:AddKeyUpHandler(CYCLE_RESOLUTION_KEY, function ()
    dropResolution = math.fmod(dropResolution + 1, DROP_RESOLUTION_LENGTH)
end)

TheInput:AddKeyUpHandler(RESTORE_DEFAULTS_KEY, function ()
    dropResolution = defaultDropResolution
    dropOffset = defaultDropOffset
end)

TheInput:AddKeyUpHandler(TOGGLE_PLACERS_KEY, function ()
    placersEnabled = not placersEnabled
    local activeItem = ThePlayer.replica.inventory:GetActiveItem()
    if activeItem and placersEnabled then
        ShowPlacers()
    elseif activeItem then
        HidePlacers()
    -- no else; placers will be shown next time there is an active item.
    end
end)

local function DropActiveItemOnGrid(pos, active_item)
    local playercontroller = ThePlayer.components.playercontroller

    pos = AlignToGrid(pos)

    local act = BufferedAction(ThePlayer, nil, ACTIONS.DROP, active_item, pos)
    if playercontroller.locomotor then
        act.options.wholestack = not TheInput:IsControlPressed(CONTROL_FORCE_STACK)
        act.preview_cb = function()
            SendRPCToServer(RPC.LeftClick, ACTIONS.DROP.code, pos.x, pos.z, nil, true, playercontroller:EncodeControlMods(), nil, act.action.mod_name)
        end
        playercontroller:DoAction(act)
    else
        SendRPCToServer(RPC.LeftClick, ACTIONS.DROP.code, pos.x, pos.z, nil, true, playercontroller:EncodeControlMods(), act.action.canforce, act.action.mod_name)
    end
end

AddComponentPostInit("playercontroller", function(self)
    ThePlayer = GLOBAL.ThePlayer
    TheWorld = GLOBAL.TheWorld
    InitializePlacers()

    local PlayerControllerGetLeftMouseAction = self.GetLeftMouseAction
    local active_item, force_inspecting, mouse_target
    local drop_action = BufferedAction(ThePlayer, nil, ACTIONS.DROP)
    self.GetLeftMouseAction = function(self)
        local act = PlayerControllerGetLeftMouseAction(self)
        if force_inspecting then return act end
        if active_item and mouse_target then
            act = drop_action
        end
        self.LMBaction = act
        return self.LMBaction
    end

    local function DoModifiedLeftClickAction(act)
        if act.action == ACTIONS.DROP then
            DropActiveItemOnGrid(TheInput:GetWorldPosition(), active_item)
            return true
        end
        return false
    end

    local PlayerControllerOnLeftClick = self.OnLeftClick
    self.OnLeftClick = function(self, down)
        if not down or TheInput:GetHUDEntityUnderMouse() or self:IsAOETargeting() or self.placer_recipe then
            return PlayerControllerOnLeftClick(self, down)
        end
        local act = self:GetLeftMouseAction()
        if act then
            if DoModifiedLeftClickAction(act) then return end
        end
        PlayerControllerOnLeftClick(self, down)
    end

    local PlayerControllerOnUpdate = self.OnUpdate
    local function InGame()
        return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
    end
    self.OnUpdate = function(self, dt)
        local next_active_item = ThePlayer.replica.inventory:GetActiveItem()
        force_inspecting = TheInput:IsControlPressed(CONTROL_FORCE_INSPECT)
        mouse_target = TheInput:GetWorldEntityUnderMouse()
        if not active_item and next_active_item and placersEnabled then
            ShowPlacers()
        elseif active_item and not next_active_item and placersVisible then
            HidePlacers()
        end
        active_item = next_active_item

        if InGame() then UpdatePlacers() end

        return PlayerControllerOnUpdate(self, dt)
    end

end)

local function DropItemFromSlot(slot, item, single_item)
    local inventory = ThePlayer.replica.inventory
    local inventoryitem = item.replica.inventoryitem
    if not single_item and not inventory:GetActiveItem()
      and inventoryitem:CanGoInContainer() and not inventoryitem:CanOnlyGoInPocket() then
        if slot.equipslot then
            inventory:TakeActiveItemFromEquipSlot(slot.equipslot)
        elseif slot.num then
            slot.container:TakeActiveItemFromAllOfSlot(slot.num)
        end
        DropActiveItemOnGrid(ThePlayer:GetPosition(), item)
    else
        inventory:DropItemFromInvTile(item, single_item)
    end
end

local function InvSlotPostInit(self)
    local InvSlotOnControl = self.OnControl
    self.OnControl = function(self, control, down)
        if down and control == CONTROL_SECONDARY and self.tile then
            local single_item = TheInput:IsControlPressed(CONTROL_FORCE_STACK)
            if TheInput:IsControlPressed(CONTROL_FORCE_TRADE) or single_item then
                DropItemFromSlot(self, self.tile.item, single_item)
                return true
            end
        end
        return InvSlotOnControl(self, control, down)
    end
end

AddClassPostConstruct("widgets/invslot", InvSlotPostInit)
AddClassPostConstruct("widgets/equipslot", InvSlotPostInit)