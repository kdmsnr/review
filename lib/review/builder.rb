# encoding: utf-8
#
# Copyright (c) 2002-2009 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/index'
require 'review/exception'
require 'stringio'
require 'nkf'

module ReVIEW

  class Builder

    def pre_paragraph
      nil
    end
    def post_paragraph
      nil
    end

    def initialize(strict = false, *args)
      @strict = strict
      builder_init(*args)
    end

    def builder_init(*args)
    end
    private :builder_init

    def bind(compiler, chapter, location)
      @compiler = compiler
      @chapter = chapter
      @location = location
      @output = StringIO.new
      @book = ReVIEW.book
      builder_init_file
    end

    def builder_init_file
    end
    private :builder_init_file

    def result
      @output.string
    end

    alias :raw_result result

    def convert_outencoding(*s)
      if ReVIEW.book.param["outencoding"] =~ /^EUC$/i
        NKF.nkf("-W, -e", *s)
      elsif ReVIEW.book.param["outencoding"] =~ /^SJIS$/i
        NKF.nkf("-W, -s", *s)
      elsif ReVIEW.book.param["outencoding"] =~ /^JIS$/i
        NKF.nkf("-W, -j", *s)
      else
        ## for 1.9 compatibility
        if s.size == 1
          return s[0]
        end
        return *s
      end
    end

    def print(*s)
      @output.print(convert_outencoding(*s))
    end

    def puts(*s)
      @output.puts(convert_outencoding(*s))
    end

    def list(lines, id, caption)
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      list_body lines
    end

    def listnum(lines, id, caption)
      begin
        list_header id, caption
      rescue KeyError
        error "no such list: #{id}"
      end
      listnum_body lines
    end

    def source(lines, caption)
      source_header caption
      source_body lines
    end

    def image(lines, id, caption, metric = nil)
      if @chapter.image(id).bound?
        image_image id, caption, metric
      else
        warn "image not bound: #{id}" if @strict
        image_dummy id, caption, lines
      end
    end

    def table(lines, id = nil, caption = nil)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\-]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        table_header id, caption unless caption.nil?
      rescue KeyError => err
        error "no such table: #{id}"
      end
      return if rows.empty?
      table_begin rows.first.size
      if sepidx
        sepidx.times do
          tr rows.shift.map {|s| th(s) }
        end
        rows.each do |cols|
          tr cols.map {|s| td(s) }
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr [th(h)] + cs.map {|s| td(s) }
        end
      end
      table_end
    end

    def adjust_n_cols(rows)
      rows.each do |cols|
        while cols.last and cols.last.strip.empty?
          cols.pop
        end
      end
      n_maxcols = rows.map {|cols| cols.size }.max
      rows.each do |cols|
        cols.concat [''] * (n_maxcols - cols.size)
      end
      rows
    end
    private :adjust_n_cols

    #def footnote(id, str)
    #  @footnotes.push [id, str]
    #end
    #
    #def flush_footnote
    #  footnote_begin
    #  @footnotes.each do |id, str|
    #    footnote_item(id, str)
    #  end
    #  footnote_end
    #end

    def compile_inline(s)
      @compiler.text(s)
    end

    def inline_chapref(id)
      @chapter.env.chapter_index.display_string(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      @chapter.env.chapter_index.number(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      @chapter.env.chapter_index.title(id)
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_list(id)
      "リスト#{@chapter.list(id).number}"
    rescue KeyError
      error "unknown list: #{id}"
      nofunc_text("[UnknownList:#{id}]")
    end

    def inline_img(id)
      "図#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
    end

    def inline_table(id)
      "表#{@chapter.table(id).number}"
    rescue KeyError
      error "unknown table: #{id}"
      nofunc_text("[UnknownTable:#{id}]")
    end

    def inline_fn(id)
      @chapter.footnote(id).content
    rescue KeyError
      error "unknown footnote: #{id}"
      nofunc_text("[UnknownFootnote:#{id}]")
    end

    def inline_bou(str)
      text(str)
    end

    def inline_ruby(arg)
      base, ruby = *arg.split(',', 2)
      compile_ruby(base, ruby)
    end

    def inline_kw(arg)
      word, alt = *arg.split(',', 2)
      compile_kw(word, alt)
    end

    def inline_href(arg)
      url, label = *arg.scan(/(?:(?:(?:\\\\)*\\,)|[^,\\]+)+/).map(&:lstrip)
      url = url.gsub(/\\,/, ",").strip
      compile_href(url, label)
    end

    def text(str)
      str
    end

    def bibpaper(lines, id, caption)
      bibpaper_header id, caption
      unless lines.empty?
        puts ""
        bibpaper_bibpaper id, caption, lines
      end
      puts ""
    end

    def inline_hd(id)
      m = /\A(\w+)\|(.+)/.match(id)
      chapter = @book.chapters.detect{|chap| chap.id == m[1]} if m && m[1]
      return inline_hd_chap(chapter, m[2]) if chapter
      return inline_hd_chap(@chapter, id)
    end

    def raw(str)
      print str.gsub("\\n", "\n")
    end

    def find_pathes(id)
      if ReVIEW.book.param["subdirmode"].nil?
        re = /\A#{@chapter.name}-#{id}(?i:#{@book.image_types.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
        .sort_by {|ent| @book.image_types.index(File.extname(ent).downcase) }\
        .map {|ent| "#{@book.basedir}/#{ent}" }
      else
        re = /\A#{id}(?i:#{@chapter.name.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
        .sort_by {|ent| @book.image_types.index(File.extname(ent).downcase) }\
        .map {|ent| "#{@book.asedir}/#{@chapter.name}/#{ent}" }
      end
    end

    def entries
      if ReVIEW.book.param["subdirmode"].nil?
        @entries ||= Dir.entries(@book.basedir + @book.image_dir)
      else
        @entries ||= Dir.entries(File.join(@book.basedir + @book.image_dir, @chapter.name))
      end
    rescue Errno::ENOENT
    @entries = []
    end

    def warn(msg)
      $stderr.puts "#{@location}: warning: #{msg}"
    end

    def error(msg)
      raise ApplicationError, "#{@location}: error: #{msg}"
    end

    def getChap(chapter = @chapter)
      if ReVIEW.book.param["secnolevel"] > 0 && !chapter.number.nil? && !chapter.number.to_s.empty?
        return "#{chapter.number}."
      end
      return ""
    end

    def extract_chapter_id(chap_ref)
      m = /\A(\w+)\|(.+)/.match(chap_ref)
      if m
        return [@book.chapters.detect{|chap| chap.id == m[1]}, m[2]]
      else
        return [@chapter, chap_ref]
      end
    end
  end

end   # module ReVIEW
