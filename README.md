# inventory-api

Rails API backend for the Inventory app — a personal item tracker (what you
own, where it is, where it's supposed to be). The web frontend lives in
[inventory-frontend](https://github.com/pjfitzgerald/inventory-frontend).

- **API**: Rails 7 (API-only), PostgreSQL, JWT auth
- **Public instance**: <https://inventory.optimisedthought.com>

---

## The `inventory` CLI

A single dependency-free Ruby script that talks to the same API as the web
app. Nothing to install beyond a Ruby interpreter (2.7 or newer) — no gems, no
`bundle install`, no clone.

### Install

```sh
curl -fsSL -o inventory \
  https://raw.githubusercontent.com/pjfitzgerald/inventory-api/master/cli/inventory
chmod +x inventory
```

Put it somewhere on your `PATH` (`~/.local/bin` or `/usr/local/bin`) if you
want to run it as just `inventory` from anywhere. The examples below assume
you have.

### Log in

```sh
inventory auth login --email you@example.com --password 'your-password'
```

The returned token is saved to `~/.config/inventory/token` (mode 0600) and
reused by every later command, so you only log in once per machine.
`inventory auth logout` discards it.

Don't have an account yet? Sign up from the CLI, then click the link in the
verification email (or pass its token to `auth verify`):

```sh
inventory auth signup --email you@example.com --password 'your-password' --name 'Your Name'
inventory auth verify --token <token-from-the-email-link>
```

### Everyday use

```sh
inventory list                              # every item, as JSON
inventory list --format table               # ...as an aligned table
inventory list --query tent                 # search name/category/tags/location
inventory show 42                           # one item

inventory create --name 'Down jacket' \
  --current-location 'Hall cupboard' \
  --intended-location 'Loft' \
  --tags camping,clothing \
  --quantity 1

inventory update 42 --current-location 'Loft' --status Sell
inventory delete 42
```

`inventory --help` prints the full command and option list.

### Shared inventories

Every account has a personal inventory, and can be given access to inventories
other people own. Item commands act on your personal one unless you name
another with `--inventory`:

```sh
inventory inventories --format table        # what you can reach, and your role in each
inventory list --inventory 7                # items in the shared inventory with id 7
inventory create --inventory 7 --name 'Lawnmower'
```

`show`, `update`, and `delete` take an item id and find it wherever you can
reach it, so they need no `--inventory`.

Roles are set by the inventory's owner in the web app — the CLI reads them but
does not change them. An **owner** can do anything, an **editor** can add,
change, and delete items, and a **viewer** can only read: a viewer's write is
refused with "You have view-only access to this inventory".

### Options worth knowing

| Option | Purpose |
| --- | --- |
| `--format=json\|table` | `json` (the default) pipes into `jq` or a script; `table` is for reading. |
| `--url=URL` | Point at a different deployment. Defaults to `$INVENTORY_API_URL`, then the public instance. |
| `--field=key:value` | Set a custom field on `create` / `update`. Repeatable. |
| `--tags=a,b,c` | Comma-separated; replaces the item's tags. |
| `--inventory=ID` | Act on a shared inventory instead of your personal one. |

Environment variables:

| Variable | Effect |
| --- | --- |
| `INVENTORY_API_URL` | Default API base URL, e.g. `http://localhost:3000/api/v1` for local dev. |
| `INVENTORY_API_TOKEN` | Auth token for this invocation; overrides the stored one. Handy in CI or a shared shell. |

### Scripting with it

JSON output plus non-zero exit codes on failure make it usable in a pipeline:

```sh
# Everything that isn't where it's supposed to be
inventory list | jq -r '.[] | select(.intended_location != null and
  .current_location != .intended_location) |
  "\(.name): \(.current_location) → \(.intended_location)"'

# Count items per location
inventory list | jq -r '.[].current_location' | sort | uniq -c | sort -rn
```

Errors go to stderr with a non-zero exit status, so `set -e` behaves: a
missing item prints `Not found`, a rejected change prints
`Validation failed (...)`, and an unreachable server says so rather than
dumping a stack trace.

### Account management

```sh
inventory auth whoami                        # who am I logged in as
inventory auth request-reset --email you@example.com
inventory auth reset-password --token <token-from-the-email> --password 'new-password'
```

Passwords must be at least 10 characters, must not be a well-known common
password, and must not contain your email address.

---

## Development

Requires Ruby 3.2.0 and PostgreSQL; `mise.toml` in the parent directory pins
the toolchain.

```sh
bundle install
bin/rails db:setup
bin/rails server
bin/rails test
```

There is also a Thor-based CLI at `bin/inventory` used during development —
same command surface, but it runs inside the app's bundle and defaults to
localhost. The standalone `cli/inventory` script above is the one to hand to
users.

### Rate limiting

The auth endpoints are throttled by [rack-attack]; the rules and the reasoning
behind each limit live in `config/initializers/rack_attack.rb`. Item endpoints
are deliberately *not* throttled — a CSV or backup import POSTs one row at a
time, and those endpoints require a valid JWT anyway.

[rack-attack]: https://github.com/rack/rack-attack

## Deployment

Two self-hosted Docker stacks (prod and staging) plus a public Railway
deployment. See the project notes for the full runbook.
