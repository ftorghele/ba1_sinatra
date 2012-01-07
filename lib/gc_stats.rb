# Basic middleware to help developers track their memory usage
# DO NOT USE IN PRODUCTION
# Currently only tested on Ruby 1.9 and no support guaranteed

class GCStats

  @@req_since_gc_cycle = 0

  def initialize(app)
    GC::Profiler.enable unless GC::Profiler.enabled?
    @app = app
  end

  def call(env)
    before_stats = ObjectSpace.count_objects
    response = @app.call(env)
    after_stats = ObjectSpace.count_objects
    if before_stats[:TOTAL] < after_stats[:TOTAL]
      puts "Total objects in memory bumped by #{after_stats[:TOTAL] - before_stats[:TOTAL]} objects."
    end

    if before_stats[:FREE] > after_stats[:FREE]
      puts "\033[0;32m[GC Stats]\033[1;33m #{before_stats[:FREE] - after_stats[:FREE]} new allocated objects.\033[0m"
      @@req_since_gc_cycle += 1
    else
      report = GC::Profiler.result
      GC::Profiler.clear
      if report != ''
        puts red("\n GC run, previous cycle was #{@@req_since_gc_cycle} requests ago.\n")
        puts report
        total_freed   = after_stats[:FREE] - before_stats[:FREE]
        freed_strings = before_stats[:T_STRING] - after_stats[:T_STRING]
        freed_arrays  = before_stats[:T_ARRAY] - after_stats[:T_ARRAY]
        freed_nums    = before_stats[:T_BIGNUM] - after_stats[:T_BIGNUM]
        freed_hashes  = before_stats[:T_HASH] - after_stats[:T_HASH]
        freed_objects = before_stats[:T_OBJECT] - after_stats[:T_OBJECT]
        freed_nodes   = before_stats[:T_NODE] - after_stats[:T_NODE]

        freed_strings_percent = ((freed_strings * 100) / total_freed)
        freed_arrays_percent = ((freed_arrays * 100) / total_freed)
        freed_nums_percent = ((freed_nums * 100) / total_freed)
        freed_hashes_percent = ((freed_hashes * 100) / total_freed)
        freed_objects_percent = ((freed_objects * 100) / total_freed)
        freed_nodes_percent = ((freed_nodes * 100) / total_freed)

        puts red("\n## #{total_freed} freed objects. ##")
        puts red("[#{freed_strings_percent}%] #{freed_strings} freed strings.")
        puts red("[#{freed_arrays_percent}%] #{freed_arrays} freed arrays.")
        puts red("[#{freed_nums_percent}%] #{freed_nums} freed bignums.")
        puts red("[#{freed_hashes_percent}%] #{freed_hashes} freed hashes.")
        puts red("[#{freed_objects_percent}%] #{freed_objects} freed objects.")
        puts red("[#{freed_nodes_percent}%] #{freed_nodes} freed parser nodes (eval usage).")

        # puts "before objects: #{before_stats.inspect}"
        # puts "after objects: #{after_stats.inspect}"
        puts "\n------\n"
        @@req_since_gc_cycle = 0
      end
    end

    response
  end

  def red(text)
    "\033[0;31m#{text}\033[0m"
  end

end