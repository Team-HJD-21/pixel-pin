"""Write and verify the DMG Finder layout without controlling Finder."""
import argparse
from pathlib import Path
from ds_store import DSStore
from mac_alias import Alias

POSITIONS = {"Pixel Pin.app": (200, 240), "Applications": (520, 240)}


def verify(volume):
    with DSStore.open(str(volume / ".DS_Store"), "r") as store:
        for name, position in POSITIONS.items():
            assert store[name]["Iloc"] == position, f"Wrong icon position: {name}"
        options = store["."]["icvp"]
        assert options["backgroundType"] == 2 and options["iconSize"] == 96
        assert Alias.from_bytes(options["backgroundImageAlias"]).target.filename == "installer.tiff"
        assert not store["."]["bwsp"]["ShowToolbar"]
    assert (volume / ".background/installer.tiff").is_file()
    print("Installer background, alias, icon positions and Finder window settings verified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("volume", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if not args.verify_only:
        with DSStore.open(str(args.volume / ".DS_Store"), "w+") as store:
            store["."]["vSrn"] = ("long", 1)
            store["."]["icvl"] = (b"type", b"icnv")
            store["."]["bwsp"] = dict(WindowBounds="{{180, 120}, {720, 528}}", ShowToolbar=False,
                ShowSidebar=False, ContainerShowSidebar=False, ShowStatusBar=False, ShowPathbar=False,
                ShowTabView=False, PreviewPaneVisibility=False)
            store["."]["icvp"] = dict(viewOptionsVersion=1, backgroundType=2,
                backgroundImageAlias=Alias.for_file(str(args.volume / ".background/installer.tiff")).to_bytes(),
                iconSize=96.0, textSize=14.0, labelOnBottom=True, showItemInfo=False,
                showIconPreview=True, arrangeBy="none", gridOffsetX=0.0, gridOffsetY=0.0,
                gridSpacing=100.0, backgroundColorRed=1.0, backgroundColorGreen=1.0, backgroundColorBlue=1.0)
            for name, position in POSITIONS.items():
                store[name]["Iloc"] = position
    verify(args.volume)
