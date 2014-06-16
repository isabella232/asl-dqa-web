/*
group.js
Author: James Holland jholland@usgs.gov
group.js contains functions for displaying stations by groupings.
License: Public Domain
*/

function setupGroupTab(jTab, typesSorted){
    var eTab = $("<div id='tGroup' style=\"font-size: 12px\"></div>");
    jTab.find("ul").append('<li><a href="#tGroup">Groups</a></li>');
    jTab.append(eTab);

    for(var i = 0; i < typesSorted.length; i++){
        var gType = $("<div></div>");
        gType.append($("<div>"+typesSorted[i]+"<div>"));
        var maxCol = 12;
        var colWidth = 140; //This size was left over from weight columns.
        //Number of columns can be overrun by the numPerCol. It fills columns until no items remain.
        var numCol = Math.floor($(document).width()/colWidth);
        if(numCol > maxCol){  //We don't want more than 3 columns.
            numCol = maxCol;
        }
        var numPerCol = Math.ceil((mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]].length + 1)/numCol);
        var curCol = -1; //If not -1 columns will skip 0
        var columns = [];
        var usedGroups = 0; //Tracks how many metrics are being displayed.
        for(var t = 0; t<mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]].length;t++){
            if(!(usedGroups % numPerCol)){
                curCol++;
                columns.push($("<div style=\"display:table; border-spacing:10px;\"></div>"));
            }
            var gID = mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]][t];
            var gName = mapGIDtoGName[mapTIDtoGIDs[mapTNametoTID[typesSorted[i]]][t]];
            columns[curCol].append(createGroupCheckbox(gName, gID));
            usedGroups++;
        }
        var colTable = $("<div style=\"display:table; border-spacing: 9px;\"></div>");
        for(var k = 0; k<columns.length; k++){
            var col = $("<div style=\"display:table-cell;\"></div>");
            col.append(columns[k]);
            colTable.append(col);
        }
        gType.append(colTable);
        eTab.append(gType);
    }
    eTab.append(
        "<button type='button' id='btnCheckGroups'>Check All</button>"
    );
    eTab.append(
        "<button type='button' id='btnUnCheckGroups'>Uncheck All</button>"
    );
    eTab.append(
        "<button type='button' id='btnFilterGroups'>Filter Table</button>"
    );
    bindGroupTab();
}

function createGroupCheckbox(label, groupID){
    var cbdiv = $("<div id='groupCB"+groupID+"'/>");
    cbdiv.append($("<input type='checkbox'/>"));
    cbdiv.append($("<label>"+label+"</label>"));
    return cbdiv;
}

function bindGroupTab(){
    $("div[id^=groupCB]").each(function(){
        $(this).find("label").on("click",function(){
            var checkbox = $(this).siblings("input[type=checkbox]");
            $(checkbox).prop("checked", !checkbox.prop("checked"));
        });
        $(this).find("input[type=checkbox]").on("click",function(){
        });
    });
    $("#btnCheckGroups").on("click",function(){
        $("div[id^=groupCB]").find("input[type=checkbox]").each(function(){
            $(this).prop("checked", true);
        });
    });
    $("#btnUnCheckGroups").on("click",function(){
        $("div[id^=groupCB]").find("input[type=checkbox]").each(function(){
            $(this).prop("checked", false);
        });
    });
    $("#btnFilterGroups").on("click",function(){
        filterGroups("TAB");
    });

    $("#ddlGroup").on("change",function(){
        filterGroups($(this).val());
    });
}

function filterGroups(command){
    if(command == "ALL"){
        dTable.fnFilter("");
        return;
    }
    else if (command == "TAB"){
        var filterString = "," 
        $("div[id^=groupCB]").each(function(){
            if($(this).find("input[type=checkbox]").prop("checked")){
                filterString += $(this).prop("id").slice(7)+",|,";
            }
        });
        dTable.fnFilter(filterString.slice(0,-2), 2, true, false);
        return;
    }
    else if(!isNaN(command)){
       dTable.fnFilter(command, 2, true, false);
       return;
    }

}

function createGroupSelect(id){
    var groupContainer = $("<span id='spanGroup"+id+"' class='ui-widget'></span>");
    return groupContainer;
}

function fillGroupSelects(typesSorted){

    $("[id^=spanGroup]").each(function(){
        var groupList = $("<select id='ddlGroup'></select>");
        groupList.append($("<option value='ALL'>All</option>"));
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
