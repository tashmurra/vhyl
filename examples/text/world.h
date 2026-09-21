#include <vhyl.h>
#include <vhyl.t>
#include <vhyl-en.t>

workshop: Room 'Workshop'
    desc = "A workbench stands beside an open doorway to the north. "
    exits(gallery, north)
;
gallery: Room 'Gallery'
    desc = "A doorway leads south to the workshop. "
    exits(workshop, south)
;
gauge: Thing 'brass gauge' location(workshop)
    vocab = 'gauge; brass'
    desc = "A portable pressure gauge. "
;
caseBox: Container 'case' location(workshop)
    vocab = 'case; storage'
    isOpenable = true
    isOpen = nil
;
weight: Thing 'reference weight' location(workshop)
    vocab = 'weight; reference'
    refuses(a, c) { return a == takeAction ? 'The reference weight stays here.' : nil; }
;
attendant: Actor 'attendant' location(workshop) vocab = 'attendant';
route: Topic 'route' vocab = 'route';
routeAnswer: TopicEntry actor = attendant matchObj = route id = 'attendant.route';
routeMessage: Message id = 'attendant.route' text = 'The gallery is north of here.';
modify gameMain initialRoom = workshop;
