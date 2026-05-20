// teslausb-ng — shared utility functions.
//
// Loaded as a classic <script> (not a module) so the existing inline
// <script> block in index.html can keep calling these without any
// import boilerplate. v1.1.2 extracts utilities a chunk at a time;
// each follow-up moves more functions out of index.html into js/*.
//
// Contents: localStorageGet / localStorageSet, log, download,
//           cachebustingurl, isElementVisible.

function localStorageGet(name) {
  try {
    return localStorage.getItem(name);
  } catch (error) {
    log(error);
  }
}

function localStorageSet(name, value) {
  try {
    localStorage.setItem(name, value);
  } catch (error) {
    log(error);
  }
}

function log(what) {
  if (window.DEBUG) {
    console.log(what);
  }
}

function download(filename, text) {
  var elem = document.createElement('a');
  elem.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
  elem.setAttribute('download', filename);
  elem.style.display = 'none';
  document.body.appendChild(elem);
  elem.click();
  document.body.removeChild(elem);
}

function cachebustingurl(url) {
  return url + '?' + Math.random();
}

function isElementVisible(elem) {
  return !(window.getComputedStyle(elem).visibility === "hidden");
}
