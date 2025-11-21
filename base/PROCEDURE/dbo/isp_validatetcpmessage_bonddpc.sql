SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* SP: isp_ValidateTCPMessage_BondDPC                                   */    
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
/************************************************************************/    
    
CREATE PROC [dbo].[isp_ValidateTCPMessage_BondDPC](  
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
          ,@c_MessageName  NVARCHAR(15)    
     
   SELECT @b_Success = 1  
         ,@n_Err = 0  
         ,@c_ErrMsg = ''    
     
   SET @c_Status = '0'    
     
   SELECT @c_DataString = ISNULL(RTRIM(DATA) ,'')  
         ,@c_StorerKey = StorerKey  
         ,@c_MessageNum = RIGHT('D0000000' + CAST(SerialNo AS VARCHAR(10)), 10)   
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)  
   WHERE  SerialNo = @n_SerialNo  
   AND    STATUS = @c_Status    
     
   IF @c_DataString = ''  
   BEGIN  
       SET @c_Status = '5'    
       SET @b_Success = 0    
       SET @n_Err = 50000    
       SET @c_Errmsg = 'TCPSocket Error: Nothing to process. SerialNo = ' +   
           CONVERT(NVARCHAR ,@n_SerialNo)  
         
       GOTO Quit  
   END    
     
   IF @b_Debug = 1  
   BEGIN  
       SELECT '@n_SerialNo : ' + CONVERT(NVARCHAR ,@n_SerialNo)   
              + ', @c_DataString : ' + @c_DataString  
   END   
     
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
     
   DECLARE @c_Delim CHAR(1)   
   DECLARE @t_DPCRec TABLE (  
      Seqno    INT,   
      ColValue VARCHAR(215)  
   )  
     
   SET @c_Delim = '<TAB>'
  
   INSERT INTO @t_DPCRec  
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_DataString)     
   
   UPDATE @t_DPCRec
   SET ColValue = REPLACE ( ColValue, 'TAB>', '')
     
   SELECT @c_MessageNum =ColValue   
   FROM @t_DPCRec  
   WHERE Seqno=3  
     
   IF ISNUMERIC(@c_MessageNum) <> 1    
   BEGIN    
      SET @c_Status = '5'    
      SET @b_Success = 0    
      SET @n_Err = 50002    
      SET @c_Errmsg = 'TCPSocket Error: Message Number not numeric.'    
      GOTO Quit    
   END    
     
   IF @b_Debug = 1      
   BEGIN      
      SELECT '@c_MessageName : ' + @c_MessageName    
      + ', @c_MessageNum : ' + @c_MessageNum      
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
     
   SET @c_SprocName = 'isp_DPC_Inbound'   
     
   /**** Get SP to execute for message ***/    
     
   IF EXISTS(  
          SELECT 1  
          FROM   TCPSocket_INLog WITH (NOLOCK)  
          WHERE  MessageNum = @c_MessageNum  
          AND    MessageType = 'RECEIVE'  
          AND    StorerKey = @c_StorerKey  
      )  
   BEGIN  
       SET @c_Status = 'E'    
       --SET @b_Success = 1    
       --SET @n_Err = 50003    
       --SET @c_Errmsg = 'TCPSocket Error: Message Processed.'   
       GOTO Quit  
   END   
        
Quit:  
     
   UPDATE TCPSocket_INLog WITH (ROWLOCK)  
   SET    MessageNum = @c_MessageNum  
         ,ErrMsg = @c_Errmsg  
         ,STATUS = @c_Status  
   WHERE  SerialNo = @n_SerialNo   
     
   RETURN  
END -- Procedure              
  

GO