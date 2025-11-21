SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RFID_Receiving_Finalize                         */
/* Creation Date: 2020-09-22                                             */
/* Copyright: Maersk                                                     */
/* Written by: Wan                                                       */
/*                                                                       */
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module             */
/*          ASN Header                                                   */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* Version: 1.1                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 09-OCT-2020 Wan      1.0   Created                                    */
/* 2023-09-23  Wan01    1.1   WMS-23643 - [CN]NIKE_B2C_Creturn_NFC_      */
/*                            Ehancement_Function CR                     */
/*************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RFID_Receiving_Finalize]
   @c_ReceiptKey        NVARCHAR(10)   = ''
,  @b_Success           INT            = 1   OUTPUT
,  @n_Err               INT            = 0   OUTPUT
,  @c_Errmsg            NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @n_Cnt                INT          = 0
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_CarrierRef         NVARCHAR(18) = ''
         , @c_ASNStatus          NVARCHAR(10) = ''                                  --(Wan01)
         , @c_TableName          NVARCHAR(30) = 'WSRPTLOGNFC'                       --(Wan01)
         , @c_WSRPTLOGNFC        NVARCHAR(10) = ''                                  --(Wan01)         

   SELECT @c_Facility  = RH.Facility                                                --(Wan01) - START
         ,@c_Storerkey = RH.Storerkey
         ,@c_ASNStatus = RH.ASNStatus
   FROM RECEIPT RH WITH (NOLOCK)
   WHERE RH.ReceiptKey = @c_ReceiptKey

   --IF EXISTS ( SELECT 1
   --            FROM RECEIPT RH WITH (NOLOCK)
   --            WHERE RH.ReceiptKey = @c_ReceiptKey
   --            AND   RH.ASNStatus = '9'
   --         )
   IF @c_ASNStatus = '9'                                                            --(Wan01) - END
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 89010
      SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': ASN is closed'
                     + '. (isp_RFID_Receiving_Finalize)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM RECEIPTDETAIL RD WITH (NOLOCK)
               WHERE RD.ReceiptKey = @c_ReceiptKey
               AND RD.FinalizeFlag = 'Y'
               )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 88020
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Finalized ASN Detail is found. (isp_RFID_Receiving_Finalize)'
      GOTO QUIT_SP
   END

   EXEC dbo.ispFinalizeReceipt
        @c_ReceiptKey         = @c_ReceiptKey
      , @c_ReceiptLineNumber  = ''
      , @b_Success            = @b_Success OUTPUT
      , @n_Err                = @n_Err     OUTPUT
      , @c_Errmsg             = @c_Errmsg  OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 88030
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Update RECEIPTDETAIL_WIP Failed. (isp_RFID_Receiving_Finalize)'
      GOTO QUIT_SP
   END
   
   --(Wan01) - START
   SELECT @c_WSRPTLOGNFC = fgr.Authority FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', @c_TableName) AS fgr
  
   IF @c_WSRPTLOGNFC = '1'
   BEGIN
      EXEC ispGenTransmitLog2 @c_Tablename, @c_Receiptkey, '', @c_StorerKey, ''   
                           ,  @b_success  OUTPUT    
                           ,  @n_Err      OUTPUT    
                           ,  @c_ErrMsg   OUTPUT    
                         
      IF @b_success <> 1    
      BEGIN    
         SET @n_continue = 3    
         SET @n_Err = 88040    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))     
                       + ': Insert into TRANSMITLOG2 Failed. (isp_RFID_Receiving_Finalize) '    
         GOTO QUIT_SP    
      END     
   END
   --(Wan01) - END
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_Receiving_Finalize'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   REVERT
END

GO