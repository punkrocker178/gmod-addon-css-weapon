"""Decode mounted CS:S weapon .ctx scripts into lua/css_weapons/sh_stats.lua."""

import os
import struct

VPK = r"D:\SteamLibrary\steamapps\common\Counter-Strike Source\cstrike\cstrike_pak_dir.vpk"
CSTRIKE = r"D:\SteamLibrary\steamapps\common\Counter-Strike Source\cstrike"
OUT = os.path.join(os.path.dirname(__file__), "..", "lua", "css_weapons", "sh_stats.lua")
KEY = b"d7NSuLq2"  # Counter-Strike: Source VICE key. x9Ke0BY7 is Half-Life 2: Deathmatch.

GUNS = [
    "ak47", "aug", "awp", "deagle", "elite", "famas", "fiveseven", "g3sg1",
    "galil", "glock", "m249", "m3", "m4a1", "mac10", "mp5navy", "p228", "p90",
    "scout", "sg550", "sg552", "tmp", "ump45", "usp", "xm1014",
]

ICONS = {
    "ak47": "ak47",
    "aug": "aug",
    "awp": "awp",
    "deagle": "deserteagle",
    "elite": "elites",
    "famas": "famas",
    "fiveseven": "fiveseven",
    "g3sg1": "g3sg1",
    "galil": "galil",
    "glock": "glock18",
    "m249": "m249",
    "m3": "m3",
    "m4a1": "m4a1",
    "mac10": "mac10",
    "mp5navy": "mp5",
    "p228": "p228",
    "p90": "p90",
    "scout": "scout",
    "sg550": "sg550",
    "sg552": "sg552",
    "tmp": "tmp",
    "ump45": "ump45",
    "usp": "usp45",
    "xm1014": "xm1014",
}

ICE_SMOD = (
    (333, 313, 505, 369),
    (379, 375, 319, 391),
    (361, 445, 451, 397),
    (397, 425, 395, 505),
)
ICE_SXOR = (
    (0x83, 0x85, 0x9B, 0xCD),
    (0xCC, 0xA7, 0xAD, 0x41),
    (0x4B, 0x2E, 0xD4, 0x33),
    (0xEA, 0xCB, 0x2E, 0x04),
)
ICE_PBOX = (
    0x00000001, 0x00000080, 0x00000400, 0x00002000,
    0x00080000, 0x00200000, 0x01000000, 0x40000000,
    0x00000008, 0x00000020, 0x00000100, 0x00004000,
    0x00010000, 0x00800000, 0x04000000, 0x20000000,
    0x00000004, 0x00000010, 0x00000200, 0x00008000,
    0x00020000, 0x00400000, 0x08000000, 0x10000000,
    0x00000002, 0x00000040, 0x00000800, 0x00001000,
    0x00040000, 0x00100000, 0x02000000, 0x80000000,
)
ICE_KEYROT = (0, 1, 2, 3, 2, 1, 3, 0, 1, 3, 2, 0, 3, 1, 0, 2)

MASK32 = 0xFFFFFFFF


def gf_mult(a, b, m):
    res = 0
    while b:
        if b & 1:
            res ^= a
        a <<= 1
        b >>= 1
        if a >= 256:
            a ^= m
    return res


def gf_exp7(b, m):
    if b == 0:
        return 0
    x = gf_mult(b, b, m)
    x = gf_mult(b, x, m)
    x = gf_mult(x, x, m)
    return gf_mult(b, x, m)


def ice_perm32(x):
    res = 0
    i = 0
    while x:
        if x & 1:
            res |= ICE_PBOX[i]
        i += 1
        x >>= 1
    return res & MASK32


def build_sboxes():
    sbox = [[0] * 1024 for _ in range(4)]
    for i in range(1024):
        col = (i >> 1) & 0xFF
        row = (i & 0x1) | ((i & 0x200) >> 8)
        for box, shift in ((0, 24), (1, 16), (2, 8), (3, 0)):
            x = gf_exp7(col ^ ICE_SXOR[box][row], ICE_SMOD[box][row]) << shift
            sbox[box][i] = ice_perm32(x)
    return sbox


SBOX = build_sboxes()


def schedule_build(kb, n, keyrot, rounds):
    for i in range(8):
        kr = keyrot[i]
        sk = [0, 0, 0]
        for j in range(15):
            curr = j % 3
            for k in range(4):
                idx = (kr + k) & 3
                bit = kb[idx] & 1
                sk[curr] = ((sk[curr] << 1) | bit) & MASK32
                kb[idx] = ((kb[idx] >> 1) | ((bit ^ 1) << 15)) & 0xFFFF
        rounds[n + i] = tuple(sk)


def ice_set(key):
    rounds = [None] * 8
    kb = [0] * 4
    for i in range(4):
        kb[3 - i] = (key[i * 2] << 8) | key[i * 2 + 1]
    schedule_build(kb, 0, ICE_KEYROT, rounds)
    return rounds


def ice_f(p, sk):
    tl = ((p >> 16) & 0x3FF) | (((p >> 14) | ((p << 18) & MASK32)) & 0xFFC00)
    tr = (p & 0x3FF) | ((p << 2) & 0xFFC00)
    al = sk[2] & (tl ^ tr)
    ar = al ^ tr
    al ^= tl
    al ^= sk[0]
    ar ^= sk[1]
    al &= MASK32
    ar &= MASK32
    return (
        SBOX[0][al >> 10]
        | SBOX[1][al & 0x3FF]
        | SBOX[2][ar >> 10]
        | SBOX[3][ar & 0x3FF]
    ) & MASK32


def ice_decrypt_block(block, rounds):
    l = (block[0] << 24) | (block[1] << 16) | (block[2] << 8) | block[3]
    r = (block[4] << 24) | (block[5] << 16) | (block[6] << 8) | block[7]
    i = 7
    while i > 0:
        l = (l ^ ice_f(r, rounds[i])) & MASK32
        r = (r ^ ice_f(l, rounds[i - 1])) & MASK32
        i -= 2
    out = bytearray(8)
    for i in range(4):
        out[3 - i] = r & 0xFF
        out[7 - i] = l & 0xFF
        r >>= 8
        l >>= 8
    return bytes(out)


def decode_ice(data, key):
    rounds = ice_set(key)
    out = bytearray()
    usable = len(data) - (len(data) % 8)
    for off in range(0, usable, 8):
        out += ice_decrypt_block(data[off:off + 8], rounds)
    return bytes(out)


def read_cstr(br):
    chars = []
    while True:
        b = br.read(1)
        if b == b"" or b == b"\0":
            return "".join(chars)
        chars.append(b.decode("latin1"))


def vpk_files():
    with open(VPK, "rb") as f:
        sig, ver, _tree = struct.unpack("<III", f.read(12))
        if sig != 0x55AA1234:
            raise SystemExit("bad vpk signature")
        if ver == 2:
            f.read(16)
        found = {}
        while True:
            ext = read_cstr(f)
            if ext == "":
                break
            while True:
                directory = read_cstr(f)
                if directory == "":
                    break
                while True:
                    name = read_cstr(f)
                    if name == "":
                        break
                    _crc, preload, archive, offset, length = struct.unpack("<IHHII", f.read(16))
                    f.read(2)
                    pre = f.read(preload) if preload else b""
                    full = f"{directory}/{name}.{ext}"
                    found[full.lower()] = (archive, offset, length, pre)
        return found


def read_vpk_file(entry):
    archive, offset, length, pre = entry
    if archive == 0x7FFF:
        return pre
    pak = os.path.join(CSTRIKE, f"cstrike_pak_{archive:03d}.vpk")
    with open(pak, "rb") as f:
        f.seek(offset)
        return pre + f.read(length)


def parse_kv(text):
    i = 0
    n = len(text)

    def skip():
        nonlocal i
        while i < n and text[i] in " \t\r\n":
            i += 1
        if i < n and text[i] == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            skip()

    def parse_string():
        nonlocal i
        skip()
        if i >= n:
            return None
        if text[i] == '"':
            i += 1
            start = i
            while i < n and text[i] != '"':
                i += 1
            s = text[start:i]
            i += 1
            return s
        start = i
        while i < n and text[i] not in " \t\r\n{}\"":
            i += 1
        return text[start:i]

    def parse_block():
        nonlocal i
        obj = {}
        while True:
            skip()
            if i >= n or text[i] == "}":
                if i < n and text[i] == "}":
                    i += 1
                return obj
            key = parse_string()
            if key is None:
                return obj
            skip()
            if i < n and text[i] == "{":
                i += 1
                obj[key] = parse_block()
            else:
                obj[key] = parse_string()

    skip()
    root_key = parse_string()
    skip()
    if i >= n or text[i] != "{":
        raise ValueError("expected block, got %r" % text[:80])
    i += 1
    body = parse_block()
    body["__root"] = root_key
    return body


def lua_num(value):
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return repr(value)


def lua_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


NUMERIC = {
    "Damage", "Penetration", "Range", "RangeModifier", "Bullets", "CycleTime",
    "AccuracyQuadratic", "AccuracyDivisor", "AccuracyOffset", "MaxInaccuracy",
    "Spread", "SpreadAlt",
    "InaccuracyCrouch", "InaccuracyStand", "InaccuracyJump", "InaccuracyLand",
    "InaccuracyLadder", "InaccuracyFire", "InaccuracyMove",
    "InaccuracyCrouchAlt", "InaccuracyStandAlt", "InaccuracyJumpAlt",
    "InaccuracyLandAlt", "InaccuracyLadderAlt", "InaccuracyFireAlt",
    "InaccuracyMoveAlt", "InaccuracyReload", "InaccuracyAltSwitch",
    "RecoveryTimeCrouch", "RecoveryTimeStand", "RecoveryTimeCrouchFinal",
    "RecoveryTimeStandFinal",
    "TimeToIdle", "IdleInterval", "clip_size", "default_clip", "weight",
    "bucket", "bucket_position", "MaxPlayerSpeed", "ZoomFOV", "ZoomTime",
    "FullAuto", "MuzzleFlashScale", "BotAudibleRange",
}


def as_number(text):
    try:
        if "." in text:
            return float(text)
        return int(text)
    except ValueError:
        return None


def emit(guns):
    lines = [
        "-- Generated from the mounted Counter-Strike: Source weapon scripts.",
        "-- Models, materials, and sounds stay in the cstrike mount.",
        "",
        "CSSWeapons = CSSWeapons or {}",
        "CSSWeapons.Stats = {",
    ]
    for name in GUNS:
        data = guns[name]
        lines.append(f"\t{name} = {{")
        lines.append(f'\t\tClass = "weapon_css_{name}",')
        lines.append(f'\t\tIcon = "vgui/gfx/vgui/{ICONS[name]}",')
        for key in (
            "printname", "viewmodel", "playermodel", "anim_prefix", "primary_ammo",
        ):
            if key in data and isinstance(data[key], str):
                lines.append(f'\t\t{key} = "{lua_escape(data[key])}",')
        sounds = data.get("SoundData") or {}
        if isinstance(sounds, dict):
            lines.append("\t\tSound = {")
            for sk, sv in sounds.items():
                if isinstance(sv, str):
                    lines.append(f'\t\t\t{sk} = "{lua_escape(sv)}",')
            lines.append("\t\t},")
        for key, value in data.items():
            if key in ("SoundData", "__root", "printname", "viewmodel", "playermodel", "anim_prefix", "primary_ammo"):
                continue
            if isinstance(value, dict):
                continue
            num = as_number(value) if isinstance(value, str) else None
            if num is not None and (key in NUMERIC or key.lower().startswith("inaccuracy") or key.lower().startswith("recovery")):
                lines.append(f"\t\t{key} = {lua_num(num)},")
            elif key in ("FullAuto",):
                lines.append(f"\t\t{key} = {lua_num(num if num is not None else value)},")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main():
    files = vpk_files()
    guns = {}
    for name in GUNS:
        path = f"scripts/weapon_{name}.ctx"
        entry = files.get(path)
        if not entry:
            raise SystemExit(f"missing {path}")
        raw = read_vpk_file(entry)
        text = decode_ice(raw, KEY).split(b"\0", 1)[0].decode("latin1", errors="replace")
        if "WeaponData" not in text and "weapondata" not in text.lower():
            raise SystemExit(f"{name} did not decode as WeaponData:\n{text[:200]}")
        data = parse_kv(text)
        guns[name] = data
        print(f"{name}: Damage={data.get('Damage')} Cycle={data.get('CycleTime')} Stand={data.get('InaccuracyStand')} RangeMod={data.get('RangeModifier')}")
    ak = guns["ak47"]
    for field in ("Damage", "CycleTime", "RangeModifier", "InaccuracyStand"):
        if as_number(str(ak.get(field, ""))) is None:
            raise SystemExit(f"AK-47 missing numeric {field}")
    emit(guns)
    print("wrote", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
