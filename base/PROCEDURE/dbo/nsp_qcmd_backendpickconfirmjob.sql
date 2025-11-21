SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: nsp_QCmd_BackEndPickConfirmJob                     */  
/* Purpose: Update PickDetail to Status 5 from backend                  */  
/* Return Status: None                                                  */  
/* Called By: SQL Schedule Job   BEJ - Backend Pick (All Storers)       */  
/* Updates:                                                             */  
/* Date         Author       Purposes                                   */  
/* 2019-12-13   SHONG        1.0 Submit to Q-Commander                  */
/* 06-May-2020  Shong        Addding Priority to Q-Cmd Task (SWT01)     */
/************************************************************************/  
CREATE PROCEDURE [dbo].[nsp_QCmd_BackEndPickConfirmJob]  
     @cStorerKey NVARCHAR(15)  
   , @b_debug    INT = 0 -- Leong01  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @c_PickDetailKey  NVARCHAR (10)  
           ,@n_Continue          INT
           ,@n_Cnt               INT
           ,@n_Err               INT
           ,@c_ErrMsg            CHAR(255)
           ,@n_RowCnt            INT
           ,@b_success           INT
           ,@f_Status            INT
           ,@c_AlertKey          NVARCHAR(18) --KH01
           ,@nErrSeverity        INT
           ,@dBegin              DATETIME
           ,@nErrState           INT
           ,@cHost               NVARCHAR(128)
           ,@cModule             NVARCHAR(128)
           ,@cCommand            NVARCHAR(4000)
           ,@cValue              NVARCHAR(30)
           
    DECLARE @c_APP_DB_Name         NVARCHAR(20)=''
           ,@c_DataStream          VARCHAR(10)=''
           ,@n_ThreadPerAcct       INT=0
           ,@n_ThreadPerStream     INT=0
           ,@n_MilisecondDelay     INT=0
           ,@c_IP                  NVARCHAR(20)=''
           ,@c_PORT                NVARCHAR(5)=''
           ,@c_IniFilePath         NVARCHAR(200)=''
           ,@c_CmdType             NVARCHAR(10)=''
           ,@c_TaskType            NVARCHAR(1)='' 
           ,@n_Priority            INT = 0 -- (SWT01)   
    
    SELECT @c_APP_DB_Name = APP_DB_Name
          ,@c_DataStream          = DataStream
          ,@n_ThreadPerAcct       = ThreadPerAcct
          ,@n_ThreadPerStream     = ThreadPerStream
          ,@n_MilisecondDelay     = MilisecondDelay
          ,@c_IP                  = IP
          ,@c_PORT                = PORT
          ,@c_IniFilePath         = IniFilePath
          ,@c_CmdType             = CmdType
          ,@c_TaskType            = TaskType
          ,@n_Priority            = ISNULL([Priority],0) -- (SWT01)
    FROM   QCmd_TransmitlogConfig WITH (NOLOCK)
    WHERE  TableName              = 'BACKENDPICK'
           AND [App_Name]         = 'WMS'
           AND StorerKey          = 'ALL'

    IF @c_IP=''
    BEGIN
        SET @n_Continue = 3  
        SET @n_Err = 60205  
        SET @c_ErrMsg = 'Q-Commander TCP Socket not setup!' 
        GOTO EXIT_SP
    END 
                 
   SELECT @n_Continue=1   
   SET @cModule   = ISNULL(OBJECT_NAME(@@PROCID),'')
   IF  @cModule = ''
      SET @cModule= 'nsp_QCmd_BackEndPickConfirmJob'
   SET @cHost     = ISNULL(HOST_NAME(),'')

   SET @cValue    = ''     --KH02
   SELECT @cValue = LTRIM(RTRIM([NSQLValue]))
   FROM [dbo].[NSQLCONFIG] WITH (NOLOCK)
   WHERE ConfigKey='LOGnsp_QCmd_BackEndPickConfirmJob'
  
   IF @cStorerKey = '%'   
   BEGIN  
      DECLARE CUR_Confirmed_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PickDetailKey, 
             PICKDETAIL.Storerkey                    
      FROM  PICKDETAIL WITH (NOLOCK)   
      JOIN  StorerConfig AS sc WITH (NOLOCK) ON sc.Storerkey = PICKDETAIL.Storerkey AND sc.ConfigKey='BackendPickConfirm' AND sc.SValue='1'   
      WHERE PICKDETAIL.Status < '5'   
      AND   PICKDETAIL.ShipFlag = 'P'   
      AND   PICKDETAIL.ShipFlag IS NOT NULL 
      ORDER BY PICKDETAIL.PickDetailKey              
   END  
   ELSE  
   BEGIN  
      DECLARE CUR_Confirmed_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PickDetailKey, 
             PICKDETAIL.Storerkey                     
      FROM  PICKDETAIL WITH (NOLOCK)   
      JOIN  StorerConfig AS sc WITH (NOLOCK) ON sc.Storerkey = PICKDETAIL.Storerkey AND sc.ConfigKey='BackendPickConfirm' AND sc.SValue='1'   
      WHERE PICKDETAIL.Status < '5'   
      AND   PICKDETAIL.ShipFlag = 'P'   
      AND   PICKDETAIL.ShipFlag IS NOT NULL               
      AND   PICKDETAIL.Storerkey = @cStorerKey
      ORDER BY PICKDETAIL.PickDetailKey         
   END  
     
   OPEN CUR_Confirmed_PickDetail  
  
   FETCH NEXT FROM CUR_Confirmed_PickDetail INTO @c_PickDetailKey, @cStorerKey  
  
   SELECT @f_status = @@FETCH_STATUS 
  
   WHILE @f_status <> -1  
   BEGIN  
      SELECT @c_ErrMsg = '', @n_Err = 0, @n_cnt = 0, @nErrSeverity=0   --KH01
      SET @dBegin = GETDATE()
      IF @b_debug = 1   -- KHLim01  
      BEGIN  
         PRINT 'Updating PickDetail with PickDetailKey: ' + @c_PickDetailKey + '. Start at ' + CONVERT(CHAR(10), @dBegin, 108)   
      END  
  
      SET @cCommand = N'EXEC [dbo].[nsp_QCmd_BackendPickConfirm] ' +
                      N'  @c_PickDetailKey = ''' + @c_PickDetailKey + ''' ' + 
                      N', @b_Debug    = 0 '
      
      IF NOT EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)
                    WHERE DataStream='BackendPK' 
                    AND tqt.TransmitLogKey = @c_PickDetailKey
                    AND tqt.[Status] IN ('0','1'))
      BEGIN
         BEGIN TRY
            EXEC isp_QCmd_SubmitTaskToQCommander 
                    @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others
                  , @cStorerKey        = @cStorerKey 
                  , @cDataStream       = 'BackendPK'
                  , @cCmdType          = 'SQL' 
                  , @cCommand          = @cCommand  
                  , @cTransmitlogKey   = @c_PickDetailKey
                  , @nThreadPerAcct    = @n_ThreadPerAcct                                                        
                  , @nThreadPerStream  = @n_ThreadPerStream                                                      
                  , @nMilisecondDelay  = @n_MilisecondDelay                                                      
                  , @nSeq              = 1                                                      
                  , @cIP               = @c_IP                                         
                  , @cPORT             = @c_PORT                                                
                  , @cIniFilePath      = @c_IniFilePath       
                  , @cAPPDBName        = @c_APP_DB_Name                                               
                  , @bSuccess          = 1   
                  , @nErr              = 0   
                  , @cErrMsg           = ''   
                  , @nPriority         = @n_Priority -- (SWT01)
      		
         END TRY
         BEGIN CATCH
      		   SELECT
      			   ERROR_NUMBER() AS ErrorNumber,
      			   ERROR_SEVERITY() AS ErrorSeverity,
      			   ERROR_STATE() AS ErrorState,
      			   ERROR_PROCEDURE() AS ErrorProcedure,
      			   ERROR_LINE() AS ErrorLine 
         END CATCH   		      	
      END 	
 
      FETCH_NEXT:
      FETCH NEXT FROM CUR_Confirmed_PickDetail INTO @c_PickDetailKey, @cStorerKey   
      SELECT @f_status = @@FETCH_STATUS  
   END -- While PickDetail Key  
  
   CLOSE CUR_Confirmed_PickDetail  
   DEALLOCATE CUR_Confirmed_PickDetail  

EXIT_SP:
  
   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      execute nsp_logerror @n_err, @c_errmsg, @cModule  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
      RETURN  
   END  
END

GO