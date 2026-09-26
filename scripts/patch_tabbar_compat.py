#!/usr/bin/env python3
"""Repair known pinned AyuGram TabBarUI compile drift, idempotently."""
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_tabbar_compat.py /path/to/Ayugram-iOS")

root = Path(sys.argv[1]).resolve()
controller = root / "submodules/TabBarUI/Sources/TabBarController.swift"
node = root / "submodules/TabBarUI/Sources/TabBarNode.swift"
root_controller = root / "submodules/TelegramUI/Sources/TelegramRootController.swift"
for path in (controller, node, root_controller):
    if not path.is_file():
        raise SystemExit(f"missing expected upstream file: {path}")

backup_root = root / ".safegram-compat-backup"
backup_root.mkdir(parents=True, exist_ok=True)

def backup_once(path: Path) -> None:
    rel = path.relative_to(root)
    dst = backup_root / rel
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dst)

controller_text = controller.read_text(encoding="utf-8")
old = "sgTabBarHeightModifier(showTabNames: self.showTabNames, tabBarHeight:"
new = "sgTabBarHeightModifier(tabBarHeight:"
if old in controller_text:
    backup_once(controller)
    controller_text = controller_text.replace(old, new)
    controller.write_text(controller_text, encoding="utf-8")

node_text = node.read_text(encoding="utf-8")
if "SGSimpleSettings.shared.showTabNames" in node_text and "import SGSimpleSettings\n" not in node_text:
    anchor = "import TelegramAnimatedStickerNode\n"
    if anchor not in node_text:
        raise SystemExit("TabBarNode import anchor missing")
    backup_once(node)
    node_text = node_text.replace(anchor, anchor + "import SGSimpleSettings\n", 1)
    node.write_text(node_text, encoding="utf-8")


root_text = root_controller.read_text(encoding="utf-8")
root_original = root_text
root_text = root_text.replace("    private var showTabNames: Bool\n    \n", "", 1)
root_text = root_text.replace("    public init(showTabNames: Bool, context: AccountContext) {", "    public init(context: AccountContext) {", 1)
root_text = root_text.replace("        self.showTabNames = showTabNames\n        \n", "", 1)
root_text = root_text.replace("TabBarControllerImpl(showTabNames: self.showTabNames, navigationBarPresentationData:", "TabBarControllerImpl(navigationBarPresentationData:", 1)
if root_text != root_original:
    backup_once(root_controller)
    if "SGSimpleSettings" not in root_text.replace("import SGSimpleSettings\n", ""):
        root_text = root_text.replace("import SGSimpleSettings\n", "", 1)
    root_controller.write_text(root_text, encoding="utf-8")

if old in controller.read_text(encoding="utf-8"):
    raise SystemExit("TabBarController compatibility patch incomplete")
if "SGSimpleSettings.shared.showTabNames" in node.read_text(encoding="utf-8") and "import SGSimpleSettings\n" not in node.read_text(encoding="utf-8"):
    raise SystemExit("TabBarNode compatibility patch incomplete")
if "showTabNames" in root_controller.read_text(encoding="utf-8"):
    raise SystemExit("TelegramRootController compatibility patch incomplete")

print("AyuGram TabBarUI compatibility patch: OK")
