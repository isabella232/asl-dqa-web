/*
progressbar.js
Author: James Holland jholland@usgs.gov
progressbar.js contains functions for displaying a progress bar during ajax queries.
License: Public Domain
*/

$(function() {
    var progress = $("#dlgprogressbar").dialog({
        height: $(document).height(),
        width: $(document).width(),
        resizable: false,
        overlay: {
            opacity: 0.5,
            background: "black"
        },
        closeOnEscape: false,
        dialogClass: 'noTitle noBackGround',
        modal: true
    });
    progress.append($('<div id="progressbar"><div class="progress-label">Loading...</div></div>').progressbar({value: false}));
    progress.dialog("moveToTop");
    $(document).ajaxStop(function () {
        progress.dialog("close");
    });
});
