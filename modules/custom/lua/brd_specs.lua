-----------------------------------
-- OverlordsXI Bard Crystal Specs
-- Registers Bard crystals:
--   1) Adventurer (ADV) - Melee Damage (Dagger/Sword + Cadence & Encore)
--   2) Musician   (MUS) - Magical Song Nuker (Threnody/Requiem + Magic Burst)
--   3) Minstrel   (MIN) - Pre-Nerf Lv.75 Song Tank (Debuff Song Enmity & Scherzo)
--
-- Design guarantees:
--   - Songs are not interrupted by melee hits (no wasted SIRD mechanics).
--   - Active rotations never require spamming buff songs, keeping party/self
--     buffs reliable while offensive songs & JAs drive damage/enmity.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/combat/basic/magic_burst')
require('scripts/combat/basic/magic_hit_rate')
require('scripts/combat/physical_utilities')
require('scripts/globals/spells/damage_spell')
-----------------------------------
local m = Module:new('overlords_brd_specs')

local spec = xi.overlords.spec

local ADVENTURER_KEY = 'adventurer'
local MUSICIAN_KEY   = 'musician'
local MINSTREL_KEY   = 'minstrel'

-- Custom Job Ability IDs (432-437)
local ABIL_LUNGE_FLOURISH     = 432
local ABIL_TROUBADOURS_ENCORE = 433
local ABIL_GRAND_FINALE       = 434
local ABIL_LYRICAL_OVERDRIVE  = 435
local ABIL_DISSONANT_CHORD    = 436
local ABIL_IRON_ARIA          = 437

-- Custom Status Effect IDs (832-836, within MAX_EFFECTID = 840)
local EFFECT_ADV_CADENCE   = 832
local EFFECT_ADV_ENCORE    = 833
local EFFECT_MUS_RESONANCE = 834
local EFFECT_MUS_OVERDRIVE = 835
local EFFECT_MIN_IRON_ARIA = 836

-- Custom Job Trait IDs (155-157)
local TRAIT_DUAL_WIELD       = (xi.trait and xi.trait.DUAL_WIELD) or 18
local TRAIT_ADVENTURER_TEMPO   = 155
local TRAIT_MUSICIAN_RESONANCE = 156
local TRAIT_MINSTREL_BULWARK   = 157

xi.jobAbility = xi.jobAbility or {}
xi.jobAbility.LUNGE_FLOURISH     = ABIL_LUNGE_FLOURISH
xi.jobAbility.TROUBADOURS_ENCORE = ABIL_TROUBADOURS_ENCORE
xi.jobAbility.GRAND_FINALE       = ABIL_GRAND_FINALE
xi.jobAbility.LYRICAL_OVERDRIVE  = ABIL_LYRICAL_OVERDRIVE
xi.jobAbility.DISSONANT_CHORD    = ABIL_DISSONANT_CHORD
xi.jobAbility.IRON_ARIA          = ABIL_IRON_ARIA

xi.effect = xi.effect or {}
xi.effect.ADVENTURER_CADENCE = EFFECT_ADV_CADENCE
xi.effect.ADVENTURER_ENCORE  = EFFECT_ADV_ENCORE
xi.effect.MUSICIAN_RESONANCE = EFFECT_MUS_RESONANCE
xi.effect.MUSICIAN_OVERDRIVE = EFFECT_MUS_OVERDRIVE
xi.effect.MINSTREL_IRON_ARIA = EFFECT_MIN_IRON_ARIA

xi.actions = xi.actions or {}
xi.actions.abilities = xi.actions.abilities or {}
xi.actions.abilities.lunge_flourish     = xi.actions.abilities.lunge_flourish or {}
xi.actions.abilities.troubadours_encore = xi.actions.abilities.troubadours_encore or {}
xi.actions.abilities.grand_finale       = xi.actions.abilities.grand_finale or {}
xi.actions.abilities.lyrical_overdrive  = xi.actions.abilities.lyrical_overdrive or {}
xi.actions.abilities.dissonant_chord    = xi.actions.abilities.dissonant_chord or {}
xi.actions.abilities.iron_aria          = xi.actions.abilities.iron_aria or {}

xi.effects = xi.effects or {}
xi.effects.adventurer_cadence = xi.effects.adventurer_cadence or {}
xi.effects.adventurer_encore  = xi.effects.adventurer_encore or {}
xi.effects.musician_resonance = xi.effects.musician_resonance or {}
xi.effects.musician_overdrive = xi.effects.musician_overdrive or {}
xi.effects.minstrel_iron_aria = xi.effects.minstrel_iron_aria or {}

local pendingBrdEffectMods = {}

local function scaleTier(lvl, lv10, lv30, lv50, lv70)
    local l = lvl or 1
    if l >= 70 and lv70 ~= nil then
        return lv70
    elseif l >= 50 then
        return lv50
    elseif l >= 30 then
        return lv30
    end
    return lv10
end

local function isBardSpec(entity, specKey)
    if entity == nil or not entity:isPC() or entity:getMainJob() ~= xi.job.BRD then
        return false
    end

    spec.ensureUpToDate(entity)
    return spec.is(entity, xi.job.BRD, specKey)
end

local function applyPendingBrdEffectMods(target, effect)
    if target == nil or effect == nil or not target.getID then
        return
    end

    local targetId = target:getID()
    local mods = pendingBrdEffectMods[targetId]
    if mods == nil then
        return
    end

    pendingBrdEffectMods[targetId] = nil
    for _, pair in ipairs(mods) do
        if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
            effect:addMod(pair[1], pair[2])
        end
    end
end

for _, effKey in ipairs({
    'adventurer_cadence',
    'adventurer_encore',
    'musician_resonance',
    'musician_overdrive',
    'minstrel_iron_aria',
}) do
    xi.effects[effKey] = xi.effects[effKey] or {}
    xi.effects[effKey].onEffectGain = function(target, effect)
        applyPendingBrdEffectMods(target, effect)
    end
    xi.effects[effKey].onEffectLose = function(_target, _effect)
    end
    m:addOverride('xi.effects.' .. effKey .. '.onEffectGain', function(target, effect)
        applyPendingBrdEffectMods(target, effect)
    end)
    m:addOverride('xi.effects.' .. effKey .. '.onEffectLose', function(_target, _effect)
    end)
end

local function applyTimedBrdEffect(target, effectId, power, duration, origin, iconId, mods)
    if target == nil or not target.addStatusEffect then
        return false
    end

    if target.hasStatusEffect and target:hasStatusEffect(effectId) and target.delStatusEffectSilent then
        target:delStatusEffectSilent(effectId)
    end

    local targetId = target.getID and target:getID() or 0
    pendingBrdEffectMods[targetId] = mods

    local ok = target:addStatusEffect(effectId,
    {
        power    = power or 1,
        duration = duration or 15,
        origin   = origin or target,
        icon     = (xi.overlords and xi.overlords.getStatusIcon and xi.overlords.getStatusIcon(effectId, iconId)) or iconId or effectId,
    })

    local leftover = pendingBrdEffectMods[targetId]
    pendingBrdEffectMods[targetId] = nil
    if ok and type(leftover) == 'table' then
        local eff = target.getStatusEffect and target:getStatusEffect(effectId) or nil
        if eff ~= nil and eff.addMod then
            for _, pair in ipairs(leftover) do
                if pair[1] ~= nil and type(pair[2]) == 'number' and pair[2] ~= 0 then
                    eff:addMod(pair[1], pair[2])
                end
            end
        end
    end

    return ok
end

local function bindAbility(name, checkFn, useFn)
    xi.actions.abilities[name] = xi.actions.abilities[name] or {}
    xi.actions.abilities[name].onAbilityCheck = checkFn
    xi.actions.abilities[name].onUseAbility   = useFn
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', checkFn)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', useFn)
end

-----------------------------------
-- Song & Buff Classification Tables
-----------------------------------
local BUFF_SONG_EFFECTS = {}
do
    local e = xi.effect or {}
    local list =
    {
        e.MINUET, e.MADRIGAL, e.MARCH, e.MINNE, e.PAEON, e.MAMBO,
        e.BALLAD, e.CAROL, e.ETUDE, e.SCHERZO, e.HYMNUS, e.PRELUDE, e.MAZURKA,
    }
    for _, effId in ipairs(list) do
        if effId ~= nil then
            BUFF_SONG_EFFECTS[effId] = true
        end
    end
end

local function countActiveBuffSongs(player)
    if player == nil or not player.hasStatusEffect then
        return 0
    end
    local count = 0
    for effId, _ in pairs(BUFF_SONG_EFFECTS) do
        if player:hasStatusEffect(effId) then
            count = count + 1
        end
    end
    return count
end

local OFFENSIVE_SONG_DEFS = {}
do
    local sp = xi.magic and xi.magic.spell or {}
    local el = xi.element or {}
    local dt = xi.damageType or {}

    local function regSong(spellId, kind, element, dmgType, basePower, ce, ve)
        if spellId ~= nil then
            OFFENSIVE_SONG_DEFS[spellId] =
            {
                kind      = kind,
                element   = element,
                dmgType   = dmgType,
                basePower = basePower,
                ce        = ce,
                ve        = ve,
            }
        end
    end

    -- Threnodies (8 elements)
    regSong(sp.FIRE_THRENODY,     'threnody', el.FIRE,    dt.FIRE,      52, 240, 720)
    regSong(sp.ICE_THRENODY,      'threnody', el.ICE,     dt.ICE,       52, 240, 720)
    regSong(sp.WIND_THRENODY,     'threnody', el.WIND,    dt.WIND,      52, 240, 720)
    regSong(sp.EARTH_THRENODY,     'threnody', el.EARTH,   dt.EARTH,     52, 240, 720)
    regSong(sp.LIGHTNING_THRENODY, 'threnody', el.THUNDER, dt.THUNDER,   52, 240, 720)
    regSong(sp.WATER_THRENODY,     'threnody', el.WATER,   dt.WATER,     52, 240, 720)
    regSong(sp.LIGHT_THRENODY,     'threnody', el.LIGHT,   dt.LIGHT,     52, 240, 720)
    regSong(sp.DARK_THRENODY,      'threnody', el.DARK,    dt.DARK,      52, 240, 720)
    regSong(sp.FIRE_THRENODY_II,   'threnody', el.FIRE,    dt.FIRE,      78, 280, 840)
    regSong(sp.ICE_THRENODY_II,    'threnody', el.ICE,     dt.ICE,       78, 280, 840)
    regSong(sp.WIND_THRENODY_II,   'threnody', el.WIND,    dt.WIND,      78, 280, 840)
    regSong(sp.EARTH_THRENODY_II,  'threnody', el.EARTH,   dt.EARTH,     78, 280, 840)
    regSong(sp.LIGHTNING_THRENODY_II, 'threnody', el.THUNDER, dt.THUNDER, 78, 280, 840)
    regSong(sp.WATER_THRENODY_II, 'threnody', el.WATER,   dt.WATER,     78, 280, 840)
    regSong(sp.LIGHT_THRENODY_II, 'threnody', el.LIGHT,   dt.LIGHT,     78, 280, 840)
    regSong(sp.DARK_THRENODY_II,  'threnody', el.DARK,    dt.DARK,      78, 280, 840)

    -- Foe Requiems (Light)
    regSong(sp.FOE_REQUIEM,       'requiem', el.LIGHT, dt.LIGHT, 24, 200, 600)
    regSong(sp.FOE_REQUIEM_II,    'requiem', el.LIGHT, dt.LIGHT, 32, 210, 630)
    regSong(sp.FOE_REQUIEM_III,   'requiem', el.LIGHT, dt.LIGHT, 40, 220, 660)
    regSong(sp.FOE_REQUIEM_IV,    'requiem', el.LIGHT, dt.LIGHT, 48, 240, 720)
    regSong(sp.FOE_REQUIEM_V,     'requiem', el.LIGHT, dt.LIGHT, 56, 250, 750)
    regSong(sp.FOE_REQUIEM_VI,    'requiem', el.LIGHT, dt.LIGHT, 64, 260, 780)
    regSong(sp.FOE_REQUIEM_VII,   'requiem', el.LIGHT, dt.LIGHT, 74, 280, 840)
    regSong(sp.FOE_REQUIEM_VIII,  'requiem', el.LIGHT, dt.LIGHT, 84, 300, 900)

    -- Elegies (Earth)
    regSong(sp.BATTLEFIELD_ELEGY, 'elegy', el.EARTH, dt.EARTH, 40, 240, 720)
    regSong(sp.CARNAGE_ELEGY,     'elegy', el.EARTH, dt.EARTH, 62, 300, 900)
    regSong(sp.MASSACRE_ELEGY,    'elegy', el.EARTH, dt.EARTH, 80, 340, 1020)

    -- Lullabies (Light - signature pre-nerf tank hate songs)
    regSong(sp.FOE_LULLABY,       'lullaby', el.LIGHT, dt.LIGHT, 0, 340, 1020)
    regSong(sp.FOE_LULLABY_II,    'lullaby', el.LIGHT, dt.LIGHT, 0, 380, 1140)
    regSong(sp.HORDE_LULLABY,     'lullaby', el.LIGHT, dt.LIGHT, 0, 300, 900)
    regSong(sp.HORDE_LULLABY_II,  'lullaby', el.LIGHT, dt.LIGHT, 0, 340, 1020)

    -- Finale / Nocturne / Virelai
    regSong(sp.MAGIC_FINALE,      'finale',  el.LIGHT, dt.LIGHT, 58, 300, 900)
    regSong(sp.PINING_NOCTURNE,   'nocturne', el.DARK, dt.DARK,  66, 260, 780)
    regSong(sp.MAIDENS_VIRELAI,   'virelai', el.LIGHT, dt.LIGHT, 0, 320, 960)
end

local function isMeleeDaggerOrSword(player)
    if player == nil or not player.getWeaponSkillType then
        return false
    end
    local wtype = player:getWeaponSkillType(xi.slot.MAIN)
    return wtype == xi.skill.DAGGER or wtype == xi.skill.SWORD
end

-----------------------------------
-- Musician Magic Song Damage Helper
-----------------------------------
local function dealMusicianSongDamage(caster, target, element, dmgType, basePower, isBurstAbility)
    if caster == nil or target == nil or target:isDead() then
        return 0
    end

    local lvl = caster:getMainLvl() or 1
    local chr = caster:getStat(xi.mod.CHR) or 0
    local singSkill = caster:getSkillLevel(xi.skill.SINGING) or 0
    local windSkill = caster:getSkillLevel(xi.skill.WIND_INSTRUMENT) or 0
    local strSkill  = caster:getSkillLevel(xi.skill.STRING_INSTRUMENT) or 0
    local instSkill = math.max(windSkill, strSkill)

    local statDiff = math.max(0, chr - (target:getStat(xi.mod.INT) or 0))
    local rawBase = basePower + math.floor(lvl * 1.4) + math.floor(chr * 1.25) + math.floor((singSkill + instSkill) * 0.22) + math.floor(statDiff * 0.8)

    local mab = 100 + (caster:getMod(xi.mod.MATT) or 0)
    local mdef = 100 + (target:getMod(xi.mod.MDEF) or 0)
    local mabRatio = math.max(0.5, mab / math.max(50, mdef))

    local magicBurstTier = 0
    if xi.combat and xi.combat.magicBurst and xi.combat.magicBurst.getMagicBurstTier then
        magicBurstTier = xi.combat.magicBurst.getMagicBurstTier(target, element) or 0
    end
    local canMBurst = magicBurstTier > 0

    local resist = 1.0
    if xi.combat and xi.combat.magicHitRate and xi.combat.magicHitRate.calculateResistRate then
        resist = xi.combat.magicHitRate.calculateResistRate(caster, target,
        {
            magicalElement = element,
            magicBurstTier = canMBurst and magicBurstTier or 0,
            skillType      = xi.skill.SINGING,
            spellGroup     = (xi.magic and xi.magic.spellGroup and xi.magic.spellGroup.SONG) or 0,
            actorStat      = xi.mod.CHR,
            bonusMacc      = 20,
        }) or 1.0
    end

    if resist <= 0 then
        return 0, false
    end

    local mbMult = 1.0
    if canMBurst then
        if xi.spells and xi.spells.damage and xi.spells.damage.calculateIfMagicBurst then
            mbMult = xi.spells.damage.calculateIfMagicBurst(caster, target, element, magicBurstTier) or 1.35
            if xi.spells.damage.calculateIfMagicBurstBonus then
                mbMult = mbMult * (xi.spells.damage.calculateIfMagicBurstBonus(caster, target, 0, xi.skill.SINGING, element) or 1.0)
            end
        else
            mbMult = 1.35
        end

        if caster:hasStatusEffect(EFFECT_MUS_OVERDRIVE) then
            mbMult = mbMult * 1.25
        end

        if caster.triggerRoeEvent and xi.roeTrigger and xi.roeTrigger.MAGIC_BURST then
            caster:triggerRoeEvent(xi.roeTrigger.MAGIC_BURST)
        end
    end

    local overdriveMult = caster:hasStatusEffect(EFFECT_MUS_OVERDRIVE) and 1.30 or 1.0
    local abilityMult   = isBurstAbility and 1.25 or 1.0

    local dmg = math.max(1, math.floor(rawBase * mabRatio * resist * mbMult * overdriveMult * abilityMult))
    if xi.customBossServer and xi.customBossServer.scaleDamageByLevelGap then
        dmg = xi.customBossServer.scaleDamageByLevelGap(caster, target, dmg)
    end
    if utils and utils.handleStoneskin then
        dmg = utils.handleStoneskin(target, dmg, xi.attackType.MAGICAL)
    end

    if dmg > 0 then
        target:takeDamage(dmg, caster, xi.attackType.MAGICAL, dmgType)
        target:updateEnmityFromDamage(caster, dmg)
    end

    return dmg, canMBurst and mbMult > 1.0
end

-----------------------------------
-- Minstrel Passive Aura Sync (no buff-spam required)
-----------------------------------
local function syncMinstrelAura(player)
    if player == nil or not isBardSpec(player, MINSTREL_KEY) then
        return
    end

    local hasMinne = xi.effect.MINNE and player:hasStatusEffect(xi.effect.MINNE)
    local wantPdt = hasMinne and -600 or 0 -- -6% extra PDT while Minne is active
    local prevPdt = player:getLocalVar('OX_MIN_MINNE_PDT')
    if prevPdt ~= wantPdt then
        if prevPdt ~= 0 then
            player:delMod(xi.mod.DMGPHYS, prevPdt)
        end
        if wantPdt ~= 0 then
            player:addMod(xi.mod.DMGPHYS, wantPdt)
        end
        player:setLocalVar('OX_MIN_MINNE_PDT', wantPdt)
    end

    local hasPaeon = xi.effect.PAEON and player:hasStatusEffect(xi.effect.PAEON)
    local wantRegen = hasPaeon and scaleTier(player:getMainLvl(), 3, 5, 8, 12) or 0
    local prevRegen = player:getLocalVar('OX_MIN_PAEON_REGEN')
    if prevRegen ~= wantRegen then
        if prevRegen ~= 0 then
            player:delMod(xi.mod.REGEN, prevRegen)
        end
        if wantRegen ~= 0 then
            player:addMod(xi.mod.REGEN, wantRegen)
        end
        player:setLocalVar('OX_MIN_PAEON_REGEN', wantRegen)
    end
end

local function clearMinstrelAura(player)
    if player == nil then
        return
    end
    local prevPdt = player:getLocalVar('OX_MIN_MINNE_PDT')
    if prevPdt ~= 0 then
        player:delMod(xi.mod.DMGPHYS, prevPdt)
        player:setLocalVar('OX_MIN_MINNE_PDT', 0)
    end
    local prevRegen = player:getLocalVar('OX_MIN_PAEON_REGEN')
    if prevRegen ~= 0 then
        player:delMod(xi.mod.REGEN, prevRegen)
        player:setLocalVar('OX_MIN_PAEON_REGEN', 0)
    end
end

-----------------------------------
-- Player Listeners
-----------------------------------
local function clearBrdListeners(player)
    if player == nil or not player.removeListener then
        return
    end
    player:removeListener('OX_BRD_MELEE')
    player:removeListener('OX_BRD_WS')
    player:removeListener('OX_BRD_MAGIC')
    player:removeListener('OX_BRD_TAKE_DMG')
    player:removeListener('OX_BRD_TICK')
end

local function installBrdListeners(player)
    if player == nil or not player.addListener then
        return
    end

    clearBrdListeners(player)

    -- Adventurer: Melee hits build Cadence stacks
    player:addListener('MELEE_SWING_HIT', 'OX_BRD_MELEE', function(actor, _target)
        if not isBardSpec(actor, ADVENTURER_KEY) or not isMeleeDaggerOrSword(actor) then
            return
        end

        local curEff = actor:getStatusEffect(EFFECT_ADV_CADENCE)
        local curStacks = curEff and curEff:getPower() or 0
        local nextStacks = math.min(5, curStacks + 1)
        local iconId = (xi.effect and xi.effect.MINUET) or EFFECT_ADV_CADENCE
        applyTimedBrdEffect(actor, EFFECT_ADV_CADENCE, nextStacks, 20, actor, iconId,
        {
            { xi.mod.CRITHITRATE, nextStacks * 2 },
        })
    end)

    -- Adventurer: Dagger/Sword WS consumes Cadence for bonus Sonic/Light hit + Encore haste
    player:addListener('WEAPONSKILL_USE', 'OX_BRD_WS', function(actor, target, _ws, _tp, _action, dmg)
        if not isBardSpec(actor, ADVENTURER_KEY) or not isMeleeDaggerOrSword(actor) then
            return
        end

        local cadEff = actor:getStatusEffect(EFFECT_ADV_CADENCE)
        local stacks = cadEff and cadEff:getPower() or 0
        if stacks <= 0 then
            return
        end

        actor:delStatusEffectSilent(EFFECT_ADV_CADENCE)

        if target ~= nil and not target:isDead() then
            local chr = actor:getStat(xi.mod.CHR) or 0
            local dex = actor:getStat(xi.mod.DEX) or 0
            local songBonus = 1.0 + (0.08 * math.min(4, countActiveBuffSongs(actor)))
            local bonusDmg = math.max(10, math.floor(((chr + dex) * 0.9 + (dmg or 0) * 0.08) * stacks * 0.55 * songBonus))
            if utils and utils.handleStoneskin then
                bonusDmg = utils.handleStoneskin(target, bonusDmg, xi.attackType.MAGICAL)
            end
            if bonusDmg > 0 then
                target:takeDamage(bonusDmg, actor, xi.attackType.MAGICAL, xi.damageType.LIGHT)
                target:updateEnmityFromDamage(actor, bonusDmg)
                actor:printToPlayer(string.format('Cadence (%d) resonates for %d sonic damage!', stacks, bonusDmg), xi.msg.channel.SYSTEM_3)
            end
        end

        local encoreIcon = (xi.effect and xi.effect.MARCH) or EFFECT_ADV_ENCORE
        applyTimedBrdEffect(actor, EFFECT_ADV_ENCORE, 1, 12, actor, encoreIcon,
        {
            { xi.mod.HASTE_ABILITY, 1500 },
            { xi.mod.CRITHITRATE, 10 },
            { xi.mod.ALL_WSDMG_ALL_HITS, 12 },
        })
    end)

    -- Musician (Offensive Song Nukes) & Minstrel (Pre-Nerf Debuff Song Enmity)
    player:addListener('MAGIC_USE', 'OX_BRD_MAGIC', function(caster, target, spell, _action)
        if caster == nil or spell == nil or target == nil then
            return
        end
        if caster:getMainJob() ~= xi.job.BRD then
            return
        end

        local spellId = spell:getID()
        local def = OFFENSIVE_SONG_DEFS[spellId]
        if def == nil then
            return
        end

        if isBardSpec(caster, MUSICIAN_KEY) then
            if def.basePower > 0 and target:isMob() and not target:isDead() then
                local dmg, isMB = dealMusicianSongDamage(caster, target, def.element, def.dmgType, def.basePower, false)
                if dmg > 0 then
                    if isMB then
                        caster:printToPlayer(string.format('Magic Burst! Your song strikes %s for %d damage.', target:getName(), dmg), xi.msg.channel.SYSTEM_3)
                    else
                        caster:printToPlayer(string.format('Your song strikes %s for %d damage.', target:getName(), dmg), xi.msg.channel.SYSTEM_3)
                    end
                end
            end

            if def.kind == 'threnody' or def.kind == 'requiem' or def.kind == 'elegy' then
                local resEff = caster:getStatusEffect(EFFECT_MUS_RESONANCE)
                local stacks = math.min(3, (resEff and resEff:getPower() or 0) + 1)
                local resIcon = (xi.effect and xi.effect.THRENODY) or EFFECT_MUS_RESONANCE
                applyTimedBrdEffect(caster, EFFECT_MUS_RESONANCE, stacks, 30, caster, resIcon,
                {
                    { xi.mod.MATT, stacks * 5 },
                })
            end
        elseif isBardSpec(caster, MINSTREL_KEY) then
            if target:isMob() and not target:isDead() and target.addEnmity then
                target:addEnmity(caster, def.ce, def.ve)
            end
        end
    end)

    -- Minstrel: Scherzo Tank-Buster Dampening & Iron Aria Sonic Reflect
    player:addListener('TAKE_DAMAGE', 'OX_BRD_TAKE_DMG', function(defender, amount, attacker)
        if not isBardSpec(defender, MINSTREL_KEY) or (amount or 0) <= 0 then
            return
        end

        if xi.effect.SCHERZO and defender:hasStatusEffect(xi.effect.SCHERZO) then
            local maxHp = defender:getMaxHP() or 1
            if amount > math.floor(maxHp * 0.35) then
                local saved = math.floor((amount - math.floor(maxHp * 0.35)) * 0.45)
                if saved > 0 and defender.addHP then
                    defender:addHP(saved)
                end
            end
        end

        if defender:hasStatusEffect(EFFECT_MIN_IRON_ARIA) and attacker ~= nil and attacker:isMob() and not attacker:isDead() then
            local reflectDmg = math.max(15, math.floor((defender:getStat(xi.mod.VIT) or 0) * 0.7 + (defender:getStat(xi.mod.CHR) or 0) * 0.5))
            attacker:takeDamage(reflectDmg, defender, xi.attackType.MAGICAL, xi.damageType.LIGHT)
            attacker:updateEnmityFromDamage(defender, reflectDmg)
        end
    end)

    -- Minstrel: Keep Minne/Paeon aura bonuses synced without re-casting buffs
    player:addListener('TICK', 'OX_BRD_TICK', function(actor)
        if isBardSpec(actor, MINSTREL_KEY) then
            syncMinstrelAura(actor)
        end
    end)
end

-----------------------------------
-- Custom Job Abilities (432-437)
-----------------------------------
-- 432: Lunge & Flourish (ADV)
bindAbility('lunge_flourish',
    function(player, target, _ability)
        if not isBardSpec(player, ADVENTURER_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        if target == nil or not target:isMob() or target:isDead() then
            return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
        end
        return 0, 0
    end,
    function(player, target, ability)
        local chr = player:getStat(xi.mod.CHR) or 0
        local dex = player:getStat(xi.mod.DEX) or 0
        local lvl = player:getMainLvl() or 1
        local songMult = 1.0 + (0.10 * math.min(4, countActiveBuffSongs(player)))
        local dmg = math.max(15, math.floor((lvl * 1.8 + dex * 1.4 + chr * 1.1) * songMult))

        if utils and utils.handleStoneskin then
            dmg = utils.handleStoneskin(target, dmg, xi.attackType.PHYSICAL)
        end
        target:takeDamage(dmg, player, xi.attackType.PHYSICAL, xi.damageType.PIERCING)
        target:updateEnmityFromDamage(player, dmg)

        if xi.effect.DEFENSE_DOWN and not target:hasStatusEffect(xi.effect.DEFENSE_DOWN) then
            target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = 10, duration = 15, origin = player })
        end

        local curEff = player:getStatusEffect(EFFECT_ADV_CADENCE)
        local nextStacks = math.min(5, (curEff and curEff:getPower() or 0) + 2)
        local iconId = (xi.effect and xi.effect.MINUET) or EFFECT_ADV_CADENCE
        applyTimedBrdEffect(player, EFFECT_ADV_CADENCE, nextStacks, 20, player, iconId,
        {
            { xi.mod.CRITHITRATE, nextStacks * 2 },
        })

        player:addTP(200)
        ability:setMsg(xi.msg.basic.JA_DAMAGE)
        return dmg
    end
)

-- 433: Troubadour's Encore (ADV)
bindAbility('troubadours_encore',
    function(player, _target, _ability)
        if not isBardSpec(player, ADVENTURER_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        return 0, 0
    end,
    function(player, _target, _ability)
        local cadIcon = (xi.effect and xi.effect.MINUET) or EFFECT_ADV_CADENCE
        applyTimedBrdEffect(player, EFFECT_ADV_CADENCE, 5, 25, player, cadIcon,
        {
            { xi.mod.CRITHITRATE, 10 },
        })

        local encoreIcon = (xi.effect and xi.effect.MARCH) or EFFECT_ADV_ENCORE
        applyTimedBrdEffect(player, EFFECT_ADV_ENCORE, 1, 15, player, encoreIcon,
        {
            { xi.mod.HASTE_ABILITY, 2000 },
            { xi.mod.CRITHITRATE, 15 },
            { xi.mod.ALL_WSDMG_ALL_HITS, 15 },
        })
        return 0
    end
)

-- 434: Grand Finale (MUS)
bindAbility('grand_finale',
    function(player, target, _ability)
        if not isBardSpec(player, MUSICIAN_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        if target == nil or not target:isMob() or target:isDead() then
            return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
        end
        return 0, 0
    end,
    function(player, target, ability)
        local resEff = player:getStatusEffect(EFFECT_MUS_RESONANCE)
        local stacks = resEff and resEff:getPower() or 0
        if stacks > 0 then
            player:delStatusEffectSilent(EFFECT_MUS_RESONANCE)
        end

        local debuffBonus = 0
        if xi.effect.THRENODY and target:hasStatusEffect(xi.effect.THRENODY) then
            debuffBonus = debuffBonus + 1
        end
        if xi.effect.REQUIEM and target:hasStatusEffect(xi.effect.REQUIEM) then
            debuffBonus = debuffBonus + 1
        end
        if xi.effect.ELEGY and target:hasStatusEffect(xi.effect.ELEGY) then
            debuffBonus = debuffBonus + 1
        end

        local basePower = 95 + (stacks * 45) + (debuffBonus * 35)
        local dmg, isMB = dealMusicianSongDamage(player, target, xi.element.LIGHT, xi.damageType.LIGHT, basePower, true)
        if isMB then
            player:printToPlayer(string.format('Magic Burst! Grand Finale detonates for %d damage!', dmg), xi.msg.channel.SYSTEM_3)
        end

        ability:setMsg(xi.msg.basic.JA_DAMAGE)
        return dmg
    end
)

-- 435: Lyrical Overdrive (MUS)
bindAbility('lyrical_overdrive',
    function(player, _target, _ability)
        if not isBardSpec(player, MUSICIAN_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        return 0, 0
    end,
    function(player, _target, _ability)
        local iconId = (xi.effect and xi.effect.TROUBADOUR) or EFFECT_MUS_OVERDRIVE
        applyTimedBrdEffect(player, EFFECT_MUS_OVERDRIVE, 1, 15, player, iconId,
        {
            { xi.mod.MATT, 35 },
            { xi.mod.MACC, 25 },
            { xi.mod.FASTCAST, 20 },
        })
        return 0
    end
)

-- 436: Dissonant Chord (MIN)
bindAbility('dissonant_chord',
    function(player, target, _ability)
        if not isBardSpec(player, MINSTREL_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        if target == nil or not target:isMob() or target:isDead() then
            return xi.msg.basic.CANNOT_ATTACK_TARGET, 0
        end
        return 0, 0
    end,
    function(player, target, ability)
        if target.addEnmity then
            target:addEnmity(player, 900, 1800)
        end
        if xi.effect.ATTACK_DOWN and not target:hasStatusEffect(xi.effect.ATTACK_DOWN) then
            target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = 15, duration = 15, origin = player })
        end
        ability:setMsg(xi.msg.basic.JA_GAIN_EFFECT)
        return 0
    end
)

-- 437: Iron Aria (MIN)
bindAbility('iron_aria',
    function(player, _target, _ability)
        if not isBardSpec(player, MINSTREL_KEY) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        return 0, 0
    end,
    function(player, _target, _ability)
        local iconId = (xi.effect and xi.effect.SENTINEL) or (xi.effect and xi.effect.MINNE) or EFFECT_MIN_IRON_ARIA
        applyTimedBrdEffect(player, EFFECT_MIN_IRON_ARIA, 1, 15, player, iconId,
        {
            { xi.mod.DMGPHYS, -2000 },
            { xi.mod.DMGMAGIC, -1500 },
            { xi.mod.ENMITY, 30 },
            { xi.mod.DEF, 40 },
        })
        return 0
    end
)

-----------------------------------
-- Job Crystal Registration (BRD)
-----------------------------------
if xi.job and xi.job.BRD then
    spec.registerJob(xi.job.BRD, 'BRD',
    {
        {
            id             = 1,
            key            = ADVENTURER_KEY,
            name           = 'Adventurer',
            role           = 'Melee Damage (Dagger / Sword)',
            icon           = 'crimson_blade',
            extraAbilities = { ABIL_LUNGE_FLOURISH, ABIL_TROUBADOURS_ENCORE },
            extraTraits    = { TRAIT_DUAL_WIELD, TRAIT_ADVENTURER_TEMPO },
            description    = 'Wandering troubadour spec: Dual-wield Dagger/Sword DPS with Cadence stacks, Sonic WS follow-ups, and Encore haste.',
            highlights     =
            {
                'Grants Dual Wield, DEX/CHR, Attack, Accuracy, and Crit Rate scaling.',
                'Dagger/Sword hits build Cadence; Weapon Skills unleash Sonic follow-up damage + Encore.',
                'Unlocks Lunge & Flourish (20s) and Troubadour\'s Encore (45s) without overwriting buffs.',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.DEX, scaleTier(lvl, 5, 10, 16, 22) },
                    { xi.mod.CHR, scaleTier(lvl, 4, 8, 14, 18) },
                    { xi.mod.ATT, scaleTier(lvl, 12, 24, 42, 60) },
                    { xi.mod.ACC, scaleTier(lvl, 10, 20, 32, 45) },
                    { xi.mod.CRITHITRATE, scaleTier(lvl, 3, 5, 8, 10) },
                    { xi.mod.DOUBLE_ATTACK, scaleTier(lvl, 5, 8, 12, 15) },
                    { xi.mod.DUAL_WIELD, scaleTier(lvl, 10, 15, 20, 25) },
                    { xi.mod.SONG_SPELLCASTING_TIME, scaleTier(lvl, 25, 30, 35, 40) },
                    { xi.mod.SPELLINTERRUPT, 105 },
                }
            end,
            onApply = function(player)
                installBrdListeners(player)
                clearMinstrelAura(player)
            end,
            onRemove = function(player)
                clearBrdListeners(player)
                if player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_ADV_CADENCE)
                    player:delStatusEffectSilent(EFFECT_ADV_ENCORE)
                end
            end,
        },
        {
            id             = 2,
            key            = MUSICIAN_KEY,
            name           = 'Musician',
            role           = 'Magical Song Nuker',
            icon           = 'onyx_tome',
            extraAbilities = { ABIL_GRAND_FINALE, ABIL_LYRICAL_OVERDRIVE },
            extraTraits    = { TRAIT_MUSICIAN_RESONANCE },
            description    = 'Tavnazian lyrical mage spec: Turns Threnodies, Requiems, and Elegies into fast-cast elemental nukes that can Magic Burst.',
            highlights     =
            {
                'Threnodies, Requiems, Elegies, and Finale deal CHR + MAB magic damage and can Magic Burst.',
                'Offensive songs never overwrite your Ballad/Scherzo party buffs.',
                'Unlocks Grand Finale (20s Resonance burst) and Lyrical Overdrive (45s).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.CHR, scaleTier(lvl, 6, 12, 18, 25) },
                    { xi.mod.MATT, scaleTier(lvl, 18, 30, 42, 55) },
                    { xi.mod.MACC, scaleTier(lvl, 15, 25, 35, 45) },
                    { xi.mod.SINGING, scaleTier(lvl, 10, 18, 26, 35) },
                    { xi.mod.WIND, scaleTier(lvl, 10, 18, 26, 35) },
                    { xi.mod.STRING, scaleTier(lvl, 10, 18, 26, 35) },
                    { xi.mod.SONG_SPELLCASTING_TIME, scaleTier(lvl, 35, 45, 50, 50) },
                    { xi.mod.FASTCAST, scaleTier(lvl, 0, 0, 0, 10) },
                    { xi.mod.SONG_RECAST_DELAY, scaleTier(lvl, 2, 2, 3, 4) },
                    { xi.mod.REFRESH, scaleTier(lvl, 1, 2, 3, 4) },
                    { xi.mod.SPELLINTERRUPT, 105 },
                }
            end,
            onApply = function(player)
                installBrdListeners(player)
                clearMinstrelAura(player)
            end,
            onRemove = function(player)
                clearBrdListeners(player)
                if player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_MUS_RESONANCE)
                    player:delStatusEffectSilent(EFFECT_MUS_OVERDRIVE)
                end
            end,
        },
        {
            id             = 3,
            key            = MINSTREL_KEY,
            name           = 'Minstrel',
            role           = 'Pre-Nerf Lv.75 Song Tank',
            icon           = 'bastion_shield',
            extraAbilities = { ABIL_DISSONANT_CHORD, ABIL_IRON_ARIA },
            extraTraits    = { TRAIT_MINSTREL_BULWARK },
            description    = 'Homage to the pre-nerf Lv.75 BRD tank: Uncapped enmity on Lullaby/Elegy/Requiem, Minne/Paeon aura mastery, and Scherzo survival.',
            highlights     =
            {
                'Lullabies, Elegies, Requiems, and Finale generate heavy pre-nerf Volatile & Cumulative Enmity.',
                'Passively empowers Minne (PDT), Paeon (Regen), and Scherzo (tank-buster dampening) without re-casting.',
                'Unlocks Dissonant Chord (15s snap taunt) and Iron Aria (45s mitigation & sonic reflect).',
            },
            mods = function(_player, lvl)
                return
                {
                    { xi.mod.VIT, scaleTier(lvl, 6, 12, 18, 24) },
                    { xi.mod.CHR, scaleTier(lvl, 4, 8, 12, 16) },
                    { xi.mod.HPP, scaleTier(lvl, 12, 16, 20, 25) },
                    { xi.mod.DEFP, scaleTier(lvl, 12, 18, 24, 30) },
                    { xi.mod.ENMITY, scaleTier(lvl, 15, 22, 30, 40) },
                    { xi.mod.DMGPHYS, scaleTier(lvl, -600, -1000, -1400, -1800) },
                    { xi.mod.DMGMAGIC, scaleTier(lvl, -400, -700, -1000, -1200) },
                    { xi.mod.EVA, scaleTier(lvl, 10, 16, 22, 30) },
                    { xi.mod.REGEN, scaleTier(lvl, 2, 4, 6, 8) },
                    { xi.mod.SONG_SPELLCASTING_TIME, scaleTier(lvl, 30, 35, 45, 50) },
                    { xi.mod.SPELLINTERRUPT, 105 },
                }
            end,
            onApply = function(player)
                installBrdListeners(player)
                syncMinstrelAura(player)
            end,
            onRemove = function(player)
                clearBrdListeners(player)
                clearMinstrelAura(player)
                if player.delStatusEffectSilent then
                    player:delStatusEffectSilent(EFFECT_MIN_IRON_ARIA)
                end
            end,
        },
    })
end

return m
