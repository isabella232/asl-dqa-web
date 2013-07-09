/*
column.js
Author: James Holland jholland@usgs.gov
column.js contains functions for column hiding and showing.
License: Public Domain
*/

var colVis;
function setupColumnTab(jTab){
    var eTab = $("<div id='tColumn' style=\"font-size: 12px\"></div>");
    jTab.append(eTab);
    jTab.tabs("add", "#tColumn", "Column");

    var maxCol = 4;
    var colWidth = 460; //This size was left over from weight columns.
    var numCol = Math.floor($(document).width()/colWidth);
    if(numCol > maxCol){  //We don't want more than 3 columns.
        numCol = maxCol;
    }
    var metrics = dTable.fnSettings().aoColumns;
    var numPerCol = Math.ceil((metrics.length + 1)/numCol);
    var curCol = -1; //If not -1 columns will skip 0
    var columns = [];
    var usedMetrics = 0; //Tracks how many metrics are being displayed.
    for(var curMetric = 0; curMetric < metrics.length; curMetric++){
        if(!(usedMetrics % numPerCol)){
            curCol++;
            columns.push($("<div style=\"display:table; border-spacing:10px;\"></div>"));
        }
        if(metrics[curMetric].bVisible){  //If the column is hidden by default we don't want to let users view it. This applies to the groups column which is used for filtering.
            columns[curCol].append(createCheckbox(metrics[curMetric], curMetric));
            usedMetrics++;
        }
    }
    var colTable = $("<div style=\"display:table; border-spacing: 9px;\"></div>");
    for(var i = 0; i<columns.length; i++){
        var col = $("<div style=\"display:table-cell;\"></div>");
        col.append(columns[i]);
        colTable.append(col);
    }
    eTab.append(colTable);
    eTab.append(
        "<button type='button' id='btnCheckAll'>Show All</button>"
    );
    eTab.append(
        "<button type='button' id='btnUnCheckAll'>Hide All</button>"
    );
    bindColumnTab();
}

function createCheckbox(metricCol, colID){
    var cbdiv = $("<div id='metricCB"+colID+"'/>");
    cbdiv.append($("<input type='checkbox' checked='checked'/>"));
    cbdiv.append($("<label>"+metricCol.sTitle+"</label>"));
    return cbdiv;
}

function bindColumnTab(){
    $("div[id^=metricCB]").each(function(){
        $(this).find("label").on("click",function(){
            $(this).siblings("input").trigger("click"); //Scope changed "this" now refers to label we found.
        });
    });
    $("#btnCheckAll").on("click",function(){
    });
    $("#btnUnCheckAll").on("click",function(){
    });
}
