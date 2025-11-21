SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_GetDFCarrierRef01                              */
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
CREATE PROC [dbo].[isp_RFID_GetDFCarrierRef01]
           @c_Receiptkey         NVARCHAR(10) = '' 
         , @c_TrackingNo         NVARCHAR(40) = '' 
         , @c_DefaultCarrierRef  NVARCHAR(18) = '' OUTPUT        
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT = @@TRANCOUNT
         , @n_Continue              INT = 1
         , @n_ExistCnt              INT = 0
         
         , @c_Storerkey             NVARCHAR(10) = ''
         , @c_Short                 NVARCHAR(10) = ''
         
         , @c_V_ID                  NVARCHAR(18)  = ''
         
   SET @c_DefaultCarrierRef = ''
   
   SET @n_ExistCnt = 0
   SELECT @c_V_ID = V_ID 
         ,@n_ExistCnt = 1
   FROM rdt.V_Rdtdatacapture WITH (NOLOCK) 
   WHERE V_String1 = @c_TrackingNo 
   
   IF @n_ExistCnt = 1
   BEGIN
      IF LEN(@c_V_ID) >= 3
      BEGIN
         SET @c_Short = SUBSTRING(@c_V_ID,2,2)
      END

      IF @c_Short <> ''
      BEGIN
         SELECT @c_Storerkey = R.Storerkey
         FROM RECEIPT AS r WITH (NOLOCK)
         WHERE r.ReceiptKey = @c_Receiptkey
         
         SELECT @c_DefaultCarrierRef = CL.Code
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = 'NIKECarref' 
         AND CL.Storerkey = @c_Storerkey
         AND CL.Short = @c_Short
      END
   END
   
QUIT_SP:
END -- procedure

GO