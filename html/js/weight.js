/*
weight.js
Author: James Holland jholland@usgs.gov
weight.js contains variables and functions related to weighting and aggregate calculation
License: Public Domain
*/
var percents = {}; //Contains list of objects for each metric
/* Format is like so:
percents = {
"station1ID" = {
metric1ID = 100,
metric2ID = 85
},
"station2ID" = ...
OR
"channel1ID" = {
metric1ID = ...
}

}
*/
var weights = {}; //Contains available metrics and weight setting (.50) 

function setupWeightTab(jTab){
    var maxCol = 4;
    var wTab = $("<div id='tWeight'></div>");

    var colWidth = 460; //The size during development was 451px. 460px gives spacing between columns.
    var numCol = Math.floor($(document).width()/colWidth);
    if(numCol > maxCol){  //We don't want more than 3 columns.
        numCol = maxCol;
    }
    var numMetrics = 0;

    var metricsSorted = new Array();
    var metrics = new Array();
    for (var wMetric in weights ){
        if(weights.hasOwnProperty(wMetric)){
            metrics.push(mapMIDtoMName[wMetric]);
            numMetrics++;
        }
    }
    metricsSorted = metrics.sort(naturalSort);
    var numPerCol = Math.ceil(numMetrics/numCol);
    var curMetric = 0;
    var curCol = -1;
    var columns = [];
    for(var i = 0; i<metricsSorted.length; i++){
        var mID = mapMNametoMID[metricsSorted[i]];
        if(!(curMetric % numPerCol)){
            curCol++;
            columns.push($("<div style=\"display:table; border-spacing:10px;\"></div>"));
        }
        var divRow = $("<div style=\"display:table-row; width: "+colWidth+"px !important;\"></div>");
        var jSliderCell = $("<div style=\" display:table-cell; margin: 15px; vertical-align: middle;\"></div>");
        var jSlider = $("<div id='slider"+mID+"' style=\"width: 200px !important;  height=17px;\" ></div>");
        jSlider.slider({
            value: 0,
            range: "min",
            animate: true,
            orientation: "horizontal",
            slide: function( event, ui){
                slideChange(this, ui.value);
            }
        });
        jSliderCell.append(jSlider);
        divRow.append("<div style=\"display:table-cell;\">"+metricsSorted[i]+"</div>");
        divRow.append(jSliderCell);
        var spinCell = $("<div style=\"display:table-cell; \"></div>");
        var spin = $("<input id='spin"+mID+"' size='3'/>");
        spinCell.append(spin);
        divRow.append(spinCell);
        divRow.append("<div style=\"display:table-cell;\" id='perLabel"+mID+"'>100%</div>");
        columns[curCol].append(divRow);
        curMetric++;
    }
    var colTable = $("<div style=\"display:table; border-spacing: 9px;\"></div>");
    for(var i = 0; i<columns.length; i++){
        var col = $("<div style=\"display:table-cell;\"></div>");
        col.append(columns[i]);
        colTable.append(col);
    }
    wTab.append(colTable);
    wTab.append(   
        "<button type='button' id='btnWeightReset'>Reset Weights</button>"
    );
    wTab.append(   
        "<button type='button' id='btnWeightSetZero'>Zero Weights</button>"
    );
    wTab.append(   
        "<button type='button' id='btnWeightProcessAggr'>Recompute Aggregrate</button>"
    );
jTab.find("ul").append('<li><a href="#tWeight">Weights</a></li>');
    jTab.append(wTab);
    bindWeightTab();
}

function bindWeightTab(){
    $("input[id^=spin]").each(function(){
        $(this).spinner({
            max: 100,
            min: 0,
            change: function(event, ui){
                spinChange(this);
            },
            spin: function(event, ui){
                spinChange(this);
            }
        });
    });
    $("#btnWeightReset").on("click",function(){
        $("input[id^=spin]").each(function(){
            $(this).spinner("value", 50);
        });
    });
    $("#btnWeightSetZero").on("click",function(){
        $("input[id^=spin]").each(function(){
            $(this).spinner("value", 0);
        });
    });
    $("#btnWeightProcessAggr").on("click",function(){
        processAllAggr();
    });
}

function slideChange(slider, value){
    var spinID = "#spin"+$(slider).attr("id").slice(6);
    if($(spinID).spinner("value") != value){
        $(spinID).spinner("value",value);
    }
}

function spinChange(spin){
    var value = $(spin).spinner("value");
    var metricID = $(spin).attr("id").slice(4);
    var sliderID = "#slider"+metricID;
    if(!isInteger(value) || parseInt(value) != value){
        value = $(sliderID).slider("value"); //Slider should still have last value, so we change back to that.
        $(spin).spinner("value",value);
        alert("Please enter an integer from 0-100.");
    }
    if(value > 100){
        value = 100;
        $(spin).spinner("value",value);
    }
    if(value < 0){
        value = 0;
        $(spin).spinner("value",value);
    }
    if($(sliderID).slider("value") != value){
        $(sliderID).slider("value",value);
    }
    calcWeightPercent();
    weights[metricID] = value;
}

function calcWeightPercent(){
    //Calculate total value
    var weightTotal = 0;
    $("input[id^=spin]").each(function(){
        weightTotal = weightTotal + parseInt($(this).spinner("value"));
    });
    //Calculate and display each percentage
    $("input[id^=spin]").each(function(){
        var value = parseFloat($(this).spinner("value"));
        if(value <= 0){
            $("#perLabel"+$(this).attr("id").slice(4)).text("0%");
        }
        else{
            $("#perLabel"+$(this).attr("id").slice(4)).text((value/weightTotal*100).toFixed(1)+"%");
        }
    });
}

function addPercent(rowID, metricID, value){
    if(!isNaN(row[2])){ //Uncomputable values are sent as "n"
        /* Overlaps in percents could occur if both station 
        averages and channel averages are loaded on the same
        page. */
        if(percents[rowID] == undefined){ 
            percents[rowID] = {};
        }
        percents[rowID][metricID] = value;
        if(weights[metricID] == undefined){
            weights[metricID] = 0; //Placeholder value
        }

    }
}

function resetWeights(){
    $("input[id^=spin]").each(function(){
        $(this).spinner("value", 50);
    });
}

function calcAggr(rowID){
    var numMetrics = 0;
    var weightSum = 0;
    var aggr = 0;
    //Build sums and counts before computing aggregates
    for (var metric in percents[rowID] ){ //
        if(percents[rowID].hasOwnProperty(metric)){
            weightSum += weights[metric];
            numMetrics++;
        }
    }
    if(weightSum == 0){ //Means either all Metrics are weighted to 0, initial load, or no weighted metric data exists
        return 0;
    }
    for (var metric in percents[rowID] ){ //
        if(percents[rowID].hasOwnProperty(metric)){
            //Doesn't need to be multiplied by 100 because the weight already is
            var trueWeight = weights[metric] / weightSum;
            aggr += percents[rowID][metric] * trueWeight; 
        }
    }
    return aggr;

}

function processAllAggr(){
    var rows = dTable.fnGetNodes();
    for(var i = 0; i<rows.length; i++){
        var rowID = $(rows[i]).attr("id");

        var cell = document.getElementById("a_"+rowID);
        if(cell){
            var pos = dTable.fnGetPosition(cell);
            var aggrVal = parseFloat(parseFloat(calcAggr(rowID)).toFixed(2));
            setAggregateClass(cell, aggrVal);
            dTable.fnUpdate(aggrVal, pos[0], pos[2], false, false );
        }
    }
}

function setAggregateClass(cell, value){
    var jcell = $(cell);
    jcell.removeClass('aggrGreen');
    jcell.removeClass('aggrYellow');
    jcell.removeClass('aggrOrange');
    jcell.removeClass('aggrRed');

    if (value >= 90)
        jcell.addClass('aggrGreen');
    else if (value >= 80)
        jcell.addClass('aggrYellow');
    else if (value >= 70)
        jcell.addClass('aggrOrange');
    else
        jcell.addClass('aggrRed');
}

//We need to do this when we update the datatable.
function resetPercents(){
percents = {};
}
