SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetBookingByDay                                */
/* Creation Date: 19-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Booking Module                                              */
/*                                                                      */
/* Called By: Booking Day View                                          */
/*                                                                      */
/* PVCS Version: 1.10                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 13-JUN-2012  YTWan    1.0  SOS#244706:Marks booking slots with color */
/*                            (Wan01)                                   */
/* 25-SEP-2013  NJOW01   1.1  288373-Fix color slot unable to add new   */
/* 27-SEP-2013  NJOW02   1.2  288364-Dynamic bay column by screen size  */
/* 06-NOV-2013  NJOW03   1.3  294384-Booking Reference on Inbound       */
/*                            Booking View By Day if empty container#   */
/* 31-OCT-2014  YTWan    1.2  SOS#322304 - PH - CPPI WMS Door Booking   */
/*                            Enhancement (Wan02)                       */
/* 19-JAN-2017  Wan03    1.3  WMS-917 - WMS Door Booking Enhancement -  */
/*                            Add ToLoc                                 */
/* 22-Mar-2017  TLTING   1.4  Force commit tran                         */
/* 08-Aug-2018  NJOW04   1.5  Fix - inbound no data update              */
/* 18-Feb-2022  Wan04    1.6  Fix - open Begin tran                     */
/* 18-Feb-2022  Wan04    1.6  DevOps Combine Script                     */
/* 09-MAR-2022  Wan05    1.7  LFWM-3336 - Door Booking SPsDB queries    */
/*                            clarification                             */
/* 16-NOV-2022  Wan06    1.8  WMS-21173-[PH] - Colgate-Palmolive Inbound*/
/*                            Doorbooking EndTime                       */
/* 31-01-2023   Wan07-v0 1.9  LFWM-3899 - SCE RG Inbound Door booking   */
/* 02-JUL-2024  Inv Team 1.10 UWP-17135 - Migrate Inbound Door booking  */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_GetBookingByDay]
   @d_Date        DATETIME,
   @n_Interval    INT = 30, 
   @c_Door1       NVARCHAR(10) = '',
   @c_Door2       NVARCHAR(10) = '',
   @c_Door3       NVARCHAR(10) = '',
   @c_Door4       NVARCHAR(10) = '',
   @c_Door5       NVARCHAR(10) = '',
   @c_Door6       NVARCHAR(10) = '', --NJOW02
   @c_Door7       NVARCHAR(10) = '',
   @c_Door8       NVARCHAR(10) = '',
   @c_Door9       NVARCHAR(10) = '',
   @c_Door10      NVARCHAR(10) = '',
   @c_Facility    NVARCHAR(5)  = '',
   @c_InOut       CHAR(1)      = 'I',
   @c_CallSource  NVARCHAR(20) = ''      
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE @nWeekNo      INT,  
           @dStartDate   DATETIME,  
           @dEndDate     DATETIME,  
           @dCurrDate    DATETIME,
           @cfrTime      VARCHAR(10),
           @ctoTime      VARCHAR(10),
           @n_starttcnt  INT

   SET @n_starttcnt=@@TRANCOUNT
           
   DECLARE @t_Day TABLE (  
      BookingTimefr        VARCHAR(10),  
      BookingTimeto        VARCHAR(10),  
      Bay1_Tag             NVARCHAR(100),
      Bay1_Status          CHAR(1),
      Bay1_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay1_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay1_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)
      Bay1_Data            NVARCHAR(50),
      Bay1_Type            NVARCHAR(10),
      Bay2_Tag             NVARCHAR(100),
      Bay2_Status          CHAR(1),  
      Bay2_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay2_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay2_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)
      Bay2_Data            NVARCHAR(50),
      Bay2_Type            NVARCHAR(10),
      Bay3_Tag             NVARCHAR(100),
      Bay3_Status          CHAR(1),  
      Bay3_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay3_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay3_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)      
      Bay3_Data            NVARCHAR(50),
      Bay3_Type            NVARCHAR(10),
      Bay4_Tag             NVARCHAR(100),
      Bay4_Status          CHAR(1),  
      Bay4_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay4_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay4_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)     
      Bay4_Data            NVARCHAR(50),
      Bay4_Type            NVARCHAR(10),
      Bay5_Tag             NVARCHAR(100),
      Bay5_Status          CHAR(1),   
      Bay5_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)  
      Bay5_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay5_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)     
      Bay5_Data            NVARCHAR(50),
      Bay5_Type            NVARCHAR(10),
      Bay6_Tag             NVARCHAR(100), --NJOW02
      Bay6_Status          CHAR(1),
      Bay6_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay6_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay6_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)    
      Bay6_Data            NVARCHAR(50),
      Bay6_Type            NVARCHAR(10),
      Bay7_Tag             NVARCHAR(100),
      Bay7_Status          CHAR(1),  
      Bay7_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay7_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay7_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)   
      Bay7_Data            NVARCHAR(50),
      Bay7_Type            NVARCHAR(10),
      Bay8_Tag             NVARCHAR(100),
      Bay8_Status          CHAR(1),  
      Bay8_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay8_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay8_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)       
      Bay8_Data            NVARCHAR(50),
      Bay8_Type            NVARCHAR(10),
      Bay9_Tag             NVARCHAR(100),
      Bay9_Status          CHAR(1),  
      Bay9_BKStatus        CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay9_Blockslotkey    NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay9_BlockSlotDescr  NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)      
      Bay9_Data            NVARCHAR(50),
      Bay9_Type            NVARCHAR(10),
      Bay10_Tag            NVARCHAR(100),
      Bay10_Status         CHAR(1),   
      Bay10_BKStatus       CHAR(1)  NOT NULL DEFAULT(''),               --(Wan05)
      Bay10_Blockslotkey   NVARCHAR(10)  NOT NULL DEFAULT(''),          --(Wan05)
      Bay10_BlockSlotDescr NVARCHAR(100) NOT NULL DEFAULT(''),          --(Wan05)                                                                      --       
      Bay10_Data           NVARCHAR(50),
      Bay10_Type           NVARCHAR(10)
      )  
               
   SET @dStartDate = CONVERT(datetime, CONVERT(varchar(12), @d_Date, 112))  
   SET @dEndDate = CONVERT(varchar(12), @d_Date, 112) + ' 23:59:59:998'
   
   CREATE TABLE #TMP_BOOKING (
       rowid         INT IDENTITY (1,1) not null,
       bkdata        NVARCHAR(50) null,
       loc           NVARCHAR(10) null,
       toLoc         NVARCHAR(10) null,         --(Wan03) 
       loc2          NVARCHAR(10) null,         --(Wan02)       
       timefrom      VARCHAR(10) null,
       timeto        VARCHAR(10) null,
       type          NVARCHAR(10) null,
       containerno   NVARCHAR(30) null,
       statusdesc    NVARCHAR(60) null,
       status        CHAR(1) NULL
      ,BKStatus      CHAR(1) NOT NULL DEFAULT('')              --(Wan05)
      )       
       
   CREATE TABLE #TMP_BLOCKSLOT_OUTPUT (
       Loc NVARCHAR(10) NULL,
       TimeFrom Varchar(10) NULL,
       TimeTo Varchar(10) NULL
      ,Color      NVARCHAR(5) NULL      --(Wan01)       
      ,ColorOnly  VARCHAR(1) NULL      --(Wan01)
      ,Blockslotkey  NVARCHAR(10)      --(Wan05)
      ,Descr         NVARCHAR(100)     --(Wan05)
      )
   
   IF @c_inout IN ( 'I', 'A' )                                                --(Wan07-v0) - START
   BEGIN
      INSERT INTO #TMP_BOOKING (bkdata, loc, timefrom, timeto, type, containerno, statusdesc, STATUS, BKStatus)               --(Wan05)
      SELECT CAST(BI.BookingNo AS char(10)) + BI.Loc + BI.Status AS BKData, BI.Loc,
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BI.BookingDate)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BI.BookingDate)), 2)  AS timefrom,
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BI.EndTime)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BI.EndTime)), 2)  AS timeto,
             'IN', CASE WHEN ISNULL(BI.containerno,'')='' THEN BI.Referenceno ELSE BI.containerno END,  --NJOW03
             CL.Description, 
             CASE WHEN CL.Short = 'GREY' THEN '0'
                  WHEN CL.Short IN('CYAN','BLUE') THEN '1'
                  WHEN CL.Short = 'GREEN' THEN '2'
                  WHEN CL.Short = 'YELLOW' THEN '3'
                  WHEN CL.Short IN ('PINK','RED','PURPLE') THEN '4'
                ELSE '' END
         ,  BI.[Status]                                                                                                       --(Wan05)
      FROM BOOKING_IN BI (NOLOCK)
      LEFT JOIN CODELKUP CL (NOLOCK) ON BI.Status = CL.code AND CL.Listname = 'BkStatusI'     
      WHERE (BI.BookingDate BETWEEN @dStartDate AND @dEndDate OR              --(Wan06)
             BI.EndTime BETWEEN @dStartDate AND @dEndDate )                   --(Wan06)
      AND BI.Loc IN (@c_Door1, @c_Door2, @c_Door3, @c_Door4, @c_Door5, @c_Door6, @c_Door7, @c_Door8, @c_Door9, @c_Door10)     --(Wan07-v0)
      AND BI.Facility = @c_Facility
      ORDER BY BI.Loc, BI.bookingdate
   END 
   
   IF @c_inout IN ( 'I' )
   BEGIN
      INSERT INTO #TMP_BOOKING (bkdata, loc, toloc, loc2, timefrom, timeto, type, containerno, statusdesc, STATUS, BKStatus)   --(Wan02) Add loc2, (Wan03) Add toloc --(Wan05)
      SELECT CAST(BO.BookingNo AS char(10)) + BO.Loc + BO.Status AS BKData
            , BO.Loc,CASE WHEN ISNULL(RTRIM(BO.ToLoc),'') = '' THEN BO.Loc ELSE BO.ToLoc END    --(Wan03)
            , BO.Loc2,                                                                          --(Wan02) Add loc2
             --(Wan02) - START
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BO.BookingDate)), 2) + ':' + 
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BO.BookingDate)), 2)  AS timefrom,
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BO.EndTime)), 2) + ':' + 
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BO.EndTime)), 2)  AS timeto,
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, BO.Bookingdate,@dStartDate) = 1 THEN '00' ELSE DATEPART(hour, BO.BookingDate) END ), 2)  + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, BO.Bookingdate,@dStartDate) = 1 THEN '00' ELSE DATEPART(minute, BO.BookingDate) END), 2)  AS timefrom,
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, @dStartDate, BO.Endtime) = 1 THEN '23' ELSE DATEPART(hour, BO.EndTime)  END ), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, @dStartDate, BO.Endtime) = 1 THEN '59' ELSE DATEPART(minute, BO.EndTime) END), 2)  AS timeto,
             --(Wan02) - END             
             'OUT', CASE WHEN ISNULL(BO.vehiclecontainer,'')='' THEN BO.ALTReference ELSE BO.vehiclecontainer END,  --NJOW03   
             CL.Description,
             CASE WHEN CL.Short = 'GREY' THEN '0'
                  WHEN CL.Short IN('CYAN','BLUE') THEN '1'
                  WHEN CL.Short = 'GREEN' THEN '2'
                  WHEN CL.Short = 'YELLOW' THEN '3'
                  WHEN CL.Short IN ('PINK','RED','PURPLE') THEN '4'
                ELSE '' END
            ,BO.[Status]                                                                                                      --(Wan05)
      FROM BOOKING_OUT BO (NOLOCK)
      LEFT JOIN CODELKUP CL (NOLOCK) ON BO.Status = CL.code AND CL.Listname = 'BkStatusO'     
      JOIN LOC (NOLOCK) ON BO.Loc = LOC.Loc        --(Wan07-v0)
      WHERE --(Wan02) - START
            --BO.BookingDate BETWEEN @dStartDate AND @dEndDate
           ( BO.BookingDate BETWEEN @dStartDate AND @dEndDate OR 
             BO.EndTime BETWEEN @dStartDate AND @dEndDate ) 
            --(Wan02) - END 
      AND BO.Facility = @c_Facility 
      --(Wan03) - START
      AND EXISTS (SELECT 1
                  FROM dbo.Fnc_GetBookingDoor(BO.Facility, BO.Loc, BO.ToLoc, BO.Loc2, @c_InOut) DOOR
                  WHERE DOOR.Loc IN (@c_Door1, @c_Door2, @c_Door3, @c_Door4, @c_Door5, @c_Door6, @c_Door7, @c_Door8, @c_Door9, @c_Door10)
                  )   
      --AND BO.Loc IN (@c_Door1, @c_Door2, @c_Door3, @c_Door4, @c_Door5, @c_Door6, @c_Door7, @c_Door8, @c_Door9, @c_Door10)
      AND LOC.LocationCategory = 'BAY'             --(Wan07-v0)
      --(Wan03) - END  
      ORDER BY BO.Loc, BO.bookingdate
   END
   --ELSE
   IF @c_inout IN ( 'O', 'A' )
   BEGIN
      INSERT INTO #TMP_BOOKING (bkdata, loc, toloc, loc2, timefrom, timeto, type, containerno, statusdesc, STATUS, BKStatus)       --(Wan02) Add loc2, --(Wan03) Add toloc --Wan05
      SELECT CAST(BO.BookingNo AS char(10)) + BO.Loc + BO.Status AS BKData   
            , BO.Loc 
            , CASE WHEN ISNULL(RTRIM(BO.ToLoc),'') = '' THEN BO.Loc ELSE BO.ToLoc END           --(Wan03)
            , BO.Loc2,                                                                          --(Wan02) Add loc2
             --(Wan02) - START
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BO.BookingDate)), 2) + ':' + 
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BO.BookingDate)), 2)  AS timefrom,
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BO.EndTime)), 2) + ':' + 
             --RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BO.EndTime)), 2)  AS timeto,
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, BO.Bookingdate,@dStartDate) = 1 THEN '00' ELSE DATEPART(hour, BO.BookingDate) END ), 2)  + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, BO.Bookingdate,@dStartDate) = 1 THEN '00' ELSE DATEPART(minute, BO.BookingDate) END), 2)  AS timefrom,
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, @dStartDate, BO.Endtime) = 1 THEN '23' ELSE DATEPART(hour, BO.EndTime)  END ), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, CASE WHEN DATEDIFF(day, @dStartDate, BO.Endtime) = 1 THEN '59' ELSE DATEPART(minute, BO.EndTime) END), 2)  AS timeto,
             --(Wan02) - END             
             'OUT', CASE WHEN ISNULL(BO.vehiclecontainer,'')='' THEN BO.ALTReference ELSE BO.vehiclecontainer END,  --NJOW03   
             CL.Description,
             CASE WHEN CL.Short = 'GREY' THEN '0'
                  WHEN CL.Short IN('CYAN','BLUE') THEN '1'
                  WHEN CL.Short = 'GREEN' THEN '2'
                  WHEN CL.Short = 'YELLOW' THEN '3'
                  WHEN CL.Short IN ('PINK','RED','PURPLE') THEN '4'
                ELSE '' END
            , BO.[Status]                                                                                                      --(Wan05)
      FROM BOOKING_OUT BO (NOLOCK)
      LEFT JOIN CODELKUP CL (NOLOCK) ON BO.Status = CL.code AND CL.Listname = 'BkStatusO'     
      WHERE --(Wan02) - START
            --BO.BookingDate BETWEEN @dStartDate AND @dEndDate
            ( BO.BookingDate BETWEEN @dStartDate AND @dEndDate OR 
              BO.EndTime BETWEEN @dStartDate AND @dEndDate ) 
            --(Wan02) - END 
      --(Wan03) - START
      AND EXISTS (SELECT 1
                  FROM dbo.Fnc_GetBookingDoor(BO.Facility, BO.Loc, BO.ToLoc, BO.Loc2, @c_InOut) DOOR
                  WHERE DOOR.Loc IN (@c_Door1, @c_Door2, @c_Door3, @c_Door4, @c_Door5, @c_Door6, @c_Door7, @c_Door8, @c_Door9, @c_Door10)
                  )   
      --AND Loc IN (@c_Door1, @c_Door2, @c_Door3, @c_Door4, @c_Door5, @c_Door6, @c_Door7, @c_Door8, @c_Door9, @c_Door10) -- (Wan02) add door5 to door10
      --(Wan03) - END  
      AND BO.Facility = @c_Facility 
      ORDER BY BO.Loc, BO.bookingdate
   END
   
   IF @c_inout IN ( 'O' )
   BEGIN
      INSERT INTO #TMP_BOOKING (bkdata, loc, timefrom, timeto, type, containerno, statusdesc, status, BKStatus)               --(Wan05)
      SELECT CAST(BI.BookingNo AS char(10)) + BI.Loc + BI.Status AS BKData, BI.Loc,
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BI.BookingDate)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BI.BookingDate)), 2)  AS timefrom,
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BI.EndTime)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BI.EndTime)), 2)  AS timeto,
             'IN', CASE WHEN ISNULL(BI.containerno,'')='' THEN BI.Referenceno ELSE BI.containerno END,  --NJOW03 
             CL.Description,      
             CASE WHEN CL.Short = 'GREY' THEN '0'
                  WHEN CL.Short IN('CYAN','BLUE') THEN '1'
                  WHEN CL.Short = 'GREEN' THEN '2'
                  WHEN CL.Short = 'YELLOW' THEN '3'
                  WHEN CL.Short IN ('PINK','RED','PURPLE') THEN '4'
                ELSE '' END
           , BI.[Status]                                                                                                      --(Wan05)
      FROM BOOKING_IN BI (NOLOCK)     
      LEFT JOIN CODELKUP CL (NOLOCK) ON BI.Status = CL.code AND CL.Listname = 'BkStatusI'     
      JOIN LOC (NOLOCK) ON BI.Loc = LOC.Loc
      WHERE (BI.BookingDate BETWEEN @dStartDate AND @dEndDate OR              --(Wan06)
             BI.EndTime BETWEEN @dStartDate AND @dEndDate)                    --(Wan06)
      AND BI.Loc IN (@c_Door1, @c_Door2, @c_Door3, @c_Door4, @c_Door5, @c_Door6, @c_Door7, @c_Door8, @c_Door9, @c_Door10) -- (Wan02) add door5 to door10
      AND BI.Facility = @c_Facility
      AND LOC.LocationCategory = 'BAY'
      ORDER BY BI.Loc, BI.bookingdate
   END                                                                        --(Wan07-v0) - END

   /*SELECT *, CAST(rowid % 5 AS char(1)) AS Status
   INTO #TMP_BOOKING2 
   FROM #TMP_BOOKING*/
               
   SET @dCurrDate = @dStartDate  
   --WHILE @dCurrDate <= @dEndDate  
   WHILE @dCurrDate <= @dEndDate  
   BEGIN  
      SET @cfrTime = RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, @dCurrDate)), 2) + ':' + 
                   RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, @dCurrDate)), 2)  

      SET @dCurrDate = DATEADD(minute, @n_Interval, @dCurrDate)

      SET @ctoTime = RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, @dCurrDate)), 2) + ':' + 
                   RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, @dCurrDate)), 2)
      IF @ctoTime = '00:00'
         SET @ctoTime = '23:59'  
                   
      INSERT INTO @t_Day (BookingTimeFr, BookingTimeTo, Bay1_Tag, Bay1_Status, Bay1_Data, 
                          Bay2_Tag, Bay2_Status, Bay2_Data, Bay3_Tag, Bay3_Status, Bay3_Data,
                          Bay4_Tag, Bay4_Status, Bay4_Data, Bay5_Tag, Bay5_Status, Bay5_Data,
                          Bay1_Type, Bay2_Type, Bay3_Type, Bay4_Type, Bay5_Type,
                          Bay6_Tag, Bay6_Status, Bay6_Data, 
                          Bay7_Tag, Bay7_Status, Bay7_Data, Bay8_Tag, Bay8_Status, Bay8_Data,
                          Bay9_Tag, Bay9_Status, Bay9_Data, Bay10_Tag, Bay10_Status, Bay10_Data,
                          Bay6_Type, Bay7_Type, Bay8_Type, Bay9_Type, Bay10_Type)
      VALUES (@cfrTime, @ctoTime, '','','','','','','','','','','','','','','','','','','','',
              '','','','','','','','','','','','','','','','','','','','')                            
   END  
      
   /*UPDATE @t_Day
   SET Bay1_Tag = CASE WHEN BK.Loc = @c_Door1 THEN RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ELSE '' END,
       Bay1_Data = CASE WHEN BK.Loc = @c_Door1 THEN BKData ELSE '' END,
       Bay1_Status = CASE WHEN BK.Loc = @c_Door1 THEN Status ELSE '' END,
       Bay2_Tag = CASE WHEN BK.Loc = @c_Door2 THEN RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ELSE '' END,
       Bay2_Data = CASE WHEN BK.Loc = @c_Door2 THEN BKData ELSE '' END,
       Bay2_Status = CASE WHEN BK.Loc = @c_Door2 THEN Status ELSE '' END,
       Bay3_Tag = CASE WHEN BK.Loc = @c_Door3 THEN RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ELSE '' END,
       Bay3_Data = CASE WHEN BK.Loc = @c_Door3 THEN BKData ELSE '' END,
       Bay3_Status = CASE WHEN BK.Loc = @c_Door3 THEN Status ELSE '' END,
       Bay4_Tag = CASE WHEN BK.Loc = @c_Door4 THEN RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ELSE '' END,
       Bay4_Data = CASE WHEN BK.Loc = @c_Door4 THEN BKData ELSE '' END,
       Bay4_Status = CASE WHEN BK.Loc = @c_Door4 THEN Status ELSE '' END,
       Bay5_Tag = CASE WHEN BK.Loc = @c_Door5 THEN RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ELSE '' END,
       Bay5_Data = CASE WHEN BK.Loc = @c_Door5 THEN BKData ELSE '' END,
       Bay5_Status = CASE WHEN BK.Loc = @c_Door5 THEN Status ELSE '' END
   FROM @t_Day DY, #TMP_BOOKING2 BK
   WHERE (DY.BookingTimeFr >= BK.TimeFrom AND  DY.BookingTimeFr < BK.TimeTo)
   OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo)*/
   
   EXEC isp_GetBookingBlockSlot @c_Facility, @d_Date, @c_InOut, '', 'N'

   IF ISNULL(@c_Door1,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay1_Tag = '',
          Bay1_Data = '',
          Bay1_Status = BLK.Color,
          Bay1_Type = 'C'
        , Bay1_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay1_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.Loc = @c_Door1  
      AND BLK.ColorOnly = 'Y'
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay1_Tag = 'XXX-BLOCKED-XXX',
          Bay1_Data = '',
          Bay1_Status = BLK.Color,     --(Wan01)
          Bay1_Type = 'X'
        , Bay1_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay1_BlockSlotDescr = BLK.Descr                               --(Wan05) 
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door1         
   
      UPDATE @t_Day
      SET Bay1_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay1_Data = BKData,
          Bay1_Status = Status,
          Bay1_BKStatus = BKStatus,                                     --(Wan05)
          Bay1_Type = TYPE
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door1 AND BK.ToLoc >= @c_Door1) OR BK.Loc2 = @c_Door1 OR (Type = 'IN' AND BK.Loc = @c_Door1)) --(Wan02) --(Wan03) --NJOW04
   END

   IF ISNULL(@c_Door2,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay2_Tag = '',
          Bay2_Data = '',
          Bay2_Status = BLK.Color,
          Bay2_Type = 'C'
        , Bay2_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay2_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y' 
      AND BLK.Loc = @c_Door2
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay2_Tag = 'XXX-BLOCKED-XXX',
          Bay2_Data = '',
          Bay2_Status = BLK.Color,     --(Wan01)
          Bay2_Type = 'X'
        , Bay2_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay2_BlockSlotDescr = BLK.Descr                               --(Wan05)          
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door2         

      UPDATE @t_Day
      SET Bay2_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay2_Data = BKData,
          Bay2_Status = Status,
          Bay2_BKStatus = BKStatus,                                     --(Wan05)
          Bay2_Type = TYPE
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door2 AND BK.ToLoc >= @c_Door2) OR BK.Loc2 = @c_Door2 OR (Type = 'IN' AND BK.Loc = @c_Door2)) --(Wan02) --(Wan03) --NJOW04
   END

   IF ISNULL(@c_Door3,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay3_Tag = '',
          Bay3_Data = '',
          Bay3_Status = BLK.Color,
          Bay3_Type = 'C'
        , Bay3_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay3_BlockSlotDescr = BLK.Descr                               --(Wan05)          
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y' 
      AND BLK.Loc = @c_Door3
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay3_Tag = 'XXX-BLOCKED-XXX',
          Bay3_Data = '',
          Bay3_Status = BLK.Color,     --(Wan01)
          Bay3_Type = 'X'
        , Bay3_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay3_BlockSlotDescr = BLK.Descr                               --(Wan05)
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door3
      
      UPDATE @t_Day
      SET Bay3_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay3_Data = BKData,
          Bay3_Status = Status,
          Bay3_BKStatus = BKStatus,                                     --(Wan05)
          Bay3_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door3 AND BK.ToLoc >= @c_Door3) OR BK.Loc2 = @c_Door3 OR (Type = 'IN' AND BK.Loc = @c_Door3)) --(Wan02) --(Wan03) --NJOW04
   END

   IF ISNULL(@c_Door4,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay4_Tag = '',
          Bay4_Data = '',
          Bay4_Status = BLK.Color,
          Bay4_Type = 'C'
        , Bay4_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay4_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y' 
      AND BLK.Loc = @c_Door4 
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay4_Tag = 'XXX-BLOCKED-XXX',
          Bay4_Data = '',
          Bay4_Status = BLK.Color,     --(Wan01)
          Bay4_Type = 'X'
        , Bay4_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay4_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door4         

      UPDATE @t_Day
      SET Bay4_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay4_Data = BKData,
          Bay4_Status = Status,
          Bay4_BKStatus = BKStatus,                                     --(Wan05)
          Bay4_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door4 AND BK.ToLoc >= @c_Door4) OR BK.Loc2 = @c_Door4 OR (Type = 'IN' AND BK.Loc = @c_Door4)) --(Wan02) --(Wan03) --NJOW04
   END

   IF ISNULL(@c_Door5,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay5_Tag = '',
          Bay5_Data = '',
          Bay5_Status = BLK.Color,
          Bay5_Type = 'C'
        , Bay5_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay5_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y'           
      AND BLK.Loc = @c_Door5
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay5_Tag = 'XXX-BLOCKED-XXX',
          Bay5_Data = '',
          Bay5_Status = BLK.Color,     --(Wan01)
          Bay5_Type = 'X'
        , Bay5_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay5_BlockSlotDescr = BLK.Descr                               --(Wan05)             
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door5

      UPDATE @t_Day
      SET Bay5_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay5_Data = BKData,
          Bay5_Status = Status,
          Bay5_BKStatus = BKStatus,                                     --(Wan05)
          Bay5_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door5 AND BK.ToLoc >= @c_Door5) OR BK.Loc2 = @c_Door5 OR (Type = 'IN' AND BK.Loc = @c_Door5)) --(Wan02) --(Wan03) --NJOW04
   END 

   IF ISNULL(@c_Door6,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay6_Tag = '',
          Bay6_Data = '',
          Bay6_Status = BLK.Color,
          Bay6_Type = 'C'
        , Bay6_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay6_BlockSlotDescr = BLK.Descr                               --(Wan05)             
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y'           
      AND BLK.Loc = @c_Door6
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay6_Tag = 'XXX-BLOCKED-XXX',
          Bay6_Data = '',
          Bay6_Status = BLK.Color,     --(Wan01)
          Bay6_Type = 'X'
        , Bay6_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay6_BlockSlotDescr = BLK.Descr                               --(Wan05)             
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door6

      UPDATE @t_Day
      SET Bay6_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay6_Data = BKData,
          Bay6_Status = Status,
          Bay6_BKStatus = BKStatus,                                     --(Wan05)
          Bay6_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door6 AND BK.ToLoc >= @c_Door6) OR BK.Loc2 = @c_Door6 OR (Type = 'IN' AND BK.Loc = @c_Door6)) --(Wan02) --(Wan03) --NJOW04
   END 

   IF ISNULL(@c_Door7,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay7_Tag = '',
          Bay7_Data = '',
          Bay7_Status = BLK.Color,
          Bay7_Type = 'C'
        , Bay7_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay7_BlockSlotDescr = BLK.Descr                               --(Wan05)             
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y'           
      AND BLK.Loc = @c_Door7
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay7_Tag = 'XXX-BLOCKED-XXX',
          Bay7_Data = '',
          Bay7_Status = BLK.Color,     --(Wan01)
          Bay7_Type = 'X'
        , Bay7_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay7_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door7

      UPDATE @t_Day
      SET Bay7_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay7_Data = BKData,
          Bay7_Status = Status,
          Bay7_BKStatus = BKStatus,                                     --(Wan05)
          Bay7_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door7 AND BK.ToLoc >= @c_Door7) OR BK.Loc2 = @c_Door7 OR (Type = 'IN' AND BK.Loc = @c_Door7)) --(Wan02) --(Wan03) --NJOW04
   END 

   IF ISNULL(@c_Door8,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay8_Tag = '',
          Bay8_Data = '',
          Bay8_Status = BLK.Color,
          Bay8_Type = 'C'
        , Bay8_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay8_BlockSlotDescr = BLK.Descr                               --(Wan05)           
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y'           
      AND BLK.Loc = @c_Door8
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay8_Tag = 'XXX-BLOCKED-XXX',
          Bay8_Data = '',
          Bay8_Status = BLK.Color,     --(Wan01)
          Bay8_Type = 'X'
        , Bay8_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay8_BlockSlotDescr = BLK.Descr                               --(Wan05)               
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door8

      UPDATE @t_Day
      SET Bay8_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay8_Data = BKData,
          Bay8_Status = Status,
          Bay8_BKStatus = BKStatus,                                     --(Wan05)
          Bay8_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door8 AND BK.ToLoc >= @c_Door8) OR BK.Loc2 = @c_Door8 OR (Type = 'IN' AND BK.Loc = @c_Door8)) --(Wan02) --(Wan03) --NJOW04
   END 

   IF ISNULL(@c_Door9,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay9_Tag = '',
          Bay9_Data = '',
          Bay9_Status = BLK.Color,
          Bay9_Type = 'C'
        , Bay9_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay9_BlockSlotDescr = BLK.Descr                               --(Wan05)               
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y'           
      AND BLK.Loc = @c_Door9
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay9_Tag = 'XXX-BLOCKED-XXX',
          Bay9_Data = '',
          Bay9_Status = BLK.Color,     --(Wan01)
          Bay9_Type = 'X'
        , Bay9_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay9_BlockSlotDescr = BLK.Descr                               --(Wan05)            
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door9

      UPDATE @t_Day
      SET Bay9_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay9_Data = BKData,
          Bay9_Status = Status,
          Bay9_BKStatus = BKStatus,                                     --(Wan05)
          Bay9_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door9 AND BK.ToLoc >= @c_Door9) OR BK.Loc2 = @c_Door9 OR (Type = 'IN' AND BK.Loc = @c_Door9)) --(Wan02) --(Wan03) --NJOW04
   END 

   IF ISNULL(@c_Door10,'') <> ''
   BEGIN
      --(Wan01) - START
      UPDATE @t_Day
      SET Bay10_Tag = '',
          Bay10_Data = '',
          Bay10_Status = BLK.Color,
          Bay10_Type = 'C'
        , Bay10_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay10_BlockSlotDescr = BLK.Descr                               --(Wan05)            
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'Y'           
      AND BLK.Loc = @c_Door10
      --(Wan01) - END

      UPDATE @t_Day
      SET Bay10_Tag = 'XXX-BLOCKED-XXX',
          Bay10_Data = '',
          Bay10_Status = BLK.Color,     --(Wan01)
          Bay10_Type = 'X'
        , Bay10_Blockslotkey   = BLK.Blockslotkey                        --(Wan05)
        , Bay10_BlockSlotDescr = BLK.Descr                               --(Wan05)             
      FROM @t_Day DY, #TMP_BLOCKSLOT_OUTPUT BLK
      WHERE ((DY.BookingTimeFr >= BLK.TimeFrom AND DY.BookingTimeFr < BLK.TimeTo)
             OR (BLK.TimeFrom >= DY.BookingTimeFr AND BLK.TimeFrom < DY.BookingTimeTo))
      AND BLK.ColorOnly = 'N'          --(Wan01)
      AND BLK.Loc = @c_Door10

      UPDATE @t_Day
      SET Bay10_Tag = RTRIM(ISNULL(containerno,'')) + ' (' + RTRIM(LEFT(type,1))+ ') - ' + RTRIM(ISNULL(statusdesc,'')) ,  --RTRIM(BK.TimeFrom) + ' - ' + BK.TimeTo ,
          Bay10_Data = BKData,
          Bay10_Status = Status,
          Bay10_BKStatus = BKStatus,             --(Wan05)
          Bay10_Type = Type
      FROM @t_Day DY, #TMP_BOOKING BK
      WHERE ((DY.BookingTimeFr >= BK.TimeFrom AND DY.BookingTimeFr < BK.TimeTo)
             OR (BK.TimeFrom >= DY.BookingTimeFr AND BK.TimeFrom < DY.BookingTimeTo))
      AND ((BK.Loc <= @c_Door10 AND BK.ToLoc >= @c_Door10) OR BK.Loc2 = @c_Door10 OR (Type = 'IN' AND BK.Loc = @c_Door10)) --(Wan02) --(Wan03) --NJOW04
   END 
  
   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY1
   FROM @t_Day 
   WHERE Bay1_Tag <> '' 
   AND Bay1_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay1_Status <> 'X'
   GROUP BY Bay1_Tag, Bay1_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY2
   FROM @t_Day
   WHERE Bay2_Tag <> ''
   AND Bay2_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay2_Status <> 'X'
   GROUP BY Bay2_Tag, Bay2_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY3
   FROM @t_Day
   WHERE Bay3_Tag <> ''
   AND Bay3_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay3_Status <> 'X'
   GROUP BY Bay3_Tag, Bay3_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY4
   FROM @t_Day
   WHERE Bay4_Tag <> ''
   AND Bay4_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay4_Status <> 'X'
   GROUP BY Bay4_Tag, Bay4_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY5
   FROM @t_Day
   WHERE Bay5_Tag <> ''
   AND Bay5_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay5_Status <> 'X'
   GROUP BY Bay5_Tag, Bay5_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY6
   FROM @t_Day
   WHERE Bay6_Tag <> ''
   AND Bay6_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay6_Status <> 'X'
   GROUP BY Bay6_Tag, Bay6_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY7
   FROM @t_Day
   WHERE Bay7_Tag <> ''
   AND Bay7_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay7_Status <> 'X'
   GROUP BY Bay7_Tag, Bay7_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY8
   FROM @t_Day
   WHERE Bay8_Tag <> ''
   AND Bay8_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay8_Status <> 'X'
   GROUP BY Bay8_Tag, Bay8_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY9
   FROM @t_Day
   WHERE Bay9_Tag <> ''
   AND Bay9_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay9_Status <> 'X'
   GROUP BY Bay9_Tag, Bay9_Data

   SELECT MIN(BookingTimeFr) AS BookingTimeFrFirst, MAX(BookingTimeFr) AS BookingTimeFrLast, Count(1) AS Slots
   INTO #BAY10
   FROM @t_Day
   WHERE Bay10_Tag <> ''
   AND Bay10_Tag <> 'XXX-BLOCKED-XXX'   --(Wan01)
   AND Bay10_Status <> 'X'
   GROUP BY Bay10_Tag, Bay10_Data
   
   UPDATE @t_Day
   SET TD.Bay1_Tag = CASE WHEN #BAY1.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY1.BookingTimeFrLast AND #BAY1.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay1_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY1 ON (TD.BookingTimeFr = #BAY1.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY1.BookingTimeFrLast)
   JOIN #BAY1 BAY1B ON (TD.BookingTimeFr >= BAY1B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY1B.BookingTimeFrLast)

   --10-JAN-2012 YTWan- Fixed: Rename TD.Bay1_Tag to TD.Bay2_Tag
   UPDATE @t_Day
   SET TD.Bay2_Tag = CASE WHEN #BAY2.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY2.BookingTimeFrLast AND #BAY2.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay2_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY2 ON (TD.BookingTimeFr = #BAY2.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY2.BookingTimeFrLast)
   JOIN #BAY2 BAY2B ON (TD.BookingTimeFr >= BAY2B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY2B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay3_Tag = CASE WHEN #BAY3.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY3.BookingTimeFrLast AND #BAY3.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay3_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY3 ON (TD.BookingTimeFr = #BAY3.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY3.BookingTimeFrLast)
   JOIN #BAY3 BAY3B ON (TD.BookingTimeFr >= BAY3B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY3B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay4_Tag = CASE WHEN #BAY4.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY4.BookingTimeFrLast AND #BAY4.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay4_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY4 ON (TD.BookingTimeFr = #BAY4.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY4.BookingTimeFrLast)
   JOIN #BAY4 BAY4B ON (TD.BookingTimeFr >= BAY4B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY4B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay5_Tag = CASE WHEN #BAY5.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY5.BookingTimeFrLast AND #BAY5.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay5_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY5 ON (TD.BookingTimeFr = #BAY5.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY5.BookingTimeFrLast)
   JOIN #BAY5 BAY5B ON (TD.BookingTimeFr >= BAY5B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY5B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay6_Tag = CASE WHEN #BAY6.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY6.BookingTimeFrLast AND #BAY6.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay6_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY6 ON (TD.BookingTimeFr = #BAY6.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY6.BookingTimeFrLast)
   JOIN #BAY6 BAY6B ON (TD.BookingTimeFr >= BAY6B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY6B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay7_Tag = CASE WHEN #BAY7.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY7.BookingTimeFrLast AND #BAY7.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay7_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY7 ON (TD.BookingTimeFr = #BAY7.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY7.BookingTimeFrLast)
   JOIN #BAY7 BAY7B ON (TD.BookingTimeFr >= BAY7B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY7B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay8_Tag = CASE WHEN #BAY8.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY8.BookingTimeFrLast AND #BAY8.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay8_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY8 ON (TD.BookingTimeFr = #BAY8.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY8.BookingTimeFrLast)
   JOIN #BAY8 BAY8B ON (TD.BookingTimeFr >= BAY8B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY8B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay9_Tag = CASE WHEN #BAY9.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY9.BookingTimeFrLast AND #BAY9.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay9_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY9 ON (TD.BookingTimeFr = #BAY9.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY9.BookingTimeFrLast)
   JOIN #BAY9 BAY9B ON (TD.BookingTimeFr >= BAY9B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY9B.BookingTimeFrLast)

   UPDATE @t_Day
   SET TD.Bay10_Tag = CASE WHEN #BAY10.BookingTimeFrFirst IS NULL THEN SPACE(6)+'||'
                          WHEN TD.BookingTimeFr = #BAY10.BookingTimeFrLast AND #BAY10.Slots > 1 THEN SPACE(6)+'\/'+SPACE(6)+ REPLICATE('  .  ',13)
                          ELSE TD.Bay10_Tag END                      
   FROM @t_Day TD LEFT JOIN #BAY10 ON (TD.BookingTimeFr = #BAY10.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY10.BookingTimeFrLast)
   JOIN #BAY10 BAY10B ON (TD.BookingTimeFr >= BAY10B.BookingTimeFrFirst AND TD.BookingTimeFr <= BAY10B.BookingTimeFrLast)

/*
   UPDATE @t_Day
   SET Bay1_Tag = ''
   FROM @t_Day TD LEFT JOIN #BAY1 ON (TD.BookingTimeFr = #BAY1.BookingTimeFrFirst OR TD.BookingTimeFr = #BAY1.BookingTimeFrLast)
   WHERE #BAY1.BookingTimeFrFirst IS NULL
 */  
   --(Wan05) - START
   IF @c_CallSource = ''
   BEGIN
      SELECT  BookingTimefr  
            , BookingTimeto  
            , Bay1_Tag       
            , Bay1_Status    
            , Bay1_Data      
            , Bay1_Type      
            , Bay2_Tag       
            , Bay2_Status    
            , Bay2_Data      
            , Bay2_Type      
            , Bay3_Tag       
            , Bay3_Status    
            , Bay3_Data      
            , Bay3_Type      
            , Bay4_Tag       
            , Bay4_Status    
            , Bay4_Data      
            , Bay4_Type      
            , Bay5_Tag       
            , Bay5_Status    
            , Bay5_Data      
            , Bay5_Type      
            , Bay6_Tag       
            , Bay6_Status    
            , Bay6_Data      
            , Bay6_Type      
            , Bay7_Tag       
            , Bay7_Status    
            , Bay7_Data      
            , Bay7_Type      
            , Bay8_Tag       
            , Bay8_Status    
            , Bay8_Data      
            , Bay8_Type      
            , Bay9_Tag       
            , Bay9_Status    
            , Bay9_Data      
            , Bay9_Type      
            , Bay10_Tag      
            , Bay10_Status   
            , Bay10_Data     
            , Bay10_Type     
      FROM @t_Day 
      ORDER BY BookingTimeFr    
   END
   ELSE
   BEGIN
      SELECT  BookingTimefr  
            , BookingTimeto  
            , Bay1_Tag       
            , Bay1_Status    
            , Bay1_BKStatus  
            , Bay1_Blockslotkey   
            , Bay1_BlockSlotDescr               
            , Bay1_Data      
            , Bay1_Type      
            , Bay2_Tag       
            , Bay2_Status    
            , Bay2_BKStatus 
            , Bay2_Blockslotkey   
            , Bay2_BlockSlotDescr   
            , Bay2_Data      
            , Bay2_Type      
            , Bay3_Tag       
            , Bay3_Status    
            , Bay3_BKStatus 
            , Bay3_Blockslotkey   
            , Bay3_BlockSlotDescr                
            , Bay3_Data      
            , Bay3_Type      
            , Bay4_Tag       
            , Bay4_Status    
            , Bay4_BKStatus
            , Bay4_Blockslotkey   
            , Bay4_BlockSlotDescr                 
            , Bay4_Data      
            , Bay4_Type      
            , Bay5_Tag       
            , Bay5_Status    
            , Bay5_BKStatus
            , Bay5_Blockslotkey   
            , Bay5_BlockSlotDescr                     
            , Bay5_Data      
            , Bay5_Type      
            , Bay6_Tag       
            , Bay6_Status    
            , Bay6_BKStatus 
            , Bay6_Blockslotkey   
            , Bay6_BlockSlotDescr                
            , Bay6_Data      
            , Bay6_Type      
            , Bay7_Tag       
            , Bay7_Status    
            , Bay7_BKStatus 
            , Bay7_Blockslotkey   
            , Bay7_BlockSlotDescr                
            , Bay7_Data      
            , Bay7_Type      
            , Bay8_Tag       
            , Bay8_Status    
            , Bay8_BKStatus
            , Bay8_Blockslotkey   
            , Bay8_BlockSlotDescr     
            , Bay8_Data      
            , Bay8_Type      
            , Bay9_Tag       
            , Bay9_Status    
            , Bay9_BKStatus  
            , Bay9_Blockslotkey   
            , Bay9_BlockSlotDescr               
            , Bay9_Data      
            , Bay9_Type      
            , Bay10_Tag      
            , Bay10_Status   
            , Bay10_BKStatus
            , Bay10_Blockslotkey   
            , Bay10_BlockSlotDescr                   
            , Bay10_Data     
            , Bay10_Type  
      FROM @t_Day 
      ORDER BY BookingTimeFr                
   END
   --(Wan05) - END
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   --WHILE @n_starttcnt < @@TRANCOUNT              --(Wan04)
   WHILE @@TRANCOUNT < @n_starttcnt                --(Wan04)
      BEGIN TRAN
END  


GO