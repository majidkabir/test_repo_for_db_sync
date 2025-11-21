SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispSHPMO03                                            */  
/* Creation Date: 15-NOV-2018                                              */  
/* Copyright: IDS                                                          */  
/* Written by: WLCHOOI                                                     */  
/*                                                                         */  
/* Purpose: WMS-6911 Update POD.PODDef06 = Y When Status = 9               */  
/*                                                                         */  
/* Called By: Copied and edited from ispSHPMO02                            */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/***************************************************************************/    
CREATE PROC [dbo].[ispSHPMO03]    
(     @c_MBOLkey     NVARCHAR(10)     
  ,   @c_Storerkey   NVARCHAR(15)  
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug     INT  
         , @n_Continue  INT   
         , @n_StartTCnt INT   
   
   --DECLARE @c_ID        NVARCHAR(18)  
   --      , @c_Orderkey  NVARCHAR(10)           
       
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug = '0'   
   SET @n_Continue = 1    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   UPDATE POD WITH (ROWLOCK)  
   SET PODDef06 = 'Y'  
   WHERE MBOLKEY = @c_MBOLkey  
  
   IF @n_err <> 0      
   BEGIN    
      SET @n_continue = 3      
      SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE POD Failed. (ispSHPMO03)'   
      GOTO QUIT_SP  
   END   
  
 --if(@b_debug = 1)  
 --BEGIN  
 --SELECT POD.PODDEF06,* FROM MBOLDETAIL (NOLOCK)  
 --JOIN POD (NOLOCK) ON POD.MBOLKEY = MBOLDETAIL.MBOLKEY   
 --WHERE MBOLDETAIL.MBOLKEY = @c_MBOLkey  
 --END  
  
QUIT_SP:  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO03'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
        COMMIT TRAN  
      END   
      RETURN  
   END   
END  

GO