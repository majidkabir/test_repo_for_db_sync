SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ASNException_PreDelete                              */
/* Creation Date: 2021-05-10                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16957 - [CN]Nike_Phoeix_B2C_Exceed_Exception_Tracking  */
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
/* 2020-05-10  Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_ASNException_PreDelete]
     @n_RowRef             BIGINT
   , @c_DocumentNo         NVARCHAR(10) = ''
   , @b_Success            INT          = 1     OUTPUT
   , @n_Err                INT          = 0     OUTPUT
   , @c_ErrMsg             NVARCHAR(255)= ''    OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_DocumentNo = ISNULL(@c_DocumentNo,'')
   
   IF @c_DocumentNo = ''
   BEGIN
      SELECT @c_DocumentNo = dst.DocumentNo
      FROM dbo.DocStatusTrack AS dst WITH (NOLOCK)
      WHERE dst.RowRef = @n_RowRef
   END
   
   IF EXISTS ( SELECT 1
               FROM dbo.DocStatusTrack AS dst WITH (NOLOCK) 
               WHERE dst.DocumentNo = @c_DocumentNo
               AND dst.TableName = 'ASNEXCEPTION'
               AND dst.DocStatus IN ('9','CANC','RR')
   )
   BEGIN
      SET @n_Continue = 3 
      SET @n_Err = 88110
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ASN Tracking Exception Status is 9/CANC/RR. Delete Abort. ([isp_ASNException_PreDelete])'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM dbo.DocStatusTrack AS dst WITH (NOLOCK) 
               WHERE dst.DocumentNo = @c_DocumentNo
               AND dst.TableName = 'EXCEPTIONRDT'
   )
   BEGIN
      SET @n_Continue = 3 
      SET @n_Err = 88120
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': RDT Tracking Exception found. Delete Abort. ([isp_ASNException_PreDelete])'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ASNException_PreDelete'
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