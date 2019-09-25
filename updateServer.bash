#!/usr/bin/env bash
./updateLocal.bash
source venv/bin/activate
python manage.py collectstatic --noinput --clear
