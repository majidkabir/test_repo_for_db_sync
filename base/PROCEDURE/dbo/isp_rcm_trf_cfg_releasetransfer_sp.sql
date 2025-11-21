SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
                      
/************************************************************************/
/* Stored Procedure: isp_RCM_TRF_CFG_ReleaseTransfer_SP                 */
/* Creation Date: 27-SEP-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-23775 - Transfer RCM to execute the release task        */
/*          stored proc of storerconfig ReleaseTransfer_SP.             */
/*          This is to migrate the RCM from Exceed WMS to SCE WM        */ 
/*                                                                      */
/* Called By: Transfer Dymaic RCM configure at listname 'RCMConfig'     */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 27-SEP-2023  NJOW      1.0   DEVOPS Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_RCM_TRF_CFG_ReleaseTransfer_SP]
   @c_Transferkey NVARCHAR(10),
   @b_success     INT OUTPUT,
   @n_err         INT OUTPUT,
   @c_errmsg      NVARCHAR(225) OUTPUT,
   @c_code        NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT,
           @n_cnt       INT,
           @n_starttcnt INT,
           @c_SQL       NVARCHAR(MAX),           
           @c_Storerkey NVARCHAR(15),
           @c_Facility  NVARCHAR(5),
           @c_SPName    NVARCHAR(60)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   IF @n_continue IN(1,2)
   BEGIN
   	  SELECT @c_Storerkey = TR.FromStorerKey,
   	         @c_Facility = TR.Facility
   	  FROM TRANSFER TR (NOLOCK)
   	  WHERE TR.Transferkey = @c_Transferkey
   	  
   	  SELECT @c_SPName = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ReleaseTransfer_SP')   --if not set will return '0'
   	  
      IF ISNULL(@c_SPName,'') IN( '','0')                                                                                                                                                                                             
      BEGIN                                                                                                                                                                                                                                  
         SELECT @n_continue = 3                                                                                                                                                                                                             
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storerconfig ReleaseTransfer_SP is not setup for the storer (' + ISNULL(@c_Storerkey,'') + ') (isp_RCM_TRF_CFG_ReleaseTransfer_SP)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP                                                                                                                                                                                                                       
      END                                                                                                                                                                                                                                    
                                                                                                                                                                                                                                          
      IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')                                                                                                                                              
      BEGIN                                                                                                                                                                                                                                  
         SELECT @n_continue = 3                                                                                                                                                                                                             
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storerconfig ReleaseTransfer_SP - Stored Proc name is invalid (' + ISNULL(@c_SPName,'') + ') (isp_RCM_TRF_CFG_ReleaseTransfer_SP)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP                                                                                                                                                                                                                       
      END                                                                                                                                                                                                                                    
                                                                                                                                                                                                                                          
      SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_Transferkey=@c_TransferkeyP, @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT, @c_ErrMsg=@c_ErrMsgP OUTPUT '                                                                                                                                     
                                                                                                                                                                                                                                             
      EXEC sp_executesql @c_SQL,                                                                                                                                                                                                             
           N'@c_TransferkeyP NVARCHAR(10), @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(250) OUTPUT',  
           @c_Transferkey,                                                                                                                                                                                                                   
           @b_Success OUTPUT,                                                                                                             
           @n_Err OUTPUT,                                                                                                                                                                                                                    
           @c_ErrMsg OUTPUT                                                                                                                                                                                                                  
                                                                                                                                                                                                                                          
      IF @b_Success <> 1                                                                                                                                                                                                                     
      BEGIN                                                                                                                                                                                                                                  
         SELECT @n_continue = 3                                                                                                                                                                                                             
         GOTO QUIT_SP                                                                                                                                                                                                                       
      END                                                                          	              
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_TRF_CFG_ReleaseTransfer_SP'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- End PROC

GO