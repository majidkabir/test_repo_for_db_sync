SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_BuildLoad03                                             */
/* Creation Date: 03-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: SKECHER DOUBLE 11                                           */
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
/* 11-Oct-2018  Wan01     (Fixed) - Start - Let the PickZone filering on*/
/*                        calling SP as this custom SP to RETURN order  */ 
/*                        with single/multi pickzone(isp_Build_Loadplan)*/
/* 17-Jul-2019  NJOW01    WMS-9551 add new param n_NoOfOrderToRelease   */
/************************************************************************/
CREATE PROC [dbo].[isp_BuildLoad03] 
            @c_Facility       NVARCHAR(5)
         ,  @c_Storerkey      NVARCHAR(15)
         ,  @c_ParmCode       NVARCHAR(10)
         ,  @c_ParmCodeCond   NVARCHAR(4000)
         ,  @c_Parm01         NVARCHAR(50) = '' -- 'M' - Multi PickZone
         ,  @c_Parm02         NVARCHAR(50) = ''
         ,  @c_Parm03         NVARCHAR(50) = ''
         ,  @c_Parm04         NVARCHAR(50) = ''
         ,  @c_Parm05         NVARCHAR(50) = ''
         ,  @dt_StartDate     DATETIME     = NULL  -- (Wan02)
         ,  @dt_EndDate       DATETIME     = NULL  -- (Wan02)
         ,  @n_NoOfOrderToRelease INT      = 0     --NJOW01         
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
              + ' JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)'
              + ' JOIN LOC    WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)'
              + ' WHERE ORDERS.Facility  = @c_Facility'
              + ' AND   ORDERS.Storerkey = @c_Storerkey'
              + ' AND   ORDERS.Status < ''9'''
              + ' AND  (ORDERS.Loadkey IS NULL OR ORDERS.Loadkey = '''')'
              + ' AND   ORDERS.OpenQty > 1'  

   SET @c_SQLGroupBy = N' GROUP BY ORDERS.Orderkey'
                     + CASE WHEN @c_Parm01 = 'M' 
                            THEN ' HAVING COUNT(DISTINCT LOC.PickZone) > 1'
                            ELSE ' HAVING COUNT(DISTINCT LOC.PickZone) = 1'
                            END
   SET @c_SQLOrderBy = N' ORDER BY ORDERS.Orderkey'

   --(Wan01) - START
   --IF @c_ParmCodeCond <> ''
   --BEGIN
   --   SET @c_SQL =  @c_SQL + @c_ParmCodeCond
   --END 
   --(Wan01) - End

   SET @c_SQL =  @c_SQL + @c_SQLGroupBy + @c_SQLOrderBy


   BEGIN TRAN
   
   INSERT INTO #TMP_ORDERS 
         (  Orderkey    )  
   EXEC sp_executesql @c_SQL
         , N'@c_Facility NVARCHAR(5), @c_Storerkey NVARCHAR(15), @dt_StartDate DATETIME, @dt_EndDate DATETIME'
         , @c_Facility
         , @c_Storerkey
         , @dt_StartDate
         , @dt_EndDate     
 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BuildLoad03'
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