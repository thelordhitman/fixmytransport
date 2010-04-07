require 'spec_helper'

describe ProblemsController do

  describe 'GET #new' do 
    
    def make_request
      get :new 
    end  
  
    it 'should ask for a new problem' do 
      Problem.should_receive(:new)
      make_request
    end
    
  end
  
  describe 'POST #create' do 
  
    before do 
      @problem = mock_model(Problem, :id => 8, :subject => 'A test problem', :save => true)
      Problem.stub!(:new).and_return(@problem)
    end
    
    def make_request
      post :create, {:problem => {:subject => 'A test problem', :description => 'More info'}}
    end
  
    it 'should create a new problem with the problem request params' do 
      expected_params = {"subject" => 'A test problem', "description" => 'More info'}
      Problem.should_receive(:new).with(expected_params).and_return(@problem)
      make_request
    end
    
    it 'should try and save the new problem' do 
      @problem.should_receive(:save)
      make_request
    end
    
    it "should render the 'New problem' view if the problem can't be saved" do 
      @problem.stub!(:save).and_return(false)
      make_request
      response.should render_template('problems/new')
    end
    
    it 'should redirect to the problem page if the problem can be saved' do 
      @problem.stub!(:save).and_return(true)
      make_request
      response.should redirect_to(problem_url(@problem))
    end
    
  end
  
  describe 'GET #index' do

    def make_request
      get :index
    end
    
    it 'should render the problems/index template' do 
      make_request
      response.should render_template("problems/index")
    end
    
    it 'should ask for all the problems' do 
      Problem.should_receive(:find).with(:all)
      make_request
    end
  
  end
  
  describe 'GET #show' do 
  
    before do
      @problem = mock_model(Problem, :id => 8, :subject => 'A test problem')
      Problem.stub!(:find).and_return(@problem)
    end
    
    def make_request
      get :show, :id => 8
    end
    
    it 'should ask for the problem by id' do 
      Problem.should_receive(:find).with('8').and_return(@problem)
      make_request
    end
  
    it 'should return a "Not found" response for a request for an invalid ID' do
      Problem.stub!(:find).with('8').and_raise ActiveRecord::RecordNotFound 
      make_request
      response.response_code.should == 404
    end
  
  end

end
