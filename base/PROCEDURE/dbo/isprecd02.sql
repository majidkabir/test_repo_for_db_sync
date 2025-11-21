SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRECD02                                          */
/* Creation Date: 15-May-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1802 CN Nike                                            */   
/*          1. Not allow multiple lottable01                            */
/*          2. Default Receiptkey to lottable06                         */
/*          3. Not allow duplicate po line                              */
/*                                                                      */
/* Called By:isp_ReceiptDetailTrigger_Wrapper from Receiptdetail Trigger*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author    Ver  Purposes                                 */  
/* 29-Jun-2017  NJOW01    1.0  Fix close cursor issue                   */
/* 13-Nov-2017  WLCHOOI01 1.1  WMS-3343 Allow multiple lottable01 when 	*/
/*							               RECEIPTDETAIL.DOCTYPE = 'R'         */
/************************************************************************/
CREATE PROC [dbo].[ispRECD02]   
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
           @c_ReceiptLineNUmber NVARCHAR(5),
           @c_PrevReceiptkey    NVARCHAR(10),
           @c_Pokey             NVARCHAR(10),
           @c_PoLineNumber      NVARCHAR(5)
                                                       
	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1, @c_PrevReceiptkey = ''

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END   
            
	 IF @c_Action IN('INSERT','UPDATE') 
	 BEGIN	 	
      DECLARE Cur_Receipt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT I.Receiptkey, I.ReceiptLineNumber
         FROM #INSERTED I
         WHERE I.Storerkey = @c_Storerkey         
         ORDER BY I.Receiptkey, I.ReceiptLineNumber

      OPEN Cur_Receipt
	  
	    FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey, @c_ReceiptLineNumber

	    WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
	    BEGIN	    	    	
	    	 IF @c_PrevReceiptkey <> @c_Receiptkey
	    	 BEGIN
				IF EXISTS(SELECT 1 FROM RECEIPTDETAIL (NOLOCK)
							    JOIN RECEIPT (NOLOCK) ON RECEIPT.RECEIPTKEY = RECEIPTDETAIL.RECEIPTKEY --WLCHOOI01
	    	 	        WHERE RECEIPTDETAIL.Receiptkey = @c_Receiptkey
	    	 	        AND RECEIPTDETAIL.Lottable01 <> ''
						    	AND RECEIPT.DOCTYPE <>'R' --WLCHOOI01
	    	 	        HAVING COUNT(DISTINCT RECEIPTDETAIL.Lottable01) > 1)
            BEGIN
   	           SELECT @n_continue = 3 
   	           SELECT @n_err = 118101
   	           SELECT @c_errmsg = 'Multiple Lottable01 is not allowed in ASN# ' + RTRIM(@c_Receiptkey) + '. (ispRECD02)'             	 
            END	  
            ELSE
            BEGIN  	 	            
               SET @c_Pokey = ''
               SET @c_PoLineNumber = ''
               
              SELECT TOP 1 @c_Pokey = Pokey, 
                            @c_PolineNumber = Polinenumber
               FROM RECEIPTDETAIL (NOLOCK) 
	    	 	     WHERE Receiptkey = @c_Receiptkey
	    	 	     AND ISNULL(Pokey,'') <> ''
	    	 	     AND ISNULL(PoLineNumber,'') <> ''
	    	 	     GROUP BY Pokey, PoLineNumber
	    	 	     HAVING COUNT(1) > 1
	    	 	     ORDER BY Pokey, Polinenumber
               
               IF ISNULL(@c_Pokey,'') <> ''         
               BEGIN
                  DECLARE @n_IsRDT INT
                  EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

                  IF @n_IsRDT <> 1
                  BEGIN
   	              SELECT @n_continue = 3 
   	              SELECT @n_err = 118102
   	              SELECT @c_errmsg = 'Populate duplicate PO# ' + RTRIM(ISNULL(@c_Pokey,'')) + ' PO Line# ' + RTRIM(ISNULL(@c_PoLineNumber,'')) + ' To ASN# ' + RTRIM(@c_Receiptkey) + ' is not allowed. (ispRECD02)'             	 
                  END
               END	    	
            END 	            
	    	 END
	    	
	    	 IF @n_continue IN(1,2)
	    	 BEGIN
	    	    UPDATE RECEIPTDETAIL WITH (ROWLOCK)
	    	    SET Lottable06 = @c_Receiptkey
	    	    WHERE Receiptkey = @c_Receiptkey
	    	    AND ReceiptLineNumber = @c_ReceiptLineNumber 
	    	    AND Lottable06 <> Receiptkey
	    	    
	    	    SET @n_Err = @@ERROR
	    	    
	    	    IF @n_Err <> 0 
	    	    BEGIN
   	           SELECT @n_continue = 3 
   	           SELECT @n_err = 118103
   	           SELECT @c_errmsg = 'Update RECEIPTDETAIL Table Failed. (ispRECD02)' 
	    	    END
	    	 END
	    	 	    		    		    	
	    	 SET @c_PrevReceiptkey = @c_Receiptkey
	    	 	    		    		    	
         FETCH NEXT FROM Cur_Receipt INTO @c_Receiptkey,  @c_ReceiptLineNumber
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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD02'		
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