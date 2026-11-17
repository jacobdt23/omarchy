-- Change the default Omarchy look'n'feel.

-- Frosted glass, subtle shadows, and rounded corners tailored from your previous setup
-- while letting Omarchy's active theme drive border colors.
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
  },

  decoration = {
    rounding = 10,
    active_opacity = 1.0,
    inactive_opacity = 0.94,

    shadow = {
      enabled = true,
      range = 14,
      render_power = 3,
      color = "rgba(00000066)",
    },

    blur = {
      enabled = true,
      size = 8,
      passes = 3,
      vibrancy = 0.18,
      new_optimizations = true,
      xray = false,
    },
  },

  render = {
    -- Keep compositing active on fullscreen windows on NVIDIA to avoid
    -- direct-scanout page-flip timeouts.
    direct_scanout = 0,
  },
})

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
