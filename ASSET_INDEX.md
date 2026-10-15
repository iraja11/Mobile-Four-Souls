# Four Souls Mobile — Asset Index

_Generated 2026-10-15. Machine-readable companion: `asset_index.json`._

This index catalogs the art/asset folders an AI or developer needs to build the
mobile adaptation of **The Binding of Isaac: Four Souls**. Every entry maps a
normalized **name** to the literal **file path** on disk.

## How to use
- **Look up a card by name** → jump to the set section, or grep `asset_index.json` for `"name"`.
- **Look up a file** → every record has `file` (exact on-disk path).
- **Find an item (dice, table, hearts, coins)** → see the *Items & TTS Images* section.
- `copy` / `same_as` flags mark multiple physical copies of the same card art.
- `subkind` (Monsters/Rooms/Loot) is a best-effort guess; filenames do not encode card type.

## Folder map

```
FOUR SOULS MOBILE/
├─ 1-Core Sets/            # card art, grouped by set and card type
├─ 2-Promotional Sets/     # (not indexed yet)
├─ 3-Extras/               # blanks, errata, key-terms cards
├─ 4-Card Backs/           # print-ready card backs + v6 experimental
├─ game/                   # Godot 4 prototype (main.gd, cards/)
├─ tts mod import/         # prebuilt Flutter app 'tts_mod_vault'
├─ tts/Mods/Images/        # TTS props: dice, table, hearts, coins, deck sheets
├─ tts/Mods/Models/        # 3D coin model (.obj)
├─ tts/Mods/PDF/           # rules / print PDFs
├─ tts/Mods/Workshop/      # TTS save + Steam preview
└─ doc base.pdf, main.pdf  # rules docs
```

## Summary

| Group | Count |
|---|---|
| 1-Base Game V2 | 340 |
| 2-Four Souls+ V2 | 98 |
| 3-Requiem | 272 |
| 4-Summer of Isaac | 50 |
| 5-Anniversary Booster Pack | 20 |
| **Core set cards total** | **780** |
| Card backs | 21 |
| TTS images | 197 |

TTS images by kind: board 1, deck_sheet 183, dice 6, mat 1, model_texture 1, other 2, token 3

---

## 1-Base Game V2

Path: `1-Core Sets/1-Base Game V2/` — 340 cards.
Set icon: `1-Core Sets/1-Base Game V2/X-SetIcon.png`

| Category | Type | Count |
|---|---|---|
| 1-Characters | Character | 11 |
| 2-Starting Items | Starting Item | 10 |
| 3-Treasure | Treasure | 105 |
| 4-Loot | Loot | 104 |
| 5-Monsters | Monster / Boss / Happening | 107 |
| 7-Bonus Souls | Bonus Soul | 3 |

### 1-Characters — Character (11)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Isaac | `1-Isaac.jpg` |  |  |
| The Forgotten | `10-The Forgotten.jpg` |  |  |
| Eden | `11-Eden.jpg` |  |  |
| Maggy | `2-Maggy.jpg` |  |  |
| Cain | `3-Cain.jpg` |  |  |
| Judas | `4-Judas.jpg` |  |  |
| Blue Baby | `5-Blue Baby.jpg` |  |  |
| Eve | `6-Eve.jpg` |  |  |
| Samson | `7-Samson.jpg` |  |  |
| Lazarus | `8-Lazarus.jpg` |  |  |
| Lilith | `9-Lilith.jpg` |  |  |

### 2-Starting Items — Starting Item (10)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| The D6 | `1-The D6.jpg` |  |  |
| The Bone | `10-The Bone.jpg` |  |  |
| Yum Heart | `2-Yum Heart.jpg` |  |  |
| Sleight of Hand | `3-Sleight of Hand.jpg` |  |  |
| Book of Belial | `4-Book of Belial.jpg` |  |  |
| Forever Alone | `5-Forever Alone.jpg` |  |  |
| The Curse | `6-The Curse.jpg` |  |  |
| Blood Lust | `7-Blood Lust.jpg` |  |  |
| Lazarus' Rags | `8-Lazarus_ Rags.jpg` |  |  |
| Incubus | `9-Incubus.jpg` |  |  |

### 3-Treasure — Treasure (105)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Baby Haunt | `Baby Haunt.jpg` |  |  |
| Battery Bum | `Battery Bum.jpg` |  |  |
| Belly Button | `Belly Button.jpg` |  |  |
| Blank Card | `Blank Card.jpg` |  |  |
| Bob's Brain | `Bob_s Brain.jpg` |  |  |
| Book of Sin | `Book of Sin.jpg` |  |  |
| Boomerang | `Boomerang.jpg` |  |  |
| Box! | `Box!.jpg` |  |  |
| Breakfast | `Breakfast.jpg` |  |  |
| Brimstone | `Brimstone.jpg` |  |  |
| Bum Friend | `Bum Friend.jpg` |  |  |
| Bum-Bo! | `Bum-Bo!.jpg` |  |  |
| Cambion Conception | `Cambion Conception.jpg` |  |  |
| Champion Belt | `Champion Belt.jpg` |  |  |
| Chaos Card | `Chaos Card.jpg` |  |  |
| Chaos | `Chaos.jpg` |  |  |
| Charged Baby | `Charged Baby.jpg` |  |  |
| Cheese Grater | `Cheese Grater.jpg` |  |  |
| Compost | `Compost.jpg` |  |  |
| Contract from Below | `Contract from Below.jpg` |  |  |
| Crystal Ball | `Crystal Ball.jpg` |  |  |
| Curse of the Tower | `Curse of the Tower.jpg` |  |  |
| Dad's Lost Coin | `Dad_s Lost Coin.jpg` |  |  |
| Daddy Haunt | `Daddy Haunt.jpg` |  |  |
| Dark Bum | `Dark Bum.jpg` |  |  |
| Dead Bird | `Dead Bird.jpg` |  |  |
| Decoy | `Decoy.jpg` |  |  |
| Dinner | `Dinner.jpg` |  |  |
| Diplopia | `Diplopia.jpg` |  |  |
| Donation Machine | `Donation Machine.jpg` |  |  |
| Dry Baby | `Dry Baby.jpg` |  |  |
| Eden's Blessing | `Eden_s Blessing.jpg` |  |  |
| Empty Vessel | `Empty Vessel.jpg` |  |  |
| Eye of Greed | `Eye of Greed.jpg` |  |  |
| Fanny Pack | `Fanny Pack.jpg` |  |  |
| Finger | `Finger.jpg` |  |  |
| Flush! | `Flush!.jpg` |  |  |
| Glass Canon | `Glass Canon.jpg` |  |  |
| Goat Head | `Goat Head.jpg` |  |  |
| Godhead | `Godhead.jpg` |  |  |
| Golden Razor Blade | `Golden Razor Blade.jpg` |  |  |
| Greed's Gullet | `Greed_s Gullet.jpg` |  |  |
| Guppy's Collar | `Guppy_s Collar.jpg` |  |  |
| Guppy's Head | `Guppy_s Head.jpg` |  |  |
| Guppy's Paw | `Guppy_s Paw.jpg` |  |  |
| Host Hat | `Host Hat.jpg` |  |  |
| Ipecac | `Ipecac.jpg` |  |  |
| Jawbone | `Jawbone.jpg` |  |  |
| Lucky Foot | `Lucky Foot.jpg` |  |  |
| Meat! | `Meat!.jpg` |  |  |
| Mini Mush | `Mini Mush.jpg` |  |  |
| Modeling Clay | `Modeling Clay.jpg` |  |  |
| Mom's Box | `Mom_s Box.jpg` |  |  |
| Mom's Bra | `Mom_s Bra.jpg` |  |  |
| Mom's Coin Purse | `Mom_s Coin Purse.jpg` |  |  |
| Mom's Purse | `Mom_s Purse.jpg` |  |  |
| Mom's Razor | `Mom_s Razor.jpg` |  |  |
| Mom's Shovel | `Mom_s Shovel.jpg` |  |  |
| Monster Manual | `Monster Manual.jpg` |  |  |
| Monstro's Tooth | `Monstro_s Tooth.jpg` |  |  |
| Mr. Boom | `Mr. Boom.jpg` |  |  |
| Mystery Sack | `Mystery Sack.jpg` |  |  |
| No! | `No!.jpg` |  |  |
| Pandora's Box | `Pandora_s Box.jpg` |  |  |
| Pay to Play | `Pay to Play.jpg` |  |  |
| Placebo | `Placebo.jpg` |  |  |
| Polydactyly | `Polydactyly.jpg` |  |  |
| Portable Slot Machine | `Portable Slot Machine.jpg` |  |  |
| Potato Peeler | `Potato Peeler.jpg` |  |  |
| Razor Blade | `Razor Blade.jpg` |  |  |
| Remote Detonator | `Remote Detonator.jpg` |  |  |
| Restock | `Restock.jpg` |  |  |
| Sack Head | `Sack Head.jpg` |  |  |
| Sack of Pennies | `Sack of Pennies.jpg` |  |  |
| Sacred Heart | `Sacred Heart.jpg` |  |  |
| Shadow | `Shadow.jpg` |  |  |
| Shiny Rock | `Shiny Rock.jpg` |  |  |
| Smelter | `Smelter.jpg` |  |  |
| Spider Mod | `Spider Mod.jpg` |  |  |
| Spoon Bender | `Spoon Bender.jpg` |  |  |
| Starter Deck | `Starter Deck.jpg` |  |  |
| Steamy Sale | `Steamy Sale.jpg` |  |  |
| Suicide King | `Suicide King.jpg` |  |  |
| Synthoil | `Synthoil.jpg` |  |  |
| Tarot Cloth | `Tarot Cloth.jpg` |  |  |
| Tech X | `Tech X.jpg` |  |  |
| The Battery | `The Battery.jpg` |  |  |
| The Blue Map | `The Blue Map.jpg` |  |  |
| The Chest | `The Chest.jpg` |  |  |
| The Compass | `The Compass.jpg` |  |  |
| The D10 | `The D10.jpg` |  |  |
| The D100 | `The D100.jpg` |  |  |
| The D20 | `The D20.jpg` |  |  |
| The D4 | `The D4.jpg` |  |  |
| The Dead Cat | `The Dead Cat.jpg` |  |  |
| The Habit | `The Habit.jpg` |  |  |
| The Map | `The Map.jpg` |  |  |
| The Midas Touch | `The Midas Touch.jpg` |  |  |
| The Polaroid | `The Polaroid.jpg` |  |  |
| The Poop | `The Poop.jpg` |  |  |
| The Relic | `The Relic.jpg` |  |  |
| The Shovel | `The Shovel.jpg` |  |  |
| There's Options | `There_s Options.jpg` |  |  |
| Trinity Shield | `Trinity Shield.jpg` |  |  |
| Two of Clubs | `Two of Clubs.jpg` |  |  |

### 4-Loot — Loot (104)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| A Dime!! | `A Dime!!.jpg` | Coin |  |
| A Nickel | `A Nickel 2.jpg` | Coin | 2 |
| A Nickel | `A Nickel 3.jpg` | Coin | 3 |
| A Nickel | `A Nickel 4.jpg` | Coin | 4 |
| A Nickel | `A Nickel 5.jpg` | Coin | 5 |
| A Nickel | `A Nickel.jpg` | Coin |  |
| A Penny | `A Penny 2.jpg` | Coin | 2 |
| A Penny | `A Penny 3.jpg` | Coin | 3 |
| A Penny | `A Penny 4.jpg` | Coin | 4 |
| A Penny | `A Penny 5.jpg` | Coin | 5 |
| A Penny | `A Penny 6.jpg` | Coin | 6 |
| A Penny | `A Penny.jpg` | Coin |  |
| Blank Rune | `Blank Rune.jpg` | Rune |  |
| Bloody Penny | `Bloody Penny.jpg` | Coin |  |
| Bomb | `Bomb 2.jpg` | Bomb | 2 |
| Bomb | `Bomb 3.jpg` | Bomb | 3 |
| Bomb | `Bomb 4.jpg` | Bomb | 4 |
| Bomb | `Bomb.jpg` | Bomb |  |
| Broken Ankh | `Broken Ankh.jpg` | Trinket / Other |  |
| Butter Bean | `Butter Bean 2.jpg` | Trinket / Other | 2 |
| Butter Bean | `Butter Bean 3.jpg` | Trinket / Other | 3 |
| Butter Bean | `Butter Bean.jpg` | Trinket / Other |  |
| Cain's Eye | `Cain_s Eye.jpg` | Trinket / Other |  |
| Counterfeit Penny | `Counterfeit Penny.jpg` | Coin |  |
| Curved Horn | `Curved Horn.jpg` | Trinket / Other |  |
| Dagaz | `Dagaz.jpg` | Rune |  |
| Dice Shard | `Dice Shard 2.jpg` | Trinket / Other | 2 |
| Dice Shard | `Dice Shard 3.jpg` | Trinket / Other | 3 |
| Dice Shard | `Dice Shard.jpg` | Trinket / Other |  |
| Ehwaz | `Ehwaz.jpg` | Rune |  |
| Four Cents | `Four Cents 2.jpg` | Coin | 2 |
| Four Cents | `Four Cents 3.jpg` | Coin | 3 |
| Four Cents | `Four Cents 4.jpg` | Coin | 4 |
| Four Cents | `Four Cents 5.jpg` | Coin | 5 |
| Four Cents | `Four Cents 6.jpg` | Coin | 6 |
| Four Cents | `Four Cents 7.jpg` | Coin | 7 |
| Four Cents | `Four Cents 8.jpg` | Coin | 8 |
| Four Cents | `Four Cents 9.jpg` | Coin | 9 |
| Four Cents | `Four Cents.jpg` | Coin |  |
| Gold Bomb!! | `Gold Bomb!!.jpg` | Bomb |  |
| Golden Horseshoe | `Golden Horseshoe.jpg` | Trinket / Other |  |
| Guppy's Hairball | `Guppy_s Hairball.jpg` | Trinket / Other |  |
| I. The Magician | `I. The Magician.jpg` | Tarot Card |  |
| II. The High Priestess | `II. The High Priestess.jpg` | Tarot Card |  |
| III. The Empress | `III. The Empress.jpg` | Tarot Card |  |
| IV. The Emperor | `IV. The Emperor.jpg` | Tarot Card |  |
| IX. The Hermit | `IX. The Hermit.jpg` | Tarot Card |  |
| Lil Battery | `Lil Battery 2.jpg` | Battery | 2 |
| Lil Battery | `Lil Battery 3.jpg` | Battery | 3 |
| Lil Battery | `Lil Battery 4.jpg` | Battery | 4 |
| Lil Battery | `Lil Battery.jpg` | Battery |  |
| Lost Soul | `Lost Soul.jpg` | Trinket / Other |  |
| Mega Battery | `Mega Battery.jpg` | Battery |  |
| O. The Fool | `O. The Fool.jpg` | Tarot Card |  |
| Pills! (Blue) | `Pills! (Blue).jpg` | Pill |  |
| Pills! (Orange) | `Pills! (Orange).jpg` | Pill |  |
| Pills! (Red) | `Pills! (Red).jpg` | Pill |  |
| Purple Heart | `Purple Heart.jpg` | Heart |  |
| Soul Heart | `Soul Heart 2.jpg` | Heart | 2 |
| Soul Heart | `Soul Heart.jpg` | Heart |  |
| Swallowed Penny | `Swallowed Penny.jpg` | Coin |  |
| Three Cents | `Three Cents 10.jpg` | Coin | 10 |
| Three Cents | `Three Cents 11.jpg` | Coin | 11 |
| Three Cents | `Three Cents 12.jpg` | Coin | 12 |
| Three Cents | `Three Cents 13.jpg` | Coin | 13 |
| Three Cents | `Three Cents 14.jpg` | Coin | 14 |
| Three Cents | `Three Cents 15.jpg` | Coin | 15 |
| Three Cents | `Three Cents 2.jpg` | Coin | 2 |
| Three Cents | `Three Cents 3.jpg` | Coin | 3 |
| Three Cents | `Three Cents 4.jpg` | Coin | 4 |
| Three Cents | `Three Cents 5.jpg` | Coin | 5 |
| Three Cents | `Three Cents 6.jpg` | Coin | 6 |
| Three Cents | `Three Cents 7.jpg` | Coin | 7 |
| Three Cents | `Three Cents 8.jpg` | Coin | 8 |
| Three Cents | `Three Cents 9.jpg` | Coin | 9 |
| Three Cents | `Three Cents.jpg` | Coin |  |
| Two Cents | `Two Cents 10.jpg` | Coin | 10 |
| Two Cents | `Two Cents 11.jpg` | Coin | 11 |
| Two Cents | `Two Cents 12.jpg` | Coin | 12 |
| Two Cents | `Two Cents 2.jpg` | Coin | 2 |
| Two Cents | `Two Cents 3.jpg` | Coin | 3 |
| Two Cents | `Two Cents 4.jpg` | Coin | 4 |
| Two Cents | `Two Cents 5.jpg` | Coin | 5 |
| Two Cents | `Two Cents 6.jpg` | Coin | 6 |
| Two Cents | `Two Cents 7.jpg` | Coin | 7 |
| Two Cents | `Two Cents 8.jpg` | Coin | 8 |
| Two Cents | `Two Cents 9.jpg` | Coin | 9 |
| Two Cents | `Two Cents.jpg` | Coin |  |
| V. The Hierophant | `V. The Hierophant.jpg` | Tarot Card |  |
| VI. The Lovers | `VI. The Lovers.jpg` | Tarot Card |  |
| VII. The Chariot | `VII. The Chariot.jpg` | Tarot Card |  |
| VIII. Justice | `VIII. Justice.jpg` | Tarot Card |  |
| X. Wheel of Fortune | `X. Wheel of Fortune.jpg` | Tarot Card |  |
| XI. Strength | `XI. Strength.jpg` | Tarot Card |  |
| XII. The Hanged Man | `XII. The Hanged Man.jpg` | Tarot Card |  |
| XIII. Death | `XIII. Death.jpg` | Tarot Card |  |
| XIV. Temperance | `XIV. Temperance.jpg` | Tarot Card |  |
| XIX. The Sun | `XIX. The Sun.jpg` | Tarot Card |  |
| XV. The Devil | `XV. The Devil.jpg` | Tarot Card |  |
| XVI. The Tower | `XVI. The Tower.jpg` | Tarot Card |  |
| XVII. The Stars | `XVII. The Stars.jpg` | Tarot Card |  |
| XVIII. The Moon | `XVIII. The Moon.jpg` | Tarot Card |  |
| XX. Judgement | `XX. Judgement.jpg` | Tarot Card |  |
| XXI. The World | `XXI. The World.jpg` | Tarot Card |  |

### 5-Monsters — Monster / Boss / Happening (107)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Ambush | `Ambush.jpg` | Monster / Boss |  |
| Big Spider | `Big Spider.jpg` | Monster / Boss |  |
| Black Bony | `Black Bony.jpg` | Monster / Boss |  |
| Boom Fly | `Boom Fly.jpg` | Monster / Boss |  |
| Carrion Queen | `Carrion Queen.jpg` | Monster / Boss |  |
| Chest | `Chest 1.jpg` | Chest | 1 |
| Chest | `Chest 2.jpg` | Chest | 2 |
| Chub | `Chub.jpg` | Monster / Boss |  |
| Clotty | `Clotty.jpg` | Monster / Boss |  |
| Cod Worm | `Cod Worm.jpg` | Monster / Boss |  |
| Conjoined Fatty | `Conjoined Fatty.jpg` | Monster / Boss |  |
| Conquest | `Conquest.jpg` | Monster / Boss |  |
| Curse of Amnesia | `Curse of Amnesia.jpg` | Curse |  |
| Curse of Greed | `Curse of Greed.jpg` | Curse |  |
| Curse of Loss | `Curse of Loss.jpg` | Curse |  |
| Curse of Pain | `Curse of Pain.jpg` | Curse |  |
| Curse of the Blind | `Curse of the Blind.jpg` | Curse |  |
| Cursed Chest | `Cursed Chest.jpg` | Chest |  |
| Cursed Fatty | `Cursed Fatty.jpg` | Monster / Boss |  |
| Cursed Gaper | `Cursed Gaper.jpg` | Monster / Boss |  |
| Cursed Horf | `Cursed Horf.jpg` | Monster / Boss |  |
| Cursed Keeper Head | `Cursed Keeper Head.jpg` | Monster / Boss |  |
| Cursed Mom's Hand | `Cursed Mom_s Hand.jpg` | Monster / Boss |  |
| Cursed Psy Horf | `Cursed Psy Horf.jpg` | Monster / Boss |  |
| Daddy Long Legs | `Daddy Long Legs.jpg` | Monster / Boss |  |
| Dank Globin | `Dank Globin.jpg` | Monster / Boss |  |
| Dark Chest | `Dark Chest 1.jpg` | Chest | 1 |
| Dark Chest | `Dark Chest 2.jpg` | Chest | 2 |
| Dark One | `Dark One.jpg` | Monster / Boss |  |
| Death | `Death.jpg` | Monster / Boss |  |
| Delirium | `Delirium.jpg` | Monster / Boss |  |
| Devil Deal | `Devil Deal.jpg` | Happening / Event |  |
| Dinga | `Dinga.jpg` | Monster / Boss |  |
| Dip | `Dip.jpg` | Monster / Boss |  |
| Dople | `Dople.jpg` | Monster / Boss |  |
| Envy | `Envy.jpg` | Monster / Boss |  |
| Evil Twin | `Evil Twin.jpg` | Monster / Boss |  |
| Famine | `Famine.jpg` | Monster / Boss |  |
| Fat Bat | `Fat Bat.jpg` | Monster / Boss |  |
| Fatty | `Fatty.jpg` | Monster / Boss |  |
| Fly | `Fly.jpg` | Monster / Boss |  |
| Gemini | `Gemini.jpg` | Monster / Boss |  |
| Gluttony | `Gluttony.jpg` | Monster / Boss |  |
| Gold Chest | `Gold Chest 1.jpg` | Chest | 1 |
| Gold Chest | `Gold Chest 2.jpg` | Chest | 2 |
| Greed! | `Greed!.jpg` | Monster / Boss |  |
| Greed | `Greed.jpg` | Monster / Boss |  |
| Greedling | `Greedling.jpg` | Monster / Boss |  |
| Gurdy Jr. | `Gurdy Jr..jpg` | Monster / Boss |  |
| Gurdy | `Gurdy.jpg` | Monster / Boss |  |
| Hanger | `Hanger.jpg` | Monster / Boss |  |
| Holy Dinga | `Holy Dinga.jpg` | Monster / Boss |  |
| Holy Dip | `Holy Dip.jpg` | Monster / Boss |  |
| Holy Keeper Head | `Holy Keeper Head.jpg` | Monster / Boss |  |
| Holy Mom's Eye | `Holy Mom_s Eye.jpg` | Monster / Boss |  |
| Holy Squirt | `Holy Squirt.jpg` | Monster / Boss |  |
| Hopper | `Hopper.jpg` | Monster / Boss |  |
| Horf | `Horf.jpg` | Monster / Boss |  |
| I Can See Forever! | `I Can See Forever!.jpg` | Happening / Event |  |
| Keeper Head | `Keeper Head.jpg` | Monster / Boss |  |
| Larry Jr. | `Larry Jr..jpg` | Monster / Boss |  |
| Leaper | `Leaper.jpg` | Monster / Boss |  |
| Leech | `Leech.jpg` | Monster / Boss |  |
| Little Horn | `Little Horn.jpg` | Monster / Boss |  |
| Lust | `Lust.jpg` | Monster / Boss |  |
| Mask of Infamy | `Mask of Infamy.jpg` | Monster / Boss |  |
| Mega Fatty | `Mega Fatty.jpg` | Monster / Boss |  |
| Mega Troll Bomb! | `Mega Troll Bomb!.jpg` | Happening / Event |  |
| Mom! | `Mom!.jpg` | Monster / Boss |  |
| Mom's Dead Hand | `Mom_s Dead Hand.jpg` | Monster / Boss |  |
| Mom's Eye | `Mom_s Eye.jpg` | Monster / Boss |  |
| Mom's Hand | `Mom_s Hand.jpg` | Monster / Boss |  |
| Monstro | `Monstro.jpg` | Monster / Boss |  |
| Mulliboom | `Mulliboom.jpg` | Monster / Boss |  |
| Mulligan | `Mulligan.jpg` | Monster / Boss |  |
| Pale Fatty | `Pale Fatty.jpg` | Monster / Boss |  |
| Peep | `Peep.jpg` | Monster / Boss |  |
| Pestilence | `Pestilence.jpg` | Monster / Boss |  |
| Pin | `Pin.jpg` | Monster / Boss |  |
| Pooter | `Pooter.jpg` | Monster / Boss |  |
| Portal | `Portal.jpg` | Monster / Boss |  |
| Pride | `Pride.jpg` | Monster / Boss |  |
| Psy Horf | `Psy Horf.jpg` | Monster / Boss |  |
| Rag Man | `Rag Man.jpg` | Monster / Boss |  |
| Rage Creep | `Rage Creep.jpg` | Monster / Boss |  |
| Red Host | `Red Host.jpg` | Monster / Boss |  |
| Ring of Flies | `Ring of Flies.jpg` | Monster / Boss |  |
| Satan! | `Satan!.jpg` | Monster / Boss |  |
| Scolex | `Scolex.jpg` | Monster / Boss |  |
| Secret Room! | `Secret Room!.jpg` | Happening / Event |  |
| Shop Upgrade! | `Shop Upgrade!.jpg` | Happening / Event |  |
| Sloth | `Sloth.jpg` | Monster / Boss |  |
| Spider | `Spider.jpg` | Monster / Boss |  |
| Squirt | `Squirt.jpg` | Monster / Boss |  |
| Stoney | `Stoney.jpg` | Monster / Boss |  |
| Swarm of Flies | `Swarm of Flies.jpg` | Monster / Boss |  |
| The Bloat | `The Bloat.jpg` | Monster / Boss |  |
| The Duke of Flies | `The Duke of Flies.jpg` | Monster / Boss |  |
| The Haunt | `The Haunt.jpg` | Monster / Boss |  |
| The Lamb | `The Lamb.jpg` | Monster / Boss |  |
| Trite | `Trite.jpg` | Monster / Boss |  |
| Troll Bombs | `Troll Bombs.jpg` | Happening / Event |  |
| War | `War.jpg` | Monster / Boss |  |
| We Need To Go Deeper! | `We Need To Go Deeper!.jpg` | Happening / Event |  |
| Wizoob | `Wizoob.jpg` | Monster / Boss |  |
| Wrath | `Wrath.jpg` | Monster / Boss |  |
| XL Floor! | `XL Floor!.jpg` | Happening / Event |  |

### 7-Bonus Souls — Bonus Soul (3)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Soul of Gluttony | `Soul of Gluttony.jpg` |  |  |
| Soul of Greed | `Soul of Greed.jpg` |  |  |
| Soul of Guppy | `Soul of Guppy.jpg` |  |  |

---

## 2-Four Souls+ V2

Path: `1-Core Sets/2-Four Souls+ V2/` — 98 cards.
Set icon: `1-Core Sets/2-Four Souls+ V2/X-SetIcon.png`

| Category | Type | Count |
|---|---|---|
| 1-Characters | Character | 4 |
| 2-Starting Items | Starting Item | 4 |
| 3-Treasure | Treasure | 30 |
| 4-Loot | Loot | 30 |
| 5-Monsters | Monster / Boss / Happening | 30 |

### 1-Characters — Character (4)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Bum-Bo | `1-Bum-Bo.jpg` |  |  |
| Dark Judas | `2-Dark Judas.jpg` |  |  |
| Guppy | `3-Guppy.jpg` |  |  |
| Whore of Babylon | `4-Whore of Babylon.jpg` |  |  |

### 2-Starting Items — Starting Item (4)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Bag-o-Trash | `1-Bag-o-Trash.jpg` |  |  |
| Dark Arts | `2-Dark Arts.jpg` |  |  |
| Infestation | `3-Infestation.jpg` |  |  |
| Gimpy | `4-Gimpy.jpg` |  |  |

### 3-Treasure — Treasure (30)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Up | `1-Up.jpg` |  |  |
| 20 | `20_20.jpg` |  | 20 |
| Abaddon | `Abaddon.jpg` |  |  |
| Athame | `Athame.jpg` |  |  |
| Black Candle | `Black Candle.jpg` |  |  |
| Cursed Eye | `Cursed Eye.jpg` |  |  |
| Daddy Long Legs | `Daddy Long Legs.jpg` |  |  |
| Distant Admiration | `Distant Admiration.jpg` |  |  |
| Divorce Papers | `Divorce Papers.jpg` |  |  |
| Euthanasia | `Euthanasia.jpg` |  |  |
| Forget Me Now | `Forget Me Now.jpg` |  |  |
| Game Breaking Bug! | `Game Breaking Bug!.jpg` |  |  |
| Guppy's Eye | `Guppy_s Eye.jpg` |  |  |
| Head of Krampus | `Head of Krampus.jpg` |  |  |
| Head of the Keeper | `Head of the Keeper.jpg` |  |  |
| Hourglass | `Hourglass.jpg` |  |  |
| Lard | `Lard.jpg` |  |  |
| Libra | `Libra.jpg` |  |  |
| Magnet | `Magnet.jpg` |  |  |
| Mama Haunt | `Mama Haunt.jpg` |  |  |
| Mom's Eye Shadow | `Mom_s Eye Shadow.jpg` |  |  |
| Mutant Spider | `Mutant Spider.jpg` |  |  |
| P.H.D. | `P.H.D..jpg` |  |  |
| Polyphemus | `Polyphemus.jpg` |  |  |
| Rainbow Baby | `Rainbow Baby.jpg` |  |  |
| Red Candle | `Red Candle.jpg` |  |  |
| Rubber Cement | `Rubber Cement.jpg` |  |  |
| Smart Fly | `Smart Fly.jpg` |  |  |
| Telepathy for Dummies | `Telepathy for Dummies.jpg` |  |  |
| The Wiz | `The Wiz.jpg` |  |  |

### 4-Loot — Loot (30)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| A Nickel | `A Nickel.jpg` | Coin |  |
| A Penny | `A Penny 2.jpg` | Coin | 2 |
| A Penny | `A Penny 3.jpg` | Coin | 3 |
| A Penny | `A Penny.jpg` | Coin |  |
| AAA Battery | `AAA Battery.jpg` | Battery |  |
| Ansuz | `Ansuz.jpg` | Rune |  |
| Black Rune | `Black Rune.jpg` | Rune |  |
| Bomb | `Bomb.jpg` | Bomb |  |
| Butter bean | `Butter bean.jpg` | Trinket / Other |  |
| Dice Shard | `Dice Shard.jpg` | Trinket / Other |  |
| Four Cents | `Four Cents 2.jpg` | Coin | 2 |
| Four Cents | `Four Cents.jpg` | Coin |  |
| Get Out of Jail Card | `Get Out of Jail Card.jpg` | Trinket / Other |  |
| Gold Key | `Gold Key.jpg` | Key |  |
| Ll Battery | `Ll Battery.jpg` | Battery |  |
| Perthro | `Perthro.jpg` | Rune |  |
| Pills! (Black) | `Pills! (Black).jpg` | Pill |  |
| Pills! (Speckled) | `Pills! (Speckled).jpg` | Pill |  |
| Pills! (White) | `Pills! (White).jpg` | Pill |  |
| Poker Chip | `Poker Chip.jpg` | Trinket / Other |  |
| Question Mark Card | `Question Mark Card.jpg` | Trinket / Other |  |
| Tape Worm | `Tape Worm.jpg` | Trinket / Other |  |
| The Left Hand | `The Left Hand.jpg` | Trinket / Other |  |
| Three Cents | `Three Cents 2.jpg` | Coin | 2 |
| Three Cents | `Three Cents 3.jpg` | Coin | 3 |
| Three Cents | `Three Cents 4.jpg` | Coin | 4 |
| Three Cents | `Three Cents.jpg` | Coin |  |
| Two Cents | `Two Cents 2.jpg` | Coin | 2 |
| Two Cents | `Two Cents 3.jpg` | Coin | 3 |
| Two Cents | `Two Cents.jpg` | Coin |  |

### 5-Monsters — Monster / Boss / Happening (30)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Angel Room | `Angel Room.jpg` | Happening / Event |  |
| Blastocyst | `Blastocyst.jpg` | Monster / Boss |  |
| Bony | `Bony.jpg` | Monster / Boss |  |
| Boss Rush | `Boss Rush.jpg` | Happening / Event |  |
| Brain | `Brain.jpg` | Monster / Boss |  |
| Curse of Blood Lust | `Curse of Blood Lust.jpg` | Curse |  |
| Curse of Impulse | `Curse of Impulse.jpg` | Curse |  |
| Cursed Globin | `Cursed Globin.jpg` | Monster / Boss |  |
| Cursed Tumor | `Cursed Tumor.jpg` | Monster / Boss |  |
| Dingle | `Dingle.jpg` | Monster / Boss |  |
| Flaming Hopper | `Flaming Hopper.jpg` | Monster / Boss |  |
| Globin | `Globin.jpg` | Monster / Boss |  |
| Head Trauma | `Head Trauma.jpg` | Happening / Event |  |
| Headless Horseman | `Headless Horseman.jpg` | Monster / Boss |  |
| Holy Bony | `Holy Bony.jpg` | Monster / Boss |  |
| Holy Chest | `Holy Chest.jpg` | Chest |  |
| Holy Mulligan | `Holy Mulligan.jpg` | Monster / Boss |  |
| Isaac! | `Isaac!.jpg` | Monster / Boss |  |
| Krampus | `Krampus.jpg` | Monster / Boss |  |
| Mom's Heart! | `Mom_s Heart!.jpg` | Monster / Boss |  |
| Monstro II | `Monstro II.jpg` | Monster / Boss |  |
| Nerve Ending | `Nerve Ending.jpg` | Monster / Boss |  |
| Roundy | `Roundy.jpg` | Monster / Boss |  |
| Spiked Chest | `Spiked Chest.jpg` | Chest |  |
| Sucker | `Sucker.jpg` | Monster / Boss |  |
| Swarmer | `Swarmer.jpg` | Monster / Boss |  |
| The Fallen | `The Fallen.jpg` | Monster / Boss |  |
| Troll Bombs | `Troll Bombs.jpg` | Happening / Event |  |
| Tumor | `Tumor.jpg` | Monster / Boss |  |
| Widow | `Widow.jpg` | Monster / Boss |  |

---

## 3-Requiem

Path: `1-Core Sets/3-Requiem/` — 272 cards.
Set icon: `1-Core Sets/3-Requiem/X-SetIcon.png`

| Category | Type | Count |
|---|---|---|
| 1-Characters | Character | 23 |
| 2-Starting Items | Starting Item | 21 |
| 3-Treasure | Treasure | 53 |
| 4-Loot | Loot | 54 |
| 5-Monsters | Monster / Boss / Happening | 53 |
| 6-Rooms | Room / Happening | 61 |
| 7-Bonus Souls | Bonus Soul | 5 |
| 8-Extra | Extra / Promo | 2 |

### 1-Characters — Character (23)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Bethany | `1-Bethany.jpg` |  |  |
| The Benighted | `10-The Benighted.jpg` |  |  |
| The Enigma | `11.1-The Enigma.jpg` |  |  |
| amginE ehT | `11.2-amginE ehT.jpg` |  |  |
| The Capricious | `12-The Capricious.jpg` |  |  |
| The Baleful | `13-The Baleful.jpg` |  |  |
| The Harlot | `14-The Harlot.jpg` |  |  |
| The Miser | `15-The Miser.jpg` |  |  |
| The Empty | `16-The Empty.jpg` |  |  |
| The Fettered | `17-The Fettered.jpg` |  |  |
| The Zealot | `18-The Zealot.jpg` |  |  |
| The Deserter | `19-The Deserter.jpg` |  |  |
| Jacob & Esau | `2-Jacob _ Esau.jpg` |  |  |
| Flash Isaac | `20-Flash Isaac.jpg` |  |  |
| The Broken | `3-The Broken.jpg` |  |  |
| The Dauntless | `4-The Dauntless.jpg` |  |  |
| The Hoarder | `5-The Hoarder.jpg` |  |  |
| The Deceiver | `6-The Deceiver.jpg` |  |  |
| The Soiled | `7-The Soiled.jpg` |  |  |
| The Curdled | `8-The Curdled.jpg` |  |  |
| The Savage | `9-The Savage.jpg` |  |  |
| Eden (Braid) | `X.1-Eden (Braid).jpg` |  |  |
| Eden (Fade) | `X.2-Eden (Fade).jpg` |  |  |

### 2-Starting Items — Starting Item (21)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Book of Virtues | `1-Book of Virtues.jpg` |  |  |
| Hemoptysis | `10-Hemoptysis.jpg` |  |  |
| Flip | `11-Flip.jpg` |  |  |
| Glitch | `12-Glitch.jpg` |  |  |
| Soulbond | `13-Soulbond.jpg` |  |  |
| Gello | `14-Gello.jpg` |  |  |
| Keeper's Bargain | `15-Keeper_s Bargain.jpg` |  |  |
| Abyss | `16-Abyss.jpg` |  |  |
| Dead Weight | `17-Dead Weight.jpg` |  |  |
| Lemegeton | `18-Lemegeton.jpg` |  |  |
| Anima Sola | `19.1-Anima Sola.jpg` |  |  |
| The Revenant | `19.2-The Revenant.jpg` |  |  |
| Sibling Rivalry | `2-Sibling Rivalry.jpg` |  |  |
| Classic Roller | `20-Classic Roller.jpg` |  |  |
| Spindown Dice | `3-Spindown Dice.jpg` |  |  |
| Hypercoagulation | `4-Hypercoagulation.jpg` |  |  |
| Bag of Crafting | `5-Bag of Crafting.jpg` |  |  |
| Ceremonial Blade | `6-Ceremonial Blade.jpg` |  |  |
| IBS | `7-IBS.jpg` |  |  |
| Sumptorium | `8-Sumptorium.jpg` |  |  |
| Berserk | `9-Berserk.jpg` |  |  |

### 3-Treasure — Treasure (53)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Abel | `Abel.jpg` |  |  |
| Alabaster Box | `Alabaster Box.jpg` |  |  |
| Auction Gavel | `Auction Gavel.jpg` |  |  |
| Backstabber | `Backstabber.jpg` |  |  |
| Ball of Bandages | `Ball of Bandages.jpg` |  |  |
| Battery Pack | `Battery Pack.jpg` |  |  |
| Birthright | `Birthright.jpg` |  |  |
| Blood Puppy | `Blood Puppy.jpg` |  |  |
| Bobby Bomb | `Bobby Bomb.jpg` |  |  |
| Book of the Dead | `Book of the Dead.jpg` |  |  |
| Car Battery | `Car Battery.jpg` |  |  |
| Chocolate Milk | `Chocolate Milk.jpg` |  |  |
| Consolation Prize | `Consolation Prize.jpg` |  |  |
| Cursed Soul | `Cursed Soul.jpg` |  |  |
| Damocles | `Damocles.jpg` |  |  |
| Eternal D6 | `Eternal D6.jpg` |  |  |
| Experimental Treatment | `Experimental Treatment.jpg` |  |  |
| Fetal Haunt | `Fetal Haunt.jpg` |  |  |
| Fire Mind | `Fire Mind.jpg` |  |  |
| Friendly Ball | `Friendly Ball.jpg` |  |  |
| Friendly Sack | `Friendly Sack.jpg` |  |  |
| Gnawed Leaf | `Gnawed Leaf.jpg` |  |  |
| Hallowed Ground | `Hallowed Ground.jpg` |  |  |
| Halo of Flies | `Halo of Flies.jpg` |  |  |
| Hand-Me-Downs | `Hand-Me-Downs.jpg` |  |  |
| Handicapped Placard | `Handicapped Placard.jpg` |  |  |
| Jaw of Flies | `Jaw of Flies.jpg` |  |  |
| Judas' Shadow | `Judas_ Shadow.jpg` |  |  |
| Keeper's Box | `Keeper_s Box.jpg` |  |  |
| Keeper's Penny | `Keeper_s Penny.jpg` |  |  |
| Keeper's Sack | `Keeper_s Sack.jpg` |  |  |
| Lil Chest | `Lil Chest.jpg` |  |  |
| Lodestone | `Lodestone.jpg` |  |  |
| Lucnh | `Lucnh.jpg` |  |  |
| Magic Skin | `Magic Skin.jpg` |  |  |
| Mama Mega | `Mama Mega.jpg` |  |  |
| Marbles | `Marbles.jpg` |  |  |
| Member Card | `Member Card.jpg` |  |  |
| Mom's Bottle of Pills | `Mom_s Bottle of Pills.jpg` |  |  |
| Pageant Boy | `Pageant Boy.jpg` |  |  |
| Playdough Cookie | `Playdough Cookie.jpg` |  |  |
| Punching Bag | `Punching Bag.jpg` |  |  |
| R Key | `R Key.jpg` |  |  |
| Red Key | `Red Key.jpg` |  |  |
| Rock Bottom | `Rock Bottom.jpg` |  |  |
| Sacrificial Dagger | `Sacrificial Dagger.jpg` |  |  |
| Spelunker Hat | `Spelunker Hat.jpg` |  |  |
| The Clicker | `The Clicker.jpg` |  |  |
| The Jar | `The Jar.jpg` |  |  |
| Trick Penny | `Trick Penny.jpg` |  |  |
| Ultra Flesh Kid! | `Ultra Flesh Kid!.jpg` |  |  |
| Undefined | `Undefined.jpg` |  |  |
| Ray Vision | `X-Ray Vision.jpg` |  |  |

### 4-Loot — Loot (54)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| A Lucky Penny | `A Lucky Penny.jpg` | Coin |  |
| A Nickel | `A Nickel.jpg` | Coin |  |
| A Sack | `A Sack.jpg` | Trinket / Other |  |
| Ace of Diamonds | `Ace of Diamonds.jpg` | Trinket / Other |  |
| Algiz | `Algiz.jpg` | Rune |  |
| Bag Lunch | `Bag Lunch.jpg` | Trinket / Other |  |
| Berkano | `Berkano.jpg` | Rune |  |
| Black Heart | `Black Heart 2.jpg` | Heart | 2 |
| Black Heart | `Black Heart.jpg` | Heart |  |
| Bomb | `Bomb 2.jpg` | Bomb | 2 |
| Bomb | `Bomb 3.jpg` | Bomb | 3 |
| Bomb | `Bomb.jpg` | Bomb |  |
| Broken Remote | `Broken Remote.jpg` | Trinket / Other |  |
| Butter Bean | `Butter Bean 2.jpg` | Trinket / Other | 2 |
| Butter Bean | `Butter Bean 3.jpg` | Trinket / Other | 3 |
| Butter Bean | `Butter Bean.jpg` | Trinket / Other |  |
| Callus | `Callus.jpg` | Trinket / Other |  |
| Dad's Note | `Dad_s Note.jpg` | Trinket / Other |  |
| Dice Shard | `Dice Shard 2.jpg` | Trinket / Other | 2 |
| Dice Shard | `Dice Shard 3.jpg` | Trinket / Other | 3 |
| Dice Shard | `Dice Shard.jpg` | Trinket / Other |  |
| Emergency Contact | `Emergency Contact.jpg` | Trinket / Other |  |
| Four Cents | `Four Cents 2.jpg` | Coin | 2 |
| Four Cents | `Four Cents 3.jpg` | Coin | 3 |
| Four Cents | `Four Cents 4.jpg` | Coin | 4 |
| Four Cents | `Four Cents.jpg` | Coin |  |
| Golden Trinket | `Golden Trinket.jpg` | Trinket / Other |  |
| Hagalaz | `Hagalaz.jpg` | Rune |  |
| Key | `Key.jpg` | Key |  |
| Lil Battery | `Lil Battery 2.jpg` | Battery | 2 |
| Lil Battery | `Lil Battery.jpg` | Battery |  |
| Lucky Toe | `Lucky Toe.jpg` | Trinket / Other |  |
| Magic Marker | `Magic Marker.jpg` | Trinket / Other |  |
| Mega Bomb! | `Mega Bomb!.jpg` | Bomb |  |
| Pills! (Black & White) | `Pills! (Black _ White).jpg` | Pill |  |
| Pills! (horse) | `Pills! (horse).jpg` | Pill |  |
| Rib of Greed | `Rib of Greed.jpg` | Trinket / Other |  |
| Soul Heart | `Soul Heart 2.jpg` | Heart | 2 |
| Soul Heart | `Soul Heart.jpg` | Heart |  |
| Sticky Nickel | `Sticky Nickel.jpg` | Coin |  |
| Three Cents | `Three Cents 2.jpg` | Coin | 2 |
| Three Cents | `Three Cents 3.jpg` | Coin | 3 |
| Three Cents | `Three Cents 4.jpg` | Coin | 4 |
| Three Cents | `Three Cents 5.jpg` | Coin | 5 |
| Three Cents | `Three Cents 6.jpg` | Coin | 6 |
| Three Cents | `Three Cents.jpg` | Coin |  |
| Tick | `Tick.jpg` | Trinket / Other |  |
| Two Cents | `Two Cents 2.jpg` | Coin | 2 |
| Two Cents | `Two Cents 3.jpg` | Coin | 3 |
| Two Cents | `Two Cents 4.jpg` | Coin | 4 |
| Two Cents | `Two Cents 5.jpg` | Coin | 5 |
| Two Cents | `Two Cents.jpg` | Coin |  |
| Two of Spades | `Two of Spades.jpg` | Trinket / Other |  |
| Wishbone | `Wishbone.jpg` | Trinket / Other |  |

### 5-Monsters — Monster / Boss / Happening (53)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Baby Plum | `Baby Plum.jpg` | Monster / Boss |  |
| Betrayal! | `Betrayal!.jpg` | Happening / Event |  |
| Brownie | `Brownie.jpg` | Monster / Boss |  |
| Charmed Bony | `Charmed Bony.jpg` | Monster / Boss |  |
| Charmed Clotty | `Charmed Clotty.jpg` | Monster / Boss |  |
| Charmed Dip | `Charmed Dip.jpg` | Monster / Boss |  |
| Charmed Fat Bat | `Charmed Fat Bat.jpg` | Monster / Boss |  |
| Charmed Fatty | `Charmed Fatty.jpg` | Monster / Boss |  |
| Charmed Globin | `Charmed Globin.jpg` | Monster / Boss |  |
| Charmed Greedling | `Charmed Greedling.jpg` | Monster / Boss |  |
| Charmed Keeper | `Charmed Keeper.jpg` | Monster / Boss |  |
| Charmed Monstro | `Charmed Monstro.jpg` | Monster / Boss |  |
| Clog | `Clog.jpg` | Monster / Boss |  |
| Corny | `Corny.jpg` | Monster / Boss |  |
| Curse of Empathy | `Curse of Empathy.jpg` | Curse |  |
| Curse of the Hollow | `Curse of the Hollow.jpg` | Curse |  |
| Curse of the Hunted | `Curse of the Hunted.jpg` | Curse |  |
| Curse of the Soulless | `Curse of the Soulless.jpg` | Curse |  |
| Cursed Dople | `Cursed Dople.jpg` | Monster / Boss |  |
| Cursed Lil Haunt | `Cursed Lil Haunt.jpg` | Monster / Boss |  |
| Cursed Mulliboom | `Cursed Mulliboom.jpg` | Monster / Boss |  |
| Cursed Mulligan | `Cursed Mulligan.jpg` | Monster / Boss |  |
| Dogma | `Dogma.jpg` | Monster / Boss |  |
| Double Treasure! | `Double Treasure!.jpg` | Happening / Event |  |
| Dressing Table | `Dressing Table.jpg` | Happening / Event |  |
| Golden Troll Bomb! | `Golden Troll Bomb!.jpg` | Happening / Event |  |
| Gutted Fatty | `Gutted Fatty.jpg` | Monster / Boss |  |
| Holy Brain | `Holy Brain.jpg` | Monster / Boss |  |
| Holy Greedling | `Holy Greedling.jpg` | Monster / Boss |  |
| Holy Portal | `Holy Portal.jpg` | Monster / Boss |  |
| Holy Psy Horf | `Holy Psy Horf.jpg` | Monster / Boss |  |
| Hornfel | `Hornfel.jpg` | Monster / Boss |  |
| Lust for Blood! | `Lust for Blood!.jpg` | Happening / Event |  |
| Mama Gurdy | `Mama Gurdy.jpg` | Monster / Boss |  |
| Mega Satan! | `Mega Satan!.jpg` | Monster / Boss |  |
| Mother! | `Mother!.jpg` | Monster / Boss |  |
| Mother's Shadow! | `Mother_s Shadow!.jpg` | Monster / Boss |  |
| Mushroom | `Mushroom.jpg` | Monster / Boss |  |
| Null | `Null.jpg` | Monster / Boss |  |
| Overflow! | `Overflow!.jpg` | Happening / Event |  |
| Peeping Fatty | `Peeping Fatty.jpg` | Monster / Boss |  |
| Pitfall! | `Pitfall!.jpg` | Happening / Event |  |
| Rag Mega | `Rag Mega.jpg` | Monster / Boss |  |
| Red Ghost | `Red Ghost.jpg` | Monster / Boss |  |
| Sister Vis | `Sister Vis.jpg` | Monster / Boss |  |
| TNT Barrel | `TNT Barrel.jpg` | Happening / Event |  |
| The Rainmaker | `The Rainmaker.jpg` | Monster / Boss |  |
| The Scourge | `The Scourge.jpg` | Monster / Boss |  |
| The Siren | `The Siren.jpg` | Monster / Boss |  |
| Troll Bombs | `Troll Bombs.jpg` | Happening / Event |  |
| Turdlings | `Turdlings.jpg` | Monster / Boss |  |
| Ultra Greed! | `Ultra Greed!.jpg` | Monster / Boss |  |
| Whipper | `Whipper.jpg` | Monster / Boss |  |

### 6-Rooms — Room / Happening (61)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| All Hallows' Eve | `All Hallows_ Eve.jpg` | Room / Happening |  |
| Angelic Intervention | `Angelic Intervention.jpg` | Room / Happening |  |
| Battle Royale!!!!! | `Battle Royale!!!!!.jpg` | Room / Happening |  |
| Battle Royale!!!! | `Battle Royale!!!!.jpg` | Room / Happening |  |
| Battle Royale!!! | `Battle Royale!!!.jpg` | Room / Happening |  |
| Beggar | `Beggar.jpg` | Room / Happening |  |
| Black Champions | `Black Champions.jpg` | Room / Happening |  |
| Blessing of Gluttony | `Blessing of Gluttony.jpg` | Room / Happening |  |
| Blessing of Greed | `Blessing of Greed.jpg` | Room / Happening |  |
| Blessing of Steam | `Blessing of Steam.jpg` | Room / Happening |  |
| Blessing of the Inner Eye | `Blessing of the Inner Eye.jpg` | Room / Happening |  |
| Blessing of the Sack | `Blessing of the Sack.jpg` | Room / Happening |  |
| Blind Rage | `Blind Rage.jpg` | Room / Happening |  |
| Blood Donation | `Blood Donation.jpg` | Room / Happening |  |
| Blood Lust | `Blood Lust.jpg` | Room / Happening |  |
| Blood Money | `Blood Money.jpg` | Room / Happening |  |
| Bomb Bum | `Bomb Bum.jpg` | Room / Happening |  |
| Bum-bo is Loose! | `Bum-bo is Loose!.jpg` | Happening / Event |  |
| Butter Fingers | `Butter Fingers.jpg` | Room / Happening |  |
| Challenge Room | `Challenge Room.jpg` | Room / Happening |  |
| Conjoined Twin | `Conjoined Twin.jpg` | Room / Happening |  |
| Dark Beggar | `Dark Beggar.jpg` | Room / Happening |  |
| Dice Room!!!!!! | `Dice Room!!!!!!.jpg` | Happening / Event |  |
| Dice Room!!!!! | `Dice Room!!!!!.jpg` | Happening / Event |  |
| Dice Room!!!! | `Dice Room!!!!.jpg` | Happening / Event |  |
| Dice Room!!! | `Dice Room!!!.jpg` | Happening / Event |  |
| Dice Room!! | `Dice Room!!.jpg` | Happening / Event |  |
| Dice Room! | `Dice Room!.jpg` | Happening / Event |  |
| Eden's Blessing | `Eden_s Blessing.jpg` | Room / Happening |  |
| Equality | `Equality.jpg` | Room / Happening |  |
| Eternal Chest | `Eternal Chest.jpg` | Chest |  |
| Floor Spikes | `Floor Spikes.jpg` | Room / Happening |  |
| Fortune Teller | `Fortune Teller.jpg` | Room / Happening |  |
| Greed Looms | `Greed Looms.jpg` | Happening / Event |  |
| Gus | `Gus.jpg` | Room / Happening |  |
| Haunted! | `Haunted!.jpg` | Happening / Event |  |
| Heavy is the Head | `Heavy is the Head.jpg` | Room / Happening |  |
| I am Error | `I am Error.jpg` | Room / Happening |  |
| Isaac's Blessing | `Isaac_s Blessing.jpg` | Room / Happening |  |
| Key Master | `Key Master.jpg` | Room / Happening |  |
| Laser Eye! | `Laser Eye!.jpg` | Room / Happening |  |
| Maggy's Blessing | `Maggy_s Blessing.jpg` | Room / Happening |  |
| Might for the Meek | `Might for the Meek.jpg` | Room / Happening |  |
| Pity for the Poor | `Pity for the Poor.jpg` | Room / Happening |  |
| Planetarium | `Planetarium.jpg` | Room / Happening |  |
| Red Champions | `Red Champions.jpg` | Room / Happening |  |
| Red Vise | `Red Vise.jpg` | Room / Happening |  |
| Restock Machine | `Restock Machine.jpg` | Room / Happening |  |
| Samson's Blessing | `Samson_s Blessing.jpg` | Room / Happening |  |
| Shadow of Famine | `Shadow of Famine.jpg` | Room / Happening |  |
| Shadow of War | `Shadow of War.jpg` | Room / Happening |  |
| Shell Game | `Shell Game.jpg` | Room / Happening |  |
| Slot Machine | `Slot Machine.jpg` | Room / Happening |  |
| Social Goals! | `Social Goals!.jpg` | Room / Happening |  |
| Spider Webs | `Spider Webs.jpg` | Happening / Event |  |
| Splash Damage | `Splash Damage.jpg` | Happening / Event |  |
| Spoils of War | `Spoils of War.jpg` | Room / Happening |  |
| Static Shock | `Static Shock.jpg` | Happening / Event |  |
| Tax for the Mighty | `Tax for the Mighty.jpg` | Room / Happening |  |
| The Mirror | `The Mirror.jpg` | Happening / Event |  |
| White Champions | `White Champions.jpg` | Room / Happening |  |

### 7-Bonus Souls — Bonus Soul (5)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Soul of Envy | `Soul of Envy.jpg` |  |  |
| Soul of Lust | `Soul of Lust.jpg` |  |  |
| Soul of Pride | `Soul of Pride.jpg` |  |  |
| Soul of Sloth | `Soul of Sloth.jpg` |  |  |
| Soul of Wrath | `Soul of Wrath.jpg` |  |  |

### 8-Extra — Extra / Promo (2)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| The Harbingers | `1.1-The Harbingers.jpg` |  |  |
| The Beast! | `1.2-The Beast!.jpg` |  |  |

---

## 4-Summer of Isaac

Path: `1-Core Sets/4-Summer of Isaac/` — 50 cards.

| Category | Type | Count |
|---|---|---|
| (root) | Card / Promo | 50 |

### (root) — Card / Promo (50)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| A Friend | `soi-a_friend.jpg` |  |  |
| Ball of Tar | `soi-ball_of_tar-updated.jpg` |  |  |
| Blast Miner TNT! | `soi-blast_miner_tnt-updated.jpg` |  |  |
| Cereus Peashy | `soi-cereus_peashy-updated.jpg` |  |  |
| Charmed Vis | `soi-charmed_vis.jpg` |  |  |
| Club | `soi-club.jpg` |  |  |
| Clubby the Seal | `soi-clubby_the_seal.jpg` |  |  |
| Coil | `soi-coil.jpg` |  |  |
| Conjoined D6 | `soi-conjoined_d6.jpg` |  |  |
| Conjoined Fatty | `soi-conjoined_fatty.jpg` |  |  |
| Conquest | `soi-conquest.jpg` |  |  |
| Curse of Envy | `soi-curse_of_envy.jpg` |  |  |
| Cursed Haunt | `soi-cursed_haunt.jpg` |  |  |
| Dogma | `soi-dogma.jpg` |  |  |
| Era Walk | `soi-era_walk.jpg` |  |  |
| Everything Must Go | `soi-everything_must_go.jpg` |  |  |
| Found Soul | `soi-found_soul.jpg` |  |  |
| Gemini | `soi-gemini.jpg` |  |  |
| Giant Poop | `soi-giant_poop.jpg` |  |  |
| Gish | `soi-gish.jpg` |  |  |
| Headless Horseman | `soi-headless_horseman.jpg` |  |  |
| Holy Greed | `soi-holy_greed.jpg` |  |  |
| Hot Potato | `soi-hot_potato.jpg` |  |  |
| Hush | `soi-hush.jpg` |  |  |
| Isaac's Last Will | `soi-isaacs_last_will.jpg` |  |  |
| Karma | `soi-karma.jpg` |  |  |
| Krampus | `soi-krampus.jpg` |  |  |
| Light Switch | `soi-light_switch.jpg` |  |  |
| Magic Mushroom | `soi-magic_mushroom.jpg` |  |  |
| Mega Bean | `soi-mega_bean.jpg` |  |  |
| Mother! | `soi-mother.jpg` |  |  |
| Mugger Bean | `soi-mugger_bean.jpg` |  |  |
| Mulligoon | `soi-mulligoon.jpg` |  |  |
| Police Lineup | `soi-police_lineup.jpg` |  |  |
| Recycling Sticker | `soi-recycling_sticker.jpg` |  |  |
| Shopkeeper! | `soi-shopkeeper.jpg` |  |  |
| Stacy | `soi-stacy.jpg` |  |  |
| Tainted Mulligan | `soi-tainted_mulligan.jpg` |  |  |
| Telekinesis | `soi-telekinesis.jpg` |  |  |
| The Adversary | `soi-the_adversary.jpg` |  |  |
| The Bloat | `soi-the_bloat.jpg` |  |  |
| The Hoarder | `soi-the_hoarder.jpg` |  |  |
| The Miser | `soi-the_miser.jpg` |  |  |
| The Monster | `soi-the_monster.jpg` |  |  |
| The Rainmaker | `soi-the_rainmaker.jpg` |  |  |
| Tumor Ball | `soi-tumor_ball.jpg` |  |  |
| Unstable DNA | `soi-unstable_dna.jpg` |  |  |
| War | `soi-war.jpg` |  |  |
| Weltling | `soi-weltling.jpg` |  |  |
| Widow | `soi-widow.jpg` |  |  |

---

## 5-Anniversary Booster Pack

Path: `1-Core Sets/5-Anniversary Booster Pack/` — 20 cards.

| Category | Type | Count |
|---|---|---|
| 1-Characters | Character | 3 |
| 2-Starting Items | Starting Item | 2 |
| 3-Treasure | Treasure | 4 |
| 4-Loot | Loot | 2 |
| 5-Monsters | Monster / Boss / Happening | 5 |
| 6-Rooms | Room / Happening | 4 |

### 1-Characters — Character (3)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Bum-botheStout | `Bum-botheStout.jpg` |  |  |
| Florian | `Florian.jpg` |  |  |
| LevelOneIsaac | `LevelOneIsaac.jpg` |  |  |

### 2-Starting Items — Starting Item (2)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| Bag-o-Holes | `Bag-o-Holes.jpg` |  |  |
| GameSquid | `GameSquid.jpg` |  |  |

### 3-Treasure — Treasure (4)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| BoosterPack | `BoosterPack.jpg` |  |  |
| Co-opBaby | `Co-opBaby.jpg` |  |  |
| Dataminer | `Dataminer.jpg` |  |  |
| Prototype | `Prototype.jpg` |  |  |

### 4-Loot — Loot (2)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| CrackedKey | `CrackedKey.jpg` | Key |  |
| MonsterCard | `MonsterCard.jpg` | Trinket / Other |  |

### 5-Monsters — Monster / Boss / Happening (5)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| GameCrash! | `GameCrash!.jpg` | Monster / Boss |  |
| Keeper sRestingPlace | `Keeper_sRestingPlace.jpg` | Monster / Boss |  |
| PatchNotes | `PatchNotes.jpg` | Monster / Boss |  |
| TaintedSpitty | `TaintedSpitty.jpg` | Monster / Boss |  |
| WrathoftheLamb | `WrathoftheLamb.jpg` | Monster / Boss |  |

### 6-Rooms — Room / Happening (4)

| Card | File | Sub-kind | Copy |
|---|---|---|---|
| DailyRun | `DailyRun.jpg` | Room / Happening |  |
| GreedMode | `GreedMode.jpg` | Room / Happening |  |
| Guppy sPieces | `Guppy_sPieces.jpg` | Room / Happening |  |
| MultiplayerUpdate | `MultiplayerUpdate.jpg` | Room / Happening |  |

---

## Card Backs

Path: `4-Card Backs/`

| Back | Type | Version | Language | File |
|---|---|---|---|---|
| PrintReady_BonusSoulBack_SBEv4_USWeb.jpg | Bonus Soul | print-ready (SBE v4/v5) | EN | `PrintReady_BonusSoulBack_SBEv4_USWeb.jpg` |
| PrintReady_CharacterBack_SBEv5b_USWeb.jpg | Character | print-ready (SBE v4/v5) | EN | `PrintReady_CharacterBack_SBEv5b_USWeb.jpg` |
| PrintReady_LootBack_SBEv4a_USWeb.jpg | Loot | print-ready (SBE v4/v5) | EN | `PrintReady_LootBack_SBEv4a_USWeb.jpg` |
| PrintReady_MonsterBack_SBEv5b_USWeb.jpg | Monster | print-ready (SBE v4/v5) | EN | `PrintReady_MonsterBack_SBEv5b_USWeb.jpg` |
| PrintReady_RoomBack_SBEv4c_USWeb.jpg | Room | print-ready (SBE v4/v5) | EN | `PrintReady_RoomBack_SBEv4c_USWeb.jpg` |
| PrintReady_StartingItemBack_SBEv4a_USWeb.jpg | Starting Item | print-ready (SBE v4/v5) | EN | `PrintReady_StartingItemBack_SBEv4a_USWeb.jpg` |
| PrintReady_TreasureBack_SBEv5b_USWeb.jpg | Treasure | print-ready (SBE v4/v5) | EN | `PrintReady_TreasureBack_SBEv5b_USWeb.jpg` |
| BonusSoulCardBack-v6-ENG-KS-room10.jpg | Bonus Soul | v6 experimental | ENG (English) | `BonusSoulCardBack-v6-ENG-KS-room10.jpg` |
| CharacterCardBack-v6-ENG-KS-room10.jpg | Character | v6 experimental | ENG (English) | `CharacterCardBack-v6-ENG-KS-room10.jpg` |
| EternalCardBack-v6-ENG-KS-room10.jpg | Eternal (Requiem) | v6 experimental | ENG (English) | `EternalCardBack-v6-ENG-KS-room10.jpg` |
| LootCardBack-v6-ENG-KS-room10.jpg | Loot | v6 experimental | ENG (English) | `LootCardBack-v6-ENG-KS-room10.jpg` |
| MonsterCardBack-v6-ENG-KS-room10.jpg | Monster | v6 experimental | ENG (English) | `MonsterCardBack-v6-ENG-KS-room10.jpg` |
| RoomCardBack-v6-ENG-KS-room10.jpg | Room | v6 experimental | ENG (English) | `RoomCardBack-v6-ENG-KS-room10.jpg` |
| TreasureCardBack-v6-ENG-KS-room10.jpg | Treasure | v6 experimental | ENG (English) | `TreasureCardBack-v6-ENG-KS-room10.jpg` |
| BonusSoulCardBack-v6-ESP-KS.jpg | Bonus Soul | v6 experimental | ESP (Spanish) | `BonusSoulCardBack-v6-ESP-KS.jpg` |
| CharacterCardBack-v6-ESP-KS.jpg | Character | v6 experimental | ESP (Spanish) | `CharacterCardBack-v6-ESP-KS.jpg` |
| EternalCardBack-v6-ESP-KS.jpg | Eternal (Requiem) | v6 experimental | ESP (Spanish) | `EternalCardBack-v6-ESP-KS.jpg` |
| LootCardBack-v6-ESP-KS.jpg | Loot | v6 experimental | ESP (Spanish) | `LootCardBack-v6-ESP-KS.jpg` |
| MonsterCardBack-v6-ESP-KS.jpg | Monster | v6 experimental | ESP (Spanish) | `MonsterCardBack-v6-ESP-KS.jpg` |
| RoomCardBack-v6-ESP-KS.jpg | Room | v6 experimental | ESP (Spanish) | `RoomCardBack-v6-ESP-KS.jpg` |
| TreasureCardBack-v6-ESP-KS.jpg | Treasure | v6 experimental | ESP (Spanish) | `TreasureCardBack-v6-ESP-KS.jpg` |

---

## Items & TTS Images

`tts/Mods/Images/` holds every image the Tabletop Simulator mod references,
named after its source URL. They are grouped by role below.

### Dice (6)

| Item | Kind | File |
|---|---|---|
| Dice - red d10 (0-9) | dice | `httpssteamusercontentaakamaihdnetugc18200160851653457458F416CEB08420DBD84233B493F493EF6A5DA5369.jpg` |
| Dice - green, item symbols | dice | `httpssteamusercontentaakamaihdnetugc7919830607469473926CBF4E75542CC08B5775F766B9A98226850CFCAF.jpg` |
| Dice - green, standard pips | dice | `httpssteamusercontentaakamaihdnetugc7919830607469498493D9EAF2C588775C5300732DC262F2A74AF839531.jpg` |
| Dice - dark, white pips | dice | `httpssteamusercontentaakamaihdnetugc7919830607469518585984C741244EF1DAF926F7598CDE430D26AF1776.jpg` |
| Dice - red, black pips | dice | `httpssteamusercontentaakamaihdnetugc791983060746953419D51923DF721755E78C04FEC9E932481EA4AA0D00.jpg` |
| Dice - red, red symbols | dice | `httpssteamusercontentaakamaihdnetugc79198306074695450224EFE1CD3873D18852D5CE0F9990EEBB8F650F3D.jpg` |

### Tokens & counters (hearts, skull, HP) (3)

| Item | Kind | File |
|---|---|---|
| Skull token | token | `httpssteamusercontentaakamaihdnetugc9450955652067475435D5EF6DBDA88AABF4DAA62D8FE03E0DD12BB4C9C.png` |
| Heart token (red heart) | token | `httpssteamusercontentaakamaihdnetugc956338348338848075D95B470ADA4858A5BD90FC657A5443BC0641E8B9.png` |
| HP / Minion HP counter | token | `httpssteamusercontentaakamaihdnetugc958597478463059274DE73B64E1B5C6F272EA3BEE5EF458E73E48FF03D.png` |

### Board / table (1)

| Item | Kind | File |
|---|---|---|
| Table / play board (wood + blue mat) | board | `httpssteamusercontentaakamaihdnetugc18200158261287846429A4AB6AAB865C68FF5A4B2578AB99F5BC8DE988D.jpg` |

### Mat (1)

| Item | Kind | File |
|---|---|---|
| Mat tile | mat | `httpssteamusercontentaakamaihdnetugc18200158261288079585010393F39F3DA3C28C846CBF8DA6E501E13A5FA.jpg` |

### 3D model textures (1)

| Item | Kind | File |
|---|---|---|
| Coin texture (heads $ / tails pentagram) | model_texture | `httpssteamusercontentaakamaihdnetugc956338348338936239B64D84967DA774EF0A6876915B624A048FD5B1E5.png` |

### Other loose images (2)

| Item | Kind | File |
|---|---|---|
| Plain gray mat (flip side of mat tile) | other | `httpsiimgurcom5ggTe2Upng.png` |
| Requiem logo / wordmark (unreferenced in save) | other | `httpssteamusercontentaakamaihdnetugc1820015280896936072E837849FC9F42B2A38E7457A2EE69E2DDD3A07DA.png` |

### Card deck sheets (composite images) (183)

| Sheet file | Role | Grid | Cards on sheet |
|---|---|---|---|
| `httpssteamusercontentaakamaihdnetugc1762617478243165277C92DF9C2F056A96CE374E66D1997B38862F579CF.jpg` | face | 1x1 | Unrelenting Delirium (Hard) |
| `httpssteamusercontentaakamaihdnetugc1762617478243168805EC9310AF3A1F3773B2A28910466BD7944149AEEC.jpg` | face | 1x1 | Delirious (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc17626174782431699292F2DFF69D9B8A03FCEE0B4F46E094D476C3680FB.jpg` | face | 1x1 | Delirious (Normal) |
| `httpssteamusercontentaakamaihdnetugc1762617478243170739D98D083AE44513CEBBD90548013701BACB6C9BFB.jpg` | face | 1x1 | Delirious (Hard) |
| `httpssteamusercontentaakamaihdnetugc1762617478243171668D0D21DCFD41DC70E7B79471BA3B4B10D21745E7D.jpg` | face | 1x1 | Unrelenting Delirium (Normal) |
| `httpssteamusercontentaakamaihdnetugc1762617478243172508FD410B6D4278347AE0656D2314FA2712355A0AAE.jpg` | face | 1x1 | Unrelenting Delirium (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1798649172901912442F8740A2F12849271E92714AADD03C37F3C36D402.jpg` | face | 1x1 | Swarming The Duke of Flies (Normal) |
| `httpssteamusercontentaakamaihdnetugc1798649172901913774E6AFE57F25FD2088AC474E43D945E27163CEA9FC.jpg` | face | 1x1 | Swarming The Duke of Flies (Hard) |
| `httpssteamusercontentaakamaihdnetugc1798649172901917932EF4E43BC773D0CA2650AEDB13421EE9D33E58465.jpg` | face | 1x1 | Swarming The Duke of Flies (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1798649172901918709E0D91D34D1C0DC118D8FD880902A17C0C176BB9E.jpg` | face | 1x1 | Lord of the Flies (Normal) |
| `httpssteamusercontentaakamaihdnetugc1798649172901919421C3FC41C4A99D2280048AF335B16764FA57D2538F.jpg` | face | 1x1 | Lord of the Flies (Hard) |
| `httpssteamusercontentaakamaihdnetugc179864917290192102693DB79762D1E00E77CE7EBFF38BF14C905ABBA21.jpg` | face | 1x1 | Lord of the Flies (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1820015348322248483DA4147A935B462FFABB80AEC5122B89DCBEA20B9.jpg` | face | 2x2 | The Bloat (Green Promo); Ultra Pride |
| `httpssteamusercontentaakamaihdnetugc1820015348322250726AD346572BABA96081548B5885DE7F529C6C0D3F9.png` | back+face | 1x1 | Monsters |
| `httpssteamusercontentaakamaihdnetugc1820015348322254301FC7FD8367ADEC87F58E9485816D7B80387B78EE3.jpg` | face | 1x1 | Gish |
| `httpssteamusercontentaakamaihdnetugc1820015348322256099C68CB28BD893F20CF08AF745B91C50C8CB33705E.jpg` | face | 1x1 | Corrupted Data |
| `httpssteamusercontentaakamaihdnetugc182001534832226064161782BEE95567DE21EC6ACE73F8E451CC32550D6.jpg` | face | 1x1 | Pink Proglottid |
| `httpssteamusercontentaakamaihdnetugc182001534832226096521BC76F546AD31D1FF6B6D7ED2987CEDDE7DC2DA.png` | back+face | 1x1 | Starting Items |
| `httpssteamusercontentaakamaihdnetugc1820015348322262996E40761E90AFA97047A5EF1269F636EAAC96CB2E1.jpg` | face | 1x1 | Rainbow Tapeworm |
| `httpssteamusercontentaakamaihdnetugc1820015348322263389F87005F800C72661FA58EA5B66F9F18ED8D2A10E.png` | back+face | 1x1 | Loot |
| `httpssteamusercontentaakamaihdnetugc1820015348322265235B9025C6E3C9221CEBBE122F460AD6FB95D98CD82.jpg` | face | 1x1 | Tapeworm |
| `httpssteamusercontentaakamaihdnetugc1820015348322265562733F67EF352E493AA712210886FD1B07389BCA83.png` | back+face | 1x1 | Characters |
| `httpssteamusercontentaakamaihdnetugc182001534832227435024688C7914287240608173B0D405E9D4927A40BA.jpg` | face | 2x2 | Eden (Boy Promo); Eden (Girl Promo) |
| `httpssteamusercontentaakamaihdnetugc18200153483222751387512224A93D1537C5AA86AEF2528868B312BE20D.jpg` | face | 2x2 | Dead Eye; Epic Fetus; Marked |
| `httpssteamusercontentaakamaihdnetugc182001534832227941347A1BC7739DCD4750FAA3D44CC3960F3C7B8B2C4.jpg` | face | 2x2 | Black Proglottid; Red Proglottid; White Proglottid |
| `httpssteamusercontentaakamaihdnetugc1820015524663295223130A4934128722670F4DA557C8258E3B1D67F4E8.png` | face | 1x1 | Bonus Souls |
| `httpssteamusercontentaakamaihdnetugc18200155246634184470C421651A8D165715873233990CB24211454BE1F.png` | back+face | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1820015524663664652A45EFA7AF7516C8C1DB331D57897B501CBC5D833.jpg` | face | 1x1 | Tapeworm |
| `httpssteamusercontentaakamaihdnetugc182001552466367314163319150847631628622EDAACFE83F6D7D08C85F.jpg` | face | 1x1 | Lil' Gish |
| `httpssteamusercontentaakamaihdnetugc18200155246745508894E17D6768B45B4E920BBFA8EF70495659095059C.jpg` | face | 1x1 | The Bloat (White Promo) |
| `httpssteamusercontentaakamaihdnetugc182001582613547937631CCD890D7E0BBB2D89ABABFF27D38586DBB23FA.jpg` | face | 1x1 | Key Terms |
| `httpssteamusercontentaakamaihdnetugc18200158261354797187E8DFBB1D27FCBAEA79AF95C275609055BC5BC24.jpg` | back | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc18200159973538380584DCA72D6E7661912DE0B9A8D43A9DC588DB09F05.jpg` | face | 1x1 | Henry |
| `httpssteamusercontentaakamaihdnetugc182001645648083011131B3907DE3101057A45C64B6C994CFD671192B0E.jpg` | face | 1x1 | It Lives! |
| `httpssteamusercontentaakamaihdnetugc1826780185923007260C03173E384D2FBAE3EA28F4E885804082A4E4671.jpg` | face | 1x1 | Dick Knot! |
| `httpssteamusercontentaakamaihdnetugc18290343361095861657BCA46A383133418327CBEA9999C4BC6469E5C36.jpg` | face | 2x2 | Christian Broadcasts; Dogma (Unboxing); TV Static |
| `httpssteamusercontentaakamaihdnetugc1829036090974737329A5F68B89C00070131CEAE565A3467B0CF5826E95.jpg` | face | 1x1 | Devout Mom (Normal) |
| `httpssteamusercontentaakamaihdnetugc182903609097474405311F57E91D19E788B518DDCC3EE3B684800CEF8FA.jpg` | face | 1x1 | Devout Mom (Hard) |
| `httpssteamusercontentaakamaihdnetugc1829036090974744942FF83F7759894E108F783853E02619A839F84834C.jpg` | face | 1x1 | Devout Mom (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1829036090974761396B27D2B86D4FA424ED5CEBE8D2396D6AC279E919E.jpg` | face | 1x1 | Motherly Love |
| `httpssteamusercontentaakamaihdnetugc18324111297512198145D0498EE96D8AE9679E5FBC69A8114E32B191398.jpg` | face | 1x1 | Resurrected Rag Man (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1832411129751233244B6E27A99EEC6EAE1A18F747F406CADFBE4D643AE.jpg` | face | 1x1 | Resurrected Rag Man (Normal) |
| `httpssteamusercontentaakamaihdnetugc1832411129751234823DE311133B8AB70155D74FF8090668541B68FA905.jpg` | face | 1x1 | Resurrected Rag Man (Hard) |
| `httpssteamusercontentaakamaihdnetugc18324111297598687057E6899719397FCB8F4DCC069E6E03EC4609E69FA.jpg` | face | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1832411129759870755D153C0113B85BF4D11D619823A7D7C85B7143AA7.jpg` | face | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc184705397986423318739E745E5CA02EA0B67FA846B0BF543C695E2B0B4.jpg` | face | 1x1 | Avaricious Greed (Hard) |
| `httpssteamusercontentaakamaihdnetugc1847053979864233877135F9F78FB356156D3A5A0EA0A35D0A128AD076A.jpg` | face | 1x1 | Avaricious Greed (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1847053979864235388BAA5F1940BD440F56B6AFCC61A455946D014D156.jpg` | face | 1x1 | Avaricious Greed (Normal) |
| `httpssteamusercontentaakamaihdnetugc184705397986423600006A0566D189C322B4DF270F9F9D5177B62CBB71F.jpg` | face | 1x1 | Greed's Gamble (Normal) |
| `httpssteamusercontentaakamaihdnetugc18470539798642369347ED05BA0E5C6CA6AE53B1C0921DECE2EE3FB57CD.jpg` | face | 1x1 | Greed's Gamble (Hard / Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1866176544840894214B9BB3B9EAD1627AF1A5D63B17E05C2EC09E724A2.jpg` | face | 2x2 | Soul of Gluttony; Soul of Greed; Soul of Guppy |
| `httpssteamusercontentaakamaihdnetugc1866176544840895895F0721AC8F24B2F9C56416DEC468585FC552F94CB.jpg` | back | 2x2 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1866176544840907514FBE76E196B57D3D5CBADA8D360515A1C5160ED67.jpg` | back | 2x2 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1866176544840909025D29CF9AC50926A1447E015C981B3D53CF9873155.jpg` | face | 4x3 | Blue Baby; Cain; Eden; Eve; Isaac; Judas; Lazarus; Lilith; Maggy; Samson; The Forgotten |
| `httpssteamusercontentaakamaihdnetugc186617654484091224756E8946ED64CF5B7A7642F3E01F8084ED56D1BF2.jpg` | face | 7x5 | 0. The Fool; 2 Cents!; 3 Cents!; 4 Cents! |
| `httpssteamusercontentaakamaihdnetugc1866176544840913502259784FEB6DB6B945DC1492E94831E4DA255AF51.jpg` | back | 7x5 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1866176544840924052259784FEB6DB6B945DC1492E94831E4DA255AF51.jpg` | back | 5x4 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc18661765448409259398AE966EB0E34EC64B7A387514F8ED8C459FC0983.jpg` | face | 7x5 | 4 Cents!; A Dime!!; A Nickel!; A Penny!; Blank Rune; Bloody Penny; Bomb!; Broken Ankh; Butter Bean!; Cain's Eye; Counterfeit Penny; Curved Horn; Dagaz; Dice Shard; Ehwaz; Gold Bomb; Golden Horseshoe; Guppy's Hairball |
| `httpssteamusercontentaakamaihdnetugc18661765448409287015018EC5752E307A987CF0CFF2647C7F35C141D74.jpg` | face | 7x5 | I. The Magician; II. The High Priestess; III. The Empress; IV. The Emperor; IX. The Hermit; Lil Battery; Lost Soul; Mega Battery; Pills!; Purple Heart; Soul Heart; Swallowed Penny; V. The Hierophant; VI. The Lovers; VII. The Chariot; VIII. Justice; X. Wheel of Fortune; XI. Strength; XII. The Hanged Man; XIII. Death; XIV. Temperance; XIX. The Sun; XV. The Devil; XVI. The Tower; XVII. The Stars; XVI |
| `httpssteamusercontentaakamaihdnetugc186617654484093176734ADA83D0E4D7BB7730DF1E16C4D1756A4EA9083.jpg` | back | 5x4 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc186617654484093299459F9A6A4B70FE64D763ED2CDBD7224C287129FE9.jpg` | face | 7x5 | Ambush!; Big Spider; Black Bony; Boom Fly; Carrion Queen; Chest; Chub; Clotty; Cod Worm; Conjoined Fatty; Conquest; Curse of Amnesia; Curse of Greed; Curse of Loss; Curse of Pain; Curse of the Blind; Cursed Chest; Cursed Fatty; Cursed Gaper; Cursed Horf; Cursed Keeper Head; Cursed Mom's Hand; Cursed Psy Horf; Daddy Long Legs; Dank Globin; Dark Chest; Dark One; Death; Delirium; Devil Deal; Dinga; D |
| `httpssteamusercontentaakamaihdnetugc18661765448409346348AC88ADB913370A932FAA19C2E8605364F33BB90.jpg` | face | 7x5 | Envy; Evil Twin; Famine; Fat Bat; FAT FUCK FRIDAY; FAT FUCK FRIDAY: JOJO REFERENCE; Fatty; Fly; Gemini; Gluttony; Gold Chest; Greed; Greed!; Greedling; Gurdy; Gurdy Jr.; Hanger; Holy Dinga; Holy Dip; Holy Keeper Head; Holy Mom's Eye; Holy Squirt; Hopper; Horf; I Can See Forever!; Keeper Head; Larry Jr.; Leaper; Leech; Little Horn; Lust; Mask of Infamy; Mega Fatty; Mega Troll Bomb!; Mom!; Mom's Dea |
| `httpssteamusercontentaakamaihdnetugc1866176544840941762D4D218DD68A492DDF712A34F0ED2FC7EC6B39F93.jpg` | face | 7x5 | FAT FUCK FRIDAY; FAT FUCK FRIDAY: JOJO REFERENCE; Mom's Eye; Mom's Hand; Monstro; Mulliboom; Mulligan; Pale Fatty; Peep; Pestilence; Pin; Pooter; Portal; Pride; Psy Horf; Rag Man; Rage Creep; Red Host; Ring of Flies; Satan!; Scolex; Secret Room!; Shop Upgrade!; Sloth; Spider; Squirt; Stoney; Swarm of Flies; The Bloat; The Duke of Flies; The Haunt; The Lamb; Trite; Troll Bombs; War; We Need to go D |
| `httpssteamusercontentaakamaihdnetugc18661765448409439060212A5E42A727A26C22DC38D20F347C6E4B26E7E.jpg` | face | 2x2 | Wrath; XL Floor! |
| `httpssteamusercontentaakamaihdnetugc1866176544840948164F8692286A0EB9BF29F3F5D43041659840BAB6E9B.jpg` | face | 4x3 | Blood Lust; Book of Belial; Forever Alone; Incubus; Lazarus' Rags; Sleight of Hand; The Bone; The Curse; The D6; Yum Heart |
| `httpssteamusercontentaakamaihdnetugc1866176544840948998B80EEF48D34B0826A3BD1E8C5D7BF90E23005AA5.jpg` | back | 2x2 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc18661765448409551340D7D21588ED9E9ECA890AB29981B13FB834401E9.jpg` | face | 7x5 | Baby Haunt; Battery Bum; Belly Button; Blank Card; Bob's Brain; Book of Sin; Boomerang; Box!; Breakfast; Brimstone; Bum Friend; Bum-Bo!; Cambion Conception; Champion Belt; Chaos; Chaos Card; Charged Baby; Cheese Grater; Compost; Contract from Below; Crystal Ball; Curse of the Tower; Dad's Lost Coin; Daddy Haunt; Dark Bum; Dead Bird; Decoy; Dinner; Diplopia; Donation Machine; Dry Baby; Eden's Bless |
| `httpssteamusercontentaakamaihdnetugc1866176544840960756D4B93DE19799B50420F1A34E179E2BAFACA1276A.jpg` | face | 7x5 | Finger!; Flush!; Glass Cannon; Goat Head; Godhead; Golden Razor Blade; Greed's Gullet; Guppy's Collar; Guppy's Head; Guppy's Paw; Host Hat; Ipecac; Jawbone; Lucky Foot; Meat!; Mini Mush; Modeling Clay; Mom's Box; Mom's Bra; Mom's Coin Purse; Mom's Purse; Mom's Razor; Mom's Shovel; Monster Manual; Monstro's Tooth; Mr. Boom; Mystery Sack; No!; Pandora's Box; Pay to Play; Placebo; Polydactyly; Portab |
| `httpssteamusercontentaakamaihdnetugc1866176544840963061DF6AB94BA6CBFD107FAC7D013ABBC0D9047B84D5.jpg` | face | 7x5 | Remote Detonator; Restock; Sack Head; Sack of Pennies; Sacred Heart; Shadow; Shiny Rock; Smelter; Spider Mod; Spoon Bender; Starter Deck; Steamy Sale!; Suicide King; Synthoil; Tarot Cloth; Tech X; The Battery; The Blue Map; The Chest; The Compass; The D10; The D100; The D20; The D4; The Dead Cat (GUPPY); The Habit; The Map; The Midas Touch; The Polaroid; The Poop; The Relic; The Shovel; There's Op |
| `httpssteamusercontentaakamaihdnetugc1866176544840966319DE215329B56B212D243072631D72979F3F6C261E.jpg` | face | 2x2 | Apollyon; Azazel; The Keeper; The Lost |
| `httpssteamusercontentaakamaihdnetugc1866176544840970673C541BF9C5CC049F86514F94A9B3D92109CE39B97.jpg` | face | 5x4 | 2 Cents!; 3 Cents!; 4 Cents!; A Penny!; A Sack; Bomb!; Cancer; Charged Penny; Credit Card; Holy Card; Jera; Joker; Pills!; Pink Eye; Soul Heart; Two of Diamonds |
| `httpssteamusercontentaakamaihdnetugc18661765448409725188851594EBCF42FBA2B8C82E712C24C1C9CD82644.jpg` | face | 5x4 | Begotten; Boil; Charger; Curse of Fatigue; Curse of Tiny Hands; Death's Head; Fistula; Gaper; Gurglings; Hush; I Am Error!; Imp; Knight; Parabite; Polycephalus; Ragling; Round Worm; Steven; The Cage; Trap Door! |
| `httpssteamusercontentaakamaihdnetugc18661765448409747517E635EC37D4B2CEA97362A592A31A0BE052E92F2.jpg` | face | 5x4 | 9 Volt; Crooked Penny; Dad's Key; Fruitcake; Guppy's Tail; I Can't Belive It's Not Butter Bean; Infamy; Lemon Mishap; Library Card; Mom's Knife; More Options; Ouija Board; Placenta; Plan C; Skeleton Key; Soy Milk; Succubus; The Bible; The Butter Bean; The Missing Page |
| `httpssteamusercontentaakamaihdnetugc1866176544840976105D802CB1AF5CA7CC551FCA555E98316CC150DAC37.jpg` | face | 2x2 | Holy Mantle; Lord of the Pit; Void; Wooden Nickel |
| `httpssteamusercontentaakamaihdnetugc1866176544840981770E656A25796B09B8E3B10D61BB08FA6DBEB055A2D.jpg` | face | 2x2 | Bum-Bo; Dark Judas; Guppy; Whore of Babylon |
| `httpssteamusercontentaakamaihdnetugc1866176544840983960421887E07622538954055A6E5A372C525FDE2073.jpg` | face | 6x5 | 2 Cents!; 3 Cents!; 4 Cents!; ? Card; A Nickel!; A Penny!; AAA Battery; Ansuz; Black Rune; Bomb!; Butter Bean!; Dice Shard; Get out of Jail Card; Gold Key; Lil Battery; Perthro; Pills!; Poker Chip; Tape Worm; The Left Hand |
| `httpssteamusercontentaakamaihdnetugc1866176544840985967FB17F3F16A3D067D87E26AAAFB44E2A3DB4A14CC.jpg` | face | 6x5 | Angel Room; Blastocyst; Bony; Boss Rush!; Brain; Crused Tumor; Curse of Blood Lust; Curse of Impulse; Cursed Globin; Dingle; Flaming Hopper; Globin; Head Trauma; Headless Horseman; Holy Bony; Holy Chest; Holy Mulligan; Isaac!; Krampus; Mom's Heart!; Monstro II; Nerve Ending; Roundy; Spiked Chest; Sucker; Swarmer; The Fallen; Troll Bombs; Tumor; Widow |
| `httpssteamusercontentaakamaihdnetugc1866176544840988257C16334E95B5711D71E4AF6E0F41056B827793FBA.jpg` | face | 6x5 | 1-Up; 20/20; Abaddon; Athame; Black Candle; Cursed Eye; Daddy Long Legs; Distant Admiration; Divorce Papers; Euthanasia; Forget Me Now; Game Breaking Bug!; Guppy's Eye; Head of Krampus; Head of the Keeper; Hourglass; Lard; Libra; Magnet; Mama Haunt; Mom's Eye Shadow; Mutant Spider; P. H. D.; Polyphemus; Rainbow Baby; Red Candle; Rubber Cement; Smart Fly; Telepathy for Dummies; The Wiz |
| `httpssteamusercontentaakamaihdnetugc1866176544840990204DD27D0FC38B54B5F8827EDD2C6184835C48523AE.jpg` | face | 2x2 | Bag-O-Trash; Dark Arts; Gimpy; Infestation |
| `httpssteamusercontentaakamaihdnetugc1866176544840997610B9F2E73E04CB98B95D2D68CE93DDFBC92699BA7B.jpg` | face | 3x2 | Soul of Envy; Soul of Lust; Soul of Pride; Soul of Sloth; Soul of Wrath |
| `httpssteamusercontentaakamaihdnetugc18661765448410009032EE00FA60C6120C98E87F0FE1EF395D018709DBB.jpg` | face | 5x5 | Bethany; Eden; Flash Isaac; Jacob & Esau; The Baleful; The Benighted; The Broken; The Capricious; The Curdled; The Dauntless; The Deceiver; The Deserter; The Empty; The Fettered; The Harlot; The Hoarder; The Miser; The Savage; The Soiled; The Zealot |
| `httpssteamusercontentaakamaihdnetugc18661765448410036984860B8D45F95F3845ABF278FA5027C28862A46D9.jpg` | face | 7x5 | 2 Cents!; 3 Cents!; 4 Cents!; A Nickel!; A Sack; Ace of Diamonds; Algiz; Bag Lunch; Berkano; Black Heart; Bomb!; Broken Remote; Butter Bean!; Callus; Dad's Note; Dice Shard |
| `httpssteamusercontentaakamaihdnetugc18661765448410059998CAD9553A7EC6FB1AB819A6E27E93B9DF6831D02.jpg` | face | 5x4 | A Lucky Penny!; Emergency Contact; Golden Trinket; Hagalaz; Key; Lil Battery; Lucky Toe; Magic Marker; Mega Bomb!; Pills!; PILLS!; Rib of Greed; Soul Heart; Sticky Nickel; Tick; Two of Spades; Wishbone |
| `httpssteamusercontentaakamaihdnetugc18661765448410088052D7022581BE8936AF66A065B95F025E1B21E3FD6.jpg` | face | 7x5 | Baby Plum; Betrayal; Brownie; Charmed Bony; Charmed Clotty; Charmed Dip; Charmed Fat Bat; Charmed Fatty; Charmed Globin; Charmed Greedling; Charmed Keeper; Charmed Monstro; Clog; Corny; Curse of Empathy; Curse of the Hollow; Curse of the Hunted; Curse of the Soulless; Cursed Dople; Cursed Lil Haunt; Cursed Mulliboom; Cursed Mulligan; Dogma; Double Treasure; Dressing Table; FAT FUCK FRIDAY: JOJO RE |
| `httpssteamusercontentaakamaihdnetugc186617654484101111491A2EEDB9B3B431DD8159C59A4D9A912EC1CF4D3.jpg` | face | 5x4 | FAT FUCK FRIDAY: JOJO REFERENCE; Mega Satan; Mother!; Mother's Shadow!; Mushroom; Null; Overflow; Peeping Fatty; Pitfall; Rag Mega; Sisters Vis; The Rainmaker; The Scourge; The Siren; TNT Barrel; Troll Bombs; Turdlings; Ultra Greed!; Whipper |
| `httpssteamusercontentaakamaihdnetugc18661765448410139725F377A8E66DA69AB48B8AE6BF13B605CDE2C1A44.jpg` | face | 7x7 | All Hallows' Eve; Angelic Intervention; Battle Royale!!!; Battle Royale!!!!; Battle Royale!!!!!; Beggar; Black Champions; Blessing of Gluttony; Blessing of Greed; Blessing of Steam; Blessing of the Inner Eye; Blessing of the Sack; Blind Rage; Blood Donation; Blood Lust; Blood Money; Bomb Bum; Bum-Bo is Loose!; Butter Fingers; Challenge Room; Conjoined Twin; Devil Beggar; Dice Room!; Dice Room!!; D |
| `httpssteamusercontentaakamaihdnetugc186617654484101485159FCBB99DEEC8C7B4395120B8B9449A3C7FD54FF.jpg` | back | 7x7 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1866176544841018441D0A3FE638015C29200057B8899ECBC6D6CBA9881.jpg` | face | 3x4 | Shadow of Famine; Shadow of War; Shell Game; Slot Machine; Social Goals!; Spider Webs; Splash Damage; Spoils of War; Static Shock; Tax for the Mighty; The Mirror; White Champions |
| `httpssteamusercontentaakamaihdnetugc1866176544841021828ABA6E739ED27BF514137E56D4C1BE1E4DE9CFC22.jpg` | face | 5x4 | Abyss; Bag of Crafting; Berserk; Book of Virtues; Ceremonial Blade; Classic Roller; Dead Weight; Flip; Gello; Glitch; Hemoptysis; Hypercoagulation; IBS; Keeper's Bargain; Lemegeton; Sibling Rivalry; Soulbond; Spindown Dice; Sumptorium |
| `httpssteamusercontentaakamaihdnetugc1866176544841025983637DE3E4EE5DD8D57C13ABFDE8E423FA558318C6.jpg` | face | 7x5 | Abel; Alabaster Box; Auction Gavel; Backstabber; Ball of Bandages; Battery Pack; Birthright; Blood Puppy; Bobby Bomb; Book of the Dead; Car Battery; Chocolate Milk; Consolation Prize; Cursed Soul; Damocles; Eternal D6; Experimental Treatment; Fetal Haunt; Fire Mind; Friendly Ball; Friendly Sack; Gnawed Leaf; Hallowed Ground; Halo of Flies; Hand-Me-Downs; Handicapped Placard; Jar of Flies; Judas' S |
| `httpssteamusercontentaakamaihdnetugc186617654484102963552E8471F5EA735E4A6F3DE6AC27C857B6B7FB564.jpg` | face | 5x4 | Lunch; Magic Skin; Mama Mega; Marbles; Member Card; Mom's Bottle of Pills; Pageant Boy; Playdough Cookie; Punching Bag; Rock Bottom; Sacrificial Dagger; Spelunker Hat; The clicker; The Jar; Trick Penny; ULTRA FLESH KID!; Undefined; X-Ray Vision |
| `httpssteamusercontentaakamaihdnetugc18661765448410383476C5120D1D284B525934A3834D9FB71D57396F90B.jpg` | face | 1x1 | Strawberry |
| `httpssteamusercontentaakamaihdnetugc1866176544841040140E0298BAFA2C9DBFE8715FF8FCFAB965D869C740B.jpg` | face | 5x4 | Abe (Oddworld); Ash (The End is Nigh); Baba (Baba is You); Blind Johnny (Johnny the Homicidal Maniac); Blue Archer (TowerFall); Boyfriend (Friday Night Funkin'); Bum-Bo the Weird (Legend of Bum-Bo); Captain Viridian (VVVVVV); Crewmate (Among Us); Edmund (McMillen - yes, that one); Guy Spelunky (Spelunky); Johnny (The Room); Pink Knight (Castle Crashers); Psycho Goreman (PG: Psycho Goreman); Quote  |
| `httpssteamusercontentaakamaihdnetugc186617654484104240086A3209214BF844D8107F4D59DC5019479D99AA0.jpg` | face | 4x3 | Bible Thump!; Blanks; Cheep Cheep Cheep!; Cow on a Trash Farm; Cunk of Amber; Demon Form; Fiend Fire; Greed Butt; Jester; Loot Card; Murder!; Witch |
| `httpssteamusercontentaakamaihdnetugc186617654484104555142ADDBA9F34C93D3EB92A882752807789F49A71C.jpg` | face | 7x5 | A Dead Horse; Ballos!; Balrog; Brea in Distress; Curse of the Suspicious; Death Trapper; Don't Starve!; Exposito; Fuck Bloat; Golden Idol; Grandparent; Grubfather; Hubert Cumberdale; Javon!; Keke is You; Leatherneck; Lil Hunter; Melquiades; Nightmare Tick; Peeper; Qwop!; Shopkeeper!; The Butcher; The Collector; The Gorm; The Impostor!; The Purple-Shirted Eye Stabber; The Radiance; Time Eater; Tria |
| `httpssteamusercontentaakamaihdnetugc186617654484104772097E5D23F8D1A5FC8FC519AF62B48D843E5EF9599.jpg` | face | 5x4 | Ball of Tumors; Bow and Arrow; Emergency Meeting; Focus; Football; Girlfriend; Gravity; Hunky Boys; Is You; Johnny's Knives; Lil Steven; Lollypop; Pop Pop!; Possession; Ring of the Snake; Rusty Spoons; Spelunking Pack; Strange Marble; The Real Left Hand |
| `httpssteamusercontentaakamaihdnetugc18661765448410493584A6899D7B9A556B8CE0473C3C3081D7EFEA6F5AA.jpg` | face | 1x1 | The Isaac of Isaac: ReIsaac |
| `httpssteamusercontentaakamaihdnetugc18661765448410514212E08D01B5AC9681FB804140647C79417C30305F5.jpg` | face | 4x4 | Aubrey; Birthday Cake; Boxing Glove; Diogenes' Pot; Doorway; George; Gun That can Kill the Past; Hitops; Newgrounds Tank; Ser Junkan; Spewer; The Crowdfunder; Tony; Water Bottle |
| `httpssteamusercontentaakamaihdnetugc1866176544841056468C7A304F4AC73272A6E74E53778FEA83338BE3D9B.jpg` | face | 4x4 | Azazel (Alt); Blue Baby (Alt); Eden (Alt); Guppy (Alt); Isaac (Alt); Judas (Alt); Lilith (Alt); The Capricious (Alt); The Forgotten (Alt); The Harlot (Alt); The Keeper (Alt); The Lost (Alt); The Savage (Alt) |
| `httpssteamusercontentaakamaihdnetugc1866176544841058836B82DE9915D4A6B91755899557F310AA142586BE2.jpg` | face | 2x2 | Lost Soul (Alt); XIII. Death (Alt); XVII. The Stars (Alt) |
| `httpssteamusercontentaakamaihdnetugc186617654484106042024D1A466E4AA54CCDCE32733FA39B25420D59EC4.jpg` | face | 7x5 | Ambush! (Alt); Begotten (Alt); Big Bony (Alt); Brownie (Alt); Clotty (Alt); Daddy Longlegs (Alt); Dark One (Alt); Delirium (Alt); Devil Deal (Alt); Dingle (Alt); Famine (Alt); Fistula (Alt); Gaper (Alt); Gurdy (Alt); Hornfel (Alt); It Lives! (Alt); Larry Jr. (Alt); Little Horn (Alt); Mega Fatty (Alt); Mega Satan (Alt); Mega Satan! (Alt); Min Min (Alt); Mom! (Alt); Mom's Hand (Alt); Monstro (Alt);  |
| `httpssteamusercontentaakamaihdnetugc1866176544841062361C9E32C33D5FE3FFF55E6F5353BD0BAF2E0959816.jpg` | face | 3x3 | Shop Upgrade! (Alt); The Beast (Alt); The Bloat (Alt); The Duke of Flies (Alt); The Lamb (Alt); Twitchy (Alt); Ultra Greed! |
| `httpssteamusercontentaakamaihdnetugc18661765448410645213981ED48976DECADFAF0F467EE5586EBF6AD2049.jpg` | face | 2x2 | Brimstone (Alt); Epic Fetus! (Alt); Godhead (Alt); Guppy's Paw (Alt) |
| `httpssteamusercontentaakamaihdnetugc186617654484106887258569E639666CB5520706424BA627BEB2774D781.png` | face | 1x1 | The Enigma |
| `httpssteamusercontentaakamaihdnetugc1866176544841069185B56B1D7A3A1E2940FE63E2B41ADCC80575CF07CA.png` | back | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc186617654484107219449F4A37676F658AB72E2A9ED6A447F053740C9E0.png` | face | 1x1 | Anima Sola |
| `httpssteamusercontentaakamaihdnetugc1866176544841072477CEB107B5DA316A15C53DE2FA34C53CF55F014782.png` | back | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1866176544841078208ED7F951E06A820CC9B72C10837C7C2F74238F29A.png` | face | 1x1 | Polar Star |
| `httpssteamusercontentaakamaihdnetugc1866176544841078508E3C92B38A9F0F08DFD7B62229E0AA4C3AB758FE0.png` | back | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc1866176544841080610EA6224ED7DD267AFCD8C8BC5DFE141D699383D0F.png` | face | 1x1 | The Harbingers |
| `httpssteamusercontentaakamaihdnetugc1866176544841080885B1ED820557798D28C3AAE6EDF1407902BC4A69BF.png` | back | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc188534592464680229172EF98CE7DA02D3ECE1819FC8AE17B087CBF2F4B.jpg` | face | 1x1 | Mischevious The Haunt (Normal) |
| `httpssteamusercontentaakamaihdnetugc1885345924646803243CC41F3CA4564ADA9B8546ACAF306FC9423B44D98.jpg` | face | 1x1 | Mischevious The Haunt (Hard) |
| `httpssteamusercontentaakamaihdnetugc1885345924646804207798DD44063F48FD501BA8401D1B6C0085D8B3F3B.jpg` | face | 1x1 | Mischevious The Haunt (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc188534592464680638498A27E4818EB7706479DB54DFB66DC657A6805D9.jpg` | face | 1x1 | Trick |
| `httpssteamusercontentaakamaihdnetugc18853459246468069758FD4171BA2DC03D72529C4051B949C14207330CD.jpg` | back | 1x1 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc191573683349408018738B82D925C9F02F2BD7A54D4EA85B8AEA9E5E204.jpg` | face | 1x1 | Masquerade (Normal) |
| `httpssteamusercontentaakamaihdnetugc1915736833494081304FB8448D59F1BDA4594DE8114448E4B04822CFAE8.jpg` | face | 1x1 | Masquerade (Hard) |
| `httpssteamusercontentaakamaihdnetugc1915736833494082123B2D30CAF7502E45FBEAE8CC6D9508BF016649DCA.jpg` | face | 1x1 | Masquerade (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1915736833494083850FF70929252FB6EC16CB235EC2748EC7AFF934CBA.jpg` | face | 1x1 | Anonymous Mask of Infamy (Normal) |
| `httpssteamusercontentaakamaihdnetugc1915736833494085144B6AC787A7A4BEF204376D336C230BD00ABF366BB.jpg` | face | 1x1 | Anonymous Mask of Infamy (Hard) |
| `httpssteamusercontentaakamaihdnetugc1915736833494085950148A9864B9C1604163B23BB370AF12276387EE79.jpg` | face | 1x1 | Anonymous Mask of Infamy (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc19495246665118988651B99BCC71EB12EC1F1FE8BD377B77306C3D1C018.jpg` | face | 1x1 | Fatty's Feast (Normal) |
| `httpssteamusercontentaakamaihdnetugc1949524666511899574A5B8D342E925EC07BEAEB9FA39250AF5D59E3FA2.jpg` | face | 1x1 | Fatty's Feast (Hard / Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc19495246665119003189BF2E8A6E339AF838AE3C01C7464077E5EE0E39D.jpg` | face | 1x1 | Engorged Mega Fatty (Normal) |
| `httpssteamusercontentaakamaihdnetugc1949524666511900951F111F3416F894653AA3A542B34DF4942E4DE5E1C.jpg` | face | 1x1 | Engorged Mega Fatty (Hard) |
| `httpssteamusercontentaakamaihdnetugc1949524666511901522103B5423C9419E945B01C5A1D92174AE0AC9C2D2.jpg` | face | 1x1 | Engorged Mega Fatty (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc1949524666513944604E7E39826CA1252A46B77326D636900E44C6FE06D.jpg` | face | 8x3 | Cube of Meat; Dad's Ring; Eden's Soul; Glitter Bombs; Lil Delirium; Lump of Coal; Mom's Heels; Mom's Lipstick; Mom's Ring; Mom's Underwear; My Little Unicorn; Number One; Number Two; Pumpkin Mask; Satanic Bible; Seraphim; The Mark; The Nail; The Stairway; Three Dollar Bill |
| `httpssteamusercontentaakamaihdnetugc1949524666513972025E2A8E13A9ACDB577567C4279AB30D7E2DF9F9A19.jpg` | face | 2x2 | Butt Penny!; Short Fuse |
| `httpssteamusercontentaakamaihdnetugc19495246665139907466DEF733BECB4E64842610D4B48F79ADB88A4CB06.jpg` | face | 2x2 | Delirium |
| `httpssteamusercontentaakamaihdnetugc194952466651400673069D2DC89233763A0689C17DA1832B78DC549FA30.jpg` | face | 1x1 | Black Market |
| `httpssteamusercontentaakamaihdnetugc2028342823250673195C95FE1E92B2EBB103715F8479F108A5A3B59CA82.jpg` | back+face | 1x1 | Treasures |
| `httpssteamusercontentaakamaihdnetugc2035101394913206905BE71E70176A4B746663B59C2AB22E3EA5C5A3AD2.jpg` | face | 1x1 | Lascivious Lust (Normal) |
| `httpssteamusercontentaakamaihdnetugc2035101394913207438A89732E1BF90E23406F763520290577261AA1B51.jpg` | face | 1x1 | Live, Laugh, Lust (Normal) |
| `httpssteamusercontentaakamaihdnetugc2035101394913208803481F781DA000230136D238E3286FEA115ED0E3F6.jpg` | face | 1x1 | Lascivious Lust (Hard) |
| `httpssteamusercontentaakamaihdnetugc2035101394913209556EC181D1683DDAD8B4BBA9FF03FD292A96B447137.jpg` | face | 1x1 | Lascivious Lust (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc2035101394913211686A3564737CC3EDAC65344733D048EA93FE301199D.jpg` | face | 1x1 | Live, Laugh, Lust (Hard / Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc2038490505484380666C22683829EDA18D12CFC80B321B6BAF713EF8453.jpg` | face | 1x1 | Brimstone |
| `httpssteamusercontentaakamaihdnetugc2038490505484382955AB15D44D08E662C9036DBB93D4EA733E0C9B985B.jpg` | face | 1x1 | G Fuel! (Blue) |
| `httpssteamusercontentaakamaihdnetugc2038490505484384296913554F400A2306C50C8383C76A2E175E22A40CD.jpg` | face | 1x1 | G Fuel! (Red) |
| `httpssteamusercontentaakamaihdnetugc2038490505484384841BAA5B7DC189B4D25B9BC3F105CC968D53565EC78.jpg` | face | 1x1 | Isaac's Tears |
| `httpssteamusercontentaakamaihdnetugc20384905054844855471F9A6BE31E8F8EE9DA025576EB3A20216FCFBF3D.jpg` | face | 1x1 | Blank Canvas |
| `httpssteamusercontentaakamaihdnetugc20384905054844864242E3B7CDE301FB623C72A1F0DF17D7C1F98EE11FA.jpg` | face | 1x1 | Blank Canvas |
| `httpssteamusercontentaakamaihdnetugc20384905054845392269B7DAACAC1E19DAE748F51511B18A13EC444FC78.jpg` | face | 1x1 | The Doodler (Normal) |
| `httpssteamusercontentaakamaihdnetugc203849050548454045171A3F385358D464598B08569D716075E9AF62645.jpg` | face | 1x1 | The Doodler (Hard) |
| `httpssteamusercontentaakamaihdnetugc20384905054845414956CFA375FB40A8B4B4CB78640410644609EAAF4C6.jpg` | face | 1x1 | The Doodler (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc2038490505484550154772DC83C81EA8B764ECA88DC247BCA8995FF1786.jpg` | face | 1x1 | Day of the Doodler (Normal) |
| `httpssteamusercontentaakamaihdnetugc20384905054845510742306F877ABA7364C3C1FB499B17A63A5735222C7.jpg` | face | 1x1 | Day of the Doodler (Hard) |
| `httpssteamusercontentaakamaihdnetugc2038490505484551942945B6F5920303592D38E72EEFA65BA34BFA9A53E.jpg` | face | 1x1 | Day of the Doodler (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc2038490505484609327EA8C131E2C169C5D686C6F989712C67341311675.jpg` | face | 1x1 | Marauding Daddy Long Legs (Normal) |
| `httpssteamusercontentaakamaihdnetugc2038490505484609961ADDC451D10BA276185C5DD7883BC1E4C8AA2A5F9.jpg` | face | 1x1 | Marauding Daddy Long Legs (Hard) |
| `httpssteamusercontentaakamaihdnetugc203849050548461896670E60225F98DE9F221218B2594E0C3DCD4027B29.jpg` | face | 1x1 | Marauding Daddy Long Legs (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc20384905054846346236340910730688C2F6A191EE43288EF20300ED57E.jpg` | face | 1x1 | Stomping Ground (Normal) |
| `httpssteamusercontentaakamaihdnetugc203849050548463655528FC02690B0645BFF7D4DBC355F0B97108296588.jpg` | face | 1x1 | Stomping Ground (Hard) |
| `httpssteamusercontentaakamaihdnetugc203849050548463722058D6D0AB50E790A7C883ED11795127F4891A01C0.jpg` | face | 1x1 | Stomping Ground (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc203849050548468660967B3F7ED6E87A2B102EA46DCA0C992F757062B20.jpg` | face | 1x1 | Cain (Unboxing) |
| `httpssteamusercontentaakamaihdnetugc203849050548468699650220CF9ED4264A7F9D2431579EB6FE9ABFE71BA.jpg` | face | 1x1 | Isaac (Unboxing) |
| `httpssteamusercontentaakamaihdnetugc20384905054846873997E431D181FBFF8971979361054B9C27F145E6542.jpg` | face | 1x1 | The Lost (Unboxing) |
| `httpssteamusercontentaakamaihdnetugc203849050548968022519078E8DEE2A2E5A8AE7AD71C41D6FB4E814AD03.jpg` | face | 1x1 | Lost Soul (Con Promo) |
| `httpssteamusercontentaakamaihdnetugc2477623897033657762F969230A1F357890DBAD6E11EA18ED14347F099B.png` | face | 2x2 | Clubby the Seal; Gish; Stacy |
| `httpssteamusercontentaakamaihdnetugc247762389703365886707A8B8A18CB003A8A6A169AAE63C42CC9AB9A8F3.jpg` | back | 2x2 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc2477623897033690911125E707CC4513B29FBE5BAEA73A864D7A05210E6.jpg` | face | 2x2 | Ball of Tar; Club; Unstable DNA |
| `httpssteamusercontentaakamaihdnetugc2477623897033721306922D02D4E53ED37378184390ED9AAA2A19D8C37B.jpg` | face | 2x2 | A Friend; Blast Miner TNT!; The Monster; Tumor Ball |
| `httpssteamusercontentaakamaihdnetugc2477623897033769341607AECC43B2AF05FCB3EDDD48E830D0EDAFA6A28.jpg` | face | 3x2 | Cereus Peashy; Coil; Light Switch; Police Lineup; Weltling |
| `httpssteamusercontentaakamaihdnetugc24776238970337715081BDD58022B50172A1975E6484495D149B07A2FF4.jpg` | back | 3x2 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc2500137370197056368E450C4A71C701868F80AD5FB0FCF47C79E2DFBC5.jpg` | face | 6x6 | Destiny Deck |
| `httpssteamusercontentaakamaihdnetugc2500137370197057941A9198D442738E44182398360B94B18A8AD7EDC24.jpg` | back | 6x6 | _card-back sheet (reverse side of a deck sheet)_ |
| `httpssteamusercontentaakamaihdnetugc2500137370197249472100B17F7C26483EB9976FA4698F373EBF7E5AD5C.jpg` | face | 1x1 | Who Am I? (Normal) |
| `httpssteamusercontentaakamaihdnetugc250013737019725161117DEDDF5124F5299689A8F403FF718C20209EB6E.jpg` | face | 1x1 | Who Am I? (Hard) |
| `httpssteamusercontentaakamaihdnetugc2500137370197252644B0296D268F292529E9AF0D14BD02361E70ED129F.jpg` | face | 1x1 | Who Am I? (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc25001373701972606546529A7BEDDC660D43C3037DB75157C8A7126D8F5.jpg` | face | 1x1 | Fragmenting Isaac (Normal) |
| `httpssteamusercontentaakamaihdnetugc2500137370197261781FE6F23298B7EDFF4054575ED8461278FE254AE01.jpg` | face | 1x1 | Fragmenting Isaac (Hard) |
| `httpssteamusercontentaakamaihdnetugc25001373701972664816A6B8F4BE7665A0380EB9135FCDB2DA2812319EC.jpg` | face | 1x1 | Fragmenting Isaac (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc5094165732988289185D77FAB7528F9C3AE9E1AC9840491B35F261D9779.jpg` | face | 1x1 | How the Krampus Stole Christmas (Normal) |
| `httpssteamusercontentaakamaihdnetugc509416573298828989301428B90B41DC242ADFA2778726A6E2D0A694C63.jpg` | face | 1x1 | How the Krampus Stole Christmas (Hard) |
| `httpssteamusercontentaakamaihdnetugc50941657329882907254223DEBA509E075AB2A9878E0FB3E98AAC3880FF.jpg` | face | 1x1 | How the Krampus Stole Christmas (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc50941657329882916434CFC5078CC2EAFCB5D5F9F7DFCD6ACF3F1EE4D51.jpg` | face | 1x1 | Pilfering Krampus (Normal) |
| `httpssteamusercontentaakamaihdnetugc5094165732988292466DC4586DA63C4EECC15996CC7D04E576F8E7B5D21.jpg` | face | 1x1 | Pilfering Krampus (Hard) |
| `httpssteamusercontentaakamaihdnetugc50941657329882931514B98A65E6D37E96E082EFC812C83090F21715677.jpg` | face | 1x1 | Pilfering Krampus (Ultra Hard) |
| `httpssteamusercontentaakamaihdnetugc5094165733004125525452AC2F7B6AB35660C387FCCB503046AA3505738.jpg` | face | 1x1 | Loki |
| `httpssteamusercontentaakamaihdnetugc5094165733004127023200EFBF75351BD33A3A9B595B9E3EDA5AC78BA1A.jpg` | face | 1x1 | The Adversary |
| `httpssteamusercontentaakamaihdnetugc5094165733004127441BB84ABAA45F42AED03A4A40D3EA7A69C2843B4A9.jpg` | face | 1x1 | Big Horn |
| `httpssteamusercontentaakamaihdnetugc5094165733004131769089C68932D1FA4AF0BC198F7835904B9F683AA95.jpg` | face | 1x1 | Pyromaniac |

---

## Reference files

### 3D models — `tts/Mods/Models/`

| File | Note |
|---|---|
| `httpspastebincomraw00YWZ28Y.obj` | 3D coin model (Blender 'coin.blend'); diffuse = coin texture in Images/ |

### TTS save & preview — `tts/Mods/Workshop/`

- `2501791757.json` — the authoritative Tabletop Simulator save. Contains every
  deck, its card names, image URLs and grid layout. Used as the cross-reference
  source for this index. The in-game decks are: Bonus Souls, Characters, Starting
  Items, Monsters, Loot, Treasures (plus every promotional set as a Bag).
- `2501791757.png` — Steam Workshop preview image.

### Print PDFs — `tts/Mods/PDF/` (15 files)

| File | Size (bytes) |
|---|---|
| `httpssteamusercontentaakamaihdnetugc1866176544836211828F536BFADEBAA0938504156758939CFB7749C7DF2.PDF` | 9817471 |
| `httpssteamusercontentaakamaihdnetugc1885345924646772309C90D3393A230F6942B7646F35C287E1F2A7E0011.PDF` | 22985097 |
| `httpssteamusercontentaakamaihdnetugc1949524666511896296944B4BF37A98506CB1AE310D9E7059B7837BA689.PDF` | 2825031 |
| `httpssteamusercontentaakamaihdnetugc19495246665139042856A658B05C8A656C49D2E510DDC8C3A61B2478543.PDF` | 2963351 |
| `httpssteamusercontentaakamaihdnetugc1949524666513930730B93FB539F0380782F4B017EE96118AA22C95E42A.PDF` | 4200037 |
| `httpssteamusercontentaakamaihdnetugc1949524666513982162468B03F36956D47CA8CD0E9781BC8F3AEF5D566C.PDF` | 2911057 |
| `httpssteamusercontentaakamaihdnetugc19495246665140022930A39B9C4F01CAF0862A3ED81A35F0720D9D6E4EB.PDF` | 3740903 |
| `httpssteamusercontentaakamaihdnetugc194952466651401255425B33E051D775395F0A2D72CA82C0F422D7B72C9.PDF` | 3173137 |
| `httpssteamusercontentaakamaihdnetugc1949524666514014152E0A6D6534393F2D9D268E7E5906BEE599C15638C.PDF` | 3029372 |
| `httpssteamusercontentaakamaihdnetugc1949524666514015076AAFB6E8C545C6F371F313D4184C26B93C5405E28.PDF` | 2162932 |
| `httpssteamusercontentaakamaihdnetugc203510139491320505771D1ADADFD4EB8E8914408868D08BCC0512B84B1.PDF` | 2864579 |
| `httpssteamusercontentaakamaihdnetugc20384905054845235996462431CD836C2617997312ECC09D9DECA0ABFA4.PDF` | 2981073 |
| `httpssteamusercontentaakamaihdnetugc203849050548463809150C19CB9157682EA07AC62198136C79689AF5F0E.PDF` | 2406151 |
| `httpssteamusercontentaakamaihdnetugc250013737019719489151E6E8B5032DFF9A601F593C729817E667BACB7B.PDF` | 5183040 |
| `httpssteamusercontentaakamaihdnetugc5094165732988286598026FD4FE7FA809FDC20245D517084848AB154C22.PDF` | 3358283 |

Other docs at project root: `doc base.pdf`, `main.pdf`.

## Caveats
- Canonical 'name' is normalized from the on-disk filename; 'file' is the literal path.
- Filenames replace apostrophes with underscores (Bob_s Brain -> Bob's Brain) and drop some punctuation.
- tts/Mods/Images filenames are lossy encodings of source URLs; each entry carries the original URL.
- Deck sheets are composite images: 'cards' lists the card faces TTS places on that sheet, 'grid' is the WxH tile layout.
- subkind for Monsters/Rooms/Loot is heuristic (filenames do not encode card type).
- 'copy' marks numbered duplicates of the same card (e.g. 'A Penny', 'A Penny 2').
