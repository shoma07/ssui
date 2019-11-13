# frozen_string_literal: true

module Ssui
  # Ssui::Store
  class Store
    attr_accessor :path, :data, :spaces, :sorts

    def initialize(path)
      @path = path
      @data = @path ? CSV.read(@path) : []
      @spaces = @data.each_with_object([]) do |row, result|
        row.each_with_index do |col, index|
          size = col.nil? ? 0 : col.chars.map { |c| c.bytesize == 1 ? 1 : 2 }.sum
          result[index] = size if result[index].nil? || result[index] < size
        end
      end
    end

    def sort(col, _order = :asc)
      @data = @data.sort_by { |row| row[col] }
    end
  end
end
