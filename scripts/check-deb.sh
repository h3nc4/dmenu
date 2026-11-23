#!/bin/sh

# Checks the .deb in a fresh Debian or Devuan container, as root. It runs lintian, then installs
# and purges the package alone and again beside suckless-tools, and fails on anything left behind.

set -eu

cd "$(dirname "$0")/../"

package="dmenu-h3nc4"
set -- "${PWD}"/"${package}"_*_amd64.deb
[ -f "$1" ] || {
  echo "check-deb.sh: no ${package} .deb in ${PWD}" >&2
  exit 1
}
deb="$1"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends lintian >/dev/null
lintian --fail-on error,warning --info "${deb}"

purge_and_check() {
  apt-get purge -y -qq "${package}"
  if dpkg-query -W -f '${db:Status-Status}\n' "${package}" 2>/dev/null | grep -qv '^not-installed$'; then
    echo "check-deb.sh: dpkg still knows ${package}" >&2
    exit 1
  fi
  diversions="$(dpkg-divert --list | grep "${package}" || true)"
  [ -z "${diversions}" ] || {
    printf 'check-deb.sh: diversions left behind:\n%s\n' "${diversions}" >&2
    exit 1
  }
  for path in /usr/bin/dmenu.suckless-tools /usr/share/doc/"${package}" /usr/share/lintian/overrides/"${package}"; do
    [ ! -e "${path}" ] || {
      echo "check-deb.sh: ${path} left behind" >&2
      exit 1
    }
  done
}

expect_version() {
  shown="$("$1" -v)"
  [ "${shown}" = "$2" ] || {
    echo "check-deb.sh: $1 -v says ${shown}, expected $2" >&2
    exit 1
  }
}

ours="dmenu-$(sed -n 's/^VERSION = //p' config.mk)"

apt-get install -y -qq --no-install-recommends "${deb}"
expect_version dmenu "${ours}"
command -v stest
purge_and_check
for path in /usr/bin/dmenu /usr/bin/dmenu_path /usr/bin/dmenu_run /usr/bin/stest; do
  [ ! -e "${path}" ] || {
    echo "check-deb.sh: ${path} left behind" >&2
    exit 1
  }
done

apt-get install -y -qq --no-install-recommends suckless-tools
stock="$(dmenu -v)"
apt-get install -y -qq --no-install-recommends "${deb}"
expect_version dmenu "${ours}"
expect_version /usr/bin/dmenu.suckless-tools "${stock}"
command -v slock
purge_and_check
expect_version dmenu "${stock}"
dpkg --verify suckless-tools

echo "check-deb.sh: ${deb##*/} passed"
