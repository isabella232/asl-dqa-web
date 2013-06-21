/*
export.js
Author: James Holland jholland@usgs.gov
export.js contains functions for exporting the data from the datatables to various formats, such as CSV or PDF
License: Public Domain
*/

var tabTools;

function setupExportTab(jTab, curTab){
    var eTab = $("<div id='tExport' style=\"font-size: 12px\"></div>");
    //Change the TableTool defaults prior to creating tabTools.
    //Using the method specified here datatables/extras/TableTools/alt_init.html does not work.
    tabTools = new TableTools(dTable, {
    "aButtons":  [ 
                {
                    "sExtends":"copy",
                    "fnInit": function(node){formatTableTools(node, 'ui-icon-clipboard');}
                },
                {
                    "sExtends":"print",
                    "fnInit": function(node){formatTableTools(node, 'ui-icon-print');}
                },
                {
                    "sExtends":"csv",
                    "fnInit": function(node){formatTableTools(node, 'ui-icon-calculator');}
                },
                {
                    "sExtends":"pdf",
                    "fnInit": function(node){formatTableTools(node, 'ui-icon-copy');}
                }
            ]

    });
    jTab.tabs("add", "#tExport", "Export");
    $("#tExport").append(tabTools.dom.container);
    jTab.on( "tabsactivate", function(event, ui){
        tabTools.fnResizeButtons();
    });
}
