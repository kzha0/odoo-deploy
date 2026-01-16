#!/bin/bash

set -e

source /home/odoo/env/bin/activate

./set-config.sh

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql
            exec odoo "$@"
        fi
        ;;
    -*)
        wait-for-psql
        exec odoo "$@"
        ;;
    *)
        if [[ $# -eq 1 ]]; then
            exec /bin/bash -c "$1"
        else
            exec "$@"
        fi
esac

exit 1
