# Third-party notices

This dashboard embeds locally adapted source from [Omamail](https://github.com/huacnlee/omamail), release **v0.11.1**, commit **a047aa24f52363fd3a20179e83483e956a0b069f**.

Omamail is Copyright (c) 2026 Jason Lee <huacnlee@gmail.com> and licensed under the MIT License. The full license and copyright notice remain in [vendor/omamail/LICENSE](vendor/omamail/LICENSE). Its pinned native backend is 0.11.0, API 7, installed using the release's checksum-verifying installer. Its source and dependency license information remain in the upstream checkout.

`EmailComposer.qml` adapts the compose recovery/send lifecycle glue from upstream `ui/App.qml`, with the same MIT attribution. Upstream compose, recovery, provider, attachment and native mail implementations are reused from the checkout.

The `Commons` and `Ui` QML components are supplied by the locally installed Omarchy shell; symlinks reference those components without changing them.

The Calendar module also reuses Omamail’s calendar source management, controller, calendar views and event detail UI from the same pinned checkout. The event editor and deletion confirmation also reuse the pinned Omamail components. Dashboard-specific summary handling and unsaved editor exit guards are outside the vendor tree.

Local calendar UI patches expose week-start and date/time preferences, default event duration/time-zone metadata, preferred manual calendars, semantic accent handling, and optional reading controls for embedding hosts. Shared account settings and reminder components are reused from the same Omamail release; the backend pin is unchanged.

The Email module embeds Omamail’s MessageReader and reuses its sanitized document layout, image policies, context menus and attachments. Local optional properties hide duplicate chrome and offer current-message image approval; The dashboard service host delegates that approval to the existing account method. Mailto draft integration uses the upstream parser.

The embedded dashboard presents the mail integration as StarMail. Local presentation copy and the service display name use this branding; upstream identifiers, storage paths, backend pins and license notices remain intact.
