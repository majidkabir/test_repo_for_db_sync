SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* SP: isp_ValidateTCPMessage_Vocollect                                 */    
/* Creation Date: 20 Feb 2013                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: Validate Message Format for Generic TCP Socket Listener     */     
/*          and return SP to execute                                    */     
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */     
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver      Purposes                              */   
/* 15-01-2015   ChewKP   1.1      Set @c_RtnMessage to MAX              */
/************************************************************************/    
    
CREATE PROC [dbo].[isp_ValidateTCPMessage_Vocollect](  
     @n_SerialNo INT  
    ,@b_Debug INT  
    ,@c_MessageNum NVARCHAR(10) OUTPUT  
    ,@c_SprocName NVARCHAR(30)  OUTPUT  
    ,@b_Success INT OUTPUT  
    ,@n_Err INT OUTPUT  
    ,@c_ErrMsg NVARCHAR(250) OUTPUT  
 )    
AS    
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
     
   DECLARE @c_Status       NVARCHAR(1)  
          ,@c_DataString   NVARCHAR(4000)  
          ,@c_StorerKey    NVARCHAR(15)  
          ,@c_MessageName  NVARCHAR(200)  
          ,@c_ErrorMsg     NVARCHAR(215)    
     
   SELECT @b_Success = 1  
         ,@n_Err = 0  
         ,@c_ErrMsg = ''    
     
   SET @c_Status = '0'    
   SET @c_SprocName = 'isp_BondDPC_Dummy'   
        
   SELECT @c_DataString = ISNULL(RTRIM(DATA) ,'')  
         ,@c_StorerKey = StorerKey   
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)  
   WHERE  SerialNo = @n_SerialNo  
   AND    STATUS = @c_Status    
     
   IF @c_DataString = ''  
   BEGIN  
       SET @c_Status = '5'    
       SET @b_Success = 0    
       SET @n_Err = 50000    
       SET @c_ErrorMsg = 'TCPSocket Error: Nothing to process. SerialNo = ' +   
           CONVERT(NVARCHAR ,@n_SerialNo)  
         
       GOTO Quit  
   END    
     
   IF @b_Debug = 1  
   BEGIN  
       SELECT '@n_SerialNo : ' + CONVERT(NVARCHAR ,@n_SerialNo)   
              + ', @c_DataString : ' + @c_DataString  
   END   
  
  
   SET @c_MessageNum = RIGHT('00000000' + CAST(@n_SerialNo AS NVARCHAR(10)), 10)  
        
   /**** Check Data String Format ***/   
     
   -- MessageName (15) + MessageNumber (8)       
--   IF LEN(@c_DataString) < 23    
--   BEGIN    
--      SET @c_Status = '5'    
--      SET @b_Success = 0    
--      SET @n_Err = 50001    
--      SET @c_Errmsg = 'TCPSocket Error: Content length cannot be less than 23.'    
--      GOTO Quit    
--   END    
     
  
   DECLARE @c_StoredProcName NVARCHAR(200),  
           @n_StartPos       INT,  
           @n_EndPos         INT,   
           @c_SQLStmt      NVARCHAR(4000),  
           @c_RtnMessage   NVARCHAR(MAX),  
           @c_Parms        NVARCHAR(4000),   
           @c_ParmsVar     NVARCHAR(4000)  
     
   SET @n_StartPos = CHARINDEX('(', @c_DataString)   
   SET @n_EndPos   = CHARINDEX(')', @c_DataString)   
   SET @c_MessageName = SUBSTRING(@c_DataString, 1, @n_StartPos - 1)  
   SET @c_Parms  = SUBSTRING(@c_DataString, @n_StartPos + 1, (@n_EndPos - @n_StartPos) -1)  
     
   SELECT @c_StoredProcName = SprocName    
   FROM TCPSocket_Process WITH (NOLOCK)    
   WHERE MessageName = @c_MessageName    
   AND StorerKey = @c_StorerKey    
  
   IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @c_StoredProcName + ']') AND type in (N'P', N'PC'))  
   BEGIN  
      SET @c_Status = '5'    
      SET @b_Success = 0    
      SET @n_Err = 50004   
      SET @c_ErrorMsg = 'Stored Procedure (' + @c_StoredProcName + ' not Setup in TCPSocket_Process'   
      GOTO Quit          
   END  
     
   IF @b_Debug = 1      
   BEGIN      
      SELECT '@c_StoredProcName : ' + @c_StoredProcName  + CHAR(13) +  
             '@c_MessageName: ' + @c_MessageName   
   END    
        
   IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[' + @c_StoredProcName + ']') AND type in (N'P', N'PC'))  
   BEGIN  
      SET @c_Status = '5'    
      SET @b_Success = 0    
      SET @n_Err = 50003    
      SET @c_ErrorMsg = 'Stored Procedure not Found In Database. SP=' + @c_StoredProcName  
      GOTO Quit          
   END  
   ELSE  
   BEGIN  
      /* Execute Function and Return the String back to AckData */  
      SET @c_RtnMessage = ''  
      SET @c_SQLStmt  = N'EXEC ' +  @c_StoredProcName + ' ' + @c_Parms + N', @n_SerialNo, @c_RtnMessage OUTPUT, @b_Success OUTPUT,@n_Error OUTPUT,@c_ErrMsg OUTPUT'  
      SET @c_ParmsVar = N'@n_SerialNo INT, @c_RtnMessage NVARCHAR(MAX) OUTPUT, @b_Success INT OUTPUT,@n_Error INT OUTPUT,@c_ErrMsg NVARCHAR(255) OUTPUT'  
        
      IF @@ERROR <> 0   
      BEGIN  
         SET @c_ErrorMsg = @c_ErrMsg  
      END  
        
      IF @b_Debug = 1      
      BEGIN      
         SELECT '@c_SQLStmt : ' + @c_SQLStmt  + CHAR(13) +  
                '@c_Parms : ' + @c_Parms   
      END    
  
      
                  
      EXEC sp_ExecuteSql @c_SQLStmt  
                      ,@c_ParmsVar   
                      ,@n_SerialNo  
                      ,@c_RtnMessage OUTPUT         
                      ,@b_Success    OUTPUT  
                      ,@n_Err        OUTPUT  
                      ,@c_ErrorMsg   OUTPUT  
                        
      IF @b_Debug = 1  
      BEGIN  
         SELECT 'Return Message: ' + @c_RtnMessage   
      END             
        
      IF LEN(ISNULL(@c_RtnMessage, '')) > 0   
      BEGIN  
         SET @c_Status = '9'  
      END  
      ELSE  
      BEGIN  
         
      
         SET @c_RtnMessage = '89,Stored Procedure Not Return Any String'  
         SET @c_Status = '3'  
         SET @c_ErrorMsg = 'Stored Procedure Not Return Any String'  
         SET @b_Success = 0    
         SET @n_Err = 50004            
         GOTO Quit  
      END  
           
   END  
        
   /**** Check Data String Format ***/   
     
   /**** Get SP to execute for message ***/   
     
   /* @c_SprocName = SprocName    
   FROM TCPSocket_Process WITH (NOLOCK)    
   WHERE MessageName = @c_MessageName    
   AND StorerKey = @c_StorerKey    
     
   IF ISNULL(@c_SprocName, '') = ''    
   BEGIN    
   SET @c_Status = '5'    
   SET @b_Success = 0    
   SET @n_Err = 50003    
   SET @c_Errmsg = 'TCPSocket Error: Invalid Message Name.'    
   GOTO Quit    
   END*/    
     
  
     
        
Quit:  
     
   UPDATE TCPSocket_INLog WITH (ROWLOCK)  
   SET    MessageNum = @c_MessageNum  
         ,ErrMsg     = @c_ErrorMsg  
         ,[STATUS]   = @c_Status  
         ,ACKData    = @c_RtnMessage   
   WHERE  SerialNo = @n_SerialNo   
     
   RETURN  
END -- Procedure

GO