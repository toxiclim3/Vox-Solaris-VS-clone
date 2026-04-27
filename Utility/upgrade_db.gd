extends Node


const ICON_PATH = "res://Textures/Items/Upgrades/"
const WEAPON_PATH = "res://Textures/Items/Weapons/"
const UPGRADES = {
	"icespear1": 
	{
		"icon": WEAPON_PATH + "ice_spear.png",
		"displayname": "item_icespear",
		"details": "ItemDesc_IceSpear1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"icespear2": 
	{
		"icon": WEAPON_PATH + "ice_spear.png",
		"displayname": "item_icespear",
		"details": "ItemDesc_IceSpear2",
		"level": "item_level2",
		"prerequisite": ["icespear1"],
		"type": "weapon"
	},
	"icespear3": 
	{
		"icon": WEAPON_PATH + "ice_spear.png",
		"displayname": "item_icespear",
		"details": "ItemDesc_IceSpear3",
		"level": "item_level3",
		"prerequisite": ["icespear2"],
		"type": "weapon"
	},
	"icespear4": 
	{
		"icon": WEAPON_PATH + "ice_spear.png",
		"displayname": "item_icespear",
		"details": "ItemDesc_IceSpear4",
		"level": "item_level4",
		"prerequisite": ["icespear3"],
		"type": "weapon"
	},
	"javelin1": 
	{
		"icon": WEAPON_PATH + "javelin_3_new_attack.png",
		"displayname": "item_javelin",
		"details": "ItemDesc_Javelin1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"javelin2": 
	{
		"icon": WEAPON_PATH + "javelin_3_new_attack.png",
		"displayname": "item_javelin",
		"details": "ItemDesc_Javelin2",
		"level": "item_level2",
		"prerequisite": ["javelin1"],
		"type": "weapon"
	},
	"javelin3": 
	{
		"icon": WEAPON_PATH + "javelin_3_new_attack.png",
		"displayname": "item_javelin",
		"details": "ItemDesc_Javelin3",
		"level": "item_level3",
		"prerequisite": ["javelin2"],
		"type": "weapon"
	},
	"javelin4": 
	{
		"icon": WEAPON_PATH + "javelin_3_new_attack.png",
		"displayname": "item_javelin",
		"details": "ItemDesc_Javelin4",
		"level": "item_level4",
		"prerequisite": ["javelin3"],
		"type": "weapon"
	},
	"tornado1": 
	{
		"icon": WEAPON_PATH + "tornado.png",
		"displayname": "item_tornado",
		"details": "ItemDesc_Tornado1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"tornado2": 
	{
		"icon": WEAPON_PATH + "tornado.png",
		"displayname": "item_tornado",
		"details": "ItemDesc_Tornado2",
		"level": "item_level2",
		"prerequisite": ["tornado1"],
		"type": "weapon"
	},
	"tornado3": 
	{
		"icon": WEAPON_PATH + "tornado.png",
		"displayname": "item_tornado",
		"details": "ItemDesc_Tornado3",
		"level": "item_level3",
		"prerequisite": ["tornado2"],
		"type": "weapon"
	},
	"tornado4": 
	{
		"icon": WEAPON_PATH + "tornado.png",
		"displayname": "item_tornado",
		"details": "ItemDesc_Tornado4",
		"level": "item_level4",
		"prerequisite": ["tornado3"],
		"type": "weapon"
	},
	"armor1": 
	{
		"icon": ICON_PATH + "helmet_1.png",
		"displayname": "item_armor",
		"details": "ItemDesc_Armor1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"armor": 1}
	},
	"armor2": 
	{
		"icon": ICON_PATH + "helmet_1.png",
		"displayname": "item_armor",
		"details": "ItemDesc_Armor2",
		"level": "item_level2",
		"prerequisite": ["armor1"],
		"type": "upgrade",
		"stat_modifiers": {"armor": 1}
	},
	"armor3": 
	{
		"icon": ICON_PATH + "helmet_1.png",
		"displayname": "item_armor",
		"details": "ItemDesc_Armor3",
		"level": "item_level3",
		"prerequisite": ["armor2"],
		"type": "upgrade",
		"stat_modifiers": {"armor": 1}
	},
	"armor4": 
	{
		"icon": ICON_PATH + "helmet_1.png",
		"displayname": "item_armor",
		"details": "ItemDesc_Armor4",
		"level": "item_level4",
		"prerequisite": ["armor3"],
		"type": "upgrade",
		"stat_modifiers": {"armor": 1}
	},
	"speed1": 
	{
		"icon": ICON_PATH + "boots_4_green.png",
		"displayname": "item_speed",
		"details": "ItemDesc_Speed1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"movement_speed_percent": 0.20}
	},
	"speed2": 
	{
		"icon": ICON_PATH + "boots_4_green.png",
		"displayname": "item_speed",
		"details": "ItemDesc_Speed2",
		"level": "item_level2",
		"prerequisite": ["speed1"],
		"type": "upgrade",
		"stat_modifiers": {"movement_speed_percent": 0.10}
	},
	"speed3": 
	{
		"icon": ICON_PATH + "boots_4_green.png",
		"displayname": "item_speed",
		"details": "ItemDesc_Speed3",
		"level": "item_level3",
		"prerequisite": ["speed2"],
		"type": "upgrade",
		"stat_modifiers": {"movement_speed_percent": 0.10}
	},
	"speed4": 
	{
		"icon": ICON_PATH + "boots_4_green.png",
		"displayname": "item_speed",
		"details": "ItemDesc_Speed4",
		"level": "item_level4",
		"prerequisite": ["speed3"],
		"type": "upgrade",
		"stat_modifiers": {"movement_speed_percent": 0.10}
	},
	"tome1": 
	{
		"icon": ICON_PATH + "thick_new.png",
		"displayname": "item_tome",
		"details": "ItemDesc_Tome1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"spell_size": 0.10}
	},
	"tome2": 
	{
		"icon": ICON_PATH + "thick_new.png",
		"displayname": "item_tome",
		"details": "ItemDesc_Tome2",
		"level": "item_level2",
		"prerequisite": ["tome1"],
		"type": "upgrade",
		"stat_modifiers": {"spell_size": 0.10}
	},
	"tome3": 
	{
		"icon": ICON_PATH + "thick_new.png",
		"displayname": "item_tome",
		"details": "ItemDesc_Tome3",
		"level": "item_level3",
		"prerequisite": ["tome2"],
		"type": "upgrade",
		"stat_modifiers": {"spell_size": 0.10}
	},
	"tome4": 
	{
		"icon": ICON_PATH + "thick_new.png",
		"displayname": "item_tome",
		"details": "ItemDesc_Tome4",
		"level": "item_level4",
		"prerequisite": ["tome3"],
		"type": "upgrade",
		"stat_modifiers": {"spell_size": 0.10}
	},
	"scroll1": 
	{
		"icon": ICON_PATH + "scroll_old.png",
		"displayname": "item_scroll",
		"details": "ItemDesc_Scroll1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"spell_cooldown": 0.05}
	},
	"scroll2": 
	{
		"icon": ICON_PATH + "scroll_old.png",
		"displayname": "item_scroll",
		"details": "ItemDesc_Scroll2",
		"level": "item_level2",
		"prerequisite": ["scroll1"],
		"type": "upgrade",
		"stat_modifiers": {"spell_cooldown": 0.05}
	},
	"scroll3": 
	{
		"icon": ICON_PATH + "scroll_old.png",
		"displayname": "item_scroll",
		"details": "ItemDesc_Scroll3",
		"level": "item_level3",
		"prerequisite": ["scroll2"],
		"type": "upgrade",
		"stat_modifiers": {"spell_cooldown": 0.05}
	},
	"scroll4": 
	{
		"icon": ICON_PATH + "scroll_old.png",
		"displayname": "item_scroll",
		"details": "ItemDesc_Scroll4",
		"level": "item_level4",
		"prerequisite": ["scroll3"],
		"type": "upgrade",
		"stat_modifiers": {"spell_cooldown": 0.05}
	},
	"ring1": 
	{
		"icon": ICON_PATH + "urand_mage.png",
		"displayname": "item_ring",
		"details": "ItemDesc_Ring1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "bossitem",
		"stat_modifiers": {"additional_attacks": 1}
	},
	"ring2": 
	{
		"icon": ICON_PATH + "urand_mage.png",
		"displayname": "item_ring",
		"details": "ItemDesc_Ring2",
		"level": "item_level2",
		"prerequisite": ["ring1"],
		"type": "bossitem",
		"stat_modifiers": {"additional_attacks": 1}
	},
	"ringofrejuvenation1": 
	{
		"icon": ICON_PATH + "icon26.png",
		"displayname": "item_ringofrejuvenation",
		"details": "ItemDesc_RingOfRejuvenation1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"max_hp_percent": 0.30}
	},
	"ringofrejuvenation2": 
	{
		"icon": ICON_PATH + "icon26.png",
		"displayname": "item_ringofrejuvenation",
		"details": "ItemDesc_RingOfRejuvenation2",
		"level": "item_level2",
		"prerequisite": ["ringofrejuvenation1"],
		"type": "upgrade",
		"stat_modifiers": {"regen": 0.001}
	},
	"ringofaffinity1": 
	{
		"icon": ICON_PATH + "icon25.png",
		"displayname": "item_ringofaffinity",
		"details": "ItemDesc_RingOfAffinity1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"xp_range_percent": 0.20}
	},
	"ringofaffinity2": 
	{
		"icon": ICON_PATH + "icon25.png",
		"displayname": "item_ringofaffinity",
		"details": "ItemDesc_RingOfAffinity2",
		"level": "item_level2",
		"prerequisite": ["ringofaffinity1"],
		"type": "upgrade",
		"stat_modifiers": {"xp_range_percent": 0.40}
	},
	"poisonbottle1": 
	{
		"icon": WEAPON_PATH + "poison_gas.png",
		"displayname": "item_poisonbottle",
		"details": "ItemDesc_PoisonBottle1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"poisonbottle2": 
	{
		"icon": WEAPON_PATH + "poison_gas.png",
		"displayname": "item_poisonbottle",
		"details": "ItemDesc_PoisonBottle2",
		"level": "item_level2",
		"prerequisite": ["poisonbottle1"],
		"type": "weapon"
	},
	"poisonbottle3": 
	{
		"icon": WEAPON_PATH + "poison_gas.png",
		"displayname": "item_poisonbottle",
		"details": "ItemDesc_PoisonBottle3",
		"level": "item_level3",
		"prerequisite": ["poisonbottle2"],
		"type": "weapon"
	},
	"poisonbottle4": 
	{
		"icon": WEAPON_PATH + "poison_gas.png",
		"displayname": "item_poisonbottle",
		"details": "ItemDesc_PoisonBottle4",
		"level": "item_level4",
		"prerequisite": ["poisonbottle3"],
		"type": "weapon"
	},
	"ritualcircle1": 
	{
		"icon": WEAPON_PATH + "ritual_chalk.png",
		"displayname": "item_ritualcircle",
		"details": "ItemDesc_RitualCircle1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"ritualcircle2": 
	{
		"icon": WEAPON_PATH + "ritual_chalk.png",
		"displayname": "item_ritualcircle",
		"details": "ItemDesc_RitualCircle2",
		"level": "item_level2",
		"prerequisite": ["ritualcircle1"],
		"type": "weapon"
	},
	"ritualcircle3": 
	{
		"icon": WEAPON_PATH + "ritual_chalk.png",
		"displayname": "item_ritualcircle",
		"details": "ItemDesc_RitualCircle3",
		"level": "item_level3",
		"prerequisite": ["ritualcircle2"],
		"type": "weapon"
	},
	"ritualcircle4": 
	{
		"icon": WEAPON_PATH + "ritual_chalk.png",
		"displayname": "item_ritualcircle",
		"details": "ItemDesc_RitualCircle4",
		"level": "item_level4",
		"prerequisite": ["ritualcircle3"],
		"type": "weapon"
	},
	"lightningrod1": 
	{
		"icon": WEAPON_PATH + "rod_6_new.png",
		"displayname": "item_lightningrod",
		"details": "ItemDesc_LightningRod1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"lightningrod2": 
	{
		"icon": WEAPON_PATH + "rod_6_new.png",
		"displayname": "item_lightningrod",
		"details": "ItemDesc_LightningRod2",
		"level": "item_level2",
		"prerequisite": ["lightningrod1"],
		"type": "weapon"
	},
	"lightningrod3": 
	{
		"icon": WEAPON_PATH + "rod_6_new.png",
		"displayname": "item_lightningrod",
		"details": "ItemDesc_LightningRod3",
		"level": "item_level3",
		"prerequisite": ["lightningrod2"],
		"type": "weapon"
	},
	"lightningrod4": 
	{
		"icon": WEAPON_PATH + "rod_6_new.png",
		"displayname": "item_lightningrod",
		"details": "ItemDesc_LightningRod4",
		"level": "item_level4",
		"prerequisite": ["lightningrod3"],
		"type": "weapon"
	},
	"food": 
	{
		"icon": ICON_PATH + "chunk.png",
		"displayname": "item_food",
		"details": "ItemDesc_Food",
		"level": "item_levelNA",
		"prerequisite": [],
		"type": "item",
		"stat_modifiers": {"hp": 20}
	},
	"glasslash1": 
	{
		"icon": WEAPON_PATH + "Kaleidoscope.webp",
		"displayname": "item_glasslash",
		"details": "ItemDesc_GlassLash1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "bossitem"
	},
	"glasslash2": 
	{
		"icon": WEAPON_PATH + "Kaleidoscope.webp",
		"displayname": "item_glasslash",
		"details": "ItemDesc_GlassLash2",
		"level": "item_level2",
		"prerequisite": ["glasslash1"],
		"type": "bossitem"
	},
	"glasslash3": 
	{
		"icon": WEAPON_PATH + "Kaleidoscope.webp",
		"displayname": "item_glasslash",
		"details": "ItemDesc_GlassLash3",
		"level": "item_level3",
		"prerequisite": ["glasslash2"],
		"type": "bossitem"
	},
	"glasslash4": 
	{
		"icon": WEAPON_PATH + "Kaleidoscope.webp",
		"displayname": "item_glasslash",
		"details": "ItemDesc_GlassLash4",
		"level": "item_level4",
		"prerequisite": ["glasslash3"],
		"type": "bossitem"
	},
	"vampireknives1": 
	{
		"icon": WEAPON_PATH + "Vampire_Knives.webp",
		"displayname": "item_vampireknives",
		"details": "ItemDesc_VampireKnives1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "bossitem"
	},
	"vampireknives2": 
	{
		"icon": WEAPON_PATH + "Vampire_Knives.webp",
		"displayname": "item_vampireknives",
		"details": "ItemDesc_VampireKnives2",
		"level": "item_level2",
		"prerequisite": ["vampireknives1"],
		"type": "bossitem"
	},
	"vampireknives3": 
	{
		"icon": WEAPON_PATH + "Vampire_Knives.webp",
		"displayname": "item_vampireknives",
		"details": "ItemDesc_VampireKnives3",
		"level": "item_level3",
		"prerequisite": ["vampireknives2"],
		"type": "bossitem"
	},
	"vampireknives4": 
	{
		"icon": WEAPON_PATH + "Vampire_Knives.webp",
		"displayname": "item_vampireknives",
		"details": "ItemDesc_VampireKnives4",
		"level": "item_level4",
		"prerequisite": ["vampireknives3"],
		"type": "bossitem"
	},
	"thornring1": 
	{
		"icon": ICON_PATH + "urand_octoring.png",
		"displayname": "item_thornring",
		"details": "ItemDesc_ThornRing1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade",
		"stat_modifiers": {"armor_multiplier": 0.20, "reflected_damage": 10}
	},
	"thornring2": 
	{
		"icon": ICON_PATH + "urand_octoring.png",
		"displayname": "item_thornring",
		"details": "ItemDesc_ThornRing2",
		"level": "item_level2",
		"prerequisite": ["thornring1"],
		"type": "upgrade",
		"stat_modifiers": {"reflected_damage": 10}
	},
	"thornring3": 
	{
		"icon": ICON_PATH + "urand_octoring.png",
		"displayname": "item_thornring",
		"details": "ItemDesc_ThornRing3",
		"level": "item_level3",
		"prerequisite": ["thornring2"],
		"type": "upgrade",
		"stat_modifiers": {"reflected_damage": 10}
	},
	"thornring4": 
	{
		"icon": ICON_PATH + "urand_octoring.png",
		"displayname": "item_thornring",
		"details": "ItemDesc_ThornRing4",
		"level": "item_level4",
		"prerequisite": ["thornring3"],
		"type": "upgrade",
		"stat_modifiers": {"reflected_damage": 15}
	},
	"occult_medallion1": 
	{
		"icon": ICON_PATH + "urand_cekugob_old.png",
		"displayname": "item_occult_medallion",
		"details": "ItemDesc_OccultMedallion1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade"
	},
	"occult_medallion2": 
	{
		"icon": ICON_PATH + "urand_cekugob_old.png",
		"displayname": "item_occult_medallion",
		"details": "ItemDesc_OccultMedallion2",
		"level": "item_level2",
		"prerequisite": ["occult_medallion1"],
		"type": "upgrade"
	},
	"occult_medallion3": 
	{
		"icon": ICON_PATH + "urand_cekugob_old.png",
		"displayname": "item_occult_medallion",
		"details": "ItemDesc_OccultMedallion3",
		"level": "item_level3",
		"prerequisite": ["occult_medallion2"],
		"type": "upgrade"
	},
	"occult_medallion4": 
	{
		"icon": ICON_PATH + "urand_cekugob_old.png",
		"displayname": "item_occult_medallion",
		"details": "ItemDesc_OccultMedallion4",
		"level": "item_level4",
		"prerequisite": ["occult_medallion3"],
		"type": "upgrade"
	},
	"willowisp1": 
	{
		"icon": ICON_PATH + "icon13.png",
		"displayname": "item_willowisp",
		"details": "ItemDesc_WillOWisp1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "upgrade"
	},
	"willowisp2": 
	{
		"icon": ICON_PATH + "icon13.png",
		"displayname": "item_willowisp",
		"details": "ItemDesc_WillOWisp2",
		"level": "item_level2",
		"prerequisite": ["willowisp1"],
		"type": "upgrade"
	},
	"willowisp3": 
	{
		"icon": ICON_PATH + "icon13.png",
		"displayname": "item_willowisp",
		"details": "ItemDesc_WillOWisp3",
		"level": "item_level3",
		"prerequisite": ["willowisp2"],
		"type": "upgrade"
	},
	"willowisp4": 
	{
		"icon": ICON_PATH + "icon13.png",
		"displayname": "item_willowisp",
		"details": "ItemDesc_WillOWisp4",
		"level": "item_level4",
		"prerequisite": ["willowisp3"],
		"type": "upgrade"
	},
	"whip1": 
	{
		"icon": WEAPON_PATH + "Leather_Whip.webp",
		"displayname": "item_whip",
		"details": "ItemDesc_Whip1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "weapon"
	},
	"whip2": 
	{
		"icon": WEAPON_PATH + "Leather_Whip.webp",
		"displayname": "item_whip",
		"details": "ItemDesc_Whip2",
		"level": "item_level2",
		"prerequisite": ["whip1"],
		"type": "weapon"
	},
	"whip3": 
	{
		"icon": WEAPON_PATH + "Leather_Whip.webp",
		"displayname": "item_whip",
		"details": "ItemDesc_Whip3",
		"level": "item_level3",
		"prerequisite": ["whip2"],
		"type": "weapon"
	},
	"whip4": 
	{
		"icon": WEAPON_PATH + "Leather_Whip.webp",
		"displayname": "item_whip",
		"details": "ItemDesc_Whip4",
		"level": "item_level4",
		"prerequisite": ["whip3"],
		"type": "weapon"
	},
	"icespear_endless": 
	{
		"icon": WEAPON_PATH + "ice_spear.png",
		"displayname": "item_icespear",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["icespear4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"javelin_endless": 
	{
		"icon": WEAPON_PATH + "javelin_3_new_attack.png",
		"displayname": "item_javelin",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["javelin4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"tornado_endless": 
	{
		"icon": WEAPON_PATH + "tornado.png",
		"displayname": "item_tornado",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["tornado4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"poisonbottle_endless": 
	{
		"icon": WEAPON_PATH + "poison_gas.png",
		"displayname": "item_poisonbottle",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["poisonbottle4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"ritualcircle_endless": 
	{
		"icon": WEAPON_PATH + "ritual_chalk.png",
		"displayname": "item_ritualcircle",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["ritualcircle4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"lightningrod_endless": 
	{
		"icon": WEAPON_PATH + "rod_6_new.png",
		"displayname": "item_lightningrod",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["lightningrod4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"glasslash_endless": 
	{
		"icon": WEAPON_PATH + "Kaleidoscope.webp",
		"displayname": "item_glasslash",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["glasslash4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"vampireknives_endless": 
	{
		"icon": WEAPON_PATH + "Vampire_Knives.webp",
		"displayname": "item_vampireknives",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["vampireknives4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"whip_endless": 
	{
		"icon": WEAPON_PATH + "Leather_Whip.webp",
		"displayname": "item_whip",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["whip4"],
		"type": "endless",
		"stat_modifiers": {"damage": 1}
	},
	"armor_endless": 
	{
		"icon": ICON_PATH + "helmet_1.png",
		"displayname": "item_armor",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["armor4"],
		"type": "endless",
		"stat_modifiers": {"armor": 1}
	},
	"speed_endless": 
	{
		"icon": ICON_PATH + "boots_4_green.png",
		"displayname": "item_speed",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["speed4"],
		"type": "endless",
		"stat_modifiers": {"movement_speed_percent": 0.02}
	},
	"tome_endless": 
	{
		"icon": ICON_PATH + "thick_new.png",
		"displayname": "item_tome",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["tome4"],
		"type": "endless",
		"stat_modifiers": {"spell_size": 0.02}
	},
	"scroll_endless": 
	{
		"icon": ICON_PATH + "scroll_old.png",
		"displayname": "item_scroll",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["scroll4"],
		"type": "endless",
		"stat_modifiers": {"spell_cooldown": 0.02}
	},
	"ring_endless": 
	{
		"icon": ICON_PATH + "urand_mage.png",
		"displayname": "item_ring",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["ring2"],
		"type": "endless",
		"stat_modifiers": {"additional_attacks": 0.05}
	},
	"ringofrejuvenation_endless": 
	{
		"icon": ICON_PATH + "icon26.png",
		"displayname": "item_ringofrejuvenation",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["ringofrejuvenation2"],
		"type": "endless",
		"stat_modifiers": {"hp": 5}
	},
	"ringofaffinity_endless": 
	{
		"icon": ICON_PATH + "icon25.png",
		"displayname": "item_ringofaffinity",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["ringofaffinity2"],
		"type": "endless",
		"stat_modifiers": {"xp_range_percent": 0.05}
	},
	"thornring_endless": 
	{
		"icon": ICON_PATH + "urand_octoring.png",
		"displayname": "item_thornring",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["thornring4"],
		"type": "endless",
		"stat_modifiers": {"reflected_damage": 5}
	},
	"occult_medallion_endless": 
	{
		"icon": ICON_PATH + "urand_cekugob_old.png",
		"displayname": "item_occult_medallion",
		"details": "item_level_endless_details",
		"level": "item_level_endless",
		"prerequisite": ["occult_medallion4"],
		"type": "endless"
	},
	"relicdrone1": 
	{
		"icon": ICON_PATH + "relic_drone.png",
		"displayname": "item_relicdrone",
		"details": "ItemDesc_RelicDrone1",
		"level": "item_level1",
		"prerequisite": [],
		"type": "bossitem"
	},
	"relicdrone2": 
	{
		"icon": ICON_PATH + "relic_drone.png",
		"displayname": "item_relicdrone",
		"details": "ItemDesc_RelicDrone2",
		"level": "item_level2",
		"prerequisite": ["relicdrone1"],
		"type": "bossitem"
	}
}
