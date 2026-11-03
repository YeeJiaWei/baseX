# Request headers

`DeviceHeaderInterceptor` (applied by `DeviceHeaderApiMixin`) adds these to every request,
then merges `baseConstant.additionalHeader` on top.

| Header | Value | Sent when |
|--------|-------|-----------|
| `App-Version` | `appInfo.version` | Always (empty string if `AppInfo` failed to load) |
| `Os-Type` | `deviceInfo.os` | Always |
| `Device-Model` | `deviceInfo.model` | Always (empty string if `DeviceInfo` failed to load) |
| `Device-ID` | `deviceInfo.id` | Only when `id` is not empty |
| `Os-Version` | `deviceInfo.osVersion` | Only when `osVersion` is not empty |

The same interceptor also sets `Accept`, `Label-Version` and `Accept-Language`; those are not
device or app info.

If [`DeviceInfo`](device-info.md) or [`AppInfo`](app-info.md) failed to load, the headers that are conditional on a non-empty value are skipped.
