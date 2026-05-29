import os
import pandas as pd


class NotePersistenceHandler:
    NOTES_FILE = "data/editor_notes.txt"
    RAW_NOTES_FILE = "data/raw_notes.json"

    def __init__(self, notes_file: str = None, raw_notes_file: str = None):
        self._notes_file = notes_file or self.NOTES_FILE
        self._raw_notes_file = raw_notes_file or self.RAW_NOTES_FILE

    def persist(self, df: pd.DataFrame, text: str) -> None:
        """Write both the raw-notes structure and editor notes text."""
        os.makedirs(os.path.dirname(self._notes_file), exist_ok=True)
        df.to_json(self._raw_notes_file)
        with open(self._notes_file, "w", encoding="utf-8") as f:
            f.write(text)

    def read_notes_text(self) -> str:
        if os.path.isfile(self._notes_file):
            with open(self._notes_file, "r", encoding="utf-8") as f:
                return f.read()
        return ""

    def has_notes(self) -> bool:
        return os.path.isfile(self._raw_notes_file)
