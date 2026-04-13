-- ================================================================
-- LOS SANTOS 1987 — Configuration Centrale
-- Tous les scripts custom lisent ce fichier via exports ou shared
-- ================================================================

Config = {}

-- ================================================================
-- SERVEUR
-- ================================================================
Config.ServerName   = "Los Santos 1987"
Config.MaxPlayers   = 64
Config.Locale       = "fr"
Config.DefaultSpawn = vector4(441.9, -982.2, 30.7, 355.0)  -- Devant LAPD

-- Argent de départ pour les nouveaux joueurs
Config.StartingCash = 500   -- 500$ en poche (billets)
Config.StartingBank = 0     -- Pas de compte bancaire pré-rempli (années 80)

-- ================================================================
-- ÉCONOMIE — Cash is King (années 80)
-- ================================================================
Config.Economy = {
    CurrencySymbol  = "$",
    MaxCashOnHand   = 50000,        -- Max en poche avant danger d'être volé
    WalletStealable = true,         -- Les joueurs peuvent voler l'argent liquide
    CashOnlyJobs    = true,         -- Tous les salaires versés en cash (pas de virement)
    BankName        = "Fleeca Bank",
    ATMInteractDist = 1.5,
    BankLocations   = {
        { label = "Fleeca — South LS",       coords = vector3(149.4,  -1042.7, 29.4)  },
        { label = "Fleeca — Rockford Hills", coords = vector3(-1212.9, -330.4, 37.8)  },
        { label = "Pacific Standard Bank",   coords = vector3(247.0,   220.5, 106.3)  },
        { label = "Fleeca — Vespucci",       coords = vector3(-2962.9, 482.6,  15.7)  },
    },
}

-- ================================================================
-- GANGS DE LOS ANGELES 1987
-- ================================================================
Config.Gangs = {
    ["los_rojo"] = {
        label       = "Los Rojos",
        description = "Gang des rues de South LS, couleur rouge. Contrôlent la drogue au sud.",
        color       = "#CC0000",
        territory   = "South Los Santos",
        spawns      = {
            vector4(96.5,  -1925.9, 20.9, 0.0),
            vector4(108.4, -1910.3, 20.8, 180.0),
            vector4(85.0,  -1945.0, 20.8, 90.0),
        },
        blip        = { sprite = 84, scale = 0.8, color = 1,  label = "Los Rojos" },
        gangItems   = { "pistol_ammo", "bandage", "weed_baggie" },
        maxMembers  = 30,
        wagePerHour = 80,   -- Gain moyen d'un soldat (activités illicites)
        grades = {
            [0] = { name = "recrue",     label = "Recrue",      salary = 0  },
            [1] = { name = "soldat",     label = "Soldat",      salary = 80 },
            [2] = { name = "sergent",    label = "Sergent",     salary = 120 },
            [3] = { name = "lieutenant", label = "Lieutenant",  salary = 160 },
            [4] = { name = "boss",       label = "Boss",        salary = 250 },
        },
    },
    ["los_azul"] = {
        label       = "Los Azules",
        description = "Gang rival des Rojos, contrôlent l'Est de LS. Couleur bleue.",
        color       = "#0044CC",
        territory   = "East Los Santos",
        spawns      = {
            vector4(692.9, -1851.2, 30.5, 90.0),
            vector4(710.1, -1835.8, 30.5, 270.0),
            vector4(680.0, -1870.0, 30.5, 0.0),
        },
        blip        = { sprite = 84, scale = 0.8, color = 3,  label = "Los Azules" },
        gangItems   = { "pistol_ammo", "bandage", "crack_baggie" },
        maxMembers  = 30,
        wagePerHour = 80,
        grades = {
            [0] = { name = "recrue",     label = "Recrue",      salary = 0  },
            [1] = { name = "soldat",     label = "Soldat",      salary = 80 },
            [2] = { name = "sergent",    label = "Sergent",     salary = 120 },
            [3] = { name = "lieutenant", label = "Lieutenant",  salary = 160 },
            [4] = { name = "boss",       label = "Boss",        salary = 250 },
        },
    },
    ["los_sur"] = {
        label       = "Los Surenos",
        description = "Gang Latino contrôlant le port et les importations de cocaïne.",
        color       = "#8B4513",
        territory   = "La Mesa / Port",
        spawns      = {
            vector4(1113.4, -3163.5, 5.9, 180.0),
            vector4(1098.7, -3178.2, 5.9,   0.0),
        },
        blip        = { sprite = 84, scale = 0.8, color = 47, label = "Los Surenos" },
        gangItems   = { "pistol_ammo", "bandage", "coke_baggie" },
        maxMembers  = 25,
        wagePerHour = 100,
        grades = {
            [0] = { name = "recrue",     label = "Recrue",      salary = 0   },
            [1] = { name = "soldado",    label = "Soldado",     salary = 100 },
            [2] = { name = "veterano",   label = "Veterano",    salary = 150 },
            [3] = { name = "jefe",       label = "Jefe",        salary = 200 },
            [4] = { name = "capo",       label = "Capo",        salary = 300 },
        },
    },
    ["la_cosa"] = {
        label       = "La Cosa Nostra",
        description = "Famille mafieuse italienne. Opèrent en costume depuis Vinewood.",
        color       = "#1A1A1A",
        territory   = "Vinewood / Rockford Hills",
        spawns      = {
            vector4(-1282.2, -1012.8, 5.0, 90.0),
            vector4(-1269.4, -1000.1, 5.0, 270.0),
        },
        blip        = { sprite = 84, scale = 0.8, color = 0,  label = "La Cosa Nostra" },
        gangItems   = { "pistol_ammo", "bandage", "coke_baggie" },
        maxMembers  = 20,
        wagePerHour = 150,
        grades = {
            [0] = { name = "associato",  label = "Associato",   salary = 0   },
            [1] = { name = "soldato",    label = "Soldato",     salary = 150 },
            [2] = { name = "capodecina", label = "Capodecina",  salary = 200 },
            [3] = { name = "sottocapo",  label = "Sottocapo",   salary = 280 },
            [4] = { name = "boss",       label = "Boss",        salary = 400 },
        },
    },
}

-- ================================================================
-- EMPLOIS CIVILS
-- ================================================================
Config.Jobs = {
    ["taxi"] = {
        label       = "Chauffeur de Taxi",
        defaultDuty = false,
        blip        = { sprite = 198, scale = 0.8, color = 5, label = "Taxi" },
        location    = vector4(906.4, -183.5, 73.9, 319.5),
        vehicle     = "taxi",
        grades = {
            [0] = { name = "debutant",  label = "Débutant",   payment = 10 },
            [1] = { name = "confirme",  label = "Confirmé",   payment = 15 },
            [2] = { name = "expert",    label = "Expert",     payment = 20 },
            [3] = { name = "gerant",    label = "Gérant",     payment = 30 },
        },
    },
    ["mechanic"] = {
        label       = "Mécanicien",
        defaultDuty = false,
        blip        = { sprite = 446, scale = 0.8, color = 25, label = "Mécano" },
        location    = vector4(114.8, -630.5, 43.9, 95.0),
        grades = {
            [0] = { name = "apprenti",    label = "Apprenti",      payment = 15 },
            [1] = { name = "mecano",      label = "Mécanicien",    payment = 25 },
            [2] = { name = "chef_atelier",label = "Chef Atelier",  payment = 35 },
            [3] = { name = "patron",      label = "Patron",        payment = 50 },
        },
    },
    ["trucker"] = {
        label       = "Camionneur",
        defaultDuty = false,
        blip        = { sprite = 477, scale = 0.8, color = 47, label = "Transports" },
        location    = vector4(-329.8, -2841.0, 6.0, 330.0),
        vehicle     = "mule",
        grades = {
            [0] = { name = "livreur",     label = "Livreur",       payment = 20 },
            [1] = { name = "camionneur",  label = "Camionneur",    payment = 30 },
            [2] = { name = "longcourrier",label = "Long-courrier", payment = 45 },
        },
    },
    ["fisher"] = {
        label       = "Pêcheur",
        defaultDuty = false,
        blip        = { sprite = 68,  scale = 0.8, color = 3,  label = "Pêche" },
        location    = vector4(-706.5, -1476.9, 1.9, 90.0),
        grades = {
            [0] = { name = "amateur",   label = "Pêcheur Amateur", payment = 15 },
            [1] = { name = "pro",       label = "Pêcheur Pro",     payment = 25 },
            [2] = { name = "capitaine", label = "Capitaine",       payment = 35 },
        },
    },
    ["police"] = {
        label       = "LAPD",
        defaultDuty = true,
        blip        = { sprite = 60, scale = 0.9, color = 3,  label = "LAPD" },
        location    = vector4(441.9, -982.2, 30.7, 355.0),
        grades = {
            [0] = { name = "officier",     label = "Officier",       payment = 60  },
            [1] = { name = "detective",    label = "Détective",      payment = 80  },
            [2] = { name = "sergent",      label = "Sergent",        payment = 100 },
            [3] = { name = "lieutenant",   label = "Lieutenant",     payment = 120 },
            [4] = { name = "capitaine",    label = "Capitaine",      payment = 150 },
            [5] = { name = "commissaire",  label = "Commissaire",    payment = 200 },
        },
    },
    ["vicesquad"] = {
        label       = "Vice Squad",
        defaultDuty = true,
        blip        = { sprite = 60, scale = 0.8, color = 28, label = "Vice Squad" },
        location    = vector4(350.0, -1530.0, 28.4, 180.0),
        grades = {
            [0] = { name = "agent",       label = "Agent Banalisé",    payment = 80  },
            [1] = { name = "inspecteur",  label = "Inspecteur",        payment = 100 },
            [2] = { name = "insp_chef",   label = "Inspecteur Chef",   payment = 130 },
            [3] = { name = "commandant",  label = "Commandant",        payment = 160 },
        },
    },
    ["ems"] = {
        label       = "Services Médicaux",
        defaultDuty = true,
        blip        = { sprite = 61, scale = 0.8, color = 49, label = "EMS" },
        location    = vector4(297.8, -584.5, 43.3, 340.0),
        grades = {
            [0] = { name = "ambulancier", label = "Ambulancier",     payment = 50  },
            [1] = { name = "infirmier",   label = "Infirmier",       payment = 65  },
            [2] = { name = "medecin",     label = "Médecin",         payment = 85  },
            [3] = { name = "chef_serv",   label = "Chef de Service", payment = 110 },
        },
    },
}

-- ================================================================
-- DROGUES — Los Angeles 1987
-- ================================================================
Config.Drugs = {
    ["crack"] = {
        label         = "Crack",
        rawItem       = "cocaine_brick",
        processedItem = "crack_baggie",
        sellPrice     = { min = 80,  max = 160  },
        supplyPrice   = 10,
        processTime   = 30,     -- secondes pour cuisiner
        riskLevel     = 3,      -- 1 (faible) → 5 (très risqué)
        supplyCoords  = vector3(360.5, -1601.5, 35.0),
        labCoords     = vector3(218.0, -810.2,  31.1),
        sellCoords    = {
            vector3(95.7,  -1932.6, 20.9),
            vector3(406.5, -1008.2, -99.0),
            vector3(712.9, -980.6,  30.4),
        },
        effects = {
            duration     = 60,
            speedBoost   = 1.5,
            staminaBoost = true,
            healthDrain  = 2,
        },
    },
    ["cocaine"] = {
        label         = "Cocaïne",
        rawItem       = "cocaine_brick",
        processedItem = "coke_baggie",
        sellPrice     = { min = 200, max = 400  },
        supplyPrice   = 50,
        processTime   = 60,
        riskLevel     = 4,
        supplyCoords  = vector3(1097.7, -3175.0, 5.9),
        labCoords     = vector3(2500.0, 4971.5,  46.4),
        sellCoords    = {
            vector3(-1282.2, -1012.8, 5.0),
            vector3(247.0,    220.5, 106.3),
            vector3(1113.4, -3163.5,  5.9),
        },
        effects = {
            duration     = 120,
            speedBoost   = 1.2,
            staminaBoost = true,
            healthDrain  = 0.5,
        },
    },
    ["weed"] = {
        label         = "Weed",
        rawItem       = "weed_leaf",
        processedItem = "weed_baggie",
        sellPrice     = { min = 20, max = 60   },
        supplyPrice   = 5,
        processTime   = 15,
        riskLevel     = 2,
        supplyCoords  = vector3(2671.0, 2615.0, 57.7),
        labCoords     = vector3(2543.0, 2609.0, 37.9),
        sellCoords    = {
            vector3(96.5,  -1925.9, 20.9),
            vector3(692.9, -1851.2, 30.5),
            vector3(-347.0, 6026.0, 31.2),
        },
        effects = {
            duration     = 180,
            speedBoost   = 0.8,
            staminaBoost = false,
            healthDrain  = 0.0,
        },
    },
    ["pcp"] = {
        label         = "PCP (Angel Dust)",
        rawItem       = "pcp_ingredient",
        processedItem = "pcp_baggie",
        sellPrice     = { min = 150, max = 300  },
        supplyPrice   = 30,
        processTime   = 45,
        riskLevel     = 5,
        supplyCoords  = vector3(500.0, -1940.0, 25.0),
        labCoords     = vector3(220.0, -805.0,  31.1),
        sellCoords    = {
            vector3(400.0, -1600.0, 30.0),
            vector3(700.0, -1850.0, 30.5),
        },
        effects = {
            duration     = 90,
            speedBoost   = 2.0,
            staminaBoost = true,
            healthDrain  = 5,
        },
    },
}

-- ================================================================
-- VÉHICULES AUTORISÉS (années 80 uniquement)
-- ================================================================
Config.AllowedVehicles = {
    -- Muscle cars
    "vigero", "dominator", "gauntlet", "phoenix", "stallion", "sabre2",
    -- Berlines / Sedans
    "stratum", "washington", "premier", "greenwood",
    -- Voitures de luxe 80s
    "feltzer", "windsor",
    -- Low-riders / Gang cars
    "voodoo", "tornado", "buccaneer", "chino",
    -- Pickup / Camionnettes
    "bison", "bobcatxl", "picador", "sadler",
    -- Police 80s
    "police", "police2", "police3", "policeold1", "policeold2",
    -- Ambulance & services
    "ambulance",
    -- Taxis
    "taxi",
    -- Motos 80s
    "daemon", "bagger",
    -- Camions
    "mule", "pounder", "phantom",
    -- Bateaux (style Miami/LA)
    "speeder", "squalo",
    -- Véhicules utilitaires
    "flatbed", "towtruck",
}

-- Véhicules modernes interdits
Config.BannedVehicles = {
    "zentorno", "t20", "osiris", "adder", "entityxf",
    "turismor", "nero", "fmj", "reaper", "tyrant",
    "cyclone", "deveste", "emerus", "krieger", "thrax",
    "lazer", "hydra", "nokota", "rogue",
    "oppressor", "oppressor2", "scramjet",
}

-- ================================================================
-- PAGER & CABINES TÉLÉPHONIQUES
-- ================================================================
Config.Pager = {
    MaxMessages     = 10,
    MessageCost     = 0,        -- Gratuit (cabines 80s)
    MaxMsgLength    = 120,      -- Chars max (biper limité)
    NotifSound      = "PAGER",  -- Son de notification
    PayphoneLocations = {
        { coords = vector3(176.9,  -1003.8, 29.3),  heading = 180.0, label = "Centre-Ville"  },
        { coords = vector3(-47.0,  -1757.3, 29.4),  heading =  90.0, label = "Forum Drive"   },
        { coords = vector3(356.0,   -693.0, 29.1),  heading =   0.0, label = "Rockford Hills" },
        { coords = vector3(-711.5,  -914.0, 19.2),  heading = 270.0, label = "Vespucci Canals" },
        { coords = vector3(1162.4,  -322.3, 69.3),  heading = 180.0, label = "East LS"       },
        { coords = vector3(-1391.9, -596.8, 30.3),  heading =  90.0, label = "Del Perro"     },
        { coords = vector3(2677.7,  3280.5, 55.2),  heading =   0.0, label = "Sandy Shores"  },
        { coords = vector3(95.7,   -1932.6, 20.9),  heading = 180.0, label = "South LS Hood" },
        { coords = vector3(692.9,  -1851.2, 30.5),  heading =  90.0, label = "East LS Hood"  },
    },
}

-- ================================================================
-- POLICE — LAPD & VICE SQUAD
-- ================================================================
Config.Police = {
    HandcuffDuration = 600,     -- Secondes avant libération auto
    BailAmount       = 5000,    -- Caution en dollars
    MaxJailTime      = 1800,    -- Peine max 30 min (en secondes)
    EvidenceExpiry   = 300,     -- Preuves disparaissent après 5 min

    Armory = {
        ["police"] = {
            weapons = {
                "weapon_pistol", "weapon_combatpistol",
                "weapon_pumpshotgun", "weapon_nightstick",
            },
            ammo = { pistol = 50, shotgun = 20 },
        },
        ["vicesquad"] = {
            weapons = {
                "weapon_pistol", "weapon_smg",
                "weapon_carbinerifle", "weapon_knife",
            },
            ammo = { pistol = 100, smg = 100, rifle = 60 },
        },
    },

    Vehicles = {
        ["police"]    = "policeold1",   -- Ford LTD style (LAPD classique)
        ["vicesquad"] = "washington",   -- Voiture banalisée
        ["swat"]      = "police3",
    },

    Locations = {
        {
            label   = "Commissariat Central — LAPD",
            coords  = vector4(441.9,  -982.2, 30.7,  355.0),
            blip    = { sprite = 60, scale = 0.9, color = 3,  label = "LAPD HQ" },
        },
        {
            label   = "Vice Squad — Bureau",
            coords  = vector4(350.0, -1530.0, 28.4, 180.0),
            blip    = { sprite = 60, scale = 0.8, color = 28, label = "Vice Squad" },
        },
    },

    JailLocation    = vector4(1651.9, 2563.8, 45.6, 90.0),   -- Bolingbroke
    CuffDistance    = 2.5,
    EvidenceBagItem = "evidence_bag",
}

-- ================================================================
-- HUD RÉTRO 80s
-- ================================================================
Config.HUD = {
    PrimaryColor    = "#FF7700",    -- Orange néon (phosphore)
    SecondaryColor  = "#00FFFF",    -- Cyan néon
    DangerColor     = "#FF0033",    -- Rouge néon
    BackgroundAlpha = 0.80,
    ShowSpeed       = true,
    ShowCash        = true,
    ShowHealth      = true,
    ShowArmor       = true,
    ShowWanted      = true,
    ShowJob         = true,
    ShowStreet      = true,
    SpeedUnit       = "MPH",        -- Miles per hour (USA années 80)
    ScanlineEffect  = true,         -- Effet CRT écran rétro
}
