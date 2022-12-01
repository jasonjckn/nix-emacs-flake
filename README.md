# nix-emacs-flake

### How to build it

```bash
nix build . 

./result/bin/emacs 
```



### Configuration

Definitely better ways to do this 

```
find /nix/store -name 'libtree-sitter-bash.dylib'

# find all directories... 

# configure emacs 

(setq treesit-extra-load-path '("add directory here" "etc..."))
```

### check if working

```
M-x bash-ts-mode
```
