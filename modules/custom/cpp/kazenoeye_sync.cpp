/************************************************************************
 * Kazenoeye Live Status Sync
 *
 * Pushes authoritative entity status effect icons and exact remaining
 * durations from the server to nearby players using custom S2C packet
 * 0x1FE ("OXKE") so the client kazenoeye HUD never relies on guessed or
 * hardcoded timers.
 ************************************************************************/

#include "common/timer.h"
#include "common/utils.h"

#include "map/entities/battle_entity.h"
#include "map/entities/char_entity.h"
#include "map/entities/mob_entity.h"
#include "map/entities/pet_entity.h"
#include "map/packets/basic.h"
#include "map/status_effect.h"
#include "map/status_effect_container.h"
#include "map/utils/moduleutils.h"
#include "map/zone.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <memory>
#include <unordered_map>
#include <vector>

using namespace std::chrono_literals;

namespace
{

constexpr uint16 PacketTypeKazenoeyeSync = 0x1FE;
constexpr uint8  ProtocolVersion         = 1;

enum class SyncOp : uint8
{
    Hello          = 0,
    EntitySnapshot = 1,
    EntityClear    = 2,
};

constexpr std::size_t HeaderBytes         = 16;
constexpr std::size_t EntryBytes          = 8;
constexpr std::size_t MaxEntriesPerPacket = 30; // 16 + 30 * 8 = 256 bytes (<= PACKET_SIZE 0x1FF)
constexpr uint32      NoTimerMarker       = 0xFFFFFFFFu;

constexpr float SyncRangeYalms   = 52.0f;
constexpr float ClearRangeYalms  = 55.0f;
constexpr auto  SyncTickInterval = 200ms;
constexpr auto  ResyncInterval   = 3s;

struct EffectEntry
{
    uint16 iconId{ 0 };
    uint16 effectId{ 0 };
    uint32 remainingMs{ 0 };
};

struct EntitySnapshot
{
    uint32                   serverId{ 0 };
    CInstance*               instance{ nullptr };
    position_t               pos{};
    uint64                   signature{ 0 };
    std::vector<EffectEntry> entries;
};

struct SentEntityState
{
    uint64            signature{ 0 };
    timer::time_point lastSentAt{};
};

struct CharSyncState
{
    std::unordered_map<uint32, SentEntityState> entities;
};

std::unordered_map<uint32, CharSyncState>           charSyncStates;
std::unordered_map<const CZone*, timer::time_point> nextZoneSyncAt;

auto HashCombine(uint64 seed, uint64 value) -> uint64
{
    seed ^= value + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    return seed;
}

auto CollectEntitySnapshot(CBattleEntity* PEntity, timer::time_point tick) -> EntitySnapshot
{
    EntitySnapshot snapshot;
    if (!PEntity || PEntity->isDead() || PEntity->status == xi::Status::Disappear || !PEntity->StatusEffectContainer)
    {
        return snapshot;
    }

    snapshot.serverId = PEntity->id;
    snapshot.instance = PEntity->PInstance;
    snapshot.pos      = PEntity->loc.p;

    uint64 sig = 0xcbf29ce484222325ULL;

    PEntity->StatusEffectContainer->ForEachEffect(
        [&](CStatusEffect& effect)
        {
            if (snapshot.entries.size() >= MaxEntriesPerPacket)
            {
                return;
            }

            if (effect.isDeleted())
            {
                return;
            }

            const uint16 iconId = effect.GetIcon();
            if (iconId == 0)
            {
                return;
            }

            if (effect.HasEffectFlag(xi::StatusEffectFlag::Confrontation))
            {
                return;
            }

            uint32 remainingMs = NoTimerMarker;
            int64  startTicks  = 0;
            int64  durationMs  = 0;

            const auto duration = effect.GetDuration();
            if (duration > 0s && !effect.HasEffectFlag(xi::StatusEffectFlag::HideTimer))
            {
                const auto start = effect.GetStartTime();
                const auto remMs = timer::count_milliseconds((start + duration) - tick);
                if (remMs <= 0)
                {
                    return;
                }

                remainingMs = static_cast<uint32>(std::min<int64>(remMs, static_cast<int64>(NoTimerMarker - 1)));
                startTicks  = static_cast<int64>(start.time_since_epoch().count());
                durationMs  = timer::count_milliseconds(duration);
            }

            const uint16 effectId = static_cast<uint16>(effect.GetStatusID());
            snapshot.entries.push_back(EffectEntry{
                .iconId      = iconId,
                .effectId    = effectId,
                .remainingMs = remainingMs,
            });

            sig = HashCombine(sig, iconId);
            sig = HashCombine(sig, effectId);
            sig = HashCombine(sig, remainingMs == NoTimerMarker ? 1ULL : 0ULL);
            sig = HashCombine(sig, static_cast<uint64>(startTicks));
            sig = HashCombine(sig, static_cast<uint64>(durationMs));
        });

    snapshot.signature = sig;
    return snapshot;
}

auto MakeHeaderPacket(SyncOp op, uint8 count, uint32 entityServerId, std::size_t totalBytes) -> std::unique_ptr<CBasicPacket>
{
    auto packet = std::make_unique<CBasicPacket>();
    packet->setType(PacketTypeKazenoeyeSync);
    packet->setSize(totalBytes);

    packet->ref<uint8>(0x04)  = 'O';
    packet->ref<uint8>(0x05)  = 'X';
    packet->ref<uint8>(0x06)  = 'K';
    packet->ref<uint8>(0x07)  = 'E';
    packet->ref<uint8>(0x08)  = ProtocolVersion;
    packet->ref<uint8>(0x09)  = static_cast<uint8>(op);
    packet->ref<uint8>(0x0A)  = count;
    packet->ref<uint8>(0x0B)  = 0;
    packet->ref<uint32>(0x0C) = entityServerId;

    return packet;
}

auto MakeHelloPacket(uint32 charId) -> std::unique_ptr<CBasicPacket>
{
    return MakeHeaderPacket(SyncOp::Hello, 0, charId, HeaderBytes);
}

auto MakeClearPacket(uint32 entityServerId) -> std::unique_ptr<CBasicPacket>
{
    return MakeHeaderPacket(SyncOp::EntityClear, 0, entityServerId, HeaderBytes);
}

auto MakeSnapshotPacket(const EntitySnapshot& snapshot) -> std::unique_ptr<CBasicPacket>
{
    const auto count      = static_cast<uint8>(std::min<std::size_t>(snapshot.entries.size(), MaxEntriesPerPacket));
    const auto totalBytes = HeaderBytes + static_cast<std::size_t>(count) * EntryBytes;
    auto       packet     = MakeHeaderPacket(SyncOp::EntitySnapshot, count, snapshot.serverId, totalBytes);

    for (std::size_t i = 0; i < count; ++i)
    {
        const auto&       entry  = snapshot.entries[i];
        const std::size_t offset = HeaderBytes + i * EntryBytes;
        packet->ref<uint16>(offset + 0x00) = entry.iconId;
        packet->ref<uint16>(offset + 0x02) = entry.effectId;
        packet->ref<uint32>(offset + 0x04) = entry.remainingMs;
    }

    return packet;
}

} // namespace

class KazenoeyeSyncModule : public CPPModule
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

        charSyncStates.erase(PChar->id);
        PChar->pushPacket(MakeHelloPacket(PChar->id));
    }

    void OnCharZoneOut(CCharEntity* PChar) override
    {
        if (!PChar)
        {
            return;
        }

        charSyncStates.erase(PChar->id);
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

        if (chars.empty())
        {
            return;
        }

        std::unordered_map<uint32, EntitySnapshot> activeSnapshots;
        auto collectEntity = [&](CBattleEntity* PEntity)
        {
            auto snapshot = CollectEntitySnapshot(PEntity, tick);
            if (!snapshot.entries.empty())
            {
                activeSnapshots.emplace(snapshot.serverId, std::move(snapshot));
            }
        };

        PZone->ForEachMob(collectEntity);
        PZone->ForEachPet(collectEntity);
        PZone->ForEachAlly(collectEntity);

        for (auto* PChar : chars)
        {
            auto& charState = charSyncStates[PChar->id];

            // Clear any entities that are no longer active, changed instance, or moved out of sync range.
            for (auto it = charState.entities.begin(); it != charState.entities.end();)
            {
                const auto snapIt = activeSnapshots.find(it->first);
                const bool shouldClear =
                    snapIt == activeSnapshots.end() ||
                    snapIt->second.instance != PChar->PInstance ||
                    distance(PChar->loc.p, snapIt->second.pos) > ClearRangeYalms;

                if (shouldClear)
                {
                    PChar->pushPacket(MakeClearPacket(it->first));
                    it = charState.entities.erase(it);
                }
                else
                {
                    ++it;
                }
            }

            if (activeSnapshots.empty())
            {
                continue;
            }

            // Send initial/changed snapshots or periodic clock resyncs to nearby players.
            for (const auto& [entityId, snapshot] : activeSnapshots)
            {
                if (snapshot.instance != PChar->PInstance)
                {
                    continue;
                }

                if (distance(PChar->loc.p, snapshot.pos) > SyncRangeYalms)
                {
                    continue;
                }

                const auto prevIt = charState.entities.find(entityId);
                const bool changed = prevIt == charState.entities.end() || prevIt->second.signature != snapshot.signature;
                const bool resyncDue = prevIt != charState.entities.end() && (tick - prevIt->second.lastSentAt) >= ResyncInterval;

                if (changed || resyncDue)
                {
                    PChar->pushPacket(MakeSnapshotPacket(snapshot));
                    charState.entities[entityId] = SentEntityState{
                        .signature  = snapshot.signature,
                        .lastSentAt = tick,
                    };
                }
            }
        }
    }
};

REGISTER_CPP_MODULE(KazenoeyeSyncModule);
