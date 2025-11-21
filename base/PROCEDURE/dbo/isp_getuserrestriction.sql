SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GetUserRestriction                             */  
/* Creation Date: 21-APR-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Check Storer and facility restrictions for the user         */  
/*        : WMS-16767                                                   */  
/* Called By:                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_GetUserRestriction]   
     @c_username         NVARCHAR(128)  
   , @c_StorerRestrict   NVARCHAR(250) OUTPUT  
   , @c_FacilityRestrict NVARCHAR(250) OUTPUT  
   , @b_Success          INT           OUTPUT    
   , @n_Err              INT           OUTPUT    
   , @c_ErrMsg           NVARCHAR(250) OUTPUT  
AS        
BEGIN       
  SET ANSI_NULLS ON  
  SET ANSI_WARNINGS ON  
  SET QUOTED_IDENTIFIER OFF  
        
  Declare @c_tsecurename     NVARCHAR(50)  
       ,  @c_SQL             NVARCHAR(MAX)    
       ,  @n_CNTRec          INT  
       ,  @c_ExecArguments   NVARCHAR(4000) 
       ,  @c_linksrvrname    NVARCHAR(50)
  
  SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @c_tsecurename ='' 
  SELECT @c_linksrvrname = ''  
         
  SELECT @c_tsecurename = dbo.fnc_GetSecurityDBName()  

  SELECT @c_linksrvrname = CASE WHEN LEFT(RTRIM(DB_NAME()), 2 ) = 'CN' THEN 'link_secure' ELSE 'link_local' END  
    
  IF ISNULL(@c_username,'') = ''  
     SELECT @c_username = SUSER_SNAME()  
       
  SET @c_SQL = N'SELECT @c_StorerRestrict = pl_usr.usr_storerkey, @c_FacilityRestrict = pl_usr.usr_facility 
                 FROM '+ @c_linksrvrname + '.' + @c_tsecurename + '.dbo.pl_usr pl_usr (NOLOCK)
                 WHERE pl_usr.usr_login = @c_username '  
                                     
  SET @c_ExecArguments = N'@c_StorerRestrict NVARCHAR(250) OUTPUT, @c_FacilityRestrict NVARCHAR(250) OUTPUT, @c_UserName NVARCHAR(128)'           
    
  EXEC sp_ExecuteSql @c_SQL     
     , @c_ExecArguments    
     , @c_StorerRestrict   OUTPUT
     , @c_FacilityRestrict OUTPUT
     , @c_UserName
                  
  SET @n_err = @@ERROR  

  IF @n_err <> 0   
  BEGIN  
     SELECT @b_success = 0  
     SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to access TSECURE. (isp_GetUserRestriction)'   
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  END      
END  

GO