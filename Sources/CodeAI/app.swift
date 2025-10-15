import Vapor

@main
struct Entrypoint
{
  // Use synchronous main to avoid Swift 6 async initializer restrictions
  static func main() throws
  {
    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)

    let app = Application(env)
    defer { app.shutdown() }

    try configure(app)

    // Use the synchronous run method (classic Vapor pattern)
    try app.run()
  }
}
