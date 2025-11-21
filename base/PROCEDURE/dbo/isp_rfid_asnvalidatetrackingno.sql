SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ASNValidateTrackingNo                          */
/* Creation Date: 2021-03-19                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving_Overall_CR     */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-03-19  Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_ASNValidateTrackingNo]
           @c_Receiptkey         NVARCHAR(10) = '' 
         , @c_TrackingNo         NVARCHAR(40) = '' 
         , @b_Success            INT          = 1  OUTPUT
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT = @@TRANCOUNT
         , @n_Continue                 INT = 1
         , @c_SQL                      NVARCHAR(1000) = ''
         , @c_SQLParms                 NVARCHAR(1000) = ''
         
         , @c_Facility                 NVARCHAR(5) = ''
         , @c_Storerkey                NVARCHAR(15)= '' 
         
         , @c_RFIDASNVLDTrackingNo_SP  NVARCHAR(30) = ''        

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT @c_Facility  = R.Facility
         ,@c_Storerkey = R.Storerkey
   FROM RECEIPT AS r WITH (NOLOCK)
   WHERE r.ReceiptKey = @c_Receiptkey
         
   SELECT @c_RFIDASNVLDTrackingNo_SP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'RFIDASNVLDTrackingNo_SP')

   IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDASNVLDTrackingNo_SP) AND [Type] = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   SET @b_Success = 1
   SET @c_SQL = N'EXEC ' + @c_RFIDASNVLDTrackingNo_SP
               +'  @c_Receiptkey = @c_Receiptkey'    
               +', @c_TrackingNo = @c_TrackingNo'     
               +', @b_Success    = @b_Success OUTPUT'
               +', @n_Err        = @n_Err     OUTPUT'
               +', @c_ErrMsg     = @c_ErrMsg  OUTPUT'

   SET @c_SQLParms= N'@c_ReceiptKey  NVARCHAR(10)'   
                  +', @c_TrackingNo  NVARCHAR(40)'
                  +', @b_Success     INT          OUTPUT'
                  +', @n_Err         INT          OUTPUT'
                  +', @c_ErrMsg      NVARCHAR(255)OUTPUT'

   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_ReceiptKey     
                     , @c_TrackingNo  
                     , @b_Success      OUTPUT
                     , @n_Err          OUTPUT
                     , @c_ErrMsg       OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81030   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_RFIDASNVLDTrackingNo_SP + '. (isp_RFID_ASNValidateTrackingNo)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNValidateTrackingNo'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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