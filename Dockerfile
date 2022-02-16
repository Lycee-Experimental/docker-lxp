# ---------------------------------------------------------------------------------------------------------------------#
# BASE IMAGE - BUILDERS
# ---------------------------------------------------------------------------------------------------------------------#
FROM python:3.9.10-slim as base-image
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
  POETRY_VIRTUALENVS_CREATE=false \
  PATH="$PATH:/runtime/bin" \
  PYTHONPATH="$PYTHONPATH:/runtime/lib/python3.9/site-packages" \
  # Versions:
  POETRY_VERSION=1.1.13

# System deps:
#RUN apt-get update && apt-get install -y build-essential unzip wget python-dev
RUN apt-get update \
    && apt install -y curl git gdal-bin libgdal-dev libpq-dev libmariadb-dev libffi6
#    && curl -sSL https://install.python-poetry.org | python - -y

RUN pip install "poetry==$POETRY_VERSION"
WORKDIR /django-lxp
COPY /django-lxp/pyproject.toml /django-lxp/poetry.lock /django-lxp/

# Generate requirements and install *all* dependencies.
RUN poetry export --dev --without-hashes --no-interaction --no-ansi -f requirements.txt -o requirements.txt
RUN pip install --prefix=/runtime --force-reinstall -r requirements.txt

COPY . /django-lxp
# I dont want poetry to do some naughty stuff
# I'll make sure to replicate the exact environment by copying deps file and lock
#COPY django-lxp/ .

# ---------------------------------------------------------------------------------------------------------------------#
# PRODUCTION IMAGE
# ---------------------------------------------------------------------------------------------------------------------#
FROM base-image as production
RUN apt-get update \
    && apt install -y gdal-bin libglib2.0-0 libpango-1.0-0 libpangoft2-1.0-0 netcat
COPY --from=build-image /runtime /usr/local
COPY /django-lxp /django-lxp
COPY /entrypoint.sh .
WORKDIR /django-lxp
#RUN python manage.py migrate
# run entrypoint.sh to verify that Postgres is healthy before applying the migrations
# and running the Django server
#ENTRYPOINT ['/django-lxp/entrypoint.sh']
ENTRYPOINT ["sh", "/entrypoint.sh"]
