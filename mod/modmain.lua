if GLOBAL.TheNet:IsDedicated() then return end

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

local CenterDropPlacer
local AdjacentDropPlacer
local OriginPlacer

-- -----------------------
-- Shared
-- -----------------------

local function round(num)
    return math.floor(num + 0.5)
end

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
local TOGGLE_ENABLED_KEY = GetKeyConfig("TOGGLE_ENABLED_KEY", "KEY_H")
local CYCLE_PLACEMENT_MODE_KEY = GetKeyConfig("CYCLE_PLACEMENT_MODE_KEY", "KEY_V")
local PICK_POINT_KEY = GetKeyConfig("PICK_POINT_KEY", "KEY_C")

local function NewCirclePlacer(anim, scale)
    local placer = SpawnPrefab(CIRCLE_PLACER)
    placer.AnimState:PlayAnimation(anim, true)
    placer.Transform:SetScale(scale, scale, scale)
    placer:Hide()
    return placer
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
    OriginPlacer = NewCirclePlacer("on", 1.0)
end

function MightBeTyping()
    if (TheFrontEnd:GetActiveScreen() and TheFrontEnd:GetActiveScreen().name or ""):find("HUD") ~= nil then
        return false
    end

    return true
end

DefaultDropper = {}
GridDropper = {
    rotation = 0.0,
}
PolarDropper = {
    last_input = { r = 0, theta = 0, d_theta = 0 }
}
dropper = GridDropper

-- OriginManager provides a shared origin
local OriginManager = { origin = { x = 0, y = 0, z = 0 }}
function OriginManager:Reset()
    self.origin = { x = 0, y = 0, z = 0 }
    self:Update()
end

function OriginManager:Get()
    return self.origin
end

function OriginManager:Update()
    OriginPlacer.Transform:SetPosition(self.origin.x, -0.1, self.origin.z)
end

function OriginManager:Pick()
    self.origin = dropper:AlignToGrid(TheInput:GetWorldPosition())
    self:Update()
end

-- ----------------------------------------------------------------------------
-- Disabled Dropper
--
-- This is the "no alignment" dropper which is effectively the default Don't
-- Starve dropping experience. Ergo, it's called the DefaultDropper.
-- ----------------------------------------------------------------------------

function DefaultDropper:AlignToGrid(pos)
    return pos
end

function DefaultDropper:UpdatePlacers()
end

function DefaultDropper:ShowPlacers()
    placersVisible = true
end

function DefaultDropper:HidePlacers()
    placersVisible = false
    CenterDropPlacer:Hide()
    OriginPlacer:Hide()
    for i=0,7 do
        local placer = AdjacentDropPlacer[i]
        placer:Hide()
    end
end

function DefaultDropper:Reset()
end

function DefaultDropper:PickRotation()
end

function DefaultDropper:NextDropper()
    return GridDropper
end

-- ----------------------------------------------------------------------------
-- Grid Placement
-- ----------------------------------------------------------------------------

function Rotate(x, z, theta)
    local cost = math.cos(theta)
    local sint = math.sin(theta)

    local xprime = x * cost - z * sint
    local zprime = x * sint + z * cost

    return xprime, zprime
end

function GridDropper:AlignToGrid(pos)
    local x = pos.x
    local z = pos.z

    local origin = OriginManager:Get()

    x = x - origin.x
    z = z - origin.z

    x, z = Rotate(x, z, -self.rotation)

    -- Lookup correct resolution and offset
    local resolution = DROP_RESOLUTION[dropResolution]
    local offset  = DROP_OFFSETS[dropOffset][dropResolution]

    -- Adjust coordinates based on resolution and offset
    x =  (resolution * round((x + offset) / resolution) - offset)
    z =  (resolution * round((z + offset) / resolution) - offset)
    x, z = Rotate(x, z, self.rotation)

    pos.x = origin.x + x
    pos.z = origin.z + z

    return pos
end

function GridDropper:UpdatePlacers()
    if not placersVisible then return end
    local center = self:AlignToGrid(TheInput:GetWorldPosition())

    -- TODO: skip update when center and rotation haven't changed.

    local x = center.x
    local z = center.z

    local resolution = DROP_RESOLUTION[dropResolution]
    local x_offset, z_offset = resolution * math.cos(self.rotation), resolution * math.sin(self.rotation)

    AdjacentDropPlacer[0].Transform:SetPosition(x - x_offset - z_offset, -0.1, z - z_offset + x_offset)
    AdjacentDropPlacer[1].Transform:SetPosition(x - x_offset           , -0.1, z - z_offset           )
    AdjacentDropPlacer[2].Transform:SetPosition(x - x_offset + z_offset, -0.1, z - z_offset - x_offset)
    AdjacentDropPlacer[3].Transform:SetPosition(x + z_offset           , -0.1, z - x_offset)
    AdjacentDropPlacer[4].Transform:SetPosition(x - z_offset           , -0.1, z + x_offset)
    AdjacentDropPlacer[5].Transform:SetPosition(x + x_offset - z_offset, -0.1, z + z_offset + x_offset)
    AdjacentDropPlacer[6].Transform:SetPosition(x + x_offset           , -0.1, z + z_offset  )
    AdjacentDropPlacer[7].Transform:SetPosition(x + x_offset + z_offset, -0.1, z + z_offset - x_offset)

    CenterDropPlacer.Transform:SetPosition(     x           , -0.1, z           )
end

function GridDropper:ShowPlacers()
    placersVisible = true
    CenterDropPlacer:Show()
    OriginPlacer:Show()
    for i=0,7 do
        local placer = AdjacentDropPlacer[i]
        placer:Show()
    end
end

function GridDropper:HidePlacers()
    DefaultDropper:HidePlacers()
end

function GridDropper:Reset()
    self.rotation = 0.0
end

function GridDropper:PickRotation()
    local input = TheInput:GetWorldPosition()
    local origin = OriginManager:Get()
    local x = origin.x - input.x
    local z = origin.z - input.z
    self.rotation = math.atan2(-x, z)
    -- round rotation to nearest 1 degree increment.
    -- This rounding avoids the problem of "infinite" grids whereby every slight
    -- rotation results in dramatically different results from AlignToGrid since
    -- the rotations are relative to the world origin.
    local res = 1 * math.pi / 180.0
    self.rotation = round(self.rotation / res) * res

    ThePlayer.components.talker:Say("Geo Drop: Grid Angle is " .. round(self.rotation * 180.0 / math.pi) .. "°")
end

function GridDropper:NextDropper()
    return PolarDropper
end

-- ----------------------------------------------------------------------------
-- Polar Placement
-- ----------------------------------------------------------------------------

function PolarDropper:WorldToPolarAligned(pos)
    local x = pos.x
    local z = pos.z
    local origin = OriginManager:Get()

    -- Lookup correct resolution and offset
    local resolution = DROP_RESOLUTION[dropResolution]
    local offset  = DROP_OFFSETS[dropOffset][dropResolution]

    -- Step 1. Translate to (0, 0)
    x = x - origin.x
    z = z - origin.z

    -- Step 2. Compute specific Radius
    local r = math.sqrt(x * x + z * z)

    -- Step 3. Round Radius to nearest resolution
    r = resolution * round((r + offset) / resolution) - offset

    -- Step 4. Compute θ
    -- Note: DST's Lua version doesn't have the newer atan so we use the
    -- deprecated atan2.
    local theta = math.atan2(z, x)

    -- Step 5. Round to nearest angle step
    local circumference = 2 * math.pi * r
    local steps_at_r = round(circumference / resolution)
    local theta_step = 2 * math.pi / steps_at_r
    local theta_offset = (theta_step * dropOffset) / 2.0
    theta = theta_step * round((theta + theta_offset) / theta_step) - theta_offset

    return { r = r, theta = theta, d_theta = theta_step}
end

function PolarDropper:PolarToWorld(pol)
    x = pol.r * math.cos(pol.theta)
    z = pol.r * math.sin(pol.theta)

    local origin = OriginManager:Get()

    return {
        x = x + origin.x,
        z = z + origin.z,
    }
end

function PolarDropper:InputWorldPositionPolar()
    return self:WorldToPolarAligned(TheInput:GetWorldPosition())
end

function PolarDropper:AlignToGrid(pos)
    local pol = self:WorldToPolarAligned(pos)
    local new_pos = self:PolarToWorld(pol)
    pos.x = new_pos.x
    pos.z = new_pos.z

    return pos
end

function PolarDropper:UpdatePlacers()
    if not placersVisible then return end

    local center = self:InputWorldPositionPolar()
    -- early exit if location hasn't changed to avoid extra work
    if center.r == self.last_input.r and center.theta == self.last_input.theta and center.d_theta == self.last_input.d_theta then
        return
    end

    local d_theta = center.d_theta

    for index, i in pairs({[0] = -2, [1] = -1, [2] = 1, [3] = 2}) do
        local pol = {
            r = center.r,
            d_theta = d_theta,
            theta = center.theta + i * d_theta,
        }

        local pos = self:PolarToWorld(pol)
        AdjacentDropPlacer[index].Transform:SetPosition(pos.x, -0.1, pos.z)
    end

    center = self:PolarToWorld(center)
    CenterDropPlacer.Transform:SetPosition(center.x, -0.1, center.z)
end

function PolarDropper:ShowPlacers()
    placersVisible = true
    CenterDropPlacer:Show()
    OriginPlacer:Show()
    for i=0,3 do
        local placer = AdjacentDropPlacer[i]
        placer:Show()
    end
end

function PolarDropper:HidePlacers()
    DefaultDropper:HidePlacers()
end

function PolarDropper:Reset()
    -- Could reset to world origin but that's not useful.
end

function PolarDropper:PickRotation()
end

function PolarDropper:NextDropper()
    return DefaultDropper
end

-- ----------------------------------------------------------------------------
-- Key handling, common to all
-- ----------------------------------------------------------------------------

TheInput:AddKeyUpHandler(CYCLE_OFFSET_KEY, function ()
    if MightBeTyping() then return end
    dropOffset = math.fmod(dropOffset + 1, DROP_OFFSETS_LENGTH)
end)

TheInput:AddKeyUpHandler(CYCLE_RESOLUTION_KEY, function ()
    if MightBeTyping() then return end

    dropResolution = math.fmod(dropResolution + 1, DROP_RESOLUTION_LENGTH)
end)

TheInput:AddKeyUpHandler(RESTORE_DEFAULTS_KEY, function ()
    if MightBeTyping() then return end

    OriginManager:Reset()
    dropper:Reset()
    dropper:HidePlacers()
    dropper = GridDropper

    if placersEnabled then
        dropper:ShowPlacers()
    end

    dropResolution = defaultDropResolution
    dropOffset = defaultDropOffset
end)

TheInput:AddKeyUpHandler(TOGGLE_ENABLED_KEY, function ()
    if MightBeTyping() then return end

    if TheInput:IsControlPressed(CONTROL_FORCE_STACK) then
        OriginManager:Pick()
    elseif TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
        -- noop, this is handled by KeyDown to do faster roations
    else
        dropper:HidePlacers()
        dropper = dropper:NextDropper()
        dropper:ShowPlacers()
    end
end)

TheInput:AddKeyDownHandler(TOGGLE_ENABLED_KEY, function ()
    if MightBeTyping() then return end

    if TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
        dropper:PickRotation()
    end
end)

TheInput:AddKeyUpHandler(TOGGLE_PLACERS_KEY, function ()
    if MightBeTyping() then return end
    placersEnabled = not placersEnabled
    local activeItem = ThePlayer.replica.inventory:GetActiveItem()
    if activeItem and placersEnabled then
        dropper:ShowPlacers()
    elseif activeItem then
        dropper:HidePlacers()
    -- no else; placers will be shown next time there is an active item.
    end
end)

local function DropActiveItemOnGrid(pos, active_item)
    local playercontroller = ThePlayer.components.playercontroller

    pos = dropper:AlignToGrid(pos)

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
        if not act and active_item and mouse_target then
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
            dropper:ShowPlacers()
        elseif active_item and not next_active_item and placersVisible then
            dropper:HidePlacers()
        end
        active_item = next_active_item

        if InGame() then
            dropper:UpdatePlacers()
        end

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
