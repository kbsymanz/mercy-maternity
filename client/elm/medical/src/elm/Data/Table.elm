module Data.Table
    exposing
        ( Table(..)
        , decodeTable
        , stringToTable
        , tableToString
        , tableToValue
        )

import Json.Decode as JD
import Json.Encode as JE


type Table
    = Unknown
    | Baby
    | BabyLab
    | BabyLabType
    | BabyMedication
    | BabyMedicationType
    | BabyVaccination
    | BabyVaccinationType
    | BirthCertificate
    | ContPostpartumCheck
    | Discharge
    | KeyValue
    | Labor
    | LaborStage1
    | LaborStage2
    | LaborStage3
    | Membrane
    | MotherMedication
    | MotherMedicationType
    | NewbornExam
    | Patient
    | PostpartumCheck
    | Pregnancy
    | Role
    | SelectData
    | User



-- HELPERS --


tableToValue : Table -> JE.Value
tableToValue table =
    JE.string <| tableToString table


tableToString : Table -> String
tableToString tbl =
    case tbl of
        Unknown ->
            "unknown"

        Baby ->
            "baby"

        BabyLab ->
            "babyLab"

        BabyLabType ->
            "babyLabType"

        BabyMedication ->
            "babyMedication"

        BabyMedicationType ->
            "babyMedicationType"

        BabyVaccination ->
            "babyVaccination"

        BabyVaccinationType ->
            "babyVaccinationType"

        BirthCertificate ->
            "birthCertificate"

        ContPostpartumCheck ->
            "contPostpartumCheck"

        Discharge ->
            "discharge"

        KeyValue ->
            "keyValue"

        Labor ->
            "labor"

        LaborStage1 ->
            "laborStage1"

        LaborStage2 ->
            "laborStage2"

        LaborStage3 ->
            "laborStage3"

        Membrane ->
            "membrane"

        MotherMedication ->
            "motherMedication"

        MotherMedicationType ->
            "motherMedicationType"

        NewbornExam ->
            "newbornExam"

        Patient ->
            "patient"

        PostpartumCheck ->
            "postpartumCheck"

        Pregnancy ->
            "pregnancy"

        Role ->
            "role"

        SelectData ->
            "selectData"

        User ->
            "user"


stringToTable : String -> Table
stringToTable tbl =
    case tbl of
        "baby" ->
            Baby

        "babyLab" ->
            BabyLab

        "babyLabType" ->
            BabyLabType

        "babyMedication" ->
            BabyMedication

        "babyMedicationType" ->
            BabyMedicationType

        "babyVaccination" ->
            BabyVaccination

        "babyVaccinationType" ->
            BabyVaccinationType

        "birthCertificate" ->
            BirthCertificate

        "contPostpartumCheck" ->
            ContPostpartumCheck

        "discharge" ->
            Discharge

        "keyValue" ->
            KeyValue

        "labor" ->
            Labor

        "laborStage1" ->
            LaborStage1

        "laborStage2" ->
            LaborStage2

        "laborStage3" ->
            LaborStage3

        "membrane" ->
            Membrane

        "motherMedication" ->
            MotherMedication

        "motherMedicationType" ->
            MotherMedicationType

        "newbornExam" ->
            NewbornExam

        "patient" ->
            Patient

        "postpartumCheck" ->
            PostpartumCheck

        "pregnancy" ->
            Pregnancy

        "role" ->
            Role

        "selectData" ->
            SelectData

        "user" ->
            User

        _ ->
            Unknown


decodeTable : JD.Decoder Table
decodeTable =
    JD.string |> JD.map stringToTable
