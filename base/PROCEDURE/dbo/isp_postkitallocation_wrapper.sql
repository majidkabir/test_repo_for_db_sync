SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PostKitAllocation_Wrapper                           */
/* Creation Date: 09-SEP-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17858 Post-Kit Allocation process                       */
/*          ispPOALKIT??                                                */
/*                                                                      */
/* Called By:  isp_kit_Allocation                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 22-NOV-2021 NJOW     1.0   DEVOPS combine script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_PostKitAllocation_Wrapper]
           @c_KitKey          NVARCHAR(10)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000) 
         , @c_SQLArgument     NVARCHAR(4000) 
         , @c_Facility        NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_SPCode          NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Storerkey= ''
   SELECT @c_Facility = Facility
         ,@c_Storerkey = Storerkey
   FROM KIT WITH (NOLOCK)
   WHERE KitKey = @c_KitKey

   SET @b_Success = 1
   SET @c_SPCode = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'PostKitAllocation_SP'      
      ,  @b_Success   = @b_Success  OUTPUT      
      ,  @c_authority = @c_SPCode   OUTPUT      
      ,  @n_err       = @n_err      OUTPUT      
      ,  @c_errmsg    = @c_errmsg   OUTPUT
 
   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61000
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing nspGetRight. (isp_PostKitAllocation_Wrapper)'  
      GOTO QUIT_SP
   END

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN 
      GOTO QUIT_SP
   END    

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN
   SET @c_SQL = N'EXEC ' + @c_SPCode 
              + ' @c_KitKey        = @c_KitKey'
              + ',@b_Success       = @b_Success OUTPUT'
              + ',@n_Err           = @n_Err     OUTPUT'
              + ',@c_ErrMsg        = @c_ErrMsg  OUTPUT'

   SET @c_SQLArgument= N'@c_KitKey        NVARCHAR(10)'
                     + ',@b_Success       INT            OUTPUT'
                     + ',@n_Err           INT            OUTPUT'
                     + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

   EXEC sp_ExecuteSql @c_SQL 
         , @c_SQLArgument
         , @c_KitKey      
         , @b_Success   OUTPUT
         , @n_Err       OUTPUT
         , @c_ErrMsg    OUTPUT      
        
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing ' + RTRIM(@c_SPCode)+ '. (isp_PostKitAllocation_Wrapper) ' + + '( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) ' 
      GOTO QUIT_SP
   END

QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "isp_PostKitAllocation_Wrapper"  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END             
END -- procedure

GO