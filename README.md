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

```bash
ddev get b13/ddev-keycloak && ddev restart
```

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
