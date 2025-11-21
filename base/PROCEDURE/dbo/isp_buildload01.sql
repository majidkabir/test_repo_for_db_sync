SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_BuildLoad01                                             */
/* Creation Date: 21-JUL-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#373149 - TH-MFG Auto assign Order to LoadPlan           */
/*        :                                                             */
/* Called By:isp_Build_Loadplan                                         */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 04-MAY-2018  Wan01   1.1   Insert into #TMP_ORDER in this Sub-SP     */
/* 26-SEP-2018  Wan02   1.1   ADD Parameters - Start & End Date         */
/* 17-Jul-2019  NJOW01  1.2   WMS-9551 add new param n_NoOfOrderToRelease*/
/************************************************************************/
CREATE PROC [dbo].[isp_BuildLoad01] 
            @c_Facility       NVARCHAR(5)
         ,  @c_Storerkey      NVARCHAR(15)
         ,  @c_ParmCode       NVARCHAR(10)
         ,  @c_ParmCodeCond   NVARCHAR(4000)
         ,  @c_Parm01         NVARCHAR(50) = ''
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

         , @c_SQL                NVARCHAR(4000)
         , @c_SQLOrderBy         NVARCHAR(4000)
         , @n_OriginalQty        INT
         , @n_FreeGoodQty        INT
         , @c_Orderkey           NVARCHAR(10)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @dt_LoadDeliveryDate  DATETIME
         , @dt_DeliveryDate      DATETIME
         , @dt_MinLeadDate       DATETIME
         , @dt_MaxLeadDate       DATETIME
         , @dt_LeadDate          DATETIME
         , @dt_today             DATETIME

         , @b_Debug              BIT      --(Wan01)
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @dt_today   = CONVERT (NVARCHAR(10), GETDATE(), 112)

   --(Wan01) - START  -- create if run this SP to test
   SET @b_Debug = 0
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
   BEGIN
      CREATE TABLE #TMP_ORDERS
      (  RowNo       BIGINT   IDENTITY(1,1)  Primary Key 
      ,  Orderkey    NVARCHAR(10)   NULL
      )
      SET @b_Debug = 1
   END
   --(Wan01) - END

   SET @c_SQL = N'DECLARE CUR_ORD CURSOR FAST_FORWARD READ_ONLY FOR'
              + ' SELECT ORDERS.Orderkey' 
              +        ',DeliveryDate = CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,112)'
              + ' FROM   ORDERS WITH (NOLOCK)'
              + ' WHERE  ORDERS.Facility = N'''  + RTRIM(@c_Facility)  + ''''
              + ' AND    ORDERS.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''
              + ' AND    ORDERS.Status < ''9'''
              + ' AND   (ORDERS.Loadkey IS NULL OR ORDERS.Loadkey = '''')'
  
   SET @c_SQLOrderBy = ' ORDER BY 2,1'

   IF @c_Parm01 <> ''
   BEGIN
      SET @c_SQL =  @c_SQL + ' AND ORDERS.UserDefine01 = N''' + RTRIM(@c_Parm01) + '''' 
   END 

   IF @c_ParmCodeCond <> ''
   BEGIN
      SET @c_SQL =  @c_SQL + @c_ParmCodeCond
   END 

   SET @c_SQL =  @c_SQL + @c_SQLOrderBy

   BEGIN TRAN
   
   EXEC (@c_SQL)  

   OPEN CUR_ORD
   
   FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
                              , @dt_DeliveryDate 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @dt_LoadDeliveryDate IS NOT NULL AND @dt_LoadDeliveryDate <> @dt_DeliveryDate
      BEGIN
         GOTO QUIT_SP 
      END
        
      IF EXISTS ( SELECT 1
                  FROM ORDERDETAIL WITH (NOLOCK)
                  JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                         AND(ORDERDETAIL.Sku = SKU.Sku) 
                  WHERE ORDERDETAIL.OrderKey = @c_Orderkey 
                  AND   ISNUMERIC(SKU.Class) = 0
                )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60010 
         SET @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Invalid Lead Time. (isp_BuildLoad01)' 

         GOTO QUIT_SP
      END
              
      SELECT @dt_MinLeadDate =  ISNULL(MIN(DATEADD(dd, SKU.Class - 1, @dt_today)), '1900-01-01')
            ,@dt_MaxLeadDate =  ISNULL(MAX(DATEADD(dd, SKU.Class - 1, @dt_today)), '1900-01-01')
      FROM ORDERDETAIL WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                             AND(ORDERDETAIL.Sku = SKU.Sku) 
      WHERE ORDERDETAIL.OrderKey = @c_Orderkey 
                             
      IF @dt_MinLeadDate > @dt_DeliveryDate -- Overdue
      BEGIN 
         UPDATE ORDERS WITH (ROWLOCK)
         SET SOStatus = 'CANC'
            ,Status   = 'CANC'
            ,Notes2   = 'OVER DUE ORDER'
            ,EditDate = GETDATE()
            ,EditWho  = SUSER_NAME()
         WHERE Orderkey = @c_Orderkey

         IF @@ERROR <> 0    
         BEGIN    
            SET @n_continue = 3
            SET @n_err = 60020 
            SET @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': UPDATE ORDERS Fail. (isp_BuildLoad01)'           
            GOTO QUIT_SP   
         END  
         GOTO NEXT_ORD  
      END                                

      IF @dt_MaxLeadDate < @dt_DeliveryDate -- Not due
      BEGIN 
         GOTO NEXT_ORD  
      END 

      DECLARE CUR_ORDDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderLineNumber
            ,OriginalQty
            ,FreeGoodQty
            ,LeadDate = DATEADD(dd, SKU.Class - 1, @dt_today)
      FROM   ORDERDETAIL WITH (NOLOCK)
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                             AND(ORDERDETAIL.Sku = SKU.Sku) 
      WHERE  ORDERDETAIL.Orderkey = @c_Orderkey
      AND    @dt_MaxLeadDate <> @dt_DeliveryDate
      ORDER BY 2 DESC
 
      OPEN CUR_ORDDET

      FETCH NEXT FROM CUR_ORDDET INTO @c_OrderLineNumber
                                    , @n_OriginalQty
                                    , @n_FreeGoodQty
                                    , @dt_LeadDate
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @dt_LeadDate > @dt_DeliveryDate -- Overdue
         BEGIN
            SET @n_FreeGoodQty = @n_OriginalQty
            SET @n_OriginalQty = 0

            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET OriginalQty = @n_OriginalQty
               ,FreeGoodQty = @n_FreeGoodQty
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_NAME()
            WHERE Orderkey = @c_Orderkey
            AND   OrderLineNumber = @c_OrderLineNumber
         
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_continue = 3
               SET @n_err = 60030 
               SET @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': UPDATE ORDERDETAIL Fail. (isp_BuildLoad01)'           
               GOTO QUIT_SP   
            END  
         END

         FETCH NEXT FROM CUR_ORDDET INTO @c_OrderLineNumber
                                       , @n_OriginalQty
                                       , @n_FreeGoodQty
                                       , @dt_LeadDate
      END
      CLOSE CUR_ORDDET
      DEALLOCATE CUR_ORDDET 

      INSERT INTO #TMP_ORDERS
      VALUES (@c_Orderkey)

      IF @dt_LoadDeliveryDate IS NULL 
      BEGIN
         SET @dt_LoadDeliveryDate = @dt_DeliveryDate
      END 

      NEXT_ORD:
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
                                 , @dt_DeliveryDate 
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD 
QUIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT Orderkey
      FROM #TMP_ORDERS
   END

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_ORD') in (0 , 1)  
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ORDDET') in (0 , 1)  
   BEGIN
      CLOSE CUR_ORDDET
      DEALLOCATE CUR_ORDDET
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BuildLoad01'
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