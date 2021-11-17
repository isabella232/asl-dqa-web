
# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False

SECRET_KEY = ''

# Add server hosts
ALLOWED_HOSTS = []

DATABASES = {
    'default': {
        'NAME': 'auth_db',
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': '5432',
    },
    'metrics': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'dqa_metrics',
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': '5432',
    },
    'metricsold': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'dqa_prod_clone',
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': '5432',
    },
}

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/1.11/howto/static-files/

STATIC_URL = '/static/dqa/'

# Comment out if running using manage.py runserver
STATIC_ROOT = '/var/www/html/static/dqa/'

# EXCLUDE_FROM_DEFAULT_GROUPS = ['GS']
EXCLUDE_FROM_DEFAULT_GROUPS = []

# Allow users to login and retain settings like columns, metric weighting, time format
ALLOW_USER_SETTINGS = True

# API parameters
API_BASE_URL = ''
API_AUTHORIZATION_TOKEN = ''
