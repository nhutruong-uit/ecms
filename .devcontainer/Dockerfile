# Image cho Codespace: Debian 12 + Python 3.11 (cùng phiên bản với CI) + ODBC Driver 18 for SQL Server.
FROM mcr.microsoft.com/devcontainers/python:1-3.11-bookworm

# Image gốc kèm kho apt của Yarn có khoá GPG hết hạn (NO_PUBKEY 62D54FD4003F6525) → mọi apt-get update đều lỗi,
# kể cả bước cài feature docker-in-docker. ECMS không dùng Yarn nên gỡ hẳn kho này.
RUN rm -f /etc/apt/sources.list.d/yarn*

# ODBC Driver 18 cho pyodbc – cùng cách cài với CI (.github/workflows/ci.yml), kho Debian thay cho Ubuntu
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && curl -fsSL "https://packages.microsoft.com/config/debian/12/prod.list" -o /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update -q \
    && ACCEPT_EULA=Y apt-get install -y -q --no-install-recommends msodbcsql18 unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*
