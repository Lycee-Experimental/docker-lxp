# pull official alpine image (légère)
FROM python:3.9.6-alpine

# set work directory
WORKDIR /usr/src/app

# set environment variables
# Prevents Python from writing pyc files to disc (equivalent to python -B option)
ENV PYTHONDONTWRITEBYTECODE 1
# Prevents Python from buffering stdout and stderr (equivalent to python -u option)
ENV PYTHONUNBUFFERED 1

# install psycopg2 dependencies
RUN apk update \
    && apk add fontconfig postgresql-dev gcc python3-dev musl-dev jpeg-dev zlib-dev libffi-dev pango openjpeg-dev g++
# install dependencies
COPY app .
COPY app/requirements.txt .
RUN pip install --upgrade pip
# copy project
RUN pip install -r requirements.txt
# run entrypoint.sh to verify that Postgres is healthy before applying the migrations and running the Django development server
ENTRYPOINT ["/usr/src/app/entrypoint.sh"]