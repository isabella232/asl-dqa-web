
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
        group = request.GET.get('group', None)
        group_param = f'&group={group}' if group is not None else ''

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
       sum(sc_child.child_count) as child_count,
       sum(sc_finished_count.finished_count) as finished_child_count,
       STRING_AGG(scm.message, '\n' ORDER BY scm."timestamp") as parent_messages,
       STRING_AGG(sc_child.child_messages, '\n') as child_messages,
       MAX(sc_child.child_last_update) as child_last_update
    FROM public.tblscan sc
    LEFT OUTER JOIN tblscanmessage scm ON sc.pkscanid = scm.fkscanid
    LEFT OUTER JOIN (
        SELECT fkparentscan,
            STRING_AGG(scm_child.message, '\n' ORDER BY scm_child."timestamp") as child_messages,
            count(sc2.*) as child_count,
            MAX(sc2.lastupdate) as child_last_update
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
    GROUP BY sc.pkscanid"""
            cursor.execute(sql)
            data_out = []
            for item in cursor.fetchall():
                if parent_id is None and item[1] is None and item[12] is not None:
                    id_link = f"<a href=\"{reverse('scans')}?parentid={str(item[0])}{group_param}\">{str(item[0])}</a>"
                    message = f"Scan Date:{item[14].split('Scan Date:')[1]}" if item[14] else ''
                else:
                    if str(item[0]) == parent_id:
                        id_link = f'{str(item[0])} (parent)'
                        message = f"Scan Date:{item[14].split('Scan Date:')[1]}" if item[14] else ''
                    else:
                        id_link = str(item[0])
                        message = f"Scan Date:{item[15].split('Scan Date:')[1]}" if item[15] else ''
                data_out.append({'id': id_link,
                                 'network_filter': item[3] if item[3] is not None else 'All',
                                 'station_filter': item[4] if item[4] is not None else 'All',
                                 'start_date': item[5], 'end_date': item[6],
                                 'priority': item[7],
                                 'last_updated': item[16].strftime('%Y-%m-%d %H:%M') if item[16] is not None else item[2].strftime('%Y-%m-%d %H:%M'),
                                 'status': scan_status(item[10], item[11], len(message), item[12], item[13]),
                                 'message': f'<span title="{message}">{message[0:50] + " ... " if len(message) > 50 else message}</span>',
                                 'ordering': scan_order(item[10], item[11], len(message), item[7], item[6])
                                 })

        return Response({'data': data_out})

    def post(self, request):
        status = scan_post_update(request.data)
        return Response(status=status)


def scan_post_update(data):
    """
    Update the database scan table with scan add data from form or API
    :param data: dict of data
    :return: status
    """
    try:
        with connections['metricsold'].cursor() as cursor:
            scan_uuid = uuid.uuid4()
            network_filter = f"\'{data['network_filter']}\'" if data['network_filter'] else 'null'
            station_filter = f"\'{data['station_filter']}\'" if data['station_filter'] else 'null'
            sql = f"INSERT INTO public.tblscan(pkscanid, fkparentscan, lastupdate, metricfilter, networkfilter, stationfilter, channelfilter, startdate, enddate, priority, deleteexisting, scheduledrun, finished, taken, locationfilter) VALUES ('{scan_uuid}', null, '{data['last_updated']}', null, {network_filter}, {station_filter}, null, '{data['start_date']}', '{data['end_date']}', {data['priority']}, false, null, false, false, null);"
            cursor.execute(sql)
    except KeyError as e:
        return f"KeyError: {str(e)}"
    except Exception as e:
        return str(e)
    return status.HTTP_201_CREATED


def scan_status(finished, taken, message, child_count, finished_child_count):
    """
    Scan status
    :param taken:
    :param finished:
    :param message:
    :param child_count:
    :param finished_child_count:
    :return:
    """
    # Pending not taken, not finished
    status_message = f'Pending'
    child_status = ""
    if finished_child_count is not None and child_count is not None:
        child_status = f": {100*finished_child_count/child_count:.1f}%"

    if taken and not finished and message:
        status_message = f'Error{child_status}'
    elif taken and not finished and not message:
        status_message = f'Running{child_status}'
    elif finished:
        status_message = 'Complete'
    return status_message


def scan_order(finished, taken, message, priority, end_date):
    """
    Scan Order
    :param taken:
    :param finished:
    :param message:
    :param priority:
    :param end_date:
    :return:
    """
    # Pending not taken, not finished
    order = '4'
    if taken and not finished and message:
        # Error
        order = '9'
    elif taken and not finished and not message:
        # Running
        order = '7'
    elif finished:
        # Complete
        order = '0'
    return f'{order}:{priority}:{end_date}'
