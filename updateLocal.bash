#!/usr/bin/env bash
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py migrate --database=metrics
