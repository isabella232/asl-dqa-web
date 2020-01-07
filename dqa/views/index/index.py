
from django.shortcuts import render
from django.conf import settings
from django.db import connection
from django.urls import reverse


def index(request):
    with connection.cursor() as cursor:
        sql = """SELECT pkgroupid, name, "fkGroupTypeID" FROM groupview"""
        cursor.execute(sql)
        groups = []
        for id, name, group_type_id in cursor.fetchall():
            if name == 'ALL':
                continue
            groups.append((name, reverse('summary', kwargs={'group': name.upper() if len(name) < 4 else name})))
        return render(request, 'index/index.html',
                      {'exclude_list': ','.join(settings.EXCLUDE_FROM_DEFAULT_GROUPS),
                       'groups': groups}
                      )
