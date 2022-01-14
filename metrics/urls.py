"""metrics URL Configuration"""

from django.conf.urls import url

from rest_framework.authtoken.views import obtain_auth_token
from metrics.views.api import usersettings
from metrics.views.api.metrics import metrics

urlpatterns = [
    url('api-token-auth', obtain_auth_token, name='api_token_auth'),
    url(r'metrics', metrics.as_view(), name="metrics"),
    url(r'settings', usersettings.usersettings, name="settings")
]
