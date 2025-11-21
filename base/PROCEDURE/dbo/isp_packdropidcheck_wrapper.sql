SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PackDropIDCheck_Wrapper                        */  
/* Creation Date: 13-Aug-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-10048 SG THG Pack DropId validation                     */  
/*          SP: ispPKDROPIDCHK??                                        */
/*                                                                      */  
/* Called By: Packing                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_PackDropIDCheck_Wrapper]  
   @c_Storerkey     NVARCHAR(15),
   @c_Facility      NVARCHAR(5),
   @c_DropID        NVARCHAR(20),
   @b_Success       INT           OUTPUT,
   @n_Err           INT           OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT,
           @c_SPCode        NVARCHAR(30),
           @c_SQL           NVARCHAR(MAX)
                                                      
   SELECT @c_SPCode='', @n_err=0, @b_success=1, @c_errmsg=''   
           
   SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackDropIDCheck_SP') 
      
   IF ISNULL(RTRIM(@c_SPCode),'') IN( '','0')
   BEGIN
       /*
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Please Setup Stored Procedure Name into Storer Configuration PackDropIDValidate_SP for '+RTRIM(@c_StorerKey)+' (isp_PackDropIDCheck_Wrapper)'
       */  
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Storerconfig PackDropIDCheck_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_PackDropIDCheck_Wrapper)'  
       GOTO QUIT_SP
   END
   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Storerkey=@c_StorerkeyP, @c_Facility=@c_FacilityP, @c_DropID=@c_DropIDP, @b_Success=@b_SuccessP OUTPUT, @n_Err=@n_ErrP OUTPUT,' +
                ' @c_ErrMsg=@c_ErrMsgP OUTPUT '
     
   EXEC sp_executesql @c_SQL, 
        N'@c_StorerkeyP NVARCHAR(15), @c_FacilityP NVARCHAR(5), @c_DropIDP NVARCHAR(20), @b_SuccessP INT OUTPUT, @n_ErrP INT OUTPUT, @c_ErrMsgP NVARCHAR(250) OUTPUT', 
        @c_Storerkey,
        @c_Facility,
        @c_DropID, 
        @b_Success OUTPUT,                      
        @n_Err OUTPUT, 
        @c_ErrMsg OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PackDropIDCheck_Wrapper'  
       --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO