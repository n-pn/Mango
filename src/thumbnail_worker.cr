# ThumbnailWorker serialises thumbnail generation in a dedicated fiber.
#
# Why a dedicated fiber instead of inline generation?
#   - Prevents multiple concurrent ImageMagick processes from spawning
#     simultaneously when many cover requests arrive at once.
#   - Ensures the bulk generation loop in Library does not skip entries
#     because a previous ImageMagick process is still running.
#
# Why NOT a separate OS Thread (Thread.new)?
#   - Crystal's Channel and fiber scheduler are NOT thread-safe without
#     the -Dpreview_mt compile flag.
#   - Using Thread.new without preview_mt causes the "can't resume a
#     running fiber" crash seen previously.
#
# How does this keep the HTTP event loop responsive?
#   - generate_thumbnail calls Process.run which pipes data to/from
#     ImageMagick via non-blocking I/O. While waiting for the subprocess,
#     the Crystal fiber scheduler runs other fibers (HTTP handlers, etc).
#   - The event loop is therefore never blocked by CPU-bound image work.

class ThumbnailWorker
  alias Job = NamedTuple(entry: Entry, done: Channel(Nil))

  use_default

  @channel : Channel(Job?)

  def initialize
    @channel = Channel(Job?).new(capacity: 200)
    start_worker_fiber
  end

  # Enqueues an entry for thumbnail generation and returns a channel that
  # will receive a value when the job completes. The caller can:
  #
  #   - Await synchronously:  worker.enqueue(entry).receive
  #   - Fire and forget:      worker.enqueue(entry)
  def enqueue(entry : Entry) : Channel(Nil)
    done = Channel(Nil).new(1)
    @channel.send({entry: entry, done: done})
    done
  end

  # Signals the worker fiber to stop after finishing the current job.
  def stop
    @channel.send nil
  end

  private def start_worker_fiber
    spawn(name: "thumbnail_worker") do
      Logger.debug "ThumbnailWorker: worker fiber started"
      loop do
        job = @channel.receive
        break if job.nil?

        entry = job[:entry]
        begin
          Logger.debug "ThumbnailWorker: generating thumbnail for #{entry.path}"
          entry.generate_thumbnail
        rescue e
          Logger.warn "ThumbnailWorker: failed for #{entry.path} — #{e}"
        ensure
          job[:done].send nil
        end
      end
      Logger.debug "ThumbnailWorker: worker fiber stopped"
    end
  end
end
