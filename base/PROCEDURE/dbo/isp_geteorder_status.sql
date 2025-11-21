SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetEOrder_Status                                    */
/* Creation Date: 05-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1719 - ECOM Nov 11 - Order Management screen            */
/*        :                                                             */
/* Called By: d_dw_eorder_status                                        */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_GetEOrder_Status]   
           @c_Storerkey        NVARCHAR(15)
         , @c_Facility         NVARCHAR(5)
         , @dt_StartDate       DATETIME = NULL
         , @dt_EndDate         DATETIME = NULL
         , @c_DateMode         NVARCHAR(10) = '' 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @n_UnReleased_Order   INT
         , @n_Released_Order     INT
         , @n_Total_Order        FLOAT
         , @n_UnReleased_pctg    INT

         , @c_SQL                NVARCHAR(MAX)
         , @c_SQLParms           NVARCHAR(MAX)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SET @n_UnReleased_Order = 0
   SET @n_Released_Order   = 0
   SET @n_Total_Order      = 0.00
   SET @n_UnReleased_pctg  = ''


   --IF @dt_OrderDate = CONVERT(DATETIME, '1900-01-01')
   --BEGIN
   --   SET @dt_OrderDate = NULL 
   --END

   SET @c_SQL = N'SELECT @n_UnReleased_Order = ISNULL(SUM(CASE WHEN ISNULL(RTRIM(ORDERS.Loadkey),'''') = '''' THEN 1 ELSE 0 END),0) '
              +  ',@n_Released_Order   = ISNULL(SUM(CASE WHEN ISNULL(RTRIM(ORDERS.Loadkey),'''') = '''' THEN 0 ELSE 1 END),0) '
              +  ',@n_Total_Order      = COUNT(1) ' 
              +  ' FROM ORDERS (NOLOCK) '
              +  ' WHERE Storerkey = @c_Storerkey '
              +  CASE WHEN @c_Facility = ''
                      THEN ''
                      ELSE ' AND ORDERS.Facility  = @c_Facility '
                      END
              +  CASE WHEN @c_DateMode = '1'
                      THEN ' AND ORDERS.AddDate   BETWEEN @dt_StartDate AND @dt_EndDate '
                      ELSE ' AND ORDERS.OrderDate BETWEEN @dt_StartDate AND @dt_EndDate ' 
                      END
              +  ' AND   Status < ''9'''

   SET @c_SQLParms = N'@c_Storerkey          NVARCHAR(15) '
                   + ',@c_Facility           NVARCHAR(5) '
                   + ',@dt_StartDate         DATETIME '
                   + ',@dt_EndDate           DATETIME '
                   + ',@n_UnReleased_Order   INT   OUTPUT '
                   + ',@n_Released_Order     INT   OUTPUT '
                   + ',@n_Total_Order        FLOAT OUTPUT '
 
   EXECUTE sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Storerkey
                        , @c_Facility
                        , @dt_StartDate
                        , @dt_EndDate
                        , @n_UnReleased_Order   OUTPUT
                        , @n_Released_Order     OUTPUT
                        , @n_Total_Order        OUTPUT

QUIT_SP:
   
   SELECT @n_UnReleased_Order
      ,   @n_Released_Order
      ,   @n_Total_Order
      ,   CASE WHEN @n_Total_Order > 0 THEN RTRIM(CONVERT(NVARCHAR(4), CEILING((@n_UnReleased_Order / @n_Total_Order) * 100))) + '%'
               ELSE '0%'
               END

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO