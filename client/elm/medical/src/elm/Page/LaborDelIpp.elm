module Page.LaborDelIpp
    exposing
        ( Model
        , buildModel
        , closeAllDialogs
        , getTablesByCacheOrServer
        , init
        , update
        , view
        )

-- LOCAL IMPORTS --

import Const exposing (Dialog(..), FldChgValue(..))
import Data.Baby
    exposing
        ( ApgarScore(..)
        , BabyId(..)
        , BabyRecord
        , BabyRecordNew
        , Sex(..)
        , apgarRecordListToApgarScoreDict
        , apgarScoreDictToApgarRecordList
        , babyRecordNewToValue
        , babyRecordToValue
        , getCustomScoresAsList
        , getScoreAsStringByMinute
        , getScoresAsList
        , isBabyRecordFullyComplete
        , maybeSexToString
        , sexToFullString
        , sexToString
        , stringToSex
        )
import Data.DataCache as DataCache exposing (DataCache(..))
import Data.DatePicker exposing (DateField(..), DateFieldMessage(..), dateFieldToString)
import Data.Labor
    exposing
        ( LaborId(..)
        , LaborRecord
        , LaborRecordNew
        , getLaborId
        , laborRecordNewToLaborRecord
        , laborRecordNewToValue
        , laborRecordToValue
        )
import Data.LaborDelIpp
    exposing
        ( AddOtherApgar(..)
        , Field(..)
        , SubMsg(..)
        )
import Data.LaborStage1
    exposing
        ( LaborStage1Id(..)
        , LaborStage1Record
        , LaborStage1RecordNew
        , laborStage1RecordNewToLaborStage1Record
        , laborStage1RecordNewToValue
        , laborStage1RecordToValue
        )
import Data.LaborStage2
    exposing
        ( LaborStage2Record
        , LaborStage2RecordNew
        , isLaborStage2RecordComplete
        , laborStage2RecordNewToValue
        , laborStage2RecordToValue
        )
import Data.LaborStage3
    exposing
        ( LaborStage3Record
        , LaborStage3RecordNew
        , isLaborStage3RecordComplete
        , laborStage3RecordNewToValue
        , laborStage3RecordToValue
        , schultzDuncan2String
        , string2SchultzDuncan
        )
import Data.Log exposing (Severity(..))
import Data.Membrane
    exposing
        ( MembraneRecord
        , MembraneRecordNew
        , isMembraneRecordComplete
        , membraneRecordNewToValue
        , membraneRecordToValue
        )
import Data.Message exposing (MsgType(..), wrapPayload)
import Data.Patient exposing (PatientRecord)
import Data.Pregnancy exposing (PregnancyId(..), PregnancyRecord, getPregId)
import Data.PregnancyHeader as PregHeaderData
import Data.Processing exposing (ProcessId(..))
import Data.SelectQuery exposing (SelectQuery, selectQueryToValue)
import Data.Session as Session exposing (Session)
import Data.Table exposing (Table(..), tableToString)
import Data.Toast exposing (ToastType(..))
import Date exposing (Date, Month(..), day, month, year)
import Date.Extra.Compare as DEComp
import Dict exposing (Dict)
import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Json.Decode as JD
import List.Extra as LE
import Msg
    exposing
        ( Msg(..)
        , ProcessType(..)
        , logError
        , logInfo
        , logWarning
        , toastError
        , toastInfo
        , toastWarn
        )
import Page.Errored as Errored exposing (PageLoadError)
import Ports
import Processing exposing (ProcessStore)
import Route
import Task exposing (Task)
import Time exposing (Time)
import Util as U exposing ((=>))
import Validate exposing (ifBlank, ifInvalid, ifNotInt)
import Views.Form as Form
import Views.PregnancyHeader as PregHeaderView
import Window


-- MODEL --


type DateTimeModal
    = NoDateTimeModal
    | Stage1DateTimeModal
    | Stage2DateTimeModal
    | Stage3DateTimeModal
    | EarlyLaborDateTimeModal


type ViewEditState
    = NoViewEditState
    | BabyEditState
    | BabyViewState
    | MembraneEditState
    | MembraneViewState
    | Stage1EditState
    | Stage1ViewState
    | Stage2EditState
    | Stage2ViewState
    | Stage3EditState
    | Stage3ViewState


type alias Model =
    { browserSupportsDate : Bool
    , currTime : Time
    , pregnancy_id : PregnancyId
    , currLaborId : Maybe LaborId
    , currPregHeaderContent : PregHeaderData.PregHeaderContent
    , dataCache : Dict String DataCache
    , pendingSelectQuery : Dict String Table
    , patientRecord : Maybe PatientRecord
    , pregnancyRecord : Maybe PregnancyRecord
    , laborRecord : Maybe LaborRecord
    , laborStage1Record : Maybe LaborStage1Record
    , laborStage2Record : Maybe LaborStage2Record
    , laborStage3Record : Maybe LaborStage3Record
    , babyRecord : Maybe BabyRecord
    , membraneRecord : Maybe MembraneRecord
    , admittanceDate : Maybe Date
    , admittanceTime : Maybe String
    , laborDate : Maybe Date
    , laborTime : Maybe String
    , pos : Maybe String
    , fh : Maybe String
    , fht : Maybe String
    , systolic : Maybe String
    , diastolic : Maybe String
    , cr : Maybe String
    , temp : Maybe String
    , comments : Maybe String
    , formErrors : List FieldError
    , stage1DateTimeModal : DateTimeModal
    , stage1Date : Maybe Date
    , stage1Time : Maybe String
    , stage1SummaryModal : ViewEditState
    , s1Mobility : Maybe String
    , s1DurationLatentHours : Maybe String
    , s1DurationLatentMinutes : Maybe String
    , s1DurationActiveMinutes : Maybe String
    , s1DurationActiveHours : Maybe String
    , s1Comments : Maybe String
    , stage2DateTimeModal : DateTimeModal
    , stage2Date : Maybe Date
    , stage2Time : Maybe String
    , stage2SummaryModal : ViewEditState
    , s2BirthType : Maybe String
    , s2BirthPosition : Maybe String
    , s2DurationPushing : Maybe String
    , s2BirthPresentation : Maybe String
    , s2TerminalMec : Maybe Bool
    , s2CordWrapType : Maybe String
    , s2DeliveryType : Maybe String
    , s2ShoulderDystocia : Maybe Bool
    , s2ShoulderDystociaMinutes : Maybe String
    , s2Laceration : Maybe Bool
    , s2Episiotomy : Maybe Bool
    , s2Repair : Maybe Bool
    , s2Degree : Maybe String
    , s2LacerationRepairedBy : Maybe String
    , s2BirthEBL : Maybe String
    , s2Meconium : Maybe String
    , s2Comments : Maybe String
    , stage3DateTimeModal : DateTimeModal
    , stage3Date : Maybe Date
    , stage3Time : Maybe String
    , stage3SummaryModal : ViewEditState
    , s3PlacentaDeliverySpontaneous : Maybe Bool
    , s3PlacentaDeliveryAMTSL : Maybe Bool
    , s3PlacentaDeliveryCCT : Maybe Bool
    , s3PlacentaDeliveryManual : Maybe Bool
    , s3MaternalPosition : Maybe String
    , s3TxBloodLoss1 : Maybe String
    , s3TxBloodLoss2 : Maybe String
    , s3TxBloodLoss3 : Maybe String
    , s3TxBloodLoss4 : Maybe String
    , s3TxBloodLoss5 : Maybe String
    , s3PlacentaShape : Maybe String
    , s3PlacentaInsertion : Maybe String
    , s3PlacentaNumVessels : Maybe String
    , s3SchultzDuncan : Maybe String
    , s3Cotyledons : Maybe String
    , s3Membranes : Maybe String
    , s3Comments : Maybe String
    , membraneSummaryModal : ViewEditState
    , membraneRuptureDate : Maybe Date
    , membraneRuptureTime : Maybe String
    , membraneRupture : Maybe String
    , membraneRuptureComment : Maybe String
    , membraneAmniotic : Maybe String
    , membraneAmnioticComment : Maybe String
    , membraneComments : Maybe String
    , babySummaryModal : ViewEditState
    , bbBirthNbr : Maybe String
    , bbLastname : Maybe String
    , bbFirstname : Maybe String
    , bbMiddlename : Maybe String
    , bbSex : Maybe String
    , bbBirthWeight : Maybe String
    , bbBFedEstablishedDate : Maybe Date
    , bbBFedEstablishedTime : Maybe String
    , bbBulb : Maybe Bool
    , bbMachine : Maybe Bool
    , bbFreeFlowO2 : Maybe Bool
    , bbChestCompressions : Maybe Bool
    , bbPpv : Maybe Bool
    , bbComments : Maybe String
    , apgarScores : Dict Int ApgarScore
    , pendingApgarWizard : AddOtherApgar
    , pendingApgarMinute : Maybe String
    , pendingApgarScore : Maybe String
    }


{-| Updates the model to close all dialogs. Called by Medical.update in
the SetRoute message. This allows the back button to close a dialog.
-}
closeAllDialogs : Model -> Model
closeAllDialogs model =
    { model
        | stage1SummaryModal = NoViewEditState
        , stage1DateTimeModal = NoDateTimeModal
        , stage2SummaryModal = NoViewEditState
        , stage2DateTimeModal = NoDateTimeModal
        , stage3SummaryModal = NoViewEditState
        , stage3DateTimeModal = NoDateTimeModal
        , membraneSummaryModal = NoViewEditState
        , babySummaryModal = NoViewEditState
    }


{-| Builds the initial model for the page. If the pregnancy has more than
one labor record, the most recent is always chosen.
-}
buildModel :
    Bool
    -> Time
    -> ProcessStore
    -> PregnancyId
    -> Maybe PatientRecord
    -> Maybe PregnancyRecord
    -> Maybe LaborRecord
    -> ( Model, ProcessStore, Cmd Msg )
buildModel browserSupportsDate currTime store pregId patrec pregRec laborRec =
    let
        -- Sort by the admittanceDate, descending.
        admitSort a b =
            U.sortDate U.DescendingSort a.admittanceDate b.admittanceDate

        -- Determine state of the labor by labor records, if any, and
        -- request additional records from the server if needed.
        ( laborId, newOuterMsg ) =
            case laborRec of
                Just rec ->
                    ( Just <| LaborId rec.id
                    , getTables
                        Labor
                        (Just rec.id)
                        [ LaborStage1, LaborStage2, LaborStage3, Baby, Membrane ]
                    )

                Nothing ->
                    -- Since no labor is selected, we cannot be on this page.
                    ( Nothing
                    , Just Route.AdmittingRoute
                        |> Task.succeed
                        |> Task.perform SetRoute
                    )
    in
    ( { browserSupportsDate = browserSupportsDate
      , currTime = currTime
      , pregnancy_id = pregId
      , currLaborId = laborId
      , currPregHeaderContent = PregHeaderData.LaborContent
      , dataCache = Dict.empty
      , pendingSelectQuery = Dict.empty
      , patientRecord = patrec
      , pregnancyRecord = pregRec
      , laborRecord = laborRec
      , laborStage1Record = Nothing
      , laborStage2Record = Nothing
      , laborStage3Record = Nothing
      , babyRecord = Nothing
      , membraneRecord = Nothing
      , admittanceDate = Nothing
      , admittanceTime = Nothing
      , laborDate = Nothing
      , laborTime = Nothing
      , pos = Nothing
      , fh = Nothing
      , fht = Nothing
      , systolic = Nothing
      , diastolic = Nothing
      , cr = Nothing
      , temp = Nothing
      , comments = Nothing
      , formErrors = []
      , stage1DateTimeModal = NoDateTimeModal
      , stage1Date = Nothing
      , stage1Time = Nothing
      , stage1SummaryModal = NoViewEditState
      , s1Mobility = Nothing
      , s1DurationLatentHours = Nothing
      , s1DurationLatentMinutes = Nothing
      , s1DurationActiveHours = Nothing
      , s1DurationActiveMinutes = Nothing
      , s1Comments = Nothing
      , stage2DateTimeModal = NoDateTimeModal
      , stage2Date = Nothing
      , stage2Time = Nothing
      , stage2SummaryModal = NoViewEditState
      , s2BirthType = Nothing
      , s2BirthPosition = Nothing
      , s2DurationPushing = Nothing
      , s2BirthPresentation = Nothing
      , s2TerminalMec = Nothing
      , s2CordWrapType = Nothing
      , s2DeliveryType = Nothing
      , s2ShoulderDystocia = Nothing
      , s2ShoulderDystociaMinutes = Nothing
      , s2Laceration = Nothing
      , s2Episiotomy = Nothing
      , s2Repair = Nothing
      , s2Degree = Nothing
      , s2LacerationRepairedBy = Nothing
      , s2BirthEBL = Nothing
      , s2Meconium = Nothing
      , s2Comments = Nothing
      , stage3DateTimeModal = NoDateTimeModal
      , stage3Date = Nothing
      , stage3Time = Nothing
      , stage3SummaryModal = NoViewEditState
      , s3PlacentaDeliverySpontaneous = Nothing
      , s3PlacentaDeliveryAMTSL = Nothing
      , s3PlacentaDeliveryCCT = Nothing
      , s3PlacentaDeliveryManual = Nothing
      , s3MaternalPosition = Nothing
      , s3TxBloodLoss1 = Nothing
      , s3TxBloodLoss2 = Nothing
      , s3TxBloodLoss3 = Nothing
      , s3TxBloodLoss4 = Nothing
      , s3TxBloodLoss5 = Nothing
      , s3PlacentaShape = Nothing
      , s3PlacentaInsertion = Nothing
      , s3PlacentaNumVessels = Nothing
      , s3SchultzDuncan = Nothing
      , s3Cotyledons = Nothing
      , s3Membranes = Nothing
      , s3Comments = Nothing
      , membraneSummaryModal = NoViewEditState
      , membraneRuptureDate = Nothing
      , membraneRuptureTime = Nothing
      , membraneRupture = Nothing
      , membraneRuptureComment = Nothing
      , membraneAmniotic = Nothing
      , membraneAmnioticComment = Nothing
      , membraneComments = Nothing
      , babySummaryModal = NoViewEditState
      , bbBirthNbr = Nothing
      , bbLastname = Nothing
      , bbFirstname = Nothing
      , bbMiddlename = Nothing
      , bbSex = Nothing
      , bbBirthWeight = Nothing
      , bbBFedEstablishedDate = Nothing
      , bbBFedEstablishedTime = Nothing
      , bbBulb = Nothing
      , bbMachine = Nothing
      , bbFreeFlowO2 = Nothing
      , bbChestCompressions = Nothing
      , bbPpv = Nothing
      , bbComments = Nothing
      , apgarScores = Dict.empty
      , pendingApgarWizard = NotStartedAddOtherApgar
      , pendingApgarMinute = Nothing
      , pendingApgarScore = Nothing
      }
    , store
    , newOuterMsg
    )


{-| Generate an top-level module command to retrieve additional data which checks
first in the data cache, and secondarily from the server.
-}
getTables : Table -> Maybe Int -> List Table -> Cmd Msg
getTables table key relatedTables =
    Task.perform
        (always (LaborDelIppSelectQuery table key relatedTables))
        (Task.succeed True)


{-| Retrieve additional data from the server as may be necessary after the page is
fully loaded, but get the data from the data cache instead of the server, if available.

This is called by the top-level module which passes it's data cache for our use.

-}
getTablesByCacheOrServer : ProcessStore -> Table -> Maybe Int -> List Table -> Dict String DataCache -> ( ProcessStore, Cmd Msg )
getTablesByCacheOrServer store table key relatedTbls dataCache =
    let
        -- Determine if the cache has all of the data that we need.
        isCached =
            List.all
                (\t -> U.isJust <| DataCache.get t dataCache)
                (table :: relatedTbls)

        -- We add the primary table to the list of tables affected so
        -- that refreshModelFromCache will update our model for the
        -- primary table as well as the related tables.
        dataCacheTables =
            relatedTbls ++ [ table ]

        ( newStore, newCmd ) =
            if isCached then
                let
                    cachedMsg =
                        Data.LaborDelIpp.DataCache Nothing (Just dataCacheTables)
                            |> LaborDelIppMsg
                in
                store => Task.perform (always cachedMsg) (Task.succeed True)
            else
                let
                    selectQuery =
                        SelectQuery table key relatedTbls

                    ( processId, processStore ) =
                        Processing.add
                            (SelectQueryType
                                (LaborDelIppMsg
                                    (DataCache Nothing (Just dataCacheTables))
                                )
                                selectQuery
                            )
                            Nothing
                            store

                    jeVal =
                        wrapPayload processId SelectMsgType (selectQueryToValue selectQuery)
                in
                processStore => Ports.outgoing jeVal
    in
    newStore => newCmd


{-| On initialization, the Model will be updated by a call to buildModel once
the initial data has arrived from the server. Hence, the SubMsg does not need
to be DataCache, which is used subsequent to first page load.
-}
init : PregnancyId -> Session -> ProcessStore -> ( ProcessStore, Cmd Msg )
init pregId session store =
    let
        selectQuery =
            SelectQuery Pregnancy (Just (getPregId pregId)) [ Patient, Labor ]

        ( processId, processStore ) =
            Processing.add (SelectQueryType (LaborDelIppLoaded pregId) selectQuery) Nothing store

        msg =
            wrapPayload processId SelectMsgType (selectQueryToValue selectQuery)
    in
    processStore
        => Ports.outgoing msg


view : Maybe Window.Size -> Session -> Model -> Html SubMsg
view size session model =
    let
        isEditingS1 =
            if model.stage1SummaryModal == Stage1EditState then
                True
            else
                not (isStage1SummaryDone model)

        isEditingS2 =
            if model.stage2SummaryModal == Stage2EditState then
                True
            else
                not (isStage2SummaryDone model)

        isEditingS3 =
            if model.stage3SummaryModal == Stage3EditState then
                True
            else
                not (isStage3SummaryDone model)

        isEditingMembrane =
            if model.membraneSummaryModal == MembraneEditState then
                True
            else
                not (isMembraneSummaryDone model)

        isEditingBaby =
            if model.babySummaryModal == BabyEditState then
                True
            else
                not (isBabySummaryDone model)

        dialogStage1Config =
            DialogSummary
                (model.stage1SummaryModal
                    == Stage1ViewState
                    || model.stage1SummaryModal
                    == Stage1EditState
                )
                isEditingS1
                "Stage 1 Summary"
                model
                (HandleStage1SummaryModal CloseNoSaveDialog)
                (HandleStage1SummaryModal CloseSaveDialog)
                (HandleStage1SummaryModal EditDialog)

        dialogStage2Config =
            DialogSummary
                (model.stage2SummaryModal
                    == Stage2ViewState
                    || model.stage2SummaryModal
                    == Stage2EditState
                )
                isEditingS2
                "Stage 2 Summary"
                model
                (HandleStage2SummaryModal CloseNoSaveDialog)
                (HandleStage2SummaryModal CloseSaveDialog)
                (HandleStage2SummaryModal EditDialog)

        dialogStage3Config =
            DialogSummary
                (model.stage3SummaryModal
                    == Stage3ViewState
                    || model.stage3SummaryModal
                    == Stage3EditState
                )
                isEditingS3
                "Stage 3 Summary"
                model
                (HandleStage3SummaryModal CloseNoSaveDialog)
                (HandleStage3SummaryModal CloseSaveDialog)
                (HandleStage3SummaryModal EditDialog)

        dialogMembraneConfig =
            DialogSummary
                (model.membraneSummaryModal
                    == MembraneViewState
                    || model.membraneSummaryModal
                    == MembraneEditState
                )
                isEditingMembrane
                "Membrane Summary"
                model
                (HandleMembraneSummaryModal CloseNoSaveDialog)
                (HandleMembraneSummaryModal CloseSaveDialog)
                (HandleMembraneSummaryModal EditDialog)

        dialogBabyConfig =
            DialogSummary
                (model.babySummaryModal
                    == BabyViewState
                    || model.babySummaryModal
                    == BabyEditState
                )
                isEditingBaby
                "Baby"
                model
                (HandleBabySummaryModal CloseNoSaveDialog)
                (HandleBabySummaryModal CloseSaveDialog)
                (HandleBabySummaryModal EditDialog)

        -- Ascertain whether we have a labor in process already.
        pregHeader =
            case ( model.patientRecord, model.pregnancyRecord ) of
                ( Just patRec, Just pregRec ) ->
                    let
                        laborInfo =
                            PregHeaderData.LaborInfo model.laborRecord
                                model.laborStage1Record
                                model.laborStage2Record
                                model.laborStage3Record
                                []
                    in
                    PregHeaderView.view patRec
                        pregRec
                        laborInfo
                        model.currPregHeaderContent
                        model.currTime
                        size

                ( _, _ ) ->
                    H.text ""
    in
    H.div []
        [ pregHeader |> H.map (\a -> RotatePregHeaderContent a)
        , H.div [ HA.class "content-wrapper" ]
            [ viewLaborDetails model
            , dialogStage1Summary dialogStage1Config
            , dialogMembraneSummary dialogMembraneConfig
            , dialogStage2Summary dialogStage2Config
            , dialogStage3Summary dialogStage3Config
            , dialogBabySummary dialogBabyConfig

            --, viewDetailsTableTEMP model
            , viewDetailsNotImplemented model
            ]
        ]


viewLaborDetails : Model -> Html SubMsg
viewLaborDetails model =
    H.div [ HA.class "content-flex-wrapper" ]
        [ viewStagesMembranesBaby model ]


viewDetailsNotImplemented : Model -> Html SubMsg
viewDetailsNotImplemented model =
    H.h3
        []
        [ H.text "Use paper for labor details" ]


{-| This is a placeholder for now in order to get a better idea of what the
page will look like eventually.
-}
viewDetailsTableTEMP : Model -> Html SubMsg
viewDetailsTableTEMP model =
    H.table
        [ HA.class "c-table c-table--striped u-small"
        , HA.style [ ( "margin-top", "1em" ) ]
        ]
        [ H.thead [ HA.class "c-table__head" ]
            [ H.tr [ HA.class "c-table__row c-table__row--heading" ]
                [ H.th
                    [ HA.class "c-table__cell"
                    , HA.style [ ( "flex", "0 0 8em" ) ]
                    ]
                    [ H.text "Date" ]
                , H.th
                    [ HA.class "c-table__cell"
                    , HA.style [ ( "flex", "0 0 6em" ) ]
                    ]
                    [ H.text "Time" ]
                , H.th [ HA.class "c-table__cell" ]
                    [ H.text "Dln" ]
                , H.th [ HA.class "c-table__cell" ]
                    [ H.text "Sys" ]
                , H.th [ HA.class "c-table__cell" ]
                    [ H.text "Dia" ]
                , H.th [ HA.class "c-table__cell" ]
                    [ H.text "FHT" ]
                , H.th
                    [ HA.style [ ( "flex", "0 0 50%" ) ]
                    ]
                    [ H.text "Comments" ]
                ]
            ]
        , H.tbody [ HA.class "c-table__body" ]
            [ H.tr [ HA.class "c-table__row" ]
                [ H.td
                    [ HA.class "c-table__cell"
                    , HA.style [ ( "flex", "0 0 8em" ) ]
                    ]
                    [ H.text "11-18-2017" ]
                , H.td
                    [ HA.class "c-table__cell"
                    , HA.style [ ( "flex", "0 0 6em" ) ]
                    ]
                    [ H.text "04:17 AM" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "122" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "85" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "148" ]
                , H.td
                    [ HA.style [ ( "flex", "0 0 50%" ) ]
                    ]
                    [ H.text "Pt reports spotting just now. Pt report ctx starting at 8pm yesterday 15-30 min apart. Pt report BOW intact." ]
                ]
            , H.tr [ HA.class "c-table__row" ]
                [ H.td
                    [ HA.class "c-table__cell"
                    , HA.style [ ( "flex", "0 0 8em" ) ]
                    ]
                    [ H.text "11-18-2017" ]
                , H.td
                    [ HA.class "c-table__cell"
                    , HA.style [ ( "flex", "0 0 6em" ) ]
                    ]
                    [ H.text "04:37 AM" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "" ]
                , H.td [ HA.class "c-table__cell" ]
                    [ H.text "140" ]
                , H.td
                    [ HA.style [ ( "flex", "0 0 50%" ) ]
                    ]
                    [ H.text "POS: ROA" ]
                ]
            ]
        ]


{-| Determine if the summary fields of stage one
are sufficiently populated. Note that this does not
include the fullDialation field.
-}
isStage1SummaryDone : Model -> Bool
isStage1SummaryDone model =
    case model.laborStage1Record of
        Just rec ->
            case
                ( rec.mobility
                , rec.durationLatent
                , rec.durationActive
                )
            of
                ( Just _, Just _, Just _ ) ->
                    True

                ( _, _, _ ) ->
                    False

        Nothing ->
            False


getErr : Field -> List FieldError -> String
getErr fld errors =
    case LE.find (\fe -> Tuple.first fe == fld) errors of
        Just fe ->
            Tuple.second fe

        Nothing ->
            ""


isStage2SummaryDone : Model -> Bool
isStage2SummaryDone model =
    case model.laborStage2Record of
        Just rec ->
            isLaborStage2RecordComplete rec

        _ ->
            False


isStage3SummaryDone : Model -> Bool
isStage3SummaryDone model =
    case model.laborStage3Record of
        Just rec ->
            isLaborStage3RecordComplete rec

        _ ->
            False


isMembraneSummaryDone : Model -> Bool
isMembraneSummaryDone model =
    case model.membraneRecord of
        Just rec ->
            isMembraneRecordComplete rec

        Nothing ->
            False


isBabySummaryDone : Model -> Bool
isBabySummaryDone model =
    case model.babyRecord of
        Just rec ->
            isBabyRecordFullyComplete rec

        _ ->
            False


{-| View the buttons used to set stage 1, 2, and 3 date/time
and related fields, the membranes fields, and the initial baby record.
Do not show all options, but only what makes sense for this progression
of the labor.

Logic:

  - hide stage 2 if stage 1 is hidden or labor stage 1 does not exist
    or does not have fullDialation set.
  - hide stage 3 if stage 2 is hidden or labor stage 2 does not exist
    or does not have birthDatetime set.
  - hide baby if stage 2 is hidden or if labor stage 2 does not exist
    or does not have the birthDatetime set.

-}
viewStagesMembranesBaby : Model -> Html SubMsg
viewStagesMembranesBaby model =
    let
        hideFalse =
            case ( model.laborStage1Record, model.membraneRecord ) of
                ( Just s1Rec, Nothing ) ->
                    s1Rec.fullDialation /= Nothing

                ( _, Just memRec ) ->
                    True

                ( Nothing, Nothing ) ->
                    False

        hideS2 =
            case model.laborStage1Record of
                Just rec ->
                    rec.fullDialation == Nothing

                Nothing ->
                    True

        hideS3 =
            hideS2
                || (case model.laborStage2Record of
                        Just rec ->
                            rec.birthDatetime == Nothing

                        Nothing ->
                            True
                   )

        hideBaby =
            hideS3

        hideMembrane =
            model.babyRecord == Nothing

        -- Raise an alert if placenta number of vessels is set to 2.
        placentaNumVesselsAlert =
            case model.laborStage3Record of
                Just ls3Rec ->
                    case ls3Rec.placentaNumVessels of
                        Just num ->
                            num == 2

                        Nothing ->
                            False

                Nothing ->
                    False
    in
    H.div [ HA.class "stage-wrapper" ]
        [ H.div
            [ HA.class "stage-content"
            , HA.classList [ ( "isHidden", hideMembrane ) ]
            ]
            [ H.div [ HA.class "c-text--brand c-text--loud" ]
                [ H.text "Membrane" ]
            , H.div []
                [ H.button
                    [ HA.class "c-button c-button--ghost-brand u-small"
                    , HE.onClick <| HandleMembraneSummaryModal OpenDialog
                    ]
                    [ if isMembraneSummaryDone model then
                        H.i [ HA.class "fa fa-check" ]
                            [ H.text "" ]
                      else
                        H.span [] [ H.text "" ]
                    , H.text " Summary"
                    ]
                ]
            ]
        , H.div
            [ HA.class "stage-content"
            ]
            [ H.div [ HA.class "c-text--brand c-text--loud" ]
                [ H.text "Stage 1 Ended" ]
            , H.div []
                [ H.label [ HA.class "c-field c-field--choice c-field-minPadding" ]
                    [ H.button
                        [ HA.class "c-button c-button--ghost-brand u-small"
                        , HE.onClick <| HandleStage1DateTimeModal OpenDialog
                        ]
                        [ H.text <|
                            case model.laborStage1Record of
                                Just ls1rec ->
                                    case ls1rec.fullDialation of
                                        Just d ->
                                            U.dateTimeHMFormatter
                                                U.MDYDateFmt
                                                U.DashDateSep
                                                d

                                        Nothing ->
                                            "Click to set"

                                Nothing ->
                                    "Click to set"
                        ]
                    , if model.browserSupportsDate then
                        Form.dateTimeModal (model.stage1DateTimeModal == Stage1DateTimeModal)
                            "Stage 1 Completed Date/Time"
                            (FldChgString >> FldChgSubMsg Stage1DateFld)
                            (FldChgString >> FldChgSubMsg Stage1TimeFld)
                            (HandleStage1DateTimeModal CloseNoSaveDialog)
                            (HandleStage1DateTimeModal CloseSaveDialog)
                            ClearStage1DateTime
                            model.stage1Date
                            model.stage1Time
                      else
                        Form.dateTimePickerModal (model.stage1DateTimeModal == Stage1DateTimeModal)
                            "Stage 1 Completed Date/Time"
                            OpenDatePickerSubMsg
                            (FldChgString >> FldChgSubMsg Stage1DateFld)
                            (FldChgString >> FldChgSubMsg Stage1TimeFld)
                            (HandleStage1DateTimeModal CloseNoSaveDialog)
                            (HandleStage1DateTimeModal CloseSaveDialog)
                            ClearStage1DateTime
                            LaborDelIppStage1DateField
                            model.stage1Date
                            model.stage1Time
                    ]
                ]
            , H.div []
                [ H.button
                    [ HA.class "c-button c-button--ghost-brand u-small"
                    , HE.onClick <| HandleStage1SummaryModal OpenDialog
                    ]
                    [ if isStage1SummaryDone model then
                        H.i [ HA.class "fa fa-check" ]
                            [ H.text "" ]
                      else
                        H.span [] [ H.text "" ]
                    , H.text " Summary"
                    ]
                ]
            ]
        , H.div
            [ HA.class "stage-content"
            , HA.classList [ ( "isHidden", hideS2 ) ]
            ]
            [ H.div [ HA.class "c-text--brand c-text--loud" ]
                [ H.text "Stage 2 Ended" ]
            , H.div []
                [ H.label [ HA.class "c-field c-field--choice c-field-minPadding" ]
                    [ H.button
                        [ HA.class "c-button c-button--ghost-brand u-small"
                        , HE.onClick <| HandleStage2DateTimeModal OpenDialog
                        ]
                        [ H.text <|
                            case model.laborStage2Record of
                                Just ls2rec ->
                                    case ls2rec.birthDatetime of
                                        Just d ->
                                            U.dateTimeHMFormatter
                                                U.MDYDateFmt
                                                U.DashDateSep
                                                d

                                        Nothing ->
                                            "Click to set"

                                Nothing ->
                                    "Click to set"
                        ]
                    , if model.browserSupportsDate then
                        Form.dateTimeModal (model.stage2DateTimeModal == Stage2DateTimeModal)
                            "Stage 2 Completed Date/Time"
                            (FldChgString >> FldChgSubMsg Stage2DateFld)
                            (FldChgString >> FldChgSubMsg Stage2TimeFld)
                            (HandleStage2DateTimeModal CloseNoSaveDialog)
                            (HandleStage2DateTimeModal CloseSaveDialog)
                            ClearStage2DateTime
                            model.stage2Date
                            model.stage2Time
                      else
                        Form.dateTimePickerModal (model.stage2DateTimeModal == Stage2DateTimeModal)
                            "Stage 2 Completed Date/Time"
                            OpenDatePickerSubMsg
                            (FldChgString >> FldChgSubMsg Stage2DateFld)
                            (FldChgString >> FldChgSubMsg Stage2TimeFld)
                            (HandleStage2DateTimeModal CloseNoSaveDialog)
                            (HandleStage2DateTimeModal CloseSaveDialog)
                            ClearStage2DateTime
                            LaborDelIppStage2DateField
                            model.stage2Date
                            model.stage2Time
                    ]
                ]
            , H.div []
                [ H.button
                    [ HA.class "c-button c-button--ghost-brand u-small"
                    , HE.onClick <| HandleStage2SummaryModal OpenDialog
                    ]
                    [ if isStage2SummaryDone model then
                        H.i [ HA.class "fa fa-check" ]
                            [ H.text "" ]
                      else
                        H.span [] [ H.text "" ]
                    , H.text " Summary"
                    ]
                ]
            ]
        , H.div
            [ HA.class "stage-content"
            , HA.classList [ ( "isHidden", hideS3 ) ]
            ]
            [ H.div [ HA.class "c-text--brand c-text--loud" ]
                [ H.text "Stage 3 Ended" ]
            , H.div []
                [ H.label [ HA.class "c-field c-field--choice c-field-minPadding" ]
                    [ H.button
                        [ HA.class "c-button c-button--ghost-brand u-small"
                        , HE.onClick <| HandleStage3DateTimeModal OpenDialog
                        ]
                        [ H.text <|
                            case model.laborStage3Record of
                                Just ls3rec ->
                                    case ls3rec.placentaDatetime of
                                        Just d ->
                                            U.dateTimeHMFormatter
                                                U.MDYDateFmt
                                                U.DashDateSep
                                                d

                                        Nothing ->
                                            "Click to set"

                                Nothing ->
                                    "Click to set"
                        ]
                    , if model.browserSupportsDate then
                        Form.dateTimeModal (model.stage3DateTimeModal == Stage3DateTimeModal)
                            "Stage 3 Completed Date/Time"
                            (FldChgString >> FldChgSubMsg Stage3DateFld)
                            (FldChgString >> FldChgSubMsg Stage3TimeFld)
                            (HandleStage3DateTimeModal CloseNoSaveDialog)
                            (HandleStage3DateTimeModal CloseSaveDialog)
                            ClearStage3DateTime
                            model.stage3Date
                            model.stage3Time
                      else
                        Form.dateTimePickerModal (model.stage3DateTimeModal == Stage3DateTimeModal)
                            "Stage 3 Completed Date/Time"
                            OpenDatePickerSubMsg
                            (FldChgString >> FldChgSubMsg Stage3DateFld)
                            (FldChgString >> FldChgSubMsg Stage3TimeFld)
                            (HandleStage3DateTimeModal CloseNoSaveDialog)
                            (HandleStage3DateTimeModal CloseSaveDialog)
                            ClearStage3DateTime
                            LaborDelIppStage3DateField
                            model.stage3Date
                            model.stage3Time
                    ]
                ]
            , H.div []
                [ H.button
                    [ HA.class "c-button c-button--ghost-brand u-small"
                    , HE.onClick <| HandleStage3SummaryModal OpenDialog
                    , if placentaNumVesselsAlert then
                        HA.style [ ( "background-color", "red" ) ]
                      else
                        HA.style []
                    ]
                    [ if isStage3SummaryDone model && not placentaNumVesselsAlert then
                        H.i [ HA.class "fa fa-check" ]
                            [ H.text "" ]
                      else if placentaNumVesselsAlert then
                        H.i [ HA.class "fa fa-exclamation" ]
                            [ H.text "" ]
                      else
                        H.span [] [ H.text "" ]
                    , H.text " Summary"
                    ]
                ]
            ]
        , H.div
            [ HA.class "stage-content"
            , HA.classList [ ( "isHidden", hideBaby ) ]
            ]
            [ H.div [ HA.class "c-text--brand c-text--loud" ]
                [ H.text "Baby" ]
            , H.div []
                [ H.button
                    [ HA.class "c-button c-button--ghost-brand u-small"
                    , HE.onClick <| HandleBabySummaryModal OpenDialog
                    ]
                    [ if isBabySummaryDone model then
                        H.i [ HA.class "fa fa-check" ]
                            [ H.text "" ]
                      else
                        H.span [] [ H.text "" ]
                    , H.text " Summary"
                    ]
                ]
            ]
        ]



-- Modal for Stage 1 Summary --


type alias DialogSummary =
    { isShown : Bool
    , isEditing : Bool
    , title : String
    , model : Model
    , closeMsg : SubMsg
    , saveMsg : SubMsg
    , editMsg : SubMsg
    }


dialogStage1Summary : DialogSummary -> Html SubMsg
dialogStage1Summary cfg =
    case cfg.isEditing of
        True ->
            -- We display the form for editing by default.
            dialogStage1SummaryEdit cfg

        False ->
            -- We display the summary results in a more concise form if not editing.
            dialogStage1SummaryView cfg


{-| Allow user to edit stage one summary fields.
-}
dialogStage1SummaryEdit : DialogSummary -> Html SubMsg
dialogStage1SummaryEdit cfg =
    let
        errors =
            validateStage1 cfg.model

        ( s1Total, s1Minutes ) =
            case cfg.model.laborStage1Record of
                Just rec ->
                    case rec.fullDialation of
                        Just fd ->
                            case cfg.model.laborRecord of
                                Just laborRec ->
                                    ( U.diff2DatesString laborRec.startLaborDate fd
                                    , Date.toTime laborRec.startLaborDate
                                        - Date.toTime fd
                                        |> Time.inMinutes
                                        |> round
                                        |> abs
                                    )

                                Nothing ->
                                    ( "", 0 )

                        Nothing ->
                            ( "", 0 )

                Nothing ->
                    ( "", 0 )

        -- Calculate the amount of time unaccounted for as the user types so that it
        -- can be displayed to the user real time.
        getMinutes str =
            U.maybeStringToMaybeInt str
                |> Maybe.withDefault 0

        pendingTotalMinutes =
            (getMinutes cfg.model.s1DurationLatentHours |> (*) 60)
                + getMinutes cfg.model.s1DurationLatentMinutes
                + (getMinutes cfg.model.s1DurationActiveHours |> (*) 60)
                + getMinutes cfg.model.s1DurationActiveMinutes

        unaccountedForHours =
            (-) s1Minutes pendingTotalMinutes // 60

        unaccountedForMinutes =
            rem ((-) s1Minutes pendingTotalMinutes) 60

        warningMsg =
            case (-) s1Minutes pendingTotalMinutes /= 0 of
                True ->
                    " Duration to account for: "
                        ++ toString unaccountedForHours
                        ++ " hours, "
                        ++ toString unaccountedForMinutes
                        ++ " minutes"

                False ->
                    ""
    in
    H.div
        [ HA.classList [ ( "isHidden", not cfg.isShown && cfg.isEditing ) ]
        , HA.class "u-high"
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Stage 1 Summary - Edit" ]
        , H.div [ HA.style [ ( "padding", "0.5em 0" ) ] ]
            [ if String.length warningMsg > 0 then
                H.span [ HA.class "u-high c-alert c-alert-warning" ]
                    [ H.text warningMsg ]
              else
                H.span [ HA.class "c-text--quiet" ]
                    [ H.text <| "Stage 1 total: " ++ s1Total ]
            ]
        , H.div [ HA.class "form-wrapper u-small" ]
            [ H.div []
                [ Form.radioFieldsetWide "Mobility"
                    "mobility"
                    cfg.model.s1Mobility
                    (FldChgString >> FldChgSubMsg Stage1MobilityFld)
                    False
                    [ "Moved around"
                    , "Didn't move much"
                    , "Movement restricted"
                    ]
                    (getErr Stage1MobilityFld errors)
                ]
            , H.div []
                [ Form.formField (FldChgString >> FldChgSubMsg Stage1DurationLatentHoursFld)
                    "Duration latent (hours)"
                    "Number of hours"
                    True
                    cfg.model.s1DurationLatentHours
                    (getErr Stage1DurationLatentHoursFld errors)
                , Form.formField (FldChgString >> FldChgSubMsg Stage1DurationLatentMinutesFld)
                    "Duration latent (minutes)"
                    "Number of minutes"
                    True
                    cfg.model.s1DurationLatentMinutes
                    (getErr Stage1DurationLatentMinutesFld errors)
                ]
            , H.div []
                [ Form.formField (FldChgString >> FldChgSubMsg Stage1DurationActiveHoursFld)
                    "Duration active (hours)"
                    "Number of hours"
                    True
                    cfg.model.s1DurationActiveHours
                    (getErr Stage1DurationActiveHoursFld errors)
                , Form.formField (FldChgString >> FldChgSubMsg Stage1DurationActiveMinutesFld)
                    "Duration active (minutes)"
                    "Number of minutes"
                    True
                    cfg.model.s1DurationActiveMinutes
                    (getErr Stage1DurationActiveMinutesFld errors)
                ]
            , Form.formTextareaFieldMin30em (FldChgString >> FldChgSubMsg Stage1CommentsFld)
                "Comments"
                "Meds, IV, Complications, Notes, etc."
                True
                cfg.model.s1Comments
                3
            , H.div
                [ HA.class "spacedButtons"
                , HA.style [ ( "width", "100%" ) ]
                ]
                [ H.button
                    [ HA.type_ "button"
                    , HA.class "c-button u-small"
                    , HE.onClick cfg.closeMsg
                    ]
                    [ H.text "Cancel" ]
                , H.button
                    [ HA.type_ "button"
                    , HA.class "c-button c-button--brand u-small"
                    , HE.onClick cfg.saveMsg
                    ]
                    [ H.text "Save" ]
                ]
            ]
        ]


{-| Display the stage one summary, including the first stage total,
if available.
-}
dialogStage1SummaryView : DialogSummary -> Html SubMsg
dialogStage1SummaryView cfg =
    let
        ( mobility, latentHours, latentMinutes, activeHours, activeMinutes, comments, s1Total ) =
            case cfg.model.laborStage1Record of
                Just rec ->
                    ( Maybe.withDefault "" rec.mobility
                    , U.minutesToHours rec.durationLatent
                        |> Maybe.map toString
                        |> Maybe.withDefault "0"
                    , U.minutesToMinutes rec.durationLatent
                        |> Maybe.map toString
                        |> Maybe.withDefault "0"
                    , U.minutesToHours rec.durationActive
                        |> Maybe.map toString
                        |> Maybe.withDefault "0"
                    , U.minutesToMinutes rec.durationActive
                        |> Maybe.map toString
                        |> Maybe.withDefault "0"
                    , Maybe.withDefault "" rec.comments
                    , case rec.fullDialation of
                        Just fd ->
                            case cfg.model.laborRecord of
                                Just laborRec ->
                                    U.diff2DatesString laborRec.startLaborDate fd

                                Nothing ->
                                    ""

                        Nothing ->
                            ""
                    )

                Nothing ->
                    ( "", "", "", "", "", "", "" )
    in
    H.div
        [ HA.classList [ ( "isHidden", not cfg.isShown && not cfg.isEditing ) ]
        , HA.class "u-high"
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Stage 1 Summary" ]
        , H.div [ HA.class "o-fieldset" ]
            [ H.div []
                [ H.span [ HA.class "c-text--loud" ]
                    [ H.text "Stage 1 Total: " ]
                , H.span [ HA.class "" ]
                    [ H.text s1Total ]
                ]
            , H.div []
                [ H.span [ HA.class "c-text--loud" ]
                    [ H.text "Mobility: " ]
                , H.span [ HA.class "" ]
                    [ H.text mobility ]
                ]
            , H.div []
                [ H.span [ HA.class "c-text--loud" ]
                    [ H.text "Duration Latent: " ]
                , H.span [ HA.class "" ]
                    [ H.text latentHours ]
                , H.span [ HA.class "" ]
                    [ H.text " hours, " ]
                , H.span [ HA.class "" ]
                    [ H.text latentMinutes ]
                , H.span [ HA.class "" ]
                    [ H.text " minutes" ]
                ]
            , H.div []
                [ H.span [ HA.class "c-text--loud" ]
                    [ H.text "Duration Active: " ]
                , H.span [ HA.class "" ]
                    [ H.text activeHours ]
                , H.span [ HA.class "" ]
                    [ H.text " hours, " ]
                , H.span [ HA.class "" ]
                    [ H.text activeMinutes ]
                , H.span [ HA.class "" ]
                    [ H.text " minutes" ]
                ]
            , H.div []
                [ H.span [ HA.class "c-text--loud" ]
                    [ H.text "Comments: " ]
                , H.span [ HA.class "" ]
                    [ H.text comments ]
                ]
            , H.div [ HA.class "spacedButtons" ]
                [ H.button
                    [ HA.type_ "button"
                    , HA.class "c-button u-small"
                    , HE.onClick cfg.closeMsg
                    ]
                    [ H.text "Close" ]
                , H.button
                    [ HA.type_ "button"
                    , HA.class "c-button c-button--ghost u-small"
                    , HE.onClick cfg.editMsg
                    ]
                    [ H.text "Edit" ]
                ]
            ]
        ]



-- Modal for Stage 2 Summary --


dialogStage2Summary : DialogSummary -> Html SubMsg
dialogStage2Summary cfg =
    case cfg.isEditing of
        True ->
            dialogStage2SummaryEdit cfg

        False ->
            dialogStage2SummaryView cfg


dialogStage2SummaryEdit : DialogSummary -> Html SubMsg
dialogStage2SummaryEdit cfg =
    let
        errors =
            validateStage2 cfg.model
    in
    H.div
        [ HA.class "u-high"
        , HA.classList [ ( "isHidden", not cfg.isShown && cfg.isEditing ) ]
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Stage 2 Summary - Edit" ]
        , H.div [ HA.class "form-wrapper u-small" ]
            [ H.div
                [ HA.class "o-fieldset form-wrapper"
                ]
                [ Form.radioFieldsetOther "Birth type"
                    "birthType"
                    cfg.model.s2BirthType
                    (FldChgString >> FldChgSubMsg Stage2BirthTypeFld)
                    False
                    [ "Single"
                    , "Twin"
                    ]
                    (getErr Stage2BirthTypeFld errors)
                , Form.radioFieldsetOther "Delivery type"
                    "deliverytype"
                    cfg.model.s2DeliveryType
                    (FldChgString >> FldChgSubMsg Stage2DeliveryTypeFld)
                    False
                    [ "NSVD"
                    , "Interventive vaginal delivery"
                    , "Vacuum"
                    , "Forceps"
                    , "CS"
                    ]
                    (getErr Stage2DeliveryTypeFld errors)
                , Form.radioFieldsetOther "Position for birth"
                    "position"
                    cfg.model.s2BirthPosition
                    (FldChgString >> FldChgSubMsg Stage2BirthPositionFld)
                    False
                    [ "Semi-sitting"
                    , "Lying on back"
                    , "Side-Lying"
                    , "Stool or Antipolo"
                    , "Hands/Knees"
                    , "Squat"
                    ]
                    (getErr Stage2BirthPositionFld errors)
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg Stage2DurationPushingFld)
                        "Duration of pushing"
                        "Number of minutes"
                        True
                        cfg.model.s2DurationPushing
                        (getErr Stage2DurationPushingFld errors)
                    ]
                , Form.radioFieldsetOther "Baby's presentation at birth"
                    "presentation"
                    cfg.model.s2BirthPresentation
                    (FldChgString >> FldChgSubMsg Stage2BirthPresentationFld)
                    False
                    [ "ROA"
                    , "ROP"
                    , "LOA"
                    , "LOP"
                    ]
                    (getErr Stage2BirthPresentationFld errors)
                , Form.radioFieldsetOther "Cord wrap type"
                    "cordwraptype"
                    cfg.model.s2CordWrapType
                    (FldChgString >> FldChgSubMsg Stage2CordWrapTypeFld)
                    False
                    [ "None"
                    , "Nuchal"
                    , "Body"
                    , "Cut on perineum"
                    ]
                    (getErr Stage2CordWrapTypeFld errors)
                , Form.checkbox "Shoulder Dystocia" (FldChgBool >> FldChgSubMsg Stage2ShoulderDystociaFld) cfg.model.s2ShoulderDystocia
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg Stage2ShoulderDystociaMinutesFld)
                        "Shoulder dystocia minutes"
                        "Number of minutes"
                        True
                        cfg.model.s2ShoulderDystociaMinutes
                        (getErr Stage2ShoulderDystociaMinutesFld errors)
                    ]
                , Form.checkbox "Laceration" (FldChgBool >> FldChgSubMsg Stage2LacerationFld) cfg.model.s2Laceration
                , Form.checkbox "Episiotomy" (FldChgBool >> FldChgSubMsg Stage2EpisiotomyFld) cfg.model.s2Episiotomy
                , Form.checkbox "Repair" (FldChgBool >> FldChgSubMsg Stage2RepairFld) cfg.model.s2Repair
                , Form.radioFieldset "Degree"
                    "degree"
                    cfg.model.s2Degree
                    (FldChgString >> FldChgSubMsg Stage2DegreeFld)
                    False
                    [ "1st"
                    , "2nd"
                    , "3rd"
                    , "4th"
                    ]
                    (getErr Stage2DegreeFld errors)
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg Stage2LacerationRepairedByFld)
                        "Laceration repaired by"
                        "Initials or lastname"
                        True
                        cfg.model.s2LacerationRepairedBy
                        (getErr Stage2LacerationRepairedByFld errors)
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg Stage2BirthEBLFld)
                        "EBL at birth"
                        "in cc"
                        True
                        cfg.model.s2BirthEBL
                        (getErr Stage2BirthEBLFld errors)
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.radioFieldset "Fluid at birth"
                        "meconium"
                        cfg.model.s2Meconium
                        (FldChgString >> FldChgSubMsg Stage2MeconiumFld)
                        False
                        [ "None"
                        , "Lt"
                        , "Mod"
                        , "Thick"
                        ]
                        (getErr Stage2MeconiumFld errors)
                    , Form.checkbox "Terminal Mec" (FldChgBool >> FldChgSubMsg Stage2TerminalMecFld) cfg.model.s2TerminalMec
                    ]
                , Form.formTextareaField (FldChgString >> FldChgSubMsg Stage2CommentsFld)
                    "Comments"
                    "Meds, IV, Complications, Notes, etc."
                    True
                    cfg.model.s2Comments
                    3
                ]
            ]
        , H.div
            [ HA.class "spacedButtons"
            , HA.style [ ( "width", "100%" ) ]
            ]
            [ H.button
                [ HA.type_ "button"
                , HA.class "c-button u-small"
                , HE.onClick cfg.closeMsg
                ]
                [ H.text "Cancel" ]
            , H.button
                [ HA.type_ "button"
                , HA.class "c-button c-button--brand u-small"
                , HE.onClick cfg.saveMsg
                ]
                [ H.text "Save" ]
            ]
        ]


dialogStage2SummaryView : DialogSummary -> Html SubMsg
dialogStage2SummaryView cfg =
    let
        ( birthType, birthPosition, durationPushing, birthPresentation, terminalMec, cordWraptype, deliveryType ) =
            case cfg.model.laborStage2Record of
                Just rec ->
                    ( Maybe.withDefault "" rec.birthType
                    , Maybe.withDefault "" rec.birthPosition
                    , Maybe.map toString rec.durationPushing
                        |> Maybe.withDefault ""
                    , Maybe.withDefault "" rec.birthPresentation
                    , Maybe.map
                        (\tm ->
                            if tm then
                                "Yes"
                            else
                                "No"
                        )
                        rec.terminalMec
                        |> Maybe.withDefault "No"
                    , Maybe.withDefault "" rec.cordWrapType
                    , Maybe.withDefault "" rec.deliveryType
                    )

                Nothing ->
                    ( "", "", "", "", "", "", "" )

        ( shoulderDystocia, laceration, episiotomy, repair, degree, repairedBy, ebl, meconium, comments ) =
            case cfg.model.laborStage2Record of
                Just rec ->
                    ( Maybe.map2
                        (\s m ->
                            if s then
                                "Yes, " ++ toString m ++ " minutes"
                            else
                                "No"
                        )
                        rec.shoulderDystocia
                        rec.shoulderDystociaMinutes
                        |> Maybe.withDefault "No"
                    , Maybe.map
                        (\l ->
                            if l then
                                "Yes"
                            else
                                "No"
                        )
                        rec.laceration
                        |> Maybe.withDefault "No"
                    , Maybe.map
                        (\e ->
                            if e then
                                "Yes"
                            else
                                "No"
                        )
                        rec.episiotomy
                        |> Maybe.withDefault "No"
                    , Maybe.map
                        (\r ->
                            if r then
                                "Yes"
                            else
                                "No"
                        )
                        rec.repair
                        |> Maybe.withDefault "No"
                    , Maybe.withDefault "None" rec.degree
                    , Maybe.withDefault "" rec.lacerationRepairedBy
                    , Maybe.map toString rec.birthEBL
                        |> Maybe.map (\e -> e ++ " cc")
                        |> Maybe.withDefault "0"
                    , Maybe.withDefault "None" rec.meconium
                    , Maybe.withDefault "" rec.comments
                    )

                Nothing ->
                    ( "", "", "", "", "", "", "", "", "" )

        s2Total =
            case cfg.model.laborStage2Record of
                Just s2Rec ->
                    case cfg.model.laborStage1Record of
                        Just s1Rec ->
                            case ( s1Rec.fullDialation, s2Rec.birthDatetime ) of
                                ( Just fd, Just bdt ) ->
                                    U.diff2DatesString fd bdt

                                ( _, _ ) ->
                                    ""

                        Nothing ->
                            ""

                Nothing ->
                    ""
    in
    H.div
        [ HA.classList [ ( "isHidden", not cfg.isShown && not cfg.isEditing ) ]
        , HA.class "u-high"
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Stage 2 Summary" ]
        , H.div []
            [ H.div
                [ HA.class "o-fieldset form-wrapper"
                ]
                [ H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Stage 2 Total: " ]
                    , H.span [ HA.class "" ]
                        [ H.text s2Total ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Birth type: " ]
                    , H.span [ HA.class "" ]
                        [ H.text birthType ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Delivery type: " ]
                    , H.span [ HA.class "" ]
                        [ H.text deliveryType ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Position for birth: " ]
                    , H.span [ HA.class "" ]
                        [ H.text birthPosition ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Duration of pushing: " ]
                    , H.span [ HA.class "" ]
                        [ H.text <| durationPushing ++ " minutes" ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Presentation at birth: " ]
                    , H.span [ HA.class "" ]
                        [ H.text birthPresentation ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Cord wrap: " ]
                    , H.span [ HA.class "" ]
                        [ H.text cordWraptype ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Shoulder dystocia: " ]
                    , H.span [ HA.class "" ]
                        [ H.text shoulderDystocia ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Laceration: " ]
                    , H.span [ HA.class "" ]
                        [ H.text laceration ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Episiotomy: " ]
                    , H.span [ HA.class "" ]
                        [ H.text episiotomy ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Repair: " ]
                    , H.span [ HA.class "" ]
                        [ H.text repair ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Degree: " ]
                    , H.span [ HA.class "" ]
                        [ H.text degree ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Laceration repaired by: " ]
                    , H.span [ HA.class "" ]
                        [ H.text repairedBy ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Est blood loss at birth: " ]
                    , H.span [ HA.class "" ]
                        [ H.text ebl ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Fluid at birth: " ]
                    , H.span [ HA.class "" ]
                        [ H.text meconium ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Terminal Mec: " ]
                    , H.span [ HA.class "" ]
                        [ H.text terminalMec ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Comments: " ]
                    , H.span [ HA.class "" ]
                        [ H.text comments ]
                    ]
                ]
            , H.div [ HA.class "spacedButtons" ]
                [ H.button
                    [ HA.type_ "button"
                    , HA.class "c-button u-small"
                    , HE.onClick cfg.closeMsg
                    ]
                    [ H.text "Close" ]
                , H.button
                    [ HA.type_ "button"
                    , HA.class "c-button c-button--ghost u-small"
                    , HE.onClick cfg.editMsg
                    ]
                    [ H.text "Edit" ]
                ]
            ]
        ]



-- Modal for Stage 3 Summary --


dialogStage3Summary : DialogSummary -> Html SubMsg
dialogStage3Summary cfg =
    case cfg.isEditing of
        True ->
            dialogStage3SummaryEdit cfg

        False ->
            dialogStage3SummaryView cfg


dialogStage3SummaryView : DialogSummary -> Html SubMsg
dialogStage3SummaryView cfg =
    let
        yesNoBool bool =
            case bool of
                Just True ->
                    "Yes"

                _ ->
                    "No"

        ( delSpon, delAMTSL, delCCT, delMan, matPos, txBL1, txBL2, txBL3 ) =
            case cfg.model.laborStage3Record of
                Just rec ->
                    ( yesNoBool rec.placentaDeliverySpontaneous
                    , yesNoBool rec.placentaDeliveryAMTSL
                    , yesNoBool rec.placentaDeliveryCCT
                    , yesNoBool rec.placentaDeliveryManual
                    , Maybe.withDefault "" rec.maternalPosition
                    , Maybe.withDefault "" rec.txBloodLoss1
                    , Maybe.withDefault "" rec.txBloodLoss2
                    , Maybe.withDefault "" rec.txBloodLoss3
                    )

                Nothing ->
                    ( "", "", "", "", "", "", "", "" )

        ( shape, insertion, numVessels, numVesselsAlert, schDun, cotyledons, membranes, comments ) =
            case cfg.model.laborStage3Record of
                Just rec ->
                    ( Maybe.withDefault "" rec.placentaShape
                    , Maybe.withDefault "" rec.placentaInsertion
                    , Maybe.map toString rec.placentaNumVessels
                        |> Maybe.withDefault ""
                    , case rec.placentaNumVessels of
                        Just num ->
                            num == 2

                        Nothing ->
                            False
                    , Maybe.map schultzDuncan2String rec.schultzDuncan
                        |> Maybe.withDefault ""
                    , Maybe.withDefault "" rec.cotyledons
                    , Maybe.withDefault "" rec.membranes
                    , Maybe.withDefault "" rec.comments
                    )

                Nothing ->
                    ( "", "", "", False, "", "", "", "" )

        treatment =
            [ txBL1, txBL2, txBL3 ]
                |> List.filter (\t -> String.length t > 0)
                |> String.join ", "

        s3Total =
            case cfg.model.laborStage3Record of
                Just s3Rec ->
                    case cfg.model.laborStage2Record of
                        Just s2Rec ->
                            case ( s2Rec.birthDatetime, s3Rec.placentaDatetime ) of
                                ( Just bdt, Just pdt ) ->
                                    U.diff2DatesString bdt pdt

                                ( _, _ ) ->
                                    ""

                        Nothing ->
                            ""

                Nothing ->
                    ""
    in
    H.div
        [ HA.classList [ ( "isHidden", not cfg.isShown && not cfg.isEditing ) ]
        , HA.class "u-high"
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Stage 3 Summary" ]
        , H.div []
            [ H.div
                [ HA.class "o-fieldset form-wrapper"
                ]
                [ H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Stage 3 Total: " ]
                    , H.span [ HA.class "" ]
                        [ H.text s3Total ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Delivery spontaneous: " ]
                    , H.span [ HA.class "" ]
                        [ H.text delSpon ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Delivery AMTSL: " ]
                    , H.span [ HA.class "" ]
                        [ H.text delAMTSL ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Delivery CCT: " ]
                    , H.span [ HA.class "" ]
                        [ H.text delCCT ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Delivery manual: " ]
                    , H.span [ HA.class "" ]
                        [ H.text delMan ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Maternal position: " ]
                    , H.span [ HA.class "" ]
                        [ H.text matPos ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Treatments: " ]
                    , H.span [ HA.class "" ]
                        [ H.text treatment ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Placenta shape: " ]
                    , H.span [ HA.class "" ]
                        [ H.text shape ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Plancenta insertion: " ]
                    , H.span [ HA.class "" ]
                        [ H.text insertion ]
                    ]
                , H.div
                    [ HA.class "mw-form-field-2x"
                    , if numVesselsAlert then
                        HA.style [ ( "border", "1px dotted red" ) ]
                      else
                        HA.style []
                    ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Placenta num vessels: " ]
                    , H.span [ HA.class "" ]
                        [ H.text numVessels ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Schultz/Duncan: " ]
                    , H.span [ HA.class "" ]
                        [ H.text schDun ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Cotyeledons: " ]
                    , H.span [ HA.class "" ]
                        [ H.text cotyledons ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Membranes: " ]
                    , H.span [ HA.class "" ]
                        [ H.text membranes ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Comments: " ]
                    , H.span [ HA.class "" ]
                        [ H.text comments ]
                    ]
                ]
            , H.div [ HA.class "spacedButtons" ]
                [ H.button
                    [ HA.type_ "button"
                    , HA.class "c-button u-small"
                    , HE.onClick cfg.closeMsg
                    ]
                    [ H.text "Close" ]
                , H.button
                    [ HA.type_ "button"
                    , HA.class "c-button c-button--ghost u-small"
                    , HE.onClick cfg.editMsg
                    ]
                    [ H.text "Edit" ]
                ]
            ]
        ]


dialogStage3SummaryEdit : DialogSummary -> Html SubMsg
dialogStage3SummaryEdit cfg =
    let
        errors =
            validateStage3 cfg.model

        deliveryFlds =
            [ Stage3PlacentaDeliverySpontaneousFld
            , Stage3PlacentaDeliveryAMTSLFld
            , Stage3PlacentaDeliveryCCTFld
            , Stage3PlacentaDeliveryManualFld
            ]

        deliveryErrorStr =
            List.filter (\( f, s ) -> List.member f deliveryFlds) errors
                |> List.map Tuple.second
                |> String.join ", "
    in
    H.div
        [ HA.class "u-high"
        , HA.classList [ ( "isHidden", not cfg.isShown && cfg.isEditing ) ]
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Stage 3 Summary - Edit" ]
        , H.div [ HA.class "form-wrapper u-small" ]
            [ H.div
                [ HA.class "o-fieldset form-wrapper"
                ]
                [ H.label [ HA.class "c-label o-form-element mw-form-field" ]
                    [ H.span
                        [ HA.class "c-text--loud" ]
                        [ H.text "Placenta Delivery" ]
                    , Form.checkbox "Spontaneous"
                        (FldChgBool >> FldChgSubMsg Stage3PlacentaDeliverySpontaneousFld)
                        cfg.model.s3PlacentaDeliverySpontaneous
                    , Form.checkbox "AMTSL"
                        (FldChgBool >> FldChgSubMsg Stage3PlacentaDeliveryAMTSLFld)
                        cfg.model.s3PlacentaDeliveryAMTSL
                    , Form.checkbox "CCT"
                        (FldChgBool >> FldChgSubMsg Stage3PlacentaDeliveryCCTFld)
                        cfg.model.s3PlacentaDeliveryCCT
                    , Form.checkbox "Manual"
                        (FldChgBool >> FldChgSubMsg Stage3PlacentaDeliveryManualFld)
                        cfg.model.s3PlacentaDeliveryManual
                    , if String.length deliveryErrorStr > 0 then
                        H.div
                            [ HA.class "c-text--mono c-text--loud u-xsmall u-bg-yellow"
                            , HA.style
                                [ ( "padding", "0.25em 0.25em" )
                                , ( "margin", "0.75em 0 1.25em 0" )
                                ]
                            ]
                            [ H.text deliveryErrorStr ]
                      else
                        H.span [] []
                    ]
                , Form.radioFieldsetOther "Maternal Position"
                    "maternalPosition"
                    cfg.model.s3MaternalPosition
                    (FldChgString >> FldChgSubMsg Stage3MaternalPositionFld)
                    False
                    [ "Semi-sitting"
                    , "Lying on back"
                    , "Squat"
                    ]
                    (getErr Stage3MaternalPositionFld errors)
                , H.div [ HA.class "mw-form-field" ]
                    [ H.span
                        [ HA.class "c-text--loud" ]
                        [ H.text "Tx for Blood Loss" ]
                    , Form.checkboxString "Oxytocin"
                        (FldChgString >> FldChgSubMsg Stage3TxBloodLoss1Fld)
                        cfg.model.s3TxBloodLoss1
                    , Form.checkboxString "IV"
                        (FldChgString >> FldChgSubMsg Stage3TxBloodLoss2Fld)
                        cfg.model.s3TxBloodLoss2
                    , Form.checkboxString "Bi-Manual Compression External/Internal"
                        (FldChgString >> FldChgSubMsg Stage3TxBloodLoss3Fld)
                        cfg.model.s3TxBloodLoss3
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg Stage3PlacentaShapeFld)
                        "Placenta Shape"
                        "shape"
                        True
                        cfg.model.s3PlacentaShape
                        (getErr Stage3PlacentaShapeFld errors)
                    ]
                , Form.radioFieldsetOther "Placenta Insertion"
                    "placentaInsertion"
                    cfg.model.s3PlacentaInsertion
                    (FldChgString >> FldChgSubMsg Stage3PlacentaInsertionFld)
                    False
                    [ "Central"
                    , "Semi-central"
                    , "Marginal"
                    ]
                    (getErr Stage3PlacentaInsertionFld errors)
                , Form.radioFieldset "Placenta Number Vessels"
                    "numberVessels"
                    cfg.model.s3PlacentaNumVessels
                    (FldChgString >> FldChgSubMsg Stage3PlacentaNumVesselsFld)
                    False
                    [ "2"
                    , "3"
                    ]
                    (getErr Stage3PlacentaNumVesselsFld errors)
                , Form.radioFieldset "Schultz/Duncan"
                    "schultzDuncan"
                    cfg.model.s3SchultzDuncan
                    (FldChgString >> FldChgSubMsg Stage3SchultzDuncanFld)
                    False
                    [ "Schultz"
                    , "Duncan"
                    ]
                    (getErr Stage3SchultzDuncanFld errors)
                , Form.radioFieldset "Cotyledons"
                    "cotyledons"
                    cfg.model.s3Cotyledons
                    (FldChgString >> FldChgSubMsg Stage3CotyledonsFld)
                    False
                    [ "Cotyledons appear complete"
                    , "Cotyledons possibly incomplete"
                    ]
                    (getErr Stage3CotyledonsFld errors)
                , Form.radioFieldset "Membranes"
                    "membranes"
                    cfg.model.s3Membranes
                    (FldChgString >> FldChgSubMsg Stage3MembranesFld)
                    False
                    [ "Membranes appear complete"
                    , "Membranes possibly incomplete"
                    ]
                    (getErr Stage3MembranesFld errors)
                , Form.formTextareaField (FldChgString >> FldChgSubMsg Stage3CommentsFld)
                    "Comments"
                    ""
                    True
                    cfg.model.s3Comments
                    3
                ]
            ]
        , H.div
            [ HA.class "spacedButtons"
            , HA.style [ ( "width", "100%" ) ]
            ]
            [ H.button
                [ HA.type_ "button"
                , HA.class "c-button u-small"
                , HE.onClick cfg.closeMsg
                ]
                [ H.text "Cancel" ]
            , H.button
                [ HA.type_ "button"
                , HA.class "c-button c-button--brand u-small"
                , HE.onClick cfg.saveMsg
                ]
                [ H.text "Save" ]
            ]
        ]



-- Modal for Membrane Summary --


dialogMembraneSummary : DialogSummary -> Html SubMsg
dialogMembraneSummary cfg =
    case cfg.isEditing of
        True ->
            dialogMembraneSummaryEdit cfg

        False ->
            dialogMembraneSummaryView cfg


{-| Note that rupture and amniotic comment fields were not desired by the
client, but the fields are only removed from the views, not the rest of
the system.
-}
dialogMembraneSummaryView : DialogSummary -> Html SubMsg
dialogMembraneSummaryView cfg =
    let
        dateString date =
            case date of
                Just d ->
                    U.dateTimeHMFormatter U.MDYDateFmt U.DashDateSep d

                Nothing ->
                    ""

        viewField label value =
            H.div [ HA.class "mw-form-field-2x" ]
                [ H.span [ HA.class "c-text--loud" ]
                    [ H.text <| label ++ ": " ]
                , H.span [ HA.class "" ]
                    [ H.text value ]
                ]
    in
    case cfg.model.membraneRecord of
        Nothing ->
            H.text ""

        Just rec ->
            H.div
                [ HA.classList [ ( "isHidden", not cfg.isShown && not cfg.isEditing ) ]
                , HA.class "u-high"
                , HA.style
                    [ ( "padding", "0.8em" )
                    , ( "margin-top", "0.8em" )
                    ]
                ]
                [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
                    [ H.text "Membranes/Resuscitation Summary" ]
                , H.div []
                    [ H.div
                        [ HA.class "o-fieldset form-wrapper"
                        ]
                        [ viewField "Rupture Date and time" <| dateString rec.ruptureDatetime
                        , viewField "Rupture" <| Data.Membrane.maybeRuptureToString rec.rupture
                        , viewField "Fluid at rupture" <| Data.Membrane.maybeAmnioticToString rec.amniotic
                        , viewField "Comments" <| Maybe.withDefault "" rec.comments
                        ]
                    , H.div [ HA.class "spacedButtons" ]
                        [ H.button
                            [ HA.type_ "button"
                            , HA.class "c-button u-small"
                            , HE.onClick cfg.closeMsg
                            ]
                            [ H.text "Close" ]
                        , H.button
                            [ HA.type_ "button"
                            , HA.class "c-button c-button--ghost u-small"
                            , HE.onClick cfg.editMsg
                            ]
                            [ H.text "Edit" ]
                        ]
                    ]
                ]


{-| Note that rupture and amniotic comment fields were not desired by the
client, but the fields are only removed from the views, not the rest of
the system.
-}
dialogMembraneSummaryEdit : DialogSummary -> Html SubMsg
dialogMembraneSummaryEdit cfg =
    let
        errors =
            validateMembrane cfg.model
    in
    H.div
        [ HA.class "u-high"
        , HA.classList [ ( "isHidden", not cfg.isShown && cfg.isEditing ) ]
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Membrane - Edit" ]
        , H.div [ HA.class "form-wrapper u-small" ]
            [ H.div [ HA.class "o-fieldset form-wrapper" ]
                [ if cfg.model.browserSupportsDate then
                    H.div [ HA.class "c-card mw-form-field-2x" ]
                        [ H.div [ HA.class "c-card__item" ]
                            [ H.div [ HA.class "c-text--loud" ]
                                [ H.text "Rupture date and time" ]
                            ]
                        , H.div [ HA.class "c-card__body dateTimeModalBody" ]
                            [ H.div [ HA.class "o-fieldset form-wrapper" ]
                                [ Form.formFieldDate (FldChgString >> FldChgSubMsg MembraneRuptureDateFld)
                                    "Date"
                                    "e.g. 08/14/2017"
                                    False
                                    cfg.model.membraneRuptureDate
                                    (getErr MembraneRuptureDateFld errors)
                                , Form.formField (FldChgString >> FldChgSubMsg MembraneRuptureTimeFld)
                                    "Time"
                                    "24 hr format, 14:44"
                                    False
                                    cfg.model.membraneRuptureTime
                                    (getErr MembraneRuptureTimeFld errors)
                                ]
                            ]
                        ]
                  else
                    -- Browser does not support date.
                    H.div [ HA.class "c-card mw-form-field-2x" ]
                        [ H.div [ HA.class "c-card__item" ]
                            [ H.div [ HA.class "c-text--loud" ]
                                [ H.text "Membrane rupture date/time" ]
                            ]
                        , H.div [ HA.class "c-card__body" ]
                            [ H.div [ HA.class "o-fieldset form-wrapper" ]
                                [ Form.formFieldDatePicker OpenDatePickerSubMsg
                                    MembraneRuptureDateField
                                    "Date"
                                    "e.g. 08/14/2017"
                                    False
                                    cfg.model.membraneRuptureDate
                                    (getErr MembraneRuptureDateFld errors)
                                , Form.formField (FldChgString >> FldChgSubMsg MembraneRuptureTimeFld)
                                    "Time"
                                    "24 hr format, 14:44"
                                    False
                                    cfg.model.membraneRuptureTime
                                    (getErr MembraneRuptureTimeFld errors)
                                ]
                            ]
                        ]
                , Form.radioFieldset "Rupture"
                    "rupture"
                    cfg.model.membraneRupture
                    (FldChgString >> FldChgSubMsg MembraneRuptureFld)
                    False
                    [ "AROM"
                    , "SROM"
                    , "Other"
                    ]
                    (getErr MembraneRuptureFld errors)
                , Form.radioFieldset "Fluid at rupture"
                    "amniotic"
                    cfg.model.membraneAmniotic
                    (FldChgString >> FldChgSubMsg MembraneAmnioticFld)
                    False
                    [ "Clear"
                    , "Lt Stain"
                    , "Mod Stain"
                    , "Thick Stain"
                    , "Other"
                    ]
                    (getErr MembraneAmnioticFld errors)
                , Form.formTextareaField (FldChgString >> FldChgSubMsg MembraneCommentsFld)
                    "Comments"
                    ""
                    True
                    cfg.model.membraneComments
                    3
                ]
            ]
        , H.div
            [ HA.class "spacedButtons"
            , HA.style [ ( "width", "100%" ) ]
            ]
            [ H.button
                [ HA.type_ "button"
                , HA.class "c-button c-button u-small"
                , HE.onClick cfg.closeMsg
                ]
                [ H.text "Cancel" ]
            , H.button
                [ HA.type_ "button"
                , HA.class "c-button c-button--brand u-small"
                , HE.onClick cfg.saveMsg
                ]
                [ H.text "Save" ]
            ]
        ]



-- Modal for Baby Summary --


dialogBabySummary : DialogSummary -> Html SubMsg
dialogBabySummary cfg =
    case cfg.isEditing of
        True ->
            dialogBabySummaryEdit cfg

        False ->
            dialogBabySummaryView cfg


dialogBabySummaryView : DialogSummary -> Html SubMsg
dialogBabySummaryView cfg =
    let
        dateString date =
            case date of
                Just d ->
                    U.dateTimeHMFormatter U.MDYDateFmt U.DashDateSep d

                Nothing ->
                    ""

        ( lastname, firstname, middlename, sex, birthWeight, bFed, comments ) =
            case cfg.model.babyRecord of
                Just rec ->
                    ( Maybe.withDefault "" rec.lastname
                    , Maybe.withDefault "" rec.firstname
                    , Maybe.withDefault "" rec.middlename
                    , sexToFullString rec.sex
                    , Maybe.withDefault 0 rec.birthWeight
                        |> toString
                        |> flip String.append " g"
                    , dateString rec.bFedEstablished
                    , Maybe.withDefault "" rec.comments
                    )

                Nothing ->
                    ( "", "", "", "", "", "", "" )

        yesNoBool bool =
            case bool of
                True ->
                    "Yes"

                _ ->
                    "No"

        ( bulb, machine, freeflow, chestComp, ppv ) =
            case cfg.model.babyRecord of
                Just rec ->
                    ( Maybe.map yesNoBool rec.bulb
                        |> Maybe.withDefault "No"
                    , Maybe.map yesNoBool rec.machine
                        |> Maybe.withDefault "No"
                    , Maybe.map yesNoBool rec.freeFlowO2
                        |> Maybe.withDefault "No"
                    , Maybe.map yesNoBool rec.chestCompressions
                        |> Maybe.withDefault "No"
                    , Maybe.map yesNoBool rec.ppv
                        |> Maybe.withDefault "No"
                    )

                Nothing ->
                    ( "", "", "", "", "" )

        apgarsList =
            getScoresAsList cfg.model.apgarScores
    in
    H.div
        [ HA.classList [ ( "isHidden", not cfg.isShown && not cfg.isEditing ) ]
        , HA.class "u-high"
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Baby Details" ]
        , H.div []
            [ H.div
                [ HA.class "o-fieldset form-wrapper" ]
                [ H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Last name: " ]
                    , H.span [ HA.class "" ]
                        [ H.text lastname ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "First name: " ]
                    , H.span [ HA.class "" ]
                        [ H.text firstname ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Middle name: " ]
                    , H.span [ HA.class "" ]
                        [ H.text middlename ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Sex: " ]
                    , H.span [ HA.class "" ]
                        [ H.text sex ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Birth weight: " ]
                    , H.span [ HA.class "" ]
                        [ H.text birthWeight ]
                    ]
                , customApgarsView "Apgar Scores" apgarsList False
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "BFed established: " ]
                    , H.span [ HA.class "" ]
                        [ H.text bFed ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Bulb: " ]
                    , H.span [ HA.class "" ]
                        [ H.text bulb ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Machine: " ]
                    , H.span [ HA.class "" ]
                        [ H.text machine ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Free flow O2: " ]
                    , H.span [ HA.class "" ]
                        [ H.text freeflow ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Chest compressions: " ]
                    , H.span [ HA.class "" ]
                        [ H.text chestComp ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "PPV: " ]
                    , H.span [ HA.class "" ]
                        [ H.text ppv ]
                    ]
                , H.div [ HA.class "mw-form-field-2x" ]
                    [ H.span [ HA.class "c-text--loud" ]
                        [ H.text "Comments: " ]
                    , H.span [ HA.class "" ]
                        [ H.text comments ]
                    ]
                ]
            , H.div [ HA.class "spacedButtons" ]
                [ H.button
                    [ HA.type_ "button"
                    , HA.class "c-button u-small"
                    , HE.onClick cfg.closeMsg
                    ]
                    [ H.text "Close" ]
                , H.button
                    [ HA.type_ "button"
                    , HA.class "c-button c-button--ghost u-small"
                    , HE.onClick cfg.editMsg
                    ]
                    [ H.text "Edit" ]
                ]
            ]
        ]


customApgarsView : String -> List ApgarScore -> Bool -> Html SubMsg
customApgarsView lbl scores isEditing =
    let
        outerClass =
            if isEditing then
                "mw-form-field"
            else
                "mw-form-field-2x"
    in
    H.div [ HA.class outerClass ]
        ([ H.span [ HA.class "c-text--loud" ]
            [ H.text lbl ]
         ]
            ++ List.map (customApgarView isEditing) scores
            ++ [ H.span [ HA.class "c-text--quiet" ]
                    [ H.text <|
                        if isEditing then
                            "After adding or deleting, press Save below."
                        else
                            ""
                    ]
               ]
        )


customApgarView : Bool -> ApgarScore -> Html SubMsg
customApgarView isEditing score =
    case score of
        ApgarScore (Just m) (Just s) ->
            H.div []
                [ H.span []
                    [ H.text <| "Minute: " ++ toString m ]
                , H.span []
                    [ H.text <| ", Score: " ++ toString s ]
                , H.span []
                    [ H.text " " ]
                , if isEditing then
                    H.i
                        [ HA.class "fa fa-trash-o"
                        , HA.style [ ( "cursor", "pointer" ) ]
                        , HE.onClick (DeleteApgar m)
                        ]
                        []
                  else
                    H.text ""
                ]

        ApgarScore _ _ ->
            H.text ""


dialogBabySummaryEdit : DialogSummary -> Html SubMsg
dialogBabySummaryEdit cfg =
    let
        errors =
            validateBaby cfg.model

        apgar1 =
            getScoreAsStringByMinute 1 cfg.model.apgarScores

        apgar5 =
            getScoreAsStringByMinute 5 cfg.model.apgarScores

        apgar10 =
            getScoreAsStringByMinute 10 cfg.model.apgarScores

        customApgarsList =
            getCustomScoresAsList cfg.model.apgarScores

        addApgarWizard =
            case cfg.model.pendingApgarWizard of
                MinuteAddOtherApgar ->
                    H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                        [ Form.formField (FldChgString >> FldChgSubMsg ApgarOtherMinuteFld)
                            "Apgar minute"
                            "Not 1, 5, or 10"
                            True
                            cfg.model.pendingApgarMinute
                            (getErr ApgarOtherMinuteFld errors)
                        , H.button
                            [ HA.type_ "button"
                            , HA.class "c-button"
                            , HE.onClick (AddApgarWizard ScoreAddOtherApgar)
                            ]
                            [ H.text "Next" ]
                        ]

                ScoreAddOtherApgar ->
                    H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                        [ Form.formField (FldChgString >> FldChgSubMsg ApgarOtherScoreFld)
                            "Apgar score"
                            "0 to 10"
                            True
                            cfg.model.pendingApgarScore
                            (getErr ApgarOtherScoreFld errors)
                        , H.button
                            [ HA.type_ "button"
                            , HA.class "c-button"
                            , HE.onClick (AddApgarWizard FinishedAddOtherApgar)
                            ]
                            [ H.text "Finish" ]
                        ]

                _ ->
                    -- Display an Add Apgar button for the NotStartedAddOtherApgar or
                    -- the FinishedAddOtherApgar.
                    H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                        [ H.label [ HA.class "c-label o-form-element mw-form-field" ]
                            [ H.span [ HA.classList [ ( "c-text--loud", True ) ] ]
                                [ H.text "Add a custom apgar" ]
                            , H.button
                                [ HA.type_ "button"
                                , HA.class "c-button"
                                , HE.onClick (AddApgarWizard MinuteAddOtherApgar)
                                ]
                                [ H.text "Add Apgar" ]
                            ]
                        ]
    in
    H.div
        [ HA.class "u-high"
        , HA.classList [ ( "isHidden", not cfg.isShown && cfg.isEditing ) ]
        , HA.style
            [ ( "padding", "0.8em" )
            , ( "margin-top", "0.8em" )
            ]
        ]
        [ H.h3 [ HA.class "c-text--brand mw-header-3" ]
            [ H.text "Baby at Birth - Edit" ]
        , H.div [ HA.class "form-wrapper u-small" ]
            [ H.div [ HA.class "o-fieldset form-wrapper" ]
                -- NOTE: we are ignoring the birthNbr field right now and assuming
                -- that we do not have twins or more. At the moment, the Philippines
                -- does not allow maternity clinics to deliver twins or more. But
                -- this will need to be changed for other countries. The database
                -- already has the birthNbr field so no schema change will be
                -- required to add this feature.
                [ H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg BabyLastnameFld)
                        "Baby Last name"
                        "Lastname"
                        True
                        cfg.model.bbLastname
                        (getErr BabyLastnameFld errors)
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg BabyFirstnameFld)
                        "Baby First name"
                        "Firstname"
                        True
                        cfg.model.bbFirstname
                        (getErr BabyFirstnameFld errors)
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg BabyMiddlenameFld)
                        "Baby Middle name"
                        "Middlename"
                        True
                        cfg.model.bbMiddlename
                        (getErr BabyMiddlenameFld errors)
                    ]
                , Form.radioFieldset "Sex"
                    "babySex"
                    cfg.model.bbSex
                    (FldChgString >> FldChgSubMsg BabySexFld)
                    False
                    [ "Male"
                    , "Female"
                    , "Ambiguous"
                    ]
                    (getErr BabySexFld errors)
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgString >> FldChgSubMsg BabyBirthWeightFld)
                        "Birth weight (grams)"
                        "a number"
                        True
                        cfg.model.bbBirthWeight
                        (getErr BabyBirthWeightFld errors)
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgIntString 1 >> FldChgSubMsg ApgarStandardFld)
                        "Apgar 1"
                        "0 to 10"
                        True
                        apgar1
                        ""
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgIntString 5 >> FldChgSubMsg ApgarStandardFld)
                        "Apgar 5"
                        "0 to 10"
                        True
                        apgar5
                        ""
                    ]
                , H.fieldset [ HA.class "o-fieldset mw-form-field" ]
                    [ Form.formField (FldChgIntString 10 >> FldChgSubMsg ApgarStandardFld)
                        "Apgar 10"
                        "0 to 10"
                        True
                        apgar10
                        ""
                    ]
                , if List.length customApgarsList > 0 then
                    customApgarsView "Custom Apgar Scores" customApgarsList True
                  else
                    H.text ""
                , addApgarWizard
                , if cfg.model.browserSupportsDate then
                    H.div [ HA.class "c-card mw-form-field-2x" ]
                        [ H.div [ HA.class "c-card__item" ]
                            [ H.div [ HA.class "c-text--loud" ]
                                [ H.text "BFed Established date and time" ]
                            ]
                        , H.div [ HA.class "c-card__body dateTimeModalBody" ]
                            [ H.div [ HA.class "o-fieldset form-wrapper" ]
                                [ Form.formFieldDate (FldChgString >> FldChgSubMsg BabyBFedEstablishedDateFld)
                                    "Date"
                                    "e.g. 08/14/2017"
                                    False
                                    cfg.model.bbBFedEstablishedDate
                                    (getErr BabyBFedEstablishedDateFld errors)
                                , Form.formField (FldChgString >> FldChgSubMsg BabyBFedEstablishedTimeFld)
                                    "Time"
                                    "24 hr format, 14:44"
                                    False
                                    cfg.model.bbBFedEstablishedTime
                                    (getErr BabyBFedEstablishedTimeFld errors)
                                ]
                            ]
                        ]
                  else
                    -- Browser does not support date.
                    H.div [ HA.class "c-card mw-form-field-2x" ]
                        [ H.div [ HA.class "c-card__item" ]
                            [ H.div [ HA.class "c-text--loud" ]
                                [ H.text "BFed Established date and time" ]
                            ]
                        , H.div [ HA.class "c-card__body dateTimeModalBody" ]
                            [ H.div [ HA.class "o-fieldset form-wrapper" ]
                                [ Form.formFieldDatePicker OpenDatePickerSubMsg
                                    BabyBFedEstablishedDateField
                                    "Date"
                                    "e.g. 08/14/2017"
                                    False
                                    cfg.model.bbBFedEstablishedDate
                                    (getErr BabyBFedEstablishedDateFld errors)
                                , Form.formField (FldChgString >> FldChgSubMsg BabyBFedEstablishedTimeFld)
                                    "Time"
                                    "24 hr format, 14:44"
                                    False
                                    cfg.model.bbBFedEstablishedTime
                                    (getErr BabyBFedEstablishedTimeFld errors)
                                ]
                            ]
                        ]
                , H.label [ HA.class "c-label o-form-element mw-form-field" ]
                    [ H.span
                        [ HA.class "c-text--loud" ]
                        [ H.text "Resuscitation" ]
                    , Form.checkbox "Bulb" (FldChgBool >> FldChgSubMsg BabyBulbFld) cfg.model.bbBulb
                    , Form.checkbox "Machine" (FldChgBool >> FldChgSubMsg BabyMachineFld) cfg.model.bbMachine
                    , Form.checkbox "Free Flow O2" (FldChgBool >> FldChgSubMsg BabyFreeFlowO2Fld) cfg.model.bbFreeFlowO2
                    , Form.checkbox "Chest Compressions" (FldChgBool >> FldChgSubMsg BabyChestCompressionsFld) cfg.model.bbChestCompressions
                    , Form.checkbox "PPV" (FldChgBool >> FldChgSubMsg BabyPpvFld) cfg.model.bbPpv
                    ]
                , Form.formTextareaField (FldChgString >> FldChgSubMsg BabyCommentsFld)
                    "Comments"
                    ""
                    True
                    cfg.model.bbComments
                    3
                ]
            ]
        , H.div
            [ HA.class "spacedButtons"
            , HA.style [ ( "width", "100%" ) ]
            ]
            [ H.button
                [ HA.type_ "button"
                , HA.class "c-button c-button u-small"
                , HE.onClick cfg.closeMsg
                ]
                [ H.text "Cancel" ]
            , H.button
                [ HA.type_ "button"
                , HA.class "c-button c-button--brand u-small"
                , HE.onClick cfg.saveMsg
                ]
                [ H.text "Save" ]
            ]
        ]



-- UPDATE --


{-| Extract data by key from the data cache passed and populate the
model with it. We do not update the model's fields except per the
list of keys (List Table) passed, which has to be initiated elsewhere
in this module. This is so that fields are not willy nilly overwritten
unexpectedly.
-}
refreshModelFromCache : Dict String DataCache -> List Table -> Model -> ( Model, Cmd Msg )
refreshModelFromCache dc tables model =
    let
        ( newModel, cmds ) =
            List.foldl
                (\t ( m, cmds ) ->
                    case t of
                        Baby ->
                            case DataCache.get t dc of
                                Just (BabyDataCache rec) ->
                                    { m | babyRecord = Just rec } => cmds

                                _ ->
                                    m => cmds

                        Labor ->
                            case DataCache.get t dc of
                                Just (LaborDataCache rec) ->
                                    { m | laborRecord = Just rec } => cmds

                                _ ->
                                    m => cmds

                        LaborStage1 ->
                            case DataCache.get t dc of
                                Just (LaborStage1DataCache rec) ->
                                    { m | laborStage1Record = Just rec } => cmds

                                _ ->
                                    m => cmds

                        LaborStage2 ->
                            case DataCache.get t dc of
                                Just (LaborStage2DataCache rec) ->
                                    { m | laborStage2Record = Just rec } => cmds

                                _ ->
                                    m => cmds

                        LaborStage3 ->
                            case DataCache.get t dc of
                                Just (LaborStage3DataCache rec) ->
                                    { m | laborStage3Record = Just rec } => cmds

                                _ ->
                                    m => cmds

                        Membrane ->
                            case DataCache.get t dc of
                                Just (MembraneDataCache rec) ->
                                    { m | membraneRecord = Just rec } => cmds

                                _ ->
                                    m => cmds

                        _ ->
                            ( m, ("LaborDelIpp.refreshModelFromCache: Unhandled Table" ++ toString t) :: cmds )
                )
                ( model, [] )
                tables
    in
    newModel => (Cmd.batch <| List.map logWarning cmds)


update : Session -> SubMsg -> Model -> ( Model, Cmd SubMsg, Cmd Msg )
update session msg model =
    case msg of
        PageNoop ->
            let
                _ =
                    Debug.log "PageNoop" "was called."
            in
            ( model, Cmd.none, Cmd.none )

        CloseAllDialogs ->
            -- Close all of the open dialogs that we have. This may be called
            -- when the user uses the back button to back out of a dialog.
            ( closeAllDialogs model, Cmd.none, Cmd.none )

        DataCache dc tbls ->
            -- If the dataCache and tables are something, this is the top-level
            -- intentionally sending it's dataCache to us as a read-only update
            -- on the latest data that it has. The specific records that need
            -- to be updated are in the tables list.
            let
                ( newModel, newCmd ) =
                    case ( dc, tbls ) of
                        ( Just dataCache, Just tables ) ->
                            refreshModelFromCache dataCache tables { model | dataCache = dataCache }

                        ( _, _ ) ->
                            ( model, Cmd.none )
            in
            ( newModel
            , Cmd.none
            , newCmd
            )

        LaborDelIppTick time ->
            -- Keep the current time in the Model.
            ( { model | currTime = time }, Cmd.none, Cmd.none )

        OpenDatePickerSubMsg id ->
            ( model, Cmd.none, Task.perform OpenDatePicker (Task.succeed id) )

        DateFieldSubMsg dateFldMsg ->
            -- For browsers that do not support a native date field.
            case dateFldMsg of
                DateFieldMessage { dateField, date } ->
                    case dateField of
                        BabyBFedEstablishedDateField ->
                            ( { model | bbBFedEstablishedDate = Just date }, Cmd.none, Cmd.none )

                        LaborDelIppLaborDateField ->
                            ( { model | laborDate = Just date }, Cmd.none, Cmd.none )

                        LaborDelIppStage1DateField ->
                            ( { model | stage1Date = Just date }, Cmd.none, Cmd.none )

                        LaborDelIppStage2DateField ->
                            ( { model | stage2Date = Just date }, Cmd.none, Cmd.none )

                        LaborDelIppStage3DateField ->
                            ( { model | stage3Date = Just date }, Cmd.none, Cmd.none )

                        MembraneRuptureDateField ->
                            ( { model | membraneRuptureDate = Just date }, Cmd.none, Cmd.none )

                        UnknownDateField str ->
                            ( model, Cmd.none, logWarning <| "Unknown date field: " ++ str )

                        _ ->
                            -- This page is not the only one with date fields, we only
                            -- handle what we know about.
                            ( model, Cmd.none, Cmd.none )

                UnknownDateFieldMessage str ->
                    ( model, Cmd.none, Cmd.none )

        FldChgSubMsg fld val ->
            -- All fields are handled here except for the date fields for browsers that
            -- do not support the input date type (see DateFieldSubMsg for those) and
            -- the boolean fields handled by FldChgBoolSubMsg above.
            let
                ( newModel, newCmd ) =
                    case val of
                        FldChgString value ->
                            case fld of
                                AdmittanceDateFld ->
                                    { model | admittanceDate = U.stringToDateAddSubOffset value } => Cmd.none

                                AdmittanceTimeFld ->
                                    { model | admittanceTime = Just <| U.filterStringLikeTime value } => Cmd.none

                                LaborDateFld ->
                                    { model | laborDate = U.stringToDateAddSubOffset value } => Cmd.none

                                LaborTimeFld ->
                                    { model | laborTime = Just <| U.filterStringLikeTime value } => Cmd.none

                                PosFld ->
                                    { model | pos = Just value } => Cmd.none

                                FhFld ->
                                    { model | fh = Just <| U.filterStringLikeInt value } => Cmd.none

                                FhtFld ->
                                    { model | fht = Just value } => Cmd.none

                                SystolicFld ->
                                    { model | systolic = Just <| U.filterStringLikeInt value } => Cmd.none

                                DiastolicFld ->
                                    { model | diastolic = Just <| U.filterStringLikeInt value } => Cmd.none

                                CrFld ->
                                    { model | cr = Just <| U.filterStringLikeInt value } => Cmd.none

                                TempFld ->
                                    { model | temp = Just <| U.filterStringLikeFloat value } => Cmd.none

                                CommentsFld ->
                                    { model | comments = Just value } => Cmd.none

                                Stage1DateFld ->
                                    { model | stage1Date = U.stringToDateAddSubOffset value } => Cmd.none

                                Stage1TimeFld ->
                                    { model | stage1Time = Just <| U.filterStringLikeTime value } => Cmd.none

                                Stage1MobilityFld ->
                                    { model | s1Mobility = Just value } => Cmd.none

                                Stage1DurationLatentHoursFld ->
                                    { model | s1DurationLatentHours = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage1DurationLatentMinutesFld ->
                                    { model | s1DurationLatentMinutes = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage1DurationActiveHoursFld ->
                                    { model | s1DurationActiveHours = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage1DurationActiveMinutesFld ->
                                    { model | s1DurationActiveMinutes = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage1CommentsFld ->
                                    { model | s1Comments = Just value } => Cmd.none

                                Stage2DateFld ->
                                    { model | stage2Date = U.stringToDateAddSubOffset value } => Cmd.none

                                Stage2TimeFld ->
                                    { model | stage2Time = Just <| U.filterStringLikeTime value } => Cmd.none

                                Stage2BirthDatetimeFld ->
                                    -- TODO: What is this field for if we have Stage2DateFld and Stage2TimeFld?
                                    model => Cmd.none

                                Stage2BirthTypeFld ->
                                    { model | s2BirthType = Just value } => Cmd.none

                                Stage2BirthPositionFld ->
                                    { model | s2BirthPosition = Just value } => Cmd.none

                                Stage2DurationPushingFld ->
                                    { model | s2DurationPushing = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage2BirthPresentationFld ->
                                    { model | s2BirthPresentation = Just value } => Cmd.none

                                Stage2CordWrapTypeFld ->
                                    { model | s2CordWrapType = Just value } => Cmd.none

                                Stage2DeliveryTypeFld ->
                                    { model | s2DeliveryType = Just value } => Cmd.none

                                Stage2ShoulderDystociaMinutesFld ->
                                    { model | s2ShoulderDystociaMinutes = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage2DegreeFld ->
                                    { model | s2Degree = Just value } => Cmd.none

                                Stage2LacerationRepairedByFld ->
                                    { model | s2LacerationRepairedBy = Just value } => Cmd.none

                                Stage2BirthEBLFld ->
                                    { model | s2BirthEBL = Just value } => Cmd.none

                                Stage2MeconiumFld ->
                                    { model | s2Meconium = Just value } => Cmd.none

                                Stage2CommentsFld ->
                                    { model | s2Comments = Just value } => Cmd.none

                                Stage3DateFld ->
                                    { model | stage3Date = U.stringToDateAddSubOffset value } => Cmd.none

                                Stage3TimeFld ->
                                    { model | stage3Time = Just <| U.filterStringLikeTime value } => Cmd.none

                                Stage3MaternalPositionFld ->
                                    { model | s3MaternalPosition = Just value } => Cmd.none

                                Stage3TxBloodLoss1Fld ->
                                    { model | s3TxBloodLoss1 = Just value } => Cmd.none

                                Stage3TxBloodLoss2Fld ->
                                    { model | s3TxBloodLoss2 = Just value } => Cmd.none

                                Stage3TxBloodLoss3Fld ->
                                    { model | s3TxBloodLoss3 = Just value } => Cmd.none

                                Stage3TxBloodLoss4Fld ->
                                    { model | s3TxBloodLoss4 = Just value } => Cmd.none

                                Stage3TxBloodLoss5Fld ->
                                    { model | s3TxBloodLoss5 = Just value } => Cmd.none

                                Stage3PlacentaShapeFld ->
                                    { model | s3PlacentaShape = Just value } => Cmd.none

                                Stage3PlacentaInsertionFld ->
                                    { model | s3PlacentaInsertion = Just value } => Cmd.none

                                Stage3PlacentaNumVesselsFld ->
                                    { model | s3PlacentaNumVessels = Just <| U.filterStringLikeInt value } => Cmd.none

                                Stage3SchultzDuncanFld ->
                                    -- TODO: need validity check here?
                                    { model | s3SchultzDuncan = Just value } => Cmd.none

                                Stage3CotyledonsFld ->
                                    { model | s3Cotyledons = Just value } => Cmd.none

                                Stage3MembranesFld ->
                                    { model | s3Membranes = Just value } => Cmd.none

                                Stage3CommentsFld ->
                                    { model | s3Comments = Just value } => Cmd.none

                                MembraneRuptureDateFld ->
                                    { model | membraneRuptureDate = U.stringToDateAddSubOffset value } => Cmd.none

                                MembraneRuptureTimeFld ->
                                    { model | membraneRuptureTime = Just <| U.filterStringLikeTime value } => Cmd.none

                                MembraneRuptureFld ->
                                    { model | membraneRupture = Just value } => Cmd.none

                                MembraneRuptureCommentFld ->
                                    { model | membraneRuptureComment = Just value } => Cmd.none

                                MembraneAmnioticFld ->
                                    { model | membraneAmniotic = Just value } => Cmd.none

                                MembraneAmnioticCommentFld ->
                                    { model | membraneAmnioticComment = Just value } => Cmd.none

                                MembraneCommentsFld ->
                                    { model | membraneComments = Just value } => Cmd.none

                                BabyLastnameFld ->
                                    { model | bbLastname = Just value } => Cmd.none

                                BabyFirstnameFld ->
                                    { model | bbFirstname = Just value } => Cmd.none

                                BabyMiddlenameFld ->
                                    { model | bbMiddlename = Just value } => Cmd.none

                                BabySexFld ->
                                    { model | bbSex = Just <| U.filterStringInList [ "Male", "Female", "Ambiguous" ] value } => Cmd.none

                                BabyBirthWeightFld ->
                                    { model | bbBirthWeight = Just <| U.filterStringLikeInt value } => Cmd.none

                                BabyBFedEstablishedDateFld ->
                                    { model | bbBFedEstablishedDate = U.stringToDateAddSubOffset value } => Cmd.none

                                BabyBFedEstablishedTimeFld ->
                                    { model | bbBFedEstablishedTime = Just <| U.filterStringLikeTime value } => Cmd.none

                                BabyCommentsFld ->
                                    { model | bbComments = Just value } => Cmd.none

                                ApgarOtherMinuteFld ->
                                    { model | pendingApgarMinute = Just value } => Cmd.none

                                ApgarOtherScoreFld ->
                                    { model | pendingApgarScore = Just <| U.filterStringLikeInt value } => Cmd.none

                                _ ->
                                    model
                                        => logWarning
                                            ("LaborDelIpp.update FldChgSubMsg: "
                                                ++ "Unknown field encountered in FldChgString. Possible mismatch between Field and FldChgValue."
                                            )

                        FldChgStringList _ _ ->
                            model => Cmd.none

                        FldChgBool value ->
                            case fld of
                                Stage2ShoulderDystociaFld ->
                                    { model | s2ShoulderDystocia = Just value } => Cmd.none

                                Stage2TerminalMecFld ->
                                    { model | s2TerminalMec = Just value } => Cmd.none

                                Stage2LacerationFld ->
                                    -- Clear the degree field if this and laceration are unchecked.
                                    if value == False then
                                        if model.s2Episiotomy == Nothing || model.s2Episiotomy == Just False then
                                            { model
                                                | s2Laceration = Just value
                                                , s2Degree = Nothing
                                            }
                                                => Cmd.none
                                        else
                                            { model | s2Laceration = Just value } => Cmd.none
                                    else
                                        { model | s2Laceration = Just value } => Cmd.none

                                Stage2EpisiotomyFld ->
                                    -- Clear the degree field if this and laceration are unchecked.
                                    if value == False then
                                        if model.s2Laceration == Nothing || model.s2Laceration == Just False then
                                            { model
                                                | s2Episiotomy = Just value
                                                , s2Degree = Nothing
                                            }
                                                => Cmd.none
                                        else
                                            { model | s2Episiotomy = Just value } => Cmd.none
                                    else
                                        { model | s2Episiotomy = Just value } => Cmd.none

                                Stage2RepairFld ->
                                    -- Clear the degree and repaired by fields if this is unchecked.
                                    if value == False then
                                        { model
                                            | s2Repair = Just value
                                            , s2Degree = Nothing
                                            , s2LacerationRepairedBy = Nothing
                                        }
                                            => Cmd.none
                                    else
                                        { model | s2Repair = Just value } => Cmd.none

                                Stage3PlacentaDeliverySpontaneousFld ->
                                    { model | s3PlacentaDeliverySpontaneous = Just value } => Cmd.none

                                Stage3PlacentaDeliveryAMTSLFld ->
                                    { model | s3PlacentaDeliveryAMTSL = Just value } => Cmd.none

                                Stage3PlacentaDeliveryCCTFld ->
                                    { model | s3PlacentaDeliveryCCT = Just value } => Cmd.none

                                Stage3PlacentaDeliveryManualFld ->
                                    { model | s3PlacentaDeliveryManual = Just value } => Cmd.none

                                BabyBulbFld ->
                                    { model | bbBulb = Just value } => Cmd.none

                                BabyMachineFld ->
                                    { model | bbMachine = Just value } => Cmd.none

                                BabyFreeFlowO2Fld ->
                                    { model | bbFreeFlowO2 = Just value } => Cmd.none

                                BabyChestCompressionsFld ->
                                    { model | bbChestCompressions = Just value } => Cmd.none

                                BabyPpvFld ->
                                    { model | bbPpv = Just value } => Cmd.none

                                _ ->
                                    model
                                        => logWarning
                                            ("LaborDelIpp.update FldChgSubMsg: "
                                                ++ "Unknown field encountered in FldChgBool. Possible mismatch between Field and FldChgValue."
                                            )

                        FldChgIntString intVal strVal ->
                            case fld of
                                ApgarStandardFld ->
                                    -- Handling one of the standard apgar 1, 5, or 10 fields. Stores data
                                    -- in the apgarScores field, which is a Dict with minute as key.
                                    case String.toInt strVal of
                                        Ok score ->
                                            -- Allowable scores are 0 - 10 inclusive.
                                            if score >= 0 && score <= 10 then
                                                { model
                                                    | apgarScores = Dict.insert intVal (ApgarScore (Just intVal) (Just score)) model.apgarScores
                                                }
                                                    => Cmd.none
                                            else
                                                model => Cmd.none

                                        Err _ ->
                                            -- That means that the user removed the score or entered
                                            -- something out of range, either way, remove it.
                                            { model
                                                | apgarScores = Dict.remove intVal model.apgarScores
                                            }
                                                => Cmd.none

                                _ ->
                                    model
                                        => logWarning
                                            ("LaborDelIpp.update FldChgSubMsg: "
                                                ++ "Unknown field encountered in FldChgTwoMaybeString. Possible mismatch between Field and FldChgValue."
                                            )
            in
            ( newModel
            , Cmd.none
            , newCmd
            )

        RotatePregHeaderContent pregHeaderMsg ->
            case pregHeaderMsg of
                PregHeaderData.RotatePregHeaderContentMsg ->
                    let
                        next =
                            case model.currPregHeaderContent of
                                PregHeaderData.PrenatalContent ->
                                    PregHeaderData.LaborContent

                                PregHeaderData.LaborContent ->
                                    PregHeaderData.IPPContent

                                PregHeaderData.IPPContent ->
                                    PregHeaderData.PrenatalContent
                    in
                    ( { model | currPregHeaderContent = next }, Cmd.none, Cmd.none )

        HandleStage1DateTimeModal dialogState ->
            case dialogState of
                OpenDialog ->
                    ( case ( model.stage1Date, model.stage1Time, model.laborStage1Record ) of
                        ( Nothing, Nothing, Nothing ) ->
                            -- If not yet set, the set the date/time to
                            -- current as a convenience to user.
                            { model
                                | stage1DateTimeModal =
                                    if model.stage1DateTimeModal == Stage1DateTimeModal then
                                        NoDateTimeModal
                                    else
                                        Stage1DateTimeModal
                                , stage1Date = Just <| Date.fromTime model.currTime
                                , stage1Time = Just <| U.timeToTimeString model.currTime
                            }

                        ( Nothing, Nothing, Just ls1Rec ) ->
                            -- Use the date/time in the fullDialation field.
                            { model
                                | stage1DateTimeModal =
                                    if model.stage1DateTimeModal == Stage1DateTimeModal then
                                        NoDateTimeModal
                                    else
                                        Stage1DateTimeModal
                                , stage1Date =
                                    Just <|
                                        Maybe.withDefault (Date.fromTime model.currTime)
                                            ls1Rec.fullDialation
                                , stage1Time =
                                    Just <|
                                        Maybe.withDefault (U.timeToTimeString model.currTime)
                                            (U.maybeDateToTimeString ls1Rec.fullDialation)
                            }

                        ( _, _, _ ) ->
                            { model | stage1DateTimeModal = Stage1DateTimeModal }
                    , Cmd.none
                    , Cmd.batch
                        [ if model.stage1DateTimeModal == NoDateTimeModal then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            -- User likely clicked outside of modal, so do nothing.
                            Cmd.none
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    ( { model | stage1DateTimeModal = NoDateTimeModal }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    -- This dialog option is not used for stage 1 date time.
                    ( model, Cmd.none, Cmd.none )

                CloseSaveDialog ->
                    -- Close and potentially send initial LaborStage1Record
                    -- to server as an add or update if it validates. An add will
                    -- send a LaborStage1RecordNew and an update uses the full
                    -- LaborStage1Record. The initial add is only sent if
                    -- both date and time are valid.
                    case validateStage1New model of
                        [] ->
                            let
                                outerMsg =
                                    case ( model.laborStage1Record, model.stage1Date, model.stage1Time ) of
                                        -- A laborStage1 record already exists, so update it.
                                        ( Just rec, Just d, Just t ) ->
                                            case U.stringToTimeTuple t of
                                                Just ( h, m ) ->
                                                    let
                                                        -- Need to insure that the new proposed date/time for
                                                        -- this stage does not fall after the next stage, if
                                                        -- it exists.
                                                        isSane =
                                                            case model.laborStage2Record of
                                                                Just ls2Rec ->
                                                                    sanityCheckStageDateTimes ls2Rec.birthDatetime
                                                                        model.stage1Date
                                                                        model.stage1Time
                                                                        |> not

                                                                Nothing ->
                                                                    True

                                                        newRec =
                                                            { rec | fullDialation = Just (U.datePlusTimeTuple d ( h, m )) }
                                                    in
                                                    if isSane then
                                                        ProcessTypeMsg
                                                            (UpdateLaborStage1Type
                                                                (LaborDelIppMsg
                                                                    (DataCache Nothing (Just [ LaborStage1 ]))
                                                                )
                                                                newRec
                                                            )
                                                            ChgMsgType
                                                            (laborStage1RecordToValue newRec)
                                                    else
                                                        Toast [ "Stage 1, 2, and 3 dates and times must be in chronological order." ]
                                                            10
                                                            ErrorToast

                                                Nothing ->
                                                    Noop

                                        ( Just rec, Nothing, Nothing ) ->
                                            -- User unset the fullDialation date/time, so update the server.
                                            let
                                                newRec =
                                                    { rec | fullDialation = Nothing }
                                            in
                                            ProcessTypeMsg
                                                (UpdateLaborStage1Type
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ LaborStage1 ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (laborStage1RecordToValue newRec)

                                        ( Nothing, Just _, Just _ ) ->
                                            -- Create a new laborStage1 record.
                                            case deriveLaborStage1RecordNew model of
                                                Just laborStage1RecNew ->
                                                    ProcessTypeMsg
                                                        (AddLaborStage1Type
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ LaborStage1 ]))
                                                            )
                                                            laborStage1RecNew
                                                        )
                                                        AddMsgType
                                                        (laborStage1RecordNewToValue laborStage1RecNew)

                                                Nothing ->
                                                    Noop

                                        ( _, _, _ ) ->
                                            Noop
                            in
                            ( { model
                                | stage1DateTimeModal = NoDateTimeModal
                              }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | stage1DateTimeModal = NoDateTimeModal }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleStage1SummaryModal dialogState ->
            case dialogState of
                -- If there already is a laborStage1Record, then populate the form
                -- fields with the contents of that record.
                OpenDialog ->
                    let
                        ( mobility, latent, active, comments ) =
                            case model.laborStage1Record of
                                Just rec ->
                                    ( rec.mobility
                                    , rec.durationLatent
                                    , rec.durationActive
                                    , rec.comments
                                    )

                                Nothing ->
                                    ( Nothing
                                    , Nothing
                                    , Nothing
                                    , Nothing
                                    )
                    in
                    -- We set the modal to View but it will show the edit screen
                    -- if there are fields not complete.
                    -- Also, if we are not on the NoViewEditState, we set the
                    -- modal to that which has the effect of allowing the Summary
                    -- button in the view to serve as a toggle.
                    ( { model
                        | stage1SummaryModal =
                            if model.stage1SummaryModal == NoViewEditState then
                                Stage1ViewState
                            else
                                NoViewEditState
                        , s1Mobility = mobility
                        , s1DurationLatentHours = Maybe.map toString <| U.minutesToHours latent
                        , s1DurationLatentMinutes = Maybe.map toString <| U.minutesToMinutes latent
                        , s1DurationActiveHours = Maybe.map toString <| U.minutesToHours active
                        , s1DurationActiveMinutes = Maybe.map toString <| U.minutesToMinutes active
                        , s1Comments = comments
                      }
                    , Cmd.none
                    , Cmd.batch
                        [ if model.stage1SummaryModal == NoViewEditState then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            Route.back
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    -- We keep whatever, if anything, the user entered into the
                    -- form fields.
                    ( { model | stage1SummaryModal = NoViewEditState }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    -- Transitioning from a viewing summary state to editing again by
                    -- explicitly setting the mode to edit. This is different that
                    -- Stage1ViewState in that we are forcing edit here.
                    ( { model | stage1SummaryModal = Stage1EditState }
                    , Cmd.none
                    , if model.stage1SummaryModal == NoViewEditState then
                        Cmd.batch
                            [ Route.addDialogUrl Route.LaborDelIppRoute
                            , Task.perform SetDialogActive <| Task.succeed True
                            ]
                      else
                        Cmd.none
                    )

                CloseSaveDialog ->
                    -- We save to the database if the form fields validate.
                    case validateStage1 model of
                        [] ->
                            let
                                outerMsg =
                                    case model.laborStage1Record of
                                        Just s1Rec ->
                                            -- A Stage 1 record already exists, so update it.
                                            let
                                                newRec =
                                                    { s1Rec
                                                        | mobility = model.s1Mobility
                                                        , durationLatent =
                                                            U.maybeHoursMaybeMinutesToMaybeMinutes
                                                                (U.maybeStringToMaybeInt model.s1DurationLatentHours)
                                                                (U.maybeStringToMaybeInt model.s1DurationLatentMinutes)
                                                        , durationActive =
                                                            U.maybeHoursMaybeMinutesToMaybeMinutes
                                                                (U.maybeStringToMaybeInt model.s1DurationActiveHours)
                                                                (U.maybeStringToMaybeInt model.s1DurationActiveMinutes)
                                                        , comments = model.s1Comments
                                                    }
                                            in
                                            ProcessTypeMsg
                                                (UpdateLaborStage1Type
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ LaborStage1 ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (laborStage1RecordToValue newRec)

                                        Nothing ->
                                            -- Need to create a new stage 1 record for the server.
                                            case deriveLaborStage1RecordNew model of
                                                Just laborStage1RecNew ->
                                                    ProcessTypeMsg
                                                        (AddLaborStage1Type
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ LaborStage1 ]))
                                                            )
                                                            laborStage1RecNew
                                                        )
                                                        AddMsgType
                                                        (laborStage1RecordNewToValue laborStage1RecNew)

                                                Nothing ->
                                                    Log ErrorSeverity "deriveLaborStage1RecordNew returned a Nothing"
                            in
                            ( { model | stage1SummaryModal = NoViewEditState }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | stage1SummaryModal = NoViewEditState }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleStage2DateTimeModal dialogState ->
            -- The user has just opened the modal to set the date/time for stage 2
            -- completion. We default to the current date/time for convenience if
            -- this is an open event, but only if the date/time has not already
            -- been previously selected.
            case dialogState of
                OpenDialog ->
                    ( case ( model.stage2Date, model.stage2Time, model.laborStage2Record ) of
                        ( Nothing, Nothing, Nothing ) ->
                            -- If not yet set, the set the date/time to
                            -- current as a convenience to user.
                            { model
                                | stage2DateTimeModal =
                                    if model.stage2DateTimeModal == Stage2DateTimeModal then
                                        NoDateTimeModal
                                    else
                                        Stage2DateTimeModal
                                , stage2Date = Just <| Date.fromTime model.currTime
                                , stage2Time = Just <| U.timeToTimeString model.currTime
                            }

                        ( Nothing, Nothing, Just ls2Rec ) ->
                            -- Use the date/time in the birthDatetime field.
                            { model
                                | stage2DateTimeModal =
                                    if model.stage2DateTimeModal == Stage2DateTimeModal then
                                        NoDateTimeModal
                                    else
                                        Stage2DateTimeModal
                                , stage2Date =
                                    Just <|
                                        Maybe.withDefault (Date.fromTime model.currTime)
                                            ls2Rec.birthDatetime
                                , stage2Time =
                                    Just <|
                                        Maybe.withDefault (U.timeToTimeString model.currTime)
                                            (U.maybeDateToTimeString ls2Rec.birthDatetime)
                            }

                        ( _, _, _ ) ->
                            { model | stage2DateTimeModal = Stage2DateTimeModal }
                    , Cmd.none
                    , Cmd.batch
                        [ if model.stage2DateTimeModal == NoDateTimeModal then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            -- User likely clicked outside of modal, so do nothing.
                            Cmd.none
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    ( { model | stage2DateTimeModal = NoDateTimeModal }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    -- This dialog option is not used for stage 2 date time.
                    ( model, Cmd.none, Cmd.none )

                CloseSaveDialog ->
                    -- Close and potentially send initial LaborStage2Record
                    -- to server as an add or update if it validates. An add will
                    -- send a LaborStage2RecordNew and an update uses the full
                    -- LaborStage2Record. The initial add is only sent if
                    -- both date and time are valid.
                    case validateStage2New model of
                        [] ->
                            let
                                -- Simple check that the date/time proposed falls after the prior stage
                                -- date/time.
                                isSane =
                                    case model.laborStage1Record of
                                        Just ls1Rec ->
                                            sanityCheckStageDateTimes ls1Rec.fullDialation
                                                model.stage2Date
                                                model.stage2Time

                                        Nothing ->
                                            False

                                outerMsg =
                                    case ( isSane, model.laborStage2Record, model.stage2Date, model.stage2Time ) of
                                        ( False, _, _, _ ) ->
                                            Toast [ "The stage 1, 2, and 3 dates and times must be in chronological order." ]
                                                10
                                                ErrorToast

                                        -- A laborStage2 record already exists, so update it.
                                        ( True, Just rec, Just d, Just t ) ->
                                            case U.stringToTimeTuple t of
                                                Just ( h, m ) ->
                                                    let
                                                        -- Need to insure that the new proposed date/time for
                                                        -- this stage does not fall after the next stage, if
                                                        -- it exists.
                                                        isSane =
                                                            case model.laborStage3Record of
                                                                Just ls3Rec ->
                                                                    sanityCheckStageDateTimes ls3Rec.placentaDatetime
                                                                        model.stage2Date
                                                                        model.stage2Time
                                                                        |> not

                                                                Nothing ->
                                                                    True

                                                        newRec =
                                                            { rec | birthDatetime = Just (U.datePlusTimeTuple d ( h, m )) }
                                                    in
                                                    if isSane then
                                                        ProcessTypeMsg
                                                            (UpdateLaborStage2Type
                                                                (LaborDelIppMsg
                                                                    (DataCache Nothing (Just [ LaborStage2 ]))
                                                                )
                                                                newRec
                                                            )
                                                            ChgMsgType
                                                            (laborStage2RecordToValue newRec)
                                                    else
                                                        Toast [ "Stage 1, 2, and 3 dates and times must be in chronological order." ]
                                                            10
                                                            ErrorToast

                                                Nothing ->
                                                    Noop

                                        ( True, Just rec, Nothing, Nothing ) ->
                                            -- User unset the birthDatetime, so update the server.
                                            let
                                                newRec =
                                                    { rec | birthDatetime = Nothing }
                                            in
                                            ProcessTypeMsg
                                                (UpdateLaborStage2Type
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ LaborStage2 ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (laborStage2RecordToValue newRec)

                                        ( True, Nothing, Just _, Just _ ) ->
                                            -- Create a new laborStage2 record.
                                            case deriveLaborStage2RecordNew model of
                                                Just laborStage2RecNew ->
                                                    ProcessTypeMsg
                                                        (AddLaborStage2Type
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ LaborStage2 ]))
                                                            )
                                                            laborStage2RecNew
                                                        )
                                                        AddMsgType
                                                        (laborStage2RecordNewToValue laborStage2RecNew)

                                                Nothing ->
                                                    Noop

                                        ( True, _, _, _ ) ->
                                            Noop
                            in
                            ( { model
                                | stage2DateTimeModal = NoDateTimeModal
                              }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | stage2DateTimeModal = NoDateTimeModal }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleStage2SummaryModal dialogState ->
            case dialogState of
                -- If there already is a laborStage2Record, then populate the form
                -- fields with the contents of that record. But since it is possible
                -- that the laborStage2Record may only have minimal content, allow
                -- form fields in model to be used as alternatives.
                OpenDialog ->
                    let
                        newModel =
                            case model.laborStage2Record of
                                Just rec ->
                                    { model
                                        | s2BirthType = U.maybeOr rec.birthType model.s2BirthType
                                        , s2BirthPosition = U.maybeOr rec.birthPosition model.s2BirthPosition
                                        , s2DurationPushing = U.maybeOr (Maybe.map toString rec.durationPushing) model.s2DurationPushing
                                        , s2BirthPresentation = U.maybeOr rec.birthPresentation model.s2BirthPresentation
                                        , s2TerminalMec = U.maybeOr rec.terminalMec model.s2TerminalMec
                                        , s2CordWrapType = U.maybeOr rec.cordWrapType model.s2CordWrapType
                                        , s2DeliveryType = U.maybeOr rec.deliveryType model.s2DeliveryType
                                        , s2ShoulderDystocia = U.maybeOr rec.shoulderDystocia model.s2ShoulderDystocia
                                        , s2ShoulderDystociaMinutes = U.maybeOr (Maybe.map toString rec.shoulderDystociaMinutes) model.s2ShoulderDystociaMinutes
                                        , s2Laceration = U.maybeOr rec.laceration model.s2Laceration
                                        , s2Episiotomy = U.maybeOr rec.episiotomy model.s2Episiotomy
                                        , s2Repair = U.maybeOr rec.repair model.s2Repair
                                        , s2Degree = U.maybeOr rec.degree model.s2Degree
                                        , s2LacerationRepairedBy = U.maybeOr rec.lacerationRepairedBy model.s2LacerationRepairedBy
                                        , s2BirthEBL = U.maybeOr (Maybe.map toString rec.birthEBL) model.s2BirthEBL
                                        , s2Meconium = U.maybeOr rec.meconium model.s2Meconium
                                        , s2Comments = U.maybeOr rec.comments model.s2Comments
                                    }

                                Nothing ->
                                    model
                    in
                    -- We set the modal to View but it will show the edit screen
                    -- if there are fields not complete.
                    --
                    -- The if below allows the summary button to toggle on/off the form.
                    ( { newModel
                        | stage2SummaryModal =
                            if newModel.stage2SummaryModal == NoViewEditState then
                                Stage2ViewState
                            else
                                NoViewEditState
                      }
                    , Cmd.none
                    , Cmd.batch
                        [ if newModel.stage2SummaryModal == NoViewEditState then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            Route.back
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    -- We keep whatever, if anything, the user entered into the
                    -- form fields.
                    ( { model | stage2SummaryModal = NoViewEditState }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    -- Transitioning from a viewing summary state to editing again by
                    -- explicitly setting the mode to edit. This is different that
                    -- Stage2ViewState in that we are forcing edit here.
                    ( { model | stage2SummaryModal = Stage2EditState }
                    , Cmd.none
                    , if model.stage2SummaryModal == NoViewEditState then
                        Cmd.batch
                            [ Route.addDialogUrl Route.LaborDelIppRoute
                            , Task.perform SetDialogActive <| Task.succeed True
                            ]
                      else
                        Cmd.none
                    )

                CloseSaveDialog ->
                    -- We save to the database if the form fields validate.
                    case validateStage2 model of
                        [] ->
                            let
                                outerMsg =
                                    case model.laborStage2Record of
                                        Just s2Rec ->
                                            -- A Stage 2 record already exists, so update it.
                                            let
                                                newRec =
                                                    { s2Rec
                                                        | birthType = model.s2BirthType
                                                        , birthPosition = model.s2BirthPosition
                                                        , durationPushing = U.maybeStringToMaybeInt model.s2DurationPushing
                                                        , birthPresentation = model.s2BirthPresentation
                                                        , terminalMec = model.s2TerminalMec
                                                        , cordWrapType = model.s2CordWrapType
                                                        , deliveryType = model.s2DeliveryType
                                                        , shoulderDystocia = model.s2ShoulderDystocia
                                                        , shoulderDystociaMinutes = U.maybeStringToMaybeInt model.s2ShoulderDystociaMinutes
                                                        , laceration = model.s2Laceration
                                                        , episiotomy = model.s2Episiotomy
                                                        , repair = model.s2Repair
                                                        , degree = model.s2Degree
                                                        , lacerationRepairedBy = model.s2LacerationRepairedBy
                                                        , birthEBL = U.maybeStringToMaybeInt model.s2BirthEBL
                                                        , meconium = model.s2Meconium
                                                        , comments = model.s2Comments
                                                    }
                                            in
                                            ProcessTypeMsg
                                                (UpdateLaborStage2Type
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ LaborStage2 ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (laborStage2RecordToValue newRec)

                                        Nothing ->
                                            -- Need to create a new stage 2 record for the server.
                                            case deriveLaborStage2RecordNew model of
                                                Just laborStage2RecNew ->
                                                    ProcessTypeMsg
                                                        (AddLaborStage2Type
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ LaborStage2 ]))
                                                            )
                                                            laborStage2RecNew
                                                        )
                                                        AddMsgType
                                                        (laborStage2RecordNewToValue laborStage2RecNew)

                                                Nothing ->
                                                    Log ErrorSeverity "deriveLaborStage2RecordNew returned a Nothing"
                            in
                            ( { model | stage2SummaryModal = NoViewEditState }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | stage2SummaryModal = NoViewEditState }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleStage3DateTimeModal dialogState ->
            -- The user has just opened the modal to set the date/time for stage 3
            -- completion. We default to the current date/time for convenience if
            -- this is an open event, but only if the date/time has not already
            -- been previously selected.
            case dialogState of
                OpenDialog ->
                    ( case ( model.stage3Date, model.stage3Time, model.laborStage3Record ) of
                        ( Nothing, Nothing, Nothing ) ->
                            -- If not yet set, the set the date/time to
                            -- current as a convenience to user.
                            { model
                                | stage3DateTimeModal =
                                    if model.stage3DateTimeModal == Stage3DateTimeModal then
                                        NoDateTimeModal
                                    else
                                        Stage3DateTimeModal
                                , stage3Date = Just <| Date.fromTime model.currTime
                                , stage3Time = Just <| U.timeToTimeString model.currTime
                            }

                        ( Nothing, Nothing, Just ls3Rec ) ->
                            -- Use the date/time in the placentaDatetime field.
                            { model
                                | stage3DateTimeModal =
                                    if model.stage3DateTimeModal == Stage3DateTimeModal then
                                        NoDateTimeModal
                                    else
                                        Stage3DateTimeModal
                                , stage3Date =
                                    Just <|
                                        Maybe.withDefault (Date.fromTime model.currTime)
                                            ls3Rec.placentaDatetime
                                , stage3Time =
                                    Just <|
                                        Maybe.withDefault (U.timeToTimeString model.currTime)
                                            (U.maybeDateToTimeString ls3Rec.placentaDatetime)
                            }

                        ( _, _, _ ) ->
                            { model | stage3DateTimeModal = Stage3DateTimeModal }
                    , Cmd.none
                    , Cmd.batch
                        [ if model.stage3DateTimeModal == NoDateTimeModal then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            -- User likely clicked outside of modal, so do nothing.
                            Cmd.none
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    ( { model | stage3DateTimeModal = NoDateTimeModal }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    -- This dialog option is not used for stage 3 date time.
                    ( model, Cmd.none, Cmd.none )

                CloseSaveDialog ->
                    -- Close and potentially send initial LaborStage3Record
                    -- to server as an add or update if it validates. An add will
                    -- send a LaborStage3RecordNew and an update uses the full
                    -- LaborStage3Record. The initial add is only sent if
                    -- both date and time are valid.
                    case validateStage3New model of
                        [] ->
                            let
                                isSane =
                                    case model.laborStage2Record of
                                        Just ls2Rec ->
                                            sanityCheckStageDateTimes ls2Rec.birthDatetime
                                                model.stage3Date
                                                model.stage3Time

                                        Nothing ->
                                            False

                                outerMsg =
                                    case ( isSane, model.laborStage3Record, model.stage3Date, model.stage3Time ) of
                                        ( False, _, _, _ ) ->
                                            Toast [ "The stage 1, 2, and 3 dates and times must be in chronological order." ]
                                                10
                                                ErrorToast

                                        -- A laborStage3 record already exists, so update it.
                                        ( True, Just rec, Just d, Just t ) ->
                                            case U.stringToTimeTuple t of
                                                Just ( h, m ) ->
                                                    let
                                                        newRec =
                                                            { rec | placentaDatetime = Just (U.datePlusTimeTuple d ( h, m )) }
                                                    in
                                                    ProcessTypeMsg
                                                        (UpdateLaborStage3Type
                                                            (LaborDelIppMsg
                                                                (DataCache Nothing (Just [ LaborStage3 ]))
                                                            )
                                                            newRec
                                                        )
                                                        ChgMsgType
                                                        (laborStage3RecordToValue newRec)

                                                Nothing ->
                                                    Noop

                                        ( True, Just rec, Nothing, Nothing ) ->
                                            -- User unset the placentaDatetime, so update the server.
                                            let
                                                newRec =
                                                    { rec | placentaDatetime = Nothing }
                                            in
                                            ProcessTypeMsg
                                                (UpdateLaborStage3Type
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ LaborStage3 ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (laborStage3RecordToValue newRec)

                                        ( True, Nothing, Just _, Just _ ) ->
                                            -- Create a new laborStage3 record.
                                            case deriveLaborStage3RecordNew model of
                                                Just laborStage3RecNew ->
                                                    ProcessTypeMsg
                                                        (AddLaborStage3Type
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ LaborStage3 ]))
                                                            )
                                                            laborStage3RecNew
                                                        )
                                                        AddMsgType
                                                        (laborStage3RecordNewToValue laborStage3RecNew)

                                                Nothing ->
                                                    Noop

                                        ( True, _, _, _ ) ->
                                            Noop
                            in
                            ( { model
                                | stage3DateTimeModal = NoDateTimeModal
                              }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | stage3DateTimeModal = NoDateTimeModal }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleStage3SummaryModal dialogState ->
            case dialogState of
                -- If there already is a laborStage3Record, then populate the form
                -- fields with the contents of that record. But since it is possible
                -- that the laborStage3Record may only have minimal content, allow
                -- form fields in model to be used as alternatives.
                OpenDialog ->
                    let
                        newModel =
                            case model.laborStage3Record of
                                Just rec ->
                                    { model
                                        | s3PlacentaDeliverySpontaneous = U.maybeOr rec.placentaDeliverySpontaneous model.s3PlacentaDeliverySpontaneous
                                        , s3PlacentaDeliveryAMTSL = U.maybeOr rec.placentaDeliveryAMTSL model.s3PlacentaDeliveryAMTSL
                                        , s3PlacentaDeliveryCCT = U.maybeOr rec.placentaDeliveryCCT model.s3PlacentaDeliveryCCT
                                        , s3PlacentaDeliveryManual = U.maybeOr rec.placentaDeliveryManual model.s3PlacentaDeliveryManual
                                        , s3MaternalPosition = U.maybeOr rec.maternalPosition model.s3MaternalPosition
                                        , s3TxBloodLoss1 = U.maybeOr rec.txBloodLoss1 model.s3TxBloodLoss1
                                        , s3TxBloodLoss2 = U.maybeOr rec.txBloodLoss2 model.s3TxBloodLoss2
                                        , s3TxBloodLoss3 = U.maybeOr rec.txBloodLoss3 model.s3TxBloodLoss3
                                        , s3TxBloodLoss4 = U.maybeOr rec.txBloodLoss4 model.s3TxBloodLoss4
                                        , s3TxBloodLoss5 = U.maybeOr rec.txBloodLoss5 model.s3TxBloodLoss5
                                        , s3PlacentaShape = U.maybeOr rec.placentaShape model.s3PlacentaShape
                                        , s3PlacentaInsertion = U.maybeOr rec.placentaInsertion model.s3PlacentaInsertion
                                        , s3PlacentaNumVessels = U.maybeOr (Maybe.map toString rec.placentaNumVessels) model.s3PlacentaNumVessels
                                        , s3SchultzDuncan = U.maybeOr (Maybe.map schultzDuncan2String rec.schultzDuncan) model.s3SchultzDuncan
                                        , s3Cotyledons = U.maybeOr rec.cotyledons model.s3Cotyledons
                                        , s3Membranes = U.maybeOr rec.membranes model.s3Membranes
                                        , s3Comments = U.maybeOr rec.comments model.s3Comments
                                    }

                                Nothing ->
                                    model
                    in
                    -- We set the modal to View but it will show the edit screen
                    -- if there are fields not complete.
                    --
                    -- The if below allows the summary button to toggle on/off the form.
                    ( { newModel
                        | stage3SummaryModal =
                            if newModel.stage3SummaryModal == NoViewEditState then
                                Stage3ViewState
                            else
                                NoViewEditState
                      }
                    , Cmd.none
                    , Cmd.batch
                        [ if newModel.stage3SummaryModal == NoViewEditState then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            Route.back
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    -- We keep whatever, if anything, the user entered into the
                    -- form fields.
                    ( { model | stage3SummaryModal = NoViewEditState }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    -- Transitioning from a viewing summary state to editing again by
                    -- explicitly setting the mode to edit. This is different that
                    -- Stage3ViewState in that we are forcing edit here.
                    ( { model | stage3SummaryModal = Stage3EditState }
                    , Cmd.none
                    , if model.stage3SummaryModal == NoViewEditState then
                        Cmd.batch
                            [ Route.addDialogUrl Route.LaborDelIppRoute
                            , Task.perform SetDialogActive <| Task.succeed True
                            ]
                      else
                        Cmd.none
                    )

                CloseSaveDialog ->
                    -- We save to the database if the form fields validate.
                    case validateStage3 model of
                        [] ->
                            let
                                outerMsg =
                                    case model.laborStage3Record of
                                        Just s3Rec ->
                                            -- A Stage 2 record already exists, so update it.
                                            let
                                                newRec =
                                                    { s3Rec
                                                        | placentaDeliverySpontaneous = model.s3PlacentaDeliverySpontaneous
                                                        , placentaDeliveryAMTSL = model.s3PlacentaDeliveryAMTSL
                                                        , placentaDeliveryCCT = model.s3PlacentaDeliveryCCT
                                                        , placentaDeliveryManual = model.s3PlacentaDeliveryManual
                                                        , maternalPosition = model.s3MaternalPosition
                                                        , txBloodLoss1 = model.s3TxBloodLoss1
                                                        , txBloodLoss2 = model.s3TxBloodLoss2
                                                        , txBloodLoss3 = model.s3TxBloodLoss3
                                                        , txBloodLoss4 = model.s3TxBloodLoss4
                                                        , txBloodLoss5 = model.s3TxBloodLoss5
                                                        , placentaShape = model.s3PlacentaShape
                                                        , placentaInsertion = model.s3PlacentaInsertion
                                                        , placentaNumVessels = U.maybeStringToMaybeInt model.s3PlacentaNumVessels
                                                        , schultzDuncan = string2SchultzDuncan (Maybe.withDefault "" model.s3SchultzDuncan)
                                                        , cotyledons = model.s3Cotyledons
                                                        , membranes = model.s3Membranes
                                                        , comments = model.s3Comments
                                                    }
                                            in
                                            ProcessTypeMsg
                                                (UpdateLaborStage3Type
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ LaborStage3 ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (laborStage3RecordToValue newRec)

                                        Nothing ->
                                            -- Need to create a new stage 3 record for the server.
                                            case deriveLaborStage3RecordNew model of
                                                Just laborStage3RecNew ->
                                                    ProcessTypeMsg
                                                        (AddLaborStage3Type
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ LaborStage3 ]))
                                                            )
                                                            laborStage3RecNew
                                                        )
                                                        AddMsgType
                                                        (laborStage3RecordNewToValue laborStage3RecNew)

                                                Nothing ->
                                                    Log ErrorSeverity "deriveLaborStage3RecordNew returned a Nothing"
                            in
                            ( { model | stage3SummaryModal = NoViewEditState }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | stage3SummaryModal = NoViewEditState }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleMembraneSummaryModal dialogState ->
            case dialogState of
                OpenDialog ->
                    let
                        newModel =
                            case model.membraneRecord of
                                Just rec ->
                                    { model
                                        | membraneRuptureDate = rec.ruptureDatetime
                                        , membraneRuptureTime =
                                            U.maybeOr
                                                (Maybe.map U.dateToTimeString rec.ruptureDatetime)
                                                model.membraneRuptureTime
                                        , membraneRupture = U.maybeOr (Just (Data.Membrane.maybeRuptureToString rec.rupture)) model.membraneRupture
                                        , membraneRuptureComment = U.maybeOr rec.ruptureComment model.membraneRuptureComment
                                        , membraneAmniotic = U.maybeOr (Just (Data.Membrane.maybeAmnioticToString rec.amniotic)) model.membraneAmniotic
                                        , membraneAmnioticComment = U.maybeOr rec.amnioticComment model.membraneAmnioticComment
                                        , membraneComments = U.maybeOr rec.comments model.membraneComments
                                    }

                                Nothing ->
                                    model
                    in
                    ( { newModel
                        | membraneSummaryModal =
                            if model.membraneSummaryModal == NoViewEditState then
                                MembraneViewState
                            else
                                NoViewEditState
                      }
                    , Cmd.none
                    , Cmd.batch
                        [ if model.membraneSummaryModal == NoViewEditState then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            Route.back
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    ( { model | membraneSummaryModal = NoViewEditState }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    ( { model | membraneSummaryModal = MembraneEditState }
                    , Cmd.none
                    , if model.membraneSummaryModal == NoViewEditState then
                        Cmd.batch
                            [ Route.addDialogUrl Route.LaborDelIppRoute
                            , Task.perform SetDialogActive <| Task.succeed True
                            ]
                      else
                        Cmd.none
                    )

                CloseSaveDialog ->
                    case validateMembrane model of
                        [] ->
                            let
                                ruptureDatetime =
                                    U.maybeDateMaybeTimeToMaybeDateTime model.membraneRuptureDate
                                        model.membraneRuptureTime
                                        "Please correct the date and time for the rupture."

                                errors =
                                    U.maybeDateTimeErrors [ ruptureDatetime ]

                                outerMsg =
                                    case ( List.length errors > 0, model.membraneRecord ) of
                                        ( True, _ ) ->
                                            -- Errors found in the date and time field, so notifiy user
                                            -- instead of saving.
                                            Toast (errors ++ [ "Record was not saved." ]) 10 ErrorToast

                                        ( False, Just rec ) ->
                                            -- A membrane record already exists so update it.
                                            let
                                                newRec =
                                                    { rec
                                                        | ruptureDatetime = U.maybeDateTimeValue ruptureDatetime
                                                        , rupture = Data.Membrane.maybeStringToRupture model.membraneRupture
                                                        , ruptureComment = model.membraneRuptureComment
                                                        , amniotic = Data.Membrane.maybeStringToAmniotic model.membraneAmniotic
                                                        , amnioticComment = model.membraneAmnioticComment
                                                        , comments = model.membraneComments
                                                    }
                                            in
                                            ProcessTypeMsg
                                                (UpdateMembraneType
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ Membrane ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (membraneRecordToValue newRec)

                                        ( False, Nothing ) ->
                                            -- A new membrane record is being created.
                                            case deriveMembraneRecordNew model of
                                                Just membraneRecordNew ->
                                                    ProcessTypeMsg
                                                        (AddMembraneType
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ Membrane ]))
                                                            )
                                                            membraneRecordNew
                                                        )
                                                        AddMsgType
                                                        (membraneRecordNewToValue membraneRecordNew)

                                                Nothing ->
                                                    Log ErrorSeverity "deriveMembraneRecordNew returned a Nothing"
                            in
                            ( { model | membraneSummaryModal = NoViewEditState }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | membraneSummaryModal = NoViewEditState }
                            , Cmd.none
                            , toastError msgs 10
                            )

        HandleBabySummaryModal dialogState ->
            case dialogState of
                OpenDialog ->
                    let
                        newModel =
                            case model.babyRecord of
                                Just rec ->
                                    { model
                                        | bbLastname = U.maybeOr rec.lastname model.bbLastname
                                        , bbFirstname = U.maybeOr rec.firstname model.bbFirstname
                                        , bbMiddlename = U.maybeOr rec.middlename model.bbMiddlename
                                        , bbSex = U.maybeOr (Just (sexToFullString rec.sex)) model.bbSex
                                        , bbBirthWeight = U.maybeOr (Maybe.map toString rec.birthWeight) model.bbBirthWeight
                                        , bbBFedEstablishedDate = rec.bFedEstablished
                                        , bbBFedEstablishedTime =
                                            U.maybeOr
                                                (Maybe.map U.dateToTimeString rec.bFedEstablished)
                                                model.bbBFedEstablishedTime
                                        , bbBulb = U.maybeOr rec.bulb model.bbBulb
                                        , bbMachine = U.maybeOr rec.machine model.bbMachine
                                        , bbFreeFlowO2 = U.maybeOr rec.freeFlowO2 model.bbFreeFlowO2
                                        , bbChestCompressions = U.maybeOr rec.chestCompressions model.bbChestCompressions
                                        , bbPpv = U.maybeOr rec.ppv model.bbPpv
                                        , bbComments = U.maybeOr rec.comments model.bbComments
                                        , apgarScores = apgarRecordListToApgarScoreDict rec.apgarScores
                                    }

                                Nothing ->
                                    model
                    in
                    ( { newModel
                        | babySummaryModal =
                            if model.babySummaryModal == NoViewEditState then
                                BabyViewState
                            else
                                NoViewEditState
                      }
                    , Cmd.none
                    , Cmd.batch
                        [ if model.babySummaryModal == NoViewEditState then
                            Route.addDialogUrl Route.LaborDelIppRoute
                          else
                            Route.back
                        , Task.perform SetDialogActive <| Task.succeed True
                        ]
                    )

                CloseNoSaveDialog ->
                    ( { model | babySummaryModal = NoViewEditState }
                    , Cmd.none
                    , Route.back
                    )

                EditDialog ->
                    ( { model | babySummaryModal = BabyEditState }
                    , Cmd.none
                    , if model.babySummaryModal == NoViewEditState then
                        Cmd.batch
                            [ Route.addDialogUrl Route.LaborDelIppRoute
                            , Task.perform SetDialogActive <| Task.succeed True
                            ]
                      else
                        Cmd.none
                    )

                CloseSaveDialog ->
                    case validateBaby model of
                        [] ->
                            let
                                -- Check that the date and corresponding time fields together
                                -- produce valid dates.
                                bfedDatetime =
                                    U.maybeDateMaybeTimeToMaybeDateTime model.bbBFedEstablishedDate
                                        model.bbBFedEstablishedTime
                                        "Please correct the date and time for the breast fed fields."

                                errors =
                                    U.maybeDateTimeErrors [ bfedDatetime ]

                                outerMsg =
                                    case ( List.length errors > 0, model.babyRecord, model.bbSex ) of
                                        ( _, Just rec, Nothing ) ->
                                            -- We should never get here.
                                            Log ErrorSeverity <|
                                                "LaborDelIpp.update in HandleBabySummaryModal,CloseSaveDialog "
                                                    ++ " branch with model.bbSex set to Nothing."

                                        ( True, _, _ ) ->
                                            -- Errors found in the date and time fields, so notifiy user
                                            -- instead of saving.
                                            Toast (errors ++ [ "Record was not saved." ]) 10 ErrorToast

                                        ( False, Just rec, Just sex ) ->
                                            -- A baby record already exists so update it.
                                            let
                                                newRec =
                                                    { rec
                                                        | lastname = model.bbLastname
                                                        , firstname = model.bbFirstname
                                                        , middlename = model.bbMiddlename
                                                        , sex = stringToSex sex
                                                        , birthWeight = U.maybeStringToMaybeInt model.bbBirthWeight
                                                        , bFedEstablished = U.maybeDateTimeValue bfedDatetime
                                                        , bulb = model.bbBulb
                                                        , machine = model.bbMachine
                                                        , freeFlowO2 = model.bbFreeFlowO2
                                                        , chestCompressions = model.bbChestCompressions
                                                        , ppv = model.bbPpv
                                                        , comments = model.bbComments
                                                        , apgarScores = apgarScoreDictToApgarRecordList model.apgarScores
                                                    }
                                            in
                                            ProcessTypeMsg
                                                (UpdateBabyType
                                                    (LaborDelIppMsg
                                                        (DataCache Nothing (Just [ Baby ]))
                                                    )
                                                    newRec
                                                )
                                                ChgMsgType
                                                (babyRecordToValue newRec)

                                        ( False, Nothing, _ ) ->
                                            -- A new baby record is being created.
                                            case deriveBabyRecordNew model of
                                                Just babyRecordNew ->
                                                    ProcessTypeMsg
                                                        (AddBabyType
                                                            (LaborDelIppMsg
                                                                -- Request top-level to provide data in
                                                                -- the dataCache once received from server.
                                                                (DataCache Nothing (Just [ Baby ]))
                                                            )
                                                            babyRecordNew
                                                        )
                                                        AddMsgType
                                                        (babyRecordNewToValue babyRecordNew)

                                                Nothing ->
                                                    Log ErrorSeverity "deriveBabyRecordNew returned a Nothing"
                            in
                            ( { model | babySummaryModal = NoViewEditState }
                            , Cmd.none
                            , Cmd.batch
                                [ Task.perform (always outerMsg) (Task.succeed True)
                                , Route.back
                                ]
                            )

                        errors ->
                            let
                                msgs =
                                    List.map Tuple.second errors
                                        |> flip (++) [ "Record was not saved." ]
                            in
                            ( { model | babySummaryModal = NoViewEditState }
                            , Cmd.none
                            , toastError msgs 10
                            )

        AddApgarWizard addOtherApgar ->
            case addOtherApgar of
                NotStartedAddOtherApgar ->
                    -- The user either has not done anything with the wizard or
                    -- else has pressed cancel part way through.
                    ( { model
                        | pendingApgarWizard = NotStartedAddOtherApgar
                        , pendingApgarMinute = Nothing
                        , pendingApgarScore = Nothing
                      }
                    , Cmd.none
                    , Cmd.none
                    )

                MinuteAddOtherApgar ->
                    -- User has started the wizard to add a custom apgar.
                    ( { model | pendingApgarWizard = MinuteAddOtherApgar }
                    , Cmd.none
                    , Cmd.none
                    )

                ScoreAddOtherApgar ->
                    -- User has already entered minute and needs to enter score.
                    ( { model | pendingApgarWizard = ScoreAddOtherApgar }
                    , Cmd.none
                    , Cmd.none
                    )

                FinishedAddOtherApgar ->
                    let
                        minute =
                            U.maybeStringToMaybeInt model.pendingApgarMinute

                        score =
                            U.maybeStringToMaybeInt model.pendingApgarScore

                        newApgarScores =
                            case ( minute, score ) of
                                ( Just min, Just scr ) ->
                                    Dict.insert min (ApgarScore minute score) model.apgarScores

                                ( _, _ ) ->
                                    model.apgarScores
                    in
                    ( { model
                        | pendingApgarWizard = NotStartedAddOtherApgar
                        , pendingApgarMinute = Nothing
                        , pendingApgarScore = Nothing
                        , apgarScores = newApgarScores
                      }
                    , Cmd.none
                    , Cmd.none
                    )

        DeleteApgar minute ->
            -- Used for the custom apgars, ignore any of the standard minutes
            -- of 1, 5, or 10.
            case minute of
                1 ->
                    ( model, Cmd.none, Cmd.none )

                5 ->
                    ( model, Cmd.none, Cmd.none )

                10 ->
                    ( model, Cmd.none, Cmd.none )

                min ->
                    ( { model
                        | apgarScores = Dict.remove min model.apgarScores
                      }
                    , Cmd.none
                    , Cmd.none
                    )

        ClearStage1DateTime ->
            ( { model
                | stage1Date = Nothing
                , stage1Time = Nothing
              }
            , Cmd.none
            , Cmd.none
            )

        ClearStage2DateTime ->
            ( { model
                | stage2Date = Nothing
                , stage2Time = Nothing
              }
            , Cmd.none
            , Cmd.none
            )

        ClearStage3DateTime ->
            ( { model
                | stage3Date = Nothing
                , stage3Time = Nothing
              }
            , Cmd.none
            , Cmd.none
            )

        LaborDetailsLoaded ->
            ( model, Cmd.none, logInfo "LaborDelIpp.update LaborDetailsLoaded" )

        ViewLaborRecord laborId ->
            ( { model
                | currLaborId = Just laborId
              }
            , Cmd.none
            , Cmd.none
            )


{-| Return whether the newDate and newTime evaluate to a datetime
equal or after the reference date passed.
-}
sanityCheckStageDateTimes : Maybe Date -> Maybe Date -> Maybe String -> Bool
sanityCheckStageDateTimes refDate newDate newTime =
    let
        newDatetime =
            U.maybeDateMaybeTimeToMaybeDateTime newDate
                newTime
                ""
    in
    case newDatetime of
        U.NoMaybeDateTime ->
            -- Clearing the date/time which is allowed.
            True

        U.InvalidMaybeDateTime _ ->
            -- Not valid proposed date/time.
            False

        U.ValidMaybeDateTime d ->
            case refDate of
                Just rd ->
                    U.datesInOrder rd d

                Nothing ->
                    -- We do not allow a date to follow our reference
                    -- date or be a date when our reference date is not.
                    False


{-| Derive a LaborStage1RecordNew from the form fields, if possible.
-}
deriveLaborStage1RecordNew : Model -> Maybe LaborStage1RecordNew
deriveLaborStage1RecordNew model =
    case model.currLaborId of
        Just (LaborId id) ->
            -- We have an admittance record, so we are allowed to have
            -- a stage one record too.
            let
                fullDialation =
                    case ( model.stage1Date, model.stage1Time ) of
                        ( Just d, Just t ) ->
                            case U.stringToTimeTuple t of
                                Just tt ->
                                    Just <| U.datePlusTimeTuple d tt

                                Nothing ->
                                    Nothing

                        ( _, _ ) ->
                            Nothing
            in
            LaborStage1RecordNew fullDialation
                model.s1Mobility
                (U.maybeHoursMaybeMinutesToMaybeMinutes
                    (U.maybeStringToMaybeInt model.s1DurationLatentHours)
                    (U.maybeStringToMaybeInt model.s1DurationLatentMinutes)
                )
                (U.maybeHoursMaybeMinutesToMaybeMinutes
                    (U.maybeStringToMaybeInt model.s1DurationActiveHours)
                    (U.maybeStringToMaybeInt model.s1DurationActiveMinutes)
                )
                model.s1Comments
                id
                |> Just

        _ ->
            Nothing


deriveLaborStage2RecordNew : Model -> Maybe LaborStage2RecordNew
deriveLaborStage2RecordNew model =
    case model.currLaborId of
        Just (LaborId id) ->
            let
                birthDatetime =
                    case ( model.stage2Date, model.stage2Time ) of
                        ( Just d, Just t ) ->
                            case U.stringToTimeTuple t of
                                Just tt ->
                                    Just <| U.datePlusTimeTuple d tt

                                Nothing ->
                                    Nothing

                        ( _, _ ) ->
                            Nothing
            in
            LaborStage2RecordNew birthDatetime
                model.s2BirthType
                model.s2BirthPosition
                (U.maybeStringToMaybeInt model.s2DurationPushing)
                model.s2BirthPresentation
                model.s2TerminalMec
                model.s2CordWrapType
                model.s2DeliveryType
                model.s2ShoulderDystocia
                (U.maybeStringToMaybeInt model.s2ShoulderDystociaMinutes)
                model.s2Laceration
                model.s2Episiotomy
                model.s2Repair
                model.s2Degree
                model.s2LacerationRepairedBy
                (U.maybeStringToMaybeInt model.s2BirthEBL)
                model.s2Meconium
                model.s2Comments
                id
                |> Just

        _ ->
            Nothing


deriveMembraneRecordNew : Model -> Maybe MembraneRecordNew
deriveMembraneRecordNew model =
    case model.currLaborId of
        Just (LaborId lid) ->
            let
                ruptureDatetime =
                    case ( model.membraneRuptureDate, model.membraneRuptureTime ) of
                        ( Just d, Just t ) ->
                            case U.stringToTimeTuple t of
                                Just tt ->
                                    Just <| U.datePlusTimeTuple d tt

                                Nothing ->
                                    Nothing

                        ( _, _ ) ->
                            Nothing
            in
            MembraneRecordNew ruptureDatetime
                (Data.Membrane.maybeStringToRupture model.membraneRupture)
                model.membraneRuptureComment
                (Data.Membrane.maybeStringToAmniotic model.membraneAmniotic)
                model.membraneAmnioticComment
                model.membraneComments
                lid
                |> Just

        Nothing ->
            Nothing


deriveBabyRecordNew : Model -> Maybe BabyRecordNew
deriveBabyRecordNew model =
    case ( model.currLaborId, model.bbSex ) of
        ( Just (LaborId id), Just sexStr ) ->
            let
                bFedDatetime =
                    case ( model.bbBFedEstablishedDate, model.bbBFedEstablishedTime ) of
                        ( Just d, Just t ) ->
                            case U.stringToTimeTuple t of
                                Just tt ->
                                    Just <| U.datePlusTimeTuple d tt

                                Nothing ->
                                    Nothing

                        ( _, _ ) ->
                            Nothing
            in
            BabyRecordNew 1
                model.bbLastname
                model.bbFirstname
                model.bbMiddlename
                (stringToSex sexStr)
                (U.maybeStringToMaybeInt model.bbBirthWeight)
                bFedDatetime
                model.bbBulb
                model.bbMachine
                model.bbFreeFlowO2
                model.bbChestCompressions
                model.bbPpv
                model.bbComments
                id
                (apgarScoreDictToApgarRecordList model.apgarScores)
                |> Just

        ( _, _ ) ->
            Nothing


deriveLaborStage3RecordNew : Model -> Maybe LaborStage3RecordNew
deriveLaborStage3RecordNew model =
    case model.currLaborId of
        Just (LaborId id) ->
            let
                placentaDatetime =
                    case ( model.stage3Date, model.stage3Time ) of
                        ( Just d, Just t ) ->
                            case U.stringToTimeTuple t of
                                Just tt ->
                                    Just <| U.datePlusTimeTuple d tt

                                Nothing ->
                                    Nothing

                        ( _, _ ) ->
                            Nothing
            in
            LaborStage3RecordNew placentaDatetime
                model.s3PlacentaDeliverySpontaneous
                model.s3PlacentaDeliveryAMTSL
                model.s3PlacentaDeliveryCCT
                model.s3PlacentaDeliveryManual
                model.s3MaternalPosition
                model.s3TxBloodLoss1
                model.s3TxBloodLoss2
                model.s3TxBloodLoss3
                model.s3TxBloodLoss4
                model.s3TxBloodLoss5
                model.s3PlacentaShape
                model.s3PlacentaInsertion
                (U.maybeStringToMaybeInt model.s3PlacentaNumVessels)
                (string2SchultzDuncan (Maybe.withDefault "" model.s3SchultzDuncan))
                model.s3Cotyledons
                model.s3Membranes
                model.s3Comments
                id
                |> Just

        _ ->
            Nothing



-- VALIDATION of the LaborDelIpp Model form fields, not the records sent to the server. --


type alias FieldError =
    ( Field, String )


validateAdmittance : Model -> List FieldError
validateAdmittance =
    Validate.all
        [ .admittanceDate >> ifInvalid (U.validateReasonableDate True) (AdmittanceDateFld => "Valid date of admittance must be provided.")
        , .admittanceTime >> ifInvalid U.validateTime (AdmittanceTimeFld => "Admitting time must be provided, ex: hhmm.")
        , .laborDate >> ifInvalid (U.validateReasonableDate True) (LaborDateFld => "Valid date of the start of labor must be provided.")
        , .laborTime >> ifInvalid U.validateTime (LaborTimeFld => "Start of labor time must be provided, ex: hhmm.")
        , .pos >> ifInvalid U.validatePopulatedString (PosFld => "POS must be provided.")
        , .fh >> ifInvalid U.validateInt (FhFld => "FH must be provided.")
        , .fht >> ifInvalid U.validateInt (FhtFld => "FHT must be provided.")
        , .systolic >> ifInvalid U.validateInt (SystolicFld => "Systolic must be provided.")
        , .diastolic >> ifInvalid U.validateInt (DiastolicFld => "Diastolic must be provided.")
        , .cr >> ifInvalid U.validateInt (CrFld => "CR must be provided.")
        , .temp >> ifInvalid U.validateFloat (TempFld => "Temp must be provided.")
        ]


validateStage1New : Model -> List FieldError
validateStage1New =
    Validate.all
        [ .stage1Time >> ifInvalid U.validateJustTime (Stage1TimeFld => "Time must be provided in hhmm format.")
        ]


validateStage1 : Model -> List FieldError
validateStage1 =
    Validate.all
        [ .s1Mobility >> ifInvalid U.validatePopulatedString (Stage1MobilityFld => "Mobility must be provided.")
        , .s1DurationLatentHours >> ifInvalid U.validatePopulatedString (Stage1DurationLatentHoursFld => "Duration latent must be provided.")
        , .s1DurationLatentMinutes >> ifInvalid U.validatePopulatedString (Stage1DurationLatentMinutesFld => "Duration latent must be provided.")
        , .s1DurationActiveHours >> ifInvalid U.validatePopulatedString (Stage1DurationActiveHoursFld => "Duration active must be provided.")
        , .s1DurationActiveMinutes >> ifInvalid U.validatePopulatedString (Stage1DurationActiveMinutesFld => "Duration active must be provided.")
        ]


{-| TODO: is this right?
-}
validateStage2New : Model -> List FieldError
validateStage2New =
    Validate.all
        [ .stage2Time >> ifInvalid U.validateJustTime (Stage2TimeFld => "Time must be provided in hhmm format.")
        ]


validateStage3New : Model -> List FieldError
validateStage3New =
    Validate.all
        [ .stage3Time >> ifInvalid U.validateJustTime (Stage3TimeFld => "Time must be provided in hhmm format.")
        ]


validateStage2 : Model -> List FieldError
validateStage2 =
    Validate.all
        [ .s2BirthType >> ifInvalid U.validatePopulatedString (Stage2BirthTypeFld => "Birth type must be provided.")
        , .s2BirthPosition >> ifInvalid U.validatePopulatedString (Stage2BirthPositionFld => "Birth position must be provided.")
        , .s2DurationPushing >> ifInvalid U.validateInt (Stage2DurationPushingFld => "Duration pushing must be provided.")
        , .s2BirthPresentation >> ifInvalid U.validatePopulatedString (Stage2BirthPresentationFld => "Birth presentation must be provided.")
        , .s2CordWrapType >> ifInvalid U.validatePopulatedString (Stage2CordWrapTypeFld => "Cord wrap type must be provided.")
        , .s2DeliveryType >> ifInvalid U.validatePopulatedString (Stage2DeliveryTypeFld => "Delivery type must be provided.")
        , \mdl ->
            case U.maybeStringToMaybeInt mdl.s2ShoulderDystociaMinutes of
                Just m ->
                    if m > 0 && (mdl.s2ShoulderDystocia == Nothing || mdl.s2ShoulderDystocia == Just False) then
                        [ Stage2ShoulderDystociaMinutesFld => "Shoulder dystocia minutes cannot be specified if shoulder dystocia is not checked." ]
                    else
                        []

                Nothing ->
                    if mdl.s2ShoulderDystocia == Just True then
                        [ Stage2ShoulderDystociaMinutesFld => "Shoulder dystocia cannot be checked without specifying shoulder dystocia minutes." ]
                    else
                        []
        , \mdl ->
            if mdl.s2Laceration == Just True || mdl.s2Episiotomy == Just True then
                if mdl.s2Degree == Nothing then
                    [ Stage2DegreeFld => "Degree must be specified if laceration or episiotomy is checked." ]
                else
                    []
            else if mdl.s2Degree /= Nothing then
                [ Stage2DegreeFld => "Either laceration and/or episiotomy must be checked if degree is specified." ]
            else
                []
        , \mdl ->
            if mdl.s2Repair == Just True && String.length (Maybe.withDefault "" mdl.s2LacerationRepairedBy) == 0 then
                [ Stage2LacerationRepairedByFld => "Laceration repaired by field must be provided if repair field is checked." ]
            else
                []
        , .s2BirthEBL >> ifInvalid U.validateInt (Stage2BirthEBLFld => "Estimated blood loss at birth must be provided.")
        , .s2Meconium >> ifInvalid U.validatePopulatedString (Stage2MeconiumFld => "Meconium must be provided.")
        ]


validateStage3 : Model -> List FieldError
validateStage3 =
    Validate.all
        [ \mdl ->
            -- All four bools are not Nothing and not all False.
            if
                (U.validateBool mdl.s3PlacentaDeliverySpontaneous
                    && U.validateBool mdl.s3PlacentaDeliveryAMTSL
                    && U.validateBool mdl.s3PlacentaDeliveryCCT
                    && U.validateBool mdl.s3PlacentaDeliveryManual
                )
                    || ((not <| Maybe.withDefault False mdl.s3PlacentaDeliverySpontaneous)
                            && (not <| Maybe.withDefault False mdl.s3PlacentaDeliveryAMTSL)
                            && (not <| Maybe.withDefault False mdl.s3PlacentaDeliveryCCT)
                            && (not <| Maybe.withDefault False mdl.s3PlacentaDeliveryManual)
                       )
            then
                [ Stage3PlacentaDeliverySpontaneousFld => "You must check one of the placenta delivery types." ]
            else
                []
        , .s3MaternalPosition >> ifInvalid U.validatePopulatedString (Stage3MaternalPositionFld => "Maternal position must be provided.")
        , .s3PlacentaShape >> ifInvalid U.validatePopulatedString (Stage3PlacentaShapeFld => "Placenta shape must be provided.")
        , .s3PlacentaInsertion >> ifInvalid U.validatePopulatedString (Stage3PlacentaInsertionFld => "Placenta insertion must be provided.")
        , .s3PlacentaNumVessels >> ifInvalid U.validateInt (Stage3PlacentaNumVesselsFld => "Number of vessels must be provided.")
        , .s3SchultzDuncan >> ifInvalid U.validatePopulatedString (Stage3SchultzDuncanFld => "Schultz or Duncan presentation must be provided.")
        , .s3Cotyledons >> ifInvalid U.validatePopulatedString (Stage3CotyledonsFld => "Cotyledons must be specified.")
        , .s3Membranes >> ifInvalid U.validatePopulatedString (Stage3MembranesFld => "Membranes must be specified.")
        ]


{-| We need only sex for a valid record. All other fields might not be
able to be provided until later.
-}
validateBaby : Model -> List FieldError
validateBaby =
    Validate.all
        [ .bbSex >> ifInvalid (U.validatePopulatedStringInList [ "Male", "Female", "Ambiguous" ]) (BabySexFld => "Sex must be provided.")
        , .bbBFedEstablishedDate >> ifInvalid (U.validateReasonableDate False) (BabyBFedEstablishedDateFld => "Valid baby bfed date must be provided.")
        ]


validateMembrane : Model -> List FieldError
validateMembrane =
    Validate.all
        [ .membraneRupture >> ifInvalid U.validatePopulatedString (MembraneRuptureFld => "Rupture type must be provided.")
        , .membraneAmniotic >> ifInvalid U.validatePopulatedString (MembraneAmnioticFld => "Amniotic type must be provided.")
        , .membraneRuptureDate >> ifInvalid (U.validateReasonableDate False) (MembraneRuptureDateFld => "Valid membrane rupture date must be provided.")
        ]
