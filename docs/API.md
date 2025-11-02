# Nihui Optimizer - Public API Documentation

Nihui Optimizer expose une API publique permettant aux addons externes d'ajouter leurs propres tabs et de contrôler la caméra.

## 🌍 Accès à l'API

L'API est disponible globalement via `_G.NihuiOptimizer` :

```lua
local NihuiOptimizer = _G.NihuiOptimizer

if NihuiOptimizer then
    -- API disponible !
    print("Nihui Optimizer version: " .. NihuiOptimizer.Version)
end
```

## 📑 TabRegistry API - Créer des Tabs Custom

### Enregistrer une Tab

```lua
NihuiOptimizer.TabRegistry:RegisterTab({
    name = "Ma Tab Custom",
    onCreate = function(tabContent) end,
    onPrepare = function() end,
    onShow = function() end,
    onHide = function() end,
    onCleanup = function() end,
})
```

### Callbacks

#### `onCreate(tabContent)` *(obligatoire)*
Appelé lors de la création du MainFrame. Créez votre UI ici.

**Paramètres:**
- `tabContent` (Frame) - Le frame parent où créer votre UI

**Retour:**
- Votre frame principal (optionnel)

**Exemple:**
```lua
onCreate = function(tabContent)
    local myFrame = CreateFrame("Frame", nil, tabContent)
    myFrame:SetAllPoints()

    -- Créer vos éléments UI
    local title = myFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    title:SetText("Mon Addon")
    title:SetPoint("TOP", myFrame, "TOP", 0, -50)

    return myFrame
end
```

#### `onPrepare()` *(optionnel)*
Appelé quand la tab devient active, **avant** l'animation de la caméra.

**Utilisation typique:**
- Définir le preset de caméra pour votre tab
- Préparer l'état de votre UI (alpha à 0, etc.)

**Exemple:**
```lua
onPrepare = function()
    -- Utiliser un preset de caméra existant
    NihuiOptimizer.CameraPresets:EnterEquipmentView(false)

    -- OU créer votre propre preset
    NihuiOptimizer.CameraPresets:EnterCustomView({
        zoom = 5.0,
        shoulderOffset = -0.5,
        mode = "MY_CUSTOM_MODE"
    }, false)
end
```

#### `onShow()` *(optionnel)*
Appelé quand l'animation de la caméra est **terminée**. Affichez/animez votre UI ici.

**Exemple:**
```lua
onShow = function()
    -- Animer vos éléments UI
    local Animations = NihuiOptimizer.Animations
    if Animations then
        Animations:FadeIn(myFrame, 0.4)
    else
        myFrame:SetAlpha(1)
    end

    print("Ma tab est maintenant visible!")
end
```

#### `onHide()` *(optionnel)*
Appelé quand l'utilisateur **change de tab** (quitte votre tab).

**Utilisation typique:**
- Cacher votre UI temporairement
- Sauvegarder l'état
- **NE PAS** restaurer les frames Blizzard ici (utilisez `onCleanup` pour ça)

**Exemple:**
```lua
onHide = function()
    -- Cacher votre UI
    if myFrame then
        myFrame:Hide()
    end
end
```

#### `onCleanup()` *(optionnel)*
Appelé quand le MainFrame se **ferme complètement**.

**Utilisation typique:**
- Restaurer les frames Blizzard que vous avez modifiées
- Nettoyer les ressources (timers, events, etc.)
- Réinitialiser l'état complet

**Exemple:**
```lua
onCleanup = function()
    -- Restaurer un frame Blizzard
    if WorldMapFrame then
        WorldMapFrame:SetParent(UIParent)
        WorldMapFrame:Show()
    end

    -- Nettoyer vos ressources
    if myTimer then
        myTimer:Cancel()
        myTimer = nil
    end
end
```

## 📷 CameraPresets API - Contrôler la Caméra

### Presets Disponibles

#### `EnterEquipmentView(animated)`
Caméra centrée sur le personnage (vue équipement).

**Paramètres:**
- `animated` (boolean) - `true` pour animer la transition, `false` pour instantané

**Exemple:**
```lua
NihuiOptimizer.CameraPresets:EnterEquipmentView(true)  -- Avec animation
```

#### `EnterLeftPanelView(animated)`
Personnage sur la droite (panneau à gauche).

**Exemple:**
```lua
NihuiOptimizer.CameraPresets:EnterLeftPanelView(true)
```

#### `EnterRightPanelView(animated)`
Personnage sur la gauche (panneau à droite).

**Exemple:**
```lua
NihuiOptimizer.CameraPresets:EnterRightPanelView(true)
```

#### `EnterMapView(animated)`
Personnage sur la droite, vue large (pour map).

**Exemple:**
```lua
NihuiOptimizer.CameraPresets:EnterMapView(true)
```

### Créer un Preset Custom

```lua
NihuiOptimizer.CameraPresets:EnterCustomView({
    zoom = 4.5,              -- Distance de la caméra (0.5 - 10)
    shoulderOffset = -0.66,  -- Décalage horizontal (-2 à 2)
    mode = "MY_VIEW"         -- Nom unique pour votre vue
}, animated)
```

## 🎬 Camera API - Contrôle Bas Niveau

### État de la Caméra

```lua
local Camera = NihuiOptimizer.Camera

-- Vérifier l'état
if Camera.isZoomed then
    print("Caméra zoomée")
end

if Camera.isTransitioning then
    print("Animation en cours")
end

if Camera.isReady then
    print("Caméra prête")
end
```

### Callbacks

```lua
-- Callback appelé quand la caméra est prête
Camera.onReady = function()
    print("Caméra prête, je peux animer mon UI maintenant!")
end

-- Callback appelé quand le zoom est terminé (mais avant rotation)
Camera.onZoomComplete = function()
    print("Zoom terminé!")
end
```

## 📋 Exemple Complet

Voici un exemple complet d'un addon qui ajoute une tab custom:

```lua
-- MonAddon.lua
local addonName, addonNS = ...

-- Attendre que Nihui Optimizer soit chargé
local function InitializeMyTab()
    local NihuiOptimizer = _G.NihuiOptimizer

    if not NihuiOptimizer then
        print("Nihui Optimizer non trouvé!")
        return
    end

    -- Stocker une référence vers notre frame
    local myFrame = nil
    local myPanel = nil

    -- Enregistrer notre tab
    local tabIndex = NihuiOptimizer.TabRegistry:RegisterTab({
        name = "Mon Addon",

        -- Créer l'UI
        onCreate = function(tabContent)
            myFrame = CreateFrame("Frame", nil, tabContent)
            myFrame:SetAllPoints()

            -- Titre
            local title = myFrame:CreateFontString(nil, "OVERLAY")
            title:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
            title:SetText("Mon Addon Custom")
            title:SetPoint("TOP", myFrame, "TOP", 0, -50)

            -- Panneau de contenu
            myPanel = CreateFrame("Frame", nil, myFrame, "BackdropTemplate")
            myPanel:SetSize(600, 400)
            myPanel:SetPoint("LEFT", myFrame, "LEFT", 50, 0)
            myPanel:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false,
                edgeSize = 2,
            })
            myPanel:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            myPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            -- Contenu du panneau
            local content = myPanel:CreateFontString(nil, "OVERLAY")
            content:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            content:SetText("Contenu de mon addon ici!")
            content:SetPoint("CENTER")

            -- Préparer pour animation (alpha 0)
            myFrame:SetAlpha(0)

            return myFrame
        end,

        -- Préparer la caméra
        onPrepare = function()
            -- Personnage à droite (panneau à gauche)
            NihuiOptimizer.CameraPresets:EnterLeftPanelView(false)
        end,

        -- Animer l'entrée
        onShow = function()
            -- Animer le fade-in
            if NihuiOptimizer.Animations then
                NihuiOptimizer.Animations:FadeIn(myFrame, 0.4)
            else
                myFrame:SetAlpha(1)
            end

            print("Tab Mon Addon affichée!")
        end,

        -- Cacher lors du changement de tab
        onHide = function()
            if myFrame then
                myFrame:Hide()
            end
        end,

        -- Cleanup final
        onCleanup = function()
            -- Nettoyer tout
            print("Cleanup de Mon Addon")
        end,
    })

    print("Mon Addon: Tab enregistrée à l'index " .. tabIndex)
end

-- Initialiser après PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Attendre un peu que Nihui Optimizer soit complètement chargé
        C_Timer.After(1, InitializeMyTab)
    end
end)
```

## ⚠️ Bonnes Pratiques

### 1. Vérifier la Disponibilité
Toujours vérifier que `_G.NihuiOptimizer` existe avant utilisation:
```lua
if not _G.NihuiOptimizer then
    print("Nihui Optimizer requis!")
    return
end
```

### 2. Timing d'Initialisation
Enregistrer vos tabs **après** `PLAYER_LOGIN` et avec un léger délai:
```lua
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        -- Enregistrer tab ici
    end)
end)
```

### 3. Gestion de la Caméra
- Utilisez `onPrepare` pour définir le preset de caméra
- Utilisez `onShow` pour animer votre UI (appelé après l'animation caméra)
- Ne changez **jamais** la caméra manuellement dans `onCreate`

### 4. Cleanup
- `onHide` : cleanup temporaire (changement de tab)
- `onCleanup` : cleanup complet (fermeture MainFrame)
- Restaurez toujours les frames Blizzard dans `onCleanup`, jamais dans `onHide`

### 5. Animations
Utilisez le système d'animations intégré pour un look cohérent:
```lua
NihuiOptimizer.Animations:FadeIn(frame, duration)
NihuiOptimizer.Animations:SlideLeft(frame, distance, duration)
```

## 🐛 Debug

Pour activer le mode debug de Nihui Optimizer:
```lua
/run _G.NihuiOptimizer.DEBUG_MODE = true
/reload
```

Cela affichera des bordures colorées sur tous les frames et des logs détaillés.

## 📚 Ressources

- **API Files:**
  - `API/TabRegistry.lua` - Code source de TabRegistry
  - `API/CameraPresets.lua` - Code source des presets caméra
  - `API/Camera.lua` - Code source du système caméra

- **Exemples:**
  - `ui/tabs/equipment.lua` - Exemple de tab (Equipment)
  - `ui/tabs/optimizer.lua` - Exemple de tab (Optimizer)

## 🤝 Support

Pour rapporter des bugs ou demander de l'aide:
- GitHub: [lien vers repo]
- Discord: [lien vers discord]

---

**Version:** 1.0.0
**Auteur:** Nihui
**License:** All Rights Reserved
