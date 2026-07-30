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

## URLs

Keycloak is served **under `/keycloak` on the project's own host**:

```
https://<project>.ddev.site/keycloak
```

It is also reachable directly through ddev-router on port 8443,
`https://<project>.ddev.site:8443/keycloak`, which is useful when the web
container is down. Note the path prefix applies there too.

The path prefix is the canonical address because it is the only one that
survives a reverse proxy in front of DDEV — a CI review app, `ddev share`, a
company proxy. Such a proxy generally forwards only port 443 for the site's own
origin, so a service on a port of its own is unreachable. Serving Keycloak on a
path of the site inherits whatever routing and access control the site has.

### Credentials

**Admin - master realm**

User: `admin`
Password: `password`

**Test - ddev realm**

User: `test`
Password: `test`

## Internal vs. public URL

This is the one thing worth reading before integrating anything.

Keycloak derives the `entityID` of its SAML/OIDC metadata, **and every SSO and
SLO `Location` in it**, from the incoming request. A service running in the same
Docker network fetches metadata over `http://keycloak:8080/...` and would
therefore get a document advertising `http://keycloak:8080/...` — endpoints no
browser can reach, and an issuer that does not match the assertion the browser
flow produces. The failure is silent and surfaces much later, looking like a
signature or issuer mismatch.

The add-on prevents this by pinning `KC_HOSTNAME` to the public URL and leaving
`KC_HOSTNAME_BACKCHANNEL_DYNAMIC` at `false`. Your application should then use:

* the **internal** URL to *fetch* metadata — `http://keycloak:8080/keycloak/...`,
  independent of hostname, TLS and any proxy
* the **public** URL for everything a browser follows, which is what the fetched
  metadata already contains

To verify that the two agree — if they differ, every service-to-service
integration is subtly broken:

```bash
URL=https://my-project.ddev.site   # or whatever the project is reached under
diff \
  <(curl -s "$URL/keycloak/realms/ddev/protocol/saml/descriptor" | grep -o 'entityID="[^"]*"') \
  <(ddev exec curl -s http://keycloak:8080/keycloak/realms/ddev/protocol/saml/descriptor | grep -o 'entityID="[^"]*"')
```

## Configuration

Everything the add-on sets on the `keycloak` service can be overridden in
`.ddev/.env.keycloak`, without editing the `#ddev-generated`
`docker-compose.keycloak.yaml`. DDEV applies that file after the compose file,
so it always wins. See `.ddev/.env.keycloak.example` for the full list.

```bash
ddev dotenv set .ddev/.env.keycloak --kc-hostname=https://mr-42.review.example.com/keycloak
ddev restart
```

| Variable | Default | Purpose |
| --- | --- | --- |
| `KC_HOSTNAME` | `$DDEV_PRIMARY_URL/keycloak` | Public origin written into metadata, redirects and SSO/SLO endpoints |
| `KC_HTTP_RELATIVE_PATH` | `/keycloak` | Path Keycloak is served under |
| `KC_BOOTSTRAP_ADMIN_USERNAME` | `admin` | Admin user of the master realm |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | `password` | Admin password |
| `KC_LOG_LEVEL` | `INFO` | `DEBUG` when a login fails for reasons Keycloak does not explain |
| `KEYCLOAK_TAG` | `26.0` | Keycloak image tag |

### Behind a reverse proxy, and in CI

`DDEV_PRIMARY_URL` is always the project's own `<name>.<tld>` — **never** an
`additional_fqdns` entry. Whenever the project is reached under a different name,
set `KC_HOSTNAME` yourself. In a GitLab review app, for example:

```yaml
script:
  - ddev dotenv set .ddev/.env.keycloak --kc-hostname="${CI_ENVIRONMENT_URL%/}/keycloak"
  - ddev start
  - ddev kcctl import
```

Two details that cost time if you find them the hard way:

* The path prefix has to be part of `KC_HOSTNAME`. Keycloak does **not** append
  `KC_HTTP_RELATIVE_PATH` to a hostname given as a URL — with the bare origin it
  advertises `https://host/realms/...`, a path nothing routes.
* Realm files contain absolute URLs (`redirectUris`,
  `saml_single_logout_service_url_redirect`). See "Realm variables" below.

### Web server support

The `/keycloak` route is a proxy in the web container, shipped for both web
servers DDEV manages:

| `webserver_type` | File | Status |
| --- | --- | --- |
| `nginx-fpm` (default) | `.ddev/nginx/keycloak.conf` | supported |
| `apache-fpm` | `.ddev/apache/keycloak.conf` | supported |
| `generic` | — | use port 8443, or add your own proxy and set `KC_HOSTNAME` to match |

Both start cleanly while Keycloak is still booting and pick it up once it is
there, so a cold boot never takes the site down with it.

To change the prefix, change `KC_HTTP_RELATIVE_PATH` **and** both files.

## Realms and users

The configuration is managed using JSON files in `.ddev/keycloak/import`.
Add the JSON files to git, so it can be shared between users.

Import realms and users:

```bash
ddev kcctl import
```

Unlike Keycloak's boot-time `--import-realm`, which silently skips a realm that
already exists, this **replaces** the realms in the files. Editing a realm file
and re-importing does what you would expect.

Export realms and users to `.ddev/keycloak/import`:

```bash
ddev kcctl export <realm, optional>
```

> [!NOTE]
> The 'master' (default) realm will not be exported as it contains the admin user
> which should not be modified at all.

Delete a single realm, or every realm and user when no realm is given
('master' will be recreated):

```bash
ddev kcctl delete <realm, optional>
```

### Realm variables

`ddev kcctl import` substitutes a small set of variables into the realm JSON on
the way in, so a realm file can be committed without hardcoding a hostname:

| Placeholder | Example |
| --- | --- |
| `${KEYCLOAK_PUBLIC_URL}` | `https://my-project.ddev.site/keycloak` (the effective `KC_HOSTNAME`) |
| `${DDEV_PRIMARY_URL}` | `https://my-project.ddev.site` |
| `${DDEV_HOSTNAME}` | `my-project.ddev.site` |
| `${DDEV_SITENAME}` | `my-project` |
| `${DDEV_TLD}` | `ddev.site` |

For example, in a SAML client:

```json
"redirectUris": ["${DDEV_PRIMARY_URL}/*"],
"attributes": {
  "saml_single_logout_service_url_redirect": "${DDEV_PRIMARY_URL}/logout"
}
```

Only these five names are replaced, so Keycloak's own message-bundle
placeholders such as `${role_default-roles}` are left untouched. Substitution
happens on a copy, so the placeholders stay in the committed file.

> [!NOTE]
> `ddev kcctl export` writes back what Keycloak has, which is the *substituted*
> value — re-add the placeholders by hand after exporting a realm that uses them.

> [!NOTE]
> Single logout cannot be made host-independent: a SAML `LogoutRequest` carries
> no return address, so without
> `saml_single_logout_service_url_redirect` the Keycloak session ends while the
> service provider's session stays alive, and single logout looks like a silent
> no-op.

## Running the keycloak control script

```
ddev kc --help
```

## Theming

`.ddev/keycloak/themes` includes a basic example for the login theme called `ddev`.

* Theming [docs](https://www.keycloak.org/docs/latest/server_development/index.html#_themes)
* Example [themes](https://github.com/keycloak/keycloak/tree/main/examples/themes/src/main/resources/theme)

**Maintained by [@b13](https://github.com/b13)**
