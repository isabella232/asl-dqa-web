
import uuid

from django.db import connections
from django.urls import reverse

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticatedOrReadOnly
from rest_framework.parsers import JSONParser
from rest_framework import status


class scans(APIView):

    permission_classes = (IsAuthenticatedOrReadOnly,)
    parser_classes = [JSONParser]

    def get(self, request):
        parent_id = request.GET.get('parentid', None)

        with connections['metricsold'].cursor() as cursor:
            if parent_id is not None:
                where = f"WHERE sc.fkparentscan='{parent_id}' OR sc.pkscanid='{parent_id}'"
            else:
                where = 'WHERE sc.fkparentscan is null'
            # sql = f"-- SELECT DISTINCT sc.pkscanid,sc.fkparentscan,sc.networkfilter,sc.stationfilter,sc.startdate,sc.enddate,sc.priority,sc.lastupdate,scm.timestamp,scm.message FROM tblscan sc JOIN tblscanmessage scm ON scm.fkscanid=sc.pkscanid {where} "
            sql = f"""SELECT sc.pkscanid, sc.fkparentscan, sc.lastupdate,
       sc.networkfilter, sc.stationfilter,
       sc.startdate, sc.enddate,
       sc.priority, sc.deleteexisting, sc.scheduledrun, sc.finished, sc.taken,
       count(sc_child.child_count) as child_count,
       sum(sc_finished_count.finished_count) as finished_child_count,
       STRING_AGG(scm.message, '\n' ORDER BY scm."timestamp") as parent_messages,
       STRING_AGG(sc_child.child_messages, '\n') as child_messages
      
    FROM public.tblscan sc
    LEFT OUTER JOIN tblscanmessage scm ON sc.pkscanid = scm.fkscanid
    LEFT OUTER JOIN (
        SELECT fkparentscan,
            STRING_AGG(scm_child.message, '\n' ORDER BY scm_child."timestamp") as child_messages,
            count(sc2.*) as child_count
        FROM tblscan sc2
        LEFT OUTER JOIN tblscanmessage scm_child ON sc2.pkscanid = scm_child.fkscanid
        WHERE fkparentscan IS NOT NULL
        GROUP BY sc2.fkparentscan
        ) sc_child ON sc.pkscanid = sc_child.fkparentscan
    LEFT OUTER JOIN (
        select fkparentscan, count(*) as finished_count
        FROM tblscan
        WHERE finished = true AND fkparentscan IS NOT NULL
        GROUP BY fkparentscan
        ) sc_finished_count ON sc.pkscanid = sc_finished_count.fkparentscan
    {where} 
    GROUP BY sc.pkscanid
    ORDER BY parent_messages DESC"""
            # sql = f"SELECT pkscanid,fkparentscan,networkfilter,stationfilter,startdate,enddate,priority,lastupdate,taken,finished FROM tblscan sc {where}"
            cursor.execute(sql)
            data_out = []
            for item in cursor.fetchall():
                if parent_id is None and item[1] is None and item[12] > 0:
                    id_link = f"<a href=\"{reverse('scans')}?parentid={str(item[0])}\">{str(item[0])}</a>"
                    message = f"Scan Date:{item[14].split('Scan Date:')[1]}" if item[14] else ''
                else:
                    if str(item[0]) == parent_id:
                        id_link = f'{str(item[0])} (parent)'
                        message = f"Scan Date:{item[14].split('Scan Date:')[1]}" if item[14] else ''
                    else:
                        id_link = str(item[0])
                        message = f"Scan Date:{item[15].split('Scan Date:')[1]}" if item[15] else ''
                # message = f'<span title="{item[9]}">{item[9][0:40]}</span>' if item[9] else ''
                # data_out.append({'id': id_link, 'child_count': children[str(item[0])] if str(item[0]) in children else 0, 'network_filter': item[2] if item[2] is not None else 'All', 'station_filter': item[3] if item[3] is not None else 'All', 'start_date': item[4], 'end_date': item[5], 'priority': item[6], 'last_updated': item[7].strftime('%Y-%m-%d %H:%M'), 'timestamp': item[8].strftime('%Y-%m-%d %H:%M') if item[8] is not None else '', 'message': message})
                data_out.append({'id': id_link, 'child_count': item[12],
                                 'network_filter': item[3] if item[3] is not None else 'All',
                                 'station_filter': item[4] if item[4] is not None else 'All', 'start_date': item[5],
                                 'end_date': item[6], 'priority': item[7], 'last_updated': item[2].strftime('%Y-%m-%d %H:%M'),
                                 'status': scan_status(item[10], item[11], len(message)), 'message': f'<span title="{message}">{message[0:50] + " ... " if len(message) > 50 else message}</span>'
                                 })

        return Response({'data': data_out})

    def post(self, request):
        with connections['metricsold'].cursor() as cursor:
            data = request.data
            scan_uuid = uuid.uuid4()
            sql = f"INSERT INTO public.tblscan(pkscanid, fkparentscan, lastupdate, metricfilter, networkfilter, stationfilter, channelfilter, startdate, enddate, priority, deleteexisting, scheduledrun, finished, taken, locationfilter) VALUES ('{scan_uuid}', null, '{data['last_updated']}', null, '{data['network_filter']}', '{data['station_filter']}', null, '{data['start_date']}', '{data['end_date']}', {data['priority']}, false, null, false, false, null);"
            cursor.execute(sql)
        return Response(status=status.HTTP_201_CREATED)


def scan_status(finished, taken, message):
    """
    Scan status
    :param taken:
    :param finished:
    :return:
    """
    # Pending not taken, not finished
    status = 'pending'
    if taken and not finished and message:
        status = 'error'
    elif taken and not finished and not message:
        status = 'running'
    elif finished:
        status = 'finished'
    return status
