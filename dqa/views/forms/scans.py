
import urllib
import json
import datetime

from django.shortcuts import render
from django.shortcuts import reverse
from django.http import HttpResponseRedirect

from dqa.forms.scan import ScanAddForm


def scanadd(request):
    if request.method == 'POST':
        form = ScanAddForm(request.POST)
        if form.is_valid():
            req = urllib.request.Request('http://localhost:8000' + reverse('scansapi'))
            req.add_header('Content-Type', 'application/json')
            output = {'start_date': form.data['start_date'],
                      'end_date': form.data['end_date'],
                      'priority': form.data['priority'],
                      'network_filter': form.data['network_filter'],
                      'station_filter': form.data['station_filter'],
                      'lastupdated': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                      }
            data = json.dumps(output)
            response = urllib.request.urlopen(req, data.encode('utf-8'))
            if response.code == 201:
                return HttpResponseRedirect(reverse('scans'))
            else:
                form.add_error(field=None, error='Scan not saved')
    else:
        form = ScanAddForm()

    return render(request, 'scans/addscan.html',
                  {'form': form,
                   'next_url': reverse('scans')})
