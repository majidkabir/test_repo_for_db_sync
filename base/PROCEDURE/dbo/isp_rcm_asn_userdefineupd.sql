SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_RCM_ASN_UserDefineUpd                               */  
/* Creation Date: 23-JAN-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-7742 - [PH] Alcon - ASN Receipt New RCM                 */  
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
/************************************************************************/  
CREATE PROC [dbo].[isp_RCM_ASN_UserDefineUpd]  
      @c_Receiptkey  NVARCHAR(10)     
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
           @n_StartTCnt          INT  
         , @n_Continue           INT   
  
         , @c_RecType            NVARCHAR(10)  
         , @c_RCStatus           NVARCHAR(10)  
   
         , @n_RDLineCnt       INT    
  
         , @c_ReceiptLineNumber  NVARCHAR(5)  
         , @c_Storerkey          NVARCHAR(15)   
         , @c_Lottable02         NVARCHAR(18)   
         , @c_Lottable06         NVARCHAR(30) 
         , @n_QtyReceived        INT
  
         , @c_GetReceiptkey      NVARCHAR(10)  
         , @c_RDUserDefine05     NVARCHAR(30)  
         , @c_RDUserDefine09     NVARCHAR(30)   
         , @c_ExternLineNo       NVARCHAR(20)  
         , @n_QtyOrdered         INT  
  
         , @c_transmitlogkey     NVARCHAR(10)  
    
         , @CUR_RD               CURSOR  
         , @CUR_CHECK            CURSOR  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
   SET @c_RCStatus       = ''      
   SET @c_Lottable02     = ''  
   SET @c_Lottable06     = ''  
   SET @c_RDUserDefine05 = ''  
 
  
   SELECT @c_RCStatus = ISNULL(RH.Status,'0')  
   FROM RECEIPT RH WITH (NOLOCK)  
   WHERE RH.ReceiptKey = @c_ReceiptKey    

   IF @c_RCStatus = '9'
   BEGIN
     SET @n_Continue = 3  
     SET @n_Err = 65888  
     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': RECEIPT already finalize.Update Fail. (isp_RCM_ASN_UserDefineUpd)'  
     GOTO QUIT_SP 
   END
  
   BEGIN TRAN  
   DECLARE CUR_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RD.ReceiptLineNumber  
         ,RD.Storerkey  
         ,RD.Externlineno  
         ,RD.Lottable02  
         ,RD.Lottable06  
         ,RD.Userdefine09  
   FROM RECEIPTDETAIL RD WITH (NOLOCK)  
   WHERE RD.ReceiptKey = @c_Receiptkey  
   
   OPEN CUR_loop   
     
   FETCH NEXT FROM CUR_loop INTO @c_receiptlinenumber,@c_storerkey,@c_Externlineno,@c_lottable02,@c_lottable06,@c_RDUserDefine09    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   
      SET @c_RDUserDefine05 = ''
      SET @n_RDLineCnt = 1
 
     SELECT @n_RDLineCnt = COUNT(DISTINCT RD.ReceiptLineNumber)
     FROM RECEIPTDETAIL RD WITH (NOLOCK)
     WHERE RD.Externlineno  = @c_Externlineno
     AND RD.Receiptkey = @c_Receiptkey
     GROUP BY RD.Receiptkey,RD.Externlineno

     IF @n_RDLineCnt = 1 AND ISNULL(@c_lottable02,'') <> '' AND ISNULL(@c_RDUserDefine09,'') = '000000'
     BEGIN
        SET @c_RDUserDefine05 = 'REGULAR'
     END
     ELSE IF @n_RDLineCnt = 1 AND ISNULL(@c_lottable02,'') = ''
     BEGIN
       SET @c_RDUserDefine05 = 'PARENT_BATCH'
     END
     ELSE IF @n_RDLineCnt > 1 AND ISNULL(@c_lottable06,'') = ''
     BEGIN
       SET @c_RDUserDefine05 = 'PARENT_SERIAL'
     END
     ELSE IF @n_RDLineCnt > 1 AND ISNULL(@c_lottable06,'') <> ''
     BEGIN
       SET @c_RDUserDefine05 = 'CHILD_SERIAL'
     END
      ELSE IF ISNULL(@c_RDUserDefine09,'') <> '000000'
     BEGIN
       SET @c_RDUserDefine05 = 'CHILD_BATCH'
     END
     
     --SELECT @c_ReceiptKey '@c_ReceiptKey',@c_receiptlinenumber '@c_receiptlinenumber',@n_RDLineCnt '@n_RDLineCnt',
     --       @c_lottable02 '@c_lottable02' ,@c_Lottable06 '@c_lottable06',@c_RDUserDefine09 '@c_RDUserDefine09'
         -- ,@c_RDUserDefine05 '@c_RDUserDefine05'
        
      UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
      SET  UserDefine05 = @c_RDUserDefine05         
         , TrafficCop = NULL  
         , EditWho = SUSER_NAME()  
         , EditDate= GETDATE()  
      WHERE Receiptkey = @c_ReceiptKey  
      AND   ReceiptLineNumber = @c_receiptlinenumber 
      
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 65889  
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update ReceiptDetail Fail. (isp_RCM_ASN_UserDefineUpd)'  
         GOTO QUIT_SP  
      END  
  
      FETCH NEXT FROM CUR_loop INTO @c_receiptlinenumber,@c_storerkey,@c_Externlineno,@c_lottable02,@c_lottable06,@c_RDUserDefine09  

   END  
   CLOSE CUR_loop  
   DEALLOCATE CUR_loop  
  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ASN_UserDefineUpd'  
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