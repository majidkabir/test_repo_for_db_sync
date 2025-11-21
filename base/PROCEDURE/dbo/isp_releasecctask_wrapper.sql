SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReleaseCCTask_Wrapper                               */
/* Creation Date: 18-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1617 - CN&SG Logitech RDT TM Cycle count with ABC       */
/*        :                                                             */
/* Called By: Job Sceduler                                              */
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
CREATE PROC [dbo].[isp_ReleaseCCTask_Wrapper]
           @c_Storerkey       NVARCHAR(15)  
         , @b_Success         INT             OUTPUT
         , @n_Err             INT             OUTPUT
         , @c_ErrMsg          NVARCHAR(255)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_SPCode          NVARCHAR(30)  
         , @c_SQL             NVARCHAR(4000)           

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN

   SET @c_SPCode = ''
   SELECT @c_SPCode = ISNULL(RTRIM(SValue),'') 
   FROM   STORERCONFIG WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'ReleaseCCTask_SP'  

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Please Setup Stored Procedure Name into Storer Config - ''ReleaseCCTask_SP'' for '
                     + RTRIM(@c_StorerKey)+ '. (isp_ReleaseCCTask_Wrapper)'  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31020
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Storerconfig ReleaseCCTask_SP - Stored Proc name invalid ('+ @c_SPCode
                     + '). (isp_ReleaseCCTask_Wrapper)'  
       GOTO QUIT_SP
   END

   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_StorerKey, @b_Success OUTPUT, @n_Err OUTPUT'
              +',@c_ErrMsg OUTPUT'

   EXEC sp_executesql @c_SQL 
      , N'@c_StorerKey NVARCHAR(15), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT' 
      , @c_StorerKey 
      , @b_Success   OUTPUT                       
      , @n_Err       OUTPUT  
      , @c_ErrMsg    OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ReleaseCCTask_Wrapper'
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