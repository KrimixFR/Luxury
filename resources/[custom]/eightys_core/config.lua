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
Config.EconomyBase = {
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
    ["government"] = {
        label       = "Gouvernement",
        defaultDuty = true,
        offDutyPay  = false,
        grades      = {
            [0] = { name="fonctionnaire",  label="Fonctionnaire",   payment=200 },
            [1] = { name="conseiller",     label="Conseiller",      payment=300 },
            [2] = { name="prefet",         label="Préfet",          payment=500 },
            [3] = { name="maire",          label="Maire",           payment=800 },
        },
    },
    ["restaurant"] = {
        label       = "Restaurateur",
        defaultDuty = false,
        offDutyPay  = false,
        grades      = {
            [0] = { name="serveur",    label="Serveur",    payment=100 },
            [1] = { name="chef",       label="Chef",       payment=200 },
            [2] = { name="gerant",     label="Gérant",     payment=300 },
        },
    },
    ["epicerie"] = {
        label       = "Épicier",
        defaultDuty = false,
        offDutyPay  = false,
        grades      = {
            [0] = { name="employe",  label="Employé",   payment=80  },
            [1] = { name="gerant",   label="Gérant",    payment=200 },
        },
    },
    ["boutique"] = {
        label       = "Gérant Boutique",
        defaultDuty = false,
        offDutyPay  = false,
        grades      = {
            [0] = { name="vendeur",  label="Vendeur",   payment=100 },
            [1] = { name="gerant",   label="Gérant",    payment=250 },
        },
    },
    ["concessionnaire"] = {
        label       = "Concessionnaire",
        defaultDuty = false,
        offDutyPay  = false,
        grades      = {
            [0] = { name="vendeur",  label="Vendeur",      payment=200 },
            [1] = { name="directeur",label="Directeur",    payment=500 },
        },
    },
    ["barman"] = {
        label       = "Barman",
        defaultDuty = false,
        offDutyPay  = false,
        grades      = {
            [0] = { name="serveur",  label="Serveur",  payment=80  },
            [1] = { name="patron",   label="Patron",   payment=200 },
        },
    },
    ["recordshop"] = {
        label       = "Disquaire",
        defaultDuty = false,
        offDutyPay  = false,
        grades      = {
            [0] = { name="vendeur",   label="Vendeur",   payment=100 },
            [1] = { name="gerant",    label="Gérant",    payment=200 },
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
-- VÉHICULES AUTORISÉS — Los Angeles 1987
-- Muscle cars, berlines, low-riders, utilitaires de l'époque
-- ================================================================
Config.AllowedVehicles = {
    -- Muscle cars (Camaro, Mustang, Charger, Firebird…)
    "vigero", "dominator", "gauntlet", "phoenix", "stallion", "sabre2",
    "sabre", "blade", "ruiner", "ruiner2",
    -- Berlines & sedans classiques
    "stratum", "washington", "premier", "greenwood",
    "primo", "primo2", "emperor", "emperor2", "emperor3",
    "glendale", "glendale2", "peyote", "peyote2", "peyote3",
    "regina",
    -- Voitures de luxe 80s (Continental, Cadillac…)
    "feltzer", "windsor", "stretch",
    -- Low-riders / Gang cars (Impala, El Camino…)
    "voodoo", "tornado", "tornado2", "tornado3", "tornado4", "tornado5", "tornado6",
    "buccaneer", "buccaneer2", "chino", "chino2",
    -- Pickup / Camionnettes (F-150, S-10…)
    "bison", "bison2", "bison3", "bobcatxl", "picador", "sadler", "sadler2",
    -- Police LAPD années 80
    "police", "police2", "police3", "policeold1", "policeold2",
    -- Ambulance & services
    "ambulance",
    -- Taxis (Checker Cab)
    "taxi",
    -- Motos 80s (Harley, Kawasaki…)
    "daemon", "daemon2", "bagger", "zombiea", "zombieb",
    "rat_bike", "faggio", "faggio2", "faggio3",
    "sanchez", "sanchez2", "bf400",
    -- Camions lourds
    "mule", "mule2", "mule3", "pounder", "phantom",
    -- Bateaux (style Miami Vice)
    "speeder", "speeder2", "squalo", "jetmax", "tropic",
    -- Véhicules utilitaires
    "flatbed", "towtruck", "towtruck2",
    "bus", "coach", "trash", "trash2",
    -- Camionnettes de livraison (Ford Transit, Dodge Van…)
    "speedo", "rumpo",
}

-- ================================================================
-- VÉHICULES MODERNES INTERDITS
-- Supprimés du trafic ambiant ET interdits aux joueurs
-- Cette liste couvre TOUS les modèles post-1987 de GTA V
-- ================================================================
Config.BannedVehicles = {
    -- ---- Super cars / Sports (normalement pas en trafic ambiant) ----
    "zentorno", "t20", "osiris", "adder", "entityxf", "entity2",
    "turismor", "nero", "nero2", "fmj", "reaper", "tyrant",
    "cyclone", "deveste", "emerus", "krieger", "thrax",
    "vagner", "xa21", "x80proto", "tempesta", "visione",
    "sc1", "prototipo", "italigtb", "italigtb2", "cheetah", "cheetah2",
    "pariah", "formula", "formula2", "banshee2",
    "elegy", "elegy2", "flashgt", "bestiagts", "autarch", "revolter",
    "pfister811", "bullet", "le7b", "jester", "jester2", "jester3", "jester4",
    "comet2", "comet3", "comet4", "comet5", "comet6",
    "sultan", "sultan2", "sultan3", "rapidgt", "rapidgt2",
    "lynx", "seven70", "stinger", "stingergt", "windsor2",
    "massacro", "massacro2", "feltzer2", "tropos",
    "carbonizzare", "vacca", "voltic", "voltic2",
    "infernus", "infernus2",
    -- ---- Berlines modernes (trafic ambiant) ----
    "asterope", "fugitive", "jackal",
    "asea", "asea2", "surge", "dilettante", "dilettante2",
    "ingot", "oracle", "oracle2",
    "cognoscenti", "cognoscenti2",
    "schafter2", "schafter3", "schafter4", "schafter5", "schafter6",
    "stafford", "limo2",
    -- ---- Compactes modernes ----
    "issi2", "issi3", "issi4", "issi5", "issi6", "issi7",
    "panto", "prairie", "rhapsody",
    "brioso", "brioso2", "brioso3",
    "kanjo", "kanjo2",
    -- ---- SUV modernes ----
    "cavalcade", "cavalcade2",
    "rocoto", "rebla", "serrano",
    "baller", "baller2", "baller3", "baller4", "baller5", "baller6",
    "granger", "huntley", "dubsta", "dubsta2",
    "fq2", "novak", "contender",
    "landstalker", "landstalker2", "radi",
    -- ---- Camionnettes / Vans modernes ----
    "minivan", "minivan2",
    "youga", "youga2", "youga3",
    "speedo2", "speedo3", "speedo4",
    "rumpo2", "rumpo3",
    -- ---- Motos modernes ----
    "akuma", "bati", "bati2", "carbon", "defiler", "double",
    "enduro", "hakuchou", "hakuchou2", "manchez", "manchez2",
    "nemesis", "nightblade", "ruffian",
    "shotaro", "sovereign", "vader", "vortex", "wolfsbane",
    "avarus", "bagger", "chimera", "deathbike",
    "hexer", "innovation", "lectro", "midi",
    "oppressor", "oppressor2",
    -- ---- Véhicules militaires / spéciaux ----
    "insurgent", "insurgent2", "insurgent3",
    "halftrack", "apc", "khanjali", "rhino", "barrage",
    "scramjet", "deluxo", "vigilante",
    -- ---- Avions / Hélicos (hors période ambiante) ----
    "lazer", "hydra", "nokota", "rogue",
    "havok", "buzzard", "buzzard2",
    -- ---- Bateaux modernes ----
    "dinghy", "dinghy2", "dinghy3", "dinghy4",
    "seashark", "seashark2", "seashark3",
    "submersible", "submersible2",
    "toro", "toro2",
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

-- ================================================================
-- LECTEUR CASSETTE & DISQUAIRE
-- ================================================================
Config.Radio = {
    -- Cassettes disponibles
    -- audioFile = fichier MP3 dans html/audio/ (lecture locale, prioritaire)
    -- Si audioFile est nil, la cassette joue en silence (musique à ajouter)
    Cassettes = {
        { name = "cassette_mj",     label = "Michael Jackson — Billie Jean", audioFile = "mj_billie_jean.mp3",  price = 25, color = "#FFFFFF" },
        { name = "cassette_rock",   label = "K-DST Classic Rock",            audioFile = "rock_mix.mp3",        price = 15, color = "#FF4400" },
        { name = "cassette_funk",   label = "Soul & Funk Mix",               audioFile = "funk_mix.mp3",        price = 12, color = "#FF8800" },
        { name = "cassette_motown", label = "Motown Gold",                   audioFile = "motown_mix.mp3",      price = 12, color = "#9900FF" },
        { name = "cassette_jazz",   label = "Blue Note Jazz",                audioFile = "jazz_mix.mp3",        price = 10, color = "#0066FF" },
        { name = "cassette_reggae", label = "Island Vibes Reggae",           audioFile = "reggae_mix.mp3",      price = 10, color = "#00AA44" },
    },

    -- Emplacement du disquaire (Vespucci Beach — 1987 LA)
    ShopLocation = vector3(-1272.0, -1256.0, 4.0),
    ShopBlip     = { sprite = 211, color = 46, scale = 0.8, label = "Ray's Records — Disquaire" },

    -- Job du propriétaire du disquaire
    ShopJob       = "recordshop",
    ShopInteract  = 2.0,     -- Distance interaction (m)
    CommissionPct = 0.80,    -- 80% des ventes vont à la caisse du propriétaire

    -- Volume & son ambiant
    RadioDefaultVolume = 0.8,   -- Volume par défaut (0.0 – 1.0)
    RadioMaxDist       = 30.0,  -- Distance max pour entendre une radio depuis l'extérieur (mètres)
}

-- ================================================================
-- BOÎTE À GANT
-- Règle : tout ce qui tient physiquement dans une boîte à gant.
--   ✔  Couteau, pistolet, revolver, brass knuckles
--   ✘  Batte, fusil, shotgun, SMG, crowbar (trop grand / trop long)
-- ================================================================
Config.GloveBox = {
    MaxSlots  = 6,       -- Nombre max d'emplacements distincts
    MaxWeight = 4000,    -- Poids total maximum (grammes)
    OpenKey   = 'B',     -- Touche d'ouverture (en véhicule)

    -- Whitelist — objets qui rentrent réalistement dans une boîte à gant
    AllowedItems = {
        -- Cassettes
        "cassette_mj", "cassette_rock", "cassette_funk",
        "cassette_motown", "cassette_jazz", "cassette_reggae",

        -- Documents & papiers
        "id_card", "drivers_license", "weapon_permit", "fake_id",
        "vehicle_insurance", "police_badge",

        -- Objets quotidiens
        "bandage", "cigarettes", "lighter", "pager",
        "beer", "sandwich", "water", "map",

        -- Armes de mêlée compactes (tiennent dans une boîte à gant)
        "weapon_knife",        -- couteau de poche
        "weapon_switchblade",  -- cran d'arrêt
        "weapon_dagger",       -- dague
        "weapon_knuckle",      -- brass knuckles
        -- ✘ weapon_bat, weapon_crowbar, weapon_nightstick, weapon_hammer → trop grands

        -- Armes de poing & revolvers (compacts, holstérables)
        "weapon_pistol",       -- pistolet standard
        "weapon_combatpistol", -- pistolet compact
        "weapon_snspistol",    -- mini pistolet
        "weapon_pistol50",     -- Desert Eagle
        "weapon_revolver",     -- revolver .357 — très 80s
        -- ✘ weapon_smg, weapon_microsmg, weapon_pumpshotgun, weapon_rifle → trop grands

        -- Munitions légères
        "pistol_ammo", "revolver_ammo",

        -- Petites substances (thème Los Santos 1987)
        "cocaine_small", "weed_small", "weed_joint",

        -- Argent liquide
        "money_bag_small",
    },
}

-- ================================================================
-- BESOINS — Faim & Soif avec péremption
-- ================================================================
Config.Needs = {
    TickInterval       = 300000,  -- Décroissance toutes les 5 min (ms)
    HungerDecay        = 8,       -- Points de faim perdus par tick (sur 100)
    ThirstDecay        = 12,      -- Points de soif perdus par tick (soif baisse plus vite)
    StarveThreshold    = 20,      -- En dessous : debuffs (vision floue, marche lente)
    DehydrateThreshold = 20,
    IllnessDuration    = 120,     -- Durée de maladie après bouffe périmée (secondes)

    -- Épiceries sur la carte (1987 — Los Angeles)
    Shops = {
        { label = "Roy's Liquors",   coords = vector3(-47.4,  -1757.4, 29.4), blipColor = 2 },
        { label = "24/7 Superette",  coords = vector3(24.5,   -1347.3, 29.5), blipColor = 2 },
        { label = "Rob's Liquor",    coords = vector3(-2966.8, 390.5,  15.0), blipColor = 2 },
        { label = "Billards & Deli", coords = vector3(1161.3,  2710.7, 38.2), blipColor = 2 },
    },

    -- Items alimentaires : valeur nutritive + durée avant péremption (secondes réelles)
    -- expiresIn = 0 signifie que l'item n'expire pas
    Foods = {
        ["water"]     = { hunger = 0,  thirst = 35, expiresIn = 0        },  -- Eau en bouteille : n'expire pas
        ["cola"]      = { hunger = 0,  thirst = 25, expiresIn = 7776000  },  -- 90 jours (canette)
        ["beer"]      = { hunger = 5,  thirst = 20, expiresIn = 2592000  },  -- 30 jours
        ["juice"]     = { hunger = 0,  thirst = 30, expiresIn = 604800   },  -- 7 jours
        ["coffee"]    = { hunger = 5,  thirst = 25, expiresIn = 86400    },  -- 1 jour
        ["candy"]     = { hunger = 5,  thirst = 0,  expiresIn = 15552000 },  -- 180 jours
        ["chips"]     = { hunger = 10, thirst = 0,  expiresIn = 2592000  },  -- 30 jours
        ["donut"]     = { hunger = 15, thirst = 0,  expiresIn = 259200   },  -- 3 jours
        ["taco"]      = { hunger = 25, thirst = 0,  expiresIn = 86400    },  -- 1 jour
        ["hotdog"]    = { hunger = 30, thirst = 0,  expiresIn = 86400    },  -- 1 jour
        ["sandwich"]  = { hunger = 25, thirst = 5,  expiresIn = 172800   },  -- 2 jours
    },

    -- Catalogue de chaque épicerie (prix en $)
    ShopItems = {
        { name = "water",    price = 1  },
        { name = "cola",     price = 2  },
        { name = "beer",     price = 3  },
        { name = "juice",    price = 3  },
        { name = "coffee",   price = 3  },
        { name = "candy",    price = 1  },
        { name = "chips",    price = 2  },
        { name = "donut",    price = 2  },
        { name = "taco",     price = 4  },
        { name = "hotdog",   price = 4  },
        { name = "sandwich", price = 5  },
    },
}

-- ================================================================
-- CARBURANT — Stations essence
-- ================================================================
Config.Fuel = {
    DefaultFuel     = 100.0,  -- Carburant au spawn (%)
    MaxFuel         = 100.0,
    ConsumptionRate = 0.35,   -- % consommé par seconde à vitesse max (adaptatif selon RPM)
    PricePerUnit    = 2,      -- $ par unité
    LowFuelAlert    = 15.0,   -- Alerte sous ce seuil

    Stations = {
        { label = "Globe Oil — Vespucci",  coords = vector3(-701.5,  -934.7,  19.2) },
        { label = "Globe Oil — Downtown",  coords = vector3(265.8,   -1261.4, 29.3) },
        { label = "LTD Gasoline — East",   coords = vector3(817.1,   -1028.4, 26.4) },
        { label = "Globe Oil — Sandy",     coords = vector3(1784.8,  3330.2,  41.2) },
        { label = "Globe Oil — Paleto",    coords = vector3(-93.4,   6419.6,  31.5) },
    },
}

-- ================================================================
-- LOGEMENTS — Appartements à louer
-- ================================================================
Config.Housing = {
    StashSlots     = 20,
    StashMaxWeight = 50000,

    Apartments = {
        {
            id       = "apt_vespucci_01",
            label    = "Studio — Vespucci Beach",
            price    = 5000,    -- Achat/caution
            rent     = 500,     -- Loyer hebdomadaire (temps réel)
            exterior = vector3(-1138.0, -1520.0, 4.4),
            interior = vector3(260.0, -1007.0, -99.0),
            spawn    = vector3(260.3, -1007.0, -99.0),
            heading  = 0.0,
        },
        {
            id       = "apt_southls_01",
            label    = "Appartement — South LS",
            price    = 3500,
            rent     = 350,
            exterior = vector3(72.0, -1953.0, 21.1),
            interior = vector3(346.0, -1012.0, -99.0),
            spawn    = vector3(346.5, -1012.0, -99.0),
            heading  = 0.0,
        },
        {
            id       = "apt_strawberry_01",
            label    = "Appartement — Strawberry",
            price    = 4000,
            rent     = 400,
            exterior = vector3(148.5, -1698.0, 29.3),
            interior = vector3(346.0, -1012.0, -99.0),
            spawn    = vector3(346.5, -1012.0, -99.0),
            heading  = 0.0,
        },
        {
            id       = "apt_rockford_01",
            label    = "Appartement — Rockford Hills",
            price    = 15000,
            rent     = 1500,
            exterior = vector3(-768.0, 323.0, 85.7),
            interior = vector3(-786.0, 315.0, 217.6),
            spawn    = vector3(-785.5, 315.0, 217.6),
            heading  = 180.0,
        },
    },
}

-- ================================================================
-- CABINES TÉLÉPHONIQUES — Pas de portable en 1987
-- ================================================================
Config.Payphone = {
    InteractDist = 2.5,   -- Distance pour afficher le texte d'aide
    UseDist      = 1.5,   -- Distance pour utiliser
    CallCost     = 1,     -- $ par appel (prélevé au demandeur)

    -- Emplacements des cabines sur la carte
    Locations = {
        vector3(-101.4, -1304.0, 29.4),
        vector3(127.6,  -1291.4, 29.2),
        vector3(-547.3, -188.1,  38.2),
        vector3(1699.5, 4928.1,  42.1),
        vector3(-1223.0, -340.4, 37.8),
        vector3(373.4,   326.9,  103.6),
        vector3(-3.0,    -1440.0, 30.5),
        vector3(-558.2,  -1570.0, 27.2),
    },
}

-- ================================================================
-- ÉCONOMIE — TVA & Gouvernement
-- ================================================================
Config.Economy = {
    TVARate     = 0.15,   -- 15% TVA sur toutes les transactions commerciales
    GovJob      = "government",
    GovLocation = vector3(375.0, -594.8, 28.9),
    GovBlip     = { sprite=419, color=3, scale=0.9, label="Hôtel de Ville — Gouvernement" },
}

-- ================================================================
-- ENTREPRISES — Los Santos 1987
-- Chaque business = job dédié, caisse collectée par le gérant
-- ================================================================
Config.Businesses = {
    ["el_burro"] = {
        label    = "Restaurante El Burro",
        job      = "restaurant",
        location = vector3(1195.8, -1455.2, 34.9),
        blip     = { sprite=52,  color=5,  scale=0.8, label="El Burro — Restaurant" },
        till     = "business_till_el_burro",
        items    = {
            { name="burger", label="Burger Spécial",  price=8  },
            { name="water",  label="Agua Fria",       price=2  },
        },
    },
    ["sunset_deli"] = {
        label    = "Sunset Liquor & Deli",
        job      = "epicerie",
        location = vector3(24.5, -1346.5, 29.5),
        blip     = { sprite=52, color=2, scale=0.8, label="Sunset Deli — Épicerie" },
        till     = "business_till_sunset_deli",
        items    = {
            { name="water",  label="Eau minérale",  price=2  },
            { name="burger", label="Sandwich",      price=5  },
        },
    },
    ["fab_fashion"] = {
        label    = "Fab Fashion",
        job      = "boutique",
        location = vector3(-713.0, -152.7, 37.4),
        blip     = { sprite=73, color=8, scale=0.8, label="Fab Fashion — Vêtements" },
        till     = "business_till_fab_fashion",
        items    = {
            { name="clothing_voucher", label="Bon de tenue",  price=50  },
            { name="clothing_luxury",  label="Tenue luxe",    price=150 },
        },
    },
    ["chrome_dreams"] = {
        label    = "Chrome Dreams Auto",
        job      = "concessionnaire",
        location = vector3(-44.6, -1095.5, 26.4),
        blip     = { sprite=225, color=46, scale=0.8, label="Chrome Dreams — Concessionnaire" },
        till     = "business_till_chrome_dreams",
        items    = {
            { name="vehicle_key_vigero",   label="Clé Vigero 1969",   price=12000 },
            { name="vehicle_key_voodoo",   label="Clé Voodoo Custom", price=15000 },
            { name="vehicle_key_phoenix",  label="Clé Phoenix 1982",  price=9500  },
            { name="vehicle_key_gauntlet", label="Clé Gauntlet 1980", price=11000 },
        },
    },
    ["el_gato_negro"] = {
        label    = "El Gato Negro Bar",
        job      = "barman",
        location = vector3(-1083.4, -1398.9, 5.0),
        blip     = { sprite=93, color=4, scale=0.8, label="El Gato Negro — Bar" },
        till     = "business_till_el_gato_negro",
        items    = {
            { name="water",  label="Bière",    price=4  },
            { name="water",  label="Cocktail", price=8  },
            { name="water",  label="Whisky",   price=6  },
        },
    },
}
