/* Public declarations for vhyl: relations, vocabulary and verification ranks.
 * Copyright (c) 2026 John Cunningham. MIT License; see LICENSE. */

enum token tokWord;
property firstTokenIndex, lastTokenIndex, tokenList;

property badness;
dictionary vhylDict;

property noun, adjective;

/*
 * The three tables a world is made of. Containment is one_to_many read from
 * either side; travel is a labelled family, one table per direction; vocabulary
 * lives in the dictionary.
 */
relation contains(container: Entity, item: Entity) one_to_many reverse location;
relation exits(from: Entity, to: Entity, way: Direction) one_to_one;
relation vocab(entity: Entity, word: Text, part: Vocabulary) many_to_many;

relation connects(door: Entity, room: Entity) many_to_many;

/*
 * Where a MultiLoc stands. Containment is one_to_many, so a thing has one
 * container and that is the right rule for nearly everything. A sky, a hedge or
 * a stretch of river is in several rooms at once and is not contained by any of
 * them, so it gets a table of its own rather than bending the containment one.
 */
relation presentIn(thing: Entity, room: Entity) many_to_many;

relation knows(knower: Entity, subject: Entity) many_to_many;

relation attachedTo(one: Entity, other: Entity) many_to_many;

+ property location;

enum Direction: north, south, east, west,
    northeast, northwest, southeast, southwest,
    up, down, inward, outward;

enum posIn, posOn, posUnder, posBehind;

enum standing, sitting, lying;

enum dobjRole, iobjRole;

#define TypeInt 7
#define TypeSString 8

#define FirstPerson  1
#define SecondPerson 2
#define ThirdPerson  3

#define rankLogical   100
#define rankDangerous  90
#define rankUnlikely   60
#define rankAlready    45
#define rankNotNow     40
#define rankIllogical  30
#define rankSelf       20

#define rankNonObvious 10
#define rankNever       0

#define rankImplicit  rankLogical

/*
 * These live in the header rather than beside the Action class because `#define`
 * is textual and sequential: a rank named in a class declared earlier in the
 * library would not be defined yet.
 */
