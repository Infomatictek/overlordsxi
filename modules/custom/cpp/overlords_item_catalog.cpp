/************************************************************************
 * OverlordsXI Authoritative Item Catalog Bridge
 *
 * Exposes read-only access to LandSandBoat's authoritative in-memory item
 * templates (item_basic, item_equipment, item_weapon, item_mods,
 * item_mods_pet) plus SQL acquisition metadata (synth_recipes,
 * mob_droplist/mob_groups/mob_pools) and NPC shop scripts to Lua under
 * `xi.overlords.itemCatalog`.
 *
 * Zero duplicate item databases: every stat, job mask, slot bitmask,
 * weapon damage/delay/subskill, and acquisition flag is read directly
 * from the live server's own data.
 ************************************************************************/

#include "common/database.h"
#include "common/logging.h"
#include "common/utils.h"

#include "map/entities/battle_entity.h"
#include "map/items/item.h"
#include "map/items/item_equipment.h"
#include "map/items/item_weapon.h"
#include "map/lua/luautils.h"
#include "map/utils/itemutils.h"
#include "map/utils/moduleutils.h"

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <regex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace
{

struct AcquisitionInfo
{
    bool   shop{ false };
    bool   crafted{ false };
    bool   craftedHQ{ false };
    bool   normalDrop{ false };
    uint16 normalDropRate{ 0 };
    bool   nmDrop{ false };
    bool   bcnmDrop{ false };
};

struct IndexedItem
{
    uint16      id{ 0 };
    std::string name;
    uint8       reqLvl{ 0 };
    uint8       iLvl{ 0 };
    uint8       suLevel{ 0 };
    uint32      jobs{ 0 };
    uint16      slotMask{ 0 };
    uint16      removeSlotMask{ 0 };
    uint32      flags{ 0 };
    uint8       ahCat{ 0 };
    uint32      basePrice{ 0 };
    uint32      stackSize{ 1 };

    bool   isWeapon{ false };
    uint8  skill{ 0 };
    uint8  subskill{ 0 };
    uint16 dmg{ 0 };
    uint16 delay{ 0 };
    double dps{ 0.0 };
    uint8  hitCount{ 1 };
    bool   isTwoHanded{ false };
    bool   isH2H{ false };
    bool   isRanged{ false };
    bool   isThrowing{ false };
    bool   isShuriken{ false };

    bool  isShield{ false };
    uint8 shieldSize{ 0 };
    uint8 shieldAbsorb{ 0 };

    bool ex{ false };
    bool rare{ false };
    bool noAuction{ false };
    bool noSale{ false };
    bool gmOnly{ false };
    bool practical{ false };
    bool prestige{ false };

    AcquisitionInfo sources;

    std::vector<std::pair<uint16, int16>> mods;
    std::vector<std::pair<uint16, int16>> petMods;
};

bool                                     g_initialized = false;
std::vector<IndexedItem>                 g_items;
std::unordered_map<uint16, std::size_t>  g_itemIndexById;
std::size_t                              g_shopCount       = 0;
std::size_t                              g_craftedCount    = 0;
std::size_t                              g_normalDropCount = 0;
std::size_t                              g_nmDropCount     = 0;

void LoadShopItems(std::unordered_set<uint16>& shopItems)
{
    sol::object xiObj = lua["xi"];
    if (!xiObj.valid() || xiObj.get_type() != sol::type::table)
    {
        return;
    }

    sol::table  xiTbl   = xiObj.as<sol::table>();
    sol::object itemObj = xiTbl["item"];
    if (!itemObj.valid() || itemObj.get_type() != sol::type::table)
    {
        return;
    }

    sol::table itemEnum = itemObj.as<sol::table>();

    const std::filesystem::path zonesRoot("scripts/zones");
    std::error_code             ec;
    if (!std::filesystem::exists(zonesRoot, ec))
    {
        return;
    }

    const std::regex itemTokenRe(R"(xi\.item\.([A-Z0-9_]+))");

    for (const auto& entry : std::filesystem::recursive_directory_iterator(zonesRoot, ec))
    {
        if (ec || !entry.is_regular_file())
        {
            continue;
        }

        const auto& path = entry.path();
        if (path.extension() != ".lua")
        {
            continue;
        }

        if (path.parent_path().filename() != "npcs")
        {
            continue;
        }

        std::ifstream ifs(path);
        if (!ifs.is_open())
        {
            continue;
        }

        std::string content((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
        if (content.find("xi.shop.") == std::string::npos)
        {
            continue;
        }

        auto begin = std::sregex_iterator(content.begin(), content.end(), itemTokenRe);
        auto end   = std::sregex_iterator();
        for (auto it = begin; it != end; ++it)
        {
            const std::string enumName = (*it)[1].str();
            sol::object       val      = itemEnum[enumName];
            if (val.valid() && val.is<uint16>())
            {
                shopItems.insert(val.as<uint16>());
            }
        }
    }
}

void LoadCraftingRecipes(std::unordered_map<uint16, AcquisitionInfo>& acqById)
{
    const auto rset = db::preparedStmt(
        "SELECT `Result`, `ResultHQ1`, `ResultHQ2`, `ResultHQ3` "
        "FROM `synth_recipes` WHERE `Desynth` = 0");

    if (!rset)
    {
        return;
    }

    while (rset->next())
    {
        const uint16 nq  = rset->get<uint16>("Result");
        const uint16 hq1 = rset->get<uint16>("ResultHQ1");
        const uint16 hq2 = rset->get<uint16>("ResultHQ2");
        const uint16 hq3 = rset->get<uint16>("ResultHQ3");

        if (nq > 0)
        {
            acqById[nq].crafted = true;
        }
        if (hq1 > 0)
        {
            acqById[hq1].crafted   = true;
            acqById[hq1].craftedHQ = true;
        }
        if (hq2 > 0)
        {
            acqById[hq2].crafted   = true;
            acqById[hq2].craftedHQ = true;
        }
        if (hq3 > 0)
        {
            acqById[hq3].crafted   = true;
            acqById[hq3].craftedHQ = true;
        }
    }
}

void LoadMobDrops(std::unordered_map<uint16, AcquisitionInfo>& acqById)
{
    // MobType bitmask: Notorious=0x02, Called=0x08, Battlefield=0x10, Event=0x20 (mask 0x3A = 58)
    const auto rset = db::preparedStmt(
        "SELECT md.`itemId`, "
        "  MAX(CASE WHEN (mp.`mobType` & 58) = 0 THEN md.`itemRate` ELSE 0 END) AS normalRate, "
        "  MAX(CASE WHEN (mp.`mobType` & 2) <> 0 THEN md.`itemRate` ELSE 0 END) AS nmRate, "
        "  MAX(CASE WHEN (mp.`mobType` & 16) <> 0 THEN md.`itemRate` ELSE 0 END) AS bcnmRate "
        "FROM `mob_droplist` md "
        "INNER JOIN `mob_groups` mg ON mg.`dropid` = md.`dropId` "
        "INNER JOIN `mob_pools` mp ON mp.`poolid` = mg.`poolid` "
        "GROUP BY md.`itemId`");

    if (!rset)
    {
        return;
    }

    while (rset->next())
    {
        const uint16 itemId     = rset->get<uint16>("itemId");
        const uint16 normalRate = rset->get<uint16>("normalRate");
        const uint16 nmRate     = rset->get<uint16>("nmRate");
        const uint16 bcnmRate   = rset->get<uint16>("bcnmRate");

        auto& info = acqById[itemId];
        if (normalRate > 0)
        {
            info.normalDrop     = true;
            info.normalDropRate = std::max(info.normalDropRate, normalRate);
        }
        if (nmRate > 0)
        {
            info.nmDrop = true;
        }
        if (bcnmRate > 0)
        {
            info.bcnmDrop = true;
        }
    }
}

void EnsureInitialized()
{
    if (g_initialized)
    {
        return;
    }
    g_initialized = true;

    std::unordered_set<uint16>                  shopItems;
    std::unordered_map<uint16, AcquisitionInfo> acqById;

    LoadShopItems(shopItems);
    for (uint16 id : shopItems)
    {
        acqById[id].shop = true;
    }
    LoadCraftingRecipes(acqById);
    LoadMobDrops(acqById);

    g_items.clear();
    g_itemIndexById.clear();
    g_items.reserve(12000);

    for (uint32 id = 1; id < MAX_ITEMID; ++id)
    {
        const auto* PEquip = xi::items::lookup<CItemEquipment>(static_cast<uint16>(id));
        if (!PEquip || !PEquip->isType(ITEM_EQUIPMENT))
        {
            continue;
        }

        IndexedItem rec;
        rec.id             = PEquip->getID();
        rec.name           = PEquip->getName();
        rec.reqLvl         = PEquip->getReqLvl();
        rec.iLvl           = PEquip->getILvl();
        rec.suLevel        = PEquip->getSuperiorLevel();
        rec.jobs           = PEquip->getJobs();
        rec.slotMask       = PEquip->getEquipSlotId();
        rec.removeSlotMask = PEquip->getRemoveSlotId();
        rec.flags          = static_cast<uint32>(PEquip->getFlag());
        rec.ahCat          = PEquip->getAHCat();
        rec.basePrice      = PEquip->getBasePrice();
        rec.stackSize      = PEquip->getStackSize();

        rec.isShield     = PEquip->IsShield();
        rec.shieldSize   = rec.isShield ? PEquip->getShieldSize() : 0;
        rec.shieldAbsorb = rec.isShield ? PEquip->getShieldAbsorption() : 0;

        if (const auto* PWeapon = dynamic_cast<const CItemWeapon*>(PEquip))
        {
            rec.isWeapon    = true;
            rec.skill       = static_cast<uint8>(PWeapon->getSkillType());
            rec.subskill    = PWeapon->getSubSkillType();
            rec.dmg         = PWeapon->getDamage();
            rec.delay       = PWeapon->getDelay();
            rec.dps         = PWeapon->getDPS();
            rec.hitCount    = PWeapon->getHitCount();
            rec.isTwoHanded = PWeapon->isTwoHanded();
            rec.isH2H       = PWeapon->isHandToHand();
            rec.isRanged    = PWeapon->isRanged();
            rec.isThrowing  = PWeapon->isThrowing();
            rec.isShuriken  = PWeapon->isShuriken();
        }

        rec.ex        = PEquip->hasFlag(xi::ItemFlag::Exclusive);
        rec.rare      = PEquip->hasFlag(xi::ItemFlag::Rare);
        rec.noAuction = PEquip->hasFlag(xi::ItemFlag::NoAuction);
        rec.noSale    = PEquip->hasFlag(xi::ItemFlag::NoSale);
        rec.gmOnly    = PEquip->hasFlag(xi::ItemFlag::GmOnly);

        if (const auto it = acqById.find(rec.id); it != acqById.end())
        {
            rec.sources = it->second;
        }

        const bool hasAccessibleSource =
            rec.sources.shop ||
            rec.sources.crafted ||
            (rec.sources.normalDrop && rec.sources.normalDropRate >= 50);

        const bool ahTradable = !rec.ex && !rec.noAuction && rec.ahCat > 0;

        // Practical items: Lv.1-75, non-GM, non-iLvl, non-SU, and obtainable via
        // NPC shop, standard crafting, normal mob drops, or non-NM/non-BCNM AH trade.
        rec.practical =
            !rec.gmOnly &&
            rec.iLvl == 0 &&
            rec.suLevel == 0 &&
            (hasAccessibleSource || (ahTradable && !rec.rare && !rec.sources.nmDrop && !rec.sources.bcnmDrop));

        rec.prestige = !rec.practical;

        rec.mods.reserve(PEquip->modList.size());
        for (const auto& mod : PEquip->modList)
        {
            rec.mods.emplace_back(static_cast<uint16>(mod.getModID()), mod.getModAmount());
        }

        rec.petMods.reserve(PEquip->petModList.size());
        for (const auto& petMod : PEquip->petModList)
        {
            rec.petMods.emplace_back(static_cast<uint16>(petMod.getModID()), petMod.getModAmount());
        }

        if (rec.sources.shop)
        {
            ++g_shopCount;
        }
        if (rec.sources.crafted)
        {
            ++g_craftedCount;
        }
        if (rec.sources.normalDrop)
        {
            ++g_normalDropCount;
        }
        if (rec.sources.nmDrop)
        {
            ++g_nmDropCount;
        }

        g_itemIndexById[rec.id] = g_items.size();
        g_items.push_back(std::move(rec));
    }

    ShowInfo(fmt::format(
        "OverlordsItemCatalog: indexed {} equipment items ({} shop, {} crafted, {} normal-drop, {} nm-drop).",
        g_items.size(),
        g_shopCount,
        g_craftedCount,
        g_normalDropCount,
        g_nmDropCount));
}

auto ToLuaTable(const IndexedItem& rec) -> sol::table
{
    sol::table t        = lua.create_table();
    t["id"]             = rec.id;
    t["name"]           = rec.name;
    t["lvl"]            = rec.reqLvl;
    t["ilvl"]           = rec.iLvl;
    t["suLevel"]        = rec.suLevel;
    t["jobs"]           = rec.jobs;
    t["slotMask"]       = rec.slotMask;
    t["removeSlotMask"] = rec.removeSlotMask;
    t["flags"]          = rec.flags;
    t["ahCat"]          = rec.ahCat;
    t["basePrice"]      = rec.basePrice;
    t["stackSize"]      = rec.stackSize;

    t["isWeapon"]    = rec.isWeapon;
    t["skill"]       = rec.skill;
    t["subskill"]    = rec.subskill;
    t["dmg"]         = rec.dmg;
    t["delay"]       = rec.delay;
    t["dps"]         = rec.dps;
    t["hitCount"]    = rec.hitCount;
    t["isTwoHanded"] = rec.isTwoHanded;
    t["isH2H"]       = rec.isH2H;
    t["isRanged"]    = rec.isRanged;
    t["isThrowing"]  = rec.isThrowing;
    t["isShuriken"]  = rec.isShuriken;

    t["isShield"]     = rec.isShield;
    t["shieldSize"]   = rec.shieldSize;
    t["shieldAbsorb"] = rec.shieldAbsorb;

    t["ex"]        = rec.ex;
    t["rare"]      = rec.rare;
    t["noAuction"] = rec.noAuction;
    t["noSale"]    = rec.noSale;
    t["gmOnly"]    = rec.gmOnly;
    t["practical"] = rec.practical;
    t["prestige"]  = rec.prestige;

    sol::table src        = lua.create_table();
    src["shop"]           = rec.sources.shop;
    src["crafted"]        = rec.sources.crafted;
    src["craftedHQ"]      = rec.sources.craftedHQ;
    src["normalDrop"]     = rec.sources.normalDrop;
    src["normalDropRate"] = rec.sources.normalDropRate;
    src["nmDrop"]         = rec.sources.nmDrop;
    src["bcnmDrop"]       = rec.sources.bcnmDrop;
    t["sources"]          = src;

    sol::table modsTbl = lua.create_table();
    for (const auto& [modId, val] : rec.mods)
    {
        modsTbl[modId] = val;
    }
    t["mods"] = modsTbl;

    sol::table petModsTbl = lua.create_table();
    for (const auto& [modId, val] : rec.petMods)
    {
        petModsTbl[modId] = val;
    }
    t["petMods"] = petModsTbl;

    return t;
}

void RegisterLuaBindings()
{
    sol::table xiTbl = lua["xi"].get_or_create<sol::table>();
    sol::table ovTbl = xiTbl["overlords"].get_or_create<sol::table>();
    sol::table cat   = ovTbl["itemCatalog"].get_or_create<sol::table>();

    cat["isAvailable"] = []() -> bool
    {
        return true;
    };

    cat["getStats"] = []() -> sol::table
    {
        EnsureInitialized();
        sol::table stats          = lua.create_table();
        stats["totalEquipment"]   = g_items.size();
        stats["shopItems"]        = g_shopCount;
        stats["craftedItems"]     = g_craftedCount;
        stats["normalDropItems"]  = g_normalDropCount;
        stats["nmDropItems"]      = g_nmDropCount;
        return stats;
    };

    cat["getItem"] = [](uint16 itemId) -> sol::object
    {
        EnsureInitialized();
        const auto it = g_itemIndexById.find(itemId);
        if (it == g_itemIndexById.end())
        {
            return sol::lua_nil;
        }
        return sol::make_object(lua, ToLuaTable(g_items[it->second]));
    };

    cat["querySlot"] = [](uint16 slotBit, uint8 jobId, uint8 maxLevel, sol::optional<sol::table> optsOpt) -> sol::table
    {
        EnsureInitialized();

        const uint8 clampedMaxLvl = std::min<uint8>(maxLevel, 75);
        uint8       minLevel      = 1;
        int32       reqSkill      = -1;
        int32       reqSubskill   = -1;
        int32       exclSubskill  = -1;
        int32       reqShield     = -1; // -1 = any, 0 = false, 1 = true
        int32       reqWeapon     = -1; // -1 = any, 0 = false, 1 = true
        bool        allowRSlot    = false;
        bool        inclPrestige  = false;
        bool        ignoreJobMask = false;
        uint16      excludeId     = 0;

        if (optsOpt.has_value())
        {
            const sol::table& opts = optsOpt.value();
            minLevel               = opts.get_or<uint8>("minLevel", 1);
            reqSkill               = opts.get_or<int32>("skill", -1);
            reqSubskill            = opts.get_or<int32>("subskill", -1);
            exclSubskill           = opts.get_or<int32>("excludeSubskill", -1);
            allowRSlot             = opts.get_or<bool>("allowRemoveSlot", false);
            inclPrestige           = opts.get_or<bool>("includePrestige", false);
            ignoreJobMask          = opts.get_or<bool>("ignoreJobMask", false);
            excludeId              = opts.get_or<uint16>("excludeId", 0);

            if (sol::object sh = opts["isShield"]; sh.valid() && sh.is<bool>())
            {
                reqShield = sh.as<bool>() ? 1 : 0;
            }
            if (sol::object wp = opts["isWeapon"]; wp.valid() && wp.is<bool>())
            {
                reqWeapon = wp.as<bool>() ? 1 : 0;
            }
        }

        const uint32 jobBit = (jobId >= 1 && jobId <= 22) ? (1u << (jobId - 1)) : 0u;
        sol::table   out    = lua.create_table();
        std::size_t  idx    = 1;

        for (const auto& rec : g_items)
        {
            if (rec.gmOnly || rec.iLvl > 0 || rec.suLevel > 0)
            {
                continue;
            }
            if (rec.reqLvl < minLevel || rec.reqLvl > clampedMaxLvl)
            {
                continue;
            }
            if ((rec.slotMask & slotBit) == 0)
            {
                continue;
            }
            if (!allowRSlot && rec.removeSlotMask != 0)
            {
                continue;
            }
            if (excludeId > 0 && rec.id == excludeId)
            {
                continue;
            }
            if (!ignoreJobMask && jobBit != 0 && (rec.jobs & jobBit) == 0)
            {
                continue;
            }
            if (!inclPrestige && !rec.practical)
            {
                continue;
            }
            if (reqWeapon == 1 && !rec.isWeapon)
            {
                continue;
            }
            if (reqWeapon == 0 && rec.isWeapon)
            {
                continue;
            }
            if (reqShield == 1 && !rec.isShield)
            {
                continue;
            }
            if (reqShield == 0 && rec.isShield)
            {
                continue;
            }
            if (reqSkill >= 0 && static_cast<int32>(rec.skill) != reqSkill)
            {
                continue;
            }
            if (reqSubskill >= 0 && static_cast<int32>(rec.subskill) != reqSubskill)
            {
                continue;
            }
            if (exclSubskill >= 0 && static_cast<int32>(rec.subskill) == exclSubskill)
            {
                continue;
            }

            out[idx++] = ToLuaTable(rec);
        }

        return out;
    };
}

} // namespace

class OverlordsItemCatalogModule : public CPPModule
{
    void OnInit() override
    {
        RegisterLuaBindings();
    }
};

REGISTER_CPP_MODULE(OverlordsItemCatalogModule);
