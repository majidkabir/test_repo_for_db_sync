SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Function:  fnc_GetLastWorkDay                                        */
/* Creation Date: 17-June-2019                                          */
/* Copyright: LF                                                        */
/* Written by: linklin                                                  */
/*                                                                      */
/* Purpose: 337773-Get last working day exclude holiday / weekend       */
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
/* Date         Author   Ver. Purposes                                  */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetLastWorkDay] ( 
   @dt_Date      DATETIME,
   @c_excludeSAT NVARCHAR(1),
   @c_excludeSUN NVARCHAR(1)
) RETURNS DATETIME AS
BEGIN
  SET QUOTED_IDENTIFIER OFF

  DECLARE @c_done NVARCHAR(1)
        
  SELECT @c_done = 'N'
  
  WHILE @c_done = 'N'
  BEGIN
    	IF EXISTS (SELECT 1 FROM HolidayDetail(NOLOCK) WHERE DATEDIFF(DAY, @dt_date, HolidayDate) = 0)
	       OR 7 = CASE WHEN @c_excludeSAT = 'Y' THEN DATEPART(DW, @dt_date) ELSE 0 END
	       OR 1 = CASE WHEN @c_excludeSUN = 'Y' THEN DATEPART(DW, @dt_date) ELSE 0 END 
	          SELECT @dt_date = DATEADD(DAY, -1, @dt_date) 
	    ELSE   	    	
	          SET @c_done = 'Y'
  END
  
  RETURN @dt_Date
END

GO