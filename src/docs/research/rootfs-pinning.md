# Pinning and reproducing the M3 rootfs when snapshot.debian.org throttles

Researched 2026-11-04 (written 3:42 PM ET) on the build host. Sources: the snapshot.debian.org front page and the `API` file in its
salsa repository, metasnap.debian.net, the Debian unstable man pages (mmdebstrap, debsnap, debootsnap, debrebuild,
apt-get, apt.conf, apt_preferences, sources.list, dpkg-query, dpkg-scanpackages, apt-ftparchive, diffoscope, mke2fs),
the mmdebstrap script at gitlab.mister-muffin.de, apt and devscripts source on salsa, e2fsprogs source (the
tytso/e2fsprogs GitHub mirror) and release notes, reproducible-builds.org, the Isar, Debusine, live-build, debos, ELBE
and meta-debian documentation, the isar-users and debian-devel lists, two live HTTP reads at 3:33 PM ET [20:33 UTC],
and `tar --help`, `strings` and `getent` on the build host. Nothing was installed, no container ran, the Googlebook was not
touched. *Inference* marks what no source states. Script line numbers are from `scripts/build-rootfs-in-container.sh`
as read while this note was written; the file was being edited during this research, so re-check them before quoting.

Context: [ADR 0012](../adr/0012-m3-rootfs-debian-sid.md) decision 1 builds Debian sid arm64 "from one snapshot.debian.org
timestamp, with a lock list and a local `.deb` cache". `scripts/build-rootfs.sh` and `scripts/build-rootfs-in-container.sh`
implement it: `mmdebstrap --variant=apt` against `http://snapshot.debian.org/archive/debian/$ts/` (line 14), a `.deb`
cache synced in and out of `/var/cache/apt/archives` (lines 33, 50), `lock.txt` as `pkg:arch=version` (line 35), and
`mke2fs -d rootfs.tar` with `-U` and `hash_seed` from the epoch (lines 73-74). On 2026-11-04 the owner saw both
snapshot hosts answer 503/504 and deliver 17 packages in 14 minutes (owner's report, this session). This note asks what
the primary sources say about the service's limits, the alternatives, lock lists, and the reproducibility of the output.

## 1. snapshot.debian.org: limits, the Cloudflare name, other services, debsnap

**What Debian publishes.** The front page ([snapshot.debian.org](https://snapshot.debian.org/), read 2026-11-04) gives
the usage (`deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/<yyyymmddThhmmssZ>/ <suite> main`;
"Valid date formats are `yyyymmddThhmmssZ` or simply `yyyymmdd`") and, in its 2024-10-08 news entry, the only
statement on throttling: "The Netfilter rate limiting has been disabled." "It will be replaced by rate limiting on the
HTTP layer, which should be easier for clients to deal with." The same entry says the HTTP interface is served from the
new Glasklar Teknik server and a LeaseWeb VM, and that the archive holds 172 TB. No number, window or policy is
published; there is no FAQ; bugs go to the `snapshot.debian.org` pseudo-package and questions to the
[debian-snapshot list](https://lists.debian.org/debian-snapshot/). The machine interface
([`API` file](https://salsa.debian.org/snapshot-team/snapshot/raw/master/API), read 2026-11-04) documents
`/mr/package/<src>/<ver>/binfiles/<bin>/<binver>`, `/mr/binary/<bin>/`, `/file/<hash>` and `/mr/timestamp` and states
no usage policy. The repository [README](https://salsa.debian.org/snapshot-team/snapshot/-/raw/master/README) says of the
web application: "It's not really built to scale well, but for now it's one way to access the data."

**The CDN.** Philipp Kern, replying on debian-devel to a "503 Response object too large" report
([lists.debian.org/debian-devel/2025/06/msg00147.html](https://lists.debian.org/debian-devel/2025/06/msg00147.html),
quoted in Christof Warlich's message of 2025-06-11): "Generally Fastly requires to turn on segmented caching to serve
larger objects", "our account still supports 2 GB for requests without Streaming Miss (snapshot.d.o) and 5 GB for
requests with Streaming Miss (deb.d.o)". So snapshot.debian.org is served through Fastly.

**snapshot-cloudflare.debian.org.** No Debian document read for this note names it: not the front page, the `API`
file, the README, nor the debootsnap and debrebuild scripts. Live read at 3:33 PM ET [20:33 UTC], one `GET` per host of
`/archive/debian/20261104T000000Z/dists/sid/Release`:

| Host (DNS at 3:28 PM ET) | Answer | Headers |
|---|---|---|
| snapshot.debian.org (151.101.2.132, .66.132, .130.132, .194.132) | `302` to `/file/8528f033…/Release` | `server: Apache`, `via: 1.1 varnish (Varnish/7.1), 1.1 varnish`, `x-served-by: cache-mia-kfll1870075-MIA`, `x-cache: MISS` |
| snapshot-cloudflare.debian.org (104.20.45.122, 172.66.150.28) | `503` | `server: cloudflare`, `cf-cache-status: BYPASS`, `retry-after: 0`, and also `via: 1.1 varnish`, `x-served-by: cache-mia-kmia1760085-MIA`, `x-cache: MISS` |

*Inference* from the headers: the Cloudflare name is a second CDN front that forwards to the same Varnish/Fastly chain
(the `x-served-by` cache node naming is identical), not a separate copy of the archive. Its 503 came from behind
Cloudflare, so switching hosts gains nothing when the backend is the bottleneck. The only statement on its history is
third-party: Felix Moessbauer (Siemens) on isar-users, 2024-09-03: "Please note, that snapshot-cloudflare stopped
mirroring in June." and "there we have massive problems with rate limiting"
([groups.google.com/g/isar-users/c/LSwbPYxSNCE](https://groups.google.com/g/isar-users/c/LSwbPYxSNCE/m/fXXvwP8nDwAJ)).
An isar-cip-core patch of April 2024 still used a `snapshot-cloudflare.debian.org/archive/debian/20240411T000000Z` URL
([lore.kernel.org](https://lore.kernel.org/r/73bb628d-3542-4f8d-8445-1380e6fcbd3d@siemens.com)). Note that at 3:33 PM
the main host answered while the owner's reads earlier in the day failed: the state changes within a day.

**How apt retries.** apt's `acquire-worker.cc` (salsa `main`, read 2026-11-04,
[source](https://salsa.debian.org/apt-team/apt/-/raw/main/apt-pkg/acquire-worker.cc)): `Acquire::Retries` defaults to
3 (`acquire-item.cc`), `Acquire::Retries::Delay` defaults to true, the delay is `1 << Iter` seconds capped by
`Acquire::Retries::Delay::Maximum` (default 30), and `Retry-After` is honoured only when the method reports
`TooManyRequests` (HTTP 429) and `Acquire::Retries::HandleRetryAfter` is true. The code comments: "Usually, all
requests run into the rate limit at the same time. Distribute the retries to avoid hitting the limit again." A 503 gets
the plain backoff, and today's 503 carried `retry-after: 0` anyway. [apt.conf(5)](https://manpages.debian.org/unstable/apt/apt.conf.5.en.html)
documents only `Acquire::Retries` ("Number of retries to perform. If this is non-zero APT will retry failed files the
given number of times."); the `Delay` options are undocumented there. Isar's response to the same problem
([isar-users patch, Felix Moessbauer, 2024-11-06](https://groups.google.com/g/isar-users/c/juMglsic-bQ/m/RmOdJtfcBwAJ)):
"The snapshot mirrors apply strict rate limiting, making it impossible to use them with a default apt configuration."
It sets `Acquire::Retries` to 10 and `Acquire::Retries::Delay::Maximum` to 600 whenever `ISAR_USE_APT_SNAPSHOT` is on,
3 and unset otherwise. debrebuild sets `Acquire::Retries "5"` and `Acquire::http::Dl-Limit "1000"` and notes "Release
files from snapshots.d.o have often expired by the time we fetch them"
([debrebuild.pl](https://salsa.debian.org/debian/devscripts/-/raw/main/scripts/debrebuild.pl)).

**Other services.**
- `snapshot.notset.fr` and `debian.notset.fr` resolve to no address today (`getent ahostsv4`, 3:28 PM ET). The
  software behind them, [fepitre/snapshot-mirror](https://github.com/fepitre/snapshot-mirror), calls itself a "Debian
  snapshot service written from scratch" that "currently uses `snapshot.debian.org` set of timestamps and data for
  provisioning the service", serves "A partial timestamps set" at `snapshot.notset.fr`, and limits clients in nginx
  (`limit_conn conn_limit_per_ip 20; limit_rate 10m;`) "for allowing every Debian rebuilder infrastructure to scale their
  actual builders". The repository page shows no archive notice and no commit date (read 2026-11-04).
- `snapshot-mlm-01.debian.org` was offered as a workaround endpoint during the June 2024 hardware migration
  ([bug #1072675](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1072675): "We're currently migrating to new
  hardware. Not losing any data.", Linus Nordberg, 2024-06-12). It is a Debian machine, not documented for general use
  (*inference*: not a pin target).
- [metasnap.debian.net](https://metasnap.debian.net/) "is an addition to snapshot.d.o": for each suite, architecture
  and binary package it records "which version of it was seen in which snapshot.d.o timestamps in that suite"; its
  `pkgs=` endpoint takes `name=version` pairs and returns a minimal set of timestamps covering them (POST for lists
  over 32768 bytes); timestamps are indexed only once they are 12 hours old. Run by Johannes Schauer Marin Rodrigues.
- Debusine serves its own repositories at `/{scope}/{workspace}/{timestamp}`, "compatible with snapshot.debian.org and
  snapshot.ubuntu.com" ([explanation/package-repositories](https://freexian-team.pages.debian.net/debusine/explanation/package-repositories.html)).
  That is Freexian's archive, not a mirror of Debian's.

**debsnap** ([debsnap(1)](https://manpages.debian.org/unstable/devscripts/debsnap.1.en.html)) "is a tool to help with
retrieving snapshots of old packages from a daily archive repository": by default every version of one source package,
`--binary` and `-a <arch>` for binaries, `--first`/`--last` for a range, `DEBSNAP_BASE_URL` defaulting to
`https://snapshot.debian.org`, exit status 2 when some files "are no longer available on the snapshot mirror". It is a
per-package fetcher against the same service, so it fills a cache but does not avoid the limit.

**debootsnap** ([debootsnap(1)](https://manpages.debian.org/unstable/devscripts/debootsnap.1.en.html) and the
[script](https://salsa.debian.org/debian/devscripts/-/raw/main/scripts/debootsnap)) "Combines debootstrap and
snapshot.debian.org to create a chroot tarball with exact package versions from the past". Its input is a list
`pkg1:arch=ver1,pkg2:arch=ver2` (or `--buildinfo`), produced on the source machine with
`dpkg-query --showformat '${binary:Package}=${Version}\n' --show`. The script asks metasnap for the timestamps, writes
one `deb` line per timestamp, downloads each `name:arch=version` with `apt-get download` through a local caching proxy
(`devscripts.proxy.setupcache`, `http_proxy=http://127.0.0.1:<port>`, `Acquire::Retries "5"`), builds a local flat
repository served as `deb [trusted=yes] http://localhost:<port>/ ./` with a dummy package whose `Depends:` names every
`pkg:arch (= ver)`, and runs `mmdebstrap --variant=essential --include=debootsnap-dummy --format=tar`. This is the
pattern [reproduce.debian.net](https://reproduce.debian.net/) runs at scale: "rebuilderd calls debrebuild that calls
debootsnap, mmdebstrap and finally sbuild".

## 2. Local mirrors and caches; how other projects pin

**mmdebstrap's own tools** ([mmdebstrap(1)](https://manpages.debian.org/unstable/mmdebstrap/mmdebstrap.1.en.html), 1.6.0-5,
read 2026-11-04):
- `sync-in <outside> <inside>`: "Recursively copy everything inside pathoutside into pathinside inside the chroot"
  "without deleting anything from pathinside but overwriting content as necessary"; `sync-out` the reverse. EXAMPLES:
  "If, for some reason, you cannot use a caching proxy like apt-cacher or apt-cacher-ng, you can use the sync-in and
  sync-out special hooks to synchronize a directory outside the chroot with /var/cache/apt/archives inside the
  chroot", and "Instead of copying potentially large amounts of data with sync-in you can also use a bind-mount in
  combination with a file:// mirror".
- The essential step "Removes all packages downloaded in the download step, except those which were present in
  /var/cache/apt/archives/ before (if any). This can be disabled using --skip=essential/unlink." The script's
  `--skip=essential/unlink` (line 53) therefore keeps the newly downloaded `.deb`s for the `sync-out` (*inference* from
  the two sentences; the man page does not spell out the combination).
- `--hook-dir=/usr/share/mmdebstrap/hooks/file-mirror-automount`: "A hook that automatically makes the contents of
  file:// mirrors as well as .deb packages given with --include available inside the chroot"; "This hook takes care of
  copying all relevant file to their correct locations and cleans up those files at the end." `--include` accepts
  "apt features like pkg/suite, pkg=version, pkg-" and `.deb` paths, with the caveat "Since apt (outside the chroot)
  passes paths to dpkg (on the inside) verbatim, you have to make the .deb package available under the same path inside
  the chroot as well". `copy://` is not mentioned.
- `--aptopt` values are "permanently added to /etc/apt/apt.conf.d/99mmdebstrap inside the chroot"; the man page's own
  example is `--aptopt='Acquire::Check-Valid-Until "false"'`, "necessary for allowing old timestamps from
  snapshot.debian.org". So line 53's option, and any retry option added the same way, stays in the rootfs.
- `--simulate`: "Only the package cache is initialized but no binary packages are downloaded or installed", "No hooks
  are executed", and for a tarball "no output is produced" (ticket 02 hit this).

**What the cache does not cover.** `sync-in` fills `/var/cache/apt/archives`, apt's download cache
([apt.conf(5)](https://manpages.debian.org/unstable/apt/apt.conf.5.en.html): `Dir::Cache::archives` is "the location to
place downloaded archives"). apt still needs the mirror's `InRelease` and `Packages` indexes, so a snapshot that answers
503 blocks the build even with every `.deb` cached (*inference*: the man page describes only what the hooks copy). The
way round, which debootsnap takes, is a local flat repository:
- [DebianRepository/Format](https://wiki.debian.org/DebianRepository/Format): "A flat repository does not use the dists
  hierarchy of directories" and "places meta index and indices directly into the archive root"; the sources line is
  `deb uri directory/`. [sources.list(5)](https://manpages.debian.org/unstable/apt/sources.list.5.en.html): the "suite
  must end with a slash (/)"; "The file scheme allows an arbitrary directory in the file system to be considered an
  archive"; `copy` is the same but copies into the cache; `trusted=yes` makes apt accept the source without
  authentication, which the page says to use only in local, trusted contexts.
- [dpkg-scanpackages(1)](https://manpages.debian.org/unstable/dpkg-dev/dpkg-scanpackages.1.en.html) "creates a Packages
  file"; `-m` includes every version found; "apt(8) ignores uncompressed Packages files except on local access (i.e.
  file:// sources)". [apt-ftparchive(1)](https://manpages.debian.org/unstable/apt-utils/apt-ftparchive.1.en.html) is "a
  superset of the dpkg-scanpackages(1) program"; its `release` command writes a Release file "containing (by default) an
  MD5, SHA1, SHA256 and SHA512 digest" with `APT::FTPArchive::Release::{Origin,Label,Suite,Codename,Valid-Until,
  Acquire-By-Hash,...}`. Neither page covers signing.

**apt-cacher-ng** ([user manual](https://sources.debian.org/src/apt-cacher-ng/latest/doc/README/), sections as numbered
there): "a caching proxy for software packages which are downloaded by Unix/Linux system distribution mechanisms from
mirror servers accessible via HTTP"; clients use `Acquire::http::proxy "http://CacheServerIp:3142";` or put the mirror
host after the cache address in the URL (3.2); `Remap-debrep` merges mirrors that are "considered equal" (4.3); "The
internal cache directory tree follows the URL requests from the clients unless modified by Remapping rules" (4.3.2),
so each snapshot timestamp is its own tree (*inference*); existing files go into the `_import` directory (8.1);
expiration removes files that are "not referenced in any index file" after a grace period (`ExTreshold`, 7.1, 9.3).
An `Offlinemode` setting was not found in the pages read (unverified). Isar users measured "~12min" to "~7min" for
four images with it (Alexander Heinisch, isar-users, 2024-08-22, thread above). Trade-off: a daemon and its expiration
rules, for a benefit the `sync-in` cache already gives a single-image project.

**aptly** ([overview](https://www.aptly.info/doc/overview/), [mirror create](https://www.aptly.info/doc/aptly/mirror/create/)):
"aptly's goal is to establish repeatability and controlled changes in package environments"; a mirror "consists of
metadata, list of packages and package files", a snapshot is an "immutable list of packages";
`aptly mirror create <name> <archive url> <distribution> [<component1> ...]` with `-architectures`, `-filter=<query>`
and `-filter-with-deps`; flat repositories take `./` as distribution. A mirror of one snapshot timestamp filtered to
`rootfs/packages.txt` with dependencies would be a self-hosted pin, at the cost of a Go tool and its database.

**reprepro** ([reprepro(1)](https://manpages.debian.org/unstable/reprepro/reprepro.1.en.html)) "is a tool to manage a
repository of Debian packages", filled by `includedeb` or by `update` from `conf/updates` rules (`Method` is an apt
URI, `FilterFormula` selects packages). Whether current reprepro keeps more than one version per package per
distribution (a `Limit` field) was not found in the man page text read: unverified.

**How established projects pin** (each from its own documentation, read 2026-11-04):
- Debian reproducible builds: the debootsnap chain above; `.buildinfo` files from buildinfos.debian.net, exact
  versions from metasnap and snapshot ([reproduce.debian.net](https://reproduce.debian.net/)).
- Debusine: timestamp URLs as above; "by-hash files under dists/, and all files resulting from a timestamp-specific
  query are immutable: they may be removed, but they won't be replaced with different contents at the same URL", served
  with `Cache-Control: max-age=31536000`; clients pin by putting the snapshot ID in the repository URL, and a
  `Snapshots` field in generated Release files is planned. Its [MmDebstrap task](https://freexian-team.pages.debian.net/debusine/reference/tasks/worker/mmdebstrap.html)
  turns `bootstrap_repositories` into a sources.list "fed to mmdebstrap as input", `extra_packages` into `--include`.
- live-build ([manual 8.1-8.4](https://live-team.pages.debian.net/live-manual/html/live-manual/customizing-package-installation.en.html)):
  `--mirror-bootstrap`, `--mirror-chroot`, `--mirror-binary*`; pinning through `config/archives/*.pref` and
  `config/apt/preferences`; local `.deb`s in `config/packages.chroot/` ("automatically installed into the live system
  during build"); `--apt-options` passes options through.
- debos ([actions](https://pkg.go.dev/github.com/go-debos/debos/actions)): the `debootstrap` action has `suite`,
  `mirror`, `variant`, `keyring-package`, `keyring-file`, `check-gpg`, `merged-usr`; the `apt` action `packages`,
  `recommends`, `unauthenticated`, `update`. No snapshot, pin or cache field.
- ELBE ([schema reference](https://elbe-rfs.org/docs/sphinx/article-elbe-schema-reference.html)): `mirror` with a
  `primary_host` and a `url-list` of extra repositories; each `pkg` has `version`, `pin` ("prefer the defined version of
  the debian package") and `md5`/`sha256` attributes. No snapshot mention.
- Isar ([user manual](https://github.com/ilbers/isar/blob/master/doc/user_manual.md),
  [debian-common.conf](https://raw.githubusercontent.com/ilbers/isar/master/meta/conf/distro/debian-common.conf)):
  `ISAR_USE_APT_SNAPSHOT` "Use a frozen apt snapshot instead of the live mirror", `ISAR_APT_SNAPSHOT_DATE` in
  `20240702T082400Z` form, the timestamp "Automatically derived from SOURCE_DATE_EPOCH if not overwritten"; the
  premirror rewrites `deb.debian.org/(.*)` to `snapshot.debian.org/archive/\1/<date>`; base-apt caches "upstream debian
  packages to reduce time for further downloads and to be able to work offline" (`ISAR_USE_CACHED_BASE_REPO`; "By
  default, the local caching repo is not gpg signed"); retries 10 / 600 s when snapshots are on.
- meta-debian ([README](https://github.com/meta-debian/meta-debian/blob/master/README.md)): poky recipes for
  "cross-building GNU/Linux images using Debian source packages"; a source build, not a binary pin; no snapshot text.

## 3. Lock lists

**`pkg=version`.** [apt-get(8)](https://manpages.debian.org/unstable/apt/apt-get.8.en.html): "A specific version of a
package can be selected for installation by following the package name with an equals and the version of the package to
select." "Both of the version selection mechanisms can downgrade packages and must be used with care." apt parses the
suffix at the last `/` or `=` ([cacheset.cc](https://salsa.debian.org/apt-team/apt/-/raw/main/apt-pkg/cacheset.cc),
`find_last_of("/=")`) and fails with `Version '%s' for '%s' was not found` (`canNotGetVerFromVersionNumber`) or
`Release '%s' for '%s' was not found`. Against a snapshot timestamp the index does not move (*inference* from the service's
purpose; the front page's news entries describe imports of the archive at each timestamp), so the version is there as
long as the service answers; against `GBOOK_ROOTFS_MIRROR=http://deb.debian.org/debian` (build-rootfs.sh line 10) sid
moves daily (live read: sid's Release is dated `Wed, 04 Nov 2026 14:14:42 UTC`, `Valid-Until` seven days later) and
"was not found" is the failure mode for any pinned version that has been superseded. mmdebstrap passes `pkg=version`
through `--include` (section 2), and debootsnap avoids the solver moving a version by making every entry a
`pkg:arch (= ver)` dependency of one dummy package.

**apt preferences** ([apt_preferences(5)](https://manpages.debian.org/unstable/apt/apt_preferences.5.en.html)):
`P >= 1000` "causes a version to be installed even if this constitutes a downgrade of the package", `500 <= P < 990`
"unless there is a version available belonging to the target release", `P < 0` "prevents the version from being
installed", `P = 0` "has undefined behaviour"; `Pin: version 5.32*` with `Pin-Priority: 1001` is the page's example;
"the first specific-form record matching an available package version determines the priority", so "always list
wild-card pins first, so later specific pins override it". A 300-stanza preferences file is a second way to lock; the
`--include` list is shorter and is what debootsnap uses.

**apt's `Snapshot:` option.** [sources.list(5)](https://manpages.debian.org/unstable/apt/sources.list.5.en.html):
`Snapshot` "allows selecting an earlier version of the archive from the snapshot service"; IDs "are usually timestamps in
the form of YYYYMMDDTHHMMSSZ"; [apt.conf(5)](https://manpages.debian.org/unstable/apt/apt.conf.5.en.html): "snapshots
can only be acquired if a URI is known from where to get them". Live read of `deb.debian.org/debian/dists/sid/Release`:
the fields present are `Suite`, `Codename`, `Date`, `Valid-Until`, `Acquire-By-Hash`; no `Snapshots` field. The
timestamp in the mirror URL, as the scripts do it, stays the working form.

**Verifying a rebuild.** [dpkg-query(1)](https://manpages.debian.org/unstable/dpkg/dpkg-query.1.en.html): `-W` lists
installed packages, default format `${binary:Package}\t${Version}\n`, where `binary:Package` carries an architecture
qualifier only for Multi-Arch same or foreign packages; the man page states no output order. The script's
`${Package}:${Architecture}=${Version}` (line 35) qualifies every line and matches debootsnap's `pkg:arch=ver` input
format, so `lock.txt` can be fed straight back to debootsnap or, comma-joined, to `--include`. Two locks compare with
`comm -3` after `LC_ALL=C sort` (which `lock_check` already enforces, build-rootfs.sh line 25); the manifest's
`lock_sha256` is the one-line form. metasnap's `pkgs=` endpoint (section 1) can confirm which timestamps hold a lock,
once the timestamp is 12 hours old.

## 4. Reproducibility of the output

**The specification.** [SOURCE_DATE_EPOCH](https://reproducible-builds.org/specs/source-date-epoch/) is "A UNIX
timestamp, defined as the number of seconds, excluding leap seconds, since 01 Jan 1970 00:00:00 UTC"; tools embedding
a time "MUST use a timestamp no later than the value of this variable" (clamping); "Build processes MUST NOT unset this
variable for child processes if it is already present".

**mmdebstrap** ([man page](https://manpages.debian.org/unstable/mmdebstrap/mmdebstrap.1.en.html) and
[script](https://gitlab.mister-muffin.de/josch/mmdebstrap/raw/branch/main/mmdebstrap), `main`, read 2026-11-04):
- "By setting SOURCE_DATE_EPOCH the result will be reproducible across multiple runs with the same options"; the output
  "will differ if it is run on machines with differing /etc/resolv.conf and /etc/hostname contents" (copied in for
  debootstrap compatibility). The script's line 34 overwrites `/etc/hostname`; nothing in the script writes or removes
  `/etc/resolv.conf`, so the tar carries the podman container's copy, a reproducibility input the build does not
  control and possibly a LAN resolver address (whether mmdebstrap's cleanup removes it was not verified). Cleanup will "Remove files that make the result unreproducible and write the empty string to
  /etc/machine-id"; "A tarball created in this mode [unshare] will be bit-by-bit identical to a tarball created with the
  root mode".
- The script extracts the essential packages chrootless "because otherwise directory creation timestamps will differ"
  since "we want to create bit-by-bit identical tar output" (`setup()`), and builds the tar with `--sort=name`,
  `--mtime=@$mtime`, `--clamp-mtime`, `--numeric-owner`,
  `--pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime`, plus `--xattrs` for tar output; `$mtime` is
  `$ENV{SOURCE_DATE_EPOCH} + 0`.
- ext4 output: "If SOURCE_DATE_EPOCH is set, the filesystem UUID and hash_seed will be set to a UUID derived from
  SOURCE_DATE_EPOCH to create reproducible images" (man page). The script derives
  `$uuid = create_v5_uuid(create_v5_uuid($UUID_NS_DNS, "mister-muffin.de"), $mtime)` (a name-based RFC 4122 version-5
  UUID, SHA-1 over namespace and name; `$UUID_NS_DNS = 6ba7b810-9dad-11d1-80b4-00c04fd430c8`) and runs
  `mke2fs -q -F -o Linux -T ext4 -U $uuid -E hash_seed=$uuid -b 4096 -d - <target> <numblocks>`, the block count from
  its `approx_disk_usage`. It sets no `E2FSPROGS_FAKE_TIME`: it relies on mke2fs reading `SOURCE_DATE_EPOCH` itself.

**e2fsprogs.** [Release notes](https://e2fsprogs.sourceforge.net/e2fsprogs-release.html): 1.47.1 (2024-05-20) "Mke2fs -d
can now support an input tar file if the libarchive library is available." and "Add support for SOURCE_DATE_EPOCH
environment variable per the specification https://reproducible-builds.org/specs/source-date-epoch"; 1.46.6
(2023-02-01) "Fix resize2fs to honor the E2FSPROGS_FAKE_TIME environment variable ... to create reproducible images";
1.47.2 (2025-01-01) gnu.translator xattrs in tar input and "Allow building e2fsprogs without libarchive-dev installed";
1.47.3 (2025-07-08) `-d` copies fs-verity metadata and chattr flags; 1.47.4 (2026-03-06) "Fix mke2fs -d so it can handle
copying a file larger than 2 GiB." [mke2fs(8)](https://manpages.debian.org/unstable/e2fsprogs/mke2fs.8.en.html): "Tarball
input is only available if mke2fs was compiled with libarchive support enabled and if the libarchive shared library is
available at run-time"; `-E hash_seed=`: "Use the specified UUID as the seed for hashing, rather than generating a
random seed each time. Intended for use with reproducible builds."; `-U` takes a UUID or `clear`, `random`, `time`;
`-E root_owner` sets the root directory's uid:gid. The source (tytso/e2fsprogs `master`, read 2026-11-04):
- [`lib/ext2fs/initialize.c`](https://raw.githubusercontent.com/tytso/e2fsprogs/master/lib/ext2fs/initialize.c):
  `SOURCE_DATE_EPOCH` is read first and sets `fs->now` plus `EXT2_FLAG2_USE_FAKE_TIME`; `E2FSPROGS_FAKE_TIME` is read
  only when `SOURCE_DATE_EPOCH` is unset and sets `fs->now` without the flag; `s_mkfs_time` and `s_lastcheck` come from
  `ext2fsP_get_time(fs)`.
- [`misc/create_inode.c`](https://raw.githubusercontent.com/tytso/e2fsprogs/master/misc/create_inode.c): `clamped_time`
  returns `fs->now` only `if ((fs->flags2 & EXT2_FLAG2_USE_FAKE_TIME) && t > fs->now)`; file times are set with
  `ext2fs_inode_xtime_set(&inode, i_mtime, clamped_time(fs, st->st_mtime))`; a directory input is walked with
  `scandir(".", &dent, NULL, alphasort)`; hard links are matched by device and inode and added with `add_link`.
- [`misc/create_inode_libarchive.c`](https://raw.githubusercontent.com/tytso/e2fsprogs/master/misc/create_inode_libarchive.c):
  libarchive is `dlopen`ed as `libarchive.so.13` ("you need libarchive to be able to process tarballs" when missing);
  entries are applied in archive order (`archive_read_next_header` loop), metadata through `archive_entry_stat` and
  `set_inode_extra`, hard links through `add_link`. So the tar's own order and mtimes decide inode allocation and
  timestamps, which is why mmdebstrap sorts and clamps the tar first.
- [`misc/mke2fs.c`](https://raw.githubusercontent.com/tytso/e2fsprogs/master/misc/mke2fs.c): without `-U`,
  `uuid_generate(fs->super->s_uuid)`; with an all-zero hash seed, `uuid_generate` on `s_hash_seed`; `hash_seed=` is
  parsed with `uuid_parse` ("Invalid hash seed" otherwise).
- Live read on the build host: `strings` of `mke2fs 1.47.4 (6-Mar-2025)` and `libext2fs.so` (e2fsprogs 1.47.4-1) contain both
  `SOURCE_DATE_EPOCH` and `E2FSPROGS_FAKE_TIME`.

**What this means for lines 16 and 73-74.** `SOURCE_DATE_EPOCH` is exported (line 16), so the
`E2FSPROGS_FAKE_TIME=$epoch` prefix on line 74 is never consulted (initialize.c reads `SOURCE_DATE_EPOCH` first); on
its own it would fix the superblock times but not clamp file mtimes (no `EXT2_FLAG2_USE_FAKE_TIME`). The comment above
line 73 says the UUID is derived "as mmdebstrap's own ext4 output does": the `-U`/`hash_seed` pairing matches, the
derivation does not (sha256 of the epoch cut into UUID shape here, a version-5 UUID over `mister-muffin.de` there).
Both are deterministic for one epoch; only the comment is wrong.

**Tool versions float.** Line 23 installs mmdebstrap and e2fsprogs from live sid at build time, and the manifest
records the versions (lines 83-84). *Inference*: two builds of one timestamp on different days may run different mke2fs
versions and lay the image out differently while the tar is byte-identical, so the tar is the stronger contract.
`e2fsck -fn` (line 76) checks consistency, not identity.

**What the reproducible-builds documentation says about images**
([system-images](https://reproducible-builds.org/docs/system-images/)): "It is also possible to produce bit-reproducible
filesystems with recent mkfs.ext2 from e2fsprogs-1.47.1", with `-E hash_seed=<uuid>` and `-U <uuid>` in its example; an
image that "has been created by mkfs.ext4, mounted, modified and saved as an image ... would not be reproducible: the
allocation of the inodes is undefined"; general problems are filesystem timestamps and "UUID or a label which are not
set explicitly"; "clamp mtimes of files in the root filesystem to $SOURCE_DATE_EPOCH before generating the system
image", with `tar --sort=name --mtime=@$SOURCE_DATE_EPOCH --clamp-mtime` in its tool table. The GNU tar manual's
Reproducibility page answered 429 three times today; `tar --help` (GNU tar 1.35 on the build host) gives the semantics:
`--clamp-mtime` "only set time when the file is more recent than what was given with --mtime", `--sort=ORDER`
"directory sorting order: none (default), name or inode".

**What to compare between two builds.** In order of cost: `lock.txt` (`comm -3`), then `sha256` of `rootfs.tar`
(content, ownership, modes, mtimes, xattrs), then `sha256` of `rootfs.ext4` (layout, which also depends on the
e2fsprogs version). To explain a mismatch, [diffoscope](https://manpages.debian.org/unstable/diffoscope/diffoscope.1.en.html)
"will recursively unpack archives of many kinds", lists "ext2/ext3/ext4/btrfs/fat filesystems" and "tape archives
(.tar)" among its formats, and `--exclude-directory-metadata` ignores "permissions, timestamps, xattrs etc." when only
content matters.

## Recommendations

1. **Add an offline mode to `scripts/build-rootfs-in-container.sh`** that builds a flat repository from `/work/cache`
   (`apt-ftparchive packages` and `release`, or `dpkg-scanpackages -m`), passes
   `deb [trusted=yes] file:///work/cache ./` as the mirror with `--hook-dir=/usr/share/mmdebstrap/hooks/file-mirror-automount`,
   and sets `--include` from the previous `lock.txt` (`pkg:arch=version` is apt syntax). Why: `sync-in` spares the `.deb`
   downloads but apt still needs the snapshot's indexes, so a 503 stops the build today even with a full cache; this is
   the debootsnap pattern. Trade-off: the flat repository is unsigned (the `.deb`s were verified when first fetched;
   `lock_sha256` and the cache's sha256s are the chain of custody), and a package missing from the cache fails with
   "Version ... was not found", which is the wanted behaviour.
2. **Raise apt's retries for the snapshot mirror** with `--aptopt='Acquire::Retries "10"'` and
   `--aptopt='Acquire::Retries::Delay::Maximum "600"'` (Isar's values), only when the mirror is a snapshot host. Why: apt's
   defaults are 3 retries capped at 30 s of backoff and `Retry-After` counts only for 429, while snapshot answers 503
   with `retry-after: 0`. Trade-off: a dead mirror takes longer to fail, and the options land in the rootfs's
   `/etc/apt/apt.conf.d/99mmdebstrap` (harmless for a rootfs that never runs apt; a customize hook can delete the file).
3. **Fix lines 73-74:** drop `E2FSPROGS_FAKE_TIME=` (dead with `SOURCE_DATE_EPOCH` exported) and reword the comment: `-U`
   and `hash_seed` follow mmdebstrap, the derivation is this script's own sha256 form. Add `e2fsprogs >= 1.47.1` as a
   stated floor (tar input and `SOURCE_DATE_EPOCH`; 1.47.4 for files over 2 GiB). Trade-off: none.
4. **State the reproducibility contract in ADR 0012:** two builds of one timestamp must agree on `lock.txt` and the
   `rootfs.tar` sha256; the `rootfs.ext4` sha256 is expected to agree only with the same e2fsprogs version (recorded in
   the manifest). Why: the container's tools float with sid (line 23). Alternative: install the tools from the same
   snapshot timestamp. Trade-off: that puts the tool install behind the throttled service too; recording versions and
   comparing tars costs nothing.
5. **When `GBOOK_ROOTFS_MIRROR` points at deb.debian.org, feed `--include` from the last `lock.txt`** so drift fails
   loudly instead of silently moving versions, or have the manifest carry a `lock_changed=N` line from `comm -3` against
   the previous lock. Why: sid moves daily and the manifest's `mirror=` line alone does not say what changed. Trade-off: a
   pipeline test against a moved sid fails until the lock is refreshed on purpose.
6. **Add the lock comparison to the normal build:** keep the previous `lock.txt` as `lock.prev.txt` and write
   `lock_changed=N` into the manifest. Why: it is the cheapest reproducibility check and the first thing to read when
   sha256s differ. Trade-off: none.
7. **Record in ADR 0012's next update** that `snapshot-cloudflare.debian.org` fronts the same backend (live read,
   section 1), that Debian publishes no limit figures, and that the project's answer to throttling is the cache plus
   the offline flat repository rather than a mirror switch; note metasnap's 12-hour rule if debootsnap or metasnap are
   ever used to find timestamps. Trade-off: none.
8. **Write a fixed `/etc/resolv.conf` in the customize hook, or remove it** and let systemd-resolved or networkd
   manage it at boot. Why: mmdebstrap copies the host's file in, the man page names it as a reason outputs differ, and
   the script does not touch it, so the container's resolver address ends up in the tar. Trade-off: none for a rootfs
   that gets its network from `/run/gbook/` and DHCP.
9. **Do not add apt-cacher-ng or aptly for this.** Why: the `sync-in` cache plus recommendation 1 covers a single-image
   project; both tools add a daemon or a database. Reconsider only if several images or hosts share the cache.

## Sources

- snapshot.debian.org: [front page](https://snapshot.debian.org/) (usage, 2024-10-08 news), [`API`](https://salsa.debian.org/snapshot-team/snapshot/raw/master/API), [README](https://salsa.debian.org/snapshot-team/snapshot/-/raw/master/README); [bug #1072675](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1072675); [debian-devel 2025-06 (Fastly limits)](https://lists.debian.org/debian-devel/2025/06/msg00147.html); [debian-devel 2024-04 (snapshot state)](https://lists.debian.org/debian-devel/2024/04/msg00421.html); live reads 2026-11-04 at 3:28 PM ET (DNS) and 3:33 PM ET [20:33 UTC] (HTTP).
- [metasnap.debian.net](https://metasnap.debian.net/); [reproduce.debian.net](https://reproduce.debian.net/); [fepitre/snapshot-mirror](https://github.com/fepitre/snapshot-mirror).
- isar-users: [apt-cacher-ng thread (2024-07/09)](https://groups.google.com/g/isar-users/c/LSwbPYxSNCE/m/fXXvwP8nDwAJ), [retry patch (2024-11-06)](https://groups.google.com/g/isar-users/c/juMglsic-bQ/m/RmOdJtfcBwAJ); [isar-cip-core patch (2024-04)](https://lore.kernel.org/r/73bb628d-3542-4f8d-8445-1380e6fcbd3d@siemens.com).
- Man pages (Debian unstable): [mmdebstrap(1)](https://manpages.debian.org/unstable/mmdebstrap/mmdebstrap.1.en.html), [debsnap(1)](https://manpages.debian.org/unstable/devscripts/debsnap.1.en.html), [debootsnap(1)](https://manpages.debian.org/unstable/devscripts/debootsnap.1.en.html), [debrebuild(1)](https://manpages.debian.org/unstable/devscripts/debrebuild.1.en.html), [apt-get(8)](https://manpages.debian.org/unstable/apt/apt-get.8.en.html), [apt.conf(5)](https://manpages.debian.org/unstable/apt/apt.conf.5.en.html), [apt_preferences(5)](https://manpages.debian.org/unstable/apt/apt_preferences.5.en.html), [sources.list(5)](https://manpages.debian.org/unstable/apt/sources.list.5.en.html), [dpkg-query(1)](https://manpages.debian.org/unstable/dpkg/dpkg-query.1.en.html), [dpkg-scanpackages(1)](https://manpages.debian.org/unstable/dpkg-dev/dpkg-scanpackages.1.en.html), [apt-ftparchive(1)](https://manpages.debian.org/unstable/apt-utils/apt-ftparchive.1.en.html), [reprepro(1)](https://manpages.debian.org/unstable/reprepro/reprepro.1.en.html), [diffoscope(1)](https://manpages.debian.org/unstable/diffoscope/diffoscope.1.en.html), [mke2fs(8)](https://manpages.debian.org/unstable/e2fsprogs/mke2fs.8.en.html).
- Source: [mmdebstrap script](https://gitlab.mister-muffin.de/josch/mmdebstrap/raw/branch/main/mmdebstrap); devscripts [debootsnap](https://salsa.debian.org/debian/devscripts/-/raw/main/scripts/debootsnap), [debrebuild.pl](https://salsa.debian.org/debian/devscripts/-/raw/main/scripts/debrebuild.pl); apt [cacheset.cc](https://salsa.debian.org/apt-team/apt/-/raw/main/apt-pkg/cacheset.cc), [acquire-worker.cc](https://salsa.debian.org/apt-team/apt/-/raw/main/apt-pkg/acquire-worker.cc), [acquire-item.cc](https://salsa.debian.org/apt-team/apt/-/raw/main/apt-pkg/acquire-item.cc); e2fsprogs [release notes](https://e2fsprogs.sourceforge.net/e2fsprogs-release.html), [initialize.c](https://raw.githubusercontent.com/tytso/e2fsprogs/master/lib/ext2fs/initialize.c), [create_inode.c](https://raw.githubusercontent.com/tytso/e2fsprogs/master/misc/create_inode.c), [create_inode_libarchive.c](https://raw.githubusercontent.com/tytso/e2fsprogs/master/misc/create_inode_libarchive.c), [mke2fs.c](https://raw.githubusercontent.com/tytso/e2fsprogs/master/misc/mke2fs.c).
- reproducible-builds.org: [SOURCE_DATE_EPOCH](https://reproducible-builds.org/specs/source-date-epoch/), [system images](https://reproducible-builds.org/docs/system-images/).
- Project docs: [Debusine package repositories](https://freexian-team.pages.debian.net/debusine/explanation/package-repositories.html) and [MmDebstrap task](https://freexian-team.pages.debian.net/debusine/reference/tasks/worker/mmdebstrap.html); [live-manual 8](https://live-team.pages.debian.net/live-manual/html/live-manual/customizing-package-installation.en.html); [debos actions](https://pkg.go.dev/github.com/go-debos/debos/actions); [ELBE schema](https://elbe-rfs.org/docs/sphinx/article-elbe-schema-reference.html); [Isar user manual](https://github.com/ilbers/isar/blob/master/doc/user_manual.md), [debian-common.conf](https://raw.githubusercontent.com/ilbers/isar/master/meta/conf/distro/debian-common.conf); [meta-debian](https://github.com/meta-debian/meta-debian/blob/master/README.md); [apt-cacher-ng manual](https://sources.debian.org/src/apt-cacher-ng/latest/doc/README/); [aptly overview](https://www.aptly.info/doc/overview/), [aptly mirror create](https://www.aptly.info/doc/aptly/mirror/create/); [DebianRepository/Format](https://wiki.debian.org/DebianRepository/Format).
- Not readable today: the GNU tar manual's Reproducibility page (HTTP 429, three attempts); `wiki.debian.org/snapshot.debian.org` and `snapshot.debian.org/news/`, `/doc/api/` (404: the front page and the salsa `API` file hold that content).
