(local argparse (require "argparse"))
(log "loading server")
(local game-server (require "server"))
(log "loading client")
(local game-client (require "client"))
(log "loading entity")
(local entity (require "entity"))
(log "loading projectile")
(local projectile (require "projectile"))
(log "loading finished.")

(local use_lfg false)

(local cplayer {:x 0 :y 0})

(var player nil)

(var client nil)
(var server nil)
(var layer nil)

(var client-needs-init nil)

;;(defn love.errorhandler [msg] (print (fennel.traceback msg 3)))

(defn love.load [args]
  (print "LOADING KORE")
  (local parser (argparse "kore" "Kore - The Rise of Persephone"))
  (parser.argument parser "dir" "App dir")
  (parser.flag parser "--server" "Host a server")
  (parser.flag parser "--client" "Run a client")
  (parser.option parser "--host" "Server host to connect to", "localhost")
  (parser.option parser "--port" "Server port to connect to", game-server.PORT)
  (parser.option parser "--character" "What character to use, one of [Minotaur, Zombie, Skeleton]", "Minotaur")
  (parser.option parser "--spell" "What spell to use, one of [Fireball, Lightning, Channel]", "Fireball")
  (parser.option parser "--name" "Your player name", "Kore Minion")

  (local pargs (parser.parse parser))
  (lfg.dbg "GOT PARSED ARGS: ")
  (lfg.pp pargs)

  (assert (lfg.init {:map_file "map_lfg_demo.lua"} pargs))

  (local bootstrap-player (fn []
    (log "BOOTSTRAPPING PLAYER")
    (let [char (lfg.get_character pargs.character)
            spell (lfg.get_spell pargs.spell)
            player_obj {}]
        (assert char "Unknown character type")

        (set player_obj.name pargs.name)
        (set player_obj.char char)
        (set player_obj.spell spell)
        (set player_obj.map_inputs true)
        (set player_obj.x 25) ;; in tile coordinates
        (set player_obj.y 25) ;; in tile coordinates
        (set player_obj.clid client.luuid)

        ;;(var player (lfg.Entity.new nil player_obj))
        (set player (lfg.Entity.new nil player_obj))
        (lfg.set_player player)
        (when client
          (game-client.announce-self client player)))))


  (if pargs.server (set server (game-server.run-server pargs.port)))
  (if pargs.client (set client (game-client.run-client pargs.host pargs.port bootstrap-player)))

  (print "SERVER IS:")
  (pp server)
  (print "CLIENT IS:")
  (pp client)


  (var ent-layer (: lfg.map :addCustomLayer "KoreEntities" (+ (# lfg.map.layers) 1)))
  (set ent-layer.entities {})
  (set ent-layer.update entity.update-entities)
  (set ent-layer.draw entity.draw-entities)

  (var pjt-layer (: lfg.map :addCustomLayer "KoreProjectiles" (+ (# lfg.map.layers) 1)))
  (set pjt-layer.projectiles {})
  (set pjt-layer.update projectile.update-layer-projectiles)
  (set pjt-layer.draw projectile.draw-projectiles)

  (lfg.dbg "Welcome to Kore!"))

(defn love.draw []
  (if client-needs-init (do (log "initializing delayed player") (client-needs-init) (var client-needs-init nil)))
  (lfg.draw))

(defn love.update [dt]
  ;;(if server (: server :update))
  (if server (game-server.update server dt))
  ;;(if client (: client :update))
  (if client (game-client.update client dt))
  (lfg.update dt)

  (when (and player (or (~= player.x cplayer.x) (~= player.y cplayer.y)))
    (set cplayer.x player.x)
    (set cplayer.y player.y)
    (game-client.send-player-state client player)))

(defn love.mousemoved [...] (lfg.mousemoved ...))

(defn do-attack-melee [action]
  (assert (= :attack-melee action.type))
  (if use_lfg
      (lfg.do_attack_melee action)
      :else
      (when client
        (game-client.send-client-action client action))))


(defn do-attack-spell [action player]
  (assert (= :attack-spell action.type))
  (if use_lfg
      (lfg.do_attack_spell action)
      :else
      (when client
        (log "DO-ATTACK-SPELL: %s" (ppsl action))
        (let [pjt (projectile.new action)
              width 0.25
              height 0.25]
          ;;(projectile.add-to-world pjt width height)
          (game-client.send-projectile client pjt))
        ;;(game-client.send-client-action client action)
        )))


(defn love.mousepressed [m-x m-y button]
  (let [p-x lfg.player.x
        p-y lfg.player.y
        (atype action) (game-client.mousepressed p-x p-y m-x m-y button player)]
    (if (= atype :attack-melee) (do-attack-melee action)
        (= atype :attack-spell) (do-attack-spell action player))))
