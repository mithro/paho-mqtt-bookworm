# paho-mqtt-bookworm

Debian trixie's **paho-mqtt 2.x** rebuilt for **bookworm**, published as a
signed APT repository at <https://mith.ro/paho-mqtt-bookworm/bookworm/>.

## Why

bookworm ships `python3-paho-mqtt` **1.6.1**. trixie and sid ship **2.1.0**.

[sensors2mqtt](https://github.com/mithro/sensors2mqtt) requires paho-mqtt ≥ 2 —
it calls `mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, ...)`, an API that does
not exist in 1.x, and its test suite imports `ReasonCode`, which 1.x spells
`ReasonCodes`. On bookworm the build fails and, if forced through, the runtime
would fail too.

fpgas.online consumes sensors2mqtt and its Raspberry Pi NFS root is still
bookworm, so dropping the suite was not an option. This backport is the
alternative.

## Using it

```console
$ sudo install -d -m0755 /etc/apt/keyrings
$ curl -fsSL https://mith.ro/paho-mqtt-bookworm/paho-mqtt-bookworm.gpg \
    | sudo tee /etc/apt/keyrings/paho-mqtt-bookworm.gpg > /dev/null
$ echo "deb [signed-by=/etc/apt/keyrings/paho-mqtt-bookworm.gpg] https://mith.ro/paho-mqtt-bookworm/bookworm/ ./" \
    | sudo tee /etc/apt/sources.list.d/paho-mqtt-bookworm.list
$ sudo apt update
$ sudo apt install python3-paho-mqtt
```

## How it is built

`packaging/build.sh`, run inside a `debian:bookworm` container:

1. Add a **`deb-src`** line for trixie — source only. No binary line, because
   pulling trixie binaries would make this a partial upgrade rather than a
   backport, and would poison the resulting package's dependencies.
2. `apt-get source paho-mqtt`.
3. `apt-get build-dep` — which must resolve from **bookworm alone**. If it
   cannot, the rebuild is not viable and the build fails loudly rather than
   being worked around.
4. `dch --local "~bpo12+"`, then `dpkg-buildpackage -us -uc -b`.

Nothing is vendored: the source is fetched at build time, so a new upstream
landing in trixie is picked up by the weekly schedule without a commit here.

## Versioning

`2.1.0-1~bpo12+1` sorts **above** bookworm's `1.6.1-1` and **below** trixie's
own `2.1.0-1`. A host that later moves to trixie therefore upgrades onto the
official package cleanly, rather than being pinned to this one.

## Scope

This repository serves **bookworm only**. trixie and sid already have 2.1.0;
adding them here would shadow the official package for no benefit.

## Licence

The packaging in this repository is Apache-2.0. paho-mqtt itself is upstream's
work under the Eclipse Public License / Eclipse Distribution License, and the
built package carries upstream's `debian/copyright` unchanged.
