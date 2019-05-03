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

Form validation, specifically verifying user input, is a common requirement in GUI applications. With statically typed languages it can get a bit complicated. In this post I'll introduce **form decoding**, a form validation method specifically suited to statically typed languages. I'll also introduce [elm-form-decoder](https://github.com/arowM/elm-form-decoder), an implementation of the concept in Elm.

## Sample Application

Say we have a social networking application for goats. For our purposes it doesn't matter how they use keyboards with their two-fingered hands. We'll assume that the application contains two screens:

1. A form to register a new goat
2. A page for viewing all registered goats

Take a look at the [finished application](https://arowm.github.io/elm-form-decoder/). Play around a bit to get an idea of how it handles error messages. Errors appear next to inputs, and the "required" error doesn't appear until the form is submitted.

![demo screenshot](/posts/img/form-decoder-screenshot.png)

## Types for Data

The core idea of Form Decoding is proper separation of concerns. The type for a Goat might look like this:

```elm
type alias Goat =
    { name : Name
    , age : Age
    , horns : Horns
    , contact : Contact
    , message : Maybe Message
    }

type Contact
    = ContactEmail Email
    | ContactPhone Phone

type Name
    = Name String

type Age
    = Age Int

...additional wrapping types...
```

But this type is **not** a good type for storing the current state of the form. The user might not have entered a valid age for example. The type that stores the form's state needs to be such that the age can be stored even if it is invalid. That way an error can be displayed if necessary:

> The input value "two" is invalid for this field. It needs to be made of digits!

Consider the contact field as another example. Say the goat first selects "Email address" as their contact method and types "you-goat-mail@example.com" in the email field, but then changed their mind and selects "Phone number" instead. The value of the `contact` field will become `ContactPhone ""` and the previously entered email address will be gone forever. It would be preferable if the goat could select email once again and have their previous entry remain.

Conclusion: We need another type to represent the state of the form.

## Types for Forms

Here's a type that can store the form's state:

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

It's pretty simple, not much to see.  You might be surprised that `contactType` is a string rather than an enumerated type such as:

```elm
type ContactType
    = UseEmail
    | UsePhone
```

The enumerated type doesn't quite capture the semantics of how HTML deals with select tags. The `value` of a select tag is just a string, with rather weak guarantees about its possible values. Its better to store whatever HTML gives us and deal with it at the validation layer.

## Form Decoding

You might have noticed that we'll need a function to convert a RegisterForm into a Goat. (After all, if we just used RegisterForm as our model going forward we might as well switch to a dynamically typed language.) This is where **form decoding** comes in. We'll write a function to __decode__ the user's input, which is comes into the system __encoded__ as strings.

Here's a possible value of the RegisterForm type:

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

This obviously cannot be successfully converted into a `Goat` type. For one thing it doesn't have digits in the age field. (Remember, the `Age` type is equivalent to an `Int`.) Since the conversion may not be successful we'll want a type signature that looks something like this:

```elm
toGoat : RegisterForm -> Maybe Goat
```

Instead of returning `Nothing` upon failure, it might be better to return a detailed error explaining __why__ it failed.

```elm
type Error
    = NameRequired
    | AgeInvalidInt
    | AgeNegative
    | AgeRequired
    ...

toGoat2 : RegisterForm -> Result (List Error) Goat
```

For which a possible return value could be:

```elm
Err [ NameRequired, AgeInvalidInt ]
```

## DO NOT use an independent form validation library

Some might want to validate and decode their form separately. Here there be dragons, and dragons eat goats.

**Reason 1. Duplicate effort.**

Since form decoding performs a pretty thorough inspection of the values, it requires implementing much the same code that form validation would require. Don't repeat yourself.

**Reason 2. It causes unexpected behavior.**

Imagine the validation and decoding fall out-of-sync with each other. Then the validation could succeed and tell the user all is good, but the decoding fails and the program grinds to a halt. For example:

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


{-| Update the Model when the user clicks the "Register" button.

This SHOULD NOT be called with an invalid value because it is only called after the validation library gives its approval.
-}
onSubmit : Model -> Model
onSubmit model =
    if List.isEmpty (errors model.registerForm) then
        let
            goat : Maybe Goat
            goat = toGoat model.registerForm
        in
        -- Oops! What should I do if form decoding fails? The form validated successfully!
        ...
        ...
```
Therefore, you should never use form validation when using form decoding.

## elm-form-decoder

Here I'll introduce my library for form decoding in Elm: [elm-form-decoder](https://package.elm-lang.org/packages/arowM/elm-form-decoder/latest/). When building a form decoding library it's important to consider composition. Users need to be able to build complex decoding functions out of small, simple parts.

Good form designs typically show the user the errors right next to the field where the error exists. You might have noticed that that is exactly how the demo app works. Here is what the form decoders for that kind of app would look like:

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

Notice that the type of `name` and `age` do not look like:

```elm
name : String -> Result Error String
age : String -> Result Error Int
```

But instead look like:

```elm
name : Decoder String Error String
age : Decoder String Error Int
```

This should indicate to the reader that they do not decode user input themselves, but are sort of like a guidebook. A guidebook of type `Decoder input error a` decodes `input` into some type `a` while raising errors of type `error`.

Decoding an input using the guidebook requires using the `run` function exposed by elm-form-decoder.

```elm
run : Decoder input err a -> input -> Result (List err) a
```

`run` takes a decoder and an input and returns a result:

```elm
Decoder.run age ""
--> Err [ AgeRequired ]

Decoder.run age "30"
--> Ok 30
```

You might be wondering: Why use a guidebook (decoder) rather than a regular old function to decode the input? Because decoders can be composed to build bigger decoders. For example:

```
name_ : Decoder RegisterForm Error String
name_ = Decoder.lift .name name

age_ : Decoder RegisterForm Error Int
age_ = Decoder.lift .age age
```

The `lift` function "lifts" a decoder up to operate on a larger structure. Here it converts the `name` decoder, which consumes a `String` to consume a `{x | name : String}`.

Let's use this to build a complete decoder for converting a `RegisterForm` into a `Goat`:

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

Just like that we've built a complete decoder out of smaller, simple decoders. That's the power of using decoders.

Let's finish up by using the decoder to convert a `RegisterForm` into a `Goat`:

```elm
Decoder.run form (Form "Sakura-chan" "2" "0" ...)
--> Ok (Goat "Sakura-chan" 2 0 ...)
```

## Real World Examples

The actual code running in production is a bit more complex than the example shown in this post. Goats have complex needs after all! You can check out the [real world example](https://github.com/arowM/elm-form-decoder/tree/master/sample) in the [elm-form-decoder repository](https://github.com/arowM/elm-form-decoder/). Please give a star if you're interested in it. 😉

![eye catch](/posts/img/form-decoder-last.jpg)
[See more Sakura-chan](https://twitter.com/hashtag/%E3%81%95%E3%81%8F%E3%82%89%E3%81%A1%E3%82%83%E3%82%93%E6%97%A5%E8%A8%98?src=hash)
