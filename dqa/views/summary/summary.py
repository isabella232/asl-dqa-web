
from django.shortcuts import render
from django.conf import settings


def summary(request, group=''):
    exclude_from_default = ''
    for grp in settings.EXCLUDE_FROM_DEFAULT_GROUPS:
        exclude_from_default += '"{0}",'.format(grp)
    return render(request, 'summary/summary.html', {'group': group.upper() if len(group) < 4 else group,
                                                    'exclude_from_default': exclude_from_default.rstrip(',')
                                                    })
