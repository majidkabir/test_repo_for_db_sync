SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/            
/* Stored Procedure: sp_CreateWMSUser                                            */            
/* Creation Date: 03-Apr-2011                                                    */            
/* Copyright: IDS                                                                */            
/* Written by: Shong                                                             */            
/*                                                                               */            
/* Purpose:  Create WMS & RDT User automatically                                 */            
/*                                                                               */            
/* Called By:  Backend Job                                                       */            
/*                                                                               */            
/* PVCS Version: 1.0                                                             */            
/*                                                                               */            
/* Version: 5.4                                                                  */            
/*                                                                               */            
/* Data Modifications:                                                           */            
/*                                                                               */            
/* Updates:                                                                      */            
/* Date           Author      Ver.  Purposes                                     */    
/* 04-Apr-2012    Shong       1.1   Check DB Exists before create user           */  
/* 10-Oct-2013    TLTING      1.2   Alter with check policy off                  */  
/* 13-Mar-2015    TLTING      1.3   RDT user no need alter password              */  
/* 09-Feb-2018    SHONG       1.4   Windows User No need alter password          */
/* 03-May-2021    LZG         1.5`  INC1487464 - Extended @cUserName length(ZG01)*/
/*********************************************************************************/      
CREATE PROC [dbo].[sp_CreateWMSUser] (    
   @cUserName VARCHAR(128),       -- ZG01
   @cPassword NVARCHAR(20),    
   @cWMS_DBName VARCHAR(50),     
   @cWCS_DBName VARCHAR(50) = '',    
   @cDTSITF_DBName VARCHAR(50) = '',    
   @cRDTUser  CHAR(1) = 'N' -- Y/N    
)    
AS    
BEGIN    
   SELECT @cUserName '@cUserName', @cPassword '@cPassword'     
     
   DECLARE @n_Count    INT = 0,  
           @n_IsNTUser INT = 0   
     
   SELECT @n_Count = 1,  
          @n_IsNTUser = isntuser    
   FROM [master].[dbo].[syslogins]    
   WHERE [master].[dbo].[syslogins].[loginname] = @cUserName  
                   
   IF @n_Count = 0       
   BEGIN    
      EXEC ('USE [master]    
             CREATE LOGIN [' + @cUserName + '] WITH PASSWORD=N''' + @cPassword +     
             ''', DEFAULT_DATABASE=[' + @cWMS_DBName + '], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF')          
   END    
   ELSE  
   BEGIN      
    -- Alter password  
      -- RDT user no need alter password  
      -- If Windows User, no password required   
      IF @cRDTUser <> 'Y' AND @n_IsNTUser = 0   
      BEGIN  
         EXEC ('USE [master]    
                ALTER LOGIN [' + @cUserName + '] WITH PASSWORD=N''' + @cPassword + ''', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF ')          
      END  
   END     
       
   DECLARE @nRowCount INT    
          ,@cSQL      NVARCHAR(MAX)    
          
   IF NOT EXISTS( SELECT 1 FROM [master].[sys].[databases] WHERE [name] = @cWMS_DBName )  
   BEGIN           
      PRINT 'Invalid WMS DB!'  
   END   
   ELSE  
   BEGIN  
      SET @cSQL = N'SELECT @nRowCount = COUNT(1) FROM [' + @cWMS_DBName + '].[dbo].[sysusers] ' +    
                 'WHERE [sysusers].[name] = @cUserName'    
                            
      EXEC sp_ExecuteSql @cSQL, N'@cUserName VARCHAR(20), @nRowCount INT OUTPUT',    
                         @cUserName, @nRowCount OUTPUT     
        
      IF @nRowCount = 0   
      BEGIN    
         EXEC ('USE [' + @cWMS_DBName + ']    
                CREATE USER [' + @cUserName + '] FOR LOGIN [' + @cUserName + ']    
                ')         
      END    
          
      EXEC('USE [' + @cWMS_DBName + ']    
            EXEC sp_addrolemember N''NSQL'', N''' + @cUserName + '''    
            ')        
   END  
   
     
   IF ISNULL(@cWCS_DBName,'') <> ''  AND DB_ID(@cWCS_DBName) IS NOT NULL   
   BEGIN    
      SET @cSQL = N'SELECT @nRowCount = COUNT(1) FROM [' + @cWCS_DBName + '].[dbo].[sysusers] ' +    
                 'WHERE [sysusers].[name] = @cUserName'    
                            
      EXEC sp_ExecuteSql @cSQL, N'@cUserName VARCHAR(20), @nRowCount INT OUTPUT',    
                         @cUserName, @nRowCount OUTPUT     
        
      IF @nRowCount = 0    
      BEGIN    
         EXEC ('USE [' + @cWCS_DBName + ']    
                CREATE USER [' + @cUserName + '] FOR LOGIN [' + @cUserName + ']    
                ')         
      END    
          
      EXEC('USE [' + @cWCS_DBName + ']    
            EXEC sp_addrolemember N''NSQL'', N''' + @cUserName + '''    
            ')    
             
   END      
       
   IF ISNULL(@cDTSITF_DBName,'') <> '' AND DB_ID(@cDTSITF_DBName) IS NOT NULL     
   BEGIN    
      SET @cSQL = N'SELECT @nRowCount = COUNT(1) FROM [' + @cDTSITF_DBName + '].[dbo].[sysusers] ' +    
                 'WHERE [sysusers].[name] = @cUserName'    
                            
      EXEC sp_ExecuteSql @cSQL, N'@cUserName VARCHAR(20), @nRowCount INT OUTPUT',    
                         @cUserName, @nRowCount OUTPUT     
        
      IF @nRowCount = 0    
      BEGIN    
         EXEC ('USE [' + @cDTSITF_DBName + ']    
                CREATE USER [' + @cUserName + '] FOR LOGIN [' + @cUserName + ']    
                ')         
      END    
          
      EXEC('USE [' + @cDTSITF_DBName + ']    
            EXEC sp_addrolemember N''NSQL'', N''' + @cUserName + '''    
            ')    
             
   END       
          
   IF @cRDTUser = 'Y'    
   BEGIN    
      SET @nRowCount = 0    
          
      SELECT @nRowCount = COUNT(1)     
      FROM [master].[dbo].[sysusers]    
      WHERE [sysusers].[name] = @cUserName    
        
      IF @nRowCount = 0     
      BEGIN    
         EXEC ('USE [master]    
                CREATE USER [' + @cUserName + '] FOR LOGIN [' + @cUserName + ']    
                ')               
      END    
        
      EXEC('USE [master]    
      EXEC sp_addrolemember N''RDT'', N''' + @cUserName + '''    
      ')    
             
   END          
END    

GO