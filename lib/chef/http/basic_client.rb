#--
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Thom May (<thom@clearairturbulence.org>)
# Author:: Nuo Yan (<nuo@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Copyright:: Copyright (c) 2009, 2010 Opscode, Inc.
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
require 'uri'
require 'chef/http/ssl_policies'
require 'chef/http/http_request'
require 'chef/http/client_cache'

class Chef
  class HTTP
    class BasicClient

      HTTPS = "https".freeze

      attr_reader :url
      attr_reader :http_client
      attr_reader :ssl_policy
      attr_reader :http_client_cache

      # Instantiate a BasicClient.
      # === Arguments:
      # url:: An URI for the remote server.
      # === Options:
      # ssl_policy:: The SSL Policy to use, defaults to DefaultSSLPolicy
      def initialize(url, opts={})
        @url = url
        @ssl_policy = opts[:ssl_policy] || DefaultSSLPolicy
        @client_cache_instance = opts[:http_client_cache]
      end

      def request(method, url, req_body, base_headers={})
        configure_http_client!
        http_request = HTTPRequest.new(method, url, req_body, base_headers).http_request
        Chef::Log.debug("Initiating #{method} to #{url}")
        Chef::Log.debug("---- HTTP Request Header Data: ----")
        base_headers.each do |name, value|
          Chef::Log.debug("#{name}: #{value}")
        end
        Chef::Log.debug("---- End HTTP Request Header Data ----")
        http_client_cache.request(url, http_request) do |response|
          Chef::Log.debug("---- HTTP Status and Header Data: ----")
          Chef::Log.debug("HTTP #{response.http_version} #{response.code} #{response.msg}")

          response.each do |header, value|
            Chef::Log.debug("#{header}: #{value}")
          end
          Chef::Log.debug("---- End HTTP Status/Header Data ----")

          # For non-400's, log the request and response bodies
          if !response.code || !response.code.start_with?('2')
            if response.body
              Chef::Log.debug("---- HTTP Response Body ----")
              Chef::Log.debug(response.body)
              Chef::Log.debug("---- End HTTP Response Body -----")
            end
            if req_body
              Chef::Log.debug("---- HTTP Request Body ----")
              Chef::Log.debug(req_body)
              Chef::Log.debug("---- End HTTP Request Body ----")
            end
          end

          yield response if block_given?
          # http_client.request may not have the return signature we want, so
          # force the issue:
          return [http_request, response]
        end
      rescue OpenSSL::SSL::SSLError => e
        Chef::Log.error("SSL Validation failure connecting to host: #{host} - #{e.message}")
        raise
      end

      private

      def configure_http_client!
#        proxy_uri = compute_proxy_uri
#        if proxy_uri
#          proxy = URI proxy_uri
#          Chef::Log.debug("Using #{proxy.host}:#{proxy.port} for proxy")
#          proxy.user = config["#{url.scheme}_proxy_user"]
#          proxy.pass = config["#{url.scheme}_proxy_pass"]
#          # XXX: read from global config, should not be mutated per-request
#          http_client_cache.proxy = proxy
#        end
#        if scheme == HTTPS
#          ssl_policy.apply_to(http_client_cache)
#        end
      end

      def host
        url.hostname
      end

      def port
        url.port
      end

      def scheme
        url.scheme
      end

#      #adapted from buildr/lib/buildr/core/transports.rb
#      # FIXME: use net-http-persistent's #no_proxy setting and move this to per-object initialization
#      #        possibly with a wrapper class
#      def compute_proxy_uri
#        proxy = config["#{scheme}_proxy"]
#        # Check if the proxy string contains a scheme. If not, add the url's scheme to the
#        # proxy before parsing. The regex /^.*:\/\// matches, for example, http://.
#        proxy = if proxy.match(/^.*:\/\//)
#          URI.parse(proxy)
#        else
#          URI.parse("#{scheme}://#{proxy}")
#        end if String === proxy
#        excludes = config[:no_proxy].to_s.split(/\s*,\s*/).compact
#        excludes = excludes.map { |exclude| exclude =~ /:\d+$/ ? exclude : "#{exclude}:*" }
#        return proxy unless excludes.any? { |exclude| File.fnmatch(exclude, "#{host}:#{port}") }
#      end

#      def config
#        Chef::Config
#      end

      def http_client_cache
        if scheme == HTTPS
          client_cache_instance.for_ssl_policy(ssl_policy)
        else
          client_cache_instance.for_ssl_policy(nil)
        end
      end

      def client_cache_instance
        @client_cache_instance ||= Chef::HTTP::ClientCache.instance
      end
    end
  end
end
