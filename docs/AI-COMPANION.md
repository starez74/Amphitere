# NetHack AI Edition — Dungeon Companion / Wiki Preview

**Branch:** feature/ai-companion in both starez74/Amphitere and
starez74/ForkFront-Android-DS.
**Based on:** release/fixed-tablet-ui-v2.
**Status:** Source implementation committed; Android build and Galaxy Tab A8
testing required. This is not a production generative-AI service.

## What the first stage does

In fixed landscape tablet mode, open the narrow companion panel by tapping
the "Inventory / menu" placeholder or selecting "Dungeon Companion (Wiki)"
from the right-hand drawer.

- Type a question using the app's fixed keyboard; its keys are diverted to
  the companion input only while that panel is open. Questions never become
  NetHack gameplay commands. Esc closes the panel.
- Tap "Ask NetHackWiki" (or press Enter) to search NetHackWiki's MediaWiki
  search endpoint over HTTPS. The search shows up to three matching page
  titles and short attributed snippets. Tap a title to open the original.
- Toggle "In-world" versus "Factual advice". In-world mode adds a brief
  role-flavored introduction. Factual mode presents the source results directly.
- Auto-detect the character's role using the character's rank in status
  title (rank data checked against NetHack 5.0 src/role.c), or override the
  role using the spinner. Unknown or ambiguous ranks stay "Adventurer".
- The source remains clearly identified as NetHackWiki, with a visible
  CC BY-SA 3.0 attribution link. The panel does not invent a wiki answer.
- When an inventory menu opens, the companion hides so the game's menu
  and input continue working normally.
- If NetHackWiki is offline, rate-limited or its API blocks requests,
  an "Open full Wiki search" browser fallback is available.

## Privacy and limitations

The search sends **only the question text the player typed** to
https://nethackwiki.com/w/api.php. It does NOT upload character names,
status, save files, dungeon maps, inventory contents or API keys.
A role is inferred locally and used only for local presentation.
The app does not automatically perform game commands based on wiki results.

This stage is a **source-backed wiki consultation tool with a role-aware
companion voice**, not a large-language-model assistant. Natural-language
answer synthesis and proactive in-dungeon analysis require a subsequent
secure proxy/service and explicit consent for any gameplay data shared.
No OpenAI or other AI-provider API credentials are embedded in Android code.

## Sources and licensing

NetHackWiki: https://nethackwiki.com/
NetHackWiki Copyrights: https://nethackwiki.com/wiki/NetHackWiki:Copyrights
Most wiki pages are CC BY-SA 3.0; individual media and NetHack source-code
pages can have other license terms. The app displays short linked previews
and does not package an offline article archive.

API: https://nethackwiki.com/w/api.php (MediaWiki list=search).
The remote wiki API's live availability has not been verified from the
Android tablet yet.

## Testing checklist

1. Save & Quit before testing and preserve the existing APK and test saves.
2. Run scripts/Build-AiCompanion.ps1 -Install from Windows PowerShell.
   The script fetches only the new branches, checks the submodule SHA,
   copies the existing APK, builds, updates via adb install -r, and launches.
   It does not uninstall the app or clear app data.
3. Tap the blank right sidebar placeholder to open the companion.
   Also test the drawer's "Dungeon Companion (Wiki)" entry.
4. Test a query such as "healing potion" using the fixed keyboard;
   the game must not move or interpret these letters as commands.
5. Confirm wiki results are either linked with short excerpts, or the
   expected browser fallback appears (no fabricated advice).
6. Test "In-world"/"Factual advice"; change character role manually, then
   test auto detection from the native character rank.
7. Tap wiki source and licensing link, press Esc to close the companion,
   and confirm normal NetHack keyboard, D-pad and inventory still work.
8. Check game Save & Quit and compressed save restoration (on a backup).
9. Inspect UI screenshot for small text, scrolling and panel alignment.

## Next AI milestone

Add an opt-in, secure and authenticated LAN/cloud companion backend that:
- receives a user-selected minimal game-state summary (not full saves);
- retrieves relevant wiki articles, cites source revisions/links, and
  synthesizes advice with a real LLM; 
- supports role-aware in-world or plain factual tones;
- refuses to invent facts when no reliable wiki evidence exists;
- never stores provider secrets in the Android APK;
- never directly controls the game without an explicit player action.

The v1 tags and release/fixed-tablet-ui-v2 checkpoint are preserved.
