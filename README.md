# kore
Kore - The Rise of Persephone

# Give it a whirl

For the moment you'll need to clone the lfg repo
[https://github.com/chewbranca/lfg](https://github.com/chewbranca/lfg) to
acquire the Flare Game assets. This repo is separate for the time being because
it's quite large. Eventually Kore will contain the subset of game assets used
from Flare Game to avoid needing the extra clone while keeping the asset size
minimal.

```
mkdir src && cd src
git clone https://github.com/chewbranca/lfg.git
git clone https://github.com/chewbranca/kore.git
ln -s ~/src/lfg/flare-game/ ~/src/kore/flare-game
```


```
love . --server --client --character "Skeleton" --spell "Lightning" --user
```

and spin up another client with:

```
optirun love . --client --character "Zombie" --spell "Channel" --us
```

Or see the command line options with:

```
love . --help
```
