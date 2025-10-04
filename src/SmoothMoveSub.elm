module SmoothMoveSub exposing
    ( Config
    , defaultConfig
    , Axis(..)
    , Model
    , init
    , update
    , startAnimationTo
    , subscriptions
    , isAnimating
    , getCurrentPosition
    , transformElement
    )

{-|


# Config

@docs Config
@docs defaultConfig
@docs Axis


# Model-Based API

@docs Model
@docs init
@docs update
@docs startAnimationTo
@docs subscriptions
@docs isAnimating
@docs getCurrentPosition


# Styling Helper

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


type alias AnimationState =
    { startX : Float
    , startY : Float
    , targetX : Float
    , targetY : Float
    , currentX : Float
    , currentY : Float
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
    { lastX : Float
    , lastY : Float
    , animation : Maybe AnimationState
    }


{-| Initialize the model with no active animations

    init =
        SmoothMoveSub.init

-}
init : Model
init =
    Model Dict.empty


{-| Start an animation to a target position, automatically using the current position as the starting point

This is a convenience function that combines getCurrentPosition with startAnimation.
If the element has no current position, it defaults to (0, 0).

    import SmoothMoveSub

    newModel =
        SmoothMoveSub.startAnimationTo "my-element" 200 300 model.smoothMove

-}
startAnimationTo : String -> Float -> Float -> Model -> Model
startAnimationTo elementId targetX targetY (Model elementsDict) =
    let
        currentPos =
            getCurrentPosition elementId (Model elementsDict)
                |> Maybe.withDefault { x = 0, y = 0 }

        config =
            defaultConfig

        startX =
            currentPos.x

        startY =
            currentPos.y

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
            , currentX = startX
            , currentY = startY
            , config = config
            , startedAt = 0
            , duration = duration
            }

        elementData =
            { lastX = startX
            , lastY = startY
            , animation = Just animationState
            }

        updatedDict =
            Dict.insert elementId elementData elementsDict
    in
    Model updatedDict


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
        updateElementData _ elementData =
            case elementData.animation of
                -- No animation, keep current state
                Nothing ->
                    elementData

                Just animationState ->
                    let
                        updatedState =
                            updateAnimation deltaMs animationState
                    in
                    if isAnimationComplete updatedState then
                        -- Animation complete, save final position
                        { elementData
                            | animation = Nothing
                            , lastX = updatedState.targetX
                            , lastY = updatedState.targetY
                        }

                    else
                        { elementData | animation = Just updatedState }

        updatedDict =
            Dict.map updateElementData elementsDict
    in
    Model updatedDict


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
        |> Maybe.map
            (\elementData ->
                case elementData.animation of
                    Just animationState ->
                        { x = animationState.currentX, y = animationState.currentY }

                    Nothing ->
                        { x = elementData.lastX, y = elementData.lastY }
            )


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


{-| Check if animation is complete by comparing current position to target position
-}
isAnimationComplete : AnimationState -> Bool
isAnimationComplete state =
    let
        xComplete =
            case state.config.axis of
                Y ->
                    True

                -- X axis not animated, so always complete
                _ ->
                    abs (state.currentX - state.targetX) < 0.1

        yComplete =
            case state.config.axis of
                X ->
                    True

                -- Y axis not animated, so always complete
                _ ->
                    abs (state.currentY - state.targetY) < 0.1
    in
    xComplete && yComplete


{-| Update animation state with elapsed time and current position
-}
updateAnimation : Float -> AnimationState -> AnimationState
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
    in
    { state
        | startedAt = newElapsedTime
        , currentX = currentX
        , currentY = currentY
    }


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
