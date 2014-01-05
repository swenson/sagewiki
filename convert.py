#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2014 Christopher Swenson (chris@caswenson.com)

import glob
import os
import os.path
import wikiconfig

config = wikiconfig.Config("wikiconfig")


os.system('rm -rf test.git')
os.system('mkdir test.git')
os.chdir('test.git')
os.system('git init')
os.chdir('..')
os.system('python moin2git | (cd test.git; git fast-import)')

def find_md_files():
  md = []
  for root, dirs, files in os.walk('test'):
    for file in files:
      if file.endswith(".md"):
        md.append(os.path.join(root, file))
  return md

def find_current(path):
  l = sorted(glob.glob("data/pages/%s/revisions/*" % (path,)))
  if l:
    return l[-1]

def build_markdown():
  os.system('rm -rf test')
  os.system('git clone test.git test')

  for b in broken:
    if os.path.exists("test/%s.md"):
      print "Not broken: %s" % (b,)
      continue
    origin = b.replace(":", "(3a)").replace("/", "(2f)").replace(".", "(2e)").replace(" ", "(20)").replace("|", "(7c)")
    if os.path.exists("data/pages/%s/current" % (origin,)):
      print "Unbreaking %s" % b
      current = find_current(origin)
      if current:
        os.system("mkdir -p \"test/%s\"" % (os.path.dirname(b)))
        os.system("cp \"%s\" \"test/%s.md\"" % (current, b))
      else:
        print "No revisions found for %s" % b
    else:
      print "Could not find %s to unbreak" % b

  os.system("python moin2mdwn -r test")


first = True
pre_broken = set([])
broken = set([])

# we have to keep running this until it collects all known broken files.
while True:
  new_broken = set(broken) - set(pre_broken)

  print "Found new broken files: %d '%s'" % (len(new_broken), "' '".join(new_broken),)
  if not first and not new_broken:
    break
  first = False


  pre_broken = broken

  build_markdown()

  with open('broken.txt') as broken_file:
    broken = set(broken_file.read().strip().split("\n"))
  broken = set([x for x in broken if x.strip()])


md_files = find_md_files()

# convert the broken files to markdown manually as well
for b in broken:
  origin = b.replace("/", "(2f)").replace(".", "(2e)").replace(" ", "(20)").replace("|", "(7c)")
  if os.path.exists("data/pages/%s/current" % (origin,)):
    current = find_current(origin)
    if current and not os.path.exists("test/%s.md" % b):
      print "Converting manually %s" % b
      os.system("mkdir -p \"test/%s\"" % (os.path.dirname(b)))
      os.system("python moin2mdwn -r test -p %s" % (b,))


os.chdir('test')
os.system("git add .")
os.system("git commit -a -m \"Convert to markdown\"")
os.system("git mv MyStartingPage.md Home.md")
os.system("git commit -a -m \"Move home page to Home.md\"")
os.chdir('..')

with open('test/_Header.md', 'w') as fout:
  fout.write(config.logo_string)

with open('test/custom.css', 'w') as fout:
  fout.write('.sagecell_output th, .sagecell_output td {border: none;}')

with open('test/custom.js', 'w') as fout:
  fout.write('''

(function() {
    var jq = document.createElement('script');
    jq.type = 'text/javascript';
    jq.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'aleph.sagemath.org/static/jquery.min.js';
    var s = document.getElementsByTagName('script')[0];
    s.parentNode.insertBefore(jq, s);
})();

$.getScript('http://aleph.sagemath.org/embedded_sagecell.js').done(function(script, textStatus ) {
    sagecell.makeSagecell({inputLocation: '.sagecellraw'});
});
''')

os.chdir('test')
os.system("git add _Header.md custom.css custom.js")
os.system("git commit -a -m \"Add header, custom css and js\"")
os.chdir('..')
