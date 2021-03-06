{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
module Plexams.Types.SemesterConfig
    ( -- * Config
      SemesterConfig(..)
    , AvailableRoom(..)
    , AvailableRooms
    ) where

import           Control.Applicative         (empty, (<$>), (<*>))
import           Data.Aeson                  (ToJSON, defaultOptions,
                                              genericToEncoding)
import           Data.List                   (elemIndex)
import qualified Data.Map                    as M
import           Data.Maybe                  (fromMaybe)
import           Data.Text                   (Text)
import           Data.Time.Calendar
import           Data.Time.Calendar.WeekDate (toWeekDate)
import           Data.Time.Format            (defaultTimeLocale, parseTimeM)
import qualified Data.Yaml                   as Y
import           GHC.Generics
import           Plexams.Types.Common

data SemesterConfig = SemesterConfig
    { semester        :: Text     -- ^ Semester
    , firstDay        :: Day      -- ^ Erster Tag des Prüfungszeitraumes, z.B. @fromGregorian 2017 7 10@
    , lastDay         :: Day      -- ^ Letzter Tag  des Prüfungszeitraumes, z.B. @fromGregorian 2017 7 21@
    , examDays        :: [Day]    -- ^ vom ersten bis letzten Tag OHNE Wochenende
    , goSlots         :: [(Int, Int)]
    , slotsPerDay     :: [String] -- ^ Liste von Slots als Zeitstrings in der Form @HH:MM@. Ein Slot ist IMMER 120 Minuten lang
    , initialPlanFile :: FilePath -- ^ Datei in der die Prüfungen für das Semester vom ZPA stehen
    , personsFile     :: FilePath -- ^ Datei in der die Personen für das Semester vom ZPA stehen
    , planManipFile   :: FilePath
    , availableRooms  :: [AvailableRoom]
    , fk10Exams       :: [[Integer]]
    }
  deriving (Eq, Show, Generic)

instance Y.FromJSON SemesterConfig where
    parseJSON (Y.Object v) = makeSemesterConfig
                        <$> v Y..: "semester"
                        <*> v Y..: "firstDay"
                        <*> v Y..: "lastDay"
                        <*> v Y..: "goDay0"
                        <*> v Y..: "slotsPerDay"
                        <*> v Y..: "initialPlan"
                        <*> v Y..: "persons"
                        <*> v Y..: "planManip"
                        <*> v Y..: "rooms"
                        <*> v Y..: "notPlannedByMe"
    parseJSON _          = empty

instance ToJSON SemesterConfig where
    toEncoding = genericToEncoding defaultOptions

makeSemesterConfig :: Text -> String -> String -> String -> [String]
                   -> FilePath -> FilePath -> FilePath
                   -> [AvailableRoom] -> [[Integer]]
                   -> SemesterConfig
makeSemesterConfig s f l goDay0 =
        SemesterConfig s firstDay' lastDay' realExamDays goSlots'
    where makeDay :: String -> Day
          makeDay str = fromMaybe (error $ "cannot parse date: " ++ str)
             (parseTimeM True defaultTimeLocale "%d.%m.%Y" str)
          firstDay' = makeDay f
          lastDay' = makeDay l
          realExamDays = filter (notWeekend . toWeekDate) [firstDay'..lastDay']
          notWeekend (_,_,weekday) = weekday <= 5
          goDay0Index = fromMaybe 0 $ elemIndex (makeDay goDay0) realExamDays
          goSlots' = map (\(d,t) -> (d+goDay0Index, t)) rawGOSlots
          rawGOSlots =  [ (0,0), (0,1) -- Tag 0
                        , (1,3), (1,4), (1,5)
                        , (2,0), (2,1)
                        , (3,3), (3,4), (3,5)
                        , (4,0), (4,1)
                        , (5,3), (5,4), (5,5)
                        , (6,0), (6,1)
                        , (9,3), (9,4), (9,5)
                        ]

data AvailableRoom = AvailableRoom
    { availableRoomName     :: String
    , availableRoomMaxSeats :: Integer
    , availableRoomHandicap :: Bool
    }
  deriving (Eq, Show, Generic)

instance Y.FromJSON AvailableRoom where
    parseJSON (Y.Object v) = AvailableRoom
                       <$> v Y..: "name"
                       <*> v Y..: "seats"
                       <*> v Y..:? "handicap" Y..!= False
    parseJSON _            = empty

instance ToJSON AvailableRoom where
    toEncoding = genericToEncoding defaultOptions

type AvailableRooms = M.Map (DayIndex, SlotIndex)
                            -- ( Normale Räume (absteigend sortiert nach Größe)
                            -- , Handicap Räume)
                            ([AvailableRoom], [AvailableRoom])
