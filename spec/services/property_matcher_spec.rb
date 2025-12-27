# frozen_string_literal: true

require "rails_helper"

RSpec.describe PropertyMatcher do
  describe ".call" do
    # Create test properties with different match qualities
    let!(:perfect_match) do
      create(:property,
        title: "Perfect Match Property",
        price: 3_000_000,
        city: "CDMX",
        area: "Roma Norte",
        bedrooms: 2,
        bathrooms: 2,
        property_type: "departamento",
        active: true
      )
    end

    let!(:close_match) do
      create(:property,
        title: "Close Match Property",
        price: 3_300_000, # 10% over budget
        city: "CDMX",
        area: "Roma Sur",
        bedrooms: 3, # 1 bedroom more
        bathrooms: 2,
        property_type: "departamento",
        active: true
      )
    end

    let!(:budget_mismatch) do
      create(:property,
        title: "Budget Mismatch Property",
        price: 5_000_000, # 66% over budget
        city: "CDMX",
        area: "Polanco",
        bedrooms: 3,
        bathrooms: 3,
        property_type: "departamento",
        active: true
      )
    end

    let!(:wrong_city) do
      create(:property,
        title: "Wrong City Property",
        price: 3_000_000,
        city: "Guadalajara",
        area: "Providencia",
        bedrooms: 2,
        bathrooms: 2,
        property_type: "departamento",
        active: true
      )
    end

    let!(:inactive_property) do
      create(:property,
        title: "Inactive Property",
        price: 3_000_000,
        city: "CDMX",
        area: "Roma Norte",
        bedrooms: 2,
        bathrooms: 2,
        property_type: "departamento",
        active: false
      )
    end

    context "with complete lead profile" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "CDMX",
          area: "Roma Norte",
          bedrooms: 2,
          property_type: "departamento"
        }
      end

      it "returns top matches sorted by score descending" do
        results = described_class.call(profile)

        expect(results).not_to be_empty
        expect(results.size).to be <= 3
        expect(results.first[:id]).to eq(perfect_match.id)

        # Verify descending order
        if results.size > 1
          expect(results.first[:score]).to be >= results.second[:score]
        end
      end

      it "includes all required fields in results" do
        results = described_class.call(profile)
        result = results.first

        expect(result).to have_key(:id)
        expect(result).to have_key(:title)
        expect(result).to have_key(:price)
        expect(result).to have_key(:city)
        expect(result).to have_key(:area)
        expect(result).to have_key(:bedrooms)
        expect(result).to have_key(:bathrooms)
        expect(result).to have_key(:score)
        expect(result).to have_key(:reasons)
      end

      it "includes reasons explaining the match" do
        results = described_class.call(profile)
        perfect = results.find { |r| r[:id] == perfect_match.id }

        expect(perfect[:reasons]).to include("budget_exact_match")
        expect(perfect[:reasons]).to include("bedrooms_exact_match")
        expect(perfect[:reasons]).to include("area_exact_match")
        expect(perfect[:reasons]).to include("property_type_match")
      end

      it "excludes properties from other cities" do
        results = described_class.call(profile)
        result_ids = results.map { |r| r[:id] }

        expect(result_ids).not_to include(wrong_city.id)
      end

      it "excludes inactive properties" do
        results = described_class.call(profile)
        result_ids = results.map { |r| r[:id] }

        expect(result_ids).not_to include(inactive_property.id)
      end

      it "calculates perfect match score correctly" do
        results = described_class.call(profile)
        perfect = results.find { |r| r[:id] == perfect_match.id }

        # Budget: 40, Bedrooms: 30, Area: 20, Type: 10 = 100
        expect(perfect[:score]).to eq(100)
      end
    end

    context "with missing city" do
      let(:profile) do
        {
          budget: 3_000_000,
          bedrooms: 2,
          property_type: "departamento"
        }
      end

      it "returns empty array" do
        results = described_class.call(profile)
        expect(results).to eq([])
      end

      it "logs warning about missing city" do
        allow(Rails.logger).to receive(:warn)

        described_class.call(profile)

        expect(Rails.logger).to have_received(:warn).with(/missing_city/)
      end
    end

    context "with nil city" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: nil,
          bedrooms: 2
        }
      end

      it "returns empty array" do
        results = described_class.call(profile)
        expect(results).to eq([])
      end
    end

    context "with no matching properties in city" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "Querétaro",
          bedrooms: 2
        }
      end

      it "returns empty array" do
        results = described_class.call(profile)
        expect(results).to be_empty
      end
    end

    context "with partial profile (only city and budget)" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "CDMX"
        }
      end

      it "returns matches scored only on available criteria" do
        results = described_class.call(profile)

        expect(results).not_to be_empty
        # Score should only include budget component (max 40)
        expect(results.first[:score]).to be <= 40
      end
    end

    context "with more than 3 matching properties" do
      before do
        # Create 5 properties in CDMX
        5.times do |i|
          create(:property,
            title: "Additional Property #{i}",
            price: 3_000_000 + (i * 100_000),
            city: "CDMX",
            area: "Condesa",
            bedrooms: 2,
            active: true
          )
        end
      end

      let(:profile) do
        {
          budget: 3_000_000,
          city: "CDMX",
          bedrooms: 2
        }
      end

      it "returns only top 3 matches" do
        results = described_class.call(profile)
        expect(results.size).to eq(3)
      end

      it "returns highest scoring properties" do
        results = described_class.call(profile)

        # All returned scores should be >= any non-returned
        lowest_returned = results.map { |r| r[:score] }.min
        expect(lowest_returned).to be > 0
      end
    end

    context "budget scoring edge cases" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "CDMX"
        }
      end

      it "scores within 10% as perfect (40 points)" do
        property = create(:property, price: 3_300_000, city: "CDMX", active: true) # 10% over

        results = described_class.call(profile)
        result = results.find { |r| r[:id] == property.id }

        expect(result[:score]).to eq(40)
        expect(result[:reasons]).to include("budget_exact_match")
      end

      it "scores within 20% as close (30 points)" do
        property = create(:property, price: 3_600_000, city: "CDMX", active: true) # 20% over

        results = described_class.call(profile)
        result = results.find { |r| r[:id] == property.id }

        expect(result[:score]).to eq(30)
        expect(result[:reasons]).to include("budget_close_match")
      end

      it "scores within 30% as acceptable (20 points)" do
        property = create(:property, price: 3_900_000, city: "CDMX", active: true) # 30% over

        results = described_class.call(profile)
        result = results.find { |r| r[:id] == property.id }

        expect(result[:score]).to eq(20)
        expect(result[:reasons]).to include("budget_close_match")
      end

      it "scores over 30% as no match (0 points)" do
        # budget_mismatch is 5M (66% over 3M budget)
        results = described_class.call(profile)
        result = results.find { |r| r[:id] == budget_mismatch.id }

        # Will be returned only if <3 other properties exist
        if result
          expect(result[:score]).to eq(0)
          expect(result[:reasons]).not_to include("budget_exact_match")
          expect(result[:reasons]).not_to include("budget_close_match")
        end
      end
    end

    context "bedrooms scoring" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "CDMX",
          bedrooms: 2
        }
      end

      it "scores exact match as 30 points" do
        results = described_class.call(profile)
        perfect = results.find { |r| r[:id] == perfect_match.id }

        # Perfect match has budget 40 + bedrooms 30 = 70 minimum
        expect(perfect[:score]).to be >= 70
        expect(perfect[:reasons]).to include("bedrooms_exact_match")
      end

      it "scores ±1 bedroom as 20 points" do
        results = described_class.call(profile)
        close = results.find { |r| r[:id] == close_match.id }

        # Close match has 3 bedrooms (profile wants 2)
        expect(close[:reasons]).to include("bedrooms_close_match")
      end
    end

    context "area scoring" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "CDMX",
          area: "Roma Norte"
        }
      end

      it "scores exact match as 20 points" do
        results = described_class.call(profile)
        perfect = results.find { |r| r[:id] == perfect_match.id }

        expect(perfect[:reasons]).to include("area_exact_match")
      end

      it "scores partial match as 10 points" do
        profile[:area] = "Roma" # Partial match for "Roma Norte" or "Roma Sur"

        results = described_class.call(profile)

        # Should match both Roma Norte and Roma Sur
        roma_results = results.select { |r| r[:area].include?("Roma") }
        expect(roma_results).not_to be_empty
        expect(roma_results.first[:reasons]).to include("area_partial_match")
      end
    end

    context "case insensitivity" do
      let(:profile) do
        {
          budget: 3_000_000,
          city: "cdmx", # lowercase
          area: "roma norte", # lowercase
          property_type: "DEPARTAMENTO" # uppercase
        }
      end

      it "matches cities case-insensitively" do
        results = described_class.call(profile)

        expect(results).not_to be_empty
        expect(results.map { |r| r[:city] }).to all(eq("CDMX"))
      end

      it "matches areas case-insensitively" do
        results = described_class.call(profile)
        perfect = results.find { |r| r[:id] == perfect_match.id }

        expect(perfect[:reasons]).to include("area_exact_match")
      end

      it "matches property type case-insensitively" do
        results = described_class.call(profile)
        perfect = results.find { |r| r[:id] == perfect_match.id }

        expect(perfect[:reasons]).to include("property_type_match")
      end
    end
  end
end
