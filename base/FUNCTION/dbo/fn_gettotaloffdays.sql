SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: fn_GetTotalOffDays                                 */
/* Creation Date: 2018-03-27                                            */
/* Copyright: LF Logistics                                              */
/* Written by:KHLim                                                     */
/*                                                                      */
/* Purpose:  https://jira.lfapps.net/browse/WMS-4319                    */
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
/* 2018-03-27   KHLim    1.0  Initial Version								   */
/************************************************************************/

CREATE FUNCTION [dbo].[fn_GetTotalOffDays](  
   @DateFrom DATE,  
   @DateTo   DATE,  
   @StorerKey NVARCHAR(15) = '' )  
RETURNS INT  
AS  
BEGIN  
   DECLARE @TotOffDays INT= 0;  
   WHILE @DateFrom <= @DateTo  
   BEGIN  
      IF DATENAME(WEEKDAY, @DateFrom) IN('Saturday', 'Sunday')  
      BEGIN  
         SET @TotOffDays = @TotOffDays + 1;  
      END  
      ELSE IF   EXISTS ( SELECT * FROM HolidayHeader AS h JOIN HolidayDetail AS d ON h.HolidayKey=d.HolidayKey   
               WHERE h.UserDefine01=@StorerKey AND h.UserDefine02='AutomailHoliday' AND convert(char(8),d.HolidayDate,112)=convert(char(8),@DateFrom,112) )  
      BEGIN  
         SET @TotOffDays = @TotOffDays + 1;  
      END  
  
      SET @DateFrom = DATEADD(DAY, 1, @DateFrom);  
   END;  
   RETURN @TotOffDays;  
END;  

GO