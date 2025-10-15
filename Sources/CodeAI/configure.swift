import Vapor

public func configure(_ app: Application) throws {
  // Configure middleware
  app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
  app.middleware.use(ErrorMiddleware.default(environment: app.environment))

  let host = Environment.get("HOST") ?? "0.0.0.0"
  let portString = Environment.get("PORT") ?? "5000" // Default to 5000 for Docker
  let port = Int(portString) ?? 5000

  // Configure the server explicitly
  app.http.server.configuration.hostname = host
  app.http.server.configuration.port = port

  // Register routes
  try routes(app)
  app.logger.info("Server configured on \(host):\(port)")
}
