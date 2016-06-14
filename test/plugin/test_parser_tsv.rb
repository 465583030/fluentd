require_relative '../helper'
require 'fluent/test/driver/parser'
require 'fluent/plugin/parser'

class TSVParserTest < ::Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  data('array param' => '["a","b"]', 'string param' => 'a,b')
  def test_config_params(param)
    parser = Fluent::TextParser::TSVParser.new

    assert_equal "\t", parser.delimiter

    parser.configure(
                     'keys' => param,
                     'delimiter' => ',',
                     )

    assert_equal ['a', 'b'], parser.keys
    assert_equal ",", parser.delimiter
  end

  data('array param' => '["time","a","b"]', 'string param' => 'time,a,b')
  def test_parse(param)
    parser = Fluent::TextParser::TSVParser.new
    parser.configure('keys' => param, 'time_key' => 'time')
    parser.parse("2013/02/28 12:00:00\t192.168.0.1\t111") { |time, record|
      assert_equal(str2time('2013/02/28 12:00:00', '%Y/%m/%d %H:%M:%S'), time)
      assert_equal({
                     'a' => '192.168.0.1',
                     'b' => '111',
                   }, record)
    }
  end

  def test_parse_with_time
    time_at_start = Time.now.to_i

    parser = Fluent::TextParser::TSVParser.new
    parser.configure('keys' => 'a,b')
    parser.parse("192.168.0.1\t111") { |time, record|
      assert time && time >= time_at_start, "parser puts current time without time input"
      assert_equal({
                     'a' => '192.168.0.1',
                     'b' => '111',
                   }, record)
    }

    parser = Fluent::TextParser::TSVParser.new
    parser.estimate_current_event = false
    parser.configure('keys' => 'a,b', 'time_key' => 'time')
    parser.parse("192.168.0.1\t111") { |time, record|
      assert_equal({
                     'a' => '192.168.0.1',
                     'b' => '111',
                   }, record)
      assert_nil time, "parser returns nil w/o time and if configured so"
    }
  end

  data(
       'left blank column' => ["\t@\t@", {"1" => "","2" => "@","3" => "@"}],
       'center blank column' => ["@\t\t@", {"1" => "@","2" => "","3" => "@"}],
       'right blank column' => ["@\t@\t", {"1" => "@","2" => "@","3" => ""}],
       '2 right blank columns' => ["@\t\t", {"1" => "@","2" => "","3" => ""}],
       'left blank columns' => ["\t\t@", {"1" => "","2" => "","3" => "@"}],
       'all blank columns' => ["\t\t", {"1" => "","2" => "","3" => ""}])
  def test_black_column(data)
    line, expected = data

    parser = Fluent::TextParser::TSVParser.new
    parser.configure('keys' => '1,2,3')
    parser.parse(line) { |time, record|
      assert_equal(expected, record)
    }
  end

  def test_parse_with_keep_time_key
    parser = Fluent::TextParser::TSVParser.new
    parser.configure(
                     'keys'=>'time',
                     'time_key'=>'time',
                     'time_format'=>"%d/%b/%Y:%H:%M:%S %z",
                     'keep_time_key'=>'true',
                     )
    text = '28/Feb/2013:12:00:00 +0900'
    parser.parse(text) do |time, record|
      assert_equal text, record['time']
    end
  end

  data('array param' => '["a","b","c","d","e","f"]', 'string param' => 'a,b,c,d,e,f')
  def test_parse_with_null_value_pattern
    parser = Fluent::TextParser::TSVParser.new
    parser.configure(
                     'keys'=>param,
                     'time_key'=>'time',
                     'null_value_pattern'=>'^(-|null|NULL)$'
                     )
    parser.parse("-\tnull\tNULL\t\t--\tnuLL") do |time, record|
      assert_nil record['a']
      assert_nil record['b']
      assert_nil record['c']
      assert_equal record['d'], ''
      assert_equal record['e'], '--'
      assert_equal record['f'], 'nuLL'
    end
  end

  data('array param' => '["a","b"]', 'string param' => 'a,b')
  def test_parse_with_null_empty_string
    parser = Fluent::TextParser::TSVParser.new
    parser.configure(
                     'keys'=>param,
                     'time_key'=>'time',
                     'null_empty_string'=>true
                     )
    parser.parse("\t ") do |time, record|
      assert_nil record['a']
      assert_equal record['b'], ' '
    end
  end
end
