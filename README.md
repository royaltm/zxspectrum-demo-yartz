Yet Another RotoZoomer
======================

r-type of 

```
   {____   {_____        {__   
 {_    {__ {__   {__  {__   {__
{__        {__    {__{__       
{__        {__    {__{__       
{__   {____{__    {__{__       
 {__    {_ {__   {__  {__   {__
  {_____   {_____       {____  
```

presents the sources for it's ZX Spectrum [demo](http://www.pouet.net/prod.php?which=80935) released on the [Speccy.pl party 2019-04-06](http://speccy.pl/party/).

You can watch it [here](https://royaltm.github.io/spectrusty/web-zxspectrum/#m=48k#ay=melodik#tap=https://yeondir.com/zxspectrum/files/demos/yartz.tap#fresh) in the web emulator.

This is a cleaned up version adopted to the latest release of the [z80rb](https://github.com/royaltm/z80-rb).

To be able to compile the demo you'd need:

- [Ruby](https://www.ruby-lang.org/en/downloads/) 2.3.0 or later
- `gem install bundler`
- `cd zxspectrum-demo-yartz`
- `rake install` or `bundle install`

To build the TAP file run:

- `cd zxspectrum-demo-yartz`
- `rake tap` or `bundle exec ruby yartz.rb`

which should produce the `yartz.tap` file.

Enjoy!


COPYING
-------

![WTFPL](wtfpl-badge-4.png?raw=true "WTFPL")

Copyright © 2019 r-type/GDC (Rafał Michalski) <r-type@yeondir.com>
This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the COPYING file for more details.
