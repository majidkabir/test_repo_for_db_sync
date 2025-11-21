SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispREC01                                           */
/* Creation Date: 08-Apr-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 367922-SG-TradeNet Integration                              */   
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

CREATE PROC [dbo].[ispREC01]   
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
           @n_StartTCnt    INT,
           @c_Receiptkey   NVARCHAR(10),
           @c_doctype NCHAR(1)           
                                             
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
         
	 IF @c_Action IN('INSERT') AND EXISTS(SELECT 1 FROM CODELKUP(NOLOCK) WHERE Listname = 'TNPOEDI' AND Storerkey = @c_Storerkey AND Code = 'ENABLE')
	 BEGIN
      DECLARE Cur_Receipt CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT Receiptkey, DocType
         FROM #INSERTED
         WHERE Storerkey = @c_Storerkey         

      OPEN Cur_Receipt
	  
	    FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_DocType

	    WHILE @@FETCH_STATUS <> -1 
	    BEGIN	    
	    	 IF @c_DocType = 'A'
	    	 BEGIN
            EXEC dbo.ispGenTransmitLog3 'RCPTLOGTN', @c_Receiptkey, @c_DocType, @c_StorerKey, ''  
                 , @b_success OUTPUT  
                 , @n_err OUTPUT  
                 , @c_errmsg OUTPUT  
            
            IF @b_success = 0
               SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'ispREC01: ' + rtrim(@c_errmsg)
         END
	    		    		    	
         FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_DocType
	    END
    	CLOSE Cur_Receipt
	    DEALLOCATE Cur_Receipt
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispREC01'		
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