SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure : ispSynchronizeRDTUser                                */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: ARCHIVEPARAMETERS Update                                       */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date           Author    	 Ver    Purposes                             */
/* 18-Apr-2012    TLTING01     1.0    Filter only acitve user              */  
/* 27-Jun-2012    TLTING02     1.1    ADD RDT if missing                   */  
/* 03-Oct-2012    TLTING03     1.2    Blank RDT user name                  */  
/* 19-Aug-2022    kelvinongcy  1.3    extend @cUserName from nvarchar(20)  */
/*                                    to nvarchar(128) (kocy01)            */
/***************************************************************************/
   
CREATE   PROC [dbo].[ispSynchronizeRDTUser] 
(   
   @cWMS_DBName    [NVARCHAR](50),    -- WMS DB Name (Required)  
   @cWCS_DBName    [NVARCHAR](50)='', -- WCS DB Name, Not Mandatory  
   @cDTSITF_DBName [NVARCHAR](50)=''  -- DTSITF DB Name, Not Mandatory   
)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
  
   DECLARE @cUserName [NVARCHAR](128),  --kocy01
           @cPassword NVARCHAR(20)  
             
             
   DECLARE CursorRDTUsers CURSOR LOCAL FAST_FORWARD READ_ONLY  
   FOR          
      SELECT UserName, [Password]   
      FROM  rdt.rdtUser (NOLOCK)   
      WHERE UserName NOT IN ('RDT', 'RESET')  
      AND   SQLUserAddDate IS NULL  
      AND   ACTIVE = '1'                  -- TLTING01  
        
   OPEN CursorRDTUsers   
  
   FETCH NEXT FROM CursorRDTUsers INTO @cUserName, @cPassword  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      -- TLTING03  
      IF @cUserName <> ''  
      BEGIN  
         EXEC sp_CreateWMSUser   
         @cUserName =@cUserName,  
         @cPassword =@cPassword,  
         @cWMS_DBName=@cWMS_DBName,   
         @cWCS_DBName=@cWCS_DBName,  
         @cDTSITF_DBName=@cDTSITF_DBName,  
         @cRDTUser = 'Y'   
      END  
      UPDATE RDT.RDTUser with (ROWLOCK)  
         SET SQLUserAddDate = GETDATE()  
      WHERE UserName = @cUserName  
        
      FETCH NEXT FROM CursorRDTUsers INTO @cUserName, @cPassword  
   END     
   CLOSE CursorRDTUsers  
   DEALLOCATE CursorRDTUsers  
     
     
   -- Remove 'Retired' User  
     
   DECLARE CursorRDTUsers CURSOR LOCAL FAST_FORWARD READ_ONLY  
   FOR          
      SELECT UserName  
      FROM  rdt.rdtUser (NOLOCK)   
      WHERE UserName NOT IN ('RDT', 'RESET')  
      AND   Active = '9'  
        
   OPEN CursorRDTUsers   
  
   FETCH NEXT FROM CursorRDTUsers INTO @cUserName  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      EXEC sp_DropWMSUser   
      @cUserName =@cUserName,  
      @cWMS_DBName=@cWMS_DBName,   
      @cWCS_DBName=@cWCS_DBName,  
      @cDTSITF_DBName=@cDTSITF_DBName  
       
      DELETE RDT.RDTUser with (ROWLOCK)  
      WHERE UserName = @cUserName  
        
      FETCH NEXT FROM CursorRDTUsers INTO @cUserName  
   END     
   CLOSE CursorRDTUsers  
   DEALLOCATE CursorRDTUsers     
     
   -- TLTING02  
   IF NOT EXISTS ( SELECT 1 FROM sys.syslogins WHERE name = 'RDT' )  
   BEGIN  
      EXEC ('USE [master]    
             CREATE LOGIN [RDT] WITH PASSWORD = ''RDT01'', SID = 0xF20BAC579967E942B3BEC75ADE11C975,   
             DEFAULT_DATABASE = [' + @cWMS_DBName + '], CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF ')   
               
      EXEC ('USE [master]    
             EXEC sys.sp_addsrvrolemember @loginame = N''RDT'', @rolename = N''sysadmin'' ')                
        
   END   
  
END   
  
  

GO