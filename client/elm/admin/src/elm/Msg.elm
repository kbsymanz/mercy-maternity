module Msg
    exposing
        ( Msg(..)
        , AdhocResponseMessage(..)
        , KeyValueMsg(..)
        , LabSuiteMsg(..)
        , LabTestMsg(..)
        , LabTestValueMsg(..)
        , MedicationTypeMsg(..)
        , RoleMsg(..)
        , SelectDataMsg(..)
        , UserMsg(..)
        , UserProfileMsg(..)
        , VaccinationTypeMsg(..)
        )

import Form exposing (Form)
import Material
import Material.Snackbar as Snackbar
import Navigation exposing (Location)
import RemoteData as RD exposing (RemoteData(..))


-- LOCAL IMPORTS

import Model exposing (..)
import Types exposing (..)


type Msg
    = AddChgDelNotificationMessages (Maybe AddChgDelNotification)
    | AddSelectedTable
    | AdhocResponseMessages AdhocResponseMessage
    | CancelSelectedTable
    | CreateResponseMsg (Maybe CreateResponse)
    | DeleteRecord Table Int
    | DeleteResponseMsg (Maybe DeleteResponse)
    | EditSelectedTable
    | EventTypeResponse (RemoteData String (List EventTypeRecord))
    | FirstRecord
    | KeyValueMessages KeyValueMsg
    | LabSuiteMessages LabSuiteMsg
    | LabTestMessages LabTestMsg
    | LabTestValueMessages LabTestValueMsg
    | LastRecord
    | Login
    | LoginFormMsg Form.Msg
    | Mdl (Material.Msg Msg)
    | MedicationTypeMessages MedicationTypeMsg
    | NewSystemMessage SystemMessageType
    | NextRecord
    | NewSystemMode SystemMode
    | NoOp
    | PregnoteTypeResponse (RemoteData String (List PregnoteTypeRecord))
    | PreviousRecord
    | RequestUserProfile
    | RiskCodeResponse (RemoteData String (List RiskCodeRecord))
    | RoleMessages RoleMsg
    | SaveSelectedTable
    | SelectDataMessages SelectDataMsg
    | SelectedTableEditMode EditMode (Maybe Int)
    | SelectQueryMsg (List SelectQuery)
    | SelectQueryResponseMsg (RemoteData String SelectQueryResponse)
    | SelectQuerySelectTable Table (List SelectQuery)
    | SelectTableRecord Int
    | SelectPage Page
    | SessionExpired
    | Snackbar (Snackbar.Msg String)
    | UpdateResponseMsg (Maybe UpdateResponse)
    | UrlChange Location
    | UserChoiceSet String String
    | UserChoiceUnset String
    | UserMessages UserMsg
    | UserProfileMessages UserProfileMsg
    | VaccinationTypeMessages VaccinationTypeMsg
    | VaccinationTypeResponse (RemoteData String (List VaccinationTypeRecord))


type KeyValueMsg
    = CancelEditKeyValue
    | FormMsgKeyValue Form.Msg
    | ReadResponseKeyValue (RemoteData String (List KeyValueRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeKeyValue EditMode (Maybe Int)
    | SelectedRecordKeyValue (Maybe Int)
    | UpdateKeyValue
    | UpdateResponseKeyValue UpdateResponse

type MedicationTypeMsg
    = CancelEditMedicationType
    | CreateMedicationType
    | CreateResponseMedicationType CreateResponse
    | DeleteMedicationType (Maybe Int)
    | DeleteResponseMedicationType DeleteResponse
    | FirstMedicationType
    | FormMsgMedicationType Form.Msg
    | LastMedicationType
    | NextMedicationType
    | PrevMedicationType
    | ReadResponseMedicationType (RemoteData String (List MedicationTypeRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeMedicationType EditMode (Maybe Int)
    | SelectedRecordMedicationType (Maybe Int)
    | UpdateMedicationType
    | UpdateResponseMedicationType UpdateResponse


type SelectDataMsg
    = CancelEditSelectData
    | CreateSelectData
    | CreateResponseSelectData CreateResponse
    | DeleteSelectData (Maybe Int)
    | DeleteResponseSelectData DeleteResponse
    | FormMsgSelectData Form.Msg
    | ReadResponseSelectData (RemoteData String (List SelectDataRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeSelectData EditMode (Maybe Int) (Maybe String)
    | SelectedRecordSelectData (Maybe Int)
    | UpdateSelectData
    | UpdateResponseSelectData UpdateResponse

type LabSuiteMsg
    = CancelEditLabSuite
    | CreateLabSuite
    | CreateResponseLabSuite CreateResponse
    | DeleteLabSuite (Maybe Int)
    | DeleteResponseLabSuite DeleteResponse
    | FormMsgLabSuite Form.Msg
    | ReadResponseLabSuite (RemoteData String (List LabSuiteRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeLabSuite EditMode (Maybe Int)
    | UpdateLabSuite
    | UpdateResponseLabSuite UpdateResponse

type LabTestMsg
    = CancelEditLabTest
    | CreateLabTest
    | CreateResponseLabTest CreateResponse
    | DeleteLabTest (Maybe Int)
    | DeleteResponseLabTest DeleteResponse
    | FormMsgLabTest Form.Msg
    | ReadResponseLabTest (RemoteData String (List LabTestRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeLabTest EditMode (Maybe Int)
    | UpdateLabTest
    | UpdateResponseLabTest UpdateResponse

type LabTestValueMsg
    = CancelEditLabTestValue
    | CreateLabTestValue
    | CreateResponseLabTestValue CreateResponse
    | DeleteLabTestValue (Maybe Int)
    | DeleteResponseLabTestValue DeleteResponse
    | FormMsgLabTestValue Form.Msg
    | ReadResponseLabTestValue (RemoteData String (List LabTestValueRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeLabTestValue EditMode (Maybe Int)
    | UpdateLabTestValue
    | UpdateResponseLabTestValue UpdateResponse

type VaccinationTypeMsg
    = CancelEditVaccinationType
    | CreateVaccinationType
    | CreateResponseVaccinationType CreateResponse
    | DeleteVaccinationType (Maybe Int)
    | DeleteResponseVaccinationType DeleteResponse
    | FirstVaccinationType
    | FormMsgVaccinationType Form.Msg
    | LastVaccinationType
    | NextVaccinationType
    | PrevVaccinationType
    | ReadResponseVaccinationType (RemoteData String (List VaccinationTypeRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeVaccinationType EditMode (Maybe Int)
    | SelectedRecordVaccinationType (Maybe Int)
    | UpdateVaccinationType
    | UpdateResponseVaccinationType UpdateResponse


type AdhocResponseMessage
    = AdhocUnknownMsg String
    | AdhocLoginResponseMsg AuthResponse
    | AdhocUserProfileResponseMsg AuthResponse
    | AdhocUserProfileUpdateResponseMsg AdhocResponse


type RoleMsg
    = ReadResponseRole (RemoteData String (List RoleRecord)) (Maybe SelectQuery)


type UserProfileMsg
    = FormMsgUserProfile Form.Msg
    | UpdateUserProfile


type UserMsg
    = CancelEditUser
    | CreateResponseUser CreateResponse
    | CreateUser
    | CreateUserForm
    | DeleteResponseUser DeleteResponse
    | DeleteUser (Maybe Int)
    | FirstUser
    | FormMsgUser Form.Msg
    | FormMsgUserSearch Form.Msg
    | LastUser
    | NextUser
    | PrevUser
    | ReadResponseUser (RemoteData String (List UserRecord)) (Maybe SelectQuery)
    | SelectedRecordEditModeUser EditMode (Maybe Int)
    | UpdateResponseUser UpdateResponse
    | UpdateUser
