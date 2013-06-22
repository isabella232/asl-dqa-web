/*
column.js
Author: James Holland jholland@usgs.gov
column.js contains functions for column hiding and showing.
License: Public Domain
*/


function setupColumnTab(jTab, curTab){
    var eTab = $("<div id='tColumn' style=\"font-size: 12px\"></div>");
    jTab.tabs("add", "#tColumn", "Column");
}
