(local lfg (require "lfg"))

;; This ordering on rows is based on the sprite sheets
(local D_W  {:x -1 :y  0}) ;; row 1
(local D_NW {:x -1 :y -1}) ;; row 2
(local D_N  {:x  0 :y -1}) ;; row 3
(local D_NE {:x  1 :y -1}) ;; row 4
(local D_E  {:x  1 :y  0}) ;; row 5
(local D_SE {:x  1 :y  1}) ;; row 6
(local D_S  {:x  0 :y  1}) ;; row 7
(local D_SW {:x -1 :y  1}) ;; row 8

;; Flare Game sprites are west oriented
(local DIRS {D_W 
             D_NW
             D_N 
             D_NE
             D_E 
             D_SE
             D_S 
             D_SW
            })

;; radians are east oriented
(local RDIRS {D_E 
              D_SE
              D_S 
              D_SW
              D_W 
              D_NW
              D_N 
              D_NE
              })

(local KEY_DIRS {
                 :up {:x 0 :y -1}
                 :down {:x 0 :y 1}
                 :left {:x -1 :y 0}
                 :right {:x 1 :y 0}
                 :w {:x 0 :y -1}
                 :s {:x 0 :y 1}
                 :a {:x -1 :y 0}
                 :d {:x 1 :y 0}
                 })

(local STATES {
               :run "run"
               :stand "stance"
               :swing "swing"
               :cast "cast"
               })

(local DEFAULT_DIR D_S)
(local DEFAULT_STATE STATES.stand)
(local DEFAULT_SPEED 150)
(local DEFAULT_PJT_SPEED (* DEFAULT_SPEED math.pi))



(defn new [e]
  (assert lfg.ran_init)
  (assert e.name "Entity name is present")
  (assert e.char "Entity char is present")
  (assert e.clid "Entity client id is present")

  (let [spell (or e.spell (lfg.get_spell "Fireball"))
        w 1.0
        h 1.0]
    {
     :clid e.clid
     :char e.char
     :char_name e.char.name
     :name e.name
     :x (or e.x 0)
     :y (or e.y 0)
     :ox (or e.ox e.char.as.ox 0)
     :oy (or e.oy e.char.as.oy 0)
     :vx (or e.vx 0)
     :vy (or e.vy 0)
     :w (or e.w w)
     :h (or e.h h)
     :cdir (or e.cdir lfg.DEFAULT_NDIR)
     :state (or e.state lfg.DEFAULT_STATE)
     :am (or e.am (. (. e.char.ams lfg.DEFAULT_NDIR) lfg.DEFAULT_STATE))
     :speed (or e.speed lfg.DEFAULT_SPEED)
     :spell spell
     :spell_name spell.name
     :type :entity
     }))


(defn create-player-entity [p]
  (let [char (assert (lfg.get_character p.char_name))
        spell (assert (lfg.get_spell p.spell_name))
        p_obj {}]

    (set p_obj.name p.name)
    (set p_obj.char char)
    (set p_obj.spell spell)
    (set p_obj.x p.x)
    (set p_obj.y p.y)
    (set p_obj.ox p.ox)
    (set p_obj.oy p.oy)
    (set p_obj.clid p.clid)
    (set p_obj.type "entity")

    (new p_obj)))


(defn serialize [player]
  {
   :char_name player.char_name
   :spell_name player.spell_name
   :name player.name
   :x player.x
   :y player.y
   :ox player.ox
   :oy player.oy
   :clid player.clid
   })


(defn set-animation [ent dir state]
  (assert ent)
  (assert dir)
  (local st (or state ent.state))
  (set ent.am (assert (. (. ent dir) st))))


(defn update [ent dt]
  (: ent.am :update dt))


(defn draw [ent]
  (: ent.am :draw ent.char.sprite ent.x ent.y 0 1 1 ent.ox ent.oy))


(defn add-entity [layer entity]
  (table.insert layer.entities entity)
  (let [(x y) (lfg.pixelToTile entity.x entity.y)]
    ;; TODO: is this double adding the local client player in lfg.set_player?
    (: lfg.real_world :add entity x y 1 1)))


(defn update-entities [self dt]
  (each [i ent (ipairs self.entities)]
    (update ent dt)))


(defn draw-entities [self]
  (each [i ent (ipairs self.entities)]
    (draw ent)))


{
 :new new
 :draw draw
 :update update
 :set-animation set-animation
 :add-entity add-entity
 :update-entities update-entities
 :draw-entities draw-entities
 :create-player-entity create-player-entity
 :serialize serialize
}

