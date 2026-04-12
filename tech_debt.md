# Technical Debt

This file tracks known bugs, mathematical quirks, or engine-level limitations that are acceptable to ship with but should be revisited in the future for a comprehensive fix.

## Visual & Rendering

### Line2D Pixel Crushing (Whip/Glass Lash)
- **Status:** Known Issue
- **Description:** When the `Line2D` used for the weapon cords bends or curves rapidly, the inner edge of the arc "pinches." Because Godot is rasterizing this polygon with Nearest Neighbor filtering (`texture_filter = 1`), this pinching forces the renderer to mathematically drop a row of pixels to fit the mesh. For the Leather Whip, which has a 3-pixel-thick cord, dropping exactly the center physical pixel makes it look "squished," leaving only the top and bottom outlines touching.
- **Why it was deferred:** Fixing this requires either:
  1. Turning on Linear filtering (`texture_filter = 2`) which makes the cord look blurry in a pixel-art game.
  2. Writing a specialized multi-sample pixel-perfect UV vertex shader.
  3. Generating a custom mesh instead of using `Line2D`.
- **Current Mitigation:** The scales are mathematically consistent (`0.7` and `0.5`), keeping it as aligned as theoretically possible while maintaining sharpness.

## UI & Navigation

### Settings & Play Menu Focus (Keyboard/Controller Support)
- **Status:** Partially Fixed / Haunted
- **Description:** Keyboard and controller navigation in the Settings and Play menus is inconsistent. Issues include focus trapping in grids (Character Selection), broken directional logic on sliders (volume adjustment vs. tab switching), and visual focus indicator visibility. Explicit `focus_neighbor` paths proved brittle, and Godot's natural spatial navigation is prone to "ghosting" or trapping due to layout overlaps and dynamic scene instantiation.
- **Why it was deferred:** Resolving this definitively requires a full UI architecture review, potentially flattening the container hierarchy or implementing a custom FocusManager to handle state transitions (like escaping from sliders back to tabs) without breaking native control behavior.
- **Current Mitigation:** 
  1. Play Menu width was increased to minimize bounding box overlaps.
  2. Character grid buttons have themes manually assigned for visual feedback.
  3. Strict `_input` overrides catch `ui_cancel` (B/Escape) to facilitate navigation back to categories.
  
