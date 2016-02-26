# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright (c) 2013,2016 Oracle and/or its affiliates. All rights reserved.
#

Puppet::Type.type(:pkg_facet).provide(:pkg_facet) do
    desc "Provider for Oracle Solaris facets"
    confine :operatingsystem => [:solaris]
    defaultfor :osfamily => :solaris, :kernelrelease => ['5.11', '5.12']
    commands :pkg => '/usr/bin/pkg'

    # Defined classvar once. Access must be via Klass.send to prevent
    # undefined method `class_variable_get' errors
    Puppet::Type::Pkg_facet::ProviderPkg_facet.send(:class_variable_set, :@@classvars, {:changes => []})

    def self.instances
        pkg(:facet, "-H", "-F", "tsv").split("\n").collect do |line|
            name, value = line.split
            new(:name => name,
                :ensure => :present,
                :value => value.downcase)
        end
    end

    def self.prefetch(resources)
        # pull the instances on the system
        facets = instances

        # set the provider for the resource to set the property_hash
        resources.keys.each do |name|
            if provider = facets.find{ |facet| facet.name == name}
                resources[name].provider = provider
            end
        end
    end

    def value
        @property_hash[:value]
    end

    def exists?
        # only compare against @resource if one is provided via manifests
        if @property_hash[:ensure] == :present and @resource[:value] != nil
            # retrieve the string representation of @resource[:value] since it
            # gets translated to an object by Puppet
            return (@property_hash[:ensure] == :present and \
                    @property_hash[:value].downcase == \
                        @resource[:value].downcase)
        end
        @property_hash[:ensure] == :present
    end

    def defer(arg)
      Puppet.debug "Defering facet: #{arg}"
      cv = Puppet::Type::Pkg_facet::ProviderPkg_facet.send(:class_variable_get, :@@classvars)
      cv[:changes].push arg
      Puppet::Type::Pkg_facet::ProviderPkg_facet.send(:class_variable_set, :@@classvars, cv)
    end

    def self.post_resource_eval
        # Apply any stashed changes and remove the class variable
        cv = Puppet::Type::Pkg_facet::ProviderPkg_facet.send(:class_variable_get, :@@classvars)
        # If changes have been stashed apply them
        if cv[:changes].length > 0
          Puppet.debug("Applying %s defered facet changes" % cv[:changes].length)
          pkg("change-facet", cv[:changes])
        end

        # Cleanup our tracking class variable
        Puppet::Type::Pkg_facet::ProviderPkg_facet.send(:remove_class_variable, :@@classvars)
    end

    # required puppet functions
    def create
        defer "#{@resource[:name]}=#{@resource[:value]}"
    end

    def destroy
        defer "#{@resource[:name]}=None"
    end
end
