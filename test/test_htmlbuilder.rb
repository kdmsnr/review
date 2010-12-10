# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'

class HTMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = HTMLBuilder.new()
    @param = {
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
      "stylesheet" => nil,  # for HTMLBuilder
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Chapter.new(nil, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_headline_level1
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<h1 id="test"><a id="h1" />第1章　this is test.</h1>\n|, @builder.raw_result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    @builder.headline(1,"test","this is test.")
    assert_equal %Q|<h1 id="test"><a id="h1" />this is test.</h1>\n|, @builder.raw_result
  end

  def test_headline_level1_with_inlinetag
    @builder.headline(1,"test","this @<b>{is} test.<&\">")
    assert_equal %Q|<h1 id="test"><a id="h1" />第1章　this <b>is</b> test.&lt;&amp;&quot;&gt;</h1>\n|, @builder.raw_result
  end

  def test_headline_level2
    @builder.headline(2,"test","this is test.")
    assert_equal %Q|\n<h2 id="test"><a id="h1-1" />1.1　this is test.</h2>\n|, @builder.raw_result
  end

  def test_headline_level3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\n<h3 id="test"><a id="h1-0-1" />this is test.</h3>\n|, @builder.raw_result
  end

  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    @builder.headline(3,"test","this is test.")
    assert_equal %Q|\n<h3 id="test"><a id="h1-0-1" />1.0.1　this is test.</h3>\n|, @builder.raw_result
  end

  def test_label
    @builder.label("label_test")
    assert_equal %Q|<a id="label_test" />\n|, @builder.raw_result
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|<a href="http://github.com" class="link">GitHub</a>|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|<a href="http://github.com" class="link">http://github.com</a>|, ret
  end

  def test_inline_raw
    ret = @builder.inline_raw("@<tt>{inline}")
    assert_equal %Q|@&lt;tt&gt;{inline}|, ret
  end

  def test_inline_in_table
    ret = @builder.table(["<b>1</b>\t<i>2</i>", "------------", "<b>3</b>\t<i>4</i>&lt;&gt;&amp;"])
    assert_equal %Q|<div class="table">\n<table>\n<tr><th><b>1</b></th><th><i>2</i></th></tr>\n<tr><td><b>3</b></td><td><i>4</i>&lt;&gt;&amp;</td></tr>\n</table>\n</div>\n|, @builder.raw_result
  end

  def test_inline_br
    ret = @builder.inline_br("")
    assert_equal %Q|<br />|, ret
  end

  def test_inline_i
    ret = @builder.compile_inline("test @<i>{inline test} test2")
    assert_equal %Q|test <i>inline test</i> test2|, ret
  end

  def test_inline_i_and_escape
    ret = @builder.compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test <i>inline&lt;&amp;;\\ test</i> test2|, ret
  end

  def test_inline_b
    ret = @builder.compile_inline("test @<b>{inline test} test2")
    assert_equal %Q|test <b>inline test</b> test2|, ret
  end

  def test_inline_b_and_escape
    ret = @builder.compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test <b>inline&lt;&amp;;\\ test</b> test2|, ret
  end

  def test_inline_tt
    ret = @builder.compile_inline("test @<tt>{inline test} test2")
    assert_equal %Q|test <tt>inline test</tt> test2|, ret
  end

  def test_inline_tti
    ret = @builder.compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test <tt><i>inline test</i></tt> test2|, ret
  end

  def test_inline_ttb
    ret = @builder.compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test <tt><b>inline test</b></tt> test2|, ret
  end

  def test_inline_uchar
    ret = @builder.compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, ret
  end

  def test_quote
    lines = ["foo", "bar", "","buz"]
    @builder.quote(lines)
    assert_equal %Q|<blockquote><p>foobar</p>\n<p>buz</p></blockquote>\n|, @builder.raw_result
  end

  def test_column
    @builder.column(["test1", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<div class="column">\n<p class="caption">this is <b>test</b>&lt;&amp;&gt;_</p>\n<p>test1</p>\n<p>test<i>2</i></p>\n</div>\n|, @builder.raw_result
  end

  def test_memo
    @builder.memo(["test1", "", "test<i>2</i>"], "this is @<b>{test}<&>_")
    assert_equal %Q|<div class="memo">\n<p class="caption">this is <b>test</b>&lt;&amp;&gt;_</p>\n<p>test1</p>\n<p>test<i>2</i></p>\n</div>\n|, @builder.raw_result
  end

  def test_noindent
    @builder.noindent
    @builder.paragraph(["foo", "bar"])
    @builder.paragraph(["foo2", "bar2"])
    assert_equal %Q|<p class="noindent">foobar</p>\n<p>foo2bar2</p>\n|, @builder.raw_result
  end

  def test_flushright
    @builder.flushright(["foo", "bar", "", "buz"])
    assert_equal %Q|<p class="flushright">foobar</p>\n<p class="flushright">buz</p>\n|, @builder.raw_result
  end

  def test_raw
    @builder.raw("<&>\\n")
    assert_equal %Q|<&>\n|, @builder.raw_result
  end

  def test_image
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo",nil)
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, @builder.raw_result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.image_image("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, @builder.raw_result
  end

  def test_indepimage
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo",nil)
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, @builder.raw_result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg",nil,nil)
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="" />\n</div>\n|, @builder.raw_result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg","sample photo","scale=1.2")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, @builder.raw_result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    @builder.indepimage("sampleimg",nil,"scale=1.2")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="" />\n</div>\n|, @builder.raw_result
  end

end
