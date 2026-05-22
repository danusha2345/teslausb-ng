// teslausb-ng — network speed-test UI (v1.1.2 fourth slice).
//
// Extracted from the inline <script> block in index.html. Loaded as a
// classic <script> AFTER utils.js (log, isElementVisible) and
// formatters.js (byteRate, bitRate). The HTML
// `onclick="startspeedtest(this)"` button resolves these through global
// scope.
//
// Contents:
//   Speedometer (rolling-average class)
//   totalRandom / randomReader / speedometer / lastTotalRandom / spinAngle (state)
//   showspeed, updatespeedspinner, startspeedtest, stopspeedtest
//
// The speed test streams cgi-bin/randomdata.sh and measures throughput
// client-side. setbuttonsdisabled() stays in index.html — it's a generic
// UI helper shared with the BLE-pairing and reboot flows, not speed-test
// specific.

class Speedometer {
  amount;
  time;
  maxlength;

  constructor(maxlength) {
    this.maxlength = maxlength;
    this.amount = [0];
    this.time = [Date.now()];
  }

  addValue(value) {
    this.amount.push(value);
    this.time.push(Date.now());
    if (this.amount.length > this.maxlength) {
      this.amount.shift();
      this.time.shift();
    }
  }

  getRecentAverage() {
    if (this.time.length > 1) {
      var timeDelta = this.time[this.time.length - 1] - this.time[0];
      var amountDelta = this.amount[this.amount.length - 1] - this.amount[0];
      return 1000 * amountDelta / timeDelta;
    }
    return 0;
  }
}

var totalRandom;
var randomReader = undefined;
var speedometer;
var lastTotalRandom = 0;
var spinAngle = 0;

function showspeed(button, indicator, spinner) {
  if (randomReader != undefined) {
    if (isElementVisible(button)) {
      speedometer.addValue(totalRandom);
      var speed = speedometer.getRecentAverage();
      var speedstring = byteRate(speed) + " (" + bitRate(speed) + ")";
      indicator.textContent = speedstring;
      setTimeout(showspeed, 1000, button, indicator, spinner);
    } else {
      stopspeedtest(button, indicator, spinner);
    }
  }
}

function updatespeedspinner(spinner) {
  if (randomReader != undefined) {
    if (totalRandom != lastTotalRandom) {
      lastTotalRandom = totalRandom;
      spinAngle += 36;
      spinner.setAttribute('transform', 'rotate('+ spinAngle + ')');
    }
    setTimeout(updatespeedspinner, 80, spinner)
  }
}

function startspeedtest(button) {
  var indicator = document.getElementById("speedtext");
  var spinner = document.getElementById('speedspinner');
  if (randomReader == undefined) {
    log("starting speed test");
    button.textContent="Stop network speed test";
    spinner.style.visibility = "inherit";
    (async () => {
      const randomStream = await fetch('cgi-bin/randomdata.sh')
      randomReader = await randomStream.body.getReader()
      totalRandom = 0;
      speedometer = new Speedometer(5);
      setTimeout(showspeed, 1000, button, indicator, spinner);
      setTimeout(updatespeedspinner, 100, spinner);

      randomReader.read().then(function receiveRandomChunk({ done, value }) {
        if (done) {
          log("speed test end");
          return
        }
        totalRandom += value.length;
        return randomReader.read().then(receiveRandomChunk)
      })
    })()
  } else {
    stopspeedtest(button, indicator, spinner);
  }
}

function stopspeedtest(button, indicator, spinner) {
  if (randomReader != undefined) {
    log("stopping speed test");
    try {
      randomReader.cancel();
    } catch (error) {
      log(error);
    }
    randomReader = undefined;
    button.textContent="Run network speed test";
    indicator.textContent = "";
    spinner.style.visibility = "hidden";
  }
}
