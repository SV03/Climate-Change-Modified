globals [
  sky-top      ;; y coordinate of top row of sky
  earth-top    ;; y coordinate of top row of earth
  temperature  ;; overall temperature
]

breed [rays ray]     ;; packets of sunlight
breed [IRs IR]       ;; packets of infrared radiation
breed [heats heat]   ;; packets of heat energy
breed [CO2s CO2]     ;; packets of carbon dioxide
breed [clouds cloud]
clouds-own [cloud-speed cloud-id]
;; -----------added code--------------------------
breed [suns sun]
breed [trees tree]
breed [towns town]
suns-own [sun-speed]
;;-------------------------------------------------
;;
;; Setup Procedures
;;

to setup
  clear-all
  set-default-shape rays "ray"
  set-default-shape IRs "ray"
  set-default-shape clouds "cloud"
  set-default-shape heats "dot"
  set-default-shape CO2s "CO2-molecule"
  ;;--------Added Code---------------------
  set-default-shape suns "sun"
  set-default-shape trees "tree pine"
  set-default-shape towns "house two story"
  ;;----------------------------------------
  setup-world
  set temperature -10
  reset-ticks
end

to setup-world
  set sky-top max-pycor - 5
  set earth-top 0
  ask patches [  ;; set colors for the different sections of the world
    if pycor > sky-top [  ;; space
      set pcolor scale-color white pycor 22 15
    ]
    if pycor <= sky-top and pycor > earth-top [ ;; sky
      set pcolor scale-color blue pycor -20 20
    ]
    if pycor < earth-top
      [ set pcolor red + 3 ] ;; earth
    if pycor = earth-top ;; earth surface
      [ albedo-surface ];;update-albedo ]
  ]
  ;;--------------Added Code---------------------
    create-suns 1
  [
    set color yellow
    set size 6
    setxy (min-pxcor + 0.3) 20.5
    set heading 90
    set sun-speed 0.045
  ]
  ;;-----------------------------------------------
end

;;
;; Runtime Procedures
;;

to go
  ask clouds [ fd cloud-speed ]  ; move clouds along
  run-sunshine   ;; step sunshine
  ;; if the albedo slider has moved update the color of the "earth surface" patches
  ask patches with [pycor = earth-top]
    [ albedo-surface ]
  run-heat  ;; step heat
  run-IR    ;; step IR
  run-CO2   ;; moves CO2 molecules
  tick
  ;;-------------Added Code------------------------------------------
  ask suns [
    run-sun
  ]
    ask trees [
    absorb-CO2s
  ]
  ask towns [
    release-C02s
  ]
  ;;-------------------------------------------------------------------
end

;to update-albedo ;; patch procedure
 ; set pcolor scale-color green albedo 0 1
;end

;; the above code is no longer needed due to albedo-surface being used to have multiple types of surfaces please refer to the bottom of the code


to add-cloud            ;; erase clouds and then create new ones, plus one
  let sky-height sky-top - earth-top
  ;; find a random altitude for the clouds but
  ;; make sure to keep it in the sky area
  let y earth-top + (random-float (sky-height - 4)) + 2
  ;; no clouds should have speed 0
  let speed (random-float 0.1) + 0.01
  let x random-xcor
  let id 0
  ;; we don't care what the cloud-id is as long as
  ;; all the turtles in this cluster have the same
  ;; id and it is unique among cloud clusters
  if any? clouds
  [ set id max [cloud-id] of clouds + 1 ]

  create-clouds 3 + random 20
  [
    set cloud-speed speed
    set cloud-id id
    ;; all the cloud turtles in each larger cloud should
    ;; be nearby but not directly on top of the others so
    ;; add a little wiggle room in the x and ycors
    setxy x + random 9 - 4
          ;; the clouds should generally be clustered around the
          ;; center with occasional larger variations
          y + 2.5 + random-float 2 - random-float 2
    set color white
    ;; varying size is also purely for visualization
    ;; since we're only doing patch-based collisions
    set size 2 + random 2
    set heading 90
  ]
end

to remove-cloud       ;; erase clouds and then create new ones, minus one
  if any? clouds [
    let doomed-id one-of remove-duplicates [cloud-id] of clouds
    ask clouds with [cloud-id = doomed-id]
      [ die ]
  ]
end



to run-sunshine
  ask rays [
    if not can-move? 0.3 [ die ]  ;; kill them off at the edge
    fd 0.3                        ;; otherwise keep moving
  ]
  reflect-rays-from-clouds  ;; check for reflection off clouds
  encounter-earth   ;; check for reflection off earth and absorption
end

to create-sunshine
  ;; don't necessarily create a ray each tick
  ;; as brightness gets higher make more
  if 10 * sun-brightness > random 50 [
    create-rays 1 [
      set heading 160
      set color yellow
      ;; rays only come from a small area
      ;; near the top of the world
      setxy (random 10) + min-pxcor max-pycor
    ]
  ]
end

to reflect-rays-from-clouds
 ask rays with [any? clouds-here] [   ;; if ray shares patch with a cloud
   set heading 180 - heading   ;; turn the ray around
 ]
end

to encounter-earth
  ask rays with [ycor <= earth-top] [
    ;; depending on the albedo either
    ;; the earth absorbs the heat or reflects it
    ifelse (100 * ((pcolor / 10) mod 1)) > random 100     ;; MODIFIED CODE old condition for the albedo level to be set 100 * albedo > random 100
      [ set heading 180 - heading  ] ;; reflect
      [ rt random 45 - random 45 ;; absorb into the earth
        set color red - 2 + random 4
        set breed heats ]
  ]
end

to run-heat    ;; advances the heat energy turtles
  ;; the temperature is related to the number of heat turtles
  set temperature 0.99 * temperature + 0.01 * (0.1 * count heats - 10) ;; MODIFIED CODE : the rate the temperature resets back to starting temperature in this case
  ask heats
  [
    let dist 0.5 * random-float 1
    ifelse can-move? dist
      [ fd dist ]
      [ set heading 180 - heading ] ;; if we're hitting the edge of the world, turn around
    if ycor >= earth-top [  ;; if heading back into sky
      ifelse random 100 > 85
              ;; heats only seep out of the earth from a small area
              ;; this makes the model look nice but it also contributes
              ;; to the rate at which heat can be lost
              ;;and xcor > 0 and xcor < max-pxcor - 8
        [ set breed IRs                    ;; let some escape as IR
          set heading (random 60 - 30)
          set color magenta ]
        [ set heading 100 + random 160 ] ;; return them to earth
    ]
  ]
end

to run-IR
  ask IRs [
    if not can-move? 0.3 [ die ]
    fd 0.3
    if ycor <= earth-top [   ;; convert to heat if we hit the earth's surface again
      set breed heats
      rt random 45
      lt random 45
      set color red - 2 + random 4
    ]
    if any? CO2s-here    ;; check for collision with CO2
      [ set heading 180 - heading ]
  ]
end

to add-CO2  ;; randomly adds 25 CO2 molecules to atmosphere
  let sky-height sky-top - earth-top
  create-CO2s 25 [
    set color green
    ;; pick a random position in the sky area
    setxy random-xcor
          earth-top + random-float sky-height
  ]
end

to remove-CO2 ;; randomly remove 25 CO2 molecules
  repeat 25 [
    if any? CO2s [
      ask one-of CO2s [ die ]
    ]
  ]
end

to run-CO2
  ask CO2s [
    rt random 51 - 25 ;; turn a bit
    let dist 0.05 + random-float 0.1
    ;; keep the CO2 in the sky area
    if [not shade-of? blue pcolor] of patch-ahead dist
      [ set heading 180 - heading ]
    fd dist ;; move forward a bit
  ]
end

;------------------------- Added Code--------------------------------
to run-sun
      ifelse day-night? [
    fd sun-speed * 50 / 50
        ifelse (round ((ticks - max-pxcor / sun-speed) / (2 * max-pxcor / sun-speed)) mod 2) = 0 [
        hide-turtle]
        [show-turtle
          radiate]
      ]
      [radiate]
end


to radiate
   if 10 * sun-brightness > random 50 [
     hatch-rays 1 [
     set color yellow
     set heading 150 + random 60
     set size 1]
   ]
end

to add-tree ;;
    create-trees 5 [
    set color green
    set size 2
       setxy random-xcor 1.4
  ]
end
to remove-tree ;;
  repeat 5 [
    if any? trees [
      ask one-of trees [ die ]
    ]
  ]
end

to absorb-CO2s
  let prey one-of CO2s-here
  if prey != nobody
    [ ask prey [ die ]
    ]
end

to add-town
    create-towns 1 [
    set color brown
    set size 3
       setxy random-xcor 1
  ]
end

to remove-town ;;
  repeat 1 [
    if any? towns [
      ask one-of towns [ die ]
    ]
  ]
end


to release-C02s
  if random 100 > 95 [
  hatch-CO2s 1 [
    set size 1
    set color green
  ]
  ]
end

to albedo-surface     ;; determine the albedo of the surface and the landtype of the surface

;; determining the surface-area of each type.
  let size1-min (min-pxcor * 0.01 * surface-area-1)
  let size1-max (max-pxcor * 0.01 * surface-area-1)
  let size2-min (size1-min + (min-pxcor - size1-min) * surface-area-2 * 0.01)
  let size2-max (size1-max + (max-pxcor - size1-max) * surface-area-2 * 0.01)
  let size3-min (size2-min + (min-pxcor - size2-min) * surface-area-3 * 0.01)
  let size3-max (size2-max + (max-pxcor - size2-max) * surface-area-3 * 0.01)

    if surface-type-4  = "ice/water" [   ;; Surface 4
      ifelse melting-ice? [
        set pcolor scale-color blue temperature 30 0 ]
        [set pcolor scale-color blue surface-type-4-albedo 0 1 ]
    ]
    if surface-type-4  = "forest" [
      set pcolor scale-color green surface-type-4-albedo 0 1 ]

    if surface-type-4 = "concert" [
      set pcolor scale-color gray surface-type-4-albedo 0 1 ]

    if surface-type-4  = "sand" [
      set pcolor scale-color yellow surface-type-4-albedo 0 1 ]



  if pxcor >= size3-min and pxcor <= size3-max [ ;; Surface 3

    if surface-type-3  = "ice/water" [
      ifelse melting-ice? [
        set pcolor scale-color blue temperature 30 0 ]
        [set pcolor scale-color blue surface-type-3-albedo 0 1 ]
    ]
    if surface-type-3  = "forest" [
      set pcolor scale-color green surface-type-3-albedo 0 1 ]

    if surface-type-3  = "concert" [
      set pcolor scale-color gray surface-type-3-albedo 0 1 ]

    if surface-type-3  = "sand" [
      set pcolor scale-color yellow surface-type-3-albedo 0 1 ]
   ]


  if pxcor >= size2-min and pxcor <= size2-max [ ;; Surface 2

    if surface-type-2 = "ice/water" [
      ifelse melting-ice? [
        set pcolor scale-color blue temperature 30 0 ]
        [set pcolor scale-color blue surface-type-2-albedo 0 1 ]
    ]
    if surface-type-2 = "forest" [
      set pcolor scale-color green surface-type-2-albedo 0 1 ]

    if surface-type-2 = "concert" [
      set pcolor scale-color gray surface-type-2-albedo 0 1 ]

    if surface-type-2 = "sand" [
      set pcolor scale-color yellow surface-type-2-albedo 0 1 ]
   ]



  if pxcor >= size1-min and pxcor <= size1-max [ ;; Surface 1

    if surface-type-1 = "ice/water" [
      ifelse melting-ice? [
        set pcolor scale-color blue temperature 30 0 ]
        [set pcolor scale-color blue surface-type-1-albedo 0 1 ]
    ]
    if surface-type-1 = "forest" [
      set pcolor scale-color green surface-type-1-albedo 0 1 ]

    if surface-type-1 = "concert" [
      set pcolor scale-color gray surface-type-1-albedo 0 1 ]

    if surface-type-1 = "sand" [
      set pcolor scale-color yellow surface-type-1-albedo 0 1 ]
   ]
end
@#$#@#$#@
GRAPHICS-WINDOW
333
14
880
364
-1
-1
11.0
1
10
1
1
1
0
1
0
1
-24
24
-8
22
1
1
1
ticks
30.0

BUTTON
11
45
106
78
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
108
45
203
78
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
18
85
191
118
sun-brightness
sun-brightness
0
5
4.2
0.2
1
NIL
HORIZONTAL

PLOT
10
395
598
792
Global Temperature
NIL
NIL
0.0
10.0
10.0
20.0
true
true
"" ""
PENS
"Temperature" 1.0 0 -2674135 true "" "plot temperature"
"CO2s" 1.0 0 -7500403 true "" "plot count turtles with [color = green]"
"Trees" 1.0 0 -955883 true "" "plot count trees"

BUTTON
10
306
105
339
add CO2
add-CO2
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
107
306
202
339
remove CO2
remove-CO2
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
602
398
746
443
Current Temperature
temperature
1
1
11

BUTTON
10
272
105
305
add cloud
add-cloud
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
107
272
202
305
remove cloud
remove-cloud
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
216
321
309
366
CO2 amount
count CO2s
2
1
11

BUTTON
206
45
307
79
watch a ray
watch one-of rays\nask subject [ pen-down ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
194
85
318
118
day-night?
day-night?
0
1
-1000

BUTTON
11
233
103
266
add trees
add-tree
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
106
233
203
266
remove trees
remove-tree
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
218
229
305
274
No.Of Trees
count trees
17
1
11

BUTTON
17
191
105
224
add town
add-town
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
106
191
202
224
remove town
remove-town
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
217
179
310
224
No.Of Towns
count towns
17
1
11

MONITOR
217
276
313
321
No.Of Clouds
count clouds
17
1
11

SLIDER
616
464
816
497
surface-type-1-albedo
surface-type-1-albedo
0
1
0.36
0.01
1
NIL
HORIZONTAL

SLIDER
617
509
817
542
surface-type-2-albedo
surface-type-2-albedo
0
1
0.18
0.01
1
NIL
HORIZONTAL

SLIDER
619
560
819
593
surface-type-3-albedo
surface-type-3-albedo
0
1
0.72
0.01
1
NIL
HORIZONTAL

SLIDER
624
609
824
642
surface-type-4-albedo
surface-type-4-albedo
0
1
0.35
0.01
1
NIL
HORIZONTAL

CHOOSER
822
461
960
506
surface-type-1
surface-type-1
"forest" "concert" "sand" "ice/water"
0

CHOOSER
823
512
961
557
surface-type-2
surface-type-2
"forest" "concert" "sand" "ice/water"
1

CHOOSER
824
561
962
606
surface-type-3
surface-type-3
"forest" "concert" "sand" "ice/water"
2

CHOOSER
825
610
963
655
surface-type-4
surface-type-4
"forest" "concert" "sand" "ice/water"
3

SWITCH
625
678
758
711
melting-ice?
melting-ice?
0
1
-1000

SLIDER
965
466
1137
499
surface-area-1
surface-area-1
0
100
64.0
1
1
NIL
HORIZONTAL

SLIDER
965
515
1137
548
surface-area-2
surface-area-2
0
100
18.0
1
1
NIL
HORIZONTAL

SLIDER
967
565
1139
598
surface-area-3
surface-area-3
0
100
53.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This is a model of energy flow in the earth, particularly heat energy. It shows the earth as rose colored, and the surface of the planet is represented by a black strip. Above the strip there is a blue atmosphere and black space at the top. Clouds and carbon dioxide (CO2) molecules can be added to the atmosphere. The CO2 molecules represent greenhouse gases that block infrared light that is emitted by the earth. Clouds block incoming or outgoing sun rays, influencing the heating up or cooling down of the planet.

## HOW IT WORKS

Yellow arrowheads stream downward representing sunlight energy. Some of the sunlight reflects off clouds and more can reflect off the earth's surface.

If sunlight is absorbed by the earth, it turns into a red dot, representing heat energy. Each dot represents the energy of one yellow sunlight arrowhead. The red dots randomly move around the earth, and its temperature is related to the total number of red dots.

Sometimes the red dots transform themselves into infrared (IR) light that heads toward space, carrying off energy. The probability of a red dot becoming IR light depends on the earth's temperature. When the earth is cold, few red dots generate IR light; when it is hot, most do. The IR energy is represented by a magenta arrowhead. Each carries the same energy as a yellow arrowhead and as a red dot. The IR light goes through clouds but can bounce off CO2 molecules.

There is a relation between the number of red dots in the earth and the temperature of the earth. This is because the earth temperature goes up as the total thermal energy is increased. Thermal energy is added by sunlight that reaches the earth as well as from infrared (IR) light reflected down to the earth. Thermal energy is removed by IR emitted by the earth. The balance of these determines the energy in the earth, which is proportional to its temperature.

There are, of course, many simplifications in this model. The earth is not a single temperature, does not have a single albedo, and does not have a single heat capacity. Visible light is somewhat absorbed by CO2 and some IR light does bounce off clouds. No model is completely accurate. What is important is that a model reacts in some ways like the system it is supposed to model. This model does that, showing how the greenhouse effect is caused by CO2 and other gases that absorb IR.

## HOW TO USE IT

The SUN-BRIGHTNESS slider controls how much sun energy enters the earth's atmosphere. A value of 1.0 corresponds to our sun. Higher values allow you to see what would happen if the earth was closer to the sun, or if the sun got brighter.

The ALBEDO slider controls how much of the sun energy hitting the earth is absorbed.
If the albedo is 1.0, the earth reflects all sunlight. This could happen if the earth froze, and it is indicated by a white surface. If the albedo is zero, the earth absorbs all sunlight. This is indicated as a black surface. The earth's albedo is about 0.6.

You can add and remove clouds with buttons. Clouds block sunlight but not IR.

You can add and remove greenhouse gases, represented as CO2 molecules. CO2 blocks IR light but not sunlight. The buttons add and subtract molecules in groups of 25 up to 150.

The temperature of the earth is related to the amount of heat in the earth. The more red dots you see, the hotter it is.

## THINGS TO NOTICE

Watch a single sunlight arrowhead. This is easier if you slow down the model using the slider at the top of the model.  You can also use the WATCH A RAY button.

What happens to the arrowhead when it hits the earth? Describe its later path. Does it escape the earth? What happens then? Do all arrowheads follow similar paths?

## THINGS TO TRY

1. Play with the model. Change the albedo and run the model. Add clouds and CO2 to the model and then watch a single sunlight arrowhead. What is the highest earth temperature you can produce?

2. Run the model with a bright sun but no clouds and no CO2. What happens to the temperature? It should rise quickly and then settle down around 37 degrees. Why does it stop rising? Why does the temperature continue to bounce around? Remember, the temperature reflects the number of red dots in the earth. When the temperature is constant, there are about as many incoming yellow arrowheads as outgoing IR ones. Why?

3. Explore the effect of albedo holding everything else constant. Does increasing the albedo increase or decrease the earth temperature? When you experiment, be sure to run the model long enough for the temperature to settle down.

4. Explore the effect of clouds holding everything else constant.

5. Explore the effect of adding 100 CO2 molecules. What is the cause of the change you observe? Follow one sunlight arrowhead now.

## EXTENDING THE MODEL

Try to add some other factors influencing the earth's temperature. For example, you could add patches of vegetation and then see what happens as they are consumed for human occupation. Also, you could try to add variable albedo to the model, instead of having one value for the whole planet. You could have glaciers with high albedo, and seas with low albedo, and then evaluate what happens when the glaciers melt into the seas.

## NETLOGO FEATURES

Note that clouds are actually made up of lots of small circular turtles.

## RELATED MODELS

Daisyworld

## CREDITS AND REFERENCES

This model is based on an earlier version created in 2005 by Robert Tinker for the TELS project.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Tinker, R. and Wilensky, U. (2007).  NetLogo Climate Change model.  http://ccl.northwestern.edu/netlogo/models/ClimateChange.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2007 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2007 Cite: Tinker, R. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cloud
false
0
Circle -7500403 true true 13 118 94
Circle -7500403 true true 86 101 127
Circle -7500403 true true 51 51 108
Circle -7500403 true true 118 43 95
Circle -7500403 true true 158 68 134

co2-molecule
true
0
Circle -1 true false 183 63 84
Circle -16777216 false false 183 63 84
Circle -7500403 true true 75 75 150
Circle -16777216 false false 75 75 150
Circle -1 true false 33 63 84
Circle -16777216 false false 33 63 84

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

house two story
false
0
Polygon -7500403 true true 2 180 227 180 152 150 32 150
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 75 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 90 150 135 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Rectangle -7500403 true true 15 180 75 255
Polygon -7500403 true true 60 135 285 135 240 90 105 90
Line -16777216 false 75 135 75 180
Rectangle -16777216 true false 30 195 93 240
Line -16777216 false 60 135 285 135
Line -16777216 false 255 105 285 135
Line -16777216 false 0 180 75 180
Line -7500403 true 60 195 60 240
Line -7500403 true 154 195 154 255

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

molecule hydrogen
true
0
Circle -1 true false 138 108 84
Circle -16777216 false false 138 108 84
Circle -1 true false 78 108 84
Circle -16777216 false false 78 108 84

molecule water
true
0
Circle -1 true false 183 63 84
Circle -16777216 false false 183 63 84
Circle -7500403 true true 75 75 150
Circle -16777216 false false 75 75 150
Circle -1 true false 33 63 84
Circle -16777216 false false 33 63 84

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

ray
true
0
Line -7500403 true 150 0 150 315
Line -7500403 true 120 255 150 225
Line -7500403 true 150 225 180 255
Line -7500403 true 120 165 150 135
Line -7500403 true 120 75 150 45
Line -7500403 true 150 135 180 165
Line -7500403 true 150 45 180 75

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

sun
false
0
Circle -7500403 true true 75 75 150
Polygon -7500403 true true 300 150 240 120 240 180
Polygon -7500403 true true 150 0 120 60 180 60
Polygon -7500403 true true 150 300 120 240 180 240
Polygon -7500403 true true 0 150 60 120 60 180
Polygon -7500403 true true 60 195 105 240 45 255
Polygon -7500403 true true 60 105 105 60 45 45
Polygon -7500403 true true 195 60 240 105 255 45
Polygon -7500403 true true 240 195 195 240 255 255

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

tree pine
false
0
Rectangle -6459832 true false 120 225 180 300
Polygon -7500403 true true 150 240 240 270 150 135 60 270
Polygon -7500403 true true 150 75 75 210 150 195 225 210
Polygon -7500403 true true 150 7 90 157 150 142 210 157 150 7

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
setup add-cloud add-cloud add-cloud repeat 800 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
