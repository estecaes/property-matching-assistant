require 'rails_helper'

RSpec.describe 'Logging Configuration' do
  it 'uses JSON formatter in development' do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    logger.formatter = Rails.application.config.log_formatter

    logger.info('test message')

    log_line = output.string
    parsed = JSON.parse(log_line)
    expect(parsed).to have_key('timestamp')
    expect(parsed).to have_key('severity')
    expect(parsed).to have_key('message')
  end
end
