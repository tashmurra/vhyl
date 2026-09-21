/* Original message selection regression with an inactive higher-priority override. */
#include "../../examples/text/world.h"
takeOverride: Message id = 'take.ok' priority = 10 text = 'Custom acquisition.';
inactiveOverride: Message id = 'take.ok' priority = 20 isActive = nil text = 'Inactive text must not appear.';
startup() { return vhylStart(); }
turn(tokens) { return vhylTurn(tokens); }
