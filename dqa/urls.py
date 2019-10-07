"""dqa URL Configuration"""

from django.conf.urls import url
from django.views.generic import RedirectView

from dqa.views.api import metrics, dqaget
from dqa.views.index import index

urlpatterns = [
    url(r'^api/metrics$', metrics.metrics, name="metrics"),
    url(r'^cgi-bin/dqaget.py$', dqaget.dqaget, name="dqaget"),
    url(r'index.html', index.index, name="index"),
    url(r'dataq.html', index.index, name="dataq"),
    url(r'summary/$', index.index, name="summary"),
    url(r'^$', RedirectView.as_view(pattern_name='summary'))
]
