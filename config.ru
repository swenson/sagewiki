#!/usr/bin/env ruby

# Copyright 2014 Christopher Swenson (chris@caswenson.com)

require 'rubygems'
require 'gollum/app'

repo = '../sage_wiki/sage_wiki/test/'
htdigest = 'passwd'
realm = 'sage.math.washington.edu'
opaque = 'b6c7d88eaa93538d264f16282a54d7c6c90556c13580337759ab7ce9e598e215'

gollum_path = File.expand_path(repo)
Precious::App.set(:gollum_path, gollum_path)
Precious::App.set(:default_markup, :markdown)
Precious::App.set(:wiki_options, {:live_preview => false, :universal_toc => false,
                                  :allow_uploads => true,
                                  :mathjax => true})

public = Precious::App

class GollumAuth
  def initialize(htdigest, realm, opaque)
    @htdigest = htdigest
    @realm = realm
    @opaque = opaque
    @passes = {}
    @last_run = 0
  end

  def reload_passes
    new_passes = {}
    File.open(@htdigest, 'r').each_line do |line|
      if line.strip != ""
        username, realm, hash = line.split(':')
        new_passes["#{username}:#{realm}"] = hash.strip
      end
    end
    @passes = new_passes
    @last_run = Time.new.to_i
    puts "Loaded #{@passes.length} passwords\n"
  end

  def passes
    now = Time.new.to_i
    if now - @last_run >= 60
      reload_passes
    end
    @passes
  end
end

auth = GollumAuth.new(htdigest, realm, opaque)

protected = Rack::Auth::Digest::MD5.new(public, {:realm => realm, :opaque => opaque, :passwords_hashed => true}) do |username|
  auth.passes["#{username}:#{realm}"]
end

class Wrapper
  def initialize(pub, priv)
    @pub = pub
    @priv = priv
  end
  def call(env)
    if env['PATH_INFO'] =~ /^\/(edit|create|delete|rename|revert|uploadFile)/
      @priv.call(env)
    else
      @pub.call(env)
    end
  end
end

run Wrapper.new(public, protected)
