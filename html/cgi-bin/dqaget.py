#!/usr/bin/env python
import os
import sys
import time
from datetime import datetime
import cgi
import cgitb
cgitb.enable()

binPath = "/dataq/bin/"
sys.path.insert(0, binPath)
import Database

queries = {
    "metrics" : """
SELECT name FROM tblmetric ORDER BY name
""",
    "data" : """
SELECT
    d1.date AS date,
    grp.name AS network,
    sta.name AS station,
    sen.location AS Location,
    cha.name AS Channel,
    m.name AS Metric,
    md.value AS Value
FROM
    tblchannel cha
    JOIN tblsensor sen ON cha.fksensorid = sen.pksensorid
    JOIN tblstation sta ON sen.fkstationid = sta.pkstationid
    JOIN "tblGroup" grp ON sta.fknetworkid = grp.pkgroupid
    JOIN tblMetricdata md ON md.fkChannelid = cha.pkChannelID
    JOIN tblMetric m ON md.fkmetricid = m.pkmetricid
    JOIN tbldate d1 ON d1.pkdateid = md.date
WHERE
    grp.name LIKE %s
    AND sta.name LIKE %s
    AND m.name LIKE %s
    AND sen.location LIKE %s
    AND cha.name LIKE %s
    AND d1.date BETWEEN %s
    AND %s
ORDER BY
    grp.name,
    sta.name,
    d1.date,
    sen.location,
    cha.name,
    Value
"""
}

database_conString = open(binPath+'db.config', 'r').readline()
database = Database.Database(database_conString)

#Http header
print "Content-Type: text/plain"
print ""

def error(message=None):
    if message is None:
        print "ERROR"
    else:
        print "ERROR:", message
    sys.exit(0)

def printMetrics(records):
    for row in records:
        print row[0]

def printData(records):
    for row in records:
        print "%10s %3s %6s %3s %4s %20s %lf" % row

form = cgi.FieldStorage()
if "cmd" not in form:
    error("No command string supplied")
cmd_str = form["cmd"].value
if len(cmd_str) < 1:
    error("No command string provided")
if "network" in form:
    network = form["network"].value
else:
    network = "%"
if "station" in form:
    station = form["station"].value
else:
    station = "%"
if "location" in form:
    location = form["location"].value
else:
    location = "%"
if "channel" in form:
    channel = form["channel"].value
else:
    channel = "%"
if "metric" in form:
    metric = form["metric"].value
else:
    metric = "%"
if "sdate" in form:
    sdate = form["sdate"].value
else:
    sdate = "%"
if "edate" in form:
    edate = form["edate"].value
else:
    edate = "%"

db_args = (network, station, metric, location, channel, sdate, edate) 
if cmd_str == "metrics":
    printMetrics(database.select(queries["metrics"]))
elif cmd_str == "data":
    printData(database.select(queries["data"],db_args))
