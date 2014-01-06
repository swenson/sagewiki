#!/usr/bin/env ruby

# Copyright 2014 Christopher Swenson (chris@caswenson.com)
# Copyright (c) Tom Preston-Werner, Rick Olson

require 'rubygems'
require 'gollum/app'

repo = 'test-flat.git'
htdigest = 'passwd'
realm = 'sage.math.washington.edu'
opaque = 'b6c7d88eaa93538d264f16282a54d7c6c90556c13580337759ab7ce9e598e215'


class Gollum::Filter::EscapeCode < Gollum::Filter
  def extract(data)
    data.gsub!(/^([ \t]*)``` ?([^\r\n]+)?\r?\n(.+?)\r?\n\1```[ \t]*\r?$/m) do
      '```' + $2 + "\n" + $3.gsub('<', '&lt;') + "\n```\n"
    end

    data
  end
  def process(d) d; end
end

class Gollum::Filter::SageCell < Gollum::Filter
  def initialize(arg)
    super(arg)
    @map = {}
  end

  def extract(data)
    data.gsub! /^([ \t]*)``` ?sagecell\r?\n(.+?)\r?\n```[ \t]*\r?$/m do
      spaces = $1
      code = $2
      remove_leading_space(code, /^#{spaces}/m)
      remove_leading_space(code, /^(  |\t)/m)
      digest = Digest::SHA1.hexdigest(code)

      @map[digest] = "<div class=\"sagecellraw\">\n#{code}\n</div>"
      digest
    end

    data
  end

  def process(data)
    @map.each do |id, value|
      data.gsub!(id, value)
    end
    data
  end

  private
  # Remove the leading space from a code block. Leading space
  # is only removed if every single line in the block has leading
  # whitespace.
  #
  # code      - The code block to remove spaces from
  # regex     - A regex to match whitespace
  def remove_leading_space(code, regex)
    if code.lines.all? { |line| line =~ /\A\r?\n\Z/ || line =~ regex }
      code.gsub!(regex) do
        ''
      end
    end
  end

end


gollum_path = File.expand_path(repo)
Precious::App.set(:gollum_path, gollum_path)
Precious::App.set(:default_markup, :markdown)
Precious::App.set(:wiki_options, {:live_preview => false,
                                  :universal_toc => false,
                                  :allow_uploads => true,
                                  :mathjax => true,
                                  :css => true,
                                  :js => true,
                                  :repo_is_bare => true,
                                  :filter_chain => [:Metadata, :TOC, :RemoteCode, :EscapeCode, :SageCell, :Code, :Sanitize, :WSD, :Tags, :Render]
                                  })

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
