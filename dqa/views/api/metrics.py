
import re

from django.http import HttpResponse
from django.db import connection


def metrics(request):
    """
    Pass back metrics for given parameters
    :param request:
    :return:
    """

    cmd = request.GET.get('cmd', None)
    param = request.GET.get('param', None)

    if cmd is None or cmd == '':
        return HttpResponse("Error: No command string")
    cmd_parts = cmd.lower().split('_')

    with connection.cursor() as cursor:
        output = []
        if param is not None:
            if param == '':
                output.append("No parameters provided")
            else:
                network_code = ''
                parameter_list = param.split('_')
                for part in parameter_list:
                    parts = part.split('.')
                    if parts[0].lower() == "dates":
                        start_date = parts[1]
                        end_date = parts[2]
                    elif parts[0].lower() == "station":
                        # Just pass through station id(s) if it is a number or dash separated list of station ids
                        # Otherwise query using network and station names for station id (only a single station)
                        if re.match(r'^[0-9\-]+$', parts[1]) is not None:
                            station_id = parts[1]
                            station_ids = "{" + parts[1].replace("-", ",") + "}"
                        else:
                            if not network_code:
                                network_code = next((s for s in parameter_list if 'network' in s), None).split('.')[1]
                            sql = """SELECT sta.pkstationid
                                     FROM tblstation sta
                                     JOIN \"tblGroup\" net on sta.fkNetworkID = net.pkGroupID
                                     WHERE net.name='{0}' AND sta.name='{1}';""".format(network_code, parts[1])
                            cursor.execute(sql)
                            result = cursor.fetchone()
                            if result is not None:
                                station_id = result[0]
                                station_ids = '{{{0}}}'.format(station_id)
                            else:
                                return HttpResponse("Error: Empty query for Network = {0} and Station = {1}".format(network_code, parts[1]))
                    elif parts[0].lower() == "channel":
                        channel_id = parts[1]
                        channel_ids = "{" + parts[1].replace("-", ",") + "}"
                    elif parts[0].lower() == "metric":
                        metric_id = parts[1]
                    elif parts[0].lower() == "network":
                        network_code = parts[1]
                    else:
                        output.append("Improper command string: {0}".format(parts[0]))

                # Parameter based queries
                if "stationgrid" in cmd_parts:
                    cursor.execute('SELECT fnsclGetStationData(\'{0}\',\'{1}\',\'{2}\',\'{3}\')'.format(station_ids, metric_id, start_date, end_date))
                    output.append(cursor.fetchone()[0])
                if "channelgrid" in cmd_parts:
                    cursor.execute('SELECT fnsclGetChannelData(\'{0}\',\'{1}\',\'{2}\',\'{3}\')'.format(channel_ids, metric_id, start_date, end_date))
                    output.append(cursor.fetchone()[0])
                if "stationplot" in cmd_parts:
                    cursor.execute('SELECT fnsclGetStationPlotData(\'{0}\',\'{1}\',\'{2}\',\'{3}\')'.format(station_id, metric_id, start_date, end_date))
                    output.append(cursor.fetchone()[0])
                if "channelplot" in cmd_parts:
                    cursor.execute('SELECT fnsclGetChannelPlotData(\'{0}\',\'{1}\',\'{2}\',\'{3}\')'.format(channel_id, metric_id, start_date, end_date))
                    output.append(cursor.fetchone()[0])
                if "channels" in cmd_parts:
                    cursor.execute('SELECT fnsclGetChannels(\'{0}\')'.format(station_ids))
                    output.append(cursor.fetchone()[0])

        if "dates" in cmd_parts:
            cursor.execute('SELECT fnsclGetDates()')
            output.append(cursor.fetchone()[0])
        if "stations" in cmd_parts:
            cursor.execute('SELECT fnsclGetStations()')
            output.append(cursor.fetchone()[0])
        if "metrics" in cmd_parts:
            cursor.execute('SELECT fnsclGetMetrics()')
            output.append(cursor.fetchone()[0])
        if "groups" in cmd_parts:  # Group types need to be queried before groups
            cursor.execute('SELECT fnsclGetGroupTypes()')
            output.append(cursor.fetchone()[0])
            cursor.execute('SELECT fnsclGetGroups()')
            output.append(cursor.fetchone()[0])
    if not output:
        output_string = 'ERROR: Database queries empty'
    elif output[0] is None:
        output_string = ''
    else:
        output_string = '\n'.join(output)

    return HttpResponse(output_string)
