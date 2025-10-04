module SmoothMoveSub exposing
    ( Config
    , defaultConfig
    , Model
    , init
    , startAnimation
    , startAnimationWithOptions
    , update
    , startAnimationTo
    , subscriptions
    , isIdle
    , isAnimating
    , getCurrentPosition
    , getElementIds
    , Axis(..)
    , AnimationState
    , moveTo
    , moveToWithOptions
    , animate
    , stopAnimation
    , updateAnimation
    , isAnimationComplete
    , transform
    , transformElement
    )

{-|


# Config

@docs Config
@docs defaultConfig


# Model-Based API (Recommended)

@docs Model
@docs init
@docs startAnimation
@docs startAnimationWithOptions
@docs update
@docs startAnimationTo
@docs subscriptions
@docs isIdle
@docs isAnimating
@docs getCurrentPosition
@docs getElementIds
@docs Axis


# Legacy API (Deprecated)

@docs AnimationState
@docs moveTo
@docs moveToWithOptions
@docs animate
@docs stopAnimation
@docs updateAnimation
@docs isAnimationComplete


# Styling Helper

@docs transform
@docs transformElement

-}

import Browser.Events
import Dict exposing (Dict)
import Ease


{-| Configuration options for smooth moving. Has options:

  - speed: The higher this number, the faster the movement!
  - easing: The easing function to use. Check out the [easing functions](https://package.elm-lang.org/packages/elm-community/easing-functions/latest/) package for more information.
  - axis: Which axis to move along (X, Y, or Both)

-}
type alias Config =
    { speed : Int
    , easing : Ease.Easing
    , axis : Axis
    }


{-| Axis configuration for movement direction
-}
type Axis
    = X
    | Y
    | Both


{-| Internal position information used for animation state management

This type is used internally by updateAnimation to communicate position data
and completion status. Subscriptions only send deltaMs (Float), not Position data.
For public position access, use getCurrentPosition or transformElement functions.

-}
type alias Position =
    { x : Float
    , y : Float
    , elementId : String
    , isComplete : Bool
    }


{-| Animation state for managing ongoing animations (Legacy API)
-}
type alias AnimationState =
    { startX : Float
    , startY : Float
    , targetX : Float
    , targetY : Float
    , config : Config
    , startedAt : Float
    , duration : Float
    }


{-| Internal model that manages animation state and element positions automatically

This model handles all animation state AND element positions internally, so developers
don't need to track AnimationState, completion logic, or current positions manually.

Uses a Dict for O(1) lookups and better performance with many elements.

-}
type Model
    = Model (Dict String ElementData)


type alias ElementData =
    { currentX : Float
    , currentY : Float
    , animation : Maybe AnimationState
    }


{-| Initialize the model with no active animations

    init =
        SmoothMoveSub.init

-}
init : Model
init =
    Model Dict.empty


{-| Start an animation using the default configuration

    import SmoothMoveSub

    update msg model =
        case msg of
            StartMove targetX targetY ->
                let
                    newSmoothMove =
                        SmoothMoveSub.startAnimation
                            "element-id"
                            model.elementPosition.x
                            model.elementPosition.y
                            targetX
                            targetY
                            model.smoothMove
                in
                ( { model | smoothMove = newSmoothMove }, Cmd.none )

-}
startAnimation : String -> Float -> Float -> Float -> Float -> Model -> Model
startAnimation elementId startX startY targetX targetY model =
    startAnimationWithOptions defaultConfig elementId startX startY targetX targetY model


{-| Start an animation using custom configuration

    import SmoothMoveSub exposing (defaultConfig)

    update msg model =
        case msg of
            StartMove targetX targetY ->
                let
                    config =
                        { defaultConfig | speed = 100, axis = Both }

                    newSmoothMove =
                        SmoothMoveSub.startAnimationWithOptions
                            config
                            "element-id"
                            model.elementPosition.x
                            model.elementPosition.y
                            targetX
                            targetY
                            model.smoothMove
                in
                ( { model | smoothMove = newSmoothMove }, Cmd.none )

-}
startAnimationWithOptions : Config -> String -> Float -> Float -> Float -> Float -> Model -> Model
startAnimationWithOptions config elementId startX startY targetX targetY (Model elementsDict) =
    let
        distance =
            case config.axis of
                X ->
                    abs (targetX - startX)

                Y ->
                    abs (targetY - startY)

                Both ->
                    sqrt ((targetX - startX) ^ 2 + (targetY - startY) ^ 2)

        -- Duration based on distance and speed (speed = pixels per second)
        duration =
            max 100 (distance * 1000 / toFloat config.speed)

        animationState =
            { startX = startX
            , startY = startY
            , targetX = targetX
            , targetY = targetY
            , config = config
            , startedAt = 0
            , duration = duration
            }

        elementData =
            { currentX = startX
            , currentY = startY
            , animation = Just animationState
            }

        updatedDict =
            Dict.insert elementId elementData elementsDict
    in
    Model updatedDict


{-| Start an animation to a target position, automatically using the current position as the starting point

This is a convenience function that combines getCurrentPosition with startAnimation.
If the element has no current position, it defaults to (0, 0).

    import SmoothMoveSub

    newModel =
        SmoothMoveSub.startAnimationTo "my-element" 200 300 model.smoothMove

-}
startAnimationTo : String -> Float -> Float -> Model -> Model
startAnimationTo elementId targetX targetY model =
    let
        currentPos =
            getCurrentPosition elementId model
                |> Maybe.withDefault { x = 0, y = 0 }
    in
    startAnimation elementId currentPos.x currentPos.y targetX targetY model


{-| Update the model with animation frame data

This function handles all the internal state management automatically.
You call this in response to the animation frame messages from subscriptions.

    import SmoothMoveSub

    type Msg
        = AnimationFrame Float
        | StartMove Float Float

    update msg model =
        case msg of
            AnimationFrame deltaMs ->
                let
                    newSmoothMove =
                        SmoothMoveSub.update deltaMs model.smoothMove
                in
                ( { model | smoothMove = newSmoothMove }
                , Cmd.none
                )

This function handles all active animations simultaneously and updates element positions.

-}
update : Float -> Model -> Model
update deltaMs (Model elementsDict) =
    let
        updateElementData elementId elementData =
            case elementData.animation of
                -- No animation, keep current state
                Nothing ->
                    elementData

                Just animationState ->
                    let
                        ( newState, position ) =
                            updateAnimation deltaMs animationState

                        -- Add elementId to position since updateAnimation no longer has access to it
                        positionWithId =
                            { position | elementId = elementId }
                    in
                    if positionWithId.isComplete then
                        -- Animation complete
                        { elementData
                            | currentX = positionWithId.x
                            , currentY = positionWithId.y
                            , animation = Nothing
                        }

                    else
                        { elementData
                            | currentX = positionWithId.x
                            , currentY = positionWithId.y
                            , animation = Just newState
                        }

        updatedDict =
            Dict.map updateElementData elementsDict
    in
    Model updatedDict


{-| Check if the model is idle (no animation running)

    if SmoothMoveSub.isIdle model.smoothMove then
        text "No animation"

    else
        text "Animation running"

-}
isIdle : Model -> Bool
isIdle (Model elementsDict) =
    not (Dict.values elementsDict |> List.any (\elementData -> elementData.animation /= Nothing))


{-| Check if the model is animating

    if SmoothMoveSub.isAnimating model.smoothMove then
        text "Animation running"

    else
        text "No animation"

-}
isAnimating : Model -> Bool
isAnimating (Model elementsDict) =
    Dict.values elementsDict |> List.any (\elementData -> elementData.animation /= Nothing)


{-| Get the current position of an element

    case SmoothMoveSub.getCurrentPosition "my-element" model.smoothMove of
        Just { x, y } ->
            div [ style "transform" (transform x y) ] [ text "Element" ]

        Nothing ->
            text "Element not found"

-}
getCurrentPosition : String -> Model -> Maybe { x : Float, y : Float }
getCurrentPosition elementId (Model elementsDict) =
    Dict.get elementId elementsDict
        |> Maybe.map (\elementData -> { x = elementData.currentX, y = elementData.currentY })


{-| Get all element IDs currently tracked by the model

    elementIds =
        SmoothMoveSub.getElementIds model.smoothMove

-}
getElementIds : Model -> List String
getElementIds (Model elementsDict) =
    Dict.keys elementsDict


{-| The default configuration which can be modified

    import Ease
    import SmoothMoveSub exposing (defaultConfig)

    defaultConfig : Config
    defaultConfig =
        { speed = 200
        , easing = Ease.outQuint
        , axis = Both
        }

-}
defaultConfig : Config
defaultConfig =
    { speed = 200
    , easing = Ease.outQuint
    , axis = Both
    }


{-| Create an animation state for moving an element to the specified position using the default configuration

    import SmoothMoveSub exposing (moveTo)

    animationState =
        moveTo "my-element" 0 0 100 200

-}
moveTo : String -> Float -> Float -> Float -> Float -> AnimationState
moveTo =
    moveToWithOptions defaultConfig


{-| Create an animation state for moving an element to the specified position using a custom configuration

    import SmoothMoveSub exposing (defaultConfig, moveToWithOptions)

    animationState =
        moveToWithOptions { defaultConfig | speed = 100 } "my-element" 0 0 100 200

-}
moveToWithOptions : Config -> String -> Float -> Float -> Float -> Float -> AnimationState
moveToWithOptions config _ startX startY targetX targetY =
    let
        distance =
            case config.axis of
                X ->
                    abs (targetX - startX)

                Y ->
                    abs (targetY - startY)

                Both ->
                    sqrt ((targetX - startX) ^ 2 + (targetY - startY) ^ 2)

        -- Duration based on distance and speed (speed = pixels per second)
        duration =
            max 100 (distance * 1000 / toFloat config.speed)
    in
    { startX = startX
    , startY = startY
    , targetX = targetX
    , targetY = targetY
    , config = config
    , startedAt = 0
    , duration = duration
    }


{-| Subscribe to animation frame updates

    import SmoothMoveSub exposing (animate, updateAnimation)

    subscriptions : Model -> Sub Msg
    subscriptions model =
        case model.animationState of
            Just state ->
                if isAnimationComplete state then
                    Sub.none

                else
                    animate state AnimationFrame

            Nothing ->
                Sub.none

    update msg model =
        case msg of
            AnimationFrame deltaMs ->
                case model.animationState of
                    Just state ->
                        let
                            ( newState, position ) =
                                updateAnimation deltaMs state
                        in
                        ( { model
                            | animationState =
                                if position.isComplete then
                                    Nothing

                                else
                                    Just newState
                            , elementPosition = { x = position.x, y = position.y }
                          }
                        , Cmd.none
                        )

                    Nothing ->
                        ( model, Cmd.none )

-}
animate : AnimationState -> (Float -> msg) -> Sub msg
animate _ toMsg =
    Browser.Events.onAnimationFrameDelta toMsg


{-| Stop an ongoing animation

    stopAnimation : Cmd msg

-}
stopAnimation : Cmd msg
stopAnimation =
    Cmd.none


{-| Update animation state with elapsed time and get current position
-}
updateAnimation : Float -> AnimationState -> ( AnimationState, Position )
updateAnimation deltaMs state =
    let
        newElapsedTime =
            if state.startedAt == 0 then
                deltaMs

            else
                state.startedAt + deltaMs

        progress =
            min 1.0 (newElapsedTime / state.duration)

        easedProgress =
            state.config.easing progress

        currentX =
            case state.config.axis of
                Y ->
                    state.startX

                _ ->
                    state.startX + (state.targetX - state.startX) * easedProgress

        currentY =
            case state.config.axis of
                X ->
                    state.startY

                _ ->
                    state.startY + (state.targetY - state.startY) * easedProgress

        isComplete =
            progress >= 1.0

        updatedState =
            { state | startedAt = newElapsedTime }

        position =
            { x = currentX
            , y = currentY
            , elementId = "" -- Will be filled by caller
            , isComplete = isComplete
            }
    in
    ( updatedState, position )


{-| Check if animation is complete
-}
isAnimationComplete : AnimationState -> Bool
isAnimationComplete state =
    state.startedAt >= state.duration


{-| Create a CSS transform string for positioning an element

    import Html exposing (div)
    import Html.Attributes exposing (style)
    import SmoothMoveSub exposing (transform)

    -- Use with individual x, y values
    div [ style "transform" (transform 100.5 200.7) ] [ text "Moving element" ]

-}
transform : Float -> Float -> String
transform x y =
    "translate(" ++ String.fromFloat x ++ "px, " ++ String.fromFloat y ++ "px)"


{-| Create a CSS transform string by looking up the element's current position in the model

This convenience function eliminates the need to manually call getCurrentPosition and handle Maybe values.
If the element is not found, it defaults to (0, 0).

    import Html exposing (div)
    import Html.Attributes exposing (style)
    import SmoothMoveSub exposing (transformElement)

    -- Much simpler - just pass the element ID and model!
    div [ style "transform" (transformElement "my-element" model.smoothMove) ] [ text "Moving element" ]

-}
transformElement : String -> Model -> String
transformElement elementId model =
    case getCurrentPosition elementId model of
        Just position ->
            transform position.x position.y

        Nothing ->
            transform 0 0


{-| Simplified subscription function that handles animation logic internally

This function takes care of all the animation frame updates and state management.
You just need to handle the Position updates in your model. The library will
automatically stop sending updates when the animation is complete.

    import SmoothMoveSub exposing (subscriptions)

    type Msg
        = StartMove Float Float
        | AnimationFrame Float
        | NoOp

    subscriptions : Model -> Sub Msg
    subscriptions model =
        SmoothMoveSub.subscriptions model.smoothMove AnimationFrame

    update msg model =
        case msg of
            StartMove targetX targetY ->
                let
                    newSmoothMove =
                        startAnimationTo "element-id" targetX targetY model.smoothMove
                in
                ( { model | smoothMove = newSmoothMove }, Cmd.none )

            AnimationFrame deltaMs ->
                let
                    newSmoothMove =
                        SmoothMoveSub.update deltaMs model.smoothMove
                in
                ( { model | smoothMove = newSmoothMove }
                , Cmd.none
                )

-}
subscriptions : Model -> (Float -> msg) -> Sub msg
subscriptions (Model modelData) toMsg =
    if not (Dict.values modelData |> List.any (\elementData -> elementData.animation /= Nothing)) then
        Sub.none

    else
        Browser.Events.onAnimationFrameDelta toMsg
