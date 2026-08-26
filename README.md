# Keycloak Add-On for DDEV

This DDEV add-on provides a [Keycloak](https://www.keycloak.org/) service for DDEV.

Keycloak is an Open Source Identity Provider and Access Management software.

**It provides ...**

* Single-Sign On
* Identity Brokering and Social Login
* User Federation
* Support for OpenID, SAML and oAuth2

## Why?

If you want to integrate an Identity Provider in your project using
OpenID, SAML or oAuth2 this addon makes it easy to have this provider
installed locally for testing.

In general, you do not have to deal with remote servers that might give you
a hard time to connect to from your local ddev instance. These servers are
mostly buried behind firewalls and other security mechanism.

## Installation

For DDEV v1.23.5 or above run

```bash
ddev add-on get b13/ddev-keycloak && ddev restart
```

For earlier versions of DDEV run

```bash
ddev get b13/ddev-keycloak && ddev restart
```

### Using alternate images

The add-on ships with a default Keycloak and MariaDB image, but both can be
pointed somewhere else — a different version, a mirror registry, or a locally
built Keycloak image containing your own providers/SPIs.

```bash
# Change the image as appropriate.
ddev dotenv set .ddev/.env.keycloak --keycloak-docker-image="quay.io/keycloak/keycloak:26.4"

ddev restart
```

Commit the `.ddev/.env.keycloak` file to version control so the whole team
runs the same images.

| Variable                   | Flag                         | Default                            |
|----------------------------|------------------------------|------------------------------------|
| `KEYCLOAK_DOCKER_IMAGE`    | `--keycloak-docker-image`    | `quay.io/keycloak/keycloak:26.0`   |
| `KEYCLOAK_DB_DOCKER_IMAGE` | `--keycloak-db-docker-image` | `mariadb:10.11`                    |

> [!IMPORTANT]
> Keycloak migrates its database schema forward automatically when you upgrade,
> but it refuses to start against a database that was already migrated by a
> *newer* version. For a downgrade — or when switching the database image to a
> different engine — wipe the volumes first:
>
> ```bash
> ddev stop
> docker volume rm ddev-<project>_keycloak ddev-<project>_keycloak-db
> ddev restart
> ```
>
> This discards the realms and users inside the container, so run
> `ddev kcctl import` afterwards. That is exactly why the JSON files in
> `.ddev/keycloak/import` belong in git.

### Credentials

**Admin - master realm**

User: `admin`
Password: `password`

**Test - ddev realm**

User: `test`
Password: `test`

## Configuration

The configuration is managed using JSON files in `.ddev/keycloak/import`.
Add the JSON files to git, so it can be shared between users.

Import realms and users:

```bash
ddev kcctl import
```

Export realms and users to `.ddev/keycloak/import`:

```bash
ddev kcctl export <realm, optional>
```

> [!NOTE]
> The 'master' (default) realm will not be exported as it contains the admin user
> which should not be modified at all.

Delete realms and user ('master' will be recreated):

```bash
ddev kcctl delete
```

## Running the keycloak control script

```
ddev kc --help
```

## Theming

`.ddev/keycloak/themes` includes a basic example for the login theme called `ddev`.

* Theming [docs](https://www.keycloak.org/docs/latest/server_development/index.html#_themes)
* Example [themes](https://github.com/keycloak/keycloak/tree/main/examples/themes/src/main/resources/theme)

**Maintained by [@b13](https://github.com/b13)**
