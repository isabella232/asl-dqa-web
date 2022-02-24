
import uuid
from collections import namedtuple

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
    ScanItem = namedtuple('ScanItem', 'id parent_id last_updated network_filter station_filter location_filter '\
                                      'start_date end_date priority delete_existing scheduled_run finished '\
                                      'taken child_count finished_child_count parent_messages '\
                                      'child_messages child_last_updated')

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
       sc.networkfilter, sc.stationfilter, sc.locationfilter,
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
                scan_item = self.ScanItem(*item)
                if parent_id is None and scan_item.parent_id is None and scan_item.child_count is not None:
                    id_link = f"<a href=\"{reverse('scans')}?parentid={str(scan_item.id)}{group_param}\">{str(scan_item.id)}</a>"
                else:
                    if str(scan_item.id) == parent_id:
                        id_link = f'{str(scan_item.id)} (parent)'
                    else:
                        id_link = str(scan_item.id)

                if scan_item.parent_messages:
                    message = f"Scan Date:{scan_item.parent_messages.split('Scan Date:')[1]}" if scan_item.parent_messages else ''
                elif scan_item.child_messages:
                    message = f"Scan Date:{scan_item.child_messages.split('Scan Date:')[1]}" if scan_item.child_messages else ''
                else:
                    message = ''

                data_out.append({'id': id_link,
                                 'network_filter': scan_item.network_filter if scan_item.network_filter is not None and len(scan_item.network_filter) > 0 else 'All',
                                 'station_filter': scan_item.station_filter if scan_item.station_filter is not None  and len(scan_item.station_filter) else 'All',
                                 'location_filter': scan_item.location_filter if scan_item.location_filter is not None  and len(scan_item.location_filter) else 'All',
                                 'start_date': scan_item.start_date,
                                 'end_date': scan_item.end_date,
                                 'priority': scan_item.priority,
                                 'last_updated': scan_item.child_last_updated.strftime('%Y-%m-%d %H:%M') if scan_item.child_last_updated is not None else scan_item.last_updated.strftime('%Y-%m-%d %H:%M'),
                                 'status': scan_status(scan_item.finished, scan_item.taken, len(message), scan_item.child_count, scan_item.finished_child_count),
                                 'message': f'<span title="{message}">{message[0:50] + " ... " if len(message) > 50 else message}</span>',
                                 'ordering': scan_order(scan_item.finished, scan_item.taken, len(message), scan_item.priority, scan_item.end_date)
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
            network_filter = data['network_filter'] if 'network_filter' in data and data['network_filter'] else None
            station_filter = data['station_filter'] if 'station_filter' in data and data['station_filter'] else None
            location_filter = data['location_filter'] if 'location_filter' in data and data['location_filter'] else None
            sql = "INSERT INTO public.tblscan(pkscanid, fkparentscan, lastupdate, metricfilter, networkfilter, stationfilter, locationfilter, channelfilter, startdate, enddate, priority, deleteexisting, scheduledrun, finished, taken) VALUES (%s, null, %s, null, %s, %s, %s, null, %s, %s, %s, false, null, false, false);"
            cursor.execute(sql, (scan_uuid, data['last_updated'], network_filter, station_filter, location_filter, data['start_date'], data['end_date'], data['priority']))
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

    if not finished and message:
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
