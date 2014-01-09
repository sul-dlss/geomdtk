#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'optparse'
require 'fileutils'

def extract_thumbnail fn, flags
  if fn =~ %r{^(.*)\.(shp|tif)\.xml$}i or File.basename(fn) == 'metadata.xml'
    puts "Processing #{fn} for JPEG" if flags[:verbose]
    thumbnail_fn = File.join(File.dirname(fn), 'preview.jpg')
    puts "Writing to #{thumbnail_fn}" if flags[:debug]
    GeoHydra::Transform.extract_thumbnail fn, thumbnail_fn
  else
    raise OptionParser::InvalidOption, "File <#{fn}> is not ESRI metadata format"
  end
end

def process_file fn, flags
  puts "Processing #{fn}" if flags[:verbose]
  if fn =~ %r{^(.*).(shp|tif).xml$}
    ofn = $1 + '-iso19139.xml'
    ofn_fc = $1 + '-iso19139-fc.xml'
  elsif File.basename(fn) == 'metadata.xml'
    ofn = File.join(File.dirname(fn), 'metadata.iso19139.xml')
    ofn_fc = File.join(File.dirname(fn), 'metadata.iso19139-fc.xml')
  else
    raise OptionParser::InvalidOption, "File <#{fn}> is not named correctly"
  end
  
  if flags[:rebuild] or not (FileUtils.uptodate?(ofn, [fn]) and FileUtils.uptodate?(ofn_fc, [fn]))
    ap({:fn => fn, :ofn => ofn, :ofn_fc => ofn_fc}) if flags[:debug]
    begin
      GeoHydra::Transform.from_arcgis fn, ofn, ofn_fc
      extract_thumbnail(fn, flags)
      if flags[:mv_jpg]
        dstdir = "#{File.dirname(fn)}/../content/"
        FileUtils.mkdir_p(dstdir) unless File.directory?(dstdir)
        system("mv #{File.dirname(fn)}/*.jpg #{dstdir}/")
        
      end
    rescue Exception => e
      puts e
    end
    
  end
end

flags = {
  :verbose => false,
  :debug => false,
  :rebuild => false,
  :mv_jpg => true,
  :directory => '/var/geomdtk/current/stage'
}
OptionParser.new do |opts|
  opts.banner = "
Usage: #{__FILE__} [-v] file.shp.xml [file.shp.xml ...]
       #{__FILE__} [-v] metadata.xml [metadata.xml ...]
       #{__FILE__} [-v] [directory]
"
  opts.on("-v", "--verbose", "Run verbosely") do |v|
    flags[:debug] = true if flags[:verbose]
    flags[:verbose] = true
  end
end.parse!
ARGV << flags[:directory] if ARGV.empty?

ap({:flags => flags, :argv => ARGV}) if flags[:debug]

n = 0
ARGV.each do |fn|
  if File.directory? fn
    Dir.glob(File.join(fn, '**', '*.shp.xml')) do |fn2|
      process_file fn2, flags if File.exist?(fn2)
      n = n + 1
    end
    Dir.glob(File.join(fn, '**', 'metadata.xml')) do |fn2|
      process_file fn2, flags if File.exist?(fn2)
      n = n + 1
    end
  elsif File.exist? fn
    process_file fn, flags
    n = n + 1
  else
    $stderr.puts "WARNING: Missing file <#{fn}>"
  end
end
puts "Processed #{n} ArcGIS metadata files"

