#!/bin/sh

# Builds dmenu-h3nc4_<version>_amd64.deb in the repository root from what `make install` installs
# under /usr. Run it on trixie, because dpkg-shlibdeps on sid sets minimums older releases lack.

set -eu

cd "$(dirname "$0")/../"

package="dmenu-h3nc4"
maintainer="Dreamweaver <me@h3nc4.com>"

# The commit time in UTC sorts each build above the one before it, and the hash tells two builds of one second apart.
upstream="$(sed -n 's/^VERSION = //p' config.mk)"
stamp="$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d%H%M%S)"
commit="$(git rev-parse HEAD)"
date="$(git log -1 --format=%cD)"
version="${upstream}+git${stamp}.$(printf '%s' "${commit}" | cut -c1-8)"
deb="${package}_${version}_amd64.deb"

# suckless-tools installs these same paths. Diverting them keeps its slock, tabbed and the rest installed.
clashing="/usr/bin/dmenu /usr/bin/dmenu_path /usr/bin/dmenu_run /usr/bin/stest
/usr/share/man/man1/dmenu.1.gz /usr/share/man/man1/stest.1.gz"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
root="${work}/root"
doc="${root}/usr/share/doc/${package}"

make clean
# config.mk assigns CFLAGS and LDFLAGS outright, so Debian's hardening flags ride on CC instead.
export DEB_BUILD_MAINT_OPTIONS="hardening=+all"
cppflags="$(dpkg-buildflags --get CPPFLAGS)"
cflags="$(dpkg-buildflags --get CFLAGS)"
ldflags="$(dpkg-buildflags --get LDFLAGS)"
make CC="cc ${cppflags} ${cflags} ${ldflags}"
make install DESTDIR="${root}" PREFIX=/usr

strip --remove-section=.comment --remove-section=.note --strip-unneeded \
  "${root}/usr/bin/dmenu" "${root}/usr/bin/stest"
gzip -9n "${root}/usr/share/man/man1/dmenu.1" "${root}/usr/share/man/man1/stest.1"

mkdir -p "${doc}" "${root}/usr/share/lintian/overrides"
{
  printf 'dmenu, packaged by %s from https://github.com/h3nc4/dmenu\n\n' "${maintainer}"
  cat LICENSE
} >"${doc}/copyright"
printf '%s (%s) unstable; urgency=medium\n\n  * Build of commit %s.\n\n -- %s  %s\n' \
  "${package}" "${version}" "${commit}" "${maintainer}" "${date}" |
  gzip -9n >"${doc}/changelog.gz"
cat >"${root}/usr/share/lintian/overrides/${package}" <<EOF
# Upstream doesn't write a manual page for either helper, and dmenu(1) describes dmenu_run.
${package}: no-manual-page [usr/bin/dmenu_path]
${package}: no-manual-page [usr/bin/dmenu_run]
EOF

installed_size="$(du -sk "${root}" | cut -f1)"
mkdir -p "${work}/debian" "${root}/DEBIAN"
printf 'Source: %s\n\nPackage: %s\nArchitecture: amd64\n' "${package}" "${package}" >"${work}/debian/control"
depends="$(
  cd "${work}" &&
    dpkg-shlibdeps -O "${root}/usr/bin/dmenu" "${root}/usr/bin/stest" |
    sed -n 's/^shlibs:Depends=//p'
)"
[ -n "${depends}" ] || {
  echo "deb.sh: dpkg-shlibdeps found no dependencies" >&2
  exit 1
}

{
  cat <<'EOF'
#!/bin/sh
set -e
if [ "$1" = install ] || [ "$1" = upgrade ]; then
EOF
  for path in ${clashing}; do
    case "${path}" in
      *.1.gz) diverted="${path%.1.gz}.suckless-tools.1.gz" ;;
      *) diverted="${path}.suckless-tools" ;;
    esac
    printf '  dpkg-divert --package %s --rename --divert %s --add %s\n' "${package}" "${diverted}" "${path}"
  done
  printf 'fi\n'
} >"${root}/DEBIAN/preinst"
{
  cat <<'EOF'
#!/bin/sh
set -e
case "$1" in
  remove | abort-install | disappear)
EOF
  for path in ${clashing}; do
    printf '    dpkg-divert --package %s --rename --remove %s\n' "${package}" "${path}"
  done
  printf '    ;;\nesac\n'
} >"${root}/DEBIAN/postrm"
chmod 0755 "${root}/DEBIAN/preinst" "${root}/DEBIAN/postrm"

cat >"${root}/DEBIAN/control" <<EOF
Package: ${package}
Version: ${version}
Architecture: amd64
Maintainer: ${maintainer}
Installed-Size: ${installed_size}
Depends: ${depends}
Provides: dmenu
Section: x11
Priority: optional
Homepage: https://github.com/h3nc4/dmenu
Description: dynamic menu for X, h3nc4 build
 dmenu reads a list of newline-separated items from standard input and
 shows them as a menu with incremental matching. dmenu_run starts the
 program picked from the commands on PATH.
 .
 This build installs beside suckless-tools and diverts its dmenu, dmenu_path,
 dmenu_run and stest while installed.
EOF
(cd "${root}" && find usr -type f -exec md5sum {} + | sort -k2) >"${root}/DEBIAN/md5sums"

dpkg-deb --root-owner-group --build "${root}" "${deb}"
