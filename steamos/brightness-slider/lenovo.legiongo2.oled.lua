-- legion-go-2 brightness-slider profile: https://github.com/Frankenleg/legion-go-2
--
-- Lenovo Legion Go 2 OLED (Samsung SDC AMS881KB01-0).
--
-- gamescope 3.16.23.6 ships no profile for this panel, so it trusts the EDID,
-- which advertises PQ. Game Mode then drives the panel with a PQ signal and
-- the panel ignores the backlight, so the Steam brightness slider does nothing.
-- Declaring a gamma 2.2 panel, as Valve's Steam Deck OLED profile does, keeps
-- the panel out of PQ and restores the slider.
-- Luminance values are the panel's EDID HDR static metadata.
--
-- gamescope 3.16.29 ships its own lenovo_legiongo2_oled profile with
-- content-driven HDR and a software backlight. System scripts run before user
-- scripts, and this one would replace it, so step aside when it is present.
if gamescope.config.known_displays.lenovo_legiongo2_oled then
    info("[lenovo_legiongo2_oled] gamescope ships a profile; skipping the user profile")
    return
end

gamescope.config.known_displays.lenovo_legiongo2_oled = {
    pretty_name = "Lenovo Legion Go 2 OLED",
    hdr = {
        supported = true,
        force_enabled = true,
        eotf = gamescope.eotf.gamma22,
        max_content_light_level = 1107,
        max_frame_average_luminance = 476,
        min_content_light_level = 0.0007
    },
    matches = function(display)
        -- The EDID model name is "AMS881KB01-0 " with a trailing space, so match
        -- the product code as Valve's profiles do. Log at info level so the
        -- match is visible in the journal.
        if display.vendor == "SDC" and display.product == 0x4301 then
            info("[lenovo_legiongo2_oled] Matched vendor: SDC product: 0x4301")
            return 5000
        end
        return -1
    end
}
debug("Registered Lenovo Legion Go 2 OLED as a known display")
