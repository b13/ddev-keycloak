#!/bin/bash

KEYCLOAK_CONTAINER="ddev-${PROJNAME}-keycloak"

setup() {
    # Several tests read and write .ddev/keycloak/import relative to the project.
    cd "${TESTDIR}" || exit 1
}

# Reads a realm through the admin API, for the properties the public realm
# endpoint does not expose.
kcadm_get_realm() {
    docker exec "${KEYCLOAK_CONTAINER}" /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://127.0.0.1:8080/keycloak --realm master --user admin --password password >/dev/null
    docker exec "${KEYCLOAK_CONTAINER}" /opt/keycloak/bin/kcadm.sh get "realms/$1"
}

@test "Bare 'ddev kcctl' prints help instead of failing" {
    run ddev kcctl

    [ "$status" -eq 0 ]
    [[ "$output" == *"Example Usage:"* ]]
}

@test "Test import of all configuration files in .ddev/keycloak/import" {
    run ddev kcctl import

    [ "$status" -eq 0 ]
    [[ "$output" == *"to container and import data"* ]]
    [[ "$output" == *"Import complete"* ]]
}

@test "Keycloak is served under /keycloak on the project's own host" {
    run curl -sf "https://${PROJNAME}.ddev.site/keycloak/realms/master"

    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"realm":"master"'* ]]
}

@test "The admin console is reachable under the path prefix" {
    run curl -sfL "https://${PROJNAME}.ddev.site/keycloak/admin/master/console/"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Administration Console"* ]]
}

# Regression test for the failure this add-on used to have: a service fetching
# metadata over the Docker network got a document advertising
# http://keycloak:8080/... - endpoints no browser can reach, and an issuer that
# does not match the assertion the browser flow produces.
@test "Back-channel metadata advertises the same issuer as the public one" {
    external=$(curl -sf "https://${PROJNAME}.ddev.site/keycloak/realms/master/.well-known/openid-configuration" | tr ',' '\n' | grep '"issuer"')
    internal=$(ddev exec curl -sf "http://keycloak:8080/keycloak/realms/master/.well-known/openid-configuration" | tr ',' '\n' | grep '"issuer"')

    echo "external: ${external}"
    echo "internal: ${internal}"
    [ -n "${external}" ]
    [ "${external}" = "${internal}" ]
    [[ "${external}" == *"https://${PROJNAME}.ddev.site/keycloak/realms/master"* ]]
}

# Two things at once: re-importing an edited realm has to take effect - the boot
# flag --import-realm silently skips a realm that already exists - and the DDEV_*
# placeholders have to be substituted on the way in.
@test "Re-import replaces an existing realm and substitutes DDEV variables" {
    python3 - <<'PY'
import json
p = ".ddev/keycloak/import/ddev-realm.json"
d = json.load(open(p))
d["displayName"] = "${DDEV_PRIMARY_URL}"
json.dump(d, open(p, "w"), indent=2)
PY

    run ddev kcctl import
    [ "$status" -eq 0 ]

    run kcadm_get_realm ddev
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://${PROJNAME}.ddev.site"* ]]
    [[ "$output" != *'${DDEV_PRIMARY_URL}'* ]]
}

# Keycloak's own message-bundle placeholders, "${role_default-roles}" and
# friends, must survive the substitution untouched.
@test "The realm still works after substitution" {
    run ddev exec curl -sf "http://keycloak:8080/keycloak/realms/ddev"

    [ "$status" -eq 0 ]
    [[ "$output" == *'"realm":"ddev"'* ]]
}

@test "Test export of all realms and users" {
    run ddev kcctl export

    [ "$status" -eq 0 ]
    [[ "$output" == *"Exporting into directory /opt/keycloak/data/import"* ]]
}

@test "Export of a single realm writes that realm's files" {
    run ddev kcctl export ddev

    echo "$output"
    [ "$status" -eq 0 ]
    [ -f ".ddev/keycloak/import/ddev-realm.json" ]
    grep -q '"realm"[[:space:]]*:[[:space:]]*"ddev"' .ddev/keycloak/import/ddev-realm.json
}

@test "Test 'master' realm not exported" {
    run ddev kcctl export master

    [ "$status" -eq 0 ]
    [[ "$output" == *"'master' is not exported because it is the default realm"* ]]
}

@test "Test kc command" {
  run ddev kc

  [ "$status" -eq 0 ]
  [[ "$output" == *"Keycloak - Open Source Identity and Access Management"* ]]
}

@test "Keycloak is also reachable on its own port" {
    run curl -sfL "https://${PROJNAME}.ddev.site:8443/keycloak/"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Administration Console"* ]]
}

@test "Refuse to delete the 'master' realm" {
    run ddev kcctl delete master

    [ "$status" -ne 0 ]
    [[ "$output" == *"Refusing to delete the 'master' realm"* ]]
}

@test "Delete a single realm leaves the others alone" {
    run ddev kcctl delete ddev
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Realm 'ddev' deleted"* ]]

    run curl -sf "https://${PROJNAME}.ddev.site/keycloak/realms/ddev"
    [ "$status" -ne 0 ]

    run curl -sf "https://${PROJNAME}.ddev.site/keycloak/realms/master"
    [ "$status" -eq 0 ]
}

@test "Delete/wipe configuration" {
    run ddev kcctl delete

    [ "$status" -eq 0 ]
    [[ "$output" == *"Delete database and configuration in container"* ]]
}
