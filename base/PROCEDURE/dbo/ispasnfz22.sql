SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ22                                            */
/* Creation Date: 02-Feb-2021                                              */
/* Copyright: LF                                                           */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-16222 - Update ECOM_Presale_Flag to blank upon Finalize ASN*/
/*                                                                         */
/* Called By: ispPostFinalizeReceiptWrapper                                */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ22]  
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
      
   DECLARE @n_Continue           INT,
           @n_StartTranCount     INT,
           @c_ExternOrderkey     NVARCHAR(50),
           @c_ExternReceiptkey   NVARCHAR(50),
           @c_Storerkey          NVARCHAR(15),
           @c_GetReceiptkey      NVARCHAR(10),
           @c_DocType            NVARCHAR(10) = 'R',
           @c_RECType            NVARCHAR(10) = 'GRN'

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     
       
   SELECT @c_Storerkey         = R.Storerkey
        , @c_ExternReceiptkey  = R.ExternReceiptkey
        , @c_GetReceiptkey     = R.ReceiptKey
   FROM RECEIPT R (NOLOCK)
   WHERE R.ReceiptKey = @c_Receiptkey
   AND R.DocType = @c_DocType
   AND R.RECType = @c_RECType
   
   IF (ISNULL(@c_GetReceiptkey,'') = '')
      GOTO QUIT_SP
      
   --Main Process
   IF @n_Continue IN (1,2) AND LEFT(LTRIM(RTRIM(ISNULL(@c_ExternReceiptkey,''))), 1) = 'E' AND RIGHT(LTRIM(RTRIM(ISNULL(@c_ExternReceiptkey,''))), 2) = 'IN'
   BEGIN
      SELECT @c_ExternOrderkey = SUBSTRING(LTRIM(RTRIM(ISNULL(@c_ExternReceiptkey,''))), 0, LEN(LTRIM(RTRIM(ISNULL(@c_ExternReceiptkey,'')))) - 2)
      
      IF ISNULL(@c_ExternOrderkey,'') <> '' AND ISNULL(@c_Storerkey,'') <> ''
      BEGIN
         --BEGIN TRAN
         UPDATE ORDERS WITH (ROWLOCK)
         SET ECOM_PRESALE_FLAG = ''
           , TrafficCop = NULL
           , EditDate = GETDATE()
           , EditWho = SUSER_SNAME()
         WHERE Storerkey = @c_Storerkey AND ExternOrderKey = @c_ExternOrderkey
         
         SELECT @n_Err = @@ERROR
         
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 62505
            SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Update ORDERS table fail (ispASNFZ22)'
            GOTO QUIT_SP
         END
      END
   END 

QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ22'
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