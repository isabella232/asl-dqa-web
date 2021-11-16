
import os
import json
from urllib import request

import django

from django.db import connections

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "dqa.settings")

django.setup()

from metrics.models import GroupType, Group, Station, Sensor, Channel
from metrics.models import ComputeType, Hash, Metric, MetricData
from metrics.models import Date, ErrorLog, Scan, ScanMessage

print('Start')

base_read_url = ''

with connections['prodclone'].cursor() as cursor:

    print('Checking Group Types')
    group_type_old = []
    sql = """SELECT "pkGroupTypeID", name FROM public."tblGroupType";"""
    cursor.execute(sql)
    for id, name in cursor.fetchall():
        group_type_old.append(name)
    url = base_read_url + '?model=grouptype'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    group_type_new = json_data['data']
    if sorted(group_type_old) != sorted(group_type_new):
        print('Group Type mismatch')
        print(sorted(group_type_old))
        print(sorted(group_type_new))
    else:
        print('* Group Types match')

    print('Checking Groups')
    group_old = []
    sql = """SELECT pkgroupid, gp.name, "isIgnored", gpt.name FROM public."tblGroup" gp FULL JOIN public."tblGroupType" gpt ON gpt."pkGroupTypeID" = gp."fkGroupTypeID";"""
    cursor.execute(sql)
    for id, name, is_ignored, group_type in cursor.fetchall():
        group_old.append((name, is_ignored, group_type))
    group_new = []
    url = base_read_url + '?model=group'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for group in json_data['data']:
        group_new.append((group['name'], group['is_ignored'], group['group_type']))
    if sorted(group_old) != sorted(group_new):
        print('Group mismatch')
        print(sorted(group_old))
        print(sorted(group_new))
    else:
        print('* Groups match')

    print('Checking Stations')
    station_old = []
    dups = {}
    station_dups = {}
    sql = """SELECT DISTINCT st.pkstationid, st.name, gp.name FROM public.tblstation st JOIN public."tblGroup" gp ON gp.pkgroupid = st.fknetworkid;"""
    cursor.execute(sql)
    for id, name, group_name in cursor.fetchall():
        station_old.append((name, group_name))
    station_new = []
    url = base_read_url + '?model=station'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for station in json_data['data']:
        station_new.append((station['name'], station['network_name']))
    if sorted(station_old) != sorted(station_new):
        print('Station mismatch')
        print(sorted(station_old))
        print(sorted(station_new))
    else:
        print('* Stations match')

    print('Checking Sensors')
    sensor_old = []
    sql = """SELECT sn.pksensorid, sn.location, st.name, st.pkstationid, gp.name FROM public.tblsensor sn JOIN public.tblstation st ON st.pkstationid = sn.fkstationid JOIN public."tblGroup" gp ON gp.pkgroupid = st.fknetworkid"""
    cursor.execute(sql)
    for id, location, station_name, station_id, network_name in cursor.fetchall():
        sensor_old.append((location, station_name, network_name))
    sensor_new = []
    url = base_read_url + '?model=sensor'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for sensor in json_data['data']:
        sensor_new.append((sensor['location'], sensor['station'], sensor['network']))
    if sorted(sensor_old) != sorted(sensor_new):
        print('Sensor mismatch')
        print(sorted(sensor_old))
        print(sorted(sensor_new))
    else:
        print('* Sensors match')

    print('Checking Channels')
    channel_old = []
    sql = """SELECT ch.pkchannelid, ch.fksensorid, ch.name, ch.derived, ch."isIgnored", sn.location, st.name, gp.name FROM public.tblchannel ch JOIN public.tblsensor sn ON sn.pksensorid = ch.fksensorid JOIN public.tblstation st ON st.pkstationid = sn.fkstationid JOIN public."tblGroup" gp ON gp.pkgroupid = st.fknetworkid;"""
    cursor.execute(sql)
    for id, sensor_id, name, derived, is_ignored, location, station, network in cursor.fetchall():
        channel_old.append((name, derived, is_ignored, location, station, network))
    channel_new = []
    url = base_read_url + '?model=channel'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for channel in json_data['data']:
        channel_new.append((channel['name'], channel['derived'], channel['is_ignored'], channel['location'], channel['station'], channel['network']))
    if sorted(channel_old) != sorted(channel_new):
        set_old = set(channel_old)
        set_new = set(channel_new)
        print('Channel mismatch')
        print(set_old.difference(set_new))
        print(set_new.difference(set_old))
    else:
        print('* Channels match')

    print('Checking Compute Type')
    compute_type_old = []
    sql = """SELECT ct.pkcomputetypeid, ct.name, ct.description, ct.iscalibration FROM tblcomputetype ct;"""
    cursor.execute(sql)
    for id, name, description, is_calibration in cursor.fetchall():
        compute_type_old.append((name, description, is_calibration))
    compute_type_new = []
    url = base_read_url + '?model=computetype'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for computetype in json_data['data']:
        compute_type_new.append((computetype['name'], computetype['description'], computetype['is_calibration']))
    if sorted(compute_type_old) != sorted(compute_type_new):
        print('Compute Type mismatch')
        print(sorted(compute_type_old))
        print(sorted(compute_type_new))
    else:
        print('* Compute Type match')

    print('Checking Metrics')
    metric_old = []
    sql = """SELECT mt.pkmetricid, mt.name, mt.displayname, mt.descriptionshort, mt.descriptionlong, ct.name FROM tblmetric mt JOIN tblcomputetype ct ON ct.pkcomputetypeid = mt.fkcomputetypeid;"""
    cursor.execute(sql)
    for id, name, display_name, description_short, description_long, compute_type in cursor.fetchall():
        metric_old.append((name, display_name, description_short, description_long, compute_type))
    metric_new = []
    url = base_read_url + '?model=metric'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for metric in json_data['data']:
        metric_new.append((metric['name'], metric['display_name'], metric['description_short'], metric['description_long'], metric['compute_type']))
    if sorted(metric_old) != sorted(metric_new):
        print('Metric mismatch')
        print(sorted(metric_old))
        print(sorted(metric_new))
    else:
        print('* Metric match')

    print('Checking Metric Data')
    metricdata_old = []
    sql = """SELECT gp.name, st.name, sn.location, ch.name, CONCAT('J', md.date::text)::date, m.name, md.value, encode(hs.hash, 'hex') FROM tblmetricdata md JOIN tblmetric m ON m.pkmetricid=md.fkmetricid JOIN tblhash hs ON hs."pkHashID" = md."fkHashID" JOIN tblchannel ch ON ch.pkchannelid=md.fkchannelid JOIN tblsensor sn ON sn.pksensorid=ch.fksensorid JOIN tblstation st ON st.pkstationid=sn.fkstationid JOIN "tblGroup" gp ON gp.pkgroupid=st.fknetworkid WHERE md.date BETWEEN 2446728 AND 2446928;"""
    cursor.execute(sql)
    for network, station, location, channel, date, metric, value, hash in cursor.fetchall():
        metricdata_old.append((network, station, location, channel, date.strftime('%Y-%m-%d'), metric, value, hash))
    metricdata_new = []
    url = base_read_url + '?model=metricdata'
    with request.urlopen(url) as response:
        result = response.read()
        json_data = json.loads(result)
    for metricdata in json_data['data']:
        metricdata_new.append((metricdata['network'], metricdata['station'], metricdata['location'], metricdata['channel'], metricdata['date'], metricdata['metric'], metricdata['value'], metricdata['hash']))
    if sorted(metricdata_old) != sorted(metricdata_new):
        print('Metric Data mismatch')
        m1 = set(metricdata_old)
        m2 = set(metricdata_new)
        print(m1.difference(m2))
        print(m2.difference(m1))
    else:
        print('* Metric Data match')

print('Done')
