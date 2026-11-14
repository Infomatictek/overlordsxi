/************************************************************************
 * Eos Companion
 *
 * Adds Eos support behavior as a C++ module:
 * - removes priority debuffs from the master, party, and trusts
 * - maintains stackable Eos Regen on the master, party, and trusts
 * - applies Orphic Egg's Eos-only Refresh through a hidden status effect
 ************************************************************************/

#include "common/utils.h"

#include "map/ai/ai_container.h"
#include "map/ai/controllers/controller.h"
#include "map/entities/battle_entity.h"
#include "map/entities/char_entity.h"
#include "map/entities/pet_entity.h"
#include "map/mob_spell_container.h"
#include "map/modifier.h"
#include "map/spell.h"
#include "map/status_effect.h"
#include "map/status_effect_container.h"
#include "map/utils/moduleutils.h"
#include "map/utils/petutils.h"
#include "map/zone.h"

#include <algorithm>
#include <memory>
#include <optional>
#include <unordered_map>

using namespace std::chrono_literals;

namespace
{

constexpr uint32           EosPetId           = 128;
constexpr auto             EosSpecVar         = "OX_SPEC_SCH";
constexpr int32            EosMedicSpecId     = 1;
constexpr xi::StatusEffect EosRegenEffect     = static_cast<xi::StatusEffect>(789);
constexpr xi::StatusEffect EosRefreshEffect   = static_cast<xi::StatusEffect>(814);
constexpr xi::Mod          EosRefreshMod      = static_cast<xi::Mod>(1198);
constexpr float            EosSupportRange    = 20.0f;
constexpr auto             EosCastCooldown    = 5s;
constexpr auto             EosRefreshDuration = 10s;
constexpr auto             EosRegenWindow     = 15s;

struct EosSupportAction
{
    SpellID        spellId;
    CBattleEntity* PTarget;
};

std::unordered_map<uint32, timer::time_point> nextEosCastTime;

bool IsEos(CPetEntity* PPet)
{
    return PPet && PPet->petID() == EosPetId && PPet->isAlive();
}

bool IsMedicScholar(CCharEntity* PMaster)
{
    return PMaster && PMaster->GetMJob() == xi::Job::SCH && PMaster->getCharVar(EosSpecVar) == EosMedicSpecId;
}

bool EnsureEosOwnerAndJobs(CPetEntity* PPet)
{
    if (!PPet || !PPet->PMaster || PPet->PMaster->objtype != TYPE_PC)
    {
        return false;
    }

    auto* PMaster = static_cast<CCharEntity*>(PPet->PMaster);
    if (!IsMedicScholar(PMaster))
    {
        petutils::DespawnPet(PMaster);
        return false;
    }

    const auto mainLevel = PMaster->GetMLevel();
    if (PPet->GetMJob() != xi::Job::SCH)
    {
        PPet->SetMJob(static_cast<uint8>(xi::Job::SCH));
    }

    if (PPet->GetSJob(true) != xi::Job::SMN)
    {
        PPet->SetSJob(static_cast<uint8>(xi::Job::SMN));
    }

    if (PPet->GetMLevel() != mainLevel)
    {
        PPet->SetMLevel(mainLevel);
    }

    const auto expectedSubLevel = mainLevel == 1 ? 1 : mainLevel / 2;
    if (PPet->GetSLevel() != expectedSubLevel)
    {
        PPet->SetSLevel(mainLevel);
    }

    return true;
}

bool IsSupportTarget(CPetEntity* PPet, CBattleEntity* PTarget)
{
    return PPet && PTarget && !PTarget->isDead() && PTarget->loc.zone == PPet->loc.zone &&
           distance(PPet->loc.p, PTarget->loc.p) <= EosSupportRange;
}

std::optional<SpellID> GetNaSpell(CBattleEntity* PTarget)
{
    auto* PEffects = PTarget->StatusEffectContainer;

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

std::optional<EosSupportAction> GetSupportAction(CPetEntity* PPet, timer::time_point tick)
{
    if (!PPet || !PPet->PMaster || PPet->PMaster->objtype != TYPE_PC)
    {
        return std::nullopt;
    }

    auto* PMaster = static_cast<CCharEntity*>(PPet->PMaster);

    auto checkNaTarget = [&](CBattleEntity* PTarget) -> std::optional<EosSupportAction>
    {
        if (!IsSupportTarget(PPet, PTarget))
        {
            return std::nullopt;
        }

        auto spellId = GetNaSpell(PTarget);
        if (spellId.has_value())
        {
            return EosSupportAction{ spellId.value(), PTarget };
        }

        return std::nullopt;
    };

    if (auto masterAction = checkNaTarget(PMaster); masterAction.has_value())
    {
        return masterAction;
    }

    std::optional<EosSupportAction> partyAction;
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

    auto checkRegenTarget = [&](CBattleEntity* PTarget) -> std::optional<EosSupportAction>
    {
        if (!IsSupportTarget(PPet, PTarget) || !NeedsEosRegen(PTarget, tick))
        {
            return std::nullopt;
        }

        return EosSupportAction{ GetEosRegenSpell(PPet), PTarget };
    };

    if (auto petRegen = checkRegenTarget(PPet); petRegen.has_value())
    {
        return petRegen;
    }

    if (auto masterRegen = checkRegenTarget(PMaster); masterRegen.has_value())
    {
        return masterRegen;
    }

    std::optional<EosSupportAction> regenAction;
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

bool CanCast(CPetEntity* PPet, SpellID spellId)
{
    if (!PPet || !PPet->PAI || !PPet->PAI->CanChangeState() || !PPet->SpellContainer || !PPet->SpellContainer->HasSpells())
    {
        return false;
    }

    if (PPet->StatusEffectContainer->HasStatusEffect({ xi::StatusEffect::Silence, xi::StatusEffect::Mute }))
    {
        return false;
    }

    auto* PController = PPet->PAI->GetController();
    if (PController && !PController->IsMagicCastingEnabled())
    {
        return false;
    }

    return PPet->SpellContainer->GetAvailable(spellId).has_value();
}

void TrySupportCast(CPetEntity* PPet, timer::time_point tick)
{
    if (nextEosCastTime[PPet->id] > tick)
    {
        return;
    }

    auto action = GetSupportAction(PPet, tick);
    if (!action.has_value() || !CanCast(PPet, action->spellId))
    {
        return;
    }

    if (PPet->PAI->Cast(action->PTarget->entityId(), action->spellId))
    {
        nextEosCastTime[PPet->id] = tick + EosCastCooldown;
    }
}

void MaintainOrphicRefresh(CPetEntity* PPet, timer::time_point tick)
{
    if (!PPet || !PPet->PMaster)
    {
        return;
    }

    const auto itemRefresh = PPet->PMaster->getMod(EosRefreshMod);
    const auto eosLevel    = PPet->GetMLevel() > 0 ? PPet->GetMLevel() : 1;
    const auto levelScale  = 1 + (eosLevel - 1) / 20;
    const auto desired     = static_cast<uint16>(std::max<int>(0, itemRefresh * levelScale));
    auto*      PCurrent    = PPet->StatusEffectContainer->GetStatusEffect(EosRefreshEffect);

    if (desired == 0)
    {
        if (PCurrent)
        {
            PPet->StatusEffectContainer->DelStatusEffectSilent(EosRefreshEffect);
        }

        return;
    }

    if (PCurrent && PCurrent->GetSubPower() == desired)
    {
        PCurrent->SetDuration(EosRefreshDuration);
        PCurrent->SetStartTime(tick);
        return;
    }

    if (PCurrent)
    {
        PPet->StatusEffectContainer->DelStatusEffectSilent(EosRefreshEffect);
    }

    auto PEosRefresh = std::make_unique<CStatusEffect>(EosRefreshEffect, 0, 0, 0s, EosRefreshDuration, 0, desired);
    PEosRefresh->addMod(xi::Mod::REFRESH, static_cast<int16>(desired));
    PPet->StatusEffectContainer->AddStatusEffect(std::move(PEosRefresh), EffectNotice::Silent);
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
                if (!IsEos(PPet))
                {
                    return;
                }

                if (!EnsureEosOwnerAndJobs(PPet))
                {
                    return;
                }

                MaintainOrphicRefresh(PPet, tick);
                TrySupportCast(PPet, tick);
            });
    }
};

REGISTER_CPP_MODULE(EosCompanionModule);
