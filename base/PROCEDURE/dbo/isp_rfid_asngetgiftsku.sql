SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RFID_ASNGetGiftSku                                  */
/* Creation Date: 2021-Apr-21                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-16736 - [CN]NIKE_GWP_RFID_Receiving_CR                 */
/*        :  Copy from isp_RFID_ASNValidateSku and modify               */
/* Called By:                                                           */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-Apr-21 WLChooi  1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_ASNGetGiftSku]
           @c_Receiptkey         NVARCHAR(10)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_SKU                NVARCHAR(20)          OUTPUT
         , @b_ReadRFIDTag        INT            = 0    OUTPUT
         , @c_GiftSKU            NVARCHAR(50)   = ''   OUTPUT
         , @b_GiftSKUFlag        INT            = 0    OUTPUT
         , @b_Success            INT            = 1    OUTPUT   --2: Question
         , @n_Err                INT            = 0    OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  = ''   OUTPUT
       
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt              INT = @@TRANCOUNT
         , @n_Continue               INT = 1
         , @n_SkuCnt                 INT = 0
                                     
         , @c_Facility               NVARCHAR(5)  = ''
         , @c_RFIDGetGiftSku_SP      NVARCHAR(30) = ''

         , @c_SQL                    NVARCHAR(MAX)= ''
         , @c_SQLParms               NVARCHAR(MAX)= ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @c_Facility = RH.Facility
   FROM RECEIPT RH (NOLOCK)
   WHERE RH.Receiptkey = @c_Receiptkey

   SET @c_RFIDGetGiftSku_SP = ''
   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'RFIDASNGetGiftSku_SP' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_RFIDGetGiftSku_SP  OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 84030   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight - RFIDASNGetGiftSku_SP. (isp_RFID_ASNGetGiftSku)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   IF @c_RFIDGetGiftSku_SP = '0'
   BEGIN
      GOTO QUIT_SP  
   END

   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDGetGiftSku_SP) AND [Type] = 'P')
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 84040   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Custom Stored Procedure:' + @c_RFIDGetGiftSku_SP 
                     +' not found. (isp_RFID_ASNGetGiftSku)'   
      GOTO QUIT_SP
   END

   SET @b_Success = 1
   SET @c_SQL = N'EXEC ' + @c_RFIDGetGiftSku_SP
               +'  @c_Receiptkey  = @c_Receiptkey' 
               +', @c_Storerkey   = @c_Storerkey' 
               +', @c_Sku         = @c_Sku' 
               +', @b_ReadRFIDTag = @b_ReadRFIDTag  OUTPUT'   
               +', @c_GiftSKU     = @c_GiftSKU      OUTPUT'
               +', @b_GiftSKUFlag = @b_GiftSKUFlag  OUTPUT'     
               +', @b_Success     = @b_Success      OUTPUT'
               +', @n_Err         = @n_Err          OUTPUT'
               +', @c_ErrMsg      = @c_ErrMsg       OUTPUT'

   SET @c_SQLParms= N'@c_Receiptkey    NVARCHAR(10)'
                  +', @c_Storerkey     NVARCHAR(15)'
                  +', @c_Sku           NVARCHAR(20)'
                  +', @b_ReadRFIDTag   INT            OUTPUT' 
                  +', @c_GiftSKU       NVARCHAR(50)   OUTPUT' 
                  +', @b_GiftSKUFlag   INT            OUTPUT' 
                  +', @b_Success       INT            OUTPUT'
                  +', @n_Err           INT            OUTPUT'
                  +', @c_ErrMsg        NVARCHAR(255)  OUTPUT'

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_Receiptkey                     
                     , @c_Storerkey   
                     , @c_Sku  
                     , @b_ReadRFIDTag  OUTPUT
                     , @c_GiftSKU      OUTPUT
                     , @b_GiftSKUFlag  OUTPUT                 
                     , @b_Success      OUTPUT
                     , @n_Err          OUTPUT
                     , @c_ErrMsg       OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP  
   END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNGetGiftSku'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
   	IF @b_Success < 2
   	BEGIN
         SET @b_Success = 1
   	END
   	
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO