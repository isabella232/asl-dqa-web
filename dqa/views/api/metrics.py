
import re

from django.http import HttpResponse
from django.db import connection
from django.conf import settings


def metrics(request):
    """
    Pass back metrics for given parameters
    :param request:
    :return:
    """

    cmd = request.GET.get('cmd', None)
    param = request.GET.get('param', None)
    group = request.GET.get('group', None)

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
        if "metrics" in cmd_parts:
            cursor.execute('SELECT fnsclGetMetrics()')
            output.append(cursor.fetchone()[0])
        if "groups" in cmd_parts:
            sql = """SELECT pkgroupid, name, "fkGroupTypeID" FROM groupview"""
            cursor.execute(sql)
            groups_list = ''
            group_id = None
            exclude_ids = []
            group_master_list = {}
            for id, name, group_type_id in cursor.fetchall():
                group_master_list[name] = (id, group_type_id)
            if group is not None and group in group_master_list:
                groups_list += 'G,{0},{1},{2}\n'.format(group_master_list[group][0], group, group_master_list[group][1])
                group_id = group_master_list[group][0]
                if group_master_list[group][1] != 1:
                    for name, values in group_master_list.items():
                        if values[1] == 1:
                            groups_list += 'G,{0},{1},{2}\n'.format(values[0], name, values[1])
            elif group is not None and group not in group_master_list:
                return HttpResponse('Error: Group {0} does not exist.'.format(group))
            else:
                for name, values in group_master_list.items():
                    if name not in settings.EXCLUDE_FROM_DEFAULT_GROUPS:
                        groups_list += 'G,{0},{1},{2}\n'.format(values[0], name, values[1])
                    else:
                        exclude_ids.append(values[0])
            output.append(groups_list)
            sql = """SELECT "pkGroupTypeID", name, pkgroupid FROM grouptypeview"""
            cursor.execute(sql)
            group_type_networks = {}
            group_type_names = {}
            for result in cursor.fetchall():
                group_type_networks.setdefault(result[0], []).append(result[2])
                group_type_names[result[0]] = result[1]
            types_list = ''
            for id, network_ids in group_type_networks.items():
                if group_id is not None:
                    for net_id in network_ids:
                        if net_id == group_id:
                            types_list += 'T,{0},{1},{2}\n'.format(id, group_type_names[id], net_id)
                elif exclude_ids:
                    for exclude_id in exclude_ids:
                        if exclude_id in network_ids:
                            network_ids.remove(exclude_id)
                    types_list += 'T,{0},{1},{2}\n'.format(id, group_type_names[id], ','.join([str(id) for id in network_ids]))
                else:
                    types_list += 'T,{0},{1},{2}\n'.format(id, group_type_names[id], ','.join([str(id) for id in network_ids]))
            output.append(types_list)
        if "stations" in cmd_parts:
            sql = """SELECT pkstationid, fknetworkid, name, \"fkGroupID\" FROM stationview"""
            if group_id is not None:
                sql += ' WHERE "fkGroupID" = ' + str(group_id)
            elif exclude_ids:
                exclude_list_sql = ','.join([str(id) for id in exclude_ids])
                sql += ' WHERE "fkGroupID" NOT IN ({0}) AND fknetworkid NOT IN ({0})'.format(exclude_list_sql)
            cursor.execute(sql)
            stations_groups = {}
            stations_raw = {}
            for id, network_id, name, group_id in cursor.fetchall():
                stations_groups.setdefault(id, []).append(group_id)
                stations_raw[id] = (network_id, name)
            stations_list = ''
            for id, group_ids in stations_groups.items():
                stations_list += 'S,{0},{1},{2},{3}\n'.format(id, stations_raw[id][0], stations_raw[id][1], ','.join([str(id) for id in group_ids]))
            output.append(stations_list)

    if not output:
        output_string = 'ERROR: Database queries empty'
    elif output[0] is None:
        output_string = ''
    else:
        output_string = '\n'.join(output)

    return HttpResponse(output_string)
