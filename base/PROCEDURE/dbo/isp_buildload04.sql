SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_BuildLoad04                                             */
/* Creation Date: 23-MAY-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-9147 - TH-NIKE enhance Build Load for Auto delete Orders*/
/*        :                                                             */
/* Called By:isp_Build_Loadplan                                         */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_BuildLoad04] 
            @c_Facility       NVARCHAR(5)
         ,  @c_Storerkey      NVARCHAR(15)
         ,  @c_ParmCode       NVARCHAR(10)
         ,  @c_ParmCodeCond   NVARCHAR(4000)
         ,  @c_Parm01         NVARCHAR(50) = ''
         ,  @c_Parm02         NVARCHAR(50) = ''
         ,  @c_Parm03         NVARCHAR(50) = ''
         ,  @c_Parm04         NVARCHAR(50) = ''
         ,  @c_Parm05         NVARCHAR(50) = ''
         ,  @dt_StartDate     DATETIME     = NULL
         ,  @dt_EndDate       DATETIME     = NULL
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT 
         , @n_err             INT 
         , @c_errmsg          NVARCHAR(255)  

         , @c_SQL             NVARCHAR(4000)
         , @c_SQLGroupBy      NVARCHAR(4000)
         , @c_SQLOrderBy      NVARCHAR(4000)

         , @b_Debug           BIT
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @b_Debug = 0
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
   BEGIN
      CREATE TABLE #TMP_ORDERS
      (  RowNo       BIGINT   IDENTITY(1,1)  Primary Key 
      ,  Orderkey    NVARCHAR(10)   NULL
      )
      SET @b_Debug = 1
   END


   SET @c_SQL = N'SELECT ORDERS.Orderkey'
              + ' FROM ORDERS WITH (NOLOCK)'
              + ' WHERE ORDERS.Facility  = @c_Facility'
              + ' AND   ORDERS.Storerkey = @c_Storerkey'
              + ' AND   ORDERS.Status = ''0'''
              + ' AND  (ORDERS.Loadkey IS NULL OR ORDERS.Loadkey = '''')'
              + ' AND   ORDERS.SOStatus <> ''PENDING'' ' 
              + ' AND   ORDERS.SOStatus NOT IN (SELECT CODELKUP.Code  
                                                FROM CODELKUP WITH (NOLOCK) 
                                                WHERE CODELKUP.Listname = ''LBEXCSOSTS''
                                                AND CODELKUP.Storerkey = ORDERS.Storerkey) '
              + ' AND   ORDERS.ConsigneeKey NOT IN (SELECT CODELKUP.Code  
                                                    FROM CODELKUP WITH (NOLOCK) 
                                                    WHERE CODELKUP.Listname = ''NIKEOUTLET''
                                                    AND CODELKUP.Storerkey = ORDERS.Storerkey) '

   SET @c_SQLGroupBy = N' GROUP BY ORDERS.Orderkey'
                    
   SET @c_SQLOrderBy = N' ORDER BY ORDERS.Orderkey'

   SET @c_SQL =  @c_SQL + @c_SQLGroupBy + @c_SQLOrderBy

   BEGIN TRAN
   
   INSERT INTO #TMP_ORDERS 
         (  Orderkey    )  
   EXEC sp_executesql @c_SQL
         , N'@c_Facility NVARCHAR(5), @c_Storerkey NVARCHAR(15)'
         , @c_Facility
         , @c_Storerkey   
 
QUIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT Orderkey
      FROM #TMP_ORDERS
   END

   IF OBJECT_ID('tempdb..#TMP_ORDERSSKU','u') IS NOT NULL
   DROP TABLE #TMP_ORDERSSKU;

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BuildLoad04'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO