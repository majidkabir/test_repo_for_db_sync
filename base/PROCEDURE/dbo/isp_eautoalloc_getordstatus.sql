SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EAutoAlloc_GetOrdStatus                             */
/* Creation Date: 28-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4406 - ECOM Auto Allocation Dashboard                   */
/*        :                                                             */
/* Called By: d_dw_eautoalloc_ordstatus_form                            */
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
CREATE PROC [dbo].[isp_EAutoAlloc_GetOrdStatus]
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
           @n_StartTCnt    INT
         , @n_Continue     INT 

         , @n_OrdersAl     INT
         , @n_OrdersAll    FLOAT

         , @c_SQL          NVARCHAR(MAX)
         , @c_SQLParms     NVARCHAR(MAX)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SET @n_OrdersAl = 0
   SET @n_OrdersAll= 0.00

   SET @c_SQL = N'SELECT @n_OrdersAl = ISNULL(SUM(CASE WHEN ISNULL(RTRIM(ORDERS.Status),'''') >= ''2'' THEN 1 ELSE 0 END),0) '
              +        ',@n_OrdersAll= COUNT(1) ' 
              +  ' FROM ORDERS (NOLOCK) '
              +  ' WHERE Storerkey = @c_Storerkey '
              +  CASE WHEN @c_Facility = ''
                      THEN ''
                      ELSE ' AND ORDERS.Facility  = @c_Facility '
                      END
              + CASE  WHEN @c_DateMode = '1' 
                      THEN ' AND ORDERS.AddDate BETWEEN @dt_StartDate AND @dt_EndDate'   
                      ELSE ' AND ORDERS.OrderDate BETWEEN @dt_StartDate AND @dt_EndDate'
                      END
              +  ' AND ORDERS.Status IN (''0'',''1'',''2'',''3'',''5'',''9'')'

   SET @c_SQLParms = N'@c_Storerkey    NVARCHAR(15) '
                   + ',@c_Facility     NVARCHAR(5) '
                   + ',@dt_StartDate   DATETIME '
                   + ',@dt_EndDate     DATETIME '
                   + ',@n_OrdersAl     INT   OUTPUT '
                   + ',@n_OrdersAll    FLOAT OUTPUT '
 
   EXECUTE sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Storerkey
                        , @c_Facility
                        , @dt_StartDate
                        , @dt_EndDate
                        , @n_OrdersAl  OUTPUT
                        , @n_OrdersAll OUTPUT

QUIT_SP:
   
   SELECT OrdersAll = @n_OrdersAll
      ,   OrdersAll_text = 'Total Orders'
      ,   OrdersAll_color= 255         -- Red
      ,   OrdersAl  = @n_OrdersAl
      ,   OrdersAl_text  = 'Allocated'
      ,   OrdersAll_color= 32768       -- Green
      ,   OrdersAlPctg = CASE WHEN @n_OrdersAll > 0 
                              THEN RTRIM(CONVERT(NVARCHAR(10), CONVERT(NUMERIC(6,2),(@n_OrdersAl / (@n_OrdersAll * 1.0)) * 100))) + '%'
                              ELSE '0.00%'
                              END
      ,   OrdersAlPctg_text  = 'Allocated %'
      ,   OrdersAll_color= 12632256    -- Silver
   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO