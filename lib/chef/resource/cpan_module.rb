require "chef/resource"

class Chef
  class Resource
    # @author Joshua Timberman <jtimberman@chef.io>
    # @author Steve Nolen <technolengy@gmail.com>
    # resource to install modules from CPAN
    class CpanModule < Chef::Resource
      resource_name :cpan_module

      property :module_name, String, name_property: true
      property :cpam_bin_path, String, default: "/usr/local/bin/cpanm"
      property :force, [true, false], default: false
      property :test, [true, false], default: false
      property :version, String
      property :cwd, String

      action :install do
        declare_resource(:execute, "CPAN :install #{new_resource.module_name}") do
          cwd current_working_dir
          command cpanm_install_cmd
          environment "HOME" => current_working_dir, "PATH" => "/usr/local/bin:/usr/bin:/bin"
          not_if { module_exists_new_enough }
        end
      end

      action :uninstall do
        declare_resource(:execute, "CPAN :uninstall #{new_resource.module_name}") do
          cwd current_working_dir
          command cpanm_uninstall_cmd
          only_if module_exists
        end
      end

      action_class do
        def module_exists_new_enough
          existing_version = parse_cpan_version
          return false if existing_version.empty? # mod doesn't exist
          return true if new_resource.version.nil? # mod exists and version is unimportant
          @comparator, @pending_version = new_resource.version.split(" ", 2)
          @current_vers = Gem::Version.new(existing_version)
          @pending_vers = Gem::Version.new(@pending_version)
          @current_vers.method(@comparator).call(@pending_vers)
        end

        def parse_cpan_version
          mod_ver_cmd = shell_out("perl -M#{new_resource.module_name} -e 'print $#{new_resource.module_name}::VERSION;' 2> /dev/null")
          mod_ver = mod_ver_cmd.stdout
          return mod_ver if mod_ver.empty?
          # remove leading v and convert underscores to dots since gems parses them wrong
          mod_ver.gsub!(/v_/, "v" => 3, "_" => ".")
          # in the event that this command outputs whatever it feels like, only keep the first vers number!
          version_match = /(^[0-9.]*)/.match(mod_ver)
          version_match[0]
        end

        # builds a string of the  perl command to see if the module exists
        # @return [String]
        def module_exists
          "perl -m#{new_resource.module_name} -e ';' 2> /dev/null"
        end

        def cpanm_install_cmd
          @cmd = "#{new_resource.cpam_bin_path} --quiet "
          @cmd += "--force " if new_resource.force
          @cmd += "--notest " unless new_resource.test
          @cmd += new_resource.module_name
          @cmd += parsed_version
          @cmd
        end

        def cpanm_uninstall_cmd
          @cmd = "#{new_resource.cpam_bin_path} "
          @cmd += "--force " if new_resource.force
          @cmd += "--uninstall "
          @cmd += new_resource.module_name
          @cmd
        end

        # a bit of a stub, could use a version parser for really consistent expeirence
        def parsed_version
          return "~\"#{new_resource.version}\"" if new_resource.version
          ""
        end

        def current_working_dir
          return new_resource.cwd if new_resource.cwd
          return "/var/root" if node["platform"] == "mac_os_x"
          "/root"
        end
      end
    end
  end
end
