SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: rdtConvertDateFormat    					            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Convert RDT Input Date Format to Std DateTime format        */
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
/* 2011-03-17   ChewKP        Created                                   */
/* 2016-11-01   ChewKP        Replace IsDate() (ChewKP01)               */
/* 2023-12-23   YeeKung       Change add date (yeekung01)               */ 
/************************************************************************/

CREATE   FUNCTION [RDT].[rdtConvertDateFormat] (
   @cDate NVARCHAR( 20),
   @cFormat NVARCHAR(10)
) RETURNS DATETIME AS
BEGIN

   DECLARE @cDD         NVARCHAR( 2)
   DECLARE @cMM         NVARCHAR( 2)
   DECLARE @cYYYY       NVARCHAR( 4)
   DECLARE @cDelimeter1 NVARCHAR( 1)
   DECLARE @cDelimeter2 NVARCHAR( 1),
           @dNewDateTime DATETIME,
           @cNewDateTime NVARCHAR(10),
           @nLastDayOfMonth INT,
           @cLFDate     NVARCHAR(10)
   DECLARE @cStorerkey   NVARCHAR(20)
   DECLARE @cFacility   NVARCHAR(20)

   SELECT @cStorerkey = storerkey,
          @cFacility = facility
   FROM RDT.RDTMobrec (NOLOCK)
   where username = SYSTEM_USER

   -- Get the date part according to the dateformat
   IF @cFormat = 'yyyymmdd'
   BEGIN
      SET @cDD         = SUBSTRING( @cDate, 7, 2)
      --SET @cDelimeter1 = SUBSTRING( @cDate, 3, 1)
      SET @cMM         = SUBSTRING( @cDate, 5, 2)
      --SET @cDelimeter2 = SUBSTRING( @cDate, 6, 1)
      SET @cYYYY       = SUBSTRING( @cDate, 1, 4)
   END
   ELSE
   BEGIN
      GOTO Fail
   END


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
--   IF @nYYYY < 1900 OR @nYYYY > 2078  -- follow smalldatetime range
   IF @nYYYY < 1900 OR @nYYYY > 9999   -- (james01). follow std datetime format
      GOTO Fail

   -- Convert to New Format
   SET @cNewDateTime =  @cDD + '/' + @cMM + '/' +  @cYYYY


   -- Date is formated correct. Use IsDate() to check the rest
   -- like last day of month, leap year... etc
--   IF IsDate(@cNewDateTime)= 0
--      GOTO Fail

  -- (ChewKP01)
   IF @nMM IN ( 1 , 3 , 5 , 7 , 9 , 11 )
   BEGIN
         SET @nLastDayOfMonth = 30
   END
   ELSE IF @nMM IN ( 4, 6, 8, 10, 12 )
   BEGIN
      SET @nLastDayOfMonth = 31
   END
   ELSE IF @nMM = 2
   BEGIN

      IF (@nYYYY % 4 = 0 AND @nYYYY % 100 <> 0) OR ( @nYYYY % 400 = 0 )
      BEGIN
         SET @nLastDayOfMonth = 29
      END
      ELSE
      BEGIN
         SET @nLastDayOfMonth = 28
      END
   END

   IF @nDD > @nLastDayOfMonth
      GOTO Fail


   SET @dNewDateTime = CONVERT (DATETIME, @cNewDateTime, 103)

   RETURN @dNewDateTime
Fail:
   RETURN NULL
END

GO