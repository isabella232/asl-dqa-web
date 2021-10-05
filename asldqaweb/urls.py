"""asldqaweb project URL Configuration"""

from django.conf.urls import url, include
from django.contrib.auth import urls as auth_urls

from dqa import urls as dqa_urls
from metrics import urls as metrics_urls

urlpatterns = [
    url(r'^accounts/', include(auth_urls)),
    url(r'', include(dqa_urls)),
    url(r'', include(metrics_urls))
]
