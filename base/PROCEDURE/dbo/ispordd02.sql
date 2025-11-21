SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO



/************************************************************************/
/* Stored Procedure: ispORDD02                                          */
/* Creation Date: 14-Jan-2025                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: FCR-2296 HILLSAU auto update order qty to be multiples of   */
/*          case qty as per customer requirement                        */   
/*                                                                      */
/* Called By: isp_OrderdetailTrigger_Wrapper from Orderdetail Trigger   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2025-01-14  YWA059   1.0   FCR-2296 HILLSAU auto update order qty    */
/************************************************************************/
CREATE        PROC [dbo].[ispORDD02]     
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_OrderKey        NVARCHAR(10), 
           @c_OrderLineNumber NVARCHAR(5), 
           @n_OpenQty         INT
         , @n_QtyAlloc        INT = 0                                               
         , @c_OrdLineNo_Orig  NVARCHAR(5) = ''                                      
		 , @c_sku             NVARCHAR(30)
		 , @n_cnt             int
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END     

   IF @c_Action IN('INSERT') 
   BEGIN
		IF EXISTS (SELECT  1
					FROM dbo.ORDERDETAIL OD (NOLOCK)
					INNER JOIN SKU (NOLOCK) ON OD.Sku = SKU.SKU AND OD.StorerKey = SKU.StorerKey
					INNER JOIN PACK P (NOLOCK) ON SKU.PACKKey = P.PackKey  
					INNER JOIN #INSERTED I ON I.Orderkey = OD.Orderkey AND I.OrderLineNumber = OD.OrderLineNumber
					WHERE OD.StorerKey = @c_Storerkey
					AND OD.Status < '9'
					AND OD.OpenQty%convert(INT, P.CaseCnt) > 0
                  )             
		BEGIN
			DECLARE CUR_ORDERKEY_Insert CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT DISTINCT OD.OrderKey,OD.OrderLineNumber,OD.SKU
			FROM dbo.ORDERDETAIL OD (NOLOCK)
			INNER JOIN SKU (NOLOCK) ON OD.Sku = SKU.SKU AND OD.StorerKey = SKU.StorerKey
			INNER JOIN PACK P (NOLOCK) ON SKU.PACKKey = P.PackKey  
			INNER JOIN #INSERTED I ON I.Orderkey = OD.Orderkey AND I.OrderLineNumber = OD.OrderLineNumber
			WHERE OD.StorerKey = @c_Storerkey
			AND OD.Status < '9'
			AND OD.OpenQty%convert(INT, P.CaseCnt) > 0

			OPEN CUR_ORDERKEY_Insert

			FETCH NEXT FROM CUR_ORDERKEY_Insert INTO @c_OrderKey, @c_OrderLineNumber, @c_sku
			WHILE @@FETCH_STATUS = 0
			BEGIN
				UPDATE OD WITH (ROWLOCK)
				SET OD.OriginalQty = (OD.OpenQty - OD.OpenQty%convert(INT, P.CaseCnt))
				  , OD.OpenQty = (OD.OpenQty - OD.OpenQty%convert(INT, P.CaseCnt))
				FROM dbo.ORDERDETAIL AS OD 
				INNER JOIN SKU (NOLOCK) ON OD.Sku = SKU.SKU AND OD.StorerKey = SKU.StorerKey
				INNER JOIN PACK P (NOLOCK) ON SKU.PACKKey = P.PackKey
				WHERE OD.OrderKey = @c_OrderKey
				  AND OD.OrderLineNumber = @c_OrderLineNumber
				  --AND OD.Sku = @c_sku
           
			   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
			   IF @n_err <> 0
			   BEGIN
				   SET @n_continue = 3
				   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 81030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail.Qty Failed. (ispORDD02)'
						   + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
			   END

        		FETCH NEXT FROM CUR_ORDERKEY_Insert INTO @c_OrderKey, @c_OrderLineNumber, @c_sku
			END
			CLOSE CUR_ORDERKEY_Insert
			DEALLOCATE CUR_ORDERKEY_Insert
		END
   END
   
   IF @c_Action IN('UPDATE') 
   BEGIN
		IF EXISTS (SELECT  1
					FROM dbo.ORDERDETAIL OD (NOLOCK)
					INNER JOIN SKU (NOLOCK) ON OD.Sku = SKU.SKU AND OD.StorerKey = SKU.StorerKey
					INNER JOIN PACK P (NOLOCK) ON SKU.PACKKey = P.PackKey
					INNER JOIN #INSERTED I ON I.Orderkey = OD.Orderkey AND I.OrderLineNumber = OD.OrderLineNumber
					INNER JOIN #DELETED D ON I.Orderkey = D.Orderkey AND I.OrderLineNumber = D.OrderLineNumber
					WHERE OD.StorerKey = @c_Storerkey
					  AND OD.Status < '9'
					  AND OD.OpenQty%convert(INT, P.CaseCnt) > 0
                  )             
		BEGIN
			DECLARE CUR_ORDERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT DISTINCT OD.OrderKey,OD.OrderLineNumber,OD.SKU
			FROM dbo.ORDERDETAIL OD (NOLOCK)
			INNER JOIN SKU (NOLOCK) ON OD.Sku = SKU.SKU AND OD.StorerKey = SKU.StorerKey
			INNER JOIN PACK P (NOLOCK) ON SKU.PACKKey = P.PackKey
			INNER JOIN #INSERTED I ON I.Orderkey = OD.Orderkey AND I.OrderLineNumber = OD.OrderLineNumber
			INNER JOIN #DELETED D ON I.Orderkey = D.Orderkey AND I.OrderLineNumber = D.OrderLineNumber
			WHERE OD.StorerKey = @c_Storerkey
			  AND OD.Status < '9'
			  AND OD.OpenQty%convert(INT, P.CaseCnt) > 0
	   
			OPEN CUR_ORDERKEY
	
			FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @c_OrderLineNumber, @c_sku
			WHILE @@FETCH_STATUS = 0
			BEGIN
			   UPDATE OD WITH (ROWLOCK)
				SET OD.OriginalQty = (OD.OpenQty - OD.OpenQty%convert(INT, P.CaseCnt))
				  , OD.OpenQty = (OD.OpenQty - OD.OpenQty%convert(INT, P.CaseCnt))
				FROM dbo.ORDERDETAIL AS OD 
				INNER JOIN SKU (NOLOCK) ON OD.Sku = SKU.SKU AND OD.StorerKey = SKU.StorerKey
				INNER JOIN PACK P (NOLOCK) ON SKU.PACKKey = P.PackKey
			   WHERE OD.OrderKey = @c_OrderKey
				 AND OD.OrderLineNumber = @c_OrderLineNumber
				 --AND OD.Sku = @c_sku

				SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
				IF @n_err <> 0
				BEGIN
				   SET @n_continue = 3
				   SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
				   SET @n_err = 81030
				   SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Orderdetail.Qty Failed. (ispORDD02)'
						   + '( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
				END
        		FETCH NEXT FROM CUR_ORDERKEY INTO @c_OrderKey, @c_OrderLineNumber, @c_sku
			END
			CLOSE CUR_ORDERKEY
			DEALLOCATE CUR_ORDERKEY
		END
   END

 

   QUIT_SP:
   
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORDD02'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  


GO