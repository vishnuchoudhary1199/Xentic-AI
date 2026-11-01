#!/bin/sh
# Executed by the postgres image's entrypoint on first start (empty data dir).
# Delegates to the same runner used by ./scripts/migrate.sh.
set -eu
SEED=true sh /db/migrate.sh
