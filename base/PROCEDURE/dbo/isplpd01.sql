SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispLPD01                                           */
/* Creation Date: 16-MAY-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1707 SG UNITY update loadplan OTM_Dispatchdate          */   
/*          and externloadkey from orders                               */
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/

CREATE PROC [dbo].[ispLPD01]   
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
           @c_Loadkey         NVARCHAR(10), 
           @dt_deliverydate   DATETIME, 
           @c_Consigneekey    NVARCHAR(15)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
	 IF @c_Action IN('INSERT') 
	 BEGIN	 		 	
      DECLARE Cur_LoadPlan CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	 	     SELECT I.Loadkey, MAX(O.DeliveryDate), MAX(O.Consigneekey)
	 	     FROM #INSERTED I 
	 	     JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
	 	     JOIN LOADPLAN LP (NOLOCK) ON I.Loadkey = LP.Loadkey
	 	     WHERE O.Storerkey = @c_Storerkey	 	    
         AND (LP.Externloadkey = '' OR LP.Externloadkey IS NULL 
	 	       OR LP.OTM_DispatchDate IS NULL OR CONVERT(NVARCHAR(10), LP.OTM_DispatchDate , 103) = '01/01/1900')
	 	     GROUP BY I.Loadkey
	 	  
      OPEN Cur_LoadPlan
	    
	    FETCH NEXT FROM Cur_LoadPlan INTO @c_Loadkey, @dt_deliverydate, @c_Consigneekey
            
	    WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
	    BEGIN
	    	
	    	 UPDATE LOADPLAN WITH (ROWLOCK)
	    	 SET OTM_DispatchDate = @dt_DeliveryDate,
	    	     ExternLoadkey = @c_Consigneekey,
	    	     Trafficcop = NULL
	    	 WHERE Loadkey = @c_Loadkey

         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table LOADPLAN. (ispLPD01)'            
         END    	   	 	  
	    	
   	     FETCH NEXT FROM Cur_LoadPlan INTO @c_Loadkey, @dt_deliverydate, @c_Consigneekey
	    END
	    CLOSE Cur_LoadPlan
	    DEALLOCATE Cur_LoadPlan
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispLPD01'		
	    --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
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