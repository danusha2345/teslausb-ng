// teslausb-ng — settings modal (v1.1.2 fifth slice).
//
// Extracted from the inline <script> block in index.html. Loaded as a
// classic <script> AFTER utils.js (localStorageGet / localStorageSet).
// The HTML `onclick="cancelsettings()"` / `onclick="confirmsettings()"`
// buttons and the `settingsbtn.onclick = showsettings` / `closebutton.onclick
// = closesettings` assignments in the inline `initialize()` all resolve
// through global scope.
//
// Contents: showsettings, closesettings, cancelsettings, confirmsettings.
// (readconfig / initialize stay inline — they're bootstrap glue coupled to
// FileBrowser, the tab DOM, and the status-poll functions.)

function showsettings() {
  var altui = document.getElementById('altui');
  altui.checked = (localStorageGet("usealtui") == "true");
  var disablepreloadvideoclips = document.getElementById('disablepreloadvideoclips');
  disablepreloadvideoclips.checked = (localStorageGet("disablepreloadvideoclips") == "true");
  var overlay = document.getElementById("settingsoverlay");
  overlay.style.display = "block";
}

function closesettings() {
  var overlay = document.getElementById("settingsoverlay");
  overlay.style.display = "none";
}

function cancelsettings() {
  closesettings();
}

function confirmsettings() {
  var usealtui = document.getElementById('altui').checked;
  localStorageSet("usealtui", usealtui);
  if (usealtui) {
    document.location.replace('/new/?source=legacy');
    nonExistentFunction();
  }
  var disablepreloadvideoclips = document.getElementById('disablepreloadvideoclips').checked;
  localStorageSet("disablepreloadvideoclips", disablepreloadvideoclips);
  closesettings();
}
