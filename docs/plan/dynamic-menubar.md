# Dynamic Menu Bar Architecture and Implementation Plan

Status: implemented and Wayland-hardened  
Scope: architecture, implementation contract, and compatibility notes.  
Target: NetworkTools desktop application (`PyQt6` + Qt Quick/QML)

## 1. Executive summary

NetworkTools should expose one command system through two interchangeable menu presenters:

- **Native Global**: `Qt.labs.platform.MenuBar` publishes the application menu to macOS or to a compatible Linux global-menu registrar, such as the one used by KDE Plasma's Global Menu widget.
- **In-Window Custom**: `ModernMenuBar.qml` renders a themed, keyboard-accessible menu directly inside the existing frameless title bar, with modern flat top-level items and custom popups.

The presenters must never own business logic. A window-scoped `CommandRegistry.qml` will be the single source of action identity, labels, icons, shortcuts, enablement, checked state, and dispatch. A separate menu-definition model will describe grouping and ordering. Both presenters consume those same objects and call the same command entry point.

A Python `MenuPresentationController` will persist the user's Appearance preference, detect the OS and desktop environment, probe actual native-global-menu capability, resolve the effective mode, and expose a stable rendering contract to QML. Auto will prefer a native global menu on macOS and on KDE/Plasma when the D-Bus registrar is available; it will prefer the custom menu on Windows, GNOME, unsupported Linux desktops, and all capability failures. An explicit Native Global override may use any compatible Linux registrar, but it must fall back visibly and safely when one is unavailable.

The existing frameless-window design remains independent from menu presentation in this project. In custom mode, `ModernMenuBar` occupies the leading part of the current title bar. In native-global mode, that same area becomes title/drag space while the existing frame and window controls remain intact. A separate native-versus-custom window-frame setting can be considered later; changing menu style must not unexpectedly change window decoration.

The first release should apply a menu-style change on the next application start. Native menu registration and teardown vary across Qt versions and desktops, and both VS Code and Obsidian document restart boundaries for related frame/menu choices. The Settings UI should save the choice immediately, show the current and next effective styles, and mark restart as required. Live switching can be enabled later only if the platform test matrix proves that detaching and recreating native menus is reliable.

### 1.1 KDE Plasma/Wayland hardening

The implemented presenter observes the following additional invariants:

- The `com.canonical.AppMenu.Registrar` capability probe uses a 300 ms D-Bus timeout, so an unhealthy session service cannot stall application startup indefinitely.
- `NativeGlobalMenuBar` is created with both `registry` and `window` as initial properties. It is never completed with a null window and rebound afterwards, avoiding an invalid native-menu/surface lifecycle on Wayland.
- Native presenter creation is delayed until its owning top-level window is visible and active. Welcome and workspace windows are handed off serially, rather than briefly owning competing active native menus.
- Before a top-level Wayland surface is hidden, focus is moved away from text input and Qt's input-method state is committed and reset. This prevents stale text-input-v3 leave/disable calls against a null surface during the window transition.
- Some PyQt6 wheels contain the matching `Qt6LabsPlatform` library but omit the QML plugin directory. Startup registers that bundled library and exposes a local `qmldir` shim; it never loads a system plugin built against a different Qt version.

## 2. Goals and non-goals

### 2.1 Goals

- Define commands once and invoke the same handler from menus, shortcuts, buttons, and future command-palette surfaces.
- Select a suitable menu presenter automatically from OS, desktop-environment, session, and runtime capability data.
- Let users override Auto under **Global Settings > Appearance** with **Auto**, **In-Window Custom**, or **Native Global**.
- Preserve native macOS placement and behavior for About, Settings/Preferences, and Quit.
- Integrate the custom menu into the frameless title bar without adding vertical chrome.
- Match modern application qualities: flat themed chrome, concise hover/pressed states, restrained animation, icons where helpful, visible shortcuts, and elevated popups.
- Provide complete pointer, keyboard, accessibility, high-DPI, localization, and multi-window behavior.
- Fail safely: the application must always retain an accessible in-window menu when native global export cannot be established.
- Fit the repository's dependency rule: `QML -> facade/slots -> service -> repository/worker`.

### 2.2 Non-goals for the first release

- Implementing Python or QML as part of this planning task.
- Replacing every context menu in the application.
- Adding a user-customizable menu editor or extension-contributed commands.
- Adding a command palette; the registry should make one possible later.
- Changing the frameless window into native server-side decoration as a side effect of the menu choice.
- Reproducing macOS, Windows, or KDE visuals inside the custom renderer pixel-for-pixel.
- Treating desktop-environment name detection as proof that a global-menu service is available.
- Promising live style switching before native-menu teardown has passed compatibility testing.

## 3. Research findings and adopted lessons

| Product or platform | Documented behavior | NetworkTools decision |
|---|---|---|
| VS Code | VS Code separates title-bar style, menu style, and menu-bar visibility. Current choices include native, custom, and inherited menu rendering; menu visibility can be classic, visible, Alt-toggle, compact, or hidden. Style changes require a full restart. See [VS Code custom layout: Window and menu style](https://code.visualstudio.com/docs/configure/custom-layout) and the [custom-menu release note](https://code.visualstudio.com/updates/v1_101#_custom-menus-with-native-window-title-bar). | Keep presentation policy separate from command content and window frame. Persist an explicit override, expose the resolved mode, and use a restart boundary in version 1. Do not couple the user's menu choice to title-bar decoration. |
| Obsidian | Obsidian exposes a **Native menus** choice independently from **Window frame style**; frame choices include custom, native, and hidden and require restart. See [Obsidian Settings: Appearance](https://obsidian.md/help/settings#Appearance). | Treat menu rendering and window framing as separate concerns. Retain the existing NetworkTools frameless shell while switching only the menu presenter. |
| Discord | Discord's custom desktop UI emphasizes consistent app-wide keyboard navigation and visible focus treatment rather than relying only on pointer interaction. See [How Discord Implemented App-Wide Keyboard Navigation](https://discord.com/blog/how-discord-implemented-app-wide-keyboard-navigation). | A branded custom menu is acceptable only if keyboard focus, directional navigation, Escape behavior, and accessibility are first-class acceptance criteria. |
| Qt shared actions | Qt describes `Action` as a reusable abstraction that centralizes text, icon, shortcut, enablement, checked state, and triggering across controls. See [Qt Quick Controls Action](https://doc.qt.io/qt-6/qml-qtquick-controls-action.html). | Expand the existing registry around shared `Action` semantics; UI delegates bind to commands rather than declaring handlers or shortcuts themselves. |
| Qt native platform menus | `Qt.labs.platform.MenuBar` is a native menu API. Linux support exists only on desktop environments that provide a global D-Bus menu bar, and the Labs module has no long-term source-compatibility guarantee. Its native menu types are designed to run with a `QApplication`; NetworkTools already creates one. See [Qt Labs Platform MenuBar](https://doc.qt.io/qt-6/qml-qt-labs-platform-menubar.html) and [Qt Labs Platform Menu](https://doc.qt.io/qt-6/qml-qt-labs-platform-menu.html). | Isolate all Labs usage in one presenter, verify it at the minimum and packaged Qt versions, and keep the custom presenter as the guaranteed fallback. Do not spread `Qt.labs.platform` imports through feature QML. |
| macOS | macOS users expect the app menu at the top of the display and a conventional order including app, File, Edit, View, Window, and Help. About, Settings/Preferences, and Quit belong in the application menu. Qt exposes native menu roles for these placements. See [Apple's menu-bar guidance](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), [Qt Labs Platform MenuItem roles](https://doc.qt.io/qt-6.8/qml-qt-labs-platform-menuitem.html), and [Qt for macOS menu guidance](https://doc.qt.io/qt-6.5/macos-issues.html#menu-bar). | Use explicit native roles instead of English-text heuristics. Preserve standard shortcuts and let the OS render and place native items. |
| KDE Plasma | KDE's Global Menu separates menus from application windows and can show them in a panel widget or window-decoration button. Adding that consumer starts the required background service. See [KDE Plasma Global Menus](https://kde.org/announcements/plasma/5/5.12.0/#global-menus). Qt documents the Linux registrar as `com.canonical.AppMenu.Registrar`; see [QMenuBar global-menu behavior](https://doc.qt.io/qt-6/qmenubar.html#qmenubar-as-a-global-menu-bar). | Detect Plasma, but also probe the session D-Bus registrar. If the widget/service is absent, Auto uses the custom menu so commands do not disappear. |
| GNOME | GNOME's current header-bar guidance combines a small number of app controls with the draggable/window-management region and usually places menus at the trailing end. See [GNOME Header Bars](https://developer.gnome.org/hig/patterns/containers/header-bars.html). | Auto uses the in-window custom menu on GNOME. Keep the title bar uncluttered and responsive; do not assume an Ubuntu/Unity-era global-menu interface from the `linux` OS value alone. |
| Windows | Microsoft's title-bar guidance supports integrating menus or relevant controls into custom title bars, but makes the app responsible for correct drag regions and interactive exclusions. See [Windows title-bar customization](https://learn.microsoft.com/en-us/windows/apps/design/controls/title-bar). | Keep the modern menu inside the existing custom title bar on Windows. Ensure menu hit targets never overlap draggable or caption-button regions. |
| Menu accessibility | The conventional menu model uses Enter/Space to open, arrows to move, Escape to close and restore focus, and predictable submenu behavior. See the [W3C Menu and Menubar Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/menubar/) and [Qt accessibility overview](https://doc.qt.io/qt-6/accessible.html). | Implement a documented focus state machine, accessible roles/names/states, non-color-only selection cues, and automated plus manual keyboard tests. |

### 3.1 Design synthesis

The common pattern is not “custom everywhere” or “native everywhere.” Modern cross-platform applications separate:

1. **Command semantics** — what actions exist and whether they are available.
2. **Information architecture** — how commands are grouped into File/View/Help and submenus.
3. **Presentation policy** — native/global versus themed/in-window.
4. **Window chrome** — native or client-drawn frame and title bar.

NetworkTools should preserve all four boundaries. This prevents a later visual redesign, desktop-policy change, or native API replacement from rewriting command behavior.

## 4. Current repository state and migration impact

The implementation must evolve existing components instead of adding a second command/menu stack:

- `app/UI/qml/shared/CommandRegistry.qml` already centralizes five contextual shortcuts and handlers: Reload, Devices, Database, Settings, and Keyboard Shortcuts. It is the migration starting point, but it does not yet model the full application menu or expose a general lookup/trigger contract.
- `app/UI/qml/app/WorkspaceMenuBar.qml` is currently a styled `QtQuick.Controls.MenuBar`. It declares its own actions and handler properties, so command metadata and dispatch are duplicated outside the registry.
- `app/UI/qml/app/Main.qml` already embeds `WorkspaceMenuBar` in `customTitleBar`, binds workspace state, supplies handlers, owns title dragging, and owns the caption buttons. The new custom presenter should replace this slot without introducing another vertical row.
- `app/UI/qml/app/StatefulWindow.qml` already uses `Qt.FramelessWindowHint`, system move/resize support, and persisted geometry. Menu mode must not break these behaviors.
- `app/core/settings.py` already contains QSettings-backed global settings, while `SettingsView.qml` has an Appearance section. The menu preference belongs beside these settings but should have its own presentation-policy object rather than becoming theme logic.
- `app/main.py` already creates `QApplication`, constructs context objects, and loads separate Welcome and workspace windows. It is the composition root for the new detector/controller.
- `app/UI/qmldir` explicitly registers QML components, so every new presenter and reusable delegate requires a module entry.
- Existing tests in `app/tests/test_qml_smoke.py`, `app/tests/test_ui_contracts.py`, and `app/tests/test_workspace_save_and_snapshots.py` assert the current registry/menu contracts. They must be migrated deliberately, not deleted wholesale.
- The project supports PyQt `>=6.7,<6.11`. Compatibility must be verified at 6.7 and at the packaged/current supported version; behavior documented only for a later Qt cannot be assumed.

## 5. Target architecture

### 5.1 Component flow

```text
OS / environment / session D-Bus
              |
              v
DesktopEnvironmentDetector -----> MenuPresentationController <---- QSettings
                                              |
                                    activeStyle + diagnostics
                                              |
                                              v
                                     Main / Welcome window
                                              |
                         +--------------------+--------------------+
                         |                                         |
                         v                                         v
              NativeGlobalMenuBar.qml                    ModernMenuBar.qml
              (Qt.labs.platform)                    + ModernMenuPopup/items
                         |                                         |
                         +--------------------+--------------------+
                                              |
                                      MenuDefinition.qml
                                              |
                                      CommandRegistry.qml
                                              |
                          QML handlers / Python facade slots
```

### 5.2 Responsibility boundaries

| Component | Responsibility | Must not do |
|---|---|---|
| `DesktopEnvironmentDetector` | Return normalized OS, desktop family, session type, Qt platform plugin, and native-global capability evidence. Probe the D-Bus registrar without changing system state. | Persist preferences, choose UX policy, or import QML. |
| `MenuPresentationController` | Persist and validate the configured style; resolve recommended, next, and active styles; expose capability/fallback reasons and restart state to QML. | Own commands or feature behavior. |
| `CommandRegistry.qml` | Own reusable action metadata, runtime enablement/check state, shortcut dispatch, command lookup, and the single `trigger(commandId)` path for the active window context. | Draw a menu, decide menu grouping, or call repositories/workers directly. |
| `MenuDefinition.qml` | Define stable top-level ordering and item tokens (`command`, `separator`, and later `submenu`). | Duplicate command labels, icons, shortcuts, or handlers. |
| `NativeGlobalMenuBar.qml` | Adapt menu definitions and commands to `Qt.labs.platform.MenuBar`, `Menu`, and `MenuItem`; set native roles; attach explicitly to the owning window. | Contain business handlers or fallback policy. |
| `ModernMenuBar.qml` | Render top-level in-window menu buttons and coordinate one open custom popup. | Define commands or own application state. |
| `ModernMenuPopup.qml` and delegates | Render items, separators, check states, icons, shortcut labels, submenus, focus, dismissal, screen-edge placement, and shadow. | Register duplicate application shortcuts or call feature controllers directly. |
| `Main.qml` / `Welcome.qml` | Supply the window-specific command context and host only the active presenter. | Re-declare menu action text or shortcuts. |

### 5.3 Backend presentation contract

Expose one context property, tentatively `menuPresentation`, with a stable, testable contract:

| Property | Meaning |
|---|---|
| `configuredStyle` | Persisted string enum: `auto`, `custom`, or `native`. Writable from Appearance settings. |
| `recommendedStyle` | Current Auto recommendation based on platform policy and capability. |
| `resolvedStyle` | Style the configured value would use if a new window were created now. |
| `activeStyle` | Style frozen for the current application/window lifecycle; QML uses this rendering flag. |
| `isCustomActive` / `isNativeGlobalActive` | Convenience read-only booleans; exactly one is true. |
| `nativeGlobalAvailable` | Whether a genuine global-menu target is currently supportable, not merely whether Qt has a type named MenuBar. |
| `platformFamily` | Normalized `macos`, `windows`, `linux`, or `other`. |
| `desktopFamily` | Normalized `kde`, `gnome`, `unity`, `other`, or `unknown`. |
| `sessionType` | `wayland`, `x11`, `windows`, `cocoa`, or `unknown`, for diagnostics and testing. |
| `capabilityReason` | Stable machine-readable reason such as `macos-system-menu`, `dbus-registrar-present`, `dbus-registrar-missing`, `unsupported-platform`, or `qt-dbus-unavailable`. |
| `fallbackMessage` | Localizable user-facing explanation when configured Native cannot be honored. |
| `restartRequired` | True when `resolvedStyle` differs from `activeStyle`. |

Use strings for persisted public settings rather than positional integers. Unknown/corrupt values normalize to `auto`. Keep diagnostic values non-sensitive and log them once at startup to simplify support reports.

### 5.4 Detection and resolution algorithm

Detection should be pure/read-only where possible and should not run external shell commands:

1. Read Python's platform value and Qt's platform plugin name.
2. On Linux, normalize `XDG_CURRENT_DESKTOP`, `XDG_SESSION_DESKTOP`, `DESKTOP_SESSION`, `KDE_FULL_SESSION`, and `GNOME_DESKTOP_SESSION_ID`, treating colon-separated desktop values as a set.
3. Read `XDG_SESSION_TYPE` and retain X11/Wayland only as diagnostic evidence; neither alone proves global-menu support.
4. If QtDBus is available, query the session bus for `com.canonical.AppMenu.Registrar`. A service owner is the decisive Linux native-global capability check.
5. Optionally watch registrar owner changes. In version 1, update `resolvedStyle` and `restartRequired` but do not tear down the active presenter.
6. On probe errors or missing QtDBus, report an unavailable capability and choose custom; never hide the menu on an assumption.

Resolution matrix:

| Platform / capability | Auto | In-Window Custom | Native Global |
|---|---|---|---|
| macOS | Native Global | Custom | Native Global |
| KDE/Plasma + registrar present | Native Global | Custom | Native Global |
| KDE/Plasma + registrar absent | Custom with diagnostic | Custom | Custom fallback with warning |
| Unity/compatible Linux + registrar present | Native Global | Custom | Native Global |
| GNOME | Custom, even if an unusual extension exposes a registrar | Custom | Native only when a compatible registrar is positively present; otherwise warned fallback |
| Other Linux + registrar present | Custom by default | Custom | Native Global when explicitly requested |
| Windows | Custom | Custom | Custom fallback with warning |
| Unknown/unsupported | Custom | Custom | Custom fallback with warning |

This matrix distinguishes **policy** from **capability**: Auto is conservative and desktop-native, while an informed user may explicitly opt into a compatible Linux registrar on an uncommon desktop.

### 5.5 Command model

Expand the existing registry into a reusable window-scoped command model. Each command should define:

- stable reverse-DNS-like or dotted `id`, such as `workspace.save` or `view.sidebar.toggle`;
- translated display `text` and optional shorter menu text;
- icon source plus optional native theme-icon name;
- portable shortcut definition, favoring `StandardKey` and platform-native display text over hardcoded `Ctrl` strings;
- `enabled`, `visible`, `checkable`, and `checked` state;
- native menu role (`about`, `preferences`, `quit`, or none);
- scope/context (`application`, `window`, or contextual content);
- one handler/dispatcher path;
- optional description for tooltips, accessibility, and a future command palette.

Initial command inventory should consolidate all current registry and workspace-menu behavior:

| Command ID | Current source | Main menu placement |
|---|---|---|
| `project.new` | Workspace menu | File |
| `project.open` | Workspace menu | File |
| `workspace.save` | Workspace menu | File |
| `workspace.snapshot.create` | Workspace menu | File |
| `workspace.snapshot.history` | Workspace menu | File |
| `workspace.close` | Workspace menu | File |
| `app.quit` | Workspace menu | File; native Quit role on macOS |
| `view.reload` | Existing registry | View |
| `view.sidebar.toggle` | Main-level shortcut/menu handler | View |
| `view.dashboard` | Existing registry/menu | View |
| `view.sftp` | Existing registry/menu | View |
| `view.systemLogs` | Existing registry/menu | View |
| `view.database` | Existing registry/menu | View |
| `settings.open` | Existing registry/menu | View in custom mode; native Preferences role on macOS |
| `help.shortcuts` | Existing registry/menu | Help |
| `app.about` | Workspace menu | Help; native About role on macOS |

Before adding Edit or Window menus, inventory real focus-aware commands. Do not ship inert Cut/Copy/Paste/Undo entries merely to imitate another app. When added, they must route to the active focus item or appropriate application controller and use standard shortcuts.

#### Shortcut ownership

Avoid ambiguous or double activation:

- In custom mode, the registry's shortcut host owns activation; custom menu rows only display the formatted sequence.
- In native mode, platform menu items may need the shortcut property to display and integrate correctly. Disable the parallel custom shortcut host for those commands, so the native item is the sole owner.
- Commands not represented in a native menu retain registry-owned shortcuts.
- A test must prove that every key sequence invokes its command exactly once in each mode.

### 5.6 Menu definition model

Keep menu topology separate from actions. The version 1 model contains File, View, and Help, with explicit separator tokens and command IDs. It should support future conditional groups and submenus without changing presenter APIs.

Rules:

- Presenters may know layout tokens, but never repeat labels, enablement logic, icons, shortcuts, or handlers.
- A missing command ID is a startup/test error, not a silently empty row.
- A command with `visible: false` is omitted; separators collapse so no menu begins, ends, or contains adjacent separators.
- A disabled command remains visible when it helps users learn availability; use visibility only for commands irrelevant to the current window/context.
- Menu ordering is deterministic and identical across presenters except for OS-native role relocation.

### 5.7 Multi-window ownership

NetworkTools currently has separate Welcome and workspace windows. Native global menus follow the active application/window context, especially on macOS, so lifecycle must be explicit:

- Instantiate a registry per top-level window from the same registry component; handlers and enablement bind to that window's context.
- Give Welcome a minimal File/Help command context: New Project, Open Project, Quit, Settings if available, and About. Workspace-only commands remain disabled or absent by definition.
- Attach each native presenter explicitly to its owning `Window` rather than relying on fragile parent traversal.
- When windows are hidden/shown, verify that the active native menu changes with focus and never dispatches to a hidden workspace.
- Do not create one global QML singleton containing handlers that capture a particular window. Definitions may be shared; live action instances must remain window-scoped.

## 6. Presenter specifications

### 6.1 Native Global presenter

`NativeGlobalMenuBar.qml` should be a narrow adapter around `Qt.labs.platform`:

- Own one `Platform.MenuBar` attached to the provided window.
- Translate each menu definition to `Platform.Menu` and `Platform.MenuItem` objects.
- Bind text, enabled, visible, checkable, checked, icon, and shortcut to the corresponding registry command.
- Dispatch only through `registry.trigger(commandId)`.
- Assign explicit About, Preferences, and Quit roles. Do not depend on English text heuristics, which fail under translation.
- Avoid custom font, color, hover, shadow, and padding expectations; the OS/desktop owns native rendering.
- Keep the module import isolated so the rest of the UI continues to load if a particular native backend is unavailable.
- Confirm the current `QApplication` composition remains in place, as required by the Qt platform menu implementation.
- Emit structured diagnostics when native creation/attachment fails, then ensure the next launch resolves to custom. If a synchronous creation failure can be detected safely, replace it with the custom presenter in the current window.

Because Qt Labs is experimental, wrap it behind a stable NetworkTools component API: `window`, `registry`, `definition`, `active`, and an optional error signal. No consumer should instantiate Labs types directly.

### 6.2 Modern custom presenter

`ModernMenuBar.qml` should feel consistent with the existing Feature Bar and theme without reusing `FeatureDropdown.qml`, which lacks menu semantics and keyboard behavior.

Top-level bar behavior:

- Flat transparent background inside the title bar; compact horizontal spacing based on Theme tokens.
- Clear hover, pressed, keyboard-focus, and open-menu states with theme/high-contrast variants.
- Clicking an inactive top-level item opens its popup; clicking the active item closes it.
- While one popup is open, pointer hover or Left/Right navigation switches top-level menus in place.
- Alt/mnemonic behavior should be researched and implemented consistently per platform; at minimum, keyboard focus must have an explicit entry path and not conflict with application shortcuts.
- At narrow widths, preserve File/View/Help access before the centered title. If necessary, collapse lower-priority top-level menus into a labeled overflow menu rather than clipping or covering caption controls.

Popup behavior:

- Use a real QML `Popup`/overlay-level surface so it is not clipped by the title-bar rectangle.
- Render a surface color, 1 px/theme-token border, radius, and restrained `MultiEffect` drop shadow; high contrast must remain legible without relying on the shadow.
- Use aligned columns: optional check/icon, label, shortcut, and submenu chevron.
- Keep icons purposeful and visually subordinate. Reserve a consistent icon column even when only some rows have icons.
- Use `Shortcut.nativeText` or equivalent native formatting for display; do not manually replace `Ctrl` with `Cmd`.
- Support disabled, checked, radio-group, separator, and submenu states even if version 1 uses only a subset.
- Clamp or flip horizontally and vertically against the owning screen's available geometry, including mixed-DPI multi-monitor setups.
- Close on command activation, Escape, focus/window deactivation, outside click, window hide, and mode teardown.
- Use theme motion tokens for a short opacity/scale transition and honor reduced-motion policy if one is later exposed. Never delay command activation for animation.

Keyboard state machine:

- Enter/Space/Down opens a top-level menu and focuses its first enabled item; Up may focus the last enabled item.
- Up/Down moves among enabled rows with wrapping; Home/End jumps to first/last.
- Right opens a submenu or moves to the next top-level menu; Left closes a submenu or moves to the previous top-level menu.
- Enter/Space activates the focused command.
- Escape closes one level, then the menu, and restores focus to the top-level item or previously focused content.
- Printable-key search/mnemonics may be phase-two behavior, but the architecture must not preclude it.
- Tab/Shift+Tab must never trap focus; define whether they close the menu and return to the normal window tab chain.

Accessibility contract:

- Expose MenuBar, MenuItem, Separator, checkable, checked, enabled, expanded, and focus states through Qt accessibility APIs where supported.
- Provide stable `Accessible.name`, `Accessible.description`, and test-friendly `objectName`/identifier values derived from command IDs.
- Make keyboard focus visible independently of hover and color alone.
- Preserve minimum hit targets, readable text scaling, sufficient contrast, and high-contrast borders.
- Test with Windows Narrator, macOS VoiceOver, and at least one Linux screen reader where the Qt stack supports it.

## 7. Title-bar integration plan

The existing `Main.qml` title bar already has the correct broad layout: menu, flexible title/drag area, then caption buttons. Refactor it into explicit zones:

1. **Leading interactive zone**: optional app/system-menu icon and `ModernMenuBar` only when custom is active.
2. **Flexible drag/title zone**: fills remaining width, elides the workspace title in the middle, supports `startSystemMove()`, and handles double-click maximize/restore.
3. **Trailing interactive zone**: minimize, maximize/restore, and close controls.

Integration rules:

- `ModernMenuBar` consumes the existing `Theme.windowTitleHeight`; it must not add a new `ColumnLayout` row.
- The title drag handler covers only the computed drag zone. It must not overlay top-level menu hit targets or caption buttons, including when the title is visually centered.
- In Native Global mode, the leading menu zone has zero width and its freed space joins the drag/title zone.
- Keep the bottom title-bar border and existing activity-bar theme alignment.
- Preserve `startSystemMove`, double-click maximize/restore, resize handles, maximized padding, full-screen behavior, and geometry persistence.
- Caption controls remain platform-aware future work. This menu project must not silently replace or reposition them beyond what is needed to avoid overlap.
- Test very narrow windows, long translated menu labels, long workspace names, 125–300% scaling, multiple screens, maximized windows, and right-to-left layout.
- If future design adds a command-center/search control like VS Code, place it in the flexible zone through a separate title-bar layout ADR; do not overload the menu component.

## 8. Settings and user experience

Add a **Menu Style** row to Global Settings > Appearance with a `StandardComboBox`:

- **Auto (Recommended)** — “Use the system global menu on macOS and supported Linux desktops; otherwise use the NetworkTools menu.”
- **In-Window Custom** — “Always show the themed menu inside the NetworkTools title bar.”
- **Native Global** — “Publish menus to the operating system or desktop global-menu service when available.”

Below the control, show:

- detected platform/desktop in friendly language;
- current active style;
- next resolved style when it differs;
- a restart-required inline notice;
- an actionable fallback explanation when Native Global is unavailable, such as “KDE Plasma was detected, but no Global Menu registrar is running. Add/enable Plasma's Global Menu widget or choose In-Window Custom.”

Behavior rules:

- Save changes immediately through the Python property setter and QSettings.
- Do not disable the Native Global option merely because it is currently unavailable; allowing selection makes the fallback reason discoverable and preserves intent if the user later enables the service.
- Never leave the user with no menu. Unsupported Native resolves to custom.
- “Reset Appearance” must restore `auto` along with other documented defaults.
- Keep the setting global, not workspace/project-scoped.
- Use the QSettings key `Appearance/menuStyle`; include normalization and migration tests.

## 9. Phased implementation plan

### Phase 0 — Compatibility spike and decision gate

1. Record the exact Qt/PyQt versions used by development, CI, and packaged releases.
2. Build a disposable, non-production QML harness to verify `Qt.labs.platform.MenuBar` attachment with the existing `QApplication` and frameless `ApplicationWindow`.
3. Test macOS native placement and KDE Plasma 6 global export on both Wayland and X11 where supported.
4. Verify behavior when the KDE Global Menu widget/registrar is absent, added, removed, or restarted.
5. Verify whether destroying/recreating the native presenter unregisters cleanly and whether shortcuts duplicate. Keep restart-only switching unless every supported platform passes.
6. Confirm that the PyQt 6.7 QML module exposes every Labs property/role the design requires.
7. Document results in an ADR or a compatibility section appended to this plan before production work begins.

Exit criteria: native export is proven on at least one supported macOS version and KDE Plasma configuration, the custom fallback is proven on unsupported configurations, and the team confirms the restart boundary.

### Phase 1 — Command inventory and registry consolidation

1. Inventory `WorkspaceMenuBar.qml`, `CommandRegistry.qml`, `Main.qml` shortcuts, Activity Bar commands, and relevant buttons.
2. Assign stable IDs and identify canonical text, icon, shortcut, enablement, checked state, scope, and native role for every initial command.
3. Resolve existing shortcut conflicts and replace portable candidates with `StandardKey` definitions.
4. Expand `CommandRegistry.qml` to expose lookup, state, trigger, and formatted-shortcut contracts while retaining current handler behavior.
5. Add `MenuDefinition.qml` for File/View/Help grouping and separator rules.
6. Move current Workspace menu metadata and dispatch into the registry; leave `WorkspaceMenuBar` as a temporary adapter until parity tests pass.
7. Update shortcut reference data so it reads from, or is validated against, the same canonical command definitions.

Exit criteria: existing menu items, shortcuts, and non-menu callers invoke the same registry command once; no application behavior is yet dependent on the new presentation detector.

### Phase 2 — Backend detection, policy, and persistence

1. Add read-only detection under `app/infrastructure/system/`, keeping environmental probing separate from UX policy.
2. Add the QSettings-backed `MenuPresentationController` under `app/core/` (or a narrowly named settings/policy module consistent with repository conventions).
3. Implement the normalized style enum, Auto resolution matrix, capability reason codes, fallback messages, and restart state.
4. Use QtDBus to probe and optionally watch `com.canonical.AppMenu.Registrar`; handle unavailable QtDBus and bus errors without exceptions escaping to QML.
5. Export the controller through `app/app_facade.py`, construct it in `app/main.py` before loading QML windows, and expose `menuPresentation` as a context property.
6. Add unit tests with mocked environment/platform/DBus inputs for every resolution-matrix row and corrupt setting value.

Exit criteria: QML can read one stable `activeStyle` flag plus complete diagnostics; every unsupported/error case resolves to custom.

### Phase 3 — Appearance setting

1. Add the Menu Style control and explanatory status to the Appearance section in `SettingsView.qml`.
2. Bind only to `menuPresentation`; do not duplicate the resolution matrix in QML.
3. Add restart-required and native-unavailable `InlineMessage` states.
4. Ensure Reset Appearance restores Auto and settings persist across application restarts.
5. Add responsive and keyboard tests for the new setting row.

Exit criteria: all three values persist, invalid values self-heal to Auto, fallback is understandable, and the active presenter does not change mid-session in version 1.

### Phase 4 — Native Global presenter

1. Add the isolated `NativeGlobalMenuBar.qml` adapter and its `qmldir` registration.
2. Bind it to the shared registry/definition and assign explicit macOS roles.
3. Add a minimal Welcome-window native menu context so app-global commands remain available when the workspace window is hidden.
4. Implement the native-mode shortcut ownership rule and exact-once dispatch tests.
5. Load this presenter only when `activeStyle === "native"`; never instantiate the custom menu at the same time.
6. Add diagnostics/fallback handling for attachment failures discovered in Phase 0.

Exit criteria: macOS and supported KDE expose the expected menus outside the NetworkTools window, role placement is correct, window focus selects the correct command context, and no in-window menu remains visible.

### Phase 5 — Modern custom presenter

1. Add `ModernMenuBar.qml`, `ModernMenuPopup.qml`, row/separator/submenu delegates, and module registrations.
2. Implement pointer/open-state coordination and popup placement before visual polish.
3. Implement the complete keyboard/focus state machine and shortcut-display formatting.
4. Bind all item state to the registry and invoke only `trigger(commandId)`.
5. Apply Theme tokens, high-contrast variants, icon tint policy, border, shadow, and restrained motion.
6. Add accessible roles/names/states and stable test identifiers.
7. Add overflow/responsive handling for long labels and narrow windows.

Exit criteria: functional parity with the native presenter, no clipped popups, complete keyboard operation, accessible state exposure, and correct rendering in every existing theme mode.

### Phase 6 — Title-bar integration and legacy removal

1. Replace the current `WorkspaceMenuBar` host in `Main.qml` with a presenter host controlled by `menuPresentation.activeStyle`.
2. Put `ModernMenuBar` in the leading title-bar zone with no additional vertical row.
3. Expand the title/drag zone when native mode is active and explicitly exclude all interactive rectangles from dragging.
4. Preserve current caption, move, maximize, resize, lock/blur, and geometry behavior.
5. Remove `WorkspaceMenuBar.qml` only after both presenters pass parity tests; otherwise retain it briefly as a compatibility wrapper with a removal issue and deadline.
6. Update `app/UI/qmldir`, `docs/SHORTCUTS.md`, `docs/UI_COMPONENTS.md`, and relevant architecture/function-map documentation.

Exit criteria: one presenter is active, no command metadata remains in the title-bar host, and the workspace content gains no vertical offset.

### Phase 7 — Cross-platform hardening and rollout

1. Run the platform matrix in section 10 using packaged builds, not only developer environments.
2. Add structured startup logging for configured/resolved/active style and capability reason.
3. Add visual regression baselines for custom menus across light, dark, high contrast, scaling, and RTL where CI supports screenshots.
4. Perform screen-reader and keyboard-only exploratory testing.
5. Roll out with Auto as the default and a kill switch that forces custom presentation if a native integration regression appears.
6. Collect platform-specific failures without changing the user's configured value; a temporary safe-mode fallback should affect only the active style.
7. Revisit live switching only after teardown/re-registration passes the full matrix repeatedly.

Exit criteria: no platform can lose access to commands, Auto is stable, and diagnostics are sufficient to resolve user reports.

## 10. Verification strategy

### 10.1 Python unit tests

- OS normalization for macOS, Windows, Linux, and unknown platforms.
- KDE/Plasma, GNOME, Unity, colon-separated desktops, and missing/malformed environment variables.
- Registrar present, absent, owner change, QtDBus unavailable, disconnected bus, and timeout/error.
- Resolution of every Auto/Custom/Native matrix cell.
- QSettings round trip, invalid value normalization, default/reset, and restart-required calculation.
- No external process execution and no state-changing D-Bus calls.

### 10.2 QML component tests

- Registry contains every required command ID and rejects missing/duplicate IDs.
- Menu definition resolves every command and collapses separators correctly.
- Enablement updates live for workspace availability, database availability, text input focus, modal lock, and active mode.
- Native and custom presenters dispatch identical command IDs and invoke exactly once.
- Custom pointer tests: open, switch, select, outside-click close, window-deactivate close.
- Custom keyboard tests: entry, arrows, Home/End, Enter/Space, Escape, submenu behavior, and focus restoration.
- Accessible role/name/checked/expanded/enabled state and stable IDs.
- Popup edge flipping/clamping on simulated screen geometries and scale factors.
- Settings rendering, persistence bindings, fallback notice, and restart notice.

### 10.3 Integration/platform matrix

| Platform | Required scenarios |
|---|---|
| Windows 10/11 | Auto custom; forced custom; requested native warned fallback; frameless drag/caption behavior; Alt/shortcut behavior; Narrator smoke test. |
| macOS, supported Intel/Apple Silicon targets | Auto native; forced custom; explicit native roles/order; Command-key display; active Welcome/workspace menu; VoiceOver; full screen and multi-monitor. |
| KDE Plasma 6 Wayland | Registrar/widget present and absent; Auto transition on next restart; explicit overrides; global menu receives enable/checked updates; native menu follows active window. |
| KDE Plasma 6 X11 | Same registrar scenarios, window move/resize, global menu export, mixed DPI. |
| GNOME Wayland/Xorg | Auto custom; explicit native fallback without registrar; client-side title-bar interaction; high contrast and screen-reader smoke test. |
| Other Linux/CI | Unknown desktop safe fallback; headless QML smoke tests; QtDBus unavailable. |

### 10.4 Regression tests

- Save uses the existing asynchronous workspace save path and remains enabled only with an active workspace.
- Snapshot dialogs, Welcome transitions, sidebar toggle, Devices, Database, Settings, shortcut reference, About, and Quit still work.
- Existing text-input protection for contextual shortcuts remains intentional; commands such as Save/Quit are not accidentally disabled by text focus.
- Modal `UiState.windowLock` prevents inappropriate commands and closes custom popups.
- No QML warnings, ambiguous-shortcut warnings, orphan popups, or duplicate native menus occur during window hide/show cycles.
- The title remains elided and draggable without covering menus or caption buttons.

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| KDE is detected but the user has no Global Menu widget/registrar, causing an invisible menu. | Require a positive D-Bus registrar capability check; fall back to custom with a clear reason. |
| `Qt.labs.platform` changes across supported Qt versions. | Isolate it in one adapter, test the minimum and packaged versions, and preserve a feature-complete custom fallback. |
| Native menu object teardown leaks, duplicates, or leaves stale macOS entries. | Use restart-only switching for version 1; attach ownership explicitly; test hide/show and shutdown. |
| Shortcuts fire twice because the registry and native menu both register them. | Define presenter-specific shortcut ownership and add exact-once tests for every sequence. |
| Command logic remains duplicated between old and new components. | Complete registry consolidation before building presenters; remove handler properties from visual components during legacy cleanup. |
| Custom menu looks modern but is not operable without a mouse. | Treat the keyboard state machine and accessibility contract as exit criteria before visual polish. |
| Popup is clipped by the title bar or placed on the wrong monitor. | Use window overlay popup hosting and available-screen geometry; test mixed-DPI multi-monitor edges. |
| Frameless drag areas intercept menu clicks. | Partition explicit interactive and drag zones; add hit-testing integration tests at their boundaries. |
| macOS application-role items appear in the wrong menu after translation. | Set explicit Platform `MenuItem` roles rather than relying on text matching. |
| A user selects Native on an unsupported platform and thinks the setting is ignored. | Preserve configured intent, show resolved/active styles and the fallback reason, and never silently rewrite the preference. |
| Welcome and workspace windows dispatch native commands to the wrong context. | Use window-scoped registry instances and native presenters; test focus/hide/show lifecycle. |

## 12. Expected file impact during implementation

Tentative paths; final naming should follow the repository's review conventions:

- **Backend, new**
  - `app/infrastructure/system/desktop_environment.py`
  - `app/core/menu_presentation.py`
- **Backend, modified**
  - `app/core/settings.py` if persistence helpers remain centralized
  - `app/app_facade.py`
  - `app/main.py`
- **QML, new**
  - `app/UI/qml/shared/MenuDefinition.qml`
  - `app/UI/qml/app/NativeGlobalMenuBar.qml`
  - `app/UI/qml/app/ModernMenuBar.qml`
  - `app/UI/qml/app/ModernMenuPopup.qml`
  - focused menu item/separator/submenu delegates under `app/UI/components/`
- **QML, modified**
  - `app/UI/qml/shared/CommandRegistry.qml`
  - `app/UI/qml/app/Main.qml`
  - `app/UI/qml/app/Welcome.qml`
  - `app/UI/qml/app/StatefulWindow.qml` only if a reusable presenter host/window lifecycle hook is necessary
  - `app/UI/qml/content/SettingsView.qml`
  - `app/UI/qmldir`
  - Theme/AppAssets files for new tokens and action icons
- **Retired after parity**
  - `app/UI/qml/app/WorkspaceMenuBar.qml`
- **Tests/docs**
  - Python detector/policy tests
  - QML registry and both-presenter harnesses
  - updates to existing smoke and contract tests
  - `docs/SHORTCUTS.md`, `docs/UI_COMPONENTS.md`, and architecture/function-map references

## 13. Definition of done

The Dynamic Menu Bar is complete when:

- All menu commands and application shortcuts derive from the centralized registry and have stable IDs.
- Native and custom presenters expose the same applicable commands, state, and dispatch behavior.
- Auto selects native global on macOS and capable KDE/Plasma sessions, and custom on Windows/GNOME/unsupported sessions.
- The three Appearance choices persist, show their resolved result, and fall back safely with a reason.
- Native menus use explicit macOS roles and work across Welcome/workspace focus changes.
- The custom menu occupies the existing title-bar height, has correct hover/shadow/icon/shortcut styling, and never overlaps drag or caption regions.
- Pointer, keyboard, accessibility, localization, high-contrast, high-DPI, multi-monitor, and narrow-window acceptance tests pass.
- No command is invoked twice, no platform can end up without a menu, and no QML/native-menu warnings remain in normal lifecycle tests.
- The legacy `WorkspaceMenuBar` action definitions are removed or reduced to a time-bounded compatibility wrapper.
- Documentation records the Auto matrix, override behavior, restart requirement, KDE registrar prerequisite, and fallback behavior.

## 14. Future extensions

After the first release is stable:

- Validate and optionally enable live presenter switching.
- Add an independent Window Frame Style setting, following the separation used by VS Code and Obsidian.
- Add Edit/Window menus with real focus-aware commands and standard platform semantics.
- Feed the same registry into a searchable command palette and toolbar customization.
- Support dynamic feature/plugin command contributions through a validated Python `QAbstractListModel` or equivalent catalog, while retaining window-scoped runtime actions.
- Add user-rebindable shortcuts with conflict detection and native display formatting.
- Share the modern popup primitives with selected context menus only after semantics and accessibility match.
