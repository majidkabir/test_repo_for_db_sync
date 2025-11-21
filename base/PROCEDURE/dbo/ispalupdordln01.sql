SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispALUPDORDLN01                                    */
/* Creation Date: 03-Feb-2023                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19078 NIKE CN Only allow allocate mininum qty per set   */
/*          by load for prepack sku                                     */
/*                                                                      */
/* Called By: isp_AllocateUpd_OPORDERLINES_Wrapper                      */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 03-Feb-2023 NJOW     1.0   DEVOPS combine scirpt                     */
/************************************************************************/

CREATE   PROCEDURE dbo.ispALUPDORDLN01
   @c_Storerkey       NVARCHAR(15) = '',
   @c_Facility        NVARCHAR(5) = '',
   @c_Orderkey        NVARCHAR(10) = '', 
   @c_Loadkey         NVARCHAR(10) = '',
   @c_Wavekey         NVARCHAR(10) = '',
   @c_SourceType      NVARCHAR(30) = '',  --calling sp name
   @b_Success         INT = 1            OUTPUT,
   @n_Err             INT = 0            OUTPUT, 
   @c_ErrMsg          NVARCHAR(250) = '' OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTcnt       INT = @@TRANCOUNT
         , @c_Sku             NVARCHAR(15)
         , @n_NoneFullSetQty  INT
         , @c_OrderLineNumber NVARCHAR(5)
         , @n_OrdQty          INT

   SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''

   IF OBJECT_ID('tempdb..#OPORDERLINES','u') IS NULL  
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @c_SourceType <> 'ispWaveProcessing'
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @n_continue IN(1,2)
   BEGIN  	
   	  DECLARE CUR_SHORTALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT LPD.Loadkey, SKU.Sku, SUM(Qty) % SKU.PackQtyIndicator AS NoneFullSetQty
         FROM #OPORDERLINES OL         
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OL.OrderKey = OD.OrderKey AND OL.OrderLineNumber = OD.OrderLineNumber                     
         JOIN ORDERS SO (NOLOCK) ON SO.OrderKey = OD.OrderKey
         JOIN WAVEDETAIL WD (NOLOCK) ON SO.Orderkey = WD.Orderkey              
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON SO.Orderkey = LPD.Orderkey           
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku   
         WHERE WD.Wavekey = @c_Wavekey
         AND SKU.PrePackIndicator = '2'
         AND SKU.PackQtyIndicator > 0
         GROUP BY LPD.Loadkey, SKU.Sku, SKU.PackQtyIndicator
         HAVING SUM(OL.Qty) % SKU.PackQtyIndicator <> 0

      OPEN CUR_SHORTALLOC

      FETCH NEXT FROM CUR_SHORTALLOC INTO @c_Loadkey, @c_Sku, @n_NoneFullSetQty

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN   	
      	 DECLARE CUR_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	    SELECT OL.Orderkey, OL.OrderLineNumber, OL.Qty
            FROM #OPORDERLINES OL         
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON OL.OrderKey = OD.OrderKey AND OL.OrderLineNumber = OD.OrderLineNumber                     
            JOIN ORDERS SO (NOLOCK) ON SO.OrderKey = OD.OrderKey
            JOIN WAVEDETAIL WD (NOLOCK) ON SO.Orderkey = WD.Orderkey              
            JOIN LOADPLANDETAIL LPD (NOLOCK) ON SO.Orderkey = LPD.Orderkey           
            JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku   
            WHERE WD.Wavekey = @c_Wavekey
            AND SKU.Sku = @c_Sku
            AND LPD.Loadkey = @c_Loadkey
            ORDER BY CASE WHEN OL.Qty % SKU.PackQtyIndicator > 0 THEN 1 ELSE 2 END, OL.Qty, OL.OrderLineNumber
      	 
         OPEN CUR_ORDLINE

         FETCH NEXT FROM CUR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrdQty

         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2) AND @n_NoneFullSetQty > 0
         BEGIN   	
            IF @n_OrdQty <= @n_NoneFullSetQty
            BEGIN
               DELETE FROM #OPORDERLINES
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber
               
               SET @n_NoneFullSetQty = @n_NoneFullSetQty - @n_OrdQty
            END
            ELSE
            BEGIN
            	 UPDATE #OPORDERLINES
            	 SET Qty = Qty - @n_NoneFullSetQty
               WHERE Orderkey = @c_Orderkey
               AND OrderLineNumber = @c_OrderLineNumber
               
               SET @n_NoneFullSetQty = 0
            END
                           
            FETCH NEXT FROM CUR_ORDLINE INTO @c_Orderkey, @c_OrderLineNumber, @n_OrdQty
         END
         CLOSE CUR_ORDLINE
         DEALLOCATE CUR_ORDLINE
      	      	 
         FETCH NEXT FROM CUR_SHORTALLOC INTO @c_Loadkey, @c_Sku, @n_NoneFullSetQty
      END
      CLOSE CUR_SHORTALLOC
      DEALLOCATE CUR_SHORTALLOC      
   END
   
QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispALUPDORDLN01'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End Procedure

GO