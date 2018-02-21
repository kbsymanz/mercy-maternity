module Data.DataCache
    exposing
        ( DataCache(..)
        , del
        , get
        , put
        )

import Dict exposing (Dict)


-- LOCAL IMPORTS --

import Data.Baby exposing (BabyRecord)
import Data.BabyMedication exposing (BabyMedicationRecord)
import Data.BabyMedicationType exposing (BabyMedicationTypeRecord)
import Data.ContPostpartumCheck exposing (ContPostpartumCheckRecord)
import Data.Labor exposing (LaborRecord)
import Data.LaborStage1 exposing (LaborStage1Record)
import Data.LaborStage2 exposing (LaborStage2Record)
import Data.LaborStage3 exposing (LaborStage3Record)
import Data.Membrane exposing (MembraneRecord)
import Data.NewbornExam exposing (NewbornExamRecord)
import Data.Patient exposing (PatientRecord)
import Data.Pregnancy exposing (PregnancyRecord)
import Data.SelectData exposing (SelectDataRecord)
import Data.Table exposing (stringToTable, tableToString, Table(..))


{-| Cache for heterogeneous data.
-}
type DataCache
    = BabyDataCache BabyRecord
    | BabyMedicationDataCache (List BabyMedicationRecord)
    | BabyMedicationTypeDataCache (List BabyMedicationTypeRecord)
    | ContPostpartumCheckDataCache (List ContPostpartumCheckRecord)
    | LaborDataCache (Dict Int LaborRecord)
    | LaborStage1DataCache LaborStage1Record
    | LaborStage2DataCache LaborStage2Record
    | LaborStage3DataCache LaborStage3Record
    | MembraneDataCache MembraneRecord
    | NewbornExamDataCache NewbornExamRecord
    | PatientDataCache PatientRecord
    | PregnancyDataCache PregnancyRecord
    | SelectDataDataCache (List SelectDataRecord)


{-| Return the Table name as a String that cooresponds to
the DataCache instance passed. This is used to generate
a consistent key for put.
-}
getTableString : DataCache -> String
getTableString dc =
    case dc of
        BabyDataCache _ ->
            tableToString Baby

        BabyMedicationDataCache _ ->
            tableToString BabyMedication

        BabyMedicationTypeDataCache _ ->
            tableToString BabyMedicationType

        ContPostpartumCheckDataCache _ ->
            tableToString ContPostpartumCheck

        LaborDataCache _ ->
            tableToString Labor

        LaborStage1DataCache _ ->
            tableToString LaborStage1

        LaborStage2DataCache _ ->
            tableToString LaborStage2

        LaborStage3DataCache _ ->
            tableToString LaborStage3

        MembraneDataCache _ ->
            tableToString Membrane

        NewbornExamDataCache _ ->
            tableToString NewbornExam

        PatientDataCache _ ->
            tableToString Patient

        PregnancyDataCache _ ->
            tableToString Pregnancy

        SelectDataDataCache _ ->
            tableToString SelectData


put : DataCache -> Dict String DataCache -> Dict String DataCache
put dc dict =
    Dict.insert (getTableString dc) dc dict


get : Table -> Dict String DataCache -> Maybe DataCache
get tbl dict =
    Dict.get (tableToString tbl) dict


del : Table -> Dict String DataCache -> Dict String DataCache
del tbl dict =
    Dict.remove (tableToString tbl) dict
