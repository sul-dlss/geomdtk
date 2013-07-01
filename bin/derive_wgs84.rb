#!/usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require 'druid-tools'
require 'fileutils'
require 'optparse'

# @param overwrite_prj [Boolean] ogr2ogr writes a .prj file that GeoServer doesn't recognize as EPSG:4326
def reproject druid, fn, flags
  k = File.basename(fn, '.zip')
  shp = k + '.shp'
  
  puts "Extracting #{druid.id} #{fn}"
  tmp = "#{flags[:tmpdir]}/#{k}"
  FileUtils.rm_rf tmp if File.directory? tmp
  FileUtils.mkdir_p tmp
  system("unzip -j '#{fn}' -d '#{tmp}'")
  
  [4326].each do |srid|
    ofn = File.join(File.dirname(fn), 'EPSG', srid.to_s, shp)
    odir = File.dirname(ofn)
    puts "Projecting #{fn} into #{ofn}"
    FileUtils.mkdir_p odir unless File.directory? odir
    unless File.exist? ofn and test(?<, fn, ofn) # ofn exists and is older than fn
      system("ogr2ogr -progress -t_srs '#{flags[:wkt][srid.to_s]}' '#{ofn}' '#{tmp}/#{shp}'") 
      if flags[:overwrite_prj]
        File.open(ofn.gsub(%r{shp$}, 'prj'), 'w') {|f| f.write(flags[:wkt][srid.to_s])}
      end
      ozip = fn.gsub(%r{\.zip}, "_EPSG_#{srid}.zip")
      FileUtils.rm_rf tmp
      system("zip -Dj '#{ozip}' #{odir}/#{k}.*")
      FileUtils.rm_rf(File.join(File.dirname(fn), 'EPSG'))
    else
      puts "#{ofn} already generated"
    end
  end
end

# __MAIN__
begin
  File.umask(002)
  flags = {
    :overwrite_prj => true,
    :verbose => false,
    :workspacedir => GeoMDTK::Config.geomdtk.workspace || 'workspace',
    :tmpdir => GeoMDTK::Config.geomdtk.tmpdir || 'tmp',
    # ogr2ogr is using a different WKT than GeoServer -- this one is from GeoServer 2.3.1.
    # As implemented by EPSG database on HSQL:
    #  http://docs.geotools.org/latest/userguide/library/referencing/hsql.html
    # Also see:
    #  http://spatialreference.org/ref/epsg/4326/prettywkt/
    :wkt => {
      '4326' => %Q{
      GEOGCS["WGS 84",
          DATUM["WGS_1984",
              SPHEROID["WGS 84",6378137,298.257223563,
                  AUTHORITY["EPSG","7030"]],
              AUTHORITY["EPSG","6326"]],
          PRIMEM["Greenwich",0,
              AUTHORITY["EPSG","8901"]],
          UNIT["degree",0.01745329251994328,
              AUTHORITY["EPSG","9122"]],
          AUTHORITY["EPSG","4326"]]
      }.split.join.freeze
    }
    
  }  
  
  OptionParser.new do |opts|
    opts.banner = <<EOM
Usage: #{File.basename(__FILE__)} [options] [druid...]
EOM
    opts.on("-v", "--verbose", "Run verbosely") do |v|
      flags[:verbose] = true
    end
    opts.on("--workspace DIR", "Workspace directory for assembly (default: #{flags[:workspacedir]})") do |v|
      flags[:workspacedir] = v
    end
    opts.on("--tmpdir DIR", "Temporary directory for assembly (default: #{flags[:tmpdir]})") do |v|
      flags[:tmpdir] = v
    end
    opts.on("--wkt SRID FILE", "Read WKT for SRID from FILE") do |srid, f|
      flags[:wkt][srid.to_s] = File.read(f).split.join.freeze
    end
  end.parse!
  
  [flags[:tmpdir], flags[:workspacedir]].each do |d|
    raise ArgumentError, "Missing directory #{d}" unless File.directory? d
  end

  if ARGV.empty?
    # matches druid workspace structure
    Dir.glob(flags[:workspacedir] + '/??/???/??/????/???????????/content/*.zip').each do |fn| 
      druid = DruidTools::Druid.new(File.dirname(fn), flags[:workspacedir])
      puts "Processing #{druid.id} #{fn}"
      reproject druid, fn, flags unless fn =~ %r{_EPSG_}i
    end
  else
    ARGV.each do |id|
      druid = DruidTools::Druid.new(id, flags[:workspacedir])
      Dir.glob(druid.content_dir + '/*.zip').each do |fn|
        puts "Processing #{druid.id} #{fn}"
        reproject druid, fn, flags unless fn =~ %r{_EPSG_}i
      end
      
    end
  end
rescue SystemCallError => e
  $stderr.puts "ERROR: #{e.message}"
  exit(-1)
end
