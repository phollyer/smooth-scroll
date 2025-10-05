module example/src/MultipleAnimations.elm exposing (main)

{-| Test if SmoothMoveSub can handle multiple animations simultaneously -}

import Browser exposing (Document)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import SmoothMoveSub exposing (transformElement, startAnimationTo)


main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { smoothMove : SmoothMoveSub.Model
    }


type Msg
    = StartElementA
    | StartElementB 
    | StartBoth
    | AnimationFrame Float
    | NoOp


init : () -> ( Model, Cmd Msg )
init _ =
    ( { smoothMove = SmoothMoveSub.init }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartElementA ->
            let
                newSmoothMove =
                    startAnimationTo "element-a" 300 100 model.smoothMove
            in
            ( { model | smoothMove = newSmoothMove }, Cmd.none )

        StartElementB ->
            let
                newSmoothMove =
                    startAnimationTo "element-b" 100 300 model.smoothMove
            in
            ( { model | smoothMove = newSmoothMove }, Cmd.none )

        StartBoth ->
            let
                smoothMove1 =
                    startAnimationTo "element-a" 400 50 model.smoothMove
                
                smoothMove2 =
                    startAnimationTo "element-b" 50 400 smoothMove1
            in
            ( { model | smoothMove = smoothMove2 }, Cmd.none )

        AnimationFrame deltaMs ->
            let
                newSmoothMove =
                    SmoothMoveSub.update deltaMs model.smoothMove
            in
            ( { model | smoothMove = newSmoothMove }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    SmoothMoveSub.subscriptions model.smoothMove AnimationFrame


view : Model -> Document Msg
view model =
    { title = "Multiple Animation Test"
    , body =
        [ div [ style "position" "relative", style "width" "100vw", style "height" "100vh" ]
            [ -- Element A
              div
                [ id "element-a"
                , style "position" "absolute"
                , style "width" "60px"
                , style "height" "60px"
                , style "background-color" "red"
                , style "border-radius" "50%"
                , style "transform" (transformElement "element-a" model.smoothMove)
                ]
                [ div [ style "color" "white", style "text-align" "center", style "line-height" "60px", style "font-weight" "bold" ]
                    [ text "A" ]
                ]
            
            -- Element B
            , div
                [ id "element-b"
                , style "position" "absolute"
                , style "width" "60px"
                , style "height" "60px"
                , style "background-color" "blue"
                , style "border-radius" "50%"
                , style "transform" (transformElement "element-b" model.smoothMove)
                ]
                [ div [ style "color" "white", style "text-align" "center", style "line-height" "60px", style "font-weight" "bold" ]
                    [ text "B" ]
                ]
            
            -- Controls
            , div [ style "margin" "20px" ]
                [ button [ onClick StartElementA ] [ text "Move A to (300, 100)" ]
                , button [ onClick StartElementB ] [ text "Move B to (100, 300)" ]  
                , button [ onClick StartBoth ] [ text "Move Both Simultaneously!" ]
                ]
            ]
        ]
    }