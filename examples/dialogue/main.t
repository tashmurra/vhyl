#include <vhyl.h>
#include <vhyl.t>
#include <vhyl-en.t>
#include <vhyl-dialogue.t>

archive: Room 'Archive';
archivist: Actor 'archivist' location(archive);
consultation: Conversation
    id = 'consultation'
    target = archivist
    choices = [routeQuestion, goodbye]
    opening(c) { return dialogueSay(target, 'archivist.welcome'); }
;
routeQuestion: DialogueChoice
    id = 'route'
    labelId = 'choice.route'
    once = true
    selected(c) { return dialogueSay(archivist, 'archivist.route'); }
;
goodbye: GoodbyeChoice;
welcome: Message id = 'archivist.welcome' text = 'Welcome to the archive.';
routeLabel: Message id = 'choice.route' text = 'Where is the reading room?';
routeReply: Message id = 'archivist.route' text = 'The reading room is upstairs.';
modify gameMain initialRoom = archive;
startup() { return vhylStart(); }
act(verb, args) { return vhylAct(verb, args); }
