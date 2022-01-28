/*
plot.js
Author: James Holland jholland@usgs.gov
plot.js contains functions for creating plot windows and actual plotting
License: Public Domain
*/

function plotTemplate(id, title){
    var dialog = $("<div id='dia"+id+"' title='"+title+"'></div>").dialog({
        width: 800,
        height: 550,
        close: function(event, ui){
            $("#dia"+id).remove();
        }
    });
    var plotTarget = $("<div id='plot"+id+"'></div>");

    dialog.append(plotTarget);
    dialog.append("<button class='button' id='btn"+id+"' value='"+id+"'>Zoom out</button>");
    dialog.append("<button class='button' style='margin-left:10px;' id='imagebtn"+id+"' value='"+id+"'>Save Plot Image</button>");

    return dialog;
}

function createDialog(id){
    var ids = id.split("_");
    var pid = ids[1]+"_"+ids[2]; //removes the "d_" from the front of the id
    var title = undefined;
    var units = mapMNametoMUnit[mapMIDtoMName[ids[1]]];

    if (pageType == "summary"){
        title = mapGIDtoGName[mapSIDtoNID[ids[2]]]+"-"+mapSIDtoSName[ids[2]]+" "+mapMIDtoMName[ids[1]];
    }
    else if (pageType == "station"){
        var stationID = getQueryString("station");
        var networkID = getQueryString("network");
        var stationName = networkID + "-" + stationID;
        title = stationName+" "+mapCIDtoLoc[ids[2]]+"-"+mapCIDtoCName[ids[2]]+" "+mapMIDtoMName[ids[1]];
    }
    else
        title = "ERROR page type not defined";

    //We may want the ability to have multiple of the same plot up to compare different date ranges.
    //If we do try to implement this, there is a bug. When the last dialog is closed, the first disapears, but doesn't get removed. Same with Second to last and second.
    if($("#dia"+pid).length) //If dialog exists, close it.
        $("#dia"+pid).dialog("close");
    getPlotData(ids, pid, title, units);
}

function bindPlot(pid, title, units){
    if (plotdata[pid].length > 0){ //Check if data was returned, if none was returned don't plot anything.
        $('#html').append(plotTemplate(pid, title));
        // If max === min then jqplot does strange scaling so force the issue by getting the max and min and manually setting max and min
        var data = [];
        $.each(plotdata[pid], function(index, item){data.push(item[1])});
        // jqplot does some strange things with scaling so fix those areas, mainly if max = min
        var maxDate = getEndDate("object");
        maxDate.setDate(maxDate.getUTCDate() + 1);
        var xmax = formatDate(maxDate);

        var minDate = getStartDate("object");
        minDate.setDate(minDate.getUTCDate() - 1);
        var xmin = formatDate(minDate);

        var ymax = Math.max(...data);
        var ymin = Math.min(...data);
        var ydelta = ymax - ymin;
        if(ymax === ymin) {
            ymax = ymax + 1.0;
            ymin = ymin - 1.0;
        }
        else{
            ymax = null;
            ymin = null;
        }
        // Set precision of y axis labels dynamically
        var yprecision = '%.1f';
        if(ydelta < 1.0)
            yprecision = '%.3f';
        else if(ydelta < 10.0)
            yprecision = '%.2f';

        var dateDiff = Math.round((maxDate - minDate) / (1000*60*60*24));
        // Max size 8 at 3 months Min size 3 at 2 years.
        var dotSize = -0.0078125*dateDiff +8.70313;

        dotSize = Math.min(Math.max(3, dotSize), 8);
        // Build plot element
        plots[pid] = $.jqplot('plot'+pid, [plotdata[pid]], {
            title: title,
            width: 800,
            height: 420,
            cursor: {
                show: true,
                zoom: true,
                showTooltip: false
            },

            highlighter: {
                show: true,
                sizeAdjust: 3.0
            },
            axes: {
                xaxis: {
                    tickOptions:{
                        formatString:'%Y-%m-%#d', //This needs to match util.formatDate
                        fontSize: '10pt',
                        angle: -30
                    },
                    max: xmax,
                    min: xmin,
                    renderer: $.jqplot.DateAxisRenderer,
                    tickRenderer: $.jqplot.CanvasAxisTickRenderer,
                    labelRenderer: $.jqplot.CanvasAxisLabelRenderer,
                },
                yaxis: {
                    tickOptions:{
                        fontSize: '10pt',
                        formatString: yprecision
                    },
                    pad: 1.05,
                    min: ymin,
                    max: ymax,
                    label: units,
                    labelRenderer: $.jqplot.CanvasAxisLabelRenderer
                }
            },
            series:[
              {
                showLine:false,
                markerOptions: { size: dotSize, style:'filledCircle' }
              },
            ]
        });

        //Bind the zoom out button
        $("#btn"+pid).click(function () {
            plots[$(this).val()].resetZoom();
        });
        $('#dia'+pid).bind('dialogresize', function(event, ui) {
            plots[pid].replot( { resetAxes: true } );
        });
        // Bind plot image dialog to view plot image button
        $("#imagebtn"+pid).click(function(){saveImageToFile(pid, title);});
    }

}

function getPlotData(ids, pid, title, units){
    var daterange = getQueryDates();
    if (pageType == "station"){
        $.get(metricsold_url,
            {cmd: "channelplot", param: "channel."+ids[2]+"_metric."+ids[1]+"_dates."+daterange},
            function(data){
                parsePlotReturn(data, pid);
            }
        ).done(function(){
            bindPlot(pid, title, units);
        });

    }
    else if (pageType == "summary"){
        $.get(metricsold_url,
            {cmd: "stationplot", param: "station."+ids[2]+"_metric."+ids[1]+"_dates."+daterange},
            function(data){
                parsePlotReturn(data, pid);
            }
        ).done(function(){
            bindPlot(pid, title, units);
        });
    }
}

function parsePlotReturn(data,pid){
    plotdata["xmax"+pid] = undefined;
    plotdata["xmin"+pid] = undefined;
    plotdata["ymax"+pid] = undefined;
    plotdata["ymin"+pid] = undefined;
    plotdata[pid] = new Array();
    var rows = new Array();
    rows = data.split("\n");
    for(var i = 0; i <rows.length; i++){
        var row = rows[i].split(",");   //row[0] is date, row[1] is value
        if(row[1] && row[0]){
            var rdate = parseDate(row[0],'-');
            var rval = parseFloat(parseFloat(row[1]).toFixed(2)); //Second parseFloat loses trailing 0s and lets us not have to parseFloat on every comparison and store.
            plotdata[pid].push([rdate,rval]);
            /*//Padding makes this code unneeded
            if(plotdata["xmax"+pid] == undefined || rdate > plotdata["xmax"+pid])
            plotdata["xmax"+pid] = rdate;
            if(plotdata["xmin"+pid] == undefined || rdate < plotdata["xmin"+pid])
            plotdata["xmin"+pid] = rdate;
            if(plotdata["ymax"+pid] == undefined || rval > plotdata["ymax"+pid])
            plotdata["ymax"+pid] = rval;
            if((plotdata["ymin"+pid] == undefined) || rval < plotdata["ymin"+pid])
            plotdata["ymin"+pid] = rval;
            */
        }
    }
}

function saveImageToFile(pid, title){
    var imgData = $('#plot'+pid).jqplotToImageStr({});
    if (imgData) {

        //Create a link to file data and then click it programmatically.
        //I couldn't find a simpler method that works universally.

        var imgDownload = document.createElement('a');
        var filename = title + ".png";
        filename = filename.replace(/[^a-z0-9 \-.]/gi, '');
        imgDownload.download = filename;
        imgDownload.href = imgData.replace("image/png", "image/octet-stream");
        //Firefox requires the link to be added to the page.
        document.body.appendChild(imgDownload);
        imgDownload.click();
        //Cleanup the added link
        imgDownload.remove();
    }

}
