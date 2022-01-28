/*
column.js
Author: James Holland jholland@usgs.gov
column.js contains functions for column hiding and showing.
License: Public Domain
*/

function setupColumnTab(jTab){
    var eTab = $("<div id='tColumn' style=\"font-size: 12px\"></div>");
    jTab.find("ul").append('<li><a href="#tColumn">Columns</a></li>');
    jTab.append(eTab);

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
        if(metrics[curMetric].sTitle != 'Groups'){  //If the column is hidden by default we don't want to let users view it. This applies to the groups column which is used for filtering.
            columns[curCol].append(createColumnCheckbox(metrics[curMetric], curMetric));
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

function createColumnCheckbox(metricCol, colID){
    var checked = '';
    if(metricCol.bVisible)
        checked = "checked='checked'";
    var cbdiv = $("<div id='metricCB"+colID+"'/>");
    cbdiv.append($("<input type='checkbox' " + checked + "/>"));
    cbdiv.append($("<label>"+metricCol.sTitle+"</label>"));
    return cbdiv;
}

function bindColumnTab(){
    $("div[id^=metricCB]").each(function(){
        $(this).find("label").on("click",function(){
            var checkbox = $(this).siblings("input[type=checkbox]");
            $(checkbox).prop("checked", !checkbox.prop("checked"));
            setColVis(checkbox);
            refreshTable();
        });
        $(this).find("input[type=checkbox]").on("click",function(){
            setColVis(this);
            refreshTable();
        });
    });
    $("#btnCheckAll").on("click",function(){
        $("div[id^=metricCB]").find("input[type=checkbox]").each(function(){
            $(this).prop("checked", true);
            setColVis(this);
        });
    });
    $("#btnUnCheckAll").on("click",function(){
        $("div[id^=metricCB]").each(function(){
            var label_element = $(this).children("label").eq(0);
            if(fixedColumns.includes(label_element.text()))
                return true
            var input_element = $(this).children("input").eq(0);
            input_element.prop("checked", false);
            setColVis(input_element);
        });
    });
}

function setColVis(checkbox){
    var colID = $(checkbox).parent().prop("id").slice(8);
    dTable.fnSetColumnVis(colID, $(checkbox).prop("checked"));
}

function updateCheckboxes(){
    $("div[id^=metricCB]").each(function(){
        var label_element = $(this).children("label").eq(0);
        var state = false;
        if(userColumns.includes(label_element.text()) || fixedColumns.includes(label_element.text())){
            state = true;
        }
        var input_element = $(this).children("input").eq(0);
        input_element.prop("checked", state);
        setColVis(input_element);
    });
}
