SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_BuildLoadUnallocateOrder_Wrapper               */  
/* Creation Date: 15-Apr-2019                                           */  
/* Copyright: LFL                                                       */  
/* Written by:Wan                                                       */  
/*                                                                      */  
/* Purpose: WMS-8633 - CN_Skecher_Robot_Exceed_BuildLoad_NewRCMMenu     */  
/*          (isp_BldLoadUnallocSO_??)                                   */
/*                                                                      */  
/* Called By: Build Load Unallocate Order                               */  
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
CREATE PROCEDURE [dbo].[isp_BuildLoadUnallocateOrder_Wrapper]  
   @c_LoadKey    NVARCHAR(10),    
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue     INT           = 1

         , @c_LoadStatus   NVARCHAR(10)  = ''
         , @c_StorerKey    NVARCHAR(15)  = ''
         , @c_Facility     NVARCHAR(5)   = ''
         , @c_SPCode       NVARCHAR(30)  = ''

         , @c_SQL          NVARCHAR(MAX) 
         , @c_Authority    NVARCHAR(30)
                                                      
   SET @n_err=0
   SET @b_success=1
   SET @c_errmsg=''
   
   SELECT @c_LoadStatus = LP.[Status] 
   FROM LOADPLAN LP WITH (NOLOCK)
   WHERE LP.LoadKey = @c_LoadKey
   
   IF @c_LoadStatus = '0'
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 31010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                    + ': Load# ' + RTRIM(@c_Loadkey) + ' status is open. (isp_BldLoadUnallocSO_01)'  
      
      GOTO QUIT_SP
   END

   IF NOT EXISTS(SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK)
                 WHERE LoadKey = @c_LoadKey)
   BEGIN
      SET @n_continue = 3  
      SET @c_ErrMsg = CONVERT(CHAR(250), @n_Err) 
      SET  @n_Err = 31020-- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                    + ': No Orders being populated into LoadPlanDetail. Load# ' + RTRIM(@c_Loadkey) + ' (isp_BuildLoadUnallocateOrder_Wrapper)'  
      
      GOTO QUIT_SP
   END
   
   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,
                @c_Facility = ORDERS.Facility
   FROM LOADPLANDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE LOADPLANDETAIL.Loadkey = @c_LoadKey    
   
   SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'BuildLoadUnallocateOrder_SP')  
   
   IF ISNULL(RTRIM(@c_SPCode),'') =''
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31030-- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)   
                     + ': Stored Procedure Name Not Yet configure to storerconfig BuildLoadUnallocateOrder for Storer: '
                     + RTRIM(@c_StorerKey) + '. Load# ' + RTRIM(@c_Loadkey) + ' (isp_BuildLoadUnallocateOrder_Wrapper)'  
       GOTO QUIT_SP           
   END
   
   IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Storerconfig BuildLoadReleaseTask_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+')' 
                     + '. Load# ' + RTRIM(@c_Loadkey) + ' (isp_BuildLoadUnallocateOrder_Wrapper)'  
       GOTO QUIT_SP
   END
   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_LoadKey=@c_Loadkey, @c_Storerkey=@c_Storerkey'
              + ', @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_Errmsg OUTPUT'
     
   EXEC sp_executesql @c_SQL 
        , N'@c_LoadKey NVARCHAR(10), @c_Storerkey NVARCHAR(15), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT' 
        , @c_LoadKey 
        , @c_Storerkey
        , @b_Success      OUTPUT                     
        , @n_Err          OUTPUT
        , @c_ErrMsg       OUTPUT

                        
   IF @b_Success <> 1 OR @n_err <> 0
   BEGIN
       SET @n_continue = 3  
       GOTO QUIT_SP
   END
                    
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_BuildLoadUnallocateOrder_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO