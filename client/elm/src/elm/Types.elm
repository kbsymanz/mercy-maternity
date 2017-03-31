module Types
    exposing
        ( adminPages
        , AuthResponse
        , CreateResponse
        , DeleteResponse
        , EditMode(..)
        , emptySystemMessage
        , ErrorCode(..)
        , EventTypeRecord
        , LabSuiteRecord
        , LabTestRecord
        , LabTestValueRecord
        , LoginForm
        , MedicationTypeForm
        , MedicationTypeRecord
        , notFoundPageDef
        , Page(..)
        , PageDef
        , PregnoteTypeRecord
        , RiskCodeRecord
        , RoleRecord
        , SelectQuery
        , SelectQueryResponse
        , SystemMessage
        , Tab(..)
        , Table(..)
        , TableMetaInfo
        , TableModel
        , TableResponse(..)
        , UpdateResponse
        , UserRecord
        , VaccinationTypeRecord
        )

import Dict exposing (Dict)
import Form exposing (Form)
import List.Extra as LE
import RemoteData as RD exposing (RemoteData(..))


type Table
    = Unknown
    | CustomField
    | CustomFieldType
    | Event
    | EventType
    | HealthTeaching
    | LabSuite
    | LabTest
    | LabTestResult
    | LabTestValue
    | Medication
    | MedicationType
    | Patient
    | Pregnancy
    | PregnancyHistory
    | Pregnote
    | PregnoteType
    | PrenatalExam
    | Priority
    | Risk
    | RiskCode
    | Referral
    | RoFieldsByRole
    | Role
    | Schedule
    | SelectData
    | User
    | Vaccination
    | VaccinationType


{-| Pages
-}
type Page
    = PageDefNotFoundPage
    | PageNotFoundPage
    | AdminHomePage
    | AdminTablesPage
    | AdminUsersPage
    | ProfilePage
    | ProfileNotLoadedPage


{-| Provides the definition of each Page including the url of the
page, as well as the optional tab and List of tabs for the page.

Note: when using hashes, location needs to be something other than
the empty String or "#".
-}
type alias PageDef =
    { page : Page
    , tab : Maybe Int
    , tabs : Maybe (List ( String, Page ))
    , location : String
    }


{-| This is the PageDef returns by getPageDef whenever the sought
after PageDef is not found in the List of PageDefs that is not Nothing.
-}
notFoundPageDef : PageDef
notFoundPageDef =
    PageDef PageDefNotFoundPage Nothing Nothing "#pagedefnotfound"


{-| List PageDef for the administrator role.
-}
adminPages : List PageDef
adminPages =
    [ PageDef AdminHomePage (Just 0) (Just adminTabs) "#home"
    , PageDef AdminTablesPage (Just 2) (Just adminTabs) "#lookuptables"
    , PageDef AdminUsersPage (Just 1) (Just adminTabs) "#users"
    , PageDef ProfilePage Nothing (Just adminTabs) "#profile"
    ]


adminTabs : List ( String, Page )
adminTabs =
    [ ( "Home", AdminHomePage )
    , ( "Users", AdminUsersPage )
    , ( "Lookup Tables", AdminTablesPage )
    ]


{-| TODO: Get rid of this so that everything is in Page somehow.
-}
type Tab
    = HomeTab
    | UserTab
    | TablesTab
    | ProfileTab


{-| is this used?
-}
type AdhocOperation
    = Login


type alias TableModel a b =
    { records : RemoteData String (List a)
    , form : Form () b
    , selectedRecordId : Maybe Int
    , editMode : EditMode
    , nextPendingId : Int
    , selectQuery : Maybe SelectQuery
    }


type EditMode
    = EditModeAdd
    | EditModeEdit
    | EditModeView
    | EditModeTable


type TableResponse
    = LabSuiteResp (List LabSuiteRecord)
    | LabTestResp (List LabTestRecord)
    | MedicationTypeResp (List MedicationTypeRecord)


type ErrorCode
    = NoErrorCode
    | UnknownErrorCode
    | SessionExpiredErrorCode
    | SqlErrorCode
    | LoginSuccessErrorCode
    | LoginFailErrorCode
    | UserProfileSuccessErrorCode
    | UserProfileFailErrorCode


type alias SelectQuery =
    { table : Table
    , id : Maybe Int
    , patient_id : Maybe Int
    , pregnancy_id : Maybe Int
    }


type alias SelectQueryResponse =
    { table : Table
    , id : Maybe Int
    , patient_id : Maybe Int
    , pregnancy_id : Maybe Int
    , success : Bool
    , errorCode : ErrorCode
    , msg : String
    , data : TableResponse
    }


type alias SystemMessage =
    { id : String
    , msgType : String
    , updatedAt : Int
    , workerId : String
    , processedBy : List String
    , systemLog : String
    }


{-| Used when there is an error decoding from JS.
-}
emptySystemMessage : SystemMessage
emptySystemMessage =
    { id = "ERROR"
    , msgType = ""
    , updatedAt = 0
    , workerId = ""
    , processedBy = []
    , systemLog = ""
    }


type alias TableMetaInfo =
    { table : Table
    , name : String
    , desc : String
    }


type alias UserRecord =
    { id : Int
    , username : String
    , firstname : String
    , lastname : String
    , password : String
    , email : String
    , lang : String
    , shortName : String
    , displayName : String
    , status : Bool
    , note : String
    , isCurrentTeacher : Bool
    , roleId : Int
    }


type alias RoleRecord =
    { id : Int
    , name : String
    , description : String
    }


type alias EventTypeRecord =
    { id : Int
    , name : String
    , description : String
    }


type alias LabSuiteRecord =
    { id : Int
    , name : String
    , description : String
    , category : String
    }


type alias LabTestRecord =
    { id : Int
    , name : String
    , abbrev : String
    , normal : String
    , unit : String
    , minRangeDecimal : Float
    , maxRangeDecimal : Float
    , minRangeInteger : Int
    , maxRangeInteger : Int
    , isRange : Bool
    , isText : Bool
    , labSuite_id : Int
    }


type alias LabTestValueRecord =
    { id : Int
    , value : String
    , labTest_id : Int
    }


type alias LoginForm =
    { username : String
    , password : String
    }


type alias MedicationTypeRecord =
    { id : Int
    , name : String
    , description : String
    , sortOrder : Int
    , stateId : Maybe Int
    }


type alias MedicationTypeForm =
    { id : Int
    , name : String
    , description : String
    , sortOrder : Int
    }


type alias PregnoteTypeRecord =
    { id : Int
    , name : String
    , description : String
    }


type alias RiskCodeRecord =
    { id : Int
    , name : String
    , riskType : String
    , description : String
    }


type alias VaccinationTypeRecord =
    { id : Int
    , name : String
    , description : String
    , sortOrder : Int
    }


type alias AuthResponse =
    { adhocType : String
    , success : Bool
    , errorCode : ErrorCode
    , msg : String
    , userId : Maybe Int
    , username : Maybe String
    , firstname : Maybe String
    , lastname : Maybe String
    , email : Maybe String
    , lang : Maybe String
    , shortName : Maybe String
    , displayName : Maybe String
    , role_id : Maybe Int
    , roleName : Maybe String
    , isLoggedIn : Bool
    }


type alias UpdateResponse =
    { id : Int
    , table : Table
    , stateId : Int
    , success : Bool
    , errorCode : ErrorCode
    , msg : String
    }


type alias CreateResponse =
    { id : Int
    , table : Table
    , pendingId : Int
    , success : Bool
    , errorCode : ErrorCode
    , msg : String
    }


type alias DeleteResponse =
    { id : Int
    , table : Table
    , stateId : Int
    , success : Bool
    , errorCode : ErrorCode
    , msg : String
    }
