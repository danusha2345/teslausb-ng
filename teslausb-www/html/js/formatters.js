// teslausb-ng — pure formatter helpers (v1.1.2 third slice).
//
// Extracted from the inline <script> block in index.html. All functions
// here are pure: no DOM access, no XHR, no shared mutable state beyond
// the four `Intl.DateTimeFormat` instances at the top.
//
// Loaded as a classic <script> early in <head>, so every other inline /
// extracted script (and the HTML `onclick` attributes that reference
// these symbols) can call them through the global scope.
//
// Contents:
//   byteRate(bytes_per_sec)        → "1.2 MB/s" / "640.0 KB/s"
//   bitRate(bytes_per_sec)         → "9.6 Mbit/s"
//   uptimeString(seconds)          → "2 days, 03:14:07"
//   spaceString(bytes)             → "120G" / "950M"
//   timeString(milliseconds)       → "1:23:45" or "23:45"
//   dateFromSeconds(unix_seconds)  → localized long date
//   dayNameFromDateString(yyyy-mm-dd) → localized weekday

function byteRate(speed) {
  if (speed > 500000) {
    return (speed / (1024 * 1024)).toFixed(1) + " MB/s";
  } else {
    return (speed / 1024).toFixed(1) + " KB/s";
  }
}

function bitRate(speed) {
  // for speeds under 20 Mbit, show one decimal
  return (speed * 8 / 1000000).toFixed(speed < 2500000 ? 1 : 0) + " Mbit/s";
}

function uptimeString(secs) {
  secs = Math.round(secs);
  var days = Math.trunc(secs / (24 * 3600));
  var hours = Math.trunc(secs % (24 * 3600) / 3600);
  var minutes = Math.trunc(secs % (3600) / 60);
  var seconds = Math.trunc(secs % 60);
  var out = "";
  if (days == 1) {
    out = "1 day, "
  } else if (days > 1) {
    out = days + " days, "
  }
  return out + hours.toString().padStart(2, 0) + ":" +
               minutes.toString().padStart(2,0) + ":" +
               seconds.toString().padStart(2,0);
}

function spaceString(bytes) {
  if (bytes > 1024 * 1024 * 1024) {
    return (bytes / (1024 * 1024 * 1024)).toFixed(0) + "G";
  } else if (bytes > 100 * 1024 * 1024) {
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + "G";
  } else {
    return (bytes / (1024 * 1024)).toFixed(0) + "M";
  }
}

function timeString(time_ms) {
  var seconds = parseInt(time_ms / 1000);
  var hours = parseInt(seconds / 3600);
  var minutes = parseInt((seconds % 3600) / 60);
  seconds = seconds % 60;
  var output = "";
  if (hours != 0) {
    output = hours + ":";
  }
  output = output + minutes.toString().padStart(2, "0") + ":";
  output = output + seconds.toString().padStart(2, "0");
  return output;
}

// Localized date formatters. `navigator.language` is available at <head>
// script-execution time, so reading it here at module load is safe.
const longDateOpts = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
const longDateFormat = new Intl.DateTimeFormat(navigator.language, longDateOpts);
const dayNameOpts = { weekday: 'long' };
const dayNameFormat = new Intl.DateTimeFormat(navigator.language, dayNameOpts);

function dateFromSeconds(seconds) {
  var d = new Date(0);
  d.setUTCSeconds(seconds);
  return longDateFormat.format(d);
}

function dayNameFromDateString(datestr) {
  /* force javascript's Date class to parse using local time
     by using yyyy/mm/dd notation instead of yyyy-mm-dd */
  var d = new Date(datestr.replaceAll("-", "/"));
  return dayNameFormat.format(d);
}
