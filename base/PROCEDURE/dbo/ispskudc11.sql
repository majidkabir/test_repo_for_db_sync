SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispSKUDC11                                         */
/* Creation Date: 29/03/2023                                            */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22024 CN ANTA decode sku from scan EPC                  */
/*                                                                      */
/*                                                                      */
/* Called By: isp_SKUDecode_Wrapper                                     */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 29-MAR-2023 NJOW     1.0   DEVOPS combine scirpt                     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispSKUDC11]
     @c_Storerkey        NVARCHAR(15)
   , @c_Sku              NVARCHAR(60)
   , @c_NewSku           NVARCHAR(60)      OUTPUT
   , @c_Code01           NVARCHAR(60) = '' OUTPUT
   , @c_Code02           NVARCHAR(60) = '' OUTPUT
   , @c_Code03           NVARCHAR(60) = '' OUTPUT
   , @b_Success          INT          = 1  OUTPUT
   , @n_Err              INT          = 0  OUTPUT
   , @c_ErrMsg           NVARCHAR(250)= '' OUTPUT
   , @c_Pickslipno       NVARCHAR(10) = ''
   , @n_CartonNo         INT = 0
   , @c_UCCNo            NVARCHAR(20) = ''  --Pack by UCC when UCCtoDropID = '1' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT = 1
         , @n_StartTcnt    INT = @@TRANCOUNT
         , @c_TempSku      NVARCHAR(60) = ''

   SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''   
   
   SET @c_TempSku = @c_Sku
    
   IF LEN(RTRIM(@c_TempSku)) = 24                    
   BEGIN                                  	                  
   	  SELECT @c_TempSku = LEFT(@c_TempSku,18)   
   END                                                 
                                                    
   SELECT @c_NewSku = @c_TempSku

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispSKUDC11'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End Procedure

GO