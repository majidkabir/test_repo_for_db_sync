SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_QCmd_SubmitAutoMbolPack                        */    
/* Creation Date: 2020-09-03                                            */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-15010 - WMS-15010_CN AutoMbol WMS2WCS                   */
/*                               trigger rule                           */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Rev   Purposes                                  */ 
/* 04-SEP-2020 Shong    1.0   Created                                   */ 
/* 11-NOV-2020 Wan01    1.1   Do not wait scheduler job to submit as take*/
/*                            1 min (slow)                              */           
/************************************************************************/    
CREATE PROC [dbo].[isp_QCmd_SubmitAutoMbolPack] (
     @c_PickSlipNo  NVARCHAR(10)     
   , @b_Success     INT = 1            OUTPUT    
   , @n_Err         INT = ''           OUTPUT    
   , @c_ErrMsg      NVARCHAR(250) = '' OUTPUT     
   , @b_Debug       INT = 0     
)    
AS    
BEGIN  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @c_StorerKey           NVARCHAR(15)=''
          ,@c_OrderKey            NVARCHAR(10)=''
          ,@c_Command             NVARCHAR(1000)=''
          ,@c_TransmitlogKey      NVARCHAR(10)
          ,@c_IP                  VARCHAR(20)
          ,@c_Port                VARCHAR(10)
          ,@n_ThreadPerAcct       INT
          ,@n_MilisecondDelay     INT
          ,@c_APP_DB_Name         VARCHAR(20)         --(Wan01) Destination DB Name > 10 for eg CNDTSITFUAM
          ,@n_ThreadPerStream     INT
          ,@c_IniFilePath         NVARCHAR(200)
          ,@nStartTranCount       INT=0
          ,@n_Continue            INT 
          ,@c_DataStream          VARCHAR(10) = ''
         
   SET @nStartTranCount = @@TRANCOUNT
   SET @n_Continue = 1
   SET @c_OrderKey = ''
   SET @c_DataStream = '4655'
   
   SELECT @c_OrderKey = ph.OrderKey, 
          @c_StorerKey = ph.StorerKey
   FROM PackHeader AS ph WITH(NOLOCK)
   WHERE ph.PickSlipNo = @c_PickSlipNo 

   IF @c_OrderKey <> ''
   BEGIN
      EXEC ispGenTransmitLog2
         @c_TableName = 'AutoMbolPack',
         @c_Key1 = @c_OrderKey,
         @c_Key2 = '',
         @c_Key3 = @c_StorerKey,
         @c_TransmitBatch = '',
         @b_Success = @b_Success OUTPUT,
         @n_err = @n_err OUTPUT,
         @c_errmsg = @c_errmsg OUTPUT  
      
      IF @b_Success  = 1
      BEGIN
         SET @c_TransmitlogKey = ''
         
         SELECT @c_TransmitlogKey = t.transmitlogkey
         FROM TRANSMITLOG2 AS t WITH(NOLOCK)
         WHERE t.tablename = 'AutoMbolPack'
         AND t.key1 = @c_OrderKey
         AND t.key3 = @c_StorerKey 
         AND t.transmitflag = '0'
         
         IF @c_TransmitlogKey <> ''
         BEGIN
            SELECT @c_Command = StoredProcName + ',@c_TransmitlogKey=''' + @c_TransmitlogKey + ''' ' 
                  ,@c_IP = IP
                  ,@c_Port = Port
                  ,@n_ThreadPerAcct = ThreadPerAcct
                  ,@n_MilisecondDelay = MilisecondDelay 
                  ,@c_APP_DB_Name = App_DB_Name--TargetDB      --(Wan01) As instruct by Chen Yu
                  ,@c_IniFilePath = IniFilePath                --(Wan01) As instruct by Chen Yu
                  ,@n_ThreadPerStream = ThreadPerStream        --(Wan01) As instruct by Chen Yu
            FROM  QCmd_TransmitlogConfig WITH (NOLOCK)  
            WHERE DataStream = @c_DataStream 
              AND TableName = 'AutoMbolPack'      
              AND StorerKey = @c_StorerKey
              
            IF @b_Debug = 1    
            BEGIN      
               PRINT '  > @c_Command : ' + @c_Command                          
            END 
                                   
            --(Wan01) - Let isp_QCmd_SubmitTaskToQCommander to validate Tranmitlogkey
            --IF NOT EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
            --              WHERE tqt.DataStream = @c_DataStream)
            --BEGIN
               BEGIN TRY    
               EXEC isp_QCmd_SubmitTaskToQCommander     
                     @cTaskType          = 'T' -- D=By Datastream, T=Transmitlog, O=Others   --(Wan01) Change from 'O' to 'T'          
                     , @cStorerKey       = @c_StorerKey                                                
                     , @cDataStream      = @c_DataStream                                                         
                     , @cCmdType         = 'SQL'                                                      
                     , @cCommand         = @c_Command                                                  
                     , @cTransmitlogKey  = @c_TransmitlogKey                                             
                     , @nThreadPerAcct   = @n_ThreadPerAcct                                                    
                     , @nThreadPerStream = @n_ThreadPerStream                                                          
                     , @nMilisecondDelay = @n_MilisecondDelay                                                          
                     , @nSeq             = 1                           
                     , @cIP              = @c_IP                                             
                     , @cPORT            = @c_PORT                                                    
                     , @cIniFilePath     = @c_IniFilePath           
                     , @cAPPDBName       = @c_APP_DB_Name                                                   
                     , @bSuccess         = @b_Success OUTPUT                                 --(Wan01)     
                     , @nErr             = @n_Err OUTPUT      
                     , @cErrMsg          = @c_ErrMsg OUTPUT 
                     , @nPriority        = 2                                                 --(Wan01) As instruct by Chen Yu
                
               IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''    
               BEGIN
                  IF @b_Debug = 1    
                     PRINT @c_ErrMsg                                                           
                  GOTO EXIT_SP     
               END                  
                                    
               END TRY    
               BEGIN CATCH    
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  IF @b_Debug = 1    
                     PRINT @c_ErrMsg                                                                
                  GOTO EXIT_SP                   
               END CATCH                
            --END                            --(Wan01)
         END         
      END
   END

   EXIT_SP:    
   WHILE @@TRANCOUNT > 0     
      COMMIT TRAN;        
                         
   WHILE @@TRANCOUNT < @nStartTranCount    
      BEGIN TRAN;    
          
   IF @n_Continue = 3    
   BEGIN    
    SET @b_Success = 0    
   END     
END -- procedure    

GO