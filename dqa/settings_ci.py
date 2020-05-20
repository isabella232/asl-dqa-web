"""
Django settings for dqa test build.
"""

from .settings import *

SECRET_KEY = 'uwh)=eqffff)f%u%pf^0z)h=7s&cf1_r$bsn!vyz4bmxzo0)77'

ALLOWED_HOSTS = ['vmdevwb.cr.usgs.gov',
                 'igskgacgvmdevwb.cr.usgs.gov',
                 'localhost'
                 ]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'dqa_prod_clone',
        'USER': 'postgres',
        'PASSWORD': 'postgres',
        'HOST': 'postgres',
        'PORT': '5432',
    }
}
