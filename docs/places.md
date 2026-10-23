# The seven places

Design notes for the course's seven phases (phase-4 spec §6). Each phase is an avoidance
behaviour, set in a real place from one life, where something happened that the runner
never faced. The place is built from memory, so it is **liminal**: true in its details and
wrong in its proportions, empty of people, and floating in the void.

Blender is the design source (`art/course/<nn>-<place>.blend`). These notes say what each
place must make the player feel. The `.blend` says how it looks.

## The life

The runner is never named or seen (founding §6). Seven places, seven ages, and one phrase
that runs through all of them: their father's **"Don't make a scene."** The dark quotes it
back in the second person, and its swallow lines come from these events.

| # | Phase | Place | Age | What happened |
|---|---|---|---|---|
| 1 | Distraction | School corridors | 10 | Pulled out of class and told in the corridor that Mum had gone |
| 2 | Busyness | Kitchen at night | 14 | The birthday dinner that burnt during the argument |
| 3 | Blame | The car, night road | 15 | The drive to give the dog away |
| 4 | Denial | Hospital waiting room | 19 | Called in to see Dad, and didn't go |
| 5 | Numbing | A party | 19 | The night of the funeral |
| 6 | Isolation | The empty house | 23 | Clearing the family house alone |
| 7 | Spiralling | The bedroom, repeating | 26 | Now: the months of not leaving it |

## Rules that bind every place

- **Empty.** No people, ever. A crowd shows up only as what it leaves behind: coats on
  pegs, chairs pushed back, cups set down.
- **One wrongness per place.** One proportion or behaviour the real place would never
  have. It is the place's signature, and it reads at speed, from first person.
- **Fragments in the void.** No skybox and no horizon. Every place ends in black, and its
  edges are already coming apart at loop 0.
- **One dominant light** per place, plus practical lights (lamps, screens, signs) that
  can fail one by one.
- **Readable at speed.** Every surface you can ride is lit and lighter than its
  surroundings, with a hard edge against the dark. Dressing never sits on a lip or seam
  or in a sightline corridor (spec §5.2): readability beats atmosphere.
- **Room for lingering** (spec, Carried forward). Each place gets one **memory object**
  in a quiet pocket off the racing line. It stays visible from the line, and stopping
  there costs time.

## The fade, every loop

Memory loosens loop by loop, and the place goes before the feeling does. The fade is
**visual only**: it never moves a collider. Erosion (`erosion_logic.gd`) owns geometry and
the pursuit (`void_logic.gd`) owns pressure.

| Loop | Colour | Detail | Light | Edges | Memory object |
|---|---|---|---|---|---|
| 0 | full | every label, poster and name legible | all practical lights on | void bites the far ends | lit, full colour |
| 1 | −20 % | text blurs to shapes | 1 in 6 practical lights dead | edges fray ~1 m | unchanged |
| 2 | −45 % | posters and labels blank, small props gone | 1 in 3 dead, the rest flicker | ~3 m | unchanged |
| 3 | −65 % | furniture loses its smaller parts (handles, legs) | half dead | ~6 m, walls thin to frames | starts to desaturate |
| 4 | −80 % | only silhouettes keep their mass | one light per room | ~10 m | dulled, and still lit |
| 5 (plateau) | −90 %, near-monochrome | surfaces you ride, plus their edge lines | the dominant light only | ~15 m, rooms read as islands | **the last coloured thing in the place** |

The memory object holds on longest because it is what the runner keeps. At plateau the
place is outlines in the dark, and the one thing in colour is the thing they never put down.

---

## 1 · Distraction: School corridors

**What happened.** Age ten, a Tuesday, mid-afternoon. Dad came in during maths and took
them out into the corridor. Mum had "gone to stay with Gran." They started crying. Dad
gripped their shoulder: *"Don't make a scene."* Through the wired-glass panel in the
classroom door, every face in the class watched. After that, they were always on their way
somewhere: the next bell, the next room, the next thing.

**Verb.** Bhop straights and open ground: long corridors, the hall and the gym. You
always have somewhere to be.

**Wrongness.** The corridor never ends, and every classroom is the same classroom: chairs
up on the desks, the blinds half down, the clock at 2:40. The bell rings and nobody comes.

**Landmark.** Lockers in endless ranks with the doors' wired-glass panels between them.
The panel is the image the player keeps.

**Palette and light.** Cold fluorescent green-grey (phase-2 tint). Ceiling panels in long
rhythm lines that draw the eye down the straight. Waxed linoleum with long reflections.
One red EXIT sign at the far end, never reached.

**Memory object.** A child's yellow raincoat still on its peg, the only one left. Its name
tag is blank, the writing worn off (the runner is never named). The other pegs are empty.

**Fade.** The art and timetables go first, then the names on the lockers, then the
fluorescents, in the order they would fail. At plateau there is one corridor of light,
the outlines of the lockers, and the coat.

**Loop-back.** It's the course start, so loop-back recognition depends on its look. Its
silhouette (ranks of lockers, a ceiling of light strips) must read in one frame, even
at plateau.

---

## 2 · Busyness: Kitchen at night

**What happened.** Age fourteen, Mum's birthday. They cooked for the first time, and the
card was already on the fridge. Dad came home late and the argument started in the
hallway. The pan burnt while they listened. Afterwards they cleaned: they wiped every
counter, scrubbed the pan and put everything away until 2 a.m., so nobody had to talk
about it.

**Verb.** Wall rides, climbs, furniture scale. You are always moving, and you never get
off the counter tops.

**Wrongness.** Scale: they're a child on a giant's counters. Cupboard faces are ride
walls, and the gap between counters is a chasm. The oven clock reads **23:47** and never
changes. The tap runs and never fills the sink.

**Landmark.** The fridge, tall as a building, its door ajar and spilling cold blue light.

**Palette and light.** The warm amber of the cooker-hood bulb against the fridge's cold
blue. The two lights fight across the room. A wisp of smoke hangs near the ceiling.

**Memory object.** The burnt pan, scrubbed clean and set upside down on the drying rack.
The birthday card is on the fridge above it.

**Fade.** The fridge magnets and the card's writing go first, then the cooker-hood bulb.
At plateau only the fridge light is left: cold, blue and open.

**The course as built (#23).** The hob run (Godot −x) and the sink run (+x) face each other
across the chasm, worktop top at 9 m. Each run is a fixed back slab (|x| 4.0–9.6, where the
markers stand) and a front strip that erodes on x toward it, pinned at the seam. That makes
the chasm **3.0 m at loop 0 and 7.5 m at plateau** (0.9 m a loop). Both crossings run
straight across (z −24 and −34.5), so neither is ever longer than the chasm. Six gaps are
**barriers**, built never to be crossed on foot: wider than the 8.31 m reach at every loop
(hob run 8.5 m and 12.5 m, the broken sink run 8.5 m; slab and strip each). The 12.5 m one is
crossed only by the cupboard-face wall ride off the microwave. Behind those three gaps the
back wall is **open** from the floor to the cupboards' underside (each gap ±1.05 m), so no low
wall ride crosses a barrier: a rider who flies in falls and resets. Markers stand 0 / 40.3 /
56.3 m along the line, and the door at 89.6 m is the landing by the rack. The calendar hangs on
the sink-side wall across the first crossing.

---

## 3 · Blame: The car, night road

**What happened.** Age fifteen, after the divorce. Dad drove them and the dog, Biscuit,
two hours to a farm because "the flat doesn't allow dogs." They spent the whole drive
shouting that it was Mum's fault. Biscuit's lead lay on the back seat on the way home.

**Verb.** Kickers and aggressive verticality: outward force. The first hard-stop
obstacles.

**Wrongness.** The road is inside the car, and the car is inside the road. Seat backs
rise like cliffs, the dashboard is a ridge, and the windscreen opens onto a motorway that
loops back under itself. The headlights don't move, and the cat's eyes never get closer.

**Landmark.** A sodium-lit overpass, and the dashboard's green clock.

**Palette and light.** Sodium orange street light in passing bands, red tail lights
ahead that never get closer, and the green dashboard.

**Memory object.** The dog's lead, coiled on the back seat. The empty water bowl sits in
the footwell.

**Fade.** The street lights die one by one, back to front. At plateau there is the
dashboard glow, the outlines of the seats, and the lead.

---

## 4 · Denial: Hospital waiting room

**What happened.** Age nineteen. Dad had a heart attack, and they waited six hours in
plastic chairs. A nurse called the name and said he was asking for them. They said they'd
just grab a coffee first, said they were fine, and sat back down. He died before they
went in. The dark's line: *"You said you were fine."*

**Verb.** Gates: doors and curtains you look at, click away, and pass. You face the door
and never go through it to *him*. Open-once gates here, taught before the timed ones.

**Wrongness.** The ticket display counts **backwards**. The chair rows go on past the
walls. Every door has a name plate, and every plate has the same name.

**Landmark.** The ticket display, red numbers in the dark, and the rows of linked chairs.

**Palette and light.** Pale washed blue-white (phase-2 tint), flat and shadowless, the
kind of light that makes everyone look ill. The vending machine glows warm in a corner.

**Memory object.** A paper cup of vending-machine coffee, full and cold, on the chair
arm. A visitor badge sits next to it.

**Fade.** The door plates go blank first, then the chairs lose their legs and float.
The ticket display is the last practical light left: at plateau it counts down to
nothing.

---

## 5 · Numbing: A party

**What happened.** Age nineteen, the night of the funeral. A friend said come out, so
they went, drank whatever was handed to them, and danced until they couldn't feel their
feet. Their phone buzzed fourteen times in their pocket. It was Mum. They didn't look.

**Verb.** Surf and hop chains. You never touch down and you never feel the impact.

**Wrongness.** The floor tilts into surf ramps, as if the room were sliding off. The music
is heard from underwater, muffled and a beat behind, and the strobe freezes the room
between flashes.

**Landmark.** The staircase from the hallway down into the room, stretched into a long
surf ramp, with the bannisters as lip edges.

**Palette and light.** Magenta and violet wash, the one saturated place in the course.
A white strobe, slick floors with smeared reflections, and haze.

**Memory object.** A phone on the edge of the kitchen-island ramp, face down, lighting up
with **14 missed calls**.

**Fade.** This place fades **backwards**: the colour drains, but the strobe gets
brighter and faster, until at plateau the room is a white flash and black. Numbing
doesn't fade, it gets louder. Only the phone's screen keeps any colour.

---

## 6 · Isolation: The empty house

**What happened.** Age twenty-three. Mum moved to a flat after selling the family house,
and they cleared it alone over one weekend. They didn't call anyone for help. Their
height marks were still on the kitchen door frame, and they painted over them before
the buyers came.

**Verb.** Precision gaps and chasms: everything spread apart, nothing in between, no
margin. Timed gates show up here, and the pressure peaks.

**Wrongness.** The rooms have come apart: each one hangs on its own in the void, joined
by doorways with the floor gone. The paler rectangles where pictures hung are the only
light sources in the room.

**Landmark.** The kitchen door frame standing alone on an island, with the height marks.

**Palette and light.** Dusty, low winter daylight through curtainless windows that look
out onto void. Cold grey walls, warmer pale patches where the furniture stood, and dust
hanging in the light.

**Memory object.** The door frame with the pencil height marks, half painted over.

**Fade.** This place is built to vanish: its small stepping platforms are the erosion
targets (spec §7, R9). Each loop the walls between the rooms thin to studs, then the
rooms drift further apart. At plateau the door frame stands alone in its own light.

---

## 7 · Spiralling: The bedroom, repeating

**What happened.** Age twenty-six, now. After a winter of the same bedroom: curtains
closed, phone face down, the alarm snoozed into the afternoon. Nothing happened here.
That is what happened.

**Verb.** Lip-to-lip surf and everything combined. You never break contact and you never
land. It feeds the compression sprint into the light-door.

**Wrongness.** The same bedroom repeats, each copy a little smaller. Doors shrink until
the last one is the light-door. The ceiling fan turns very slowly in every copy, in sync.

**Landmark.** The light-door: a thin warm line under the bedroom door, the only warm
light this deep. It grows through the zone until it is the exit.

**Palette and light.** Blue phone-screen light and grey curtain glow, with the warm line
under the door getting brighter ahead.

**Memory object.** The alarm clock, flashing **12:00** after a power cut nobody reset.

**Fade.** This place fades least, because it is the present. Each loop the copies shrink
faster and there are more of them, and the line of light under the door gets brighter.
At plateau the light-door is the only thing in colour in the whole course.

---

## Seams between places

Places join through liminal seams (founding §3), each one a thing that could be in
both rooms: a door, a corridor, a stair. Each seam hides the ring and doesn't announce
the next place, so the new place turns up halfway through a stride.

| From → to | Seam |
|---|---|
| School → Kitchen | A school corridor door opens onto the kitchen floor, at giant scale |
| Kitchen → Car | The back door opens onto the passenger seat |
| Car → Hospital | The windscreen becomes the hospital's automatic sliding doors |
| Hospital → Party | The corridor past the doors you never opened turns into the party's hallway |
| Party → House | The party stairs keep going down into the empty house's hall |
| House → Bedroom | The last island is the landing outside their bedroom door |
| Bedroom → School | The light-door: a white flash, mid-stride in the first corridor (spec §3) |
