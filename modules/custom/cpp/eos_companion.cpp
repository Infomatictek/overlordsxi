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
#include "map/entities/battleentity.h"
#include "map/entities/charentity.h"
#include "map/entities/petentity.h"
#include "map/mob_spell_container.h"
#include "map/modifier.h"
#include "map/spell.h"
#include "map/status_effect.h"
#include "map/status_effect_container.h"
#include "map/utils/moduleutils.h"
#include "map/zone.h"

#include <algorithm>
#include <optional>
#include <unordered_map>

using namespace std::chrono_literals;

namespace
{

constexpr uint32 EosPetId           = 128;
constexpr EFFECT EosRegenEffect     = static_cast<EFFECT>(789);
constexpr EFFECT EosRefreshEffect   = static_cast<EFFECT>(814);
constexpr Mod    EosRefreshMod      = static_cast<Mod>(1198);
constexpr float  EosSupportRange    = 20.0f;
constexpr auto   EosCastCooldown    = 5s;
constexpr auto   EosRefreshDuration = 10s;
constexpr auto   EosRegenWindow     = 15s;

struct EosSupportAction
{
    SpellID        spellId;
    CBattleEntity* PTarget;
};

std::unordered_map<uint32, timer::time_point> nextEosCastTime;

bool IsEos(CPetEntity* PPet)
{
    return PPet && PPet->m_PetID == EosPetId && PPet->isAlive();
}

bool IsSupportTarget(CPetEntity* PPet, CBattleEntity* PTarget)
{
    return PPet && PTarget && !PTarget->isDead() && PTarget->loc.zone == PPet->loc.zone &&
           distance(PPet->loc.p, PTarget->loc.p) <= EosSupportRange;
}

std::optional<SpellID> GetNaSpell(CBattleEntity* PTarget)
{
    auto* PEffects = PTarget->StatusEffectContainer;

    if (PEffects->HasStatusEffect(EFFECT_PETRIFICATION))
    {
        return SpellID::Stona;
    }

    if (PEffects->HasStatusEffect({ EFFECT_DOOM, EFFECT_CURSE, EFFECT_CURSE_II, EFFECT_BANE }))
    {
        return SpellID::Cursna;
    }

    if (PEffects->HasStatusEffect(EFFECT_PARALYSIS))
    {
        return SpellID::Paralyna;
    }

    if (PEffects->HasStatusEffect(EFFECT_SILENCE))
    {
        return SpellID::Silena;
    }

    if (PEffects->HasStatusEffect(EFFECT_POISON))
    {
        return SpellID::Poisona;
    }

    if (PEffects->HasStatusEffect(EFFECT_BLINDNESS))
    {
        return SpellID::Blindna;
    }

    if (PEffects->HasStatusEffect({ EFFECT_DISEASE, EFFECT_PLAGUE }))
    {
        return SpellID::Viruna;
    }

    if (PEffects->HasStatusEffectByFlag(EFFECTFLAG_ERASABLE))
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

    auto checkRegenTarget = [&](CBattleEntity* PTarget) -> std::optional<EosSupportAction>
    {
        if (!IsSupportTarget(PPet, PTarget) || !NeedsEosRegen(PTarget, tick))
        {
            return std::nullopt;
        }

        return EosSupportAction{ SpellID::Regen, PTarget };
    };

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

    if (PPet->StatusEffectContainer->HasStatusEffect({ EFFECT_SILENCE, EFFECT_MUTE }))
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

    if (PPet->PAI->Cast(action->PTarget->targid, action->spellId))
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

    auto* PEosRefresh = new CStatusEffect(EosRefreshEffect, 0, 0, 0s, EosRefreshDuration, 0, desired);
    PEosRefresh->addMod(Mod::REFRESH, desired);

    if (!PPet->StatusEffectContainer->AddStatusEffect(PEosRefresh, EffectNotice::Silent))
    {
        delete PEosRefresh;
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
                if (!IsEos(PPet))
                {
                    return;
                }

                MaintainOrphicRefresh(PPet, tick);
                TrySupportCast(PPet, tick);
            });
    }
};

REGISTER_CPP_MODULE(EosCompanionModule);
