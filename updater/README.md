# Dependency updater

This directory contains the dependency locks and generators used by extension
maintainers:

- `versions.json` pins the MAX core SDK and Google UMP.
- `adapters.json` pins optional mediated-network adapters.
- `android.py` and `ios.py` generate platform manifests.
- `adapters.py` generates adapter switches and dependency blocks.

Do not edit generated sections by hand.

## Update iOS

The default iOS updater refreshes AppLovin's core and mediated-network
SKAdNetwork identifiers, syncs the pinned SDK resources, and regenerates all
iOS manifests:

```sh
python3 -B updater/ios.py
```

## Check committed output

These commands are offline and safe for CI:

```sh
python3 -B updater/adapters.py check
python3 -B updater/android.py check
python3 -B updater/ios.py check
```

## Verify locked artifacts

`refresh` checks the network repositories, recorded checksums, and the pinned
AppLovin SKAdNetwork identifiers without changing the catalogs:

```sh
python3 -B updater/adapters.py refresh
python3 -B updater/android.py refresh
python3 -B updater/ios.py refresh
```

## Regenerate files

After intentionally changing a catalog:

```sh
python3 -B updater/adapters.py generate
python3 -B updater/android.py generate
python3 -B updater/ios.py generate
```

Review every generated diff. Generation confirms consistency, not native API
compatibility.

## Update only SKAdNetwork identifiers

Fetch AppLovin's official generator output, update the core list in
`versions.json` and network-specific lists in `adapters.json`, then regenerate
the iOS manifest:

```sh
python3 -B updater/ios.py sync-skadnetwork
```

## Update iOS resources

After updating the iOS SDK archive pin:

```sh
python3 -B updater/ios.py sync-resources
```

To use an already downloaded official archive:

```sh
python3 -B updater/ios.py sync-resources \
  --archive /path/to/applovin-sdk.zip
```

Resource synchronization verifies the archive checksum and copies the
platform-neutral AppLovin resource bundle. The SDK privacy manifest remains in
`AppLovinSDK.framework`; it is not duplicated at the application resource
root.

After any dependency update, run all updater checks, repository tests, Bob
builds, and the MAX Mediation Debugger on both platforms.
