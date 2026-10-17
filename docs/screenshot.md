# Screenshots of your game

The reader can take a screenshot of your game when you ask ("ss", "screenshot", "look at my screen"), look at it, and send back a copy with the spot you asked about circled and labelled. It never takes one on its own.

**Windows only.** Mac and Linux are not supported yet.

## What you need

- Windows 10 or 11 with the game running in **borderless-windowed** or **windowed** mode. Exclusive fullscreen usually copies as a black image.
- Nothing to install. The tools use PowerShell and the drawing library that ships with Windows.
- You signed in at the PC, with the screen unlocked.

## First screenshot for a guide

The guide's `CHECKPOINT.md` has a `game_window_process:` line for the game's program name (for example the name shown in Task Manager's Details tab, without `.exe`). It starts blank. On your first "ss", the reader lists the open windows that could be a game:

- one candidate: it uses that one and saves the name;
- more than one: it asks you once which is the game and saves your answer;
- none: it tells you it could not find the game window.

You can also fill the line in yourself. The name can differ between stores, so it lives in your own `CHECKPOINT.md`, not in the shared guide files.

## How it works

`tools/screenshot/capture.ps1` copies the part of the screen where the game's window is. An AI assistant's shell often runs without access to your desktop, so the script creates a one-time Windows scheduled task that runs inside your signed-in session, takes the copy, and deletes itself. That task starts its console hidden (`conhost.exe --headless`), so no black console box appears over the game.

`tools/screenshot/markup.ps1` draws a circle, a label box and a connecting line for each spot, and puts the map grid cell in the label when the guide has a grid.

Screenshots are saved in your temp folder. One goes into the guide only when you ask (for example, to use as a map base).

## Commands

```powershell
pwsh -NoProfile -File <reader>/tools/screenshot/capture.ps1 -Window <program name> [-Out shot.png]
pwsh -NoProfile -File <reader>/tools/screenshot/capture.ps1 -List
pwsh -NoProfile -File <reader>/tools/screenshot/markup.ps1 -In shot.png -Out marked.png -Mark "640,360,40,Supply cache -- C4|900,200,30,Exit"
```

`<reader>` is the folder holding the reader's `SKILL.md`. Windows PowerShell (`powershell`) works in place of `pwsh`.

## When it fails

| Message | What to do |
|---|---|
| The program '...' is not running or has no visible window. | Start the game, or correct `game_window_process:` in `CHECKPOINT.md`. |
| The program '...' is minimized. | Bring the game back on screen. |
| The screenshot came back black. | Unlock the PC, or switch the game to borderless-windowed. |
| No signed-in desktop was found. | Sign in at the PC. |
| Windows refused to create the one-time capture task. | Your account may not be allowed to create scheduled tasks; the screenshot tool cannot work on this PC. |
| The capture command is longer than Windows allows. | Install the reader in a folder with a shorter path. |

The script never falls back to a picture of your whole desktop. `-Desktop` captures every monitor and is used only when you ask for the whole screen.

## Known limit

The script copies what is on screen. A window that really sits on top of the game, such as a chat app or a notification, shows in the screenshot.
