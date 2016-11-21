require 'colorize'

Encoding.default_external = 'UTF-8'

HEADER_STYLE = '[V4+ Styles]'
HEADER_EVENT = '[Events]'
DATA_STYLE = 'Style:'
DATA_EVENT = 'Dialogue:'
DATA_COMMENT = 'Comment:'
SEPARATOR = "; --- ;\n"

name = $name
eps = ENV['eps']
raise 'Usage: rake eps=## [touch] [check]' if eps.nil?

type = ['chs', 'cht', 'jpn']
targets = []
type.each do |t|
  target = "dist/#{name} #{eps.gsub('/', ' ')}.#{t}.ass"
  targets << target
  files = ['layout/all.ass'] +
          Dir["layout/#{t}.ass"] +
          Dir["src/#{eps}/all.*.ass"] +
          Dir["src/#{eps}/jpn.*.ass"] +
          Dir["src/#{eps}/#{t}.*.ass"]
  files << Dir["src/#{eps}/*.meta.ass"].first if t == 'jpn'
  files.compact!
  files.uniq!
  file target => files do |t|
    puts "Generating #{t.name.magenta}"
    t.sources.each { |f| puts " <- #{f}".cyan }
    ass = merge_sub t.sources
    File.write t.name, ass
  end
end

task :default => targets

task :touch do
  mkdir "src/#{eps}" unless File.exists? "src/#{eps}"
  ['chs.meta.ass', 'chs.oped.ass', 'chs.text.ass', 'cht.meta.ass', 'cht.oped.ass', 'cht.text.ass', 'jpn.oped.ass', 'jpn.text.ass'].each do |f|
    target = "src/#{eps}/#{f}"
    next if File.exists? target
    cp "src/empty.ass", target
    source = case f
      when /chs/ then '简日'
      when /cht/ then '繁日'
      when /jpn/ then '日文'
    end
    keys = case f
      when /jpn\.oped/ 
        /(,| )(OP|ED)[- ]JP,/
      when /jpn\.text/ 
        /(,| )TEXT[- ]JP/
      when /oped/ 
        /(,| )(OP|ED)[- ]CN,/
      when /text/ 
        /(,| )(TEXT[- ]CN|TITLE|OTHERS|NOTES|ENG)/
      when /meta/ 
        /(,| )STATE|STAFF,/
    end
    file = Dir["src/#{eps}/*#{source}*.ass"].first
    next if file.nil?
    puts " + Inserting content".cyan
    lines = File.readlines(file).select{|l| l[keys]}
    File.open(target, 'a') {|f| f << lines.join}
  end
end

task :check do
  require 'differ'
  require 'ropencc'

  [['chs.meta.ass', 'cht.meta.ass'], ['chs.oped.ass', 'cht.oped.ass'], ['chs.text.ass', 'cht.text.ass']].each do |f|
    puts f.join(" <=> ").cyan
    target = f.map {|fn| "src/#{eps}/#{fn}"}
    size = target.map {|fn| File.size fn} rescue nil
    if size.nil?
      puts 'WARNING: FILES ARE MISSING.'.red
      next
    end
    content = target.map {|fn| File.readlines fn}
    lines = content.map(&:size)
    linelens = content.map {|c| c.map &:size}
    puts ("Lines: " + lines.join(" <=> ")).red if lines.max != lines.min
    minline = lines.min
    1.upto(minline) do |ln|
      lens = linelens.map {|l| l[ln-1]}
      puts ("Line #{ln}: " + lens.join(" <=> ")).red if lens.max != lens.min
      text = content.map {|c| Ropencc.conv('s2tw.json', c[ln-1]).chomp}
      puts "Line #{ln}:\n".blue + Differ.diff_by_char(text[0], text[1]).to_s + "\n" if text.first != text.last
    end
  end
end

def merge_sub files
  return nil if files.empty?
  ass_file = []
  file_data = files.map { |fn| File.readlines fn }
  layout = file_data.shift
  # Headers
  header = layout.take_while { |l| ! l.start_with? HEADER_STYLE }
  layout = layout.drop header.size
  ass_file += header
  # Styles
  styles = layout.take_while { |l| ! l.start_with? HEADER_EVENT }
  layout = layout.drop styles.size
  styles.delete_if {|s| s.chomp.empty?}
  ass_file += styles
  styles_data = file_data.map { |f| f.select { |l| l.start_with? DATA_STYLE } }
  styles_data.flatten!
  styles_data = dedup styles_data
  ass_file += styles_data << "\n"
  # Events
  layout.delete_if {|s| s.chomp.empty?}
  ass_file += layout
  events_data = file_data.map { |f| f.select { |l| l.start_with?(DATA_EVENT) || l.start_with?(DATA_COMMENT) } + [SEPARATOR] }
  events_data.flatten!
  ass_file += events_data
  ass_file.join
end

def dedup styles
  st = Hash.new nil
  styles.select do |s|
    s_n = s.split(':').last.split(',').first.strip
    if st[s_n]
      puts "  \#  Skip  ( #{s.strip} )"
      if st[s_n] != s.strip
        puts "   Because ( #{st[s_n]} )".red
      else
        puts "  \# Duplicate".cyan
      end
      next false
    end
    st[s_n] = s.strip
    true
  end
end
