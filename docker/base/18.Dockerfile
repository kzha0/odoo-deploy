FROM debian:trixie-slim

ENV LANG=C.UTF-8
ENV PATH=/home/odoo/env/bin:${PATH}
ENV ODOO_RC=/etc/odoo/odoo.conf

ARG UID=1000
ARG GID=1000
ARG TARGETARCH
ARG PYTHON_VERSION=3.13
ARG ODOO_VERSION=18.0
ARG ODOO_REPOSITORY=https://github.com/OCA/OCB.git
ARG WKHTMLTOPDF_VERSION=0.12.6.1-3
ARG WKHTMLTOPDF_TARGET=bookworm
ARG WKHTMLTOPDF_ARM64_SHA=b6606157b27c13e044d0abbe670301f88de4e1782afca4f9c06a5817f3e03a9c
ARG WKHTMLTOPDF_AMD64_SHA=98ba0d157b50d36f23bd0dedf4c0aa28c7b0c50fcdcdc54aa5b6bbba81a3941d
ARG WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.${WKHTMLTOPDF_TARGET}_${TARGETARCH}.deb"
ARG GEOLITE_GITHUB_REPOSITORY="https://github.com/P3TERX/GeoLite.mmdb"

ADD ${WKHTMLTOPDF_URL} /wkhtmltox.deb
ADD ${GEOLITE_GITHUB_REPOSITORY}/raw/download/GeoLite2-City.mmdb /usr/share/GeoIP/GeoLite2-City.mmdb
ADD ${GEOLITE_GITHUB_REPOSITORY}/raw/download/GeoLite2-Country.mmdb /usr/share/GeoIP/GeoLite2-Country.mmdb
ADD ${GEOLITE_GITHUB_REPOSITORY}/raw/download/GeoLite2-ASN.mmdb /usr/share/GeoIP/GeoLite2-ASN.mmdb

COPY setup-util /usr/local/bin/setup-util
COPY wait-for-psql /usr/local/bin/wait-for-psql
COPY template.odoo.conf /home/odoo/template.odoo.conf
COPY set-config.sh /home/odoo/set-config.sh
COPY entrypoint.sh /home/odoo/entrypoint.sh

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/tmp/git_cache \
    --mount=type=cache,target=/root/.cache/pip \
    set -eu; \
    if [ "${TARGETARCH}" = "arm64" ]; then \
        SHA=${WKHTMLTOPDF_ARM64_SHA}; \
    elif [ "${TARGETARCH}" = "amd64" ]; then \
        SHA=${WKHTMLTOPDF_AMD64_SHA}; \
    else \
        echo "Unsupported architecture: ${TARGETARCH}" >&2; \
        exit 1; \
        fi; \
    head -c 7 /wkhtmltox.deb | grep -aq '^!<arch>'; \
    echo "${SHA} /wkhtmltox.deb" | sha256sum -c -; \
    apt-get update && apt-get install -y --no-install-recommends \
        "python${PYTHON_VERSION}" \
        "python${PYTHON_VERSION}-venv" \
        "python${PYTHON_VERSION}-dev" \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libfreetype6-dev \
        build-essential \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        libpq-dev \
        libldap2-dev \
        libsasl2-dev \
        xz-utils \
        fontconfig \
        xfonts-75dpi \
        xfonts-base \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        gettext \
        postgresql-client \
        libcairo2-dev \
        openssh-client \
        git \
        tini \
        ./wkhtmltox.deb; \
    rm -f ; \
    if [ ! -d /tmp/git_cache/odoo/.git ]; then \
        git clone --depth 1 --branch ${ODOO_VERSION} --single-branch ${ODOO_REPOSITORY} /tmp/git_cache/odoo; \
    else \
        git -C /tmp/git_cache/odoo pull; \
    fi; \
    cp -r /tmp/git_cache/odoo /odoo; \
    npm install --force -g rtlcss@3.4.0 \
    && python3 -m venv /home/odoo/env \
    && python -m ensurepip --upgrade \
    && python -m pip install --upgrade pip \
    && python -m pip install rlpycairo "pypdf2<3.0" \
    && python -m pip install -r /odoo/requirements.txt \
    && python -m pip install /odoo \
    && rm -rf /odoo /wkhtmltox.deb \
    && ln -sf "/home/odoo/env/bin/odoo" /usr/local/bin/odoo \
    && mkdir -p "/home/odoo/env/lib/python${PYTHON_VERSION}/site-packages/addons" \
    && groupadd -g ${GID} odoo -o \
    && useradd -m -s /bin/bash -u ${UID} -g ${GID} odoo \
    && mkdir -p  /var/lib/odoo /etc/odoo \
    && chown -R odoo:odoo /opt /var/lib/odoo /etc/odoo /home/odoo \
    && sync

LABEL maintainer="Soolit Technologies" \
      uploaders="Soolit Technologies" \
      description="Odoo base image for custom Odoo deployments"

USER odoo
WORKDIR /home/odoo
EXPOSE 8069 8071 8072
HEALTHCHECK --interval=30s --timeout=5s --retries=10 \
    CMD curl -fsS "http://127.0.0.1:${ODOO_HTTP_PORT:-8069}/web/health" || exit 1
VOLUME ["/var/lib/odoo"]
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/home/odoo/entrypoint.sh"]
CMD ["odoo"]
