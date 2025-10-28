# Nihui Optimizer - Architecture du Système de Builds

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
   - [Principe Fondamental : Affichage depuis la Base de Données WoW](#-principe-fondamental--affichage-depuis-la-base-de-données-wow)
2. [Builds par Défaut](#builds-par-défaut)
3. [Application Desktop Tauri](#application-desktop-tauri)
4. [Structure des Fichiers](#structure-des-fichiers)
5. [Format des Builds](#format-des-builds)
6. [Système de Tabs In-Game](#système-de-tabs-in-game)
7. [Workflow Complet](#workflow-complet)
8. [Implémentation Technique](#implémentation-technique)

---

## 🎯 Vue d'ensemble

### Concept

Le système de builds repose sur **deux sources de données** :

1. **Builds par Défaut** : Packagés avec l'addon (1 build par spec)
2. **Builds Étendus** : Téléchargés et gérés via l'application desktop Tauri

```
┌─────────────────────────────────────────────────────────────┐
│                    NIHUI OPTIMIZER                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐      ┌──────────────────────┐     │
│  │  Builds par Défaut  │      │   Builds Étendus     │     │
│  │  (1 par spec)       │      │   (App Desktop)      │     │
│  │                     │      │                      │     │
│  │  • Leveling         │      │  • Recherche builds  │     │
│  │  • BIS Gear         │      │  • Scraping Maxroll  │     │
│  │  • Rotations        │      │  • 200+ builds       │     │
│  └─────────────────────┘      └──────────────────────┘     │
│           ↓                              ↓                  │
│  builds_default.lua           builds_extended.lua          │
│           └──────────────┬──────────────┘                  │
│                          ↓                                  │
│                  E.BuildDatabase                            │
│                          ↓                                  │
│              ┌───────────────────────┐                      │
│              │   UI Tabs In-Game     │                      │
│              │  • Overview           │                      │
│              │  • Leveling Guide     │                      │
│              │  • BIS Gear           │                      │
│              │  • Rotations          │                      │
│              │  • Stat Priorities    │                      │
│              └───────────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

### ⚡ Principe Fondamental : Affichage depuis la Base de Données WoW

**IMPORTANT** : Les builds affichés dans l'addon **ne sont PAS limités à l'équipement possédé** par le joueur.

#### Comment ça fonctionne ?

1. **Stockage des ItemIDs** : Chaque build contient des `itemID` (ex: `248410`)
2. **Récupération depuis WoW DB** : L'addon utilise `C_Item.GetItemInfo(itemID)` pour afficher les items
3. **Theorycrafting complet** : Le joueur peut **explorer tous les builds** même s'il ne possède aucun item
4. **Comparaison intelligente** : Le système compare l'équipement **actuellement équipé** avec les recommandations BIS

#### Exemple Concret

```lua
-- Build recommande HEAD = 248410 (Cowl of Branching Fate)
local bisItem = build.bestInSlot.HEAD

-- ✅ TOUJOURS AFFICHÉ (depuis WoW DB)
local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(bisItem.itemID)

-- 🔍 COMPARAISON avec équipement actuel
local equippedLocation = ItemLocation:CreateFromEquipmentSlot(INVSLOT_HEAD)
if C_Item.DoesItemExist(equippedLocation) then
    local equippedID = C_Item.GetItemID(equippedLocation)
    local equippedLevel = C_Item.GetCurrentItemLevel(equippedLocation)

    -- Affichage: "Recommandé: Cowl of Branching Fate (502) | Équipé: Autre Helm (489)"
end
```

#### Cas d'Usage

| Scénario | Comportement |
|----------|-------------|
| Joueur level 70 fresh | Voit tous les items BIS recommandés (aucun possédé) |
| Joueur avec 3/16 items BIS | Voit les 16 items, avec comparaison sur les 3 équipés |
| Joueur full BIS | Voit tous les items avec ✓ vert sur les slots parfaits |
| Joueur explore autre spec | Voit les items d'une spec non jouée (theorycrafting) |

#### Avantages

- ✅ **Exploration libre** : Découvrir tous les builds sans contrainte d'inventaire
- ✅ **Guide visuel** : Savoir exactement quoi farmer (source + boss)
- ✅ **Comparaison facile** : "Mon item actuel vs item recommandé"
- ✅ **Motivant** : Vision claire de la progression possible

---

## 📦 Builds par Défaut

### Objectif

Fournir **1 build complet par spécialisation** pour que l'addon soit **immédiatement fonctionnel** sans application externe.

### Contenu de Chaque Build

Chaque build par défaut contient :

#### 1. Guide de Leveling
- Talents recommandés par paliers (10, 20, 30, etc.)
- Équipement à rechercher par niveau
- Zones de farming recommandées
- Sorts clés à obtenir

#### 2. Best in Slot (BIS)
- Liste complète des items BIS par slot
- Alternatives farmables (M+, Craft, Réputation)
- Sources précises (Boss, Donjon, Raid)
- Bonus stats par item

#### 3. Rotations
- **Opener** : Séquence de démarrage optimale
- **Single Target** : Rotation DPS mono-cible
- **AoE** : Rotation pour plusieurs cibles
- **Priority List** : Liste de priorités dynamiques
- **Cooldowns** : Utilisation des CDs majeurs

#### 4. Stat Priorities
- Ordre de priorité des stats
- Caps importants (ex: 35% Hâte)
- Breakpoints à connaître
- Raisons de chaque priorité

#### 5. Notes & Tips
- Conseils de gameplay
- Macros utiles
- WeakAuras recommandées
- Erreurs communes à éviter

### Liste des Builds par Défaut

**Total : 39 builds** (13 classes × 3 specs en moyenne)

| Classe | Spécialisation | Build par Défaut |
|--------|---------------|------------------|
| **Death Knight** | Blood | Tank - All-Around |
| | Frost | DPS - Mythic+ |
| | Unholy | DPS - Raid |
| **Demon Hunter** | Havoc | DPS - Mythic+ |
| | Vengeance | Tank - All-Around |
| **Druid** | Balance | DPS - Raid |
| | Feral | DPS - Mythic+ |
| | Guardian | Tank - All-Around |
| | Restoration | Heal - Raid |
| **Evoker** | Devastation | DPS - Raid |
| | Preservation | Heal - Mythic+ |
| | Augmentation | Support - All-Around |
| **Hunter** | Beast Mastery | DPS - All-Around |
| | Marksmanship | DPS - Raid |
| | Survival | DPS - Mythic+ |
| **Mage** | Arcane | DPS - Raid |
| | Fire | DPS - Mythic+ |
| | Frost | DPS - Leveling |
| **Monk** | Brewmaster | Tank - All-Around |
| | Mistweaver | Heal - Raid |
| | Windwalker | DPS - Mythic+ |
| **Paladin** | Holy | Heal - Raid |
| | Protection | Tank - All-Around |
| | Retribution | DPS - Mythic+ |
| **Priest** | Discipline | Heal - Raid |
| | Holy | Heal - Mythic+ |
| | Shadow | DPS - Raid |
| **Rogue** | Assassination | DPS - Raid |
| | Outlaw | DPS - Mythic+ |
| | Subtlety | DPS - PvP |
| **Shaman** | Elemental | DPS - Raid |
| | Enhancement | DPS - Mythic+ |
| | Restoration | Heal - Raid |
| **Warlock** | Affliction | DPS - Raid |
| | Demonology | DPS - Mythic+ |
| | Destruction | DPS - All-Around |
| **Warrior** | Arms | DPS - PvP |
| | Fury | DPS - Raid |
| | Protection | Tank - All-Around |

---

## 🖥️ Application Desktop Tauri

### Technologies

- **Framework** : Tauri (Rust)
- **Frontend** : Vue.js 3 + TypeScript
- **UI Library** : Vuetify / PrimeVue
- **HTTP Client** : reqwest (Rust)
- **HTML Parser** : scraper (Rust)
- **État** : Pinia (Vue)

### Fonctionnalités

#### 1. Détection Automatique de WoW

```rust
// src-tauri/src/wow_detector.rs
use std::path::PathBuf;

pub fn detect_wow_installation() -> Option<PathBuf> {
    let common_paths = vec![
        "C:/Program Files (x86)/World of Warcraft/_retail_",
        "C:/Program Files/World of Warcraft/_retail_",
        "D:/Games/World of Warcraft/_retail_",
        "E:/Battle.net/World of Warcraft/_retail_",
    ];

    for path in common_paths {
        let wow_path = PathBuf::from(path);
        if wow_path.exists() {
            return Some(wow_path);
        }
    }

    None
}

pub fn get_addon_path(wow_path: &PathBuf) -> PathBuf {
    wow_path.join("Interface/AddOns/Nihui_Optimizer")
}
```

#### 2. Scraper Maxroll.gg

```rust
// src-tauri/src/scraper/maxroll.rs
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Build {
    pub name: String,
    pub class: String,
    pub spec: String,
    pub source: String,
    pub source_url: String,
    pub last_update: String,
    pub season: String,
    pub activity_type: String,
    pub stat_priorities: StatPriorities,
    pub best_in_slot: BestInSlot,
    pub rotation: Rotation,
    pub talents: String,
}

pub async fn scrape_build(url: &str) -> Result<Build, Box<dyn std::error::Error>> {
    let response = reqwest::get(url).await?;
    let html = response.text().await?;
    let document = Html::parse_document(&html);

    // Extract title
    let title_selector = Selector::parse("h1").unwrap();
    let title = document.select(&title_selector)
        .next()
        .map(|el| el.text().collect::<String>())
        .unwrap_or_default();

    // Extract last update
    let update_selector = Selector::parse("time").unwrap();
    let last_update = document.select(&update_selector)
        .next()
        .and_then(|el| el.value().attr("datetime"))
        .unwrap_or("")
        .to_string();

    // Extract BIS items
    let item_selector = Selector::parse("a[data-wowhead-item]").unwrap();
    let mut bis_items = Vec::new();

    for item in document.select(&item_selector) {
        let item_data = item.value().attr("data-wowhead-item").unwrap_or("");
        let item_id = item_data.split(':').next().unwrap_or("");
        let item_name = item.text().collect::<String>();

        bis_items.push(BisItem {
            item_id: item_id.parse().unwrap_or(0),
            item_name,
            bonuses: item_data.to_string(),
        });
    }

    // Extract stat priorities
    let stat_priorities = extract_stat_priorities(&document)?;

    // Extract rotation
    let rotation = extract_rotation(&document)?;

    Ok(Build {
        name: title,
        class: extract_class_from_url(url),
        spec: extract_spec_from_url(url),
        source: "Maxroll.gg".to_string(),
        source_url: url.to_string(),
        last_update,
        season: "The War Within S3".to_string(),
        activity_type: extract_activity_type(url),
        stat_priorities,
        best_in_slot: BestInSlot { items: bis_items },
        rotation,
        talents: extract_talents(&document).unwrap_or_default(),
    })
}
```

#### 3. Convertisseur JSON → Lua

```rust
// src-tauri/src/lua_generator.rs
use crate::scraper::Build;

pub fn build_to_lua(build: &Build) -> String {
    format!(
        r#"table.insert(ns.E.BuildDatabase, {{
    name = "{}",
    class = "{}",
    spec = "{}",
    source = "{}",
    sourceURL = "{}",
    lastUpdate = "{}",
    season = "{}",
    activityType = "{}",

    statPriorities = {},

    bestInSlot = {},

    rotation = {},

    talents = "{}",

    leveling = {},
}})"#,
        build.name,
        build.class,
        build.spec,
        build.source,
        build.source_url,
        build.last_update,
        build.season,
        build.activity_type,
        stat_priorities_to_lua(&build.stat_priorities),
        bis_to_lua(&build.best_in_slot),
        rotation_to_lua(&build.rotation),
        build.talents,
        leveling_to_lua(&build.leveling),
    )
}

fn stat_priorities_to_lua(stats: &StatPriorities) -> String {
    format!(
        r#"{{
        intellect = {{priority = 1}},
        haste = {{priority = 2, target = {}, reason = "{}"}},
        mastery = {{priority = 3, target = {}}},
        crit = {{priority = 4}},
        versatility = {{priority = 5}},
    }}"#,
        stats.haste.target.unwrap_or(0.0),
        stats.haste.reason,
        stats.mastery.target.unwrap_or(0.0),
    )
}

fn bis_to_lua(bis: &BestInSlot) -> String {
    let mut lua = String::from("{\n");

    for item in &bis.items {
        lua.push_str(&format!(
            r#"        ["{}"] = {{
            itemID = {},
            itemName = "{}",
            bonuses = "{}",
            source = "{}",
        }},
"#,
            item.slot,
            item.item_id,
            item.item_name,
            item.bonuses,
            item.source,
        ));
    }

    lua.push_str("    }");
    lua
}
```

#### 4. Interface Vue.js

**Structure de l'App:**

```
src/
├── components/
│   ├── WowPathSelector.vue      # Sélection du dossier WoW
│   ├── BuildSearch.vue          # Recherche de builds
│   ├── BuildList.vue            # Liste des builds trouvés
│   ├── BuildPreview.vue         # Aperçu d'un build
│   └── SyncStatus.vue           # Statut de synchronisation
├── views/
│   ├── Home.vue                 # Page d'accueil
│   ├── Search.vue               # Page de recherche
│   └── Settings.vue             # Paramètres
├── stores/
│   ├── builds.ts                # État des builds
│   └── settings.ts              # Paramètres de l'app
└── services/
    ├── tauri.ts                 # Interface avec Rust
    └── lua-writer.ts            # Écriture des fichiers .lua
```

**Exemple de Composant (BuildSearch.vue):**

```vue
<template>
  <v-container>
    <v-card>
      <v-card-title>
        Rechercher des Builds
      </v-card-title>

      <v-card-text>
        <v-row>
          <v-col cols="4">
            <v-select
              v-model="filters.class"
              :items="classes"
              label="Classe"
              clearable
            />
          </v-col>

          <v-col cols="4">
            <v-select
              v-model="filters.spec"
              :items="specs"
              label="Spécialisation"
              clearable
            />
          </v-col>

          <v-col cols="4">
            <v-select
              v-model="filters.activity"
              :items="activities"
              label="Activité"
              clearable
            />
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="12">
            <v-text-field
              v-model="filters.search"
              label="Recherche libre"
              prepend-icon="mdi-magnify"
              clearable
            />
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="12">
            <v-btn
              color="primary"
              block
              :loading="searching"
              @click="searchBuilds"
            >
              <v-icon left>mdi-cloud-search</v-icon>
              Rechercher
            </v-btn>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- Résultats -->
    <v-card v-if="results.length > 0" class="mt-4">
      <v-card-title>
        {{ results.length }} builds trouvés
      </v-card-title>

      <v-card-text>
        <build-list
          :builds="results"
          @select="previewBuild"
          @add="addBuild"
        />
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { invoke } from '@tauri-apps/api/tauri'
import { useBuildsStore } from '@/stores/builds'

const buildsStore = useBuildsStore()

const filters = ref({
  class: null,
  spec: null,
  activity: null,
  search: '',
})

const searching = ref(false)
const results = ref([])

const classes = ['WARLOCK', 'MAGE', 'WARRIOR', /* ... */]
const activities = ['Raid', 'Mythic+', 'PvP', 'Leveling']

const specs = computed(() => {
  if (!filters.value.class) return []
  // Retourner les specs de la classe sélectionnée
  return getSpecsForClass(filters.value.class)
})

async function searchBuilds() {
  searching.value = true

  try {
    // Appel au backend Rust
    results.value = await invoke('search_builds', {
      filters: filters.value
    })
  } catch (error) {
    console.error('Erreur de recherche:', error)
  } finally {
    searching.value = false
  }
}

async function addBuild(build) {
  await buildsStore.addBuild(build)
  // Mettre à jour le fichier builds_extended.lua
  await invoke('write_builds_file')
}
</script>
```

---

## 📁 Structure des Fichiers

```
Nihui_Optimizer/
├── data/
│   └── builds/
│       ├── builds_default.lua       # Builds packagés (1 par spec)
│       └── builds_extended.lua      # Builds téléchargés (géré par app)
├── core/
│   └── build_manager.lua            # Gestionnaire de builds
├── ui/
│   └── tabs/
│       ├── build_overview.lua       # Tab: Vue d'ensemble
│       ├── build_leveling.lua       # Tab: Guide leveling
│       ├── build_bis.lua            # Tab: Best in Slot
│       ├── build_rotation.lua       # Tab: Rotations
│       └── build_stats.lua          # Tab: Stat Priorities
└── Nihui_Optimizer.toc
```

### builds_default.lua

**Contenu:**

```lua
local _, ns = ...
ns.E = ns.E or {}
ns.E.BuildsDefault = {}

-- Build 1: Warlock Destruction
table.insert(ns.E.BuildsDefault, {
    name = "Warlock Destruction - All-Around",
    class = "WARLOCK",
    spec = "Destruction",
    source = "Nihui Optimizer (Inclus)",
    sourceURL = "https://nihui-optimizer.com/builds/warlock-destruction",
    lastUpdate = "2025-10-25",
    season = "The War Within S3",
    activityType = "All-Around",

    -- Leveling Guide
    leveling = {
        talents = {
            {level = 10, talent = "Fel Domination", reason = "Instant summon"},
            {level = 15, talent = "Mortal Coil", reason = "Self-heal + CC"},
            {level = 25, talent = "Burning Rush", reason = "Mobility"},
            -- ...
        },

        gearPriorities = {
            {level = "1-20", priority = "Intellect > Stamina"},
            {level = "20-40", priority = "Intellect > Haste > Mastery"},
            {level = "40-60", priority = "Intellect > Haste > Crit > Mastery"},
            {level = "60-70", priority = "Intellect > Haste (35%) > Mastery > Crit"},
        },

        zones = {
            {level = "1-10", zone = "Starting Zone"},
            {level = "10-20", zone = "Exile's Reach → Dragonflight Intro"},
            {level = "20-60", zone = "Dragonflight Campaign"},
            {level = "60-70", zone = "The War Within Campaign"},
        },

        tips = {
            "Toujours avoir Immolate actif sur la cible",
            "Utiliser Conflagrate pour générer Soul Shards",
            "Chaos Bolt quand 2+ Soul Shards disponibles",
            "Rain of Fire pour AoE (3+ cibles)",
        },
    },

    -- Best in Slot
    bestInSlot = {
        HEAD = {
            itemID = 248410,
            itemName = "Cowl of Branching Fate",
            bonuses = "1:10:3524",
            source = "Nerub-ar Palace - Sikran (Boss 3)",
        },
        NECK = {
            itemID = 225577,
            itemName = "Sureki Zealot's Insignia",
            bonuses = "1:10:3524",
            source = "Nerub-ar Palace - Ulgrax (Boss 1)",
        },
        -- ... tous les slots
    },

    farmableAlternatives = {
        HEAD = {
            {
                itemID = 221163,
                itemName = "Visor of the Ascended Captain",
                source = "The Dawnbreaker (M+)",
                quality = "near-bis",
                itemLevel = 489,
            },
            {
                itemID = 212072,
                itemName = "Crafted Helm",
                source = "Tailoring Craft",
                quality = "good",
                itemLevel = 486,
            },
        },
        -- ...
    },

    -- Stat Priorities
    statPriorities = {
        intellect = {
            priority = 1,
            target = nil,
            reason = "Primary stat, toujours #1",
        },
        haste = {
            priority = 2,
            target = 35.0,
            reason = "Soft cap à 35% pour GCD optimal (1.5s → 1.0s)",
        },
        mastery = {
            priority = 3,
            target = 28.0,
            reason = "Augmente les dégâts Chaos (Chaos Bolt, Incinerate)",
        },
        crit = {
            priority = 4,
            target = nil,
            reason = "Dégâts critiques, synergize avec talents",
        },
        versatility = {
            priority = 5,
            target = nil,
            reason = "Stat équilibrée, moins prioritaire",
        },
    },

    -- Rotations
    rotation = {
        opener = {
            {
                spellID = 17877,
                spellName = "Shadowburn",
                icon = 136191,
                note = "Pré-cast avant pull",
            },
            {
                spellID = 348,
                spellName = "Immolate",
                icon = 135817,
                note = "DoT initial",
            },
            {
                spellID = 17962,
                spellName = "Conflagrate",
                icon = 135807,
                note = "Générer Soul Shards",
            },
            {
                spellID = 116858,
                spellName = "Chaos Bolt",
                icon = 136211,
                note = "Gros dégâts",
            },
            -- ...
        },

        singleTarget = {
            priority = {
                {
                    spellID = 348,
                    spellName = "Immolate",
                    condition = "Si absent ou <3s restants",
                },
                {
                    spellID = 17962,
                    spellName = "Conflagrate",
                    condition = "Si 2 charges ou <30% rechargé",
                },
                {
                    spellID = 116858,
                    spellName = "Chaos Bolt",
                    condition = "Si 4-5 Soul Shards",
                },
                {
                    spellID = 29722,
                    spellName = "Incinerate",
                    condition = "Filler",
                },
            },
        },

        aoe = {
            threshold = 3, -- Nombre de cibles pour switch
            priority = {
                {
                    spellID = 5740,
                    spellName = "Rain of Fire",
                    condition = "Si 3+ cibles groupées",
                },
                {
                    spellID = 152108,
                    spellName = "Cataclysm",
                    condition = "CD disponible sur 3+ cibles",
                },
                {
                    spellID = 348,
                    spellName = "Immolate",
                    condition = "Spread sur toutes les cibles",
                },
                {
                    spellID = 29722,
                    spellName = "Incinerate",
                    condition = "Filler",
                },
            },
        },

        cooldowns = {
            {
                spellID = 113858,
                spellName = "Dark Soul: Instability",
                usage = "Sur burst phase ou boss fight",
                note = "Utiliser avec 5 Soul Shards prêts pour Chaos Bolt spam",
            },
            {
                spellID = 1122,
                spellName = "Summon Infernal",
                usage = "Sur pull + bloodlust / burst windows",
                note = "Aligner avec Dark Soul si possible",
            },
        },
    },

    -- Talents
    talents = "BQEAAAAAAAAAAAAAAAAAAAAAAskEJJRSkkkkQSIRAAAAAAIJRSaRSSSSIikE",

    -- Notes & Tips
    notes = {
        gameplay = {
            "Prioriser la génération de Soul Shards avec Conflagrate",
            "Ne jamais capper à 5 Soul Shards (perte de génération)",
            "Maintenir Immolate actif en permanence",
            "Chaos Bolt fait plus de dégâts que 2x Incinerate",
        },

        macros = {
            {
                name = "Chaos Bolt + Mouseover Focus",
                macro = [[
#showtooltip Chaos Bolt
/cast [@mouseover,harm,nodead][@focus,harm,nodead][] Chaos Bolt
                ]],
            },
            {
                name = "Healthstone + Auto Create",
                macro = [[
#showtooltip
/use Healthstone
/cast [nochanneling] Create Healthstone
                ]],
            },
        },

        weakauras = {
            "Luxthos - Warlock WeakAuras (wago.io/HJxL_fG7b)",
            "Soul Shard Tracker",
            "Immolate Duration Tracker",
        },

        commonMistakes = {
            "❌ Oublier de maintenir Immolate → Perte DPS majeure",
            "❌ Utiliser Chaos Bolt avec 1-2 Soul Shards → Inefficace",
            "❌ Ne pas utiliser Conflagrate à recharge → Perte de génération",
            "❌ Capper Soul Shards → Waste de ressources",
        },
    },
})

-- Build 2: Warlock Demonology
-- ...

-- Build 3: Warlock Affliction
-- ...

-- (39 builds au total)
```

### builds_extended.lua

**Fichier vide par défaut (pour éviter les crashes):**

```lua
-- builds_extended.lua
-- Ce fichier est géré par l'application Nihui Optimizer Desktop
-- NE PAS MODIFIER MANUELLEMENT

local _, ns = ...
ns.E = ns.E or {}
ns.E.BuildsExtended = {}

-- Les builds seront ajoutés ici par l'application desktop
-- Format identique à builds_default.lua

-- Exemple (une fois rempli par l'app):
--[[
table.insert(ns.E.BuildsExtended, {
    name = "Destruction Warlock - Raid Mythique (Icy Veins)",
    class = "WARLOCK",
    spec = "Destruction",
    source = "Maxroll.gg",
    sourceURL = "https://maxroll.gg/...",
    -- ...
})
]]
```

**Après synchronisation avec l'app, ce fichier sera rempli:**

```lua
local _, ns = ...
ns.E = ns.E or {}
ns.E.BuildsExtended = {}

-- AUTO-GENERATED by Nihui Optimizer Desktop v1.0.0
-- Last sync: 2025-10-25 14:32:01
-- Total builds: 47

table.insert(ns.E.BuildsExtended, {
    name = "Destruction Warlock - Raid Mythique (Maxroll)",
    class = "WARLOCK",
    spec = "Destruction",
    -- ... contenu complet
})

table.insert(ns.E.BuildsExtended, {
    name = "Destruction Warlock - M+ Clés 20+ (Maxroll)",
    -- ...
})

-- ... 45 autres builds
```

---

## 🎨 Système de Tabs In-Game

### Concept

Chaque build affiché dans l'addon dispose de **5 tabs** pour organiser l'information:

```
┌──────────────────────────────────────────────────────────────┐
│  DESTRUCTION WARLOCK - ALL-AROUND                            │
├──────────────────────────────────────────────────────────────┤
│  [Overview] [Leveling] [BIS Gear] [Rotations] [Stats]       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  (Contenu de la tab sélectionnée)                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Tab 1: Overview

**Contenu:**
- Nom du build
- Source (Maxroll, Icy Veins, Nihui Default, etc.)
- Dernière mise à jour
- Saison (The War Within S3)
- Type d'activité (Raid, M+, PvP, All-Around, Leveling)
- Description courte
- Lien vers la source
- Notes importantes

**Layout:**

```
┌────────────────────────────────────────────────────────┐
│  📋 OVERVIEW                                           │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Destruction Warlock - All-Around                     │
│  Source: Nihui Optimizer (Inclus)                     │
│  Mise à jour: 25 octobre 2025                         │
│  Saison: The War Within S3                            │
│                                                        │
│  ─────────────────────────────────────────────────    │
│                                                        │
│  📝 Description                                        │
│  Build polyvalent pour Raid et M+. Focus sur la      │
│  génération de Soul Shards et l'utilisation           │
│  optimale de Chaos Bolt.                              │
│                                                        │
│  🎯 Recommandé pour:                                   │
│  • Joueurs débutants                                  │
│  • Progression Raid Normal/Héroïque                   │
│  • M+ jusqu'à clé +15                                 │
│                                                        │
│  💡 Notes Importantes                                  │
│  • Maintenir Immolate actif en permanence            │
│  • Ne jamais capper à 5 Soul Shards                   │
│  • Prioriser Hâte jusqu'à 35%                         │
│                                                        │
│  🔗 Source: nihui-optimizer.com/builds/...            │
└────────────────────────────────────────────────────────┘
```

### Tab 2: Leveling

**Contenu:**
- Talents par paliers (10, 15, 20, etc.)
- Priorités de stats par tranche de niveau
- Zones recommandées
- Conseils de gameplay
- Équipement à rechercher

**Layout:**

```
┌────────────────────────────────────────────────────────┐
│  🌱 LEVELING GUIDE                                     │
├────────────────────────────────────────────────────────┤
│                                                        │
│  📚 Talents Recommandés                                │
│  ┌──────────────────────────────────────────────┐     │
│  │ Niveau 10: Fel Domination                    │     │
│  │   → Invocation instantanée du démon          │     │
│  │                                               │     │
│  │ Niveau 15: Mortal Coil                       │     │
│  │   → Self-heal + CC                           │     │
│  │                                               │     │
│  │ Niveau 25: Burning Rush                      │     │
│  │   → Mobilité accrue                          │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  ⚔️ Priorités de Stats                                 │
│  • 1-20:   Intellect > Stamina                        │
│  • 20-40:  Intellect > Haste > Mastery                │
│  • 40-60:  Intellect > Haste > Crit > Mastery         │
│  • 60-70:  Intellect > Haste (35%) > Mastery > Crit   │
│                                                        │
│  🗺️ Zones Recommandées                                 │
│  • 1-10:   Starting Zone                              │
│  • 10-20:  Exile's Reach → Dragonflight Intro         │
│  • 20-60:  Dragonflight Campaign                      │
│  • 60-70:  The War Within Campaign                    │
│                                                        │
│  💡 Conseils de Gameplay                               │
│  ✓ Maintenir Immolate actif                          │
│  ✓ Spam Conflagrate pour Soul Shards                 │
│  ✓ Chaos Bolt avec 2+ Soul Shards                    │
│  ✓ Rain of Fire pour 3+ ennemis                      │
└────────────────────────────────────────────────────────┘
```

### Tab 3: BIS Gear

**Contenu:**
- Liste complète des items Best in Slot par slot
- Alternatives farmables (M+, Craft, Réputation)
- Sources précises (Boss, Donjon, Raid)
- Preview de l'item au survol
- Bouton "Trouver des alternatives"

**Layout:**

```
┌────────────────────────────────────────────────────────┐
│  👑 BEST IN SLOT GEAR                                  │
├────────────────────────────────────────────────────────┤
│                                                        │
│  [🎩] HEAD                                             │
│  ┌────────────────────────────────────────────┐       │
│  │ [Icon] Cowl of Branching Fate               │       │
│  │        Item Level: 502                      │       │
│  │        Stats: +450 Int, +320 Haste, +280 Mast│      │
│  │        📍 Nerub-ar Palace - Sikran (Boss 3) │       │
│  │        [Alternatives ▼]                     │       │
│  └────────────────────────────────────────────┘       │
│                                                        │
│  [📿] NECK                                             │
│  ┌────────────────────────────────────────────┐       │
│  │ [Icon] Sureki Zealot's Insignia             │       │
│  │        Item Level: 499                      │       │
│  │        Stats: +380 Int, +290 Haste, +250 Vers│      │
│  │        📍 Nerub-ar Palace - Ulgrax (Boss 1) │       │
│  │        [Alternatives ▼]                     │       │
│  └────────────────────────────────────────────┘       │
│                                                        │
│  ... (tous les autres slots)                          │
│                                                        │
│  ─────────────────────────────────────────────────    │
│                                                        │
│  📊 Résumé des Stats (Équipement Complet)             │
│  Intellect:     15,234                                │
│  Haste:         3,892  (34.2%)                        │
│  Mastery:       3,124  (27.8%)                        │
│  Crit:          2,456  (21.3%)                        │
│  Versatility:   1,234  (8.9%)                         │
└────────────────────────────────────────────────────────┘
```

**Alternatives (dépliant):**

```
│  [🎩] HEAD                                             │
│  ┌────────────────────────────────────────────┐       │
│  │ ✓ Cowl of Branching Fate (BIS)             │       │
│  │                                             │       │
│  │ Alternatives:                               │       │
│  │ ┌─────────────────────────────────────┐    │       │
│  │ │ ⭐ Visor of the Ascended Captain    │    │       │
│  │ │    ilvl 489 | Near-BIS              │    │       │
│  │ │    📍 The Dawnbreaker (M+)          │    │       │
│  │ │    Stats: +420 Int, +310 Haste      │    │       │
│  │ └─────────────────────────────────────┘    │       │
│  │ ┌─────────────────────────────────────┐    │       │
│  │ │ ⚡ Crafted Hood of Insight          │    │       │
│  │ │    ilvl 486 | Good                  │    │       │
│  │ │    📍 Tailoring Craft               │    │       │
│  │ │    Stats: +400 Int, +295 Haste      │    │       │
│  │ └─────────────────────────────────────┘    │       │
│  └────────────────────────────────────────────┘       │
```

### Tab 4: Rotations

**Contenu:**
- Opener (séquence d'ouverture)
- Rotation Single Target (priorités)
- Rotation AoE (3+ cibles)
- Utilisation des Cooldowns
- Icônes des sorts
- Notes et tips

**Layout:**

```
┌────────────────────────────────────────────────────────┐
│  ⚔️ ROTATIONS                                          │
├────────────────────────────────────────────────────────┤
│                                                        │
│  🎯 OPENER (Séquence d'Ouverture)                     │
│  ┌────────────────────────────────────────────┐       │
│  │  -3s  [Icon] Shadowburn  (Pré-cast)        │       │
│  │  -1s  [Icon] Potion of Power               │       │
│  │   0s  [Icon] Immolate  (DoT initial)       │       │
│  │   1s  [Icon] Conflagrate  (Soul Shards)    │       │
│  │   2s  [Icon] Chaos Bolt  (Gros dégâts)     │       │
│  │   3s  [Icon] Conflagrate  (si 2 charges)   │       │
│  │   4s  [Icon] Chaos Bolt                    │       │
│  └────────────────────────────────────────────┘       │
│                                                        │
│  🎯 SINGLE TARGET (Rotation Principale)               │
│  ┌────────────────────────────────────────────┐       │
│  │  1. [Icon] Immolate                        │       │
│  │     Si absent ou <3s restants              │       │
│  │                                             │       │
│  │  2. [Icon] Conflagrate                     │       │
│  │     Si 2 charges OU <30% rechargé          │       │
│  │                                             │       │
│  │  3. [Icon] Chaos Bolt                      │       │
│  │     Si 4-5 Soul Shards                     │       │
│  │                                             │       │
│  │  4. [Icon] Incinerate                      │       │
│  │     Filler (génère Soul Shards)            │       │
│  └────────────────────────────────────────────┘       │
│                                                        │
│  🔥 AOE (3+ Cibles)                                   │
│  ┌────────────────────────────────────────────┐       │
│  │  1. [Icon] Rain of Fire                    │       │
│  │     Si 3+ cibles groupées                  │       │
│  │                                             │       │
│  │  2. [Icon] Cataclysm                       │       │
│  │     CD disponible sur 3+ cibles            │       │
│  │                                             │       │
│  │  3. [Icon] Immolate                        │       │
│  │     Spread sur toutes les cibles           │       │
│  │                                             │       │
│  │  4. [Icon] Incinerate                      │       │
│  │     Filler                                 │       │
│  └────────────────────────────────────────────┘       │
│                                                        │
│  ⏰ COOLDOWNS                                          │
│  ┌────────────────────────────────────────────┐       │
│  │  [Icon] Dark Soul: Instability             │       │
│  │  • Utiliser sur burst phase                │       │
│  │  • Avoir 5 Soul Shards prêts               │       │
│  │  • Spam Chaos Bolt pendant le buff         │       │
│  │                                             │       │
│  │  [Icon] Summon Infernal                    │       │
│  │  • Sur pull + bloodlust                    │       │
│  │  • Aligner avec Dark Soul si possible      │       │
│  └────────────────────────────────────────────┘       │
└────────────────────────────────────────────────────────┘
```

### Tab 5: Stats

**Contenu:**
- Priorités de stats (ordre + raisons)
- Caps importants
- Breakpoints
- Comparaison stats actuelles vs objectifs
- Barres de progression

**Layout:**

```
┌────────────────────────────────────────────────────────┐
│  📊 STAT PRIORITIES                                    │
├────────────────────────────────────────────────────────┤
│                                                        │
│  🎯 Ordre de Priorité                                  │
│  ┌────────────────────────────────────────────┐       │
│  │  1. Intellect (Primary Stat)               │       │
│  │     → Toujours #1, jamais compromis        │       │
│  │                                             │       │
│  │  2. Haste (TARGET: 35%)                    │       │
│  │     → Soft cap pour GCD optimal            │       │
│  │     → 1.5s GCD → 1.0s avec 35% Hâte        │       │
│  │     📊 Actuel: 3,892 (34.2%) ▓▓▓▓▓▓▓▓░░    │       │
│  │        Manque: 89 rating (0.8%)            │       │
│  │                                             │       │
│  │  3. Mastery (TARGET: 28%)                  │       │
│  │     → Augmente dégâts Chaos (CB, Incin)    │       │
│  │     📊 Actuel: 3,124 (27.8%) ▓▓▓▓▓▓▓▓▓░    │       │
│  │        Manque: 24 rating (0.2%)            │       │
│  │                                             │       │
│  │  4. Critical Strike                        │       │
│  │     → Dégâts critiques                     │       │
│  │     → Synergize avec talents               │       │
│  │     📊 Actuel: 2,456 (21.3%)               │       │
│  │                                             │       │
│  │  5. Versatility                            │       │
│  │     → Stat équilibrée mais moins forte     │       │
│  │     → Prendre si aucune alternative        │       │
│  │     📊 Actuel: 1,234 (8.9%)                │       │
│  └────────────────────────────────────────────┘       │
│                                                        │
│  ⚡ Breakpoints Importants                             │
│  • 35% Haste = GCD optimal (1.0s)                     │
│  • 28% Mastery = Point d'équilibre DPS                │
│  • 20% Crit = Baseline minimum                        │
│                                                        │
│  💡 Tips                                               │
│  • Prioriser Hâte jusqu'à 35% avant tout             │
│  • Ne PAS sacrifier ilvl pour stats (>10 ilvl gap)   │
│  • Gemmes: Hâte si <35%, sinon Mastery               │
│  • Enchants: Toujours Hâte sur les pièces majeures   │
└────────────────────────────────────────────────────────┘
```

---

## 🔄 Workflow Complet

### Scénario 1: Utilisateur Basique (Builds par Défaut)

```
1. Joueur installe Nihui Optimizer
   ↓
2. Addon charge automatiquement builds_default.lua
   ↓
3. 39 builds disponibles immédiatement (1 par spec)
   ↓
4. Joueur sélectionne "Warlock Destruction - All-Around"
   ↓
5. Affichage des 5 tabs:
   - Overview
   - Leveling Guide
   - BIS Gear
   - Rotations
   - Stat Priorities
   ↓
6. Joueur suit les recommandations in-game
```

### Scénario 2: Utilisateur Avancé (App Desktop)

```
1. Joueur installe Nihui Optimizer + App Desktop
   ↓
2. App détecte automatiquement le dossier WoW
   ↓
3. App affiche interface de recherche
   ↓
4. Joueur recherche:
   - Classe: Warlock
   - Spec: Destruction
   - Activité: Mythic+ Clés 20+
   ↓
5. App scrape Maxroll.gg en temps réel
   ↓
6. Affiche 5 builds trouvés:
   - Destruction M+ High Keys (Maxroll)
   - Destruction M+ Speed Run (Icy Veins)
   - Destruction M+ AoE Focus (Wowhead)
   - etc.
   ↓
7. Joueur preview et sélectionne 2 builds
   ↓
8. Clic sur "Ajouter à l'addon"
   ↓
9. App télécharge les builds complets
   ↓
10. App convertit JSON → Lua
   ↓
11. App écrit dans builds_extended.lua:
    Interface/AddOns/Nihui_Optimizer/data/builds/builds_extended.lua
   ↓
12. Joueur relance WoW (ou /reload)
   ↓
13. Addon détecte builds_extended.lua
   ↓
14. 39 + 2 = 41 builds disponibles
   ↓
15. Les 2 nouveaux builds marqués "Source: Maxroll.gg"
```

### Scénario 3: Mise à Jour des Builds

```
1. Nouveau patch WoW (meta change)
   ↓
2. App Desktop affiche notification:
   "Mise à jour disponible: 12 builds modifiés"
   ↓
3. Joueur clique "Mettre à jour"
   ↓
4. App re-scrape les builds existants
   ↓
5. Compare avec versions locales
   ↓
6. Affiche les changements:
   - Stats priorities modifiées
   - Nouveaux items BIS
   - Rotations ajustées
   ↓
7. Joueur valide la mise à jour
   ↓
8. App réécrit builds_extended.lua
   ↓
9. /reload in-game
   ↓
10. Builds à jour!
```

---

## 🛠️ Implémentation Technique

### Backend Rust (Tauri)

**Commandes exposées à Vue.js:**

```rust
// src-tauri/src/main.rs
use tauri::command;

#[command]
async fn detect_wow_path() -> Result<String, String> {
    match wow_detector::detect_wow_installation() {
        Some(path) => Ok(path.to_string_lossy().to_string()),
        None => Err("Installation WoW non trouvée".to_string()),
    }
}

#[command]
async fn search_builds(filters: BuildFilters) -> Result<Vec<Build>, String> {
    let results = scraper::search_maxroll(&filters).await?;
    Ok(results)
}

#[command]
async fn download_build(url: String) -> Result<Build, String> {
    let build = scraper::scrape_build(&url).await?;
    Ok(build)
}

#[command]
async fn save_builds_to_addon(builds: Vec<Build>, wow_path: String) -> Result<(), String> {
    let addon_path = PathBuf::from(wow_path)
        .join("Interface/AddOns/Nihui_Optimizer/data/builds/builds_extended.lua");

    let lua_content = lua_generator::builds_to_lua(&builds);

    fs::write(addon_path, lua_content)
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[command]
async fn get_local_builds(wow_path: String) -> Result<Vec<Build>, String> {
    // Lire et parser builds_extended.lua pour afficher dans l'UI
    let file_path = PathBuf::from(wow_path)
        .join("Interface/AddOns/Nihui_Optimizer/data/builds/builds_extended.lua");

    if !file_path.exists() {
        return Ok(vec![]);
    }

    let content = fs::read_to_string(file_path)
        .map_err(|e| e.to_string())?;

    // Parser le Lua (basique, chercher les patterns)
    let builds = lua_parser::parse_builds(&content)?;

    Ok(builds)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            detect_wow_path,
            search_builds,
            download_build,
            save_builds_to_addon,
            get_local_builds,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### Addon WoW (Lua)

**Build Manager:**

```lua
-- core/build_manager.lua
E.BuildManager = {
    builds = {},
    currentBuild = nil,
    currentTab = "overview",
}

function E.BuildManager:Initialize()
    -- Charger les builds par défaut
    if E.BuildsDefault then
        for _, build in ipairs(E.BuildsDefault) do
            build.type = "default"
            table.insert(self.builds, build)
        end

        print(string.format(
            "|cff00ff00[Nihui Optimizer]|r %d builds par défaut chargés",
            #E.BuildsDefault
        ))
    end

    -- Charger les builds étendus (si présents)
    if E.BuildsExtended then
        for _, build in ipairs(E.BuildsExtended) do
            build.type = "extended"

            -- Vérifier si ce build existe déjà dans les defaults
            local exists = false
            for i, defaultBuild in ipairs(self.builds) do
                if defaultBuild.name == build.name then
                    -- Remplacer par la version étendue (plus à jour)
                    self.builds[i] = build
                    exists = true
                    break
                end
            end

            if not exists then
                table.insert(self.builds, build)
            end
        end

        print(string.format(
            "|cff00ff00[Nihui Optimizer]|r +%d builds étendus chargés via app desktop",
            #E.BuildsExtended
        ))
    else
        print("|cffff9900[Nihui Optimizer]|r Aucun build étendu trouvé")
        print("💡 Installez Nihui Optimizer Desktop pour 200+ builds")
    end

    print(string.format(
        "|cff00ff00[Nihui Optimizer]|r Total: %d builds disponibles",
        #self.builds
    ))
end

function E.BuildManager:GetBuildsForClass(class, spec)
    local filtered = {}

    for _, build in ipairs(self.builds) do
        if build.class == class then
            if not spec or build.spec == spec then
                table.insert(filtered, build)
            end
        end
    end

    -- Trier par type d'activité puis source
    table.sort(filtered, function(a, b)
        if a.activityType == b.activityType then
            -- Builds par défaut en premier
            if a.type == "default" and b.type ~= "default" then
                return true
            elseif a.type ~= "default" and b.type == "default" then
                return false
            end
            return a.name < b.name
        end
        return a.activityType < b.activityType
    end)

    return filtered
end

function E.BuildManager:SelectBuild(build)
    self.currentBuild = build
    self.currentTab = "overview"

    -- Rafraîchir l'UI
    if E.BuildUI then
        E.BuildUI:Update()
    end
end

function E.BuildManager:SelectTab(tabName)
    self.currentTab = tabName

    -- Rafraîchir l'UI
    if E.BuildUI then
        E.BuildUI:UpdateTab()
    end
end

function E.BuildManager:GetCurrentBuild()
    return self.currentBuild
end

function E.BuildManager:GetCurrentTab()
    return self.currentTab
end
```

**Build UI (Tabs):**

```lua
-- ui/tabs/build_viewer.lua
E.BuildUI = {}

function E.BuildUI:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()

    -- Tab buttons
    self.tabButtons = {
        overview = self:CreateTabButton(frame, "Overview", "overview", 0),
        leveling = self:CreateTabButton(frame, "Leveling", "leveling", 1),
        bis = self:CreateTabButton(frame, "BIS Gear", "bis", 2),
        rotation = self:CreateTabButton(frame, "Rotations", "rotation", 3),
        stats = self:CreateTabButton(frame, "Stats", "stats", 4),
    }

    -- Content frame
    self.contentFrame = CreateFrame("Frame", nil, frame)
    self.contentFrame:SetPoint("TOPLEFT", 20, -80)
    self.contentFrame:SetPoint("BOTTOMRIGHT", -20, 20)

    self.frame = frame
    return frame
end

function E.BuildUI:CreateTabButton(parent, text, tabName, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(120, 30)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20 + (index * 130), -40)

    -- Background
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Text
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)

    -- Click handler
    button:SetScript("OnClick", function()
        E.BuildManager:SelectTab(tabName)
    end)

    -- Hover
    button:SetScript("OnEnter", function(self)
        if E.BuildManager:GetCurrentTab() ~= tabName then
            self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
        end
    end)

    button:SetScript("OnLeave", function(self)
        if E.BuildManager:GetCurrentTab() ~= tabName then
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end
    end)

    button.tabName = tabName
    return button
end

function E.BuildUI:Update()
    local build = E.BuildManager:GetCurrentBuild()

    if not build then
        return
    end

    -- Update tab button states
    local currentTab = E.BuildManager:GetCurrentTab()
    for tabName, button in pairs(self.tabButtons) do
        if tabName == currentTab then
            button.bg:SetColorTexture(0, 1, 0, 0.5)  -- Green active
        else
            button.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)  -- Gray inactive
        end
    end

    -- Update content
    self:UpdateTab()
end

function E.BuildUI:UpdateTab()
    local build = E.BuildManager:GetCurrentBuild()
    local tab = E.BuildManager:GetCurrentTab()

    if not build or not tab then
        return
    end

    -- Clear existing content
    self.contentFrame:Hide()
    self.contentFrame:Show()

    -- Load appropriate tab content
    if tab == "overview" then
        self:ShowOverview(build)
    elseif tab == "leveling" then
        self:ShowLeveling(build)
    elseif tab == "bis" then
        self:ShowBIS(build)
    elseif tab == "rotation" then
        self:ShowRotation(build)
    elseif tab == "stats" then
        self:ShowStats(build)
    end
end

-- Tab implementations
function E.BuildUI:ShowOverview(build)
    -- Créer le contenu de la tab Overview
    -- (voir layout décrit précédemment)
end

function E.BuildUI:ShowLeveling(build)
    -- Créer le contenu de la tab Leveling
end

function E.BuildUI:ShowBIS(build)
    -- Créer le contenu de la tab BIS Gear
end

function E.BuildUI:ShowRotation(build)
    -- Créer le contenu de la tab Rotations
end

function E.BuildUI:ShowStats(build)
    -- Créer le contenu de la tab Stats
end
```

---

## 🎯 Checklist de Développement

### Phase 1: Builds par Défaut (2 semaines)

- [ ] **Recherche & Curation**
  - [ ] Scraper/compiler 39 builds (1 par spec)
  - [ ] Vérifier sources (Maxroll, Icy Veins, Wowhead)
  - [ ] Valider talents, stats, rotations

- [ ] **Création builds_default.lua**
  - [ ] Créer structure complète pour 1 build (template)
  - [ ] Remplir les 39 builds
  - [ ] Ajouter leveling guides
  - [ ] Ajouter rotations avec icônes

- [ ] **Implémentation Addon**
  - [ ] core/build_manager.lua (chargement)
  - [ ] ui/tabs/build_viewer.lua (tabs)
  - [ ] ui/tabs/build_overview.lua
  - [ ] ui/tabs/build_leveling.lua
  - [ ] ui/tabs/build_bis.lua
  - [ ] ui/tabs/build_rotation.lua
  - [ ] ui/tabs/build_stats.lua

### Phase 2: Application Desktop (4 semaines)

- [ ] **Setup Tauri + Vue.js**
  - [ ] Initialiser projet Tauri
  - [ ] Setup Vue.js 3 + TypeScript + Vuetify
  - [ ] Configuration de build

- [ ] **Backend Rust**
  - [ ] Détecteur d'installation WoW
  - [ ] Scraper Maxroll.gg
  - [ ] Parser HTML → Build struct
  - [ ] Convertisseur Build → Lua
  - [ ] Écriture fichier builds_extended.lua

- [ ] **Frontend Vue.js**
  - [ ] Interface de détection WoW
  - [ ] Page de recherche de builds
  - [ ] Filtres avancés (classe, spec, activité)
  - [ ] Preview de build
  - [ ] Liste des builds locaux
  - [ ] Synchronisation

- [ ] **Polish**
  - [ ] Gestion d'erreurs
  - [ ] Loading states
  - [ ] Notifications
  - [ ] Auto-update (optionnel)

### Phase 3: Intégration & Tests (2 semaines)

- [ ] **Tests**
  - [ ] Tester avec tous les 39 builds
  - [ ] Vérifier chargement in-game
  - [ ] Tester app desktop sur Windows/Mac/Linux
  - [ ] Tester synchronisation

- [ ] **Documentation**
  - [ ] README pour l'addon
  - [ ] Guide d'utilisation app desktop
  - [ ] Vidéo tutoriel (optionnel)

- [ ] **Release**
  - [ ] Package addon pour CurseForge/Wago
  - [ ] Build app desktop (exe/dmg/AppImage)
  - [ ] Publier sur GitHub Releases

---

## 📝 Notes Importantes

### Limites Techniques

1. **Taille du fichier builds_extended.lua**
   - Recommandé: <5 MB
   - Maximum pratique: ~10 MB
   - Au-delà: impacte temps de chargement WoW

2. **Mise à jour**
   - Les builds par défaut sont mis à jour avec les releases addon
   - Les builds étendus sont mis à jour via l'app desktop
   - Pas de mise à jour automatique in-game (limitation WoW)

3. **Performance**
   - Chargement initial: ~100-200ms pour 100 builds
   - Changement de tab: instantané (< 16ms)
   - Pas d'impact sur FPS in-game

### Évolutions Futures

- **Phase 4**: Système communautaire (voir ci-dessous)
- **Phase 5**: Intégration WeakAuras (génération auto)
- **Phase 6**: Comparateur de builds (side-by-side)
- **Phase 7**: Système de notation et reviews

---

## 🌐 Phase 4: Système Communautaire

### Concept

Permettre aux joueurs de **créer et partager** leurs propres builds via:
- Export SimC depuis l'addon
- Upload vers sites communautaires
- Partage via l'app desktop

### Workflow Complet

```
┌─────────────────────────────────────────────────────────────┐
│  1. CRÉATION IN-GAME                                        │
│  ┌───────────────────────────────────────────────────┐     │
│  │  Joueur in-game:                                  │     │
│  │  • Configure son build                            │     │
│  │  • Optimise son équipement                        │     │
│  │  • Teste rotations                                │     │
│  │  • /nihui save "Mon Build M+ Destru"              │     │
│  └───────────────────────────────────────────────────┘     │
│                         ↓                                    │
│  ┌───────────────────────────────────────────────────┐     │
│  │  SavedVariables (NihuiOptimizerDB)                │     │
│  │  • Équipement complet                             │     │
│  │  • Talents                                        │     │
│  │  • Stats actuelles                                │     │
│  │  • Notes du joueur                                │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  2. LECTURE PAR L'APP DESKTOP                               │
│  ┌───────────────────────────────────────────────────┐     │
│  │  App Tauri lit SavedVariables:                    │     │
│  │  • Parse NihuiOptimizerDB.lua                     │     │
│  │  • Extrait les builds sauvegardés                 │     │
│  │  • Affiche dans UI "Mes Builds"                   │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  3. EXPORT SIMCRAFT                                         │
│  ┌───────────────────────────────────────────────────┐     │
│  │  App génère profil SimC:                          │     │
│  │  warlock="PlayerName"                             │     │
│  │  level=70                                         │     │
│  │  race=blood_elf                                   │     │
│  │  spec=destruction                                 │     │
│  │  head=248410,bonus_id=...                         │     │
│  │  neck=225577,bonus_id=...                         │     │
│  │  ...                                              │     │
│  │  talents=BQEAAAAAAAAAAAAAAAAAAAAAAskEJJRSk...       │     │
│  └───────────────────────────────────────────────────┘     │
│                         ↓                                    │
│  [Copier dans Presse-papier]  [Ouvrir Raidbots]            │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  4. PARTAGE COMMUNAUTAIRE                                   │
│  ┌───────────────────────────────────────────────────┐     │
│  │  Options:                                         │     │
│  │  • Upload vers Nihui Optimizer Community          │     │
│  │  • Ouvrir Raidbots avec profil pré-rempli         │     │
│  │  • Copier lien de partage                         │     │
│  │  • Export JSON pour sites tiers                   │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Implémentation In-Game

**Système de sauvegarde de build:**

```lua
-- core/build_creator.lua
E.BuildCreator = {
    currentPlayerBuild = nil,
}

-- Sauvegarder le build actuel du joueur
function E.BuildCreator:SaveCurrentBuild(buildName, notes)
    local build = self:GenerateBuildFromPlayer(buildName, notes)

    -- Sauvegarder dans SavedVariables
    NihuiOptimizerDB = NihuiOptimizerDB or {}
    NihuiOptimizerDB.myBuilds = NihuiOptimizerDB.myBuilds or {}

    table.insert(NihuiOptimizerDB.myBuilds, build)

    print(string.format(
        "|cff00ff00[Nihui Optimizer]|r Build '%s' sauvegardé!",
        buildName
    ))

    print("Ouvrez l'app desktop pour exporter vers SimC ou partager")

    return build
end

-- Générer un build depuis l'état actuel du joueur
function E.BuildCreator:GenerateBuildFromPlayer(buildName, notes)
    local playerName = UnitName("player")
    local _, className = UnitClass("player")
    local specIndex = GetSpecialization()
    local specName = select(2, GetSpecializationInfo(specIndex))

    local build = {
        name = buildName,
        class = className,
        spec = specName,
        author = playerName,
        createdAt = date("%Y-%m-%d %H:%M:%S"),
        notes = notes or "",

        -- Équipement complet
        equipment = {},

        -- Stats actuelles
        stats = {},

        -- Talents
        talents = self:GetTalentString(),

        -- Métadonnées
        itemLevel = select(1, GetAverageItemLevel()),
        realm = GetRealmName(),
    }

    -- Extraire équipement
    for slotID = 1, 19 do
        local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)

        if C_Item.DoesItemExist(itemLocation) then
            local itemLink = C_Item.GetItemLink(itemLocation)
            local itemID = C_Item.GetItemID(itemLocation)
            local itemName = C_Item.GetItemName(itemLocation)

            -- Parser le itemLink pour extraire bonus_id, gems, etc.
            local bonusIDs, gems, enchants = self:ParseItemLink(itemLink)

            build.equipment[slotID] = {
                itemID = itemID,
                itemName = itemName,
                itemLink = itemLink,
                bonusIDs = bonusIDs,
                gems = gems,
                enchants = enchants,
            }
        end
    end

    -- Extraire stats
    build.stats = {
        intellect = UnitStat("player", LE_UNIT_STAT_INTELLECT),
        haste = {
            rating = GetCombatRating(CR_HASTE_MELEE),
            percent = UnitSpellHaste("player"),
        },
        mastery = {
            rating = GetCombatRating(CR_MASTERY),
            percent = GetMasteryEffect(),
        },
        crit = {
            rating = GetCombatRating(CR_CRIT_MELEE),
            percent = GetCritChance(),
        },
        versatility = {
            rating = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE),
            percent = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE),
        },
    }

    return build
end

-- Parser itemLink pour extraire bonus_id
function E.BuildCreator:ParseItemLink(itemLink)
    -- Format: |cffffffff|Hitem:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:level:specializationID:upgradeTypeID:instanceDifficulty:numBonusIDs:bonusID1:bonusID2...|h[Name]|h|r

    local parts = {strsplit(":", itemLink)}

    local bonusIDs = {}
    local gems = {}
    local enchant = tonumber(parts[2]) or 0

    -- Gems
    for i = 3, 6 do
        local gemID = tonumber(parts[i]) or 0
        if gemID > 0 then
            table.insert(gems, gemID)
        end
    end

    -- Bonus IDs (après le 13ème élément)
    local numBonusIDs = tonumber(parts[14]) or 0
    for i = 1, numBonusIDs do
        local bonusID = tonumber(parts[14 + i]) or 0
        table.insert(bonusIDs, bonusID)
    end

    return bonusIDs, gems, enchant
end

-- Obtenir la string de talents
function E.BuildCreator:GetTalentString()
    local exportString = C_Traits.GenerateImportString()
    return exportString or ""
end

-- Commande slash
SLASH_NIHUISAVE1 = "/nihuisave"
SlashCmdList["NIHUISAVE"] = function(msg)
    local buildName, notes = msg:match("^(%S+)%s*(.*)$")

    if not buildName or buildName == "" then
        print("|cffff0000[Nihui Optimizer]|r Usage: /nihuisave <nom du build> [notes]")
        print("Exemple: /nihuisave 'M+ Destru S3' Optimisé pour clés 20+")
        return
    end

    E.BuildCreator:SaveCurrentBuild(buildName, notes)
end
```

**SavedVariables (NihuiOptimizerDB.lua):**

```lua
-- WTF/Account/.../SavedVariables/NihuiOptimizer.lua
NihuiOptimizerDB = {
    ["myBuilds"] = {
        {
            ["name"] = "M+ Destru S3",
            ["class"] = "WARLOCK",
            ["spec"] = "Destruction",
            ["author"] = "Xerwo",
            ["realm"] = "Hyjal",
            ["createdAt"] = "2025-10-25 14:32:01",
            ["notes"] = "Optimisé pour clés 20+, focus AoE",
            ["itemLevel"] = 502.4,

            ["equipment"] = {
                [1] = {  -- HEAD
                    ["itemID"] = 248410,
                    ["itemName"] = "Cowl of Branching Fate",
                    ["itemLink"] = "|cffa335ee|Hitem:248410::::::::70:267::3:4:10341:10532:1537:8767::::::|h[Cowl of Branching Fate]|h|r",
                    ["bonusIDs"] = {10341, 10532, 1537, 8767},
                    ["gems"] = {},
                    ["enchants"] = 0,
                },
                [2] = {  -- NECK
                    -- ...
                },
                -- ... tous les slots
            },

            ["stats"] = {
                ["intellect"] = 15234,
                ["haste"] = {
                    ["rating"] = 3892,
                    ["percent"] = 34.2,
                },
                ["mastery"] = {
                    ["rating"] = 3124,
                    ["percent"] = 27.8,
                },
                ["crit"] = {
                    ["rating"] = 2456,
                    ["percent"] = 21.3,
                },
                ["versatility"] = {
                    ["rating"] = 1234,
                    ["percent"] = 8.9,
                },
            },

            ["talents"] = "BQEAAAAAAAAAAAAAAAAAAAAAAskEJJRSkkkkQSIRAAAAAAIJRSaRSSSSIikE",
        },

        -- Autre build du joueur
        {
            ["name"] = "Raid Mythique Destru",
            -- ...
        },
    },

    -- Autres settings de l'addon
    ["settings"] = {
        ["showTooltips"] = true,
        -- ...
    },
}
```

### Implémentation App Desktop

**Lecture des SavedVariables:**

```rust
// src-tauri/src/saved_variables.rs
use std::path::PathBuf;
use std::fs;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct PlayerBuild {
    pub name: String,
    pub class: String,
    pub spec: String,
    pub author: String,
    pub realm: String,
    pub created_at: String,
    pub notes: String,
    pub item_level: f32,
    pub equipment: Vec<EquipmentSlot>,
    pub stats: Stats,
    pub talents: String,
}

#[command]
async fn load_player_builds(wow_path: String) -> Result<Vec<PlayerBuild>, String> {
    // Trouver tous les comptes
    let wtf_path = PathBuf::from(&wow_path).join("WTF/Account");

    let mut all_builds = Vec::new();

    // Parcourir tous les comptes
    for account_dir in fs::read_dir(wtf_path).map_err(|e| e.to_string())? {
        let account_dir = account_dir.map_err(|e| e.to_string())?;

        let saved_vars_path = account_dir.path()
            .join("SavedVariables/NihuiOptimizer.lua");

        if !saved_vars_path.exists() {
            continue;
        }

        // Lire et parser le fichier Lua
        let content = fs::read_to_string(&saved_vars_path)
            .map_err(|e| e.to_string())?;

        // Parser les builds (simple regex pour extraire les builds)
        let builds = parse_saved_variables(&content)?;

        all_builds.extend(builds);
    }

    Ok(all_builds)
}

fn parse_saved_variables(lua_content: &str) -> Result<Vec<PlayerBuild>, String> {
    // Parser le Lua (basique)
    // Chercher NihuiOptimizerDB = { ... }
    // Extraire myBuilds = { ... }

    // Pour une implémentation robuste, utiliser un parser Lua
    // Ici, on fait du parsing simple avec regex/string matching

    // TODO: Implémentation complète du parser

    Ok(vec![])
}
```

**Export SimC:**

```rust
// src-tauri/src/simc_exporter.rs
use crate::saved_variables::PlayerBuild;

pub fn build_to_simc(build: &PlayerBuild) -> String {
    let mut simc = String::new();

    // Header
    simc.push_str(&format!("{}=\"{}\"\n", build.spec.to_lowercase(), build.author));
    simc.push_str(&format!("level=70\n"));
    simc.push_str(&format!("race={}\n", get_race_from_build(build)));
    simc.push_str(&format!("spec={}\n", build.spec.to_lowercase()));
    simc.push_str("\n");

    // Équipement
    for slot in &build.equipment {
        let slot_name = get_simc_slot_name(slot.slot_id);

        let mut item_str = format!("{}={}", slot_name, slot.item_id);

        // Bonus IDs
        if !slot.bonus_ids.is_empty() {
            let bonus_str = slot.bonus_ids
                .iter()
                .map(|id| id.to_string())
                .collect::<Vec<_>>()
                .join("/");
            item_str.push_str(&format!(",bonus_id={}", bonus_str));
        }

        // Gems
        if !slot.gems.is_empty() {
            for (i, gem_id) in slot.gems.iter().enumerate() {
                item_str.push_str(&format!(",gem_id{}={}", i + 1, gem_id));
            }
        }

        // Enchant
        if slot.enchant > 0 {
            item_str.push_str(&format!(",enchant_id={}", slot.enchant));
        }

        simc.push_str(&format!("{}\n", item_str));
    }

    simc.push_str("\n");

    // Talents
    simc.push_str(&format!("talents={}\n", build.talents));

    simc
}

fn get_simc_slot_name(slot_id: u32) -> &'static str {
    match slot_id {
        1 => "head",
        2 => "neck",
        3 => "shoulder",
        4 => "shirt",
        5 => "chest",
        6 => "waist",
        7 => "legs",
        8 => "feet",
        9 => "wrist",
        10 => "hands",
        11 => "finger1",
        12 => "finger2",
        13 => "trinket1",
        14 => "trinket2",
        15 => "back",
        16 => "main_hand",
        17 => "off_hand",
        19 => "tabard",
        _ => "unknown",
    }
}
```

**Interface Vue.js (My Builds):**

```vue
<template>
  <v-container>
    <v-card>
      <v-card-title>
        Mes Builds Personnalisés
      </v-card-title>

      <v-card-subtitle>
        Builds sauvegardés depuis le jeu avec <code>/nihuisave</code>
      </v-card-subtitle>

      <v-card-text>
        <v-row>
          <v-col
            v-for="build in myBuilds"
            :key="build.name"
            cols="12"
            md="6"
          >
            <v-card elevation="2">
              <v-card-title>
                {{ build.name }}
              </v-card-title>

              <v-card-subtitle>
                {{ build.class }} - {{ build.spec }} | ilvl {{ build.itemLevel }}
                <br>
                Par {{ build.author }} ({{ build.realm }})
              </v-card-subtitle>

              <v-card-text>
                <p>{{ build.notes }}</p>

                <v-divider class="my-2" />

                <p class="text-caption">
                  Créé le {{ formatDate(build.createdAt) }}
                </p>
              </v-card-text>

              <v-card-actions>
                <v-btn
                  color="primary"
                  variant="text"
                  @click="exportToSimC(build)"
                >
                  <v-icon left>mdi-export</v-icon>
                  Export SimC
                </v-btn>

                <v-btn
                  color="secondary"
                  variant="text"
                  @click="shareToRaidbots(build)"
                >
                  <v-icon left>mdi-share</v-icon>
                  Raidbots
                </v-btn>

                <v-btn
                  color="info"
                  variant="text"
                  @click="shareToCommunity(build)"
                >
                  <v-icon left>mdi-cloud-upload</v-icon>
                  Partager
                </v-btn>
              </v-card-actions>
            </v-card>
          </v-col>
        </v-row>

        <v-alert v-if="myBuilds.length === 0" type="info">
          Aucun build sauvegardé. Utilisez <code>/nihuisave</code> in-game pour créer un build.
        </v-alert>
      </v-card-text>
    </v-card>

    <!-- Dialog Export SimC -->
    <v-dialog v-model="simcDialog" max-width="800">
      <v-card>
        <v-card-title>
          Export SimulationCraft
        </v-card-title>

        <v-card-text>
          <v-textarea
            v-model="simcExport"
            readonly
            rows="20"
            variant="outlined"
            label="Profil SimC"
          />
        </v-card-text>

        <v-card-actions>
          <v-btn
            color="primary"
            @click="copyToClipboard(simcExport)"
          >
            Copier
          </v-btn>

          <v-btn
            color="secondary"
            @click="openRaidbots(simcExport)"
          >
            Ouvrir Raidbots
          </v-btn>

          <v-spacer />

          <v-btn @click="simcDialog = false">
            Fermer
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { invoke } from '@tauri-apps/api/tauri'
import { writeText } from '@tauri-apps/api/clipboard'
import { open } from '@tauri-apps/api/shell'

const myBuilds = ref([])
const simcDialog = ref(false)
const simcExport = ref('')

onMounted(async () => {
  await loadMyBuilds()
})

async function loadMyBuilds() {
  const wowPath = await invoke('get_wow_path')
  myBuilds.value = await invoke('load_player_builds', { wowPath })
}

async function exportToSimC(build) {
  simcExport.value = await invoke('build_to_simc', { build })
  simcDialog.value = true
}

async function copyToClipboard(text) {
  await writeText(text)
  // Show notification
}

async function openRaidbots(simcText) {
  // Encoder le profil SimC
  const encoded = encodeURIComponent(simcText)
  const url = `https://www.raidbots.com/simbot/quick?profile=${encoded}`

  await open(url)
}

async function shareToRaidbots(build) {
  const simc = await invoke('build_to_simc', { build })
  await openRaidbots(simc)
}

async function shareToCommunity(build) {
  // TODO: Upload vers serveur Nihui Optimizer Community
  // Ou export JSON pour partage manuel
}
</script>
```

### Partage Communautaire (Optionnel)

**Serveur communautaire pour partage de builds:**

```rust
// Backend API (FastAPI/Actix-web)
#[post("/api/builds")]
async fn upload_build(build: Json<PlayerBuild>) -> Result<HttpResponse> {
    // Valider le build
    validate_build(&build)?;

    // Sauvegarder en DB
    let build_id = save_build_to_db(&build).await?;

    // Retourner lien de partage
    Ok(HttpResponse::Ok().json(json!({
        "build_id": build_id,
        "share_url": format!("https://nihui-optimizer.com/builds/{}", build_id),
    })))
}

#[get("/api/builds/{build_id}")]
async fn get_build(build_id: Path<String>) -> Result<HttpResponse> {
    let build = fetch_build_from_db(&build_id).await?;
    Ok(HttpResponse::Ok().json(build))
}
```

**Lien de partage:**

```
https://nihui-optimizer.com/builds/abc123

Format:
{
  "name": "M+ Destru S3 - Xerwo",
  "class": "WARLOCK",
  "spec": "Destruction",
  "author": "Xerwo@Hyjal",
  "itemLevel": 502.4,
  "equipment": [...],
  "stats": {...},
  "talents": "...",
  "notes": "Build optimisé pour clés 20+",
  "upvotes": 42,
  "downloads": 156,
}
```

---

## 🎯 Checklist Phase Communautaire

### In-Game (Addon)

- [ ] **Build Creator**
  - [ ] Commande `/nihuisave <nom>`
  - [ ] Extraction équipement complet
  - [ ] Extraction stats actuelles
  - [ ] Extraction talents
  - [ ] Sauvegarde dans SavedVariables

### App Desktop

- [ ] **Lecture SavedVariables**
  - [ ] Parser NihuiOptimizerDB.lua
  - [ ] Afficher "Mes Builds"
  - [ ] Preview de build

- [ ] **Export SimC**
  - [ ] Convertisseur Build → SimC
  - [ ] Interface d'export
  - [ ] Copie dans presse-papier
  - [ ] Ouverture Raidbots avec pré-remplissage

- [ ] **Partage (Optionnel)**
  - [ ] Upload vers serveur communautaire
  - [ ] Génération lien de partage
  - [ ] Export JSON pour sites tiers

### Serveur (Optionnel)

- [ ] **API REST**
  - [ ] POST /api/builds (upload)
  - [ ] GET /api/builds/:id (téléchargement)
  - [ ] GET /api/builds (liste publique)
  - [ ] Système de votes/reviews

- [ ] **Database**
  - [ ] Schema builds
  - [ ] Modération
  - [ ] Statistiques

---

**Document Version**: 1.1
**Dernière mise à jour**: 2025-10-25
**Auteur**: Nihui Optimizer Team
