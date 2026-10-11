# RIFTSTRIKE — Godot 3D Android Prototype

This is a starter project for a real 3D first-person arena prototype. It uses only built-in Godot meshes and GDScript; no external assets are required.

## Open on Android

1. Install **Godot Engine 4 for Android** from the official page: https://godotengine.org/download/android/
2. Open Godot and grant file access when Android asks.
3. Extract `RIFTSTRIKE_Godot_3D_Prototype.zip` into a folder such as `Documents/RIFTSTRIKE`.
4. In Godot's Project Manager, import/open the extracted folder (the folder containing `project.godot`).
5. Open the project and press **Run Project** (triangle/play icon).
6. Use the left on-screen joystick to move, drag the right half of the screen to look, and use FIRE / RELOAD / DASH / PULSE.

## Important limitations

- This is an early 3D prototype with procedural primitive models, not a finished commercial-quality game.
- Bots are local test targets; online 5v5, matchmaking, player accounts, and authoritative servers are not implemented.
- The Godot Android editor is experimental and its UI can be awkward on a phone. Use the Compatibility renderer for broad device support.
- For a polished game, replace primitive geometry with properly licensed 3D models, textures, animations, sound, and optimized lighting.

## If you see an error

Check that you imported the folder containing `project.godot`, not the ZIP itself. If the editor reports a script error, send me the exact error text or a screenshot and I can fix the project.
