# swift-llm-kit

**This library is a Work in Progress**

## Motivation

`LLMKit` is a library focussing on providing a highly composable tool to interact with Large Language Models.


a `LLMKit` value can be seen as a function that takes a `CompletionChain` and returns a new `CompletionChain`

a `CompletionChain` is a list of `ChatLog` each one being the result of a completion call to the LLM


## Usage

```swift
// Create a openAI llmkit
let llm: LLMKit = .openAI(apiKey:"<your api token>")

// Initialize a completion chain
let initialChain: CompletionChain = .init(systemPrompt: "")
// Get a new completion by calling openAI api
let chain: CompletionChain = try await llm(chain: initialChain, message"Hello!")

// Get the last state of the chat
let chatLog: ChatLog = chain.output
// get the last message
let lastMessage: Model.MessageContent? = chatLog.messages.last
```

### Constructing a llmKit elements

The library is heavily composability oriented. It provides a lot of ways to construct and compose llmKit elements but you can easily implement your own.

Creation

```swift
let llm: LLMKit = .openAI()
let llm: LLMKit = .openAI(url: "...")

// misc examples
let llm: LLMKit = .echoing // just repeats the last user's message
let llm: LLMKit = .jsEvaluating // returns the result of the last user's message evaluated as a js expression

// you can even implement your own computation by using the poor man's plugin
let llm: LLMKit = .computing { chatLog in 
    let computedString = ...
    return computedString
}
```

Modify and Compose

```swift
let filtering = llm.filter { message in 
    message.user == .agent
} 
let debugged = llm.debug
let pipe = llm.pipe(llm2) (or llm | llm2)
let fallingback = llm.fallback(llm2)
```


### implementing your own LLMKit

Extensing the library is straightforward. 

```swift
extension LLMKit { 
    static var myLLMKit: Self { 
        .init { chatLog in
            let computedChatLog = ...
            return computedChatLog
        }
    }
}
...
// getting an instance
let myLLM: LLMKit = .myLLMKit // you can also use all modification / composition tools like .debug, .pipe, etc..

// using it...
let completion = try await myLLM.complete(chatLog, message: "Hello!")
```

You can take a look at how LLMKit.openAI or LLMKit.echo are implemented. Those are good sources of information.

### Streaming

WIP...

```swift
// get a stream of chatlog deltas
let chatLogDeltas: AsyncThrowingStream<ChatLog.Delta> = try await llm.stream(chatLog, message: "hello!")
```



### Window management

WIP...

```swift
let strat: LLMWindowStrategy = .trim(maxToken: 4096, position: .older, tokenizer: someTokenizer)
let strat: LLMWindowStrategy = .trim(tokenizer: tokenizer) { chatLog, tokenizer in 
    ...
    return computedChatLog
}


let llmWithWindowManagement = llm.withWindowStrategy(strat)
```
