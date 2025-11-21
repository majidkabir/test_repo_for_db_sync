SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetBookingBlockSlot                            */
/* Creation Date: 22-Feb-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Booking Module                                              */
/*                                                                      */
/* Called By: Block Booking Calendar                                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 13-JUN-2012  YTWan    1.0  SOS#244706:Marks booking slots with color */
/*                            (Wan01)                                   */
/* 04-APR-2022  Wan02    1.2  DevOps Combine Script                     */
/* 04-APR-2022  Wan02    1.2  LFWM-3336 - Door Booking SPsDB queries    */
/*                            clarification                             */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_GetBookingBlockSlot]
   @c_Facility NVARCHAR(5) = '',
   @d_Date     DATETIME,   
   @c_InOut    CHAR(1) = 'I', 
   @c_Door     NVARCHAR(10) = '',
   @c_Output   CHAR(1) = 'N'
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
     
   DECLARE @c_bay        NVARCHAR(10),  
           @n_day        INT  
                                    
   /*CREATE TABLE #TMP_BLOCKSLOT_OUTPUT (
       Loc NVarchar(10) NULL,
       TimeFrom Varchar(10) NULL,
       TimeTo Varchar(10) NULL)*/          
   
   SELECT @n_day = DATEPART(dw, @d_Date)
   IF @c_inout = 'I'
      SELECT @c_bay = 'BAYIN'
   ELSE
      SELECT @c_bay = 'BAYOUT' 
   
   SELECT LOC.Loc,
          CASE WHEN BS.FromTime IS NULL THEN '00:00' 
          ELSE
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BS.FromTime)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BS.FromTime)), 2) 
          END AS timefrom,
          CASE WHEN BS.ToTime IS NULL THEN '23:59'
          ELSE 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BS.ToTime)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BS.ToTime)), 2)  
          END AS timeto
         ,BS.Color                     --(Wan01)
         ,BS.ColorOnly                 --(Wan01)
         ,BS.Blockslotkey              --(Wan02)
         ,BS.Descr                     --(Wan02)
   INTO #TMP_BLOCKSLOT
   FROM Booking_BlockSlot BS (NOLOCK)
   JOIN LOC ON (BS.Loc = LOC.Loc)
   WHERE BS.Facility = @c_Facility
   AND (ISNULL(BS.Day,0)=0 OR BS.Day = @n_day)
   AND ISNULL(BS.Loc,'') <> ''
   AND LOC.LocationCategory IN('BAY',@c_bay)
   AND (LOC.Loc = @c_Door OR ISNULL(@c_Door,'')='')
   AND CONVERT(datetime, CONVERT(varchar(12), BS.FromDate, 112)) <= @d_Date
   AND (CONVERT(datetime, CONVERT(varchar(12), BS.ToDate, 112) + ' 23:59:59:998') >= @d_Date OR BS.ToDate IS NULL )
   UNION 
   SELECT LOC.Loc, 
          CASE WHEN BS.FromTime IS NULL THEN '00:00' 
          ELSE
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BS.FromTime)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BS.FromTime)), 2) 
          END AS timefrom,
          CASE WHEN BS.ToTime IS NULL THEN '23:59'
          ELSE 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(hour, BS.ToTime)), 2) + ':' + 
             RIGHT('0' + CONVERT(VARCHAR, DATEPART(minute, BS.ToTime)), 2)  
          END AS timeto
         ,BS.Color                     --(Wan01)
         ,BS.ColorOnly                 --(Wan01)
         ,BS.Blockslotkey              --(Wan02)
         ,BS.Descr                     --(Wan02)         
   FROM Booking_BlockSlot BS (NOLOCK)
   JOIN LOC ON (BS.Facility = LOC.Facility)
   WHERE BS.Facility = @c_Facility
   AND (ISNULL(BS.Day,0)=0 OR BS.Day = @n_day)
   AND ISNULL(BS.Loc,'') = ''
   AND LOC.LocationCategory IN('BAY',@c_bay)
   AND (LOC.Loc = @c_Door OR ISNULL(@c_Door,'')='')
   AND CONVERT(datetime, CONVERT(varchar(12), BS.FromDate, 112)) <= @d_Date
   AND (CONVERT(datetime, CONVERT(varchar(12), BS.ToDate, 112) + ' 23:59:59:998') >= @d_Date OR BS.ToDate IS NULL )
   
   IF @c_Output = 'Y'
   BEGIN
      SELECT * FROM #TMP_BLOCKSLOT
      ORDER BY Loc, TimeFrom
   END
   ELSE
   BEGIN
      IF OBJECT_ID('tempdb..#TMP_BLOCKSLOT_OUTPUT') IS NOT NULL
      BEGIN
         INSERT INTO #TMP_BLOCKSLOT_OUTPUT
         SELECT * FROM #TMP_BLOCKSLOT
         ORDER BY Loc, TimeFrom
      END
   END   
END  

GO