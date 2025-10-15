import Vapor

public func configure(_ app: Application) throws
{
  // Configure middleware
  app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
  app.middleware.use(ErrorMiddleware.default(environment: app.environment))

  // Register routes
  try routes(app)
}
