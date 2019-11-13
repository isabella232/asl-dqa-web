#!/usr/bin/env bash
source venv/bin/activate
pip install -r requirements.txt --cert=/usr/share/ca-certificates/extra/DOIRootCA2.cer
python manage.py migrate
