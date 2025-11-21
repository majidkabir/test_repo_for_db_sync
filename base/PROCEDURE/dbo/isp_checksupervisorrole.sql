SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_CheckSupervisorRole                            */  
/* Creation Date: 15-Dec-2015                                           */  
/* Copyright: Maersk                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Check IDS_SUPERVISOR role                                   */  
/*        : SOS#357827                                                  */  
/* Called By: Pickdetail delete trigger                                 */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 2017-Jan-19  CSCHONG   1.0 Revise the scripts using dynamic (CS01)   */  
/* 2020-Sept-22 kocy      1.1 Revise link server for CN use link_secure */
/*                             while other countries use link_local     */  
/* 2022-Sep-20  Wan01     1.2 JSM-95588 - Cannot Delete Picked Status   */
/*                            DevOps Combine Script                     */
/* 2024-Feb-15  Wan02     1.3 UWP-14785-UNABLE TO DELETE PALLET MANIFEST*/
/************************************************************************/  
CREATE   PROCEDURE [dbo].[isp_CheckSupervisorRole]   
     @c_username    NVARCHAR(128)                  --(Wan01)  
   , @c_Flag        NVARCHAR(10)  OUTPUT  
   , @b_Success     INT           OUTPUT    
   , @n_Err         INT           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) OUTPUT  
AS        
BEGIN   
    
  SET ANSI_NULLS ON  
  SET ANSI_WARNINGS ON  
  SET QUOTED_IDENTIFIER OFF  
    
  Declare @c_tsecurename      NVARCHAR(50)  
       ,  @c_SQL              NVARCHAR(MAX)    
       ,  @n_CNTRec           INT  
       ,  @c_ExecArguments    NVARCHAR(4000) 
       ,  @c_linksrvrname     NVARCHAR(50)
       
       ,  @c_SCE_CounrtryName NVARCHAR(30) = ''    --(Wan01) 
       ,  @c_WMSSupervisor_V  NVARCHAR(120) = ''   --(Wan01) 
       ,  @c_SQLParms         NVARCHAR(1000)= ''   --(Wan01)
  
  SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @c_Flag = 'N',@c_tsecurename ='' --CS01 
  
   --(Wan01) - START
   IF ISNULL(@c_username,'') = ''         -- Move Up 
      SET @c_username = SUSER_SNAME()  
   
   --(Wan02) - START 
   SET @c_Flag = 'Y'          --V2 uses 1 DB Connection-WMCONNECT, Always Return As Supervisor
   GOTO QUIT_SP                                                            
   --(Wan02) - END

   IF EXISTS ( SELECT 1
               FROM WM.WMS_USER_CREATION_STATUS AS wucs WITH (NOLOCK)
               WHERE CHARINDEX(wucs.[USER_NAME], @c_username,  1) > 0
             )
   BEGIN
      SELECT @c_linksrvrname     = RTRIM(n.NSQLValue)
            ,@c_SCE_CounrtryName = RTRIM(n.NSQLDefault)
            ,@c_WMSSupervisor_V  = RTRIM(ISNULL(n.NSQLDescrip,''))
      FROM dbo.NSQLCONFIG AS n (NOLOCK) WHERE n.ConfigKey = 'SCE_WMSSupervisor'
      
      IF @c_linksrvrname <> '' AND @c_WMSSupervisor_V <> ''
      BEGIN
         SET @c_SQL = N'SELECT @c_Flag = ''Y'''
                    + ' FROM ' + @c_linksrvrname + '.' + @c_WMSSupervisor_V + ' AS S (NOLOCK)'
                    + ' WHERE CHARINDEX(s.[USER_NAME], @c_username,  1) > 0'
         SET @c_SQLParms = N'@c_Flag               NVARCHAR(10)   OUTPUT'
                         + ',@c_SCE_CounrtryName   NVARCHAR(30)'
                         + ',@c_username           NVARCHAR(128)'
                   
         EXEC sp_ExecuteSql @c_SQL
                           ,@c_SQLParms 
                           ,@c_Flag  OUTPUT
                           ,@c_SCE_CounrtryName
                           ,@c_username                      
      END
      GOTO QUIT_SP
   END
   --(Wan01) - END
     
  SELECT @c_linksrvrname = ''  --kocy
         
  SELECT @c_tsecurename = dbo.fnc_GetSecurityDBName()  

  SELECT @c_linksrvrname = CASE WHEN LEFT(RTRIM(DB_NAME()), 2 ) = 'CN' THEN 'link_secure' ELSE 'link_local' END  --kocy
    
   --IF ISNULL(@c_username,'') = ''        --Wan01 Move Up 
   --SELECT @c_username = SUSER_SNAME()  
       
/*CS01 start*/      
/*  IF EXISTS (SELECT 1   
             FROM link_local.tsecure.dbo.pl_usr pl_usr (NOLOCK)   
             LEFT JOIN link_local.tsecure.dbo.pl_grp_usr pl_grp_usr (NOLOCK) ON pl_usr.usr_key = pl_grp_usr.usr_key  
             LEFT JOIN link_local.tsecure.dbo.pl_grp_role pl_grp_role (NOLOCK) ON pl_grp_usr.grp_key = pl_grp_role.grp_key AND pl_grp_role.app_key = 1  
             LEFT JOIN link_local.tsecure.dbo.pl_role pl_rolegrp (NOLOCK) ON pl_grp_role.role_key = pl_rolegrp.role_key   
             LEFT JOIN link_local.tsecure.dbo.pl_usr_role pl_usr_role (NOLOCK) ON pl_usr.usr_key = pl_usr_role.usr_key AND pl_usr_role.app_key = 1   
             LEFT JOIN link_local.tsecure.dbo.pl_role pl_role (NOLOCK) ON pl_usr_role.role_key = pl_role.role_key   
             WHERE pl_usr.usr_login = @c_username  
             AND (pl_role.role_name = 'IDS_SUPERVISOR' OR pl_rolegrp.role_name = 'IDS_SUPERVISOR')  )  
             */  
   SET @c_SQL = N' IF EXISTS(SELECT 1   
             FROM '+ @c_linksrvrname + '.' + @c_tsecurename + '.dbo.pl_usr pl_usr (NOLOCK)   
             LEFT JOIN '+ @c_linksrvrname + '.'+ @c_tsecurename + '.dbo.pl_grp_usr pl_grp_usr (NOLOCK) ON pl_usr.usr_key = pl_grp_usr.usr_key  
             LEFT JOIN '+ @c_linksrvrname + '.'+ @c_tsecurename + '.dbo.pl_grp_role pl_grp_role (NOLOCK) ON pl_grp_usr.grp_key = pl_grp_role.grp_key AND pl_grp_role.app_key = 1  
             LEFT JOIN '+ @c_linksrvrname + '.'+ @c_tsecurename + '.dbo.pl_role pl_rolegrp (NOLOCK) ON pl_grp_role.role_key = pl_rolegrp.role_key   
             LEFT JOIN '+ @c_linksrvrname + '.'+ @c_tsecurename + '.dbo.pl_usr_role pl_usr_role (NOLOCK) ON pl_usr.usr_key = pl_usr_role.usr_key AND pl_usr_role.app_key = 1   
             LEFT JOIN '+ @c_linksrvrname + '.'+ @c_tsecurename + '.dbo.pl_role pl_role (NOLOCK) ON pl_usr_role.role_key = pl_role.role_key   
             WHERE pl_usr.usr_login = ''' + @c_username + '''  
             AND (pl_role.role_name = ''IDS_SUPERVISOR'' OR pl_rolegrp.role_name = ''IDS_SUPERVISOR''))   
             BEGIN  
              SET @c_flag = ''Y''  
             END'  
               
     SET @c_ExecArguments = N'@c_flag  NVARCHAR(1) OUTPUT'    
       
     
    EXEC sp_ExecuteSql @c_SQL     
                     , @c_ExecArguments    
                     , @c_flag  OUTPUT       
  --IF @n_CNTRec >= 1    
  --/*CS01 End*/                          
  --BEGIN  
  -- SET @c_flag = 'Y'  
  --END  
    
  SET @n_err = @@ERROR  
    
  IF @n_err <> 0   
  BEGIN  
    SELECT @b_success = 0  
     SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to access TSECURE. (isp_CheckSupervisorRole)'   
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
  END  
  
  QUIT_SP:              --(Wan01) 
END  

GO