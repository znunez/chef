#
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
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

require 'spec_helper'
require 'tmpdir'

shared_examples_for Chef::Provider::File do
  # Mocksplosion

  let(:node) { double('Chef::Node') }
  let(:events) { double('Chef::Events').as_null_object }  # mock all the methods
  let(:run_context) { double('Chef::RunContext', :node => node, :events => events) }
  let(:enclosing_directory) { File.expand_path(File.join(CHEF_SPEC_DATA, "templates")) }
  let(:resource_path) { File.expand_path(File.join(enclosing_directory, "seattle.txt")) }

  # Subject

  let(:provider) do
    provider = described_class.new(resource, run_context)
    provider.stub!(:content).and_return(content)
    provider
  end

  # Filesystem stubs

  def setup_normal_file
    File.stub!(:exists?).with(resource_path).and_return(true)
    File.stub!(:directory?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(enclosing_directory).and_return(true)
    File.stub!(:writable?).with(resource_path).and_return(true)
    File.stub!(:symlink?).with(resource_path).and_return(false)
  end

  def setup_missing_file
    File.stub!(:exists?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(enclosing_directory).and_return(true)
    File.stub!(:writable?).with(resource_path).and_return(false)
    File.stub!(:symlink?).with(resource_path).and_return(false)
  end

  def setup_symlink
    File.stub!(:exists?).with(resource_path).and_return(true)
    File.stub!(:directory?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(enclosing_directory).and_return(true)
    File.stub!(:writable?).with(resource_path).and_return(true)
    File.stub!(:symlink?).with(resource_path).and_return(true)
  end

  def setup_unwritable_file
    File.stub!(:exists?).with(resource_path).and_return(true)
    File.stub!(:directory?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(enclosing_directory).and_return(true)
    File.stub!(:writable?).with(resource_path).and_return(false)
    File.stub!(:symlink?).with(resource_path).and_return(false)
  end

  def setup_missing_enclosing_directory
    File.stub!(:exists?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(resource_path).and_return(false)
    File.stub!(:directory?).with(enclosing_directory).and_return(false)
    File.stub!(:writable?).with(resource_path).and_return(false)
    File.stub!(:symlink?).with(resource_path).and_return(false)
  end

  # Tests

  it "should return a #{described_class}" do
    provider.should be_a_kind_of(described_class)
  end

  it "should store the resource passed to new as new_resource" do
    provider.new_resource.should eql(resource)
  end

  it "should store the node passed to new as node" do
    provider.node.should eql(node)
  end

  context "when loading the current resource" do

    context "when running load_current_resource and the file exists" do
      before do
        setup_normal_file
        provider.load_current_resource
      end

      it "should load a current resource based on the one specified at construction" do
        provider.current_resource.should be_a_kind_of(Chef::Resource::File)
      end

      it "the loaded current_resource name should be the same as the resource name" do
        provider.current_resource.name.should eql(resource.name)
      end

      it "the loaded current_resource path should be the same as the resoure path" do
        provider.current_resource.path.should eql(resource.path)
      end

      it "the loaded current_resource content should be nil" do
        provider.current_resource.content.should eql(nil)
      end
    end

    context "when running load_current_resource and the file does not exist" do
      before do
        setup_missing_file
        provider.load_current_resource
      end

      it "the current_resource should be a Chef::Resource::File" do
        provider.current_resource.should be_a_kind_of(Chef::Resource::File)
      end

      it "the current_resource name should be the same as the resource name" do
        provider.current_resource.name.should eql(resource.name)
      end

      it "the current_resource path should be the same as the resource path" do
        provider.current_resource.path.should eql(resource.path)
      end

      it "the loaded current_resource content should be nil" do
        provider.current_resource.content.should eql(nil)
      end
    end

    context "examining file security metadata on Unix with a file that exists" do
      before do
        # fake that we're on unix even if we're on windows
        Chef::Platform.stub!(:windows?).and_return(false)
        # mock up the filesystem to behave like unix
        setup_normal_file
        stat_struct = mock("::File.stat", :mode => 0600, :uid => 0, :gid => 0, :mtime => 10000)
        File.should_receive(:stat).with(resource.path).at_least(:once).and_return(stat_struct)
        Etc.stub!(:getgrgid).with(0).and_return(mock("Group Ent", :name => "wheel"))
        Etc.stub!(:getpwuid).with(0).and_return(mock("User Ent", :name => "root"))
      end

      context "when the new_resource does not specify any state" do
        before do
          provider.load_current_resource
        end

        it "should load the permissions into the current_resource" do
          provider.current_resource.mode.should == "0600"
          provider.current_resource.owner.should == "root"
          provider.current_resource.group.should == "wheel"
        end

        it "should not set the new_resource permissions" do
          provider.new_resource.group.should be_nil
          provider.new_resource.owner.should be_nil
          provider.new_resource.mode.should be_nil
        end
      end

      context "when the new_resource explicitly specifies resource state as numbers" do
        before do
          resource.owner(1)
          resource.group(1)
          resource.mode(0644)
          provider.load_current_resource
        end

        it "should load the permissions into the current_resource as numbers (BUT DOESN'T, BUG?)" do
          # FIXME: inconsistency, hmmmm....
          provider.current_resource.mode.should == "0600"
          provider.current_resource.owner.should == 0
          provider.current_resource.group.should == 0
        end

        it "should not set the new_resource permissions" do
          provider.new_resource.group.should == 1
          provider.new_resource.owner.should == 1
          provider.new_resource.mode.should == 0644
        end
      end

      context "when the new_resource explicitly specifies resource state as symbols" do
        before do
          resource.owner("macklemore")
          resource.group("seattlehiphop")
          resource.mode("0321")
          provider.load_current_resource
        end

        it "should load the permissions into the current_resource as symbols" do
          provider.current_resource.mode.should == "0600"
          provider.current_resource.owner.should == "root"
          provider.current_resource.group.should == "wheel"
        end

        it "should not set the new_resource permissions" do
          provider.new_resource.group.should == "seattlehiphop"
          provider.new_resource.owner.should == "macklemore"
          provider.new_resource.mode.should == "0321"
        end
      end

    end

    context "examining file security metadata on Unix with a file that does not exist" do
      before do
        # fake that we're on unix even if we're on windows
        Chef::Platform.stub!(:windows?).and_return(false)
        setup_missing_file
      end

      context "when the new_resource does not specify any state" do
        before do
          provider.load_current_resource
        end

        it "the current_resource permissions should be nil" do
          provider.current_resource.mode.should be_nil
          provider.current_resource.owner.should be_nil
          provider.current_resource.group.should be_nil
        end

        it "should not set the new_resource permissions" do
          provider.new_resource.group.should be_nil
          provider.new_resource.owner.should be_nil
          provider.new_resource.mode.should be_nil
        end
      end

      context "when the new_resource explicitly specifies resource state" do
        before do
          resource.owner(63945)
          resource.group(51948)
          resource.mode(0123)
          provider.load_current_resource
        end

        it "the current_resource permissions should be nil" do
          provider.current_resource.mode.should be_nil
          provider.current_resource.owner.should be_nil
          provider.current_resource.group.should be_nil
        end

        it "should not set the new_resource permissions" do
          provider.new_resource.group.should == 51948
          provider.new_resource.owner.should == 63945
          provider.new_resource.mode.should == 0123
        end
      end
    end
  end

  context "when loading the new_resource after the run" do

    before do
      # fake that we're on unix even if we're on windows
      Chef::Platform.stub!(:windows?).and_return(false)
      # mock up the filesystem to behave like unix
      setup_normal_file
      stat_struct = mock("::File.stat", :mode => 0600, :uid => 0, :gid => 0, :mtime => 10000)
      File.stub!(:stat).with(resource.path).and_return(stat_struct)
      Etc.stub!(:getgrgid).with(0).and_return(mock("Group Ent", :name => "wheel"))
      Etc.stub!(:getpwuid).with(0).and_return(mock("User Ent", :name => "root"))
      provider.send(:load_resource_attributes_from_file, resource)
    end

    it "new_resource should record the new permission information" do
      provider.new_resource.group.should == "wheel"
      provider.new_resource.owner.should == "root"
      provider.new_resource.mode.should == "0600"
    end
  end

  context "when reporting security metadata on windows (FIXME: moar tests)" do

    it "records the file owner" do
      pending
    end

    it "records rights for each user in the ACL" do
      pending
    end

    it "records deny_rights for each user in the ACL" do
      pending
    end
  end

  context "define_resource_requirements" do
    context "when the enclosing directory does not exist" do
      before { setup_missing_enclosing_directory }

      [:create, :create_if_missing, :touch].each do |action|
        context "action #{action}" do
          it "raises EnclosingDirectoryDoesNotExist" do
            lambda {provider.run_action(action)}.should raise_error(Chef::Exceptions::EnclosingDirectoryDoesNotExist)
          end

          it "does not raise an exception in why-run mode" do
            Chef::Config[:why_run] = true
            lambda {provider.run_action(action)}.should_not raise_error(Chef::Exceptions::EnclosingDirectoryDoesNotExist)
            Chef::Config[:why_run] = false
          end
        end
      end
    end

    context "when the file exists but is not deletable" do
      before { setup_unwritable_file }

      it "action delete raises InsufficientPermissions" do
        lambda {provider.run_action(:delete)}.should raise_error(Chef::Exceptions::InsufficientPermissions)
      end

      it "action delete also raises InsufficientPermissions in why-run mode" do
        Chef::Config[:why_run] = true
        lambda {provider.run_action(:delete)}.should raise_error(Chef::Exceptions::InsufficientPermissions)
        Chef::Config[:why_run] = false
      end
    end
  end

  context "action create" do
    it "should create the file, update its contents and then set the acls on the file"  do
      setup_missing_file
      provider.should_receive(:do_create_file)
      provider.should_receive(:do_contents_changes)
      provider.should_receive(:do_acl_changes)
      provider.should_receive(:load_resource_attributes_from_file)
      provider.run_action(:create)
    end

    context "do_create_file" do
      context "when the file exists" do
        before { setup_normal_file }
        it "should not create the file" do
          provider.deployment_strategy.should_not_receive(:create).with(resource_path)
          provider.send(:do_create_file)
          provider.send(:file_created?).should == false
        end
      end
      context "when the file does not exist" do
        before { setup_missing_file }
        it "should create the file" do
          provider.deployment_strategy.should_receive(:create).with(resource_path)
          provider.send(:do_create_file)
          provider.send(:file_created?).should == true
        end
      end
    end

    context "do_contents_changes" do
      context "when there is content to deploy" do
        before do
          tempfile = double('Tempfile', :path => "/tmp/foo-bar-baz")
          content.stub!(:tempfile).and_return(tempfile)
          File.should_receive(:exists?).with("/tmp/foo-bar-baz").and_return(true)
          tempfile.should_receive(:unlink).once
        end

        context "when the contents have changed" do
          let (:tempfile_path) { "/tmp/foo-bar-baz" }
          let (:tempfile_md5) { "71f3811d0472fbef15d90a779615b254" }
          let (:diff_for_reporting) { "+++\n---\n+foo\n-bar\n" }
          before do
            provider.stub!(:contents_changed?).and_return(true)
            diff = double('Diff', :for_output => ['+++','---','+foo','-bar'],
                                  :for_reporting => diff_for_reporting )
            diff.stub!(:diff).with(resource_path, tempfile_path).and_return(true)
            provider.should_receive(:diff).at_least(:once).and_return(diff)
            provider.should_receive(:checksum).with(tempfile_path).and_return(tempfile_md5)
            provider.deployment_strategy.should_receive(:deploy).with(tempfile_path, resource_path)
          end
          context "when the file was created" do
            before { provider.should_receive(:file_created?).at_least(:once).and_return(true) }
            it "does not backup the file and does not produce a diff for reporting" do
              provider.should_not_receive(:backup)
              provider.send(:do_contents_changes)
              resource.diff.should be_nil
            end
          end
          context "when the file was not created" do
            before { provider.should_receive(:file_created?).at_least(:once).and_return(false) }
            it "backs up the file and produces a diff for reporting" do
              provider.should_receive(:backup)
              provider.send(:do_contents_changes)
              resource.diff.should == diff_for_reporting
            end
          end
        end

        it "does nothing when the contents have not changed"  do
          provider.stub!(:contents_changed?).and_return(false)
          provider.should_not_receive(:diff)
          provider.send(:do_contents_changes)
        end
      end

      it "does nothing when there is no content to deploy (tempfile returned from contents is nil)" do
        provider.send(:content).should_receive(:tempfile).at_least(:once).and_return(nil)
        provider.should_not_receive(:diff)
        lambda{ provider.send(:do_contents_changes) }.should_not raise_error
      end

      it "raises an exception when the content object returns a tempfile with a nil path" do
        tempfile = double('Tempfile', :path => nil)
        provider.send(:content).should_receive(:tempfile).at_least(:once).and_return(tempfile)
        lambda{ provider.send(:do_contents_changes) }.should raise_error
      end

      it "raises an exception when the content object returns a tempfile that does not exist" do
        tempfile = double('Tempfile', :path => "/tmp/foo-bar-baz")
        provider.send(:content).should_receive(:tempfile).at_least(:once).and_return(tempfile)
        File.should_receive(:exists?).with("/tmp/foo-bar-baz").and_return(false)
        lambda{ provider.send(:do_contents_changes) }.should raise_error
      end
    end

    context "do_acl_changes" do
      it "needs tests" do
        pending
      end
    end

    #    it "should compare the current content with the requested content" do
    #      @provider.load_current_resource
    #
    #      @provider.new_resource.content "foobar"
    #      @provider.compare_content.should eql(false)
    #
    #      @provider.new_resource.content IO.read(@resource.path)
    #      @provider.compare_content.should eql(true)
    #    end
    #
    #    it "should set the content of the file to the requested content" do
    #      io = StringIO.new
    #      @provider.load_current_resource
    #      @provider.new_resource.content "foobar"
    #      @provider.should_receive(:diff_current_from_content).and_return("")
    #      @provider.should_receive(:backup)
    #      # checksum check
    #      File.should_receive(:open).with(@provider.new_resource.path, "rb").and_yield(io)
    #      File.should_receive(:open).with(@provider.new_resource.path, "w").and_yield(io)
    #      @provider.set_content
    #      io.string.should == "foobar"
    #    end
    #
    #    it "should not set the content of the file if it already matches the requested content" do
    #      @provider.load_current_resource
    #      @provider.new_resource.content IO.read(@resource.path)
    #      # Checksum check:
    #      File.should_receive(:open).with(@resource.path, "rb").and_yield(StringIO.new(@resource.content))
    #      File.should_not_receive(:open).with(@provider.new_resource.path, "w")
    #      lambda { @provider.set_content }.should_not raise_error
    #      @resource.should_not be_updated_by_last_action
    #    end
    #
    #    it "should create the file if it is missing, then set the attributes on action_create" do
    #      @provider.load_current_resource
    #      @provider.stub!(:update_new_file_state)
    #      @provider.new_resource.stub!(:path).and_return(File.join(Dir.tmpdir, "monkeyfoo"))
    #      @provider.access_controls.should_receive(:set_all)
    #      @provider.should_receive(:diff_current_from_content).and_return("")
    #      File.stub!(:open).and_return(1)
    #      #File.should_receive(:directory?).with("/tmp").and_return(true)
    #      File.should_receive(:open).with(@provider.new_resource.path, "w+")
    #      @provider.run_action(:create)
    #      @resource.should be_updated_by_last_action
    #    end
    #
    #    it "should create the file with the proper content if it is missing, then set attributes on action_create" do
    #      io = StringIO.new
    #      @provider.load_current_resource
    #      @provider.new_resource.content "foobar"
    #      @provider.new_resource.stub!(:path).and_return(File.join(Dir.tmpdir, "monkeyfoo"))
    #      @provider.should_receive(:diff_current_from_content).and_return("")
    #      @provider.stub!(:update_new_file_state)
    #      File.should_receive(:open).with(@provider.new_resource.path, "w+").and_yield(io)
    #      @provider.access_controls.should_receive(:set_all)
    #      @provider.run_action(:create)
    #      io.string.should == "foobar"
    #      @resource.should be_updated_by_last_action
    #    end
  end

  context "action delete" do
    context "when the file exists" do
      context "when the file is writable" do
        context "when the file is not a symlink" do
          before { setup_normal_file }
          it "should backup and delete the file and be updated by the last action" do
            provider.should_receive(:backup).at_least(:once).and_return(true)
            File.should_receive(:delete).with(resource_path).and_return(true)
            provider.run_action(:delete)
            resource.should be_updated_by_last_action
          end
        end
        context "when the file is a symlink" do
          before { setup_symlink }
          it "should not backup the symlink" do
            provider.should_not_receive(:backup)
            File.should_receive(:delete).with(resource_path).and_return(true)
            provider.run_action(:delete)
            resource.should be_updated_by_last_action
          end
        end
      end
      context "when the file is not writable" do
        before { setup_unwritable_file }
        it "should not try to backup or delete the file, and should not be updated by last action" do
          provider.should_not_receive(:backup)
          File.should_not_receive(:delete)
          lambda { provider.run_action(:delete) }.should raise_error()
          resource.should_not be_updated_by_last_action
        end
      end
    end

    context "when the file does not exist" do
      before { setup_missing_file }

      it "should not try to backup or delete the file, and should not be updated by last action" do
        provider.should_not_receive(:backup)
        File.should_not_receive(:delete)
        lambda { provider.run_action(:delete) }.should_not raise_error()
        resource.should_not be_updated_by_last_action
      end
    end
  end

  context "action touch" do
    context "when the file does not exist" do
      before { setup_missing_file }
      it "should update the atime/mtime on action_touch" do
        File.should_receive(:utime).once
        provider.should_receive(:action_create)
        provider.run_action(:touch)
        resource.should be_updated_by_last_action
      end
    end
    context "when the file exists" do
      before { setup_normal_file }
      it "should update the atime/mtime on action_touch" do
        File.should_receive(:utime).once
        provider.should_receive(:action_create)
        provider.run_action(:touch)
        resource.should be_updated_by_last_action
      end
    end
  end

  context "action create_if_missing" do
    context "when the file does not exist" do
      before { setup_missing_file }
      it "should call action_create" do
        provider.should_receive(:action_create)
        provider.run_action(:create_if_missing)
      end
    end

    context "when the file exists" do
      before { setup_normal_file }
      it "should not call action_create" do
        provider.should_not_receive(:action_create)
        provider.run_action(:create_if_missing)
      end
    end

  end

end
