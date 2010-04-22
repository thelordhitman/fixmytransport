# An alternative way of disabling foreign keys in fixture loading in Postgres and
# does not require superuser permissions
# http://kopongo.com/2008/7/25/postgres-ri_constrainttrigger-error
# Additionally, require the spatial adapter plugin to make sure
# it doesn't clobber our change
require 'vendor/plugins/spatial_adapter/init.rb'
module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      def disable_referential_integrity(&block)
         transaction {
           begin
             execute "SET CONSTRAINTS ALL DEFERRED"
             yield
           ensure
             execute "SET CONSTRAINTS ALL IMMEDIATE"
           end
         }
      end
    end
  end
end