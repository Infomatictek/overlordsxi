// OverlordsXI: nearby Soul identity announcements for local visual presentation.
// Separate from the existing OXHD meter feed; no spell IDs or gameplay modified.
#include "common/timer.h"
#include "map/entities/char_entity.h"
#include "map/lua/luautils.h"
#include "map/packets/basic.h"
#include "map/utils/moduleutils.h"
#include "map/zone.h"
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
using namespace std::chrono_literals;

namespace
{
constexpr uint16 PeerPacketType = 0x1FC;
constexpr auto PeerTick = 2s;
constexpr auto Refresh = 45s;  // Client expires announcements after 120s.
constexpr float RadiusSq = 2500.0f; // 50 yalms, same-zone only.

struct Peer
{
    CCharEntity* entity{};
    uint32 actor{};
    uint8 job{};
    uint8 branch{};
    std::string name;
    std::string key;
};
struct Delivered
{
    uint64 signature{};
    timer::time_point at{};
};
std::unordered_map<const CZone*, std::unordered_map<uint64, Delivered>> sentByZone;
std::unordered_map<const CZone*, timer::time_point> next;

bool valid(const std::string& s, bool isName)
{
    if (s.size() < 2 || s.size() > (isName ? 24 : 64)) return false;
    for (unsigned char c : s)
    {
        bool alpha = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
        bool digit = (c >= '0' && c <= '9');
        if (!alpha && !digit && c != '-' && c != '_') return false;
    }
    return !isName || ((s[0] >= 'A' && s[0] <= 'Z') || (s[0] >= 'a' && s[0] <= 'z'));
}

Peer fetch(CCharEntity* player)
{
    Peer peer{};
    peer.entity = player;
    peer.actor = player->id;
    peer.name = player->name;
    if (!valid(peer.name, true)) return peer;

    auto x = lua["xi"];
    if (!x.valid()) return peer;
    auto o = x["overlords"];
    if (!o.valid()) return peer;
    auto h = o["hud"];
    if (!h.valid()) return peer;
    sol::protected_function fn = h["buildIdentityData"];
    if (!fn.valid()) return peer;
    const auto result = fn(player);
    if (!result.valid()) return peer;
    sol::object object = result.get<sol::object>();
    if (!object.valid() || object.get_type() != sol::type::table) return peer;
    auto tbl = object.as<sol::table>();
    peer.job = tbl.get_or<uint8>("jobId", 0);
    peer.branch = tbl.get_or<uint8>("branch", 0);
    peer.key = tbl.get_or<std::string>("soulKey", "");
    if (peer.job < 1 || peer.job > 22 || peer.branch < 1 || peer.branch > 3 ||
        !valid(peer.key, false))
    {
        peer.branch = 0;
        peer.key.clear();
    }
    return peer;
}

auto makePacket(const Peer& peer, bool remove) -> std::unique_ptr<CBasicPacket>
{
    const auto n = peer.name.size();
    const auto k = remove ? 0u : peer.key.size();
    const auto padded = (22u + n + k + 3u) & ~std::size_t(3u);
    auto p = std::make_unique<CBasicPacket>();
    p->setType(PeerPacketType);
    p->setSize(padded);
    p->ref<uint8>(0x04) = 'O'; p->ref<uint8>(0x05) = 'X';
    p->ref<uint8>(0x06) = 'S'; p->ref<uint8>(0x07) = 'I';
    p->ref<uint8>(0x08) = 1;
    p->ref<uint8>(0x09) = remove ? 0 : 1;
    p->ref<uint32>(0x0A) = peer.actor;
    p->ref<uint32>(0x0E) = peer.actor; // Zone-scoped ID; not a character database ID.
    p->ref<uint8>(0x12) = peer.job;
    p->ref<uint8>(0x13) = remove ? 0 : peer.branch;
    p->ref<uint8>(0x14) = static_cast<uint8>(n);
    p->ref<uint8>(0x15) = static_cast<uint8>(k);
    std::memcpy(&p->ref<uint8>(0x16), peer.name.data(), n);
    if (k) std::memcpy(&p->ref<uint8>(0x16 + n), peer.key.data(), k);
    return p;
}

uint64 signature(const Peer& p)
{
    uint64 v = 14695981039346656037ULL;
    auto mix = [&](unsigned char c) { v ^= c; v *= 1099511628211ULL; };
    mix(p.job); mix(p.branch);
    for (auto c : p.key) mix(static_cast<unsigned char>(c));
    for (auto c : p.name) mix(static_cast<unsigned char>(c));
    return v;
}
uint64 pairKey(const Peer& viewer, const Peer& caster)
{
    return (static_cast<uint64>(viewer.actor) << 32) | caster.actor;
}
bool nearby(const Peer& viewer, const Peer& caster)
{
    float x = viewer.entity->loc.p.x - caster.entity->loc.p.x;
    float y = viewer.entity->loc.p.y - caster.entity->loc.p.y;
    float z = viewer.entity->loc.p.z - caster.entity->loc.p.z;
    return x*x + y*y + z*z <= RadiusSq;
}
void announce(CZone* zone, timer::time_point now)
{
    auto& sent = sentByZone[zone]; // Avoid entity ID collisions across zones.
    std::vector<Peer> peers;
    zone->ForEachChar([&](CCharEntity* ch)
    {
        if (ch && ch->status != xi::Status::Disappear)
        {
            peers.push_back(fetch(ch));
        }
    });
    for (const Peer& viewer : peers)
    {
        if (!viewer.entity || !valid(viewer.name,true)) continue;
        for (const Peer& caster : peers)
        {
            if (caster.actor == viewer.actor || !valid(caster.name,true)) continue;
            auto key = pairKey(viewer, caster);
            auto it = sent.find(key);
            const bool present = caster.branch > 0 && nearby(viewer, caster);
            if (!present)
            {
                if (it != sent.end())
                {
                    viewer.entity->pushPacket(makePacket(caster, true));
                    sent.erase(it);
                }
                continue;
            }
            const auto sig = signature(caster);
            if (it == sent.end() || it->second.signature != sig ||
                now - it->second.at >= Refresh)
            {
                viewer.entity->pushPacket(makePacket(caster, false));
                sent[key] = Delivered{sig, now};
            }
        }
    }
}
void forgetActor(uint32 actor)
{
    for (auto& zoneEntry : sentByZone)
    {
        auto& sent = zoneEntry.second;
        for (auto it = sent.begin(); it != sent.end(); )
        {
            const uint32 viewer = static_cast<uint32>(it->first >> 32);
            const uint32 caster = static_cast<uint32>(it->first);
            if (viewer == actor || caster == actor) it = sent.erase(it);
            else ++it;
        }
    }
}
} // namespace

class OverlordsSoulActionPeersModule final : public CPPModule
{
    void OnCharZoneIn(CCharEntity* p) override
    {
        if (p) forgetActor(p->id);
    }
    void OnCharZoneOut(CCharEntity* p) override
    {
        if (p) forgetActor(p->id);
    }
    void OnZoneTick(CZone* z) override
    {
        if (!z) return;
        const auto now = timer::now();
        if (next[z] > now) return;
        next[z] = now + PeerTick;
        announce(z, now);
    }
};
REGISTER_CPP_MODULE(OverlordsSoulActionPeersModule);
