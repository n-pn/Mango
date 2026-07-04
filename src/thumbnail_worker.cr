# ThumbnailWorker runs thumbnail generation in a dedicated OS thread so the
# Kemal/fiber event loop is never blocked by CPU-bound image resizing.
#
# Design:
#   - A single worker thread is used intentionally. On a low-power quad-core
#     like the Intel N5095, a single background thread keeps one CPU core busy
#     on thumbnails while the other cores remain available for the web server
#     and OS tasks. Parallel thumbnail workers would thrash disk I/O on slow
#     storage and cause thermal throttling.
#   - Jobs are queued in a bounded channel (capacity 200). If the queue fills
#     up, `enqueue` blocks the caller — this is intentional backpressure.
#   - Each job carries a `done` channel so callers can optionally await
#     completion (synchronous) or fire-and-forget via `spawn`.

class ThumbnailWorker
  alias Job = NamedTuple(entry: Entry, done: Channel(Nil))

  use_default

  @channel : Channel(Job?)
  @thread : Thread?

  def initialize
    @channel = Channel(Job?).new(capacity: 200)
    start_worker_thread
  end

  # Enqueue an entry for thumbnail generation and return a channel that will
  # receive a value when the job is complete. The caller can choose to:
  #
  #   - Await completion:    worker.enqueue(entry).receive
  #   - Fire and forget:     spawn { worker.enqueue(entry).receive }
  def enqueue(entry : Entry) : Channel(Nil)
    done = Channel(Nil).new(1)
    @channel.send({entry: entry, done: done})
    done
  end

  # Gracefully stop the worker thread. Waits for the current job (if any)
  # to finish before the thread exits.
  def stop
    @channel.send nil
    @thread.try &.join
  end

  private def start_worker_thread
    @thread = Thread.new do
      Logger.debug "ThumbnailWorker: worker thread started (tid=#{Thread.current.object_id})"
      loop do
        job = @channel.receive
        # nil is the sentinel value signalling shutdown
        break if job.nil?

        entry = job[:entry]
        begin
          Logger.debug "ThumbnailWorker: generating thumbnail for #{entry.path}"
          entry.generate_thumbnail
        rescue e
          Logger.warn "ThumbnailWorker: failed for #{entry.path} — #{e}"
        ensure
          # Always signal completion so waiting fibers are unblocked
          job[:done].send nil
        end
      end
      Logger.debug "ThumbnailWorker: worker thread stopped"
    end
  end
end
