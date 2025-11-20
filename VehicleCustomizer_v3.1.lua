--[[
    Vehicle Customizer v3.1  •  Lexis Mod Menu (GTA V Enhanced)
    -----------------------------------------------------------
    Drop this file into:  Lexis/scripts
    Then reload scripts in the menu.

    Author : StinkyPete ;)
    Script : All-in-one vehicle customization hub for Lexis

    Feature Log / Changelog
    -----------------------
    v1.0 - Initial release
        - Max Upgrade
        - Repair & Clean
        - Basic paint + neon presets

    v1.2 - Individual Parts submenu
        - Per-part options (spoilers, bumpers, hood, fenders, etc.)
        - Up to 25 options per part

    v1.3 - Wheels overhaul
        - Single “Wheels” entry
        - Wheel Utilities submenu
        - Wheel type selector incl. F1 wheels

    v1.4 - Paint system upgrade
        - Grouped paint presets (Metallic, Matte, Metals & Chrome, Favorites & Combos)
        - Custom Color editor for Primary / Secondary / Pearlescent / Wheels

    v1.5 - Branding & UX
        - Startup message: “Vehicle Customizer loaded. Made by StinkyPete.”
        - Long-duration notify helper (~30 seconds on screen, where supported)

    v1.6 - Internal logging
        - Central log capturing all printF messages
        - “Show Last 10 Log Entries” button

    v1.7 - Tire smoke presets
        - Tire Smoke Presets submenu with multiple colors
        - Auto-enables tire smoke mod

    v1.8 - Vehicle Extras
        - Vehicle Extras submenu to toggle extras
        - “All Extras On / Off” helper

    v1.9 - Extras scanner
        - Scan Available Extras button
        - Extended range 0–20
        - Improved logging for All Extras

    v2.0 - On-screen log popup
        - Last 10 log entries can be shown in a long HUD notification

    v2.1 - Live Log HUD
        - Toggle that keeps the log popup refreshing until turned off

    v2.2 - Benny & F1 wheel presets
        - Benny Wheel Options submenu (Benny Style wheel type + up to 50 designs)
        - F1 Wheel Options submenu (F1 wheel type + up to 50 designs)

    v2.3 - In-game Feature Log popup
        - Button to show this changelog as a long HUD notification

    v2.4 - Plate Tools Upgrade
        - Lock Plate Text: preset plate text + auto-apply on vehicle enter (toggle)
        - Plate Text Editor: menu-based editor (cursor + char cycling) to change preset & apply

    v2.5 - Personalized welcome
        - Load message greets the current Lexis user by name (via lexis.username())

    v2.6 - Doors & Radio Fun
        - Door Controls submenu
        - Radio & Subwoofer submenu (radio loud outside your car)

    v2.6.1 - Easier Plate Editor
        - Click-to-set characters per position
        - Random plate generator
        - Old cursor editor moved to "Advanced Cursor Editor"

    v2.7 - Saved Build Slots
        - 3 build slots (mods only)
        - Save / Apply / Clear per slot
        - Applies Turbo, Tire Smoke & Xenon on build apply

    v2.8 - Show-Off Mode
        - Show-Off Now: doors/hood/trunk open, neon on, headlights on, radio loud
        - Auto Show-Off While Parked: auto flex when stopped, auto reset when driving

    v2.9 - Auto Upgrade on Enter
        - Automatically upgrade vehicle when you enter it
        - Modes: Performance Only or Fully (all mods)

    v3.0 - Paint & Color overhaul
        - New root submenu: "Paint & Color" (Random LSC Paint, Paint Presets, Custom Color)
        - Added "Pearlescent Combos" preset group
        - Added "Chameleon (Fake Flip)" preset group using strong pearlescent highlights
        - Ensured presets/custom colors fully apply by setting the vehicle mod kit before colours
        - Added Xenon headlight color support with presets under Paint & Color
        - Moved Neon Presets and Tire Smoke Presets into the Paint & Color submenu
    v3.1 - Last Vehicle Editor
        - Added "Last Vehicle Editor" root submenu (doors + radio) for your last vehicle
        - Automatically tracks the last vehicle you exit and lets you control its doors and radio
        - Background watcher remembers last exited vehicle even while you are on foot

]]--

--========================
-- Logging + helpers
--========================

local LOG = {
    entries     = {},
    max_entries = 100
}

local function log_push(msg)
    if #LOG.entries >= LOG.max_entries then
        table.remove(LOG.entries, 1)
    end
    LOG.entries[#LOG.entries + 1] = {
        time = os.time(),
        msg  = msg
    }
end

local function printF(msg)
    log_push(msg)
    if notify and notify.push then
        notify.push('Vehicle Customizer', msg)
    end
    if print then
        print(msg)
    end
end

local function y(ms)
    if util and util.yield then
        util.yield(ms)
    end
end

-- Long-duration notify helper (tries to keep msg up ~duration_ms ms)
local function long_notify(msg, duration_ms)
    duration_ms = duration_ms or 30000 -- default 30 seconds
    if notify and notify.push then
        local ok = pcall(function()
            -- Some menus support (title, message, duration_ms)
            notify.push('Vehicle Customizer', msg, duration_ms)
        end)
        if not ok then
            -- Fallback: basic notify without custom duration
            notify.push('Vehicle Customizer', msg)
        end
    elseif util and util.toast then
        util.toast(msg)
    else
        print(msg)
    end
end

--========================
-- Lexis username helper
--========================

local function get_lexis_username()
    -- Try lexis.username() if available
    if lexis and type(lexis.username) == 'function' then
        local ok, name = pcall(lexis.username)
        if ok and type(name) == 'string' and name ~= '' then
            return name
        end
    end

    -- Fallback if API not present or fails
    return 'driver'
end

local CLICK = 0
local root  = menu.root()  -- script root

-- live HUD flag
local log_hud_enabled = false

-- plate lock flag + preset text (max 8 chars for GTA plates)
local plate_lock_enabled = false
local PLATE_TEXT_PRESET  = "STINKY"  -- default; editable via Plate Tools

-- "Subwoofer" / outside radio mode
local subwoofer_enabled = false

-- Show-Off auto toggle
local showcase_auto_enabled = false

-- Auto Upgrade on Enter (v2.9)
local AUTO_UPGRADE_OFF  = 0
local AUTO_UPGRADE_PERF = 1
local AUTO_UPGRADE_FULL = 2

local auto_upgrade_mode = AUTO_UPGRADE_OFF

--========================
-- Natives we use
--========================

local HASH_SET_VEHICLE_MOD_KIT           = 0x1F2AA07F00B3217A
local HASH_GET_NUM_VEHICLE_MODS          = 0xE38E9162A2500646
local HASH_GET_VEHICLE_MOD               = 0x772960298DA26FDB
local HASH_SET_VEHICLE_MOD               = 0x6AF0636DDEDCB6DD
local HASH_TOGGLE_VEHICLE_MOD            = 0x2A1F4F37F95BAD08
local HASH_SET_VEHICLE_FIXED             = 0x115722B1B9C14C1C
local HASH_SET_VEHICLE_DIRT_LEVEL        = 0x79D3B596FE44EE8B
local HASH_SET_VEHICLE_COLOURS           = 0x4F1D4BE3A7F24601
local HASH_SET_VEHICLE_EXTRA_COLOURS     = 0x2036F561ADD12E33
local HASH_NEON_ENABLED                  = 0x2AA720E4287BF269
local HASH_NEON_COLOR                    = 0x8E0A582209A62695
local HASH_SET_VEHICLE_WHEEL_TYPE        = 0x487EB21CC7295BA1  -- wheel type
local HASH_SET_VEHICLE_TYRE_SMOKE_COLOR  = 0xB5BA80F839791C0F  -- tire smoke color
local HASH_DOES_EXTRA_EXIST              = 0x1262D55792428154  -- vehicle extras
local HASH_SET_VEHICLE_EXTRA             = 0x7EE3A3C5E4A40CC9  -- SetVehicleExtra(vehicle, extraId, disable)
local HASH_IS_VEHICLE_EXTRA_TURNED_ON    = 0xD2E6822DBFD6C8BD
local HASH_SET_VEHICLE_NUMBER_PLATE_TEXT = 0x95A88F0B409CDA47  -- SetVehicleNumberPlateText(vehicle, text)

-- Doors + radio natives (v2.6 fun stuff)
local HASH_SET_VEHICLE_DOOR_OPEN        = 0x7C65DAC73C35C862  -- SetVehicleDoorOpen(vehicle, doorIndex, loose, instantly)
local HASH_SET_VEHICLE_DOOR_SHUT        = 0x93D9BD300D7789E5  -- SetVehicleDoorShut(vehicle, doorIndex, closeInstantly)
local HASH_SET_VEHICLE_DOORS_SHUT       = 0x781B3D62BB013EF5  -- SetVehicleDoorsShut(vehicle, closeInstantly)

local HASH_SET_VEHICLE_RADIO_ENABLED    = 0x3B988190C0AA6C0B  -- SetVehicleRadioEnabled(vehicle, toggle)
local HASH_SET_VEHICLE_RADIO_LOUD       = 0xBB6F1CAEC68B0BCE  -- SetVehicleRadioLoud(vehicle, toggle)
local HASH_SET_VEH_RADIO_STATION        = 0x1B9C0099CB942AC6  -- SetVehRadioStation(vehicle, stationName)

-- Headlights + speed for Show-Off Mode
local HASH_SET_VEHICLE_LIGHTS           = 0x34E710FF01247C5A  -- SetVehicleLights(vehicle, state)
local HASH_GET_ENTITY_SPEED             = 0xD5037BA82E12416F  -- GetEntitySpeed(entity)
local HASH_SET_VEHICLE_XENON_LIGHTS_COLOR = 0xE41033B25D003A07  -- SetVehicleXenonLightsColor(vehicle, colorIndex)

--========================
-- Vehicle helpers
--========================

-- last vehicle tracker (v3.1)
last_vehicle = last_vehicle or 0  -- preserve across reloads if environment is reused

function remember_last_vehicle(veh)
    if veh and veh ~= 0 then
        last_vehicle = veh
    end
end

function get_last_vehicle()
    if last_vehicle and last_vehicle ~= 0 then
        return last_vehicle
    end

    -- Try to fall back to current vehicle if possible
    if players and players.me then
        local me = players.me()
        if me and me.exists and me.in_vehicle and me.vehicle ~= 0 then
            remember_last_vehicle(me.vehicle)
            return me.vehicle
        end
    end

    printF('No last vehicle saved yet. Get in and out of a vehicle first.')
    return nil
end

local function get_player_vehicle()
    if not players or not players.me then
        printF('Players API missing (update Lexis).')
        return nil
    end

    local me = players.me()
    if not me or not me.exists or not me.in_vehicle or me.vehicle == 0 then
        printF('You need to be in a vehicle.')
        return nil
    end

    remember_last_vehicle(me.vehicle)

    return me.vehicle
end

local function ensure_control(veh)
    if request and request.control then
        request.control(veh, true)
        y(50)
    end
end

--========================
-- Max upgrade logic
--========================

local max_mod_types = {
    0,  -- Spoilers
    1,  -- Front bumper
    2,  -- Rear bumper
    3,  -- Side skirts
    4,  -- Exhaust
    5,  -- Frame
    6,  -- Grille
    7,  -- Hood
    8,  -- Fender
    9,  -- Right fender
    10, -- Roof
    11, -- Engine
    12, -- Brakes
    13, -- Transmission
    15, -- Suspension
    16, -- Armor
    23, -- Wheels (front – used for most vehicles)
    24  -- Rear wheels (motorcycles / some vehicles, still used in max upgrade)
}

local function max_upgrade_current()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    for _, modType in ipairs(max_mod_types) do
        local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, modType)
        local count     = count_ret and count_ret.int or 0
        if count and count > 0 then
            invoker.call(HASH_SET_VEHICLE_MOD, veh, modType, count - 1, false)
            y(15)
        end
    end

    -- Turbo, tire smoke, xenon
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 18, true)
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 20, true) -- tire smoke
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 22, true)

    printF('Max upgrades applied to current vehicle.')
end

local performance_mod_types = {
    11, -- Engine
    12, -- Brakes
    13, -- Transmission
    15, -- Suspension
    16  -- Armor
}

local function performance_upgrade_current()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    for _, modType in ipairs(performance_mod_types) do
        local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, modType)
        local count     = count_ret and count_ret.int or 0
        if count and count > 0 then
            invoker.call(HASH_SET_VEHICLE_MOD, veh, modType, count - 1, false)
            y(15)
        end
    end

    -- Always make sure Turbo is on for performance mode
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 18, true)

    printF('Performance upgrades applied to current vehicle.')
end

--========================
-- Saved Build Slots (v2.7)
--========================

-- mods-only build slots (no paint/neon yet)
local saved_build_slots = {
    [1] = nil,
    [2] = nil,
    [3] = nil
}

local function save_build_to_slot(slot)
    local veh = get_player_vehicle()
    if not veh then return end

    if not saved_build_slots[slot] then
        saved_build_slots[slot] = {}
    end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    local mods = {}

    for _, modType in ipairs(max_mod_types) do
        local mod_ret = invoker.call(HASH_GET_VEHICLE_MOD, veh, modType)
        local mod_idx = mod_ret and mod_ret.int or -1
        mods[modType] = mod_idx
    end

    saved_build_slots[slot].mods = mods

    printF('Saved current build (mods) to Build Slot ' .. slot .. '.')
end

local function apply_build_from_slot(slot)
    local data = saved_build_slots[slot]
    if not data or not data.mods then
        printF('No build saved in Build Slot ' .. slot .. '.')
        return
    end

    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    for _, modType in ipairs(max_mod_types) do
        local saved_index = data.mods[modType]
        if saved_index and saved_index >= 0 then
            local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, modType)
            local count     = count_ret and count_ret.int or 0

            if count > 0 and saved_index < count then
                invoker.call(HASH_SET_VEHICLE_MOD, veh, modType, saved_index, false)
                y(15)
            end
        end
    end

    -- Always make sure Turbo / Tire Smoke / Xenon are ON when applying a build
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 18, true)
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 20, true)
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 22, true)

    printF('Applied build from Build Slot ' .. slot .. '.')
end

local function clear_build_slot(slot)
    saved_build_slots[slot] = nil
    printF('Cleared Build Slot ' .. slot .. '.')
end

--========================
-- Paint helpers
--========================

local function apply_paint(preset)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    local primary     = preset.primary     or 0
    local secondary   = preset.secondary   or primary
    local pearlescent = preset.pearlescent or primary
    local wheels      = preset.wheels      or primary

    invoker.call(HASH_SET_VEHICLE_COLOURS,       veh, primary, secondary)
    invoker.call(HASH_SET_VEHICLE_EXTRA_COLOURS, veh, pearlescent, wheels)

    printF('Applied paint preset: ' .. (preset.name or 'Unknown'))
end

--========================
-- Neon helpers
--========================

local function apply_neon(r, g, b)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    for i = 0, 3 do
        invoker.call(HASH_NEON_ENABLED, veh, i, true)
    end

    invoker.call(HASH_NEON_COLOR, veh, r, g, b)
    printF(string.format('Neon color set to RGB(%d, %d, %d)', r, g, b))
end

-- Make sure neon is enabled on all sides without touching color (for Show-Off Mode)
local function ensure_neon_on_current()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    for i = 0, 3 do
        invoker.call(HASH_NEON_ENABLED, veh, i, true)
    end
end

--========================
-- Tire smoke helpers
--========================

local function apply_tire_smoke(r, g, b)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    -- make sure tire smoke mod is turned on
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 20, true)
    invoker.call(HASH_SET_VEHICLE_TYRE_SMOKE_COLOR, veh, r, g, b)

    printF(string.format('Tire smoke color set to RGB(%d, %d, %d)', r, g, b))
end

--========================
-- Vehicle Extras helpers
--========================

local MAX_EXTRA_ID = 20  -- scan & toggles 0–20

local function extra_exists(veh, extraId)
    local ret = invoker.call(HASH_DOES_EXTRA_EXIST, veh, extraId)
    return ret and ret.bool
end

local function set_extra_state(extraId, enabled)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    if not extra_exists(veh, extraId) then
        printF('Extra ' .. extraId .. ' does not exist on this vehicle.')
        return
    end

    -- SET_VEHICLE_EXTRA(vehicle, extraId, disable)
    local disable = not enabled
    invoker.call(HASH_SET_VEHICLE_EXTRA, veh, extraId, disable)

    if enabled then
        printF('Extra ' .. extraId .. ' enabled.')
    else
        printF('Extra ' .. extraId .. ' disabled.')
    end
end

local function toggle_extra(extraId)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    if not extra_exists(veh, extraId) then
        printF('Extra ' .. extraId .. ' does not exist on this vehicle.')
        return
    end

    local state_ret = invoker.call(HASH_IS_VEHICLE_EXTRA_TURNED_ON, veh, extraId)
    local is_on     = state_ret and state_ret.bool

    set_extra_state(extraId, not is_on)
end

local function set_all_extras(enabled)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    local changed = 0

    for extraId = 0, MAX_EXTRA_ID do
        if extra_exists(veh, extraId) then
            local disable = not enabled
            invoker.call(HASH_SET_VEHICLE_EXTRA, veh, extraId, disable)
            changed = changed + 1
        end
    end

    if changed == 0 then
        printF('No extras found in range 0–' .. MAX_EXTRA_ID .. ' on this vehicle.')
        return
    end

    if enabled then
        printF('All available extras enabled (' .. changed .. ' extras).')
    else
        printF('All available extras disabled (' .. changed .. ' extras).')
    end
end

local function scan_extras()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    local found = {}

    for extraId = 0, MAX_EXTRA_ID do
        local ret = invoker.call(HASH_DOES_EXTRA_EXIST, veh, extraId)
        if ret and ret.bool then
            table.insert(found, tostring(extraId))
        end
    end

    if #found == 0 then
        printF('This vehicle has no extras in range 0–' .. MAX_EXTRA_ID .. '.')
    else
        printF('Vehicle extras found: ' .. table.concat(found, ', '))
    end
end

--========================
-- Repair / clean helpers
--========================

local function fix_vehicle()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    invoker.call(HASH_SET_VEHICLE_FIXED, veh)
    invoker.call(HASH_SET_VEHICLE_DIRT_LEVEL, veh, 0.0)

    printF('Vehicle repaired & cleaned.')
end

--========================
-- Door helpers (v2.6)
--========================

-- door indices:
-- 0 = Front Left, 1 = Front Right
-- 2 = Rear Left,  3 = Rear Right
-- 4 = Hood,       5 = Trunk

local function open_all_doors()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    for door = 0, 5 do
        -- SET_VEHICLE_DOOR_OPEN(vehicle, doorIndex, loose, instantly)
        invoker.call(HASH_SET_VEHICLE_DOOR_OPEN, veh, door, false, true)
    end

    printF('All doors, hood and trunk opened.')
end

local function close_all_doors()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    -- SET_VEHICLE_DOORS_SHUT(vehicle, closeInstantly)
    invoker.call(HASH_SET_VEHICLE_DOORS_SHUT, veh, true)
    printF('All doors, hood and trunk closed.')
end

local function open_named_door(doorIndex, label)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_DOOR_OPEN, veh, doorIndex, false, true)
    printF(label .. ' opened.')
end

local function shut_named_door(doorIndex, label)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    -- SET_VEHICLE_DOOR_SHUT(vehicle, doorIndex, closeInstantly)
    invoker.call(HASH_SET_VEHICLE_DOOR_SHUT, veh, doorIndex, true)
    printF(label .. ' closed.')
end

--========================
-- Last Vehicle door helpers (v3.1)
--========================

function open_all_doors_last()
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)

    for door = 0, 5 do
        invoker.call(HASH_SET_VEHICLE_DOOR_OPEN, veh, door, false, true)
    end

    printF('All doors, hood and trunk opened on last vehicle.')
end

function close_all_doors_last()
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)

    invoker.call(HASH_SET_VEHICLE_DOORS_SHUT, veh, true)
    printF('All doors, hood and trunk closed on last vehicle.')
end

function open_named_door_last(doorIndex, label)
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_DOOR_OPEN, veh, doorIndex, false, true)
    printF(label .. ' opened on last vehicle.')
end

function shut_named_door_last(doorIndex, label)
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_DOOR_SHUT, veh, doorIndex, true)
    printF(label .. ' closed on last vehicle.')
end

--========================
-- Radio / Subwoofer helpers (v2.6)
--========================

local function radio_on()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    -- Turn radio on for this vehicle
    invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, true)

    if subwoofer_enabled then
        -- Make radio loud outside the car
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, true)
    end

    printF('Vehicle radio turned ON.')
end

local function radio_off()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    -- Turn radio off for this vehicle
    invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, false)
    if subwoofer_enabled then
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, false)
    end
    printF('Vehicle radio turned OFF.')
end

local function toggle_subwoofer_mode()
    subwoofer_enabled = not subwoofer_enabled

    local veh = get_player_vehicle()
    if veh then
        ensure_control(veh)
        -- Make sure radio is on when we enable subwoofer mode
        invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, true)
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, subwoofer_enabled)
    end

    if subwoofer_enabled then
        printF('Subwoofer / outside radio mode ENABLED (radio will be loud outside your car).')
    else
        printF('Subwoofer / outside radio mode DISABLED (radio back to normal).')
    end
end

local function set_radio_station(station_name, pretty_label)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    -- Force radio on and set station
    invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, true)
    invoker.call(HASH_SET_VEH_RADIO_STATION, veh, station_name)

    if subwoofer_enabled then
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, true)
    end

    printF('Radio set to ' .. pretty_label .. '.')
end

--========================
-- Last Vehicle Radio helpers (v3.1)
--========================

function radio_on_last()
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, true)

    if subwoofer_enabled then
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, true)
    end

    printF('Last vehicle radio turned ON.')
end

function radio_off_last()
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, false)

    if subwoofer_enabled then
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, false)
    end

    printF('Last vehicle radio turned OFF.')
end

function set_radio_station_last(station_name, pretty_label)
    local veh = get_last_vehicle()
    if not veh then return end

    ensure_control(veh)

    invoker.call(HASH_SET_VEHICLE_RADIO_ENABLED, veh, true)
    invoker.call(HASH_SET_VEH_RADIO_STATION, veh, station_name)

    if subwoofer_enabled then
        invoker.call(HASH_SET_VEHICLE_RADIO_LOUD, veh, true)
    end

    printF('Last vehicle radio set to ' .. pretty_label .. '.')
end

--========================
-- Headlight helper (Show-Off)
--========================

local function set_headlights_forced(on)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    -- state values differ per doc, but 2 generally "forces on" and 0 back to normal
    local state = on and 2 or 0
    invoker.call(HASH_SET_VEHICLE_LIGHTS, veh, state)
end

--========================
-- Headlight (Xenon) Color helpers
--========================

local function ensure_xenon_enabled(veh)
    if not veh then return end
    ensure_control(veh)
    -- 22 = Xenon headlights mod
    invoker.call(HASH_TOGGLE_VEHICLE_MOD, veh, 22, true)
end

local function set_headlight_color(color_id, label)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    -- turn xenons on so color actually shows
    ensure_xenon_enabled(veh)

    -- -1 = reset to default (game stock), 0–12 = xenon colors
    invoker.call(HASH_SET_VEHICLE_XENON_LIGHTS_COLOR, veh, color_id)

    if label then
        printF('Headlight color set to ' .. label .. ' (ID ' .. color_id .. ').')
    else
        printF('Headlight color ID ' .. color_id .. ' applied.')
    end
end

--========================
-- Random paint (uses math.random)
--========================

local function random_paint()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    -- make sure the vehicle has a mod kit
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    -- seed RNG and pick random colours
    local t = os.time()
    math.randomseed(t % 2147483647)

    local primary   = math.random(0, 160)
    local secondary = math.random(0, 160)
    local pearl     = math.random(0, 160)
    local wheels    = math.random(0, 160)

    invoker.call(HASH_SET_VEHICLE_COLOURS,       veh, primary, secondary)
    invoker.call(HASH_SET_VEHICLE_EXTRA_COLOURS, veh, pearl, wheels)

    printF(string.format(
        'Random paint applied (P:%d S:%d Pearl:%d Wheels:%d)',
        primary, secondary, pearl, wheels
    ))
end

--========================
-- Grouped paint presets
--========================

local paint_groups = {
    {
        name = 'Metallic',
        presets = {
            { name = 'Metallic Black',            primary = 0,   secondary = 0,   pearlescent = 0,   wheels = 0   },
            { name = 'Metallic Graphite',         primary = 1,   secondary = 1,   pearlescent = 1,   wheels = 1   },
            { name = 'Metallic Steel Grey',       primary = 3,   secondary = 3,   pearlescent = 3,   wheels = 3   },
            { name = 'Metallic Silver',           primary = 4,   secondary = 4,   pearlescent = 4,   wheels = 4   },
            { name = 'Metallic Bluish Silver',    primary = 5,   secondary = 5,   pearlescent = 5,   wheels = 5   },
            { name = 'Metallic Red',              primary = 27,  secondary = 27,  pearlescent = 27,  wheels = 27  },
            { name = 'Metallic Torino Red',       primary = 28,  secondary = 28,  pearlescent = 28,  wheels = 28  },
            { name = 'Metallic Lava Red',         primary = 150, secondary = 150, pearlescent = 150, wheels = 150 },
            { name = 'Metallic Racing Green',     primary = 50,  secondary = 50,  pearlescent = 50,  wheels = 50  },
            { name = 'Metallic Sea Green',        primary = 51,  secondary = 51,  pearlescent = 51,  wheels = 51  },
            { name = 'Metallic Surf Blue',        primary = 68,  secondary = 68,  pearlescent = 68,  wheels = 68  },
            { name = 'Metallic Ultra Blue',       primary = 73,  secondary = 73,  pearlescent = 73,  wheels = 73  },
            { name = 'Metallic Midnight Blue',    primary = 61,  secondary = 61,  pearlescent = 61,  wheels = 61  },
            { name = 'Metallic Bright Purple',    primary = 71,  secondary = 71,  pearlescent = 71,  wheels = 71  }
        }
    },
    {
        name = 'Matte',
        presets = {
            { name = 'Matte Black',               primary = 12,  secondary = 12,  pearlescent = 12,  wheels = 12  },
            { name = 'Matte Dark Grey',           primary = 13,  secondary = 13,  pearlescent = 13,  wheels = 13  },
            { name = 'Matte Light Grey',          primary = 14,  secondary = 14,  pearlescent = 14,  wheels = 14  },
            { name = 'Matte White',               primary = 131, secondary = 131, pearlescent = 131, wheels = 131 },
            { name = 'Matte Red',                 primary = 39,  secondary = 39,  pearlescent = 39,  wheels = 39  },
            { name = 'Matte Dark Red',            primary = 40,  secondary = 40,  pearlescent = 40,  wheels = 40  },
            { name = 'Matte Orange',              primary = 41,  secondary = 41,  pearlescent = 41,  wheels = 41  },
            { name = 'Matte Yellow',              primary = 42,  secondary = 42,  pearlescent = 42,  wheels = 42  },
            { name = 'Matte Lime Green',          primary = 55,  secondary = 55,  pearlescent = 55,  wheels = 55  },
            { name = 'Matte Blue',                primary = 83,  secondary = 83,  pearlescent = 83,  wheels = 83  },
            { name = 'Matte Midnight Blue',       primary = 84,  secondary = 84,  pearlescent = 84,  wheels = 84  },
            { name = 'Matte Dark Purple',         primary = 148, secondary = 148, pearlescent = 148, wheels = 148 }
        }
    },
    {
        name = 'Metals & Chrome',
        presets = {
            { name = 'Brushed Steel',             primary = 117, secondary = 117, pearlescent = 117, wheels = 117 },
            { name = 'Brushed Black Steel',       primary = 118, secondary = 118, pearlescent = 118, wheels = 118 },
            { name = 'Brushed Aluminum',          primary = 119, secondary = 119, pearlescent = 119, wheels = 119 },
            { name = 'Full Chrome',               primary = 120, secondary = 120, pearlescent = 120, wheels = 120 },
            { name = 'Pure Gold',                 primary = 158, secondary = 158, pearlescent = 158, wheels = 158 },
            { name = 'Brushed Gold',              primary = 159, secondary = 159, pearlescent = 159, wheels = 159 }
        }
    },
    {
        name = 'Favorites & Combos',
        presets = {
            { name = 'Street Black & Red',        primary = 0,   secondary = 27,  pearlescent = 27,  wheels = 0   },
            { name = 'Ice White Luxury',          primary = 111, secondary = 111, pearlescent = 111, wheels = 0   },
            { name = 'Midnight Blue Classic',     primary = 141, secondary = 141, pearlescent = 141, wheels = 0   },
            { name = 'Chrome & Ice White',        primary = 120, secondary = 120, pearlescent = 120, wheels = 111 },
            { name = 'Chrome Everything',         primary = 120, secondary = 120, pearlescent = 120, wheels = 120 },
            { name = 'Mafia Black (Pearl White)', primary = 0,   secondary = 0,   pearlescent = 111, wheels = 0   },
            { name = 'Nardo-ish Grey',            primary = 5,   secondary = 5,   pearlescent = 5,   wheels = 0   }
        }

    },
    {
        name = 'Pearlescent Combos',
        presets = {
            { name = 'Black with Ice Pearl',        primary = 0,   secondary = 0,   pearlescent = 111, wheels = 0   },
            { name = 'Red with Yellow Pearl',       primary = 27,  secondary = 27,  pearlescent = 89,  wheels = 27  },
            { name = 'Blue with Purple Pearl',      primary = 64,  secondary = 64,  pearlescent = 71,  wheels = 64  },
            { name = 'Sea Green with Gold Pearl',   primary = 51,  secondary = 51,  pearlescent = 158, wheels = 51  },
            { name = 'Midnight with Diamond Pearl', primary = 61,  secondary = 61,  pearlescent = 111, wheels = 0   }
        }
    },
    {
        name = 'Chameleon (Fake Flip)',
        presets = {
            -- Stronger, more obvious flip-style combos
            { name = 'Teal / Purple Flip',          primary = 55,  secondary = 145, pearlescent = 145, wheels = 145 },
            { name = 'Blue / Green Flip',           primary = 64,  secondary = 55,  pearlescent = 118, wheels = 64  },
            { name = 'Orange / Red Flip',           primary = 41,  secondary = 27,  pearlescent = 150, wheels = 27  },
            { name = 'Gold / Green Flip',           primary = 158, secondary = 55,  pearlescent = 92,  wheels = 158 },
            { name = 'Purple / Blue Flip',          primary = 71,  secondary = 64,  pearlescent = 73,  wheels = 71  },
            { name = 'Oil Slick Flip',              primary = 0,   secondary = 145, pearlescent = 73,  wheels = 145 },
            { name = 'Toxic Green Flip',            primary = 55,  secondary = 92,  pearlescent = 118, wheels = 55  },
            { name = 'Rose Gold Flip',              primary = 159, secondary = 27,  pearlescent = 111, wheels = 159 },
            { name = 'Midnight Rainbow Flip',       primary = 61,  secondary = 71,  pearlescent = 120, wheels = 71  },
            { name = 'Ice vs Fire Flip',            primary = 27,  secondary = 111, pearlescent = 73,  wheels = 27  },
            { name = 'Lime / Purple Flip',          primary = 55,  secondary = 148, pearlescent = 71,  wheels = 148 },
            { name = 'Copper / Teal Flip',          primary = 88,  secondary = 64,  pearlescent = 92,  wheels = 88  },
            { name = 'Magenta / Cyan Flip',         primary = 135, secondary = 64,  pearlescent = 118, wheels = 135 }
        }
    }
}


--========================
-- Neon presets
--========================

local neon_presets = {
    { name = 'Neon White',   r = 222, g = 222, b = 255 },
    { name = 'Neon Blue',    r =   2, g =  21, b = 255 },
    { name = 'Neon Mint',    r =   0, g = 255, b = 140 },
    { name = 'Neon Yellow',  r = 255, g = 255, b =   0 },
    { name = 'Neon Red',     r = 255, g =   1, b =   1 },
    { name = 'Neon Purple',  r =  35, g =   1, b = 255 }
}

--========================
-- Tire Smoke presets
--========================

local tire_smoke_presets = {
    { name = 'White',       r = 254, g = 254, b = 254 },
    { name = 'Black',       r =   0, g =   0, b =   0 },
    { name = 'Red',         r = 244, g =  65, b =  65 },
    { name = 'Orange',      r = 244, g = 167, b =  66 },
    { name = 'Yellow',      r = 244, g = 244, b =  66 },
    { name = 'Green',       r =  65, g = 244, b =  65 },
    { name = 'Blue',        r =  65, g =  65, b = 244 },
    { name = 'Purple',      r = 163, g =  65, b = 244 },
    { name = 'Pink',        r = 244, g =  65, b = 163 },
    { name = 'Police Mix',  r =  50, g =  70, b = 255 }
}

--========================
-- Headlight (Xenon) Color presets
--========================

local xenon_colors = {
    { name = 'Reset to Default', id = -1 },
    { name = 'White',            id = 0  },
    { name = 'Blue',             id = 1  },
    { name = 'Electric Blue',    id = 2  },
    { name = 'Mint Green',       id = 3  },
    { name = 'Lime Green',       id = 4  },
    { name = 'Yellow',           id = 5  },
    { name = 'Golden Shower',    id = 6  },
    { name = 'Orange',           id = 7  },
    { name = 'Red',              id = 8  },
    { name = 'Pony Pink',        id = 9  },
    { name = 'Hot Pink',         id = 10 },
    { name = 'Purple',           id = 11 },
    { name = 'Blacklight',       id = 12 }
}

--========================
-- Custom color editor (per-channel ID control)
--========================

local CUSTOM_MIN, CUSTOM_MAX = 0, 160
local custom_color = {
    primary     = 0,
    secondary   = 0,
    pearlescent = 0,
    wheels      = 0
}

local function clamp_colour(v)
    if v < CUSTOM_MIN then v = CUSTOM_MIN end
    if v > CUSTOM_MAX then v = CUSTOM_MAX end
    return v
end

local function apply_custom_color()
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    local p  = clamp_colour(custom_color.primary)
    local s  = clamp_colour(custom_color.secondary)
    local pe = clamp_colour(custom_color.pearlescent)
    local w  = clamp_colour(custom_color.wheels)

    invoker.call(HASH_SET_VEHICLE_COLOURS,       veh, p, s)
    invoker.call(HASH_SET_VEHICLE_EXTRA_COLOURS, veh, pe, w)

    printF(string.format(
        'Custom Color applied (P:%d S:%d Pearl:%d Wheels:%d)',
        p, s, pe, w
    ))
end

local function adjust_custom(channel, delta)
    local old = custom_color[channel] or 0
    local new = clamp_colour(old + delta)
    custom_color[channel] = new
    apply_custom_color()
    local label = channel:gsub('^%l', string.upper)
    printF(label .. ' set to ' .. new)
end

local function random_custom_channel(channel)
    local t = os.time()
    math.randomseed(t % 2147483647)
    local new = math.random(CUSTOM_MIN, CUSTOM_MAX)
    custom_color[channel] = new
    apply_custom_color()
    local label = channel:gsub('^%l', string.upper)
    printF(label .. ' randomly set to ' .. new)
end

local function reset_custom_channel(channel)
    custom_color[channel] = 0
    apply_custom_color()
    local label = channel:gsub('^%l', string.upper)
    printF(label .. ' reset to 0')
end

local function random_custom_all()
    local t = os.time()
    math.randomseed(t % 2147483647)

    custom_color.primary     = math.random(CUSTOM_MIN, CUSTOM_MAX)
    custom_color.secondary   = math.random(CUSTOM_MIN, CUSTOM_MAX)
    custom_color.pearlescent = math.random(CUSTOM_MIN, CUSTOM_MAX)
    custom_color.wheels      = math.random(CUSTOM_MIN, CUSTOM_MAX)

    apply_custom_color()
end

local function reset_custom_all()
    custom_color.primary     = 0
    custom_color.secondary   = 0
    custom_color.pearlescent = 0
    custom_color.wheels      = 0
    apply_custom_color()
end

--========================
-- Individual parts (list-based)
--========================

local indiv_mods = {
    { name = 'Spoiler',       id = 0 },
    { name = 'Front Bumper',  id = 1 },
    { name = 'Rear Bumper',   id = 2 },
    { name = 'Side Skirts',   id = 3 },
    { name = 'Exhaust',       id = 4 },
    { name = 'Frame',         id = 5 },
    { name = 'Grille',        id = 6 },
    { name = 'Hood',          id = 7 },
    { name = 'Left Fender',   id = 8 },
    { name = 'Right Fender',  id = 9 },
    { name = 'Roof',          id = 10 },
    { name = 'Engine',        id = 11 },
    { name = 'Brakes',        id = 12 },
    { name = 'Transmission',  id = 13 },
    { name = 'Suspension',    id = 15 },
    { name = 'Armor',         id = 16 },
    { name = 'Wheels',        id = 23 }   -- single wheels entry
}

local current_mod_index = {}
local MAX_OPTIONS_PER_PART = 25

local function set_mod_stock(entry)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD, veh, entry.id, -1, false)
    current_mod_index[entry.id] = -1

    printF(entry.name .. ' set to stock.')
end

local function set_mod_option(entry, mod_index)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, entry.id)
    local count     = count_ret and count_ret.int or 0

    if not count or count == 0 then
        printF('This vehicle has no options for ' .. entry.name .. '.')
        return
    end

    if mod_index >= count then
        printF(string.format(
            '%s option %d not available (this vehicle only has %d).',
            entry.name, mod_index + 1, count
        ))
        return
    end

    invoker.call(HASH_SET_VEHICLE_MOD, veh, entry.id, mod_index, false)
    current_mod_index[entry.id] = mod_index

    printF(string.format('%s set to option %d.', entry.name, mod_index + 1))
end

--========================
-- Wheel type (Sport / Offroad / F1 / Benny / etc.)
--========================

local wheel_types = {
    { name = 'Sport',            id = 0 },
    { name = 'Muscle',           id = 1 },
    { name = 'Lowrider',         id = 2 },
    { name = 'SUV',              id = 3 },
    { name = 'Offroad',          id = 4 },
    { name = 'Tuner',            id = 5 },
    { name = 'Bike/Truck',       id = 6 }, -- depends on vehicle
    { name = 'High End',         id = 7 },
    { name = "Benny's Original", id = 8 }, -- Benny's Original wheel category
    { name = "Benny's Bespoke",  id = 9 }, -- Benny's Bespoke wheel category
    { name = 'F1 (Open Wheel)',  id = 10 } -- F1 wheel category
}

local function set_wheel_type(entry)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)

    invoker.call(HASH_SET_VEHICLE_WHEEL_TYPE, veh, entry.id)
    printF('Wheel type set to ' .. entry.name .. ' (ID ' .. entry.id .. ').')
end

-- Force wheel color to gold (Pure Gold)
local GOLD_WHEEL_COLOR_ID = 158 -- Pure Gold from Metals & Chrome group

local function force_wheels_gold(veh)
    if not veh then return end
    ensure_control(veh)
    -- This native sets pearlescent + wheel color; here we just make both Pure Gold
    invoker.call(HASH_SET_VEHICLE_EXTRA_COLOURS, veh, GOLD_WHEEL_COLOR_ID, GOLD_WHEEL_COLOR_ID)
    printF('Wheel color forced to Pure Gold (ID ' .. GOLD_WHEEL_COLOR_ID .. ').')
end

-- Benny Original wheel setter (modType 23, wheel type 8)
local function set_benny_original_wheel(option_index)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    -- force Benny Original wheel type
    invoker.call(HASH_SET_VEHICLE_WHEEL_TYPE, veh, 8)

    local modType   = 23 -- front wheels
    local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, modType)
    local count     = count_ret and count_ret.int or 0

    if not count or count == 0 then
        printF('This vehicle has no Benny Original wheels available.')
        return
    end

    if option_index >= count then
        printF(string.format(
            'Benny Original wheel %d not available (this vehicle only has %d options).',
            option_index + 1, count
        ))
        return
    end

    invoker.call(HASH_SET_VEHICLE_MOD, veh, modType, option_index, false)

    -- Force wheel color to gold every time we apply a Benny wheel
    force_wheels_gold(veh)

    printF(string.format(
        'Benny Original wheel set to option %d (wheel color forced to Pure Gold).',
        option_index + 1
    ))
end

-- Benny Bespoke wheel setter (modType 23, wheel type 9)
local function set_benny_bespoke_wheel(option_index)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    -- force Benny Bespoke wheel type
    invoker.call(HASH_SET_VEHICLE_WHEEL_TYPE, veh, 9)

    local modType   = 23 -- front wheels
    local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, modType)
    local count     = count_ret and count_ret.int or 0

    if not count or count == 0 then
        printF('This vehicle has no Benny Bespoke wheels available.')
        return
    end

    if option_index >= count then
        printF(string.format(
            'Benny Bespoke wheel %d not available (this vehicle only has %d options).',
            option_index + 1, count
        ))
        return
    end

    invoker.call(HASH_SET_VEHICLE_MOD, veh, modType, option_index, false)

    -- Force wheel color to gold every time we apply a Benny wheel
    force_wheels_gold(veh)

    printF(string.format(
        'Benny Bespoke wheel set to option %d (wheel color forced to Pure Gold).',
        option_index + 1
    ))
end

-- F1-specific wheel setter (modType 23, wheel type 10)
local function set_f1_wheel(option_index)
    local veh = get_player_vehicle()
    if not veh then return end

    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_MOD_KIT, veh, 0)

    -- force F1 wheel type
    invoker.call(HASH_SET_VEHICLE_WHEEL_TYPE, veh, 10)

    local modType   = 23 -- front wheels
    local count_ret = invoker.call(HASH_GET_NUM_VEHICLE_MODS, veh, modType)
    local count     = count_ret and count_ret.int or 0

    if not count or count == 0 then
        printF('This vehicle has no F1 wheels available.')
        return
    end

    if option_index >= count then
        printF(string.format(
            'F1 wheel %d not available (this vehicle only has %d options).',
            option_index + 1, count
        ))
        return
    end

    invoker.call(HASH_SET_VEHICLE_MOD, veh, modType, option_index, false)
    printF(string.format('F1 wheel set to option %d.', option_index + 1))
end

--========================
-- Plate text helpers (Lock Plate Text feature + menu editor)
--========================

local function set_plate_text_on_vehicle(veh)
    if not veh then return end
    ensure_control(veh)
    invoker.call(HASH_SET_VEHICLE_NUMBER_PLATE_TEXT, veh, PLATE_TEXT_PRESET)
    printF('Plate text set to "' .. PLATE_TEXT_PRESET .. '".')
end

local function set_plate_text_on_current()
    local veh = get_player_vehicle()
    if not veh then return end
    set_plate_text_on_vehicle(veh)
end

-- ---- Menu-based plate editor state ----
local MAX_PLATE_LEN = 8
local plate_charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
local plate_chars   = {}
for i = 1, #plate_charset do
    plate_chars[i] = plate_charset:sub(i, i)
end

local plate_cursor = 1  -- 1..MAX_PLATE_LEN

local function trim_right_spaces(s)
    return (s:gsub("%s+$", ""))
end

local function get_char_index(ch)
    for i, c in ipairs(plate_chars) do
        if c == ch then return i end
    end
    return 1
end

local function get_plate_char(text, pos)
    if pos > #text then return " " end
    local ch = text:sub(pos, pos)
    if ch == "" then ch = " " end
    return ch
end

local function set_plate_char(text, pos, ch)
    local len = #text
    if pos > len then
        text = text .. string.rep(" ", pos - len)
    end
    return text:sub(1, pos - 1) .. ch .. text:sub(pos + 1)
end

local function cycle_plate_char(delta)
    local text = PLATE_TEXT_PRESET or ""
    local ch   = get_plate_char(text, plate_cursor)
    local idx  = get_char_index(ch)

    local max = #plate_chars
    idx = idx + delta
    while idx < 1 do idx = idx + max end
    while idx > max do idx = idx - max end

    local newch = plate_chars[idx]
    text = set_plate_char(text, plate_cursor, newch)
    PLATE_TEXT_PRESET = trim_right_spaces(text)

    printF(string.format(
        'Plate char at pos %d set to "%s" (plate now "%s").',
        plate_cursor, newch, PLATE_TEXT_PRESET
    ))
end

local function move_plate_cursor(delta)
    plate_cursor = plate_cursor + delta
    if plate_cursor < 1 then plate_cursor = 1 end
    if plate_cursor > MAX_PLATE_LEN then plate_cursor = MAX_PLATE_LEN end
    printF(string.format('Plate cursor moved to position %d.', plate_cursor))
end

local function clear_plate_text()
    PLATE_TEXT_PRESET = ""
    plate_cursor      = 1
    printF('Plate preset cleared.')
end

-- New: direct set + random plate (easier editor)
local function set_plate_char_direct(pos, ch)
    local text = PLATE_TEXT_PRESET or ""
    text = set_plate_char(text, pos, ch)
    PLATE_TEXT_PRESET = trim_right_spaces(text)
    plate_cursor = pos  -- keep cursor in sync

    local display = (ch == " ") and "[space]" or ch
    printF(string.format(
        'Plate char at pos %d set to "%s" (plate now "%s").',
        pos, display, PLATE_TEXT_PRESET
    ))
end

local function random_plate()
    local t = os.time()
    math.randomseed(t % 2147483647)

    local text = ""
    for i = 1, MAX_PLATE_LEN do
        -- ignore space when randomly generating
        local idx = math.random(1, #plate_chars - 1)
        text = text .. plate_chars[idx]
    end

    PLATE_TEXT_PRESET = text
    plate_cursor      = 1

    printF('Random plate preset: "' .. PLATE_TEXT_PRESET .. '".')
end

--========================
-- Log viewer
--========================

local function dump_log()
    if #LOG.entries == 0 then
        printF('Log is empty.')
        return
    end

    local start = #LOG.entries - 9
    if start < 1 then start = 1 end

    local count = #LOG.entries - start + 1
    printF('--- Last ' .. tostring(count) .. ' log entries ---')

    for i = start, #LOG.entries do
        local e  = LOG.entries[i]
        local ts = os.date('%H:%M:%S', e.time)
        if not ts then ts = '??:??:??' end
        printF(string.format('[%s] %s', ts, e.msg))
    end
end

-- On-screen popup for last 10 log entries
local function popup_log()
    if #LOG.entries == 0 then
        long_notify('Log is empty.', 8000)
        return
    end

    local start = #LOG.entries - 9
    if start < 1 then start = 1 end

    local lines = {}
    table.insert(lines, 'Last log entries:')

    for i = start, #LOG.entries do
        local e  = LOG.entries[i]
        local ts = os.date('%H:%M:%S', e.time) or '??:??:??'
        table.insert(lines, string.format('[%s] %s', ts, e.msg))
    end

    local msg = table.concat(lines, '\n')
    long_notify(msg, 25000)  -- ~25 seconds
end

-- Feature Log popup (shows changelog)
local function show_feature_log()
    local lines = {
        'Vehicle Customizer Feature Log:',
        'v1.0 - Initial release: Max Upgrade, Repair & Clean, basic paint and neon presets.',
        'v1.2 - Individual Parts submenu: per-part options (spoilers, bumpers, hood, fenders, etc.).',
        'v1.3 - Wheels overhaul: Wheels entry + Wheel Utilities + wheel type selector.',
        'v1.4 - Paint system upgrade: grouped presets + Custom Color editor.',
        'v1.5 - Branding & UX: startup message + long-duration notifications.',
        'v1.6 - Internal logging: central log + Last 10 Log Entries.',
        'v1.7 - Tire smoke presets: multiple colors, auto-enables tire smoke.',
        'v1.8 - Vehicle Extras: toggle extras + All Extras On/Off.',
        'v1.9 - Extras scanner: scan extras 0–20 with better logging.',
        'v2.0 - On-screen log popup: long HUD view of last 10 log entries.',
        'v2.1 - Live Log HUD: keeps log popup refreshed while enabled.',
        'v2.2 - Benny & F1 wheel presets: Benny/F1 wheel option submenus.',
        'v2.3 - Feature Log popup: this in-game changelog view.',
        'v2.4 - Plate Tools Upgrade: Lock Plate Text + menu Plate Text Editor.',
        'v2.5 - Personalized welcome: Load message greets current Lexis user by name.',
        'v2.6 - Doors & Radio Fun: Door Controls + Radio & Subwoofer (radio loud outside your car).',
        'v2.6.1 - Easier Plate Editor: click-to-set characters, random plate, advanced cursor editor submenu.',
        'v2.7 - Saved Build Slots: 3 slots for mods-only builds (with turbo/smoke/xenon on apply).',
        'v2.8 - Show-Off Mode: Show-Off Now + Auto Show-Off While Parked.'
    }
    local msg = table.concat(lines, '\n')
    long_notify(msg, 45000) -- ~45 seconds to read
end

--========================
-- Show-Off Mode helpers (v2.8)
--========================

-- one-shot "flex" (doors open, neon & lights on, radio loud)
local function showoff_now()
    open_all_doors()
    ensure_neon_on_current()
    set_headlights_forced(true)
    radio_on()
    printF('Show-Off Mode: doors open, neon on, headlights on, radio on.')
end

local function showoff_reset()
    close_all_doors()
    set_headlights_forced(false)
    radio_off()
    printF('Show-Off Mode reset: doors closed, lights normal, radio off.')
end

--========================
-- Background threads
--========================

-- Live HUD loop – keeps refreshing popup while log_hud_enabled == true
if util and util.create_thread then
    util.create_thread(function()
        while true do
            if log_hud_enabled then
                popup_log()
            end
            util.yield(8000) -- refresh every ~8s so it looks "permanent"
        end
    end)
else
    printF('Live Log HUD loop not available (util.create_thread missing).')
end

-- Plate lock watcher – auto-apply plate text when entering a new vehicle
if util and util.create_thread then
    util.create_thread(function()
        local lastVeh = 0
        while true do
            if plate_lock_enabled and players and players.me then
                local me = players.me()
                if me and me.exists and me.in_vehicle and me.vehicle ~= 0 then
                    local veh = me.vehicle
                    if veh ~= lastVeh then
                        lastVeh = veh
                        set_plate_text_on_vehicle(veh)
                    end
                else
                    lastVeh = 0
                end
            end
            util.yield(500) -- check twice a second
        end
    end)
else
    printF('Plate lock watcher not available (util.create_thread missing).')
end

-- Auto Upgrade on Enter watcher (v2.9)
if util and util.create_thread then
    util.create_thread(function()
        local lastVeh = 0

        while true do
            if auto_upgrade_mode ~= AUTO_UPGRADE_OFF and players and players.me then
                local me = players.me()
                if me and me.exists and me.in_vehicle and me.vehicle ~= 0 then
                    local veh = me.vehicle
                    if veh ~= lastVeh then
                        lastVeh = veh

                        if auto_upgrade_mode == AUTO_UPGRADE_PERF then
                            performance_upgrade_current()
                        elseif auto_upgrade_mode == AUTO_UPGRADE_FULL then
                            max_upgrade_current()
                        end
                    end
                else
                    lastVeh = 0
                end
            else
                lastVeh = 0
            end

            util.yield(500) -- check twice a second
        end
    end)
else
    printF('Auto Upgrade watcher not available (util.create_thread missing).')
end

-- Auto Show-Off While Parked watcher (v2.8)
if util and util.create_thread then
    util.create_thread(function()
        local is_showing_off = false

        while true do
            if showcase_auto_enabled and players and players.me then
                local me = players.me()
                local veh = (me and me.exists and me.in_vehicle and me.vehicle ~= 0) and me.vehicle or nil

                if veh then
                    ensure_control(veh)
                    local speed_ret = invoker.call(HASH_GET_ENTITY_SPEED, veh)
                    local speed     = speed_ret and (speed_ret.float or speed_ret.double or speed_ret.number) or 0.0

                    -- treat ~0 as parked; tweak threshold if needed
                    if speed < 0.5 then
                        if not is_showing_off then
                            showoff_now()
                            is_showing_off = true
                        end
                    else
                        if is_showing_off then
                            showoff_reset()
                            is_showing_off = false
                        end
                    end
                else
                    -- player not in vehicle; if we were in showoff state, just mark it off
                    is_showing_off = false
                end
            else
                -- Not enabled; make sure flag is off
                is_showing_off = false
            end

            util.yield(600) -- run about 1.5x per second
        end
    end)
else
    printF('Auto Show-Off loop not available (util.create_thread missing).')
end


-- Last Vehicle auto-tracker (v3.1)
if util and util.create_thread then
    util.create_thread(function()
        local last_seen_veh = 0
        local was_in_vehicle = false

        while true do
            if players and players.me then
                local me = players.me()
                if me and me.exists then
                    if me.in_vehicle and me.vehicle ~= 0 then
                        last_seen_veh = me.vehicle
                        was_in_vehicle = true
                    else
                        if was_in_vehicle and last_seen_veh ~= 0 then
                            remember_last_vehicle(last_seen_veh)
                            was_in_vehicle = false
                        end
                    end
                end
            end

            util.yield(500) -- check twice a second
        end
    end)
else
    printF('Last Vehicle auto-tracker not available (util.create_thread missing).')
end


--========================
-- Menu wiring (on root)
--========================

-- Core buttons grouped under Quick Actions
local quick_root = root:submenu('Quick Actions')

local btn_max = quick_root:button('Max Upgrade Current Vehicle')
btn_max:event(CLICK, function()
    max_upgrade_current()
end)

local btn_perf = quick_root:button('Performance Upgrade Current Vehicle')
btn_perf:event(CLICK, function()
    performance_upgrade_current()
end)

local btn_fix = quick_root:button('Repair & Clean Current Vehicle')
btn_fix:event(CLICK, function()
    fix_vehicle()
end)

local btn_showoff_quick = quick_root:button('Show-Off Now (Open, Neon, Radio Loud)')
btn_showoff_quick:event(CLICK, function()
    showoff_now()
end)

-- Auto Upgrade on Enter submenu (v2.9)
local auto_upgrade_root = root:submenu('Auto Upgrade on Enter')

local auto_off_btn = auto_upgrade_root:button('Auto Upgrade: Disabled')
auto_off_btn:event(CLICK, function()
    auto_upgrade_mode = AUTO_UPGRADE_OFF
    printF('Auto Upgrade on Enter disabled.')
end)

local auto_perf_btn = auto_upgrade_root:button('Auto Upgrade: Performance Only')
auto_perf_btn:event(CLICK, function()
    auto_upgrade_mode = AUTO_UPGRADE_PERF
    printF('Auto Upgrade on Enter set to PERFORMANCE ONLY (engine/brakes/trans/susp/armor + turbo).')
end)

local auto_full_btn = auto_upgrade_root:button('Auto Upgrade: Fully (All Mods)')
auto_full_btn:event(CLICK, function()
    auto_upgrade_mode = AUTO_UPGRADE_FULL
    printF('Auto Upgrade on Enter set to FULLY upgrade vehicle.')
end)

-- Saved Builds submenu (v2.7)
local builds_root = root:submenu('Saved Builds')

for slot = 1, 3 do
    local slot_sub = builds_root:submenu('Build Slot ' .. slot)

    local save_btn = slot_sub:button('Save Current Build to Slot ' .. slot)
    save_btn:event(CLICK, function()
        save_build_to_slot(slot)
    end)

    local apply_btn = slot_sub:button('Apply Build from Slot ' .. slot)
    apply_btn:event(CLICK, function()
        apply_build_from_slot(slot)
    end)

    local clear_btn = slot_sub:button('Clear Slot ' .. slot)
    clear_btn:event(CLICK, function()
        clear_build_slot(slot)
    end)
end

-- Door Controls submenu
local doors_root = root:submenu('Door Controls')

local btn_open_all = doors_root:button('Open All Doors / Hood / Trunk')
btn_open_all:event(CLICK, function()
    open_all_doors()
end)

local btn_close_all = doors_root:button('Close All Doors / Hood / Trunk')
btn_close_all:event(CLICK, function()
    close_all_doors()
end)

local btn_open_hood = doors_root:button('Open Hood')
btn_open_hood:event(CLICK, function()
    open_named_door(4, 'Hood')
end)

local btn_close_hood = doors_root:button('Close Hood')
btn_close_hood:event(CLICK, function()
    shut_named_door(4, 'Hood')
end)

local btn_open_trunk = doors_root:button('Open Trunk')
btn_open_trunk:event(CLICK, function()
    open_named_door(5, 'Trunk')
end)

local btn_close_trunk = doors_root:button('Close Trunk')
btn_close_trunk:event(CLICK, function()
    shut_named_door(5, 'Trunk')
end)

-- Radio & Subwoofer submenu
local radio_root = root:submenu('Radio & Subwoofer')

local btn_radio_on = radio_root:button('Radio ON (Vehicle)')
btn_radio_on:event(CLICK, function()
    radio_on()
end)

local btn_radio_off = radio_root:button('Radio OFF (Vehicle)')
btn_radio_off:event(CLICK, function()
    radio_off()
end)

local btn_subwoofer = radio_root:button('Toggle Subwoofer / Outside Radio Mode')
btn_subwoofer:event(CLICK, function()
    toggle_subwoofer_mode()
end)

local btn_station_pop = radio_root:button('Station: Non-Stop-Pop FM')
btn_station_pop:event(CLICK, function()
    set_radio_station('RADIO_02_POP', 'Non-Stop-Pop FM')
end)

local btn_station_rock = radio_root:button('Station: Los Santos Rock')
btn_station_rock:event(CLICK, function()
    set_radio_station('RADIO_01_CLASS_ROCK', 'Los Santos Rock Radio')
end)

local btn_station_hiphop = radio_root:button('Station: Radio Los Santos')
btn_station_hiphop:event(CLICK, function()
    set_radio_station('RADIO_03_HIPHOP_NEW', 'Radio Los Santos')
end)

-- Last Vehicle Editor submenu (v3.1)
last_root = root:submenu('Last Vehicle Editor')

-- Manual save, just in case the watcher is not running
last_root:button('Save Current Vehicle as Last'):event(CLICK, function()
    local veh = get_player_vehicle()
    if not veh then return end
    remember_last_vehicle(veh)
    printF('Current vehicle saved as last vehicle.')
end)

last_doors_root = last_root:submenu('Doors (Last Vehicle)')

last_doors_root:button('Open All Doors / Hood / Trunk (Last)'):event(CLICK, function()
    open_all_doors_last()
end)

last_doors_root:button('Close All Doors / Hood / Trunk (Last)'):event(CLICK, function()
    close_all_doors_last()
end)

last_doors_root:button('Open Hood (Last)'):event(CLICK, function()
    open_named_door_last(4, 'Hood')
end)

last_doors_root:button('Close Hood (Last)'):event(CLICK, function()
    shut_named_door_last(4, 'Hood')
end)

last_doors_root:button('Open Trunk (Last)'):event(CLICK, function()
    open_named_door_last(5, 'Trunk')
end)

last_doors_root:button('Close Trunk (Last)'):event(CLICK, function()
    shut_named_door_last(5, 'Trunk')
end)

last_radio_root = last_root:submenu('Radio (Last Vehicle)')

last_radio_root:button('Radio ON (Last Vehicle)'):event(CLICK, function()
    radio_on_last()
end)

last_radio_root:button('Radio OFF (Last Vehicle)'):event(CLICK, function()
    radio_off_last()
end)

last_radio_root:button('Station: Non-Stop-Pop FM (Last)'):event(CLICK, function()
    set_radio_station_last('RADIO_02_POP', 'Non-Stop-Pop FM')
end)

last_radio_root:button('Station: Los Santos Rock (Last)'):event(CLICK, function()
    set_radio_station_last('RADIO_01_CLASS_ROCK', 'Los Santos Rock Radio')
end)

last_radio_root:button('Station: Radio Los Santos (Last)'):event(CLICK, function()
    set_radio_station_last('RADIO_03_HIPHOP_NEW', 'Radio Los Santos')
end)

-- Show-Off Mode submenu (v2.8)
local showoff_root = root:submenu('Show-Off Mode')

local showoff_once_btn = showoff_root:button('Show-Off Now (Open, Neon, Radio Loud)')
showoff_once_btn:event(CLICK, function()
    showoff_now()
end)

local showoff_auto_btn = showoff_root:button('Toggle Auto Show-Off While Parked')
showoff_auto_btn:event(CLICK, function()
    showcase_auto_enabled = not showcase_auto_enabled
    if showcase_auto_enabled then
        printF('Auto Show-Off enabled: when you stop, the car will open up and flex.')
    else
        printF('Auto Show-Off disabled.')
    end
end)

-- Paint & Color root submenu
local paint_root = root:submenu('Paint & Color')

local rand_paint_btn = paint_root:button('Random LSC Paint')
rand_paint_btn:event(CLICK, function()
    random_paint()
end)

-- Paint presets (grouped)
local paint_sub = paint_root:submenu('Paint Presets')
for _, group in ipairs(paint_groups) do
    local group_sub = paint_sub:submenu(group.name)
    for _, preset in ipairs(group.presets) do
        local btn = group_sub:button(preset.name)
        btn:event(CLICK, function()
            apply_paint(preset)
        end)
    end
end

-- Custom Color menu
local custom_sub = paint_root:submenu('Custom Color')

local apply_custom_btn = custom_sub:button('Apply Custom Color Now')
apply_custom_btn:event(CLICK, function()
    apply_custom_color()
end)

local random_all_btn = custom_sub:button('Random All 0–160')
random_all_btn:event(CLICK, function()
    random_custom_all()
end)

local reset_all_btn = custom_sub:button('Reset All to 0')
reset_all_btn:event(CLICK, function()
    reset_custom_all()
end)

local custom_channels = {
    { key = 'primary',     label = 'Primary' },
    { key = 'secondary',   label = 'Secondary' },
    { key = 'pearlescent', label = 'Pearlescent' },
    { key = 'wheels',      label = 'Wheels' }
}

for _, ch in ipairs(custom_channels) do
    local ch_sub = custom_sub:submenu(ch.label)

    local minus10 = ch_sub:button('-10')
    minus10:event(CLICK, function()
        adjust_custom(ch.key, -10)
    end)

    local minus1 = ch_sub:button('-1')
    minus1:event(CLICK, function()
        adjust_custom(ch.key, -1)
    end)

    local plus1 = ch_sub:button('+1')
    plus1:event(CLICK, function()
        adjust_custom(ch.key, 1)
    end)

    local plus10 = ch_sub:button('+10')
    plus10:event(CLICK, function()
        adjust_custom(ch.key, 10)
    end)

    local rand_btn = ch_sub:button('Random 0–160')
    rand_btn:event(CLICK, function()
        random_custom_channel(ch.key)
    end)

    local reset_btn = ch_sub:button('Reset to 0')
    reset_btn:event(CLICK, function()
        reset_custom_channel(ch.key)
    end)
end

-- Neon presets
local neon_sub = paint_root:submenu('Neon Presets')
for _, preset in ipairs(neon_presets) do
    local btn = neon_sub:button(preset.name)
    btn:event(CLICK, function()
        apply_neon(preset.r, preset.g, preset.b)
    end)
end

-- Tire Smoke presets
local smoke_sub = paint_root:submenu('Tire Smoke Presets')
for _, preset in ipairs(tire_smoke_presets) do
    local btn = smoke_sub:button(preset.name)
    btn:event(CLICK, function()
        apply_tire_smoke(preset.r, preset.g, preset.b)
    end)
end

-- Headlight Color (Xenon)
local headlight_sub = paint_root:submenu('Headlight Color (Xenon)')
for _, col in ipairs(xenon_colors) do
    local btn = headlight_sub:button(col.name)
    btn:event(CLICK, function()
        set_headlight_color(col.id, col.name)
    end)
end

-- Vehicle Extras submenu
local extras_root = root:submenu('Vehicle Extras')

local btn_scan = extras_root:button('Scan Available Extras')
btn_scan:event(CLICK, function()
    scan_extras()
end)

local btn_all_on = extras_root:button('All Extras ON')
btn_all_on:event(CLICK, function()
    set_all_extras(true)
end)

local btn_all_off = extras_root:button('All Extras OFF')
btn_all_off:event(CLICK, function()
    set_all_extras(false)
end)

for extraId = 0, MAX_EXTRA_ID do
    local btn = extras_root:button('Toggle Extra ' .. extraId)
    btn:event(CLICK, function()
        toggle_extra(extraId)
    end)
end

-- Individual Parts submenu (all parts including Wheels + Wheel Utilities)
local indiv_root = root:submenu('Individual Parts')

for _, entry in ipairs(indiv_mods) do
    local part_sub = indiv_root:submenu(entry.name)

    local stock_btn = part_sub:button('Stock (No ' .. entry.name .. ')')
    stock_btn:event(CLICK, function()
        set_mod_stock(entry)
    end)

    for i = 0, MAX_OPTIONS_PER_PART - 1 do
        local label = string.format('Option %d', i + 1)
        local btn   = part_sub:button(label)
        btn:event(CLICK, function()
            set_mod_option(entry, i)
        end)
    end
end

-- Wheel Utilities inside Individual Parts
local wheel_utils = indiv_root:submenu('Wheel Utilities')

-- Wheel type picker
local wheel_type_sub = wheel_utils:submenu('Wheel Type')
for _, wt in ipairs(wheel_types) do
    local btn = wheel_type_sub:button(wt.name)
    btn:event(CLICK, function()
        set_wheel_type(wt)
    end)
end

-- Benny wheel name tables (from GTA Wiki)
local benny_bespoke_names = {
    "Chrome OG Hunnets",
    "Gold OG Hunnets",
    "Chrome Wires",
    "Gold Wires",
    "Chrome Spoked Out",
    "Gold Spoked Out",
    "Chrome Knock-Offs",
    "Gold Knock-Offs",
    "Chrome Bigger Worm",
    "Gold Bigger Worm",
    "Chrome Vintage Wire",
    "Gold Vintage Wire",
    "Chrome Classic Wire",
    "Gold Classic Wire",
    "Chrome Smoothie",
    "Gold Smoothie",
    "Chrome Classic Rod",
    "Gold Classic Rod",
    "Chrome Dollar",
    "Gold Dollar",
    "Chrome Mighty Star",
    "Gold Mighty Star",
    "Chrome Decadent Dish",
    "Gold Decadent Dish",
    "Chrome Razor Style",
    "Gold Razor Style",
    "Chrome Celtic Knot",
    "Gold Celtic Knot",
    "Chrome Warrior Dish",
    "Gold Warrior Dish",
    "Gold Big Dog Spokes",
}

local benny_original_names = {
    "OG Hunnets",
    "OG Hunnets (Chrome Lip)",
    "Knock-Offs",
    "Knock-Offs (Chrome Lip)",
    "Spoked Out",
    "Spoked Out (Chrome Lip)",
    "Vintage Wire",
    "Vintage Wire (Chrome Lip)",
    "Smoothie",
    "Smoothie (Chrome Lip)",
    "Smoothie (Solid Color)",
    "Rod Me Up",
    "Rod Me Up (Chrome Lip)",
    "Rod Me Up (Solid Color)",
    "Clean",
    "Lotta Chrome",
    "Spindles",
    "Viking",
    "Triple Spoke",
    "Pharohe",
    "Tiger Style",
    "Three Wheelin",
    "Big Bar",
    "Biohazard",
    "Waves",
    "Lick Lick",
    "Spiralizer",
    "Hypnotics",
    "Psycho-Delic",
    "Half Cut",
    "Super Electric",
}

-- Benny Wheel Options submenu
local benny_sub = wheel_utils:submenu('Benny Wheel Options')

-- Benny's Original wheels
local benny_original_sub = benny_sub:submenu("Benny's Original Wheels")

local benny_original_type_btn = benny_original_sub:button("Set Wheel Type to Benny's Original")
benny_original_type_btn:event(CLICK, function()
    local entry = { name = "Benny's Original", id = 8 }
    set_wheel_type(entry)
end)

-- Create a button for each Benny's Original wheel by name
for index, name in ipairs(benny_original_names) do
    local btn = benny_original_sub:button(name)
    btn:event(CLICK, function()
        -- Lua arrays are 1-based, vehicle mods are 0-based
        set_benny_original_wheel(index - 1)
    end)
end

-- Benny's Bespoke wheels (includes money sign rims etc.)
local benny_bespoke_sub = benny_sub:submenu("Benny's Bespoke Wheels")

local benny_bespoke_type_btn = benny_bespoke_sub:button("Set Wheel Type to Benny's Bespoke")
benny_bespoke_type_btn:event(CLICK, function()
    local entry = { name = "Benny's Bespoke", id = 9 }
    set_wheel_type(entry)
end)

-- Quick access money-sign rims
local chrome_dollar_btn = benny_bespoke_sub:button("Chrome Dollar ($)")
chrome_dollar_btn:event(CLICK, function()
    -- Chrome Dollar is index 18 in our bespoke list (0-based)
    set_benny_bespoke_wheel(18)
end)

local gold_dollar_btn = benny_bespoke_sub:button("Gold Dollar ($)")
gold_dollar_btn:event(CLICK, function()
    -- Gold Dollar is index 19 in our bespoke list (0-based)
    set_benny_bespoke_wheel(19)
end)

-- Create a button for each Benny's Bespoke wheel by name
for index, name in ipairs(benny_bespoke_names) do
    local btn = benny_bespoke_sub:button(name)
    btn:event(CLICK, function()
        -- Lua arrays are 1-based, vehicle mods are 0-based
        set_benny_bespoke_wheel(index - 1)
    end)
end

-- F1 Wheel Options submenu
local f1_sub = wheel_utils:submenu('F1 Wheel Options')

local f1_type_btn = f1_sub:button('Set Wheel Type to F1')
f1_type_btn:event(CLICK, function()
    local entry = { name = 'F1 (Open Wheel)', id = 10 }
    set_wheel_type(entry)
end)

for i = 0, 49 do -- up to 50 F1 wheel designs
    local label = string.format('F1 Option %d', i + 1)
    local btn   = f1_sub:button(label)
    btn:event(CLICK, function()
        set_f1_wheel(i)
    end)
end

-- Plate tools (Lock Plate Text + improved menu editor)
local plate_sub = root:submenu('Plate Tools')

local btn_plate_now = plate_sub:button('Apply Preset Plate to Current Vehicle')
btn_plate_now:event(CLICK, function()
    set_plate_text_on_current()
end)

local plate_editor = plate_sub:submenu('Plate Text Editor')

-- Basic info / actions
local plate_show = plate_editor:button('Show Current Plate Text')
plate_show:event(CLICK, function()
    local text = PLATE_TEXT_PRESET or ""
    printF('Current plate preset: "' .. text .. '" (cursor at pos ' .. plate_cursor .. ').')
end)

local random_plate_btn = plate_editor:button('Random Plate (A–Z / 0–9)')
random_plate_btn:event(CLICK, function()
    random_plate()
end)

local clear_btn = plate_editor:button('Clear Plate Text')
clear_btn:event(CLICK, function()
    clear_plate_text()
end)

local apply_btn = plate_editor:button('Apply Plate Preset to Current Vehicle')
apply_btn:event(CLICK, function()
    set_plate_text_on_current()
end)

-- New: Edit by Position (click to pick char)
local positions_root = plate_editor:submenu('Edit by Position (Click to Pick Char)')

for pos = 1, MAX_PLATE_LEN do
    local pos_sub = positions_root:submenu('Position ' .. pos)

    for _, ch in ipairs(plate_chars) do
        local label = (ch == " ") and '[Space]' or ch
        local btn   = pos_sub:button(label)

        btn:event(CLICK, function()
            set_plate_char_direct(pos, ch)
        end)
    end
end

-- Old cursor-based editor kept as "Advanced"
local advanced_sub = plate_editor:submenu('Advanced Cursor Editor')

local cursor_left = advanced_sub:button('Move Cursor Left')
cursor_left:event(CLICK, function()
    move_plate_cursor(-1)
end)

local cursor_right = advanced_sub:button('Move Cursor Right')
cursor_right:event(CLICK, function()
    move_plate_cursor(1)
end)

local char_up = advanced_sub:button('Cycle Char Up (A→Z,0→9,space)')
char_up:event(CLICK, function()
    cycle_plate_char(1)
end)

local char_down = advanced_sub:button('Cycle Char Down')
char_down:event(CLICK, function()
    cycle_plate_char(-1)
end)

local btn_plate_lock = plate_sub:button('Toggle Lock Plate Text (Auto Apply)')
btn_plate_lock:event(CLICK, function()
    plate_lock_enabled = not plate_lock_enabled
    if plate_lock_enabled then
        printF('Plate lock ENABLED. Any vehicle you enter will get plate "' .. PLATE_TEXT_PRESET .. '".')
    else
        printF('Plate lock DISABLED.')
    end
end)

-- Log and info controls grouped under Logs & Info

local logs_root = root:submenu('Logs & Info')

local btn_log_hud = logs_root:button('Toggle Live Log HUD (Stay On Screen)')
btn_log_hud:event(CLICK, function()
    log_hud_enabled = not log_hud_enabled
    if log_hud_enabled then
        printF('Live Log HUD enabled. Log popup will stay on screen until you toggle off.')
    else
        printF('Live Log HUD disabled.')
    end
end)


--========================
-- Startup message
--========================

local username = get_lexis_username()

long_notify('Welcome ' .. username .. '! Vehicle Customizer v3.1 loaded. Made by StinkyPete.', 30000)
printF('Vehicle Customizer v3.1 initialized for ' .. username .. '.')