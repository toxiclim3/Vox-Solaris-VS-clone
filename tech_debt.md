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

### Camera Subpixel Moiré vs. Integer Jitter
- **Status:** Known Issue
- **Description:** Moving the camera causes a slight Moiré / shimmering effect on the background tilemap and sprite edges. This happens because the game uses `canvas_items` stretch mode and renders natively at screen resolution. When the float-based `Camera2D` moves, Godot's Nearest Neighbor filtering has to rasterize non-integer positions, causing sprite pixels to shift in width on the physical monitor.
- **Why it was deferred:** Fixing this requires forcing the camera rendering offset to an integer (which causes a violently noticeable 1-to-2 pixel jitter between the player sprite and background at high refresh rates like 144hz), or implementing a strict `SubViewport` architecture. However, utilizing a `SubViewport` inherently breaks our pristine infinitely-scaling MSDF text in the UI by locking scaling logic inside the viewport's low internal resolution. Furthermore, fractional Camera Zoom guarantees Moiré regardless of architecture when filtering is set to nearest. 
- **Current Mitigation:** The moiré is accepted as a necessary evil to retain flawlessly crisp UI scaling and smooth player motion.

## UI & Navigation

### Settings & Play Menu Focus (Keyboard/Controller Support)
- **Status:** Partially Fixed / Haunted
- **Description:** Keyboard and controller navigation in the Settings and Play menus is inconsistent. Issues include focus trapping in grids (Character Selection), broken directional logic on sliders (volume adjustment vs. tab switching), and visual focus indicator visibility. Explicit `focus_neighbor` paths proved brittle, and Godot's natural spatial navigation is prone to "ghosting" or trapping due to layout overlaps and dynamic scene instantiation.
- **Why it was deferred:** Resolving this definitively requires a full UI architecture review, potentially flattening the container hierarchy or implementing a custom FocusManager to handle state transitions (like escaping from sliders back to tabs) without breaking native control behavior.
- **Current Mitigation:** 
  1. Play Menu width was increased to minimize bounding box overlaps.
  2. Character grid buttons have themes manually assigned for visual feedback.
  3. Strict `_input` overrides catch `ui_cancel` (B/Escape) to facilitate navigation back to categories.

## Performance & Loading

### Scene Transition & Instantiation Hitches
- **Status:** Partially Optimized
- **Description:** Significant freezes (2s-4s) occur when transitioning between the Title Screen and the World. While bidirectional background preloading and lazy-loading for audio/textures have been implemented, the absolute scale of the `world.tscn` tree and its internal dependencies causes a bottleneck during the `instantiate()` phase, which always runs on the main thread in Godot 4.
- **Why it was deferred:** Resolving this requires a massive structural overhaul, such as partitioning the world into smaller chunks or implementing a dedicated loading state machine that spreads instantiation over multiple frames. Additionally, the first-time preloading of the world scene while in the menu can compete for I/O and CPU resources with the shader pre-warming process, occasionally making the initial run-start feel slower than subsequent ones.
- **Current Mitigation:** 
  1. **Bidirectional Preloading:** The Menu pre-loads the World and vice versa.
  2. **Lazy Assets:** Music and Level Backgrounds are loaded on-demand or background-cached.
  3. **UI LoD:** Heavy UI elements like the "How To Play" menu are loaded on-demand only.
