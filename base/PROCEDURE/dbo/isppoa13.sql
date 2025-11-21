SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPOA13                                           */  
/* Creation Date: 19-Mar-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-12563 PH Adidas unallocate partial allocated case       */
/*                                                                      */  
/* Called By: StorerConfig.ConfigKey = PostAllocationSP                 */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispPOA13]    
     @c_OrderKey    NVARCHAR(10) = '' 
   , @c_LoadKey     NVARCHAR(10) = ''
   , @c_Wavekey     NVARCHAR(10) = ''
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT    
   , @b_debug       INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF         
    
   DECLARE  @n_Continue              INT,    
            @n_StartTCnt             INT, -- Holds the current transaction count
            @c_Pickdetailkey         NVARCHAR(10),
            @c_Orderkey2             NVARCHAR(10),
            @c_Lottable10            NVARCHAR(30)
                                                                          
   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''  
          
   IF @n_continue IN(1,2) 
   BEGIN   	         
      DECLARE cur_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT O.Orderkey, OD.Lottable10
   	     FROM ORDERS O (NOLOCK)
   	     JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   	     LEFT JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
         LEFT JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.orderkey = LPD.Orderkey
         OUTER APPLY (SELECT SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable 
                      FROM LOTXLOCXID LLI (NOLOCK) 
                      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                      WHERE LLI.Storerkey = OD.Storerkey 
                      AND LA.Lottable10 = OD.Lottable10) INV
         WHERE (LPD.Loadkey = @c_Loadkey OR ISNULL(@c_Loadkey,'') = '')
         AND (WD.Wavekey = @c_Wavekey OR ISNULL(@c_Wavekey,'') = '')
         AND (O.Orderkey = @c_Orderkey OR ISNULL(@c_Orderkey,'') = '')
         AND OD.Lottable10 <> '' 
         AND OD.Lottable10 IS NOT NULL
         GROUP BY O.Orderkey, OD.Lottable10, ISNULL(INV.QtyAvailable,0)
         HAVING SUM(OD.OpenQty - OD.Qtyallocated - OD.QtyPicked) > 0 OR SUM(OD.OpenQty - OD.QtyAllocated + OD.QtyPicked) < ISNULL(INV.QtyAvailable,0)
         ORDER BY O.Orderkey
      
      OPEN cur_ORD  
          
      FETCH NEXT FROM cur_ORD INTO @c_Orderkey2, @c_Lottable10
          
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN      	 
      	 DECLARE cur_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      	    SELECT PD.Pickdetailkey
      	    FROM ORDERDETAIL OD (NOLOCK)
      	    JOIN PICKDETAIL PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLinenUmber
      	    WHERE OD.Orderkey = @c_Orderkey2
      	    AND OD.Lottable10 = @c_Lottable10
      	    
         OPEN cur_PICK  
          
         FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey
          
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN      	          	
         	  DELETE FROM PICKDETAIL
         	  WHERE Pickdetailkey = @c_Pickdetailkey
         
            SET @n_err = @@ERROR
         
            IF @n_err <> 0                                                                                                                                                             
            BEGIN                                                                                                                                                                                
               SELECT @n_Continue = 3                                                                                                                                                            
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                          
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PICKDETAIL table failed. (ispPOA13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            END

            FETCH NEXT FROM cur_PICK INTO @c_Pickdetailkey         
         END
         CLOSE cur_PICK
         DEALLOCATE cur_PICK                                                                 
                             	
         FETCH NEXT FROM cur_ORD INTO @c_Orderkey2, @c_Lottable10
      END
      CLOSE cur_ORD
      DEALLOCATE cur_ORD      
   END
         
EXIT_SP:
    
   IF @n_Continue=3  -- Error Occured - Process And Return    
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA13'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
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
    
END -- Procedure  

GO