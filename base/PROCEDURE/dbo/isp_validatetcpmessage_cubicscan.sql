SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* SP: isp_ValidateTCPMessage_CubicScan                                   */      
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
CREATE PROC [dbo].[isp_ValidateTCPMessage_CubicScan](    
     @n_SerialNo INT    
    ,@b_Debug INT    
    ,@c_MessageNum NVARCHAR(10) OUTPUT    
    ,@c_SprocName NVARCHAR(30)  OUTPUT    
    ,@b_Success INT OUTPUT    
    ,@n_Err INT OUTPUT    
    ,@c_ErrMsg NVARCHAR(250) OUTPUT   
 ,@c_Status NVARCHAR(10) OUTPUT  
 ,@c_RespondMsg NVARCHAR(250) OUTPUT   
 )      
AS      
BEGIN    
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF      
       
   DECLARE-- @c_Status       NVARCHAR(1)    
          @c_DataString   NVARCHAR(4000)    
          ,@c_StorerKey    NVARCHAR(15)    
          ,@c_MessageName  NVARCHAR(15)    
      
      
   DECLARE @Type   NVARCHAR(10),  
     @DeviceID  NVARCHAR(10),  
     @Referencekey NVARCHAR(20),  
     @Weight   Float,  
     @Length   Float,  
     @Width   Float,  
     @Height   Float,  
         @Datetime  NVARCHAR(14)  
  
  
   SELECT @b_Success = 1    
         ,@n_Err = 0    
         ,@c_ErrMsg = ''      
       
   SET @c_Status = '0'      
       
   SELECT @c_DataString = ISNULL(RTRIM(DATA) ,'')    
         --,@c_StorerKey = StorerKey    
         ,@c_MessageNum = RIGHT('D0000000' + CAST(SerialNo AS VARCHAR(10)), 10)     
 --  ,@c_MessageName = Replace(Substring(Data, 1, 16),'<TAB>','')  
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
       
  
 SELECT @Type =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=2  
   
 SELECT @DeviceID =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=3  
  
 SELECT @Referencekey =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=4  
  
 SELECT @Weight =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=5    
  
 SELECT @Length =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=6    
  
 SELECT @Width =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=7    
  
 SELECT @Height =ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=8    
  
 SELECT @Datetime = ColValue     
 FROM @t_DPCRec    
 WHERE Seqno=9    
  
  
 IF @Referencekey<> ''  
 BEGIN  
   SELECT @c_StorerKey = Storerkey   
   FROM(  
     select distinct storerkey, labelno refkey from packdetail (nolock) where labelno = @Referencekey  
     union  
     select distinct storerkey, labelno refkey from packdetail (nolock) where dropid = @Referencekey  
    ) a  
 END  
  
  
       
   IF @b_Debug = 1        
   BEGIN        
      SELECT '@c_MessageName : ' + @c_MessageName      
      + ', @c_MessageNum : ' + @c_MessageNum ,  
    @c_MessageName as 'c_MessageName',  
     @Type as 'Type',  
     @DeviceID as 'DeviceID',  
     @Referencekey as 'ReferenceKey',  
     @Weight as 'Weight',  
     @Length as 'Length',  
     @Width as 'Width',  
     @Height as 'Height',  
     @Datetime as 'Datetime',  
     @c_StorerKey as 'StorerKey'  
   END      
       
       
   /**** Check Data String Format ***/     
       
   /**** Get SP to execute for message ***/     
       
     
   SELECT @c_SprocName = SprocName     
   FROM TCPSocket_Process WITH (NOLOCK)      
   WHERE MessageName = @Type AND Storerkey = @c_StorerKey  
        
       
   IF ISNULL(@c_SprocName, '') = ''      
   BEGIN      
    SET @c_Status = 'E'      
    SET @b_Success = 0      
    SET @n_Err = 50003      
    SET @c_Errmsg = 'SProcName cannot be blank. (isp_ValidateTCPMessage_CubicScan)'  
    GOTO Quit      
   END  
               
   /**** Get SP to execute for message ***/      
    
  --select @c_SprocName, @c_StorerKey  
  
   /**** End Execute SP ***/      
       
   --IF EXISTS(    
   --       SELECT 1    
   --       FROM   TCPSocket_INLog WITH (NOLOCK)    
   --       WHERE  MessageNum = @c_MessageNum    
   --       AND    MessageType = 'RECEIVE'    
   --       AND    StorerKey = @c_StorerKey    
   --   )    
   --BEGIN    
   --    SET @c_Status = 'E'      
   --    --SET @b_Success = 1      
   --    --SET @n_Err = 50003      
   --    --SET @c_Errmsg = 'TCPSocket Error: Message Processed.'     
   --    GOTO Quit    
   --END     
          
Quit:    
       
   UPDATE TCPSocket_INLog WITH (ROWLOCK)    
   SET    MessageNum = @c_MessageNum    
         ,ErrMsg = @c_Errmsg    
         ,STATUS = @c_Status    
   WHERE  SerialNo = @n_SerialNo     
     
   SET @c_Status ='9'  
   SET @c_RespondMsg = @c_Errmsg  
       
   RETURN    
END -- Procedure                
    
  
/*  
  
declare @c_MessageNum NVARCHAR(10), @c_SprocName NVARCHAR(30), @b_Success int, @n_Err int, @c_ErrMsg NVARCHAR(250)  
  
exec isp_ValidateTCPMessage_CubicScan  2573639, 0  
    ,@c_MessageNum  OUTPUT    
    ,@c_SprocName   OUTPUT    
    ,@b_Success  OUTPUT    
    ,@n_Err  OUTPUT    
    ,@c_ErrMsg  OUTPUT    
   
select @c_MessageNum , @c_SprocName , @b_Success , @n_Err , @c_ErrMsg   
  
  
  
  
*/

GO