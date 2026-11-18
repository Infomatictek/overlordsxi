-----------------------------------
-- OverlordsXI Central Custom Status Effect Registry
-- Auto-generated from modules/custom/data/custom_status_manifest.json
-- Registers xi.effect.<KEY> and xi.overlords.statusIcons[effectId] = iconId
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('overlords_status_registry')

xi = xi or {}
xi.effect = xi.effect or {}
xi.overlords = xi.overlords or {}
xi.overlords.statusIcons = xi.overlords.statusIcons or {}
xi.overlords.statusRegistry = xi.overlords.statusRegistry or {}

local ENTRIES =
{
    { effectId = 815, iconId =  24, key = 'COMMANDER_BREACH', name = 'commander_breach', aliases = {  } },
    { effectId = 816, iconId =  25, key = 'COMMANDER_BULWARK', name = 'commander_bulwark', aliases = {  } },
    { effectId = 817, iconId =  26, key = 'COMMANDER_CADENCE', name = 'commander_cadence', aliases = {  } },
    { effectId = 818, iconId =  27, key = 'COMMANDER_REGROUP', name = 'commander_regroup', aliases = {  } },
    { effectId = 819, iconId = 224, key = 'BERSERKER_SURGE', name = 'berserker_surge', aliases = {  } },
    { effectId = 820, iconId = 225, key = 'GLADIATOR_WARD', name = 'gladiator_ward', aliases = { 'SPARTAN_WARD' } },
    { effectId = 821, iconId = 226, key = 'INQUISITOR_BATTUTA', name = 'inquisitor_battuta', aliases = {  } },
    { effectId = 822, iconId = 232, key = 'INQUISITOR_AEGIS', name = 'inquisitor_aegis', aliases = {  } },
    { effectId = 823, iconId = 372, key = 'INQUISITOR_CONVERGE', name = 'inquisitor_converge', aliases = {  } },
    { effectId = 824, iconId = 373, key = 'SPELLBLADE_EDGEFLARE', name = 'spellblade_edgeflare', aliases = {  } },
    { effectId = 825, iconId = 374, key = 'LIFEBINDER_FONT', name = 'lifebinder_font', aliases = {  } },
    { effectId = 826, iconId = 514, key = 'LIFEBINDER_SANCTUARY', name = 'lifebinder_sanctuary', aliases = {  } },
    { effectId = 827, iconId = 520, key = 'SPELLBLADE_CONDUCTION', name = 'spellblade_conduction', aliases = {  } },
    { effectId = 828, iconId = 521, key = 'SPELLBLADE_ASCENDANCE', name = 'spellblade_ascendance', aliases = {  } },
    { effectId = 829, iconId = 636, key = 'CHIWEAVER_LOTUS', name = 'chiweaver_lotus', aliases = {  } },
    { effectId = 830, iconId = 637, key = 'CHIWEAVER_HARMONY', name = 'chiweaver_harmony', aliases = {  } },
    { effectId = 831, iconId = 638, key = 'SPELLBLADE_OVERCHARGE', name = 'spellblade_overcharge', aliases = {  } },
    { effectId = 832, iconId = 244, key = 'ADVENTURER_CADENCE', name = 'adventurer_cadence', aliases = {  } },
    { effectId = 833, iconId = 245, key = 'ADVENTURER_ENCORE', name = 'adventurer_encore', aliases = {  } },
    { effectId = 834, iconId = 246, key = 'MUSICIAN_RESONANCE', name = 'musician_resonance', aliases = {  } },
    { effectId = 835, iconId = 247, key = 'MUSICIAN_OVERDRIVE', name = 'musician_overdrive', aliases = {  } },
    { effectId = 836, iconId = 248, key = 'MINSTREL_IRON_ARIA', name = 'minstrel_iron_aria', aliases = {  } },
    { effectId = 837, iconId = 473, key = 'RONIN_STAGGER', name = 'ronin_stagger', aliases = {  } },
    { effectId = 838, iconId = 475, key = 'IMP_DRAWN_OISOYA', name = 'imp_drawn_oisoya', aliases = {  } },
    { effectId = 839, iconId = 476, key = 'IMP_COSMIC_BRAND', name = 'imp_cosmic_brand', aliases = {  } },
    { effectId = 840, iconId = 486, key = 'WARLORD_NOTO', name = 'warlord_noto', aliases = {  } },
    { effectId = 841, iconId = 487, key = 'WARLORD_ASHURA', name = 'warlord_ashura', aliases = {  } },
    { effectId = 842, iconId = 488, key = 'AEGIS_ZEAL', name = 'aegis_zeal', aliases = {  } },
    { effectId = 843, iconId = 489, key = 'AEGIS_CONSECRATION', name = 'aegis_consecration', aliases = {  } },
    { effectId = 844, iconId = 506, key = 'HOLY_RETRIBUTION', name = 'holy_retribution', aliases = {  } },
    { effectId = 845, iconId = 509, key = 'KAGEMUSHA_SHADOW_SMOKE', name = 'kagemusha_shadow_smoke', aliases = {  } },
    { effectId = 846, iconId = 510, key = 'KAGEMUSHA_BUNSHIN', name = 'kagemusha_bunshin', aliases = {  } },
    { effectId = 847, iconId = 572, key = 'ALPHA_PACK_INSTINCT', name = 'alpha_pack_instinct', aliases = {  } },
    { effectId = 848, iconId = 573, key = 'ALPHA_RENDING_BITE', name = 'alpha_rending_bite', aliases = {  } },
    { effectId = 849, iconId = 578, key = 'ALPHA_SOUL_BOND', name = 'alpha_soul_bond', aliases = {  } },
    { effectId = 850, iconId = 585, key = 'ALPHA_FERAL_ROAR', name = 'alpha_feral_roar', aliases = {  } },
    { effectId = 851, iconId = 587, key = 'ALPHA_FAMILIAR_BOND', name = 'alpha_familiar_bond', aliases = {  } },
    { effectId = 852, iconId = 602, key = 'ALPHA_REWARD_BOND', name = 'alpha_reward_bond', aliases = {  } },
    { effectId = 853, iconId = 605, key = 'CRIMSON_FLOW', name = 'crimson_flow', aliases = {  } },
    { effectId = 854, iconId = 606, key = 'CRIMSON_FLECHE', name = 'crimson_fleche', aliases = {  } },
    { effectId = 855, iconId = 607, key = 'BLOOD_CARAPACE', name = 'blood_carapace', aliases = {  } },
    { effectId = 856, iconId = 608, key = 'DREAD_BASTION', name = 'dread_bastion', aliases = {  } },
    { effectId = 857, iconId = 609, key = 'CHITIN_CARAPACE', name = 'chitin_carapace', aliases = {  } },
    { effectId = 858, iconId = 610, key = 'AZURE_SURGE', name = 'azure_surge', aliases = {  } },
    { effectId = 859, iconId = 613, key = 'DIAMOND_SHELL', name = 'diamond_shell', aliases = {  } },
    { effectId = 860, iconId = 614, key = 'SOLACE_WARD', name = 'solace_ward', aliases = {  } },
    { effectId = 861, iconId = 616, key = 'SACRED_GRACE', name = 'sacred_grace', aliases = {  } },
    { effectId = 862, iconId = 618, key = 'DIVINE_VEIL', name = 'divine_veil', aliases = {  } },
    { effectId = 863, iconId = 620, key = 'LIGHTS_GRACE', name = 'lights_grace', aliases = {  } },
    { effectId = 864, iconId = 624, key = 'CRUSADERS_AEGIS', name = 'crusaders_aegis', aliases = {  } },
    { effectId = 865, iconId = 627, key = 'AZURE_CATALYST', name = 'azure_catalyst', aliases = {  } },
    { effectId = 866, iconId = 629, key = 'OSMOTIC_CONDUIT', name = 'osmotic_conduit', aliases = {  } },
    { effectId = 867, iconId = 630, key = 'CRIMSON_VEIL', name = 'crimson_veil', aliases = {  } },
    { effectId = 868, iconId = 631, key = 'SANGUINE_WALTZ', name = 'sanguine_waltz', aliases = {  } },
    { effectId = 869, iconId = 632, key = 'CELESTIAL_SANCTUARY', name = 'celestial_sanctuary', aliases = {  } },
    { effectId = 870, iconId = 633, key = 'CELESTIAL_CONVERGENCE', name = 'celestial_convergence', aliases = {  } },
    { effectId = 871, iconId = 634, key = 'CLOCKWORK_AEGIS', name = 'clockwork_aegis', aliases = {  } },
    { effectId = 872, iconId = 635, key = 'BARKSKIN', name = 'barkskin', aliases = {  } },
    { effectId = 873, iconId = 250, key = 'CANOPY_OF_THE_ANCIENTS', name = 'canopy_of_the_ancients', aliases = {  } },
    { effectId = 874, iconId = 264, key = 'DRAGONSCALE', name = 'dragonscale', aliases = {  } },
    { effectId = 875, iconId = 267, key = 'DRAGONSCALE_SANCTUARY', name = 'dragonscale_sanctuary', aliases = {  } },
    { effectId = 876, iconId = 284, key = 'EFF_OX_SUP_OFFENSE', name = 'ox_sup_offense', aliases = {  } },
    { effectId = 877, iconId = 292, key = 'EFF_OX_SUP_CHAIN', name = 'ox_sup_chain', aliases = {  } },
    { effectId = 878, iconId = 474, key = 'EFF_OX_SUP_WARD', name = 'ox_sup_ward', aliases = {  } },
    { effectId = 879, iconId = 481, key = 'EFF_OX_DEB_BREACH', name = 'ox_deb_breach', aliases = {  } },
    { effectId = 880, iconId = 495, key = 'EFF_OX_DEB_CRIPPLE', name = 'ox_deb_cripple', aliases = {  } },
    { effectId = 881, iconId = 575, key = 'EFF_OX_DEB_EXPOSE', name = 'ox_deb_expose', aliases = {  } },
    { effectId = 882, iconId = 576, key = 'HOUSE_DEBT', name = 'house_debt', aliases = {  } },
    { effectId = 883, iconId = 603, key = 'CARD_COUNTING', name = 'card_counting', aliases = {  } },
    { effectId = 884, iconId = 626, key = 'HOUSE_ADVANTAGE', name = 'house_advantage', aliases = {  } },
}

for _, entry in ipairs(ENTRIES) do
    xi.effect[entry.key] = entry.effectId
    for _, alias in ipairs(entry.aliases) do
        xi.effect[alias] = entry.effectId
    end
    xi.overlords.statusIcons[entry.effectId] = entry.iconId
    xi.overlords.statusRegistry[entry.effectId] = entry
end

function xi.overlords.getStatusIcon(effectId, fallback)
    if effectId ~= nil and xi.overlords.statusIcons[effectId] ~= nil then
        return xi.overlords.statusIcons[effectId]
    end
    return fallback or effectId
end

return m
