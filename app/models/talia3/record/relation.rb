# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

##
# @todo Documentation here or in Record?
class Talia3::Record::Relation < ActiveRecord::Relation
  #**
  # @todo Redo to implement caching
  def loaded?
    false
  end

  def initialize(klass, table=nil)
    super klass, nil
  end

  # TODO: do our own #sanitize_sql here.
  def build_where(opts, other=[])
    [opts] + other
  end

  def find_by_id(id)
    klass.for(id)
  end

  def to_a
    # puts "====="
    # puts "TO_A!"
    # puts "====="
    return @records if loaded?

    # puts

    # puts "SELECT VALUES"
    # puts @select_values.inspect
    # puts "--------------------"
    # puts "WHERE VALUES"
    # puts @where_values.inspect
    # puts "--------------------"
    # puts "ORDER VALUES"
    # puts @order_values.inspect
    # puts "--------------------"
    # puts "LIMIT VALUE"
    # puts @limit_value.inspect
    # puts "--------------------"
    # puts "OFFSET VALUE"
    # puts @offset_value.inspect
    # puts "--------------------"
    # puts "FROM VALUES"
    # puts @from_values.inspect
    # puts "--------------------"
    # puts "JOIN VALUES"
    # puts @joins_values.inspect
    # puts "--------------------"
    # puts "GROUP VALUES"
    # puts @group_values.inspect
    # puts "--------------------"
    # puts "HAVING VALUES"
    # puts @having_values.inspect
    # puts "--------------------"
    # puts "LOCK VALUES"
    # puts @lock_values.inspect
    # puts "--------------------"

    # puts

    @records = []
    klass.repository.query(build_query).each do |solution|
      @records << klass.for(solution.uri)
    end
    @loaded = true
    @records
  end

  def calculate(operation, column_name, options = {})
    # puts "========="
    # puts "calculate"
    # puts "========="

    # puts

    # puts "--------------------"
    # puts "operation"
    # puts operation.inspect
    # puts "--------------------"
    # puts "--------------------"
    # puts "column_name"
    # puts column_name.inspect
    # puts "--------------------"
    # puts "--------------------"
    # puts "options"
    # puts options.inspect
    # puts "--------------------"

    # puts

    case operation
      when :count
        if column_name.nil?
          to_a.size
        else
          clone.where(column_name.to_sym).to_a.size
        end
      else
        raise NotImplementedError, "Operation not supported"
      end
  end

  def build_query
    klass.repository.supports?(:sparql) ? to_sparql : to_patterns
  end

  # @todo prototype implementation, very limited and simplicistic.
  def to_sparql
    from_string  = "FROM <#{klass.context}>" if klass.context
    where_conditions = []
    @where_values.each do |where|
      case where
        when Symbol
          where_conditions << "?uri <#{Talia3::URI.from_key(where)}> ?#{where}"
        when Hash
        where.each_pair do |key, value|
          value = value.is_a?(RDF::URI) ? "<#{value}>" :"'#{value}'"
          where_conditions << "?uri <#{Talia3::URI.from_key(key)}> #{value}"
        end
      end
    end

    order_conditions = []
    @order_values.each do |order|
      case order
      when Symbol
        order_conditions << "?#{order}"
        where_conditions << "OPTIONAL {?uri <#{Talia3::URI.from_key(order)}> ?#{order}}"
      when Hash
        order.each_pair do |key, value|
          if ['asc', 'desc'].include? value.to_s.downcase
            order_conditions << "#{value.to_s.downcase}(?#{key})"
            where_conditions << "OPTIONAL {?uri <#{Talia3::URI.from_key(key)}> ?#{key}}"
          else
            order_conditions << "?#{key}"
            where_conditions << "OPTIONAL {?uri <#{Talia3::URI.from_key(key)}> ?#{key}}"
          end
        end
      end
    end
    order_conditions = order_conditions.any? ? "ORDER BY #{order_conditions.join(' ')}" : ''

    limit_condition = "LIMIT #{@limit_value.to_i}" if @limit_value.to_i > 0
    offset_condition = "OFFSET #{@offset_value.to_i}" if @offset_value.to_i > 0

    "SELECT DISTINCT ?uri #{from_string} WHERE {#{where_conditions.join('.')}} #{order_conditions} #{limit_condition} #{offset_condition}"
  end

  def to_patterns
    raise NotImplementedError, "Querying non-SPARQL repositories is not supported"
  end

end # module Talia3::Record::Relation
