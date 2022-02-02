#!/usr/bin/env bash
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py migrate metrics --database=metrics
# Load the new Django version of metrics table
python manage.py load_metrics_from_db
deactivate
