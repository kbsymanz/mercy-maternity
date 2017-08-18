module Data.TableRecord
    exposing
        ( TableRecord(..)
        , tableRecord
        )

import Json.Decode as JD
import Json.Decode.Pipeline as JDP


-- LOCAL IMPORTS --

import Data.Patient exposing (PatientRecord, patientRecord)
import Data.Pregnancy exposing (PregnancyRecord, pregnancyRecord)
import Data.Table as DT exposing (Table(..))


type TableRecord
    = TableRecordPatient (List PatientRecord)
    | TableRecordPregnancy (List PregnancyRecord)


tableRecord : Table -> JD.Decoder TableRecord
tableRecord table =
    case table of
        Patient ->
            JD.map TableRecordPatient (JD.list patientRecord)

        Pregnancy ->
            JD.map TableRecordPregnancy (JD.list pregnancyRecord)

        _ ->
            JD.fail <| "Cannot yet handle table of " ++ (DT.tableToString table) ++ " in Data.TableRecord.tableRecord."