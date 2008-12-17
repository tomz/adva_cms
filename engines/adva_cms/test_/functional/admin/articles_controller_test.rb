require File.dirname(__FILE__) + "/../../test_helper"

class AdminArticlesControllerTest < ActionController::TestCase
  tests Admin::ArticlesController
 
  def setup
    stub(@controller).guard_permission
    stub(@controller).require_authentication
    stub(@controller).current_user{ User.make }
  end

  test "is an Admin::BaseController" do
    Admin::BaseController.should === @controller # FIXME matchy doesn't have a be_kind_of matcher
  end
   
  describe "routing" do
    with_options :controller => 'admin/articles', :site_id => "1", :section_id => "1" do |r|
      r.it_maps :get,    "/admin/sites/1/sections/1/articles",        :action => 'index'
      r.it_maps :get,    "/admin/sites/1/sections/1/articles/1",      :action => 'show',    :id => '1'
      r.it_maps :get,    "/admin/sites/1/sections/1/articles/new",    :action => 'new'
      r.it_maps :post,   "/admin/sites/1/sections/1/articles",        :action => 'create'
      r.it_maps :get,    "/admin/sites/1/sections/1/articles/1/edit", :action => 'edit',    :id => '1'
      r.it_maps :put,    "/admin/sites/1/sections/1/articles/1",      :action => 'update',  :id => '1'
      r.it_maps :delete, "/admin/sites/1/sections/1/articles/1",      :action => 'destroy', :id => '1'
    end
  end
  
  describe "GET to :index" do
    before do
      stub(@controller).guard_permission
      stub(@controller).require_authentication
      stub(@controller).current_user{ User.make }
    end
    
    action { get :index, :site_id => @site.id, :section_id => @section.id }
    
    with :an_empty_section do
      it_assigns :articles
      it_renders :template, 'admin/articles/index'
    end
   
    with :an_empty_blog do
      it_assigns :articles
      it_renders :template, 'admin/blog/index'
    end
   
    describe "filter_options", :with => :an_empty_section do
      before do
        @controller.instance_variable_set :@section, @section
      end
      
      it "fetches articles belonging to a category when :filter == category" do
        @controller.params = {:filter => 'category', :category => '1'}
        filter_options.should == {:conditions => "category_assignments.category_id = 1"}
      end
     
      it "fetches articles by checking the title when :filter == title" do
        @controller.params = {:filter => 'title', :query => 'foo'}
        filter_options.should == {:conditions => "LOWER(contents.title) LIKE '%foo%'"}
      end
     
      it "fetches articles by checking the excerpt and body when :filter == body" do
        @controller.params = {:filter => 'body', :query => 'foo'}
        filter_options.should == {:conditions => "LOWER(contents.excerpt) LIKE '%foo%' OR LOWER(contents.body) LIKE '%foo%'"}
      end
     
      it "fetches articles by checking the tags when :filter == tags" do
        @controller.params = {:filter => 'tags', :query => 'foo bar'}
        filter_options.should == {:conditions => "tags.name IN ('foo','bar')"}
      end
     
      it "fetches articles by checking published_at when :filter == draft" do
        @controller.params = {:filter => 'draft'}
        filter_options.should == {:conditions => "published_at is null"}
      end 
    end
  end
    
  def filter_options
    @controller.send(:filter_options).slice(:conditions)
  end
   
  describe "GET to :show" do
    action { get :show, @params }
  
    with :published_blog_article do
      before { @params = {:site_id => @site.id, :section_id => @section.id, :id => @article.id} }
      
      it "previews the article in the frontend layout" do
        it_assigns :article => :not_nil
        it_renders :template, 'blog/show'
      end
      
      with "given a :version param" do
        before do
          @params.merge! :version => 1
          @article.update_attributes :title => 'new title'
        end
  
        it "reverts the article to the given version" do
          assigns(:article).version.should == 1
        end
      end
    end
  
    with :published_section_article do
      before { @params = {:site_id => @site.id, :section_id => @section.id, :id => @article.id} }
      
      it "previews the article in the frontend layout" do
        it_assigns :article => :not_nil
        it_renders :template, 'sections/show'
      end
    end
  end
  
  describe "GET to :new" do
    action { get :new, :site_id => @site.id, :section_id => @section.id }
    
    with :an_empty_section, :an_empty_blog do
      it_assigns :site, :section, :article
      it_renders_template :new
      # it_guards_permissions :create, :article
    end
  end
  
  describe "POST to :create" do
    action { post :create, { :site_id => @site.id, :section_id => @section.id }.merge(@params) }
    
    with :an_empty_section, :an_empty_blog do
      it_assigns :site, :section, :article
  
      with :valid_article_params do
        # it_guards_permissions :create, :article
        it_changes 'Article.count' => 1
        it_triggers_event :article_created
        it_assigns_flash_cookie :notice => :not_nil
        it_redirects_to { edit_admin_article_path(@site.id, @section.id, assigns(:article).id) }
              
        it "associates the new Article to the current site" do
          assigns(:article).reload.site.should == @site
        end
              
        it "associates the new Article to the current section" do
          assigns(:article).reload.section.should == @section
        end
      end
  
      with :invalid_article_params do
        it_does_not_change 'Article.count'
        it_does_not_trigger_any_event
        it_renders_template :new
        it_assigns_flash_cookie :error => :not_nil
      end
    end
  end
  
  def default_params
    { :site_id => @site.id, :section_id => @section.id }
  end
 
  describe "GET to :edit" do
    action { get :edit, default_params.merge(:id => @article.id) }

    with :an_empty_section, :an_empty_blog do
      with :a_published_article do
        it_assigns :site, :section, :article
        it_renders_template :edit
        # it_guards_permissions :update, :article
      end
    end
  end
 
  describe "PUT to :update" do
    action do 
      params = default_params.merge(@params).merge(:id => @article.id)
      params[:article][:title] = "#{@article.title} changed" unless params[:article][:title].blank?
      put :update, params
    end

    with :an_empty_section, :an_empty_blog do
      it_assigns :site, :section, :article
      # it_guards_permissions :update, :article

      with :a_published_article do
        with "no version param" do
          with :valid_article_params do
            it_updates :article
            it_redirects_to { edit_admin_article_path(@site, @section, @article) }
            it_assigns_flash_cookie :notice => :not_nil
            it_triggers_event :article_updated
            
            with(:save_revision_param)    { it_versions :article }
            with(:no_save_revision_param) { it_does_not_version :article }
          end
          
          with :invalid_article_params do
            it_renders_template :edit
            it_assigns_flash_cookie :error => :not_nil
            it_does_not_trigger_any_event
          end
        end
      end
    end
      
    # describe "given a version param" do 
    #   act! { request_to :put, @member_path, @params.merge({:article => {:version => "1"}}) }
    #   
    #   describe "and the article can be rolled back to the given version" do
    #     before :each do
    #       @article.stub!(:revert_to!).and_return true
    #     end
    #     
    #     it_triggers_event :article_rolledback
    #     it_assigns_flash_cookie :notice => :not_nil
    #     it_redirects_to { @edit_member_path }
    #   
    #     it "reverts the article before saving" do
    #       @article.should_receive(:revert_to!).any_number_of_times.with "1"
    #       act!
    #     end
    #   end
    #   
    #   describe "and the article can not be rolled back to the given version" do
    #     before :each do
    #       @article.stub!(:revert_to!).and_return false
    #     end
    #     
    #     it_does_not_trigger_any_event
    #     it_assigns_flash_cookie :error => :not_nil
    #     it_redirects_to { @edit_member_path }
    #   end
    # end
    #  
    # describe "given invalid article params" do
    #   before :each do @article.stub!(:save_without_revision).and_return false end
    #   it_renders_template :edit
    #   it_assigns_flash_cookie :error => :not_nil
    # end
  end
end