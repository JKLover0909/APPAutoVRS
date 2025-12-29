// ==UserScript==
// @name         OpenProject - Gantt RIGHT text colors by Status (TASK only)
// @namespace    http://tampermonkey.net/
// @version      2025-12-17
// @description  Color ONLY TEXT on Gantt right side (start date, end date, task name) by status; TASK type only; does NOT color bars.
// @author       You
// @match        http://192.168.0.115:8080/projects/*/gantt*
// @match        http://192.168.0.115:8080/projects/*/work_packages*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
  "use strict";

  const ONLY_TYPE = "task";

  // Use "bar" as the status color for TEXT on the right side
  const STATUS = {
    "new":         { rowBg: "#E3F2FD", bar: "#1E88E5" },
    "in progress": { rowBg: "#FFF8E1", bar: "#FFB300" },
    "resolved":    { rowBg: "#E8EAF6", bar: "#3949AB" },
    "review":      { rowBg: "#E0F2F1", bar: "#00897B" },
    "closed":      { rowBg: "#ECEFF1", bar: "#607D8B" },
    "follow":      { rowBg: "#E0F7FA", bar: "#00ACC1" },
    "cancel":      { rowBg: "#FFEBEE", bar: "#E53935" },
    "done":        { rowBg: "#E8F5E9", bar: "#43A047" },
    "reject":      { rowBg: "#FBE9E7", bar: "#D84315" },
  };

  // End date exceptions: keep default color (do not change)
  const END_DATE_KEEP = new Set(["new", "in progress", "review", "follow"]);

  const ROW_CLASS  = "tm-op-row";
  const PILL_CLASS = "tm-op-pill";

  // Old class from previous scripts (we remove it)
  const OLD_DATE_CLASS = "tm-op-dateBadge";
  const OLD_CR_CLASS   = "tm-op-containerRight";
  const OLD_BAR_CLASS  = "tm-op-bar";

  function norm(s) {
    return (s || "").replace(/\s+/g, " ").trim().toLowerCase();
  }

  function extractIdFromClass(el) {
    const cls = el?.className ? String(el.className) : "";
    const m = cls.match(/\bwp-row-(\d+)\b/);
    return m ? m[1] : null;
  }

  // ===== CSS (LEFT only) =====
  function injectCSS() {
    const style = document.createElement("style");
    style.textContent = `
      /* LEFT row coloring */
      .${ROW_CLASS}{
        background: var(--tm-row-bg) !important;
        box-shadow: inset 6px 0 0 var(--tm-bar) !important;
      }
      .${ROW_CLASS} td,
      .${ROW_CLASS} .wp-table--cell,
      .${ROW_CLASS} [role="cell"]{
        background: transparent !important;
      }

      /* Status pill (left) */
      .${PILL_CLASS}{
        display:inline-block;
        padding:2px 10px;
        border-radius:999px;
        font-weight:600;
        border:1px solid var(--tm-bar);
        background: rgba(255,255,255,0.75) !important;
      }
    `;
    document.head.appendChild(style);
  }

  // ===== META: wpId -> {type,status} from LEFT =====
  const meta = new Map();

  function findLeftRows() {
    const selectors = ["tbody tr", ".wp-table--row", ".wp--row", "[role='row']"];
    const all = Array.from(document.querySelectorAll(selectors.join(",")));

    // Exclude right timeline cells
    return all.filter(el => {
      if (!el) return false;
      if (el.classList?.contains("wp-timeline-cell")) return false;
      if (el.closest?.(".wp-timeline-cell")) return false;
      const id = el.getAttribute?.("data-work-package-id") || extractIdFromClass(el);
      return !!id;
    });
  }

  function findTypeCell(row) {
    return (
      row.querySelector("[data-column-id='type']") ||
      row.querySelector(".wp-table--cell.-type, .wp-table--cell.type, td.type") ||
      null
    );
  }

  function findStatusCell(row) {
    return (
      row.querySelector("[data-column-id='status']") ||
      row.querySelector(".wp-table--cell.-status, .wp-table--cell.status, td.status") ||
      null
    );
  }

  function readRowId(row) {
    return row.getAttribute?.("data-work-package-id") || extractIdFromClass(row);
  }

  function applyLeftRow(row, typeKey, statusKey) {
    const st = STATUS[statusKey];
    if (typeKey !== ONLY_TYPE || !st) return;

    const key = `${typeKey}|${statusKey}`;
    if (row.dataset.tmKey === key) return;

    row.dataset.tmKey = key;
    row.classList.add(ROW_CLASS);
    row.style.setProperty("--tm-row-bg", st.rowBg);
    row.style.setProperty("--tm-bar", st.bar);

    const statusCell = findStatusCell(row);
    if (statusCell) {
      const leaf = statusCell.querySelector("button, span, a, div") || statusCell;
      leaf?.classList?.add(PILL_CLASS);
    }
  }

  function scanLeft() {
    const rows = findLeftRows();
    for (const row of rows) {
      const id = readRowId(row);
      if (!id) continue;

      const typeKey = norm(findTypeCell(row)?.innerText || "");
      const statusKey = norm(findStatusCell(row)?.innerText || "");
      if (typeKey || statusKey) meta.set(id, { type: typeKey, status: statusKey });

      applyLeftRow(row, typeKey, statusKey);
    }
  }

  // ===== RIGHT: TEXT ONLY =====

  // Remove styles injected by older versions (so UI goes back to normal before recoloring text)
  function cleanupOldRightStyles(cell) {
    // Remove old classes on bars/containers if they exist
    cell.querySelectorAll("." + OLD_BAR_CLASS).forEach(el => el.classList.remove(OLD_BAR_CLASS));
    cell.querySelectorAll("." + OLD_CR_CLASS).forEach(el => el.classList.remove(OLD_CR_CLASS));

    // For all label-content inside the timeline cell, remove old date badge class and inline props we previously set
    cell.querySelectorAll(".label-content").forEach(el => {
      el.classList.remove(OLD_DATE_CLASS);

      // Remove inline styles that caused borders/backgrounds/rings
      [
        "background",
        "background-color",
        "background-image",
        "border",
        "border-left",
        "outline",
        "box-shadow",
        "opacity",
        "--tm-row-bg",
        "--tm-bar",
        "color"
      ].forEach(p => el.style.removeProperty(p));
    });

    // Also clear inline styles on containerRight if old scripts set them
    const cr = cell.querySelector(".containerRight");
    if (cr) {
      ["background", "background-color", "border", "border-left", "outline", "box-shadow", "opacity", "color"].forEach(p =>
        cr.style.removeProperty(p)
      );
    }
  }

  function setTextColor(el, color) {
    if (!el) return;
    el.style.setProperty("color", color, "important");
  }

  function colorRightText(cell, statusKey, statusColor) {
    // Start date: labelLeft + hoverLeft
    const startEls = cell.querySelectorAll(".labelLeft .label-content, .labelHoverLeft .label-content");
    startEls.forEach(el => setTextColor(el, statusColor));

    // Task name: labelFarRight (inside containerRight)
    const subjectEls = cell.querySelectorAll(".labelFarRight .label-content");
    subjectEls.forEach(el => setTextColor(el, statusColor));

    // End date: labelRight + hoverRight
    // Keep default if status is done/closed/resolved
    if (!END_DATE_KEEP.has(statusKey)) {
      const endEls = cell.querySelectorAll(".labelRight .label-content, .labelHoverRight .label-content");
      endEls.forEach(el => setTextColor(el, statusColor));
    }
  }

  function scanRight() {
    const cells = Array.from(document.querySelectorAll(".wp-timeline-cell[data-work-package-id]"));
    for (const cell of cells) {
      const id = cell.getAttribute("data-work-package-id");
      if (!id) continue;

      const m = meta.get(id);
      if (!m || m.type !== ONLY_TYPE) continue;

      const st = STATUS[m.status];
      if (!st) continue;

      // Clean old styles (prevents leftover borders/backgrounds from previous versions)
      cleanupOldRightStyles(cell);

      // Apply TEXT coloring only
      colorRightText(cell, m.status, st.bar);
    }
  }

  // ===== Scheduler (debounced) =====
  let timer = 0;
  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(() => {
      scanLeft();
      scanRight();
    }, 120);
  }

  function start() {
    injectCSS();

    // Initial + retries for async loading
    schedule();
    let tries = 0;
    const retry = setInterval(() => {
      schedule();
      tries++;
      if (tries >= 12) clearInterval(retry);
    }, 450);

    const root = document.querySelector("main") || document.body;
    const mo = new MutationObserver(() => schedule());
    mo.observe(root, { childList: true, subtree: true });

    document.addEventListener("click", schedule, true);
  }

  start();
})();
