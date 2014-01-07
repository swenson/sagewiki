#!/usr/bin/env ruby

# Copyright 2014 Christopher Swenson (chris@caswenson.com)
# Copyright (c) Tom Preston-Werner, Rick Olson

require 'rubygems'
require 'gollum/app'

repo = '../sage_wiki/test'
htdigest = 'passwd'
realm = 'sage.math.washington.edu'
opaque = 'b6c7d88eaa93538d264f16282a54d7c6c90556c13580337759ab7ce9e598e215'


class Gollum::Filter::SpecialInclude < Gollum::Filter
  def extract(data)
    data.gsub!(/(.?)\[\[(.+?)\]\]([^\[]?)/m) do
      tag = $2
      if $1 == "'" && $3 != "'"
        "[[#{$2}]]#{$3}"
      elsif $2.start_with? 'includesnippet'
        page_name = tag[15..-1]
        if @markup.include_levels > 0
          page = @markup.wiki.page(page_name)
          if page
            page_data = page.text_data(@markup.encoding)
            i = page_data.index('<!--start-include-->')
            unless i.nil?
              i += 20
              j = page_data.index('---', i)
              unless j.nil?
                page_data[i..j-1]
              else
                page_data[i..-1]
              end
            else
              page_data
            end
          else
            html_error("Cannot include #{process_page_link_tag(page_name)} - does not exist yet")
          end
        else
          html_error("Too many levels of included pages, will not include #{process_page_link_tag(page_name)}")
        end
      else
        "#{$1}[[#{$2}]]#{$3}" # pass through
      end
    end
    data
  end

  def process(data) data; end
end

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
                                  :repo_is_bare => false,
                                  :filter_chain => [:SpecialInclude, :Metadata, :TOC, :RemoteCode, :EscapeCode, :SageCell, :Code, :Sanitize, :WSD, :Tags, :Render]
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
