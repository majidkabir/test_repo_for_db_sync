SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_THGSG_UpdOrderJob                              */  
/* Creation Date: 28-Aug-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-10369 SG THG Update order job                           */  
/*                                                                      */  
/* Called By: Packing                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_THGSG_UpdOrderJob]  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue        INT 
          ,@n_StartTCnt       INT 
          ,@n_Err             INT           
          ,@c_ErrMsg          NVARCHAR(255)       
          ,@c_Storerkey       NVARCHAR(15)
          ,@c_Orderkey        NVARCHAR(10)   
          ,@c_SpecialHandling NVARCHAR(1)

   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Err     = 0  
   SET @c_ErrMsg  = ''
   SET @c_Storerkey = 'THGSG'
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR               
         SELECT O.Orderkey,
                O.SpecialHandling
         FROM ORDERS O (NOLOCK)
         LEFT JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
         WHERE O.Status = '0'
         AND O.SOStatus <> 'CANC'
         AND O.OrderGroup = 'MULTI'
         AND O.Storerkey = @c_Storerkey
         AND WD.Orderkey IS NULL
         ORDER BY O.Orderkey
                              
      OPEN CUR_ORD   
      
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_SpecialHandling
      
      WHILE @@FETCH_STATUS <> -1  
      BEGIN      	                                  
         IF EXISTS(SELECT 1
                   FROM ORDERS (NOLOCK)
                   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey
                   JOIN SKU (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku
                   WHERE ORDERS.Orderkey = @c_Orderkey
                   HAVING COUNT(ORDERDETAIL.Sku) = SUM(CASE WHEN SKU.BUSR10 = 'PBO' THEN 1 ELSE 0 END))
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
            SET SpecialHandling = 'X',               
                TrafficCop = NULL
            WHERE Orderkey = @c_Orderkey         	 

      	    SELECT @n_err = @@ERROR
      	    
      	    IF @n_err <> 0
      	    BEGIN
               SET @n_continue = 3
               SET @n_err = 63500   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Orders Table Failed! (isp_THGSG_UpdOrderJob)' + '( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		   	    END
         END 
         ELSE IF ISNULL(@c_Specialhandling,'') <> ''
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
            SET SpecialHandling = '',
                TrafficCop = NULL            
            WHERE Orderkey = @c_Orderkey

      	    SELECT @n_err = @@ERROR
      	    
      	    IF @n_err <> 0
      	    BEGIN
               SET @n_continue = 3
               SET @n_err = 63510   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Update Orders Table Failed! (isp_THGSG_UpdOrderJob)' + '( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
		   	    END
         END
                         	       	
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_SpecialHandling
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END
                    
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_THGSG_UpdOrderJob'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END  

GO