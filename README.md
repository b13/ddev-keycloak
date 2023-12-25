# KeyCloak Add-On for DDEV

This DDEV add-on provides a [Keycloak](https://www.keycloak.org/) service for DDEV.

* Theming

## Installation

```bash
ddev get b13/ddev-keycloak && ddev restart
```

### Credentials

**Admin:**

User: `admin`
Password: `password`

**Test:**

User: `test`
Password: `test`

## Configuration

The configuration is managed using JSON files in `.ddev/keycloak/import`.
Add the JSON files to git so it can be shared between users.

Import realms and users:

```bash
ddev kcctl import
```

Export realms and users:

```bash
ddev kcctl export <realm, optional>
```

> [!NOTE]
> The 'master' (default) realm will not be exported as it contains the admin user
> which should not be modified at all.

## Running the keycloak control script

```
ddev kc --help
```

**Maintained by [@b13](https://github.com/b13)**
