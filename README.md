# ruby-auto.el
ruby-auto is a Ruby environment auto-configuration tool for Emacs, inspired by the `auto.sh` functionality of [Chruby](https://github.com/postmodern/chruby).  

This package _requires_ having a `.ruby-version` file within the current buffer's directory tree.

## Installation
Clone this repository:  
```sh
git clone https://github.com/beelleau/ruby-auto.git
```

Either symlink or copy `ruby-auto.el` into a path that is loaded in your `init.el`. I typically use a symlink:  
```sh
ln -s ruby-auto/ruby-auto.el .emacs.d/lisp/ruby-auto.el
```

Ensure your path is loaded, and load `ruby-auto`:  
```elisp
(add-to-list 'load-path
             (concat user-emacs-directory "lisp/"))

(require 'ruby-auto)
```

## Usage
ruby-auto has one interactive function, also named `ruby-auto`.  

You must have a `.ruby-version` file somewhere in the current buffer's directory tree. `ruby-auto` will find the nearest `.ruby-version` file.

## Configuration
By default, ruby-auto will search for rubies in `~/.rubies`. If you need to configure a different directory to search for rubies, you can modify the value of the `ruby-auto-rubies-dir` variable. Modify `ruby-auto-rubies-dir` _after_ `ruby-auto` is loaded:  
```elisp
(require 'ruby-auto)
(setq ruby-auto-rubies-dir "/opt/rubies")
```

ruby-auto also uses a static gem directory configuration. By default, it will search for gems under `~/.gem`. `ruby-auto` will automatically append the correct `RUBY_ENGINE` and `RUBY_VERSION` values to this variable to find the actual gem directory. If you need to configure a different directory to search for gems, you can modify the value of the `ruby-auto-gem-dir` variable. Modify `ruby-auto-gem-dir` _after_ `ruby-auto` is loaded:  
```elisp
(require 'ruby-auto)
(setq ruby-auto-gem-dir "/usr/local/bundle")
```

If you use a configuration function to hook into major modes, you can have that function run the `ruby-auto` function. Run `ruby-auto` as early as possible in the function, since you'll likely want its configurations for other utilities like `eglot`, `flymake`, `inf-ruby-minor-mode`, etc.  
```elisp
;; a simple ruby-config function and hook
(defun ruby-config ()
  (ruby-auto)
  (visual-line-mode -1)
  (inf-ruby-minor-mode 1)
  (setq truncate-lines t
        fill-column 80
        ruby-indent-tabs-mode nil
        ruby-indent-level 2)
  (eglot-ensure)
  (corfu-mode 1))
(add-hook 'ruby-mode-hook #'ruby-config)

```

Lastly, you can run the `ruby-auto` function at any time to have your in-tree `.ruby-version` file discovered and environment variables set.

## Acknowledgments
ruby-auto is inspired by [Chruby](https://github.com/postmodern/chruby) written by [postmodern](https://github.com/postmodern). The methodology used to set environment variables in Chruby was influential in the methodology used in `ruby-auto.el`.
