/*:
 # Combine

 The Combine framework provides a declarative Swift API for processing values over time.
 These values can represent many kinds of asynchronous events.
 Combine declares publishers to expose values that can change over time, and subscribers to receive those values from the publishers.

 ## How combine is working?

 Instead of being concerned with the actual values actions and states and handling transformation synchronously with huge overhead knowing which data belongs to which part, combine suggests to design some kind of a funnel that is ready to process those values/events/states using operators, and hands them asynchronously to all subscribers regardless which thread they're listening to.

 ## Main components of combine

 ### Publishers
 Declares a type that can deliver a sequence of values over time. Publishers have operators to act on the values received from upstream publishers and republish them

 ### Subscribers
 Acts on elements as it receives them. Publishers only emit values when explicitly requested to do so by subscribers. This puts your subscriber code in control of how fast it receives events from the publishers it’s connected to.

 ### Cancellables
 Simply a cancellable operation, usually a subscription, but could be anything.

 ### Operators
 Appended in the sequence between Publisher and subscriber does important transformation and business logic, between the two ends handling all events that are emitted from the publisher to the subscriber.

 ### Schedulers
 Defines when and how to execute a closure (which thread, what to do when receiving a specific event, when to complete and when to fail)


 - What are we covering in today's introduction workshop
 - Publishers ✅
 - Operators ✅
 - Subscribers ✅
 - Subjects ✅
 - Cancellables ✅
 - Schedulers ✅
 - Benefits and issues ✅
 */


/*:
 ## Publishers
 
 * Publishers, are observable objects that emit values whenever a given event occurred.
 * Publishers can either be *active indefinitely or eventually be completed, and can also optionally fail* when an error was encountered.
 */

import Foundation
import Combine

var url = URL(string: "https://api.github.com/repos/johnsundell/publish")!
var publisher = URLSession.shared.dataTaskPublisher(for: url)

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
 Decode the JSON in the receiveValue block.
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
 * Other interesting operators to look for e.g. tryMap, flatMap, filter etc some of them react similarly to the swift ones others not
 * full on documentation from apple : https://developer.apple.com/documentation/combine/passthroughsubject-publisher-operators
 */

let dataPublisher = publisher.map(\.data)
let repoPublisher = publisher
    .map(\.data)
    .decode(type: Repository.self, decoder: JSONDecoder())

let repoSubscriber = repoPublisher.sink(
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

/// For custom cancelation of subscriptions
/// cancellableStore.forEach { $0.cancel() }

/*:
 ## Subjects

 A publisher that exposes a method for outside callers to publish elements

 A publisher that can be used by outsiders to publish actions not just for outsiders to subscribe to and react, it has multiple types:
 ### PassthroughSubjects
 Creating a PassthroughSubject identifying what exactly needed to pass as a value, and as a fail case
 PassthroughSubjects are usually passing a stream of events and exposes the possibility for outsiders to pass events through them.
 No initial value needed for the `PassthroughSubject` to hold
 */

let passthroughSubject = PassthroughSubject<String, Error>()

// an external component can use that subject to pass whatever event it wants
// sending a string value
passthroughSubject.send("Passing a string through a passthrough subject !")

// sending a failure event in completion
passthroughSubject.send(completion: .failure(NSError(domain: "passthrogh passed an error", code: 0, userInfo: nil)))

// this won't send as we send the completion event with failure
passthroughSubject.send("calling all subscribers another time !")


var passthroughSubjectCancellable = Set<AnyCancellable>()

passthroughSubject
    .subscribe(on: RunLoop.current)
    .receive(on: RunLoop.main)
    .sink { completion in
        switch completion {
        case .finished:
            print("passthroughSubject finished ")
        case .failure(let error):
            print("passthroughSubject failed with error: \(error) ")
        }
    } receiveValue: { value in
        print("passthroughSubject received a value: \(value)")
    }.store(in: &passthroughSubjectCancellable)
/*:
### CurrentValueSubject
Unlike PassthroughSubject `CurrentValueSubject` is a subject that emits only the current value and needs to be init with an initial value
 usually `CurrentValueSubject`, pushes a  new value when the value changes
*/

var currentValueSubjectCancellable = Set<AnyCancellable>()

let currentValueSubject = CurrentValueSubject<Bool, Error>(false)

currentValueSubject
    .subscribe(on: RunLoop.current)
    .receive(on: RunLoop.main)
    .sink { completion in
        switch completion {
        case .finished:
            print("currentValueSubject finished ")
        case .failure(let error):
            print("currentValueSubject failed with error: \(error) ")
        }
    } receiveValue: { value in
        print("currentValueSubject received a value: \(value)")
    }.store(in: &passthroughSubjectCancellable)

currentValueSubject.send(false)
currentValueSubject.send(false)
currentValueSubject.send(true)

/*:
 we can get the current value of the currentValueSubject by using `value`
 */
print("currentValue of currentValueSubject: \(currentValueSubject.value)")

/*:

 ## Schedulers

 ## What are the benefits of using combine

 ## Readability issues
 */

/*:
 - subjects and the custom publishers
 - schedulers and working in different queues
 - what's the benefit of using this
 - Readability issues
 */
