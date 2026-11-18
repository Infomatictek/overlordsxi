/************************************************************************
 * OverlordsXI Universal Soul HUD Binary Sync
 *
 * Pushes authoritative Soul HUD state to players via custom S2C packet
 * 0x1FC ("OXHD") so zero chat commands or 0x017 chat packets are used.
 ************************************************************************/

#include "common/timer.h"
#include "common/utils.h"

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

constexpr uint16      PacketTypeSoulHudSync = 0x1FC;
constexpr uint8       ProtocolVersion       = 1;
constexpr std::size_t HeaderBytes           = 16;
constexpr std::size_t MaxPayloadBytes       = 236; // 16 + 236 = 252 bytes (<= PACKET_SIZE)
constexpr auto        SyncTickInterval      = 500ms;
constexpr auto        ResyncInterval        = 10s;

struct SentHudState
{
    uint64            signature{ 0 };
    timer::time_point lastSentAt{};
};

std::unordered_map<uint32, SentHudState>            charHudStates;
std::unordered_map<const CZone*, timer::time_point> nextZoneSyncAt;

auto ComputeFnv1a(uint8 jobId, uint8 unlocked, const std::string& soulKey, const std::string& kvStr) -> uint64
{
    uint64 hash = 0xcbf29ce484222325ULL;
    auto   mix  = [&](uint8 b)
    {
        hash ^= b;
        hash *= 0x100000001b3ULL;
    };

    mix(jobId);
    mix(unlocked);
    for (unsigned char c : soulKey)
    {
        mix(c);
    }
    mix('|');
    for (unsigned char c : kvStr)
    {
        mix(c);
    }
    return hash;
}

auto MakeHudPacket(uint8 jobId, uint8 unlocked, const std::string& soulKey, const std::string& kvStr) -> std::unique_ptr<CBasicPacket>
{
    const std::size_t keyLen   = std::min<std::size_t>(soulKey.size(), 48);
    const std::size_t maxKv    = MaxPayloadBytes > keyLen ? (MaxPayloadBytes - keyLen) : 0;
    const std::size_t kvLen    = std::min<std::size_t>(kvStr.size(), maxKv);
    const std::size_t rawBytes = HeaderBytes + keyLen + kvLen;
    const std::size_t padded   = (rawBytes + 3u) & ~std::size_t(3u);

    auto packet = std::make_unique<CBasicPacket>();
    packet->setType(PacketTypeSoulHudSync);
    packet->setSize(padded);

    packet->ref<uint8>(0x04)  = 'O';
    packet->ref<uint8>(0x05)  = 'X';
    packet->ref<uint8>(0x06)  = 'H';
    packet->ref<uint8>(0x07)  = 'D';
    packet->ref<uint8>(0x08)  = ProtocolVersion;
    packet->ref<uint8>(0x09)  = unlocked ? 1 : 0;
    packet->ref<uint8>(0x0A)  = jobId;
    packet->ref<uint8>(0x0B)  = static_cast<uint8>(keyLen);
    packet->ref<uint16>(0x0C) = static_cast<uint16>(kvLen);
    packet->ref<uint16>(0x0E) = 0;

    if (keyLen > 0)
    {
        std::memcpy(&packet->ref<uint8>(HeaderBytes), soulKey.data(), keyLen);
    }
    if (kvLen > 0)
    {
        std::memcpy(&packet->ref<uint8>(HeaderBytes + keyLen), kvStr.data(), kvLen);
    }

    return packet;
}

void SyncCharHud(CCharEntity* PChar, timer::time_point tick, bool force)
{
    if (!PChar || PChar->status == xi::Status::Disappear)
    {
        return;
    }

    auto xiObj = lua["xi"];
    if (!xiObj.valid())
    {
        return;
    }
    auto overlordsObj = xiObj["overlords"];
    if (!overlordsObj.valid())
    {
        return;
    }
    auto hudObj = overlordsObj["hud"];
    if (!hudObj.valid())
    {
        return;
    }
    sol::protected_function fn = hudObj["buildPacketData"];
    if (!fn.valid())
    {
        return;
    }

    auto res = fn(PChar);
    if (!res.valid())
    {
        return;
    }

    sol::object retObj = res.get<sol::object>();
    if (!retObj.valid() || retObj.get_type() != sol::type::table)
    {
        return;
    }

    sol::table  tbl      = retObj.as<sol::table>();
    uint8       jobId    = tbl.get_or<uint8>("jobId", 0);
    uint8       unlocked = tbl.get_or<uint8>("unlocked", 0);
    std::string soulKey  = tbl.get_or<std::string>("soulKey", "");
    std::string kvStr    = tbl.get_or<std::string>("kv", "");

    const uint64 sig    = ComputeFnv1a(jobId, unlocked, soulKey, kvStr);
    const auto   prevIt = charHudStates.find(PChar->id);
    const bool   changed = prevIt == charHudStates.end() || prevIt->second.signature != sig;
    const bool   resync  = prevIt != charHudStates.end() && (tick - prevIt->second.lastSentAt) >= ResyncInterval;

    if (force || changed || resync)
    {
        PChar->pushPacket(MakeHudPacket(jobId, unlocked, soulKey, kvStr));
        charHudStates[PChar->id] = SentHudState{
            .signature  = sig,
            .lastSentAt = tick,
        };
    }
}

} // namespace

class OverlordsSoulHudSyncModule : public CPPModule
{
    void OnInit() override
    {
    }

    void OnCharZoneIn(CCharEntity* PChar) override
    {
        if (!PChar)
        {
            return;
        }
        charHudStates.erase(PChar->id);
        SyncCharHud(PChar, timer::now(), true);
    }

    void OnCharZoneOut(CCharEntity* PChar) override
    {
        if (!PChar)
        {
            return;
        }
        charHudStates.erase(PChar->id);
    }

    void OnZoneTick(CZone* PZone) override
    {
        if (!PZone)
        {
            return;
        }

        const auto tick = timer::now();
        if (nextZoneSyncAt[PZone] > tick)
        {
            return;
        }
        nextZoneSyncAt[PZone] = tick + SyncTickInterval;

        std::vector<CCharEntity*> chars;
        PZone->ForEachChar(
            [&chars](CCharEntity* PChar)
            {
                if (PChar && PChar->status != xi::Status::Disappear)
                {
                    chars.push_back(PChar);
                }
            });

        for (auto* PChar : chars)
        {
            SyncCharHud(PChar, tick, false);
        }
    }
};

REGISTER_CPP_MODULE(OverlordsSoulHudSyncModule);
