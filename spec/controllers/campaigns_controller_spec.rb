require 'spec_helper'

describe CampaignsController do

  
  describe 'GET #index' do

    def make_request
      get :index
    end
    
    it 'should render the campaigns/index template' do 
      make_request
      response.should render_template("campaigns/index")
    end
    
    it 'should ask for campaigns' do 
      Campaign.should_receive(:find).and_return([])
      make_request
    end
  
  end
  
  describe 'GET #show' do 
  
    before do
      mock_assignment = mock_model(Assignment, :task_type_name => 'A test task')
      @campaign = mock_model(Campaign, :id => 8, 
                                       :title => 'A test campaign',
                                       :initiator_id => 44, 
                                       :confirmed => true,
                                       :location => mock_model(Stop, :points => [mock("point", :lat => 51, :lon => 0)]))
      Campaign.stub!(:find).and_return(@campaign)
    end
    
    def make_request
      get :show, :id => 8
    end
    
    it 'should ask for the campaign by id' do 
      Campaign.should_receive(:find).with('8').and_return(@campaign)
      make_request
    end
    
    it 'should not display a campaign that has not been confirmed' do 
      @campaign.stub!(:confirmed).and_return(false)
      make_request
      response.status.should == '404 Not Found'
    end
    
  end
  
  shared_examples_for "an action that requires the campaign initiator or a token" do 
        
    describe 'when the campaign is new' do

      before do 
        @mock_campaign.stub!(:status).and_return(:new)
      end
      
      describe 'and the campaign initiator is a registered user' do 
        
        before do 
          @campaign_user.stub!(:registered?).and_return(true)
        end
      
        describe "and the campaign's problem's token is not supplied" do        
          
          it 'should do the default behaviour for the action if the current user is the campaign initiator' do 
            controller.stub!(:current_user).and_return(@campaign_user)
            make_request
            response.should do_default_behaviour
          end
          
          it "should return a 'not found' response if the current user is not the campaign initiator" do 
            controller.stub!(:current_user).and_return(mock_model(User))
            make_request
            response.status.should == '404 Not Found'
          end
          
          it "should return a 'not found' response if there is no current user" do 
            controller.stub!(:current_user).and_return(nil)
            make_request
            response.status.should == '404 Not Found'            
          end
        
        end
   
        describe "and the campaign's problem's token is supplied" do 
          
          it 'should do the default behaviour for the action if the current user is the campaign initiator' do 
            controller.stub!(:current_user).and_return(@campaign_user)
            make_request(token=@mock_problem.token)
            response.should do_default_behaviour
          end
          
          it 'should render the "wrong_user" template with appropriate message params if the current user is not the campaign initiator' do 
            controller.stub!(:current_user).and_return(mock_model(User))
            make_request(token=@mock_problem.token)
            response.should render_template("shared/wrong_user")
            assigns[:name].should == 'Campaign User'
            assigns[:access_message].should == @expected_access_message
          end
          
          it 'should redirect to the login page with a message if there is no current user' do 
            controller.stub!(:current_user).and_return(nil)
            make_request(token=@mock_problem.token)
            response.should redirect_to(login_url)
            flash[:notice].should == "Login as Campaign User to #{@expected_wrong_user_message}"          
          end
        
        end
    
      end
    
      describe 'and the campaign initiator is not yet a registered user' do 
        
        before do 
          @campaign_user.stub!(:registered?).and_return(false)
        end
    
        describe "and the campaign's problem's token is not supplied" do     

          it 'should return a "not found" response' do 
            make_request
            response.status.should == '404 Not Found' 
          end

        end
        
        describe "and the campaign's problem's token is supplied" do 
          
          it 'should do the default behaviour for the action if there is no current user' do 
            controller.stub!(:current_user).and_return(nil)
            make_request(token=@mock_problem.token)
            response.should do_default_behaviour
          end
          
          it 'should render the "wrong_user" template if there is a current user' do 
            controller.stub!(:current_user).and_return(mock_model(User))
            make_request(token=@mock_problem.token)
            response.should render_template("shared/wrong_user")
          end
          
        end
      
      end

    end
    
    describe 'when the campaign is confirmed' do 
      
      before do 
       @mock_campaign.stub!(:status).and_return(:confirmed)
      end
      
      describe 'and the current user is the campaign initiator' do 
      
        it 'should do the default behaviour of the action' do   
          controller.stub!(:current_user).and_return(@campaign_user)
          make_request
          response.should do_default_behaviour
        end
        
      end
      
      describe 'and the current user is not the campaign initiator' do
        
        it 'should render the "wrong_user" template' do 
          controller.stub!(:current_user).and_return(mock_model(User))
          make_request(token=@mock_problem.token)
          response.should render_template('shared/wrong_user')
        end
        
        it 'should assign variables for an appropriate message' do 
          controller.stub!(:current_user).and_return(mock_model(User))
          make_request(token=@mock_problem.token)
          assigns[:name].should == 'Campaign User'
          assigns[:access_message].should == @expected_access_message
        end
        
      end
      
      describe 'and there is no current user' do 

        it 'should redirect to the login page with a message' do 
          controller.stub!(:current_user).and_return(nil)
          make_request(token=@mock_problem.token)
          response.should redirect_to(login_url)
          flash[:notice].should == "Login as Campaign User to confirm this problem"
        end

      end
    
    end
  end
  
  describe 'PUT #update' do 
    
    before do 
      @campaign_user = mock_model(User, :name => "Campaign User", 
                                        :save => true, 
                                        :registered? => false, 
                                        :attributes= => true, 
                                        :registered= => true)
      @mock_problem = mock_model(Problem, :token => 'problem-token')
      @mock_campaign = mock_model(Campaign, :problem => @mock_problem, 
                                            :initiator => @campaign_user, 
                                            :attributes= => true, 
                                            :valid? => true, 
                                            :confirmed= => true,
                                            :save => true, 
                                            :status => :new)
      Campaign.stub!(:find).and_return(@mock_campaign)
      @expected_wrong_user_message = "confirm this problem"
      @expected_access_message = :campaigns_update_access_message
    end
    
    def make_request(token=nil)
      put :update, { :id => 33, :token => token, 
                                :campaign => { :title => 'Test Campaign' }, 
                                :user => { :password => 'A password' } }
    end   
    
    def do_default_behaviour
      redirect_to(campaign_url(@mock_campaign))
    end
    
    it_should_behave_like "an action that requires the campaign initiator or a token"
    
    it 'should update the campaign with the campaign params passed' do 
      @mock_campaign.should_receive(:attributes=).with("title" => 'Test Campaign')
      make_request(token=@mock_problem.token)
    end
    
    describe 'if a valid token and user params are supplied' do 
      
      it 'should update the campaign initiator with the user params' do 
        @campaign_user.should_receive(:attributes=).with("password" => 'A password')
        make_request(token=@mock_problem.token)
      end
      
      it 'should set the registered flag on the user' do 
        @campaign_user.should_receive(:registered=).with(true)
        make_request(token=@mock_problem.token)
      end
      
      it 'should set the confirmed flag on the campaign' do
        @mock_campaign.should_receive(:confirmed=).with(true)
        make_request(token=@mock_problem.token)
      end
    
    end
    
    describe 'if the campaign is valid' do 
      
      before do 
        @mock_campaign.stub!(:valid?).and_return(true)
      end
      
      it 'should save the campaign' do 
        @mock_campaign.should_receive(:save)
        make_request(token=@mock_problem.token)
      end
      
      it 'should save the campaign initiator (logging them in though authlogic)' do
        @campaign_user.should_receive(:save)
        make_request(token=@mock_problem.token)
      end
      
      it 'should redirect to the campaign url' do 
        make_request(token=@mock_problem.token)
        response.should redirect_to(campaign_url(@mock_campaign))
      end
       
    end
    
    describe 'if the campaign is not valid' do 
      
      it 'should render the "edit" template' do 
        @mock_campaign.stub!(:valid?).and_return(false)
        make_request(token=@mock_problem.token)
        response.should render_template("campaigns/edit")
      end
      
    end
    
  end
  
  describe 'GET #edit' do 
    
    before do 
      @campaign_user = mock_model(User, :name => "Campaign User")
      @mock_problem = mock_model(Problem, :token => 'problem-token')
      @mock_campaign = mock_model(Campaign, :problem => @mock_problem, 
                                            :initiator => @campaign_user, 
                                            :title => 'A test campaign', 
                                            :description => 'Campaign description')
      Campaign.stub!(:find).and_return(@mock_campaign)
      @expected_wrong_user_message = "confirm this problem"
      @expected_access_message = :campaigns_edit_access_message
    end
    
    def make_request(token=nil)
      get :edit, { :id => 33, :token => token }
    end
    
    def do_default_behaviour
      render_template("campaigns/edit")
    end

    it_should_behave_like "an action that requires the campaign initiator or a token"
    
  end

  describe 'GET #join' do 
    
    before do 
      Campaign.stub!(:find).and_return(mock_model(Campaign, :confirmed => true))
    end
    
    def make_request
      get :join, { :id => 44 }
    end
    
    it "should render the 'join' template" do 
      make_request
      response.should render_template("campaigns/join")
    end

  end
    
  describe 'GET #add_update' do 
    
    before do 
      @campaign_user = mock_model(User, :name => "Campaign User")
      @mock_campaign = mock_model(Campaign, :confirmed => true, 
                                            :initiator => @campaign_user,
                                            :campaign_updates => mock('update', :build => true))
      Campaign.stub!(:find).and_return(@mock_campaign)
      @controller.stub!(:current_user).and_return(@campaign_user)
      @expected_wrong_user_message = "add an update"
      @expected_access_message = :campaigns_add_update_access_message
      @default_params = { :id => 55, :update_id => '33' }
    end
  
    def make_request params
      get :add_update, params
    end
    
    it 'should assign a campaign update to the view' do
      make_request({:id => 55})
      assigns[:campaign_update].should_not be_nil
    end 
    
    it_should_behave_like "an action that requires the campaign initiator"
  end
  
  describe 'GET #add_comment' do 

    before do 
      @mock_campaign = mock_model(Campaign,  :confirmed => true)
      Campaign.stub!(:find).and_return(@mock_campaign)
      @mock_update = mock_model(CampaignUpdate)
      CampaignUpdate.stub!(:find).and_return(@mock_update)
      @mock_user = mock_model(User)
      @controller.stub!(:current_user).and_return(@mock_user)
    end
        
    def make_request(params=nil)
      params = { :id => 55, :update_id => '33' } if !params
      get :add_comment, params
    end
    
    it 'should render the template "add_comment"' do 
      make_request
      response.should render_template('add_comment')
    end
    
    describe 'when no campaign update can be found' do
    
      before do 
        @mock_user = mock_model(User, :campaigns => [@mock_campaign])
        @controller.stub!(:current_user).and_return(@mock_user)
        CampaignUpdate.stub!(:find).and_return(nil)
      end
      
      it 'should return a "not found" response' do 
        make_request
        response.status.should == '404 Not Found'
      end
    
    end
    
  end

  describe 'POST #add_comment' do 
    
    before do 
      @mock_user = mock_model(User)
      @mock_campaign = mock_model(Campaign, :confirmed => true)
      Campaign.stub!(:find).and_return(@mock_campaign)
      @controller.stub!(:current_user).and_return(@mock_user)
      @mock_comment = mock_model(CampaignComment, :save => true,
                                                  :campaign_update_id => 66,
                                                  :text => 'comment text')
      @mock_update = mock_model(CampaignUpdate, :comments => mock('comments', :build => @mock_comment))
      CampaignUpdate.stub!(:find).and_return(@mock_update)
    end
    
    def make_request params
      post :add_comment, params
    end
    
    it 'should create a comment associated with the update' do 
      @mock_update.comments.should_receive(:build)
      make_request( :id => 55, :campaign_comment => {:update_id => 66} )      
    end
    
    it 'should save the comment' do 
      @mock_comment.should_receive(:save).and_return(true)
      make_request( :id => 55, :campaign_comment => {:update_id => 66} )
    end
    
    it 'should assign a comment to the view' do 
      make_request( :id => 55, :campaign_comment => {:update_id => 66} )
      assigns[:comment].should_not be_nil
    end
  
    describe 'when handling an AJAX request' do 
      
      it 'should return a json hash containing the update_id and comment html' do 
        xhr :post, :add_comment, { :id => 55, :campaign_comment => {:update_id => 66} }
        json_hash = JSON.parse(response.body)
        json_hash['update_id'].should == 66
        json_hash['html'].should_not be_nil
      end
    
    end
        
  end  

  describe 'POST #add_update' do 

    before do 
      @user = mock_model(User, :id => 55)
      @controller.stub!(:current_user).and_return(@user)
      @mock_update = mock_model(CampaignUpdate, :save => true, 
                                                :is_advice_request? => false)
      @mock_updates = mock('campaign updates', :build => @mock_update)
      @mock_campaign = mock_model(Campaign, :supporters => [], 
                                            :title => 'A test title',
                                            :confirmed => true,
                                            :add_supporter => true,
                                            :campaign_updates => @mock_updates, 
                                            :initiator => @user)
      Campaign.stub!(:find).and_return(@mock_campaign)
      @expected_wrong_user_message = 'Add an update'
      @expected_access_message = :campaigns_add_update_access_message
      @default_params = { :id => 55, :update_id => '33' }
    end
    
    def make_request(params)
      post :add_update, params
    end
    
    it_should_behave_like "an action that requires the campaign initiator"
    
    it 'should redirect to the campaign url' do 
      make_request(:id => 55)
      response.should redirect_to(campaign_url(@mock_campaign))
    end
    
    it 'should try and save the new campaign update' do 
      @mock_updates.should_receive(:build).and_return(@mock_update)
      @mock_update.should_receive(:save).and_return(true)
      make_request(:id => 55)
    end
    
    it 'should display a notice if the new update was successfully saved' do 
      @mock_update.stub!(:save).and_return(true)
      make_request(:id => 55)
      flash[:notice].should == 'Your update has been added.'
    end
    
    describe 'when handling an AJAX request' do 
    
      it 'should return a json hash with a key "html"' do 
        xhr :post, :add_update, {:id => 55}
        json_hash = JSON.parse(response.body)
        json_hash['html'].should_not be_nil
      end
      
    end
    
  end

  describe 'POST #join' do
    
    before do 
      @mock_campaign = mock_model(Campaign, :supporters => [], 
                                            :title => 'A test title',
                                            :confirmed => true,
                                            :add_supporter => true)
      Campaign.stub!(:find).and_return(@mock_campaign)
    end
    
    def make_request(params)
      post :join, params
    end
    
    describe 'when the current user has the same user id as that passed in the params' do 
      
      before do 
        @user = mock_model(User, :id => 55)
        @controller.stub!(:current_user).and_return(@user)
      end
      
      it 'should make the user a confirmed campaign supporter' do
        @mock_campaign.should_receive(:add_supporter).with(@user, confirmed=true)
        make_request({ :id => 44, :user_id => '55' })
      end
      
      it 'should redirect them to the campaign URL' do 
        make_request({ :id => 44, :user_id => '55' })
        response.should redirect_to(campaign_url(@mock_campaign))
      end
    
    end
    
    describe 'when an invalid email address is supplied' do 
       
      it 'should render the "join" template' do 
        make_request({ :id => 44, :email => 'bad_email' })
        response.should render_template('join')
      end
    
    end
    
    describe 'when a valid email address is supplied' do 
    
      before do 
        @mock_user = mock_model(User, :valid? => true, :save_if_new => true)
        User.stub!(:find_or_initialize_by_email).and_return(@mock_user)
      end
      
      it 'should save the user if new' do 
        @mock_user.should_receive(:save_if_new)
        make_request({ :id => 44, :email => 'goodemail' })
      end
      
      it 'should make the user a campaign supporter' do 
        @mock_campaign.should_receive(:add_supporter).with(@mock_user, confirmed=false)
        make_request({ :id => 44, :email => 'goodemail' })
      end
      
      it 'should render the "confirmation_sent" template' do
        make_request({ :id => 44, :email => 'goodemail' })
        response.should render_template('shared/confirmation_sent')
      end
      
    end
  end
  
  describe 'GET #confirm_join' do 
    
    before do 
      @mock_user = mock_model(User)
      @mock_supporter = mock_model(CampaignSupporter, :supporter => @mock_user,
                                                      :confirm! => true)
      CampaignSupporter.stub!(:find_by_token).and_return(@mock_supporter)
    end
  
    def make_request
      get :confirm_join, { :email_token => 'mytoken' }
    end
  
    it 'should assign an error to the view if the campaign supporter cannot be found' do 
      CampaignSupporter.stub!(:find_by_token).and_return(nil)
      make_request
      assigns[:error].should == :error_on_join
    end
    
    it 'should assign the user to the view' do 
      make_request
      assigns[:user].should == @mock_user
    end
    
    it 'should confirm the campaign supporter' do 
      @mock_supporter.should_receive(:confirm!)
      make_request
    end
    
  end
  
  describe '#PUT confirm_join' do 
    
    before do 
      @mock_user = mock_model(User,  :attributes= => true, 
                                     :registered= => true,
                                     :save => true)
      @mock_campaign = mock_model(Campaign)
      @mock_supporter = mock_model(CampaignSupporter, :supporter => @mock_user,
                                                      :confirm! => true,
                                                      :campaign => @mock_campaign)
      CampaignSupporter.stub!(:find_by_token).and_return(@mock_supporter)
    end
    
    def make_request
      put :confirm_join, { :email_token => 'mytoken' }
    end
    
    it 'should assign an error to the view if the campaign supporter cannot be found' do 
      CampaignSupporter.stub!(:find_by_token).and_return(nil)
      make_request
      assigns[:error].should == :error_on_register
    end
    
    it 'should assign the user to the view' do 
      make_request
      assigns[:user].should == @mock_user
    end
    
    it 'should redirect to the campaign url if the user model can be saved' do 
      make_request
      response.should redirect_to(campaign_url(@mock_campaign))
    end
    
    it 'should not redirect to the campaign url if the user model cannot be saved' do 
      @mock_user.stub!(:save).and_return(false)
      make_request
      response.should_not redirect_to(campaign_url(@mock_campaign))
    end
    
  end
  
end
