SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtIsValidDate    					                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Validate date according to the dateformat of the sql login  */
/*          Can't use IsDate() because it allows many dateformat. User  */
/*          only wants 1 fixed date format for validation               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2006-06-21   dhung         Created                                   */
/* 2009-04-20   James         Change the date range from smalldatetime  */
/*                            format to std datetime format (james01)   */
/* 2009-04-21   Vicky         Get dateformat from RDTUser, if no setup  */
/*                            then get from login (Vicky01)             */
/* 2014-11-04   Ung           SOS317571 Fix dateformat is null when run */
/*                            from SQL studio without rdt.rdtUser       */
/* 2015-01-9    Ung           SOS315262 Support 8 chars dateformat      */
/* 2016-10-17   ChewKP        Replace IsDate()                          */
/************************************************************************/

CREATE FUNCTION RDT.rdtIsValidDate (
   @cDate NVARCHAR( 10)
) RETURNS INT AS
BEGIN
   DECLARE @cDD         NVARCHAR( 2)
   DECLARE @cMM         NVARCHAR( 2)
   DECLARE @cYYYY       NVARCHAR( 4)
   DECLARE @cDelimeter1 NVARCHAR( 1)
   DECLARE @cDelimeter2 NVARCHAR( 1)
   DECLARE @nLastDayOfMonth INT 
   DECLARE @cUserDateFormat NVARCHAR( 3)

   -- Get user date format
   SET @cUserDateFormat = rdt.rdtGetDateFormat( SYSTEM_USER)

   -- Check date length
   -- Note: len = 6 is removed 
   DECLARE @nLen INT
   SET @nLen = LEN( @cDate)
   IF @nLEN <> 8 AND @nLen <> 10 
      GOTO Fail

   -- Get the date part according to the dateformat
   IF @cUserDateFormat = 'dmy'
   BEGIN
      IF @nLen = 10
      BEGIN
         SET @cDD         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = SUBSTRING( @cDate, 3, 1)
         SET @cMM         = SUBSTRING( @cDate, 4, 2)
         SET @cDelimeter2 = SUBSTRING( @cDate, 6, 1)
         SET @cYYYY       = SUBSTRING( @cDate, 7, 4)
      END
      ELSE IF @nLen = 8
      BEGIN
         SET @cDD         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = '/'
         SET @cMM         = SUBSTRING( @cDate, 3, 2)
         SET @cDelimeter2 = '/'
         SET @cYYYY       = SUBSTRING( @cDate, 5, 4)
         SET @cDate       = @cDD + @cDelimeter1 + @cMM + @cDelimeter2 + @cYYYY
      END
   END
   ELSE IF @cUserDateFormat = 'mdy'
   BEGIN
      IF @nLen = 10
      BEGIN
         SET @cMM         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = SUBSTRING( @cDate, 3, 1)
         SET @cDD         = SUBSTRING( @cDate, 4, 2)
         SET @cDelimeter2 = SUBSTRING( @cDate, 6, 1)
         SET @cYYYY       = SUBSTRING( @cDate, 7, 4)
      END
      ELSE IF @nLen = 8
      BEGIN
         SET @cMM         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = '/'
         SET @cDD         = SUBSTRING( @cDate, 3, 2)
         SET @cDelimeter2 = '/'
         SET @cYYYY       = SUBSTRING( @cDate, 5, 4)
         SET @cDate       = @cMM + @cDelimeter1 + @cDD + @cDelimeter2 + @cYYYY
      END
   END
   ELSE IF @cUserDateFormat = 'ymd'
   BEGIN
      IF @nLen = 10
      BEGIN
         SET @cYYYY       = SUBSTRING( @cDate, 1, 4)
         SET @cDelimeter1 = SUBSTRING( @cDate, 5, 1)
         SET @cMM         = SUBSTRING( @cDate, 6, 2)
         SET @cDelimeter2 = SUBSTRING( @cDate, 8, 1)
         SET @cDD         = SUBSTRING( @cDate, 9, 2)
      END
      ELSE IF @nLen = 8
      BEGIN
         SET @cYYYY       = SUBSTRING( @cDate, 1, 4)
         SET @cDelimeter1 = '/'
         SET @cMM         = SUBSTRING( @cDate, 5, 2)
         SET @cDelimeter2 = '/'
         SET @cDD         = SUBSTRING( @cDate, 7, 2)
         SET @cDate       = @cYYYY + @cDelimeter1 + @cMM + @cDelimeter2 + @cDD
      END
   END
   ELSE IF @cUserDateFormat = 'ydm'
   BEGIN
      IF @nLen = 10
      BEGIN
         SET @cYYYY       = SUBSTRING( @cDate, 1, 4)
         SET @cDelimeter1 = SUBSTRING( @cDate, 5, 1)
         SET @cDD         = SUBSTRING( @cDate, 6, 2)
         SET @cDelimeter2 = SUBSTRING( @cDate, 8, 1)
         SET @cMM         = SUBSTRING( @cDate, 9, 2)
      END
      ELSE IF @nLen = 8
      BEGIN
         SET @cYYYY       = SUBSTRING( @cDate, 1, 4)
         SET @cDelimeter1 = '/'
         SET @cDD         = SUBSTRING( @cDate, 5, 2)
         SET @cDelimeter2 = '/'
         SET @cMM         = SUBSTRING( @cDate, 7, 2)
         SET @cDate       = @cYYYY + @cDelimeter1 + @cDD + @cDelimeter2 + @cMM
      END
   END
   ELSE IF @cUserDateFormat = 'myd'
   BEGIN
      IF @nLen = 10
      BEGIN
         SET @cMM         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = SUBSTRING( @cDate, 3, 1)
         SET @cYYYY       = SUBSTRING( @cDate, 4, 4)
         SET @cDelimeter2 = SUBSTRING( @cDate, 8, 1)
         SET @cDD         = SUBSTRING( @cDate, 9, 2)
      END
      ELSE IF @nLen = 8
      BEGIN
         SET @cMM         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = '/'
         SET @cYYYY       = SUBSTRING( @cDate, 3, 4)
         SET @cDelimeter2 = '/'
         SET @cDD         = SUBSTRING( @cDate, 7, 2)
         SET @cDate       = @cMM + @cDelimeter1 + @cYYYY + @cDelimeter2 + @cDD
      END
   END
   ELSE IF @cUserDateFormat = 'dym'
   BEGIN
      IF @nLen = 10
      BEGIN
         SET @cDD         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = SUBSTRING( @cDate, 3, 1)
         SET @cYYYY       = SUBSTRING( @cDate, 4, 4)
         SET @cDelimeter2 = SUBSTRING( @cDate, 8, 1)
         SET @cMM         = SUBSTRING( @cDate, 9, 2)
      END
      ELSE IF @nLen = 8
      BEGIN
         SET @cDD         = SUBSTRING( @cDate, 1, 2)
         SET @cDelimeter1 = '/'
         SET @cYYYY       = SUBSTRING( @cDate, 3, 4)
         SET @cDelimeter2 = '/'
         SET @cMM         = SUBSTRING( @cDate, 7, 2)
         SET @cDate       = @cDD + @cDelimeter1 + @cYYYY + @cDelimeter2 + @cMM
      END
   END
   ELSE 
      GOTO Fail

   -- Check delimeter
   IF @cDelimeter1 <> @cDelimeter2
      GOTO Fail
   IF @cDelimeter1 <> '.' AND
      @cDelimeter1 <> '/' AND
      @cDelimeter1 <> '-'
      GOTO Fail

   -- Check day
   DECLARE @nDD INT
   IF RDT.rdtIsInteger( @cDD) = 0
      GOTO Fail
   SET @nDD = CAST( @cDD AS INT)
   IF @nDD < 1 OR @nDD > 31
      GOTO Fail

   -- Check Month
   IF RDT.rdtIsInteger( @cMM) = 0
      GOTO Fail
   DECLARE @nMM INT
   SET @nMM = CAST( @cMM AS INT)
   IF @nMM < 1 OR @nMM > 12
      GOTO Fail

   -- Check Year
   IF RDT.rdtIsInteger( @cYYYY) = 0
      GOTO Fail
   DECLARE @nYYYY INT
   SET @nYYYY = CAST( @cYYYY AS INT)
   IF @nYYYY < 1900 OR @nYYYY > 9999
      GOTO Fail

   -- Date is formated correct. Use IsDate() to check the rest
   -- like last day of month, leap year... etc
   -- IF IsDate( @cDate) = 0
   --    GOTO Fail
   
   -- Get last day of month
   IF @nMM IN ( 1, 3, 5, 7, 8, 10, 12) SET @nLastDayOfMonth = 31 ELSE
   IF @nMM IN ( 4, 6, 9, 11)   SET @nLastDayOfMonth = 30 ELSE
   IF @nMM = 2 
   BEGIN
      -- Check leap year
      IF (@nYYYY % 4 = 0 AND @nYYYY % 100 <> 0) OR ( @nYYYY % 400 = 0 ) 
         SET @nLastDayOfMonth = 29
      ELSE
         SET @nLastDayOfMonth = 28
   END
   
   -- Check last day of month
   IF @nDD > @nLastDayOfMonth
      GOTO Fail  

   RETURN 1
Fail:
   RETURN 0
END

GO