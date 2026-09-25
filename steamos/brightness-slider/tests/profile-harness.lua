-- Loads the profile against a stub gamescope API. arg[1]: profile path;
-- arg[2]: "shipped" when gamescope already defines the Legion Go 2 profile.
local shipped = arg[2] == "shipped"
local valve = {pretty_name = "Valve"}
gamescope = {
    config = {known_displays = shipped and {lenovo_legiongo2_oled = valve} or {}},
    eotf = {gamma22 = "gamma22", pq = "pq"},
}
function info() end
function debug() end
dofile(arg[1])
local profile = gamescope.config.known_displays.lenovo_legiongo2_oled
if profile == valve then
    print("valve")
else
    print(profile.hdr.eotf, profile.matches({vendor = "SDC", product = 0x4301}))
end
