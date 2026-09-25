#!/usr/bin/env python3
"""Apply the SAFEGRAM overlay to the pinned AyuGram tree without overwriting edits."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_ayugram.py /path/to/Ayugram-iOS")
root = Path(sys.argv[1]).resolve()
bundle = Path(__file__).resolve().parents[1]
settings = Path("Swiftgram/SGSettingsUI/Sources/SGSettingsController.swift")
settings_build = Path("Swiftgram/SGSettingsUI/BUILD")
app = Path("submodules/TelegramUI/Sources/AppDelegate.swift")
app_build = Path("submodules/TelegramUI/BUILD")
state_utils = Path("submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift")
core_build = Path("submodules/TelegramCore/BUILD")
update_peers = Path("submodules/TelegramCore/Sources/UpdatePeers.swift")
cached_peers = Path("submodules/TelegramCore/Sources/TelegramEngine/Peers/UpdateCachedPeerData.swift")
fork_config = Path("Telegram/Telegram-iOS/Config-Fork.xcconfig")
icon = Path("Telegram/Telegram-iOS/DefaultAppIcon.xcassets/AppIconLLC.appiconset/Swiftgram.png")
required = (settings, settings_build, app, app_build, state_utils, core_build, update_peers, cached_peers, fork_config)
if any(not (root / p).is_file() for p in required):
    raise SystemExit("Expected AyuGram/Swiftgram tree with TelegramUI AppDelegate")
if not (root / icon).is_file():
    raise SystemExit("Expected pinned Swiftgram app icon")

original = {p: (root / p).read_text(encoding="utf-8") for p in required}
text = original[settings]
def insert_once(value, anchor, addition, marker):
    if marker in value:
        return value
    if anchor not in value:
        raise SystemExit(f"Patch anchor missing: {anchor[:90]}")
    return value.replace(anchor, anchor + addition, 1)

text = insert_once(text, "import SGAPIToken\n", "import SafeGramUI\n", "import SafeGramUI")
text = insert_once(text, "    case search\n", "    case safegram\n", "case safegram")
text = insert_once(text, "private enum SGDisclosureLink: String {\n", "    case safeGramCenter\n", "case safeGramCenter")
needle = '    entries.append(.searchInput(id: id.count, section: .search, title: NSAttributedString(string: "🔍"), text: state.searchQuery ?? "", placeholder: strings.Common_Search))\n'
text = insert_once(text, needle, '    entries.append(.header(id: id.count, section: .safegram, text: "SAFEGRAM SECURITY", badge: nil))\n    entries.append(.disclosure(id: id.count, section: .safegram, link: .safeGramCenter, text: "Security Center"))\n', "SAFEGRAM SECURITY")
text = insert_once(text, "        switch (link) {\n", "            case .safeGramCenter:\n                pushControllerImpl?(safeGramSecurityCenterController(accountId: context.account.peerId.toInt64()))\n", "case .safeGramCenter:")
text = text.replace('title: .text("Swiftgram")', 'title: .text("SAFEGRAM")')

build = insert_once(original[settings_build], "    deps = [\n", '        "//Swiftgram/SafeGramUI:SafeGramUI",\n', "//Swiftgram/SafeGramUI:SafeGramUI")
app_text = insert_once(original[app], "import SGAPIToken\n", "import SafeGramUI\n", "import SafeGramUI")
app_text = insert_once(app_text, "        self.window = window\n", "        SafeGramPrivacyCover.shared.attach(to: window)\n", "SafeGramPrivacyCover.shared.attach(to: window)")
app_build_text = insert_once(original[app_build], '    "//Swiftgram/SGSettingsUI:SGSettingsUI",\n', '    "//Swiftgram/SafeGramUI:SafeGramUI",\n', '"//Swiftgram/SafeGramUI:SafeGramUI"')
utils = insert_once(original[state_utils], "import Foundation\n", "import SafeGramCore\n", "import SafeGramCore")
receive_anchor = "            case let .AddMessages(messages, location):\n                if case .UpperHistoryBlock = location {"
if "SafeGramEventBridge.shared.messageReceived(" not in utils:
    if receive_anchor not in utils:
        raise SystemExit("Message replay anchor missing")
    utils = utils.replace(receive_anchor, '''            case let .AddMessages(messages, location):
                for message in messages {
                    if case let .Id(id) = message.id {
                        var replyAuthorId: Int64?
                        var mentions: [Int64] = []
                        for attribute in message.attributes {
                            if let reply = attribute as? ReplyMessageAttribute {
                                replyAuthorId = transaction.getMessage(reply.messageId)?.author?.id.toInt64()
                            } else if let entities = attribute as? TextEntitiesMessageAttribute {
                                for entity in entities.entities {
                                    if case let .TextMention(peerId) = entity.type { mentions.append(peerId.toInt64()) }
                                }
                            }
                        }
                        SafeGramEventBridge.shared.messageReceived(
                            accountId: accountPeerId.toInt64(), chatId: id.peerId.toInt64(), messageId: Int64(id.id),
                            authorId: message.authorId?.toInt64(), authorUsername: nil,
                            text: message.text, date: Date(timeIntervalSince1970: TimeInterval(message.timestamp)),
                            replyToAuthorId: replyAuthorId, mentionedUserIds: mentions)
                    }
                }
                if case .UpperHistoryBlock = location {''', 1)
utils = insert_once(utils, "            case let .EditMessage(id, message):\n", '''                SafeGramEventBridge.shared.messageEdited(
                    accountId: accountPeerId.toInt64(), chatId: id.peerId.toInt64(), messageId: Int64(id.id),
                    authorId: message.authorId?.toInt64(), authorUsername: nil,
                    text: message.text, date: Date(timeIntervalSince1970: TimeInterval(message.timestamp)),
                    previousText: transaction.getMessage(id)?.text)
''', "SafeGramEventBridge.shared.messageEdited(")
utils = insert_once(utils, "            case let .DeleteMessages(ids):\n", '''                for id in ids {
                    SafeGramEventBridge.shared.messageDeleted(
                        accountId: accountPeerId.toInt64(), chatId: id.peerId.toInt64(), messageId: Int64(id.id),
                        lastKnownText: transaction.getMessage(id)?.text ?? "")
                }
''', "SafeGramEventBridge.shared.messageDeleted(")
utils = insert_once(utils, "            case let .DeleteMessagesWithGlobalIds(ids):\n", '''                for id in transaction.messageIdsForGlobalIds(ids) {
                    SafeGramEventBridge.shared.messageDeleted(
                        accountId: accountPeerId.toInt64(), chatId: id.peerId.toInt64(), messageId: Int64(id.id),
                        lastKnownText: transaction.getMessage(id)?.text ?? "")
                }
''', "for id in transaction.messageIdsForGlobalIds(ids) {")
core_build_text = insert_once(original[core_build], "sgdeps = [\n", '    "//Swiftgram/SafeGramCore:SafeGramCore",\n', '"//Swiftgram/SafeGramCore:SafeGramCore"')
utils = insert_once(utils, "            case let .UpdatePeer(id, f):\n                if let peer = f(transaction.getPeer(id)) {\n", '''                    if let user = peer as? TelegramUser {
                        let name = [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " ")
                        SafeGramEventBridge.shared.profileObserved(accountId: accountPeerId.toInt64(), peerId: user.id.toInt64(), displayName: name, username: user.username, bio: nil, avatarId: user.photo.first?.resource.id.stringRepresentation ?? "")
                    } else if let channel = peer as? TelegramChannel {
                        SafeGramEventBridge.shared.profileObserved(accountId: accountPeerId.toInt64(), peerId: channel.id.toInt64(), displayName: channel.title, username: channel.username, bio: nil, avatarId: channel.photo.first?.resource.id.stringRepresentation ?? "")
                    }
''', "SafeGramEventBridge.shared.profileObserved(accountId: accountPeerId.toInt64(), peerId: user.id.toInt64()")
utils = insert_once(utils, "            case let .UpdateCachedPeerData(id, f):\n                transaction.updatePeerCachedData(peerIds: Set([id]), update: { _, current in\n", '''                    let result = f(current)
                    if let data = result as? CachedUserData {
                        SafeGramEventBridge.shared.profileBioObserved(accountId: accountPeerId.toInt64(), peerId: id.toInt64(), bio: data.about)
                    } else if let data = result as? CachedChannelData {
                        SafeGramEventBridge.shared.profileBioObserved(accountId: accountPeerId.toInt64(), peerId: id.toInt64(), bio: data.about)
                    }
                    return result
''', "SafeGramEventBridge.shared.profileBioObserved(accountId:")
utils = utils.replace("                    return result\n                    return f(current)\n", "                    return result\n", 1)
peers_text = insert_once(original[update_peers], "import Foundation\n", "import SafeGramCore\n", "import SafeGramCore")
profile_anchor = "    updatePeersCustom(transaction: transaction, peers: parsedPeers, update: { _, updated in updated })\n"
if "SafeGramEventBridge.shared.profileObserved(" not in peers_text:
    if profile_anchor not in peers_text:
        raise SystemExit("Peer update anchor missing")
    peers_text = peers_text.replace(profile_anchor, '''    updatePeersCustom(transaction: transaction, peers: parsedPeers, update: { _, updated in
        if let user = updated as? TelegramUser {
            let name = [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " ")
            SafeGramEventBridge.shared.profileObserved(accountId: accountPeerId.toInt64(), peerId: user.id.toInt64(), displayName: name, username: user.username, bio: nil, avatarId: user.photo.first?.resource.id.stringRepresentation ?? "")
        } else if let channel = updated as? TelegramChannel {
            SafeGramEventBridge.shared.profileObserved(accountId: accountPeerId.toInt64(), peerId: channel.id.toInt64(), displayName: channel.title, username: channel.username, bio: nil, avatarId: channel.photo.first?.resource.id.stringRepresentation ?? "")
        }
        return updated
    })
''', 1)
cached = insert_once(original[cached_peers], "import Foundation\n", "import SafeGramCore\n", "import SafeGramCore")
def insert_before_once(value, anchor, addition, marker):
    if marker in value:
        return value
    if anchor not in value:
        raise SystemExit(f"Patch anchor missing: {anchor[:90]}")
    return value.replace(anchor, addition + anchor, 1)

cached = insert_before_once(cached, "                                        return previous.withUpdatedAbout(userFullAbout)\n", '''                                        SafeGramEventBridge.shared.profileBioObserved(accountId: accountPeerId.toInt64(), peerId: peerId.toInt64(), bio: userFullAbout)
''', "profileBioObserved(accountId: accountPeerId.toInt64(), peerId: peerId.toInt64(), bio: userFullAbout)")
cached = insert_before_once(cached, "                                                return previous.withUpdatedFlags(channelFlags)\n", '''                                                SafeGramEventBridge.shared.profileBioObserved(accountId: accountPeerId.toInt64(), peerId: peerId.toInt64(), bio: about)
''', "profileBioObserved(accountId: accountPeerId.toInt64(), peerId: peerId.toInt64(), bio: about)")
brand = original[fork_config].replace("APP_NAME=Telegram Fork", "APP_NAME=SAFEGRAM", 1)
if brand == original[fork_config] and "APP_NAME=SAFEGRAM" not in brand:
    raise SystemExit("Fork app name anchor missing")
updated = {settings: text, settings_build: build, app: app_text, app_build: app_build_text, state_utils: utils, core_build: core_build_text, update_peers: peers_text, cached_peers: cached, fork_config: brand}
icon_path = bundle / "branding/SafeGramIcon.png"
icon_bytes = icon_path.read_bytes() if icon_path.exists() else None

backup_dir = root / ".safegram-backup"
manifest_file = backup_dir / "manifest.json"
if manifest_file.exists():
    manifest = json.loads(manifest_file.read_text())
    if any(str(p) not in manifest.get("patched", {}) for p in required) or "asset_patched" not in manifest:
        raise SystemExit("Older SAFEGRAM backup schema; roll back the older overlay before applying v0.4")
    for p in required:
        before = manifest["patched"][str(p)]
        if hashlib.sha256(original[p].encode()).hexdigest() != before and original[p] != updated[p]:
            raise SystemExit(f"Refusing to overwrite modified integration file: {p}")
    if hashlib.sha256((root / icon).read_bytes()).hexdigest() != manifest["asset_patched"]:
        raise SystemExit("Refusing to overwrite modified app icon")
else:
    if any("SAFEGRAM SECURITY" in original[p] for p in required):
        raise SystemExit("Existing SAFEGRAM edits without backup; preserve them manually")
    manifest = {"original": {}, "patched": {}}
    for p in required:
        destination = backup_dir / p
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(original[p], encoding="utf-8")
        manifest["original"][str(p)] = hashlib.sha256(original[p].encode()).hexdigest()
    icon_backup = backup_dir / icon
    icon_backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / icon, icon_backup)
    manifest["asset_original"] = hashlib.sha256(icon_backup.read_bytes()).hexdigest()

for name in ("SafeGramCore", "SafeGramUI"):
    source = bundle / "overlay/Swiftgram" / name
    destination = root / "Swiftgram" / name
    if destination.exists():
        for file in destination.rglob("*"):
            if file.is_file():
                relative = file.relative_to(destination)
                counterpart = source / relative
                if not counterpart.is_file() or file.read_bytes() != counterpart.read_bytes():
                    raise SystemExit(f"Refusing to overwrite modified overlay file: {file}")
    shutil.copytree(source, destination, dirs_exist_ok=True)

for p in required:
    (root / p).write_text(updated[p], encoding="utf-8")
    manifest["patched"][str(p)] = hashlib.sha256(updated[p].encode()).hexdigest()
if icon_bytes is not None:
    (root / icon).write_bytes(icon_bytes)
manifest["asset_patched"] = hashlib.sha256((root / icon).read_bytes()).hexdigest()
manifest_file.write_text(json.dumps(manifest, indent=2) + "\n")
print("SAFEGRAM overlay installed; original integration files backed up")
