/*
tabs.js
Author: James Holland jholland@usgs.gov
tabs.js contains functions related to the tab control.
License: Public Domain
*/


function setupTabs() {
    var jtab = $("#tabs");
    jtab.append("<ul></ul>");
    jtab.tabs({
        collapsible: true
    });
    var curTab = 0;
    setupWeightTab(jtab);
    curTab++;
    setupExportTab(jtab, curTab);
    //setupColumnTab(jtab);
    //setupGroupTab(jtab);
    jtab.tabs( "option", "selected", -1);  //Have to select -1 so that the tabs are collapsed.
}
