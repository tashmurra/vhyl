#include <vhyl.h>
#include <vhyl.t>
#include <vhyl-en.t>

station: Room 'Station' exits(platform, north);
platform: Room 'Platform' exits(station, south);
parcel: Thing 'parcel' location(station);
modify gameMain initialRoom = station;
startup() { return vhylStart(); }
/* An engine submits a verb code and entity handles instead of parsing text. */
act(verb, subjects) { return vhylAct(verb, subjects); }
