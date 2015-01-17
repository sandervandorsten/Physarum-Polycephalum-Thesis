globals [ 
  ; Jeff Jones'-variables
  dampT 
  sensor-offset
  depT 
  SS step-size 
  evaporation-rate
  
  mortality-rate
  
  ; 'toggle'-variables
  ants-visible? food-visible? pheromone-visible? recording-movie? 

  ; additional variables for a good workflow
  country not-country soft-land
  close-movie-at-tick
  color-scale
  date-time
  date time
  export-prefix
  ]

breed [ ants ant ]
breed [ food food-pellet ]

patches-own [pheromone food-here? evap-rate patch-type]
food-own [my-size]
ants-own [FF FL FR]

extensions[ profiler ]

to setup
  ifelse (keep-land) [
    reset-ticks
    ask food [ clear-food-spot-here die ]
    ask ants [ die ] 
  ] 
  [__clear-all-and-reset-ticks]
  clear-output
  revive-patches
  set-global-variables
  make-land
  add-food food-scenario
  add-ants density
end

to profile
  setup                  ;; set up the model
  profiler:start         ;; start profiling

  while [ticks < n-of-steps] [
    go                   ;; run something you want to measure
  ]
  profiler:stop          ;; stop profiling
  print profiler:report  ;; view the results
  profiler:reset         ;; clear the data 
end

to revive-patches
  ask patches [ set pheromone 0 set food-here? false set pcolor black set patch-type 0]
end

to set-global-variables
  ; --------------------------   Jeff Jones' typical values   -------------------------- ;
  
  ;density   Population density                                        1-15%
  ;diffK     Diffusion kernel size                                     3
  ;dampT     Chemoattractant diffusion damping factor                  0.1
  ;wProj     'Food' stimulus projection weight                         0.001-0.1
  ;Boundary  Diffusion and Agent environmental boundary conditions     Periodic/fixed
  ;SA        FL and FR Sensor angle from forward position              45 degrees
  ;RA        Agent rotation angle                                      45 degrees
  ;SO        Sensor offset distance                                    5-9 patches
  ;SW        Sensor width                                              1 patch
  ;SS        Step size - distance per move                             1 patch per step
  ;depT      Chemoattractant deposition per step                       5
  ;sMin      Sensitivity threshold                                     0
  
 ; ------------------------------------------------------------------------------------- ;
  set SS 1
  set sensor-offset SO * patch-size
  set step-size SS * patch-size
  set depT 5
  set dampT 0.1

  set evaporation-rate   0.9
  
  ;additional settings
  set ants-visible?      true
  set food-visible?      true
  set pheromone-visible? true
  set recording-movie?   false
  set color-scale 20
  set date-time date-and-time
  set date substring date-time 16 (length date-time - 5)
  set time word substring date-and-time 0 8 substring date-and-time 12 15
  set time replace-item 2 time ";"
  set time replace-item 5 time ";"
  set export-prefix (word "/recordings3/" food-scenario " - " border-type " - " land-type " - " time)
end

to make-land
  if (not keep-land) [
    ifelse (land-type = "import land from CSV") [
      set country patches with [pcolor = violet] 
      set not-country patches with [ pcolor = violet]
      set soft-land patches with [ pcolor = violet]    ;little trick to tell the variable it's an agentset
      user-message "you can now select an earlier exported CSV file"
      file-open user-file
      
      user-message "file will be imported. this may take up to 2 minutes, please hang in there"
      let read-line get-coords 
      while [(first read-line != "#") ][
        ask patch first read-line last read-line [
          set pcolor 5
        ]      
        set read-line get-coords 
      ]
      set read-line get-coords
      while [(first read-line != "$") ][
        ask patch first read-line last read-line [
          set pcolor 2
        ] 
        set read-line get-coords 
      ]
      set read-line get-coords
      while [(first read-line != "@") ][
        ask patch first read-line last read-line [
          set pcolor (blue - 1)
        ]
        set read-line get-coords 
      ]
      file-close
      import-color
    ]
    [ set-border set-land ] ;else: border-type != CSV
  ]
  set-land-variables ;allways
end
  
to-report get-coords
  let coords []
  let csv file-read-line
    let comma-pos position "," csv 
    let x-cor substring csv 0 comma-pos  ; extract item 
    carefully [set x-cor read-from-string x-cor][] ; convert if number 
    let y-cor substring csv (comma-pos + 1) length csv
    carefully [set y-cor read-from-string y-cor][] ; convert if number 
    set coords lput x-cor coords
    set coords lput y-cor coords
  report coords
end

to set-border
  if (border-type = "No border") [
    set country patches
    set not-country patches with [ pcolor = violet]
    set soft-land patches with [ pcolor = violet]    ;little trick to tell the variable it's an agentset
  ]
      
  if (border-type = "Circle") [
    set country patches with     [ distancexy 0 0 <= max-pycor ]
    set not-country patches with [ distancexy 0 0 > max-pycor  ]
    set soft-land patches with   [ pcolor = violet ]
  ]
  if (border-type = "No corners") [
    set country patches with     [ distancexy 0 0 <= (sqrt ((max-pxcor * max-pxcor) + (max-pycor * max-pycor) ) - (max-pxcor / 6)) ]
    set not-country patches with [ distancexy 0 0 > (sqrt ((max-pxcor * max-pxcor) + (max-pycor * max-pycor) ) - (max-pxcor / 6))  ]
    set soft-land patches with [ pcolor = violet ]
  ]
end

to set-land
  let object-size 20
  if (land-type = "Center lake") [
    ask patches with [distancexy 0 0 <= object-size] [
        set pcolor (blue - 1)
      ]
    import-color
  ]
  if (land-type = "Center mountain") [
    ask patch 0 0 [
      ask patches in-radius object-size [
        set pcolor 5
      ]
    ]
    import-color
  ]
end

to set-land-variables
  ask country [
    set evap-rate evaporation-rate
    set patch-type 0
  ]
  ask not-country [
    set pcolor 3
    set pheromone -1
    set evap-rate 0
    set patch-type 1
    ]
  ask soft-land [ 
    set pcolor blue
    set evap-rate evaporation-rate * wAcc
    set patch-type 2
  ]
  display
end

to add-food [ f-scenario ]
  let axis-size 70
  if (f-scenario = "steiner triangle") [ 
    create-food 3 [
      give-food-attributes
      right 120 * who
      fd axis-size
    ]
  ]
  if (f-scenario = "steiner square") [
    create-food 4 [
      give-food-attributes
      right 90 * who
      fd axis-size
    ]
  ]
  if (f-scenario = "steiner rectangle") [
    create-food 6 [
      give-food-attributes
      if who = 0 [
        left 60
        fd axis-size
      ]
      if who = 3 [
        left 120
        fd axis-size
      ]
      if who = 1 or who = 2 [
        right 60 * who
        fd axis-size
      ]
      if who = 4 [
        fd (cos 60 * axis-size)
      ]
      if who = 5 [ 
        left 180
        fd (cos 60 * axis-size)
      ]
    ]
  ]
  if (f-scenario = "place food random") [
    create-food nFood-if-random [
      give-food-attributes
      let random-patch one-of country
      setxy [pxcor] of random-patch [pycor] of random-patch
    ]
    let busy? true
    while [ busy? ] [
      set busy? false 
      ask food [
        let too-close min-one-of other food in-radius (3 * food-size) [ distance myself ]
        if too-close != nobody [ face too-close fd random-float -7.0 set busy? true ]
      ]
    ]
  ]
  ;insert food scenarios here ---------------------------------------
  
  if (f-scenario = "scenario 1") [ 
    create-food 1 [ give-food-attributes setxy -58 41 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 47 -39 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -75 7 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -17 27 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -2 96 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 96 49 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -100 39 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 23 -70 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 78 73 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -27 65 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 51 45 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -12 -13 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 71 -66 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 25 -7 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 17 28 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -54 93 set my-size 6 set size my-size ]
  ]
  if (f-scenario = "scenario 2") [ 
    create-food 1 [ give-food-attributes setxy -29 19 ]
    create-food 1 [ give-food-attributes setxy -47 93 ]
    create-food 1 [ give-food-attributes setxy 26 66 ]
    create-food 1 [ give-food-attributes setxy 53 -76 ]
    create-food 1 [ give-food-attributes setxy 43 -15 ]
    create-food 1 [ give-food-attributes setxy 68 37 ]
    create-food 1 [ give-food-attributes setxy -78 -60 ]
  ]
  if (f-scenario = "the Netherlands") [ 
    create-food 1 [ give-food-attributes setxy -13 -3 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy 25 -32 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy -104 -54 set my-size 7 set size my-size ]
    create-food 1 [ give-food-attributes setxy -58 -26 set my-size 10 set size my-size ]
    create-food 1 [ give-food-attributes setxy 43 8 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy 29 -133 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy 96 14 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy 29 -133 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy -6 -50 set my-size 7 set size my-size ]
    create-food 1 [ give-food-attributes setxy -33 23 set my-size 14 set size my-size ]
    create-food 1 [ give-food-attributes setxy -72 -5 set my-size 11 set size my-size ]
    create-food 1 [ give-food-attributes setxy 85 59 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy 32 106 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy 48 42 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy -28 72 set my-size 7 set size my-size ]
    create-food 1 [ give-food-attributes setxy 29 -133 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy 80 112 set my-size 9 set size my-size ]
  ]
  if (f-scenario = "England") [ 
    create-food 1 [ give-food-attributes setxy 2 74 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy -50 -13 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy -1 3 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy -38 -124 set my-size 7 set size my-size ]
    create-food 1 [ give-food-attributes setxy 61 -122 set my-size 15 set size my-size ]
    create-food 1 [ give-food-attributes setxy -13 -65 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy -25 -10 set my-size 9 set size my-size ]
    create-food 1 [ give-food-attributes setxy 17 -40 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy 7 -15 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy -98 125 set my-size 7 set size my-size ]
  ]
  if (f-scenario = "Zeeland") [ 
    create-food 1 [ give-food-attributes setxy -33 -23 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 3 -85 set my-size 4 set size my-size ]
    create-food 1 [ give-food-attributes setxy -34 87 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 2 54 set my-size 7 set size my-size ]
    create-food 1 [ give-food-attributes setxy -34 -81 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy -118 8 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -73 -6 set my-size 10 set size my-size ]
    create-food 1 [ give-food-attributes setxy 7 120 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 64 99 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy -50 69 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy -8 -109 set my-size 4 set size my-size ]
    create-food 1 [ give-food-attributes setxy 128 90 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 91 -40 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 133 65 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy -108 19 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 109 141 set my-size 7 set size my-size ]
    create-food 1 [ give-food-attributes setxy 87 21 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy -114 -78 set my-size 4 set size my-size ]
    create-food 1 [ give-food-attributes setxy -84 -23 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 38 54 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 141 118 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 137 3 set my-size 12 set size my-size ]
    create-food 1 [ give-food-attributes setxy 91 -9 set my-size 11 set size my-size ]
    create-food 1 [ give-food-attributes setxy 32 -100 set my-size 4 set size my-size ]
    create-food 1 [ give-food-attributes setxy -8 -14 set my-size 8 set size my-size ]
    create-food 1 [ give-food-attributes setxy 38 116 set my-size 6 set size my-size ]
    create-food 1 [ give-food-attributes setxy 75 71 set my-size 5 set size my-size ]
    create-food 1 [ give-food-attributes setxy 58 130 set my-size 6 set size my-size ]
  ]
  ;------------------------------------------------------------------
  ask food [ 
    ask country in-radius (0.5 * my-size) [
      set pheromone wproj * depT
      set food-here? true
      set pcolor scale-color yellow pheromone 0 color-scale
    ]
  ]
end

to give-food-attributes
  set color white set shape "circle"
  set my-size food-size
  set size my-size ;to allow for different sized food-pellets 
  setxy 0 0
  set heading 0
end

to give-ant-attributes
  set color green
  set size patch-size / 2
  set shape "circle"
  reset-sensors
end

to add-ants [ dens ]
  let nAnts (max-pxcor * 2 * max-pycor * 2) *  (dens / 100)
  if (ant-deployment = "filamentous condensation") [
    ask n-of nAnts patches with [distancexy 0 0 <= max-pycor] [ 
      sprout-ants 1 [
        give-ant-attributes
        set heading random 360
      ] 
    ]
  ]
  if (ant-deployment = "filamentous foraging") [
    let n-ants-per-food nAnts / count food
    ask food [
      let drop-spot patches
      ask patch-here [ 
        set drop-spot country in-radius (ceiling sqrt( n-ants-per-food / pi) + 0.5)
      ]
      ask n-of n-ants-per-food drop-spot [
        sprout-ants 1 [
          give-ant-attributes
        ]
      ]
    ]
  ] 
  if (ant-deployment = "plasmodial shrinkage") [
    set mortality-rate 0.0005
    set nAnts (max-pxcor * 2 * max-pycor * 2) * 0.5
    ask n-of nAnts patches with [distancexy 0 0 <= max-pycor] [
      sprout-ants 1 [ 
        give-ant-attributes
      ]
    ]
  ]
end

to go 
  ifelse (ant-deployment = "plasmodial shrinkage") [
    ask ants [ sense move reset-sensors die?]
  ]
  [  
    ask ants [ sense move reset-sensors]
  ]
  update-environment
  tick
  if recording-movie? [
    let modulo 1 + floor (close-movie-at-tick / 2500)
      if ticks mod modulo = 0 [
        movie-grab-view
      ]
    if ticks = close-movie-at-tick [ toggle-record-movie stop ]
  ]
end

to sense 
  ; what if sensor is over the edge of the game?
  ; decision: the ant wont sense anything with that sensor
  let patch-front patch-ahead sensor-offset
  let patch-left patch-left-and-ahead  SA sensor-offset
  let patch-right patch-right-and-ahead SA sensor-offset
  
  if patch-front != nobody [
    let pher-patch-front [ pheromone ] of patch-front 
    if pher-patch-front > sMin or pher-patch-front != -1 [
      set FF pher-patch-front
    ]
  ]
  if patch-left  != nobody [
    let pher-patch-left [ pheromone ] of patch-left 
    if pher-patch-left > sMin  or pher-patch-left != -1 [
      set FL pher-patch-left
    ]
  ]
  if patch-right != nobody [
    let pher-patch-right [ pheromone ] of patch-right
    if pher-patch-right > sMin or pher-patch-right != -1 [
      set FR pher-patch-right
    ]
  ]
  
  if FF > FL and FF > FR [ stop ]
  if FL < FR [ right RA stop ]
  if FR < FL [ left  RA stop ]
end

to move
  ;move forward, if not occupied
  if ([patch-type] of patch-here = 1) [
    let random-patch one-of country
    facexy ([pxcor] of random-patch) ([pycor] of random-patch)
    fd step-size
  ]
  
  if-else (patch-ahead step-size != nobody and not any? ants-on patch-ahead step-size and [ patch-type ] of patch-ahead step-size != 1 )[
    set color green
    fd step-size
    ;if move is succesful, drop pheromone
    set pheromone pheromone + depT
  ] [
    set color orange
    ; if an ant isn't able to move, change his orientation randomly
    set heading random-float 360
  ]
end

to update-environment
  ;let the pheromone diffuse. then evaporate 
  diffuse pheromone dampT
  ask not-country [ 
     set pheromone -1
     set pcolor 3 
  ] 
  ask country [
    set pheromone pheromone * evap-rate
    if pheromone-visible? [ set pcolor scale-color yellow pheromone 0 color-scale ] 
  ]
  ask soft-land [
    set evap-rate evaporation-rate * wAcc
    set pheromone pheromone * evap-rate
    set pcolor blue 
  ]
  ask food [ 
    ask patches in-radius (0.5 * my-size) with [patch-type = 0][
      set pheromone wproj * depT
    ]
  ]
end

to reset-sensors
  set FF -1 set FR -1 set FL -1
end

to die?
  if count ants > (max-pxcor * 2 * max-pycor * 2) * (density / 100) [ if random-float 1.0 < mortality-rate [die]]
end

to-report random-polarity
  report (2 * random 2) - 1
end

to spray-pheromone
  if mouse-down? [
    ask patch mouse-xcor mouse-ycor [
      ifelse squarebrush? [
        let nearby moore-offsets (0.5 * pencil-size)
        ask patches at-points nearby [ 
          set pheromone pheromone + depT
          if pheromone-visible? [ set pcolor scale-color yellow pheromone 0 color-scale]
        ]
      ]
      [
        ask patches in-radius (0.5 * pencil-size) [
         set pheromone pheromone + depT
         if pheromone-visible? [ set pcolor scale-color yellow pheromone 0 color-scale]
       ]
      ]
    ]
    display
  ]
end

to draw-terrain
 if mouse-down? [
   ask patch mouse-xcor mouse-ycor [
     ifelse squarebrush? [ 
       let nearby moore-offsets (0.5 * pencil-size)
       ask patches at-points nearby [ set pcolor (blue - 1) ]
     ]
     [ ask patches in-radius (0.5 * pencil-size) [ set pcolor (blue - 1) ] ]
   ]
   display
 ]
end

to draw-country
  if mouse-down? [
    ask patch mouse-xcor mouse-ycor [
      ifelse squarebrush? [ 
        let nearby moore-offsets (0.5 * pencil-size)
        ask patches at-points nearby [ set pcolor 5 ]
      ]
      [ ask patches in-radius (0.5 * pencil-size) [ set pcolor 5 ] ]
    ]
    display
  ]
end

to draw-hard-border 
  if mouse-down? [
    ask patch mouse-xcor mouse-ycor [
      ifelse squarebrush? [ 
        let nearby moore-offsets (0.5 * pencil-size)
        ask patches at-points nearby [ set pcolor 2 ]
      ]
      [ ask patches in-radius (0.5 * pencil-size) [ set pcolor 2 ] ]
    ]
    display
  ] 
end

to become-country
  set not-country not-country with [self != myself]
  set soft-land soft-land with [self != myself]
  set country (patch-set country self)
  set pcolor black
  set pheromone 0
  set patch-type 0
end

to become-not-country
  set country country with [self != myself]
  set soft-land soft-land with [self != myself]
  set not-country (patch-set not-country self)
  set pcolor 3
  set pheromone -1
  set patch-type 1
end

to become-terrain
  set country country with [self != myself]
  set not-country not-country with [self != myself]
  set soft-land (patch-set soft-land self)
  set pcolor blue
  set evap-rate evaporation-rate * wAcc
  set patch-type 2
end

to-report moore-offsets [n]
  let result [list pxcor pycor] of patches with [abs pxcor <= n and abs pycor <= n]
  report result
end

to import-color 
  let N-not-country patches with [pcolor = 2]
  let N-country     patches with [pcolor = 5]
  let N-soft-land patches with [pcolor = (blue - 1) ]
  set not-country (patch-set not-country N-not-country)
  set country country with [not member? self N-not-country]
  set soft-land soft-land with [not member? self N-not-country]
  ask N-not-country [
    set pcolor 3
    set pheromone -1
    set patch-type 1
  ]
  set country (patch-set country N-country)
  set not-country not-country with [not member? self N-country]
  set soft-land soft-land with [not member? self N-country]
  ask N-country [
    set pcolor black
    set pheromone 0
    set patch-type 0
  ]
  set soft-land (patch-set soft-land N-soft-land)
  set not-country not-country with [not member? self N-soft-land]
  set country country with [not member? self N-soft-land]
  ask N-soft-land [
    set pcolor blue
    set evap-rate evaporation-rate * wAcc
    set patch-type 2
  ]
end

to draw-food
  if mouse-down? [
    let food? false
    ask patch mouse-xcor mouse-ycor [
      if not food-here? [
        set food? true
      ]
    ]
    if food? [
      create-food 1 [
        give-food-attributes
        setxy mouse-xcor mouse-ycor
        ask patches in-radius (0.5 * food-size) with [patch-type = 0] [
          set pheromone wproj * depT
          set food-here? true
        ]
      ]
    ]
    display
  ]      
end

to remove-food
  if mouse-down? [
    ask food with [ distancexy mouse-xcor mouse-ycor <= food-size ] [
      clear-food-spot-here die
    ]
    display
  ]
end

to clear-food-spot-here
  ask patches in-radius food-size with [food-here?] [
    set pheromone 0
    set food-here? false
    if pheromone-visible? [ 
      set pcolor scale-color yellow pheromone 0 color-scale
    ]
  ]
end

to set-scenario
  ; todo:
end

to save-land
  file-open (word "/land-scenarios/zeeland2.csv")
  ask country     [ file-print (word pxcor "," pycor) ]
  file-print "#,#"
  ask not-country [ file-print (word pxcor "," pycor) ]
  file-print "$,$"
  ask soft-land   [ file-print (word pxcor "," pycor) ]
  file-print "@,@"
  file-close
  user-message "file saved as .csv file. You can import this file as 'border-type: import from CSV'"
end

to save-food
  clear-output
  output-print "if (f-scenario = \"scenario X\") [ "
  ask food [ 
    output-print (word "  create-food 1 [ give-food-attributes setxy " round xcor " " round ycor " set my-size " size" set size my-size ]")
  ] 
  output-print "]"
end

to toggle-ants
  ask ants [ set hidden? ants-visible? ] set ants-visible? not ants-visible?
end

to toggle-food
  ask food [ set hidden? food-visible? ] set food-visible? not food-visible?
end

to toggle-pheromone
  if pheromone-visible? [ ask country [ set pcolor black ] ]  set pheromone-visible? not pheromone-visible?
end

to print-parameters
  file-open (word export-prefix ".csv")
  file-print word "density," density 
  file-print word "diffK," 3
  file-print word "dampT," dampT
  file-print word "wProj," wProj
  file-print word "SA," SA
  file-print word "RA," RA
  file-print word "SO," sensor-offset
  file-print word "SS," 1
  file-print word "depT," depT
  file-print word "sMin," sMin                 
  file-print word "food-size," food-size
  file-print word "evaporation-rate," evaporation-rate
  file-print word "food-scenario," food-scenario
  file-print word "ant-deployment," ant-deployment
  file-print word "mortality-rate," mortality-rate
  file-close
end 

to print-screen
  export-interface (word export-prefix ".png")
end

to import-parameters
  __clear-all-and-reset-ticks
  clear-output
  set-global-variables
  set-border
  user-message "import an earlier exported .csv file"
  file-open user-file
  let x file-read-line ; delete the first line
  let parameter ""
  let parameter-value 0
  print "\n...importing parameters..."
  while [not file-at-end?] [
    set x file-read-line
    set parameter (substring x 0 position "," x)
    set parameter-value substring x (position "," x + 1) length x
    print (word parameter " " parameter-value)
    set parameter parameter-value
    ;run en runresult bekijken, run (word " set " parameter " value")
  ]
  add-food food-scenario
  show density
  show RA
  add-ants density
  file-close
  print "parameters successfully imported! (not really yet because it's not working)"
end

to toggle-record-movie
  if not recording-movie? [reset-ticks]
  if-else not recording-movie? [
    set recording-movie? true
    set close-movie-at-tick 60 * duration-in-minutes * frames-per-second
    movie-start (word export-prefix ".mov")

    movie-set-frame-rate frames-per-second
  ] 
  [
    if-else user-yes-or-no? "Do you want to save this movie and it's parameters?"
    [
      movie-close
      print-parameters
      print-screen
      set recording-movie? false
      stop
    ]
    [ movie-cancel
      set recording-movie? false
      stop
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
235
10
847
643
150
150
2.0
1
10
1
1
1
0
0
0
1
-150
150
-150
150
1
1
1
ticks
9999.0

SLIDER
5
65
165
98
density
density
0
20
0
1
1
%
HORIZONTAL

MONITOR
170
60
227
105
ants
count ants
0
1
11

TEXTBOX
1230
10
1546
276
Standard values for parameters\n-----------------------------------------------------------------------------\ndensity\ndampT\n\nwProj\nSA\n\nRA\nSO\nSW\nSS\ndepT\n\nsMin
11
0.0
1

TEXTBOX
1291
39
1461
325
Population density\nChemoattractant diffusion damping factor\n'Food' stimulus projection weight\nFL and FR Sensor angle from forward position\nAgent rotation angle\nSensor offset distance\nSensor width\nStep size - distance per move\nChemoattractant deposition per step\nSensitivity threshold
11
0.0
1

TEXTBOX
1474
38
1624
369
1-5%\n0.1\n\n0.5-50\n25 - 70 degrees\n\n25 - 70 degrees\n5-20 patches\n1 patch\n1 patch per step\n5\n\n(1.0E-8) - (1.0E-5) or 0
11
0.0
1

SLIDER
0
135
110
168
SA
SA
0
90
50
5
1
Degrees
HORIZONTAL

SLIDER
115
135
225
168
RA
RA
0
90
45
5
1
Degrees
HORIZONTAL

SLIDER
0
175
110
208
SO
SO
5
30
6
1
1
patches
HORIZONTAL

BUTTON
860
605
940
638
NIL
toggle-ants
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
1030
605
1130
638
NIL
toggle-pheromone
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
865
140
990
173
NIL
spray-pheromone
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
5
435
175
480
food-scenario
food-scenario
"steiner triangle" "steiner square" "steiner rectangle" "place food random" "scenario 1" "scenario 2" "the Netherlands" "England" "Zeeland"
3

SLIDER
900
220
1085
253
food-size
food-size
1
25
8
1
1
patches
HORIZONTAL

BUTTON
945
605
1025
638
NIL
toggle-food
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
5
490
142
535
border-type
border-type
"No border" "Circle" "No corners"
1

SLIDER
1250
575
1525
608
duration-in-minutes
duration-in-minutes
0
5
2
0.1
1
minutes
HORIZONTAL

SLIDER
1250
610
1525
643
frames-per-second
frames-per-second
0
150
40
10
1
fps
HORIZONTAL

BUTTON
1250
525
1365
570
start/stop record
toggle-record-movie
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

MONITOR
1465
525
1525
570
recording:
recording-movie?
17
1
11

INPUTBOX
180
430
230
490
nFood-if-random
0
1
0
Number

CHOOSER
5
595
230
640
ant-deployment
ant-deployment
"filamentous condensation" "filamentous foraging" "plasmodial shrinkage"
0

MONITOR
1370
525
1460
570
#ticks recording:
60 * duration-in-minutes * frames-per-second
1
1
11

BUTTON
865
35
990
68
draw border
draw-hard-border
T
1
T
OBSERVER
NIL
H
NIL
NIL
1

SLIDER
995
35
1110
68
pencil-size
pencil-size
1
150
52
1
1
NIL
HORIZONTAL

OUTPUT
870
420
1115
565
10

BUTTON
1005
350
1115
383
save land
save-land
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
865
70
990
103
draw terrain
draw-terrain
T
1
T
OBSERVER
NIL
T
NIL
NIL
1

CHOOSER
5
545
125
590
land-type
land-type
"No land" "Center lake" "Center mountain" "import land from CSV"
3

BUTTON
1005
385
1115
418
save food
save-food
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
900
185
985
218
draw food
draw-food
T
1
T
OBSERVER
NIL
F
NIL
NIL
1

BUTTON
990
185
1085
218
remove food
remove-food
T
1
T
OBSERVER
NIL
E
NIL
NIL
1

BUTTON
870
350
995
383
import drawing
import-drawing user-file
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
870
385
995
418
NIL
clear-drawing
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
865
105
990
138
draw country
draw-country
T
1
T
OBSERVER
NIL
C
NIL
NIL
1

SWITCH
130
550
230
583
keep-land
keep-land
1
1
-1000

BUTTON
880
295
1017
331
test time-efficiency
profile
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
1020
285
1085
345
n-of-steps
10
1
0
Number

BUTTON
995
70
1110
131
import colours
import-color
NIL
1
T
OBSERVER
NIL
I
NIL
NIL
1

SWITCH
995
140
1110
173
squarebrush?
squarebrush?
1
1
-1000

CHOOSER
120
375
230
420
wProj
wProj
0.0050 0.05 0.5 1 2 5 50
5

CHOOSER
115
175
225
220
sMin
sMin
0 0.1 0.0010 1.0E-4 1.0E-5 1.0E-6 1.0E-7 1.0E-8 1.0E-9
5

TEXTBOX
5
110
225
135
                       ANT VARIABLES\n------------------------------------------------------
11
0.0
1

TEXTBOX
865
10
1110
35
                         DRAWING TOOLS\n-------------------------------------------------------------
11
0.0
1

TEXTBOX
1265
495
1545
551
                         RECORDING TOOLS\n-------------------------------------------------------------
11
0.0
1

TEXTBOX
875
575
1125
616
                             VIEW OPTIONS\n-------------------------------------------------------------
11
0.0
1

TEXTBOX
10
340
230
365
              ENVIRONMENT PROPERTIES\n------------------------------------------------------
11
0.0
1

BUTTON
85
10
150
55
step
go
NIL
1
T
OBSERVER
NIL
T
NIL
NIL
1

BUTTON
155
10
225
55
go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
5
10
80
55
setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SLIDER
5
375
115
408
wAcc
wAcc
0.05
1
0.35
0.05
1
NIL
HORIZONTAL

TEXTBOX
870
260
1115
285
                          TESTING & OTHER\n-------------------------------------------------------------
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This is a model of the slime mould <i>Physarum Polycephalum</i> creating emergent transport networks. It is a particle-based approach in a active reaction-diffusion environment where ants represent units of sol/flux in the body of the mould. The collective of these agents and the pheromone they deposit represent the plasmodium. 

The model is based on an implementation of dr. Jeff Jones, researcher at the University of Western England, Bristol. We extended the model described in his article <i>"influences on the formation and evolution of Physarum Polycephalum inspired emergent transport networks"</i> with a notion of permeability of terrain. This permeability is modelled as a weigthed value affecting the evaporation-rate of the chemoattractant/pheromone, speeding up the process of evaporation at patches where this terrain is modelled. 

## HOW IT WORKS

Each step, all agents will be asked exactly once to sense their environment and move in the direction of the patch where perceived pheromone has the highest value. While the ant moves it deposits pheromone, positively reinforcing the network created by all the ants. The environment is then asked to update itself. the pheromone will diffuse accross all patches and evaporation sequentially. 

Food spots represent cities in transport networks and secrete a constant amount of pheromone. If the value of 'pheromone dropped at food' > 'pheromone dropped by ants', it will be likely that to virtual plasmodium configures itself towards the nutrient sources. 

## HOW TO USE IT

The items in the interface are grouped in the following way:

### An agent operates as follows:
Each agent occupies a single patch with its body. It has 3 antennae-like sensors of length **SO** (Sensory Offset), of which the outer two are placed at an angle **SA** (Sensory angle) relative to the heading of the ant. There is a sensor at the end of the antennae of size **SW x SW** (sensor width)  occupying exactly 1 patch. The agent is asked to rotate **RA** degrees (rotation angle) in the direction of the sensor with the highest value of pheromone and do a step of size **SS** (step size), if **pheromone-perceived > sMin** (sensitivity threshold) and if no other ant occupies that cell. 

if the move was successful, the ant secretes some pheromone represented by the variable **depT** (pheromone deposition per step)

An ant cannot move onto a patch of the patch-set '_border_'. This patch-set delimits the area of the testing environment. 

####Ant variables:
  * **density** : percentage of the grid that will be covered with ants once initialized
  * **SA**      : Sensory angle of the ant
  * **RA**      : Rotation angle of the ant
  * **SO**      : Sensory offset distance
  * **sMin**    : sensitivity threshold of sensing pheromone
  * **SW**    (not shown in interface) : Sensory width
  * **SS**   (not shown in interface) : Step size
  * **depT**  (not shown in interface) : pheromone deposition per step

###The environment behaves as follows:
The patches will be asked to diffuse their pheromone values to the patches around them in a 3x3  grid of which the patch itself is the centre. this is done by updating the pheromone values of its Moore neighbourhood by 1/8 * **dampT** After this, the patches in '_country_' and '_terrain_' will be asked to evaporate the pheromone. Patches with food on them will reset the values pheromone back to their original standard to prevent the pheromone at a food-spot to be exhausted. 

The environment is setup by choosing a **food-scenario**, **land-type**, **border-type** and **ant-deployment**. These parameters affect the initial state of the environment. 

####Environment variables:
  * **wProj**   : Food stimulus projection weight
  * **wAcc** : terrain permeability projection weight
  * **nFood-if-random**: number of foodspots if _place food random_ is chosen
  * **keep-land?** : do you want to keep the land after pressing setup so you dont have to import/draw your land again for the next simulation?
  * **dampT** (not shown in interface) : pheromone diffusion damping factor
  * **food-scenario** : scenario of how the food will be deployed
  * **land-type** : creates land in the environment 
  * **border-type** : creates a border in the environment
  * **ant-deployment** : scenario of how the ants will be deployed
	
###Tools
Tools for working with the model efficiently are positioned at the right side of the grid

####Drawing tools
 * **draw border/terrain/country** : gives you a pencil of size **pencil-size** and shape **square-brush?** with which you can draw
 * **import colours** imports the country, border and terrain you have drawn since last import. This would be inefficient if updated dynamically. 
 * **draw food** : gives you a pencil of size **food-size** with which you can place food spots
 * **remove food** : enables you to remove a food-spot

####Testing & other
  * **test time-efficiency** : runs the programme for **n-of-steps** and measures speed with the NetLogo extension _profiler_
  * **import-drawing** : imports a .png file used for recreating real-land scenarios
  * **remove-drawing** : removes the imported drawing
  * **save-land** : saves the land as a .csv file which can be imported by choosing _import from CSV_ as **land-type**
  * **save food** : prints the food as pastable code to the export window below. Give the scenario a name and add its name to the chooser of **food-scenario** et voila!

####View Options
 * **toggle ants/pheromone/food** : toggles the ants/pheromone/food

####Recording tools
 * **start/stop record** : toggles recording of a movie. #ticks-recording = duration-in-minutes * frames-per-second. 

## THINGS TO NOTICE

(suggestjj234ed things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)


## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1999"/>
    <metric>printscreen</metric>
    <enumeratedValueSet variable="sMin">
      <value value="1.0E-6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-scenario">
      <value value="&quot;steiner rectangle&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wProj">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SA" first="15" step="5" last="90"/>
    <enumeratedValueSet variable="ant-deployment">
      <value value="&quot;filamentous condensation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration-in-minutes">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="RA">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SO">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="frames-per-second">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nFood-if-random">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-size">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="density">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="border-type">
      <value value="&quot;Circle&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
1
@#$#@#$#@
