ARG ODOO_VERSION=18.0
ARG ODOO_IMAGE=soolit-tech/odoo-base
FROM ${ODOO_IMAGE}:${ODOO_VERSION} AS builder

ONBUILD SHELL ["/bin/bash", "-xeuo", "pipefail", "-c"]

ONBUILD ARG GID=1000
ONBUILD ARG UID=1000
ONBUILD ARG BUILDER_ADDONS_JSON_B64="${BUILDER_ADDONS_JSON_B64:-}"
ONBUILD ARG BUILDER_ADDONS_BASE_DIR="${BUILDER_ADDONS_BASE_DIR:-/opt/addons}"
ONBUILD ENV BUILDER_ADDONS_JSON_B64=${BUILDER_ADDONS_JSON_B64}
ONBUILD ENV BUILDER_ADDONS_BASE_DIR=${BUILDER_ADDONS_BASE_DIR}

ONBUILD RUN --mount=type=cache,target=/home/odoo/.cache/pip,uid=${UID},gid=${GID} \
            if [ -n "${BUILDER_ADDONS_JSON_B64:-}" ]; then \
                setup-util get-addons -j -b "${BUILDER_ADDONS_JSON_B64}"; \
            else \
                echo "BUILDER_ADDONS_JSON_B64 not set; skipping get-addons"; \
            fi
