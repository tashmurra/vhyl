/* Original regression world: action effects, scheduling, topic dialogue and undo. */
#include "../../examples/text/world.h"
clock: object
    ticks = 0
    tick() { ticks += 1; return nil; }
;
pulse: Daemon owner = clock prop = &tick interval = 1;
status()
{
    "[state room=<<here().name>> held=<<contains.contains(player, gauge) ? 1 : 0>> boxed=<<contains.contains(caseBox, gauge) ? 1 : 0>> open=<<caseBox.isOpen ? 1 : 0>> weight=<<contains.contains(workshop, weight) ? 1 : 0>> ticks=<<clock.ticks>>]\n";
    return nil;
}
turn(tokens) { vhylTurn(tokens); return status(); }

startup() { return vhylStart(); }
