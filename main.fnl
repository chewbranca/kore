(local lfg (require "lfg"))
(local argparse (require "argparse"))

(var player nil)

(defn love.errorhandler [msg] (print (fennel.traceback msg 3)))

(defn love.load [args]
  (local parser (argparse "kore" "Kore - The Rise of Persephone"))
  (parser.argument parser "dir" "App dir")
  (parser.flag parser "--server" "Host a server")
  (parser.flag parser "--client" "Run a client")
  (parser.option parser "--host" "Server host to connect to", "localhost")

  (local pargs (parser.parse parser))
  (lfg.dbg "GOT PARSED ARGS: ")
  (lfg.pp pargs)

  (assert (lfg.init {:map_file "map_lfg_demo.lua"} pargs))
  (lfg.dbg "Welcome to Kore!")

  (let [char (lfg.get_character "Minotaur")
        spell (lfg.get_spell "Channel")
        player_obj {}]
    (set player_obj.name "Kore Minion")
    (set player_obj.char char)
    (set player_obj.spell spell)
    (set player_obj.map_inputs true)
    (set player_obj.x 25) ;; in tile coordinates
    (set player_obj.y 25) ;; in tile coordinates

    (var player (lfg.Entity.new nil player_obj))
    (lfg.set_player player)))

(defn love.draw []
  (lfg.draw))

(defn love.update [dt]
  (lfg.update dt))

(defn love.mousemoved [...] (lfg.mousemoved ...))
(defn love.mousepressed [...] (lfg.mousepressed ...))
