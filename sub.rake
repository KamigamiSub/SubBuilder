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
raise 'Usage: rake eps=## [touch]' if eps.nil?

type = ['chs', 'cht', 'jpn']
targets = []
type.each do |t|
  target = "dist/#{name} #{eps}.#{t}.ass"
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
      when /jpn\.oped/ then /(,| )(OP|ED) JP,/
      when /jpn\.text/ then /(,| )TEXT JP/
      when /oped/ then /(,| )(OP|ED) CN,/
      when /text/ then /(,| )(TEXT CN|TITLE|OTHERS|NOTES|ENG)/
      when /meta/ then /(,| )(STATE|STAFF),/
    end
    file = Dir["src/#{eps}/*#{source}*.ass"].first
    next if file.nil?
    puts " + Inserting content".cyan
    lines = File.readlines(file).select{|l| l[keys]}
    File.open(target, 'a') {|f| f << lines.join}
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
  styles.delete "\n"
  ass_file += styles
  styles_data = file_data.map { |f| f.select { |l| l.start_with? DATA_STYLE } }
  styles_data.flatten!
  styles_data = dedup styles_data
  ass_file += styles_data << "\n"
  # Events
  layout.delete "\n"
  ass_file += layout
  events_data = file_data.map { |f| f.select { |l| l.start_with?(DATA_EVENT) || l.start_with?(DATA_COMMENT) } + [SEPARATOR] }
  events_data.flatten!
  ass_file += events_data
  ass_file.join
end

def dedup styles
  st = Hash.new 0
  styles.select do |s|
    s_n = s.split(':').last.split(',').first.strip
    if st[s_n] == 1
      puts "  # Skip ( #{s.chomp} )"
      next false
    end
    st[s_n] = 1
    true
  end
end
