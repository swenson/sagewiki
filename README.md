# sagewiki

Tools for the Sage wikis.

## convert.py

Master script for converting an existing (SageMath) MoinMoin wiki to a gollum wiki.

## config.ru

Rack script for running gollum with the necessary authentication bits,
and loading the correct modules.

## moin2git and moin2mdwn

These files are modifications of the same-named files from http://ikiwiki.info/tips/convert_moinmoin_to_ikiwiki/

I believe the original authors are Josh Triplett and Antoine Beaupré.

## Licenses

`moin2git` and `moin2mdwn` are probably licensed under the GPLv2 license (see `GPL_LICENSE`).

`unidecode` is vendored in `unidecode`, and is licensed under GPLv2 (see `GPL_LICENSE`).

The rest of everything in this repository is licensed under the MIT license (see `MIT_LICENSE`).

