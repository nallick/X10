# X10

Provides X10 home automation formatting and state management. State changes are provided via NotificationManager notifications, and a X10 hardware interface which implements a simple protocol can be connected. In addition, expected X10 devices and scenes can be provided as an environment file to keep the state as accurate as possible.

### Use:

To add X10 to your project, declare a dependency in your Package.swift file,
````
.package(url: "https://github.com/nallick/X10.git", from: "1.0.0"),
````
and add the dependency to your target:
````
.target(name: "MyProjectTarget", dependencies: ["X10"]),
````
