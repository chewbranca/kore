(local lfg (require "lfg"))
(local argparse (require "argparse"))
(local game-server (require "server"))
(local game-client (require "client"))

(local use_lfg false)

(var player nil)

(var client nil)
(var server nil)

(defn love.errorhandler [msg] (print (fennel.traceback msg 3)))

(defn love.load [args]
  (local parser (argparse "kore" "Kore - The Rise of Persephone"))
  (parser.argument parser "dir" "App dir")
  (parser.flag parser "--server" "Host a server")
  (parser.flag parser "--client" "Run a client")
  (parser.option parser "--host" "Server host to connect to", "localhost")
  (parser.option parser "--port" "Server port to connect to", game-server.PORT)

  (local pargs (parser.parse parser))
  (lfg.dbg "GOT PARSED ARGS: ")
  (lfg.pp pargs)

  (if pargs.server (set server (game-server.run-server pargs.port)))
  (if pargs.client (set client (game-client.run-client pargs.host pargs.port)))
  (print "SERVER IS:")
  (pp server)
  (print "CLIENT IS:")
  (pp client)

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
  (if server (: server :update))
  (if client (: client :update))
  (lfg.update dt))

(defn love.mousemoved [...] (lfg.mousemoved ...))

(defn do-attack-melee [action]
  (assert (= :attack-melee action.type))
  (if use_lfg
      (lfg.do_attack_melee action)
      :else
      (when client
        (game-client.send-client-action client action))))


(defn do-attack-spell [action]
  (assert (= :attack-spell action.type))
  (if use_lfg
      (lfg.do_attack_spell action)
      :else
      (when client
        (game-client.send-client-action client action))))


(defn love.mousepressed [m-x m-y button]
  (let [p-x lfg.player.x
        p-y lfg.player.y
        (atype action) (game-client.mousepressed p-x p-y m-x m-y button)]
    (if (= atype :attack-melee) (do-attack-melee action)
        (= atype :attack-spell) (do-attack-spell action))))
