SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPKD03                                           */
/* Creation Date: 29-Apr-2015                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 357402-CN-Inditex-unallocate set orderdetail.qtytoprocess=0 */   
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
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

CREATE PROC [dbo].[ispPKD03]   
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
     
   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
   
	 IF @c_Action = 'DELETE'
	 BEGIN
	 	  UPDATE ORDERDETAIL WITH (ROWLOCK)
	 	  SET ORDERDETAIL.QtyToProcess = 0,
	 	      TrafficCop = NULL,
	 	      EditWho = SUSER_SNAME(),
	 	      EditDate = GETDATE()	 	   
	 	  FROM ORDERDETAIL
	 	  JOIN #DELETED ON #DELETED.Orderkey = ORDERDETAIL.Orderkey 
	 	                   AND #DELETED.OrderLineNumber = ORDERDETAIL.OrderLineNumber
	 	  WHERE NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK) WHERE PD.Orderkey = #DELETED.Orderkey AND PD.OrderLineNumber = #DELETED.OrderLineNumber)
	 	  AND ORDERDETAIL.QtyToProcess > 0
	 	  
	    SET @n_Err = @@ERROR
	                       
      IF @n_Err <> 0
      BEGIN
      	 SELECT @n_Continue = 3 
	       SELECT @n_Err = 38020
	       SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERDETAIL Failed. (ispPKD03)'
         GOTO QUIT_SP 
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKD03'		
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