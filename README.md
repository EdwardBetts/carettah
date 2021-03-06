# Carettah := Make your presentation more fun! [![Build Status](https://api.travis-ci.org/master-q/carettah.svg)](https://travis-ci.org/master-q/carettah)

[![Vimeo movie](./img/vimeo.png)](https://vimeo.com/53777328)

## How to use

~~~
$ mkdir new_dir
$ cd new_dir
$ carettah -n new_slide.md &
$ vi new_slide.md
~~~

if you would like to use
[wii remote](http://en.wikipedia.org/wiki/Wii_Remote)...

~~~
$ carettah -w new_slide.md
Put Wiimote in discoverable mode now (press 1+2)...
~~~

## How to install

Install below:

* [stack](https://www.stackage.org/)
* [cwiid](http://abstrakraft.org/cwiid)
* [Google Noto Fonts](http://www.google.com/get/noto/#/family/noto-sans-jpan) (need `Noto Sans CJK JP` and `Noto Sans Mono CJK JP`)

```
$ sudo apt-get install libcwiid-dev fonts-noto-cjk haskell-stack
```

And stack install.

~~~
$ git clone https://github.com/master-q/carettah.git
$ cd carettah
$ stack setup
$ stack install gtk2hs-buildtools
$ stack install
~~~

## For more detail

* [sample.md](./sample/sample.md)
* [Hackage](http://hackage.haskell.org/package/carettah)
* [Source code](https://github.com/master-q/carettah)
* [Demo movies](http://vimeo.com/channels/carettah)
* [Sample slides](http://www.slideshare.net/tag/carettah)
* [twitter](http://twitter.com/carettah)
* [Facebook page](http://www.facebook.com/pages/carettah/185683134833159)
* I'm a clone of [Rabbit](http://rabbit-shockers.org/).

## Memo

* `cairoFontMapGetDefault >>= pangoFontMapListFamilies :: IO [FontFamily]` can get list of font names.
* `pangoFontFamilyIsMonospace :: FontFamily -> Bool` can find mono fonts.

## Acknowledgment

The carettah icon is created by [VisualPharm (Ivan Boyko)](http://www.visualpharm.com/).
The icon is found at [Icon Search Engine](http://findicons.com/icon/69/turtle).
Thank's a lot!
