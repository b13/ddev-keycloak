#!/bin/bash

@test "Test import of all configuration files in .ddev/keycloak/import" {
    run ddev kcctl import

    [ "$status" -eq 0 ]
    [[ "$output" == *"to container and import data"* ]]
}

@test "Test export of all realms and users" {
    run ddev kcctl export

    [ "$status" -eq 0 ]
    [[ "$output" == *"Exporting into directory /opt/keycloak/data/import"* ]]
}

@test "Test 'master' realm not exported" {
    run ddev kcctl export master

    [ "$status" -eq 0 ]
    [[ "$output" == *"'master' is not exported because it is the default realm"* ]]
}

@test "Delete/wipe configuration" {
    run ddev kcctl delete

    [ "$status" -eq 0 ]
    [[ "$output" == *"Delete database and configuration in container"* ]]
}

@test "Test kc command" {
  run ddev kc

  [ "$status" -eq 0 ]
  [[ "$output" == *"Keycloak - Open Source Identity and Access Management"* ]]
}

@test "Send request from 'web' to the api" {
    ddev exec bash -c "until nc -z keycloak 8080; do sleep 2; done;"

    run curl -L --fail -H 'Content-Type: application/json' -X GET "https://test-keycloak-addon.ddev.site:8443/"
    echo "$status"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Administration Console"* ]]
}

@test "Metadata fetched internally advertises the browser-reachable URL" {
    ddev exec bash -c "until nc -z keycloak 8080; do sleep 2; done;"

    run ddev exec curl -s --fail http://keycloak:8080/realms/master/protocol/saml/descriptor

    [ "$status" -eq 0 ]
    [[ "$output" == *"https://test-keycloak-addon.ddev.site:8443/realms/master"* ]]
    [[ "$output" != *"http://keycloak:8080"* ]]
}

@test "Docker images are overridable via .ddev/.env.keycloak" {
    cd "${TESTDIR}"

    run docker inspect --format '{{.Config.Image}}' ddev-${PROJNAME}-keycloak
    [ "$status" -eq 0 ]
    [[ "$output" == "quay.io/keycloak/keycloak:26.7" ]]

    ddev dotenv set .ddev/.env.keycloak --keycloak-docker-image="quay.io/keycloak/keycloak:26.1"
    ddev restart -y >/dev/null

    run docker inspect --format '{{.Config.Image}}' ddev-${PROJNAME}-keycloak
    [ "$status" -eq 0 ]
    [[ "$output" == "quay.io/keycloak/keycloak:26.1" ]]

    rm -f .ddev/.env.keycloak
    ddev restart -y >/dev/null
}

@test "The ddev mkcert root CA is present in Keycloak's truststore" {
    ddev exec bash -c "until nc -z keycloak 8080; do sleep 2; done;"

    run ddev exec -s keycloak cat /opt/keycloak/conf/truststores/rootCA.pem

    [ "$status" -eq 0 ]
    [[ "$output" == *"BEGIN CERTIFICATE"* ]]
}

@test "Keycloak trusts the ddev certificate for its own outgoing HTTPS calls" {
    ddev exec bash -c "until nc -z keycloak 8080; do sleep 2; done;"

    base="https://${PROJNAME}.ddev.site:8443"
    token=$(curl -s --fail -X POST "${base}/realms/master/protocol/openid-connect/token" \
        -d client_id=admin-cli -d username=admin -d password=password -d grant_type=password \
        | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
    [ -n "$token" ]

    # Keycloak fetches 'fromUrl' itself, so this only succeeds when ddev's mkcert
    # root CA is trusted by the JVM inside the keycloak container.
    run curl -s --fail -X POST "${base}/admin/realms/master/identity-provider/import-config" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "{\"providerId\":\"oidc\",\"fromUrl\":\"${base}/realms/master/.well-known/openid-configuration\"}"

    [ "$status" -eq 0 ]
    [[ "$output" == *"authorizationUrl"* ]]
}
