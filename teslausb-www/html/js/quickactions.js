// Quick-actions panel for BLE-controlled Tesla commands.
//
// On page load, probes /cgi-bin/ble_action.sh?action=status. If BLE is
// configured server-side, reveals the panel and wires up the buttons.
// Otherwise the panel stays hidden — no error, no console noise.
//
// Each button is debounced (disabled while the request is in flight) and
// shows ✓ on success / ✗ on failure for 2s before resetting. The panel is
// a single ES module imported via <script type="module">.

(async function init() {
  const panel = document.getElementById("quick-actions-panel");
  if (!panel) return;

  let status;
  try {
    const res = await fetch("cgi-bin/ble_action.sh?action=status", {
      cache: "no-store",
    });
    status = await res.json();
  } catch {
    // CGI unreachable — leave the panel hidden.
    return;
  }
  if (!status?.ble_enabled) {
    return;
  }

  panel.hidden = false;

  for (const btn of panel.querySelectorAll("button[data-ble-action]")) {
    btn.addEventListener("click", () => runAction(btn));
  }
})();

async function runAction(btn) {
  const action = btn.dataset.bleAction;
  if (!action) return;

  const orig = btn.textContent;
  btn.disabled = true;
  btn.textContent = "⏳ " + orig;

  let ok = false;
  try {
    const res = await fetch(
      "cgi-bin/ble_action.sh?action=" + encodeURIComponent(action),
      { method: "POST" }
    );
    const body = await res.json();
    ok = Boolean(body?.ok);
  } catch {
    ok = false;
  }

  btn.textContent = (ok ? "✓ " : "✗ ") + orig;
  setTimeout(() => {
    btn.textContent = orig;
    btn.disabled = false;
  }, 2000);
}
