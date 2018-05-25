# Kore
Kore - The Rise of Persephone

# Give it a Whirl

## First install Love 2D

Grab the appropriate binary from [https://love2d.org/](https://love2d.org/)

## Grab the Kore Game

```
git clone https://github.com/chewbranca/kore.git
cd kore
```

or download a zip without using git

```
wget https://github.com/chewbranca/kore/archive/master.zip
unzip master.zip
```

or just click on
[https://github.com/chewbranca/kore/archive/master.zip](https://github.com/chewbranca/kore/archive/master.zip)

## Run a Server

```
love . --server
```

## Now run a client (or many clients) to connect to the local server

```
# Connect with random character and spell
love .  --host "localhost" --name "FOO 1"
```

```
love .  --host "localhost" --character "Minotaur" --spell "Fireball" --name "FOO 2"
```

```
love .  --host "localhost" --character "Skeleton" --spell "Channel" --name "FOO 3"
```

## Connect to a Remote Server

To connect to a remote server, you'll need to supply the `--host` param with the
appropriate host, and you'll probably also want to specify a name too with the
`--name` parameter.

```
love .  --name "FOO" --host 1.2.3.4
```

# Running Kore on OSX

Because there is not yet a menu system in Kore, you must run this from the
command line. If you installed Love2D using the binaries linked above, you need
to invoke the commands through the app package. Basically you just need to do:

```
/Applications/love.app/Contents/MacOS/love .  --name "FOO" --host 1.2.3.4
```

# Running Kore on Linux

All the standard commands should work fine.

# Running Kore on Windows

You'll need to make a shortcut to love.ex, and then edit it to include the path
to Kore and the relevant command options detailed above. More details her:
[https://love2d.org/wiki/Getting_Started](https://love2d.org/wiki/Getting_Started)


# Cosmetic Decisions!

You can choose between one of three characters, and one of three spells. These
are all functionally identical, but they add a lot of style points.

Available character options for the command line setting (choose one):

  * --character "Minotaur"
  * --character "Skeleton"
  * --character "Zombie"

Available spell options for the command line setting (choose one):

  * --spell "Fireball"
  * --spell "Channel"
  * --spell "Lightning"

