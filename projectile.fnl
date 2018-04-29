;; TOOD: move to global config module
(local DEFAULT_SPEED 150)
(local DEFAULT_PJT_SPEED (* DEFAULT_SPEED math.pi))

(local TYPE "PROJECTILE")

(defn new [p]
  (assert p.spell-name)
  (assert p.x)
  (assert p.y)
  (assert p.dx)
  (assert p.dy)

  (let [spell (lfg.get_spell p.spell-name)
        am (. (. spell.ams p.dir) :power)
        spacing 50
        h 0.25
        w 0.25
        pjt {
             :am am
             :spell spell
             :spell-name p.spell-name
             :sprite spell.sprite
             :x (+ p.x (* p.dx spacing))
             :y (+ p.y (* p.dy spacing))
             :dx p.dx
             :dy p.dy
             :dir p.dir

             :h (or p.h h)
             :w (or p.w w)

             :ox (or p.ox 0)
             :oy (or p.oy 0)
             :speed (or p.speed DEFAULT_PJT_SPEED)

             :age 0
             :max_age 5

             :clid p.clid
             :uuid (or p.uuid (lume.uuid))

             :type "projectile"
             }
        (tl_x tl_y) (lfg.pixelToTile pjt.x pjt.y)]
    
    (set pjt.tl_x tl_x)
    (set pjt.tl_y tl_y)

    pjt))


(defn add-to-world [pjt w h]
  (log "ADDING TO WORLD %s %s %s" (ppsl pjt) w h)
  (: lfg.real_world :add pjt pjt.tl_x pjt.tl_y w h))


;; TODO: reconcile the two update-*-projectile functions
;; need to know when we're in client context vs server
(defn update [pjt dt]
  (: pjt.am :update dt))


(defn draw [pjt]
  (: pjt.am :draw pjt.sprite pjt.x pjt.y 0 1 1 pjt.ox pjt.oy))


(defn add-projectile [layer pjt add-to-lfg]
  (tset layer.projectiles pjt.uuid pjt)
  (when add-to-lfg
    (let [(x y) (lfg.pixelToTile pjt.x pjt.y)]
      (log "ADDING PJT <%s, %s>{%s, %s}" x, y, pjt.x, pjt.y)
      (: lfg.real_world :add pjt x y 1 1))))


;; TODO: reconcile the two update-*-projectiles functions
(defn update-layer-projectiles [self dt]
  (each [uuid pjt (pairs self.projectiles)]
    (update pjt dt)))


(defn draw-projectiles [self]
  (each [uuid pjt (pairs self.projectiles)]
    (draw pjt)))


(defn serialize [p]
  {
   :spell-name p.spell-name
   :x p.x 
   :y p.y 
   :dx p.dx 
   :dy p.dy 
   :clid p.clid 
   :uuid p.uuid 
   :type :projectile 
   :age p.age
   :dir p.dir
   })


(defn serialize-all [projectiles]
  (let [spjts {}]
    (each [uuid pjt (pairs projectiles)]
      (table.insert spjts (serialize pjt)))
    spjts))


{
 :add-to-world add-to-world
 :add-projectile add-projectile
 :update-layer-projectiles update-layer-projectiles
 :draw-projectiles draw-projectiles
 :new new
 :serialize serialize
 :serialize-all serialize-all
 :TYPE TYPE
 }
