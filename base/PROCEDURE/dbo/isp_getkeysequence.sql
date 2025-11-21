SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_GetKeySequence                                 */    
/* Creation Date: 25-Apr-2017                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
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
/* Date         Author  Rev   Purposes                                  */    
/* 25-Apr-2017  Shong   1.0   Initial Version                           */    
/************************************************************************/
CREATE PROCEDURE  [dbo].[isp_GetKeySequence]  
    @cKeyName        NVARCHAR(50)  
,   @cPrefixed       VARCHAR(5) = ''           
,   @nFieldLength    INT = 0   
,   @cKeystring      NVARCHAR(25)   OUTPUT    
,   @bSuccess        INT            OUTPUT    
,   @nErr            INT            OUTPUT    
,   @cErrmsg         NVARCHAR(250)  OUTPUT    
,   @bResultSet      INT       = 0    
,   @nBatch          INT       = 1    
AS
BEGIN
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
   
   DECLARE 
      @nCount     INT, /* next key */  
      @nCounter   INT, 
      @cBigString VARCHAR(25), 
      @nStartTCnt INT 

   DECLARE @cStoredProcName SYSNAME
   SET @cStoredProcName = OBJECT_NAME(@@PROCID)
         
   SET @nStartTCnt = @@TRANCOUNT;
   SET @cKeystring = ''
      
   DECLARE @nContinue int /* Continuation flag: 
                              1=Continue, 
                              2=failed but continue processsing, 
                              3=failed do not continue processing, 
                              4=successful but skip furthur processing */    

   IF OBJECT_ID(@cKeyName) IS NULL
   BEGIN
      SET @nContinue = 3     
      SET @nErr=302751       
      SET @cErrmsg='ERROR:'+CONVERT(varchar(5),@nErr)+': Object ' + @cKeyName + ' not found database'    --YJ01
      GOTO QUIT_SP      
   END
   
   DECLARE @cSQL NVARCHAR(2000)
   
   SET @cSQL = N'SELECT @nCount = NEXT VALUE FOR ' + @cKeyName 
   SET @nCounter = 0
        
   WHILE @nCounter < @nBatch
   BEGIN
       EXEC sys.sp_executesql @cSQL, N'@nCount BIGINT OUTPUT', @nCount OUTPUT 
       IF @@ERROR = 0 
       BEGIN
          SET @nCounter = @nCounter + 1   
       END
       ELSE 
       BEGIN
          SET @nContinue = 3  
          SET @cErrmsg = 'GetKey ' + @cKeyName + ' failed'           
       END     
   END 
   
   SET @cBigString = CAST(@nCount AS VARCHAR(25))  
   SET @cBigString = RIGHT(Replicate('0',25) + RTRIM(@cBigString), 25)
   SET @nFieldLength = @nFieldLength - LEN(RTRIM(@cPrefixed))          
   SET @cBigString = RIGHT(RTRIM(@cBigString), @nFieldLength)   
   SET @cKeystring = ISNULL(RTRIM(@cPrefixed),'') + Rtrim(@cBigString)    
          
   QUIT_SP:
   IF @nContinue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @bSuccess = 0         
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @nStartTCnt     
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE     
      BEGIN    
         WHILE @@TRANCOUNT > @nStartTCnt     
         BEGIN    
            COMMIT TRAN    
         END              
      END    
    
      EXECUTE nsp_LogError @nErr, @cErrmsg, 'isp_GetKeySequence'    
      RAISERROR (@cErrmsg, 16, 1) WITH SETERROR      
      RETURN        
   END    
   ELSE     
   BEGIN    
      SELECT @bSuccess = 1    
      WHILE @@TRANCOUNT > @nStartTCnt     
      BEGIN    
            COMMIT TRAN    
      END    
      RETURN        
   END
END

GO