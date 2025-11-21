SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Function: fnc_ConvSFTimeZone                                  */
/* Creation Date: 2023-09-14                                            */
/* Copyright: Maersk                                                    */
/* Written by:Shong                                                     */
/*                                                                      */
/* Purpose: Support multi TimeZone, convert UTC date to Local Time      */
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
CREATE   FUNCTION [dbo].[fnc_ConvSFTimeZone]
(
    @cStorerKey NVARCHAR(15)='',
	 @cFacility  NVARCHAR(5)='',
    @dUTCDate   DATETIME
)
RETURNS DATETIME
AS
BEGIN
   DECLARE @cTimeZone NVARCHAR(128)= '', 
           @dLocalTime DATETIME 

   -- If UTC Date do not have time, then do nothing
   IF @dUTCDate = CONVERT(DATETIME, CONVERT(VARCHAR(10), @dUTCDate, 120))
   BEGIN
       SET @dLocalTime = @dUTCDate 
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
         SET @dLocalTime = @dUTCDate 
      END
      ELSE
      BEGIN
         SELECT @dLocalTime = CONVERT(DATETIME,
                  @dUTCDate AT TIME ZONE 'UTC'
                     AT TIME ZONE @cTimeZone);

      END
   END 
   RETURN @dLocalTime

END


GO