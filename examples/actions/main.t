#include <vhyl.h>
#include <vhyl.t>
#include <vhyl-en.t>
#include <vhyl-actions.t>

workshop: Room 'Workshop' desc = "A cabinet stands beside the workbench. ";
cabinet: Container 'cabinet' location(workshop) vocab = 'cabinet'
    isOpenable = true isOpen = nil isLockable = true isLocked = true keyItem = brassKey
;
brassKey: Thing 'brass key' location(player) vocab = 'key; brass' isFamiliar = true;
steelKey: Thing 'steel key' location(player) vocab = 'key; steel' isFamiliar = true;
parcel: Thing 'parcel' location(workshop) vocab = 'parcel';
attendant: Actor 'attendant' location(workshop) vocab = 'attendant';

/* Discovery and defaults belong to the game. Both keys remain plausible. */
modify unlockAction
    affordance(c)
    {
        if (c.dobj != cabinet || !c.actor.knowsAbout(cabinet)) return nil;
        if (c.iobj != nil && !c.actor.knowsAbout(c.iobj)) return nil;
        local f = new ActionAffordance();
        f.visible = true; f.labelId = 'menu.unlock';
        return f;
    }
;
modify examineAction
    affordance(c)
    {
        if (c.dobj == nil || !c.actor.knowsAbout(c.dobj)) return nil;
        local f = new ActionAffordance();
        f.visible = true; f.labelId = 'menu.examine'; f.isDefault = true;
        return f;
    }
;
modify giveAction
    affordance(c)
    {
        if (c.dobj != nil && !c.actor.knowsAbout(c.dobj)) return nil;
        if (c.iobj != nil && !c.actor.knowsAbout(c.iobj)) return nil;
        local f = new ActionAffordance();
        f.visible = true; f.labelId = 'menu.give';
        return f;
    }
;
unlockLabel: Message id = 'menu.unlock' text = 'Unlock with…';
examineLabel: Message id = 'menu.examine' text = 'Examine';
giveLabel: Message id = 'menu.give' text = 'Give to…';

modify gameMain initialRoom = workshop;
startup() { return vhylStart(); }
turn(tokens) { return vhylTurn(tokens); }
#ifndef CUSTOM_ACTION_ENTRY
act(verb, args) { return vhylAct(verb, args); }
#endif
