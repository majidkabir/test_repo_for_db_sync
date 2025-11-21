SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Function: fnc_ConvSFUTCTime                                   */
/* Creation Date: 2023-09-14                                            */
/* Copyright: Maersk                                                    */
/* Written by:Shong                                                     */
/*                                                                      */
/* Purpose: Support multi TimeZone, convert Local time to UTC Time      */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2023-09-14   1.0      Initial Version								         */
/* 2024-01-22   1.1      SWT  Not doing any convertion if Input Date not*/
/*                            timestamp                                 */
/* 2024-02-23   1.2      Getting Timezone from Facility instead of      */
/*                       StorerConfig                                   */
/************************************************************************/
CREATE   FUNCTION [dbo].[fnc_ConvSFUTCTime]
(
    @cStorerKey NVARCHAR(15)='',
	 @cFacility  NVARCHAR(5)='',
    @dLocalTime DATETIME
)
RETURNS DATETIME
AS
BEGIN
   DECLARE @cTimeZone NVARCHAR(128)= '', 
           @dUTCDate  DATETIME 

   -- If UTC Date do not have time, then do nothing
   IF @dLocalTime = CONVERT(DATETIME, CONVERT(VARCHAR(10), @dLocalTime, 120))
   BEGIN
       SET @dUTCDate = @dLocalTime
   END
   ELSE 
   BEGIN
      IF ISNULL(RTRIM(@cFacility), '') = '' AND ISNULL(RTRIM(@cStorerKey), '') <> ''
      BEGIN
         SELECT @cFacility = ISNULL(Facility,'') 
         FROM dbo.STORER WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
      END

      IF ISNULL(RTRIM(@cFacility), '') <> ''
      BEGIN
         SELECT @cTimeZone=ISNULL(TimeZone,'')
         FROM dbo.FACILITY WITH (NOLOCK) 
         WHERE  [Facility] = @cFacility
      END

      IF ISNULL(@cTimeZone,'') = '' OR 
         NOT EXISTS(SELECT 1 FROM sys.[time_zone_info]
                  WHERE [name]= @cTimeZone)
      BEGIN
         SET @dUTCDate = @dLocalTime
      END
      ELSE
      BEGIN      
         SELECT @dUTCDate = CONVERT(DATETIME,
                  @dLocalTime AT TIME ZONE @cTimeZone
                     AT TIME ZONE 'UTC');
      END
   END 
   RETURN @dUTCDate

END


GO