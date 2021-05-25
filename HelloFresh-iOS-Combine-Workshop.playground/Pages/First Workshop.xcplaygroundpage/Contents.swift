/*:
 ## Publishers
 
 * Publishers,are observable objects that emit values whenever a given event occurred.
 * Publishers can either be *active indefinitely or eventually be completed, and can also optionally fail* when an error was encountered.
*/

import Foundation
import Combine

let url = URL(string: "https://api.github.com/repos/johnsundell/publish")!
let publisher = URLSession.shared.dataTaskPublisher(for: url)

/*:
 * Once we’ve created a publisher, we can then attach subscriptions to it, for example by using the *sink API*.
 * It lets us pass a closure to be called whenever a new value was received, as well as one that’ll be called once the publisher was completed
 * Every publisher returns a cancellable when a subscriber subscribes to it. We hold it as long as we want subscriber to live
*/

let cancellable = publisher.sink(
    receiveCompletion: { completion in
        // Called once, when the publisher was completed.
        print(completion)
    },
    receiveValue: { value in
        // Can be called multiple times, each time that a
        // new value was emitted by the publisher.
        print(value)
    }
)

/*:
Let's decode the the response in a model. Since it's git repo API, below is a very simple Model for it.
*/

struct Repository: Codable {
    var name: String
    var url: URL
}

/*:
Decode the JSON in the reciveValue block.
*/

let decodedCancellable = publisher.sink(
    receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
            print(error)
        case .finished:
            print("Success")
        }
    },
    receiveValue: { value in
        let decoder = JSONDecoder()

        do {
            // Since each value passed into our closure will be a tuple
            // containing the downloaded data, as well as the network
            // response itself, we're accessing the 'data' property here:
            let repo = try decoder.decode(Repository.self, from: value.data)
            print(repo)
        } catch {
            print(error)
        }
    }
)

/*:
 ## Operators
 
 * *The true power of Combine (and reactive programming in general) lies in constructing chains of operations that our data gets streamed through .*
 * Operators are methods declared on the Publisher to perform some operations and return *either the same or a new publisher*
 
*/

let dataPublisher = publisher.map(\.data)
let repoPublisher = publisher
    .map(\.data)
    .decode(type: Repository.self, decoder: JSONDecoder())
    
let repoSubcriber = repoPublisher.sink(
    receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
            print(error)
        case .finished:
            print("Success")
        }
    },
    receiveValue: { repo in
        print("data by using operators", repo)
    }
)

/*:
 ## Any Cancellable
 
 * A type-erasing cancellable object that executes a provided closure when canceled.
 * Normally we create a cancellable store which takes care of subscription cancellations
 
*/

var cancellableStore = Set<AnyCancellable>()

let cancellableStorePublisher = publisher
    .map(\.data)
    .decode(type: Repository.self, decoder: JSONDecoder())
    
cancellableStorePublisher.sink(
    receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
            print(error)
        case .finished:
            print("Success")
        }
    },
    receiveValue: { repo in
        print("data by using operators", repo)
    }
).store(in: &cancellableStore)

/// For custom cancelation of subcriptions
/// cancellableStore.forEach { $0.cancel() }
