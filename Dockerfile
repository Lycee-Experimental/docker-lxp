# ---------------------------------------------------------------------------------------------------------------------#
# BASE IMAGE - BUILDERS
# ---------------------------------------------------------------------------------------------------------------------#
FROM python:3.10-slim-bullseye as base-image
# ---------------------------------------------------------------------------------------------------------------------#
# BUILD IMAGE
# ---------------------------------------------------------------------------------------------------------------------#
FROM base-image as build-image
ENV PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_NO_INTERACTION=1 \
  POETRY_HOME="/opt/poetry" \
  POETRY_VIRTUALENVS_CREATE=false \
  PATH="$PATH:/runtime/bin:/opt/poetry/bin" \
  PYTHONPATH="$PYTHONPATH:/runtime/lib/python3.10/site-packages"

# Install build dependencies
RUN apt-get update \
    && apt install -y curl git gdal-bin libgdal-dev libpq-dev libmariadb-dev libffi-dev g++ libfreetype6-dev

WORKDIR /django-lxp
COPY /django-lxp/pyproject.toml /django-lxp/poetry.lock /django-lxp/

# Install Poetry.
RUN curl -sSL https://install.python-poetry.org | python3.10 -
# Generate requirements
RUN poetry export --dev --without-hashes --no-interaction --no-ansi -f requirements.txt -o requirements.txt
# Build python dependencies
RUN python3.10 -m pip install --prefix=/runtime --force-reinstall -r requirements.txt

COPY . /django-lxp

# ---------------------------------------------------------------------------------------------------------------------#
# PRODUCTION IMAGE
# ---------------------------------------------------------------------------------------------------------------------#
FROM base-image as production
RUN apt-get update \
    && apt install -y gdal-bin libglib2.0-0 libpango-1.0-0 libpangoft2-1.0-0 netcat
COPY --from=build-image /runtime /usr/local
COPY django-lxp /django-lxp/
COPY /entrypoint.sh .
WORKDIR /django-lxp
#RUN python manage.py migrate
# run entrypoint.sh to verify that Postgres is healthy before applying the migrations
# and running the Django server
#ENTRYPOINT ['/django-lxp/entrypoint.sh']
ENTRYPOINT ["sh", "/entrypoint.sh"]
