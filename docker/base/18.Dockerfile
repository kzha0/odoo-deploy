FROM debian:trixie-slim

SHELL ["/bin/bash", "-xeuo", "pipefail", "-c"]

ENV LANG=C.UTF-8
ENV PATH=/home/odoo/env/bin:${PATH}
ENV ODOO_RC=/etc/odoo/odoo.conf

ARG UID=1000
ARG GID=1000
ARG TARGETARCH
ARG PYTHON_VERSION=3.13
ARG ODOO_VERSION=18.0
ARG ODOO_REPOSITORY="OCA/OCB"
ARG WKHTMLTOPDF_VERSION=0.12.6.1-3
ARG WKHTMLTOPDF_TARGET=bookworm
ARG WKHTMLTOPDF_ARM64_SHA=b6606157b27c13e044d0abbe670301f88de4e1782afca4f9c06a5817f3e03a9c
ARG WKHTMLTOPDF_AMD64_SHA=98ba0d157b50d36f23bd0dedf4c0aa28c7b0c50fcdcdc54aa5b6bbba81a3941d
ARG WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.${WKHTMLTOPDF_TARGET}_${TARGETARCH}.deb"
ARG GEOLITE_GITHUB_REPOSITORY="P3TERX/GeoLite.mmdb"

# install system packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    groupadd -g ${GID} odoo -o \
    && useradd -m -s /bin/bash -u ${UID} -g ${GID} odoo \
    && apt-get update \
    && if [ "${TARGETARCH}" = "arm64" ]; then \
        SHA=${WKHTMLTOPDF_ARM64_SHA}; \
    elif [ "${TARGETARCH}" = "amd64" ]; then \
        SHA=${WKHTMLTOPDF_AMD64_SHA}; \
    else \
        echo "Unsupported architecture: ${TARGETARCH}" >&2; \
        exit 1; \
    fi \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && curl -fSLo /wkhtmltox.deb "${WKHTMLTOPDF_URL}" \
    && head -c 7 wkhtmltox.deb | grep -aq '^!<arch>' \
    && echo "${SHA} /wkhtmltox.deb" | sha256sum -c - \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        "python${PYTHON_VERSION}" \
        python3-pip \
        python3-venv \
        python3-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libfreetype6-dev \
        build-essential \
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
        ./wkhtmltox.deb \
    && mkdir -p /usr/shr/GeoIP \
    && curl -Lo /usr/shr/GeoIP/GeoLite2-City.mmdb "https://github.com/${GEOLITE_GITHUB_REPOSITORY}/raw/download/GeoLite2-City.mmdb" \
    && curl -Lo /usr/shr/GeoIP/GeoLite2-Country.mmdb "https://github.com/${GEOLITE_GITHUB_REPOSITORY}/raw/download/GeoLite2-Country.mmdb" \
    && curl -Lo /usr/shr/GeoIP/GeoLite2-ASN.mmdb "https://github.com/${GEOLITE_GITHUB_REPOSITORY}/raw/download/GeoLite2-ASN.mmdb" \
    && apt-get autopurge -y \
    && rm -rf /wkhtmltox.deb /var/lib/apt/lists/* /tmp/* \
    && sync

# install dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    npm install --force -g rtlcss@3.4.0 \
    && curl -o /requirements.txt "https://raw.githubusercontent.com/${ODOO_REPOSITORY}/${ODOO_VERSION}/requirements.txt" \
    && pip install --break-system-packages -r /requirements.txt \
        rlpycairo \
        "pypdf2<3.0" \
    && rm -f /requirements.txt

# install odoo
RUN git clone \
        --depth 1 \
        --branch ${ODOO_VERSION} \
        --single-branch \
        "https://github.com/${ODOO_REPOSITORY}.git" /opt/odoo \
    && pip install --break-system-packages /opt/odoo  \
    && python3 -m venv /home/odoo/env --system-site-packages \
    && ln -sf /opt/odoo/odoo-bin /usr/local/bin/odoo \
    && mkdir -p "/home/odoo/env/lib/python${PYTHON_VERSION}/site-packages/addons" \
    && mkdir -p  /var/lib/odoo /etc/odoo \
    && chown -R odoo:odoo /opt /var/lib/odoo /etc/odoo /home/odoo \
    && sync

COPY setup-util /usr/local/bin/setup-util
COPY wait-for-psql /usr/local/bin/wait-for-psql
COPY template.odoo.conf /home/odoo/template.odoo.conf
COPY set-config.sh /home/odoo/set-config.sh
COPY entrypoint.sh /home/odoo/entrypoint.sh

LABEL maintainer="Soolit Technologies" \
      uploaders="Soolit Technologies" \
      description="Odoo base image for custom Odoo deployments"

USER odoo
WORKDIR /home/odoo
EXPOSE 8069 8072
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=30s \
    CMD curl -fsS "http://127.0.0.1:${ODOO_HTTP_PORT:-8069}/web/health" || exit 1
VOLUME ["/var/lib/odoo"]
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/home/odoo/entrypoint.sh"]
CMD ["odoo"]
