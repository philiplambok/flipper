require 'helper'
require 'rails'
require 'flipper/cloud'

RSpec.describe Flipper::Cloud::Engine do
  let(:env) do
    { "FLIPPER_CLOUD_TOKEN" => "ASDF" }
  end

  let(:application) do
    Class.new(Rails::Application) do
      config.eager_load = false
      config.logger = ActiveSupport::Logger.new($stdout)
    end
  end

  before do
    Rails.application = nil

    # Force loading of flipper to configure itself
    load 'flipper/cloud.rb'
  end

  it "initializes cloud configuration" do
    stub_request(:get, /flippercloud\.io/).to_return(status: 200, body: "{}")

    with_modified_env env do
      application.initialize!

      expect(Flipper.instance).to be_a(Flipper::Cloud::DSL)
      expect(Flipper.instance.instrumenter).to be(ActiveSupport::Notifications)
    end
  end

  context "with CLOUD_SYNC_SECRET" do
    before do
      env.update "FLIPPER_CLOUD_SYNC_SECRET" => "abc"
    end

    it "configures webhook app" do
      with_modified_env env do
        application.initialize!

        expect(find_route("/_flipper")).to be_a(ActionDispatch::Journey::Route)
      end
    end
  end

  context "without CLOUD_SYNC_SECRET" do
    it "does not configure webhook app" do
      with_modified_env env do
        application.initialize!

        expect(find_route("/_flipper")).to be(nil)
      end
    end
  end

  context "without FLIPPER_CLOUD_TOKEN" do
    it "gracefully skips configuring webhook app" do
      with_modified_env "FLIPPER_CLOUD_TOKEN" => nil do
        application.initialize!
        expect(silence { Flipper.instance }).to match(/Missing FLIPPER_CLOUD_TOKEN/)
        expect(Flipper.instance).to be_a(Flipper::DSL)
        expect(find_route("/_flipper")).to be(nil)
      end
    end
  end

  def find_route(path)
    # `routes.recognize_path` doesn't work with rack apps, so find route manually
    req = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method: "GET"))
    matched_route = nil
    application.routes.router.recognize(req) { |route,_| matched_route ||= route }

    matched_route
  end
end
