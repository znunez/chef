#--
# Author:: Lamont Granquist (<lamont@getchef.com>)
# Copyright:: Copyright (c) 2014 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/client'
require 'net/http/persistent'
require 'singleton'
require 'forwardable'

class Chef
  class HTTP
    class ClientCache
      include Singleton
      extend Forwardable

      attr_accessor :config
      attr_accessor :logger
      attr_accessor :caches

      Chef::Client.when_run_starts do |run_status|
        logger.debug "Resetting persistent HTTP connections at start of client run"
        instance.reset!
      end

      Chef::Client.when_run_completes_successfully do |run_status|
        logger.debug "Tearing down persistent HTTP connections in successful run callback"
        instance.shutdown
      end

      Chef::Client.when_run_fails do |run_status|
        logger.debug "Tearing down persistent HTTP connections in failed run callback"
        instance.shutdown
      end

      def initialize
        reset!
      end

      # Changing the SSL policy on a Net::HTTP::Persistent object invalidates all of the
      # connections, so we create a cache of them based on SSL policy
      def for_ssl_policy(ssl_policy, opts = {})
        opts ||= {}
        config = opts[:config] if opts[:config]
        logger = opts[:logger] if opts[:logger]
        caches[ssl_policy.hash] ||=
          begin
            logger.debug "Creating new Net::HTTP::Persistent object for #{ssl_policy}"
            cache = new_cache
            ssl_policy.apply_to(cache, config: config) if ssl_policy
            cache
          end
      end

      def config
        @config ||= Chef::Config
      end

      def logger
        @logger ||= Chef::Log
      end

      def shutdown
        caches.each_value do |cache|
          cache.shutdown
        end
        reset!
      end

      def reset!
        @caches = {}
      end

      private

      def new_cache
        cache = Net::HTTP::Persistent.new
        cache.read_timeout = config[:rest_timeout]
        cache.open_timeout = config[:rest_timeout]
        cache.max_requests = nil
        cache.idle_timeout = 300
        cache
      end
    end
  end
end
