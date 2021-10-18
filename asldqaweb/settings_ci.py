"""
Django settings for dqa test build.
"""

from .settings import *

SECRET_KEY = 'uwh)=eqffff)f%u%pf^0z)h=7s&cf1_r$bsn!vyz4bmxzo0)77'

DATABASES = {
    'default': {
        'NAME': 'auth_db',
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'USER': 'postgres',
        'PASSWORD': 'postgres',
        'HOST': 'postgres',
        'PORT': '5432',
    },
    'metrics': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'dqa_dave',
        'USER': 'postgres',
        'PASSWORD': 'postgres',
        'HOST': 'postgres',
        'PORT': '5432',
        # 'DISABLE_SERVER_SIDE_CURSORS': True
    },
    'metricsold': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'dqa_prod_clone',
        'USER': 'postgres',
        'PASSWORD': 'postgres',
        'HOST': 'postgres',
        'PORT': '5432',
        'DISABLE_SERVER_SIDE_CURSORS': True
    },
}

EXCLUDE_FROM_DEFAULT_GROUPS = []
