
module Circos

  def self.parse_conf_values(string)
    info = {}
    string.split("\n").each do |line|
      next if line =~ /^\s*#/
      next unless line =~ /=/
      key, value = line.match(/(.*?)=(.*)/).values_at 1, 2
      key.strip!
      value.strip!
      info[key] = value
    end
    info
  end

  def self.parse_conf_chunk(string)
    info = []
    start, match, eend = string.partition(/<<([^>]+)>>/sm)

    info << parse_conf_values(start) unless start.empty?
    info << {:include => match} unless match.empty?
    info.concat parse_conf_chunk(eend) unless eend.empty?

    info.delete_if{|v| v.empty?}

    info
  end

  def self.parse_conf(string)
    info = []
    start, match, eend = string.partition(/<([^>]+)>(.*?)<\/\1>/sm)
    match_name = $1
    match_content = $2

    info.concat parse_conf_chunk(start) unless start.empty?
    info << {match_name => parse_conf(match_content)} unless match_content.nil? or match_content.empty?
    info.concat parse_conf(eend) unless eend.empty?

    info
  end

  def self.print_chunk(chunk)
    case
    when chunk.keys == [:include]
      chunk.values.first
    when (chunk.values.length == 1 and String === chunk.values.first)
      [chunk.keys.first, chunk.values.first] * " = "
    when (chunk.values.length == 1 and Array === chunk.values.first)
      key = chunk.keys.first
      "\n<#{key}>\n" +
        print_conf(chunk.values.first) +
        "</#{key}>\n"
    else
      chunk.collect do |key, value|
        [key, value] * " = "
      end * "\n"
    end
  end

  def self.print_conf(conf)
    conf.inject(""){|text,chunk|
      text << print_chunk(chunk) << "\n"
      text
    }
  end

  def self.header
    text = Rbbt.share.circos.partials['header.conf'].read
    parse_conf(text)
  end

  def self.image(filename)
    text = Rbbt.share.circos.partials['image.conf'].read
    conf = parse_conf(text)
    conf.first["dir"] = File.dirname(filename)
    conf.first["file"] = File.basename(filename)
    [{:image => conf}]
  end

  def self.rules(min, max, steps = 9, prefix = "ylorrd")
    text = Rbbt.share.circos.partials['rule.conf'].read
    conf = parse_conf(text).first

    step_size = (max - min).to_f / 9

    rules = []
    steps.times do |step|
      rule_conf = conf.dup
      threshold = step_size * (step)
      color = [prefix, steps, 'seq', step+1] * "-"
      rule_conf['fill_color'] = color
      rule_conf['condition'] = "_VALUE_ >= #{threshold}"
      rule_conf['importance'] = step
      rules << {:rule => [rule_conf]}
    end

    [{:rules => rules}]
  end

  def self.plot(filename, options = {})
    text = Rbbt.share.circos.partials['plot.conf'].read
    conf = parse_conf(text)
    values = Open.read(filename).split("\n").collect{|l| l.split("\t").last.to_f}
    
    params = conf.first
    params["file"] = filename
    params.merge! options

    #params["min"] ||= values.min
    #params["max"] ||= values.max
    #conf.concat rules(min, max)
    {:plot => conf}
  end


end
