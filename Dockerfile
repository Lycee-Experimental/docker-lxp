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
    && apt install -y curl git gdal-bin libgdal-dev libpq-dev libmariadb-dev libffi-dev g++

WORKDIR /django-lxp
COPY /django-lxp/pyproject.toml /django-lxp/poetry.lock /django-lxp/

# Install Poetry.
RUN curl -sSL https://install.python-poetry.org | python -
# Generate requirements
RUN poetry export --dev --without-hashes --no-interaction --no-ansi -f requirements.txt -o requirements.txt
# Build python dependencies
RUN python -m pip install --prefix=/runtime --force-reinstall -r requirements.txt

COPY . /django-lxp

# ---------------------------------------------------------------------------------------------------------------------#
# PRODUCTION IMAGE
# ---------------------------------------------------------------------------------------------------------------------#
FROM base-image as production
RUN apt-get update \
    && apt install -y gdal-bin libglib2.0-0 netcat chromium-driver
COPY --from=build-image /runtime /usr/local
RUN addgroup djangolxp && adduser djangolxp --ingroup djangolxp
COPY ./django-lxp /home/djangolxp/django-lxp
COPY ./entrypoint.sh /home/djangolxp/
RUN sed -i 's/\r$//g' /home/djangolxp/entrypoint.sh
RUN chmod +x /home/djangolxp/entrypoint.sh
RUN chown -R djangolxp:djangolxp /home/djangolxp/django-lxp
#RUN mkdir /django-lxp/staticfiles
WORKDIR /home/djangolxp/django-lxp
# create the app user
# change to the app user
USER djangolxp
#RUN python manage.py migrate
# run entrypoint.sh to verify that Postgres is healthy before applying the migrations
# and running the Django server
#ENTRYPOINT ['/django-lxp/entrypoint.sh']
ENTRYPOINT ["sh", "/home/djangolxp/entrypoint.sh"]
