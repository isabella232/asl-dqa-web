/*
header.js
Author: James Holland jholland@usgs.gov
header.js contains functions for creating the page's header
License: Public Domain
*/

function setupHeader(){
    var header = $("#header");

    $("#useriddiv").dialog({
        autoOpen: false,
        height: 200,
        width: 400,
        modal: true,
        buttons: {
            "Login": function() {
                var userid = $('#userid').val();
                getUserSettings(userid, loginCallback);
                $("#btnLogin").button( "option", "label", "Save" );
                $("#useriddiv").dialog("close");
            },
            Cancel: function () {
                $("#useriddiv").dialog("close");
            }
        }
    });

    if(pageType == "station"){
        header.append(
            "<button type='button' id='btnSummary'>Summary</button>"
        );
        $("#btnSummary").on("click",function(){
            window.location = summary_url + "?&sdate=" + getStartDate("simple") + "&edate=" + getEndDate("simple") + "&tdate=" + getDateType();
        });

        header.append(
            "<span id='spnTitle' class='headerTitle'></span>"
        );
    }
    else if(pageType == "summary"){
        header.append("<span class='headerTitle'>Station Summary</span>");

    }
    header.append("<span class='headerVersion'>v" + version + "</span>");

    header.append(
        "<button type='button' id='btnLegend'>Legend</button>"
    );

    $("#btnLegend").on("click",function(){
        $("#legend").dialog( "open" );
    });
    $("#legend").dialog({
        autoOpen: false,
        height: 650,
        width: 1000,
        modal: true
    });

    header.append(
        "<button type='button' id='btnScans' onclick=\"location.href=scans_url;\">Scans</button>"
    );

    //Adding span for dateRange now, but the dates and their controls will be added in the dateselection code.
    var rightSide = $("<span class='right'></span>");
    if(pageType == "summary"){
        rightSide.append(createGroupSelect("header"));
    }
    rightSide.append(createDateRangeSpan("header"));
    rightSide.append(
        "<button type='button' id='btnRefresh'>Update</button>"
    );
    header.append(rightSide);
    $("#btnRefresh").on("click",function(){
        refreshTable();
    });
    if(allow_user_settings){
        var buttonText = (username.length > 0) ? 'Logout' : 'Login';
        rightSide.append("<button type='button' id='btnLogin'>" + buttonText + "</button>");
        $("#btnLogin").on("click", function(){
            loginOrOut(this);
        });
        rightSide.append("<button type='button' id='btnSave'>Save Settings</button>");
        if(buttonText == 'Login'){
            $("#btnSave").hide();
        }
        $("#btnSave").on("click", function(){
            saveUserSettings();
        });
        rightSide.append("<span id='username'>" + username + "</span>");
    }
    //Adds the actual jqueryui datepicker controls and theme
    bindDateRangeSpan("header");
}

function loginCallback(){
    updateUserSettings();
    refreshTable();
}

//Must be called after setup data is parsed to get the station name
function setStationTitle(){
    var stationID = getQueryString("station");
    var networkID = getQueryString("network");
    var newTitle = networkID + "-" + stationID;
    $("#spnTitle").text(newTitle);
    document.title = "DQA "+newTitle;
}

function buildLegend(){
    var sorted_keys = Object.keys(mapMNametoMLong).sort()
    for (var i=0; i<sorted_keys.length; i++){
        $("#legendtable tbody").append('<tr><td>' + sorted_keys[i] + '</td><td>' + mapMNametoMLong[sorted_keys[i]] + '</td></tr>')
    }
}

function loginOrOut(buttonObject){
    var loginObject = $(buttonObject);
    if(loginObject.text() == 'Login'){
        window.location.href = login_url;
    }
    else {
        window.location.href = logout_url;
    }
}

function getUserSettings(userid, callback){
    $.get(settings_url + '?username=' + userid, function (returnedData) {
        userColumns = returnedData['user_settings']['columns'];
        userWeights = returnedData['user_settings']['weights'];
        userDateFormat = returnedData['user_settings']['date_format'];
        callback();
    });
}

function updateUserSettings(){
    if(userColumns.length > 0){
        $.each(dTable.fnSettings().aoColumns, function(c, value) {
            if(userColumns.includes(value.sTitle) || fixedColumns.includes(value.sTitle)){
                dTable.fnSetColumnVis(c, true);
            }
            else{
                dTable.fnSetColumnVis(c, false);
            }
        });
        updateCheckboxes();
    }
    if(Object.keys(userWeights).length > 0){
        for (const [key, value] of Object.entries(userWeights)) {
            weights[mapMNametoMID[key]] = value;
        }
        updateWeights();
    }
    if(Object.keys(userDateFormat) != ''){
        updateSettingsDate();
    }
}

function saveUserSettings() {
    var column_list = Array();
    $("div[id^=metricCB]").each(function () {
        var label_element = $(this).children("label").eq(0);
        var input_element = $(this).children("input").eq(0);
        if (input_element.prop("checked") == true) {
            column_list.push(label_element.text());
        }
    });
    var weight_list = {};
    for (var key in weights) {
        weight_list[mapMIDtoMName[key]] = weights[key]
    }
    var date_format = $("#dpFormatheader option:selected").val();

    var output = {user_settings: {columns: column_list, weights: weight_list, date_format: date_format}}
    $.post(settings_url, JSON.stringify(output),
    function (returnedData) {
    }, 'json');
}
