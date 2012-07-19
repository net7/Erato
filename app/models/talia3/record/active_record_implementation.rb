# Copyright (c) 2010 Net7 SRL, <http://www.netseven.it/>
# This Software is released under the terms of the MIT License
# See LICENSE.TXT for the full text of the license.

##
#
module Talia3::Record::ActiveRecordImplementation
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # These are all the original ActiveRecord delegations.
    # delegate :find, :first, :last, :all, :destroy, :destroy_all, :exists?, :delete, :delete_all, :update, :update_all, :to => :scoped
    # delegate :find_each, :find_in_batches, :to => :scoped
    # delegate :select, :group, :order, :reorder, :except, :limit, :offset, :joins, :where, :preload, :eager_load, :includes, :from, :lock, :readonly, :having, :create_with, :to => :scoped
    # delegate :count, :average, :minimum, :maximum, :sum, :calculate, :to => :scoped

    delegate :columns, :table_exists?, :reflect_on_all_associations, :to => :schema

    delegate :find_by_id, :to => :relation
    delegate :find, :first, :last, :all, :exists?, :to => :relation
    delegate :select, :group, :order, :reorder, :except, :limit, :offset, :joins, :where, :from, :having, :to => :relation
    delegate :count, :to => :relation

    def relation
      @relation ||= Talia3::Record::Relation.new(self).where(:rdf__type => type).clone
    end

    # @todo this should be one of the custom find_by_x methods that use method_missing.
    def find_all_by_id(ids)
      ids.map do |uri|
        self.for(uri)
      end
    end

    # @todo separate situation when conditions contain :id and 
    #   then reinject in relation if possible.
    def destroy_all(conditions=nil)
      raise NotImplementedError, "#destroy_all is a TODO"
    end

    # @todo implement? What does it do exactly? Is it an activemodel thing?
    def serialized_attributes
      {}
    end
  end # module ClassMethods

  # @todo guard_protected_attributes is ignored for now, 
  #   see if it could be usedm, and how.
  def attributes=(attributes, guard_protected_attributes = false)
    fill_from_params attributes
  end
end # module Talia3::Record::ActiveRecordImplementation
