
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
                for part in param.split('_'):
                    parts = part.split('.')
                    if parts[0].lower() == "dates":
                        start_date = parts[1]
                        end_date = parts[2]
                    elif parts[0].lower() == "station":
                        station_id = parts[1]
                        station_ids = "{" + parts[1].replace("-", ",") + "}"
                    elif parts[0].lower() == "channel":
                        channel_id = parts[1]
                        channel_ids = "{" + parts[1].replace("-", ",") + "}"
                    elif parts[0].lower() == "metric":
                        metric_id = parts[1]
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
