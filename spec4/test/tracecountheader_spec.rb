require('helper')
require('ddtrace')
require('ddtrace/tracer')
require('stringio')
require('thread')
require('webrick')
class TraceCountHeaderTest < Minitest::Test
  TEST_PORT = 6218
  before do
    @log_buf = StringIO.new
    log = WEBrick::Log.new(@log_buf)
    access_log = [[@log_buf, WEBrick::AccessLog::COMBINED_LOG_FORMAT]]
    @server = WEBrick::HTTPServer.new(Port: TEST_PORT, Logger: log, AccessLog: access_log)
    @server.mount_proc('/') do |req, res|
      res.body = '{}'
      trace_count = req.header['x-datadog-trace-count']
      if trace_count.nil? || (trace_count.empty? || ((trace_count[0].to_i < 1) || (trace_count[0].to_i > 2)))
        raise("bad trace count header: #{trace_count}")
      end
    end
  end
  it('agent receives span') do
    begin
      (@thread = Thread.new { @server.start }
       tracer = Datadog::Tracer.new
       tracer.configure(enabled: true, hostname: '127.0.0.1', port: TEST_PORT)
       tracer.trace('op1') do |span|
         span.service = 'my.service'
         sleep(0.001)
       end
       tracer.trace('op2') do |span|
         span.service = 'my.service'
         tracer.trace('op3') { true }
       end
       test_repeat.times do
         break if tracer.writer.stats[:traces_flushed] >= 2
         sleep(0.1)
       end
       stats = tracer.writer.stats
       expect(stats[:traces_flushed]).to(eq(2))
       expect(stats[:transport][:client_error]).to(eq(0))
       expect(stats[:transport][:server_error]).to(eq(0))
       expect(stats[:transport][:internal_error]).to(eq(0)))
    ensure
      @server.shutdown
    end
  end
end
