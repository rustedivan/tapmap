ROAD TO FINAL

# POI styling
POI styling needs better markers, and support for selecting different marker sprites. It looks pretty straight-forward - every rank has its own POI plane, so the marker index can be an instance uniform.
Label layout, however, looks to be a right week-long beast. I've done some research of how MapBox and friends to do it, and here are some requirements and insights.

**Label collision detection:** on scroll or zoom, labels need to be laid out by collision detection. Fixable margins around fitted label boxes. As a first step, layout all labels where they want to be.
**Label anchoring:** Maps seem to have a convention where labels are offset diagonally from their anchor points: NE, SE, NW, SW in that order. The offset in pixels would be a good Fixable.
**Label prioritisation:** Select new labels into the view in rank order. Weaker ranks are inserted later. A bound label should keep its binding until zoomed/scrolled out of scope (prioritize existing labels)
**Layout annealing:** When inserting, check for collisions. Incoming labels must move if colliding. If no free space can be found by selecting another anchor, restart from the first anchor point, and ask colliding labels to move to a "worse" anchor. Don't recurse. If a solution can't be found, drop the label.
**Label polish:** Areas should print in small-caps, without a marker. POI labels should come in two weights with differing size, weight and brightness. Give multiline labels negative line height.
**Label animation:** fade out labels before unbinding them; 

Depending on how fast this layout step runs, it can be done on each zoom frame. Otherwise, put it on a backthread, and animate to the produced frame when it's done.
- refactoring: break out other backthread jobs to their own files

# Label layout engine
The label layout engine kind of works already, but it has one big problem: frame-to-frame, the order of insertions changes, because it's all set/dictionary-based. This causes different labels to fit on different frames, which causes flickering.

I have two approaches to consider: either keep the layout from the previous frame, layout any new labels that may fit, and then re-project all the labels before rendering; OR figure out a stable sorting so the insert order is the same on every layout frame.

The first approach seems obviously better on first glance, but since scrolling causes _all_ labels to move, there isn't really that much useful information. Doing it in this way may be a bit faster (saving quadtree inserts, which are fast anyway) but also causes collision detection to happen with frame-old layouts. No biggie, but not clearly the best either.

The second approach is more expensive in that hundreds of markers need to be sorted per frame, but it solves the problems of older labels being butted out by younger labels, too.

Then, the actual binding to labels is turning out to be more of a problem than I thought. I'll try to formulate it more clearly than before.

1. We have one large set of markers `M`, to allocate to a (probably) smaller set of labels `L`. This is a (simple) bipartite graph problem.
2. The allocation of a label to a marker is said to _bind_ a marker to a label. Markers can be _bound_ or _unbound_; labels can be _used_ or _free_.
3. `M` changes frame to frame, so some markers will need to be unbound from their labels, and possibly bound to new markers. Every frame forms a new set of free labels `Lf`, and a new set of unbound markers `Mu`.
4. Markers have rank prioritizations that should be considered during layout insertion.
5. The layout is dependent on insertion order from `M`, so `M` needs to sorted in a stable manner from frame to frame.
6. A label should only disappear due to zooming or scrolling, and should not be freed up even if a higher-prioritized marker needs a label.

Currently, the system is letting markers bind to free labels, but I think this becomes clearer if free labels can pick what markers to display. This is simply sorting `Mu`, and iterating over `Lf` and popping members off `Mu` to bind to each free label.

- mark the binding with the frame ID


# Optimizations
- MetalRenderer spends effort to filter out the visible + available render sets, but they are already calculated and available in worldState. No need for `renderSet.filter(...`
- Put label layout on a backthread

# Rendering brief, step 2
 There are some effects I want to spice up the presentation. I'm a little stuck at how to lookup the color for a region at runtime, since the base color isn't always static. Specifically, provinces have different colors when visited and unvisited. I can definitely route around that, and ~100 O(1) dictionary lookups per frame isn't going to make a difference, but it's _wrong_. To help guide the stylesheet lookup design, let's take a look at those extra effects.
 
 √ Color key for visited provinces (need to know visit state for region). I could re-create the render primitive when the province is visited and reuse the buffer. No wait, BaseRenderPrimitive is a reference type so I can mutate the color at runtime!
 √ Province borders need the same visited/unvisited logic, but can HSL-darken the base color)
 - Key-color selection outline + bloom (static selection color and HSL-brightening of the base color)
 - Chromatic aberration (screen-space, independent of app logic, but animatable)
 
 √ But OK then, in this case all I need is to pre-bake the colors into the BRPs, and find a clean way to update the color of provinces when they are visited. Fixa tweakability will be a bit worse since I'll need to find a way to re-tint all regions at runtime... Would it be possible to just make an enum list of all BRP uses and tag them? Might be useful in other cases as well and not that big a violation of principles. Semantic tagging of primitives sounds nice! Like, `continent, country, province, border, selection, marker`? I'm sure there are other places that could benefit from having that lookup burned into the primitives. Another solution would be to split the region renderer itself into three passes, one per region type. Only change needed would be to teach prepareFrame to append to its instance uniform buffer and render list, and then clear it at frame change...
 
 The province colors should represent the their continents. I think this could be a cool way to achieve a faceted, sharp, consistent look that still sells the proximity between areas, and would look really nice for long overland trips.
 
- Prerender an image with the continents' key colors.
- Blur it heavily to get soft gradients where continents are close, and along coastlines (maybe even bring dark blue into the continent coastlines?)
- For each province (and optionally country, if needed), sample the blurred map at the pole of inaccessibility
 
 I did a quick test by just taking a continent-color map, blurring it in Pixelmator and taking a Voronoi filter to simulate countries. Looked good after one minute of work. This is the thing.
 
 Since the blur map is pre-rendered art, I can overlay a NSWE gradient cross to get a feeling for the equator, directions, parts of the world... Can get very creative!
 
 ## Province colors from pre-baked blur map
 Again, stuck on architecture decision: where do I store the region colors? Three places, with drawbacks:
 
 1. In the baked tessellation (colors don't really belong in a tessellation, and should static colors be adjusted at runtime? [e.g. selected darkening, pulsing...])
 2. In the render primitive (makes semantic sense, but then the color lookup must be made from GeometryStreamer on primitive creation)
 3. In the renderer (flexible and nice, but then the colors must be passed to prepareFrame and do per-frame lookup... which doesn't serve any purpose)
 
 (3) is out immediately - the region _authored_ colors are not changing at runtime outside known visual effects, so this is over-generalization
 (2) sure, ideally the render primitives should be assembled per-frame, referencing persistent GPU buffers, but that's an additional level of indirection that only serves code style)
 (1) is also just a naming quirk - it wouldn't have been a complaint if GeoTessellation had been GeoMesh, and as with (3), this is about the authored content colors, not necessary the frame color
 
 So, (1) it is - looking up the blur map color at bake time and storing it into the GeoTessellation.
 
 ## Polish
 √ author continent hue and build HSB tuples from from Stylesheet for all regions to get the tinted black/white
 


# Marketing
Find public land travels and make maps from it. LWR/D/U


# Rendering brief, step 1
  Main design issue to solve: what are the actual visual states of regions?
	The unclear design I've been working off so far is that a region can be
	- unvisited/closed
	- visited
	- open, so the regions below are shown instead
	This assumes that there is a difference between a visited region and an open
	region. Why would there be, though? A user would never want to mark a country
	as visited without moving on the the provinces below. So to clarify the visual
	hierarchy:
	
	- Unvisited continents
	- Visited continent renders unvisited countries
	- Visited countries renders unvisited provinces
	- Visited provinces
	
	The difference between a visited and unvisited continent is the country borders,
	and the difference between a visited and unvisited country is the province borders.
	Visited countries still render borders. Borders are rendered as an overlay, where
	countries overwrite province borders.
	
	So, the color stylesheet needs ten colors (three levels, seven continent colors for provinces).
	The renderer needs to copy out these style colors in prepareFrame to populate the instance uniforms (per frame, when selected).
	
	Additionally, selection border width and color.
	
	
  - Shader setup (HSV | border color)
  - Ocean: 200-7-90 | none
  - Unvisited continent: 0-0-97 | none			(bright white, no borders)
  - Unvisited country: C-3-95 | white*			(tinted white, black borders)
  - Unvisited province: C-70-17 | white			(tinted black, white borders)
  - Visited province: C-100-50 | C-10-20		(bright hue, no borders)
  - C: continent key color

  Country and province shaders blend in a topography relief map with a 50% linear burn.
  
  Selected regions re-render with a double-wide key-color border and bloom overlay.


# Hash key simplification
- add chunkname to the streamed chunks
- use lodHashKey as key in the chunktable

# Optimisation
- building chunkname/LOD hashkeys is the most expensive part of the app now
--build render primitive bookie with frame-count access markers, use to nuke when under memory pressure
- vertices down to Float16

# Ocean rendering
- add ocean pass in geography encoder
- pale bathygraphic map
- shifting blur waves
√ ocean outlines

## Pass color based on rank
-- color should be set from SelectionRenderer.select too, directly on the render primitive
## Arc length UVs
-- arc length determined by lat/lon distance
## Scale outline width on tap
-- scale the outline width uniform with a progress variable

# Creative brief
## Shading
## UX
## Splash screen
## Launch experience
- regions removed from launch screen to reveal map behind
## Opening animation
## Selected state
## Color scheme
## Labelling scheme

# Runtime tweaking
- runtime setting: borders should ramp between min/max screenspace width, not fixed regardless of zoom
- runtime setting: number of outlines to draw for each continent (Africa=2, Asia=5 and so on)
- runtime setting: zoom limits
- stylesheets for regions and colors

# Rendering improvements
## Outline feathering
-- can be done with an outline texture
## Label layout
-- layout into coordinate grid
## Texture UV's
-- can draw full-screen quad behind map? as a clear-op?
## 60Hz updates
-- setting on the viewcontroller
## Splash screen until streamer goes still
## Evict LRU render primitive
-- if memory used goes over high-water mark, evict 20% of the pool
## Rewrite tessellator
- replace with ear clipper to avoid the sliver polys

# Content patches
## Move Gibraltar into Europe
## Nudge coastal cities
## Move labels
## Remove POIs
## Split Seven Seas continent into their own seas
## Figure out how to handle Clipperton and friends (see "skipping..." in bake log)

----- ARCHIVE -----

# Persistence
- Store userstate to Application Support
-- Save regularily
- Knock out geoworld from userstate on startup
-- Animated on startup
- Store userstate to iCloud
-- CKContainer
-- Don't animate updates from iCloud

## LabelView's tag mechanism is incredibly expensive
- together with projectPoint - move off main thread?

# Metal rewrite
- drop everything except IndexedRenderPrimitive
-- move the cursor stuff up from OutlineRenderPrim
-- move color into it
-- rename to renderPrimitive
-- typealias the [scale]Vertex
- renderer setup function (load shader, set pipeline)
- parallel commannd encoding
-- don't create streamed/backthread-generated resources from the renderer's completion handlers
-- add simple requests from the render thread
-- enqueue work from main to worker thread
-- add mutex for reading/writing to the work queue (multiple writers, single reader)

# Metal rewrite
- target the Apple 1 GPU family (all the way back to iPhone 5S, iPad m3)

## Render passes
- ocean pass (single texture, color x 2, time, zoom, [position + uv])
- continent border pass (single texture, color, [position + miter + uv], border width)
- geography pass (single texture, color, [position + uv], highlight, visited)
- country border pass (color, [position + miter + uv], highlight, border width)
- POI render pass (sprite atlas, [position + miter + uv], marker size)
- effect render pass (color, progress, scaleInPlaceMatrix, [position])
- selection render pass (color, [position + miter + uv], border width)
- (label view pass)

## Data formats
- one uniform block per render pass, they're not going to stay
	as uniform through the design phase
- fixed-scale vertex format for borders, markers, selection and opening effect
- polygon vertex format for geography

## Render primitives
- outline render primitive (Arrayed +
- fixed-scale marker render primitive (Indexed + scale vertex) (Maybe just drop the indexed renderer?)
- region render primitive (Arrayed - maybe cheaper as indexed?)
- possibly boil this down to IndexedPrimitive with scalable/non-scalabe vertices?

## Parallelism
- break border, region and POI passes into separate command queues and encode in parallel
-- if needed, region CQ could be put into a parallel encoder itself, and run as separate jobs
-- argument buffers seems like a good fit for blasting out all the regions
--- could ICBs enable encoding all the regions in parallel? (No, only available in later GPU families)

## Modern rendering
- memoryless attachments?


# Master branch pickups after merging
√ make type for baked geometry hash
√ fix the O(nn) lookup in the LOD baker
√ rename L3 regions to provinces (continent, country, province)
√ city regions seem to be holes in continents and countries
√ border LOD broken again
x fall back to rendering worse LOD instead of missing
√ only give continent outlines to the largest poly (sort polys by area in tessellation step and only outline the first poly's exterior ring)
√ move pole of inaccessibility calc to tessellation step as visualCenter, use for label and opening effect
√ fix comments in RuntimeWorld

## Selection renderer generates outlines from known region "level""
-√ pass to SelectionRenderer.select(...)
-√ use to scale the miter ribs
## Pass width as uniform
-- ribs are already scaled to their normalized thickness
-- scale up by width
## Move outline generation to dispatch block
## √ Different style for coastlines?
-- seems difficult to do in geometry without re-analysing every edge's cardinality in yet another pass
-- possible to fake in fragment pass by taking the largest vertex ring in the continents
   at, say, LOD1, generating outline primitives from them and drawing them in a pass
   below the map geometry
-- this is essentially Y2K-style contour rendering - it'll miss lakes but can live without that

# Outline rendering
Preparations on Master
- rename MapRenderer to RegionRenderer
- pull outline generation out to sepearate Geometry/ file
- create outline struct
- OutlineRenderPrimitive should be able to render multiple tristrips for multiple rings
- selection renderer holds one outline struct

Work on branch
- separate border renderer and selection renderer
- border renderer holds map of outline structs
-
- country borders
-- outline primitive with UVs
-√ only expanded inwards (maybe a pixel or two outwards) to avoid overlap
-√ pull tessellations from geometry streamer
-√ build border primitives from that, mapped in with the lod from Geostreamer
--- the tricky part is that geostreamer can't track the primitives for us, and maybe never should have
	 (nah, it's good. the tessellation is the stored geometry, the border case is
    the odd one out - generating a new tessellation from vertex ring data)
--- if that tessellation doesn't have a border primitive at Geostreamer's actualLodLevel,
    enqueue it for extrusion
--- if a border LOD isn't available, queue it and render at the previous LOD level. this
    puts the borders a frame behind the region renderer, but that's OK since the border(s) will
    cover up the new region outline (both countries on a border will cover up their halves)
+++ move geometryStreamer's updates to the end of the frame (AFTER the render pass)
--- or wait until all borders have been generated, at risk of a frame hitch
--- not sure what "previous LOD level" should mean though. don't update the border renderer's
    lod level until all borders in a frame agree?
---- actualLodLevel and wantedLodLevel, and reading wantedLodLevel from the GS' actualLodLevel
---- in this way we can slave border and selection renderers to the GS
--- but I think waiting for all border generations is better, opening a country is already
    expensive
-√ only generate borders for countries



- continent outlines
-- fat, single color, scaled outline

- generation
-- move outline generation to dispatch block
-- same idea as geometry streamer (per-LOD hash)


# POI rendering
## √ Fixed screen scale
## √ Fixed size + rank scale
## Fixed rank size + zoom bump
-- markers can grow to twice their size when fully zoomed in (compensate for half of the zoom?)

# Region labelling
## Add POIs for all regions
-- Barycenter is not a good fit for this job
-- Instead, scan for the widest horizontal line through the polygon
-- and center on that line
-- Add POI category for .Region
-- ...add it to the list
## Two lines' worth of linebreak
-- ...only for region UILabels
-- Maybe a separate queue of region labels?
## Fade out these when zooming in
## Send label types to zoom view

# LOD support
## Define reshape settings for LOD levels
√ 3 LOD levels (low, mid, high)
√ reshape settings a pairing between LOD key and simplify-value
## Run pipeline for each LOD level
  √ push place distribution down below all tessellation
  √ run tessellation in a loop
  √ give ToolGeoRegion an array of tessellations at different LODs
  √ push them into the chunk table under LOD key
  √ run POI distribution against the high tessellation
## √ Suffix LOD to streaming key
## Use zoom to select LOD level

## LOD selection and rendering strategy
  Mixing LODs looks bad on interior borders, since LOD0 and LOD2 for neighboring
  countries will exhibit gaps. Therefore, the entire streamer needs to switch
  LOD level within a frame. That doesn't mean that the loading needs to occurr in
  a frame, though. The streamer tracks the "wanted LOD" level based on zoom, but
  does not change the "actual LOD" while there are still LODs missing.
  
  When the streamer gets a request for a render primitive, it returns the primitive
  for the "actual LOD" level. If the "wanted LOD" is different from the actual LOD,
  it puts in a stream request for the same primitive, but at the wanted LOD. If that
  stream request is accepted (that is, the LOD is still missing), "LOD switch pending"
  flag is raised. If the flag is unset at the end of the frame, the actual LOD level
  is set to the wanted level, so the render quality is changed in the next frame.
  The flag is set, it is cleared at the end of the frame.
  
  If the streamer has already switched to a better LOD, there may be primitive misses
  when the renderer asks for a primitive. In that case, the streamer walks up the
  LOD ladder until a primitive is found. This behaviour may exhibit border
  gaps for a short moment.
  
  Tests on iPhone 7 hardware suggests that the worst case is a second or so
  when loading all European countries at an artificially high LOD level. Tests also
  show that the worst case is a stream queue 30 chunks deep. Without parallel loading,
  30 chunks at 1 streamer update/frame comes out to about a second of loading, so
  that parallellism should be investigated.
  
  A mitigation can be to stream, but not render, with a slightly expanded focusBox.
  UIState should rename visibleSet to residentSet, and the MapRenderer should cull
  the residentSet to the actual screen. That way GeometryStreamer can pre-stream
  around the edges of the screen.
  
  As a final trick, GeometryStreamer should prioritize new chunks based on their
  distance from the camera, offset by a projection of the camera's movement during
  the past 1-2 seconds. That way, GeometryStreamer can prefetch geometry from
  memory based on a guess of what will be viewed next.
  
  After that, I can't imagine any improvements that aren't based on covering up
  mismatched LOD levels with a fat border, that must also scale with zoom.
  
  

## Switch LOD level for entire map renderer
--- don't mix LOD levels in the same frame
## Don't swap render level while a LOD level is missing
--- separate the "wanted" LOD level from the rendered LOD level
--- when LOD request changes, pull in those chunks
--- don't switch rendering level until streamed goes still

## Alternative strategy
- if a region is not available at a certain LOD, go up one level
- rendering fat outlines could cover up the mismatches at interior borders
-- having the fat outlines always-ready at LOD0 comes out to
--- ~50kB for continents
--- ~5kB for countries
--- ~1kB for regions
--- ...which is megabyte-scale for the worst case
- don't evict the previous geometry until the new ones are completely loaded

# Spherical projection
## If at all possible?
## Otherwise, lock to Winkel-Tripel
--- Winkel-Tripel looks like a bastard to invert (for click mapping)





# √ Country collation
## Generalize variable names

## Tile streaming
*The world tree could be used to speed up loading.*
The structure of the world must be known up-front, but the actual
geometry data can be streamed in lazily.

Build a file header that stores offset/size of the worldtree and the geometry chunk.
Store the world quadtree (hashes + boxes) at the top of the file.
Store the actual GeoXRegions under their keys in a keyed container.

Goal 1: load the world tree without having to parse the geometry yet.
Goal 2: load specific GeoXRegions from their hashkeys
				- ah, that's not how Codable's hashkeys work. Pulling partial results doesn't make
				  sense, unless I want to spin up an entire Decoder, partially parse it,
				  copy out the parts I want, and then destroy the entire thing again.
				- I think a better approach is to marshal each XRegion into an NSData,
				  concatenate them into one superbuffer and build a ToC for it. Then
				  I can pull byte ranges out of the sbuffer and unmarshal them as needed.
				  Very parallelizable too.
				- Pulling these chunks needs to be run on a back thread, or there will be
				  terrible frame hitches. I think that, if the file is mmapped, I don't have
				  to go out on an I/O thread, but the parsing needs to be async.
				- Wrote a testbed for the above, works really well. The chunk table should be
				  seeded with the mmapped file, and then the targeted accesses will be spooled
				  up from disk by the OS.

That is, loading the world needs to be done from a streaming controller.

### Loading file chunks
Haven't done chunk loading in modern iOS for a long time, so here are primitives
for writing and loading a raw file header from a byte chunk.
```
var headerData = withUnsafePointer(to: header) { (headerBytes) in
	return Data(bytes: headerBytes, count: MemoryLayout<WorldHeader>.size)
}

var loadedHeader = headerData.withUnsafeBytes { (bytes) in
	return bytes.load(as: WorldHeader.self)
}
```

WOW this is actually looking super promising. The entire geometry chunk table is ~30MB now,
so I guess there must have been some massive redundancies in the Foundation-coded file.
Looked into Swift half-floats and there is a proposal making its way through the Swift WG
_this_ week.

Geometry streaming is in. Even without actually using the streamer (loading all the geometry
up-front anyway) loading times are down to about 70%.

---

$$ Move GeoRegion to /Mapping

Now for the final act: actually using the streamer.
- teach GeometryStreamer to load GeoTessellations on-demand
- teach GeometryStreamer to create RenderPrimitives for them
- let MapRenderer fetch primitives from GeoStreamer instead
-- list of hashes -> list of primitives
- GeoTessellations can be evicted when no longer useful
- move the 'updatePrimitives' logic to GeoStreamer
- parse on background thread
-- creating the GL objects can be done on main thread, because
	 that will be different on Metal anyway.
	 
This is working a lot better than it has any right to do.
The map renderer gets a set of region hashes to render, and does
just that. If a primitive is not resident, the streamer pulls it
in on a background thread and the renderer never knows it missed
anything since it gets the list through a compactMap.

And since we stream only what is visible through the quadtree,
I can zoom in on Spain, open Europe, and only get resident primitives
for Portugal, Spain, France and Italy. Norway isn't streamed in until
I scroll that way.

### Tile streaming strategy
- rebuild the world file
-- build a file header
-- store the quadtree at the top of the file
-- move the tessellations out to a separate dictionary
-- reference the tessellations by ownerHash
-- tree, geoWorld and tessellation dictionaries should be marshaled
   separately and appended into the file with the file header.

- load tessellations into a GeometryCache controller
-- render geometries via lookup into that cache
-- MapRenderer needs to lookup its primitives through the GeoCache
- at this point, everything should work as before

- replace the tessellation dictionary with the chunk table
- append the chunk table's data to the file
- on loading, create empty render primitives for each tessellation
- when a tessellation is looked up and isn't created yet, pull the chunk from
  the chunk table and update the empty primitive

---

- restructure the GeoRegions so they have keys to their geometries. the geometries should be kept separate in the tilestreamer and fetched from there.
- on boot, get a file handle on the geometry file, read the header, then the tree and the chunk table. They are always necessary and should be loaded up-front.
- from userState + worldTree, we can get the set of visible hashes. They will be all continents since we haven't updated with UserState yet.
- insert those GeoRegions into the GeoWorld??? or load the GeoWorld sans geometries directly? I guess that would be easier - keep the logic running as before, but just constructing the render primitives on the fly?
- yeah, looks like I can create a null VBO for the primitive, and then glBufferData into it when the actual vertices are available.

Find the continent hashes and pull them from file, load and render as normal.
Using .UserState, mark tree nodes as seen or not
From here on:
- when rendering the screen, figure out the visible set of hashes from the tree
- pull missing region geometries from file and create primitives on the fly
-- this can be done on a background thread until the main thread needs to create GL primitives
- build the primitive list based off opened & visible & available geometry hashes
- if a primitive is missing, just skip it - it will pop in when available

- move POI distribution job to runtime side
- load continent + country POI planes
- start client
- load region POI planes, distribute, re-render
- quantize world grid into 5ºx5º boxes
- if close to village-level, load POI box files for visible grids
- put into LRU cache
- evict tiles at memory pressure warning
- make sure model handles eviction of rendered tile

## POI Labeling
This is the feature that scares me the most right now, becaue I _don't_ want to end up having to render them through GL/Metal.
Instead, the idea is to put a transparent UIView on top of the render view, and put the labels on that.
That means that I have to be able to transform each visible POI to screenspace, along with its alpha.

1. Put transparent view on top of GLview, with a label rendering on it
2. Figure out the transform matrix from world- to screenspace
3. Create a view model to pass down the rendering pipeline from POI to label view
4. Possibly limit the label density in some way

Getting the set of visible POIs into the label renderer is ALSO tricky.
The Poi renderer will not be helpful, since it doesn't hold the POI:s' names,
and only holds them in batch planes. This'll require another copy of the data
(which will be a lot more efficient once box culling gets up and running).

So, init with the geoWorld, make the necessary starting data copy, and update as needed.
The data will be the entire regions this time around, since we need both the rich region
metadata and the rich POI meta.

## Map scale notes
At furthest zoom level, only capitals and mega cities (NY, Caracas, Mumbai, Stockholm, London, Berlin, Moscow, Lagos, Cape Town, Cairo, Tehran, Karachi)
At roughly Brazil size, large cities (Salvador, Rio, Palmas, Campo Grande, La Paz, Trujillo, Cordoba, Harare, Pretoria, Kansas City)
At roughly Colorado size, towns (Littleton, Soria, Guildford, Alingsås, Budaun)
At roughly Java size, villages (Magelang, Karangasem, Skara)

[1] = 1.0
[2] = 5.0
[5] = 25.0
[6] = 30.0

1 = 1
5 = 2
25 = 5
30 = 6

Very rough approx: Tr = 0.01z^2 + 0.3z

+ Levels get different border widths




Do the same vec2+scale trick I used for the outlines, for the POIs, to get consistent scales

Finally:
- per zoom frame, find any poi plane that moved across the rank threshold and touch its toggleTime


PROBLEM:
- how do I pack POIs into progressively deeper regions? Does a province contain its megacapital?
++ no problem, POIs are distributed into regions and promoted up into the countries

POI Scaling:
- Admin level <= 2 -> .Capital

### STEPS
+ rebake map data
- use rank to scale poi markers
- give indexedPrimitive an extra attrib buffer (scalar float)
-- fill that extra attrib from buildPlaceMarkers
- use zoom to reject pois
-- put rankZoom into Z coordinate
-- send stepZoom level as uniform to entire shader
-- #1 Reject if too distant
-- if sZ<rZ, reject
-- #2 Smoothfade on approach
-- if sZ>rZ-w, render with alpha = lerp through (sZ in rZ-w, rZ)
- polish crossfades from the poirenderer
-- stepZoom is zoom, smooth-snapped to specific rank levels

## View culling
Start designing the tile system now, otherwise the label rendering will go down the wrong path
Requirements:
- culling away render primitives that are clearly outside the view
- getting regions that intersect the view
- getting POIs that intersect the view
- making progressively good decisions at closer zoom levels
- fast insertion/removal
...which sounds like a perfect quadtree, with regions inserted in all t-cells they intersect.

In general: given a q-tree and a view box, query out the regions and POIs in the view box. Without
splitting the regions, regions may appear multiple times, but if we insert only the hashes, they can
form a set and the rest can be queried out of the map. This query would be "reject all cells that
don't intersect the viewbox."

...aaand if I only have the region hashes in the tree, then I can pull out the POIs from that too.

A) If the inner nodes of the search is included in the BSP result, then querying the map is easy
B) If we have a map from hash to region for all visible regions, then quering that is easy - and
   this would be super useful in other contexts.

Left to do:
- geoworld filter by region hashes (dictionary hash -> region, should be copy-on-write and cheap)
-- this dictionary should be the working copy after each opening
-- that is, geoWorld is the source data, and the dictionary is a userstate cache
-- worldTree should be renamed worldQuadTree, it's not the most important source
-- visibleRegions should be visibleRegionHashes, it's just the hashes of currently rendered regions
-- the new data source is availableProvinces -> Int:GeoIdentifiable
--- IFF it is possible to still cast GeoIdentifiables to PlaceContainers and GeoTessellations
--- Because it it necessary to query against availableProvinces and pull out poi lists and render primitives
--- after all this, MapRenderer doesn't have to do the tree traversal to init the renderPrimitives list!
- point query
-- spearfish quadtree nodes from worldTree.visibleHashes
-- use hashes to find regions in worldCache
-- get the tessellations from those regions
-- box-colline those tessellations
-- tri-collide those tessellations
- Poi cloud culling
-- for all visible hashes, find the regions in worldCache
-- collect all POIs
-- point-collide against the projected viewbox (project the viewbox instead of all POIs)
-- pass to POI renderer to select projected set
-- project those points into viewspace

## Map scale notes
At furthest zoom level, only capitals and mega cities (NY, Caracas, Mumbai, Stockholm, London, Berlin, Moscow, Lagos, Cape Town, Cairo, Tehran, Karachi)
At roughly Brazil size, large cities (Salvador, Rio, Palmas, Campo Grande, La Paz, Trujillo, Cordoba, Harare, Pretoria, Kansas City)
At roughly Colorado size, towns (Littleton, Soria, Guildford, Alingsås, Budaun)
At roughly Java size, villages (Magelang, Karangasem, Skara)

+ Levels get different border widths

## Outline rendering
- teach RenderPrimitive to work with different vertex formats
- try to break apart RenderPrimitive into Indexed, Arrayed and Tristrip versions
- try to create an outline primitive with Tristrip and fat vertex format

## POI rendering
- progressive POI plane rendering
-- each POI plane has a feature level
-- aggressive box culling
--- culled with its GeoRegion
-- each POI plane renders its alpha at relation to global zoom
--- country POI plane ramps in over 1.5x-1.6x; region POI plane ramps in over 3x-4x
--- this info and conf should sit in the POI renderer
-- POIs scale, but very slowly (~0.1x)

## Labels
- composite UIView over GLKView
-- transparent UIView (visual and touch)
-- render groups of labels based on
- alpha based on distance to label

## Dataset economy
- Swift bitfields?
- Fixed-point floats

## Persistence

## UI
- visited viewstate
- close regions
- interaction markers

## User journey
### Insights
- need a selection state separate from opening
-- which means "visited" and "opened" are two different states
- cities are used to navigate, especially at detailed levels
-- which means cities must be visible on any closed region

### First boot
U launches tapmap and is met by an overview of the world.
There is only land and sea. U taps the landmass. The borders around
the continents highlight, and the name "Earth" is displayed.
Also, a small circle appears, an inviting tap-to-select.
Tapping there, U marks Earth as visited.
?? How does the difference between selection and opening look?
U long-presses the landmass, and the cracks quickly spread out around U's finger.

When the cracks have spread to the edges of the landmass, it fractures
and reveals the continents underneath. The capitals of the world are marked
by little stars.

U has been to Europe, and taps it to mark it as visited.
U then long-presses Europe.
Europe splits apart to reveal the countries underneath.
The countries are labeled and tinted in their national
colours so they can be easily found.

At this point, U expects to be able to mark countries U has visited.
However, every opened country splits apart into their constituent regions.

The world fractures into a beautiful jagged mess of regions and
provinces, with names few have noticed. Gone is the "went to Germany",
and instead U went to Bavaria, Thüringen and Brandenburg.

### Covering U's travel history
U now starts going over past journeys. U keeps going through
Europe, drilling into countries. U leaves some of them marked
as visited but will come back later to sort out the provinces.

U makes a simple mistake by tapping Switzerland instead of Austria.
By tapping again, Switzerland is no longer marked as visited.
Had U also opened Switzerland, a simple pinch would have closed
Switzerland again, and closed all its cantons too.

Soon U reaches the less familiar region level. U is not sure whether the
visit to Bangkok means Samut Prakan or Samut Sakhon. By zooming in a bit,
cities are named by labels. U finds the Bangkok Metropolis area, and presses
the circle to mark it as visited.

### Making something from the data
U has marked and opened the parts of the world U has visited.
There is a button on the map, that flips it around to the backside.
On the backside is a wealth of presentation modes


