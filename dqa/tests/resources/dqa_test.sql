--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2 (Ubuntu 12.2-2.pgdg18.04+1)
-- Dumped by pg_dump version 12.2 (Ubuntu 12.2-2.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: fnfinishscan(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnfinishscan(scanid uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

--Update scan to finished
  UPDATE tblscan
   SET finished=true
 WHERE
pkscanid = scanid;

--Update timestamp
UPDATE tblscan
SET lastupdate = current_timestamp
WHERE
pkscanid = scanid;

 
--Update any parent scan if all of its children are finished.
  UPDATE tblscan
  SET finished = TRUE, lastupdate = current_timestamp
  WHERE
  fkparentscan IS NULL --Must be a parent scan
  AND
  taken = TRUE --Must have been processed
  AND
  finished = False
  AND
  pkscanid NOT IN (
  --List of all parents with unfinished children
      select distinct fkparentscan
      from tblscan
      where fkparentscan IS NOT NULL
      AND finished = FALSE
  );

  --Remove finished children of finished parent scans.
  DELETE
  FROM tblscan child
  USING tblscan parent
  WHERE
    child.fkparentscan = parent.pkscanid
    AND
    parent.finished = TRUE;

END
$$;


ALTER FUNCTION public.fnfinishscan(scanid uuid) OWNER TO postgres;

--
-- Name: fnsclgetchanneldata(integer[], integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetchanneldata(integer[], integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    channelIDs alias for $1;
    metricID alias for $2;
    startDate alias for $3;
    endDate alias for $4;
    channelData TEXT;
    computeType int;
    metricName TEXT;
BEGIN
    Select fkComputeTypeID, name from tblMetric where pkMetricID = metricID INTO computeType, metricName;
    CASE computeType
        --Metric Data
        WHEN 1 THEN
            --Average across total number of values
            SELECT INTO channelData string_agg(CONCAT(id, ',',avg, ',', fnsclGetPercentage(avg, metricName)), E'\n') FROM (
                SELECT md1.fkChannelID as id, round((SUM(md1.value)/count(md1.*))::numeric, 2) as avg
                FROM tblMetricData md1
                WHERE md1.fkChannelID = any(channelIDs)
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY md1.fkChannelID ) channels;
        WHEN 2 THEN
            --Average across days NOT ACCURATE
            select '2' into channelData;
        WHEN 3 THEN
            --Count all values, return sum
            SELECT INTO channelData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
                SELECT md1.fkChannelID as id, round(SUM(md1.value)::numeric, 0) as sum
                FROM tblMetricData md1
                WHERE md1.fkChannelID = any(channelIDs)
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY md1.fkChannelID ) channels;
        
        WHEN 5 THEN
            --Calculate data between last calibrations
            SELECT INTO channelData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
                SELECT md1.fkChannelID as id, round((to_char(endDate, 'J')::INT-max(date))::numeric, 0) as sum
                FROM tblMetricStringData md1
                WHERE md1.fkChannelID = any(channelIDs)
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY md1.fkChannelID ) channels;
        WHEN 6 THEN
            --Average across number of values
            select '6' into channelData;
        ELSE
            --Insert error into error log
            select 'Error' into channelData;
    END CASE;

    
    RETURN channelData;
END;
$_$;


ALTER FUNCTION public.fnsclgetchanneldata(integer[], integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetchannelplotdata(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetchannelplotdata(integer, integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    channelID alias for $1;
    metricID alias for $2;
    startDate alias for $3;
    endDate alias for $4;
    channelPlotData TEXT;
    computeType int;
BEGIN
    
    Select fkComputeTypeID from tblMetric where pkMetricID = metricID INTO computeType;
    CASE computeType
        --Metric Data
        WHEN 1 THEN
            --Average across total number of values
            SELECT INTO channelPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
                SELECT to_date(md1.date::text, 'J') as sdate, round(md1.value::numeric, 4) as avg
                FROM tblMetricData md1
                WHERE md1.fkChannelID = channelID
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                 ) channels;
        WHEN 2 THEN
            --Average across days NOT ACCURATE
            select '2' into channelPlotData;
        WHEN 3 THEN
            --Count all values, return sum
            SELECT INTO channelPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
                SELECT to_date(md1.date::text, 'J') as sdate, round(md1.value::numeric, 4) as avg
                FROM tblMetricData md1
                WHERE md1.fkchannelID = channelID
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                ) stations;
        --Calibration Data
        WHEN 5 THEN
            --Calculate data between last calibrations
            select '5' into channelPlotData;
        WHEN 6 THEN
            --Average across number of values
            select '6' into channelPlotData;
        ELSE
            --Insert error into error log
            select 'Error' into channelPlotData;
    END CASE;

    
    RETURN channelPlotData;
END;
$_$;


ALTER FUNCTION public.fnsclgetchannelplotdata(integer, integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetchannels(integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetchannels(integer[]) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    stationIDs alias for $1;
    channelString TEXT;
BEGIN
    SELECT 
    INTO channelString
        string_agg( 
            CONCAT(
                  'C,'
                , pkchannelID
                , ','
                , name
                , ','
                , tblSensor.location
                , ','
                , fkStationID
            )
            , E'\n' 
        )
    FROM tblChannel
    JOIN tblSensor
        ON tblChannel.fkSensorID = tblSensor.pkSensorID
    WHERE tblSensor.fkStationID = any(stationIDs)
    AND NOT tblChannel."isIgnored" ;

    RETURN channelString;
    
END;
$_$;


ALTER FUNCTION public.fnsclgetchannels(integer[]) OWNER TO postgres;

--
-- Name: fnsclgetdates(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetdates() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    dateString TEXT;
BEGIN
    
    SELECT INTO dateString
        string_agg(
            "date"
            , E'\n'
        )
    FROM (

    SELECT CONCAT('DS,', MIN(date)) as date
      FROM tbldate
      UNION
    SELECT CONCAT('DE,', MAX(date)) as date
      FROM tbldate
    ) dates; --to_char('2012-03-01'::date, 'J')::INT  || to_date(2456013::text, 'J')

    RETURN dateString;
END;
$$;


ALTER FUNCTION public.fnsclgetdates() OWNER TO postgres;

--
-- Name: fnsclgetgroups(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetgroups() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    groupString TEXT;
BEGIN


    
    SELECT 
    INTO groupString
        string_agg( DISTINCT
            CONCAT(
                  'G,'
                , gp.pkGroupID
                , ','
                , gp."name"
                , ','
                , gp."fkGroupTypeID"

                
            )
            , E'\n' 
        )
    FROM "tblGroup" gp;
        

    RETURN groupString;
    
END;
$$;


ALTER FUNCTION public.fnsclgetgroups() OWNER TO postgres;

--
-- Name: fnsclgetgrouptypes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetgrouptypes() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    groupTypeString TEXT;
BEGIN


         SELECT                                                              
         INTO groupTypeString                                                
                 string_agg( groupTypeData                                   
                         , E'\n'                                             
                 )                                                           
                 FROM                                                        
                         (SELECT                                             
                                 CONCAT(                                     
                                           'T,'                              
                                         , "pkGroupTypeID"                   
                                         , ','                               
                                         , "tblGroupType".name               
                                         ,','                                
                                         , string_agg(                       
                                                   "tblGroup".pkGroupID::text
                                                 , ','                       
                                                 ORDER BY "tblGroup".name)   
                                 ) AS groupTypeData                          
                         FROM "tblGroupType"                                 
                         Join "tblGroup"                                     
                                 ON "fkGroupTypeID" = "pkGroupTypeID"        
                         GROUP BY "pkGroupTypeID"                            
                         ORDER BY "tblGroupType".name) AS grouptypes         
         ;                                                                   
                                                                             
         RETURN groupTypeString;
    
END;
$$;


ALTER FUNCTION public.fnsclgetgrouptypes() OWNER TO postgres;

--
-- Name: fnsclgetmetrics(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetmetrics() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    metricString TEXT;
BEGIN


    
    SELECT 
    INTO metricString
        string_agg( 
            CONCAT(
                  'M,'
                , pkMetricID
                , ','
                , coalesce(DisplayName, name, 'No name')

                
            )
            , E'\n' 
        )
    FROM tblMetric;

    RETURN metricString;
    
END;
$$;


ALTER FUNCTION public.fnsclgetmetrics() OWNER TO postgres;

--
-- Name: fnsclgetpercentage(double precision, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetpercentage(double precision, character varying) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    valueIn alias for $1;
    metricName alias for $2;
    percent double precision;
    isNum boolean;
BEGIN

    SELECT TRUE INTO isNum;
    CASE metricName

        --State of Health
        WHEN 'AvailabilityMetric' THEN
            SELECT valueIN INTO percent;
        WHEN 'GapCountMetric' THEN
            SELECT (100.0 - 15*(valueIn - 0.00274)/0.992) INTO percent;
        WHEN 'MassPositionMetric' THEN
            SELECT (100.0 - 15*(valueIn - 3.52)/10.79) INTO percent;
        WHEN 'TimingQualityMetric' THEN
            SELECT valueIN INTO percent;
        WHEN 'DeadChannelMetric:4-8' THEN
            SELECT (valueIN*100) INTO percent;
        
        --Coherence
        WHEN 'CoherencePBM:4-8' THEN
            SELECT (100.0 - 15*(1 - valueIn)/0.0377) INTO percent;
        WHEN 'CoherencePBM:18-22' THEN
            SELECT (100.0 - 15*(0.99 - valueIn)/0.12) INTO percent;
        WHEN 'CoherencePBM:90-110' THEN
            SELECT (100.0 - 15*(0.93 - valueIn)/0.0337) INTO percent;
        WHEN 'CoherencePBM:200-500' THEN
            SELECT (100.0 - 15*(0.83 - valueIn)/0.346) INTO percent;

        --Power Difference
        WHEN 'DifferencePBM:4-8' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.01)/0.348) INTO percent;
        WHEN 'DifferencePBM:18-22' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.01)/1.17) INTO percent;
        WHEN 'DifferencePBM:90-110' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.04)/4.66) INTO percent;
        WHEN 'DifferencePBM:200-500' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.03)/5.97) INTO percent;

        --Noise/StationDeviationMetric
        WHEN 'StationDeviationMetric:4-8' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.11)/3.32) INTO percent;
        WHEN 'StationDeviationMetric:18-22' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.17)/2.57) INTO percent;
        WHEN 'StationDeviationMetric:90-110' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.02)/2.88) INTO percent;
        WHEN 'StationDeviationMetric:200-500' THEN
            SELECT (100.0 - 15*(abs(valueIn) - 0.07)/2.90) INTO percent;

        --NLNM Deviation
        WHEN 'NLNMDeviationMetric:4-8' THEN
            SELECT (100.0 - 15*(valueIn - 3.33)/12.53) INTO percent;
        WHEN 'NLNMDeviationMetric:18-22' THEN
            SELECT (100.0 - 15*(valueIn - 13.41)/12.64) INTO percent;
        WHEN 'NLNMDeviationMetric:90-110' THEN
            SELECT (100.0 - 15*(valueIn - 13.57)/14.79) INTO percent;
        WHEN 'NLNMDeviationMetric:200-500' THEN
            SELECT (100.0 - 15*(valueIn - 20.74)/15.09) INTO percent;

        --Calibrations Does not exist when added, name may need changed.
        WHEN 'CalibrationMetric' THEN
            SELECT (100 - 10*power(valueIn/365, 2)) INTO percent;
        WHEN 'MeanError' THEN
            SELECT (100 - 500*valueIn) INTO percent;
        ELSE
            SELECT FALSE INTO isNum;
    END CASE;

    IF isNum = TRUE THEN
        IF percent >= 100 THEN
            RETURN '100';
        ELSIF percent <= 0 THEN
            RETURN '0';
        ELSE
            RETURN percent::text; 
        END IF;
    ELSE
        RETURN 'n'; --Front end strips out anything that isn't a number
    END IF;
END;
$_$;


ALTER FUNCTION public.fnsclgetpercentage(double precision, character varying) OWNER TO postgres;

--
-- Name: fnsclgetstationdata(integer[], integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetstationdata(integer[], integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    stationIDs alias for $1;
    metricID alias for $2;
    startDate alias for $3;
    endDate alias for $4;
    stationData TEXT;
    computeType int;
    metricName TEXT;
BEGIN
/*SELECT sum(value) as valueSum, sum(day) as dayCount, sen1.fkStationID, metricID
FROM(
    (
    --#EXPLAIN EXTENDED
    Select    --#pc1.valueSum, pc1.dayCount
            pc1.valueSum as value, pc1.dayCount as day
            , pc1.fkMetricID as metricID, pc1.fkChannelID as channelID
        FROM tblPreComputed pc1 --#FORCE INDEX (idx_tblPreComputed_Dates_fkParent)
        LEFT OUTER JOIN tblPreComputed pc2 --FORCE INDEX FOR JOIN (idx_tblPreComputed_Dates_primary)
            ON pc1.fkParentPreComputedID = pc2.pkPreComputedID 
                AND 2455988 <= pc2.start
                AND 2456018 >= pc2."end"
        WHERE   2455988 <= pc1.start
            AND 2456018 >= pc1."end"
            AND pc2.pkPreComputedID IS NULL
            
        --#GROUP BY pc1.fkChannelID, pc1.fkMetricID ORDER BY NULL
    )
    UNION ALL
    (
   -- #EXPLAIN EXTENDED
    Select   md1.value as value, 1 as day
            , md1.fkMetricID as metricID, md1.fkChannelID as channelID
        FROM tblMetricData md1
        WHERE 
            (date >= 2455988
                AND date <=  2455988 + 10 - (2455988 % 10) --#2455990
            )
            OR
            (date >=  2456018 - (2456018 % 10) --#2456010
                AND date <= 2456018)

        --#GROUP BY md1.fkChannelID, md1.fkMetricID ORDER BY NULL
    )
) semisum
INNER JOIN tblChannel ch1
    ON semisum.channelID = ch1.pkChannelID
        AND NOT ch1."isIgnored"
INNER JOIN tblSensor sen1
    ON ch1.fkSensorID = sen1.pkSensorID

GROUP BY sen1.fkStationID, semisum.metricID
*/
    Select fkComputeTypeID, name from tblMetric where pkMetricID = metricID INTO computeType, metricName;
    CASE computeType
        --Metric Data
        WHEN 1 THEN
            --Average across total number of values
            SELECT INTO stationData string_agg(CONCAT(id, ',',avg, ',', fnsclGetPercentage(avg, metricName)), E'\n') FROM (
                SELECT sen1.fkStationID as id, round((SUM(md1.value)/count(md1.*))::numeric, 4)::numeric as avg
                FROM tblMetricData md1
                JOIN tblChannel ch1
                    ON ch1.pkChannelID = md1.fkChannelID
                    AND NOT ch1."isIgnored"
                JOIN tblSensor sen1
                    ON ch1.fkSensorID = sen1.pkSensorID
                WHERE sen1.fkStationID = any(stationIDs)
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY sen1.fkStationID ) stations;
        WHEN 2 THEN
            --Average across days NOT ACCURATE
            select '2' into stationData;
        WHEN 3 THEN
            --Count all values, return sum
            SELECT INTO stationData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
                SELECT sen1.fkStationID as id, round(SUM(md1.value)::numeric, 0) as sum
                FROM tblMetricData md1
                JOIN tblChannel ch1
                    ON ch1.pkChannelID = md1.fkChannelID
                    AND NOT ch1."isIgnored"
                JOIN tblSensor sen1
                    ON ch1.fkSensorID = sen1.pkSensorID
                WHERE sen1.fkStationID = any(stationIDs)
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY sen1.fkStationID ) stations;
        WHEN 5 THEN
            --Calculate date since last calibration
            SELECT INTO stationData string_agg(CONCAT(id, ',',sum, ',', fnsclGetPercentage(sum, metricName)), E'\n') FROM (
                SELECT sen1.fkStationID as id, round((to_char(endDate, 'J')::INT-max(date))::numeric, 4) as sum
                FROM tblMetricstringData md1
                JOIN tblChannel ch1
                    ON ch1.pkChannelID = md1.fkChannelID
                    AND NOT ch1."isIgnored"
                JOIN tblSensor sen1
                    ON ch1.fkSensorID = sen1.pkSensorID
                WHERE sen1.fkStationID = any(stationIDs)
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY sen1.fkStationID ) stations;
        WHEN 6 THEN
            --Average across number of values
            select NULL into stationData;
        ELSE
            --Insert error into error log
            select 'Error' into stationData;
    END CASE;

    
    RETURN stationData;
END;
$_$;


ALTER FUNCTION public.fnsclgetstationdata(integer[], integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetstationplotdata(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetstationplotdata(integer, integer, date, date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    stationID alias for $1;
    metricID alias for $2;
    startDate alias for $3;
    endDate alias for $4;
    stationPlotData TEXT;
    computeType int;
BEGIN
    
    Select fkComputeTypeID from tblMetric where pkMetricID = metricID INTO computeType;
    CASE computeType
        --Metric Data
        WHEN 1 THEN
            --Average across total number of values
            SELECT INTO stationPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
                SELECT to_date(md1.date::text, 'J') as sdate, round((SUM(md1.value)/count(md1.*))::numeric, 4) as avg
                FROM tblMetricData md1
                JOIN tblChannel ch1
                    ON ch1.pkChannelID = md1.fkChannelID
                    AND NOT ch1."isIgnored"
                JOIN tblSensor sen1
                    ON ch1.fkSensorID = sen1.pkSensorID
                WHERE sen1.fkStationID = stationID
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY md1.date ) stations;
        WHEN 2 THEN
            --Average across days NOT ACCURATE
            select '2' into stationPlotData;
        WHEN 3 THEN
            --Count all values, return sum
            SELECT INTO stationPlotData string_agg(CONCAT(sdate, ',',avg), E'\n') FROM (
                SELECT to_date(md1.date::text, 'J') as sdate, round(SUM(md1.value)::numeric, 4) as avg
                FROM tblMetricData md1
                JOIN tblChannel ch1
                    ON ch1.pkChannelID = md1.fkChannelID
                    AND NOT ch1."isIgnored"
                JOIN tblSensor sen1
                    ON ch1.fkSensorID = sen1.pkSensorID
                WHERE sen1.fkStationID = stationID
                    AND 
                    md1.date >= to_char(startDate, 'J')::INT
                    AND md1.date <= to_char(endDate, 'J')::INT
                    AND md1.fkMetricID = metricID
                GROUP BY md1.date ) stations;
        --Calibration Data
        WHEN 5 THEN
            --Calculate data between last calibrations
            select '5' into stationPlotData;
        WHEN 6 THEN
            --Average across number of values
            select '6' into stationPlotData;
        ELSE
            --Insert error into error log
            select 'Error' into stationPlotData;
    END CASE;

    
    RETURN stationPlotData;
END;
$_$;


ALTER FUNCTION public.fnsclgetstationplotdata(integer, integer, date, date) OWNER TO postgres;

--
-- Name: fnsclgetstations(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclgetstations() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    stationString TEXT;
BEGIN


    
    SELECT 
    INTO stationString
        string_agg(
            CONCAT(
                  'S,'
                , pkstationID
                , ','
                , fkNetworkID
                , ','
                , st1."name"
                , ','
                , groupIDs
                
            )
            , E'\n' 
        )
    FROM tblStation st1
    JOIN "tblGroup"
        ON st1.fkNetworkID = pkGroupID --to_char('2012-03-01'::date, 'J')::INT  || to_date(2456013::text, 'J')
    JOIN (
        SELECT "fkStationID" as statID, string_agg("fkGroupID"::text, ',') as groupIDs
            FROM "tblStationGroupTie"
            GROUP BY "fkStationID") as gst
        ON st1.pkStationID = gst.statID;

    RETURN stationString;
    
END;
$$;


ALTER FUNCTION public.fnsclgetstations() OWNER TO postgres;

--
-- Name: fnsclisnumeric(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fnsclisnumeric("inputText" text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
  DECLARE num NUMERIC;
BEGIN
    IF "inputText" = 'NaN' THEN
        RETURN FALSE;
    END IF;

    num = "inputText"::NUMERIC;
    --No exceptions and hasn't returned false yet, so it must be a numeric.
    RETURN TRUE;
    EXCEPTION WHEN invalid_text_representation THEN
    RETURN FALSE;
END;
$$;


ALTER FUNCTION public.fnsclisnumeric("inputText" text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tblscan; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblscan (
    pkscanid uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    fkparentscan uuid,
    lastupdate timestamp with time zone DEFAULT now(),
    metricfilter character varying,
    networkfilter character varying,
    stationfilter character varying,
    channelfilter character varying,
    startdate date NOT NULL,
    enddate date NOT NULL,
    priority integer DEFAULT 10 NOT NULL,
    deleteexisting boolean DEFAULT false NOT NULL,
    scheduledrun date,
    finished boolean DEFAULT false NOT NULL,
    taken boolean DEFAULT false NOT NULL,
    locationfilter character varying(10)
);


ALTER TABLE public.tblscan OWNER TO postgres;

--
-- Name: COLUMN tblscan.pkscanid; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.tblscan.pkscanid IS 'Uses uuid_generate_v1mc() to generate the default value.';


--
-- Name: COLUMN tblscan.scheduledrun; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.tblscan.scheduledrun IS 'Future date when this scan can be run.';


--
-- Name: fntakenextscan(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fntakenextscan() RETURNS SETOF public.tblscan
    LANGUAGE plpgsql
    AS $$
DECLARE
    scanID uuid;
BEGIN
--We do not want multiple connections taking the same scan
    LOCK TABLE tblscan IN ACCESS EXCLUSIVE MODE;

    --Find our priority scan.
    SELECT pkscanid
      FROM tblscan
      WHERE
          finished = FALSE
          AND
          (
          scheduledrun < current_date
          OR
          scheduledrun IS NULL
          )
          AND
          taken = FALSE
      ORDER BY
          priority desc,
          enddate desc,
          startdate desc
      LIMIT 1
  INTO scanID;

--Set taken update timestamp
  UPDATE tblscan
    SET taken=true, lastupdate = current_timestamp
  WHERE
    pkscanid = scanID;

RETURN QUERY
SELECT pkscanid, fkparentscan, lastupdate, metricfilter, networkfilter,
       stationfilter, channelfilter, startdate, enddate, priority, deleteexisting,
       scheduledrun, finished, taken, locationfilter
  FROM tblscan
  WHERE
  pkscanid = scanID;



END
$$;


ALTER FUNCTION public.fntakenextscan() OWNER TO postgres;

--
-- Name: spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	hashIN alias for $7;
	hashID int;
	debug text;

BEGIN
--select name from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;

	SELECT
	  tblhash."pkHashID"
	FROM
	  public.tblhash,
	  public.tblmetricdata,
	  public.tblmetric,
	  public.tblchannel,
	  public.tblsensor,
	  public.tblstation,
	  public."tblGroup"
	WHERE
	  --JOINS
	  tblhash."pkHashID" = tblmetricdata."fkHashID" AND
	  tblmetricdata.fkmetricid = tblmetric.pkmetricid AND
	  tblmetricdata.fkchannelid = tblchannel.pkchannelid AND
	  tblchannel.fksensorid = tblsensor.pksensorid AND
	  tblsensor.fkstationid = tblstation.pkstationid AND
	  tblstation.fknetworkid = "tblGroup".pkgroupid AND
	  --Criteria
	  tblMetric.name = metricName AND
	  "tblGroup".name = networkName AND
	  tblStation.name = stationName AND
	  tblSensor.location = locationName AND
	  tblChannel.name = channelName

	INTO hashID;

	IF hashID IS NOT NULL THEN
		RETURN 1;
	ELSE
		RETURN 0;
	END IF;

    END;
$_$;


ALTER FUNCTION public.spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) OWNER TO postgres;

--
-- Name: spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) RETURNS double precision
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	value double precision;
	debug text;

BEGIN
--select name from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;

	SELECT
	  tblMetricData.value
	FROM

	  public.tblmetricdata,
	  public.tblmetric,
	  public.tblchannel,
	  public.tblsensor,
	  public.tblstation,
	  public."tblGroup"
	WHERE
	  --JOINS
	   tblmetricdata.fkmetricid = tblmetric.pkmetricid AND
	  tblmetricdata.fkchannelid = tblchannel.pkchannelid AND
	  tblchannel.fksensorid = tblsensor.pksensorid AND
	  tblsensor.fkstationid = tblstation.pkstationid AND
	  tblstation.fknetworkid = "tblGroup".pkgroupid AND
	  --Criteria
	  tblMetric.name = metricName AND
	  "tblGroup".name = networkName AND
	  tblStation.name = stationName AND
	  tblSensor.location = locationName AND
	  tblChannel.name = channelName AND
	  tblMetricData.date = to_char(nDate, 'J')::INT
	INTO value;
	RETURN value;

    END;
$_$;


ALTER FUNCTION public.spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) RETURNS bytea
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	hash alias for $7;
	debug text;

BEGIN

--select name from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;

--SELECT to_char('2012-06-19'::DATE, 'J')::INT;

	SELECT
	  tblHash.hash
	FROM
	  public.tblhash,
	  public.tblmetricdata,
	  public.tblmetric,
	  public.tblchannel,
	  public.tblsensor,
	  public.tblstation,
	  public."tblGroup"
	WHERE
	  --JOINS
	  tblmetricdata."fkHashID" = tblHash."pkHashID" AND
	  tblmetricdata.fkmetricid = tblmetric.pkmetricid AND
	  tblmetricdata.fkchannelid = tblchannel.pkchannelid AND
	  tblchannel.fksensorid = tblsensor.pksensorid AND
	  tblsensor.fkstationid = tblstation.pkstationid AND
	  tblstation.fknetworkid = "tblGroup".pkgroupid AND
	  --Criteria
	  tblMetric.name = metricName AND
	  "tblGroup".name = networkName AND
	  tblStation.name = stationName AND
	  tblSensor.location = locationName AND
	  tblChannel.name = channelName AND
	  tblMetricData.date = to_char(nDate, 'J')::INT
	INTO hash;


    END;
$_$;


ALTER FUNCTION public.spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) OWNER TO postgres;

--
-- Name: spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	valueIN alias for $7;
	hashIN alias for $8;
	networkID int;
	stationID int;
	sensorID int;
	channelID int;
	metricID int;
	hashID int;
	debug text;

BEGIN
--INSERT INTO tblerrorlog (errortime, errormessage) values (CURRENT_TIMESTAMP,'It inserted'||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName);

    IF fnsclisnumeric(valueIN::TEXT) = FALSE THEN
	INSERT INTO tblerrorlog (errortime, errormessage)
		VALUES (
			CURRENT_TIMESTAMP,
			'Non Numeric value: Nothing Inserted '||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName||' '||valueIN);
	RETURN;
    END IF;

--Insert network if doesn't exist then get ID

    LOCK TABLE "tblGroup" IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO "tblGroup" (name,"fkGroupTypeID")
	SELECT networkName, 1  --Group Type 1 is Network
	WHERE NOT EXISTS (
	    SELECT * FROM "tblGroup" WHERE name = networkName
	);

    SELECT pkGroupID
        FROM "tblGroup"
        WHERE name = networkName
    INTO networkID;

--Insert station if doesn't exist then get ID
    LOCK TABLE tblStation IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblStation (name,fkNetworkID)
	SELECT stationName, networkID
	WHERE NOT EXISTS (
	    SELECT * FROM tblStation WHERE name = stationName AND fkNetworkID = networkID
	);

    SELECT pkStationID
        FROM tblStation
        WHERE name = stationName AND fkNetworkID = networkID
    INTO stationID;

--Ties the Station to its Network for the GUI to use.
    LOCK TABLE "tblStationGroupTie" IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO "tblStationGroupTie" ("fkGroupID", "fkStationID")
	SELECT networkID, stationID
	WHERE NOT EXISTS (
	    SELECT * FROM "tblStationGroupTie" WHERE "fkGroupID" = networkID AND "fkStationID" = stationID
	);

--Insert sensor if doesn't exist then get ID
    LOCK TABLE tblSensor IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblSensor (location,fkStationID)
	SELECT locationName, stationID
	WHERE NOT EXISTS (
	    SELECT * FROM tblSensor WHERE location = locationName AND fkStationID = stationID
	);

    SELECT pkSensorID
        FROM tblSensor
        WHERE location = locationName AND fkStationID = stationID
    INTO sensorID;

--Insert channel if doesn't exist then get ID
    LOCK TABLE tblChannel IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblChannel (name, fkSensorID)
	SELECT channelName, sensorID
	WHERE NOT EXISTS (
	    SELECT * FROM tblChannel WHERE name = channelName AND fkSensorID = sensorID
	);

    SELECT pkChannelID
        FROM tblChannel
        WHERE name = channelName AND fkSensorID = sensorID
    INTO channelID;

--Insert metric if doesn't exist then get ID
    LOCK TABLE tblMetric IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblMetric (name, fkComputeTypeID, displayName)
	SELECT metricName, 1, metricName --Compute Type 1 is averaged over channel and days.
	WHERE NOT EXISTS (
	    SELECT * FROM tblMetric WHERE name = metricName
	);

    SELECT pkMetricID
        FROM tblMetric
        WHERE name = metricName
    INTO metricID;

--Insert hash if doesn't exist then get ID
    LOCK TABLE tblHash IN SHARE ROW EXCLUSIVE MODE;
    INSERT INTO tblHash (hash)
	SELECT hashIN
	WHERE NOT EXISTS (
	    SELECT * FROM tblHash WHERE hash = hashIN
	);

   --select pkHashID from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;
    SELECT "pkHashID"
        FROM tblHash
        WHERE hash = hashIN
    INTO hashID;

--Insert date into tblDate
    LOCK TABLE tblDate IN SHARE ROW EXCLUSIVE MODE;
    BEGIN
    INSERT INTO tblDate (pkDateID, date)
	SELECT to_char(nDate, 'J')::INT, nDate
	WHERE NOT EXISTS (
	    SELECT * FROM tblDate WHERE date = nDate
	);


    EXCEPTION WHEN unique_violation THEN
        INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "tblDate has a date with incorrect pkDateID date:"
	    +to_char(nDate, 'J')::INT);
    END;
--Insert/Update metric value for day
    UPDATE tblMetricData
	SET value = valueIN, "fkHashID" = hashID
	WHERE date = to_char(nDate, 'J')::INT AND fkMetricID = metricID AND fkChannelID = channelID;
    IF NOT FOUND THEN
    BEGIN
	INSERT INTO tblMetricData (fkChannelID, date, fkMetricID, value, "fkHashID")
	    VALUES (channelID, to_char(nDate, 'J')::INT, metricID, valueIN, hashID);
    --We could remove this possibility with a table lock, but I fear locking such a large table.
    EXCEPTION WHEN unique_violation THEN
	INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "Multiple simultaneous data inserts for metric:"+metricID+
	    " date:"+to_char(nDate, 'J')::INT);
    END;
    END IF;


    END;
$_$;


ALTER FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) OWNER TO postgres;

--
-- Name: spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	valueIN alias for $7;
	hashIN alias for $8;
	networkID int;
	stationID int;
	sensorID int;
	channelID int;
	metricID int;
	hashID int;
	debug text;

BEGIN
INSERT INTO tblerrorlog (errortime, errormessage) values (CURRENT_TIMESTAMP,'It inserted'||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName);

--Insert network if doesn't exist then get ID
    BEGIN
        INSERT INTO "tblGroup" (name,"fkGroupTypeID") VALUES (networkName, 1); --Group Type 1 is Network
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkGroupID
        FROM "tblGroup"
        WHERE name = networkName
    INTO networkID;

--Insert station if doesn't exist then get ID
    BEGIN
        INSERT INTO tblStation(name,fkNetworkID) VALUES (stationName, networkID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkStationID
        FROM tblStation
        WHERE name = stationName AND fkNetworkID = networkID
    INTO stationID;

    BEGIN --Ties the Station to its Network for the GUI to use.
        INSERT INTO "tblStationGroupTie" ("fkGroupID", "fkStationID")
		VALUES (networkID, stationID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;

--Insert sensor if doesn't exist then get ID
    BEGIN
        INSERT INTO tblSensor(location,fkStationID) VALUES (locationName, stationID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkSensorID
        FROM tblSensor
        WHERE location = locationName AND fkStationID = stationID
    INTO sensorID;
--Insert channel if doesn't exist then get ID
    BEGIN
        INSERT INTO tblChannel(name,fkSensorID) VALUES (channelName, sensorID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkChannelID
        FROM tblChannel
        WHERE name = channelName AND fkSensorID = sensorID
    INTO channelID;
--Insert metric if doesn't exist then get ID
    BEGIN
        INSERT INTO tblMetric(name, fkComputeTypeID, displayName) VALUES (metricName, 1, metricName); --Compute Type 1 is averaged over channel and days.
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkMetricID
        FROM tblMetric
        WHERE name = metricName
    INTO metricID;

--Insert hash if doesn't exist then get ID
    BEGIN
        INSERT INTO tblHash(hash) VALUES (hashIN);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
   --select pkHashID from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;
    SELECT "pkHashID"
        FROM tblHash
        WHERE hash = hashIN
    INTO hashID;

--Insert date into tblDate
    BEGIN
        INSERT INTO tblDate (pkDateID, date)
	    VALUES (to_char(nDate, 'J')::INT, nDate);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
--Insert/Update metric value for day
    UPDATE tblmetricstringdata
	SET value = valueIN, "fkHashID" = hashID
	WHERE date = to_char(nDate, 'J')::INT AND fkMetricID = metricID AND fkChannelID = channelID;
    IF NOT found THEN
    BEGIN
	INSERT INTO tblmetricstringdata (fkChannelID, date, fkMetricID, value, "fkHashID")
	    VALUES (channelID, to_char(nDate, 'J')::INT, metricID, valueIN, hashID);
    EXCEPTION WHEN unique_violation THEN
	INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "Multiple simultaneous data inserts for metric:"+metricID+
	    " date:"+to_char(nDate, 'J')::INT);
    END;
    END IF;


    END;
$_$;


ALTER FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) OWNER TO postgres;

--
-- Name: spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nDate alias for $1;
	metricName alias for $2;
	networkName alias for $3;
	stationName alias for $4;
	locationName alias for $5;
	channelName alias for $6;
	valueIN alias for $7;
	hashIN alias for $8;
	networkID int;
	stationID int;
	sensorID int;
	channelID int;
	metricID int;
	hashID int;
	debug text;

BEGIN
INSERT INTO tblerrorlog (errortime, errormessage) values (CURRENT_TIMESTAMP,'It inserted'||nDate||' '||locationName||' '||channelName||' '||stationName||' '||metricName);

--Insert network if doesn't exist then get ID
    BEGIN
        INSERT INTO "tblGroup" (name,"fkGroupTypeID") VALUES (networkName, 1); --Group Type 1 is Network
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkGroupID
        FROM "tblGroup"
        WHERE name = networkName
    INTO networkID;

--Insert station if doesn't exist then get ID
    BEGIN
        INSERT INTO tblStation(name,fkNetworkID) VALUES (stationName, networkID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkStationID
        FROM tblStation
        WHERE name = stationName AND fkNetworkID = networkID
    INTO stationID;

    BEGIN --Ties the Station to its Network for the GUI to use.
        INSERT INTO "tblStationGroupTie" ("fkGroupID", "fkStationID")
		VALUES (networkID, stationID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;

--Insert sensor if doesn't exist then get ID
    BEGIN
        INSERT INTO tblSensor(location,fkStationID) VALUES (locationName, stationID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkSensorID
        FROM tblSensor
        WHERE location = locationName AND fkStationID = stationID
    INTO sensorID;
--Insert channel if doesn't exist then get ID
    BEGIN
        INSERT INTO tblChannel(name,fkSensorID) VALUES (channelName, sensorID);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkChannelID
        FROM tblChannel
        WHERE name = channelName AND fkSensorID = sensorID
    INTO channelID;
--Insert metric if doesn't exist then get ID
    BEGIN
        INSERT INTO tblMetric(name, fkComputeTypeID, displayName) VALUES (metricName, 1, metricName); --Compute Type 1 is averaged over channel and days.
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
    SELECT pkMetricID
        FROM tblMetric
        WHERE name = metricName
    INTO metricID;

--Insert hash if doesn't exist then get ID
    BEGIN
        INSERT INTO tblHash(hash) VALUES (hashIN);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
   --select pkHashID from tblStation into debug;
--RAISE NOTICE 'stationID(%)', debug;
    SELECT "pkHashID"
        FROM tblHash
        WHERE hash = hashIN
    INTO hashID;

--Insert date into tblDate
    BEGIN
        INSERT INTO tblDate (pkDateID, date)
	    VALUES (to_char(nDate, 'J')::INT, nDate);
    EXCEPTION WHEN unique_violation THEN
        --Do nothing, it already exists
    END;
--Insert/Update metric value for day
    UPDATE tblmetricstringdata
	SET value = valueIN, "fkHashID" = hashID
	WHERE date = to_char(nDate, 'J')::INT AND fkMetricID = metricID AND fkChannelID = channelID;
    IF NOT found THEN
    BEGIN
	INSERT INTO tblmetricstringdata (fkChannelID, date, fkMetricID, value, "fkHashID")
	    VALUES (channelID, to_char(nDate, 'J')::INT, metricID, valueIN, hashID);
    EXCEPTION WHEN unique_violation THEN
	INSERT INTO tblErrorLog (errortime, errormessage)
	    VALUES (CURRENT_TIMESTAMP, "Multiple simultaneous data inserts for metric:"+metricID+
	    " date:"+to_char(nDate, 'J')::INT);
    END;
    END IF;


    END;
$_$;


ALTER FUNCTION public.spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) OWNER TO postgres;

--
-- Name: tblGroup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."tblGroup" (
    pkgroupid integer NOT NULL,
    name character varying(36) NOT NULL,
    "isIgnored" boolean DEFAULT false NOT NULL,
    "fkGroupTypeID" integer
);


ALTER TABLE public."tblGroup" OWNER TO postgres;

--
-- Name: tblGroupType; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."tblGroupType" (
    "pkGroupTypeID" integer NOT NULL,
    name character varying(16) NOT NULL
);


ALTER TABLE public."tblGroupType" OWNER TO postgres;

--
-- Name: grouptypeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.grouptypeview AS
 SELECT grpt."pkGroupTypeID",
    grpt.name,
    grp.pkgroupid
   FROM (public."tblGroupType" grpt
     JOIN public."tblGroup" grp ON ((grp."fkGroupTypeID" = grpt."pkGroupTypeID")))
  ORDER BY grpt."pkGroupTypeID", grp.pkgroupid;


ALTER TABLE public.grouptypeview OWNER TO postgres;

--
-- Name: groupview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.groupview AS
 SELECT "tblGroup".pkgroupid,
    "tblGroup".name,
    "tblGroup"."fkGroupTypeID"
   FROM public."tblGroup"
  ORDER BY "tblGroup".pkgroupid;


ALTER TABLE public.groupview OWNER TO postgres;

--
-- Name: tblStationGroupTie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."tblStationGroupTie" (
    "fkGroupID" integer NOT NULL,
    "fkStationID" integer NOT NULL
);


ALTER TABLE public."tblStationGroupTie" OWNER TO postgres;

--
-- Name: tblstation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblstation (
    pkstationid integer NOT NULL,
    fknetworkid integer NOT NULL,
    name character varying(16) NOT NULL
);


ALTER TABLE public.tblstation OWNER TO postgres;

--
-- Name: stationview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.stationview AS
 SELECT sta.pkstationid,
    sta.fknetworkid,
    sta.name,
    sgt."fkGroupID"
   FROM (public.tblstation sta
     JOIN public."tblStationGroupTie" sgt ON ((sta.pkstationid = sgt."fkStationID")))
  ORDER BY sta.pkstationid, sgt."fkGroupID";


ALTER TABLE public.stationview OWNER TO postgres;

--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."tblGroupType_pkGroupTypeID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."tblGroupType_pkGroupTypeID_seq" OWNER TO postgres;

--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."tblGroupType_pkGroupTypeID_seq" OWNED BY public."tblGroupType"."pkGroupTypeID";


--
-- Name: tblGroup_pkgroupid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."tblGroup_pkgroupid_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."tblGroup_pkgroupid_seq" OWNER TO postgres;

--
-- Name: tblGroup_pkgroupid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."tblGroup_pkgroupid_seq" OWNED BY public."tblGroup".pkgroupid;


--
-- Name: tblcalibrationdata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblcalibrationdata (
    pkcalibrationdataid integer NOT NULL,
    fkchannelid integer NOT NULL,
    year smallint NOT NULL,
    month smallint NOT NULL,
    day smallint NOT NULL,
    date date NOT NULL,
    calyear integer NOT NULL,
    calmonth smallint NOT NULL,
    calday smallint NOT NULL,
    caldate date NOT NULL,
    fkmetcaltypeid integer NOT NULL,
    value double precision NOT NULL,
    fkmetricid integer NOT NULL
);


ALTER TABLE public.tblcalibrationdata OWNER TO postgres;

--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblcalibrationdata_pkcalibrationdataid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblcalibrationdata_pkcalibrationdataid_seq OWNER TO postgres;

--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblcalibrationdata_pkcalibrationdataid_seq OWNED BY public.tblcalibrationdata.pkcalibrationdataid;


--
-- Name: tblchannel; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblchannel (
    pkchannelid integer NOT NULL,
    fksensorid integer NOT NULL,
    name character varying(16) NOT NULL,
    derived integer DEFAULT 0 NOT NULL,
    "isIgnored" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.tblchannel OWNER TO postgres;

--
-- Name: tblchannel_pkchannelid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblchannel_pkchannelid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblchannel_pkchannelid_seq OWNER TO postgres;

--
-- Name: tblchannel_pkchannelid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblchannel_pkchannelid_seq OWNED BY public.tblchannel.pkchannelid;


--
-- Name: tblcomputetype; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblcomputetype (
    pkcomputetypeid integer NOT NULL,
    name character varying(8) NOT NULL,
    description character varying(2000) DEFAULT 'NULL::character varying'::character varying,
    iscalibration boolean DEFAULT false NOT NULL
);


ALTER TABLE public.tblcomputetype OWNER TO postgres;

--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblcomputetype_pkcomputetypeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblcomputetype_pkcomputetypeid_seq OWNER TO postgres;

--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblcomputetype_pkcomputetypeid_seq OWNED BY public.tblcomputetype.pkcomputetypeid;


--
-- Name: tbldate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tbldate (
    pkdateid integer NOT NULL,
    date date NOT NULL
);


ALTER TABLE public.tbldate OWNER TO postgres;

--
-- Name: tblerrorlog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblerrorlog (
    pkerrorlogid integer NOT NULL,
    errortime timestamp(6) without time zone DEFAULT now(),
    errormessage character varying(20480) DEFAULT 'NULL::character varying'::character varying
);


ALTER TABLE public.tblerrorlog OWNER TO postgres;

--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblerrorlog_pkerrorlogid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblerrorlog_pkerrorlogid_seq OWNER TO postgres;

--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblerrorlog_pkerrorlogid_seq OWNED BY public.tblerrorlog.pkerrorlogid;


--
-- Name: tblhash; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblhash (
    "pkHashID" bigint NOT NULL,
    hash bytea NOT NULL
);


ALTER TABLE public.tblhash OWNER TO postgres;

--
-- Name: tblhash_pkHashID_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."tblhash_pkHashID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."tblhash_pkHashID_seq" OWNER TO postgres;

--
-- Name: tblhash_pkHashID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."tblhash_pkHashID_seq" OWNED BY public.tblhash."pkHashID";


--
-- Name: tblmetadata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblmetadata (
    fkchannelid integer NOT NULL,
    epoch timestamp(6) without time zone NOT NULL,
    sensor_info character varying(64) DEFAULT 'NULL::character varying'::character varying,
    raw_metadata bytea
);


ALTER TABLE public.tblmetadata OWNER TO postgres;

--
-- Name: tblmetric; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblmetric (
    pkmetricid integer NOT NULL,
    name character varying(64) NOT NULL,
    fkparentmetricid integer,
    legend character varying(128) DEFAULT 'NULL::character varying'::character varying,
    fkcomputetypeid integer NOT NULL,
    displayname character varying(64) DEFAULT 'NULL::character varying'::character varying
);


ALTER TABLE public.tblmetric OWNER TO postgres;

--
-- Name: tblmetric_pkmetricid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblmetric_pkmetricid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblmetric_pkmetricid_seq OWNER TO postgres;

--
-- Name: tblmetric_pkmetricid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblmetric_pkmetricid_seq OWNED BY public.tblmetric.pkmetricid;


--
-- Name: tblmetricdata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblmetricdata (
    fkchannelid integer NOT NULL,
    date integer NOT NULL,
    fkmetricid integer NOT NULL,
    value double precision NOT NULL,
    "fkHashID" bigint NOT NULL
);


ALTER TABLE public.tblmetricdata OWNER TO postgres;

--
-- Name: COLUMN tblmetricdata.date; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.tblmetricdata.date IS 'Julian date (number of days from Midnight November 4714 BC). This is based on the Gregorian proleptic Julian Day number standard and is natively supported in Postgresql.';


--
-- Name: tblmetricstringdata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblmetricstringdata (
    fkchannelid integer NOT NULL,
    date integer NOT NULL,
    fkmetricid integer NOT NULL,
    value character varying NOT NULL,
    "fkHashID" bigint NOT NULL
);


ALTER TABLE public.tblmetricstringdata OWNER TO postgres;

--
-- Name: COLUMN tblmetricstringdata.date; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.tblmetricstringdata.date IS 'Julian date (number of days from Midnight November 4714 BC). This is based on the Gregorian proleptic Julian Day number standard and is natively supported in Postgresql.';


--
-- Name: tblscanmessage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblscanmessage (
    pkmessageid bigint NOT NULL,
    fkscanid uuid NOT NULL,
    network character(2),
    location character varying(10),
    station character varying(10),
    channel character varying(10),
    "timestamp" timestamp with time zone DEFAULT now(),
    metric character varying(50),
    message text
);


ALTER TABLE public.tblscanmessage OWNER TO postgres;

--
-- Name: COLUMN tblscanmessage.location; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.tblscanmessage.location IS 'Allows for comparison metrics 00-10';


--
-- Name: tblscanmessage_pkmessageid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblscanmessage_pkmessageid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblscanmessage_pkmessageid_seq OWNER TO postgres;

--
-- Name: tblscanmessage_pkmessageid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblscanmessage_pkmessageid_seq OWNED BY public.tblscanmessage.pkmessageid;


--
-- Name: tblsensor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tblsensor (
    pksensorid integer NOT NULL,
    fkstationid integer NOT NULL,
    location character varying(16) NOT NULL
);


ALTER TABLE public.tblsensor OWNER TO postgres;

--
-- Name: tblsensor_pksensorid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblsensor_pksensorid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblsensor_pksensorid_seq OWNER TO postgres;

--
-- Name: tblsensor_pksensorid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblsensor_pksensorid_seq OWNED BY public.tblsensor.pksensorid;


--
-- Name: tblstation_pkstationid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tblstation_pkstationid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tblstation_pkstationid_seq OWNER TO postgres;

--
-- Name: tblstation_pkstationid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tblstation_pkstationid_seq OWNED BY public.tblstation.pkstationid;


--
-- Name: tblGroup pkgroupid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroup" ALTER COLUMN pkgroupid SET DEFAULT nextval('public."tblGroup_pkgroupid_seq"'::regclass);


--
-- Name: tblGroupType pkGroupTypeID; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroupType" ALTER COLUMN "pkGroupTypeID" SET DEFAULT nextval('public."tblGroupType_pkGroupTypeID_seq"'::regclass);


--
-- Name: tblcalibrationdata pkcalibrationdataid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcalibrationdata ALTER COLUMN pkcalibrationdataid SET DEFAULT nextval('public.tblcalibrationdata_pkcalibrationdataid_seq'::regclass);


--
-- Name: tblchannel pkchannelid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblchannel ALTER COLUMN pkchannelid SET DEFAULT nextval('public.tblchannel_pkchannelid_seq'::regclass);


--
-- Name: tblcomputetype pkcomputetypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcomputetype ALTER COLUMN pkcomputetypeid SET DEFAULT nextval('public.tblcomputetype_pkcomputetypeid_seq'::regclass);


--
-- Name: tblerrorlog pkerrorlogid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblerrorlog ALTER COLUMN pkerrorlogid SET DEFAULT nextval('public.tblerrorlog_pkerrorlogid_seq'::regclass);


--
-- Name: tblhash pkHashID; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblhash ALTER COLUMN "pkHashID" SET DEFAULT nextval('public."tblhash_pkHashID_seq"'::regclass);


--
-- Name: tblmetric pkmetricid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetric ALTER COLUMN pkmetricid SET DEFAULT nextval('public.tblmetric_pkmetricid_seq'::regclass);


--
-- Name: tblscanmessage pkmessageid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblscanmessage ALTER COLUMN pkmessageid SET DEFAULT nextval('public.tblscanmessage_pkmessageid_seq'::regclass);


--
-- Name: tblsensor pksensorid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblsensor ALTER COLUMN pksensorid SET DEFAULT nextval('public.tblsensor_pksensorid_seq'::regclass);


--
-- Name: tblstation pkstationid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblstation ALTER COLUMN pkstationid SET DEFAULT nextval('public.tblstation_pkstationid_seq'::regclass);


--
-- Data for Name: tblGroup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."tblGroup" (pkgroupid, name, "isIgnored", "fkGroupTypeID") FROM stdin;
649	IU	f	1
650	US	f	1
\.


--
-- Data for Name: tblGroupType; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."tblGroupType" ("pkGroupTypeID", name) FROM stdin;
1	Network Code
2	Groups
3	Countries
4	Regions
\.


--
-- Data for Name: tblStationGroupTie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."tblStationGroupTie" ("fkGroupID", "fkStationID") FROM stdin;
649	161
650	146
649	165
650	147
\.


--
-- Data for Name: tblcalibrationdata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblcalibrationdata (pkcalibrationdataid, fkchannelid, year, month, day, date, calyear, calmonth, calday, caldate, fkmetcaltypeid, value, fkmetricid) FROM stdin;
\.


--
-- Data for Name: tblchannel; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblchannel (pkchannelid, fksensorid, name, derived, "isIgnored") FROM stdin;
3353	505	LNZ	0	f
3354	506	VMW	0	f
3355	506	BH2	0	f
3356	506	VMV	0	f
3357	506	BH1	0	f
3358	506	VMU	0	f
3359	506	LH2	0	f
3360	506	LH1	0	f
3361	506	BHZ	0	f
3362	506	VH2	0	f
3363	506	VH1	0	f
3364	506	LHZ	0	f
3365	506	VHZ	0	f
3366	505	LN2	0	f
3367	505	LN1	0	f
3368	507	LHZ	0	f
3369	508	LN2	0	f
3370	508	LN1	0	f
3371	509	LDO	0	f
3372	508	LNZ	0	f
3373	510	VMW	0	f
3374	510	VMV	0	f
3375	510	BH2	0	f
3376	510	VMU	0	f
3377	510	BH1	0	f
3378	510	VH2	0	f
3379	510	VH1	0	f
3380	507	VMW	0	f
3381	507	VMV	0	f
3382	507	BH2	0	f
3383	507	VMU	0	f
3384	507	BH1	0	f
3385	510	BHZ	0	f
3386	507	VH2	0	f
3387	507	VH1	0	f
3388	510	VHZ	0	f
3389	507	BHZ	0	f
3390	507	VHZ	0	f
3391	510	LH2	0	f
3392	510	LH1	0	f
3393	507	LH2	0	f
3394	507	LH1	0	f
3395	510	LHZ	0	f
3396	511	LHZ-LHZ	0	f
3397	511	LHND-LHND	0	f
3398	511	LHED-LHED	0	f
3574	540	BH2	0	f
3575	540	BH1	0	f
3579	542	BHZ	0	f
3580	543	BDF	0	f
3581	544	LDO	0	f
3582	545	HDF	0	f
3583	546	LKO	0	f
3584	547	LFZ	0	f
3585	546	LWS	0	f
3586	542	VMW	0	f
3587	542	VMV	0	f
3588	542	VH2	0	f
3589	542	VMU	0	f
3590	542	VH1	0	f
3591	540	VHZ	0	f
3592	546	LWD	0	f
3593	542	LH2	0	f
3594	542	LH1	0	f
3595	548	LDO	0	f
3596	546	LDO	0	f
3597	540	LHZ	0	f
3599	550	LNZ	0	f
3600	542	BH2	0	f
3601	542	BH1	0	f
3602	547	LF2	0	f
3603	547	LF1	0	f
3604	540	BHZ	0	f
3606	540	VH2	0	f
3607	540	VH1	0	f
3608	542	VHZ	0	f
3609	546	LIO	0	f
3610	540	LH2	0	f
3611	540	LH1	0	f
3612	546	LRI	0	f
3613	550	LN2	0	f
3614	546	LRH	0	f
3615	550	LN1	0	f
3616	542	LHZ	0	f
3649	556	LHZ-LHZ	0	f
3650	556	LHND-LHND	0	f
3651	556	LHED-LHED	0	f
3734	571	VM2	0	f
3735	571	VM1	0	f
3736	572	LHZ	0	f
3737	573	LN2	0	f
3738	573	LN1	0	f
3739	571	VY2	0	f
3740	571	VY1	0	f
3741	571	VMZ	0	f
3742	574	LDO	0	f
3743	573	LNZ	0	f
3744	571	VYZ	0	f
3745	571	BH2	0	f
3746	571	BH1	0	f
3747	571	VH2	0	f
3748	571	VH1	0	f
3749	572	VMW	0	f
3750	572	VMV	0	f
3751	572	BH2	0	f
3752	572	VMU	0	f
3753	572	BH1	0	f
3754	571	BHZ	0	f
3755	572	VH2	0	f
3756	572	VH1	0	f
3757	571	VHZ	0	f
3758	572	BHZ	0	f
3759	572	VHZ	0	f
3760	571	LH2	0	f
3761	575	LDO	0	f
3762	571	LH1	0	f
3763	572	LH2	0	f
3764	572	LH1	0	f
3765	571	LHZ	0	f
3802	580	LHZ-LHZ	0	f
3803	580	LHND-LHND	0	f
3804	580	LHED-LHED	0	f
11787	540	VMW	0	f
11788	540	VMV	0	f
11789	540	VMU	0	f
\.


--
-- Data for Name: tblcomputetype; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblcomputetype (pkcomputetypeid, name, description, iscalibration) FROM stdin;
1	AVG_CH	Average across total number of values	f
2	AVG_DAY	Values are averaged over number of days.	f
3	VALUE_CO	Values are totalled over the window of time.	f
4	PARENT	Not used in computations.	f
5	CAL_DATE	Value is the difference between the Calibrati	t
6	CAL_AVG	Values are averaged over the number of values	t
7	NONE	Values are not computed	f
\.


--
-- Data for Name: tbldate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tbldate (pkdateid, date) FROM stdin;
2458854	2020-01-05
2458855	2020-01-06
\.


--
-- Data for Name: tblerrorlog; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblerrorlog (pkerrorlogid, errortime, errormessage) FROM stdin;
\.


--
-- Data for Name: tblhash; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblhash ("pkHashID", hash) FROM stdin;
30452149	\\x281871d19d89331a82656ef1d726a622
30452604	\\x302627b2e49594cfc401d7b7a3c37920
30454542	\\x12edddd70e7949fa479c508931951a7e
30454543	\\x31c046d8e892d7c6ffbc71ce405898b2
30454544	\\x9cd4211a9907efa5875333c74df52c7b
30454545	\\xde5143781786fd244ee4f36f59967514
30454546	\\x8f714aea7664449c80e757f39d5229b5
30454547	\\x0749b47501cc0851419e8eba642bd1f1
30454548	\\xcc9000071e9932f77400beac0fa4d908
30454549	\\xc67fa4ddc925125dc2576073f124aff8
30454550	\\xe5b4567edb96aa35d81a7a67d403cc4c
30454551	\\x953c8bd61e37815a4e1bf516eb820bef
30454552	\\xd00cce278c12bca5b2b386d2317a90d8
30454553	\\x3cb758cfffbbffd5d38c646dcdbadaa0
30454554	\\xc6c1fd8a76371b98563b451791ed2a7d
30454555	\\x6872e0e5bca5d1e24dc29f529047a904
30454556	\\xbf23e4b51582ee356482cd83c082bdd5
30455812	\\x330cd1ecb526badb80fb9f15647d6bd7
30455813	\\x8fcd6ff4c4dea6e66f1695cc2959b876
30455814	\\xc705eb5e7bf3ce4de99fe98e0d7c5250
30455815	\\xca8b8bb46f1bc75e866a049de986c731
30455816	\\x22616437225d95bd206ae8bc27974d4b
30455817	\\x0b3872cd233633e055ea8eef760223ee
30455823	\\x1fefebfb4633d79eb0874a909f0603a2
30455826	\\xdad8b53592c781439193f07e64ad68b0
30455832	\\x7935473b008558afe4b5bf98f9c9e125
30455833	\\xe4a1208787838ae0597fa5e101029c02
30455841	\\x4ac5391d033ac816ec7d77fd5be3db04
30457237	\\xa77fe932392cf483c186a4a2898c3911
30457238	\\xe28ac71cd60420743767ad896d2776b5
30457239	\\xb215c69e6b628621264c24fbc3486281
30457240	\\x4f2649af2926b9b4d20b39fe507320c0
30457241	\\xb28019857d8e2d2a5a0205cd8b241b97
30457242	\\xc7fa8e1edabce58e0894beb384036fcc
30457243	\\x64c9df20578ef67d8a8b7d308dea4dca
30457244	\\x13ba2770036ff2bb837df06e9af59dff
30457245	\\x30360d471c4e92e7fdbe9a0f05c773e4
30457246	\\x075bd5069e2e929a4c5c4910d20fb81a
30457247	\\x1fa0f830768650e5957e404605ff16ed
30457248	\\xd1fdb80b6e17f009f04b3af4115695d6
30457249	\\x4c1012f49c6c986f53e33b3942860acf
30457250	\\xef36a2deb8d7af42685a9134376b5378
30457251	\\x3720c688d709428e2be383dda6dfe4d9
30457252	\\xbea7dcc3a6b4aa47ac4a206fd34eeed6
30457253	\\xeb49a34961c2d1f97fd98b0a39d50d3e
30457254	\\xeb3230832bfbd9d98149921d71eb88c7
30457255	\\x4570686124052ab15e9df386284ac0c3
30457256	\\x8696e7e7a01250f0d08748f1f11dd0f1
30457257	\\xb4a108302020f14492e8cf7190b9cf22
30457258	\\x307a75499379f2ed90776986d2ee7940
30457259	\\xd68a270456a66d0a3f70888c5ba99415
30457260	\\x3f7125ac52a832ac73facdfb6d3a36bc
30457261	\\x56e28d7c6fbdb8c0e27222d2879f6a4b
30457262	\\xbe2ba1b1692c2b808a42367cf4c3bca0
30457263	\\x15e4f6cfc66d42a21591498dd57f0f1d
30457264	\\xb29b1ffdff41b621d417ed2f5cf3360c
30457265	\\xb01dcb9d799ef41de762fc54eb1198c3
30457266	\\xbbcebbc0bcfc7fa22bfa721e99fa8f00
30458185	\\x90d1961e5561388a8ff8378756baa3d9
30458186	\\x6eb0727cc0d9438cfe6d1e8fa9f04297
30458188	\\x21d9aff606ddf0073ded0e949d6a947f
30458190	\\xf9a7c83e1ac0185ab3063cd56a31accf
30469406	\\xe5763b774e7c1dee62758dcba8945ab1
30470978	\\x2c6880b880f5b445817c6b891db584fd
30470979	\\x85f8ea084054015da81241f3c52610fc
30470980	\\x02038aaf214470e4782994afcdf78603
30470981	\\x30acd374fc97d045bad7c54dbddbe43a
30470982	\\x036577bbcb23d8cdbb1374c2fca357fb
30470983	\\xa7a9d9838bebc5a15ef11044edd91f3d
30470984	\\x885d7a659f5a4e8feadb0c2777003e33
30470985	\\x992e6150ccf1074afaabf6b9cc7878fb
30470986	\\x1b31db23e44221cbadfc57b6d6dacedf
30470987	\\xdaf161a1faccdead1c497b60c2a83d7d
30470988	\\xa00104a7919bd2d4bf59e5813fe5d3bc
30470989	\\xe6f9a1a4a32852b1d4f4d3eae5fc53c2
30470990	\\x072dc86c7a5cda2e671d11e86526b6d8
30470991	\\xfc3829806ae4c7c86aebb450619a5b06
30470992	\\xd53d67c2ecb1598afb14f85e74deb2b7
30470993	\\xe4f5b5bbc46f32389fbeb53b86df009d
30470994	\\xfbf7a0377316559598f413a931d01df6
30470995	\\xb4dfc73445e6fcc52c5bc465a332396f
30470996	\\x83bb158fd5248aef01d6460c88f1e39f
30470997	\\xcd391f5d9a810a59161c974f6e0ad8a2
30470998	\\x4f23ffc162ef6086d3b06e965f2d78e8
30470999	\\xdb289fe4e38963cc97f762e5b3600b94
30471000	\\x6a5fed98b831317105c5222854ab55fe
30471001	\\xf89f5df34f46fa6df2a11cb8d5544baf
30471002	\\xeed145a33d4596ae66d75c7da175aec0
30471003	\\x782910e179650eb5c2c296e532d4a1b5
30471004	\\x4716e369c9b73e61c023f04661206ea2
30471039	\\x35972b4e639511d34761d5b751d316b4
30471093	\\x6b7e63d149428a24415f9bcf7c95ea5f
30471094	\\xdcf6c336ab92dd051c718a9c64e27318
30471095	\\x2cab76842a1e473f698de554e96aa381
30473163	\\x2e7e54010229cfb71162d317585630d1
30473164	\\x2a046c21393e272495c4db0c747775f2
30473166	\\x9fa6393b200a9dd4ec836028b1ffc176
30473168	\\xff569386e94ddd94fae22e42ca56fe57
30474769	\\x1d05b233a21563f2b67f72d591146341
30474770	\\x9b92d845d752f5344037d57cd82966bb
30474771	\\x5d84fdbf70da984085c8cbfcd464e5f1
30474772	\\xfd2468f365fd60de485ffb59bdfc7b82
30474773	\\xf26f81213c9cd6cc9fd2074c0a260409
30474774	\\xe90dd72c5783d604a537dd9395ea9ab5
30474781	\\xeb6c0b2f33335cfcf25ceaba19db823f
30474784	\\x0b816bf37a35d3486cb74c76098765e9
30474790	\\xa8863e4d711b197c121fb6ccb248dba4
30474791	\\x7baee1c1a85ba92d7191237520b3e46e
30474797	\\x981a178504d9e5d2b57400a453d6634b
30475715	\\x20ae32dff4473e4a34a95c2b32d48348
30475716	\\x0c1aeb700817c5b906651610adea7034
30475717	\\x5638ac2760b9424f032e82ce311b249a
30475718	\\x935a79243413c71e6bcc6cd3c75f9a3a
30475719	\\xaba04727413544387c4f6be5205c098b
30475720	\\xb11504dbd1d6888ac5ca7d3a1779a6cb
30475721	\\x7d2b820085bf9761b61e23da914de0ae
30475722	\\xd2344f33c03c03de73a182ab33cda265
30475723	\\x2ce7836d887be0772cb96f9287f5306b
30475724	\\xd771a1bca60cd13b033d4bf17655f40b
30475725	\\x20ef96f7d9b6e45e1b446365edeb266b
30475726	\\xb5d350129e1a1b62ff632595b6453194
30475727	\\x0a23c5f5836275db5e618a954f05e40a
30475728	\\xe2d572459fbe6be2a7b43081bc9e2e24
30475729	\\xba4bd4a13c88fef1d900d0fa778788cb
30532898	\\xa625287f9fe2ee34d71e77e7a438fa35
30532902	\\x4c3eaadefaff1e4719bd76f983542e05
30532903	\\xbf05a30c41311ab53ccd5b6eb4dea148
30532904	\\xf64ac581e565aa287b26c99e06554a5c
30532905	\\x35ac83f4ea95d6eaf9233f4bebd0f263
30532906	\\xee96f47c164ff2803e92c6c491944928
30532907	\\x990bc7129d9f4918a65e79b7b7f5f828
30532908	\\xe6333cee32bc81ef4866976b4b795d33
30532909	\\x2d67e478f0f78a41263c59a95c811e08
30532910	\\x151b802e0e47a95dd82dfbecd800d7bf
30532911	\\x19e427e8766beaa84766ffa870d9925b
30532912	\\x4f40c3f41df80ca8d659ed5340dbd013
30532913	\\x0502a27f909884fcbbb26ace745e77de
30532914	\\x004e63fec67bd882e64f56d92289ab39
30532915	\\x24c809ef5996d6142fb69751ebc9ffac
30532916	\\xd52dd17d5a9bde60981d15b297186760
30532917	\\x28ebf47701f6b1827d59a6182696a7cf
30532918	\\xe742faa5f8f3d3edf90585210380bd71
30532967	\\x4167d2da67113dd92e1bf2c6a7b84744
30532968	\\xe14964785baddabaeb356235416f9084
30532969	\\x3dc88eebe4429c01893e516632021d7e
30533122	\\xe27433f610d3710e228e69f812c46b1c
30533126	\\x649ba507bf0cb1a1eae83ee0f5cd7c92
30533127	\\x801c0613f0c8fd2bb7508cd383aacbb0
30533128	\\xcf10c6d2c1b81b90b9f1ca740ec29379
30533129	\\x2c509cfdb407996cf75b816b8e9149d2
30533130	\\x8c6d55e9bc78343eb413d0cd3c27ebc0
30533131	\\xb31886d36821f8edf845d56887d687e8
30533132	\\x92943bd2302396378e802265fd046cf4
30533133	\\x7257cf66f3b750af2cf7160165f893dc
30533134	\\x990d79674fc7a44512a8ee6d39328713
30533135	\\xf61f4872e647858424b87b0655c6c597
30533136	\\x5e3d938e3b4913174985dc3424782906
30533137	\\xe09cd6f4e5b9d17d8d8ff0b86745cfcb
30533138	\\x4e8f4fd7a013008e1a72a06cc6a3e757
30533139	\\xecb327070912d269dd1b8141d4461527
30533140	\\xe9006236138e9ff240b7d6f23fe44a38
30533141	\\xfc4b9fdcc87ce5a91baa6d90684aa9b3
30533142	\\xfda09a54ebc3d843c2e2a78ae8f6b23d
30533146	\\x1fd4a9a2fb10a94de06cce72fa32d921
30533147	\\x8850377eb9341cb671616ebc2984367b
30533148	\\x9acb31c8c4411b12b13aca7b3cf8d666
31585947	\\xdb428c92b54f04c93990bccd0c125a1e
31595674	\\x691fdf23f0588e77b0c65f14ee785ad2
31596086	\\x6cd5a530957e006af932cbe492447a51
31596087	\\xb472ac8b3bd739e4e2e47aeeea019b75
31596088	\\xf66efb5b867f2ae5d21f6158202fbb8c
31596089	\\x3b998ba70ed5e15648ddcfafb430789f
31596090	\\xef7af48df6c7fb5c266b2f07d8d59a6d
31596091	\\x81bb519961e4d015911cbfebd2bab866
31596092	\\xd975dd1994d4de8cc41cdc87e1d35152
31596093	\\xe56198feca4c1edd30cc2266f34fb791
31596094	\\x434948acd28df1b310b38a7599aea11c
31596196	\\x94a8ff5d6daf6647eba273ee65b8df91
31596198	\\x2243c8867622a74fab160cbc6ba6f811
31596200	\\xef99fc6c0a369ff707504ae21f1cd910
31596201	\\x79f2454cbd781726079657fb67a7f38e
31596203	\\xaadf07806d0ff0a41ed8efff72a809b9
31596204	\\xbb74e298bdcc7572ed41ca9d255f2c3d
31596205	\\x8bc8781381cca5a6922803efc8896e73
31596207	\\x8e3eb41f06c64d552c67be8ec12b654e
31596209	\\xb232328ba095b5aab1422e9f31b88cf8
31596211	\\x609aeb7d4d7d17fbd6c219301b67035d
31596213	\\x2cf6bc9720432951b7e9c70d75980e8a
31596215	\\x682f811d7ccbb98aedefda4dcc3640a7
31596217	\\xb85401da6653b906680d8df50309ec77
31596218	\\xc7e5a234eb77b63a9ab8a5251c89e1c9
31596219	\\xc535ef8119bc8b1ab81f12c7975714c1
31596220	\\xe80c9d2108bbe3238d010da7a4a251d7
31596221	\\xa9bdeadb6d269710a16ebaaa896edfc6
31596222	\\x8a1084ab774374bc017aa279d04acb63
31596223	\\x50e2f3c6e7123a9bc9dbe4e9141c9a3c
31596224	\\xdf685326f041a757e0e5f765721d9523
31596225	\\xcb4d7b3ebe3d76cbd16d9e1a556c45da
31596226	\\x34d5e131b306a268b1cf71cc00a0d8b6
31596227	\\x624ee65493cdf8ebdecacdc599d6b831
31596228	\\x793b2dbf553271ac420f31f90e512375
31596229	\\x625fed053ec1e94f0090081d791156bf
31596230	\\x3ed1c10a388437f9b258d57906e572f8
31596231	\\xc038d75619af55fa8264dfddcf3a5a13
31596256	\\x5490280b740033bd69c6ac33aa828582
31596257	\\x1332c8fd4c216b500be10c42b5c6198f
31596258	\\x106790757313037726d27360f0050ea9
31610255	\\xc8fc7fbaae08c63977e9feaa8e6a319c
31610256	\\xf4d76608d5029bdbe494346971712424
31610400	\\x4f4fc1d6be92b9107ef056cc24a1fc3e
31610507	\\x403afb1bf9019a8d919b78bb0e06aed6
31610508	\\xb7828b1ad0de10663291c262794e0213
31610509	\\xf7da5b5e0e308bf8e6ce78503d993b93
31610510	\\x9198e247b7610d3293a34fe8c2bc2232
31610511	\\x6c9572aa608bcd5261df51c10b436152
31610512	\\xc8ede830c46f6ee41b66c02ccfe95059
31610513	\\xf14cf79938d2b3623d9be13e1ef959d6
31610514	\\x28cb49a7ac327f53142a3dbcadfdaf17
31610515	\\xd5fdab99b871d2e580a74be545f80e1b
31611033	\\x49ab98692090003dde08dedafb269a97
31611034	\\x0eeb34014bf003885fee1100d7d1a55f
31611035	\\x8e7c52db65248215be0eab649b2b65ce
31611036	\\x51dd09ecd626d50bf750c083ac24e22e
31611037	\\x8438be88953392199ab68c6936ed0c33
31611038	\\xd25c456ebffd8f636f51dffb2bc8e3cd
31611039	\\x4fd1e963f9b0222dd6baa6ebeeceaeed
31611040	\\x918c567517faa4ef8faee35b98255e69
31611041	\\x84ecd91ec253ae65a78f271fd40c4697
31611042	\\x7a6526a6ce0bbc89597aa7ba86a874cf
31611043	\\x398a574fa67871b2686bc1a240717bd4
31611044	\\x9932d403a25750792cddbb50530dd116
31611045	\\xe4c1b128c1eb267ec6391ed06258715e
31611046	\\xa83327491327ceb6724f38fe579b2cf1
31611047	\\x2a4a396186167ebb26265b750c156b07
31611048	\\x1836b6e70b637b7df792cadde958001a
31611049	\\xfead96d6305946d4a541ad2fb6d7756c
31611050	\\x97dad6874b0faf77c7c624204bf07397
31611051	\\x7a45c666a90954d5ba70e00e73142ea7
31611052	\\x823e891a88e5aa37c3911388e8467812
31611053	\\x2287a57ed84c75bce2f0085453a5e1a0
31611054	\\x6dbeab543759f9f4bbfa8027daa4567e
31611055	\\xb47053a1a598b0d3d478af468faff0b6
31611056	\\x04cd489bcec6f906073d2fba496dc427
31611057	\\x1750d8e93cfb6a9b8b695e5dec68b443
31611058	\\x0a0143dc506e8c3f64c893f4e2395db1
31611062	\\x43aadbb570fe8c02bac04d2e191fc726
31611063	\\x432b3587e9a448a32ab9b940ea2b5425
31611064	\\xcc715a9a7f43469c479830e9f9551686
\.


--
-- Data for Name: tblmetadata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblmetadata (fkchannelid, epoch, sensor_info, raw_metadata) FROM stdin;
\.


--
-- Data for Name: tblmetric; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblmetric (pkmetricid, name, fkparentmetricid, legend, fkcomputetypeid, displayname) FROM stdin;
29	EventCompareSynthetic	\N	NULL::character varying	1	Event Compare Synthetic
28	EventCompareStrongMotion	\N	NULL::character varying	1	Event Compare Strong Motion
27	DifferencePBM:200-500	\N	NULL::character varying	1	Difference: 200-500
26	DifferencePBM:90-110	\N	NULL::character varying	1	Difference: 90-110
25	DifferencePBM:18-22	\N	NULL::character varying	1	Difference: 18-22
24	DifferencePBM:4-8	\N	NULL::character varying	1	Difference: 4-8
23	CoherencePBM:200-500	\N	NULL::character varying	1	Coherence: 200-500
22	StationDeviationMetric:200-500	\N	NULL::character varying	1	Station Deviation: 200-500
21	StationDeviationMetric:90-110	\N	NULL::character varying	1	Station Deviation: 90-110
20	StationDeviationMetric:18-22	\N	NULL::character varying	1	Station Deviation: 18-22
19	DeadChannelMetric:4-8	\N	NULL::character varying	1	Dead Channel: 4-8
18	StationDeviationMetric:4-8	\N	NULL::character varying	1	Station Deviation: 4-8
17	CoherencePBM:90-110	\N	NULL::character varying	1	Coherence: 90-110
16	NLNMDeviationMetric:200-500	\N	NULL::character varying	1	NLNM Deviation: 200-500
15	NLNMDeviationMetric:90-110	\N	NULL::character varying	1	NLNM Deviation: 90-110
14	CoherencePBM:18-22	\N	NULL::character varying	1	Coherence: 18-22
13	NLNMDeviationMetric:18-22	\N	NULL::character varying	1	NLNM Deviation: 18-22
12	NLNMDeviationMetric:4-8	\N	NULL::character varying	1	NLNM Deviation: 4-8
11	CoherencePBM:4-8	\N	NULL::character varying	1	Coherence: 4-8
10	NLNMDeviationMetric:0.125-0.25	\N	NULL::character varying	1	NLNM Deviation: 0.125-0.25
9	NLNMDeviationMetric:0.5-1	\N	NULL::character varying	1	NLNM Deviation: 0.5-1
8	VacuumMonitorMetric	\N	NULL::character varying	1	Vacuum Monitor
7	ALNMDeviationMetric:18-22	\N	NULL::character varying	1	ALNM Deviation: 18-22
6	ALNMDeviationMetric:4-8	\N	NULL::character varying	1	ALNM Deviation: 4-8
5	MassPositionMetric	\N	NULL::character varying	1	Mass Position
4	TimingQualityMetric	\N	NULL::character varying	1	Timing Quality
2	AvailabilityMetric	\N	NULL::character varying	1	Availability
3	GapCountMetric	\N	NULL::character varying	3	Gap Count
32	PressureMetric	\N	NULL::character varying	1	Pressure Metric
30	EventComparePWaveOrientation	\N	NULL::character varying	1	Event Compare PWave Orientation
31	InfrasoundMetric	\N	NULL::character varying	1	Infrasound Metric
\.


--
-- Data for Name: tblmetricdata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblmetricdata (fkchannelid, date, fkmetricid, value, "fkHashID") FROM stdin;
3353	2458854	2	99.99768521197672	30454542
3354	2458854	2	99.97685453072562	30454543
3355	2458854	2	99.99997106482319	30454544
3356	2458854	2	99.97685453072562	30454545
3357	2458854	2	100	30454546
3358	2458854	2	99.97685453072562	30454547
3359	2458854	2	99.99884260598836	30454548
3360	2458854	2	99.99884260598836	30454549
3361	2458854	2	99.99997106482319	30454550
3362	2458854	2	99.9884272653628	30454551
3363	2458854	2	99.9884272653628	30454552
3364	2458854	2	99.99884260598836	30454553
3365	2458854	2	99.9884272653628	30454554
3366	2458854	2	99.99768521197672	30454555
3367	2458854	2	99.99768521197672	30454556
3368	2458854	2	99.99884260598836	30457237
3369	2458854	2	99.99884260598836	30457238
3370	2458854	2	99.99884260598836	30457239
3371	2458854	2	99.99884260598836	30457240
3372	2458854	2	99.99884260598836	30457241
3373	2458854	2	99.9884272653628	30452604
3374	2458854	2	99.9884272653628	30457242
3375	2458854	2	99.99997106482319	30457243
3376	2458854	2	99.9884272653628	30457244
3377	2458854	2	99.99997106482319	30457245
3378	2458854	2	100	30457246
3379	2458854	2	99.9884272653628	30457247
3380	2458854	2	99.97685453072562	30457248
3381	2458854	2	99.97685453072562	30457249
3382	2458854	2	99.99997106482319	30457250
3383	2458854	2	99.97685453072562	30457251
3384	2458854	2	99.99997106482319	30457252
3385	2458854	2	99.99997106482319	30457253
3386	2458854	2	100	30457254
3387	2458854	2	99.9884272653628	30457255
3388	2458854	2	99.9884272653628	30457256
3389	2458854	2	99.99997106482319	30457257
3390	2458854	2	99.9884272653628	30457258
3391	2458854	2	100	30457259
3392	2458854	2	100	30457260
3393	2458854	2	99.99884260598836	30457261
3394	2458854	2	99.99884260598836	30457262
3395	2458854	2	100	30457263
3574	2458854	2	99.99997106482319	31596205
3575	2458854	2	99.99997106482319	31596209
3579	2458854	2	99.99997106482319	31596225
3580	2458854	2	99.99947916681737	30455812
3581	2458854	2	99.99884260598836	30455813
3582	2458854	2	99.99984953705444	30455814
3583	2458854	2	99.99884260598836	30455815
3584	2458854	2	99.99884260598836	30455816
3585	2458854	2	99.99884260598836	30455817
3586	2458854	2	99.9884272653628	31585947
3587	2458854	2	99.9884272653628	31596215
3588	2458854	2	99.9884272653628	31596222
3589	2458854	2	99.9884272653628	31596218
3590	2458854	2	99.9884272653628	31596223
3591	2458854	2	99.9884272653628	31596224
3592	2458854	2	99.99884260598836	30455823
3593	2458854	2	99.99884260598836	31596229
3594	2458854	2	99.99884260598836	31596230
3595	2458854	2	99.99884260598836	30455826
3596	2458854	2	99.99884260598836	31596221
3597	2458854	2	99.99884260598836	31596231
3599	2458854	2	99.99884260598836	31596201
3600	2458854	2	99.99997106482319	31596217
3601	2458854	2	99.99997106482319	31596219
3602	2458854	2	99.99884260598836	30455832
3603	2458854	2	99.99884260598836	30455833
3604	2458854	2	99.99997106482319	31596220
3606	2458854	2	99.9884272653628	31596211
3607	2458854	2	99.9884272653628	31596213
3608	2458854	2	99.9884272653628	31596226
3609	2458854	2	99.99884260598836	30455841
3610	2458854	2	99.99884260598836	31596227
3611	2458854	2	99.99884260598836	31596228
3612	2458854	2	99.99884260598836	30452149
3613	2458854	2	99.99884260598836	31596198
3614	2458854	2	99.99884260598836	30452149
3615	2458854	2	99.99884260598836	31596200
3616	2458854	2	99.99884260598836	31596196
3734	2458854	2	99.97685453072562	31596086
3735	2458854	2	99.97685453072562	31596087
3736	2458854	2	99.99884260598836	30532898
3737	2458854	2	99.99884260598836	31596088
3738	2458854	2	99.99884260598836	31596089
3739	2458854	2	99.9884272653628	30458185
3740	2458854	2	99.9884272653628	30458186
3741	2458854	2	99.97685453072562	31596090
3742	2458854	2	99.99884260598836	30458188
3743	2458854	2	99.99884260598836	31596091
3744	2458854	2	99.9884272653628	30458190
3745	2458854	2	99.99994212966313	30532902
3746	2458854	2	99.99994212966313	30532903
3747	2458854	2	99.9884272653628	30532904
3748	2458854	2	99.9884272653628	30532905
3749	2458854	2	99.9884272653628	31596092
3750	2458854	2	99.9884272653628	31596093
3751	2458854	2	99.99997106482319	30532906
3752	2458854	2	99.9884272653628	31595674
3753	2458854	2	99.99892939845793	30532907
3754	2458854	2	99.9994212966312	30532908
3755	2458854	2	99.9884272653628	30532909
3756	2458854	2	99.9884272653628	30532910
3757	2458854	2	99.9884272653628	30532911
3758	2458854	2	99.99997106482319	30532912
3759	2458854	2	99.9884272653628	30532913
3760	2458854	2	99.99884260598836	30532914
3761	2458854	2	99.99884260598836	31596094
3762	2458854	2	99.99884260598836	30532915
3763	2458854	2	99.99884260598836	30532916
3764	2458854	2	99.99884260598836	30532917
3765	2458854	2	99.99884260598836	30532918
11787	2458854	2	99.97685453072562	31596203
11788	2458854	2	99.97685453072562	31596204
11789	2458854	2	99.97685453072562	31596207
3353	2458855	2	99.99884260598836	30475715
3354	2458855	2	99.9884272653628	30475716
3355	2458855	2	99.99997106482319	30475717
3356	2458855	2	99.9884272653628	30475718
3357	2458855	2	99.99994212964637	30475719
3358	2458855	2	99.9884272653628	30475720
3359	2458855	2	99.99884260598836	30475721
3360	2458855	2	99.99884260598836	30475722
3361	2458855	2	99.99997106482319	30475723
3362	2458855	2	99.9884272653628	30475724
3363	2458855	2	99.9884272653628	30475725
3364	2458855	2	99.99884260598836	30475726
3365	2458855	2	99.9884272653628	30475727
3366	2458855	2	99.99884260598836	30475728
3367	2458855	2	99.99884260598836	30475729
3368	2458855	2	99.99884260598836	30470978
3369	2458855	2	99.99884260598836	30470979
3370	2458855	2	99.99884260598836	30470980
3371	2458855	2	99.99884260598836	30470981
3372	2458855	2	99.99884260598836	30470982
3373	2458855	2	99.9884272653628	30469406
3374	2458855	2	99.9884272653628	30470983
3375	2458855	2	99.99997106482319	30470984
3376	2458855	2	99.9884272653628	30470985
3377	2458855	2	99.99997106482319	30470986
3378	2458855	2	99.97685453072562	30470987
3379	2458855	2	99.9884272653628	30470988
3380	2458855	2	99.9884272653628	30470989
3381	2458855	2	99.9884272653628	30470990
3382	2458855	2	99.99997106482319	30470991
3383	2458855	2	99.9884272653628	30470992
3384	2458855	2	99.99997106482319	30470993
3385	2458855	2	99.99997106482319	30470994
3386	2458855	2	99.97685453072562	30470995
3387	2458855	2	99.9884272653628	30470996
3388	2458855	2	99.9884272653628	30470997
3389	2458855	2	99.99907407434199	30470998
3390	2458855	2	99.9884272653628	30470999
3391	2458855	2	99.99768521197672	30471000
3392	2458855	2	99.99768521197672	30471001
3393	2458855	2	99.99884260598836	30471002
3394	2458855	2	99.99884260598836	30471003
3395	2458855	2	99.99768521197672	30471004
3574	2458855	2	99.99997106482319	31611037
3575	2458855	2	99.99997106482319	31611039
3579	2458855	2	99.99997106482319	31611052
3580	2458855	2	99.99997106482319	30474769
3581	2458855	2	99.99884260598836	30474770
3582	2458855	2	99.99883101865382	30474771
3583	2458855	2	99.99884260598836	30474772
3584	2458855	2	99.99884260598836	30474773
3585	2458855	2	99.99884260598836	30474774
3586	2458855	2	100	31611042
3587	2458855	2	100	31611043
3588	2458855	2	99.9884272653628	31611049
3589	2458855	2	100	31611045
3590	2458855	2	99.9884272653628	31611050
3591	2458855	2	99.9884272653628	31611051
3592	2458855	2	99.99884260598836	30474781
3593	2458855	2	99.99884260598836	31611056
3594	2458855	2	99.99884260598836	31611057
3595	2458855	2	99.99884260598836	30474784
3596	2458855	2	99.99884260598836	31611048
3597	2458855	2	99.99884260598836	31611058
3599	2458855	2	99.99884260598836	31611036
3600	2458855	2	99.99997106482319	31611044
3601	2458855	2	99.99997106482319	31611046
3602	2458855	2	99.99884260598836	30474790
3603	2458855	2	99.99884260598836	30474791
3604	2458855	2	99.99997106482319	31611047
3606	2458855	2	99.9884272653628	31611040
3607	2458855	2	99.9884272653628	31611041
3608	2458855	2	99.9884272653628	31611053
3609	2458855	2	99.99884260598836	30474797
3610	2458855	2	99.99884260598836	31611054
3611	2458855	2	99.99884260598836	31611055
3612	2458855	2	99.99884260598836	30471039
3613	2458855	2	99.99884260598836	31611034
3614	2458855	2	99.99884260598836	30471039
3615	2458855	2	99.99884260598836	31611035
3616	2458855	2	99.99884260598836	31611033
3734	2458855	2	99.9884272653628	31610507
3735	2458855	2	99.9884272653628	31610508
3736	2458855	2	99.99884260598836	30533122
3737	2458855	2	99.99884260598836	31610509
3738	2458855	2	99.99884260598836	31610510
3739	2458855	2	99.9884272653628	30473163
3740	2458855	2	99.9884272653628	30473164
3741	2458855	2	99.9884272653628	31610511
3742	2458855	2	99.99884260598836	30473166
3743	2458855	2	99.99884260598836	31610512
3744	2458855	2	99.9884272653628	30473168
3745	2458855	2	99.99994212966313	30533126
3746	2458855	2	99.99994212966313	30533127
3747	2458855	2	99.9884272653628	30533128
3748	2458855	2	99.9884272653628	30533129
3749	2458855	2	99.9884272653628	31610513
3750	2458855	2	99.9884272653628	31610514
3751	2458855	2	99.99997106482319	30533130
3752	2458855	2	99.9884272653628	31610400
3753	2458855	2	99.99997106482319	30533131
3754	2458855	2	99.99994212966313	30533132
3755	2458855	2	99.9884272653628	30533133
3756	2458855	2	99.9884272653628	30533134
3757	2458855	2	99.9884272653628	30533135
3758	2458855	2	99.99997106482319	30533136
3759	2458855	2	99.9884272653628	30533137
3760	2458855	2	99.99884260598836	30533138
3761	2458855	2	99.99884260598836	31610515
3762	2458855	2	99.99884260598836	30533139
3763	2458855	2	99.99884260598836	30533140
3764	2458855	2	99.99884260598836	30533141
3765	2458855	2	99.99884260598836	30533142
11787	2458855	2	99.9884272653628	31610256
11788	2458855	2	99.9884272653628	31610255
11789	2458855	2	99.9884272653628	31611038
3353	2458854	3	1	30454542
3354	2458854	3	1	30454543
3355	2458854	3	0	30454544
3356	2458854	3	1	30454545
3357	2458854	3	0	30454546
3358	2458854	3	1	30454547
3359	2458854	3	0	30454548
3360	2458854	3	0	30454549
3361	2458854	3	0	30454550
3362	2458854	3	0	30454551
3363	2458854	3	0	30454552
3364	2458854	3	0	30454553
3365	2458854	3	0	30454554
3366	2458854	3	1	30454555
3367	2458854	3	1	30454556
3368	2458854	3	0	30457237
3369	2458854	3	0	30457238
3370	2458854	3	0	30457239
3371	2458854	3	0	30457240
3372	2458854	3	0	30457241
3373	2458854	3	0	30452604
3374	2458854	3	0	30457242
3375	2458854	3	0	30457243
3376	2458854	3	0	30457244
3377	2458854	3	0	30457245
3378	2458854	3	0	30457246
3379	2458854	3	0	30457247
3380	2458854	3	1	30457248
3381	2458854	3	1	30457249
3382	2458854	3	0	30457250
3383	2458854	3	1	30457251
3384	2458854	3	0	30457252
3385	2458854	3	0	30457253
3386	2458854	3	0	30457254
3387	2458854	3	0	30457255
3388	2458854	3	0	30457256
3389	2458854	3	0	30457257
3390	2458854	3	0	30457258
3391	2458854	3	0	30457259
3392	2458854	3	0	30457260
3393	2458854	3	0	30457261
3394	2458854	3	0	30457262
3395	2458854	3	0	30457263
3574	2458854	3	0	31596205
3575	2458854	3	0	31596209
3579	2458854	3	0	31596225
3580	2458854	3	1	30455812
3581	2458854	3	0	30455813
3582	2458854	3	1	30455814
3583	2458854	3	0	30455815
3584	2458854	3	0	30455816
3585	2458854	3	0	30455817
3586	2458854	3	0	31585947
3587	2458854	3	0	31596215
3588	2458854	3	0	31596222
3589	2458854	3	0	31596218
3590	2458854	3	0	31596223
3591	2458854	3	0	31596224
3592	2458854	3	0	30455823
3593	2458854	3	0	31596229
3594	2458854	3	0	31596230
3595	2458854	3	0	30455826
3596	2458854	3	0	31596221
3597	2458854	3	0	31596231
3599	2458854	3	0	31596201
3600	2458854	3	0	31596217
3601	2458854	3	0	31596219
3602	2458854	3	0	30455832
3603	2458854	3	0	30455833
3604	2458854	3	0	31596220
3606	2458854	3	0	31596211
3607	2458854	3	0	31596213
3608	2458854	3	0	31596226
3609	2458854	3	0	30455841
3610	2458854	3	0	31596227
3611	2458854	3	0	31596228
3612	2458854	3	0	30452149
3613	2458854	3	0	31596198
3614	2458854	3	0	30452149
3615	2458854	3	0	31596200
3616	2458854	3	0	31596196
3734	2458854	3	1	31596086
3735	2458854	3	1	31596087
3736	2458854	3	0	30532898
3737	2458854	3	0	31596088
3738	2458854	3	0	31596089
3739	2458854	3	0	30458185
3740	2458854	3	0	30458186
3741	2458854	3	1	31596090
3742	2458854	3	0	30458188
3743	2458854	3	0	31596091
3744	2458854	3	0	30458190
3745	2458854	3	0	30532902
3746	2458854	3	0	30532903
3747	2458854	3	0	30532904
3748	2458854	3	0	30532905
3749	2458854	3	0	31596092
3750	2458854	3	0	31596093
3751	2458854	3	0	30532906
3752	2458854	3	0	31595674
3753	2458854	3	1	30532907
3754	2458854	3	1	30532908
3755	2458854	3	0	30532909
3756	2458854	3	0	30532910
3757	2458854	3	0	30532911
3758	2458854	3	0	30532912
3759	2458854	3	0	30532913
3760	2458854	3	0	30532914
3761	2458854	3	0	31596094
3762	2458854	3	0	30532915
3763	2458854	3	0	30532916
3764	2458854	3	0	30532917
3765	2458854	3	0	30532918
11787	2458854	3	1	31596203
11788	2458854	3	1	31596204
11789	2458854	3	1	31596207
3353	2458855	3	0	30475715
3354	2458855	3	0	30475716
3355	2458855	3	0	30475717
3356	2458855	3	0	30475718
3357	2458855	3	1	30475719
3358	2458855	3	0	30475720
3359	2458855	3	0	30475721
3360	2458855	3	0	30475722
3361	2458855	3	0	30475723
3362	2458855	3	0	30475724
3363	2458855	3	0	30475725
3364	2458855	3	0	30475726
3365	2458855	3	0	30475727
3366	2458855	3	0	30475728
3367	2458855	3	0	30475729
3368	2458855	3	0	30470978
3369	2458855	3	0	30470979
3370	2458855	3	0	30470980
3371	2458855	3	0	30470981
3372	2458855	3	0	30470982
3373	2458855	3	0	30469406
3374	2458855	3	0	30470983
3375	2458855	3	0	30470984
3376	2458855	3	0	30470985
3377	2458855	3	0	30470986
3378	2458855	3	1	30470987
3379	2458855	3	0	30470988
3380	2458855	3	0	30470989
3381	2458855	3	0	30470990
3382	2458855	3	0	30470991
3383	2458855	3	0	30470992
3384	2458855	3	0	30470993
3385	2458855	3	0	30470994
3386	2458855	3	1	30470995
3387	2458855	3	0	30470996
3388	2458855	3	0	30470997
3389	2458855	3	1	30470998
3390	2458855	3	0	30470999
3391	2458855	3	1	30471000
3392	2458855	3	1	30471001
3393	2458855	3	0	30471002
3394	2458855	3	0	30471003
3395	2458855	3	1	30471004
3574	2458855	3	0	31611037
3575	2458855	3	0	31611039
3579	2458855	3	0	31611052
3580	2458855	3	0	30474769
3581	2458855	3	0	30474770
3582	2458855	3	1	30474771
3583	2458855	3	0	30474772
3584	2458855	3	0	30474773
3585	2458855	3	0	30474774
3586	2458855	3	0	31611042
3587	2458855	3	0	31611043
3588	2458855	3	0	31611049
3589	2458855	3	0	31611045
3590	2458855	3	0	31611050
3591	2458855	3	0	31611051
3592	2458855	3	0	30474781
3593	2458855	3	0	31611056
3594	2458855	3	0	31611057
3595	2458855	3	0	30474784
3596	2458855	3	0	31611048
3597	2458855	3	0	31611058
3599	2458855	3	0	31611036
3600	2458855	3	0	31611044
3601	2458855	3	0	31611046
3602	2458855	3	0	30474790
3603	2458855	3	0	30474791
3604	2458855	3	0	31611047
3606	2458855	3	0	31611040
3607	2458855	3	0	31611041
3608	2458855	3	0	31611053
3609	2458855	3	0	30474797
3610	2458855	3	0	31611054
3611	2458855	3	0	31611055
3612	2458855	3	0	30471039
3613	2458855	3	0	31611034
3614	2458855	3	0	30471039
3615	2458855	3	0	31611035
3616	2458855	3	0	31611033
3734	2458855	3	0	31610507
3735	2458855	3	0	31610508
3736	2458855	3	0	30533122
3737	2458855	3	0	31610509
3738	2458855	3	0	31610510
3739	2458855	3	0	30473163
3740	2458855	3	0	30473164
3741	2458855	3	0	31610511
3742	2458855	3	0	30473166
3743	2458855	3	0	31610512
3744	2458855	3	0	30473168
3745	2458855	3	0	30533126
3746	2458855	3	0	30533127
3747	2458855	3	0	30533128
3748	2458855	3	0	30533129
3749	2458855	3	0	31610513
3750	2458855	3	0	31610514
3751	2458855	3	0	30533130
3752	2458855	3	0	31610400
3753	2458855	3	0	30533131
3754	2458855	3	0	30533132
3755	2458855	3	0	30533133
3756	2458855	3	0	30533134
3757	2458855	3	0	30533135
3758	2458855	3	0	30533136
3759	2458855	3	0	30533137
3760	2458855	3	0	30533138
3761	2458855	3	0	31610515
3762	2458855	3	0	30533139
3763	2458855	3	0	30533140
3764	2458855	3	0	30533141
3765	2458855	3	0	30533142
11787	2458855	3	0	31610256
11788	2458855	3	0	31610255
11789	2458855	3	0	31611038
3353	2458854	4	100	30454542
3354	2458854	4	100	30454543
3355	2458854	4	99.93709726910095	30454544
3356	2458854	4	100	30454545
3357	2458854	4	99.93722536095417	30454546
3358	2458854	4	100	30454547
3359	2458854	4	100	30454548
3360	2458854	4	100	30454549
3361	2458854	4	99.93748883729238	30454550
3362	2458854	4	100	30454551
3363	2458854	4	100	30454552
3364	2458854	4	100	30454553
3365	2458854	4	100	30454554
3366	2458854	4	100	30454555
3367	2458854	4	100	30454556
3368	2458854	4	100	30457237
3369	2458854	4	100	30457238
3370	2458854	4	100	30457239
3371	2458854	4	100	30457240
3372	2458854	4	100	30457241
3373	2458854	4	100	30452604
3374	2458854	4	100	30457242
3375	2458854	4	99.86842105263158	30457243
3376	2458854	4	100	30457244
3377	2458854	4	99.86476608187135	30457245
3378	2458854	4	100	30457246
3379	2458854	4	100	30457247
3380	2458854	4	100	30457248
3381	2458854	4	100	30457249
3382	2458854	4	99.952	30457250
3383	2458854	4	100	30457251
3384	2458854	4	99.95235308869013	30457252
3385	2458854	4	99.86429326753613	30457253
3386	2458854	4	100	30457254
3387	2458854	4	100	30457255
3388	2458854	4	100	30457256
3389	2458854	4	99.94939759036144	30457257
3390	2458854	4	100	30457258
3391	2458854	4	100	30457259
3392	2458854	4	100	30457260
3393	2458854	4	100	30457261
3394	2458854	4	100	30457262
3395	2458854	4	100	30457263
3574	2458854	4	99.97615397717595	31596205
3575	2458854	4	99.97638326585695	31596209
3579	2458854	4	99.97941409342835	31596225
3580	2458854	4	99.8609047137847	30455812
3581	2458854	4	100	30455813
3582	2458854	4	99.85597832545096	30455814
3583	2458854	4	100	30455815
3584	2458854	4	100	30455816
3585	2458854	4	100	30455817
3586	2458854	4	100	31585947
3587	2458854	4	100	31596215
3588	2458854	4	100	31596222
3589	2458854	4	100	31596218
3590	2458854	4	100	31596223
3591	2458854	4	100	31596224
3592	2458854	4	100	30455823
3593	2458854	4	100	31596229
3594	2458854	4	100	31596230
3595	2458854	4	100	30455826
3596	2458854	4	100	31596221
3597	2458854	4	100	31596231
3599	2458854	4	100	31596201
3600	2458854	4	99.97908622908623	31596217
3601	2458854	4	99.9788755281118	31596219
3602	2458854	4	100	30455832
3603	2458854	4	100	30455833
3604	2458854	4	99.98074454428755	31596220
3606	2458854	4	100	31596211
3607	2458854	4	100	31596213
3608	2458854	4	100	31596226
3609	2458854	4	100	30455841
3610	2458854	4	100	31596227
3611	2458854	4	100	31596228
3612	2458854	4	100	30452149
3613	2458854	4	100	31596198
3614	2458854	4	100	30452149
3615	2458854	4	100	31596200
3616	2458854	4	100	31596196
3734	2458854	4	100	31596086
3735	2458854	4	100	31596087
3736	2458854	4	100	30532898
3737	2458854	4	100	31596088
3738	2458854	4	100	31596089
3739	2458854	4	100	30458185
3740	2458854	4	100	30458186
3741	2458854	4	100	31596090
3742	2458854	4	100	30458188
3743	2458854	4	100	31596091
3744	2458854	4	100	30458190
3745	2458854	4	99.900395256917	30532902
3746	2458854	4	99.89174560216509	30532903
3747	2458854	4	100	30532904
3748	2458854	4	100	30532905
3749	2458854	4	100	31596092
3750	2458854	4	100	31596093
3751	2458854	4	99.89310105909136	30532906
3752	2458854	4	100	31595674
3753	2458854	4	99.8904970481813	30532907
3754	2458854	4	99.89570467956635	30532908
3755	2458854	4	100	30532909
3756	2458854	4	100	30532910
3757	2458854	4	100	30532911
3758	2458854	4	99.89205285687697	30532912
3759	2458854	4	100	30532913
3760	2458854	4	100	30532914
3761	2458854	4	100	31596094
3762	2458854	4	100	30532915
3763	2458854	4	100	30532916
3764	2458854	4	100	30532917
3765	2458854	4	100	30532918
11787	2458854	4	100	31596203
11788	2458854	4	100	31596204
11789	2458854	4	100	31596207
3353	2458855	4	100	30475715
3354	2458855	4	100	30475716
3355	2458855	4	99.93816254416961	30475717
3356	2458855	4	100	30475718
3357	2458855	4	99.93624772313296	30475719
3358	2458855	4	100	30475720
3359	2458855	4	100	30475721
3360	2458855	4	100	30475722
3361	2458855	4	99.93748944078392	30475723
3362	2458855	4	100	30475724
3363	2458855	4	100	30475725
3364	2458855	4	100	30475726
3365	2458855	4	100	30475727
3366	2458855	4	100	30475728
3367	2458855	4	100	30475729
3368	2458855	4	100	30470978
3369	2458855	4	100	30470979
3370	2458855	4	100	30470980
3371	2458855	4	100	30470981
3372	2458855	4	100	30470982
3373	2458855	4	100	30469406
3374	2458855	4	100	30470983
3375	2458855	4	99.84959835925483	30470984
3376	2458855	4	100	30470985
3377	2458855	4	99.84617985125085	30470986
3378	2458855	4	100	30470987
3379	2458855	4	100	30470988
3380	2458855	4	100	30470989
3381	2458855	4	100	30470990
3382	2458855	4	99.97354297376975	30470991
3383	2458855	4	100	30470992
3384	2458855	4	99.97359154929578	30470993
3385	2458855	4	99.8464875688303	30470994
3386	2458855	4	100	30470995
3387	2458855	4	100	30470996
3388	2458855	4	100	30470997
3389	2458855	4	99.97305171158048	30470998
3390	2458855	4	100	30470999
3391	2458855	4	100	30471000
3392	2458855	4	100	30471001
3393	2458855	4	99.98333333333333	30471002
3394	2458855	4	100	30471003
3395	2458855	4	100	30471004
3574	2458855	4	99.89739663093415	31611037
3575	2458855	4	99.89408382508701	31611039
3579	2458855	4	99.89142538975501	31611052
3580	2458855	4	99.87624309392265	30474769
3581	2458855	4	100	30474770
3582	2458855	4	99.8801722952848	30474771
3583	2458855	4	100	30474772
3584	2458855	4	100	30474773
3585	2458855	4	100	30474774
3586	2458855	4	100	31611042
3587	2458855	4	100	31611043
3588	2458855	4	100	31611049
3589	2458855	4	100	31611045
3590	2458855	4	100	31611050
3591	2458855	4	100	31611051
3592	2458855	4	100	30474781
3593	2458855	4	100	31611056
3594	2458855	4	100	31611057
3595	2458855	4	100	30474784
3596	2458855	4	100	31611048
3597	2458855	4	100	31611058
3599	2458855	4	100	31611036
3600	2458855	4	99.89667049368542	31611044
3601	2458855	4	99.89244186046511	31611046
3602	2458855	4	100	30474790
3603	2458855	4	100	30474791
3604	2458855	4	99.89110187705975	31611047
3606	2458855	4	100	31611040
3607	2458855	4	100	31611041
3608	2458855	4	100	31611053
3609	2458855	4	100	30474797
3610	2458855	4	100	31611054
3611	2458855	4	100	31611055
3612	2458855	4	100	30471039
3613	2458855	4	100	31611034
3614	2458855	4	100	30471039
3615	2458855	4	100	31611035
3616	2458855	4	100	31611033
3734	2458855	4	100	31610507
3735	2458855	4	100	31610508
3736	2458855	4	100	30533122
3737	2458855	4	100	31610509
3738	2458855	4	100	31610510
3739	2458855	4	100	30473163
3740	2458855	4	100	30473164
3741	2458855	4	100	31610511
3742	2458855	4	100	30473166
3743	2458855	4	100	31610512
3744	2458855	4	100	30473168
3745	2458855	4	99.89505012531329	30533126
3746	2458855	4	99.89606206997512	30533127
3747	2458855	4	100	30533128
3748	2458855	4	100	30533129
3749	2458855	4	100	31610513
3750	2458855	4	100	31610514
3751	2458855	4	99.88690007867821	30533130
3752	2458855	4	100	31610400
3753	2458855	4	99.88883699205978	30533131
3754	2458855	4	99.89250238127636	30533132
3755	2458855	4	100	30533133
3756	2458855	4	100	30533134
3757	2458855	4	100	30533135
3758	2458855	4	99.88959425890147	30533136
3759	2458855	4	100	30533137
3760	2458855	4	100	30533138
3761	2458855	4	100	31610515
3762	2458855	4	100	30533139
3763	2458855	4	100	30533140
3764	2458855	4	100	30533141
3765	2458855	4	100	30533142
11787	2458855	4	100	31610256
11788	2458855	4	100	31610255
11789	2458855	4	100	31611038
3354	2458854	5	4.641643537428937	30454543
3356	2458854	5	16.868385337418793	30454545
3358	2458854	5	24.679421612757668	30454547
3373	2458854	5	6.999999999999224	30452604
3374	2458854	5	7.99978298316793	30457242
3376	2458854	5	11.998668907656437	30457244
3380	2458854	5	12.004098925678871	30457248
3381	2458854	5	4.999374888577234	30457249
3383	2458854	5	23.000946144801052	30457251
3586	2458854	5	1.0000000000000422	31585947
3587	2458854	5	3.999898725569957	31596215
3589	2458854	5	1.985800286478495	31596218
3734	2458854	5	3.2400934879812233	31596086
3735	2458854	5	3.93392291587492	31596087
3741	2458854	5	2.004624818292443	31596090
3749	2458854	5	1.1416970798869372	31596092
3750	2458854	5	7.999891492320023	31596093
3752	2458854	5	2.0000000000000844	31595674
11787	2458854	5	1.0000000000000422	31596203
11788	2458854	5	6.999999999999224	31596204
11789	2458854	5	6.000000000000121	31596207
3354	2458855	5	6.158750549691885	30475716
3356	2458855	5	16.224959339104068	30475718
3358	2458855	5	23.36569927859741	30475720
3373	2458855	5	6.999999999999224	30469406
3374	2458855	5	8.045983297411698	30470983
3376	2458855	5	11.998779837658423	30470985
3380	2458855	5	12.46074855815802	30470989
3381	2458855	5	5	30470990
3383	2458855	5	23.359645382742478	30470992
3586	2458855	5	1.0000000000000422	31611042
3587	2458855	5	3.9998987372903265	31611043
3589	2458855	5	1.9832652491510168	31611045
3734	2458855	5	3.185470486792005	31610507
3735	2458855	5	3.8811629604960616	31610508
3741	2458855	5	2.0200098551282215	31610511
3749	2458855	5	1.592517224745472	31610513
3750	2458855	5	7.999891492320023	31610514
3752	2458855	5	2.0000000000000844	31610400
11787	2458855	5	1.0000000000000422	31610256
11788	2458855	5	6.999999999999224	31610255
11789	2458855	5	6.000000000000121	31611038
3353	2458854	6	13.832064835658668	30454542
3366	2458854	6	13.347460571448394	30454555
3367	2458854	6	12.858933675314162	30454556
3369	2458854	6	12.844449108702403	30457238
3370	2458854	6	13.949326740809772	30457239
3372	2458854	6	13.629384063137602	30457241
3599	2458854	6	14.175489399109535	31596201
3613	2458854	6	12.767791627381317	31596198
3615	2458854	6	11.469557451644082	31596200
3737	2458854	6	9.798967248504164	31596088
3738	2458854	6	9.722860216569346	31596089
3743	2458854	6	9.93449166649809	31596091
3353	2458855	6	14.828419581739217	30475715
3366	2458855	6	15.168567444291138	30475728
3367	2458855	6	14.865056843881552	30475729
3369	2458855	6	15.630769920099054	30470979
3370	2458855	6	16.843228190886293	30470980
3372	2458855	6	16.95163211724578	30470982
3599	2458855	6	16.564462576486722	31611036
3613	2458855	6	16.169308687931593	31611034
3615	2458855	6	15.755890179432544	31611035
3737	2458855	6	10.06061040662722	31610509
3738	2458855	6	9.78474833247554	31610510
3743	2458855	6	9.497913394006698	31610512
3353	2458854	7	10.829205257423219	30454542
3366	2458854	7	11.14324850348494	30454555
3367	2458854	7	10.608336897139331	30454556
3369	2458854	7	12.185135541666305	30457238
3370	2458854	7	14.769292070782534	30457239
3372	2458854	7	13.20162670181589	30457241
3599	2458854	7	10.422370223577332	31596201
3613	2458854	7	11.092444240842703	31596198
3615	2458854	7	8.995302092946162	31596200
3737	2458854	7	7.642030930663488	31596088
3738	2458854	7	8.64347375202285	31596089
3743	2458854	7	8.469980827243148	31596091
3353	2458855	7	10.72551322097685	30475715
3366	2458855	7	9.234086607362045	30475728
3367	2458855	7	10.670957665166299	30475729
3369	2458855	7	12.25958022268339	30470979
3370	2458855	7	12.88450557231652	30470980
3372	2458855	7	13.230800191450541	30470982
3599	2458855	7	9.065609460280044	31611036
3613	2458855	7	10.78317427185474	31611034
3615	2458855	7	9.678184094783397	31611035
3737	2458855	7	8.176525163325422	31610509
3738	2458855	7	10.152765565980296	31610510
3743	2458855	7	8.401624387435334	31610512
3739	2458854	8	9.506145416654185	30458185
3740	2458854	8	13.972091304045138	30458186
3744	2458854	8	11.828228324859298	30458190
3739	2458855	8	9.579336415602317	30473163
3740	2458855	8	14.044600585716434	30473164
3744	2458855	8	11.900355168920083	30473168
3355	2458854	9	13.491798446577873	30454544
3357	2458854	9	15.299903038176552	30454546
3361	2458854	9	15.820450671981016	30454550
3375	2458854	9	35.11907615807291	30457243
3377	2458854	9	27.157470557446143	30457245
3382	2458854	9	35.15378636804033	30457250
3384	2458854	9	26.989572641105628	30457252
3385	2458854	9	30.508691880093302	30457253
3389	2458854	9	30.526614214623642	30457257
3574	2458854	9	11.567050042005897	31596205
3575	2458854	9	15.922605469226129	31596209
3579	2458854	9	16.2651328066452	31596225
3600	2458854	9	16.36497361791509	31596217
3601	2458854	9	12.117139979035038	31596219
3604	2458854	9	15.940794015989333	31596220
3745	2458854	9	37.52775928117367	30532902
3746	2458854	9	36.331734524549134	30532903
3751	2458854	9	37.51803164969984	30532906
3753	2458854	9	36.38875601613316	30532907
3754	2458854	9	36.65271084189657	30532908
3758	2458854	9	36.7086010435932	30532912
3355	2458855	9	14.276040377107257	30475717
3357	2458855	9	15.665083611347193	30475719
3361	2458855	9	15.604805547392974	30475723
3375	2458855	9	14.788040677709088	30470984
3377	2458855	9	14.820557281061873	30470986
3382	2458855	9	14.707697539695273	30470991
3384	2458855	9	14.647632333754498	30470993
3385	2458855	9	16.028719531693323	30470994
3389	2458855	9	15.940704506303193	30470998
3574	2458855	9	8.306878859987352	31611037
3575	2458855	9	7.677914380260262	31611039
3579	2458855	9	11.088583911146664	31611052
3600	2458855	9	7.993294248351238	31611044
3601	2458855	9	8.59848832744307	31611046
3604	2458855	9	10.922240705511749	31611047
3745	2458855	9	39.928454132361566	30533126
3746	2458855	9	37.91914636578094	30533127
3751	2458855	9	39.94407038652592	30533130
3753	2458855	9	37.97149131721241	30533131
3754	2458855	9	37.56594603988395	30533132
3758	2458855	9	37.628917907523295	30533136
3355	2458854	10	17.684088785752234	30454544
3357	2458854	10	15.378662615269597	30454546
3361	2458854	10	14.513609242503115	30454550
3375	2458854	10	21.300742760751866	30457243
3377	2458854	10	19.48337189360234	30457245
3382	2458854	10	21.05236823025329	30457250
3384	2458854	10	19.220333962896582	30457252
3385	2458854	10	23.47611194780214	30457253
3389	2458854	10	22.86378996448318	30457257
3574	2458854	10	8.5978370161612	31596205
3575	2458854	10	7.613927252886512	31596209
3579	2458854	10	6.691149354138261	31596225
3600	2458854	10	7.940694203816268	31596217
3601	2458854	10	7.65360091352354	31596219
3604	2458854	10	6.773405126702119	31596220
3745	2458854	10	40.27247033189603	30532902
3746	2458854	10	40.63636750809445	30532903
3751	2458854	10	39.92468510082097	30532906
3753	2458854	10	40.1303719543404	30532907
3754	2458854	10	42.678848062990156	30532908
3758	2458854	10	42.13638745288941	30532912
3355	2458855	10	20.32849742456942	30475717
3357	2458855	10	17.389345334562364	30475719
3361	2458855	10	18.4937139932448	30475723
3375	2458855	10	25.134226580596525	30470984
3377	2458855	10	22.96831106602333	30470986
3382	2458855	10	25.054671150492403	30470991
3384	2458855	10	22.819625258103443	30470993
3385	2458855	10	22.554560104326494	30470994
3389	2458855	10	22.47239243075644	30470998
3574	2458855	10	10.421688790094557	31611037
3575	2458855	10	9.35494771751489	31611039
3579	2458855	10	9.872881465444621	31611052
3600	2458855	10	9.819953212372859	31611044
3601	2458855	10	10.067069229618404	31611046
3604	2458855	10	8.396555005968555	31611047
3745	2458855	10	40.91144735453425	30533126
3746	2458855	10	41.760362607083266	30533127
3751	2458855	10	40.78630847720226	30533130
3753	2458855	10	41.26728125705638	30533131
3754	2458855	10	43.50637578480778	30533132
3758	2458855	10	42.97785972893105	30533136
3396	2458854	11	0.9999770916657433	30457264
3397	2458854	11	0.9878719427311092	30457265
3398	2458854	11	0.9965907311019845	30457266
3649	2458854	11	0.9999608214192459	31596256
3650	2458854	11	0.9999133455487562	31596257
3651	2458854	11	0.9999128667048747	31596258
3802	2458854	11	0.9999844710270395	30532967
3803	2458854	11	0.9996350206702952	30532968
3804	2458854	11	0.9985426106757772	30532969
3396	2458855	11	0.9999956007143832	30471093
3397	2458855	11	0.9998558757197951	30471094
3398	2458855	11	0.9999365289734435	30471095
3649	2458855	11	0.9999711182959036	31611062
3650	2458855	11	0.9999240252930576	31611063
3651	2458855	11	0.9999299423412308	31611064
3802	2458855	11	0.9999854217051346	30533146
3803	2458855	11	0.999566981412392	30533147
3804	2458855	11	0.9987247831714648	30533148
3359	2458854	12	20.813239550140764	30454548
3360	2458854	12	20.092738557837574	30454549
3364	2458854	12	19.374578990092626	30454553
3368	2458854	12	19.37892129197946	30457237
3391	2458854	12	18.032235730554902	30457259
3392	2458854	12	17.94819253279791	30457260
3393	2458854	12	17.964706919575878	30457261
3394	2458854	12	18.056573436700948	30457262
3395	2458854	12	19.42330388046329	30457263
3593	2458854	12	15.388259711562393	31596229
3594	2458854	12	15.442322748880946	31596230
3597	2458854	12	16.375038229366336	31596231
3610	2458854	12	15.30132074681372	31596227
3611	2458854	12	15.244732529350307	31596228
3616	2458854	12	16.45832556687783	31596196
3736	2458854	12	10.81303619028455	30532898
3760	2458854	12	12.049810696091976	30532914
3762	2458854	12	11.5603506733302	30532915
3763	2458854	12	12.13560316349052	30532916
3764	2458854	12	11.732423284998282	30532917
3765	2458854	12	10.698616795530322	30532918
3359	2458855	12	23.96130149465608	30475721
3360	2458855	12	23.13064062082475	30475722
3364	2458855	12	22.368813995192802	30475726
3368	2458855	12	27.003388135942394	30470978
3391	2458855	12	25.326471722401575	30471000
3392	2458855	12	26.8393480450167	30471001
3393	2458855	12	25.326342249166878	30471002
3394	2458855	12	26.820921609909266	30471003
3395	2458855	12	27.04726801867887	30471004
3593	2458855	12	22.244723935546183	31611056
3594	2458855	12	21.706605393072635	31611057
3597	2458855	12	23.38848050131847	31611058
3610	2458855	12	21.503720788765634	31611054
3611	2458855	12	22.132336607394215	31611055
3616	2458855	12	23.46733545080996	31611033
3736	2458855	12	12.335157562196699	30533122
3760	2458855	12	13.901654096397419	30533138
3762	2458855	12	12.782579562298242	30533139
3763	2458855	12	13.995557755648411	30533140
3764	2458855	12	12.941230491293473	30533141
3765	2458855	12	12.22028925782611	30533142
3359	2458854	13	32.74287257548493	30454548
3360	2458854	13	33.17916661817042	30454549
3364	2458854	13	32.157633545373706	30454553
3368	2458854	13	26.20449667243679	30457237
3391	2458854	13	26.63367600365952	30457259
3392	2458854	13	27.959113541015284	30457260
3393	2458854	13	32.43782742402001	30457261
3394	2458854	13	30.200761930842003	30457262
3395	2458854	13	26.256087540473874	30457263
3593	2458854	13	28.4653904704028	31596229
3594	2458854	13	26.59480619103015	31596230
3597	2458854	13	30.01335257251778	31596231
3610	2458854	13	26.619331865966547	31596227
3611	2458854	13	28.27844480394441	31596228
3616	2458854	13	30.12678957231884	31596196
3736	2458854	13	17.4999777266223	30532898
3760	2458854	13	16.375973805124676	30532914
3762	2458854	13	15.492883133594205	30532915
3763	2458854	13	17.994724436788392	30532916
3764	2458854	13	15.567157636119504	30532917
3765	2458854	13	17.44451016409543	30532918
3359	2458855	13	35.213841838829374	30475721
3360	2458855	13	35.34069646196581	30475722
3364	2458855	13	34.87862878373354	30475726
3368	2458855	13	32.53508394853469	30470978
3391	2458855	13	37.16786626905841	30471000
3392	2458855	13	37.23130464769276	30471001
3393	2458855	13	37.172092012834526	30471002
3394	2458855	13	37.20463741149413	30471003
3395	2458855	13	32.58621618245684	30471004
3593	2458855	13	37.66003296155002	31611056
3594	2458855	13	31.042569232085384	31611057
3597	2458855	13	33.77848829665677	31611058
3610	2458855	13	31.267628009409417	31611054
3611	2458855	13	37.48096470336171	31611055
3616	2458855	13	33.876461639908435	31611033
3736	2458855	13	30.065931719593152	30533122
3760	2458855	13	30.686188108618136	30533138
3762	2458855	13	22.219377684919902	30533139
3763	2458855	13	31.079298080676086	30533140
3764	2458855	13	22.20100986488194	30533141
3765	2458855	13	29.98643685870037	30533142
3396	2458854	14	0.9998104003031839	30457264
3397	2458854	14	0.35768080859295925	30457265
3398	2458854	14	0.8174864617928853	30457266
3649	2458854	14	0.9999889955850174	31596256
3650	2458854	14	0.9999491141312302	31596257
3651	2458854	14	0.9999632137446289	31596258
3802	2458854	14	0.9998570631308089	30532967
3803	2458854	14	0.9900674483872184	30532968
3804	2458854	14	0.9164571366786562	30532969
3396	2458855	14	0.9999829122232408	30471093
3397	2458855	14	0.9810227568352762	30471094
3398	2458855	14	0.993382909900771	30471095
3649	2458855	14	0.9999933851775198	31611062
3650	2458855	14	0.9999968242300935	31611063
3651	2458855	14	0.9999529949621534	31611064
3802	2458855	14	0.9999649517986942	30533146
3803	2458855	14	0.9946219618515344	30533147
3804	2458855	14	0.9735312699015994	30533148
3359	2458854	15	40.57393222162046	30454548
3360	2458854	15	38.40139895063003	30454549
3364	2458854	15	13.289153622325037	30454553
3368	2458854	15	14.720875829793831	30457237
3391	2458854	15	38.62614501865016	30457259
3392	2458854	15	42.906925423212016	30457260
3393	2458854	15	48.024115260440944	30457261
3394	2458854	15	42.71930213483239	30457262
3395	2458854	15	18.220466487189878	30457263
3593	2458854	15	13.36879446937391	31596229
3594	2458854	15	12.741354759294248	31596230
3597	2458854	15	13.727261719266798	31596231
3610	2458854	15	12.519904924166553	31596227
3611	2458854	15	13.292168759994391	31596228
3616	2458854	15	13.607837600853761	31596196
3736	2458854	15	10.536587141591818	30532898
3760	2458854	15	28.96365919206094	30532914
3762	2458854	15	29.1523675676097	30532915
3763	2458854	15	31.910581917732134	30532916
3764	2458854	15	29.7619204844587	30532917
3765	2458854	15	10.094405738295288	30532918
3359	2458855	15	39.59776206606869	30475721
3360	2458855	15	39.868529599097194	30475722
3364	2458855	15	11.563875895005651	30475726
3368	2458855	15	11.093506538583009	30470978
3391	2458855	15	30.854721356661674	30471000
3392	2458855	15	34.19898390336591	30471001
3393	2458855	15	37.54541608859686	30471002
3394	2458855	15	31.738048907067867	30471003
3395	2458855	15	16.495471073807863	30471004
3593	2458855	15	14.329664607445645	31611056
3594	2458855	15	11.10772313383552	31611057
3597	2458855	15	11.70298461345674	31611058
3610	2458855	15	10.852584045765903	31611054
3611	2458855	15	14.011292204159199	31611055
3616	2458855	15	12.047661623555532	31611033
3736	2458855	15	8.593693579742109	30533122
3760	2458855	15	30.98649739001642	30533138
3762	2458855	15	33.77811001049769	30533139
3763	2458855	15	35.50732044327694	30533140
3764	2458855	15	34.14936418459564	30533141
3765	2458855	15	7.591596161106669	30533142
3359	2458854	16	50.9051428728179	30454548
3360	2458854	16	44.56545015571805	30454549
3364	2458854	16	13.304272375702721	30454553
3368	2458854	16	10.781215002789333	30457237
3391	2458854	16	46.96681824615178	30457259
3392	2458854	16	50.74833458907764	30457260
3393	2458854	16	56.09686444055497	30457261
3394	2458854	16	49.23051633522457	30457262
3395	2458854	16	20.98256372267239	30457263
3593	2458854	16	12.899911517227292	31596229
3594	2458854	16	10.899111939355906	31596230
3597	2458854	16	2.8721035596550735	31596231
3610	2458854	16	10.667935835635024	31596227
3611	2458854	16	12.492214036207422	31596228
3616	2458854	16	3.7610144588400996	31596196
3736	2458854	16	6.370331053938039	30532898
3760	2458854	16	35.63520642891266	30532914
3762	2458854	16	37.64196790537571	30532915
3763	2458854	16	41.633186118790555	30532916
3764	2458854	16	38.25306674244845	30532917
3765	2458854	16	6.477088356975582	30532918
3359	2458855	16	48.13558194172338	30475721
3360	2458855	16	44.61166112132691	30475722
3364	2458855	16	12.954222895891128	30475726
3368	2458855	16	6.511520484671419	30470978
3391	2458855	16	43.111359353893725	30471000
3392	2458855	16	46.151694212098	30471001
3393	2458855	16	50.44305211499315	30471002
3394	2458855	16	42.84240494413768	30471003
3395	2458855	16	20.916401649803742	30471004
3593	2458855	16	15.31526939321892	31611056
3594	2458855	16	13.418603085110243	31611057
3597	2458855	16	3.065065401075556	31611058
3610	2458855	16	13.687339372883345	31611054
3611	2458855	16	15.414297930589521	31611055
3616	2458855	16	4.133719410372877	31611033
3736	2458855	16	5.850398936761689	30533122
3760	2458855	16	38.10549740870758	30533138
3762	2458855	16	38.12966059396895	30533139
3763	2458855	16	45.049914280133684	30533140
3764	2458855	16	39.80289106274255	30533141
3765	2458855	16	8.010807775182156	30533142
3396	2458854	17	0.6366573795676124	30457264
3397	2458854	17	0.48201302381264227	30457265
3398	2458854	17	0.8342161652819254	30457266
3649	2458854	17	0.9885689526317548	31596256
3650	2458854	17	0.9822524975495812	31596257
3651	2458854	17	0.9803225106984309	31596258
3802	2458854	17	0.9741559628040987	30532967
3803	2458854	17	0.9045376636929218	30532968
3804	2458854	17	0.6594880003212378	30532969
3396	2458855	17	0.49789932412967225	30471093
3397	2458855	17	0.4786382474426718	30471094
3398	2458855	17	0.6295198771370883	30471095
3649	2458855	17	0.983741788891339	31611062
3650	2458855	17	0.982677038571131	31611063
3651	2458855	17	0.9646187474270752	31611064
3802	2458855	17	0.9462449859061177	30533146
3803	2458855	17	0.89137897070458	30533147
3804	2458855	17	0.5962799343161742	30533148
3359	2458854	18	3.046057221898991	30454548
3360	2458854	18	3.4631026998715004	30454549
3364	2458854	18	2.111272029429963	30454553
3368	2458854	18	2.6399965125350158	30457237
3391	2458854	18	2.676029031456941	30457259
3392	2458854	18	2.117616957292193	30457260
3393	2458854	18	2.670042222891221	30457261
3394	2458854	18	2.045423090965915	30457262
3395	2458854	18	2.5883139242166084	30457263
3593	2458854	18	3.083938136460598	31596229
3594	2458854	18	3.09459203958854	31596230
3597	2458854	18	2.554438299853942	31596231
3610	2458854	18	2.6734681911945994	31596227
3611	2458854	18	2.3417852375206962	31596228
3616	2458854	18	2.3420453653445827	31596196
3736	2458854	18	-3.2024880609545536	30532898
3760	2458854	18	-2.6186042556917704	30532914
3762	2458854	18	-1.8680314752582932	30532915
3763	2458854	18	-2.5368162470496967	30532916
3764	2458854	18	-1.84792594574514	30532917
3765	2458854	18	-6.158950852734765	30532918
3359	2458855	18	6.382180336037891	30475721
3360	2458855	18	6.006988513687355	30475722
3364	2458855	18	6.038735451055824	30475726
3368	2458855	18	9.627776473978486	30470978
3391	2458855	18	9.527317523249236	30471000
3392	2458855	18	10.589875758080803	30471001
3393	2458855	18	9.574776942741757	30471002
3394	2458855	18	10.571855673470004	30471003
3395	2458855	18	9.576592213234482	30471004
3593	2458855	18	9.651219543280833	31611056
3594	2458855	18	8.105871415940845	31611057
3597	2458855	18	8.030781360237768	31611058
3610	2458855	18	7.627913314474554	31611054
3611	2458855	18	8.9672604432528	31611055
3616	2458855	18	7.8105720986740055	31611033
3736	2458855	18	-2.4358480456706704	30533122
3760	2458855	18	-0.8232530426615957	30533138
3762	2458855	18	-1.7984577384415559	30533139
3763	2458855	18	-0.7483713477218809	30533140
3764	2458855	18	-1.7768514569941785	30533141
3765	2458855	18	-5.388529890645992	30533142
3359	2458854	19	1	30454548
3360	2458854	19	1	30454549
3364	2458854	19	1	30454553
3368	2458854	19	1	30457237
3391	2458854	19	1	30457259
3392	2458854	19	1	30457260
3393	2458854	19	1	30457261
3394	2458854	19	1	30457262
3395	2458854	19	1	30457263
3593	2458854	19	1	31596229
3594	2458854	19	1	31596230
3597	2458854	19	1	31596231
3610	2458854	19	1	31596227
3611	2458854	19	1	31596228
3616	2458854	19	1	31596196
3736	2458854	19	1	30532898
3760	2458854	19	1	30532914
3762	2458854	19	1	30532915
3763	2458854	19	1	30532916
3764	2458854	19	1	30532917
3765	2458854	19	1	30532918
3359	2458855	19	1	30475721
3360	2458855	19	1	30475722
3364	2458855	19	1	30475726
3368	2458855	19	1	30470978
3391	2458855	19	1	30471000
3392	2458855	19	1	30471001
3393	2458855	19	1	30471002
3394	2458855	19	1	30471003
3395	2458855	19	1	30471004
3593	2458855	19	1	31611056
3594	2458855	19	1	31611057
3597	2458855	19	1	31611058
3610	2458855	19	1	31611054
3611	2458855	19	1	31611055
3616	2458855	19	1	31611033
3736	2458855	19	1	30533122
3760	2458855	19	1	30533138
3762	2458855	19	1	30533139
3763	2458855	19	1	30533140
3764	2458855	19	1	30533141
3765	2458855	19	1	30533142
3359	2458854	20	3.8566739266214114	30454548
3360	2458854	20	5.587221566486122	30454549
3364	2458854	20	10.748650535732295	30454553
3368	2458854	20	7.876226316069861	30457237
3391	2458854	20	2.3676614146059336	30457259
3392	2458854	20	-0.5367878015841399	30457260
3393	2458854	20	4.500679958055471	30457261
3394	2458854	20	-0.37627781413002026	30457262
3395	2458854	20	7.7758266036136945	30457263
3593	2458854	20	7.801045642391159	31596229
3594	2458854	20	5.398638579588749	31596230
3597	2458854	20	10.662408019627819	31596231
3610	2458854	20	5.478715236845062	31596227
3611	2458854	20	7.642853697523549	31596228
3616	2458854	20	10.066721417628258	31596196
3736	2458854	20	-3.160037671883444	30532898
3760	2458854	20	-6.651001413278195	30532914
3762	2458854	20	-5.332062920687818	30532915
3763	2458854	20	-6.153880061636755	30532916
3764	2458854	20	-4.909440862601812	30532917
3765	2458854	20	-7.241362260232805	30532918
3359	2458855	20	8.358027157670364	30475721
3360	2458855	20	6.627770478814497	30475722
3364	2458855	20	11.514621939937086	30475726
3368	2458855	20	12.729039866963618	30470978
3391	2458855	20	8.118546265228503	30471000
3392	2458855	20	3.7110993736378504	30471001
3393	2458855	20	4.547244516276578	30471002
3394	2458855	20	1.109407759876433	30471003
3395	2458855	20	12.623700410025833	30471004
3593	2458855	20	16.703375363149632	31611056
3594	2458855	20	12.033423064134482	31611057
3597	2458855	20	10.076993535370306	31611058
3610	2458855	20	12.30826644645785	31611054
3611	2458855	20	16.404383710072167	31611055
3616	2458855	20	9.451186665003846	31611033
3736	2458855	20	11.531846081558484	30533122
3760	2458855	20	6.236341556604586	30533138
3762	2458855	20	4.179974416321343	30533139
3763	2458855	20	5.871048427050141	30533140
3764	2458855	20	4.388884805230049	30533141
3765	2458855	20	7.435913750965867	30533142
3359	2458854	21	-2.4427264012529406	30454548
3360	2458854	21	-3.5789675395392444	30454549
3364	2458854	21	2.998359675009008	30454553
3368	2458854	21	5.385515778394146	30457237
3391	2458854	21	0.1712440003825293	30457259
3392	2458854	21	-2.7685101058143196	30457260
3393	2458854	21	1.6627658153361342	30457261
3394	2458854	21	-6.189328236472392	30457262
3395	2458854	21	8.26132476865205	30457263
3593	2458854	21	-9.145905511333543	31596229
3594	2458854	21	-7.587989208761731	31596230
3597	2458854	21	5.591155243997188	31596231
3610	2458854	21	0.5986783049049981	31596227
3611	2458854	21	-0.3656186051302181	31596228
3616	2458854	21	-1.274299853572548	31596196
3736	2458854	21	-4.873136886872487	30532898
3760	2458854	21	-3.576146095728584	30532914
3762	2458854	21	-2.514623352460726	30532915
3763	2458854	21	-1.5689442935688855	30532916
3764	2458854	21	-0.3962698795064057	30532917
3765	2458854	21	-4.5337935890659935	30532918
3359	2458855	21	-4.16997368275806	30475721
3360	2458855	21	-2.636696539090451	30475722
3364	2458855	21	1.9253470421355796	30475726
3368	2458855	21	1.9508964846982622	30470978
3391	2458855	21	-8.305907890938784	30471000
3392	2458855	21	-11.812299048645022	30471001
3393	2458855	21	-7.646498178397347	30471002
3394	2458855	21	-16.532402086441618	30471003
3395	2458855	21	6.642358583665981	30471004
3593	2458855	21	-7.902254342046301	31611056
3594	2458855	21	-9.475428363277596	31611057
3597	2458855	21	3.1520164206851766	31611058
3610	2458855	21	-1.021088510690267	31611054
3611	2458855	21	0.5835688307359135	31611055
3616	2458855	21	-3.8147889093226013	31611033
3736	2458855	21	-7.502552960863615	30533122
3760	2458855	21	-0.9995080081015905	30533138
3762	2458855	21	0.9750216875396518	30533139
3763	2458855	21	1.1042620433292523	30533140
3764	2458855	21	2.453711979207251	30533141
3765	2458855	21	-7.791231414555085	30533142
3359	2458854	22	-4.242779820262939	30454548
3360	2458854	22	-5.090511750075521	30454549
3364	2458854	22	-3.46673642018919	30454553
3368	2458854	22	-2.2862078309736065	30457237
3391	2458854	22	-1.4668776163128512	30457259
3392	2458854	22	-4.925609223652816	30457260
3393	2458854	22	-0.5668310246709339	30457261
3394	2458854	22	-10.121226896680906	30457262
3395	2458854	22	5.262446196486496	30457263
3593	2458854	22	-17.69839690854857	31596229
3594	2458854	22	-18.505707208577974	31596230
3597	2458854	22	-11.136878337494545	31596231
3610	2458854	22	-8.8498351064838	31596227
3611	2458854	22	-8.299162054481693	31596228
3616	2458854	22	-17.590406825776473	31596196
3736	2458854	22	-20.276870287832317	30532898
3760	2458854	22	-0.3108478600175829	30532914
3762	2458854	22	0.16411040858796183	30532915
3763	2458854	22	0.41974795233144846	30532916
3764	2458854	22	2.8580601210864898	30532917
3765	2458854	22	-9.394888381517521	30532918
3359	2458855	22	-7.671693163477817	30475721
3360	2458855	22	-5.12562890182924	30475722
3364	2458855	22	-4.071545722590739	30475726
3368	2458855	22	-6.786466621382715	30470978
3391	2458855	22	-5.238055131591676	30471000
3392	2458855	22	-9.647460796028042	30471001
3393	2458855	22	-6.132184449905688	30471002
3394	2458855	22	-16.41766447551754	30471003
3395	2458855	22	5.287286607455902	30471004
3593	2458855	22	-15.394659830850344	31611056
3594	2458855	22	-16.195390482292932	31611057
3597	2458855	22	-10.649305263604052	31611058
3610	2458855	22	-6.005679953690228	31611054
3611	2458855	22	-5.36148045386081	31611055
3616	2458855	22	-17.077942541321974	31611033
3736	2458855	22	-20.629289259844587	30533122
3760	2458855	22	2.5303655663111813	30533138
3762	2458855	22	0.611402804606928	30533139
3763	2458855	22	3.8277530053646216	30533140
3764	2458855	22	4.327049291273823	30533141
3765	2458855	22	-7.484855207218345	30533142
3396	2458854	23	0.386730964002735	30457264
3397	2458854	23	0.6878785449674284	30457265
3398	2458854	23	0.7895476295470866	30457266
3649	2458854	23	0.5686451788044019	31596256
3650	2458854	23	0.7956873499400576	31596257
3651	2458854	23	0.6520140476340957	31596258
3802	2458854	23	0.4363259973839343	30532967
3803	2458854	23	0.7897005094476459	30532968
3804	2458854	23	0.7698200606583088	30532969
3396	2458855	23	0.4289786725795533	30471093
3397	2458855	23	0.7148370792635439	30471094
3398	2458855	23	0.6761702370684501	30471095
3649	2458855	23	0.6139606349457616	31611062
3650	2458855	23	0.8508719297976873	31611063
3651	2458855	23	0.7844468553734022	31611064
3802	2458855	23	0.2998823436291259	30533146
3803	2458855	23	0.6462895244009922	30533147
3804	2458855	23	0.8310578722345137	30533148
3396	2458854	24	0.04633499725030861	30457264
3397	2458854	24	-0.030081110846346657	30457265
3398	2458854	24	-0.0026194648490265576	30457266
3649	2458854	24	-0.08304847784752328	31596256
3650	2458854	24	-0.14626449461047075	31596257
3651	2458854	24	-0.14700977306990465	31596258
3802	2458854	24	-0.11792705042992689	30532967
3803	2458854	24	-0.15039785157912275	30532968
3804	2458854	24	-0.12268156057381567	30532969
3396	2458855	24	0.04562558753611913	30471093
3397	2458855	24	0.02260829866537691	30471094
3398	2458855	24	0.005055296404724917	30471095
3649	2458855	24	-0.08171411440479873	31611062
3650	2458855	24	-0.1362150458005802	31611063
3651	2458855	24	-0.16604393967683037	31611064
3802	2458855	24	-0.114923734815026	30533146
3803	2458855	24	-0.16513725077508898	30533147
3804	2458855	24	-0.09163494396529297	30533148
3396	2458854	25	0.04607352019993905	30457264
3397	2458854	25	-1.5686592994572663	30457265
3398	2458854	25	-4.93348082452619	30457266
3649	2458854	25	-0.10518376294363055	31596256
3650	2458854	25	-0.11071611953442807	31596257
3651	2458854	25	-0.08823539866837998	31596258
3802	2458854	25	-0.07653370340526985	30532967
3803	2458854	25	-0.027945481622186904	30532968
3804	2458854	25	-0.743365655387038	30532969
3396	2458855	25	0.044840274508791675	30471093
3397	2458855	25	-0.019247165740456994	30471094
3398	2458855	25	-0.005863573919686111	30471095
3649	2458855	25	-0.09125751559100494	31611062
3650	2458855	25	-0.10138853836579058	31611063
3651	2458855	25	-0.11907786726986115	31611064
3802	2458855	25	-0.0717441019817218	30533146
3803	2458855	25	-0.11068201985633173	30533147
3804	2458855	25	-0.24400774574313389	30533148
3396	2458854	26	3.1002009887709487	30457264
3397	2458854	26	0.20414858899895122	30457265
3398	2458854	26	-9.614196693625482	30457266
3649	2458854	26	-0.04557303867423499	31596256
3650	2458854	26	-0.029768632061535443	31596257
3651	2458854	26	-0.21160085627078165	31596258
3802	2458854	26	-0.3868899370228877	30532967
3803	2458854	26	-0.5914315433991885	30532968
3804	2458854	26	-4.271525226524005	30532969
3396	2458855	26	4.978623543359363	30471093
3397	2458855	26	1.6971794263129187	30471094
3398	2458855	26	-7.758730290422537	30471095
3649	2458855	26	-0.214937119167695	31611062
3650	2458855	26	-0.22984523092754397	31611063
3651	2458855	26	-0.02917485361347351	31611064
3802	2458855	26	-1.0261495465619075	30533146
3803	2458855	26	-0.1732562386983071	30533147
3804	2458855	26	-4.531098521363456	30533148
3396	2458854	27	11.194775397688014	30457264
3397	2458854	27	1.458783769033633	30457265
3398	2458854	27	-9.215266177853822	30457266
3649	2458854	27	-0.8574596168325356	31596256
3650	2458854	27	-0.782848482841435	31596257
3651	2458854	27	0.3840940895236478	31596258
3802	2458854	27	0.10808891562718152	30532967
3803	2458854	27	-0.9609543921865595	30532968
3804	2458854	27	-5.879588162745283	30532969
3396	2458855	27	15.4368803338884	30471093
3397	2458855	27	3.7253953247731775	30471094
3398	2458855	27	-6.853871837809895	30471095
3649	2458855	27	-0.9103630331923714	31611062
3650	2458855	27	-0.2804019382141521	31611063
3651	2458855	27	0.35739105884090033	31611064
3802	2458855	27	1.7252692732629753	30533146
3803	2458855	27	-1.655273241962785	30533147
3804	2458855	27	-6.693165325987017	30533148
3580	2458854	31	0.0018070557862568265	30455812
3582	2458854	31	0.011164163363931267	30455814
3580	2458855	31	0.1758493250521967	30474769
3582	2458855	31	0.3184944594336328	30474771
3581	2458854	32	1.0143517256225136	30455813
3595	2458854	32	1.011384099201956	30455826
3742	2458854	32	1.0149804794143418	30458188
3581	2458855	32	1.0124349852669927	30474770
3595	2458855	32	1.0094129390574949	30474784
3742	2458855	32	1.016064495622387	30473166
\.


--
-- Data for Name: tblmetricstringdata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblmetricstringdata (fkchannelid, date, fkmetricid, value, "fkHashID") FROM stdin;
\.


--
-- Data for Name: tblscan; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblscan (pkscanid, fkparentscan, lastupdate, metricfilter, networkfilter, stationfilter, channelfilter, startdate, enddate, priority, deleteexisting, scheduledrun, finished, taken, locationfilter) FROM stdin;
\.


--
-- Data for Name: tblscanmessage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblscanmessage (pkmessageid, fkscanid, network, location, station, channel, "timestamp", metric, message) FROM stdin;
\.


--
-- Data for Name: tblsensor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblsensor (pksensorid, fkstationid, location) FROM stdin;
505	146	20
506	146	00
507	147	10
508	147	20
509	147	30
510	147	00
511	147	00-10
540	161	00
541	161	35
542	161	10
543	161	32
544	161	31
545	161	33
546	161	50
547	161	40
548	161	30
549	161	60
550	161	20
556	161	00-10
571	165	00
572	165	10
573	165	20
574	165	30
575	165	31
580	165	00-10
794	161	10-20
795	161	00-20
833	146	00-20
854	147	10-20
855	147	00-20
968	165	10-20
969	165	00-20
\.


--
-- Data for Name: tblstation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tblstation (pkstationid, fknetworkid, name) FROM stdin;
146	650	WVOR
147	650	WMOK
161	649	ANMO
165	649	FURI
\.


--
-- Name: tblGroupType_pkGroupTypeID_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."tblGroupType_pkGroupTypeID_seq"', 1, false);


--
-- Name: tblGroup_pkgroupid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."tblGroup_pkgroupid_seq"', 684, true);


--
-- Name: tblcalibrationdata_pkcalibrationdataid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblcalibrationdata_pkcalibrationdataid_seq', 1, false);


--
-- Name: tblchannel_pkchannelid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblchannel_pkchannelid_seq', 23766, true);


--
-- Name: tblcomputetype_pkcomputetypeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblcomputetype_pkcomputetypeid_seq', 1, false);


--
-- Name: tblerrorlog_pkerrorlogid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblerrorlog_pkerrorlogid_seq', 3322959, true);


--
-- Name: tblhash_pkHashID_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."tblhash_pkHashID_seq"', 32662795, true);


--
-- Name: tblmetric_pkmetricid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblmetric_pkmetricid_seq', 32, true);


--
-- Name: tblscanmessage_pkmessageid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblscanmessage_pkmessageid_seq', 1231228, true);


--
-- Name: tblsensor_pksensorid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblsensor_pksensorid_seq', 2492, true);


--
-- Name: tblstation_pkstationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tblstation_pkstationid_seq', 583, true);


--
-- Name: tblStationGroupTie Primary_tblstationGrouptie; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblStationGroupTie"
    ADD CONSTRAINT "Primary_tblstationGrouptie" PRIMARY KEY ("fkGroupID", "fkStationID");


--
-- Name: tblhash pkTblHash; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblhash
    ADD CONSTRAINT "pkTblHash" PRIMARY KEY ("pkHashID");


--
-- Name: tblmetricdata pk_metric_date_channel; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetricdata
    ADD CONSTRAINT pk_metric_date_channel PRIMARY KEY (fkmetricid, date, fkchannelid);


--
-- Name: tblscan pk_tblScan; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblscan
    ADD CONSTRAINT "pk_tblScan" PRIMARY KEY (pkscanid);


--
-- Name: tblmetricstringdata pkstring_metric_date_channel; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetricstringdata
    ADD CONSTRAINT pkstring_metric_date_channel PRIMARY KEY (fkmetricid, date, fkchannelid);


--
-- Name: tblGroupType primary_tblGroupType; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroupType"
    ADD CONSTRAINT "primary_tblGroupType" PRIMARY KEY ("pkGroupTypeID");


--
-- Name: tblcalibrationdata tblcalibrationdata_fkchannelid_fkmetcaltypeid_calday_calmon_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcalibrationdata
    ADD CONSTRAINT tblcalibrationdata_fkchannelid_fkmetcaltypeid_calday_calmon_key UNIQUE (fkchannelid, fkmetcaltypeid, calday, calmonth, calyear, day, month, year);


--
-- Name: tblcalibrationdata tblcalibrationdata_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcalibrationdata
    ADD CONSTRAINT tblcalibrationdata_pkey PRIMARY KEY (pkcalibrationdataid);


--
-- Name: tblchannel tblchannel_fksensorid_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblchannel
    ADD CONSTRAINT tblchannel_fksensorid_name_key UNIQUE (fksensorid, name);


--
-- Name: tblchannel tblchannel_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblchannel
    ADD CONSTRAINT tblchannel_pkey PRIMARY KEY (pkchannelid);


--
-- Name: tblcomputetype tblcomputetype_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcomputetype
    ADD CONSTRAINT tblcomputetype_name_key UNIQUE (name);


--
-- Name: tblcomputetype tblcomputetype_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcomputetype
    ADD CONSTRAINT tblcomputetype_pkey PRIMARY KEY (pkcomputetypeid);


--
-- Name: tbldate tbldate_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tbldate
    ADD CONSTRAINT tbldate_date_key UNIQUE (date);


--
-- Name: tbldate tbldate_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tbldate
    ADD CONSTRAINT tbldate_pkey PRIMARY KEY (pkdateid);


--
-- Name: tblerrorlog tblerrorlog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblerrorlog
    ADD CONSTRAINT tblerrorlog_pkey PRIMARY KEY (pkerrorlogid);


--
-- Name: tblmetadata tblmetadata_fkchannelid_epoch_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetadata
    ADD CONSTRAINT tblmetadata_fkchannelid_epoch_key UNIQUE (fkchannelid, epoch);


--
-- Name: tblmetric tblmetric_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetric
    ADD CONSTRAINT tblmetric_pkey PRIMARY KEY (pkmetricid);


--
-- Name: tblGroup tblnetwork_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroup"
    ADD CONSTRAINT tblnetwork_pkey PRIMARY KEY (pkgroupid);


--
-- Name: tblscanmessage tblscanmessage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblscanmessage
    ADD CONSTRAINT tblscanmessage_pkey PRIMARY KEY (pkmessageid);


--
-- Name: tblsensor tblsensor_fkstationid_location_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblsensor
    ADD CONSTRAINT tblsensor_fkstationid_location_key UNIQUE (fkstationid, location);


--
-- Name: tblsensor tblsensor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblsensor
    ADD CONSTRAINT tblsensor_pkey PRIMARY KEY (pksensorid);


--
-- Name: tblstation tblstation_fknetworkid_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblstation
    ADD CONSTRAINT tblstation_fknetworkid_name_key UNIQUE (fknetworkid, name);


--
-- Name: tblstation tblstation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblstation
    ADD CONSTRAINT tblstation_pkey PRIMARY KEY (pkstationid);


--
-- Name: tblGroupType un_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroupType"
    ADD CONSTRAINT un_name UNIQUE (name);


--
-- Name: tblGroup un_name_fkGroupType; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroup"
    ADD CONSTRAINT "un_name_fkGroupType" UNIQUE (name, "fkGroupTypeID");


--
-- Name: tblhash un_tblHash_hash; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblhash
    ADD CONSTRAINT "un_tblHash_hash" UNIQUE (hash);


--
-- Name: tblmetric un_tblMetric_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetric
    ADD CONSTRAINT "un_tblMetric_name" UNIQUE (name);


--
-- Name: tblchannel_pkchannelid_fksensorid_isIgnored_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "tblchannel_pkchannelid_fksensorid_isIgnored_idx" ON public.tblchannel USING btree (pkchannelid, fksensorid, "isIgnored");

ALTER TABLE public.tblchannel CLUSTER ON "tblchannel_pkchannelid_fksensorid_isIgnored_idx";


--
-- Name: tbldate_pkdateid_date_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tbldate_pkdateid_date_idx ON public.tbldate USING btree (pkdateid, date);

ALTER TABLE public.tbldate CLUSTER ON tbldate_pkdateid_date_idx;


--
-- Name: tblhash_pkHashID_hash_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "tblhash_pkHashID_hash_idx" ON public.tblhash USING btree ("pkHashID", hash);

ALTER TABLE public.tblhash CLUSTER ON "tblhash_pkHashID_hash_idx";


--
-- Name: tblmetricdata_fkmetricid_date_fkchannelid_value_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tblmetricdata_fkmetricid_date_fkchannelid_value_idx ON public.tblmetricdata USING btree (fkmetricid, date, fkchannelid, value);

ALTER TABLE public.tblmetricdata CLUSTER ON tblmetricdata_fkmetricid_date_fkchannelid_value_idx;


--
-- Name: tblmetricstringdata_fkmetricid_date_fkchannelid_value_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tblmetricstringdata_fkmetricid_date_fkchannelid_value_idx ON public.tblmetricstringdata USING btree (fkmetricid, date, fkchannelid, value);


--
-- Name: tblsensor_pksensorid_fkstationid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tblsensor_pksensorid_fkstationid_idx ON public.tblsensor USING btree (pksensorid, fkstationid);

ALTER TABLE public.tblsensor CLUSTER ON tblsensor_pksensorid_fkstationid_idx;


--
-- Name: tblstation_pkstationid_fknetworkid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tblstation_pkstationid_fknetworkid_idx ON public.tblstation USING btree (pkstationid, fknetworkid);

ALTER TABLE public.tblstation CLUSTER ON tblstation_pkstationid_fknetworkid_idx;


--
-- Name: tblStationGroupTie fkStationTieTblGroup; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblStationGroupTie"
    ADD CONSTRAINT "fkStationTieTblGroup" FOREIGN KEY ("fkGroupID") REFERENCES public."tblGroup"(pkgroupid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tblStationGroupTie fkStationTieTblStation; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblStationGroupTie"
    ADD CONSTRAINT "fkStationTieTblStation" FOREIGN KEY ("fkStationID") REFERENCES public.tblstation(pkstationid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tblcalibrationdata fk_tblCalibrationData_tblChannel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcalibrationdata
    ADD CONSTRAINT "fk_tblCalibrationData_tblChannel" FOREIGN KEY (fkchannelid) REFERENCES public.tblchannel(pkchannelid);


--
-- Name: tblcalibrationdata fk_tblCalibrationData_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblcalibrationdata
    ADD CONSTRAINT "fk_tblCalibrationData_tblMetric" FOREIGN KEY (fkmetricid) REFERENCES public.tblmetric(pkmetricid);


--
-- Name: tblmetricdata fk_tblChannel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetricdata
    ADD CONSTRAINT "fk_tblChannel" FOREIGN KEY (fkchannelid) REFERENCES public.tblchannel(pkchannelid) ON DELETE CASCADE;


--
-- Name: tblmetric fk_tblComputeType; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetric
    ADD CONSTRAINT "fk_tblComputeType" FOREIGN KEY (fkcomputetypeid) REFERENCES public.tblcomputetype(pkcomputetypeid) ON DELETE CASCADE;


--
-- Name: tblmetricdata fk_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetricdata
    ADD CONSTRAINT "fk_tblMetric" FOREIGN KEY (fkmetricid) REFERENCES public.tblmetric(pkmetricid) ON DELETE CASCADE;


--
-- Name: tblstation fk_tblNetwork; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblstation
    ADD CONSTRAINT "fk_tblNetwork" FOREIGN KEY (fknetworkid) REFERENCES public."tblGroup"(pkgroupid) ON DELETE CASCADE;


--
-- Name: tblchannel fk_tblSensor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblchannel
    ADD CONSTRAINT "fk_tblSensor" FOREIGN KEY (fksensorid) REFERENCES public.tblsensor(pksensorid) ON DELETE CASCADE;


--
-- Name: tblsensor fk_tblStation; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblsensor
    ADD CONSTRAINT "fk_tblStation" FOREIGN KEY (fkstationid) REFERENCES public.tblstation(pkstationid) ON DELETE CASCADE;


--
-- Name: tblGroup fk_tblgrouptype; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."tblGroup"
    ADD CONSTRAINT fk_tblgrouptype FOREIGN KEY ("fkGroupTypeID") REFERENCES public."tblGroupType"("pkGroupTypeID");


--
-- Name: tblmetricstringdata fkstring_tblChannel; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetricstringdata
    ADD CONSTRAINT "fkstring_tblChannel" FOREIGN KEY (fkchannelid) REFERENCES public.tblchannel(pkchannelid) ON DELETE CASCADE;


--
-- Name: tblmetricstringdata fkstring_tblMetric; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblmetricstringdata
    ADD CONSTRAINT "fkstring_tblMetric" FOREIGN KEY (fkmetricid) REFERENCES public.tblmetric(pkmetricid) ON DELETE CASCADE;


--
-- Name: tblscan tblScan_fkparentscan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblscan
    ADD CONSTRAINT "tblScan_fkparentscan_fkey" FOREIGN KEY (fkparentscan) REFERENCES public.tblscan(pkscanid);


--
-- Name: tblscanmessage tblscanmessage_fkscanid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tblscanmessage
    ADD CONSTRAINT tblscanmessage_fkscanid_fkey FOREIGN KEY (fkscanid) REFERENCES public.tblscan(pkscanid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA public TO postgres;


--
-- Name: FUNCTION fnfinishscan(scanid uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnfinishscan(scanid uuid) TO postgres;
GRANT ALL ON FUNCTION public.fnfinishscan(scanid uuid) TO postgres;


--
-- Name: FUNCTION fnsclgetchanneldata(integer[], integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetchanneldata(integer[], integer, date, date) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetchanneldata(integer[], integer, date, date) TO postgres;


--
-- Name: FUNCTION fnsclgetchannelplotdata(integer, integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetchannelplotdata(integer, integer, date, date) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetchannelplotdata(integer, integer, date, date) TO postgres;


--
-- Name: FUNCTION fnsclgetchannels(integer[]); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetchannels(integer[]) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetchannels(integer[]) TO postgres;


--
-- Name: FUNCTION fnsclgetdates(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetdates() TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetdates() TO postgres;


--
-- Name: FUNCTION fnsclgetgroups(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetgroups() TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetgroups() TO postgres;


--
-- Name: FUNCTION fnsclgetgrouptypes(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetgrouptypes() TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetgrouptypes() TO postgres;


--
-- Name: FUNCTION fnsclgetmetrics(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetmetrics() TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetmetrics() TO postgres;


--
-- Name: FUNCTION fnsclgetpercentage(double precision, character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetpercentage(double precision, character varying) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetpercentage(double precision, character varying) TO postgres;


--
-- Name: FUNCTION fnsclgetstationdata(integer[], integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetstationdata(integer[], integer, date, date) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetstationdata(integer[], integer, date, date) TO postgres;


--
-- Name: FUNCTION fnsclgetstationplotdata(integer, integer, date, date); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetstationplotdata(integer, integer, date, date) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetstationplotdata(integer, integer, date, date) TO postgres;


--
-- Name: FUNCTION fnsclgetstations(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclgetstations() TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclgetstations() TO postgres;


--
-- Name: FUNCTION fnsclisnumeric("inputText" text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fnsclisnumeric("inputText" text) TO dqa_write;
GRANT ALL ON FUNCTION public.fnsclisnumeric("inputText" text) TO postgres;


--
-- Name: FUNCTION uuid_generate_v1mc(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v1mc() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_generate_v1mc() TO postgres;


--
-- Name: TABLE tblscan; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblscan TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblscan TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblscan TO postgres;


--
-- Name: FUNCTION fntakenextscan(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fntakenextscan() TO dqa_write;
GRANT ALL ON FUNCTION public.fntakenextscan() TO postgres;


--
-- Name: FUNCTION spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) TO dqa_write;
GRANT ALL ON FUNCTION public.spcomparehash(date, character varying, character varying, character varying, character varying, character varying, bytea) TO postgres;


--
-- Name: FUNCTION spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) TO dqa_write;
GRANT ALL ON FUNCTION public.spgetmetricvalue(date, character varying, character varying, character varying, character varying, character varying) TO postgres;


--
-- Name: FUNCTION spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) TO dqa_write;
GRANT ALL ON FUNCTION public.spgetmetricvaluedigest(date, character varying, character varying, character varying, character varying, character varying, OUT bytea) TO postgres;


--
-- Name: FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) TO dqa_write;
GRANT ALL ON FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, double precision, bytea) TO postgres;


--
-- Name: FUNCTION spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO dqa_write;
GRANT ALL ON FUNCTION public.spinsertmetricdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO postgres;


--
-- Name: FUNCTION spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO dqa_write;
GRANT ALL ON FUNCTION public.spinsertmetricstringdata(date, character varying, character varying, character varying, character varying, character varying, text, bytea) TO postgres;


--
-- Name: FUNCTION uuid_generate_v1(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v1() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_generate_v1() TO postgres;


--
-- Name: FUNCTION uuid_generate_v3(namespace uuid, name text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v3(namespace uuid, name text) TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_generate_v3(namespace uuid, name text) TO postgres;


--
-- Name: FUNCTION uuid_generate_v4(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v4() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_generate_v4() TO postgres;


--
-- Name: FUNCTION uuid_generate_v5(namespace uuid, name text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_generate_v5(namespace uuid, name text) TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_generate_v5(namespace uuid, name text) TO postgres;


--
-- Name: FUNCTION uuid_nil(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_nil() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_nil() TO postgres;


--
-- Name: FUNCTION uuid_ns_dns(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_dns() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_ns_dns() TO postgres;


--
-- Name: FUNCTION uuid_ns_oid(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_oid() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_ns_oid() TO postgres;


--
-- Name: FUNCTION uuid_ns_url(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_url() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_ns_url() TO postgres;


--
-- Name: FUNCTION uuid_ns_x500(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.uuid_ns_x500() TO dqa_write;
GRANT ALL ON FUNCTION public.uuid_ns_x500() TO postgres;


--
-- Name: TABLE "tblGroup"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public."tblGroup" TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public."tblGroup" TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public."tblGroup" TO postgres;


--
-- Name: TABLE "tblGroupType"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public."tblGroupType" TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public."tblGroupType" TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public."tblGroupType" TO postgres;


--
-- Name: TABLE grouptypeview; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.grouptypeview TO postgres;
GRANT ALL ON TABLE public.grouptypeview TO postgres;
GRANT ALL ON TABLE public.grouptypeview TO dqa_write;


--
-- Name: TABLE groupview; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.groupview TO postgres;
GRANT ALL ON TABLE public.groupview TO postgres;
GRANT ALL ON TABLE public.groupview TO dqa_write;


--
-- Name: TABLE "tblStationGroupTie"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public."tblStationGroupTie" TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public."tblStationGroupTie" TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public."tblStationGroupTie" TO postgres;


--
-- Name: TABLE tblstation; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblstation TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblstation TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblstation TO postgres;


--
-- Name: TABLE stationview; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.stationview TO postgres;
GRANT ALL ON TABLE public.stationview TO postgres;
GRANT ALL ON TABLE public.stationview TO dqa_write;


--
-- Name: SEQUENCE "tblGroupType_pkGroupTypeID_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public."tblGroupType_pkGroupTypeID_seq" TO PUBLIC;
GRANT ALL ON SEQUENCE public."tblGroupType_pkGroupTypeID_seq" TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public."tblGroupType_pkGroupTypeID_seq" TO postgres;


--
-- Name: SEQUENCE "tblGroup_pkgroupid_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public."tblGroup_pkgroupid_seq" TO PUBLIC;
GRANT ALL ON SEQUENCE public."tblGroup_pkgroupid_seq" TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public."tblGroup_pkgroupid_seq" TO postgres;


--
-- Name: TABLE tblcalibrationdata; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblcalibrationdata TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblcalibrationdata TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblcalibrationdata TO postgres;


--
-- Name: SEQUENCE tblcalibrationdata_pkcalibrationdataid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblcalibrationdata_pkcalibrationdataid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblcalibrationdata_pkcalibrationdataid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblcalibrationdata_pkcalibrationdataid_seq TO postgres;


--
-- Name: TABLE tblchannel; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblchannel TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblchannel TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblchannel TO postgres;


--
-- Name: SEQUENCE tblchannel_pkchannelid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblchannel_pkchannelid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblchannel_pkchannelid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblchannel_pkchannelid_seq TO postgres;


--
-- Name: TABLE tblcomputetype; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblcomputetype TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblcomputetype TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblcomputetype TO postgres;


--
-- Name: SEQUENCE tblcomputetype_pkcomputetypeid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblcomputetype_pkcomputetypeid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblcomputetype_pkcomputetypeid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblcomputetype_pkcomputetypeid_seq TO postgres;


--
-- Name: TABLE tbldate; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tbldate TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tbldate TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tbldate TO postgres;


--
-- Name: TABLE tblerrorlog; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblerrorlog TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblerrorlog TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblerrorlog TO postgres;


--
-- Name: SEQUENCE tblerrorlog_pkerrorlogid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblerrorlog_pkerrorlogid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblerrorlog_pkerrorlogid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblerrorlog_pkerrorlogid_seq TO postgres;


--
-- Name: TABLE tblhash; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblhash TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblhash TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblhash TO postgres;


--
-- Name: SEQUENCE "tblhash_pkHashID_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public."tblhash_pkHashID_seq" TO PUBLIC;
GRANT ALL ON SEQUENCE public."tblhash_pkHashID_seq" TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public."tblhash_pkHashID_seq" TO postgres;


--
-- Name: TABLE tblmetadata; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblmetadata TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblmetadata TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblmetadata TO postgres;


--
-- Name: TABLE tblmetric; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblmetric TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblmetric TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblmetric TO postgres;


--
-- Name: SEQUENCE tblmetric_pkmetricid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblmetric_pkmetricid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblmetric_pkmetricid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblmetric_pkmetricid_seq TO postgres;


--
-- Name: TABLE tblmetricdata; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblmetricdata TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblmetricdata TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblmetricdata TO postgres;


--
-- Name: TABLE tblmetricstringdata; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblmetricstringdata TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblmetricstringdata TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblmetricstringdata TO postgres;


--
-- Name: TABLE tblscanmessage; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblscanmessage TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblscanmessage TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblscanmessage TO postgres;


--
-- Name: SEQUENCE tblscanmessage_pkmessageid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblscanmessage_pkmessageid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblscanmessage_pkmessageid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblscanmessage_pkmessageid_seq TO postgres;


--
-- Name: TABLE tblsensor; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,REFERENCES ON TABLE public.tblsensor TO PUBLIC;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE public.tblsensor TO dqa_write;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.tblsensor TO postgres;


--
-- Name: SEQUENCE tblsensor_pksensorid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblsensor_pksensorid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblsensor_pksensorid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblsensor_pksensorid_seq TO postgres;


--
-- Name: SEQUENCE tblstation_pkstationid_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON SEQUENCE public.tblstation_pkstationid_seq TO PUBLIC;
GRANT ALL ON SEQUENCE public.tblstation_pkstationid_seq TO dqa_write;
GRANT SELECT,USAGE ON SEQUENCE public.tblstation_pkstationid_seq TO postgres;


--
-- PostgreSQL database dump complete
--

