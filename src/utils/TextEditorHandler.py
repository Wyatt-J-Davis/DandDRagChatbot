import streamlit.components.v1 as components
from streamlit_quill import st_quill

# Quill renders inside a sandboxed (but same-origin) component iframe, so
# page-level CSS cannot reach it. These styles are injected directly into the
# Quill iframe's document instead.

# Caps the editor at a fixed height so the iframe stops growing with content:
# the text area scrolls internally while the toolbar stays pinned in view.
_LAYOUT_CSS = """
.ql-toolbar.ql-snow { position: sticky; top: 0; z-index: 2; background: #ffffff; }
.ql-container.ql-snow { height: __HEIGHT__px !important; position: relative; }
.ql-editor { height: 100% !important; overflow-y: auto !important; }
#dandd-quill-resize {
    position: absolute; right: 1px; bottom: 1px;
    width: 18px; height: 18px; z-index: 5;
    cursor: nwse-resize; opacity: 0.55; touch-action: none;
    background: repeating-linear-gradient(135deg,
        rgba(128,128,128,0) 0 2px, rgba(128,128,128,0.75) 2px 4px);
}
#dandd-quill-resize:hover { opacity: 1; }
"""

_DARK_CSS = """
.ql-toolbar.ql-snow, .ql-container.ql-snow { border-color: #3a3a3a !important; }
.ql-container, .ql-editor { background: #1e1e1e !important; color: #e0e0e0 !important; }
.ql-editor.ql-blank::before { color: #777 !important; }
.ql-toolbar.ql-snow { background: #2a2a2a !important; }
.ql-snow .ql-stroke { stroke: #cfcfcf !important; }
.ql-snow .ql-fill, .ql-snow .ql-stroke.ql-fill { fill: #cfcfcf !important; }
.ql-snow .ql-picker { color: #cfcfcf !important; }
.ql-snow .ql-picker-options { background: #2a2a2a !important; border-color: #3a3a3a !important; }
.ql-snow.ql-toolbar button:hover .ql-stroke,
.ql-snow .ql-toolbar button:hover .ql-stroke { stroke: #ffffff !important; }
.ql-snow.ql-toolbar button:hover .ql-fill,
.ql-snow .ql-toolbar button:hover .ql-fill { fill: #ffffff !important; }
a { color: #6cb6ff !important; }
body { background: #1e1e1e !important; }
"""

# Polls for the same-origin Quill iframe and keeps the layout stylesheet (and,
# when enabled, the dark one) present. Re-applied on an interval so it survives
# Quill re-mounting on Streamlit reruns. The same poll restores and tracks the
# editor's scroll position and drag-resized dimensions via localStorage so they
# survive page switches (same SPA top window) and app restarts (same origin).
_THEME_SCRIPT = """
<script>
(function() {
    var DARK = __DARK__;
    var LAYOUT_ID = 'dandd-quill-layout';
    var DARK_ID = 'dandd-quill-dark';
    var SIZE_ID = 'dandd-quill-size-style';
    var SCROLL_KEY = 'dandd-quill-scroll';
    var SIZE_KEY = 'dandd-quill-size';
    var LAYOUT_CSS = `__LAYOUT_CSS__`;
    var DARK_CSS = `__DARK_CSS__`;

    function findQuillFrame() {
        try {
            var iframes = window.parent.document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
                var f = iframes[i];
                var ref = (f.getAttribute('src') || '') + '|' + (f.getAttribute('title') || '');
                if (ref.indexOf('streamlit_quill') !== -1) return f;
            }
        } catch (e) {}
        return null;
    }

    function findQuillDoc() {
        var f = findQuillFrame();
        return f ? f.contentDocument : null;
    }

    function ensure(doc, id, css) {
        var el = doc.getElementById(id);
        if (!el) {
            el = doc.createElement('style');
            el.id = id;
            doc.head.appendChild(el);
        }
        if (el.textContent !== css) el.textContent = css;
    }

    function remove(doc, id) {
        var el = doc.getElementById(id);
        if (el) el.parentNode.removeChild(el);
    }

    // Top-window localStorage outlives the per-page component iframe, so the
    // scroll position and editor size survive page switches and restarts.
    function prefStore() {
        try { return window.parent.localStorage; } catch (e) {}
        try { return window.localStorage; } catch (e) {}
        return null;
    }

    function manageScroll(doc) {
        var el = doc.querySelector('.ql-editor');
        if (!el) return;
        var win = doc.defaultView || window;

        if (!el.__scrollBound) {
            el.__scrollBound = true;
            el.addEventListener('scroll', function() {
                // Hold off saving until the stored target has been restored,
                // otherwise a pre-restore scroll would overwrite it.
                if (!el.__scrollRestored) return;
                if (el.__scrollRaf) return;
                var schedule = win.requestAnimationFrame || function(cb) { return win.setTimeout(cb, 16); };
                el.__scrollRaf = schedule(function() {
                    el.__scrollRaf = 0;
                    var s = prefStore();
                    if (s) { try { s.setItem(SCROLL_KEY, String(Math.round(el.scrollTop))); } catch (e) {} }
                });
            });
        }

        if (el.__scrollRestored) return;
        el.__scrollTries = (el.__scrollTries || 0) + 1;
        var s = prefStore();
        if (!s) { el.__scrollRestored = true; return; }
        var raw = null;
        try { raw = s.getItem(SCROLL_KEY); } catch (e) {}
        var target = parseInt(raw, 10);
        if (!raw || isNaN(target) || target <= 0) { el.__scrollRestored = true; return; }
        if (el.scrollHeight > el.clientHeight) {
            el.scrollTop = target;
            var maxScroll = el.scrollHeight - el.clientHeight;
            if (el.scrollTop >= Math.min(target, maxScroll) - 1) el.__scrollRestored = true;
        }
        // Stop retrying after ~3s so a never-scrollable note still enables saving.
        if (!el.__scrollRestored && el.__scrollTries >= 12) el.__scrollRestored = true;
    }

    function readSize() {
        var s = prefStore();
        if (!s) return null;
        var raw = null;
        try { raw = s.getItem(SIZE_KEY); } catch (e) {}
        if (!raw) return null;
        try {
            var o = JSON.parse(raw);
            if (o && typeof o === 'object') return o;
        } catch (e) {}
        return null;
    }

    function writeSize(w, h) {
        var s = prefStore();
        if (!s) return;
        try { s.setItem(SIZE_KEY, JSON.stringify({ w: w, h: h })); } catch (e) {}
    }

    function setWidth(frame, w) {
        if (!frame || !(w > 0)) return;
        frame.style.width = w + 'px';
        frame.style.maxWidth = w + 'px';
        frame.style.minWidth = '0px';
        // Keep the narrowed iframe centred in its full-width container; resizing
        // from the corner then grows/shrinks it symmetrically about the centre.
        frame.style.display = 'block';
        frame.style.marginLeft = 'auto';
        frame.style.marginRight = 'auto';
    }

    function setHeight(doc, h) {
        if (!(h > 0)) return;
        ensure(doc, SIZE_ID, '.ql-container.ql-snow { height: ' + h + 'px !important; }');
    }

    // The grip lives at the editor's bottom-right corner. Width is applied to
    // the Quill iframe element (parent doc); height overrides .ql-container in
    // the Quill doc, mirroring how the static layout sets it.
    function bindResize(frame, doc) {
        var cont = doc.querySelector('.ql-container.ql-snow');
        if (!cont) return;
        var handle = doc.getElementById('dandd-quill-resize');
        if (!handle) {
            handle = doc.createElement('div');
            handle.id = 'dandd-quill-resize';
            handle.title = 'Drag to resize the editor';
            cont.appendChild(handle);
        }
        if (handle.__resizeBound) return;
        handle.__resizeBound = true;

        var startX = 0, startY = 0, startW = 0, startH = 0;

        function onMove(e) {
            var w = Math.max(320, Math.min(2400, startW + (e.clientX - startX)));
            var h = Math.max(200, Math.min(2400, startH + (e.clientY - startY)));
            setWidth(frame, w);
            setHeight(doc, h);
            cont.__lastW = w; cont.__lastH = h;
            e.preventDefault();
        }
        function onUp(e) {
            cont.__resizing = false;
            doc.body.style.userSelect = '';
            try { handle.releasePointerCapture(e.pointerId); } catch (err) {}
            handle.removeEventListener('pointermove', onMove);
            handle.removeEventListener('pointerup', onUp);
            handle.removeEventListener('pointercancel', onUp);
            if (cont.__lastW && cont.__lastH) writeSize(cont.__lastW, cont.__lastH);
        }
        handle.addEventListener('pointerdown', function(e) {
            startX = e.clientX;
            startY = e.clientY;
            startW = frame ? frame.getBoundingClientRect().width : cont.getBoundingClientRect().width;
            startH = cont.clientHeight;
            cont.__lastW = startW; cont.__lastH = startH;
            cont.__resizing = true;
            doc.body.style.userSelect = 'none';
            try { handle.setPointerCapture(e.pointerId); } catch (err) {}
            handle.addEventListener('pointermove', onMove);
            handle.addEventListener('pointerup', onUp);
            handle.addEventListener('pointercancel', onUp);
            e.preventDefault();
        });
    }

    function applySize(frame, doc) {
        var cont = doc.querySelector('.ql-container.ql-snow');
        if (!cont || cont.__resizing) return;
        var sz = readSize();
        if (!sz) return;
        if (typeof sz.w === 'number') setWidth(frame, sz.w);
        if (typeof sz.h === 'number') setHeight(doc, sz.h);
    }

    function apply() {
        var frame = findQuillFrame();
        var doc = frame ? frame.contentDocument : findQuillDoc();
        if (!doc || !doc.head) return;
        ensure(doc, LAYOUT_ID, LAYOUT_CSS);
        if (DARK) ensure(doc, DARK_ID, DARK_CSS);
        else remove(doc, DARK_ID);
        manageScroll(doc);
        bindResize(frame, doc);
        applySize(frame, doc);
    }

    var n = 0;
    var iv = setInterval(function() {
        apply();
        if (++n > 40) clearInterval(iv);
    }, 250);
})();
</script>
"""


class TextEditorHandler:
    def render(
        self,
        key: str,
        initial_value: str = "",
        height: int = 600,
        dark_mode: bool = False,
    ) -> str:
        content = st_quill(
            value=initial_value,
            html=True,
            key=key,
        )
        layout_css = _LAYOUT_CSS.replace("__HEIGHT__", str(int(height)))
        script = (
            _THEME_SCRIPT
            .replace("__DARK__", "true" if dark_mode else "false")
            .replace("__LAYOUT_CSS__", layout_css)
            .replace("__DARK_CSS__", _DARK_CSS)
        )
        components.html(script, height=0)
        return content if content is not None else ""
