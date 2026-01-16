#!/bin/bash

set -eu

ODOO_VERSION=18.0
DATE=$(date +"%Y-%m-%d")

(
    LABEL=soolit-tech/odoo-base
    TAG=$ODOO_VERSION
    TAG_SHORT=${ODOO_VERSION%.0}
    cd base
    docker build \
        -t "${LABEL}:latest" \
        -t "${LABEL}:${TAG}" \
        -t "${LABEL}:${TAG}_${DATE}" \
        -t "${LABEL}:${TAG_SHORT}" \
        -t "${LABEL}:${TAG_SHORT}_${DATE}" \
        -f "18.Dockerfile" \
        .
)

(
    LABEL=soolit-tech/odoo-oca
    TAG=$ODOO_VERSION
    TAG_SHORT=${ODOO_VERSION%.0}
    cd oca
    docker build \
        -t "${LABEL}:latest" \
        -t "${LABEL}:${TAG}" \
        -t "${LABEL}:${TAG}_${DATE}" \
        -t "${LABEL}:${TAG_SHORT}" \
        -t "${LABEL}:${TAG_SHORT}_${DATE}" \
        -f "18.Dockerfile" \
        .
)

(
    LABEL=soolit-tech/odoo-builder
    TAG=$ODOO_VERSION
    TAG_SHORT=${ODOO_VERSION%.0}
    cd builder
    docker build \
        -t "${LABEL}:latest" \
        -t "${LABEL}:${TAG}" \
        -t "${LABEL}:${TAG}_${DATE}" \
        -t "${LABEL}:${TAG_SHORT}" \
        -t "${LABEL}:${TAG_SHORT}_${DATE}" \
        -f "18.Dockerfile" \
        .
)

(
    LABEL=soolit-tech/odoo-builder-oca
    TAG=$ODOO_VERSION
    TAG_SHORT=${ODOO_VERSION%.0}
    cd builder
    docker build \
        -t "${LABEL}:latest" \
        -t "${LABEL}:${TAG}" \
        -t "${LABEL}:${TAG}_${DATE}" \
        -t "${LABEL}:${TAG_SHORT}" \
        -t "${LABEL}:${TAG_SHORT}_${DATE}" \
        --build-arg ODOO_IMAGE=soolit-tech/odoo-oca \
        -f "18.Dockerfile" \
        .
)
