---
title: "Form Decoding: the next era of the Form Validation"
date: 2019-04-26T16:06:39+09:00
featured_image: "/img/form-decoding-head.jpg"
tags: ["Form decoding", "Form validation", "Elm"]
author: "arowM"
author_href: "https://github.com/arowM/"
images: ["/posts/img/form-decoding-twitter.jpg"]
draft: false
---

Form validation, verifying the user inputs, is common in GUI applications. But when it comes to be the context of statically typed programming, the form validation is not enough.

In these days, some application developers like to use statically typed programming languages in order to make their application more reliable. In this post I introduce new concept named **form decoding**, a sort of form validation especially suitable for statically typed programming, and demonstrate how it could be make your applications better by using [elm-form-decoder](https://github.com/arowM/elm-form-decoder), which I've developed to do form decoding in Elm applications.

## Sample application

Say that we have an SNS application for goats. Here, do not matter how they can use keyboards by their two-fingered hands.

In this example app, we assume that it only contains two screens:

* A form to register a new goat
* A page for viewing all the goats registered

Here I've prepared [a demo app](https://arowm.github.io/elm-form-decoder/). Please play with it to get practical visualization.
For example, input "foo" on age field and blur to show error messages. (It does not show "required" error message till pressing register button for EFO).

![demo screenshot](/posts/img/form-decoder-screenshot.png)

## Type for managing data itself, and type for managing state of form

In this sample app, we have following data structure as a goat profile.

* Name
* Age
* Number of Horns
* Means of Contact
    * Either of Email or Phone Number
* Message to other goats
    * It's optional

You would declare a type for managing this data like this:
(In this post, all sample codes are written in Elm.)

```elm
type alias Goat =
    { name : Name
    , age : Age
    , horns : Horns
    , contact : Contact
    , message : Maybe Message
    }
```

Types `Name`, `Age`, `Horns`, and `Message` here is declared in another place:

```elm
type Name
    = Name String

type Age
    = Age Int

...
```

It's just an opaque type to assure that the value is valid as name, age, e.t.c.

The `Contact` type can take two type of values email or phone:

```elm
type Contact
    = ContactEmail Email
    | ContactPhone Phone
```

The reason `message` has type of `Maybe Message` is that it is optional value. It can take Nothing (empty input), or something like `Just "Hi! I'm Sakura-chan."`. Nice modeling!

So do we use `Goat` type to hold the state of registration form? No! The `Goat` type is not suitable for user inputs that is plain text itself. For example, the user would input "two" in the input field for age, but `age` field of the `Goat` is actually the type of `Int`. It means if we want to show the error text bellow, we have to take the `value` property of the `input` tag directly.

> The input value "two" is invalid for this field.

It's assumed a sort of bad pattern, especially Elm does not allow developers to do such methods to avoid mess codes.

The another example that `Goat` type cannot handle form state is about the method of contact. Say that the goat first selected "Email address" as their contact method and input "you-goat-a-mail@example.com" in email field, but they changed their mind to select "Phone number". In this situation, the value of the `contact` field can be `ContactPhone ""`, but the input value "you-goat-a-mail@example.com" is no more here. It means if the goat selected "Email address" again, they
have to input email address again!

Therefore, we need another type to represent form state.

![eye catch](/posts/img/form-decoder-middle.jpg)

## Type for holding form state

Okay, let's declare another type to hold state of registration form here:

```elm
type alias RegisterForm =
    { name : String
    , age : String
    , horns : String
    , email : String
    , phone : String
    , contactType : String
    , message : String
    }
```

It's simple honesty. No interest things. It just holds user inputs as it is in `String` fields.

Maybe you think that `contactType` could be enumeration type:

```elm
type ContactType
    = UseEmail
    | UsePhone
```

But it cannot handle state of `select` tag of HTML exactly. The `value` property of `select` tag is just a string, so the `ContactType` cannot handle the possibility that the select tag has unexpected `value`.

## Why Form decoding is needed?

You may noticed that we need some function to convert `RegisterForm` into `Goat` because we cannot benefit from static types if using `RegisterForm` as it is even after registering. It would be much better to use dynamic typing if doing so!

In this post, this sort of conversion is called **form decoding**, assuming that user inputs are __encoded__ as string.

## Form decoding is the next-generation of form validation

Bunch of people would think "Hey, form decoding is different from form validation, though I've understood its importance". Yes, you are right. But if considering the possibility of failing decoding, it practically a sort of form validation.

Say that we have following value in Model as `RegisterForm`.

```elm
type alias RegisterForm =
    { name = "Hey!"
    , age = "I'm pretty geneous"
    , horns = "to use SNS"
    , email = ""
    , phone = ""
    , contactType = ""
    , message = "WHATS CONTACT TYPE???"
    }
```

This obviously cannot be successfully converted to `Goat` type. One of the reason to fail is that it does not have digits in age field. Remember that `Age` type is actually equivalent to `Int`.

```elm
type Age
    = Age Int
```

Consequently, the convert function is supposed to have type like:

```elm
toGoat : RegisterForm -> Maybe Goat
```

It returns `Nothing` if it fails to convert. Or it can be more user friendly to tell why it failed.

```elm
type Error
    = NameRequired
    | AgeInvalidInt
    | AgeNegative
    | AgeRequired
    ...
    ...

toGoat2 : RegisterForm -> Result (List Error) Goat
```

If user inputs are invalid, it returns `Err` like:

```elm
Err [ NameRequired, AgeInvalidInt ]
```

And it only returns converted value with `Ok` keyword:

```elm
Ok (Goat "Sakura-chan" 2 ......)
```

It's obvious that it is also doing form validation. I confidently say that form decoding is the new-generation of form validation for statically typed programming!

## DO NOT use with independent form validation library

Some people would want to do form validation and form decoding separately by the reason such as they have familiar form validation libraries. But I recommend them not to do so.

**Reason 1. It just forces us to duplication of effort.**

Using independent form validation library means you have to declare similar code on form validation and form decoding on another place.

**Reason 2. It causes unexpected behaviours.**

Sometime it could cause following situation.

* A user input is valid for form validation
* But form decoding fails for the input

For example, how you can manage following code?

```elm
type alias Model =
    { registerForm : RegisterForm
    , goats : List Goat
    }


{-| Function for form validation
-}
errors : RegisterForm -> List Error
errors = ...


{-| Function for form decoding
-}
toGoat : RegisterForm -> Maybe Goat
toGoat = ...


{-| Update Model when user clicked "Register" button.

It SHOULD NOT be called with invalid value because this function is called only after checking by validation library.
-}
onSubmit : Model -> Model
onSubmit model =
    if List.isEmpty (errors model.registerForm) then
        let
            goat : Maybe Goat
            goat = toGoat model.registerForm
        in
        -- Oops! How can I manage if unexpectedly form decoding fails????
        ...
        ...
```

As a result, not form validation but form decoding libraries must be essential for statically typed programming.

## elm-form-decoder

Here I'll introduce my Elm library for form decoding named [elm-form-decoder](https://package.elm-lang.org/packages/arowM/elm-form-decoder/latest/) to show practical implementations. One of the important requirements for such libraries is that it can build big decode function with partial decode functions. Let's see real examples.

In practical forms, it is common to show errors on each input field. The [example introduced first](https://arowm.github.io/elm-form-decoder/#goat-registerForm) also adopts such UI. If you input "foo" on "Age" field, it shows "Invalid input. Please input integer." just bellow the input box.

To realise such UI, it is natural to declare decode functions for each input field. Just look over the code bellow. Need not to understand completely.

```elm
import Form.Decoder as Decoder

{-| Decoder for name field.

    import Form.Decoder as Decoder

    Decoder.run name ""
    --> Err [ NameRequired ]

    Decoder.run name "foo"
    --> Ok "foo"
-}
name : Decoder String Error String
name =
    Decoder.identity
        |> Decoder.assert (Decoder.minLength NameRequired 1)


{-| Decoder for name field.

    import Form.Decoder as Decoder

    Decoder.run age ""
    --> Err [ AgeRequired ]

    Decoder.run age "foo"
    --> Err [ AgeInvalidInt ]

    Decoder.run age "-30"
    --> Err [ AgeNegative ]

    Decoder.run age "30"
    --> Ok 30

-}
age : Decoder String Error Int
age =
    Decoder.identity
        |> Decoder.assert (Decoder.minLength AgeRequired 1)
        |> Decoder.andThen (\_ -> Decoder.int AgeInvalidInt)
        |> Decoder.assert (Decoder.minBound AgeNegative 0)
```

Notice that the type of `name` and `age` are NOT like:

```elm
name : String -> Result Error String
age : String -> Result Error Int
```

Instead, they have following types:

```elm
name : Decoder String Error String
age : Decoder String Error Int
```

It means they are **NOT functions to decode user inputs itself, but just a sort of guidebooks**. A guidebook with type of `Decoder input err a` decodes `input` type into `a` type, with raising error of type `err`.

To decode inputs by following instructions written in such __guidebooks__, use `run` function exposed by elm-form-decoder.

```elm
run : Decoder input err a -> input -> Result (List err) a
```

It takes decoder and actual inputs like:

```elm
Decoder.run age ""
--> Err [ AgeRequired ]

Decoder.run age "30"
--> Ok 30
```

Why it uses guidebook (decoder) rather than function to decode input itself? It is because decoders can be composed to build big decoder. At first, let's create a new decoder by converting existing decoders:

```
name_ : Decoder RegisterForm Error String
name_ = Decoder.lift .name name

age_ : Decoder RegisterForm Error Int
age_ = Decoder.lift .age age
```

The `lift` function takes getter function and original decoder to make new decoder that consumes `RegisterForm` instead of `String`.

We can now create a decoder that converts `RegisterForm` into `Goat` just composing them:

```elm
form : Decoder RegisterForm Error Goat
form =
    Decoder.top Goat
        |> Decoder.field name_
        |> Decoder.field age_
        |> Decoder.field horns_
        |> Decoder.field contact_
        |> Decoder.field memo_
```

Wow, It's all! There are no difficulties. It just aligns field decoders. This is the great power of decoder pattern.

Finally, let's use this form decoder to check it can decode `RegisterForm` into `Goat`:

```elm
Decoder.run form (Form "Sakura-chan" "2" "0" ...)
--> Ok (Goat "Sakura-chan" 2 0 ...)
```

## Real world examples

The actual code in production is a bit more complex than example of this post. You can check [real world example](https://github.com/arowM/elm-form-decoder/tree/master/sample) on the [repository for elm-form-decoder](https://github.com/arowM/elm-form-decoder/). Please give your star if you interested in it 😉

![eye catch](/posts/img/form-decoder-last.jpg)
[See more Sakura-chan](https://twitter.com/hashtag/%E3%81%95%E3%81%8F%E3%82%89%E3%81%A1%E3%82%83%E3%82%93%E6%97%A5%E8%A8%98?src=hash)
