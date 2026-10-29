# StarDock

A native Omarchy / Quickshell dashboard concept with swappable panels with live weather, radar and an RSS reading room.

## Install on Omarchy

Requires the Omarchy shell components, Quickshell and Python 3. Clone the source and install the launcher:

```sh
git clone https://github.com/vandrare/StarDock-desktop.git
cd StarDock-desktop
./install.sh
```

For Email and Calendar, install the exact checksum-verified backend pinned by the embedded source:

```sh
XDG_DATA_HOME="$HOME/.local/share/starlink-dashboard/mail/runtime-data" \
  /usr/bin/python3 vendor/omamail/scripts/backend-runtime.py install
```

The dashboard does not automatically pull upstream source or update its backend. Embedded mail/calendar source is included directly, with local changes and license notices, rather than downloaded on launch. Saved accounts and personal data are outside this repository.

Launch **StarDock** from the application launcher, or run:

```sh
~/.local/bin/stardock
```

The window starts tiled. Use **Super+Alt+F** for a maximized view or **Super+F** for fullscreen. The top toolbar contains Settings, About, and Close icons.

## Panels and reading room

Click a summary card to swap it with the main detail panel. Wide windows use a two-thirds detail area and a one-third summary column. Narrow windows put the summaries below the main panel. Notes has a scrolling title list in the left column and a title field plus a full-height editor on the right. New note and Delete manage the list. Titles and plain-text content save automatically to `~/.config/starlink-dashboard-notes.json`, including line breaks. The title list reserves a 24px scrollbar gutter.

The bottom reading room now loads real RSS and Atom feeds. The first default entry is:

`https://www.jpost.com/rss/rssfeedsfrontpage.aspx`

Article cards show a larger title, the article's publication date in your local time zone, a feed-provided summary, and the publisher. Dates missing from the feed display as unavailable. Click a card to open its reading popup. When the feed supplies an image, it appears below the publisher/date line on the left third of the content area, with the article text wrapping to its right and continuing across the full width below the image. The popup height fits its content and expands for longer articles, with scrolling once it reaches the available window height. Equal-width Open original article and Close buttons share one responsive bottom row. The popup width defaults to 33% of the current screen’s available width and can be adjusted from 20–100% in Appearance settings. Images load only for the open article, keep their aspect ratio, align to the top without an image border, and disappear on a loading error so the text can use the full width.  **Open original article** launches the publisher's page in your browser. The popup includes the text supplied by the feed, which may be an excerpt rather than the full article. RSS settings also provide a maximum word count (default 300; 0 means no word limit). When the content is longer than this limit, it ends with ` ...<more>` and “more” links to the original article. This setting shortens only the displayed popup; the fetched content remains available if the limit is increased.

Automatic scrolling loops the articles at the configured speed. It pauses while the pointer is over the feed, while manually dragging the list, and while a dialog is open. A speed of zero pauses automatic scrolling. The feed refreshes every ten minutes; its refresh icon requests an immediate update. If a refresh fails, available stories from the current session remain visible with an error status.

## Settings

Settings has independently expandable **Modules**, **Appearance**, **Weather** and **RSS news feeds** sections. All sections start collapsed.

- Modules: enable 3–4 of Overview, Weather, Calendar, Notes and Email. Email starts disabled. Its Omamail integration provides account setup, inbox/folder navigation, search, refresh, a sanitized HTML/reading/plain-text message reader and clickable unread previews. Disabled modules disappear from the panels; two or three summary cards share the available sidebar space evenly.
- Appearance: optional background, text and accent overrides; text size; article popup screen width (default 33%); Reset appearance to theme. Empty color fields inherit Omarchy's active palette.
- Weather: search for a city or postal code and select a matching location; choose °F/°C independently of imperial/metric wind and precipitation units, refresh interval and map zoom. Phoenix is the initial location.
- RSS news feeds: add/remove up to ten feeds, enter each feed URL, set 1–50 articles per feed, and choose a global scrolling speed from 0–150 pixels per second, and set the maximum words shown per article.
- Apply saves changes to `~/.config/starlink-dashboard-demo.json`. Cancel discards the draft. Resetting appearance leaves RSS settings intact.

The app follows your active Omarchy colors and configured font family and rechecks the theme files every two seconds. It does not modify the desktop theme or shell. Weather uses Open-Meteo for current conditions and seven-day forecasts, OpenStreetMap for the basemap, and NOAA/NWS for U.S. radar and alerts. The expanded Weather panel places conditions and the forecast in a 25% left column and the map in a 75% right column; narrow panels stack them. Radar animates roughly the past hour of NOAA reflectivity over the contiguous U.S., with play/pause, Slow/Normal/Fast playback, local frame timestamps, refresh and zoom controls. The map aligns to the top of its column, with controls directly below. Other U.S. regions, or an unavailable animation service, use the latest static radar image. Forecasts and basemaps work worldwide; NOAA radar and NWS alerts are limited to U.S. locations. Map assets and forecasts are cached locally. Calendar uses Omamail for connected calendars and event details; Overview shows live summaries of enabled modules. RSS requests go only to configured feeds and their redirects. Weather and RSS require no account or API key, and feed scripts are not loaded. Feed-supplied article images load when their popup is opened.

## Email

Enable Email in Modules, expand its summary card, then choose **Connect a mailbox…**, or use **Settings → Email → Accounts → + Account…**. The sign-in screens come from a locally adapted checkout of Omamail **v0.11.1** (commit `a047aa24f52363fd3a20179e83483e956a0b069f`). That release pins backend **0.11.0 / API 7**; the dashboard installs that exact verified backend in a private runtime directory. The installed Omamail plugin and its customizations remain untouched.

Gmail and Outlook personal use their provider-specific OAuth setup; IMAP and JMAP use the corresponding password/token setup. HEY uses the upstream HEY CLI flow. Microsoft 365 needs API 8, which this release's pinned backend does not provide; selecting it explains that limitation. The dashboard does not substitute a development backend.

Email supports adding/configuring accounts, selecting accounts and folders, searching, refreshing, loading more messages and reading messages. Clicking an unread preview expands Email and opens that message. Opening a message follows Omamail's normal mark-read behavior. The reader offers sanitized Reading, Formatted and Plain text modes; remote images remain blocked until approved. The second phase adds Compose, Reply, Reply all, Forward, Cc/Bcc/Reply-To, attachment picking and drag/drop, incoming attachment open/download, and editable provider-saved drafts. The compose form uses Omamail's own sender, recipient, MIME and native outbox handling. Send enters the default ten-second undo window; **Undo send** restores the draft. Failed sends restore their draft instead of silently losing it. Archive/Move to Inbox, Move to trash/Restore, read/unread and star actions follow the provider's capabilities and the selected folder; trash never permanently deletes mail.

Open drafts survive panel swaps, save local recovery automatically, and restore after restarting. The app flushes recovery before closing or disabling Email; if saving fails, Email stays available with the error. Leaving an edited composer offers Save draft, Discard or Cancel. Saved drafts can be reopened with **Edit draft…** in the Drafts folder. Delivery receipts are reconciled before recovering a queued send so an already-sent message is not reopened as a retry.

Mail account configuration, cache and state use dashboard-only XDG roots beneath `~/.config/starlink-dashboard/mail`, `~/.cache/starlink-dashboard/mail` and `~/.local/state/starlink-dashboard/mail`. Passwords and tokens use Omamail's system-keyring implementation. Do not enter passwords into dashboard JSON settings. No mailbox is configured automatically; sign in through the Email panel.

The private backend can be installed or checked again with:

```sh
XDG_DATA_HOME="$HOME/.local/share/starlink-dashboard/mail/runtime-data" \
  /usr/bin/python3 "$HOME/projects/starlink-dashboard-demo/vendor/omamail/scripts/backend-runtime.py" install
```

`Commons` and `Ui` link to the installed Omarchy shell's shared QML components, which are read without modification. Third-party source attribution is in `THIRD_PARTY_NOTICES.md`; the upstream MIT license is retained in `vendor/omamail/LICENSE`.

## Files

- `EmailPanel.qml`, `EmailComposer.qml`, `EmailService.qml`: mail panel and isolated Omamail service adapter.
- `scripts/mail-backend`, `scripts/mail_store.py`: private mail process environment and preference writes.
- `Dashboard.qml`: panels, toolbar, reading room and dialogs.
- `SettingsEditor.qml`: accordion settings and feed list editor.
- `WeatherPanel.qml`, `WeatherSettings.qml`, `Weather.js`: live conditions, radar, forecast and weather preferences.
- `scripts/fetch_weather.py`: Open-Meteo location search/forecasts and cached OSM/NOAA map assets, using system Python only.
- `Config.js`: shared settings defaults and normalization.
- `shell.qml`: native window, theme reader, configuration persistence and RSS refresh orchestration.
- `scripts/fetch_rss.py`: bounded RSS/Atom retrieval and plain-text extraction, using system Python's standard library.
- `tests/`: Qt interaction tests and Python parser tests.
- Desktop launcher: `~/.local/share/applications/stardock.desktop`.

## Verify

```sh
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_CONTROLS_STYLE=Basic \
  /usr/lib/qt6/bin/qmltestrunner -input tests
/usr/bin/python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Mail panel interaction fixture (synthetic messages, no mailbox access):

```sh
quickshell -n -d -p "$HOME/projects/starlink-dashboard-demo/mail-panel-test.qml"
quickshell ipc -p "$HOME/projects/starlink-dashboard-demo/mail-panel-test.qml" call mailtest exercise
quickshell ipc -p "$HOME/projects/starlink-dashboard-demo/mail-panel-test.qml" call mailtest verify
quickshell kill -p "$HOME/projects/starlink-dashboard-demo/mail-panel-test.qml"
```

Full synthetic phase-two workflow suite (does not send or modify real mail):

```sh
/usr/bin/python3 scripts/test_mail_panel.py
```

### Calendar integration

Calendar now reuses the pinned Omamail v0.11.1 calendar controller and native month, week, day and agenda views. Open **Calendar → Connections** to enable calendars for a compatible signed-in account or add a CalDAV source. Google Calendar may request additional consent when enabled; an IMAP mailbox alone does not supply a calendar. Accounts and calendar sources use the dashboard's private Omamail configuration and system keyring. Microsoft 365 remains unavailable with the upstream release's pinned API 7 backend.

The left quarter contains source controls; the right three quarters contain the calendar and event details. The sidebar shows the next three upcoming or ongoing events within the next 31 days; clicking an event opens its details. A separate calendar controller supplies this summary, so changing the displayed month does not change the upcoming list. Calendar keeps the shared account service running even when the Email module is disabled.

Calendar supports creating and editing events, all-day and repeating events where the provider supports them, drag rescheduling, and confirmed deletion. The native Omamail controller enforces read-only sources, recurring-event limitations, calendar ownership and backend capabilities. Undo is available for changes that Omamail can reverse; deletion uses a confirmation that names the event and explains series/guest notification choices when applicable. Successful writes refresh the sidebar summary. Switching panels retains an open event editor. Closing the app or disabling Calendar prompts before discarding an unsaved event and waits for event writes to finish. Shared mail/calendar account settings are now available from Calendar’s Settings button, Settings → Email → Accounts, and the Calendar settings accordion. Connection changes and source visibility are saved by the upstream controller.

Calendar regression checks: `python3 scripts/test_calendar_panel.py` exercises all four native views, event details, connection UI, creation/editing, all-day recurrence, invalid dates, failed saves, confirmed deletion, undo, read-only sources and unsaved editor guards with synthetic data. The Qt dashboard tests also cover summary ordering, limiting, clickable navigation and use with Email disabled. Neither test modifies real events.


### Calendar preferences and reminders

Open **Settings → Calendar** for the starting view, Sunday/Monday week start, calendar date/time formats, default event duration, new-event time-zone metadata, desktop reminders and snooze duration. Apply saves these privately in `~/.config/starlink-dashboard/mail/omamail/dashboard.json`; Cancel leaves the preference draft unchanged. Calendar grids and entered times use the desktop time zone. A selected IANA event zone supplies metadata (for example Google recurrence rules), and does not change the grid's zone or reinterpret entered times. Existing events retain their time-zone metadata when edited.

**Accounts & calendars…** opens Omamail's shared settings for mailbox setup, account names/signatures, OAuth setup, default calendars, source colors/visibility and per-calendar reminder timing. These controls save their changes directly, as in Omamail. Removing an account first saves an open mail draft and checks for an unsaved calendar event. Account settings survive a restart; OAuth secrets and calendar passwords continue to use the upstream private storage and keyring. Theme palette colors supply the calendar color choices while the dashboard accent override remains effective.

The pinned Omamail v0.11.1 release supports desktop reminders for **Google Calendar sources only**. Other providers retain their existing event features. Reminders run while the dashboard account service is running (Email or Calendar enabled); the app must remain open. Per-calendar policies choose the calendar's reminder defaults or an explicit number of minutes. Desktop notification actions and the in-app reminder list support opening the event, snoozing and dismissing. The backend persists reminder state; failed actions leave the reminder available for retry. Opening a reminder with Calendar disabled explains how to enable the module. Notifications stay off until enabled by the user.

The upstream calendar UI has small local patches to expose week start, date/time formats, event duration and time-zone defaults, respect a preferred manual calendar, and retain semantic accent overrides when loading the theme palette. Backend/API pins are unchanged. Synthetic checks cover preference application, reminder actions/failures and private file round trips without sending real notifications or changing real events.


### HTML email reading

The Email module embeds Omamail's message reader while retaining the dashboard's sender/date line and icon actions. The bottom view controls select **Reading** (theme-styled content), **Formatted** (sanitized sender layout), or **Plain text**. Reading is the initial default; view mode and zoom use Omamail's private window preferences. Text-only mail and documents too expensive to lay out fall back to plain text. Attachments use the reader's expandable list.

Remote images are blocked unless approved. **Load images** grants permission for the current message only; switching messages starts with images blocked again unless the user enabled **Always show remote images** under **Settings → Email**. That shared settings page also exposes heavy-message rendering and content direction. Sender image URLs never go directly to Qt: Omamail's backend and protected image-fetch helper supply prepared raster data, with DNS, redirect, size and deadline checks. Existing explicitly saved image preferences are respected.

HTTP(S) links pass through Omamail's external-link checks. Mail links create an unsent compose draft, preserve line breaks in its body and do not replace an already open draft. The dashboard does not evaluate scripts or embed a browser. This uses Qt's supported rich-text layout; browser-only email CSS may differ from a webmail view.

`python3 scripts/test_mail_reader.py` checks all reading modes, malicious resource URLs against a controlled loopback server (zero requests), per-message consent, heavy/text fallbacks, checked links and unsent mailto draft ownership using only synthetic messages. Existing composition, attachments, send/undo and calendar tests remain separate fixtures. Security: PASS for the exercised resource blocking, link and draft-ownership boundaries; live remote-image delivery is not exercised by these synthetic checks.


### Live Overview

Overview summarizes the enabled Weather, Calendar, Email and Notes modules. Weather shows current conditions, precipitation probability and active alerts. Calendar shows today's event count, remaining events and the next upcoming or ongoing appointment (including one after today). Email shows the unread total and the three recent unread messages supplied by Omamail. Notes shows the three most recently edited notes and their first text line. Headers open the module; individual events, messages and notes open their corresponding detail. Disabled modules are omitted.

**Settings → Overview** controls summary visibility and order with switches and up/down buttons. Apply saves the draft; Cancel leaves the prior arrangement. Cards stack on narrow panels and use two columns when space permits. Overview and the sidebar use the current theme colors and text scale, and empty/loading states replace demo text.

The email message body's default base text now matches message-list titles at 12 px times the app's text scale. Explicit zoom remains available; sender-defined heading/style sizes in Formatted mode are preserved.

### Backup & restore

Settings has a separate **Backup & restore** accordion. Save its location, daily/weekly schedule and retention with **Save backup settings**. Automatic backups default to Off, run while the dashboard is open, and catch up at the next launch. The default folder is `~/.local/share/starlink-dashboard/backups`; snapshots are private JSON files (mode 0600), not encrypted.

Snapshots include notes, dashboard configuration, mail/calendar preferences, calendar source metadata and account names/signatures/monitored folders. They exclude passwords, OAuth credentials, account connection definitions, message caches, outgoing drafts and attachments. Notes/signatures can contain private content. Feed/calendar URLs containing credentials, query strings or fragments are omitted. Only snapshots recognized as this app's format in the selected folder are subject to retention.

Select a snapshot or browse to one, preview the affected categories, then confirm **Restore and restart**. The app saves pending edits, closes the backend and restores offline. A safety snapshot is created before replacing files; failed writes roll back earlier writes. A changed snapshot requires a fresh preview. Existing connections and credentials remain; account metadata is merged only for matching IDs, so a new machine requires reconnecting accounts. Remote mail images start blocked again. Retention also applies to safety snapshots. No restore of real user data is performed by the tests.

StarDock retains the existing `starlink-dashboard` storage paths and project directory for compatibility with saved notes, accounts, credentials and backups. The former `starlink-dashboard-demo` command forwards to `stardock`.

## Email preferences

Open **Settings → Email** to set the mail-check interval (30–3600 seconds; default 120), desktop notifications (default Off), and always showing remote images (default Off). These controls save with Apply; Cancel discards edits. Mail notifications require `notify-send` (Arch package `libnotify`) and a running desktop notification service. Notifications include the sender and subject, run only while StarDock is running with Email enabled, and open the correct account/message when Read is selected. Sender text is escaped as plain notification content and is never interpreted as command options or shell code. Notification delivery errors appear in the Email settings.

**Account signatures…** opens the existing per-account signature editor directly. Signatures save separately when focus leaves the field, including when switching accounts. Plain and imported formatted signatures keep the existing sanitizer and compose behavior. Remote images can still be approved per message without changing the standing preference. The shared account settings remain available from Email and Calendar.

Native Email preference persistence and notification routing can be checked with `python3 scripts/test_mail_settings.py`. This requires bubblewrap, Quickshell and the installed pinned backend; it copies source and that binary into a temporary profile, keeps your HOME value unchanged inside a private filesystem view, and uses synthetic notifications instead of contacting real accounts. `python3 -m unittest discover -s tests -p 'test_*.py'` covers notification argument and markup handling.

## Fullscreen layout and RSS visibility

Appearance includes **Fullscreen summary column width** (20–35%, default 33%). The main content uses the remaining width; narrow windows keep their stacked layout. Modules includes an independent **RSS News Feeds** switch, which does not count toward the three-to-four panel limit. When disabled, RSS fetching and scrolling stop, and the module panels expand into the available height. Feed URLs and article settings are retained. Both options save with Apply and are included in backups. The RSS article popup has a soft drop shadow.

Account creation, shared account settings and signatures are grouped under **Settings → Email → Accounts**. Compose is an icon beside the message actions above the reader; in the compact list-only layout, its icon remains available beside Refresh.

Appearance also includes independent base font sizes for email bodies (default 14 px, 10–24), notes (14 px, 10–24), sidebar summaries and the message list (12 px, 10–18), RSS popup text (14 px, 10–24) and RSS headlines (15 px, 12–22). Each offers **Use default** and a live preview. Global text scale multiplies these sizes; mail's existing zoom remains an additional adjustment and HTML headings retain their proportions. Apply saves changes, Cancel discards edits, and Reset appearance clears the overrides. The font overrides are included in backups.

Appearance's **Popup appearance** controls are shared by app dialogs and confirmations, including RSS, Settings, account setup, mail drafts and calendar deletion. Shadow size is 0–64 px (default 20; 0 turns shadows off). Shadow color accepts `#RRGGBB` or `#AARRGGBB` (default black). Background dimming is 0–100% opacity (default 35%; 0 disables darkening). The preview updates while editing; Apply saves, Cancel discards, and Reset appearance restores defaults. Popup surfaces share the active theme background, border and rounded corners. Native operating-system file/folder pickers retain their system styling.

### Restore verification

Run `python3 scripts/test_backup_restore.py` on an Omarchy desktop with bubblewrap installed. The test copies the current source into a private filesystem profile, installs temporary launchers, and exercises backup, preview, save/quit, offline restore and relaunch. It verifies multiline notes, appearance settings, the safety snapshot and remote-image blocking. A test-only write failure in the copied helper verifies rollback, failure reporting, ticket cleanup and relaunch. Real notes, accounts and launchers are not modified. Synthetic light, dark and narrow screenshots are saved as `/tmp/stardock-release-*.png`.

Run `python3 scripts/test_fresh_install.py` to clone the current GitHub main branch into a temporary folder and test the installer, checksum-verified backend download, command and desktop launchers, single-instance behavior, relaunch, RSS, weather and radar in an empty private profile. This requires network access, bubblewrap and a running Omarchy desktop. It does not connect real accounts.
