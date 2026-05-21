// teslausb-ng — recordings / video-layout functions (v1.1.2 second slice).
//
// Extracted from the inline <script> block in index.html. Loaded as a classic
// <script> AFTER utils.js (so it can call localStorageGet / localStorageSet)
// and BEFORE the existing inline code (so the inline calls
// `showcontrols()`, `setLayout(localStorageGet("layout"))`, and the HTML
// `onclick` attributes that reference these symbols still resolve through
// the global scope).
//
// Contents:
//   currentLayout (state)
//   hideRecordingParent, showDebugInfo, showcontrols,
//   setLayout, cycleLayout, skipBack, startPlaying, skipForward.
//
// Dependencies it expects on `window` at call time (NOT at file load —
// the call sites in the inline script run after the relevant DOM and
// other globals exist):
//   currentsequence (filled in by the inline script when video playback
//                    starts; setLayout / skip* guard with typeof checks)
//   videoelems, canvaselems (set up by the same playback code)
//   document.querySelector(".recordings"), #leftrepeaterview, etc.

var currentLayout = 1;

function hideRecordingParent() {
  var i = document.querySelector(".recordings");
  if (i.contentWindow.location.pathname === "/TeslaCam/") {
    var parentlink = i.contentDocument.querySelector("#list tbody tr");
    parentlink.parentElement.removeChild(parentlink);
  }
}

function showDebugInfo() {
  if (window.DEBUG === false || typeof window.DEBUG === "undefined") {
    return;
  }
  var db = document.getElementById('debuginfo');
  var debuginfo = "segments: " + currentsequence.currentSegmentIdx() + "/" + currentsequence.length();
  debuginfo += ", position: ";
  for (var vid of videoelems) {
    if (vid == undefined) {
      debuginfo = debuginfo + "unused/"
    } else {
      debuginfo = debuginfo + parseInt(vid.currentTime) + "/";
    }
  }
  db.innerText = debuginfo;
}

function showcontrols() {
  var c=document.getElementById("videocontrols");
  if (c.classList.contains("shown")) {
    return;
  }
  c.classList.add("shown");
  setTimeout(function() { c.classList.remove("shown"); }, 5000);
}

function setLayout(layout) {
  var leftrepeaterview = document.getElementById("leftrepeaterview");
  var leftpillarview = document.getElementById("leftpillarview");
  var rightrepeaterview = document.getElementById("rightrepeaterview");
  var rightpillarview = document.getElementById("rightpillarview");
  var backview = document.getElementById("backview");
  var videogrid = document.querySelector(".videoholder");

  if (layout == 3 || layout == 5 || layout == 6) {
    leftrepeaterview.classList.remove("flipped");
    rightrepeaterview.classList.remove("flipped");
    backview.classList.remove("flipped");
  }

  if (layout == 1) {
    // mirrorleft-front-mirrorright on top, map-mirrorrear-info on bottom
    leftrepeaterview.classList.add("flipped");
    rightrepeaterview.classList.add("flipped");
    backview.classList.add("flipped");
    videogrid.classList="videoholder layout1";
  } else if (layout == 2) {
    // map-front-info on top, mirrorleft-mirrorrear-mirrorright on bottom
    leftrepeaterview.classList.add("flipped");
    rightrepeaterview.classList.add("flipped");
    backview.classList.add("flipped");
    videogrid.classList="videoholder layout2";
  } else if (layout == 4) {
    // front on top, sides in middle, rear on bottom, mirrored
    leftrepeaterview.classList.add("flipped");
    rightrepeaterview.classList.add("flipped");
    backview.classList.add("flipped");
    videogrid.classList="videoholder layout4";
  } else if (layout == 5) {
    // front on top, sides in middle, rear on bottom
    videogrid.classList="videoholder layout5";
  } else if (layout == 6) {
    // map-front-info on top, pillars on the side, repeaters and rear on bottom
    videogrid.classList="videoholder layout6";
  } else {
    layout = 3;
    // (default) map-front-info on top, right-rear-left on bottom
    videogrid.classList="videoholder layout3";
  }
  currentLayout = layout;
  localStorageSet("layout", layout);

  var l = document.querySelector("#layouts.subnav-content");
  for (var i = 0; i < l.childElementCount; i++) {
    var item = l.children[i];
    if (i == (currentLayout - 1) ) {
      item.classList.add("selected");
    } else {
      item.classList.remove("selected");
    }
  }

  if (typeof currentsequence !== 'undefined') {
    setTimeout(function() {
      for (var i=0; i < 6;i++) {
        var v = videoelems[i];
        var c = canvaselems[i];

        if (v.clientWidth > 0 && v.clientHeight > 0) {
            c.width = v.clientWidth;
            c.height = v.clientHeight;
        }

        if (v.style.visibility == "hidden") {
           var ctx = c.getContext("2d");
           if (v.classList.contains("flipped")) {
             ctx.scale(-1, 1);
             ctx.drawImage(v, 0, 0, -c.width, c.height);
           } else {
             ctx.drawImage(v, 0, 0, c.width, c.height);
           }
        }
      }
    }, 50);
  }
}

function cycleLayout() {
  setLayout(currentLayout + 1);
}

function skipBack() {
  var slider=document.getElementById('position');
  currentsequence.seekTo(parseInt(slider.value) - 10000);
}

function startPlaying() {
  currentsequence.toggleplaypause();
}

function skipForward() {
  var slider=document.getElementById('position');
  currentsequence.seekTo(parseInt(slider.value) + 30000);
}
