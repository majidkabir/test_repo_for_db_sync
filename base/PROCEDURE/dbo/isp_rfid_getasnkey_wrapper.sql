SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_GetASNKey_Wrapper                              */
/* Creation Date: 2020-08-28                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 09-OCT-2020 Wan      1.0   Created                                   */
/* 2021-03-19  Wan01    1.1   WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving*/
/*                           _Overall_CR                                */
/* 2021-05-20  WLChooi  1.2   WMS-16736 - [CN]NIKE_GWP_RFID_Receiving_CR*/
/*                            (WL01)                                    */
/* 2021-07-06  WLChooi  1.3   WMS-17404 - [CN]NIKE PHC Outlets RFID     */
/*                            Receiving CR (WL02)                       */
/* 2023-09-23  Wan02    1.4   WMS-23643 - [CN]NIKE_B2C_Creturn_NFC_      */
/*                            Ehancement_Function CR                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RFID_GetASNKey_Wrapper]
           @c_Facility           NVARCHAR(5)  
         , @c_Storerkey          NVARCHAR(15) 
         , @c_RefNo              NVARCHAR(50)
         , @c_ReceiptKey         NVARCHAR(10) = '' OUTPUT
         , @n_TotalQtyExpected   INT = 0           OUTPUT
         , @n_TotalQtyReceived   INT = 0           OUTPUT
         , @n_SessionID          BIGINT = 0        OUTPUT   --(Wan01)
         , @c_Remark             NVARCHAR(50) = '' OUTPUT   --WL02  
         , @c_AdminUser          NVARCHAR(1)  = 'N'OUTPUT   --Wan02   
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

         , @c_Facility_Chk       NVARCHAR(5)  = ''
         , @c_Storerkey_Chk      NVARCHAR(15) = ''
         , @c_Status             NVARCHAR(10) = ''
         , @c_ASNStatus          NVARCHAR(10) = '' 
         , @c_DocType            NVARCHAR(10) = ''

         , @c_RFIDGetASNKey_SP   NVARCHAR(30) = '' 
         
         , @c_SQL                NVARCHAR(1000)= ''
         , @c_SQLParms           NVARCHAR(1000)= ''  
         , @c_UserName           NVARCHAR(128) = SUSER_SNAME()
  
   SET @n_err      = 0
   SET @c_errmsg   = ''
   

   IF ISNULL(@c_Facility,'') = '' OR ISNULL(@c_StorerKey,'') = '' 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81005   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility and Storerkey is required to get ASN #. (isp_RFID_GetASNKey_Wrapper)'   
      GOTO QUIT_SP  
   END

   SET @c_ReceiptKey = ''
   
   SET @c_RFIDGetASNKey_SP = ''
   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'RFIDGetASNKey_SP' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_RFIDGetASNKey_SP    OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 81010   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_RFID_GetASNKey_Wrapper)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   IF @c_RFIDGetASNKey_SP IN ('', '0')
   BEGIN
      SET @c_ReceiptKey = @c_RefNo
   END
   ELSE
   BEGIN   
      IF NOT EXISTS (SELECT 1 FROM Sys.Objects (NOLOCK) WHERE object_id = object_id(@c_RFIDGetASNKey_SP) AND [Type] = 'P')
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81020   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Custom Stored Procedure:' + @c_RFIDGetASNKey_SP 
                      +' not found. (isp_RFID_GetASNKey_Wrapper)'   
         GOTO QUIT_SP
      END

      SET @b_Success = 1
      SET @c_SQL = N'EXEC ' + @c_RFIDGetASNKey_SP
                 +'  @c_Facility   = @c_Facility'    
                 +', @c_Storerkey  = @c_Storerkey' 
                 +', @c_RefNo      = @c_RefNo'     
                 +', @c_ReceiptKey = @c_ReceiptKey OUTPUT'
                 +', @n_SessionID  = @n_SessionID  OUTPUT'     --(Wan01)
                 +', @c_Remark     = @c_Remark     OUTPUT'     --WL02
                 +', @b_Success    = @b_Success OUTPUT'
                 +', @n_Err        = @n_Err     OUTPUT'
                 +', @c_ErrMsg     = @c_ErrMsg  OUTPUT'

      SET @c_SQLParms= N'@c_Facility    NVARCHAR(5)'   
                     +', @c_Storerkey   NVARCHAR(15)'
                     +', @c_RefNo       NVARCHAR(50)'
                     +', @c_ReceiptKey  NVARCHAR(10) OUTPUT'
                     +', @n_SessionID   BIGINT       OUTPUT'   --(Wan01)
                     +', @c_Remark       NVARCHAR(50) OUTPUT'   --WL02
                     +', @b_Success     INT          OUTPUT'
                     +', @n_Err         INT          OUTPUT'
                     +', @c_ErrMsg      NVARCHAR(255)OUTPUT'

      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Facility     
                        , @c_Storerkey   
                        , @c_RefNo       
                        , @c_ReceiptKey   OUTPUT
                        , @n_SessionID    OUTPUT               --(Wan01)
                        , @c_Remark       OUTPUT               --WL02
                        , @b_Success      OUTPUT
                        , @n_Err          OUTPUT
                        , @c_ErrMsg       OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81030   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_RFIDGetASNKey_SP + '. (isp_RFID_GetASNKey_Wrapper)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP  
      END
   END 

   IF @c_ReceiptKey <> ''
   BEGIN
      SELECT 
         @c_Facility_Chk = RH.Facility
      ,  @c_Storerkey_Chk= RH.Storerkey
      ,  @c_Status       = RH.[Status]
      ,  @c_ASNStatus    = RH.[ASNStatus]
      ,  @c_DocType      = RH.DocType
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE Receiptkey = @c_ReceiptKey
   
      IF @c_Facility <> @c_Facility_Chk
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81040   
         SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': Invalid Receipt''s facility different from '
                      + @c_Facility + '. (isp_RFID_GetASNKey_Wrapper)'   
 
         GOTO QUIT_SP   
      END

      IF @c_Storerkey <> @c_Storerkey_Chk
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81050   
         SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': Invalid Receipt''s Storer different from '
                      + @c_Storerkey + '. (isp_RFID_GetASNKey_Wrapper)'   
 
         GOTO QUIT_SP   
      END

      IF @c_ASNStatus = '9'
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81060   
         SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': ASN is closed'
                      + '. (isp_RFID_GetASNKey_Wrapper)'   
         GOTO QUIT_SP   
      END

      IF @c_DocType = 'X'
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81070   
         SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': RFID does tot support XDOCK Receiving'
                      + '. (isp_RFID_GetASNKey_Wrapper)'   
         GOTO QUIT_SP   
      END

      SELECT @n_TotalQtyExpected = SUM(RD.QtyExpected)
            ,@n_TotalQtyReceived = SUM(RD.BeforeReceivedQty)
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      GROUP BY RD.Receiptkey
   END
   
   SET @c_AdminUser = 'N'                                                           --(Wan02) - START
   SELECT TOP 1 @c_AdminUser = IIF(c.UDF01 = @c_UserName OR c.UDF02 = @c_UserName,'Y','N')
   FROM dbo.CODELKUP AS c (NOLOCK) 
   WHERE c.ListName = 'NFCADMIN'
   ORDER BY IIF(c.UDF01 = @c_UserName OR c.UDF02 = @c_UserName,'Y','N') DESC        --(Wan02) - END
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_GetASNKey_Wrapper'
   END
   ELSE
   BEGIN
      IF @b_Success <> 2   --WL01 - Return b_success = 2 back to PB to show warning/information message box
         SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO