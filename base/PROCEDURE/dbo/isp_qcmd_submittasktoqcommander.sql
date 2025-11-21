SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: isp_QCmd_SubmitTaskToQCommander                    */      
/* Creation Date: 10-Jun-2003                                           */      
/* Copyright: LF Logistics                                              */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: Submitting task to Q commander                              */    
/*          Duplicate from isp_SubmitTaskToQCommander                   */      
/*                                                                      */      
/*                                                                      */      
/* Called By:  Any other related Store Procedures.                      */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 1.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Purposes                                        */      
/* 30-Aug-2016 KTLow    Add SEQ Column (KT01)                           */    
/* 06-Oct-2016 MCTang   Add Port (MC01)                                 */    
/* 10-Oct-2016 KTLow    Filter By Port (KT02)                           */    
/* 01-Nov-2016 MCTang   Filter By Port (MC02)                           */    
/* 14-Apr-2017 MCTang   Enhancement QueueData (MC03)                    */    
/* 12-Oct-2017 MCTang   Include Retry (MC04)                            */    
/* 25-May-2018 MCTang   Handle @cCmdType (MC05)                         */    
    
/* 09-Nov-2018 KHChan   Add Port into TCP Socket Msg (KH01)             */    
/* 23-May-2019 MCTang   Add Priority (MC06)                             */    
    
/* 05-Sep-2019 GHChan   Enhancement QueueData (GH01)                    */       
/* 02-Oct-2019 KCY      Add filter by 'R' (KCY01)                       */    
/* 19-Oct-2019 TKLIM    Add Support for CmdType = 'WSC' (TK01)          */    
/* 18-Mar-2021 YTKuek   Stop QCMD re-push for ASYNC (YT01)              */ 
/* 30-Mar-2021 TLTINGxx Performance tune                                */     
/* 30-Jul-2021 MCTang   Replace 'R' to 'W' when port exhausted  (MC07)  */
/* 30-Jul-2021 MCTang   Add StopSocketMsg (MC08)                        */
/* 21-DEC-2022 Wan01    LFWM-3699 - CLONE - [CN]NIKE_TRADE RETURN_      */
/*                      Suggest PA locP (Pre-finalize)by batch ASN      */
/*                      Return Q task ID                                */
/************************************************************************/      
CREATE   PROC [dbo].[isp_QCmd_SubmitTaskToQCommander]    
            @cTaskType           NVARCHAR(10)    
          , @cStorerKey          NVARCHAR(15)     
          , @cDataStream         NVARCHAR(10)    
          , @cCmdType            NVARCHAR(10)    
          , @cCommand            NVARCHAR(1024)     
          , @cTransmitlogKey     NVARCHAR(10)   = ''     
          , @nThreadPerAcct      INT            = 0     
          , @nThreadPerStream    INT            = 0    
          , @nMilisecondDelay    INT            = 0    
          , @nSeq                INT            = 1   --(KT01)    
          , @cIP                 NVARCHAR(20)   = ''  --(MC01)    
          , @cPORT               NVARCHAR(5)    = ''  --(MC01)    
          , @cIniFilePath        NVARCHAR(200)  = ''  --(MC01)    
          , @cAPPDBName          NVARCHAR(20)   = ''  --(MC03)    
          , @bSuccess            INT            OUTPUT     
          , @nErr                INT            OUTPUT     
          , @cErrMsg             NVARCHAR(256)  OUTPUT    
          , @nPriority           INT            = 0   --(MC06)    
          , @n_QTask_StopRetry   INT            = 0   --(YT01)  
          , @c_StopSocketMsg     NVARCHAR(1)    = ''  --(MC08) 
          , @nQueueID            BIGINT         = 0   OUTPUT         --(Wan01)        
AS      
BEGIN      
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
       
   DECLARE --@nQueueID         BIGINT,                --(Wan01)      
           @cDataReceived    NVARCHAR(4000)    
         , @cData            NVARCHAR(4000)     
         , @cCurrentDBName   NVARCHAR(20)       --(MC03)    
         , @cPriority        NVARCHAR(10)       --(MC06)    
         , @c_Socket_Status  NVARCHAR(1)        --(MC08)  

   SET @nQueueID = 0     
   SET @cCurrentDBName = DB_NAME()              --(MC03)    
   SET @cPriority = ''                          --(MC06)    

   IF @cTaskType = 'T' AND @cTransmitlogKey <>'' -- By TransmitlogKey    
   BEGIN    
      IF EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH (NOLOCK, FORCESEEK) --tltingxx WITH (NOLOCK)  
                WHERE tqt.DataStream = @cDataStream    
                AND   tqt.TransmitLogKey = @cTransmitlogKey      
                AND   tqt.SEQ  = @nSeq     --(KT01)    
                AND   tqt.Port = @cPORT    --(KT02)    
                AND   tqt.[Status] IN ('0','1','R','W'))  --(MC07) 
                --AND   tqt.[Status] IN ('0','1','R'))    --(KCY01)     
                --AND   tqt.[Status] IN ('0','1'))      
      BEGIN    
         GOTO SKIP_INSERT     
      END    
   END    
   ELSE IF @cTaskType='D' AND @cTransmitlogKey='' -- By Data Stream     
   BEGIN    
      IF EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH (NOLOCK, FORCESEEK) --tltingxx WITH (NOLOCK)   
                WHERE tqt.DataStream = @cDataStream    
                AND   tqt.Port       = @cPORT                  --(MC02)    
                AND   tqt.[Status]   IN ('0','1','R','W') )    --(MC07)    
                --AND   tqt.[Status]   IN ('0','1','R') )      --(KCY01)      
                --AND   tqt.[Status]   IN ('0','1') )          --(MC02)      
                --AND   tqt.[Status] ='0')                     --(MC02)    
      BEGIN    
         GOTO SKIP_INSERT     
      END             
      SET @nThreadPerAcct=1    
      SET @nThreadPerStream=1    
   END                 
       
   --(MC05) - S    
   IF @cCmdType = ''    
   BEGIN    
      SET @cCmdType = 'SQL'    
   END    
   --(MC05) - E    
    
   --(MC06) - S    
   IF @nPriority = 0     
   BEGIN    
      SET @cPriority = ''    
   END    
   ELSE    
   BEGIN    
      SET @cPriority = '|' + RTRIM(LTRIM(CAST(@nPriority AS NVARCHAR(10))))    
   END    
   --(MC06) - E    
      
   --(MC08) - S
   IF @c_StopSocketMsg = 'Y'
   BEGIN
      SET @c_Socket_Status = 'W'
   END
   ELSE 
   BEGIN
      SET @c_Socket_Status = '0'
   END
   --(MC08) - E
   
   INSERT INTO TCPSocket_QueueTask    
   (   CmdType        , Cmd             , StorerKey    
     , ThreadPerAcct  , ThreadPerStream , MilisecondDelay    
     , DataStream     , TransmitLogKey    
     , SEQ           --(KT01)    
     , PORT          --(MC01)    
     , TargetDB      --(MC03)    
     , IP            --(MC04)    
     , [Priority]    --(MC06)    
     , [Status]      --(MC08)
   )    
   VALUES    
   (   @cCmdType        , @cCommand          , @cStorerKey    
     , @nThreadPerAcct  , @nThreadPerStream  , @nMilisecondDelay    
     , @cDataStream     , @cTransmitlogKey    
     , @nSeq            --(KT01)    
     , @cPORT           --(MC01)    
     , @cAPPDBName      --(MC03)    
     , @cIP             --(MC04)    
     , @nPriority       --(MC06)   
     , @c_Socket_Status --(MC08)
   )    
          
   SELECT @nQueueID = @@IDENTITY, @nErr = @@ERROR    
       
   IF @nQueueID IS NULL OR @nQueueID = 0     
   BEGIN    
      SET @cErrMsg = 'Insert into TCPSocket_QueueTask fail, Error# ' + CAST(@nErr AS VARCHAR(10))    
      SET @bSuccess = 0     
      GOTO SKIP_INSERT     
   END
   --(MC07) - S
   IF @c_StopSocketMsg = 'Y'  
   BEGIN
      SET @cErrMsg = ''
      SET @bSuccess = 1 
      GOTO SKIP_INSERT     
   END 
   --(MC07) - E   

   --(MC03) - S    
   IF @cAPPDBName <> ''    
   BEGIN    
    
      --(TK01) START      
      /*    
      --(GH01) START         
      IF ISNULL(RTRIM(@cCmdType),'') = 'CMD'        
      BEGIN        
            --CMD|176657|CNDTSITF|"D:\CN\FTP\ExcelGenerator\ExcelGenerator.exe" "3" "3" "PUMA|0000742905"        
         SET @cData = '<STX>'          
                    + @cCmdType+'|'           
                    + CAST(@nQueueID AS VARCHAR(20)) + '|'           
                    + RTRIM(@cAPPDBName) + '|'          
                    + @cCommand        
                    + '<ETX>'             
      END        
      --(GH01) END       
      ELSE    
      BEGIN    
         --SQL|176657|CNDTSITF|EXEC CNDTSITF..isp_QCmd_ExecuteSQL @cAPPDBName=CNDTSITF, @nQTaskID=176657     
         SET @cData = '<STX>'    
                    + @cCmdType+'|'     
                    + CAST(@nQueueID AS VARCHAR(20)) + '|'     
                    + RTRIM(@cAPPDBName) + '|'    
                    --+ 'EXEC ' + RTRIM(@cAPPDBName) + '..isp_QCmd_ExecuteSQL @cTargetDB=''' + RTRIM(@cCurrentDBName) + ''', @nQTaskID=' + CAST(@nQueueID AS VARCHAR(20)) --(KH01)    
                    + 'EXEC ' + RTRIM(@cAPPDBName) + '..isp_QCmd_ExecuteSQL @cTargetDB=''' + RTRIM(@cCurrentDBName) + ''', @nQTaskID=' + CAST(@nQueueID AS VARCHAR(20)) + ', @cPort=''' + @cPORT + '''' --(KH01)    
                    + @cPriority       --(MC06)    
                    + '<ETX>'       
      END    
      */      
      IF ISNULL(RTRIM(@cCmdType),'') = 'SQL'          
      BEGIN          
         --SQL|176657|CNDTSITF|EXEC CNDTSITF..isp_QCmd_ExecuteSQL @cAPPDBName=CNDTSITF, @nQTaskID=176657, @cPort='30209'|1    
         SET @cData = '<STX>'      
                    + @cCmdType+'|'       
                    + CAST(@nQueueID AS VARCHAR(20)) + '|'       
                    + RTRIM(@cAPPDBName) + '|'      
                    --+ 'EXEC ' + RTRIM(@cAPPDBName) + '..isp_QCmd_ExecuteSQL @cTargetDB=''' + RTRIM(@cCurrentDBName) + ''', @nQTaskID=' + CAST(@nQueueID AS VARCHAR(20)) --(KH01)      
                    + 'EXEC ' + RTRIM(@cAPPDBName) + '..isp_QCmd_ExecuteSQL @cTargetDB=''' + RTRIM(@cCurrentDBName) + ''', @nQTaskID=' + CAST(@nQueueID AS VARCHAR(20)) + ', @cPort=''' + @cPORT + '''' --(KH01)      
                    + @cPriority       --(MC06)      
                    + '<ETX>'         
      END          
      ELSE      
      BEGIN      
            --CMD|176657|CNDTSITF|"D:\CN\FTP\ExcelGenerator\ExcelGenerator.exe" "3" "3" "PUMA|0000742905"|1     
            --WSC|176657|CNDTSITF|EXEC dbo.isp0000P_WSNonGIS_GENERIC_SendRequest7 @n_GISURLNo=56,@n_IsWSLog=0,@b_Success=0,@n_Err=0,@c_ErrMsg ='',@b_debug=0,@c_CategoryId='Q',@c_InDataStream='2702',@n_InSeqNo=4238|1    
         SET @cData = '<STX>'            
                    + @cCmdType+'|'             
                    + CAST(@nQueueID AS VARCHAR(20)) + '|'             
                    + RTRIM(@cAPPDBName) + '|'            
                    + @cCommand          
                    + @cPriority       --(MC06)      
                    + '<ETX>'               
      END      
      --(TK01) END     
    
   END    
   --(MC03) - E    
   ELSE    
   BEGIN    
      SET @cData = '<STX>'+ CAST(@nQueueID AS VARCHAR(20)) + '<ETX>'         
   END      
    PRINT 'Command Sending Message to QComannder'   
   EXEC isp_QCmd_SendTCPSocketMsg    
        @cApplication     = 'QCommander'    
      , @cStorerKey       = @cStorerKey     
      , @cMessageNum      = ''    
      , @cData            = @cData    
      , @cIP              = @cIP            --(MC01)    
      , @cPORT            = @cPORT          --(MC01)    
      , @cIniFilePath     = @cIniFilePath   --(MC01)    
      , @cDataReceived    = @cDataReceived  OUTPUT    
      , @bSuccess         = @bSuccess       OUTPUT     
      , @nErr             = @nErr           OUTPUT     
      , @cErrMsg          = @cErrMsg        OUTPUT    
    
   --(MC04) - S    
   IF ISNULL(RTRIM(LTRIM(@cErrMsg)), '') <> ''    
   BEGIN    
      --(YT01)-S  
      IF @n_QTask_StopRetry = 1  
      BEGIN  
         UPDATE TCPSocket_QueueTask  WITH (ROWLOCK)               
         SET    STATUS     = '5'     
              , EditDate   = GETDATE()    
              , EditWho    = SUSER_SNAME()    
              , ErrMsg     = ISNULL(RTRIM(LTRIM(@cErrMsg)), '')    
         WHERE  ID   = @nQueueID    
      END  
      ELSE  
      BEGIN  
         UPDATE TCPSocket_QueueTask  WITH (ROWLOCK)               
         --SET    STATUS     = 'R'                 --(MC07)
         SET    STATUS     = 'W'                   --(MC07)
              , EditDate   = GETDATE()    
              , EditWho    = SUSER_SNAME()    
              , ErrMsg     = ISNULL(RTRIM(LTRIM(@cErrMsg)), '')    
         WHERE  ID   = @nQueueID    
      END  
      --(YT01)-E  
   END    
   --(MC04) - E    
   
   RETURN      
       
   SKIP_INSERT:    
       
END -- procedure 

GO