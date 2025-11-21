SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store procedure: lsp_Synchronize_WM_Users                            */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Call by Backend Schedule job, to crate SQL login for new    */
/*          WM Users                                                    */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-11-2014  1.0  Shong       Created                                 */
/* 03-05-2018  1.0  TLTING      enlarge variable length                 */  
/* 14-08-2018  1.1  TLTING01    bug fix                                 */ 
/* 10-11-2020  1.2  SHONG       Create User to Archive DB               */
/* 18-05-2023  1.3  TLTING      Set ANSI ON                             */
/************************************************************************/
CREATE     PROCEDURE [WM].[lsp_Synchronize_WM_Users]
   @c_User_Name       NVARCHAR(100) = '',   
   @n_Err             INT ='' OUTPUT,    
   @c_ErrMsg          NVARCHAR(125) = '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   --SET QUOTED_IDENTIFIER OFF  
   --SET ANSI_NULLS OFF  
   --SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_USER_TYPE                  INT  
          ,@c_LDAP_DOMAIN                NVARCHAR(50)  
          ,@c_STATUS                     INT  
          ,@d_CREATED_DATE               DATETIME2  
          ,@d_UPDATED_DATE               DATETIME2  
          ,@c_WMS_USER_NAME              NVARCHAR(128)    --tlting01
          ,@n_WMS_LOGIN_SYNC             INT  
          ,@d_WMS_LOGIN_CREATED_DATE     DATETIME  
          ,@n_User_Count                 INT = 0  
          ,@n_SYNC_ERROR_NO              INT = 0   
          ,@c_SYNC_ERROR_MESSAGE         VARCHAR(1024)   
          ,@c_DBName                     VARCHAR(200)  
          ,@c_SQL                        NVARCHAR(2000)            
  
   IF @c_User_Name = ''  
   BEGIN  
      DECLARE CUR_USERS CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
          SELECT [USER_NAME]  
                ,USER_TYPE  
                ,LDAP_DOMAIN  
                ,[STATUS]   
                ,CREATED_DATE  
                ,UPDATED_DATE  
                ,WMS_USER_NAME  
                ,WMS_LOGIN_SYNC  
                ,WMS_LOGIN_CREATED_DATE  
          FROM   WM.WMS_USER_CREATION_STATUS WITH (NOLOCK)   
          WHERE WMS_LOGIN_CREATED_DATE IS NULL OR (WMS_LOGIN_SYNC = 0 OR WMS_LOGIN_SYNC IS NULL)  
          ORDER BY CREATED_DATE    
   END   
   ELSE   
   BEGIN  
      DECLARE CUR_USERS CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR      
      SELECT [USER_NAME]  
                ,USER_TYPE  
                ,LDAP_DOMAIN  
                ,[STATUS]   
                ,CREATED_DATE  
                ,UPDATED_DATE  
                ,WMS_USER_NAME  
                ,WMS_LOGIN_SYNC  
                ,WMS_LOGIN_CREATED_DATE  
      FROM   WM.WMS_USER_CREATION_STATUS WITH (NOLOCK)   
      WHERE [USER_NAME] = @c_User_Name   
   END  
      
   OPEN CUR_USERS  
  
   FETCH FROM CUR_USERS INTO @c_USER_NAME, @n_USER_TYPE, @c_LDAP_DOMAIN, @c_STATUS,  
                             @d_CREATED_DATE, @d_UPDATED_DATE, @c_WMS_USER_NAME,  
                             @n_WMS_LOGIN_SYNC, @d_WMS_LOGIN_CREATED_DATE  
  
   WHILE @@FETCH_STATUS=0  
   BEGIN      
      IF @c_USER_NAME LIKE '%_@_%_.__%'   
         SET @n_USER_TYPE = 1 -- External User  
        
      IF ISNULL(@c_LDAP_DOMAIN,'') = '' AND @n_USER_TYPE <> 1  
     BEGIN  
        SET @c_LDAP_DOMAIN = 'ALPHA'  
           
        UPDATE WM.WMS_USER_CREATION_STATUS  
         SET LDAP_DOMAIN = @c_LDAP_DOMAIN  
        WHERE WMS_USER_NAME = @c_WMS_USER_NAME   
     END  
                
     IF @n_USER_TYPE = 1   
     BEGIN  
        SET @c_WMS_USER_NAME = @c_USER_NAME  
     END     
     ELSE  
     BEGIN  

        SET @c_WMS_USER_NAME = @c_LDAP_DOMAIN + '\' + @c_USER_NAME   
     END  
             
      IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE [name] = @c_WMS_USER_NAME )  -- TLTING01
      BEGIN                           
          IF @n_USER_TYPE = 0  
          BEGIN
            SET  @n_SYNC_ERROR_NO = 0 
            SET  @c_SYNC_ERROR_MESSAGE = ''
              
             SET @c_SQL = 'CREATE LOGIN [' + @c_WMS_USER_NAME + '] FROM WINDOWS'  

             BEGIN TRY  
                EXEC sp_executesql @c_SQL    
  
             END TRY  
             BEGIN CATCH     
                SELECT @n_SYNC_ERROR_NO = ERROR_NUMBER(),   
                       @c_SYNC_ERROR_MESSAGE = ERROR_MESSAGE()  
                
             END CATCH  
          END -- IF @n_USER_TYPE = 0            
      END -- IF NOT EXISTS   
      ELSE 
      BEGIN
         BEGIN TRY
            EXECUTE AS LOGIN=@c_WMS_USER_NAME;     
            REVERT;     
         END TRY
         BEGIN CATCH
            REVERT;              
            SET @c_SQL = 'DROP USER [' + @c_WMS_USER_NAME + ']' 
            
            EXEC sp_executesql @c_SQL              
         END CATCH
      END 
      IF @n_SYNC_ERROR_NO <> 0
	  BEGIN
			PRINT @c_SQL
			PRINT @c_SYNC_ERROR_MESSAGE
		END
      --SET @c_SQL = 'EXEC sp_addrolemember N''NSQL'', N''' + @c_WMS_USER_NAME + ''''  
      --EXEC sp_executesql @c_SQL                   
           
      BEGIN TRY  
         SELECT @c_DBName = DB_NAME()  
         SET  @n_SYNC_ERROR_NO = 0 
         SET  @c_SYNC_ERROR_MESSAGE = ''
         
         EXEC sp_CreateWMSUser  
            @cUserName =@c_WMS_USER_NAME,  
            @cPassword ='lfWM@2017',  
            @cWMS_DBName =@c_DBName,  
            @cWCS_DBName ='',  
            @cDTSITF_DBName = '',  
            @cRDTUser = 'N'   
            
         -- Added by SHONG on 10-Nov-2020
         EXEC sp_CreateWMSArchiveUser 
             @cUserName = @c_WMS_USER_NAME,  @cWMS_DBName  = @c_DBName   
      END TRY  
      BEGIN CATCH             
           SELECT @n_SYNC_ERROR_NO = ERROR_NUMBER(),   
                  @c_SYNC_ERROR_MESSAGE = ERROR_MESSAGE()                 
      END CATCH        
            
      IF @n_SYNC_ERROR_NO <> 0   
      BEGIN  
        UPDATE WM.WMS_USER_CREATION_STATUS  
        SET [SYNC_ERROR_NO] = @n_SYNC_ERROR_NO,   
              [SYNC_ERROR_MESSAGE] = @c_SYNC_ERROR_MESSAGE,  
              [SYNC_NO_OF_TRY] = ISNULL([SYNC_NO_OF_TRY],0) + 1  
        WHERE [USER_NAME] = @c_USER_NAME   
      END   
      ELSE   
      BEGIN  
        UPDATE WM.WMS_USER_CREATION_STATUS  
        SET [SYNC_ERROR_NO] = 0,   
              [SYNC_ERROR_MESSAGE] = '',  
              [SYNC_NO_OF_TRY] = ISNULL([SYNC_NO_OF_TRY],0) + 1,  
              [WMS_LOGIN_SYNC] = 1,  
              [WMS_LOGIN_CREATED_DATE] = GETDATE()  
        WHERE [USER_NAME] = @c_USER_NAME           
      END  
  
      --Grant the Impersonate        
      EXEC MASTER.dbo.GrantImpersonateLogin @c_UserName = @c_WMS_USER_NAME, @ToUserName ='WMConnect'  
  
       FETCH FROM CUR_USERS INTO @c_USER_NAME, @n_USER_TYPE, @c_LDAP_DOMAIN,  
       @c_STATUS, @d_CREATED_DATE, @d_UPDATED_DATE,  
       @c_WMS_USER_NAME, @n_WMS_LOGIN_SYNC,  
       @d_WMS_LOGIN_CREATED_DATE  
   END  
  
    
   CLOSE CUR_USERS  
   DEALLOCATE CUR_USERS                                                                                                                                                                                                                                        
                                                                                                                                                                                                                                                               
                                                                                                                            
END -- Procedure   
                                 
--nsprights

GO