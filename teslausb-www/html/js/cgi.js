// teslausb-ng — CGI / XHR helpers.
//
// Loaded as a classic <script> (not a module). Depends on log() and
// cachebustingurl() from js/utils.js, so utils.js MUST load first in
// index.html.
//
// Contents: readyState, starttailing, readfile, callcgi.

function readyState(state) {
  if (state == 0) {
    return "UNSENT";
  } else if (state == 1) {
    return "OPENED";
  } else if (state == 2) {
    return "HEADERS_RECEIVED";
  } else if (state == 3) {
    return "LOADING";
  } else if (state == 4) {
    return "DONE";
  } else {
    return "UNKNOWN";
  }
}

function starttailing({url, pre, button}) {
  if (!isElementVisible(pre)) {
    setTimeout(function() {
                            starttailing({url:url, pre:pre, button:button});
                          }, 1000);
    return;
  }
  log("tail " + url);
  if (pre.tailcorrection === undefined) {
    pre.tailcorrection=0;
  }
  var tailpos=pre.textContent.length - 1 + pre.tailcorrection;
  var request = new XMLHttpRequest();
  request.open('GET', cachebustingurl(url));
  request.setRequestHeader('Range', 'bytes=' + tailpos + '-' + (tailpos + 32768));
  request.onreadystatechange = function () {
    if (request.readyState === 4) {
      if (request.status === 206) {
        var left = pre.scrollLeft;
        var scrollpos=pre.scrollTop+pre.clientHeight;
        var scrollheight=pre.scrollHeight;
        var shouldgotobottom=(Math.abs(scrollpos-scrollheight) < 5)
        pre.appendChild(document.createTextNode(request.responseText.substring(1)));
        if (shouldgotobottom) {
          pre.scrollTo(left,pre.scrollHeight);
        }
        setTimeout(function() {
                                starttailing({url:url, pre:pre, button:button});
                              }, 500);
      } else if (request.status === 416) {
        /* log was truncated, find the end of the currently
           displayed log in the new remote log to determine
           the offset at which we should now read. */
        log('reloading truncated log: ' + tailpos);
        var newreq = new XMLHttpRequest();
        newreq.open('GET', cachebustingurl(url));
        newreq.onreadystatechange = function () {
          if (newreq.readyState === 4) {
            if (newreq.status === 200) {
              var len=pre.textContent.length;
              var lastshown=pre.textContent.substring(len-200,len);
              var newpos=newreq.responseText.indexOf(lastshown);
              if (newpos > 0) {
                pre.tailcorrection=-(len-(newpos+200));
                starttailing({url:url, pre:pre, button:button});
                return;
              }
            }
            log('could not read file "' + url + '", status: ' + request.status);
            pre.textContent="Attempting refresh..."
            pre.tailcorrection=0;
            readfile({url:url, pre:pre.id, button:button, tail:true});
          }
        }
        newreq.send();
      } else {
        log('unexpected status: ' + request.status);
      }
    }
  }
  request.send();
}

function readfile({url, callback, callbackarg, pre, tail, button}) {
  var request = new XMLHttpRequest();
  request.open('GET', cachebustingurl(url));
  log("reading " + url);
  request.onreadystatechange = function () {
    log(`read ${url}, result: ${request.status}, state: ${readyState(request.readyState)}`);
    if (request.readyState === 4 && request.status === 200) {
      var type = request.getResponseHeader('Content-Type');
      if (type.indexOf("text") !== 1) {
        if (callback != null) {
          callback(request.responseText, callbackarg);
        }
        if (pre != null) {
          var preobj = document.getElementById(pre);
          preobj.textContent=request.responseText;
          if (tail === true) {
            preobj.scrollTo(0,preobj.scrollHeight);
            starttailing({url:url, pre:preobj, button:button});
          }
        }
        if (button != null) {
          var btn = document.getElementById(button);
          btn.disabled=false;
        }
      }
    }
  }
  request.send();
}

function callcgi(url) {
  var request = new XMLHttpRequest();
  request.open('GET', cachebustingurl(url));
  request.onreadystatechange = function () {
    if (request.readyState === 4 && request.status === 200) {
      var type = request.getResponseHeader('Content-Type');
      if (type.indexOf("text") !== 1) {
        return request.responseText;
      }
    }
  }
  request.send();
}
