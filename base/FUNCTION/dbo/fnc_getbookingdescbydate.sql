SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_GetBookingDescByDate                                  */
/* Creation Date: 09-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Get booking count in description                            */
/*                                                                      */
/* Called By:  Booking Module                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 31-OCT-2014 YTWan    1.2   SOS#322304 - PH - CPPI WMS Door Booking   */
/*                            Enhancement (Wan01)                       */
/* 16-NOV-2022 Wan02    1.3   WMS-21173-[PH] - Colgate-Palmolive Inbound*/
/*                            Doorbooking EndTime                       */
/*                            DevOps Combine Script                     */
/************************************************************************/

CREATE   FUNCTION [dbo].[fnc_GetBookingDescByDate] ( 
   @cFacility NVARCHAR(5),
   @dDate     DATETIME,
   @cInOut    NVARCHAR(1)
) RETURNS NVARCHAR(80) AS
BEGIN
  SET QUOTED_IDENTIFIER OFF

  DECLARE @dFromDate datetime, 
          @dToDate datetime,
          @nCount int,
          @nCount_ShareBay int,
          @cDesc NVARCHAR(80),
          @nDurationMin int,
          @nDurationMin_ShareBay int,
          @nTotalLoc int
  
  SELECT @dFromDate = Convert(Datetime, Convert(NVARCHAR(10), @dDate, 101))   
  SELECT @dToDate = DateAdd(mi,-1,DateAdd(dd,1,@dFromdate))
  SELECT @cDesc = ''
   
  IF @cInOut = 'I'
  BEGIN
   SELECT @nCount = COUNT(*), @nDurationMin = SUM(datediff(mi,'1900-01-01', BI.duration))
   FROM BOOKING_IN BI (NOLOCK)
   WHERE BI.Facility = @cFacility
   AND BI.Status <> '9'
   --(Wan02) - START
   --AND BI.BookingDate BETWEEN @dFromDate AND @dToDate
   AND ( BI.BookingDate BETWEEN @dFromDate AND @dToDate OR
         BI.EndTime     BETWEEN @dFromDate AND @dToDate )
   --(Wan02) - END   
   
   SELECT @nCount_ShareBay = COUNT(*), @nDurationMin_ShareBay = SUM(datediff(mi,'1900-01-01', BO.duration))
   FROM BOOKING_OUT BO (NOLOCK)
    JOIN LOC (NOLOCK) ON BO.Loc = LOC.Loc
   WHERE BO.Facility = @cFacility
   AND BO.Status <> '9'
   --(Wan01) - START    
   --AND BO.BookingDate BETWEEN @dFromDate AND @dToDate
   AND ( BO.BookingDate BETWEEN @dFromDate AND @dToDate OR
         BO.EndTime     BETWEEN @dFromDate AND @dToDate )      
   --(Wan01) - END
   AND LOC.LocationCategory = 'BAY'
      
   SELECT @nTotalLoc = COUNT(*)
   FROM LOC(NOLOCK)
   WHERE LocationCategory IN('BAYIN','BAY')
   AND Facility = @cfacility
  END
  ELSE
  BEGIN
   SELECT @nCount = COUNT(*), @nDurationMin = SUM(datediff(mi,'1900-01-01', BO.duration))
   FROM BOOKING_OUT BO (NOLOCK)
   WHERE BO.Facility = @cFacility
   AND BO.Status <> '9'
   --(Wan01) - START
   --AND BO.BookingDate BETWEEN @dFromDate AND @dToDate 
   AND ( BO.BookingDate BETWEEN @dFromDate AND @dToDate OR
         BO.EndTime     BETWEEN @dFromDate AND @dToDate )      
   --(Wan01) - END
   SELECT @nCount_ShareBay = COUNT(*), @nDurationMin_ShareBay = SUM(datediff(mi,'1900-01-01', BI.duration))
   FROM BOOKING_IN BI (NOLOCK)
    JOIN LOC (NOLOCK) ON BI.Loc = LOC.Loc
   WHERE BI.Facility = @cFacility
   AND BI.Status <> '9'
   --AND BI.BookingDate BETWEEN @dFromDate AND @dToDate
   AND ( BI.BookingDate BETWEEN @dFromDate AND @dToDate OR
         BI.EndTime     BETWEEN @dFromDate AND @dToDate )
   --(Wan02) - END
   AND LOC.LocationCategory = 'BAY'

   SELECT @nTotalLoc = COUNT(*)
   FROM LOC(NOLOCK)
   WHERE LocationCategory IN('BAYOUT','BAY')
   AND Facility = @cfacility
  END
  
  IF @nCount IS NULL
     SET @nCount = 0
  IF @nCount_ShareBay IS NULL
     SET @nCount_ShareBay = 0
  IF @nDurationMin IS NULL
     SET @nDurationMin = 0
  IF @nDurationMin_ShareBay IS NULL
     SET @nDurationMin_ShareBay = 0
  
   IF (@nCount + @nCount_ShareBay) > 0
   BEGIN
      IF @nCount_ShareBay > 0
      BEGIN 
           IF @cInOut = 'I'
           SET @cDesc = rtrim(ltrim(str(@nCount))) + ' Booking (I)' + char(10) + rtrim(ltrim(str(@nCount_ShareBay))) + ' Booking (O)'
        ELSE
           SET @cDesc = rtrim(ltrim(str(@nCount))) + ' Booking (O)' + char(10) + rtrim(ltrim(str(@nCount_ShareBay))) + ' Booking (I)'       
      END
      ELSE
           IF @cInOut = 'I'
           SET @cDesc = rtrim(ltrim(str(@nCount))) + ' Booking (I)'
        ELSE
           SET @cDesc = rtrim(ltrim(str(@nCount))) + ' Booking (O)'        
                  
     IF (@nDurationMin + @nDurationMin_ShareBay) > 0
      BEGIN
          SET @cDesc = @cDesc + char(10) + ' ' + STR(( (@nDurationMin+@nDurationMin_ShareBay) / ((@nTotalLoc * 24) * 60.00) * 100),5,2)+ '%'
      END 
   END

  RETURN @cDesc
END

GO