# Cabalesque resources

## Player

1. Blue (player 1)
2. Red (player 2)

Player characters wear coloured overalls to make them easily distinguishable in multiplayer cooperative mode. The characters wear military webbing to hold ammunition clips and grenades.

### Control / Movement

* Fire weapon (lmb);
* Throw grenade (g);
* Stand (default);
* Crouch (crouch key - increases accuracy at the cost of mobility);
* Run L/R (A, D);
* Dive Roll L/R (Run L/R + prone key).

Items such as powerups and XP pickups are automatically collected by moving a character over the dropped item.

### Player Weapons

Weapons available to player characters have the following attributes:

* Type: The type/ name of the weapon. Except for the default weapon (assault rifle) all weapons are gained by destroying Cabal infantry, vehicles, and structures;
* Projectile: The type of projectile fired by the weapon;
* Rate of fire: All primary weapons are automatic fire, with varying rates of fire;
* Equip duration: Apart from the default weapon, weapons are only able to be equipped for a short duration. When the equip duration expires, the player character is assigned the default weapon again.

#### Primary Weapons

| Type | Projectile | Fire Rate | Equip Duration |
|---|---|---|---|
| Assault rifle | Bullet | 5/sec | Indefinite (default) |
| Shotgun | Bullet | 5x3/sec | 20 seconds |
| Minigun | Bullet | 10/sec | 15 seconds |
| Grenade Launcher | Grenade | 2/sec | 15 seconds |
| Rocket Launcher | Rocket | One-shot | One-shot

#### Secondary Weapons

Players start with three high-explosive hand grenades that detonate on impact. Additional grenades become available after defeating certain enemy units or destroying structures.

* Grenade

The Grenade applies the same effect as projectiles fired from the *Grenade Launcher* primary weapon.

### Projectiles

* Type: The type / name of the projectile
* Trigger class: What event causes the projectile to impart its result action
* Result class: *Hit* or *Blast* (all projectiles are using *blast* to support damage to all enemy types)
* Damage: The effect caused to objects in the projectile's area of effect on impact/
* Area of effect: Indicated by the size of the crosshair when using the weapon;
* Fired by: A list of the weapons that fire the projectile

| Type | Trigger | Result | Damage | Area of Effect | Fired by |
|---|---|---|---|---|---|
| Bullet | Impact | Blast | Low | Low | Assault Rifle, Shotgun, Minigun |
| Grenade | Impact | Blast | Medium | Medium | Grenade Launcher, Grenade |
| Rocket | Impact | Blast | High | High | Rocket Launcher |

## Cabal

### Infantry

* **Rifleman**:
The rifleman wears a long-sleeved, long-legged khaki uniform with black army boots, and carries a rifle that resembles an AK-47. This unit runs towards the player in a zig-zag fashion, pausing occasionally to fire a reasonably accurate, slow-moving, single shot in the direction of the player character before resuming. Riflemen will occasionally drop a *Grenade* cache or a small *XP* pickup.
  * **Covert Ops**:
  These units use cover heavily and wear a special black uniform to identify them as an elite unit within the Cabal. They carry a shotgun that fires an arc of three bullets in the player character's direction. Covert Operatives wear a bulletproof vest that protects against a single bullet impact. A second bullet impact wounds the unit and places him out of action until healed by a medic. Covert Ops units often drop a shotgun when defeated.
* **Grenadier**:
These characters move from one side of the screen to the other, stopping occasionally to throw a grenade directly at one of the player characters.
  * **Commando**:
  This unit is an advanced Grenadier, who wears a custom uniform to designate his role in the Cabal. The commando wears a bulletproof vest that protects against the first two bullet impacts. The third bullet to strike the commando causes him to fall to the ground, wounded, and out of action unless healed. The Commando often drops a grenade cache when defeated.
* **Medic**:
These unarmed units operate only to heal commandos who lie wounded on the battlefield.

### Cabal Projectiles

This section covers all objects fired by the Cabal forces.
Any projectile that makes direct contact with a player character results in that character being killed immediately, unless the character is performing a dive roll. Some projectiles apply damage to a blast area, as indicated by the size of the explosion effect created when the projectile detonates.

| Type | Speed | Size / Area of effect | Fired by |
|---|---|---|---|
| Bullet | Low | Low | Rifleman, Covert Ops, APC, Helicopter |
| Grenade | Medium | Low | Grenadier, Commando |
| Shell | Medium | Medium | Tank |
| Bomb | Medium | High | Jet |

### Cabal Vehicles

The Cabal has access to a number of armoured vehicles, detailed in the following sections.

#### Land vehicles

These appear from a screen edge, a moderate distance away from the player (at least half way up the screen) and drive 1/3 to 1/2 way across the screen before stopping, rotating their turret in the direction of the player characters and firing a single shot from the turret weapon. After firing, the vehicle repeats the drive/fire pattern until leaving via the opposite screen edge.

| Type | Speed | Weapon | Fire Rate | Ammunition | Armour |
|---|---|---|---|---|---|
| APC | Medium | 360-degree turret | Medium | High-calibre bullet | Low |
| Tank | Low | 360-degree turret | Low | Artillery shell | High |

In addition to performing the standard land vehicle actions, the **APC** releases 2-4 Riflemen from its rear door when stopping for the first time. APCs will often drop a *Grenade Launcher* when defeated.
**Tanks** are the most heavily armoured mobile unit the Cabal has available. If destroyed, they will drop a *Rocket Launcher*.

#### Air vehicles

These vehicles appear in the extreme distance before performing their scripted behaviours, detailed after the following specifications table.

| Type | Speed | Weapon | Fire Rate | Ammunition | Armour |
|---|---|---|---|---|---|
| Helicopter | Medium | Strafing Machine gun | High | Double bullet | Medium |
| Jet | High | Triple bomb | One-shot | High-explosive bomb | Low |

The **Helicopter** behaves similarly to a land vehicle, appearing from one screen edge (but in the air) and travelling a short distance before hovering and turning towards the player character. The helicopter fires its strafing machine gun in a line towards the player characters then repeats the behaviour until destroyed or leaving via the opposite screen edge. Helicopters drop a *Minigun* when defeated.
The **Jet** appears in the centre of the horizon and rapidly travels in a straight line towards the player characters. When almost overhead, the jet releases three bombs (one from right wing tip, one from fuselage, one from left wing tip) that fall directly down. The bombs explode on contact with the ground, or a player character if he has failed to evade the bomb. Jets drop a *Rocket Launcher* when destroyed.

### Cabal Structures

Inanimate structures act as entry, exit, and cover points for player and cabal units. Some structures serve to set the scene or indicate the boundaries of a mission and, thus, are indestructible. Others, however, are composed of multiple, destructible components. This allows larger structures to afford greater levels of protection and survivability than their smaller counterparts. Destructible components are rapidly identifiable because they begin to emit smoke or damage effect particles after being struck by a small number of projectiles. Individual components of structures will be destroyed when their health is depleted. See the below table for more information.

* **Building**:
Basic structures with primitive shapes. May be placed adjacent to each other to create a building that is several components wide and has differing heights. While individual building heights can differ, they cannot stack on top of each other. Buildings will often drop either a medium or high *XP* pickup item when destroyed, depending on the size of the building;
* **Wall**:
Very similar to building structures, but they have very little depth. Some wall units can be seen (and fired) through in places, such as ruins of a building wall where windows may have been. Walls occasionally drop a small or medium *XP* pickup when destroyed.
* **Parked vehicles**:
This group includes cars, trucks, bulldozers, planes, etc. that are relevant to the map currently being played. They are generally located in the second third split into three sections (front, mid, back). Each section of a parked vehicle has a chance to drop a medium *XP* pickup when destroyed;
* **Watchtower**:
Often found far in the distance, these structures may hold a single Rifleman, who acts as a sniper from the top of the tower. When destroyed, Watchtowers will often drop a medium *XP* pickup item.

## Maps

Four missions, each having four stages. Final stage of each mission ends with a boss fight against a heavily-armoured vehicle with multiple turrets.
