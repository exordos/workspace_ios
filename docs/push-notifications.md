# Apple push notifications

Workspace uses the saved, signed-in project and its authenticated user to
register a native APNs token and a separate X25519 push public key. The
private key stays in the device-only Keychain. APNs is enabled for
installations advertising `apns_push_notifications_enabled`.

Use the build setting `WORKSPACE_APNS_ENVIRONMENT` that matches the
signed `aps-environment` entitlement. Debug defaults to `development`
and registers `apns_sandbox`. Release defaults to `production` and
registers `apns`. Keep the bundle identifier and verify both values in
the signed artifact when changing the signing configuration.

iOS displays a generic Workspace alert. The message preview travels
inside HPKE ciphertext. HPKE associated data binds the routing IDs
to the registered recipient.
The app authenticates the envelope on tap, then reads the stream, topic
and message from Workspace under the current account before navigating
to the message. A silent read update removes matching older delivered
alerts when iOS schedules the app to receive it.

For device acceptance, use a Workspace installation with the APNs
producer and Notification transport enabled. On a development-signed
iPhone, grant notifications, receive an alert while the app is
backgrounded and tap through to the expected message. Verify that a
muted topic stays quiet and that logout retires the device registration.
If the server is unreachable on logout, the local key is removed
immediately and server-side removal requires a successful connection.
