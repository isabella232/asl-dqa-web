"""metrics URL Configuration"""

from django.conf.urls import url
from django.views.generic import RedirectView

from metrics.views.api import metrics

urlpatterns = [
    url(r'metrics', metrics.metrics, name="metrics"),
]