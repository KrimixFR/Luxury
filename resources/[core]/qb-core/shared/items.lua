-- ================================================================
-- QBCore Shared Items — Los Santos 1987
-- ================================================================

QBShared = QBShared or {}
QBShared.Items = {
    -- Argent & documents
    ['id_card']         = { name='id_card',         label='Carte d\'identité',   weight=10,  type='item', image='id_card.png',         useable=false, shouldClose=false, combinable=nil, description='Pièce d\'identité officielle' },
    ['phone']           = { name='phone',            label='Pager',               weight=100, type='item', image='phone.png',           useable=true,  shouldClose=true,  combinable=nil, description='Biper Motorola Advisor' },
    ['money']           = { name='money',            label='Argent liquide',      weight=0,   type='item', image='money.png',           useable=false, shouldClose=false, combinable=nil, description='Billets de banque' },

    -- Médical
    ['bandage']         = { name='bandage',          label='Bandage',             weight=100, type='item', image='bandage.png',         useable=true,  shouldClose=true,  combinable=nil, description='Pansement d\'urgence' },
    ['firstaid']        = { name='firstaid',         label='Trousse de soins',    weight=300, type='item', image='firstaid.png',        useable=true,  shouldClose=true,  combinable=nil, description='Trousse de premiers secours' },

    -- Drogues — matières premières
    ['cocaine_brick']   = { name='cocaine_brick',    label='Briquette de cocaïne',weight=500, type='item', image='cocaine_brick.png',   useable=false, shouldClose=false, combinable=nil, description='Cocaïne brute non traitée' },
    ['weed_leaf']       = { name='weed_leaf',        label='Feuille de cannabis', weight=100, type='item', image='weed_leaf.png',       useable=false, shouldClose=false, combinable=nil, description='Feuilles de cannabis fraîches' },
    ['pcp_ingredient']  = { name='pcp_ingredient',   label='Produit chimique',    weight=200, type='item', image='pcp_ingredient.png',  useable=false, shouldClose=false, combinable=nil, description='Précurseur chimique pour PCP' },

    -- Drogues — produits traités
    ['crack_baggie']    = { name='crack_baggie',     label='Crack',               weight=50,  type='item', image='crack_baggie.png',    useable=true,  shouldClose=true,  combinable=nil, description='Dose de crack prête à vendre' },
    ['coke_baggie']     = { name='coke_baggie',      label='Cocaïne',             weight=50,  type='item', image='coke_baggie.png',     useable=true,  shouldClose=true,  combinable=nil, description='Sachet de cocaïne pure' },
    ['weed_baggie']     = { name='weed_baggie',      label='Weed',                weight=50,  type='item', image='weed_baggie.png',     useable=true,  shouldClose=true,  combinable=nil, description='Sachet de marijuana' },
    ['pcp_baggie']      = { name='pcp_baggie',       label='PCP',                 weight=50,  type='item', image='pcp_baggie.png',      useable=true,  shouldClose=true,  combinable=nil, description='Angel Dust — très dangereux' },

    -- Armes et munitions
    ['pistol_ammo']     = { name='pistol_ammo',      label='Munitions pistolet',  weight=20,  type='ammo', image='pistol_ammo.png',     useable=false, shouldClose=false, combinable=nil, description='9mm' },
    ['shotgun_ammo']    = { name='shotgun_ammo',     label='Cartouches fusil',    weight=40,  type='ammo', image='shotgun_ammo.png',    useable=false, shouldClose=false, combinable=nil, description='Calibre 12' },
    ['smg_ammo']        = { name='smg_ammo',         label='Munitions SMG',       weight=25,  type='ammo', image='smg_ammo.png',        useable=false, shouldClose=false, combinable=nil, description='9mm SMG' },
    ['rifle_ammo']      = { name='rifle_ammo',       label='Munitions fusil',     weight=30,  type='ammo', image='rifle_ammo.png',      useable=false, shouldClose=false, combinable=nil, description='5.56mm' },

    -- Armes
    ['weapon_pistol']        = { name='weapon_pistol',        label='Pistolet',      weight=500, type='weapon', image='weapon_pistol.png',        useable=false, shouldClose=false, combinable=nil, description='Pistolet semi-automatique' },
    ['weapon_combatpistol']  = { name='weapon_combatpistol',  label='Pistolet Combat',weight=600,type='weapon', image='weapon_combatpistol.png',  useable=false, shouldClose=false, combinable=nil, description='Pistolet de combat' },
    ['weapon_pumpshotgun']   = { name='weapon_pumpshotgun',   label='Fusil à pompe', weight=900, type='weapon', image='weapon_pumpshotgun.png',   useable=false, shouldClose=false, combinable=nil, description='Fusil à pompe 12 gauge' },
    ['weapon_nightstick']    = { name='weapon_nightstick',    label='Matraque',      weight=400, type='weapon', image='weapon_nightstick.png',    useable=false, shouldClose=false, combinable=nil, description='Matraque de police' },
    ['weapon_smg']           = { name='weapon_smg',           label='SMG',           weight=800, type='weapon', image='weapon_smg.png',           useable=false, shouldClose=false, combinable=nil, description='Pistolet mitrailleur' },
    ['weapon_carbinerifle']  = { name='weapon_carbinerifle',  label='Carabine',      weight=1200,type='weapon', image='weapon_carbinerifle.png',  useable=false, shouldClose=false, combinable=nil, description='Carabine M4' },
    ['weapon_knife']         = { name='weapon_knife',         label='Couteau',       weight=200, type='weapon', image='weapon_knife.png',         useable=false, shouldClose=false, combinable=nil, description='Couteau de combat' },

    -- Police
    ['evidence_bag']    = { name='evidence_bag',     label='Sac à preuves',       weight=100, type='item', image='evidence_bag.png',    useable=false, shouldClose=false, combinable=nil, description='Sac à preuves LAPD scellé' },
    ['handcuffs']       = { name='handcuffs',        label='Menottes',            weight=100, type='item', image='handcuffs.png',       useable=true,  shouldClose=true,  combinable=nil, description='Menottes en acier' },

    -- Alimentaire / pêche
    ['fish']            = { name='fish',             label='Poisson',             weight=300, type='item', image='fish.png',            useable=true,  shouldClose=true,  combinable=nil, description='Poisson frais pêché' },
    ['burger']          = { name='burger',           label='Hamburger',           weight=200, type='item', image='burger.png',          useable=true,  shouldClose=true,  combinable=nil, description='Nourriture' },
    ['water']           = { name='water',            label='Eau',                 weight=100, type='item', image='water.png',           useable=true,  shouldClose=true,  combinable=nil, description='Bouteille d\'eau' },
}
