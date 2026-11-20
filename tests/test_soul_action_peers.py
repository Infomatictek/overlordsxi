"""Regression tests for SoulspireXI OXSI nearby-caster Soul identity protocol."""
import ctypes
import os
import struct
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CPP_PATH = REPO_ROOT / 'modules' / 'custom' / 'cpp' / 'soulspire_soul_action_peers.cpp'
HUD_LUA_PATH = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'soulspire_soul_hud.lua'
INIT_APPEND_PATH = REPO_ROOT / 'modules' / 'init.append.txt'
LUAJIT_DLL = Path(r'C:\dev\server\libluajit_64.dll')


def build_oxsi_packet(actor: int, job: int, branch: int, name: str, key: str, remove: bool) -> bytes:
    """Reference encoder matching soulspire_soul_action_peers.cpp makePacket()."""
    name_b = name.encode('ascii')
    key_b = b'' if remove else key.encode('ascii')
    raw = 22 + len(name_b) + len(key_b)
    padded = (raw + 3) & ~3
    tail = padded - raw
    header = struct.pack('<HH', 0x1FC | (((padded // 2) & 0xFE) << 8), 0)
    body = (
        b'OXSI'
        + struct.pack(
            '<BBIIBBBB',
            1,
            0 if remove else 1,
            actor,
            actor,
            job,
            0 if remove else branch,
            len(name_b),
            len(key_b),
        )
        + name_b
        + key_b
        + (b'\x00' * tail)
    )
    return header + body


def decode_oxsi_packet(pkt: bytes):
    """Reference decoder matching peer_souls.lua M.decode()."""
    if len(pkt) < 24 or len(pkt) > 160 or pkt[4:8] != b'OXSI':
        return None
    ver, op, actor, character, job, branch, nlen, slen = struct.unpack('<BBIIBBBB', pkt[8:22])
    if (
        ver != 1
        or op not in (0, 1)
        or actor == 0
        or character == 0
        or not (1 <= job <= 22)
        or branch > 3
        or nlen > 24
        or slen > 64
        or len(pkt) < 22 + nlen + slen
        or len(pkt) > 25 + nlen + slen
    ):
        return None
    padding = pkt[22 + nlen + slen :]
    if any(b != 0 for b in padding):
        return None
    name = pkt[22 : 22 + nlen].decode('ascii')
    soul = pkt[22 + nlen : 22 + nlen + slen].decode('ascii')
    if op == 1 and (branch == 0 or len(soul) < 2):
        return None
    if op == 0 and (branch != 0 or slen != 0):
        return None
    return {
        'op': op,
        'actor': actor,
        'character': character,
        'job': job,
        'branch': branch,
        'name': name,
        'soul': soul if op == 1 else None,
    }


class SoulActionPeersProtocolTests(unittest.TestCase):
    def test_module_registered_in_init_append(self):
        init_text = INIT_APPEND_PATH.read_text(encoding='utf-8')
        self.assertIn('custom/cpp/soulspire_soul_action_peers.cpp', init_text)

    def test_cpp_module_implements_oninit_and_zone_isolation(self):
        src = CPP_PATH.read_text(encoding='utf-8')
        self.assertIn('void OnInit() override', src)
        self.assertIn('void OnCharZoneIn(CCharEntity* p) override', src)
        self.assertIn('void OnCharZoneOut(CCharEntity* p) override', src)
        self.assertIn('void OnZoneTick(CZone* z) override', src)
        self.assertIn('sentByZone', src)
        self.assertIn('PInstance', src)
        self.assertIn('REGISTER_CPP_MODULE(OverlordsSoulActionPeersModule)', src)

    def test_oxsi_packet_alignment_all_padding_remainders(self):
        # Test 0, 1, 2, 3 zero-padding bytes for upsert and revoke.
        for name in ('Ab', 'Rin', 'Kage', 'OtherNinja'):
            for soul in ('shinobi', 'kagemusha', 'crimsonduelist'):
                pkt = build_oxsi_packet(54321, 13, 1, name, soul, remove=False)
                self.assertEqual(len(pkt) % 4, 0)
                dec = decode_oxsi_packet(pkt)
                self.assertIsNotNone(dec)
                self.assertEqual(dec['op'], 1)
                self.assertEqual(dec['actor'], 54321)
                self.assertEqual(dec['job'], 13)
                self.assertEqual(dec['branch'], 1)
                self.assertEqual(dec['name'], name)
                self.assertEqual(dec['soul'], soul)

            rev = build_oxsi_packet(54321, 13, 0, name, '', remove=True)
            self.assertEqual(len(rev) % 4, 0)
            dec_rev = decode_oxsi_packet(rev)
            self.assertIsNotNone(dec_rev)
            self.assertEqual(dec_rev['op'], 0)
            self.assertEqual(dec_rev['branch'], 0)
            self.assertIsNone(dec_rev['soul'])

    def test_oxhd_is_rejected_by_oxsi_decoder(self):
        oxhd = b'\x00\x00\x00\x00OXHD' + b'\x01\x01\x0d\x07\x00\x00\x00\x00shinobi\x00'
        self.assertIsNone(decode_oxsi_packet(oxhd))

    @unittest.skipUnless(LUAJIT_DLL.exists(), 'Local libluajit_64.dll not available')
    def test_hud_build_identity_data_in_luajit(self):
        dll = ctypes.CDLL(str(LUAJIT_DLL))
        dll.luaL_newstate.restype = ctypes.c_void_p
        dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
        dll.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        dll.luaL_loadstring.restype = ctypes.c_int
        dll.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        dll.lua_pcall.restype = ctypes.c_int
        dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        dll.lua_tolstring.restype = ctypes.c_char_p
        dll.lua_close.argtypes = [ctypes.c_void_p]

        hud_path = str(HUD_LUA_PATH).replace('\\', '\\\\')
        script = f"""
        -- Minimal server globals stub to load soulspire_soul_hud.lua
        local origRequire = require
        function require(name)
            if type(name) == 'string' and (name:match('^modules/') or name:match('^scripts/')) then
                return true
            end
            return origRequire(name)
        end
        Module = {{
            new = function(_, name)
                return {{
                    name = name,
                    addOverride = function() end,
                }}
            end
        }}
        xi = {{
            effect = {{}},
            soulspire = {{
                spec = {{
                    get = function(p, jobId) return p._active end,
                    isLevelEligible = function(p, jobId, active) return p._eligible == true end,
                    refreshPlayer = function(p) return true end,
                }}
            }}
        }}
        dofile('{hud_path}')
        local hud = xi.soulspire.hud
        assert(type(hud.buildIdentityData) == 'function', 'buildIdentityData missing')
        assert(type(hud.buildPacketData) == 'function', 'buildPacketData missing')

        -- 1. Legacy kurogane resolves to shinobi
        local p1 = {{
            isPC = function() return true end,
            getMainJob = function() return 13 end,
            _active = {{ id = 1, key = 'kurogane', canonicalKey = 'kurogane' }},
            _eligible = true,
        }}
        local id1 = hud.buildIdentityData(p1)
        assert(id1.jobId == 13 and id1.branch == 1 and id1.soulKey == 'shinobi',
            'Expected shinobi, got ' .. tostring(id1.soulKey))

        -- 2. Alias aegistemplar uses canonicalKey defender
        local p2 = {{
            isPC = function() return true end,
            getMainJob = function() return 7 end,
            _active = {{ id = 2, key = 'aegistemplar', canonicalKey = 'defender' }},
            _eligible = true,
        }}
        local id2 = hud.buildIdentityData(p2)
        assert(id2.jobId == 7 and id2.branch == 2 and id2.soulKey == 'defender',
            'Expected defender, got ' .. tostring(id2.soulKey))

        -- 3. Ineligible level returns empty identity with valid jobId
        local p3 = {{
            isPC = function() return true end,
            getMainJob = function() return 13 end,
            _active = {{ id = 1, key = 'kurogane' }},
            _eligible = false,
        }}
        local id3 = hud.buildIdentityData(p3)
        assert(id3.jobId == 13 and id3.branch == 0 and id3.soulKey == '', 'Expected empty for ineligible')

        -- 4. No active Soul returns empty identity with valid jobId
        local p4 = {{
            isPC = function() return true end,
            getMainJob = function() return 1 end,
            _active = nil,
            _eligible = true,
        }}
        local id4 = hud.buildIdentityData(p4)
        assert(id4.jobId == 1 and id4.branch == 0 and id4.soulKey == '', 'Expected empty for no Soul')

        -- 5. BST alphawarden, DNC miragesentinel, and PUP pugilist/animist match client pairs
        local p5 = {{
            isPC = function() return true end,
            getMainJob = function() return 9 end,
            _active = {{ id = 2, key = 'alphawarden', canonicalKey = 'alphawarden' }},
            _eligible = true,
        }}
        local id5 = hud.buildIdentityData(p5)
        assert(id5.jobId == 9 and id5.branch == 2 and id5.soulKey == 'soulbeast',
            'Expected BST (9,2,soulbeast), got ' .. tostring(id5.branch) .. ',' .. tostring(id5.soulKey))

        local p6 = {{
            isPC = function() return true end,
            getMainJob = function() return 19 end,
            _active = {{ id = 4, key = 'miragesentinel', canonicalKey = 'miragesentinel' }},
            _eligible = true,
        }}
        local id6 = hud.buildIdentityData(p6)
        assert(id6.jobId == 19 and id6.branch == 1 and id6.soulKey == 'miragesentinel',
            'Expected DNC (19,1,miragesentinel), got ' .. tostring(id6.branch) .. ',' .. tostring(id6.soulKey))

        local p7 = {{
            isPC = function() return true end,
            getMainJob = function() return 18 end,
            _active = {{ id = 3, key = 'pugilist', canonicalKey = 'pugilist' }},
            _eligible = true,
        }}
        local id7 = hud.buildIdentityData(p7)
        assert(id7.jobId == 18 and id7.branch == 2 and id7.soulKey == 'pugilist',
            'Expected PUP (18,2,pugilist), got ' .. tostring(id7.branch) .. ',' .. tostring(id7.soulKey))

        local p8 = {{
            isPC = function() return true end,
            getMainJob = function() return 18 end,
            _active = {{ id = 2, key = 'animist', canonicalKey = 'animist' }},
            _eligible = true,
        }}
        local id8 = hud.buildIdentityData(p8)
        assert(id8.jobId == 18 and id8.branch == 3 and id8.soulKey == 'animist',
            'Expected PUP (18,3,animist), got ' .. tostring(id8.branch) .. ',' .. tostring(id8.soulKey))

        -- 6. Existing OXHD buildPacketData remains compatible
        local oxhd = hud.buildPacketData(p1)
        assert(oxhd.jobId == 13 and oxhd.unlocked == 1 and oxhd.soulKey == 'kurogane',
            'OXHD packet data regressed')
        """

        L = dll.luaL_newstate()
        dll.luaL_openlibs(L)
        rc = dll.luaL_loadstring(L, script.encode('utf-8'))
        if rc == 0:
            rc = dll.lua_pcall(L, 0, 0, 0)
        err = None
        if rc != 0:
            err = dll.lua_tolstring(L, -1, None).decode('utf-8', 'replace')
        dll.lua_close(L)
        self.assertEqual(rc, 0, f'LuaJIT test failed: {err}')


if __name__ == '__main__':
    unittest.main()
