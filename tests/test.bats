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
    # Wait for API to get ready
    max_retry=30
    counter=0
    until ddev exec "curl --fail -H 'Content-Type: application/json' -X GET \"http://keycloak:8080\"" 2> /dev/null
    do
       sleep 1
       [[ counter -eq $max_retry ]] && exit 1
       ((counter=counter+1))
    done

    run ddev exec "curl --fail -H 'Content-Type: application/json' -X GET \"http://keycloak:8080\""
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Administration Console"* ]]
}

