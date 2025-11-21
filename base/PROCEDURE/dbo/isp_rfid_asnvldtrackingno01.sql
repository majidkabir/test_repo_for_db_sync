SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_ASNVLDTrackingNo01                             */
/* Creation Date: 2021-03-19                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving_Overall_CR     */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-03-19  Wan      1.0   Created                                   */
/* 2021-07-06  WLChooi  1.1   WMS-17404 - Prompt ErrorMsg if TrackingNo */
/*                            not valid (WL01)                          */
/************************************************************************/
CREATE PROC [dbo].[isp_RFID_ASNVLDTrackingNo01]
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
           @n_StartTCnt          INT = @@TRANCOUNT
         , @n_Continue           INT = 1
         , @n_Match              INT          = 0
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Pattern            NVARCHAR(100)= ''

   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   
   --CR 1.4 Validate Input TrackingNo
   SELECT @c_Storerkey = r.StorerKey
   FROM dbo.RECEIPT AS r WITH (NOLOCK)
   WHERE r.ReceiptKey = @c_Receiptkey
   
   SELECT @c_Pattern = ISNULL(c.Long,'')
   FROM dbo.CODELKUP AS c WITH (NOLOCK) 
   WHERE c.LISTNAME = 'RDTFormat'
   AND c.Code = '706-TrackingNo'
   AND c.Storerkey  = @c_Storerkey

   IF @c_Pattern <> ''
   BEGIN
      SELECT @n_Match = master.dbo.RegExIsMatch( @c_Pattern, @c_TrackingNo, 0) -- 0=RegexOptions.None    

      IF @n_Match = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 87010
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Invalid Tracking #: ' + @c_TrackingNo
                         + ' (isp_RFID_ASNVLDTrackingNo01)'
         GOTO QUIT_SP   
      END
   END

   IF NOT EXISTS (SELECT 1 FROM rdt.V_Rdtdatacapture WITH (NOLOCK) WHERE V_String1 = @c_TrackingNo)
   BEGIN
      SET @n_Continue = 3      --WL01
      SET @n_Err      = 87015  --WL01
      SET @c_ErrMsg = 'Tracking # Not Found in V_Rdtdatacapture. (isp_RFID_ASNVLDTrackingNo01) '
      GOTO QUIT_SP   --WL01
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_ASNVLDTrackingNo01'
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