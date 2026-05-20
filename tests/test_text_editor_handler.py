"""Unit tests for the Quill-backed TextEditorHandler — no Streamlit runtime."""

from unittest.mock import patch

from src.utils.TextEditorHandler import TextEditorHandler


def _patched():
    """Patch the two Streamlit-side calls render() makes."""
    return (
        patch("src.utils.TextEditorHandler.st_quill", return_value=""),
        patch("src.utils.TextEditorHandler.components"),
    )


class TestTextEditorHandlerRender:
    def test_returns_quill_content(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value="<p>hi</p>"), \
             patch("src.utils.TextEditorHandler.components"):
            result = TextEditorHandler().render(key="k", initial_value="<p>hi</p>")
        assert result == "<p>hi</p>"

    def test_requests_html_output(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value="") as mq, \
             patch("src.utils.TextEditorHandler.components"):
            TextEditorHandler().render(key="note_editor_0", initial_value="seed")
        assert mq.call_args.kwargs.get("html") is True

    def test_forwards_key_and_initial_value(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value="") as mq, \
             patch("src.utils.TextEditorHandler.components"):
            TextEditorHandler().render(key="note_editor_3", initial_value="<p>seed</p>")
        assert mq.call_args.kwargs.get("key") == "note_editor_3"
        assert mq.call_args.kwargs.get("value") == "<p>seed</p>"

    def test_none_return_coerced_to_empty_string(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=None), \
             patch("src.utils.TextEditorHandler.components"):
            result = TextEditorHandler().render(key="k")
        assert result == ""

    def test_defaults_to_empty_initial_value(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value="") as mq, \
             patch("src.utils.TextEditorHandler.components"):
            TextEditorHandler().render(key="k")
        assert mq.call_args.kwargs.get("value") == ""


class TestTextEditorHandlerDarkMode:
    def test_theme_script_injected_via_components_html(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        assert mc.html.call_count == 1
        assert mc.html.call_args.kwargs.get("height") == 0

    def test_dark_mode_defaults_to_false(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "var DARK = false" in script

    def test_dark_mode_true_emits_dark_flag(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k", dark_mode=True)
        script = mc.html.call_args.args[0]
        assert "var DARK = true" in script

    def test_dark_mode_false_emits_light_flag(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k", dark_mode=False)
        script = mc.html.call_args.args[0]
        assert "var DARK = false" in script

    def test_returns_content_regardless_of_theme(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value="<p>x</p>"), \
             patch("src.utils.TextEditorHandler.components"):
            result = TextEditorHandler().render(key="k", dark_mode=True)
        assert result == "<p>x</p>"


class TestTextEditorHandlerScrollPersistence:
    def test_scroll_position_stored_in_local_storage(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "localStorage" in script

    def test_uses_stable_scroll_storage_key(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "dandd-quill-scroll" in script

    def test_listens_for_scroll_events(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "addEventListener('scroll'" in script
        assert "setItem" in script

    def test_restores_saved_scroll_position(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "getItem" in script
        assert "scrollTop" in script

    def test_scroll_persistence_present_regardless_of_theme(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k", dark_mode=True)
        script = mc.html.call_args.args[0]
        assert "dandd-quill-scroll" in script
        assert "var DARK = true" in script


class TestTextEditorHandlerResize:
    def test_resize_handle_injected(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "dandd-quill-resize" in script

    def test_resize_handle_has_two_axis_cursor(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "nwse-resize" in script

    def test_size_persisted_with_stable_key(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "dandd-quill-size" in script
        assert "JSON.stringify" in script

    def test_drag_uses_pointer_events(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "addEventListener('pointerdown'" in script

    def test_size_restored_from_storage(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "JSON.parse" in script
        assert "getItem" in script

    def test_width_applied_to_iframe_element(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "style.width" in script

    def test_editor_stays_horizontally_centered(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "marginLeft = 'auto'" in script
        assert "marginRight = 'auto'" in script

    def test_resize_present_regardless_of_theme(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k", dark_mode=True)
        script = mc.html.call_args.args[0]
        assert "dandd-quill-resize" in script
        assert "var DARK = true" in script


class TestTextEditorHandlerLayout:
    def test_layout_stylesheet_always_injected(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k", dark_mode=False)
        script = mc.html.call_args.args[0]
        assert "dandd-quill-layout" in script

    def test_toolbar_is_pinned(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "position: sticky" in script

    def test_editor_scrolls_internally(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "overflow-y: auto" in script

    def test_default_height_is_600px(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k")
        script = mc.html.call_args.args[0]
        assert "600px" in script

    def test_custom_height_forwarded(self):
        with patch("src.utils.TextEditorHandler.st_quill", return_value=""), \
             patch("src.utils.TextEditorHandler.components") as mc:
            TextEditorHandler().render(key="k", height=820)
        script = mc.html.call_args.args[0]
        assert "820px" in script
