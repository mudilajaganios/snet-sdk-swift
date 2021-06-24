# snet-sdk-swift
SNET SDK in Swift

SNET SDK in Swift

snet-sdk-swift is a Swift library for interacting with AI services published on SingularityNET AI marketplace.

## Platforms support

| Platform | Version |
| ------ | ------ |
| iOS | 11 or higher |
| macOS | 10.12 or higher |

This SDK is under active development and not ready for production use yet. If you find any bug or something doesn't work as expected, please create an issue.

## Installation

### Pre-requisites
Xcode >= 12.0 or Swift >= 5.3.

### Swift Package Manager

snet-sdk-swift is compatible with Swift Package Manager v5 (Swift 5 and above). Simply add it to the project dependencies.

```
dependencies: [
    .package(url: "https://github.com/singnet/snet-sdk-swift.git", from: "0.0.2")
]
```
Add snet-sdk-swift to the Framework, Libraries, and Embedded Content section of your target settings.


## Usage

SDK assumes that there is enough  ```eth``` balance to cover the ```gas``` cost and ```AGI``` tokens in the wallet to cover the service execution cost.

The SDK choses a default  ```PaymentChannelManagementStrategy```  which is the simplest form of picking an existing ```Payment Channel``` if any or creates a new ```Payment Channel``` if no channel is found. This can be easily overridden by providing your own strategy to the SDK at the time of construction. Documentation on creating custom strategies will be available soon.

## Development

This library is built on PromiseKit and GRPC libraries. In order to create Service client and interact with service client methods, you need to import PromiseKit module in your Swift class file.

```
import snet_sdk_swift
import PromiseKit
import GRPC
```
### SDK Configuration

First things first, you need to create instance for  ```SDKConfig``` as below.

```
let config = SDKConfig(web3Provider: "https://<mainnet>.infura.io/v3/<Project_ID_from_Infura_Dashboard>", privateKey: "<Ethereum wallet privatekey>", signerPrivateKey: "<Ethereum wallet privatekey>", networkId: "<1>")
```
```web3Provider``` is your Infura project URL. for development/testing you can use Ropsten network URL. For development you need to use Mainnet URL.
```privateKey``` and ```signerPrivateKey``` is your Ethereum wallet private key
```networkId``` is "1" for Mainnet and "3" for Ropsten networks.

Secondly, create instance for ```SnetSDK``` as below.

```
let _snetSDK: SnetSDK = try SnetSDK(config: config)
```
You can provide free call configuration to avail free calls for your subscription. Please visit AI marketplace for the free call configuration.

```
let _freeCallOptions: [String: Any] = [
    "tokenToMakeFreeCall":"",
    "tokenExpirationBlock": ,
    "email": "",
    "disableBlockchainOperations": true/ false,
    "concurrency": true/ false
] as [String : Any]
```

Consuming AI service as below:

```
firstly {
    sdk.createServiceClient(orgId: "snet", serviceId: "example-service",paymentChannelManagementStrategy: nil ,options: serviceClientOptions, concurrentCalls: 300)
}.done { serviceClient in
    firstly {
        serviceClient.getServiceClientOptions()
    }.done { options in
        let client = ExampleService_CalculatorClient(channel: serviceClient.serviceChannel, defaultCallOptions: options ?? CallOptions())
        let numbers: ExampleService_Numbers = .with {
            $0.a = 100
            $0.b = 20
        }
        let call = client.add(numbers)
        let response = try call.response.wait()
        print(response.value)
    }.catch { (error) in
        print(error)
    }
}.catch { (error) in
    print(error)
}
} catch {
    print(error)
}
```

[LICENSE](https://github.com/singnet/snet-sdk-swift/blob/main/LICENSE) file for details.
