require('spec_helper')
require('ddtrace/sampler')
RSpec.describe Datadog::RateByServiceSampler do
  MAX_DEVIATION = 0.3
  ITERATIONS_PER_SERVICE = 1000
  DEFAULT_RATE = 0.5
  before do
    @rates = {
      'service:a,env:test' => 1.0,
      'service:b,env:test' => 0.5,
      'service:c,env:test' => 0.25,
      'service:d,env:test' => 0.1
    }
    @sampler = Datadog::RateByServiceSampler.new(DEFAULT_RATE, env: :test)
    @sampler.update(@rates)
  end
  it('sampling') do
    counter = Hash.new(0)
    @rates.each do |service_key, _|
      ITERATIONS_PER_SERVICE.times do
        span = span_for(service_key)
        @sampler.sample(span)
        counter[service_key] += 1 if span.sampled
      end
    end
    @rates.each do |service_key, sampling_rate|
      sample_expect = (sampling_rate * ITERATIONS_PER_SERVICE)
      assert_in_epsilon(counter[service_key], sample_expect, MAX_DEVIATION)
    end
  end
  it('sampling fallback') do
    counter = 0
    ITERATIONS_PER_SERVICE.times do
      span = Span.new(nil, nil, service: 'foo_service')
      @sampler.sample(span)
      counter = (counter + 1) if span.sampled
    end
    assert_in_epsilon(counter, (DEFAULT_RATE * ITERATIONS_PER_SERVICE), MAX_DEVIATION)
  end
  it('fallback update') do
    counter = 0
    rate = 0.2
    @sampler.update('service:,env:' => rate)
    ITERATIONS_PER_SERVICE.times do
      span = Span.new(nil, nil, service: 'foo_service')
      @sampler.sample(span)
      counter = (counter + 1) if span.sampled
    end
    assert_in_epsilon(counter, (rate * ITERATIONS_PER_SERVICE), MAX_DEVIATION)
  end

    private

  def span_for(service_key)
    name = service_name(service_key)
    Span.new(nil, nil, service: name)
  end

  def service_name(service_key)
    service_key.match(/service:(?<name>.)/)[:name]
  end
end
