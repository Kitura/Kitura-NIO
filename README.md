<p align="center">
<a href="http://kitura.io/">
<img src="https://raw.githubusercontent.com/IBM-Swift/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
</a>
</p>


<p align="center">
<img src="https://img.shields.io/badge/Swift-4.2-orange.svg?style=flat" alt="Swift 4.2">
<a href="https://www.kitura.io/packages.html#all">
<img src="https://img.shields.io/badge/docs-kitura.io-1FBCE4.svg" alt="Docs">
</a>
<a href="https://travis-ci.org/IBM-Swift/Kitura-NIO">
<img src="https://travis-ci.org/IBM-Swift/Kitura-NIO.svg?branch=master" alt="Build Status - Master">
</a>
<img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
<img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
<a href="http://swift-at-ibm-slack.mybluemix.net/">
<img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
</a>
</p>

# Kitura-NIO

Kitura-NIO is a SwiftNIO based networking library for Kitura. Other than an additive change to the HTTPServer API around IPv6 support, Kitura-NIO adopts the same API as KituraNet, making the transition to using the NIO port almost seamless. While Kitura-NIO shares some code with Kitura-Net, the core comprising of HTTPServer, ClientRequest/ClientResponse and TLS support have been implemented using SwiftNIO.

We expect most of our users to require higher level concepts such as routing, templates and middleware, these are not provided in Kitura-NIO, if you want to use those facilities you should be coding at the Kitura level, for this please see the [Kitura](https://github.com/IBM-Swift/Kitura) project. Kitura-NIO, like  Kitura-net, underpins Kitura which offers a higher abstraction level to users.

Kitura-NIO utilises [SwiftNIO](https://github.com/apple/swift-nio) and [NIOOpenSSL](https://github.com/apple/swift-nio-ssl). 

As of today, Kitura-NIO has been tested with Swift 4.1 only.

## Features

- Port Listening
- HTTP Server support (request and response)

## Using Kitura-NIO

To test your Kitura app with the very early version of the Kitura-NIO networking framework, all you need to do is point to the [kitura-nio](https://github.com/IBM-Swift/Kitura/tree/kitura-nio) branch from your `Package.swift`:

```swift
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/IBM-Swift/Kitura", .branch("kitura-nio")),
    ],
```

Kitura will then use Kitura-NIO instead of Kitura-net for, networking.

## Getting Started

Visit [www.kitura.io](http://www.kitura.io/) for reference documentation.

## Contributing to Kitura-NIO

We'd be more than happy to receive bug reports, enhancement requests and pull requests!

1. Clone this repository.

`$ git clone https://github.com/IBM-Swift/Kitura-NIO && cd Kitura-NIO`

2. Set the open file limit to a large number. This is to work around an [open issue](https://github.com/IBM-Swift/Kitura-NIO/issues/1).

`$ ulimit -n 65536`

3. Build and run tests.

`$ swift test`


## Community

These are early days for Kitura-NIO. We'd really love to hear feedback from you.

Join the [Kitura on Swift Forums](https://forums.swift.org/c/related-projects/kitura) or our [Slack](http://swift-at-ibm-slack.mybluemix.net/) to meet the team!
