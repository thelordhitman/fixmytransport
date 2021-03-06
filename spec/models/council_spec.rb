require 'spec_helper'

describe Council do

  before do
    @council = Council.from_hash({ 'id' => 22, 'name' => 'A Test Council' })
  end

  it 'should create an instance from a hash keyed by strings' do
    @council.id.should == 22
    @council.name.should == 'A Test Council'
  end

  it 'should be able to respond to calls to emailable?' do
    @council.stub!(:contacts).and_return([mock_model(CouncilContact)])
    @council.emailable?(mock_model(Stop)).should be_true
    @council.stub!(:contacts).and_return([])
    @council.emailable?(mock_model(Stop)).should be_false
  end

  describe 'when asked for all councils' do

    before do
      MySociety::MaPit.stub!(:call).and_return({44 => {'name' => 'A council', 'id' => 44}})
    end

    it 'should map a hash of data returned by MaPit into model instances' do
      councils = Council.find_all()
      councils.first.name.should == 'A council'
      councils.first.id.should == 44
      councils.first.is_a?(Council).should == true
    end

  end
  
  describe 'when asked for all councils without PTEs' do 
  
    before do 
      pte_area = mock_model(PassengerTransportExecutiveArea, :area_id => 44)
      PassengerTransportExecutiveArea.stub!(:find).and_return([pte_area])
      MySociety::MaPit.stub!(:call).and_return({44 => {'name' => 'A council', 'id' => 44}})
    end
  
    it 'should not return any council whose area is covered by a PTE' do 
      councils = Council.find_all_without_ptes()
      councils.size.should == 0
    end
  
  end

  describe 'when asked for a contact for a problem category' do

    before do
      @mock_stop = mock_model(Stop)
      @location_category_contact = mock_model(CouncilContact, :category => "Test category",
                                                              :email => "test@example.com",
                                                              :district_id => 55)
      @location_other_contact = mock_model(CouncilContact, :category => "Other",
                                                           :email => "test@example.com",
                                                           :district_id => 55)
      @other_contact = mock_model(CouncilContact, :category => 'Other',
                                                  :email => 'other@example.com')
      @unrelated_contact = mock_model(CouncilContact, :category => 'Unrelated',
                                                      :email => 'unrelated@example.com')
      @category_contact = mock_model(CouncilContact, :category => 'Test category',
                                                     :email => 'test@example.com')
    end

    it 'should return the location-specific category contact if there is one' do
      @council.stub!(:contacts_for_location).with(@mock_stop).and_return([@location_other_contact,
                                                                          @location_category_contact])
      @council.contact_for_category_and_location('Test category', @mock_stop).should == @location_category_contact
    end

    it 'should return the location-specific "Other" contact if there is no location specific category contact' do
      @council.stub!(:contacts_for_location).with(@mock_stop).and_return([@location_other_contact])
      @council.contact_for_category_and_location('Test category', @mock_stop).should == @location_other_contact
    end

    it 'should return the general contact for the category if there is no location specific category or "Other" contact' do
      @council.stub!(:contacts_for_location).with(@mock_stop).and_return([])
      @council.stub!(:general_contacts).and_return([@unrelated_contact,
                                                                     @other_contact,
                                                                     @category_contact])
       @council.contact_for_category_and_location('Test category', @mock_stop).should == @category_contact
    end

    it 'should return the general contact for the contact for category "other" if there is no contact for the category passed or location-specific contact' do
      @council.stub!(:contacts_for_location).with(@mock_stop).and_return([])
      @council.stub!(:general_contacts).and_return([@unrelated_contact,
                                                                     @other_contact])
      @council.contact_for_category_and_location('Test category', @mock_stop).should == @other_contact
    end

    it 'should raise an error if there is no contact for the category or for "other"' do
      @council.stub!(:contacts_for_location).with(@mock_stop).and_return([])
      @council.stub!(:general_contacts).and_return([@unrelated_contact])
      lambda{ @council.contact_for_category_and_location('Test category', @mock_stop) }.should raise_error('No "Other" category contact for A Test Council (area ID: 22)')
    end

  end

end
