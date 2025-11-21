SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ21                                            */
/* Creation Date: 03-MAR-2021                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-16330 - CN SEC ASN Suggest PA Finalize AS remove RDTPutaway*/
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 22-Oct-2021  NJOW    1.0   DEVOPS combine script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ21]  
(     @c_Receiptkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue INT,
           @n_StartTranCount INT,
           @c_Userdefine10 NVARCHAR(30),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20),
           @n_PABookingKey INT,
           @n_QtyReceived INT,
           @n_PABookQty INT,
           @n_Variance INT,
           @n_rowref BIGINT,
           @n_PAQty INT,
           @c_Lot NVARCHAR(10),
           @c_Loc NVARCHAR(10),
           @c_ID NVARCHAR(18),
           @c_LoseID NVARCHAR(1),
           @n_QtyFinal INT

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT
   
   IF ISNULL(@c_ReceiptLineNumber,'') <> ''
      GOTO QUIT_SP     
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN                                                     

   DECLARE ASN_CUR CURSOR FAST_FORWARD READ_ONLY FOR
	    SELECT RD.Storerkey, RD.Sku, SUM(RD.QtyReceived), RD.Userdefine10
	    FROM RECEIPTDETAIL RD (NOLOCK)
	    WHERE RD.Receiptkey = @c_Receiptkey 
	    AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END
	    AND ISNUMERIC(ISNULL(RD.Userdefine10,'')) = 1
	    GROUP BY RD.Storerkey, RD.Sku, RD.Userdefine10
	 
	 OPEN ASN_CUR 
	 
	 FETCH NEXT FROM ASN_CUR INTO @c_Storerkey, @c_Sku, @n_QtyReceived, @c_Userdefine10

	 WHILE @@FETCH_STATUS<>-1 AND @n_continue IN(1,2)
	 BEGIN
	 	
	 	 SET @n_PABookingKey = CAST(@c_Userdefine10 AS BIGINT)
	 	 
	 	 SET @n_PABookQty = 0
	 	 SELECT @n_PABookQty = SUM(Qty) 
	 	 FROM RFPUTAWAY(NOLOCK)
	 	 WHERE PABookingkey = @n_PABookingKey
	 	 AND Storerkey = @c_Storerkey
	 	 AND Sku = @c_Sku
	 	 
	 	 SET @n_Variance = ISNULL(@n_PABookQty, 0) - @n_QtyReceived
	 	 
	 	 WHILE @n_Variance > 0
	 	 BEGIN
	 	    SELECT TOP 1 @n_rowref = RowRef, 
	 	           @n_PAQty = Qty,
	 	           @c_Lot = Lot,
	 	           @c_Loc = SuggestedLoc,
	 	           @c_Id = ID
	 	    FROM RFPUTAWAY (NOLOCK)
	 	    WHERE PABookingKey = @n_PABookingKey
   	 	  AND Storerkey = @c_Storerkey
	 	    AND Sku = @c_Sku
	 	    AND Qty > 0	 	    
	 	    ORDER BY RowRef
	 	    
	 	    IF @@ROWCOUNT = 0
	 	       BREAK
	 	       
	 	    SELECT @c_LoseID = LoseID
        FROM LOC (NOLOCK)
        WHERE Loc = @c_Loc
        
        IF @c_LoseID = '1'
           SET @c_ID = ''      
	 	       
	 	    IF @n_PAQty <= @n_Variance    
	 	    BEGIN	 	       
	 	       DELETE FROM RFPUTAWAY WHERE RowRef = @n_RowRef AND PABookingKey = @n_PABookingKey
	 	       
	 	       SET @n_QtyFinal = @n_PAQty	 	       
	 	    END
	 	    ELSE
	 	    BEGIN
	 	    	 SET @n_QtyFinal = @n_Variance
	 	    	 
	 	    	 UPDATE RFPUTAWAY 
	 	    	 SET Qty = Qty - @n_QtyFinal	 	 
	 	    	 WHERE RowRef = @n_RowRef 
	 	    	 AND PABookingKey = @n_PABookingKey 	 	    	  
	 	    END   	 	                 
	 	    
	 	    UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) 
	 	    SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_QtyFinal < 0 THEN 0 ELSE PendingMoveIn - @n_QtyFinal END
        WHERE LOT = @c_Lot
        AND LOC = @c_Loc
        AND ID  = @c_ID
        
        SET @n_Variance = @n_Variance - @n_QtyFinal 
	 	 END
	 	 	 	 	 	 
     /*
     EXEC rdt.rdt_Putaway_PendingMoveIn 
         @cUserName = SUSER_SNAME(), 
         @cType = 'UNLOCK'
        ,@cFromLoc = ''
        ,@cFromID = ''
        ,@cSuggestedLOC = ''
        ,@cStorerKey = @c_Storerkey
        ,@nErrNo = @n_Err OUTPUT
        ,@cErrMsg = @c_Errmsg OUTPUT
        ,@cSKU = @c_Sku
        ,@nPutawayQTY    = 0
        ,@cFromLOT       = ''
        ,@cTaskDetailKey = ''
        ,@nFunc = 0
        ,@nPABookingKey = @n_PABookingKey                                       	  		  	

      IF @n_Err <> 0 
      BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 820100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute rdt.rdt_Putaway_PendingMoveIn Failed. (ispASNFZ21)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                           	
      END
      */
                                
      FETCH NEXT FROM ASN_CUR INTO @c_Storerkey, @c_Sku, @n_QtyReceived, @c_Userdefine10         
	 END
	 CLOSE ASN_CUR
	 DEALLOCATE ASN_CUR
	  	             
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ21'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO