require 'pathname'
require 'json'

results_raw_path = ARGV[0]

results_path = Pathname.new(results_raw_path)
all_stats_files = Dir.glob("#{results_path}/*.stats.json")
all_stats = all_stats_files.map {|f| JSON.parse(File.read(f)) }

gems_count = all_stats.size
gems_which_finished_parsing = all_stats.select {|s| s.key?("parsing") }
gems_which_finished_building = all_stats.select {|s| s.key?("building") }
gems_which_finished_typing = all_stats.select {|s| s.key?("typing") }
gems_finished = gems_which_finished_typing.select {|s| s.key?("typing") }.size

total_parsing_time = gems_which_finished_parsing.map {|s| s.fetch("parsing") }.sum
total_building_time = gems_which_finished_building.map {|s| s.fetch("building") }.sum
total_typing_time = gems_which_finished_typing.map {|s| s.fetch("typing") }.sum

parsing_by_building = gems_which_finished_building.map {|s| s.fetch("parsing") / s.fetch("building") }
building_by_typing = gems_which_finished_typing.map {|s| s.fetch("building") / s.fetch("typing") }
typing_per_100k_nodes = gems_which_finished_typing.map {|s| (s.fetch("typing") * 100_000) / s.fetch("processed_nodes") }

total_results = {
  gems_count: gems_count,
  gems_finished: gems_finished,
  gems_finished_percent: gems_finished.to_f / gems_count,
  total_parsing_time: total_parsing_time,
  total_building_time: total_building_time,
  total_typing_time: total_typing_time,
  min_parsing_by_building: parsing_by_building.min,
  max_parsing_by_building: parsing_by_building.max,
  avg_parsing_by_building: parsing_by_building.sum / parsing_by_building.size,
  min_building_by_typing: building_by_typing.min,
  max_building_by_typing: building_by_typing.max,
  avg_building_by_typing: building_by_typing.sum / building_by_typing.size,
  min_typing_per_100k_nodes: typing_per_100k_nodes.min,
  max_typing_per_100k_nodes: typing_per_100k_nodes.max,
  avg_typing_per_100k_nodes: typing_per_100k_nodes.sum / typing_per_100k_nodes.size,
}

require 'pp'
pp total_results

puts all_stats_files.zip(all_stats).select {|_f, s| !s.key?("typing") }.map(&:first)
