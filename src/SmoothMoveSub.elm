module SmoothMoveSub exposing
    ( Config
    , defaultConfig
    , Model
    , init
    , Position
    , startAnimation
    , startAnimationWithOptions
    , updateModel
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
    , transformPosition
    )

{-|


# Config

@docs Config
@docs defaultConfig


# Model-Based API (Recommended)

@docs Model
@docs init
@docs Position
@docs startAnimation
@docs startAnimationWithOptions
@docs updateModel
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
@docs transformPosition

-}

import Browser.Events
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


{-| Position information sent through subscriptions
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
    { elementId : String
    , startX : Float
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

-}
type Model
    = Model
        { elements : List ElementState
        , activeAnimation : Maybe AnimationState
        }


type alias ElementState =
    { elementId : String
    , currentX : Float
    , currentY : Float
    }


{-| Initialize an empty SmoothMoveSub model

    import SmoothMoveSub

    type alias Model =
        { smoothMove : SmoothMoveSub.Model
        }

    init : Model
    init =
        { smoothMove = SmoothMoveSub.init
        }

-}
init : Model
init =
    Model { elements = [], activeAnimation = Nothing }


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
startAnimationWithOptions config elementId startX startY targetX targetY (Model modelData) =
    let
        -- Update or add element position
        updatedElements =
            updateElementPosition elementId startX startY modelData.elements

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
            { elementId = elementId
            , startX = startX
            , startY = startY
            , targetX = targetX
            , targetY = targetY
            , config = config
            , startedAt = 0
            , duration = duration
            }
    in
    Model { elements = updatedElements, activeAnimation = Just animationState }


{-| Update the model with animation frame data

This function handles all the internal state management automatically.
You call this in response to the animation frame messages from subscriptions.

    import SmoothMoveSub

    type Msg
        = AnimationFrame Float Position
        | StartMove Float Float

    update msg model =
        case msg of
            AnimationFrame deltaMs position ->
                let
                    newSmoothMove =
                        SmoothMoveSub.updateModel deltaMs model.smoothMove
                in
                ( { model
                    | smoothMove = newSmoothMove
                    , elementPosition = { x = position.x, y = position.y }
                  }
                , Cmd.none
                )

-}
updateModel : Float -> Model -> ( Model, Maybe Position )
updateModel deltaMs (Model modelData) =
    case modelData.activeAnimation of
        Nothing ->
            ( Model modelData, Nothing )

        Just state ->
            let
                ( newState, position ) =
                    updateAnimation deltaMs state

                -- Update element position in our internal tracking
                updatedElements =
                    updateElementPosition state.elementId position.x position.y modelData.elements
            in
            if position.isComplete then
                ( Model { elements = updatedElements, activeAnimation = Nothing }, Just position )

            else
                ( Model { elements = updatedElements, activeAnimation = Just newState }, Just position )


{-| Check if the model is idle (no animation running)

    if SmoothMoveSub.isIdle model.smoothMove then
        text "No animation"

    else
        text "Animation running"

-}
isIdle : Model -> Bool
isIdle (Model modelData) =
    case modelData.activeAnimation of
        Nothing ->
            True

        Just _ ->
            False


{-| Check if the model is animating

    if SmoothMoveSub.isAnimating model.smoothMove then
        text "Animation running"

    else
        text "No animation"

-}
isAnimating : Model -> Bool
isAnimating model =
    not (isIdle model)


{-| Get the current position of an element

    case SmoothMoveSub.getCurrentPosition "my-element" model.smoothMove of
        Just { x, y } ->
            div [ style "transform" (transform x y) ] [ text "Element" ]

        Nothing ->
            text "Element not found"

-}
getCurrentPosition : String -> Model -> Maybe { x : Float, y : Float }
getCurrentPosition elementId (Model modelData) =
    modelData.elements
        |> List.filter (\element -> element.elementId == elementId)
        |> List.head
        |> Maybe.map (\element -> { x = element.currentX, y = element.currentY })


{-| Get all element IDs currently tracked by the model

    elementIds =
        SmoothMoveSub.getElementIds model.smoothMove

-}
getElementIds : Model -> List String
getElementIds (Model modelData) =
    List.map .elementId modelData.elements


{-| Helper function to update element position in the list
-}
updateElementPosition : String -> Float -> Float -> List ElementState -> List ElementState
updateElementPosition elementId x y elements =
    let
        updateElement element =
            if element.elementId == elementId then
                { element | currentX = x, currentY = y }

            else
                element

        elementExists =
            List.any (\element -> element.elementId == elementId) elements
    in
    if elementExists then
        List.map updateElement elements

    else
        { elementId = elementId, currentX = x, currentY = y } :: elements


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
moveToWithOptions config elementId startX startY targetX targetY =
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
    { elementId = elementId
    , startX = startX
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
            , elementId = state.elementId
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


{-| Create a CSS transform string from a Position record

    import Html exposing (div)
    import Html.Attributes exposing (style)
    import SmoothMoveSub exposing (transformPosition)

    -- Use directly with a Position record
    div [ style "transform" (transformPosition position) ] [ text "Moving element" ]

-}
transformPosition : Position -> String
transformPosition position =
    transform position.x position.y


{-| Simplified subscription function that handles animation logic internally

This function takes care of all the animation frame updates and state management.
You just need to handle the Position updates in your model. The library will
automatically stop sending updates when the animation is complete.

    import SmoothMoveSub exposing (subscriptions)

    type Msg
        = StartMove Float Float
        | PositionUpdate Position
        | NoOp

    subscriptions : Model -> Sub Msg
    subscriptions model =
        SmoothMoveSub.subscriptions model.animationState PositionUpdate

    update msg model =
        case msg of
            StartMove targetX targetY ->
                let
                    animState =
                        moveTo "element-id" model.position.x model.position.y targetX targetY
                in
                ( { model | animationState = Just animState }, Cmd.none )

            PositionUpdate position ->
                ( { model
                    | position = { x = position.x, y = position.y }
                    , animationState =
                        if position.isComplete then
                            Nothing

                        else
                            model.animationState
                  }
                , Cmd.none
                )

-}
subscriptions : Model -> (Float -> Position -> msg) -> Sub msg
subscriptions (Model modelData) toMsg =
    case modelData.activeAnimation of
        Nothing ->
            Sub.none

        Just state ->
            if isAnimationComplete state then
                Sub.none

            else
                Browser.Events.onAnimationFrameDelta
                    (\deltaMs ->
                        let
                            ( _, position ) =
                                updateAnimation deltaMs state
                        in
                        toMsg deltaMs position
                    )
