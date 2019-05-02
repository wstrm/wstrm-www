---
title: "Better fonts and more symbols with Gentoo"
date: "2019-03-04"
lastmod: "2019-03-04"
description: "Support most fonts and symbols with Gentoo"
aliases: [/post/better_fonts_and_more_symbols_with_gentoo/]
tags:
    - "gentoo"
    - "font"
    - "rendering"
---

## What do I need?
It's really annoying when viewing some random website and all you see is those
boxes instead of the actual symbol. So the first thing to do is to install some
fonts that support _many_ code points, like Google's Noto. There's also alot of
web pages that use Microsoft's Corefonts.

When it comes to the licensing, Google's Noto is under the SIL Open Font
License - which is open source - which is nice. Sadly the Microsoft Corefonts
are licensed under Microsoft and requires that you sign an EULA. However, even
if you do not sign the EULA, Microsoft won't really sue you because they've already given
up([1](https://en.wikipedia.org/wiki/Core_fonts_for_the_Web#Program_termination_and_software_licence_agreement_issues)).
For those that are good citizens you can either sign that EULA (as you must when
using Gentoo) or just use Google's alternative, the Croscore fonts (which is
licensed under Apache License 2.0). These fonts doesn't really look like the
Microsoft Corefonts, but they are "metrically compatible".

## Prepare a font set
So let's begin with installing some fonts that will cover most code points (over
60 000). I usually use the `/etc/portage/sets/` folder and use `emerge
@<set-name>` for stuff that I use on all my computers.

Either use the command below to just add the required fonts to the `fonts` set,
or install them manually.
```
(root) echo "media-fonts/noto\nmedia-fonts/croscorefonts" > /etc/portage/sets/fonts
```

## Even more symbols!
Optionally, you can have even _more_ symbols if you enable the `cjk` flag for
the `media-fonts/noto` package. This adds many symbols for Chinese, Japanese and
Korean languages.

```
(root) echo "media-fonts/noto cjk" >> /etc/portage/package.use/noto
```

### If you've chosen Microsoft Corefonts
If you have chosen to use the Microsoft fonts, also add the
`media-fonts/corefonts` package to the set:
```
(root) echo "media-fonts/corefonts" >> /etc/portage/sets/fonts
```

## Install them!
Now just install all these fonts in one go with:
```
(root) emerge --ask @fonts
```

Note: If you are using the Microsoft Corefonts the command will ask you if you
want to accept the EULA, say `Yes` and then run `dispatch-conf`:
```
(root) dispatch-conf
```

Press `u` to use the suggested changes (and therefore accepting the EULA).

And now you can try to install again:
```
(root) emerge --ask @fonts
```

## Enable font configurations
You also need to enable the fonts so that they can be used as fallback fonts
with `fontconfig`, Gentoo provides support for doing this with the `eselect`
utility.

List the different font configurations with:
```
eselect fontconfig list
```

You should see a list where `croscore` and `noto` is mentioned.
```
...
[28]  60-liberation.conf
[29]  62-croscore-arimo.conf
[30]  62-croscore-cousine.conf
[31]  62-croscore-symbolneu.conf
[32]  62-croscore-tinos.conf
...
[36]  66-noto-mono.conf
[37]  66-noto-sans.conf
[38]  66-noto-serif.conf
...
[41]  70-noto-cjk.conf
```

The Liberation font family is also nice to enable as it provides several nice
alternatives to some common proprietary fonts.

Let's enable all of those (_as root_)!
```
eselect fontconfig enable 62-croscore-arimo.conf
eselect fontconfig enable 62-croscore-cousine.conf
eselect fontconfig enable 62-croscore-symbolneu.conf
eselect fontconfig enable 62-croscore-tinos.conf
eselect fontconfig enable 60-liberation.conf
eselect fontconfig enable 66-noto-mono.conf
eselect fontconfig enable 66-noto-sans.conf
eselect fontconfig enable 66-noto-serif.conf
eselect fontconfig enable 70-noto-cjk.conf
```

And you're done!

The changes will be applied after you've restarted your running applications.
