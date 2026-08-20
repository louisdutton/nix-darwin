# Essentials Push Gateway

This is the suite's small, data-free invalidation gateway. Application data is
stored through standard WebDAV, CalDAV, or CardDAV services; this process only
stores per-device Web Push subscriptions and publishes namespace wake-ups.

Import `nixos-module.nix`, then configure `services.essentialsPushGateway`.
Device credentials are shared with the WebDAV provisioning flow: the device
label is the WebDAV username and its secret is both the DAV password and the
gateway bearer token. The separate identity registry supplies the user and
group membership without placing secrets in the Nix store.

Authenticated clients use `/v1/push/vapid`, `/v1/push/subscriptions/<device>`,
and `/v1/push/invalidate/<namespace>`. Standard services such as Radicale call
the separately authenticated `/internal/v1/invalidate` hook after a durable
mutation. Notifications contain only a namespace hint; clients still reconcile
against their authoritative DAV server using ETags.

The NixOS service runs as `essentials-push`, stores subscriptions under
`/var/lib/essentials-push`, and migrates existing subscriptions from the former
service on first start. Run `go test ./...` to verify authentication,
device binding, registration, and delivery.
