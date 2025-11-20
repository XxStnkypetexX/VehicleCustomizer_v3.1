# VehicleCustomizer_v3.1
Lua Script for Lexis.
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
