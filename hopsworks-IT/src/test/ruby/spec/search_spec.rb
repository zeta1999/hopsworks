=begin
 This file is part of Hopsworks
 Copyright (C) 2020, Logical Clocks AB. All rights reserved

 Hopsworks is free software: you can redistribute it and/or modify it under the terms of
 the GNU Affero General Public License as published by the Free Software Foundation,
 either version 3 of the License, or (at your option) any later version.

 Hopsworks is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.  See the GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License along with this program.
 If not, see <https://www.gnu.org/licenses/>.
=end
describe "On #{ENV['OS']}" do
  before(:all) do
    @debugOpt = false
  end
  after(:all) do
    clean_all_test_projects
  end

  context "featurestore" do

    def featuregroups_setup(project)
      fgs = Array.new(6)
      featurestore_id = get_featurestore_id(project[:id])

      fgs[0] = {}
      fgs[0][:name] = "fg_animal1"
      fgs[0][:id] = create_cached_featuregroup_checked(project[:id], featurestore_id, fgs[0][:name])
      fgs[1] = {}
      fgs[1][:name] = "fg_dog1"
      fgs[1][:id] = create_cached_featuregroup_checked(project[:id], featurestore_id, fgs[1][:name])
      fgs[2] = {}
      fgs[2][:name] = "fg_othername1"
      fgs[2][:id] = create_cached_featuregroup_checked(project[:id], featurestore_id, fgs[2][:name])
      fgs[3] = {}
      fgs[3][:name] = "fg_othername2"
      features3 = [
          {
              type: "INT",
              name: "dog",
              description: "--",
              primary: true
          }
      ]
      fgs[3][:id] = create_cached_featuregroup_checked(project[:id], featurestore_id, fgs[3][:name], features: features3)
      fgs[4] = {}
      fgs[4][:name] = "fg_othername3"
      features4 = [
          {
              type: "INT",
              name: "cat",
              description: "--",
              primary: true
          }
      ]
      fgs[4][:id] = create_cached_featuregroup_checked(project[:id], featurestore_id, fgs[4][:name], features: features4)
      fgs[5] = {}
      fgs[5][:name] = "fg_othername4"
      fg5_description = "some description about a dog"
      fgs[5][:id] = create_cached_featuregroup_checked(project[:id], featurestore_id, fgs[5][:name], featuregroup_description: fg5_description)
      fgs
    end

    def trainingdataset_setup(project)
      tds = Array.new(4)
      featurestore_id = get_featurestore_id(project[:id])
      connector = get_hopsfs_training_datasets_connector(project[:projectname])
      tds[0] = {}
      tds[0][:name] = "td_animal1"
      tds[0][:id] = create_hopsfs_training_dataset_checked(project[:id], featurestore_id, connector, tds[0][:name])[:id]
      tds[1] = {}
      tds[1][:name] = "td_dog1"
      tds[1][:id] = create_hopsfs_training_dataset_checked(project[:id], featurestore_id, connector, tds[1][:name])[:id]
      tds[2] = {}
      tds[2][:name] = "td_something3"
      td3_features = [
          { name: "dog", featuregroup: "fg", version: 1, type: "INT", description: "testfeaturedescription"},
          { name: "feature2", featuregroup: "fg", version: 1, type: "INT", description: "testfeaturedescription"}
      ]
      tds[2][:id] = create_hopsfs_training_dataset_checked(project[:id], featurestore_id, connector, tds[2][:name], features: td3_features)[:id]
      tds[3] = {}
      tds[3][:name] = "td_something4"
      td3_description = "some description about a dog"
      tds[3][:id] = create_hopsfs_training_dataset_checked(project[:id], featurestore_id, connector, tds[3][:name], description: td3_description)[:id]
      # TODO add featuregroup name to search
      tds
    end

    context "same project" do
      before :all do
        #make sure epipe is free of work
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        with_valid_session
        @project = create_project

        @FEATURE_SIZE_1 = 10
        @FEATURE_SIZE_2 = 208
        @FEATURE_SIZE_3 = 5000
        @FEATURE_SIZE_4 = 20000
        @FEATURE_SIZE_5 = 21400

        @featurestore_id = get_featurestore_id(@project[:id])
        @fg_name_keyword = "cat"
        @fg_name = "#{@fg_name_keyword}#{"t"*(63-@fg_name_keyword.length)}"
        @td_name_keyword = "dog"
        @td_name = "#{@td_name_keyword}#{"t"*(63-@td_name_keyword.length)}"
        @desc_keyword = "bird"
        @description = "#{@desc_keyword}#{"t"*(256-@desc_keyword.length)}"
        @feature_keyword1 = "goose"
        @feature_keyword2 = "duck"
        @connector = get_hopsfs_training_datasets_connector(@project[:projectname])
      end

      def get_fg_features(size, f_prefix1: "", f_prefix2: "")
        padding_size = 5
        #invariants
        expect(size).to be_between(0, 99999).inclusive, "update padding"
        expect(f_prefix1.length).to be_between(0, (63-padding_size)), "prefix1 out of bounds"
        expect(f_prefix2.length).to be_between(0, (63-padding_size)), "prefix2 out of bounds"

        s_padding1 = "t" * (63-padding_size-f_prefix1.length)
        s_padding2 = "t" * (63-padding_size-f_prefix2.length)
        fg_features = Array.new(size) do |i|
          {
            type: "INT",
            name: "#{f_prefix1}#{s_padding1}#{i.to_s.rjust(padding_size, '0')}",
            description: "",
            primary: false
          }
        end
        fg_features[0][:primary] = true
        #last feature with different prefix
        fg_features[size-1]={
            type: "INT",
            name: "#{f_prefix2}#{s_padding2}#{(size-1).to_s.rjust(padding_size, '0')}",
            description: "",
            primary: false
        }
        return fg_features
      end

      def get_td_features(fg_name, fg_features)
        td_features = Array.new(fg_features.size()) do |i|
          { name:  fg_features[i][:name], featuregroup: fg_name, version: 1, type: "INT", description: "" }
        end
        return td_features
      end

      def xattr_num_parts(inode_name)
        result = INode.where(name: inode_name)
        result1 = XAttr.where(inode_id: result[0][:id])
        pp "#{result[0][:id]} : #{result1[0][:num_parts]}"
      end

      def fg_featurstore_xattr_size(fg_size)
        epipe_stop_restart do
          fg_features = get_fg_features(fg_size, f_prefix1: @feature_keyword1, f_prefix2: @feature_keyword2)
          td_features = get_td_features(@fg_name, fg_features)
          create_cached_featuregroup_checked(@project[:id], @featurestore_id, @fg_name, features: fg_features, featuregroup_description: @description)
          create_hopsfs_training_dataset_checked(@project[:id], @featurestore_id, @connector, @td_name, features: td_features, description: @description)
          xattr_num_parts("#{@fg_name}_1")
          xattr_num_parts("#{@td_name}_1")
        end
      end

      def featurestore_search_test(size)
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        begin
          #setup
          fg_features = get_fg_features(size, f_prefix1: @feature_keyword1, f_prefix2: @feature_keyword2)
          fg_id = create_cached_featuregroup_checked(@project[:id], @featurestore_id, @fg_name, features: fg_features, featuregroup_description: @description)
          td_features = get_td_features(@fg_name, fg_features)
          td_result = create_hopsfs_training_dataset_checked(@project[:id], @featurestore_id, @connector, @td_name, features: td_features, description: @description)
          td_id = td_result[:id]
          wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
          expect(wait_result["success"]).to be(true), wait_result["msg"]
          #search
          expected_hits1 = [{:name => @fg_name, :highlight => "name", :parent_project => @project[:projectname]}]
          project_search_test(@project, @fg_name_keyword, "featuregroup", expected_hits1)
          expected_hits2 = [{:name => @fg_name, :highlight => "description", :parent_project => @project[:projectname]}]
          project_search_test(@project, @desc_keyword, "featuregroup", expected_hits2)
          expected_hits3 = [{:name => @fg_name, :highlight => "features", :parent_project => @project[:projectname]}]
          project_search_test(@project, @feature_keyword1, "featuregroup", expected_hits3)
          project_search_test(@project, @feature_keyword2, "featuregroup", expected_hits3)

          expected_hits4 = [{:name => @td_name, :highlight => 'name', :parent_project => @project[:projectname]}]
          project_search_test(@project, @td_name_keyword, "trainingdataset", expected_hits4)
          expected_hits5 = [{:name => @td_name, :highlight => 'description', :parent_project => @project[:projectname]}]
          project_search_test(@project, @desc_keyword, "trainingdataset", expected_hits5)
          expected_hits6 = [{:name => @td_name, :highlight => 'features', :parent_project => @project[:projectname]}]
          project_search_test(@project, @feature_keyword1, "trainingdataset", expected_hits6)
          project_search_test(@project, @feature_keyword2, "trainingdataset", expected_hits6)
        ensure
          delete_featuregroup_checked(@project[:id], @featurestore_id, fg_id) if defined?(fg_id)
          delete_trainingdataset_checked(@project[:id], @featurestore_id, td_id) if defined?(td_id)
        end
      end

      it "create small featuregroup & training dataset - searchable (with features)" do
        featurestore_search_test(@FEATURE_SIZE_1)
      end

      it "create large1 featuregroup & training dataset - searchable (with features)" do
        featurestore_search_test(@FEATURE_SIZE_2)
      end

      it "create large2 featuregroup & training dataset - searchable (with features)" do
        featurestore_search_test(@FEATURE_SIZE_3)
      end

      it "local search featuregroup, training datasets with name, features, xattr" do
        #make sure epipe is free of work
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        begin
          fgs = featuregroups_setup(@project)
          tds = trainingdataset_setup(@project)
          #search
          wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
          expect(wait_result["success"]).to be(true), wait_result["msg"]

          expected_hits1 = [{:name => fgs[1][:name], :highlight => "name", :parent_project => @project[:projectname]},
                            {:name => fgs[3][:name], :highlight => "features", :parent_project => @project[:projectname]},
                            {:name => fgs[5][:name], :highlight => "description", :parent_project => @project[:projectname]}]
          project_search_test(@project, "dog", "featuregroup", expected_hits1)
          expected_hits2 = [{:name => tds[1][:name], :highlight => "name", :parent_project => @project[:projectname]},
                            {:name => tds[2][:name], :highlight => "features", :parent_project => @project[:projectname]},
                            {:name => tds[3][:name], :highlight => "description", :parent_project => @project[:projectname]}]
          project_search_test(@project, "dog", "trainingdataset", expected_hits2)
          expected_hits3 = [{:name => fgs[3][:name], :highlight => "name", :parent_project => @project[:projectname]}]
          project_search_test(@project, "dog", "feature", expected_hits3)
        ensure
          fgs.each do |fg|
            delete_featuregroup_checked(@project[:id], @featurestore_id, fg[:id]) if defined?(fg[:id])
          end
          tds.each do |td|
            delete_trainingdataset_checked(@project[:id], @featurestore_id, td[:id]) if defined?(td[:id])
          end
        end
      end

      it 'featurestore pagination' do
        fgs_nr = 15
        tds_nr = 15
        fgs_id = Array.new(fgs_nr)
        tds_id = Array.new(tds_nr)

        #make sure epipe is free of work
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        begin
          #create 15 featuregroups
          featurestore_id = get_featurestore_id(@project[:id])
          fgs_nr.times do |i|
            fg_name = "fg_dog_#{i}"
            fgs_id[i] = create_cached_featuregroup_checked(@project[:id], featurestore_id, fg_name)
          end

          #create 15 training datasets
          td_name = "#{@project[:projectname]}_Training_Datasets"
          td_dataset = get_dataset(@project, td_name)
          connector = get_hopsfs_training_datasets_connector(@project[:projectname])
          tds_nr.times do |i|
            td_name = "td_dog_#{i}"
            td_result = create_hopsfs_training_dataset_checked(@project[:id], featurestore_id, connector, td_name)
            tds_id[i] = td_result[:id]
          end

          wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
          expect(wait_result["success"]).to be(true), wait_result["msg"]

          #local search
          local_featurestore_search(@project, "FEATUREGROUP", "dog")
          local_featurestore_search(@project, "FEATUREGROUP", "dog", from:0, size:10)
          expect(local_featurestore_search(@project, "FEATUREGROUP", "dog", from:0, size:10)["featuregroups"].length).to eq (10)
          expect(local_featurestore_search(@project, "FEATUREGROUP", "dog", from:10, size:10)["featuregroups"].length).to eq(5)

          expect(local_featurestore_search(@project, "TRAININGDATASET", "dog", from:0, size:10)["trainingdatasets"].length).to eq(10)
          expect(local_featurestore_search(@project, "TRAININGDATASET", "dog", from:10, size:10)["trainingdatasets"].length).to eq(5)
          #global search
          expect(global_featurestore_search("FEATUREGROUP", "dog", from:0, size:10)["featuregroups"].length).to eq(10)
          expect(global_featurestore_search("FEATUREGROUP", "dog", from:10, size:10)["featuregroups"].length).to be >= 5

          expect(global_featurestore_search("TRAININGDATASET", "dog", from:0, size:10)["trainingdatasets"].length).to eq(10)
          expect(global_featurestore_search("TRAININGDATASET", "dog", from:10, size:10)["trainingdatasets"].length).to be >= 5
        ensure
          fgs_id.each do |id|
            delete_featuregroup_checked(@project[:id], @featurestore_id, id) if defined?(id)
          end
          tds_id.each do |id|
            delete_trainingdataset_checked(@project[:id], @featurestore_id, id) if defined?(id)
          end
        end
      end
    end
    context "each with its own project" do
      it "local search featuregroup, training datasets with name, features, xattr with shared training datasets" do
        #make sure epipe is free of work
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        with_valid_session
        project1 = create_project
        project2 = create_project
        #share featurestore (with training dataset)
        featurestore_name = project1[:projectname].downcase + "_featurestore.db"
        featurestore1 = get_dataset(project1, featurestore_name)
        request_access_by_dataset(featurestore1, project2)
        share_dataset_checked(project1, featurestore_name, project2[:projectname], "FEATURESTORE")
        fgs1 = featuregroups_setup(project1)
        fgs2 = featuregroups_setup(project2)
        tds1 = trainingdataset_setup(project1)
        tds2 = trainingdataset_setup(project2)
        #search
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        expected_hits1 = [{:name => fgs1[1][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => fgs1[3][:name], :highlight => 'features', :parent_project => project1[:projectname]},
                          {:name => fgs1[5][:name], :highlight => "description", :parent_project => project1[:projectname]}]
        project_search_test(project1, "dog", "featuregroup", expected_hits1)
        expected_hits2 = [{:name => fgs2[1][:name], :highlight => 'name', :parent_project => project2[:projectname]},
                          {:name => fgs2[3][:name], :highlight => 'features', :parent_project => project2[:projectname]},
                          {:name => fgs2[5][:name], :highlight => "description", :parent_project => project2[:projectname]},
                          #shared featuregroups
                          {:name => fgs1[1][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => fgs1[3][:name], :highlight => 'features', :parent_project => project1[:projectname]},
                          {:name => fgs1[5][:name], :highlight => "description", :parent_project => project1[:projectname]}]
        project_search_test(project2, "dog", "featuregroup", expected_hits2)
        expected_hits3 = [{:name => tds1[1][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => tds1[2][:name], :highlight => 'features', :parent_project => project1[:projectname]},
                          {:name => tds1[3][:name], :highlight => "description", :parent_project => project1[:projectname]}]
        project_search_test(project1, "dog", "trainingdataset", expected_hits3)
        expected_hits4 = [{:name => tds2[1][:name], :highlight => 'name', :parent_project => project2[:projectname]},
                          {:name => tds2[2][:name], :highlight => 'features', :parent_project => project2[:projectname]},
                          {:name => tds2[3][:name], :highlight => "description", :parent_project => project2[:projectname]},
                          # shared trainingdatasets
                          {:name => tds1[1][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => tds1[2][:name], :highlight => 'features', :parent_project => project1[:projectname]},
                          {:name => tds1[3][:name], :highlight => "description", :parent_project => project1[:projectname]}]
        project_search_test(project2, "dog", "trainingdataset", expected_hits4)
        expected_hits5 = [{:name => fgs1[3][:name], :highlight => 'name', :parent_project => project1[:projectname]}]
        project_search_test(project1, "dog", "feature", expected_hits5)
        expected_hits6 = [{:name => fgs2[3][:name], :highlight => 'name', :parent_project => project2[:projectname]},
                          # shared features
                          {:name => fgs1[3][:name], :highlight => 'name', :parent_project => project1[:projectname]}]
        project_search_test(project2, "dog", "feature", expected_hits6)
      end

      it "global search featuregroup, training datasets with name, features, xattr" do
        #make sure epipe is free of work
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        with_valid_session
        project1 = create_project
        project2 = create_project
        fgs1 = featuregroups_setup(project1)
        fgs2 = featuregroups_setup(project2)
        tds1 = trainingdataset_setup(project1)
        tds2 = trainingdataset_setup(project2)

        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        expected_hits1 = [{:name => fgs1[1][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => fgs1[3][:name], :highlight => 'features', :parent_project => project1[:projectname]},
                          {:name => fgs1[5][:name], :highlight => "description", :parent_project => project1[:projectname]},
                          {:name => fgs2[1][:name], :highlight => 'name', :parent_project => project2[:projectname]},
                          {:name => fgs2[3][:name], :highlight => 'features', :parent_project => project2[:projectname]},
                          {:name => fgs2[5][:name], :highlight => "description", :parent_project => project2[:projectname]}]
        global_search_test("dog", "featuregroup", expected_hits1)
        expected_hits2 = [{:name => tds1[1][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => tds1[2][:name], :highlight => 'features', :parent_project => project1[:projectname]},
                          {:name => tds1[3][:name], :highlight => "description", :parent_project => project1[:projectname]},
                          {:name => tds2[1][:name], :highlight => 'name', :parent_project => project2[:projectname]},
                          {:name => tds2[2][:name], :highlight => 'features', :parent_project => project2[:projectname]},
                          {:name => tds2[3][:name], :highlight => "description", :parent_project => project2[:projectname]}]
        global_search_test("dog", "trainingdataset", expected_hits2)
        expected_hits3 = [{:name => fgs1[3][:name], :highlight => 'name', :parent_project => project1[:projectname]},
                          {:name => fgs2[3][:name], :highlight => 'name', :parent_project => project2[:projectname]}]
        global_search_test("dog", "feature", expected_hits3)
      end

      it "accessor projects for search result items" do
        #make sure epipe is free of work
        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        with_valid_session
        user1_email = @user["email"]
        project1 = create_project
        project2 = create_project
        featurestore1_name = project1[:projectname].downcase + "_featurestore.db"
        featurestore1_id = get_featurestore_id(project1[:id])
        featurestore1 = get_dataset(project1, featurestore1_name)
        #share featurestore from one of your projects with another one of your projects
        request_access_by_dataset(featurestore1, project2)
        share_dataset_checked(project1, featurestore1_name, project2[:projectname], "FEATURESTORE")
        fg1_name = "fg_dog1"
        featuregroup1_id = create_cached_featuregroup_checked(project1[:id], featurestore1_id, fg1_name)

        #new user with a project shares featurestore with the previous user
        reset_and_create_session
        user2_email = @user["email"]
        project3 = create_project
        featurestore3_name = project3[:projectname].downcase + "_featurestore.db"
        featurestore3_id = get_featurestore_id(project3[:id])
        featurestore3 = get_dataset(project3, featurestore3_name)
        fg3_name = "fg_cat1"
        featuregroup3_id = create_cached_featuregroup_checked(project3[:id], featurestore3_id, fg3_name)
        create_session(user1_email, "Pass123")
        request_access_by_dataset(featurestore3, project2)
        create_session(user2_email, "Pass123")
        share_dataset_checked(project3, featurestore3_name, project2[:projectname], "FEATURESTORE")

        create_session(user1_email, "Pass123")

        wait_result = epipe_wait_on_mutations(wait_time: 30, repeat: 2)
        expect(wait_result["success"]).to be(true), wait_result["msg"]

        #have access to the featurestore both from parent(project1) and shared project(project2) (user1)
        expected_hits1 = [{:name => fg1_name, :highlight => 'name', :parent_project => project1[:projectname], :access_projects => 2}]
        global_search_test("dog", "featuregroup", expected_hits1)
        #have access to the user2 project(project3) featurestore shared with me (user1)
        expected_hits2 = [{:name => fg3_name, :highlight => 'name', :parent_project => project3[:projectname], :access_projects => 1}]
        global_search_test("cat", "featuregroup", expected_hits2)
        #I see the featuregroup of user1, but no access to it
        create_session(user2_email, "Pass123")
        expected_hits3 = [{:name => fg1_name, :highlight => 'name', :parent_project => project1[:projectname], :access_projects => 0}]
        global_search_test("dog", "featuregroup", expected_hits3)
      end
    end
  end
end

