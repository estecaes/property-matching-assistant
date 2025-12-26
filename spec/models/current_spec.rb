# frozen_string_literal: true

require "rails_helper"

RSpec.describe Current, type: :model do
  # Ensure Current is reset after each test to prevent state leakage
  after { Current.reset }

  describe ".scenario" do
    it "stores and retrieves scenario value" do
      Current.scenario = "budget_seeker"
      expect(Current.scenario).to eq("budget_seeker")
    end

    it "returns nil when not set" do
      expect(Current.scenario).to be_nil
    end

    it "can be reset" do
      Current.scenario = "budget_seeker"
      Current.reset
      expect(Current.scenario).to be_nil
    end
  end

  describe "thread isolation" do
    it "maintains separate values across threads" do
      Current.scenario = "main_thread"

      thread_value = nil
      thread = Thread.new do
        Current.scenario = "other_thread"
        thread_value = Current.scenario
      end
      thread.join

      # Main thread value should be unchanged
      expect(Current.scenario).to eq("main_thread")
      # Other thread had its own value
      expect(thread_value).to eq("other_thread")
    end

    it "does not leak values between threads" do
      Current.scenario = "parent_scenario"

      child_saw_value = false
      thread = Thread.new do
        # Child thread should not see parent's value
        child_saw_value = Current.scenario.present?
      end
      thread.join

      expect(child_saw_value).to be(false)
    end

    it "handles concurrent thread access safely" do
      threads = 10.times.map do |i|
        Thread.new do
          Current.scenario = "thread_#{i}"
          sleep 0.01 # Simulate work
          Current.scenario
        end
      end

      results = threads.map(&:value)

      # Each thread should have retrieved its own value
      10.times do |i|
        expect(results[i]).to eq("thread_#{i}")
      end
    end
  end

  describe "request isolation" do
    it "resets between requests" do
      Current.scenario = "first_request"
      expect(Current.scenario).to eq("first_request")

      Current.reset
      expect(Current.scenario).to be_nil

      Current.scenario = "second_request"
      expect(Current.scenario).to eq("second_request")
    end
  end
end
