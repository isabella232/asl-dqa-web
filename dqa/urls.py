"""dqa URL Configuration"""

from django.conf.urls import url
from django.views.generic import RedirectView

from dqa.views.api import metrics, dqaget
from dqa.views.index import index
from dqa.views.summary import summary

urlpatterns = [
    url(r'api/metrics', metrics.metrics, name="oldmetrics"),
    url(r'cgi-bin/dqaget.py', dqaget.dqaget, name="dqaget"),
    url(r'index.html', index.index, name="index"),
    url(r'(?P<group>[^/]+)/summary/$', summary.summary, name="summary"),
    url(r'summary/$', summary.summary, name="summary_nogroup"),
    url(r'(?P<group>[^/]*)/$', summary.summary),
    url(r'^$', RedirectView.as_view(pattern_name='index'))
]
