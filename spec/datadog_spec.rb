# frozen_string_literal: true

require "racecar/datadog"
RSpec.describe Racecar::Datadog::StatsdSubscriber do
  describe '#emit' do
    let(:subscriber)  { Racecar::Datadog::StatsdSubscriber.new }
    let(:tags)        { { tag_1: 'race', tag_2: 'car'} }

    it 'publishes stats with tags' do
      expect(Racecar::Datadog.statsd).
        to receive(:increment).
        with('metric', tags: ['tag_1:race', 'tag_2:car'])

      subscriber.send(:emit, :increment, 'metric', tags: tags)
    end
  end
end

def create_event(name, payload = {})
  Timecop.freeze do
    start = Time.now - 2
    ending = Time.now - 1

    transaction_id = nil

    args = [name, start, ending, transaction_id, payload]

    ActiveSupport::Notifications::Event.new(*args)
  end
end

RSpec.describe Racecar::Datadog::ConsumerSubscriber do
  before do
    %w[increment histogram count timing gauge].each do |type|
      allow(statsd).to receive(type)
    end
  end
  let(:subscriber)  { Racecar::Datadog::ConsumerSubscriber.new }
  let(:statsd)      { Racecar::Datadog.statsd }

  describe '#process_message' do
    let(:event) do
      create_event(
        'process_message',
        client_id:      'racecar',
        group_id:       'test_group',
        consumer_class: 'TestConsumer',
        topic:          'test_topic',
        partition:      1,
        offset:         2,
        create_time:    Time.now - 1,
        key:            'key',
        value:          'nothing new',
        headers:        {}
      )
    end
    let(:duration) { 1000.0 }
    let(:metric_tags) do
      %w[
          client:racecar
          group_id:test_group
          topic:test_topic
          partition:1
        ]
    end

    it 'publishes latency' do
      expect(statsd).
        to receive(:timing).
        with('consumer.process_message.latency', duration, tags: metric_tags)

      subscriber.process_message(event)
    end

    it 'gauges offset' do
      expect(statsd).
        to receive(:gauge).
        with('consumer.offset', 2, tags: metric_tags)

      subscriber.process_message(event)
    end

    it 'gauges time lag' do
      expect(statsd).
        to receive(:gauge).
        with('consumer.time_lag', 1000, tags: metric_tags)

      subscriber.process_message(event)
    end
  end

  describe '#process_batch' do
    let(:event) do
      create_event(
        'process_batch',
        client_id:      'racecar',
        group_id:       'test_group',
        consumer_class: 'TestConsumer',
        topic:          'test_topic',
        partition:      1,
        first_offset:   3,
        last_offset:    10,
        last_create_time: Time.now,
        message_count:  20,
      )
    end
    let(:duration) { 1000.0 }
    let(:metric_tags) do
      %w[
          client:racecar
          group_id:test_group
          topic:test_topic
          partition:1
        ]
    end

    it 'publishes latency' do
      expect(statsd).
        to receive(:timing).
        with('consumer.process_batch.latency', duration, tags: metric_tags)

      subscriber.process_batch(event)
    end

    it 'publishes batch count' do
      expect(statsd).
        to receive(:count).
        with('consumer.messages', 20, tags: metric_tags)

      subscriber.process_batch(event)
    end

    it 'gauges offset' do
      expect(statsd).
        to receive(:gauge).
        with('consumer.offset', 10, tags: metric_tags)

      subscriber.process_batch(event)
    end
  end

  describe '#join_group' do
    let(:event) do
      create_event(
        'join_group',
        client_id:      'racecar',
        group_id:       'test_group',
      )
    end
    let(:duration) { 1000.0 }
    let(:metric_tags) do
      %w[
          client:racecar
          group_id:test_group
        ]
    end

    it 'publishes latency' do
      expect(statsd).
        to receive(:timing).
        with('consumer.join_group', duration, tags: metric_tags)

      subscriber.join_group(event)
    end
  end

  describe '#leave_group' do
    let(:event) do
      create_event(
        'leave_group',
        client_id:      'racecar',
        group_id:       'test_group',
      )
    end
    let(:duration) { 1000.0 }
    let(:metric_tags) do
      %w[
          client:racecar
          group_id:test_group
        ]
    end

    it 'publishes latency' do
      expect(statsd).
        to receive(:timing).
        with('consumer.leave_group', duration, tags: metric_tags)

      subscriber.leave_group(event)
    end
  end

  describe '#main_loop' do
    let(:event) do
      create_event(
        'main_loop',
        client_id:      'racecar',
        group_id:       'test_group',
      )
    end
    let(:duration) { 1000.0 }
    let(:metric_tags) do
      %w[
          client:racecar
          group_id:test_group
        ]
    end

    it 'publishes loop duration' do
      expect(statsd).
        to receive(:histogram).
        with('consumer.loop.duration', duration, tags: metric_tags)

      subscriber.main_loop(event)
    end
  end

  describe '#pause_status' do
    let(:event) do
      create_event(
        'main_loop',
        client_id: 'racecar',
        group_id:  'test_group',
        topic:     'test_topic',
        partition: 1,
        duration:  10,
      )
    end
    let(:metric_tags) do
      %w[
          client:racecar
          group_id:test_group
          topic:test_topic
          partition:1
        ]
    end

    it 'gauges pause duration' do
      expect(statsd).
        to receive(:gauge).
        with('consumer.pause.duration', 10, tags: metric_tags)

      subscriber.pause_status(event)
    end
  end
end

RSpec.describe Racecar::Datadog::ProducerSubscriber do
  before do
    %w[increment histogram count timing gauge].each do |type|
      allow(statsd).to receive(type)
    end
  end
  let(:subscriber)  { Racecar::Datadog::ProducerSubscriber.new }
  let(:statsd)      { Racecar::Datadog.statsd }

  describe '#produce_message' do
    let(:event) do
      create_event(
        'produce_message',
        client_id:      'racecar',
        group_id:       'test_group',
        topic:          'test_topic',
        message_size:   12,
        buffer_size:    10
      )
    end
    let(:metric_tags) do
      %w[
          client:racecar
          topic:test_topic
        ]
    end

    it 'increments number of produced messages' do
      expect(statsd).
        to receive(:increment).
        with('producer.produce.messages', tags: metric_tags)

      subscriber.produce_message(event)
    end

    it 'publishes message size' do
      expect(statsd).
        to receive(:histogram).
        with('producer.produce.message_size', 12, tags: metric_tags)

      subscriber.produce_message(event)
    end

    it 'aggregates message size' do
      expect(statsd).
        to receive(:count).
        with('producer.produce.message_size.sum', 12, tags: metric_tags)

      subscriber.produce_message(event)
    end

    it 'publishes buffer size' do
      expect(statsd).
        to receive(:histogram).
        with('producer.buffer.size', 10, tags: metric_tags)

      subscriber.produce_message(event)
    end
  end

  describe '#deliver_messages' do
    let(:event) do
      create_event(
        'deliver_messages',
        client_id:      'racecar',
        delivered_message_count: 10
      )
    end
    let(:duration) { 1000.0 }
    let(:metric_tags) do
      %w[
          client:racecar
        ]
    end

    it 'publishes delivery latency' do
      expect(statsd).
        to receive(:timing).
        with('producer.deliver.latency', duration, tags: metric_tags)

      subscriber.deliver_messages(event)
    end

    it 'publishes message size' do
      expect(statsd).
        to receive(:count).
        with('producer.deliver.messages', 10, tags: metric_tags)

      subscriber.deliver_messages(event)
    end
  end

  describe '#acknowledged_message' do
    let(:event) do
      create_event(
        'deliver_messages',
        client_id: 'racecar',
        delivered_message_count: 10
      )
    end
    let(:metric_tags) do
      %w[
          client:racecar
        ]
    end

    it 'publishes number of acknowledged messages' do
      expect(statsd).
        to receive(:increment).
        with('producer.ack.messages', tags: metric_tags)

      subscriber.acknowledged_message(event)
    end
  end
end
