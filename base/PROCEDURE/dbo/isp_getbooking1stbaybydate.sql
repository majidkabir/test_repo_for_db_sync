SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure:  isp_GetBooking1stBayByDate                        */
/* Creation Date: 09-Jul-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#297080 Get booking fist bay                             */
/*                                                                      */
/* Called By:  Booking Module                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                */
/* 2022-11-16  Wan01    1.1   WMS-21173-[PH] - Colgate-Palmolive Inbound*/
/*                            Doorbooking EndTime                       */
/*                            DevOps Combine Script                     */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_GetBooking1stBayByDate]
   @cFacility NVARCHAR(5),
   @dDate     DATETIME,
   @cInOut    NVARCHAR(1),
   @cLoc      NVARCHAR(10) OUTPUT
AS
BEGIN
  SET NOCOUNT ON  
  SET ANSI_DEFAULTS OFF
  SET QUOTED_IDENTIFIER OFF
  SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @dFromDate datetime, 
          @dToDate datetime,
          @cInLoc NVARCHAR(10),
          @cOutLoc NVARCHAR(10),
          @cInCategory NVARCHAR(10),
          @cOutCategory NVARCHAR(10)
  
  SELECT @dFromDate = Convert(Datetime, Convert(NVARCHAR(10), @dDate, 101))   
  SELECT @dToDate = DateAdd(mi,-1,DateAdd(dd,1,@dFromdate))

  IF @cInOut = 'I'
  BEGIN
     SET @cInCategory = 'BayIn'
     SET @cOutCategory = 'XXXXX'
  END
  ELSE
  BEGIN
     SET @cInCategory = 'XXXXX'
     SET @cOutCategory = 'BayOut'
  END
    
  SELECT TOP 1 @cInLoc = LOC.Loc 
  FROM BOOKING_IN BI (NOLOCK) 
  JOIN LOC WITH (NOLOCK) ON BI.Loc = LOC.Loc 
  LEFT JOIN CODELKUP WITH (NOLOCK) ON LOC.LOC = CODELKUP.Long AND LOC.Facility = CODELKUP.Short 
                                   AND CODELKUP.Listname = 'USREXCLBAY' AND CODELKUP.UDF01 = SUSER_SNAME()  
  WHERE BI.Facility = @cFacility 
  AND LOC.LocationCategory IN(@cInCategory,'Bay') 
  AND CODELKUP.Code IS NULL
  AND (BI.BookingDate BETWEEN @dFromDate AND @dToDate OR                   --(Wan01)
       BI.EndTime BETWEEN @dFromDate AND @dToDate)                         --(Wan01)
  ORDER BY LOC.logicallocation, LOC.Loc
  
  SELECT TOP 1 @cOutLoc = LOC.Loc 
  FROM BOOKING_OUT BO (NOLOCK) 
  JOIN LOC WITH (NOLOCK) ON BO.Loc = LOC.Loc 
  LEFT JOIN CODELKUP WITH (NOLOCK) ON LOC.LOC = CODELKUP.Long AND LOC.Facility = CODELKUP.Short 
                                   AND CODELKUP.Listname = 'USREXCLBAY' AND CODELKUP.UDF01 = SUSER_SNAME()  
  WHERE BO.Facility = @cFacility 
  AND LOC.LocationCategory IN(@cOutCategory,'Bay') 
  AND CODELKUP.Code IS NULL
  AND (BO.BookingDate BETWEEN @dFromDate AND @dToDate OR                   --(Wan01)
       BO.EndTime BETWEEN @dFromDate AND @dToDate)                         --(Wan01)
  ORDER BY LOC.logicallocation, LOC.Loc    
     
  IF ISNULL(@cInLoc,'ZZZZZZZZZZ') <= ISNULL(@cOutLoc,'ZZZZZZZZZ')
     SET @cLoc = ISNULL(@cInLoc,'')
  ELSE
     SET @cLoc = ISNULL(@cOutLoc,'')
END

GO