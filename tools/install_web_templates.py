"""Install the official Web release template and ICU data without downloading all platforms."""

import argparse
import io
from pathlib import Path
import time
from urllib.error import URLError
from urllib.request import Request, urlopen
import zipfile


VERSION = "4.7.2"
ARCHIVE = (
    f"https://godot-releases.nbg1.your-objectstorage.com/{VERSION}-stable/"
    f"Godot_v{VERSION}-stable_export_templates.tpz"
)
WEB_FILES = ("web_nothreads_release.zip", "icudt_godot.dat")


class TemplateArchive(io.RawIOBase):
    def __init__(self):
        self.position = 0
        with urlopen(Request(ARCHIVE, method="HEAD"), timeout=30) as response:
            self.length = int(response.headers["Content-Length"])

    def tell(self):
        return self.position

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = (0, self.position, self.length)[whence] + offset
        return self.position

    def read(self, count=-1):
        available = self.length - self.position
        count = available if count < 0 else min(count, available)
        if count <= 0:
            return b""
        first = self.position
        last = first + count - 1
        headers = {"Range": f"bytes={first}-{last}"}
        for attempt in range(3):
            request = Request(f"{ARCHIVE}?range={first}-{last}&attempt={attempt}", headers=headers)
            try:
                with urlopen(request, timeout=55) as response:
                    expected = f"bytes {first}-{last}/{self.length}"
                    if response.status != 206 or response.headers.get("Content-Range") != expected:
                        raise OSError("The template host did not honor the requested byte range.")
                    data = response.read(count + 1)
                if len(data) != count:
                    raise OSError("The template host returned an incomplete range.")
                self.position += count
                return data
            except (OSError, URLError):
                if attempt == 2:
                    raise
                time.sleep(attempt + 1)


def install(destination):
    needed = [name for name in WEB_FILES if not (destination / name).is_file()]
    if not needed:
        return
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(TemplateArchive()) as templates:
        for name in needed:
            member, = (entry for entry in templates.namelist() if Path(entry).name == name)
            data = templates.read(member)
            temporary = destination / (name + ".tmp")
            temporary.write_bytes(data)
            temporary.replace(destination / name)
            print(f"Installed {name}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    install(parser.parse_args().destination)
