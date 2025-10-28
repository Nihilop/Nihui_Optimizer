# Nihui Optimizer - Roadmap & Vision

## 📋 Bugs à Corriger (Prioritaire)

### 🔴 CRITIQUE: Menu Contextuel - Positionnement Incorrect

**Problème:**
Le menu contextuel n'apparaît pas à la position du curseur. Les coordonnées calculées semblent correctes dans les logs, mais le menu s'affiche très loin du point de clic.

**Importance:**
Ce système de positionnement sera réutilisé pour:
- Tooltip qui suit la souris (`cursor_tooltip.lua`)
- Tous les éléments UI qui doivent suivre le curseur
- **BLOQUANT** pour la suite du développement

**État actuel:**
- Coordonnées scalées correctement dans `equipment_slots.lua:159` (`x / scale, y / scale`)
- Positionnement dans `slot_context_menu.lua:162` avec `BOTTOMLEFT` anchor
- Logs montrent des valeurs cohérentes mais rendu visuel incorrect

**Investigation nécessaire:**
- Vérifier si le système de coordonnées WoW utilise `BOTTOMLEFT` de `UIParent` comme origine (0,0)
- Tester avec d'autres anchors (`TOPLEFT`, `CENTER`)
- Comparer avec la méthode utilisée par d'autres addons (Narcissus, WeakAuras)
- Possibilité que `GetCursorPosition()` retourne des coordonnées dans un référentiel différent de celui de `UIParent`

**Fichiers concernés:**
- `ui/components/slot_context_menu.lua:138-166`
- `ui/components/equipment_slots.lua:158-161`
- `ui/components/cursor_tooltip.lua` (sera affecté)

---

## 🟡 Améliorations UI en Cours

### Tooltips - Stats Vertes avec Pourcentages

**Objectif:**
Afficher les pourcentages à côté des stats vertes, comme Narcissus le fait.

**Exemple visuel:**
```
+392 Score de crit. (2.15%)
+729 Hâte (3.87%)
+450 Maîtrise (1.92%)
```

**Implémentation requise:**
1. Détecter les lignes de stats dans `ParseTooltipData()`
2. Extraire la valeur numérique (ex: "392" de "+392 Score de crit.")
3. Mapper les noms de stats français aux constantes WoW:
   ```lua
   local STAT_TO_CONSTANT = {
       ["Coup critique"] = CR_CRIT_MELEE,
       ["Score de crit"] = CR_CRIT_MELEE,
       ["Hâte"] = CR_HASTE_MELEE,
       ["Maîtrise"] = CR_MASTERY,
       ["Polyvalence"] = CR_VERSATILITY_DAMAGE_DONE,
       ["Vitesse"] = CR_SPEED,
       ["Ponction"] = CR_LIFESTEAL,
       ["Évitement"] = CR_AVOIDANCE,
   }
   ```
4. Utiliser `GetCombatRatingBonus(constant)` pour obtenir le pourcentage par point
5. Calculer: `percentage = rating * GetCombatRatingBonus(constant)`
6. Formater le texte: `colorCode .. text .. " (" .. string.format("%.2f%%", percentage) .. ")|r"`

**Difficulté:** Moyenne
**Estimation:** 1-2 heures

**Fichier concerné:**
- `ui/components/custom_tooltip.lua:230-244`

---

### Tooltips - Support des Sockets/Gemmes

**État actuel:**
Les sockets ne sont pas affichés dans nos tooltips.

**Narcissus affiche:**
- Icône du socket (Rouge, Bleu, Jaune, Méta, etc.)
- Nom de la gemme enchâssée (si présente)
- Effet de la gemme avec ses bonus

**Implémentation requise:**
Utiliser `C_TooltipInfo` pour détecter les lignes de type `LINE_TYPE_SOCKET`:
```lua
if lines[i].type and (lines[i].type == LINE_TYPE_SOCKET) then
    local socketType = lines[i].stringVal
    local gemIcon = lines[i].gemIcon
    local gemName, gemLink = GetItemGem(itemLink, socketOrderID)
    -- Formater et afficher
end
```

**Difficulté:** Moyenne-Élevée
**Estimation:** 2-3 heures

---

## 🎯 Vision du Projet: Nihui Optimizer

### Concept Principal

**Nihui Optimizer** est un addon d'optimisation de gear qui combine:
- Interface visuelle immersive (style Narcissus)
- Connexion à des builds en ligne (comme SimC, WoWHead, Raidbots)
- Guidance étape par étape pour atteindre les caps de stats
- Alternative moderne à Pawn avec une vraie interface visuelle

### Philosophie

> **"Un Pawn en mieux, avec une interface digne de Narcissus"**

L'addon vise **TOUT LE MONDE**:
- **Joueurs hardcore**: Optimisation précise avec caps de stats, SimC weights
- **Joueurs casual**: Belle interface de personnage, meilleure que celle native de WoW
- **Joueurs RP/Cosmétiques**: Interface élégante pour consulter son équipement

---

## 📊 Fonctionnalités - Onglet "Optimizer"

### 1. Liste des Builds Disponibles

**Interface:**
```
╔══════════════════════════════════════════════════════════════╗
║  OPTIMIZER - Démoniste Destruction                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📋 Builds Disponibles                                       ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │ 🔥 [Destruction] M+ Clés Hautes (Icy Veins)           │ ║
║  │    Hâte: 35% | Maîtrise: 28% | Crit: 20%              │ ║
║  │    ⚠️ Vous manquez: 3.2% Hâte, 5.1% Maîtrise          │ ║
║  ├────────────────────────────────────────────────────────┤ ║
║  │ 🔥 [Destruction] Raid Mythique (Wowhead)              │ ║
║  │    Hâte: 30% | Maîtrise: 32% | Crit: 22%              │ ║
║  │    ✅ Objectifs atteints!                             │ ║
║  ├────────────────────────────────────────────────────────┤ ║
║  │ 💀 [Démonologie] M+ Clés Hautes                       │ ║
║  │ 🔥 [Affliction] Raid Mythique                         │ ║
║  └────────────────────────────────────────────────────────┘ ║
╚══════════════════════════════════════════════════════════════╝
```

**Fonctionnalités:**
- Détection automatique de la classe/spé actuelle
- Mise en avant des builds de la spé active
- Regroupement par spécialisation
- Indicateur visuel de progression vers les objectifs
- Source du build (Icy Veins, Wowhead, SimC, builds custom)

---

### 2. Vue Détaillée d'un Build

**Quand l'utilisateur sélectionne un build:**

```
╔══════════════════════════════════════════════════════════════╗
║  BUILD: M+ Clés Hautes - Destruction                        ║
║  Source: Icy Veins (Mise à jour: 15/10/2024)                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🎯 Objectifs de Stats                                       ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │ Hâte:        32.5% ███████░░░ 28.3% (+4.2% manquant)   │ ║
║  │ Maîtrise:    28.0% ████████░░ 25.7% (+2.3% manquant)   │ ║
║  │ Coup Crit:   20.0% ██████████ 21.4% ✅ Atteint         │ ║
║  │ Polyvalence:  8.0% ████░░░░░░  5.2% (+2.8% manquant)   │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  🔄 Changements Recommandés                                  ║
║  ┌────────────────────────────────────────────────────────┐ ║
║  │ 1. 🎩 CASQUE                                           │ ║
║  │    Actuel:  Heaume du gardien (502)                   │ ║
║  │             +320 Hâte, +280 Maîtrise                   │ ║
║  │                                                         │ ║
║  │    Recommandé: Couronne de l'éveilleur (509)          │ ║
║  │               +450 Hâte, +320 Maîtrise                 │ ║
║  │               📍 Source: Galerie Azur (Boss 3)         │ ║
║  │                                                         │ ║
║  │    Impact: 🔼 +1.8% Hâte, 🔼 +0.5% Maîtrise           │ ║
║  │    ───────────────────────────────────────────────     │ ║
║  │                                                         │ ║
║  │ 2. 👔 POITRINE                                         │ ║
║  │    Actuel:  Tunique corrompue (498)                    │ ║
║  │             +380 Crit, +290 Polyvalence                │ ║
║  │                                                         │ ║
║  │    Recommandé: Plastron du prophète (506)             │ ║
║  │               +410 Hâte, +350 Maîtrise                 │ ║
║  │               📍 Source: Donjon Atal'Dazar M+         │ ║
║  │                                                         │ ║
║  │    Impact: 🔼 +2.4% Hâte, 🔼 +1.8% Maîtrise           │ ║
║  └────────────────────────────────────────────────────────┘ ║
║                                                              ║
║  💡 En changeant ces 2 pièces, vous atteindrez 32.5% Hâte!  ║
╚══════════════════════════════════════════════════════════════╝
```

---

### 3. Système de Guidance Intelligent

**Fonctionnalités clés:**

#### a) Détection des Upgrades Disponibles
- Scan de l'équipement actuel
- Comparaison avec les items disponibles au niveau du joueur
- Filtrage par source (Raid, Donjon, Craft, Réputation, etc.)
- Priorisation par impact sur les stats

#### b) Informations de Source
Pour chaque item recommandé, afficher:
- **Raids**: Boss qui drop, difficulté
- **Donjons**: Nom du donjon, niveau M+, boss
- **Craft**: Profession requise, matériaux nécessaires
- **Réputation**: Faction, niveau de réputation requis
- **PvP**: Score requis, type de contenu
- **World Boss**: Nom du boss, rotation

#### c) Calcul d'Impact
```lua
-- Pseudo-code
function CalculateItemImpact(currentItem, recommendedItem, statPriorities)
    local currentStats = GetItemStats(currentItem)
    local newStats = GetItemStats(recommendedItem)

    local impact = {
        haste = (newStats.haste - currentStats.haste) / GetHasteRatingPerPercent(),
        mastery = (newStats.mastery - currentStats.mastery) / GetMasteryRatingPerPercent(),
        crit = (newStats.crit - currentStats.crit) / GetCritRatingPerPercent(),
        vers = (newStats.vers - currentStats.vers) / GetVersatilityRatingPerPercent(),
    }

    -- Score pondéré selon les priorités du build
    local score = 0
    for stat, value in pairs(impact) do
        score = score + (value * statPriorities[stat])
    end

    return impact, score
end
```

#### d) Priorisation des Slots
L'addon doit suggérer les changements dans l'ordre qui a le plus d'impact:
1. **Impact/Difficulté ratio** - Préférer les items faciles à obtenir avec gros impact
2. **Proximité des objectifs** - Prioriser les stats les plus loin de leurs caps
3. **Synergie d'ensemble** - Tenir compte des bonus de set

---

### 4. Connexion aux Sources de Builds

**Sources supportées (phase 1):**
- ✅ **Fichiers JSON locaux** (builds custom de l'utilisateur)
- 🔄 **API Icy Veins** (si disponible)
- 🔄 **Scraping Wowhead** (builds de guides)
- 🔄 **Import SimC** (poids de stats depuis simulation)

**Structure de données - Build JSON:**
```json
{
  "name": "M+ Clés Hautes - Destruction",
  "class": "WARLOCK",
  "spec": "Destruction",
  "source": "Icy Veins",
  "lastUpdate": "2024-10-15",
  "statTargets": {
    "haste": {
      "percent": 35.0,
      "priority": 1,
      "reason": "Réduction GCD, plus de casts"
    },
    "mastery": {
      "percent": 28.0,
      "priority": 2,
      "reason": "Dégâts chaos augmentés"
    },
    "crit": {
      "percent": 20.0,
      "priority": 3,
      "reason": "Dégâts critiques"
    },
    "versatility": {
      "percent": 8.0,
      "priority": 4,
      "reason": "Dégâts globaux"
    }
  },
  "notes": "Build orienté M+ pour maximiser l'AoE et la mobilité",
  "talents": "BQEAAAAAAAAAAAAAAAAAAAAAAskEJJRSkkkkQSIRAAAAAAIJRSaRSSSSIikE",
  "consumables": {
    "flask": "Flask of Power",
    "food": "Feast of the Divine Day",
    "augmentRune": "Draconic Augment Rune"
  }
}
```

---

## 🏗️ Architecture Technique

### Nouveaux Modules à Créer

#### 1. `core/build_manager.lua`
Gestion des builds:
```lua
E.BuildManager = {
    builds = {},              -- Cache des builds chargés
    activeBuild = nil,        -- Build actuellement sélectionné

    LoadBuilds = function()
        -- Charger depuis JSON local
        -- Télécharger depuis sources en ligne
    end,

    GetBuildsForClass = function(class, spec)
        -- Filtrer les builds par classe/spé
    end,

    CalculateProgress = function(build)
        -- Comparer stats actuelles vs objectifs
        -- Retourner pourcentages de progression
    end,

    GetRecommendedUpgrades = function(build)
        -- Analyser équipement actuel
        -- Suggérer les meilleurs changements
    end
}
```

#### 2. `core/item_database.lua`
Base de données d'items:
```lua
E.ItemDatabase = {
    items = {},               -- Cache d'items

    FindItemsForSlot = function(slotID, filters)
        -- Rechercher items disponibles pour un slot
        -- Filtrer par niveau, source, stats
    end,

    GetItemSource = function(itemID)
        -- Retourner la source de l'item
        -- (Raid, Donjon, Boss, Craft, etc.)
    end,

    CompareItems = function(item1, item2, statPriorities)
        -- Comparer deux items selon les priorités de stats
    end
}
```

#### 3. `core/stat_calculator.lua`
Calculs de stats:
```lua
E.StatCalculator = {
    GetCurrentStats = function()
        -- Stats actuelles du personnage
    end,

    RatingToPercent = function(rating, statType)
        -- Convertir rating → pourcentage
    end,

    PercentToRating = function(percent, statType)
        -- Convertir pourcentage → rating nécessaire
    end,

    SimulateEquipment = function(changes)
        -- Simuler les stats avec des changements d'équipement
    end,

    GetStatGap = function(current, target)
        -- Calculer l'écart entre stats actuelles et objectif
    end
}
```

#### 4. `ui/tabs/optimizer.lua` (DÉJÀ CRÉÉ, à implémenter)
Interface de l'onglet Optimizer:
```lua
function E:CreateOptimizerTab(parent)
    local tab = CreateFrame("Frame", nil, parent)

    -- Liste des builds (gauche)
    local buildList = CreateBuildList(tab)

    -- Détails du build sélectionné (droite)
    local buildDetails = CreateBuildDetails(tab)

    -- Panneau de progression
    local progressPanel = CreateProgressPanel(tab)

    -- Liste des changements recommandés
    local upgradeList = CreateUpgradeList(tab)

    return tab
end
```

---

## 🎨 Design UI - Style Narcissus

### Principes de Design

1. **Couleurs:**
   - Fond sombre: `0.05, 0.05, 0.05, 0.95`
   - Bordures: `0.3, 0.3, 0.3, 1`
   - Accent vert (stats atteintes): `0, 1, 0`
   - Accent rouge (stats manquantes): `1, 0.2, 0.2`
   - Accent jaune (warnings): `1, 1, 0`

2. **Typographie:**
   - Titres: `FRIZQT__.TTF, 18, OUTLINE`
   - Sous-titres: `FRIZQT__.TTF, 14, OUTLINE`
   - Corps: `FRIZQT__.TTF, 12, OUTLINE`
   - Stats: `FRIZQT__.TTF, 10, OUTLINE`

3. **Espacements:**
   - Padding standard: 24px (comme Narcissus)
   - Gap entre éléments: 12px
   - Marges internes: 8px

4. **Animations:**
   - Fade in/out: 0.15s
   - Slide: 0.2s avec easing
   - Hover effects: instant background change

### Composants Réutilisables

#### ProgressBar avec Label
```lua
function CreateStatProgressBar(parent, label, current, target)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(300, 24)

    -- Background
    bar:SetBackdrop({...})

    -- Label (gauche)
    bar.label = bar:CreateFontString(nil, "OVERLAY")
    bar.label:SetPoint("LEFT", 8, 0)
    bar.label:SetText(label)

    -- Progress fill
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetColorTexture(0, 1, 0, 0.3)
    local progress = math.min(current / target, 1)
    bar.fill:SetWidth(bar:GetWidth() * progress)

    -- Value text (droite)
    bar.value = bar:CreateFontString(nil, "OVERLAY")
    bar.value:SetPoint("RIGHT", -8, 0)
    bar.value:SetText(string.format("%.1f%% / %.1f%%", current, target))

    return bar
end
```

---

## 📝 Checklist de Développement

### Phase 1: Fondations (1-2 semaines)
- [ ] 🔴 **CRITIQUE**: Corriger le positionnement du menu contextuel/tooltip cursor
- [ ] Ajouter les pourcentages aux stats vertes dans les tooltips
- [ ] Créer `core/stat_calculator.lua` (conversion rating ↔ %)
- [ ] Créer `core/build_manager.lua` (structure de base)
- [ ] Créer la structure JSON pour les builds
- [ ] Implémenter le chargement de builds depuis JSON local

### Phase 2: Interface Optimizer (2-3 semaines)
- [ ] Créer la liste des builds disponibles
- [ ] Implémenter la sélection d'un build
- [ ] Afficher les objectifs de stats du build
- [ ] Créer les barres de progression pour chaque stat
- [ ] Calculer l'écart entre stats actuelles et objectifs

### Phase 3: Système de Recommandations (3-4 semaines)
- [ ] Créer `core/item_database.lua`
- [ ] Intégrer une base de données d'items (Wowhead, Wowtools.org)
- [ ] Implémenter la recherche d'items par slot et stats
- [ ] Calculer l'impact de chaque changement d'item
- [ ] Afficher les recommandations d'upgrade triées par impact
- [ ] Ajouter les informations de source (où dropper l'item)

### Phase 4: Connexions Externes (4-6 semaines)
- [ ] API/Scraping Icy Veins pour builds
- [ ] API/Scraping Wowhead pour builds
- [ ] Import de poids de stats depuis SimC
- [ ] Système de mise à jour automatique des builds
- [ ] Cache intelligent pour réduire les appels API

### Phase 5: Polish & Avancé (Continu)
- [ ] Support des sockets/gemmes dans tooltips
- [ ] Système de "parcours d'optimisation" (étapes à suivre)
- [ ] Comparaison de plusieurs builds côte à côte
- [ ] Export de configuration vers WeakAuras/TMW
- [ ] Intégration avec Raidbots pour SimC automatique
- [ ] Historique de progression des stats
- [ ] Notifications quand un item recommandé droppe

---

## 🎯 Objectifs Finaux

### Pour les Joueurs Hardcore
✅ Guidance précise pour atteindre les caps de stats optimaux
✅ Intégration avec SimC pour les weights exacts
✅ Recommandations basées sur les meilleurs builds de la communauté
✅ Suivi de progression vers les objectifs

### Pour les Joueurs Casual
✅ Interface magnifique pour consulter son personnage
✅ Suggestions simples et compréhensibles ("change ça pour gagner X%")
✅ Pas besoin de comprendre SimC ou les calculs complexes
✅ Remplacement de la fiche de personnage Blizzard

### Pour Tout le Monde
✅ Design immersif et élégant (style Narcissus)
✅ Tooltips riches avec toutes les infos importantes
✅ Expérience fluide et intuitive
✅ Customisable selon les besoins de chacun

---

## 🚀 Slogan

> **"Nihui Optimizer - De magnifique à optimal, un seul addon."**

---

## 📌 Notes Techniques Importantes

### Conversion Rating → Pourcentage
WoW utilise des fonctions natives pour les conversions:
```lua
-- Pour la hâte
local hasteRating = GetCombatRating(CR_HASTE_MELEE)
local hastePercent = GetHaste() -- ou UnitSpellHaste("player")

-- Pour le crit
local critRating = GetCombatRating(CR_CRIT_MELEE)
local critPercent = GetCritChance()

-- Pour la maîtrise
local masteryRating = GetCombatRating(CR_MASTERY)
local masteryPercent = GetMasteryEffect()

-- Pour la polyvalence
local versRating = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)
local versPercent = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)

-- Ratio rating/percent (varie selon le niveau)
local ratingPerPercent = {
    haste = hasteRating / hastePercent,
    crit = critRating / critPercent,
    -- etc.
}
```

### Sources de Données d'Items

1. **Wowhead Data API** (requiert clé API)
   - Items, sources, stats, tooltips
   - Limitations de rate

2. **Wowtools.org Database Dumps**
   - Fichiers CSV téléchargeables
   - Mis à jour chaque patch
   - Utilisation locale (pas d'API calls)

3. **Blizzard Game Data API**
   - API officielle
   - Requiert token OAuth
   - Rate limits stricts

### Performance

- **Cache local** des builds pour éviter les requêtes réseau
- **Lazy loading** des données d'items (charger uniquement ce qui est visible)
- **Throttling** des calculs de recommandations (debounce sur changement d'équipement)
- **Indexation** de la base d'items par slot/stats pour recherche rapide

---

**Document créé le:** [Date]
**Dernière mise à jour:** [Date]
**Version:** 1.0.0
