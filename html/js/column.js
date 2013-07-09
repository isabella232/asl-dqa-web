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
    var colWidth = 460; //The size during development was 451px. 460px gives spacing between columns.
    var numCol = Math.floor($(document).width()/colWidth);
    if(numCol > maxCol){  //We don't want more than 3 columns.
        numCol = maxCol;
    }
    var metrics = dTable.fnSettings().aoColumns;
    var numPerCol = Math.ceil((metrics.length + 1)/numCol);
    var curMetric = 0;
    var curCol = -1;
    var columns = [];
    for(; curMetric < metrics.length; curMetric++){
        if(!(curMetric % numPerCol)){
            curCol++;
            columns.push($("<div style=\"display:table; border-spacing:10px;\"></div>"));
        }
        if(metrics[curMetric].bVisible){
            columns[curCol].append(createCheckbox(metrics[curMetric], curMetric));
        }
    }
    var colTable = $("<div style=\"display:table; border-spacing: 9px;\"></div>");
    for(var i = 0; i<columns.length; i++){
        var col = $("<div style=\"display:table-cell;\"></div>");
        col.append(columns[i]);
        colTable.append(col);
    }
    eTab.append(colTable);
//    jTab.on( "tabsactivate", function(event, ui){
    //colVis.fnRebuild();
//    });
}
/*    wTab.append(colTable);
    wTab.append(   
        "<button type='button' id='btnWeightReset'>Reset Weights</button>"
    );
    wTab.append(   
        "<button type='button' id='btnWeightSetZero'>Zero Weights</button>"
    );
    wTab.append(   
        "<button type='button' id='btnWeightProcessAggr'>Recompute Aggregrate</button>"
    );
    jTab.append(wTab);
    jTab.tabs("add", "#tWeight", "Weights");
    bindWeightTab();*/

function createCheckbox(metricCol, colID){
    var cbdiv = $("<div id='metricCB"+colID+"'/>");
    cbdiv.append($("<input type='checkbox'/>"));
    cbdiv.append($("<label>"+metricCol.sTitle+"</label>"));
    return cbdiv;
}
