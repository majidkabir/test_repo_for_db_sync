SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: nsp_QCmd_ValidateMBOL                              */  
/* Purpose: Update PickDetail to Status 9 from backend                  */  
/* Called By: SQL Schedule Job    BEJ - Backend ValidateMBOL (ALL)      */  
/* Updates:                                                             */  
/* Date         Author       Purposes                                   */  
/* 23-Mar-2020  Shong        Created                                    */
/* 29-Mar-2020  TLTING01     StorerConfig - NoCont4VldMBOL              */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[nsp_QCmd_ValidateMBOL]  
      @c_StorerKey NVARCHAR(15) = '%'  
     ,@b_debug    INT = 0  
     ,@nMinuteToSkip INT = 30   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue        INT = 1,  
           @n_cnt             INT = 0,  
           @n_err             INT = 0,  
           @c_ErrMsg          NvarCHAR (255) = '',               
           @c_MBOLKey         NVARCHAR(10) = '',  
           @f_status          INT = '',  
           @n_StartTran       INT = 0,  
           @c_ContainerStatus NVARCHAR(10) = '0',  
           @c_ValidatedFlag   NCHAR(1) = 'N',  
           @d_EditDate        DATETIME   

   DECLARE @n_RowCnt          INT = 0,
           @b_ReturnCode      INT = 0,  
           @b_ReturnErr       INT = 0,  
           @c_ReturnErrMsg    NVARCHAR (255) = '',  
           @b_success         INT = 0   
           
   DECLARE  @cHost               NVARCHAR(128)           
           ,@cModule             NVARCHAR(128)
           ,@cCommand            NVARCHAR(4000)           
           ,@cValue              NVARCHAR(30)
                        
   SET @n_StartTran = @@TRANCOUNT  
   SET @n_continue=1
   
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
           ,@n_ShipCounter         INT = 0       

   DECLARE @n_SC_NoCont4VldMBOL INT = 0  
      
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
    FROM   QCmd_TransmitlogConfig WITH (NOLOCK)  
    WHERE  TableName              = 'BackendValidMBOL'  
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
      SET @cModule= 'nsp_QCmd_ValidateMBOL'  
   SET @cHost     = ISNULL(HOST_NAME(),'')  
  
   SET @cValue    = ''     --KH02  
   SELECT @cValue = LTRIM(RTRIM([NSQLValue]))  
   FROM [dbo].[NSQLCONFIG] WITH (NOLOCK)  
   WHERE ConfigKey='LOGnsp_QCmd_ValidateMBOL'  
                 
     
   SET @c_MBOLKey  = ''  
  
   IF ISNULL(RTRIM(@c_StorerKey), '') = ''  
      SET @c_StorerKey = '%'  
  
   IF @c_StorerKey = '%'  
   BEGIN  
      DECLARE CUR_MBOLKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Mbol.MbolKey, ISNULL(Mbol.ValidatedFlag, 'N'), Mbol.EditDate, MAX(O.StorerKey), ISNULL(Mbol.ShipCounter,0)   
      FROM dbo.Mbol Mbol (NOLOCK)  
      JOIN dbo.MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MBOL.MbolKey  
      JOIN dbo.Orders O (NOLOCK) ON o.OrderKey = MD.OrderKey  
      WHERE Mbol.status = '5'   
      AND NOT EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK)  
                       WHERE C.LISTNAME  = 'VALISTORER'  
                       AND C.Code = O.StorerKey ) 
      GROUP BY Mbol.MbolKey, ISNULL(Mbol.ValidatedFlag, 'N'), Mbol.EditDate, ISNULL(Mbol.ShipCounter,0) 
      ORDER BY Mbol.editdate, Mbol.MbolKey  
            
   END  
   ELSE  
   BEGIN  
      DECLARE CUR_MBOLKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT  DISTINCT Mbol.MbolKey, ISNULL(Mbol.ValidatedFlag, 'N'), Mbol.EditDate, @c_StorerKey, ISNULL(Mbol.ShipCounter,0)    
      FROM dbo.Mbol (NOLOCK)  
      JOIN dbo.MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MBOL.MbolKey  
      JOIN dbo.Orders O (NOLOCK) ON o.OrderKey = MD.OrderKey  
      WHERE Mbol.status = '5'   
      AND O.StorerKey = @c_StorerKey  
      ORDER BY Mbol.editdate, Mbol.MbolKey  
   END  
  
   OPEN CUR_MBOLKey  
   FETCH NEXT FROM CUR_MBOLKey INTO @c_MBOLKey, @c_ValidatedFlag, @d_EditDate, @c_StorerKey, @n_ShipCounter 
  
   SELECT @f_status = @@FETCH_STATUS  
   WHILE @f_status <> -1  
   BEGIN  
      SET @b_ReturnCode = 0    
      SET @b_ReturnErr  = 0     
      SET @c_ReturnErrMsg = ''   
  
      SELECT @n_continue =1  
      IF @b_debug = 1  
      BEGIN  
       PRINT ''   
         PRINT '** MBOLKey: ' + @c_MBOLKey +   
               ' ValidatedFlag: ' + @c_ValidatedFlag +  
               ' EditDate: ' + CONVERT(VARCHAR(20), @d_EditDate, 120) + 
               ' Minute Diff: ' +   CONVERT(VARCHAR(20), DATEDIFF(minute, @d_EditDate, GETDATE())) +
               ' Ship Counter: ' +  CAST(@n_ShipCounter AS VARCHAR(3)) 
      END  

      -- If this is the 1st time, go to submit task.
      IF @c_ValidatedFlag = 'N'
         GOTO SUBMIT_TASK

     --TLTING01                        
      SET @n_SC_NoCont4VldMBOL = 0
      EXECUTE nspGetRight   
         NULL,          -- facility  
         @c_StorerKey, -- StorerKey  
         NULL,          -- Sku  
         'NoCont4VldMBOL', -- Configkey for CartonTrack delay archive 
         @b_Success OUTPUT,   
         @n_SC_NoCont4VldMBOL OUTPUT,     -- this is return result
         @n_err OUTPUT,  
         @c_errmsg OUTPUT
    
      IF (@n_err <> 0)
      BEGIN
         PRINT N' FAIL Retrieved Config.  ConfigKey ''NoCont4VldMBOL'' for storerkey ''' + @c_StorerKey +'''. '
      END   

      SET @c_ContainerStatus = '0'
      -- tlting01
      IF @n_SC_NoCont4VldMBOL = 1
      BEGIN
         SET @c_ContainerStatus   = '9'
      END
      ELSE
      BEGIN             
         SELECT TOP 1 
            @c_ContainerStatus =  ISNULL(C.[Status],'0')  
         FROM CONTAINER C WITH (NOLOCK)  
         JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON C.ContainerKey = CD.ContainerKey  
         JOIN dbo.Mbol M WITH (NOLOCK) ON CD.PalletKey = M.ExternMbolKey  
         WHERE M.MBOLKey = @c_MBOLKey  
         AND C.ContainerType = 'ECOM' 

         IF @b_debug = 1  
         BEGIN  
            PRINT '   Container Status: ' + @c_ContainerStatus 
         END 
      END
      
      -- If Validation Fail, try 3 times
      IF @c_ValidatedFlag = 'E' AND @n_ShipCounter >= 3 AND @c_ContainerStatus <> '9'
      BEGIN
         IF @b_debug = 1
            PRINT '-->SKIP: Validation Fail, Container Status <> 9, No of Try ' + CAST(@n_ShipCounter AS VARCHAR(5))
        
         GOTO FETCH_NEXT
      END

      IF DATEDIFF(minute, @d_EditDate, GETDATE()) < @nMinuteToSkip AND @n_ShipCounter > 0
      BEGIN
         IF @b_debug = 1
            PRINT '-->SKIP: Validation Fail, No of Try ' + CAST(@n_ShipCounter AS VARCHAR(5)) 
                  + ' Minutes Diff: '  
                  + CAST(DATEDIFF(minute, @d_EditDate, GETDATE()) AS VARCHAR(5))
        
         GOTO FETCH_NEXT
      END      
                                                     
      IF @c_ContainerStatus = '9' AND @c_ValidatedFlag = 'E' 
      BEGIN  
         IF ( SELECT count(distinct convert(char(15), adddate, 120) ) -- tlting02 more than 10 min  
               FROM [dbo].[MBOLErrorReport]  (NOLOCK)  
               WHERE MBOLKey = @c_MBOLKey ) = 1  -- having error more 2 times Validate MBOL   
         BEGIN  
            SET @c_ValidatedFlag = 'N'
            IF @b_debug = 1  
            BEGIN  
               PRINT '>>> SET @c_ValidatedFlag = N '   
            END                  
         END  
         ELSE  
         BEGIN  
            IF @b_debug = 1  
            BEGIN  
               PRINT '-->SKIP: ValidatedFlag - E AND EditDate = ' + CONVERT(VARCHAR(20), @d_EditDate, 120)  
            END      
            GOTO FETCH_NEXT    
         END  
      END -- IF @c_ContainerStatus = '9'
         
      IF @c_ContainerStatus = '0' AND @c_ValidatedFlag ='E' AND @n_ShipCounter >= 3
      BEGIN
         IF @b_debug = 1  
         BEGIN  
            PRINT '-->SKIP: ValidatedFlag - E, No of Try' + CONVERT(VARCHAR(20), @n_ShipCounter)  
         END  
                     
         GOTO FETCH_NEXT
      END  
      
      IF @c_ContainerStatus = '0' AND @c_ValidatedFlag = 'Y' 
      BEGIN
         IF @b_debug = 1  
         BEGIN  
            PRINT '-->SKIP: ValidatedFlag - Y, Container Status = 0'   
         END  
                  
         GOTO FETCH_NEXT
      END  
         
      SUBMIT_TASK:
               
      SET @cCommand = N'EXEC [dbo].[nsp_QCmd_Backend_ValidateMBOL] ' +  
                        N'  @c_MBOLKey = ''' + @c_MBOLKey + ''' ' +   
                        N', @c_ValidatedFlag = ''' + @c_ValidatedFlag + ''' ' + 
                        N', @b_Debug = 0 '  
        
      IF NOT EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH(NOLOCK)  
                     WHERE DataStream='BEndVldMBL'   
                     AND tqt.TransmitLogKey = @c_MBOLKey  
                     AND tqt.[Status] IN ('0','1'))  
      BEGIN  
         BEGIN TRY  
            EXEC isp_QCmd_SubmitTaskToQCommander   
                     @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others  
                  , @cStorerKey        = @c_StorerKey   
                  , @cDataStream       = 'BEndVldMBL'  
                  , @cCmdType          = 'SQL'   
                  , @cCommand          = @cCommand    
                  , @cTransmitlogKey   = @c_MBOLKey  
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

            IF @b_debug = 1  
            BEGIN  
               PRINT ''   
               PRINT ' MBOLKey - ' + @c_MBOLKey +   
                     ', Task Submitted!'   
            END  
                
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
  
      FETCH NEXT FROM CUR_MBOLKey INTO @c_MBOLKey, @c_ValidatedFlag, @d_EditDate, @c_StorerKey, @n_ShipCounter   
      SELECT @f_status = @@FETCH_STATUS  
   END -- While  
  
   CLOSE CUR_MBOLKey  
   DEALLOCATE CUR_MBOLKey  
  
   EXIT_SP:
  
   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      execute nsp_logerror @n_err, @c_errmsg, "nsp_QCmd_ValidateMBOL"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
END  

GO