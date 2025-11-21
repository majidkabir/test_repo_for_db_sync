SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetBookingByMonth                              */
/* Creation Date: 09-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Booking Module                                              */
/*                                                                      */
/* Called By: Booking                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 11-JUN-2014  YTWan    1.1  SOS#312513 - Add man hours to Booking View*/
/*                            By Month. (Wan01)                         */
/************************************************************************/

CREATE PROC [dbo].[isp_GetBookingByMonth] 
   @nMonth  INT,
   @nYear   INT,
   @cFacility NVARCHAR(5) = '',  
   @cInOut CHAR(1) = 'I' 

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nWeekNo      INT,
           @dStartDate   DATETIME,
           @dEndDate     DATETIME,
           @dCurrDate    DATETIME,
           @dWorkDate    DATETIME,
           @cSunday      NVARCHAR(80),
           @cMonday      NVARCHAR(80), 
           @cTuesday     NVARCHAR(80),
           @cWednesday   NVARCHAR(80),
           @cThursday    NVARCHAR(80),
           @cFriday      NVARCHAR(80),
           @cSaturday    NVARCHAR(80),
           @nWeekDay     INT,
           @nPrevWeekNo  INT, 
           @nDayIdx      INT,
           @cDesc        NVARCHAR(80),
           @cNewLine     CHAR(5)  
            
   
   DECLARE @t_Month TABLE (
      WeekNo    INT,
      Sunday    NVARCHAR(80),
      Monday    NVARCHAR(80), 
      Tuesday   NVARCHAR(80),
      Wednesday NVARCHAR(80),
      Thursday  NVARCHAR(80),
      Friday    NVARCHAR(80),
      Saturday  NVARCHAR(80) 
      )
      
   SET @dStartDate = convert(datetime, CAST(@nYear AS VARCHAR(4)) + '/' + CAST(@nMonth AS VARCHAR(2)) + '/1')
   IF @nMonth = 12 
      SET @dEndDate = convert(datetime, CAST(@nYear+1 AS VARCHAR(4)) + '/' + CAST(1 AS VARCHAR(2)) + '/1')
   ELSE

      SET @dEndDate = convert(datetime, CAST(@nYear AS VARCHAR(4)) + '/' + CAST(@nMonth + 1 AS VARCHAR(2)) + '/1')

      SET @dEndDate = DATEADD(DAY, -1, @dEndDate)
     
   SET @cNewLine = '  '+CHAR(10)
    
   SET @dCurrDate = @dStartDate
   WHILE @dCurrDate <= @dEndDate
   BEGIN
      
      IF @dCurrDate = @dStartDate
      BEGIN
         SET @nWeekDay = DATEPART(dw, @dCurrDate)
         WHILE @nWeekDay >= 1 
         BEGIN
         	  SET @dWorkDate = DateAdd(day, @nWeekDay * -1, @dCurrDate)
         	  SET @cDesc = dbo.fnc_GetBookingDescByDate(@cFacility, @dWorkDate, @cInOut)
              --(Wan01) - START
              SET @cDesc = @cDesc + CHAR(10) + dbo.fnc_GetBookingShiftByDate(@cFacility, @dWorkDate, @cInOut)
              --(Wan01) - END
            IF DATEPART(dw, @dWorkDate) = 1
               SET @cSunday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc

            IF DATEPART(dw, @dWorkDate) = 2
               SET @cMonday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc

            IF DATEPART(dw, @dWorkDate) = 3
               SET @cTuesday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc

            IF DATEPART(dw, @dWorkDate) = 4
               SET @cWednesday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc

            IF DATEPART(dw, @dWorkDate) = 5
               SET @cThursday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc

            IF DATEPART(dw, @dWorkDate) = 6
               SET @cFriday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc

            IF DATEPART(dw, @dWorkDate) = 7
               SET @cSaturday = LEFT(CONVERT(VARCHAR(10), @dWorkDate, 6),6) + @cNewLine + @cDesc
               
            SET @nWeekDay = @nWeekDay - 1   
         END
      END 
           
      SET @nWeekDay = DATEPART(dw, @dCurrDate)
      SET @cDesc = dbo.fnc_GetBookingDescByDate(@cFacility, @dCurrDate, @cInOut)
  
      --(Wan01) - START
      SET @cDesc = @cDesc + CHAR(10) + dbo.fnc_GetBookingShiftByDate(@cFacility, @dCurrDate, @cInOut)
      --(Wan01) - END

      IF @nWeekDay = 1
         SET @cSunday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc
         
      IF @nWeekDay = 2
         SET @cMonday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc
                        
      IF @nWeekDay = 3
         SET @cTuesday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc
         
      IF @nWeekDay = 4
         SET @cWednesday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc
         
      IF @nWeekDay = 5
         SET @cThursday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc
         
      IF @nWeekDay = 6
         SET @cFriday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc
         
      IF @nWeekDay = 7
         SET @cSaturday = CONVERT(VARCHAR(2), DatePart(day, @dCurrDate)) + @cNewLine + @cDesc

      
      SET @nWeekNo   = DATEPART(wk, @dCurrDate)
      
      IF NOT EXISTS(SELECT 1 FROM @t_Month tm WHERE tm.WeekNo = @nWeekNo) AND @nWeekDay = 7
      BEGIN
         INSERT INTO @t_Month 
         VALUES (@nWeekNo, @cSunday, @cMonday, @cTuesday, @cWednesday, @cThursday, @cFriday, @cSaturday)  
         SET @cSunday=''
         SET @cMonday=''
         SET @cTuesday='' 
         SET @cWednesday=''
         SET @cThursday=''
         SET @cFriday='' 
         SET @cSaturday=''
      END
 
      IF @dCurrDate = @dEndDate
      BEGIN
         WHILE @nWeekDay < 7 
         BEGIN
            SET @nDayIdx = 1
            SET @nWeekDay = @nWeekDay + 1
            SET @dCurrDate = DATEADD(DAY, 1, @dCurrDate)
         	SET @cDesc = dbo.fnc_GetBookingDescByDate(@cFacility, @dCurrDate, @cInOut)
            --(Wan01) - START
            SET @cDesc = @cDesc + CHAR(10) + dbo.fnc_GetBookingShiftByDate(@cFacility, @dCurrDate, @cInOut)
            --(Wan01) - END      
            IF DATEPART(dw, @dCurrDate) = 1
               SET @cSunday = LEFT(CONVERT(VARCHAR(10), @dCurrDate, 6),6) + @cNewLine + @cDesc
               
            IF DATEPART(dw, @dCurrDate) = 2
               SET @cMonday = LEFT(CONVERT(VARCHAR(10), @dCurrDate, 6),6) + @cNewLine + @cDesc
                              
            IF DATEPART(dw, @dCurrDate) = 3
               SET @cTuesday = LEFT(CONVERT(VARCHAR(10), @dCurrDate,6),6) + @cNewLine + @cDesc
               
            IF DATEPART(dw, @dCurrDate) = 4
               SET @cWednesday = LEFT(CONVERT(VARCHAR(10), @dCurrDate, 6),6) + @cNewLine + @cDesc
               
            IF DATEPART(dw, @dCurrDate) = 5
               SET @cThursday = LEFT(CONVERT(VARCHAR(10), @dCurrDate, 6),6) + @cNewLine + @cDesc
               
            IF DATEPART(dw, @dCurrDate) = 6
               SET @cFriday = LEFT(CONVERT(VARCHAR(10), @dCurrDate,6),6) + @cNewLine + @cDesc
               
            IF DATEPART(dw, @dCurrDate) = 7
               SET @cSaturday = LEFT(CONVERT(VARCHAR(10), @dCurrDate, 6),6) + @cNewLine + @cDesc
               
            SET @nDayIdx = 1 + @nDayIdx    
         END
         IF NOT EXISTS(SELECT 1 FROM @t_Month tm WHERE tm.WeekNo = @nWeekNo) 
         BEGIN
            INSERT INTO @t_Month 
            VALUES (@nWeekNo, @cSunday, @cMonday, @cTuesday, @cWednesday, @cThursday, @cFriday, @cSaturday)  

         END
      END 
  
      SET @dCurrDate = DATEADD(DAY, 1, @dCurrDate)

   END
   SELECT * FROM @t_Month    
END

GO