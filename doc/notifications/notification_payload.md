# Notification Payload — JSON structure

> **Status: proposed.** Nothing below is implemented yet. This is the design to
> review before the build starts.

The JSON the backend sends so `PushNotifications` and `NotificationLinks` can
show, track and route a notification. The same fields go into the push
message and into the inbox row, so a push tap and an inbox tap route the same
way.

```
 backend
    |
    |  type, title, body, link, ids   (same values in both)
    +--------------------+
    v                    v
 push (FCM)          inbox row (DB + API)
 notification{}      type, title, body,
 data{} strings      link, ids, read_at
    |                    |
    v                    v
 PushNotifications   inbox page
    |                    |
    +--------+-----------+
             v
   NotificationLinks.handleEvent(type, data)
             | no event route
             v
   NotificationLinks.handle(data.link)
```

## Push message

```json
{
  "message": {
    "token": "<device token>",
    "notification": {
      "title": "Your order has shipped",
      "body": "Order #1042 is on its way."
    },
    "data": {
      "type": "ORDER_SHIPPED",
      "link": "shop://orders/1042",
      "notification_id": "9f1c2e4a-0d6b-4c51-9a63-1b2f0e7d8c11",
      "delivery_id": "0190a3b2-7c4d-7e8f-9a01-b2c3d4e5f607",
      "order_id": "1042"
    },
    "android": {
      "priority": "high",
      "collapse_key": "order-1042",
      "notification": { "channel_id": "orders", "tag": "order-1042" }
    },
    "apns": {
      "headers": { "apns-collapse-id": "order-1042" },
      "payload": { "aps": { "sound": "default", "badge": 3 } }
    }
  }
}
```

### `data` fields

| Key | Required | Value | Used by |
|---|---|---|---|
| `type` | yes | `UPPER_SNAKE` event type, e.g. `ORDER_SHIPPED` | event routes, `lastMessageType` |
| `link` | yes for tappable notifications | `<scheme>://<path>`, e.g. `shop://orders/1042` | path routes (fallback when no event route matches) |
| `notification_id` | when an inbox row exists | inbox row id | mark the row read on open |
| `delivery_id` | when delivery is tracked | unique per device send | `PushHandler.messageKey` (dedup), `onReceipt` |
| `<entity>_id` | per type | flat scalar ids, `snake_case`, e.g. `order_id` | event routes (`require`) |

The key names `link` and `delivery_id` are defaults. An existing backend that
already sends other names maps them on the client (`NotificationLinkConfig.linkKey`,
`PushHandler.messageKey`) instead of renaming server fields.

### Rules

- **Every `data` value is a string.** FCM rejects non-string values. Send
  `"1042"`, not `1042`; `LinkParam.int` parses it back on the client. No
  nested objects or arrays — flatten to `<entity>_id` keys.
- **Always send `link`, even when an event route handles the type.** An older
  app version without that event route still routes through the link.
- **Never change a link path in place.** Installed old versions still receive
  pushes. Add the new path, keep the old one as a client route (or a
  `{kind:old|new}` alias) until no supported version needs it.
- **New types are additive.** A client that doesn't know a type falls back to
  `link`, then to `onUnknown`. Never reuse a retired type name for something
  else.
- **No secrets or personal data in `data`.** Payloads show up in device logs
  and crash reports. Send ids; the app fetches details through the API.
- **Stay under 4 KB** for the whole message (FCM limit). Ids, not content.
- **Reserved keys:** don't use `from`, `notification`, `message_type`,
  `collapse_key`, or anything starting with `google.` or `gcm.` in `data`.

### `notification` block

Send `notification.title` / `notification.body` for anything the user should
see — the OS shows it when the app is in the background or killed. Send a
data-only message (no `notification` block) only for silent refreshes; those
are not shown, are throttled by iOS, and are not tappable.

### Platform options

| Option | Purpose |
|---|---|
| `android.notification.channel_id` | Must match a channel the app creates; one per category (`orders`, `chat`, …) so users can mute by category |
| `android.collapse_key` / `notification.tag` | A newer push for the same entity replaces the old one in the tray |
| `apns.headers.apns-collapse-id` | Same, on iOS |
| `apns.payload.aps.badge` | App icon badge — the unread inbox count |
| `android.priority: high` | Needed for timely delivery when the device is idle; use only for user-visible pushes |

## Inbox row

The inbox API returns the same fields, plus read state:

```json
{
  "id": "9f1c2e4a-0d6b-4c51-9a63-1b2f0e7d8c11",
  "type": "ORDER_SHIPPED",
  "title": "Your order has shipped",
  "body": "Order #1042 is on its way.",
  "link": "shop://orders/1042",
  "data": { "order_id": 1042 },
  "read_at": null,
  "created_at": "2026-10-13T09:30:00Z"
}
```

The inbox is plain JSON, so ids may keep their real types here. The app taps a
row with `NotificationLinks.instance.handleEvent(row.type, {...row.data, 'link': row.link})`.
