SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTReceivingItemReceived         */  
 /* Creation Date: 26-Feb-2013                                          */  
 /* Copyright: IDS                                                      */  
 /* Written by: Shong                                                   */  
 /*                                                                     */  
 /* Purposes: The device sends this message so the host can record the  */
 /*           received item.                                            */  
 /*                                                                     */  
 /* Updates:                                                            */  
 /* Date         Author    Purposes                                     */  
 /* 30-May-2014  TKLIM     Added Lottables 06-15                        */
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTReceivingItemReceived] (  
    @c_TranDate       NVARCHAR(20)  
   ,@c_DevSerialNo    NVARCHAR(20)  
   ,@c_OperatorID     NVARCHAR(20)  
   ,@c_SKU            NVARCHAR(20)  
   ,@c_PalletID       NVARCHAR(18)    
   ,@n_QtyReceived    INT  
   ,@c_ExpiryDate     NVARCHAR(10)  
   ,@n_SerialNo       INT  
   ,@c_RtnMessage     NVARCHAR(500) OUTPUT      
   ,@b_Success        INT = 1 OUTPUT  
   ,@n_Error          INT = 0 OUTPUT  
   ,@c_ErrMsg         NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode       NVARCHAR(20)   --  0: No error. The VoiceApplication proceeds.  
                                             -- 98: Critical error. If this error is received,   
                                             --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                             -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                             --     but does not force the operator to sign off.  
         , @c_Message         NVARCHAR(400)  
         , @c_Remarks         NVARCHAR(255)  
         , @c_QtyRemain       NVARCHAR(10)  
         
         , @c_StorerKey       NVARCHAR(15)  
         , @c_ReceiptKey      NVARCHAR(10)  
         , @c_POKey           NVARCHAR(10)  
         , @c_BaseUOM         NVARCHAR(10)  
         , @c_PackKey         NVARCHAR(10)  
         , @c_LOC             NVARCHAR(10)  
         , @c_outstring       NVARCHAR(215)  
         , @n_QtyRemain       INT   
         , @cReceiptLineNo    NVARCHAR(5)  
         , @b_LotFound        INT   
         , @c_ReceiptDate     NVARCHAR(10)
     
      SET @c_ErrorCode = '0'
      SET @c_Message = ''      
      
   -- Sample prTaskLUTReceivingItemReceived('11-10-10 13:52:21.000','Device.Id','Operator.Id','124','11','9','')  
     
      SELECT @c_ReceiptKey = V_ReceiptKey, 
             @c_POKey =  V_POKey,
             @c_StorerKey = StorerKey 
      FROM rdt.RDTMOBREC WITH (NOLOCK)  
      WHERE UserName = @c_OperatorID 
      AND   DeviceID = @c_DevSerialNo
      
      SELECT @c_BaseUOM = PACK.PackUOM3,  
             @c_PackKey = S.PackKey,
             @c_LOC = s.ReceiptLoc   
     FROM dbo.PACK PACK WITH (NOLOCK)  
     INNER JOIN dbo.SKU S WITH (NOLOCK) ON Pack.PackKey = S.PackKey  
     WHERE S.StorerKey = @c_StorerKey  
     AND S.SKU = @c_SKU
     
     SET @c_ReceiptDate = rdt.rdtFormatDate( GETDATE() )
      
     EXEC dbo.nspRFRC01  
            @c_SendDelimiter  = null  
          , @c_ptcid          = @c_DevSerialNo  
          , @c_userid         = @c_OperatorID  
          , @c_taskId         = 'RDT'  
          , @c_databasename   = NULL  
          , @c_appflag        = NULL  
          , @c_recordType     = NULL  
          , @c_server         = NULL  
          , @c_receiptkey     = NULL  
          , @c_storerkey      = @c_StorerKey   
          , @c_prokey         = @c_ReceiptKey  
          , @c_sku            = @c_SKU  
          , @c_Lottable01     = ''  
          , @c_Lottable02     = ''  
          , @c_Lottable03     = ''
          , @d_Lottable04     = @c_ExpiryDate 
          , @d_Lottable05     = @c_ReceiptDate  
          , @c_Lottable06     = ''  
          , @c_Lottable07     = ''  
          , @c_Lottable08     = ''
          , @c_Lottable09     = '' 
          , @c_Lottable10     = ''  
          , @c_Lottable11     = ''  
          , @c_Lottable12     = ''  
          , @d_Lottable13     = NULL
          , @d_Lottable14     = NULL 
          , @d_Lottable15     = NULL  
          , @c_lot            = ''  
          , @c_pokey          = @c_POKey  
          , @n_qty            = @n_QtyReceived  
          , @c_uom            = @c_BaseUOM  
          , @c_packkey        = @c_PackKey  
          , @c_loc            = @c_LOC  
          , @c_id             = @c_PalletID  
          , @c_holdflag       = ''  
          , @c_other1         = ''  
          , @c_other2         = ''  
          , @c_other3         = ''  
          , @c_outstring      = @c_outstring  OUTPUT  
          , @b_Success        = @b_Success OUTPUT  
          , @n_err            = @n_Error   OUTPUT  
          , @c_errmsg         = @c_errmsg  OUTPUT  
                              
      SET @cReceiptLineNo = ''  
      -- Get Receipt Line from RFRC01 OutString -- (ChewKP02) 
      SET @cReceiptLineNo = [dbo].[fnc_GetDelimitedColumn] (@c_outstring, '|', 9)     
      
      SELECT @n_QtyRemain = SUM(r.QtyExpected) - SUM(r.BeforeReceivedQty)  
      FROM RECEIPTDETAIL r WITH (NOLOCK)
      WHERE r.ReceiptKey = @c_ReceiptKey 
      AND r.Sku = @c_SKU     
  
      SET @c_RtnMessage = '' + ',' + CAST(@n_QtyRemain AS NVARCHAR(10)) + @c_ErrorCode + ',' + @c_Message
      
QUIT_SP:     
   SET @c_RtnMessage = ''  
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = ",,0,"   
   END  
   

  
END


GO