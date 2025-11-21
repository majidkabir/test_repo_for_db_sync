SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
 /* Store Procedure:  isp_TCP_VC_prTaskLUTReceivingValidPO               */        
 /* Creation Date: 26-Feb-2013                                           */        
 /* Copyright: IDS                                                       */        
 /* Written by: Shong                                                    */        
 /*                                                                      */        
 /* Purposes: Get the list of items to be received                       */        
 /*                                                                      */        
 /* Updates:                                                             */        
 /* Date         Author    Purposes                                      */        
/************************************************************************/        
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTReceivingValidPO] (        
    @c_TranDate      NVARCHAR(20)        
   ,@c_DevSerialNo   NVARCHAR(20)        
   ,@c_OperatorID    NVARCHAR(20)        
   ,@c_POKey         NVARCHAR(20)  -- PO Number 
   ,@n_SerialNo     INT        
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT            
   ,@b_Success      INT = 1 OUTPUT        
   ,@n_Error        INT = 0 OUTPUT        
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT         
        
)        
AS        
BEGIN        
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.        
                                            -- 98: Critical error. If this error is received,         
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.         
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,         
                                            --     but does not force the operator to sign off.        
         , @c_Message            NVARCHAR(400)     
         , @c_SKU                NVARCHAR(20)             
         , @c_UPC                NVARCHAR(20)         
         , @c_SKUDesc            NVARCHAR(60)
         , @n_ExpectedQty        INT
         , @n_QtyReceived        INT       
         , @c_ExpiryDate         NVARCHAR(10)
         , @c_Lottable           NVARCHAR(18)
         , @c_RushItem           NVARCHAR(1)
         , @c_PODescription      NVARCHAR(200)   
         , @c_StorerKey          NVARCHAR(15)   
                   
                 

   DECLARE @c_ReceiptKey      NVARCHAR(10)

   SET @c_ErrorCode = '0'
   SET @c_Message = ''
   
   SET @c_RushItem = '0'
         
   IF NOT EXISTS(SELECT 1 FROM RECEIPT r WITH (NOLOCK) WHERE r.POKey = @c_POKey)
   BEGIN
      SET @c_ErrorCode = '89'
      SET @c_Message = 'Wrong PO Number'
      GOTO Quit_SP
   END
   ELSE
   BEGIN
      SELECT @c_ReceiptKey =  r.ReceiptKey,
             @c_PODescription = ISNULL(CAST(r.Notes AS NVARCHAR(1000)), ''),
             @c_StorerKey = r.StorerKey 
      FROM RECEIPT r WITH (NOLOCK)
      WHERE r.POKey = @c_POKey
      
      DECLARE CUR_RECEIPT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT r.Sku, ISNULL(RTRIM(r.AltSku), ''), s.DESCR, SUM(r.QtyExpected), SUM(r.BeforeReceivedQty), r.Lottable02, CONVERT(VARCHAR(10), r.Lottable04, 112)
         FROM RECEIPTDETAIL r WITH (NOLOCK) 
         JOIN SKU s WITH (NOLOCK) ON s.StorerKey = r.StorerKey AND s.Sku = r.Sku  
         WHERE r.ReceiptKey = @c_ReceiptKey 
         GROUP BY r.Sku, ISNULL(RTRIM(r.AltSku), ''), s.DESCR, r.Lottable02, CONVERT(VARCHAR(10), r.Lottable04, 112)
         HAVING SUM(r.QtyExpected) > SUM(r.BeforeReceivedQty)

      OPEN CUR_RECEIPT
      
      FETCH NEXT FROM CUR_RECEIPT INTO @c_SKU, @c_UPC, @c_SKUDesc, @n_ExpectedQty,
                                       @n_QtyReceived, @c_Lottable, @c_ExpiryDate    
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_RtnMessage = CASE WHEN ISNULL(RTRIM(@c_RtnMessage), '') = '' THEN '' ELSE '<CR><LF>' END + 
                       ISNULL(RTRIM(@c_SKU),'') + ',' +         
                       ISNULL(RTRIM(@c_UPC),'')   + ',' +        
                       ISNULL(RTRIM(@c_SKUDesc),'')   + ',' +         
                       ISNULL(RTRIM(CAST(@n_ExpectedQty AS NVARCHAR(10))),'')  + ',' +        
                       ISNULL(RTRIM(CAST(@n_QtyReceived AS NVARCHAR(10))),'')  + ',' +        
                       ISNULL(RTRIM(@c_ExpiryDate),'')  + ',' +  
                       ISNULL(RTRIM(@c_Lottable),'')          + ',' +                                                              --   
                       ISNULL(RTRIM(@c_RushItem),'')         
                                               
         
         FETCH NEXT FROM CUR_RECEIPT INTO @c_SKU, @c_UPC, @c_SKUDesc, @n_ExpectedQty,
                                          @n_QtyReceived, @c_Lottable, @c_ExpiryDate             
      END     
      CLOSE CUR_RECEIPT
      DEALLOCATE CUR_RECEIPT
      
      UPDATE rdt.RDTMOBREC 
         SET V_ReceiptKey = @c_ReceiptKey, 
             V_POKey = @c_POKey, 
             StorerKey = @c_StorerKey 
      WHERE UserName = @c_OperatorID 
      AND   DeviceID = @c_DevSerialNo  
                  
   END    


Quit_SP:
   SET @c_RtnMessage = RTRIM(@c_RtnMessage) +                        
                       ISNULL(RTRIM(@c_ErrorCode),'') + ',' +  
                       ISNULL(RTRIM(@c_Message),'')   
                          
                                                      
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0         
   BEGIN        
      SET @c_RtnMessage = ',,,,0,,,0,,89,Unknown Error'        
   END  
   
   
        
END

GO