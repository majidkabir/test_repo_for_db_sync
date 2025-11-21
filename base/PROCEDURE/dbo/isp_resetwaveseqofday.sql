SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ResetWaveSeqOfDay                              */  
/* Creation Date: 03-Feb-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-16289 - Reset WaveSeqOfDay NCounter Count               */  
/*                                                                      */  
/* Called By: SQL Job                                                   */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_ResetWaveSeqOfDay]
   @c_Storerkey  NVARCHAR(15),  
   @b_Success    INT           OUTPUT,
   @n_Err        INT           OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT

AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @n_StartTCnt     INT,
           @c_KeyName       NVARCHAR(30),
           @n_InitialCnt    INT = 0,
           @c_LastUpdated   NVARCHAR(30) = '1900-01-01 12:00:00'
                                                      
   SELECT @n_err = 0, @b_success = 1, @c_errmsg = '', @n_Continue = 1
   SELECT @n_StartTCnt = @@TRANCOUNT
      
   SELECT @c_KeyName     = CL.Code
        , @n_InitialCnt  = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS INT) - 1 ELSE 0 END
        , @c_LastUpdated = ISNULL(CL.UDF02,'1900-01-01 12:00:00')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'WVSeqOfDay' 
   AND CL.Storerkey = @c_Storerkey
   AND CL.Short = 'Y'

   IF ISNULL(RTRIM(@c_KeyName),'') = ''
   BEGIN
       --SELECT @n_continue = 4  
       --SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
       --       @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       --SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
       --       ': Please Setup Codelkup WVSeqOfDay for '+RTRIM(@c_StorerKey)+' (isp_ResetWaveSeqOfDay)'  
       GOTO QUIT_SP
   END
   
   --BEGIN TRAN
   
    --SELECT @c_KeyName    
    --     , @n_InitialCnt 
    --     , @c_LastUpdated
    --     , @n_Continue
         
   IF @n_Continue IN (1,2)
   BEGIN
      UPDATE NCOUNTER WITH (ROWLOCK)
      SET keycount = @n_InitialCnt, EditDate = GETDATE()
      WHERE keyname = @c_KeyName
      
      SET @n_Err = @@ERROR
      
      IF @n_Err <> 0
      BEGIN
      	SELECT @n_continue = 3
         SELECT @n_Err = 65050
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
                ': Update NCounter Failed! (isp_ResetWaveSeqOfDay)'  
      END
   END
   
   IF @n_Continue IN (1,2)
   BEGIN
      UPDATE CODELKUP WITH (ROWLOCK)
      SET UDF01 = CONVERT(NVARCHAR(30), GETDATE(), 120)
      WHERE LISTNAME = 'WVSeqOfDay' 
      AND Storerkey = @c_Storerkey
      AND Short = 'Y'
      AND Code = @c_KeyName
      
      SET @n_Err = @@ERROR
      
      IF @n_Err <> 0
      BEGIN
      	SELECT @n_continue = 3
         SELECT @n_Err = 65055
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
                ': Update CODELKUP Failed! (isp_ResetWaveSeqOfDay)'  
      END
   END
                    
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_ResetWaveSeqOfDay'		
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END    
END  

GO