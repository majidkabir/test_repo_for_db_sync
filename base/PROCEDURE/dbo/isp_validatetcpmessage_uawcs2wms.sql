SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* SP: isp_ValidateTCPMessage_UAWCS2WMS                                 */      
/* Creation Date: 20 Feb 2013                                           */      
/* Copyright: IDS                                                       */      
/* Written by:                                                          */      
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
/* 2019-06-27   James    1.0      WMS9329. Created                      */  
/************************************************************************/      
      
CREATE PROC [dbo].[isp_ValidateTCPMessage_UAWCS2WMS](    
     @n_SerialNo        INT        
    ,@b_Debug           INT        
    ,@c_MessageNum      NVARCHAR(10)   OUTPUT    
    ,@c_SprocName       NVARCHAR(30)   OUTPUT    
    ,@c_Status          NVARCHAR(1)    OUTPUT    
    ,@c_RespondMsg      NVARCHAR(500)  OUTPUT    
    ,@b_Success         INT            OUTPUT    
    ,@n_Err             INT            OUTPUT    
    ,@c_ErrMsg          NVARCHAR(250)  OUTPUT    
  
 )      
AS      
BEGIN    
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF      
       
   DECLARE @c_DataString   NVARCHAR( 4000)    
          ,@c_StorerKey    NVARCHAR( 15)    
          ,@c_MessageName  NVARCHAR( 200)    
          ,@c_ErrorMsg     NVARCHAR( 215)    
          ,@c_ColValue     NVARCHAR( 215)    
          ,@c_WCSMessage   NVARCHAR( MAX)  
          ,@c_RtnMessage   NVARCHAR( MAX)    
          ,@c_SerialNo     NVARCHAR( 10)    
          ,@c_BatchNo      NVARCHAR( 20)    
          ,@c_SubSeq       NVARCHAR( 2)    
          ,@c_LaneNo       NVARCHAR( 2)    
          ,@c_FreeNo       NVARCHAR( 2)    
          ,@c_BatchCtNo    NVARCHAR( MAX)   
          ,@c_ChildID      NVARCHAR( 20)  
          ,@c_DropID       NVARCHAR( 20)  
          ,@c_DropIDType   NVARCHAR( 10)  
          ,@n_Seqno        INT  
  
   SELECT @b_Success = 1    
         ,@n_Err = 0    
         ,@c_ErrMsg = ''      
       
   SET @c_Status = '0'      
   SET @c_SprocName = ''     
          
   SELECT @c_DataString = ISNULL(RTRIM(DATA) ,'')    
         ,@c_StorerKey = StorerKey     
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)    
   WHERE  SerialNo = @n_SerialNo    
   AND    STATUS = @c_Status      
     
   IF @c_StorerKey = ''  
      SET @c_StorerKey = 'UA'  
  
   IF @c_DataString = ''    
   BEGIN    
       SET @c_Status = '5'      
       SET @b_Success = 0      
       SET @n_Err = 141951      
       SET @c_ErrMsg = 'TCPSocket Error: Nothing to process. ( SerialNo = ' +     
           CONVERT(NVARCHAR ,@n_SerialNo) + ')'  
           
       GOTO Exit_Proc    
   END      
       
   IF @b_Debug = 1    
   BEGIN    
       SELECT '@n_SerialNo : ' + CONVERT(NVARCHAR ,@n_SerialNo)     
              + ', @c_DataString : ' + @c_DataString    
              + ', @c_Status : ' + @c_Status  
   END     
    
    
   SET @c_MessageNum = RIGHT('00000000' + CAST(@n_SerialNo AS NVARCHAR(10)), 10)    
          
   DECLARE @c_Delim CHAR(1)       
   DECLARE @t_WCSRec TABLE (      
      Seqno    INT,       
      ColValue VARCHAR(215) )      
  
   -- remove ack/nak  
   SET @c_DataString = REPLACE( @c_DataString, 'chr(2)', '')  
   SET @c_DataString = REPLACE( @c_DataString, 'chr(3)', '')  
  
   SET @c_Delim = '|'  
   INSERT INTO @t_WCSRec     
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_DataString)   
  
   DECLARE @curD CURSOR    
   SET @curD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT Seqno, ColValue FROM @t_WCSRec ORDER BY Seqno  
   OPEN @curD  
   FETCH NEXT FROM @curD INTO @n_Seqno, @c_ColValue  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF @n_Seqno = 1 SET @c_SerialNo = @c_ColValue  
      IF @n_Seqno = 2 SET @c_BatchNo = @c_ColValue  
      IF @n_Seqno = 3 SET @c_SubSeq = @c_ColValue  
      IF @n_Seqno = 4 SET @c_LaneNo = @c_ColValue  
      IF @n_Seqno = 5 SET @c_FreeNo = @c_ColValue  
      IF @n_Seqno = 6 SET @c_BatchCtNo = @c_ColValue  
  
      FETCH NEXT FROM @curD INTO @n_Seqno, @c_ColValue  
   END  
  
   IF @b_Debug = 1  
      SELECT '@c_SerialNo', @c_SerialNo, '@c_BatchNo', @c_BatchNo, '@c_SubSeq', @c_SubSeq,   
      '@c_LaneNo', @c_LaneNo, '@c_FreeNo', @c_FreeNo, '@c_BatchCtNo', @c_BatchCtNo  
  
     
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN isp_ValidateTCPMessage_UAWCS2WMS  
  
   IF @n_Err <> 0  
   BEGIN    
       SET @c_Status = '5'      
       SET @b_Success = 0      
       SET @c_ErrorMsg = RTRIM( @c_ErrMsg) +   
          ' ( SerialNo = ' + CONVERT(NVARCHAR ,@n_SerialNo) + ')'  
           
       GOTO RollBackTran    
   END   
  
   SET @c_DropID = 'UA' + RTRIM( @c_BatchNo) + '-' + @c_SubSeq  
   SET @c_DropIDType = 'ECOM-MULTI'  
  
   IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @c_DropID)  
   BEGIN    
      SET @c_Status = '5'      
      SET @b_Success = 0      
      SET @n_Err = 141952     
      SET @c_ErrMsg = 'DROPID: ' + RTRIM( @c_DropID) + ' EXISTS ' +   
          ' ( SerialNo = ' + CONVERT(NVARCHAR ,@n_SerialNo) + ')'  
      GOTO RollBackTran            
   END   
  
   INSERT INTO dbo.DropID ( DropID, DropIDType, Status, DropLOC, UDF01) VALUES  
   (@c_DropID, @c_DropIDType, '0', @c_LaneNo, @c_FreeNo)  
  
   IF @@ERROR <> 0  
   BEGIN    
      SET @c_Status = '5'      
      SET @b_Success = 0      
      SET @n_Err = 141953     
      SET @c_ErrMsg = 'INSERT DROPID FAIL' +   
          ' ( SerialNo = ' + CONVERT(NVARCHAR ,@n_SerialNo) + ')'  
      GOTO RollBackTran            
   END   
  
   DECLARE @t_WCSCtn TABLE (      
      Seqno    INT,       
      ColValue VARCHAR(215)      
   )      
  
   SET @c_Delim = '~'  
   INSERT INTO @t_WCSCtn     
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_BatchCtNo)   
  
   IF @b_Debug = 1    
      SELECT * FROM @t_WCSCtn  
   DECLARE @curInsDD CURSOR  
   SET @curInsDD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
   SELECT Seqno, ColValue FROM @t_WCSCtn ORDER BY Seqno  
   OPEN @curInsDD  
   FETCH NEXT FROM @curInsDD INTO @n_Seqno, @c_ChildID  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM dbo.DropidDetail WITH (NOLOCK)   
                  WHERE DropID = @c_DropID   
                  AND   ChildID = @c_ChildID)  
      BEGIN    
         SET @c_Status = '5'      
         SET @b_Success = 0      
         SET @n_Err = 141954     
         SET @c_ErrMsg = 'DropID: ' + RTRIM( @c_DropID) + ' CHILDID: ' + RTRIM( @c_ChildID) + ' EXISTS ' +   
             ' ( SerialNo = ' + CONVERT(NVARCHAR ,@n_SerialNo) + ')'  
         GOTO RollBackTran            
      END   
  
      INSERT INTO dbo.DropidDetail (DropID, ChildID, UserDefine01) VALUES  
      (@c_DropID, @c_ChildID, @n_Seqno)  
  
      IF @@ERROR <> 0  
      BEGIN    
         SET @c_Status = '5'      
         SET @b_Success = 0   
         SET @n_Err = 141955     
         SET @c_ErrMsg = 'INSERT DROPID DETAIL FAIL' +   
          ' ( SerialNo = ' + CONVERT(NVARCHAR ,@n_SerialNo) + ')'  
         GOTO RollBackTran            
      END   
        
      FETCH NEXT FROM @curInsDD INTO @n_Seqno, @c_ChildID  
   END  
    
  GOTO Quit  
  
  RollBackTran:  
      ROLLBACK TRAN isp_ValidateTCPMessage_UAWCS2WMS  
  Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
   
   IF @n_Err <> 0  
   BEGIN   
	  SET @c_RespondMsg = CHAR(2) + @c_SerialNo + '|' + '2' + '|' + CAST(@n_Err AS NVARCHAR(10)) + '|' + CHAR(3) 
   END  
   ELSE  
   BEGIN   
      SET @c_RespondMsg = CHAR(2) + @c_SerialNo + '|' + '1' + '|' + 'OK' + '|' + CHAR(3)  
   END     
          
   Exit_Proc:    
   UPDATE TCPSocket_INLog WITH (ROWLOCK)    
   SET    MessageNum = @c_MessageNum    
         ,ErrMsg     = @c_ErrMsg    
         ,[STATUS]   = @c_Status    
         ,ACKData    = @c_RespondMsg     
   WHERE  SerialNo = @n_SerialNo      
       
   RETURN    
END -- Procedure  


GO