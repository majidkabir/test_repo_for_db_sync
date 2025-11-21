SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Function: fnc_GetVC_DateTime                                            */
/* Creation Date: 30-Mar-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: Check-in fnc_GetVC_DateTime from PD                            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/ 
CREATE FUNCTION [dbo].[fnc_GetVC_DateTime] 
  ( 
    @d_Date          DATETIME, 
    @c_LanguageCode  NVARCHAR(10)
  )
RETURNS NVARCHAR(100)
AS
BEGIN
   DECLARE @c_Year   INT
          ,@c_Month  INT  
          ,@c_Day    INT
          ,@c_Hour   INT
          ,@c_Minute INT
          ,@c_DateString NVARCHAR(100)
          
   SET @c_Year   = DATEPART(YEAR, @d_Date)
   SET @c_Month  = DATEPART(MONTH, @d_Date)
   SET @c_Day    = DATEPART(DAY, @d_Date)
   SET @c_Hour   = DATEPART(hour, @d_Date)
   SET @c_Minute = DATEPART(minute, @d_Date)
   
   SET @c_DateString = 
      CASE @c_LanguageCode 
         WHEN 'CHN' 
            THEN @c_Year + N'σ╣┤ ' + CASE @c_Month 
                     WHEN 1 	THEN 'Σ╕Çµ£ê'
                     WHEN 2 	THEN 'Σ║îµ£ê'
                     WHEN 3 	THEN 'Σ╕ëµ£ê'
                     WHEN 4 	THEN 'σ¢¢µ£ê'
                     WHEN 5 	THEN 'Σ║öµ£ê'
                     WHEN 6 	THEN 'σà¡µ£ê'
                     WHEN 7 	THEN 'Σ╕âµ£ê'
                     WHEN 8 	THEN 'σà½µ£ê'
                     WHEN 9 	THEN 'Σ╣¥µ£ê'
                     WHEN 10  THEN 'σìüµ£ê'
                     WHEN 11  THEN 'σìüΣ╕Çµ£ê'
                     WHEN 12  THEN 'σìüΣ║îµ£ê'     
                END + @c_Day + N'ΦÖƒ'   
         WHEN 'MYL' 
            THEN @c_Day + ' ' + 
                 CASE @c_Month 
                     WHEN 1 	THEN 'Januari'
                     WHEN 2 	THEN 'Februari'
                     WHEN 3 	THEN 'Mac'
                     WHEN 4 	THEN 'April'
                     WHEN 5 	THEN 'Mei'
                     WHEN 6 	THEN 'Jun'
                     WHEN 7 	THEN 'Julai'
                     WHEN 8 	THEN 'Ogos'
                     WHEN 9 	THEN 'September'
                     WHEN 10  THEN 'Oktober'
                     WHEN 11  THEN 'November'
                     WHEN 12  THEN 'Disember'     
                END + ' tahun ' + @c_Year 
         ELSE
            @c_Day + ' ' + 
                 CASE @c_Month 
                     WHEN 1 	THEN 'January'	           
                     WHEN 2 	THEN 'February'	         
                     WHEN 3 	THEN 'March'	             
                     WHEN 4 	THEN 'April'	             
                     WHEN 5 	THEN 'May'	               
                     WHEN 6 	THEN 'June'	             
                     WHEN 7 	THEN 'July'	             
                     WHEN 8 	THEN 'August'	           
                     WHEN 9 	THEN 'September'	         
                     WHEN 10 THEN 'October'	           
                     WHEN 11 THEN 'November'	         
                     WHEN 12 THEN 'December'       
                END + ' ' + @c_Year             
      END       
   
       
   RETURN @c_DateString
END

GO