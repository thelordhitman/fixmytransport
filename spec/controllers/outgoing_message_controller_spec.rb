require 'spec_helper'

describe OutgoingMessagesController do

  def mock_campaign
    @campaign_user = mock_model(User, :name => "Campaign User")
    @mock_council_contact = mock_model(CouncilContact)
    @mock_outgoing_message = mock_model(OutgoingMessage, :save => true, 
                                                         :recipient => @mock_council_contact)
    @outgoing_messages_mock = mock('outgoing message association', :build => @mock_outgoing_message)
    @mock_campaign = mock_model(Campaign, :confirmed => true,
                                          :initiator => @campaign_user,
                                          :outgoing_messages => @outgoing_messages_mock)
    @controller.stub!(:current_user).and_return(@campaign_user)
    Campaign.stub!(:find).and_return(@mock_campaign)
  end
  
  describe "GET #new" do 
    
    before do 
      @default_params = { :campaign_id => 66, :recipient_id => 1, :recipient_type => 'CouncilContact' }
      mock_campaign
      @expected_access_message = :outgoing_messages_new_access_message
    end
    
    def make_request params
      get :new, params 
    end
    
    it 'should render the template "new"' do 
      make_request @default_params
      response.should render_template('new')
    end
    
    it_should_behave_like "an action that requires the campaign initiator"
  
  end
  
  describe 'POST #create' do 
    
    before do 
      mock_campaign
      @default_params = { :campaign_id => 66 }
      @expected_access_message = :outgoing_messages_create_access_message
    end
    
    def make_request params
      post :create, params
    end
    
    it 'should create an outgoing message for the campaign' do 
      @outgoing_messages_mock.should_receive(:build).with({ 'text' => 'test text' })
      make_request({:campaign_id => 55, :outgoing_message => { :text => 'test text' }})
    end  
    
    describe 'if the outgoing message cannot be saved' do 
      
      it 'should render the "new" template' do 
        @mock_outgoing_message.stub!(:save).and_return(false)
        make_request(@default_params)
        response.should render_template('new')
      end
      
    end
  
    describe 'if the outgoing message can be saved' do 
    
      it 'should redirect to the outgoing message page' do
        @mock_outgoing_message.stub!(:save).and_return(true)
        make_request(@default_params)
        response.should redirect_to(campaign_outgoing_message_path(@mock_campaign, @mock_outgoing_message))
      end
    
    end
    
    it_should_behave_like "an action that requires the campaign initiator"    
  
  end
  
  describe 'GET #show' do 
    
    before do 
      @mock_outgoing_message = mock_model(OutgoingMessage)
      OutgoingMessage.stub!(:find).and_return(@mock_outgoing_message)
      @default_params = { :campaign_id => 55, :id => 33 }
    end
  
    def make_request params
      get :show, params
    end
    
    it 'should render the "show" template' do 
      make_request(@default_params)
      response.should render_template('show')
    end
    
    it 'should get the incoming message' do 
      OutgoingMessage.should_receive(:find).with('33')
      make_request(@default_params)
    end
    
  end
  
end