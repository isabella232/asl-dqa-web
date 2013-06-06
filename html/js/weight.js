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
    for (var wMetric in weights ){
        if(weights.hasOwnProperty(wMetric)){
            numMetrics++;
        }
    }
    var numPerCol = Math.ceil(numMetrics/numCol);
    var curMetric = 0;
    var curCol = -1;
    var columns = [];
    for (var wMetric in weights ){
        if(weights.hasOwnProperty(wMetric)){
            
            if(!(curMetric % numPerCol)){
                curCol++;
                columns.push($("<div style=\"display:table; border-spacing:10px;\"></div>"));
            }
            var divRow = $("<div style=\"display:table-row; width: "+colWidth+"px !important;\"></div>");
            var jSliderCell = $("<div style=\" display:table-cell; margin: 15px; vertical-align: middle;\"></div>");
            var jSlider = $("<div id='slider"+wMetric+"' style=\"width: 200px !important;  height=17px;\" ></div>");
            jSlider.slider({
                value: 50,
                range: "min",
                animate: true,
                orientation: "horizontal",
                change: function( event, ui){
                    slideChange(this, ui.value)
                }
            });
            jSliderCell.append(jSlider);
            divRow.append("<div style=\"display:table-cell;\">"+mapMIDtoMName[wMetric]+"</div>");
            divRow.append(jSliderCell);
            var spinCell = $("<div style=\"display:table-cell; \"></div>");
            var spin = $("<input id='spin"+wMetric+"' size='3'/>");
            spinCell.append(spin);
            divRow.append(spinCell);
            columns[curCol].append(divRow);
            curMetric++;
        }
    }
        var colTable = $("<div style=\"display:table; border-spacing: 9px;\"></div>");
    for(var i = 0; i<columns.length; i++){
        var col = $("<div style=\"display:table-cell;\"></div>");
        col.append(columns[i]);
        colTable.append(col);
    }
    wTab.append(colTable);
    jTab.append(wTab);
    jTab.tabs("add", "#tWeight", "Weights");
    bindWeightTab();
}

function bindWeightTab(){
    $("input[id^=spin]").each(function(){
        $(this).spinner();
    });
}

function slideChange(slider, value){
    var spinID = "#spin"+$(slider).attr("id").slice(6);
    if($(spinID).spinner("value") != value){
        $(spinID).spinner("value",value);
    }
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
    var numMetrics = 0;
    for (var wMetric in weights ){
        if(weights.hasOwnProperty(wMetric)){
            numMetrics++;
        }
    }

    for (var mWeight in weights ){
        if(weights.hasOwnProperty(mWeight)){
            weights[mWeight] = 100/numMetrics;
        }
    }
    return 100/numMetrics;
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
