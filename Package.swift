// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
/*
 * Copyright IBM Corporation and the Kitura project authors 2016-2020
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import PackageDescription

let package = Package(
    name: "Kitura-NIO",
    products: [
        .library(
            name: "KituraNet",
            targets: ["KituraNet"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        .package(name: "SSLService", url: "https://github.com/Kitura/BlueSSLService.git", from: "2.0.1"),
        .package(url: "https://github.com/Kitura/LoggerAPI.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "CLinuxHelpers",
            dependencies: []),
        .target(
            name: "KituraNet",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                "SSLService",
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                 "LoggerAPI", "CLinuxHelpers"]),
        .testTarget(
            name: "KituraNetTests",
            dependencies: ["KituraNet"])
    ]
)
