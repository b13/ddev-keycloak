#!/usr/bin/env bats

setup_suite() {
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  set -eu -o pipefail
  export TESTDIR=~/tmp/test-keycloak-addon
  mkdir -p $TESTDIR
  export PROJNAME=test-keycloak-addon
  export DDEV_NON_INTERACTIVE=true

  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  ddev start -y >/dev/null

  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get "${DIR}/.."
  cp -rf "$DIR" "$TESTDIR/"
  ddev restart -y >/dev/null
}

teardown_suite() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  cd /
  # Plain rm is enough in the normal case; sudo is only a fallback for
  # root-owned leftovers, and it cannot prompt in a non-interactive run.
  # Cleanup must never fail the suite after the tests themselves passed.
  if [ "${TESTDIR}" != "" ]; then
    rm -rf "${TESTDIR}" 2>/dev/null \
      || sudo -n rm -rf "${TESTDIR}" 2>/dev/null \
      || printf "warning: could not remove %s\n" "${TESTDIR}" >&2
  fi
}
