/*
group.js
Author: James Holland jholland@usgs.gov
group.js contains functions for displaying stations by groupings.
License: Public Domain
*/

var groupVis;
function setupGroupTab(jTab, typesSorted){
    var eTab = $("<div id='tGroup' style=\"font-size: 12px\"></div>");
    jTab.find("ul").append('<li><a href="#tGroup">Groups</a></li>');
    jTab.append(eTab);

        for(var i = 0; i < typesSorted.length; i++){
            var gType = $("<div></div>");
            gType.append($("<div>"+typesSorted[i]+"<div>"));
            for(var t = 0; t<mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]].length;t++){
                var gID = mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]][t];
                var gName = mapGIDtoGName[mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]][t]];
                gType.append(createGroupCheckbox(gName, gID));
            }
            eTab.append(gType);
        }

        /*
    var maxCol = 8;
    var colWidth = 460; //This size was left over from weight columns.
    var numCol = Math.floor($(document).width()/colWidth);
    if(numCol > maxCol){  //We don't want more than 3 columns.
        numCol = maxCol;
    }
    var numPerCol = Math.ceil((metrics.length + 1)/numCol);
    var curCol = -1; //If not -1 columns will skip 0
    var columns = [];
    var usedGT = 0; //Tracks how many metrics are being displayed.
    for(var curMetric = 0; curMetric < metrics.length; curMetric++){
        if(!(usedMetrics % numPerCol)){
            curCol++;
            columns.push($("<div style=\"display:table; border-spacing:10px;\"></div>"));
        }
        if(metrics[curMetric].bVisible){  //If the column is hidden by default we don't want to let users view it. This applies to the groups column which is used for filtering.
            columns[curCol].append(createColumnCheckbox(metrics[curMetric], curMetric));
            usedMetrics++;
        }
    }
    var colTable = $("<div style=\"display:table; border-spacing: 9px;\"></div>");
    for(var i = 0; i<columns.length; i++){
        var col = $("<div style=\"display:table-cell;\"></div>");
        col.append(columns[i]);
        colTable.append(col);
    }*/
    eTab.append(
        "<button type='button' id='btnCheckAll'>Show All</button>"
    );
    eTab.append(
        "<button type='button' id='btnUnCheckAll'>Hide All</button>"
    );
    bindColumnTab();
}

function createGroupCheckbox(label, groupID){
    var cbdiv = $("<span id='groupCB"+groupID+"'/>");
    cbdiv.append($("<input type='checkbox' checked='checked'/>"));
    cbdiv.append($("<label>"+label+"</label>"));
    return cbdiv;
}

function bindGroupTab(){
    $("div[id^=metricCB]").each(function(){
        $(this).find("label").on("click",function(){
            var checkbox = $(this).siblings("input[type=checkbox]");
            $(checkbox).prop("checked", !checkbox.prop("checked"));
            setColVis(checkbox);
        });
        $(this).find("input[type=checkbox]").on("click",function(){
            setColVis(this);
        });
    });
    $("#btnCheckAll").on("click",function(){
        $("div[id^=metricCB]").find("input[type=checkbox]").each(function(){
            $(this).prop("checked", true);
            setColVis(this);
        });
    });
    $("#btnUnCheckAll").on("click",function(){
        $("div[id^=metricCB]").find("input[type=checkbox]").each(function(){
            $(this).prop("checked", false);
            setColVis(this);
        });
    });
}

function setGroupVis(checkbox){
    var colID = $(checkbox).parent().attr("id").slice(8);
    dTable.fnSetColumnVis(colID, $(checkbox).prop("checked"));
}

function createGroupSelect(id){
    var groupContainer = $("<span id='spanGroup"+id+"' class='ui-widget'></span>");
    return groupContainer;
}

function fillGroupSelects(typesSorted){

    $("[id^=spanGroup]").each(function(){
        var groupList = $("<select id='ddlGroup'></select>");
        groupList.append($("<option value=0>All</option>"));
        for(var i = 0; i < typesSorted.length; i++){
            var optGroup = document.createElement('optgroup');
            optGroup.label = typesSorted[i];
            groupList.append(optGroup);
            for(var t = 0; t<mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]].length;t++){
                var option = document.createElement("option")
                option.value = mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]][t];
                option.innerHTML = mapGIDtoGName[mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]][t]];
                optGroup.appendChild(option);
            }
        }
        $(this).append(groupList);
    });
    return;
}

function setupGroups(jTab){
    var typesSorted = new Array();
    var types = new Array();
    for(var groupType in mapTNametoTID){ //puts the group types into an array that can be sorted
        if(mapTNametoTID.hasOwnProperty(groupType)){
            types.push(groupType);
        }
    }
    typesSorted = types.sort();
    fillGroupSelects(typesSorted);

    setupGroupTab(jTab, typesSorted);
    return;
}
