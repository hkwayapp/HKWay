# HK Way --- iPadOS & Shared Platform Roadmap

**Status:** iOS, watchOS and tvOS completed and submitted for App
Review.\
**Next major platform:** iPadOS\
**Later major feature:** HK Way Journey Planner\
**After HK Way:** Japanese Mahjong project

## Immediate follow-ups

- Add lookup by KMB stop number.
- Fix the Light Rail page: the station list currently does not respond to taps.

## 1. Product Direction

HK Way should not try to replace specialist apps such as MyObservatory,
nor try to become another Google Maps.

Its core strength is:

> **Bring Hong Kong public transport together, regardless of operator.**

Weather, traffic, service disruptions and other information are
supporting context. The centre of HK Way remains unified public
transport.

### Platform roles

-   **iPhone --- "Take me there."** Full everyday HK Way experience.
-   **Apple Watch --- "Travel with me."** Active-journey companion: next
    stop, interchange, ETA and haptic get-off alerts.
-   **Apple TV --- "Plan with me."** Large-screen home planning and
    transport/attraction exploration.
-   **iPad --- "Explore with me."** Rich interactive planning workspace
    with maps, route details and touch interaction.
-   **Mac --- Widget first.** A full macOS app is not currently a
    priority. A glanceable all-operator transport widget may be useful.

## 2. iPadOS Direction

Use the existing tvOS dashboard as the visual starting point, but do not
simply enlarge or copy the TV interface.

The iPad version should turn the same visual language into a touch-first
interactive workspace.

### Home screen

Retain the general dashboard identity: - Greeting/date - Weather and
relevant warnings - Transport alerts - Nearby/favourite departures - HK
Way visual style

Cards become interactive: - Tap a route to open route details. - Tap a
stop to open stop information and departures. - Tap weather/warning
information for details. - Tap a traffic incident to view it on the
map. - Long press can expose contextual actions such as favourite, route
details, stop details and show on map. - Gestures may be added where
discoverable and useful, but essential actions should not depend on
hidden gestures.

### Large-screen workspace

A selected route or journey can transition from the dashboard into a
split workspace:

``` text
[                 MAP                 ] [ Route / Stop / Journey Details ]
```

The user can select stops and legs on either side and have the other
side update.

Support: - Landscape and portrait - Window resizing / iPad
multitasking - Sidebar or adaptive navigation - Large interactive maps -
Smooth card-to-detail transitions - Appropriate drag, swipe and pinch
gestures

The principle is:

> **tvOS provides the visual language; iPadOS turns it into an
> interactive workspace.**

## 3. Shared HK Way Architecture

Do not create separate implementations of the same capability for every
Apple platform.

Target structure:

``` text
HK Way Shared Core
│
├── TransportData
│   ├── Operators
│   ├── Routes
│   ├── Stops
│   └── Journeys
│
├── JourneyPlanner
│   ├── TransportGraph
│   ├── RouteSearch
│   ├── WalkingConnections
│   └── JourneyScoring
│
├── LiveServices
│   ├── ETA
│   ├── Traffic
│   ├── ServiceDisruptions
│   └── Weather
│
├── UserData
│   ├── Favourites
│   ├── RecentJourneys
│   └── Preferences
│
└── Platform UI
    ├── iOS
    ├── iPadOS
    ├── watchOS
    └── tvOS
```

Core principle:

> **One HK Way brain. Different interfaces depending on where the user
> is.**

For example, `TrafficService` belongs to HK Way Shared Core, not iPadOS.
iPad can show a traffic map/panel, iPhone can show a list, tvOS can show
important incidents, and watchOS can show only incidents relevant to an
active journey.

## 4. Journey Planner

The Journey Planner should eventually become a major HK Way feature.

Do not hard-code specific Hong Kong journeys. Model the transport
network as a graph.

-   Stops/stations are nodes.
-   Travel along a service is an edge.
-   Transfers are connections.
-   Nearby stops belonging to different transport systems can be
    connected by walking edges.

The engine should discover valid journeys from the data.

### Development stages

**Stage 1 --- Connectivity**

Given origin A and destination B: - Find a direct service. - Find
journeys with one transfer. - Later allow additional transfers. - First
goal: find a valid journey, not necessarily the mathematically fastest
journey.

**Stage 2 --- Walking connections**

Connect geographically close stops/stations across operators and modes.
This is essential for making the separate transport networks behave as
one Hong Kong network.

**Stage 3 --- Journey scoring**

Do not optimize solely for travel time.

Conceptually:

``` text
cost =
    travelTime
  + transferPenalty
  + walkingPenalty
  + waitingPenalty
```

This can support user-facing preferences such as: - 最快 --- fastest -
最少轉乘 --- fewer transfers - 最少步行 --- less walking - 巴士優先 ---
prefer buses - 鐵路優先 --- prefer rail - 較少等待 --- less waiting,
where real-time information permits - 無障礙路線 --- later, when
reliable accessibility data is available - 觀光模式 --- later, using HK
Way's destination/attraction information

**Stage 4 --- Real-time intelligence**

Keep real-time information separate from the base routing graph:

``` text
Transport Network
       ↓
Candidate Journeys
       ↓
ETA + Traffic + Disruptions
       ↓
Re-score / Rank
       ↓
Recommended Journeys
```

The static network answers **what is possible**. Live information helps
determine **what is sensible now**.

## 5. Live Traffic

Live traffic should be added later as a shared service.

A traffic jam should normally change the estimated cost/time of a
road-based leg rather than remove the route from the network.

Potential planner behaviour:

``` text
Normal:
Bus option     38 min
MTR option     44 min

Heavy road congestion:
Bus option     52 min
MTR option     44 min

→ HK Way recommends MTR first
```

HK Way should communicate uncertainty appropriately, e.g. "estimated
delay," rather than implying false precision.

### Traffic news UI

Traffic news does not need to occupy a large permanent dashboard area.

A small top-menu control could show:

``` text
🚦 交通  3
```

When tapped, it can open a panel containing important incidents and an
option to show them on the map.

When a traffic incident actually affects a planned journey, HK Way can
surface it contextually:

``` text
⚠️ 此路線受交通擠塞影響
預計行程時間增加約 10 分鐘
[查看其他路線]
```

Distinction: - **Traffic button:** "I want to know what is happening." -
**Planner warning:** "This incident affects my journey."

A traffic map layer may be added later and should normally remain
optional.

## 6. Weather and Other Context

HK Way has no intention of replacing MyObservatory.

Weather and warnings may remain on HK Way's dashboard because they
affect travel, but they should be supporting information rather than the
product's primary purpose.

Similarly, traffic information supports the transport experience rather
than turning HK Way into a dedicated traffic-news application.

## 7. Unified Operator Experience

HK Way should avoid forcing passengers to think in terms of individual
operator apps.

The desired experience is:

> **Where do you want to go? HK Way deals with the operator.**

Where possible, results should be organized around usefulness to the
passenger---journey, departure, proximity, destination and
preference---while still clearly identifying the operator.

This unified approach is one of HK Way's strongest differentiators.

## 8. Cross-Device Journey Vision

Long-term flow:

``` text
iPad / Apple TV
Plan and explore
       ↓
iPhone
Active navigation
       ↓
Apple Watch
Next step / interchange / get-off haptics
```

Example: 1. User plans a journey on iPad. 2. HK Way presents several
alternatives. 3. User selects one and views it on the large map. 4. The
journey continues on iPhone. 5. Apple Watch supplies immediate travel
instructions and haptic alerts.

The platforms should feel like parts of one HK Way system rather than
separate apps.

## 9. Mac Strategy

Do not prioritize a full macOS application unless a compelling desktop
use case emerges.

A Mac widget is more promising, particularly for unified transport
information such as: - Favourite routes - Nearby/useful departures -
Multiple operators together - Major transport disruption - Secondary
weather/traffic context

The transport information---not weather---should be the primary value of
an HK Way Mac widget.

## 10. Implementation Priority

Current order:

1.  Allow submitted iOS/watchOS/tvOS builds to complete App Review;
    avoid unnecessary changes to submitted builds.
2.  Build the iPadOS UI foundation.
3.  Add iPad-specific interaction and polish.
4.  Release/polish the iPad experience.
5.  Build the first Journey Planner core.
6.  Add timing and ETA intelligence.
7.  Add live traffic and disruption-aware ranking.
8.  Expand cross-device journey continuation.
9.  Consider Mac/widget enhancements where useful.
10. After HK Way reaches this milestone, move focus to the Japanese
    Mahjong project.

### Planner implementation principle

Start small:

> **A → graph search → valid direct/transfer journey → display result**

Then improve intelligence incrementally:

> **Valid route → estimated time → live ETA → live traffic →
> disruption-aware ranking**

Before implementing `TransportGraph`, inspect the current HK Way data
model and determine exactly what information is available to describe
connections between stops. Design the graph around the real dataset
rather than forcing the existing data into a theoretical model.

------------------------------------------------------------------------

## Guiding Product Statement

> **HK Way brings Hong Kong public transport together.**

It does not need to replace every specialist service. Its value comes
from combining operators, journeys and useful travel context into one
coherent experience across Apple's devices.
