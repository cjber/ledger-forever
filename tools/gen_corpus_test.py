"""Pure checks for the ignored QuestieDB corpus pin."""

import io
import unittest
import zipfile

from tools.gen_corpus import QUESTIEDB_SHA256, archive_files, validate_zip, verify


def archive(*names):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as output:
        for name in names:
            output.writestr(name, b"data")
    return stream.getvalue()


class CorpusTest(unittest.TestCase):
    def test_the_pin_is_a_sha256_digest(self):
        self.assertEqual(len(QUESTIEDB_SHA256), 64)
        self.assertRegex(QUESTIEDB_SHA256, r"^[0-9a-f]+$")

    def test_archive_requires_the_forever_toc(self):
        with self.assertRaisesRegex(ValueError, "no QuestieDB/QuestieDB_Forever.toc"):
            archive_files(archive("QuestieDB/other.lua"))

    def test_archive_rejects_path_traversal(self):
        with self.assertRaisesRegex(ValueError, "unsafe path"):
            archive_files(archive("QuestieDB/QuestieDB_Forever.toc", "QuestieDB/../escape.lua"))

    def test_verify_rejects_another_archive(self):
        with self.assertRaisesRegex(ValueError, "sha256"):
            verify(b"not the pinned release")

    def test_validate_zip_accepts_a_valid_archive(self):
        validate_zip(archive("QuestieDB/QuestieDB_Forever.toc"))


if __name__ == "__main__":
    unittest.main()
