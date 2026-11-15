/************************************************************************
 * Eos & Titania Faerie Companions
 *
 * Adds Eos (SCH Medic Light Arts) and Titania (SCH Sage Dark Arts)
 * companion behavior as a C++ module:
 * - Eos: removes priority debuffs and maintains stackable Regen on party/trusts
 * - Titania: assists in combat by enfeebling, draining, and elemental nuking
 * - Both: apply Orphic Egg's level-scaling Refresh (and Sage magic bonuses for Titania)
 ************************************************************************/

#include "common/utils.h"

#include "map/ai/ai_container.h"
#include "map/ai/controllers/controller.h"
#include "map/enmity_container.h"
#include "map/entities/battle_entity.h"
#include "map/entities/char_entity.h"
#include "map/entities/mob_entity.h"
#include "map/entities/pet_entity.h"
#include "map/entities/trust_entity.h"
#include "map/mob_spell_container.h"
#include "map/mob_spell_list.h"
#include "map/modifier.h"
#include "map/recast_container.h"
#include "map/spell.h"
#include "map/status_effect.h"
#include "map/status_effect_container.h"
#include "map/utils/battleutils.h"
#include "map/utils/mobutils.h"
#include "map/utils/moduleutils.h"
#include "map/utils/petutils.h"
#include "map/zone.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <memory>
#include <optional>
#include <unordered_map>
#include <utility>
#include <vector>

using namespace std::chrono_literals;

namespace
{

constexpr uint32           EosPetId              = 128;
constexpr uint32           TitaniaPetId          = 129;
constexpr auto             SchSpecVar            = "OX_SPEC_SCH";
constexpr int32            SchMedicSpecId        = 1;
constexpr int32            SchSageSpecId         = 2;
constexpr uint8            MinSpecLevel          = 10;
constexpr xi::StatusEffect EosRegenEffect        = static_cast<xi::StatusEffect>(789);
constexpr xi::StatusEffect FaerieRefreshEffect   = static_cast<xi::StatusEffect>(814);
constexpr xi::Mod          FaerieRefreshMod      = static_cast<xi::Mod>(1198);
constexpr float            FaerieActionRange     = 20.0f;
constexpr auto             FaerieCastCooldown    = 5s;
constexpr auto             TitaniaEnfeebleWindow = 10s;
constexpr auto             TitaniaRetryWindow    = 20s;
constexpr auto             FaerieRefreshDuration = 10s;
constexpr auto             EosRegenWindow        = 15s;

struct FaerieCastAction
{
    SpellID        spellId;
    CBattleEntity* PTarget;
};

struct ElementalLine
{
    xi::Mod                   resMod;
    std::array<SpellID, 5>    tiers; // Tier I .. Tier V
};

constexpr std::array<ElementalLine, 6> TitaniaElements =
{
    ElementalLine{ xi::Mod::THUNDER_RES_RANK, { SpellID::Thunder, SpellID::Thunder_II, SpellID::Thunder_III, SpellID::Thunder_IV, SpellID::Thunder_V } },
    ElementalLine{ xi::Mod::ICE_RES_RANK, { SpellID::Blizzard, SpellID::Blizzard_II, SpellID::Blizzard_III, SpellID::Blizzard_IV, SpellID::Blizzard_V } },
    ElementalLine{ xi::Mod::FIRE_RES_RANK, { SpellID::Fire, SpellID::Fire_II, SpellID::Fire_III, SpellID::Fire_IV, SpellID::Fire_V } },
    ElementalLine{ xi::Mod::WIND_RES_RANK, { SpellID::Aero, SpellID::Aero_II, SpellID::Aero_III, SpellID::Aero_IV, SpellID::Aero_V } },
    ElementalLine{ xi::Mod::WATER_RES_RANK, { SpellID::Water, SpellID::Water_II, SpellID::Water_III, SpellID::Water_IV, SpellID::Water_V } },
    ElementalLine{ xi::Mod::EARTH_RES_RANK, { SpellID::Stone, SpellID::Stone_II, SpellID::Stone_III, SpellID::Stone_IV, SpellID::Stone_V } },
};

std::unordered_map<uint32, timer::time_point> nextFaerieCastTime;
std::unordered_map<uint32, timer::time_point> nextTitaniaEnfeebleTime;
std::unordered_map<uint64, timer::time_point> nextTitaniaSpellRetryTime;

bool IsEos(CPetEntity* PPet)
{
    return PPet && PPet->petID() == EosPetId && PPet->isAlive();
}

bool IsTitania(CPetEntity* PPet)
{
    return PPet && PPet->petID() == TitaniaPetId && PPet->isAlive();
}

bool IsMedicScholar(CCharEntity* PMaster)
{
    return PMaster && PMaster->GetMJob() == xi::Job::SCH && PMaster->GetMLevel() >= MinSpecLevel &&
           PMaster->getCharVar(SchSpecVar) == SchMedicSpecId;
}

bool IsSageScholar(CCharEntity* PMaster)
{
    return PMaster && PMaster->GetMJob() == xi::Job::SCH && PMaster->GetMLevel() >= MinSpecLevel &&
           PMaster->getCharVar(SchSpecVar) == SchSageSpecId;
}

bool EnsureOwnerAndJobs(CPetEntity* PPet)
{
    if (!PPet || !PPet->PMaster || PPet->PMaster->objtype != TYPE_PC)
    {
        return false;
    }

    auto*      PMaster   = static_cast<CCharEntity*>(PPet->PMaster);
    const bool isEosPet  = IsEos(PPet);
    const bool authorized = isEosPet ? IsMedicScholar(PMaster) : IsSageScholar(PMaster);

    if (!authorized)
    {
        petutils::DespawnPet(PMaster);
        return false;
    }

    const auto expectedMainJob  = isEosPet ? xi::Job::SCH : xi::Job::BLM;
    const auto expectedSubJob   = isEosPet ? xi::Job::SMN : xi::Job::RDM;
    const auto expectedSpellLst = isEosPet ? uint16{ 566 } : uint16{ 600 };
    const auto mainLevel        = PMaster->GetMLevel();
    const bool levelChanged     = PPet->GetMLevel() != mainLevel || PPet->GetSLevel() != mainLevel;
    const bool jobChanged       = PPet->GetMJob() != expectedMainJob || PPet->GetSJob(true) != expectedSubJob;
    const bool spellsMissing    = PPet->m_SpellListContainer == nullptr || !PPet->SpellContainer || !PPet->SpellContainer->HasSpells();

    if (PPet->GetMJob() != expectedMainJob)
    {
        PPet->SetMJob(static_cast<uint8>(expectedMainJob));
    }

    if (PPet->GetSJob(true) != expectedSubJob)
    {
        PPet->SetSJob(static_cast<uint8>(expectedSubJob));
    }

    if (PPet->GetMLevel() != mainLevel)
    {
        PPet->SetMLevel(mainLevel);
    }

    if (PPet->GetSLevel() != mainLevel)
    {
        PPet->SetSLevel(mainLevel);
    }

    if (PPet->m_SpellListContainer == nullptr)
    {
        PPet->m_SpellListContainer = mobSpellList::GetMobSpellList(expectedSpellLst);
    }

    if (levelChanged || jobChanged || spellsMissing)
    {
        const uint8 skillLvl = std::min<uint8>(mainLevel, 99);
        for (int i = static_cast<int>(xi::SkillType::DivineMagic); i <= static_cast<int>(xi::SkillType::BlueMagic); ++i)
        {
            const auto skillType = static_cast<xi::SkillType>(i);
            uint16     maxSkill  = battleutils::GetMaxSkill(skillType, expectedMainJob, skillLvl);
            if (maxSkill == 0)
            {
                maxSkill = battleutils::GetMaxSkill(skillType, expectedSubJob, skillLvl);
            }
            PPet->WorkingSkills.skill[i] = maxSkill;
        }

        if (levelChanged || PPet->health.maxmp <= 0)
        {
            const int32 expectedMaxMp = static_cast<int32>(15.2 * std::pow(static_cast<double>(mainLevel), 1.1075));
            PPet->health.maxmp        = std::max<int32>(1, expectedMaxMp);
            PPet->UpdateHealth();
            if (PPet->health.mp > PPet->GetMaxMP() || levelChanged)
            {
                PPet->health.mp = PPet->GetMaxMP();
            }
        }

        if (PPet->m_SpellListContainer != nullptr)
        {
            mobutils::GetAvailableSpells(PPet);
        }
    }

    return true;
}

bool IsInFaerieRange(CPetEntity* PPet, CBattleEntity* PTarget)
{
    return PPet && PTarget && !PTarget->isDead() && PTarget->loc.zone == PPet->loc.zone &&
           distance(PPet->loc.p, PTarget->loc.p) <= FaerieActionRange;
}

bool CanCast(CPetEntity* PPet, SpellID spellId, bool checkMp)
{
    if (!PPet || !PPet->PAI || !PPet->PAI->CanChangeState() || !PPet->SpellContainer || !PPet->SpellContainer->HasSpells())
    {
        return false;
    }

    if (PPet->StatusEffectContainer->HasStatusEffect({ xi::StatusEffect::Silence, xi::StatusEffect::Mute }) ||
        PPet->StatusEffectContainer->HasPreventActionEffect())
    {
        return false;
    }

    auto* PController = PPet->PAI->GetController();
    if (PController && !PController->IsMagicCastingEnabled())
    {
        return false;
    }

    if (!PPet->SpellContainer->GetAvailable(spellId).has_value())
    {
        return false;
    }

    auto* PSpell = spell::GetSpell(spellId);
    if (!PSpell || !PPet->CanUseSpell(PSpell))
    {
        return false;
    }

    if (checkMp && PSpell->hasMPCost())
    {
        const auto cost = battleutils::CalculateSpellCost(PPet, PSpell);
        if (PPet->health.mp < cost)
        {
            return false;
        }
    }

    return true;
}

std::optional<SpellID> GetNaSpell(CBattleEntity* PTarget)
{
    auto* PEffects = PTarget->StatusEffectContainer.get();

    if (PEffects->HasStatusEffect(xi::StatusEffect::Petrification))
    {
        return SpellID::Stona;
    }

    if (PEffects->HasStatusEffect({ xi::StatusEffect::Doom, xi::StatusEffect::CurseI, xi::StatusEffect::CurseIi, xi::StatusEffect::Bane }))
    {
        return SpellID::Cursna;
    }

    if (PEffects->HasStatusEffect(xi::StatusEffect::Paralysis))
    {
        return SpellID::Paralyna;
    }

    if (PEffects->HasStatusEffect(xi::StatusEffect::Silence))
    {
        return SpellID::Silena;
    }

    if (PEffects->HasStatusEffect(xi::StatusEffect::Poison))
    {
        return SpellID::Poisona;
    }

    if (PEffects->HasStatusEffect(xi::StatusEffect::Blindness))
    {
        return SpellID::Blindna;
    }

    if (PEffects->HasStatusEffect({ xi::StatusEffect::Disease, xi::StatusEffect::Plague }))
    {
        return SpellID::Viruna;
    }

    if (PEffects->HasStatusEffectByFlag(xi::StatusEffectFlag::Erasable))
    {
        return SpellID::Erase;
    }

    return std::nullopt;
}

bool NeedsEosRegen(CBattleEntity* PTarget, timer::time_point tick)
{
    auto* PEosRegen = PTarget->StatusEffectContainer->GetStatusEffect(EosRegenEffect);
    return !PEosRegen || PEosRegen->GetStartTime() + PEosRegen->GetDuration() <= tick + EosRegenWindow;
}

SpellID GetEosRegenSpell(CPetEntity* PPet)
{
    const auto level = PPet ? PPet->GetMLevel() : 1;

    if (level >= 81)
    {
        return SpellID::Regen_V;
    }

    if (level >= 61)
    {
        return SpellID::Regen_IV;
    }

    if (level >= 41)
    {
        return SpellID::Regen_III;
    }

    if (level >= 21)
    {
        return SpellID::Regen_II;
    }

    return SpellID::Regen;
}

std::optional<FaerieCastAction> GetEosSupportAction(CPetEntity* PPet, timer::time_point tick)
{
    if (!PPet || !PPet->PMaster || PPet->PMaster->objtype != TYPE_PC)
    {
        return std::nullopt;
    }

    auto* PMaster = static_cast<CCharEntity*>(PPet->PMaster);

    auto checkNaTarget = [&](CBattleEntity* PTarget) -> std::optional<FaerieCastAction>
    {
        if (!IsInFaerieRange(PPet, PTarget))
        {
            return std::nullopt;
        }

        auto spellId = GetNaSpell(PTarget);
        if (spellId.has_value())
        {
            return FaerieCastAction{ spellId.value(), PTarget };
        }

        return std::nullopt;
    };

    if (auto masterAction = checkNaTarget(PMaster); masterAction.has_value())
    {
        return masterAction;
    }

    std::optional<FaerieCastAction> partyAction;
    PMaster->ForPartyWithTrusts(
        [&](CBattleEntity* PMember)
        {
            if (!partyAction.has_value() && PMember && PMember->id != PMaster->id)
            {
                partyAction = checkNaTarget(PMember);
            }
        });

    if (partyAction.has_value())
    {
        return partyAction;
    }

    if (auto petAction = checkNaTarget(PPet); petAction.has_value())
    {
        return petAction;
    }

    auto checkRegenTarget = [&](CBattleEntity* PTarget) -> std::optional<FaerieCastAction>
    {
        if (!IsInFaerieRange(PPet, PTarget) || !NeedsEosRegen(PTarget, tick))
        {
            return std::nullopt;
        }

        return FaerieCastAction{ GetEosRegenSpell(PPet), PTarget };
    };

    if (auto petRegen = checkRegenTarget(PPet); petRegen.has_value())
    {
        return petRegen;
    }

    if (auto masterRegen = checkRegenTarget(PMaster); masterRegen.has_value())
    {
        return masterRegen;
    }

    std::optional<FaerieCastAction> regenAction;
    PMaster->ForPartyWithTrusts(
        [&](CBattleEntity* PMember)
        {
            if (!regenAction.has_value() && PMember && PMember->id != PMaster->id)
            {
                regenAction = checkRegenTarget(PMember);
            }
        });

    return regenAction;
}

void TryEosCast(CPetEntity* PPet, timer::time_point tick)
{
    if (nextFaerieCastTime[PPet->id] > tick)
    {
        return;
    }

    auto action = GetEosSupportAction(PPet, tick);
    if (!action.has_value() || !CanCast(PPet, action->spellId, true))
    {
        return;
    }

    if (PPet->PAI->Cast(action->PTarget->entityId(), action->spellId))
    {
        nextFaerieCastTime[PPet->id] = tick + FaerieCastCooldown;
    }
}

bool IsValidTitaniaTarget(CPetEntity* PPet, CCharEntity* PMaster, CBattleEntity* PTarget, bool requireEngaged)
{
    if (!PPet || !PMaster || !PTarget || !IsInFaerieRange(PPet, PTarget))
    {
        return false;
    }

    if (PTarget->allegiance == PPet->allegiance || !PTarget->PAI || PTarget->PAI->IsUntargetable())
    {
        return false;
    }

    if (auto* PMob = dynamic_cast<CMobEntity*>(PTarget))
    {
        if (!PMaster->IsMobOwner(PMob))
        {
            return false;
        }

        if (requireEngaged && !PMob->PAI->IsEngaged() && !PMob->PEnmityContainer->HasID(PMaster->id) && !PMob->PEnmityContainer->HasID(PPet->id))
        {
            return false;
        }
    }

    return true;
}

CBattleEntity* FindTitaniaTarget(CPetEntity* PPet, CCharEntity* PMaster)
{
    if (!PPet || !PMaster || !PPet->loc.zone)
    {
        return nullptr;
    }

    if (auto* PPetTarget = PPet->GetBattleTarget(); IsValidTitaniaTarget(PPet, PMaster, PPetTarget, false))
    {
        return PPetTarget;
    }

    if (auto* PMasterTarget = PMaster->GetBattleTarget(); IsValidTitaniaTarget(PPet, PMaster, PMasterTarget, false))
    {
        return PMasterTarget;
    }

    if (IsValidTitaniaTarget(PPet, PMaster, PMaster->PClaimedMob, true))
    {
        return PMaster->PClaimedMob;
    }

    if (const auto savedTargId = PMaster->GetLocalVar("OX_TITANIA_TARGET"); savedTargId > 0)
    {
        if (auto* PSaved = dynamic_cast<CBattleEntity*>(PMaster->GetEntity(static_cast<uint16>(savedTargId), TYPE_MOB));
            IsValidTitaniaTarget(PPet, PMaster, PSaved, true))
        {
            return PSaved;
        }
    }

    CMobEntity* PClosestMob   = nullptr;
    float       closestDistSq = std::numeric_limits<float>::max();

    PPet->loc.zone->ForEachMob(
        [&](CMobEntity* PMob)
        {
            if (!PMob || !IsInFaerieRange(PPet, PMob) || !PMob->PAI || PMob->PAI->IsUntargetable() || !PMob->PAI->IsEngaged())
            {
                return;
            }

            if (!PMaster->IsMobOwner(PMob))
            {
                return;
            }

            const bool masterOrPetOnEnmity =
                PMob->PEnmityContainer->HasID(PMaster->id) ||
                PMob->PEnmityContainer->HasID(PPet->id);

            if (!masterOrPetOnEnmity)
            {
                return;
            }

            const float distSq = distanceSquared(PPet->loc.p, PMob->loc.p);
            if (distSq < closestDistSq)
            {
                closestDistSq = distSq;
                PClosestMob   = PMob;
            }
        });

    return PClosestMob;
}

uint64 MakeRetryKey(uint32 targetId, SpellID spellId)
{
    return (static_cast<uint64>(targetId) << 16) | static_cast<uint64>(spellId);
}

bool WasSpellRecentlyTried(uint32 targetId, SpellID spellId, timer::time_point tick)
{
    const auto it = nextTitaniaSpellRetryTime.find(MakeRetryKey(targetId, spellId));
    return it != nextTitaniaSpellRetryTime.end() && it->second > tick;
}

void MarkSpellTried(uint32 targetId, SpellID spellId, timer::time_point tick)
{
    if (nextTitaniaSpellRetryTime.size() > 256)
    {
        for (auto it = nextTitaniaSpellRetryTime.begin(); it != nextTitaniaSpellRetryTime.end();)
        {
            if (it->second <= tick)
            {
                it = nextTitaniaSpellRetryTime.erase(it);
            }
            else
            {
                ++it;
            }
        }
    }

    nextTitaniaSpellRetryTime[MakeRetryKey(targetId, spellId)] = tick + TitaniaRetryWindow;
}

std::optional<SpellID> PickTitaniaEnfeeble(CPetEntity* PPet, CBattleEntity* PTarget, timer::time_point tick)
{
    auto trySpell = [&](SpellID spellId) -> bool
    {
        return !WasSpellRecentlyTried(PTarget->id, spellId, tick) && CanCast(PPet, spellId, true);
    };

    bool hasDispelable = false;
    PTarget->StatusEffectContainer->ForEachEffect(
        [&hasDispelable](const CStatusEffect& PStatus)
        {
            if (!hasDispelable && PStatus.GetDuration() > 0s && PStatus.HasEffectFlag(xi::StatusEffectFlag::Dispelable))
            {
                hasDispelable = true;
            }
        });

    if (hasDispelable && trySpell(SpellID::Dispel))
    {
        return SpellID::Dispel;
    }

    if (nextTitaniaEnfeebleTime[PPet->id] > tick)
    {
        return std::nullopt;
    }

    if (!PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Bio) &&
        !PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Dia))
    {
        if (trySpell(SpellID::Bio_II))
        {
            return SpellID::Bio_II;
        }

        if (trySpell(SpellID::Bio))
        {
            return SpellID::Bio;
        }
    }

    if (!PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Slow) && trySpell(SpellID::Slow))
    {
        return SpellID::Slow;
    }

    if (!PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Paralysis) && trySpell(SpellID::Paralyze))
    {
        return SpellID::Paralyze;
    }

    if (!PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Blindness) && trySpell(SpellID::Blind))
    {
        return SpellID::Blind;
    }

    if (!PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Poison))
    {
        if (trySpell(SpellID::Poison_II))
        {
            return SpellID::Poison_II;
        }

        if (trySpell(SpellID::Poison))
        {
            return SpellID::Poison;
        }
    }

    if (!PTarget->StatusEffectContainer->HasStatusEffect(xi::StatusEffect::Addle) && trySpell(SpellID::Addle))
    {
        return SpellID::Addle;
    }

    return std::nullopt;
}

std::optional<SpellID> PickTitaniaNuke(CPetEntity* PPet, CBattleEntity* PTarget)
{
    std::array<std::pair<std::size_t, int16>, 6> rankedElements;
    for (std::size_t i = 0; i < TitaniaElements.size(); ++i)
    {
        rankedElements[i] = { i, PTarget->getMod(TitaniaElements[i].resMod) };
    }

    std::stable_sort(
        rankedElements.begin(),
        rankedElements.end(),
        [](const auto& a, const auto& b)
        {
            return a.second < b.second;
        });

    const int maxTierIndex = PTarget->GetHPP() <= 15 ? 1 : 4;

    for (const auto& [idx, _] : rankedElements)
    {
        const auto& tiers = TitaniaElements[idx].tiers;
        for (int tier = maxTierIndex; tier >= 0; --tier)
        {
            if (CanCast(PPet, tiers[tier], true))
            {
                return tiers[tier];
            }
        }
    }

    return std::nullopt;
}

void TryTitaniaCast(CPetEntity* PPet, timer::time_point tick)
{
    if (!PPet || !PPet->PMaster || PPet->PMaster->objtype != TYPE_PC || nextFaerieCastTime[PPet->id] > tick)
    {
        return;
    }

    auto* PMaster = static_cast<CCharEntity*>(PPet->PMaster);
    auto* PTarget = FindTitaniaTarget(PPet, PMaster);
    if (!PTarget)
    {
        return;
    }

    // Prioritize Aspir/Drain sustain when needed
    if (PPet->GetMPP() < 55 && PTarget->health.mp > 0)
    {
        if (CanCast(PPet, SpellID::Aspir_II, true) && PPet->PAI->Cast(PTarget->entityId(), SpellID::Aspir_II))
        {
            nextFaerieCastTime[PPet->id] = tick + FaerieCastCooldown;
            return;
        }

        if (CanCast(PPet, SpellID::Aspir, true) && PPet->PAI->Cast(PTarget->entityId(), SpellID::Aspir))
        {
            nextFaerieCastTime[PPet->id] = tick + FaerieCastCooldown;
            return;
        }
    }

    if (PPet->GetHPP() < 70 && PTarget->m_EcoSystem != xi::Ecosystem::Undead &&
        CanCast(PPet, SpellID::Drain, true) && PPet->PAI->Cast(PTarget->entityId(), SpellID::Drain))
    {
        nextFaerieCastTime[PPet->id] = tick + FaerieCastCooldown;
        return;
    }

    // Weave Enfeebling & Dispel with Elemental nuking
    if (auto enfeeble = PickTitaniaEnfeeble(PPet, PTarget, tick); enfeeble.has_value())
    {
        if (PPet->PAI->Cast(PTarget->entityId(), enfeeble.value()))
        {
            MarkSpellTried(PTarget->id, enfeeble.value(), tick);
            nextTitaniaEnfeebleTime[PPet->id] = tick + TitaniaEnfeebleWindow;
            nextFaerieCastTime[PPet->id]      = tick + FaerieCastCooldown;
            return;
        }
    }

    if (auto nuke = PickTitaniaNuke(PPet, PTarget); nuke.has_value())
    {
        if (PPet->PAI->Cast(PTarget->entityId(), nuke.value()))
        {
            nextFaerieCastTime[PPet->id] = tick + FaerieCastCooldown;
        }
    }
}

void MaintainFaerieBuffs(CPetEntity* PPet, timer::time_point tick)
{
    if (!PPet || !PPet->PMaster)
    {
        return;
    }

    const auto itemRefresh  = PPet->PMaster->getMod(FaerieRefreshMod);
    const auto petLevel     = PPet->GetMLevel() > 0 ? PPet->GetMLevel() : 1;
    const auto levelScale   = 1 + (petLevel - 1) / 20;
    const auto baseRefresh  = IsTitania(PPet) ? static_cast<int>(2 + petLevel / 25) : 0;
    const auto desiredRefr  = static_cast<uint16>(std::max<int>(0, baseRefresh + itemRefresh * levelScale));
    const auto desiredMatt  = static_cast<int16>(IsTitania(PPet) ? (15 + petLevel / 4) : 0);
    const auto desiredMacc  = static_cast<int16>(IsTitania(PPet) ? (15 + petLevel / 3) : 0);
    const auto stateKey     = static_cast<uint16>((desiredRefr & 0xFF) |
                                                  ((static_cast<uint16>(petLevel) & 0x7F) << 8) |
                                                  (IsTitania(PPet) ? 0x8000 : 0));
    auto*      PCurrent     = PPet->StatusEffectContainer->GetStatusEffect(FaerieRefreshEffect);

    if (desiredRefr == 0 && desiredMatt == 0)
    {
        if (PCurrent)
        {
            PPet->StatusEffectContainer->DelStatusEffectSilent(FaerieRefreshEffect);
        }

        return;
    }

    if (PCurrent && PCurrent->GetSubPower() == stateKey)
    {
        PCurrent->SetDuration(FaerieRefreshDuration);
        PCurrent->SetStartTime(tick);
        return;
    }

    if (PCurrent)
    {
        PPet->StatusEffectContainer->DelStatusEffectSilent(FaerieRefreshEffect);
    }

    if (PPet->StatusEffectContainer->AddStatusEffectSilent(FaerieRefreshEffect, 0, 0, 0s, FaerieRefreshDuration, 0, stateKey))
    {
        if (auto* PFairyBuff = PPet->StatusEffectContainer->GetStatusEffect(FaerieRefreshEffect))
        {
            if (desiredRefr > 0)
            {
                PFairyBuff->addMod(xi::Mod::REFRESH, static_cast<int16>(desiredRefr));
            }
            if (desiredMatt > 0)
            {
                PFairyBuff->addMod(xi::Mod::MATT, desiredMatt);
            }
            if (desiredMacc > 0)
            {
                PFairyBuff->addMod(xi::Mod::MACC, desiredMacc);
            }
        }
    }
}

} // namespace

class EosCompanionModule : public CPPModule
{
    void OnInit() override
    {
    }

    void OnZoneTick(CZone* PZone) override
    {
        if (!PZone)
        {
            return;
        }

        const auto tick = timer::now();
        PZone->ForEachPet(
            [tick](CPetEntity* PPet)
            {
                const bool eosPet     = IsEos(PPet);
                const bool titaniaPet = IsTitania(PPet);

                if (!eosPet && !titaniaPet)
                {
                    return;
                }

                if (!EnsureOwnerAndJobs(PPet))
                {
                    return;
                }

                MaintainFaerieBuffs(PPet, tick);

                if (eosPet)
                {
                    TryEosCast(PPet, tick);
                }
                else
                {
                    TryTitaniaCast(PPet, tick);
                }
            });
    }
};

REGISTER_CPP_MODULE(EosCompanionModule);
