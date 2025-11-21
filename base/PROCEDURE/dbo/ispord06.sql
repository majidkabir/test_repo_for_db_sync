SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD06                                           */
/* Creation Date: 31-Aug-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6214 CN UA Ship combine order update child order status */   
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
/* 23/11/2018   NJOW01   1.0  Performance Tuning.                       */
/************************************************************************/

CREATE PROC [dbo].[ispORD06]   
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
           @c_ChildOrderkey   NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5)  --NJOW01
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   IF @c_Action IN('UPDATE')
   BEGIN 
   	 --NJOW01 -S  	           	   	 
   	 IF NOT EXISTS(SELECT 1 
   	               FROM #INSERTED I
   	               JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
   	               WHERE O.Status = '9')
   	 BEGIN
   	    GOTO END_UPD
   	 END              
   	               
   	 IF NOT EXISTS(SELECT 1 
   	               FROM #INSERTED I
   	               JOIN ORDERDETAIL OD (NOLOCK) ON I.Orderkey = OD.Orderkey
   	               WHERE OD.ConsoOrderkey <> ''
   	               AND OD.ConsoOrderkey IS NOT NULL)
   	 BEGIN
   	    GOTO END_UPD
   	 END        
   	 --NJOW01 -E      
   	 
     DECLARE cur_shiporder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT CHILD.Orderkey
        FROM #INSERTED I 
	      JOIN #DELETED D ON I.Orderkey = D.Orderkey 
	      JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
	      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
	      JOIN ORDERS CHILD (NOLOCK) ON OD.ConsoOrderkey = CHILD.Orderkey
	      WHERE O.Status <> D.Status 
	      AND O.Status = '9'
	      AND I.Storerkey = @c_Storerkey
	      AND CHILD.Storerkey = @c_Storerkey

      OPEN cur_shiporder  
      
      FETCH NEXT FROM cur_shiporder INTO @c_ChildOrderkey
           
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 --NJOW01 -S
   	     DECLARE cur_orddet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	        SELECT OrderLineNumber
   	        FROM ORDERDETAIL (NOLOCK)   	        
       	    WHERE Orderkey = @c_ChildOrderkey
      	    AND Status NOT IN('9','CANC')

         OPEN cur_orddet  
       
         FETCH NEXT FROM cur_orddet INTO @c_OrderLineNumber
           
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
         BEGIN   	       
      	    UPDATE ORDERDETAIL WITH (ROWLOCK)
      	    SET Status = '9',      	          	 
      	        Trafficcop = NULL
      	    WHERE Orderkey = @c_ChildOrderkey
      	    AND OrderLineNumber = @c_OrderLineNumber
      	    --AND Status NOT IN('9','CANC')
            
            SET @n_err = @@ERROR    
            IF @n_err <> 0    
            BEGIN    
               SET @n_continue = 3    
               SET @n_err = 61900-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
               SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table ORDERDETAIL. (ispORD06)'            
            END   
            
            FETCH NEXT FROM cur_orddet INTO @c_OrderLineNumber
         END   
         CLOSE cur_orddet
         DEALLOCATE cur_orddet 	   	 	        	 
      	 --NJOW01 E
      	 
      	 UPDATE ORDERS WITH (ROWLOCK)
      	 SET Status = '9',
      	     SoStatus = '9',      	          	 
      	     Trafficcop = NULL
      	 WHERE Orderkey = @c_ChildOrderkey
      	 AND Status NOT IN('9','CANC')      	 

         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_err = 61910-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table ORDERS. (ispORD06)'            
         END    	   	 	  
      	       	 
         FETCH NEXT FROM cur_shiporder INTO @c_ChildOrderkey
	    END
	    CLOSE cur_shiporder
	    DEALLOCATE cur_shiporder
	  
	    END_UPD:	  
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD06'		
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