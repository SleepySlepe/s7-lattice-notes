# s7-lattice-notes

Small update payload for the live AI/editor files.

## Update Rules

Patchable files:

- `AI.lua`
- `Const.lua`
- `Util.lua`
- `SlepeAI Settings.exe`
- `SlepeAI Settings.cs`

Protected user settings:

- `TargetLists.lua`
- `SlepeAI Settings Profiles.json`
- `Profiles/`
- `*.bak`

`TargetLists.lua` is protected because it contains tactics, global behavior, runtime behavior toggles, homunculus skill settings, and patrol settings. Updates should replace code files only, then let the editor and AI read the existing local settings.
