"""dqa URL Configuration"""

from django.conf.urls import url
from django.views.generic import RedirectView

from dqa.views.api import metrics, dqaget, scans as apiscans
from dqa.views.index import index
from dqa.views.summary import summary
from dqa.views.scans import scans
from dqa.views.forms import scans as formscans


urlpatterns = [
    url(r'api/metrics', metrics.metrics, name="oldmetrics"),
    url(r'cgi-bin/dqaget.py', dqaget.dqaget, name="dqaget"),
    url(r'index.html', index.index, name="index"),
    url(r'scansapi', apiscans.scans.as_view(), name="scansapi"),
    url(r'scans', scans.scans, name="scans"),
    url(r'scanadd', formscans.scanadd, name='addscan'),
    url(r'(?P<group>[^/]+)/summary/$', summary.summary, name="summary"),
    url(r'summary/$', summary.summary, name="summary_nogroup"),
    url(r'(?P<group>[^/]*)/$', summary.summary),
    url(r'^$', RedirectView.as_view(pattern_name='index'))
]
