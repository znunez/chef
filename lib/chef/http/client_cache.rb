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

require 'net/http/persistent'
require 'singleton'
require 'forwardable'

class Chef
  class HTTP
    class ClientCache
      include Singleton
      extend Forwardable

      attr_accessor :config
      attr_accessor :caches

      def initialize
        @caches = {}
      end

#      def_delegator :@net_http_persistent, :verify_mode=
#      def_delegator :@net_http_persistent, :cert_store
#      def_delegator :@net_http_persistent, :cert_store=
#      def_delegator :@net_http_persistent, :read_timeout=
#      def_delegator :@net_http_persistent, :open_timeout=
#      def_delegator :@net_http_persistent, :request

      def for_ssl_policy(ssl_policy)
        caches[ssl_policy.hash] ||=
          begin
            cache = new_cache
            ssl_policy.apply_to(cache) if ssl_policy
            cache
          end
      end

      def config
        @config ||= Chef::Config
      end

      private

      def new_cache
        cache = Net::HTTP::Persistent.new
        cache.read_timeout = config[:rest_timeout]
        cache.open_timeout = config[:rest_timeout]
        cache
      end
    end
  end
end
