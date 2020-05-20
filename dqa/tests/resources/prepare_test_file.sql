-- SELECT COUNT(*) FROM tblMetricData;
-- SELECT COUNT(*) FROM tblchannel;
-- SELECT COUNT(*) FROM tbldate;
-- SELECT COUNT(*) FROM tblerrorlog;
-- SELECT COUNT(*) FROM tblhash;
-- SELECT COUNT(*) FROM tblscan;
-- SELECT COUNT(*) FROM tblscanmessage;
-- SELECT COUNT(*) FROM tblsensor;
-- SELECT COUNT(*) FROM tblstation;

-- commands to clean up dqa_prod_clone to produce a reduced database for dqa tests
-- Only keeps IU-ANMO and IU-FURI and US-WVOR and US-WMOK for 6-7 Jan 2020

-- TRUNCATE tblerrorlog;
-- TRUNCATE tblscan CASCADE;

-- DELETE FROM tblMetricData md WHERE md.fkChannelid NOT IN (
-- SELECT COUNT(md.fkChannelid)
-- FROM tblMetricData md
-- JOIN tblchannel cha ON md.fkChannelid = cha.pkChannelID
-- JOIN tblsensor sen ON cha.fksensorid = sen.pksensorid
-- JOIN tblstation sta ON sen.fkstationid = sta.pkstationid
-- JOIN "tblGroup" grp ON sta.fknetworkid = grp.pkgroupid
-- JOIN tblMetric m ON md.fkmetricid = m.pkmetricid
-- JOIN tblhash h ON md."fkHashID" = h."pkHashID"
-- WHERE
-- grp.name IN ('IU', 'US')
-- AND sta.name IN ('ANMO', 'FURI', 'WVOR', 'WMOK')
-- AND md.date BETWEEN (to_char('2020-005'::date, 'J')::INT)
-- AND (to_char('2020-007'::date, 'J')::INT))

-- SELECT COUNT(ch.pkchannelid) FROM tblchannel ch WHERE ch.pkchannelid NOT IN (SELECT md.fkChannelid FROM tblMetricData md);
-- DELETE FROM tblchannel ch WHERE ch.pkchannelid NOT IN (SELECT md.fkChannelid FROM tblMetricData md);

-- SELECT COUNT(h."pkHashID") FROM tblhash h WHERE h."pkHashID" NOT IN (SELECT md."fkHashID" FROM tblMetricData md);
-- DELETE FROM tblhash h WHERE h."pkHashID" NOT IN (SELECT md."fkHashID" FROM tblMetricData md);

-- DELETE FROM tbldate WHERE pkdateid NOT IN (SELECT date FROM tblmetricdata);
-- SELECT * FROM tbldate WHERE pkdateid IN (SELECT date FROM tblmetricdata);

-- SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'auth_%';
-- DROP TABLE auth_group_permissions;
-- DROP TABLE auth_user_groups;
-- DROP TABLE auth_user_user_permissions;
-- DROP TABLE auth_group;
-- DROP TABLE auth_permission;
-- DROP TABLE auth_user CASCADE;

-- SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'django_%';
-- DROP TABLE django_admin_log;
-- DROP TABLE django_content_type;
-- DROP TABLE django_migrations;
-- DROP TABLE django_session;

-- DROP TABLE databasechangelog;
-- DROP TABLE databasechangeloglock;
