ARG ODOO_VERSION=18.0
ARG ODOO_IMAGE=soolit-tech/odoo-base
FROM ${ODOO_IMAGE}:${ODOO_VERSION}

SHELL ["/bin/bash", "-xeuo", "pipefail", "-c"]

ARG UID=1000
ARG GID=1000
ARG ODOO_VERSION
RUN --mount=type=bind,source=${ODOO_VERSION}.repos.json,target=/tmp/repos.json \
    --mount=type=cache,target=/home/odoo/.cache/pip,uid=${UID},gid=${GID} \
    setup-util get-addons -d /opt/oca -j /tmp/repos.json

ARG ODOO_SERVER_WIDE_MODULES="base,web,session_redis"
ENV ODOO_SERVER_WIDE_MODULES=$ODOO_SERVER_WIDE_MODULES

LABEL maintainer="Soolit Technologies" \
      uploaders="Soolit Technologies" \
      description="Odoo image supercharged with community modules"
