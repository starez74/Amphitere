# Fixed landscape tablet interface — prototype

**Branch:** feature/fixed-tablet-ui (main project and Android frontend).
**Status:** Code committed; Android build and real-device QA pending. **Do not replace the stable v1 tag.**

## Layout and behavior
- Landscape tablets with smallest width >=600dp use a non-editable, fixed workspace.
- The NetHack map remains the real TextureView and game logic; its display region is
  smaller to reserve space for controls, and the default map scale is reduced.
- A single-line, color-coded status strip is positioned top left; game messages
  are displayed in a fixed top-right panel, including --More-- indication.
- Menu windows, including inventory, render in a narrow right-hand dock.
  Text dialogs, line entry, character selection and other modal screens retain
  their existing behavior pending dedicated QA.
- A native-in-app keyboard and 8-way D-pad occupy a fixed lower region.
  They are *not* draggable or resizable ControlWidgets, and the tablet's
  editable overlay is disabled on this branch.
- Built-in keyboard: Shift (single use), Ctrl (single use), !#1 symbol-number
  toggle, Enter, Esc, Tab, Space, Backspace/Delete, cursor/paging < and >,
  numbers and letters. All keys use the existing GameInputRouter.
- Existing phone and secondary-display UI paths remain unchanged.
- Existing save and restore code is unchanged.

## Source
- Frontend: lib/src/com/tbd/forkfront/ui/FixedTabletUi.java
- Frontend: ForkFront.java, WidgetLayoutController.java
- Frontend: NHW_Menu.java, MenuFragment.java
- Frontend: tablet_menu1.xml, tablet_menu3.xml, fixed_tablet_ids.xml
- Frontend: MapViewport.java, DrawerMenuController.java
- Parent repository: submodule gitlink sys/android/forkfront points to frontend
  feature/fixed-tablet-ui commit. .gitmodules continues to use starez74 fork.

## Real-device acceptance checklist
1. Back up the current compressed save (*.gz) outside the app before installing.
   Preserve the original v1 APK and tag for rollback.
2. Build the feature branch with the existing Windows Java 17/MSYS2/NDK setup.
   No automated Android build has been run remotely for this prototype.
3. Install the debug APK with 'adb install -r' (never uninstall, clear data, or
   delete the application's save directory).
4. Confirm status/info is one line, and the map stays centered without overlapping
   status, message, inventory, keyboard or D-pad.
5. Test all 8 D-pad directions, diagonal repeat and the center '.' action.
6. Test keyboard letters, capital letters, numbers, Ctrl commands, the symbols
   toggle, Esc, Space, Enter, Backspace and menu accelerators.
7. Open inventory and other single/multi-select menus; select and cancel,
   inspect list scrolling and the right-hand width.
8. Test GetLine, player prompts, the character picker, Save and Quit, and restore
   of a copied *test* save (not the sole original copy).
9. Share a tablet screenshot for spacing/size adjustments before merging.
10. Only after QA should this feature branch be merged. Never move the two v1 tags.

## Safe rollback
The original project and frontend are preserved on
feature/nethack-ai-tablet-stable and on the original/fork-ready v1 tags.
Checking out those saved commits and rebuilding restores the prior UI.
