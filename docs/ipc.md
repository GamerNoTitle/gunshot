# Jailbreak IPC without RocketBootstrap

Gunshot no longer depends on, links or calls RocketBootstrap. This removes the daemon's mandatory `rocketbootstrap_unlock` startup call as well as the old redirected-name and broker lookup code. Rootless and rootful packages keep **libSandy 1.1.6+** and a substrate-compatible injection system. Jailed/LiveContainer builds continue to run the uploader in the host process and require neither IPC library.

## Connection sequence

1. Obtain the calling task's current bootstrap port and look up `dev.tqmane.gunshot.service` directly.
2. If lookup reports denied access (1100) or an unknown service in that namespace (1102), apply the packaged `dev.tqmane.gunshot.ipc` libSandy profile and retry direct lookup. An unrelated lookup error is reported immediately.
3. If profile application succeeds but raw lookup still fails, connect to `dev.tqmane.gunshot.discovery` as a privileged XPC LaunchDaemon service. This allows the libSandy adapter to resolve the daemon through libxpc. Discovery returns its Mach send right only after checking the peer's kernel audit token.
4. Send the existing bounded JSON/Mach request. The daemon checks the caller again for every request, including requests arriving through a discovered port.

The bootstrap port and request reply port belong to each call and are released on completion. Reply ports retain the iOS 16+ `MPO_REPLY_PORT` behavior required by reply-enforcing endpoints. XPC discovery still has a five-second timeout and discards late port-bearing replies safely. Upload RPC message limits and timeouts are unchanged.

## Access boundaries

The root-owned libSandy profile is restricted to **Google Photos and Apple Photos** and only the upload and discovery service names above. It grants the two existing Mach lookup extension classes; it adds no filesystem permissions, wildcard identifiers or access to unrelated services. Profile application failure ends the connection attempt with its own diagnostic code.

Discovery and upload RPC use the existing daemon authorization: mobile UID, signing identifier and expected executable path. Missing identity APIs or an unauthorized peer are rejected. Discovery accepts only a protocol version; callers cannot ask it for arbitrary service names or send upload/account commands through discovery. Removing RocketBootstrap does not relax these checks or change credential storage.

The daemon checks its two services in through launchd and serves requests on its serial worker. Its main run loop remains available for Foundation callbacks and its network/power monitors use their existing queues. No third-party broker initialization is needed for startup.

## Diagnostics and upgrading

`lookup.direct`, `sandbox.profile`, `lookup.authorized`, `discovery.*` and `request.*` report the actual attempted path. There are no current `lookup.redirected`, `lookup.broker` or `broker.*` stages. Those names in older diagnostic files describe a previous implementation, not a missing dependency to reinstall.

Install a build containing this change before removing RocketBootstrap for Gunshot. Older binaries still link it and require it during daemon startup. The updated package removes only Gunshot's dependency; it does not uninstall another package. If other installed tweaks require RocketBootstrap, their dependencies still apply.

If connection fails, export diagnostics from GoToHP settings and check the stage. A running daemon is not sufficient evidence that the app's sandbox can reach it. Keep libSandy and the matching Gunshot profile installed. The upstream [libSandy package metadata](https://github.com/opa334/libSandy/blob/main/control) and [build configuration](https://github.com/opa334/libSandy/blob/main/Makefile) do not declare or link RocketBootstrap.

## Validation

- Real Mach request/reply exchanges with reply-enforcing ports, timeout and repeated right cleanup.
- Production IPC client with direct lookup, profile-authorized lookup and discovery after both denied and unknown-service responses. The fixture rejects every attempted lookup of an unrelated service.
- Missing/provider-restricted libSandy, repeated retry, discovery rejection/timeout, unauthorized RPC, malformed replies and unexpected descriptor cleanup.
- Existing real XPC discovery tests for audit-token authorization, invalid protocol, late replies and send-right lifetime, plus a named launchd service integration test.
- Package checks reject RocketBootstrap dependency declarations, dynamic links, undefined symbols and old broker service names in both the tweak and daemon. Jailed packaging retains its no-jailbreak-library check.

These tests run on macOS and do not exercise a jailbroken iPhone's sandbox. A physical rootless/rootful check with RocketBootstrap absent remains necessary.
