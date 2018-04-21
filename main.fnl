(local lfg (require "lfg"))

(var player nil)

(defn love.errorhandler [msg] (print (fennel.traceback msg 3)))

(defn love.load [args]
  (assert (lfg.init {:map_file "map_lfg_demo.lua"} args))
  (lfg.dbg "Welcome to Kore!")
  (lfg.pp lfg.Entity)

  (let [char (lfg.get_character "Minotaur")
        spell (lfg.get_spell "Channel")
        player_obj {}]
    (set player_obj.name "Kore Minion")
    (set player_obj.char char)
    (set player_obj.spell spell)
    (set player_obj.map_inputs true)
    (set player_obj.x 25)
    (set player_obj.y 25)

    (var player (lfg.Entity.new nil player_obj))
    (lfg.set_player player)
    (lfg.dbg "PLAYER IS")
    (lfg.pp player)
    ))

(defn love.draw []
  (lfg.draw))

(defn love.update [dt]
  (lfg.update dt))

(defn love.mousemoved [...] (lfg.mousemoved ...))
(defn love.mousepressed [...] (lfg.mousepressed ...))
