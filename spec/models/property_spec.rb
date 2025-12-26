require "rails_helper"

RSpec.describe Property, type: :model do
  describe "validations" do
    it "validates presence of title" do
      expect(build(:property, title: nil)).not_to be_valid
      expect(build(:property, title: "Casa en CDMX")).to be_valid
    end

    it "validates presence of price" do
      expect(build(:property, price: nil)).not_to be_valid
      expect(build(:property, price: 3_000_000)).to be_valid
    end

    it "validates price is greater than 0" do
      expect(build(:property, price: 0)).not_to be_valid
      expect(build(:property, price: -1000)).not_to be_valid
      expect(build(:property, price: 1_000_000)).to be_valid
    end

    it "validates presence of city" do
      expect(build(:property, city: nil)).not_to be_valid
      expect(build(:property, city: "CDMX")).to be_valid
    end

    it "validates bedrooms is non-negative when present" do
      expect(build(:property, bedrooms: nil)).to be_valid
      expect(build(:property, bedrooms: 0)).to be_valid
      expect(build(:property, bedrooms: 3)).to be_valid
      expect(build(:property, bedrooms: -1)).not_to be_valid
    end

    it "validates bathrooms is non-negative when present" do
      expect(build(:property, bathrooms: nil)).to be_valid
      expect(build(:property, bathrooms: 0)).to be_valid
      expect(build(:property, bathrooms: 2)).to be_valid
      expect(build(:property, bathrooms: -1)).not_to be_valid
    end

    it "validates property_type inclusion when present" do
      expect(build(:property, property_type: nil)).to be_valid
      expect(build(:property, property_type: "casa")).to be_valid
      expect(build(:property, property_type: "departamento")).to be_valid
      expect(build(:property, property_type: "terreno")).to be_valid
      expect(build(:property, property_type: "invalid")).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:active_cdmx) { create(:property, city: "CDMX", active: true) }
    let!(:inactive_cdmx) { create(:property, city: "CDMX", active: false) }
    let!(:active_gdl) { create(:property, :in_guadalajara, active: true) }

    describe ".active" do
      it "returns only active properties" do
        expect(Property.active).to include(active_cdmx, active_gdl)
        expect(Property.active).not_to include(inactive_cdmx)
      end
    end

    describe ".in_city" do
      it "returns properties in the specified city (case-insensitive)" do
        expect(Property.in_city("CDMX")).to include(active_cdmx, inactive_cdmx)
        expect(Property.in_city("cdmx")).to include(active_cdmx, inactive_cdmx)
        expect(Property.in_city("CDMX")).not_to include(active_gdl)
      end
    end

    describe ".price_range" do
      let!(:cheap) { create(:property, price: 1_000_000) }
      let!(:mid) { create(:property, price: 3_000_000) }
      let!(:expensive) { create(:property, price: 5_000_000) }

      it "returns properties within price range" do
        results = Property.price_range(2_000_000, 4_000_000)
        expect(results).to include(mid)
        expect(results).not_to include(cheap, expensive)
      end
    end

    describe ".min_bedrooms" do
      let!(:one_bed) { create(:property, bedrooms: 1) }
      let!(:two_bed) { create(:property, bedrooms: 2) }
      let!(:three_bed) { create(:property, bedrooms: 3) }

      it "returns properties with at least specified bedrooms" do
        results = Property.min_bedrooms(2)
        expect(results).to include(two_bed, three_bed)
        expect(results).not_to include(one_bed)
      end
    end
  end

  describe ".search_by_profile" do
    let!(:cdmx_2bed_3m) { create(:property, city: "CDMX", bedrooms: 2, price: 3_000_000, active: true) }
    let!(:cdmx_3bed_4m) { create(:property, city: "CDMX", bedrooms: 3, price: 4_000_000, active: true) }
    let!(:gdl_2bed_2_5m) { create(:property, :in_guadalajara, bedrooms: 2, price: 2_500_000, active: true) }
    let!(:cdmx_inactive) { create(:property, city: "CDMX", bedrooms: 2, price: 3_000_000, active: false) }

    it "returns none when city is missing" do
      profile = { "bedrooms" => 2, "budget" => 3_000_000 }
      expect(Property.search_by_profile(profile)).to be_empty
    end

    it "returns properties matching city (active only)" do
      profile = { "city" => "CDMX" }
      results = Property.search_by_profile(profile)
      expect(results).to include(cdmx_2bed_3m, cdmx_3bed_4m)
      expect(results).not_to include(gdl_2bed_2_5m, cdmx_inactive)
    end

    it "filters by minimum bedrooms when specified" do
      profile = { "city" => "CDMX", "bedrooms" => 3 }
      results = Property.search_by_profile(profile)
      expect(results).to include(cdmx_3bed_4m)
      expect(results).not_to include(cdmx_2bed_3m)
    end

    it "filters by budget with 20% flexibility" do
      profile = { "city" => "CDMX", "budget" => 3_000_000 }
      # 20% flexibility: 2.4M - 3.6M
      results = Property.search_by_profile(profile)
      expect(results).to include(cdmx_2bed_3m)  # 3M is within range
      expect(results).not_to include(cdmx_3bed_4m)  # 4M is above range
    end

    it "combines city, bedrooms, and budget filters" do
      profile = { "city" => "CDMX", "bedrooms" => 2, "budget" => 3_000_000 }
      results = Property.search_by_profile(profile)
      expect(results).to include(cdmx_2bed_3m)
      expect(results).not_to include(cdmx_3bed_4m, gdl_2bed_2_5m)
    end

    it "handles case-insensitive city search" do
      profile = { "city" => "cdmx" }
      results = Property.search_by_profile(profile)
      expect(results).to include(cdmx_2bed_3m, cdmx_3bed_4m)
    end
  end
end
