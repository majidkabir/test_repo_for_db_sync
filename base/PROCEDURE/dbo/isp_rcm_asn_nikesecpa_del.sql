SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_RCM_ASN_NikeSECPA_DEL                               */  
/* Creation Date: 06-JUL-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-16330 - CN Nike SEC Putaway - Delete Short RFPutaway    */  
/*        :                                                             */  
/* Called By: Custom RCM Menu                                           */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 22-Oct-2021 NJOW     1.0   DEVOPS combine script                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_RCM_ASN_NikeSECPA_DEL]  
      @c_Receiptkey  NVARCHAR(MAX)     
   ,  @b_success     INT OUTPUT  
   ,  @n_err         INT OUTPUT  
   ,  @c_errmsg      NVARCHAR(225) OUTPUT  
   ,  @c_code        NVARCHAR(30)=''  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt     INT  
         , @n_Continue      INT   
         , @n_rowref        BIGINT
         , @c_Storerkey     NVARCHAR(15)
         , @c_Sku           NVARCHAR(20)
         , @n_PABookingKey  INT
         , @c_Userdefine10 NVARCHAR(30)
         , @n_PAQty INT
         , @c_Lot NVARCHAR(10)
         , @c_Loc NVARCHAR(10)
         , @c_ID NVARCHAR(18)         
         , @c_LoseID NVARCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
   
   IF EXISTS(SELECT 1
             FROM RECEIPT(NOLOCK)
             WHERE Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))
             HAVING COUNT(DISTINCT Storerkey) > 1)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63010
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Selected receipts from more than one storerkey are not allowed' 
                    + '. (isp_RCM_ASN_NikeSECPA_DEL)'
      GOTO QUIT_SP   	  
   END   
   
   DECLARE ASN_CUR CURSOR FAST_FORWARD READ_ONLY FOR
	    SELECT RD.Storerkey, RD.Sku, RD.Userdefine10
	    FROM RECEIPTDETAIL RD (NOLOCK)
	    WHERE RD.Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))
	    AND ISNUMERIC(ISNULL(RD.Userdefine10,'')) = 1
	    GROUP BY RD.Storerkey, RD.Sku, RD.Userdefine10
	 
	 OPEN ASN_CUR 
	 
	 FETCH NEXT FROM ASN_CUR INTO @c_Storerkey, @c_Sku, @c_Userdefine10

	 WHILE @@FETCH_STATUS<>-1 AND @n_continue IN(1,2)
	 BEGIN
	 	
	    SET @n_PABookingKey = CAST(@c_Userdefine10 AS BIGINT)
	    
	    DECLARE PA_CUR CURSOR FAST_FORWARD READ_ONLY FOR
	       SELECT RowRef,
	 	            Qty,
	 	            Lot,
	 	            SuggestedLoc,
	 	            ID	       
	       FROM RFPUTAWAY (NOLOCK)
	       WHERE PABookingKey = @n_PABookingKey
      	  AND Storerkey = @c_Storerkey
	       AND Sku = @c_Sku
	       AND QtyPrinted = 0	 	 
	       ORDER BY RowRef
	       
      OPEN PA_CUR 
	    
	    FETCH NEXT FROM PA_CUR INTO @n_rowref, @n_PAQty, @c_Lot, @c_Loc, @c_Id  
	    
	    WHILE @@FETCH_STATUS<>-1 AND @n_continue IN(1,2)
	    BEGIN
	       SELECT @c_LoseID = LoseID
         FROM LOC (NOLOCK)
         WHERE Loc = @c_Loc
        
         IF @c_LoseID = '1'
            SET @c_ID = ''  	    	
            
         DELETE FROM RFPUTAWAY WHERE RowRef = @n_RowRef AND PABookingKey = @n_PABookingKey	   	  	   	  

	 	     UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) 
	 	     SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_PAQty < 0 THEN 0 ELSE PendingMoveIn - @n_PAQty END
         WHERE LOT = @c_Lot
         AND LOC = @c_Loc
         AND ID  = @c_ID
                  
         FETCH NEXT FROM PA_CUR INTO @n_rowref, @n_PAQty, @c_Lot, @c_Loc, @c_Id  
	    END
	    CLOSE PA_CUR
	    DEALLOCATE PA_CUR
	   	 	     	 		 	
      FETCH NEXT FROM ASN_CUR INTO @c_Storerkey, @c_Sku, @c_Userdefine10         
	 END
	 CLOSE ASN_CUR
	 DEALLOCATE ASN_CUR
  
QUIT_SP:  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ASN_NikeSECPA_DEL'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure  

GO