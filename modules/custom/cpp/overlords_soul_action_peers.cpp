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

constexpr uint16 PeerPacketType  = 0x1FC;
constexpr uint8  ProtocolVersion = 1;
constexpr auto   PeerTick        = 2s;
constexpr auto   Refresh         = 45s;     // Client expires announcements after 120s.
constexpr float  RadiusSq        = 2500.0f; // 50 yalms, same-zone and same-instance only.

struct Peer
{
    CCharEntity* entity{};
    uint32       actor{};
    uint8        job{};
    uint8        branch{};
    std::string  name;
    std::string  key;
};

struct Delivered
{
    uint64            signature{};
    timer::time_point at{};
    uint8             job{};
    std::string       name;
};

std::unordered_map<const CZone*, std::unordered_map<uint64, Delivered>> sentByZone;
std::unordered_map<const CZone*, timer::time_point>                     nextZoneTick;

bool valid(const std::string& s, bool isName)
{
    if (s.size() < 2 || s.size() > (isName ? 24u : 64u))
    {
        return false;
    }
    for (unsigned char c : s)
    {
        const bool alpha = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
        const bool digit = (c >= '0' && c <= '9');
        if (!alpha && !digit && c != '-' && c != '_')
        {
            return false;
        }
    }
    return !isName || ((s[0] >= 'A' && s[0] <= 'Z') || (s[0] >= 'a' && s[0] <= 'z'));
}

bool validJob(uint8 job)
{
    return job >= 1 && job <= 22;
}

Peer fetch(CCharEntity* player)
{
    Peer peer{};
    peer.entity = player;
    peer.actor  = player->id;
    peer.job    = static_cast<uint8>(player->GetMJob());
    peer.name   = player->name;
    if (peer.actor == 0 || !valid(peer.name, true))
    {
        return peer;
    }

    auto x = lua["xi"];
    if (!x.valid())
    {
        return peer;
    }
    auto o = x["overlords"];
    if (!o.valid())
    {
        return peer;
    }
    auto h = o["hud"];
    if (!h.valid())
    {
        return peer;
    }
    sol::protected_function fn = h["buildIdentityData"];
    if (!fn.valid())
    {
        return peer;
    }
    const auto result = fn(player);
    if (!result.valid())
    {
        return peer;
    }
    sol::object object = result.get<sol::object>();
    if (!object.valid() || object.get_type() != sol::type::table)
    {
        return peer;
    }

    auto        tbl    = object.as<sol::table>();
    const uint8 tblJob = tbl.get_or<uint8>("jobId", peer.job);
    if (validJob(tblJob))
    {
        peer.job = tblJob;
    }
    peer.branch = tbl.get_or<uint8>("branch", 0);
    peer.key    = tbl.get_or<std::string>("soulKey", "");
    if (!validJob(peer.job) || peer.branch < 1 || peer.branch > 3 || !valid(peer.key, false))
    {
        peer.branch = 0;
        peer.key.clear();
    }
    return peer;
}

auto makePacket(uint32 actor, uint8 job, uint8 branch, const std::string& name, const std::string& key, bool remove) -> std::unique_ptr<CBasicPacket>
{
    if (actor == 0 || !validJob(job) || !valid(name, true))
    {
        return nullptr;
    }
    if (!remove && (branch < 1 || branch > 3 || !valid(key, false)))
    {
        return nullptr;
    }

    const std::size_t n      = name.size();
    const std::size_t k      = remove ? 0u : key.size();
    const std::size_t raw    = 22u + n + k;
    const std::size_t padded = (raw + 3u) & ~std::size_t(3u);

    auto p = std::make_unique<CBasicPacket>();
    p->setType(PeerPacketType);
    p->setSize(padded);

    p->ref<uint8>(0x04)  = 'O';
    p->ref<uint8>(0x05)  = 'X';
    p->ref<uint8>(0x06)  = 'S';
    p->ref<uint8>(0x07)  = 'I';
    p->ref<uint8>(0x08)  = ProtocolVersion;
    p->ref<uint8>(0x09)  = remove ? 0 : 1;
    p->ref<uint32>(0x0A) = actor;
    p->ref<uint32>(0x0E) = actor;
    p->ref<uint8>(0x12)  = job;
    p->ref<uint8>(0x13)  = remove ? 0 : branch;
    p->ref<uint8>(0x14)  = static_cast<uint8>(n);
    p->ref<uint8>(0x15)  = static_cast<uint8>(k);

    std::memcpy(&p->ref<uint8>(0x16), name.data(), n);
    if (k > 0)
    {
        std::memcpy(&p->ref<uint8>(0x16 + n), key.data(), k);
    }
    const std::size_t tail = padded - raw;
    if (tail > 0)
    {
        std::memset(&p->ref<uint8>(0x16 + n + k), 0, tail);
    }
    return p;
}

uint64 signature(const Peer& p)
{
    uint64 v   = 14695981039346656037ULL;
    auto   mix = [&](unsigned char c)
    {
        v ^= c;
        v *= 1099511628211ULL;
    };
    mix(p.job);
    mix(p.branch);
    for (unsigned char c : p.key)
    {
        mix(c);
    }
    mix('|');
    for (unsigned char c : p.name)
    {
        mix(c);
    }
    return v;
}

uint64 pairKey(uint32 viewerActor, uint32 casterActor)
{
    return (static_cast<uint64>(viewerActor) << 32) | casterActor;
}

bool nearby(const Peer& viewer, const Peer& caster)
{
    if (viewer.entity->PInstance != caster.entity->PInstance)
    {
        return false;
    }
    const float x = viewer.entity->loc.p.x - caster.entity->loc.p.x;
    const float y = viewer.entity->loc.p.y - caster.entity->loc.p.y;
    const float z = viewer.entity->loc.p.z - caster.entity->loc.p.z;
    return x * x + y * y + z * z <= RadiusSq;
}

void announce(CZone* zone, timer::time_point now)
{
    std::vector<CCharEntity*> chars;
    zone->ForEachChar(
        [&](CCharEntity* ch)
        {
            if (ch && ch->id != 0 && ch->status != xi::Status::Disappear)
            {
                chars.push_back(ch);
            }
        });

    auto sentZoneIt = sentByZone.find(zone);
    if (chars.empty())
    {
        if (sentZoneIt != sentByZone.end())
        {
            sentByZone.erase(sentZoneIt);
        }
        return;
    }

    if (chars.size() < 2 && (sentZoneIt == sentByZone.end() || sentZoneIt->second.empty()))
    {
        return;
    }

    std::vector<Peer> peers;
    peers.reserve(chars.size());
    std::unordered_map<uint32, std::size_t> byActor;
    byActor.reserve(chars.size());
    for (CCharEntity* ch : chars)
    {
        byActor[ch->id] = peers.size();
        peers.push_back(fetch(ch));
    }

    auto& sent = sentByZone[zone]; // Avoid entity ID collisions across zones.

    // Revoke any previously announced caster that disappeared or left the zone,
    // and drop entries whose viewer is no longer present.
    for (auto it = sent.begin(); it != sent.end();)
    {
        const uint32 viewerId = static_cast<uint32>(it->first >> 32);
        const uint32 casterId = static_cast<uint32>(it->first);
        const auto   viewerIt = byActor.find(viewerId);
        if (viewerIt == byActor.end())
        {
            it = sent.erase(it);
            continue;
        }
        if (byActor.find(casterId) == byActor.end())
        {
            if (auto pkt = makePacket(casterId, it->second.job, 0, it->second.name, "", true))
            {
                peers[viewerIt->second].entity->pushPacket(std::move(pkt));
            }
            it = sent.erase(it);
            continue;
        }
        ++it;
    }

    for (const Peer& viewer : peers)
    {
        if (!viewer.entity || viewer.actor == 0 || !valid(viewer.name, true))
        {
            continue;
        }
        for (const Peer& caster : peers)
        {
            if (caster.actor == 0 || caster.actor == viewer.actor || !valid(caster.name, true))
            {
                continue;
            }
            const auto key     = pairKey(viewer.actor, caster.actor);
            const auto it      = sent.find(key);
            const bool present = caster.branch > 0 && validJob(caster.job) && nearby(viewer, caster);
            if (!present)
            {
                if (it != sent.end())
                {
                    const uint8        revokeJob  = validJob(caster.job) ? caster.job : it->second.job;
                    const std::string& revokeName = valid(caster.name, true) ? caster.name : it->second.name;
                    if (auto pkt = makePacket(caster.actor, revokeJob, 0, revokeName, "", true))
                    {
                        viewer.entity->pushPacket(std::move(pkt));
                    }
                    sent.erase(it);
                }
                continue;
            }

            const auto sig = signature(caster);
            if (it == sent.end() || it->second.signature != sig || now - it->second.at >= Refresh)
            {
                if (auto pkt = makePacket(caster.actor, caster.job, caster.branch, caster.name, caster.key, false))
                {
                    viewer.entity->pushPacket(std::move(pkt));
                    sent[key] = Delivered{ sig, now, caster.job, caster.name };
                }
            }
        }
    }

    if (sent.empty())
    {
        sentByZone.erase(zone);
    }
}

void revokeAndForgetActor(CCharEntity* player, bool notifyZoneViewers)
{
    if (!player || player->id == 0)
    {
        return;
    }

    const uint32 actor = player->id;
    CZone*       zone  = player->loc.zone;

    std::unordered_map<uint32, CCharEntity*> activeViewers;
    if (notifyZoneViewers && zone != nullptr)
    {
        zone->ForEachChar(
            [&](CCharEntity* ch)
            {
                if (ch && ch->id != 0 && ch->id != actor && ch->status != xi::Status::Disappear)
                {
                    activeViewers[ch->id] = ch;
                }
            });
    }

    for (auto zoneIt = sentByZone.begin(); zoneIt != sentByZone.end();)
    {
        auto& sent = zoneIt->second;
        for (auto it = sent.begin(); it != sent.end();)
        {
            const uint32 viewerId = static_cast<uint32>(it->first >> 32);
            const uint32 casterId = static_cast<uint32>(it->first);
            if (viewerId == actor || casterId == actor)
            {
                if (notifyZoneViewers && casterId == actor && zoneIt->first == zone)
                {
                    const auto vIt = activeViewers.find(viewerId);
                    if (vIt != activeViewers.end())
                    {
                        if (auto pkt = makePacket(actor, it->second.job, 0, it->second.name, "", true))
                        {
                            vIt->second->pushPacket(std::move(pkt));
                        }
                    }
                }
                it = sent.erase(it);
            }
            else
            {
                ++it;
            }
        }

        if (sent.empty())
        {
            zoneIt = sentByZone.erase(zoneIt);
        }
        else
        {
            ++zoneIt;
        }
    }
}

} // namespace

class OverlordsSoulActionPeersModule final : public CPPModule
{
    void OnInit() override
    {
    }

    void OnCharZoneIn(CCharEntity* p) override
    {
        revokeAndForgetActor(p, false);
    }

    void OnCharZoneOut(CCharEntity* p) override
    {
        revokeAndForgetActor(p, true);
    }

    void OnZoneTick(CZone* z) override
    {
        if (!z)
        {
            return;
        }
        const auto now = timer::now();
        if (nextZoneTick[z] > now)
        {
            return;
        }
        nextZoneTick[z] = now + PeerTick;
        announce(z, now);
    }
};

REGISTER_CPP_MODULE(OverlordsSoulActionPeersModule);
