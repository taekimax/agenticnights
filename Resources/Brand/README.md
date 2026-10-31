# Moon artwork

- `agenticnights-moon-transparent-v1.png`: selected 1254 × 1254 RGBA master for the app icon and profile images. Transparent exterior and inner opening, antialiased edges.
- `agenticnights-moon-dark-v1.png`: original generated artwork, retained as the pixel source.
- `image-prompts-v1.txt`: exact prompt, generated with the built-in image_gen tool.
- `alpha-cleanup-v1.py`: pixel cleanup and preview generation; requires Pillow and NumPy. Run from any directory.

The crescent follows the existing moon menu-bar symbol. Platinum and silver dominate, with muted steel-blue and champagne reflections matching the password prompt palette.

The transparent master was extracted from the original artwork by the requested Terra low worker. Exterior glow and disconnected pixels were removed; partial-alpha edge colors were recovered from the dark background. Black, white, gray and 64px previews were inspected. The earlier generated transparent trials are not used.

`Scripts/build-icon.sh` packages the transparent master into the app's `AppIcon.icns`. The menu-bar symbol remains the monochrome system moon.
