SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
  
   /******************************************************************************/  
   /* Stored Procedure: rdtConvertToDate                                 */  
   /* Copyright: LFLogistics                                                     */  
   /*                                                                            */  
   /* Purpose: Convert string to date                                            */  
   /*                                                                            */  
   /* Date         Author     Ver   Purposes                                     */  
   /* 2015-01-23   Ung        1.0   SOS315262 Support 8 chars dateformat         */  
   /* 2016-11-01   ChewKP     1.1   Replace IsDate()                             */  
   /* 2017-11-23   Ung        1.2   WMS-3153 Fix date format not follow session  */  
   /* 2023-12-23   YeeKung    1.3   Change add date (yeekung01)                  */   
   /******************************************************************************/  
  
   CREATE    FUNCTION [RDT].[rdtConvertToDate] (  
      @cDate NVARCHAR( 20)  
   ) RETURNS DATETIME AS  
   BEGIN  
      DECLARE @cDD         NVARCHAR( 2)  
      DECLARE @cMM         NVARCHAR( 2)  
      DECLARE @cYYYY       NVARCHAR( 4)  
      DECLARE @cDelimeter1 NVARCHAR( 1)  
      DECLARE @cDelimeter2 NVARCHAR( 1)  
      DECLARE @nLastDayOfMonth INT  
      DECLARE @cUserDateFormat NVARCHAR( 3)  
      DECLARE @cSysDateFormat  NVARCHAR( 3)  
      DECLARE @cStorerkey   NVARCHAR(20)  
      DECLARE @cFacility   NVARCHAR(20)  
      DECLARE @cHour       NVARCHAR( 2)  
      DECLARE @cMinute     NVARCHAR( 2)  
  
      -- Get user date format  
      SET @cUserDateFormat = rdt.rdtGetDateFormat( SYSTEM_USER)  
  
      SELECT @cStorerkey = storerkey,  
             @cFacility = facility  
      FROM RDT.RDTMobrec (NOLOCK)  
      where username = SYSTEM_USER  
  
      -- Check date length  
      -- Note: len = 6 is removed  
      DECLARE @nLen INT  
      SET @nLen = LEN( @cDate)  
      --IF @nLEN <> 8 AND @nLen <> 10  
      --   GOTO Fail  
  
      -- Get the date part according to the dateformat  
      IF @cUserDateFormat = 'dmy'  
      BEGIN  
         IF @nLen = 10  OR CHARINDEX ('/',@cDate) >0
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
         IF @nLen = 10  OR CHARINDEX ('/',@cDate) >0
         BEGIN  
            SET @cMM         = SUBSTRING( @cDate, 1, 2)  
            SET @cDelimeter1 = SUBSTRING( @cDate, 3, 1)  
            SET @cDD         = SUBSTRING( @cDate, 4, 2)  
            SET @cDelimeter2 = SUBSTRING( @cDate, 6, 1)  
            SET @cYYYY       = SUBSTRING( @cDate, 7, 4)        
            SET @cHour = CASE WHEN ISNULL(RIGHT( '0' + RTRIM( DATEPART( hh, @cDate)), 2),'') ='' THEN 0 ELSE @cHour END
            SET @cMinute = CASE WHEN ISNULL(RIGHT( '0' + RTRIM( DATEPART( mi, @cDate)), 2),'') ='' THEN 0 ELSE @cMinute END
         END  
         ELSE IF @nLen = 8  OR CHARINDEX ('/',@cDate) >0
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
         IF @nLen = 10  OR CHARINDEX ('/',@cDate) >0
         BEGIN  
            SET @cYYYY       = SUBSTRING( @cDate, 1, 4)  
            SET @cDelimeter1 = SUBSTRING( @cDate, 5, 1)  
            SET @cMM         = SUBSTRING( @cDate, 6, 2)  
            SET @cDelimeter2 = SUBSTRING( @cDate, 8, 1)              
            SET @cDD         = SUBSTRING( @cDate, 9, 2)  
            SET @cHour = CASE WHEN ISNULL(RIGHT( '0' + RTRIM( DATEPART( hh, @cDate)), 2),'') ='' THEN 0 ELSE @cHour END
            SET @cMinute = CASE WHEN ISNULL(RIGHT( '0' + RTRIM( DATEPART( mi, @cDate)), 2),'') ='' THEN 0 ELSE @cMinute END
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
         IF @nLen = 10  OR CHARINDEX ('/',@cDate) >0
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
         IF @nLen = 10  OR CHARINDEX ('/',@cDate) >0
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
         IF @nLen = 10  OR CHARINDEX ('/',@cDate) >0
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
  
      -- Get SQL login date format  
      SELECT @cSysDateFormat = date_format FROM sys.dm_exec_sessions WHERE login_name = SYSTEM_USER AND session_id = @@SPID  
		DECLARE @dDate DATETIME  
		DECLARE @cTimeZone VARCHAR(100)= ''
    
		-- Output date as per SQL login date format  
		IF @cSysDateFormat = 'dmy' SET @dDate = @cDD   + '-' + @cMM   + '-' + @cYYYY  ELSE  
		IF @cSysDateFormat = 'mdy' SET @dDate = @cMM   + '-' + @cDD   + '-' + @cYYYY  ELSE  
		IF @cSysDateFormat = 'ymd' SET @dDate = @cYYYY + '-' + @cMM   + '-' + @cDD    ELSE  
		IF @cSysDateFormat = 'ydm' SET @dDate = @cYYYY + '-' + @cDD   + '-' + @cMM    ELSE  
		IF @cSysDateFormat = 'myd' SET @dDate = @cMM   + '-' + @cYYYY + '-' + @cDD    ELSE  
		IF @cSysDateFormat = 'dym' SET @dDate = @cDD   + '-' + @cYYYY + '-' + @cMM    ELSE
      GOTO FAIL

      SET @dDate = dbo.fnc_ConvSFUTCTime(@cStorerkey, @cFacility, @dDate)  
  
      RETURN @dDate 
   Fail:  
      RETURN NULL  
   END 

GO