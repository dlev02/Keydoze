# Keydoze design

The interface uses warm ivory in light appearance, layered charcoal green in dark appearance, and one sage/forest accent for selection and the main action. System typography, capsule duration choices, a fixed window, and a large countdown keep each state easy to read. Recovery stays visible while input is paused.

The setup artwork is a native SwiftUI drawing of a pause keycap and trackpad. The matching app icon is original ImageGen artwork; its source and exact prompt are in [Resources/Brand](../../Resources/Brand/ICON-PROMPT.md). The icon was inspected at small sizes and packaged with native macOS tools.

## References

Public product imagery was inspected on 6 September 2026:

- [Raycast](https://www.raycast.com/): dark panel hierarchy, fine boundaries, and a restrained selected row.
- [Craft](https://www.craft.do/): light surfaces, clear typography, and soft control depth.
- [CleanShot X](https://cleanshot.com/): compact status/recovery controls and a simple dimensional Dock icon.
- [Dropover](https://dropoverapp.com/): native light settings surfaces and focused selection color.

These informed general interface principles. Their artwork is not incorporated or redistributed. The references include light and dark product imagery, but do not establish both appearances for every product.

`light.png` and `dark.png` are captures of the actual Keydoze window. Debug simulation is used separately to inspect active, recovery, and failure states without blocking input.

## Final layout decisions

- The main window uses a continuous surface with standard Mac window controls and no visible title strip. Setup artwork and session headings provide additional drag regions.
- Content is 440 points wide with 32-point side margins and a 510-point content height. These are app-specific optical dimensions, not claimed platform constants.
- Setup and countdown are centered. Labels and instructions use leading alignment; the recovery group is centered with left-aligned text beside its symbols.
- Scope choices are 65 points high. Duration choices have a 32-point button within a 40-point capsule track. Primary actions are approximately 42 points high.
- Scope and duration form one group; a larger gap separates them from Start. Permission help appears only on request. Offline/privacy details live in About and repository documentation.
- The ready screen retains one concise, clickable coverage limit. Active states show the scope, time until input returns, and one recovery instruction. Only safe development previews include the small preview label.

## Motion

SwiftUI uses short, non-bouncing transitions: a 240 ms selection spring, a 280 ms screen fade with a 6-point entrance offset, and an 180 ms numeric countdown transition. The duration selection capsule moves between choices with matched geometry. Selected input artwork shifts only 4 points. Native glass buttons retain system interaction feedback.

Animations do not delay engine actions or recovery. The countdown ring follows the actual session progress. Reduce Motion disables the custom transitions, rolling digits, and artwork displacement; no repeating decorative animation is used.

## Naming and completion

The product is **Keydoze**: one word, capital K. Source modules use Keydoze and KeydozeCore; the historical bundle identifier stays unchanged for development permission continuity. The completion screen has one action, Clean again. Quitting uses the standard window close button or Command-Q, avoiding an ambiguous Done action that would terminate the app.
