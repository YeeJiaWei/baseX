# Notification Payload — JSON structure

The JSON the backend sends so `PushNotifications` and `NotificationLinks` can
show, track and route a push notification.

```
 backend
    |
    |  notification{title, body}  +  data{payload}
    v
 push (FCM or Huawei)
    |
    v
 PushNotifications  -->  PushMessage.payload (type, link, deliveryId, params)
    |
    v
 NotificationLinks.handleEvent(type, params: params, link: link)
    | no event route handles the type
    v
 NotificationLinks.handle(link)
```

## Providers and tokens

Each device token belongs to a provider, sent with the registration
(`PushRegistration.provider`: `fcm` or `hms`). The backend stores the provider
next to the token and sends through that provider's API: FCM for `fcm`, Huawei
Push Kit for `hms`. Android phones with Google services (including older Huawei
phones) register `fcm`; Huawei phones without Google services register `hms`.
The same payload is sent either way; only the envelope differs.

## Push message (FCM)

```json
{
  "message": {
    "token": "<device token>",
    "notification": {
      "title": "Your order has shipped",
      "body": "Order #1042 is on its way."
    },
    "data": {
      "payload": "{\"type\":\"ORDER_SHIPPED\",\"link\":\"orders/1042\",\"delivery_id\":\"0190a3b2-7c4d-7e8f-9a01-b2c3d4e5f607\",\"params\":{\"order_id\":1042}}"
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

## The `payload` object

baseX reads one fixed key from `data`: `payload`. Its value is the object
below. The key name is a constant in baseX and cannot be configured.

| Field | Required | Type | Value | Used by |
|---|---|---|---|---|
| `type` | yes, for event routing | string | `UPPER_SNAKE` event type, e.g. `ORDER_SHIPPED` | event routes, `lastMessageType` |
| `link` | optional | string | plain path, e.g. `orders/1042` (no scheme; a leading `/` is allowed) | path routes, used when no event route handles the type |
| `delivery_id` | optional | string | unique per device send | tap dedup (the default `PushHandler.messageKey`) |
| `params` | optional | object | values with their real JSON types, e.g. `{"order_id": 1042}` | event routes (`require`, `aliases`) |

`type`, `link` and `delivery_id` must be JSON strings: a number is dropped with a warning, so a numeric `delivery_id` silently loses tap dedup.

### Rules

- **`data` values must be strings, so `payload` is a JSON string.** FCM rejects
  non-string `data` values. Serialise the whole object into one string under
  the single key `payload`. Inside that string the values keep their real
  types: send `1042`, not `"1042"`.
- **`link` is a plain path.** Write `orders/1042`, not `shop://orders/1042`. A
  client may opt in to a scheme (`NotificationLinkConfig.scheme`); only then are
  `scheme://path` links accepted as well.
- **`params` carries real JSON types.** Numbers, booleans, nested objects and
  arrays are allowed. `LinkParam.int` accepts a real int and a numeric string.
- **Other `data` keys belong to the app.** baseX passes them through untouched
  in `PushMessage.data`.
- **A missing or malformed `payload` never throws.** The message arrives with an
  empty payload and a warning is logged; the notification itself still shows.
- **Always send `link`, even when an event route handles the type.** An older
  app version without that event route still routes through the link.
- **Never change a link path in place.** Installed old versions still receive
  pushes. Add the new path, keep the old one as a client route (or a
  `{kind:old|new}` alias) until no supported version needs it.
- **New types are additive.** A client that doesn't know a type falls back to
  `link`, then to `onUnknown`. Never reuse a retired type name for something
  else.
- **No secrets or personal data.** Payloads show up in device logs and crash
  reports. Send ids; the app fetches details through the API.
- **Stay under 4 KB** for the whole message (FCM limit). Ids, not content.
- **Reserved `data` keys:** don't use `from`, `notification`, `message_type`,
  `collapse_key`, or anything starting with `google.` or `gcm.`.

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
| `apns.payload.aps.badge` | App icon badge — the unread count |
| `android.priority: high` | Needed for timely delivery when the device is idle; use only for user-visible pushes |

## Push message (Huawei Push Kit)

For tokens registered with provider `hms`, the same payload goes through the
Push Kit `messages:send` API.

> **Verify against the Huawei Push Kit REST docs before relying on any Huawei
> field below** — the `messages:send` shape, the token array, `data` as one JSON
> string, `android.urgency`, the integer `collapse_key`, `click_action.type: 3`,
> the 4 KB limit and the claim that a tap without `click_action` never reaches
> the app. They were written from memory of the API, not checked against it.

```json
{
  "validate_only": false,
  "message": {
    "token": ["<device token>"],
    "data": "{\"payload\":{\"type\":\"ORDER_SHIPPED\",\"link\":\"orders/1042\",\"delivery_id\":\"0190a3b2-7c4d-7e8f-9a01-b2c3d4e5f607\",\"params\":{\"order_id\":1042}}}",
    "android": {
      "urgency": "HIGH",
      "collapse_key": 1,
      "notification": {
        "title": "Your order has shipped",
        "body": "Order #1042 is on its way.",
        "channel_id": "orders",
        "tag": "order-1042",
        "click_action": { "type": 3 }
      }
    }
  }
}
```

| FCM | Huawei |
|---|---|
| `data` map whose `payload` value is a JSON string | `data` is **one JSON string** holding `{"payload": {...}}`; the object is nested directly, though a JSON string value is accepted too |
| `notification.title` / `body` | `android.notification.title` / `body` |
| `android.notification.channel_id` | `android.notification.channel_id` |
| `android.notification.tag` | `android.notification.tag` |
| `android.collapse_key` (string) | `android.collapse_key` is an integer; map each collapse group to one |
| `android.priority: high` | `android.urgency: HIGH` |
| tap opens the app by default | set `android.notification.click_action.type` to `3` (open the app); without it a tap reportedly does not reach the app, so `onOpened` never fires (verify) |

The notification-opened event hands the client the intent extras and the
message; the client merges them with the decoded `data` and reads `payload`
exactly as for FCM. The no-secrets rule applies to the whole message, and so
does a size limit (4 KB assumed; verify Huawei's).
