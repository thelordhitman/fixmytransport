require 'spec_helper'

describe ProblemMailer do
  
  describe 'when sending problem confirmations' do
 
    before do
      @problem = mock_model(Problem, :subject => "My Problem", 
                                     :description => "Some description",
                                     :reporter_name => "Problem Reporter", 
                                     :anonymous? => false)
      @recipient = mock_model(User, :email => "problemreporter@example.com")
      @token = "test-token"
    end
  
    describe "when creating a problem confirmation" do

      it "should render successfully" do
        lambda { ProblemMailer.create_problem_confirmation(@recipient, @problem, @token) }.should_not raise_error
      end
      
    end
  
    describe 'when delivering a problem confirmation' do 
    
      before do 
        @mailer = ProblemMailer.create_problem_confirmation(@recipient, @problem, @token)
      end

      it "should deliver successfully" do
        lambda { ProblemMailer.deliver(@mailer) }.should_not raise_error
      end

    end
    
  end
  
  describe 'when sending problem reports' do 
    
    before do
      @mock_operator = mock_model(Operator, :email => 'operator@example.com', 
                                            :name => 'Test Operator')
      @mock_user = mock_model(User, :email => 'user@example.com')
      @mock_problem = mock_model(Problem, :operator => @mock_operator, 
                                          :reporter => @mock_user,
                                          :reporter_name => 'Test User', 
                                          :reporter_phone => '123',
                                          :anonymous? => false,
                                          :subject => "Missing ticket machines", 
                                          :description => "Desperately need more.",
                                          :location => stops(:victoria_station_one))
    end
   
    describe "when creating a problem report" do

      it "should render successfully" do
        lambda { ProblemMailer.create_report(@mock_problem, [@mock_operator]) }.should_not raise_error
      end
      
    end
    
    describe 'when delivering a problem report' do 
    
      before do 
        @mailer = ProblemMailer.create_report(@mock_problem, [@mock_operator])
      end
      
      it 'should deliver successfully' do
        lambda { ProblemMailer.deliver(@mailer) }.should_not raise_error
      end
      
    end
    
  end
  
  describe 'when checking for a problem change' do 
  
    it 'should print a message if the council info for the problem location is different from that stored on the problem' do 
      mock_stop = mock_model(Stop, :council_info => "33|44")
      mock_problem = mock_model(Problem, :councils_responsible? => true, 
                                         :council_info => "33,44",
                                         :location => mock_stop, 
                                         :id => 22)
      STDERR.should_receive(:puts).with("Councils changed for problem 22. Was 33,44, now 33|44")
      ProblemMailer.check_for_council_change(mock_problem)
    end
  
  end
  
  describe 'when sending problem reports' do 
    
    def make_mock_problem(emailable_orgs, unemailable_orgs)
      mock_location = mock_model(Stop, :name => 'A test stop',
                                       :atco_code => 'abc', 
                                       :plate_code => 'def')
      mock_model(Problem, :responsible_organizations => emailable_orgs + unemailable_orgs,
                          :emailable_organizations => emailable_orgs,
                          :unemailable_organizations => unemailable_orgs,
                          :update_attribute => true,
                          :reporter_name => 'Test User', 
                          :reporter_phone => '123',
                          :anonymous? => false, 
                          :subject => 'A test problem',
                          :description => 'Some description',
                          :reporter => @reporter,
                          :location => mock_location)
    end
    
    before do
      @reporter = mock_model(User, :name => "John Q User", 
                                   :email => 'john@example.com', 
                                   :phone => nil)
      MySociety::MaPit.stub!(:call).and_return({ 22 => {'name' => 'Unemailable council'}, 
                                                 44 => {'name' => 'Emailable council'}})
                                                 
      @emailable_council = mock_model(Council, :name => 'Emailable council', 
                                               :email => 'council@example.com')
      @unemailable_council = mock_model(Council, :name => 'Unemailable council')
      
      @operator_with_mail = mock_model(Operator, :email => 'operator@example.com', 
                                                 :name => "Emailable operator")
      @operator_without_mail = mock_model(Operator, :email => nil, 
                                                    :name => "Unemailable operator")
      
      @pte_with_mail = mock_model(PassengerTransportExecutive, :email => 'pte@example.com', 
                                                               :name => 'Emailable PTE')
      @pte_without_mail = mock_model(PassengerTransportExecutive, :email => nil, 
                                                                  :name => 'Unemailable PTE')

      @mock_problem_email_operator = make_mock_problem([@operator_with_mail], [])
      @mock_problem_no_email_operator = make_mock_problem([], [@operator_without_mail]) 
      @mock_problem_email_pte =  make_mock_problem([@pte_with_mail], [])
      @mock_problem_no_email_pte = make_mock_problem([], [@pte_without_mail])
      @mock_problem_some_council_mails = make_mock_problem([@emailable_council], [@unemailable_council])                 
      
      @sendable = [@mock_problem_email_operator, 
                   @mock_problem_email_pte, 
                   @mock_problem_some_council_mails]
      @unsendable = [@mock_problem_no_email_operator,
                     @mock_problem_no_email_pte]
      @all = @sendable + @unsendable
      Problem.stub!(:sendable).and_return([@mock_problem_email_operator,
                                           @mock_problem_no_email_operator,
                                           @mock_problem_email_pte,
                                           @mock_problem_no_email_pte,
                                           @mock_problem_some_council_mails])
      
      ProblemMailer.stub!(:deliver_report)
      ProblemMailer.stub!(:check_for_council_change)
      STDERR.stub!(:puts)
    end
  
    it 'should ask for all sendable problems' do 
      Problem.should_receive(:sendable).and_return([@mock_problem_email_operator, 
                                                    @mock_problem_no_email_operator])
      ProblemMailer.send_reports
    end
    
    it 'should print a list of operators with missing emails' do 
      STDERR.should_receive(:puts).with("Unemailable operator")
      ProblemMailer.send_reports
    end
    
    it 'should print a list of PTEs with missing emails' do 
      STDERR.should_receive(:puts).with("Unemailable PTE")
      ProblemMailer.send_reports
    end
    
    it 'should print a list of councils with missing emails' do 
      STDERR.should_receive(:puts).with("Unemailable council")
      STDERR.should_not_receive(:puts).with("Emailable council")
      ProblemMailer.send_reports
    end
    
    it 'should send a report email for a problem which has an operator email' do
      ProblemMailer.should_receive(:deliver_report).with(@mock_problem_email_operator, [@operator_with_mail], [])
      ProblemMailer.send_reports
    end  
    
    it 'should send a report for a problem with a PTE with an email address' do 
      ProblemMailer.should_receive(:deliver_report).with(@mock_problem_email_pte, [@pte_with_mail], [])
      ProblemMailer.send_reports
    end
    
    it 'should send a report for a problem with councils with email addresses' do 
      Council.stub!(:from_hash).and_return(@unemailable_council)
      Council.stub!(:from_hash).with({ 'name' => 'Emailable council' }).and_return(@emailable_council)
      ProblemMailer.should_receive(:deliver_report).with(@mock_problem_some_council_mails, 
                                                         [@emailable_council], 
                                                         [@unemailable_council])
      ProblemMailer.send_reports
    end
    
    it 'should set the "sent at" time on each problem report delivered' do 
      @mock_problem_email_operator.should_receive(:update_attribute).with(:sent_at, anything)
      @mock_problem_email_pte.should_receive(:update_attribute).with(:sent_at, anything)
      ProblemMailer.send_reports
    end
    
    it 'should print the number of sent reports' do 
      STDERR.should_receive(:puts).with("Sent #{@sendable.size} reports")
      ProblemMailer.send_reports  
    end
    
    it 'should check for a change in the councils for the problem' do 
      ProblemMailer.should_receive(:check_for_council_change)
      ProblemMailer.send_reports
    end
  
    
    describe 'when in dryrun mode' do 
      
      it 'should print output for each message that would be sent' do 
        STDERR.should_receive(:puts).with("Would send the following:").exactly(@sendable.size).times
        ProblemMailer.send_reports(dryrun=true)
      end
      
      it 'should not send messages' do 
        ProblemMailer.should_not_receive(:deliver_report)
        ProblemMailer.send_reports(dryrun=true)
      end
      
      it 'should not update message attributes' do 
        @all.each do |problem|
          problem.should_not_receive(:update_attribute)
        end
        ProblemMailer.send_reports(dryrun=true)
      end
    
    end
  end
  
end