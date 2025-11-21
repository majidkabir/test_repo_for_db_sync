SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispRECD06                                          */
/* Creation Date: 24-APR-2021                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-16855 NIEK TW/CN/HK Copy receidetail.userdefine03       */   
/*                                                                      */
/* Called By:isp_ReceiptDetailTrigger_Wrapper from Receiptdetail Trigger*/
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

CREATE PROC [dbo].[ispRECD06]   
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
     
   DECLARE @n_Continue          INT,
           @n_StartTCnt         INT,
           @c_Receiptkey        NVARCHAR(10),
           @c_ReceiptLineNumber NVARCHAR(5),
           @c_Userdefine03      NVARCHAR(30),
           @c_Lottable09        NVARCHAR(30)
                                                                  
	SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   

   IF @@TRANCOUNT = 0
      BEGIN TRAN
  
	 IF @c_Action IN('INSERT') 
	 BEGIN		            	 	   
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT I.Receiptkey, I.ReceiptLineNumber
      FROM #INSERTED I
      JOIN RECEIPT R (NOLOCK) ON I.Receiptkey = R.Receiptkey
      WHERE I.Storerkey = @c_Storerkey    
      AND (ISNULL(I.Userdefine03,'') = ''
           OR ISNULL(I.Lottable09,'') = '')
      AND EXISTS(SELECT 1 
                 FROM CODELKUP (NOLOCK) 
                 WHERE Listname = 'RECTYPE'      
                 AND Storerkey = R.Storerkey
                 AND Code = R.RecType
                 AND UDF04 = 'Y')                
   
      OPEN CUR_RECDET
	   
	    FETCH NEXT FROM CUR_RECDET INTO @c_Receiptkey, @c_ReceiptLineNumber
	    
	    WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
	    BEGIN
	    	  SET @c_Userdefine03 = ''
	    	  SET @c_Lottable09 = ''
	    	  
	    	  SELECT @c_Userdefine03 = MAX(Userdefine03),
	    	         @c_Lottable09 = MAX(Lottable09)
	    	  FROM RECEIPTDETAIL (NOLOCK)
	    	  WHERE Receiptkey = @c_Receiptkey
	    	  
	    	  IF ISNULL(@c_Userdefine03,'') <> ''
	    	  BEGIN	   	   
	    	     UPDATE RECEIPTDETAIL WITH (ROWLOCK)
	    	     SET Userdefine03 = CASE WHEN ISNULL(Userdefine03,'') = '' THEN @c_Userdefine03 ELSE Userdefine03 END, 
    	    	     Lottable09 = CASE WHEN ISNULL(Lottable09,'') = '' THEN @c_Lottable09 ELSE Lottable09 END, 
	    	         Trafficcop = NULL
	    	     WHERE Receiptkey = @c_Receiptkey
	    	     AND ReceiptLineNumber = @c_ReceiptLineNumber 
	    	     
	    	     SET @n_Err = @@ERROR
	    	     
	    	     IF @n_Err <> 0 
	    	     BEGIN
                 SELECT @n_continue = 3 
                 SELECT @n_err = 60100
                 SELECT @c_errmsg = 'Update RECEIPTDETAIL Table Failed. (ispRECD06)' 
	    	     END
	    	  END
      	   		    	
          FETCH NEXT FROM CUR_RECDET INTO @c_Receiptkey, @c_ReceiptLineNumber
	    END
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD06'		
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