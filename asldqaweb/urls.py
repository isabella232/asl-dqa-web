"""asldqaweb project URL Configuration"""

from django.conf.urls import url, include

from dqa import urls as dqa_urls

urlpatterns = [
    url(r'', include(dqa_urls))
]
