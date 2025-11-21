SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  fnc_GetBookingShiftByDate                                 */
/* Creation Date: 11-Jun-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Get booking Shift in description                            */
/*        : SOS#312513 - Add man hours to Booking View By Month.        */
/*                                                                      */
/* Called By:  Booking Module                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetBookingShiftByDate] ( 
      @c_Facility NVARCHAR(5) 
   ,  @d_Date     DATETIME 
   ,  @c_InOut    NVARCHAR(1)
) RETURNS NVARCHAR(80) AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE @n_Cnt          INT
         , @n_TotalHrs     DECIMAL(8,1) 
         , @n_TotalSingles INT
         , @d_FromDate     DATETIME  
         , @d_ToDate       DATETIME 
         , @c_Desc         NVARCHAR(80) 
         , @c_TotalHrs     NVARCHAR(8)
         

   SET @n_Cnt  = 1
   SET @c_Desc = ''
   SET @n_TotalSingles = 0
   SET @c_TotalHrs = ''

   IF NOT EXISTS  ( SELECT 1
                    FROM CODELKUP CL WITH (NOLOCK)
                    WHERE CL.ListName = 'BOOKSHIFT'
                  )
   BEGIN
      GOTO QUIT_FNC
   END    

   DECLARE @t_Shift TABLE 
      (  
         ShiftCode      NVARCHAR(30)  
      ,  ShiftStart     NVARCHAR(60) 
      ,  TotalHrs       DECIMAL(8,1)
      ,  TotalSingles   INT
      )

   SET @d_FromDate = CONVERT(Datetime, CONVERT(NVARCHAR(10), @d_Date, 101))   
   SET @d_ToDate   = DATEADD(mi,-1,DATEADD(dd,1,@d_Fromdate))
   SET @c_Desc = ''

   IF @c_InOut = 'I' 
   BEGIN
      INSERT INTO @t_Shift (ShiftCode, ShiftStart, TotalHrs, TotalSingles)
      SELECT CL.Code
            ,CL.UDF01
            ,SUM (CASE WHEN  CL.UDF01 < CL.UDF02 AND CONVERT(NVARCHAR(10),BI.BookingDate,108) BETWEEN CL.UDF01 AND CL.UDF02 
                       THEN  DATEDIFF(mi, CONVERT(NVARCHAR(10),BI.BookingDate,108), CONVERT(NVARCHAR(10),BI.EndTime,108))
                       WHEN  CL.UDF01 >  CL.UDF02 AND ( CONVERT(NVARCHAR(10),BI.BookingDate,108) >= CL.UDF01  
                             OR  CONVERT(NVARCHAR(10),BI.BookingDate,108) <= CL.UDF02 )
                       THEN  DATEDIFF(mi, CONVERT(NVARCHAR(10),BI.BookingDate,108), CONVERT(NVARCHAR(10),BI.EndTime,108)) 
                       ELSE 0
                       END) / 60.0
            ,SUM(CASE WHEN  CL.UDF01 < CL.UDF02 AND CONVERT(NVARCHAR(10),BI.BookingDate,108) BETWEEN CL.UDF01 AND CL.UDF02 
                       THEN  BI.Qty
                       WHEN  CL.UDF01 >  CL.UDF02 AND ( CONVERT(NVARCHAR(10),BI.BookingDate,108) >= CL.UDF01  
                             OR  CONVERT(NVARCHAR(10),BI.BookingDate,108) <= CL.UDF02 )
                       THEN  BI.Qty
                       ELSE 0
                       END)
      FROM BOOKING_IN BI WITH (NOLOCK)
      JOIN CODELKUP   CL WITH (NOLOCK) ON (CL.ListName = 'BOOKSHIFT')
      WHERE BI.Facility = @c_Facility
      AND BI.BookingDate BETWEEN @d_FromDate AND @d_ToDate
      GROUP BY CL.Code
            ,  CL.UDF01
    END
   ELSE
   BEGIN
      GOTO QUIT_FNC
--      INSERT INTO @t_Shift (ShiftCode, ShiftStart, TotalHrs, TotalSingles)
--      SELECT CL.Code
--            ,CL.UDF01
--            ,SUM (CASE WHEN  CL.UDF01 < CL.UDF02 AND CONVERT(NVARCHAR(10),BO.BookingDate,108) BETWEEN CL.UDF01 AND CL.UDF02 
--                       THEN  DATEDIFF(mi, CONVERT(NVARCHAR(10),BO.BookingDate,108), CONVERT(NVARCHAR(10),BO.EndTime,108))
--                       WHEN  CL.UDF01 >  CL.UDF02 AND ( CONVERT(NVARCHAR(10),BO.BookingDate,108) >= CL.UDF01  
--                             OR  CONVERT(NVARCHAR(10),BO.BookingDate,108) <= CL.UDF02 )
--                       THEN  DATEDIFF(mi, CONVERT(NVARCHAR(10),BO.BookingDate,108), CONVERT(NVARCHAR(10),BO.EndTime,108)) 
--                       ELSE 0
--                       END) / 60.0
--            ,0
--      FROM BOOKING_OUT BO WITH (NOLOCK)
--      JOIN CODELKUP   CL WITH (NOLOCK) ON (CL.ListName = 'BOOKSHIFT')
--      WHERE BO.Facility = @c_Facility
--      AND BO.BookingDate BETWEEN @d_FromDate AND @d_ToDate   
--      GROUP BY CL.Code
--            ,  CL.UDF01
   END
  
   DECLARE CUR_SHIFT CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT TotalHrs
         ,TotalSingles
   FROM @t_Shift
   ORDER BY ShiftStart
  
   OPEN CUR_SHIFT

   FETCH NEXT FROM CUR_SHIFT INTO @n_TotalHrs
                                 ,@n_TotalSingles   

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_TotalHrs = ''
      SET @c_TotalHrs = CASE WHEN @n_TotalHrs % 1 = 0 THEN CONVERT(VARCHAR(8), CONVERT (INT, @n_TotalHrs))
                             ELSE CONVERT(VARCHAR(8),@n_TotalHrs) END 

      SET @c_Desc = @c_Desc + CASE WHEN @c_Desc = '' THEN '  ' ELSE ', ' END  
                  + CASE WHEN @n_Cnt % 3 = 0 THEN CHAR(10) + '  ' ELSE '' END +  
                  + 'S' + CONVERT(VARCHAR(2), @n_Cnt) + '-' + CONVERT(VARCHAR(8),@n_TotalSingles)

--      SET @c_Desc = @c_Desc + CASE WHEN @c_Desc = '' THEN '  ' ELSE ', ' END  
--                  + CASE WHEN @n_Cnt % 3 = 0 THEN CHAR(10) + '  ' ELSE '' END +  
--                  + 'S' + CONVERT(VARCHAR(2), @n_Cnt) + '-' + @c_TotalHrs --CONVERT(VARCHAR(8),@n_TotalHrs)

--      SET  @c_Desc = @c_Desc + '  ' --CASE WHEN @c_Desc = '' THEN '  ' ELSE ', ' END  
--                   + 'S' + CONVERT(VARCHAR(2), @n_Cnt) + '-' + @c_TotalHrs + 'h, ' 
--                   + CONVERT(VARCHAR(8),@n_TotalSingles) + 's' + CHAR(10)
      SET @n_Cnt = @n_Cnt + 1
      FETCH NEXT FROM CUR_SHIFT INTO @n_TotalHrs
                                    ,@n_TotalSingles   
   END
   CLOSE CUR_SHIFT
   DEALLOCATE CUR_SHIFT


   QUIT_FNC:
   RETURN @c_Desc
END

GO