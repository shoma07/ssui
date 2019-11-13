# frozen_string_literal: true

module Ssui
  # Ssui::App
  class App
    attr_accessor :hight, :width, :store, :cursor

    # @param [String] path
    # @return [Ssui::App]
    def initialize(path)
      @store = Store.new(path)
      @cursor = [0, 0]
      console_size = IO.console_size
      @hight = (console_size[0] / 2) - 1
      @width = console_size[1] - @store.data.size.to_s.size - 3
    end

    def watch
      loop do
        Signal.trap(:WINCH, &render)
      end
    end

    # @return [NilClass]
    def render
      puts (@hight + (@colfix.nil? ? 0 : (@colfix.to_i + 1))).times.each_with_object([color(render_header)]) { |i, rows|
        rows << render_line
        rows << if @colfix.nil? || (!@colfix.nil? && @colfix < i)
                  render_row(i + @cursor[0] - (@colfix.nil? ? 0 : @colfix))
                else
                  render_row(i + @colfix)
                end
      }.flatten.join("\n")
    end

    # @return [String]
    def render_header
      h = nil
      row = @store.spaces.map { |space| (h = h&.succ || 'A').ljust(space) }
      [
        (' ' * @store.data.size.to_s.size),
        row.join(' | ')[@cursor[1]..(@cursor[1] + @width - 1)]
      ].join(' | ')
    end

    # @return [String]
    def color(str)
      "\e[30;47;1m%s\e[m" % str
    end

    # @return [String]
    def render_line
      row = @store.spaces.map { |space| '-' * space }
      [
        color('-' * @store.data.size.to_s.size),
        row.join('- -')[@cursor[1]..(@cursor[1] + @width - 1)]
      ].join('- -')
    end

    # @return [String]
    def render_row(index)
      row = if @store.data[index]
              @store.data[index].map.with_index do |col, i|
                (col || '').ljust(@store.spaces[i])
              end
            else
              @store.spaces.map.with_index { |space, _i| ' ' * space }
            end
      [
        color((index + 1).to_s.ljust(@store.data.size.to_s.size)),
        row.join(' | ')[@cursor[1]..(@cursor[1] + @width - 1)]
      ].join(' | ')
    end

    # @return [NilClass]
    def colfix(col_index = 0)
      return if @store.data.size < col_index.to_i - 1 && col_index.to_i - 1 <= 0

      @colfix = col_index.to_i - 1
      @hight = ((IO.console_size[0] / 2) - 1) - (@colfix + 1)
    end

    # @return [NilClass]
    def colfix_clear
      return if @colfix.nil?

      @hight = (IO.console_size[0] / 2) - 1
      @colfix = nil
    end

    # @return [NilClass]
    def rowfix(row_index = 'A')
      header = (@store.spaces.size - 1).times.each_with_object(['A']) do |i, h|
        h[i + 1] = h[i].succ
      end
      index = header.find_index(row_index)
      @rowfix = index
    end

    # @return [NilClass]
    def command(str)
      cmd_argv = str.split(' ')
      case cmd_argv[0]
      when 'colfix'
        if cmd_argv[1] == 'clear'
          colfix_clear
        else
          colfix(cmd_argv[1].to_i)
        end
      end
    end

    def run
      mode = :normal
      print "\e[2J"
      render
      rerender = false
      cmd_list = []
      while (key = STDIN.getch)
        break if key == "\C-c"

        case mode
        when :command
          if ["\n", "\r"].include? key
            mode = :normal
            command(cmd_list.join)
            cmd_list = []
            rerender = true
            print "\n"
          elsif !["\e", '[', 'A', 'B', 'C', 'D'].include?(key)
            print key
            cmd_list << key
          end
        when :normal
          case key
          when ':'
            mode = :command
            print format("\e[%d;%dH", IO.console_size[0], 0)
            print key
          when 'k', "\e[A" # up
            if (@cursor[0]).positive?
              @cursor[0] -= 1
              rerender = true
            end
          when 'j', "\e[B" # down
            if @cursor[0] < @store.data.size - @hight
              @cursor[0] += 1
              rerender = true
            end
          when 'l', "\e[C" # right
            max = @store.spaces.map { |size| '-' * size }.join('- -').size - @width
            if @cursor[1] < max
              @cursor[1] += 1
              rerender = true
            else
              @cursor[1] = max
            end
          when 'h', "\e[D" # left
            if (@cursor[1]).positive?
              @cursor[1] -= 1
              rerender = true
            end
          when "\C-d"
            if @cursor[0] <= @store.data.size - (2 * @hight)
              @cursor[0] += @hight
              rerender = true
            elsif @cursor[0] > @store.data.size - (2 * @hight)
              @cursor[0] = @store.data.size > @hight ? @store.data.size - @hight : 0
              rerender = true
            end
          when "\C-u"
            if @cursor[0] >= 0 + @hight
              @cursor[0] -= @hight
              rerender = true
            elsif @cursor[0] < 0 + @hight
              @cursor[0] = 0
              rerender = true
            end
          when '0'
            @cursor[1] = 0
            rerender = true
          when '$'
            @cursor[1] = @store.spaces.map { |size| '-' * size }.join('- -').size - @width
            rerender = true
          when 'g'
            @cursor[0] = 0
            rerender = true
          when 'G'
            @cursor[0] = @store.data.size > @hight ? @store.data.size - @hight : 0
            rerender = true
          end
        end
        render if rerender
        rerender = false
      end
    end
  end
end
