class ApplicationRecord < ActiveRecord::Base
  include CableReady::Updatable
  primary_abstract_class
end
