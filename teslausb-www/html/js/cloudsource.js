// Cloud-source viewer support (#1035 — cloudviewer-api).
//
// Additive and inert on the Pi. The Local/Cloud switch only appears when the
// page is served by the cloudviewer-api Docker stack AND that stack reports a
// configured cloud source (GET /api/v1/cloud/health -> {"enabled":true}).
// Everywhere else (the Pi's own web UI, or the Docker stack with cloud not
// configured) the switch stays hidden and the viewer behaves exactly like the
// local-only viewer it has always been: videolistUrl() resolves to the same
// cgi-bin/videolist.sh and mediaSrc() to the same cachebusted TeslaCam/ path.
//
// Loaded as a classic <script> after js/utils.js (needs localStorageGet/Set
// and cachebustingurl).

var videoSource = (localStorageGet("videosource") === "cloud") ? "cloud" : "local";

// Where the recording list is fetched from for the active source.
function videolistUrl() {
  return videoSource === "cloud" ? "/api/v1/cloud/videolist" : "cgi-bin/videolist.sh";
}

// URL a single media file is loaded from. relpath is "group/sequence/filename"
// (no leading "TeslaCam/"). For local the cloudviewer nginx and the Pi both
// serve it under TeslaCam/; for cloud the API streams it with Range support.
function mediaSrc(relpath) {
  if (videoSource === "cloud") {
    return "/api/v1/cloud/stream?path=" + encodeURIComponent(relpath);
  }
  return cachebustingurl("TeslaCam/" + relpath);
}

// Switch source and reload, so the one-shot list/dropdown init re-runs cleanly
// against the new source instead of trying to mutate live playback state.
function setVideoSource(src) {
  if (src !== "cloud") {
    src = "local";
  }
  localStorageSet("videosource", src);
  location.reload();
}

// Probe whether a cloud source is available here and reveal the switch if so.
function initCloudSource() {
  var request = new XMLHttpRequest();
  request.open('GET', '/api/v1/cloud/health');
  request.onreadystatechange = function() {
    if (request.readyState !== 4) {
      return;
    }
    var enabled = false;
    if (request.status === 200) {
      try {
        enabled = JSON.parse(request.responseText).enabled === true;
      } catch (e) {
        enabled = false;
      }
    }
    if (!enabled) {
      // No cloud source here (the Pi, or cloud not configured). Never leave the
      // viewer stuck on a stale cloud selection — fall back to local once.
      if (videoSource === "cloud") {
        localStorageSet("videosource", "local");
        location.reload();
      }
      return;
    }
    var sw = document.getElementById("videosourceswitch");
    if (sw) {
      sw.style.display = "";
    }
    var sel = document.getElementById("videosource_" + videoSource);
    if (sel) {
      sel.classList.add("selected");
    }
  };
  request.send();
}
