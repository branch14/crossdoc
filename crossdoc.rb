#!/usr/bin/env ruby

require 'yaml'
require 'ostruct'

require 'sinatra'
require 'arbre'

def deep_ostruct(values)
  case values
  when Hash
    OpenStruct.new.tap do |o|
      values.each do |key, value|
        o.send key.to_s + '=',
               deep_ostruct(value)
      end
    end
  when Array
    values.map { |v| deep_ostruct(v) }
  else values
  end
end

input = ARGV.shift
output = ARGV.shift

$config = deep_ostruct(YAML.load(File.read(input)))
$config.total = $config.rows.size * $config.columns.size
$result = {}
$result = YAML.load(File.read(output)) if File.exist?(output)

def empty
  ((0...$config.total).to_a - $result.keys).sort
end

def first_empty
  "/q/#{empty.first}"
end

get '/' do
  Arbre::Context.new do
    style 'body { background-color: aliceblue }'
    style '* { font-family: arial; font-size: 36px; text-align: center }'
    style 'table { margin: 0 auto }'
    h1 'crossdoc'
    table do
      tr do
        th ''
        $config.columns.each_with_index do |column, cidx|
          # th column.match(/\((.+)\)/).to_a[1]
          th cidx + 1
        end
      end
      $config.rows.each_with_index do |row, ridx|
        tr do
          #th row
          th ridx + 1
          $config.columns.each_with_index do |column, cidx|
            td do
              idx = ridx*$config.columns.size+cidx
              title = $config.text.question %
                      ["#{$config.text.row} #{row}",
                       "#{$config.text.column} #{column}"]
              a ($result[idx] ? 'X' : 'O'), href: "/q/#{idx}", title: title
            end
          end
        end
      end
    end
    br
    if empty.empty?
      # TODO download svg
      a 'Results', href: '/results'
    else
      if empty.size == $config.total
        a ($config.text.start), href: first_empty
      else
        a ($config.text.continue), href: first_empty
      end
    end
  end
end

get '/q/:idx' do |idx|
  idx = idx.to_i
  ridx = idx / $config.columns.size
  cidx = idx % $config.columns.size
  field = "<span class='row'>#{$config.text.row} #{$config.rows[ridx]}</span>"
  epic = "<span class='column'>#{$config.text.column} #{$config.columns[cidx]}</span>"
  question = ($config.text.question % [field, epic]).gsub("\n", '<br/>')

  Arbre::Context.new do
    style 'body { background-color: aliceblue }'
    style '* { font-family: arial; font-size: 36px; text-align: center }'
    style ".row { color: CornflowerBlue } .column { color: orange }"
    style "textarea { width: 50%; height: 30%; text-align: left }"
    a h1("crossdoc"), href: '/'
    h2 $config.text.stats % [idx + 1, $config.total, empty.size]
    h3 question.html_safe
    form method: 'POST', action: "/q/#{idx}" do
      textarea $result[idx] || $config.text.na, name: 'text'
      br
      input(value: $config.text.save, type: 'submit')
    end
  end
end

post '/q/:idx' do |idx|
  idx = idx.to_i
  $result[idx] = params[:text]
  File.open(output, 'w') { |f| f.print(YAML.dump($result)) }
  redirect '/' if empty.empty?
  redirect first_empty
end

get '/results' do
  Arbre::Context.new do
    style 'body { background-color: aliceblue }'
    style '* { font-family: arial; text-align: left }'
    style 'table { margin: 0 auto }'
    style 'td { border-top: 1px solid black }'
    a h1("crossdoc"), href: '/'
    table do
      tr do
        th [$config.text.row, $config.text.column] * ' / '
        $config.columns.each_with_index do |column, cidx|
          th column.gsub(' ', '&nbsp;').html_safe
        end
      end
      $config.rows.each_with_index do |row, ridx|
        tr do
          th row
          $config.columns.each_with_index do |column, cidx|
            td do
              idx = ridx*$config.columns.size+cidx
              div $result[idx]
            end
          end
        end
      end
    end
  end
end
