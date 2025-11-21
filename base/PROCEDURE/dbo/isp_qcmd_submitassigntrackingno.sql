SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_QCmd_SubmitAssignTrackingNo                    */    
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
/* 10-Aug-2017  Shong   1.1   Remove HardCode IP and Port               */ 
/* 06-Sep-2017  TLTING  1.2   Performance tune                          */ 
/* 06-May-2020  Shong   1.4   Addding Priority to Q-Cmd Task (SWT01)    */
/* 18-Aug-2021  NJOW01  1.5   WMS-14231 add config to change carrier    */
/*                            field mapping                             */
/************************************************************************/  
CREATE PROC [dbo].[isp_QCmd_SubmitAssignTrackingNo] (
   @d_StartDate  DATETIME,  
   @bSuccess     INT = 1 OUTPUT,
   @nErr         INT = 0 OUTPUT,
   @cErrMsg      NVARCHAR(250) = '' OUTPUT,
   @bDebug       INT = 0
)
AS 
BEGIN
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   
       
   DECLARE @cKeyName         NVARCHAR(50),
           @cCarrierName     NVARCHAR(10),
           @cCommand         NVARCHAR(2014),
           @cStorerKey       NVARCHAR(15)  

	DECLARE @c_APP_DB_Name           NVARCHAR(20)
         , @c_DataStream            VARCHAR(10)
         , @n_ThreadPerAcct         INT = 0 
         , @n_ThreadPerStream       INT = 0 
         , @n_MilisecondDelay       INT = 0 
         , @c_TableName             NVARCHAR(20)  = ''
         , @c_IP                    NVARCHAR(20)  = ''
         , @c_PORT                  NVARCHAR(5)   = ''
         , @c_IniFilePath           NVARCHAR(200) = ''
         , @c_CmdType               NVARCHAR(10)  = ''        
         , @c_TaskType              NVARCHAR(1)   = ''     
         , @n_Priority              INT = 0 -- (SWT01)   
         
	SELECT @c_APP_DB_Name          = APP_DB_Name
	      , @c_DataStream          = DataStream 
	      , @n_ThreadPerAcct       = ThreadPerAcct 
	      , @n_ThreadPerStream     = ThreadPerStream 
	      , @n_MilisecondDelay     = MilisecondDelay 
         , @c_IP                  = IP
         , @c_PORT                = PORT
         , @c_IniFilePath         = IniFilePath
         , @c_CmdType             = CmdType             
         , @c_TaskType            = TaskType       
         , @n_Priority            = ISNULL([Priority],0) -- (SWT01)            
	FROM  QCmd_TransmitlogConfig WITH (NOLOCK)
	WHERE TableName               = 'ASSIGNTRACKNO'
   AND   [App_Name]					= 'WMS'
   AND   StorerKey               = 'ALL' 
   
   IF @c_IP = ''
      RETURN               
                 
   DECLARE C_Shipper CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT distinct  clk.Short
   FROM  CODELKUP   clk WITH (NOLOCK)  
   WHERE clk.LISTNAME = N'AsgnTNo'
   AND clk.Code2 = '1'

   OPEN C_Shipper
   
   FETCH FROM C_Shipper INTO @cCarrierName 
   
   WHILE @@FETCH_STATUS = 0
   BEGIN                           
         DECLARE C_Carrier CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT MAX(O.StorerKey), clk.Long 
         FROM  CODELKUP   clk WITH (NOLOCK)           
         OUTER APPLY(SELECT Authority, Option1 from dbo.fnc_getright2(clk.notes, clk.storerkey,'','AsgnTnoGetCarrierFrom')) CFG  --NJOW01
                JOIN  ORDERS O WITH (NOLOCK)
                     ON  clk.Storerkey = O.StorerKey
                     AND clk.Short = CASE WHEN CFG.Authority=  '1' AND CFG.Option1 = 'M_FAX2' THEN O.M_Fax2 ELSE O.Shipperkey END  --NJOW01
                     AND clk.Notes = O.Facility
                     AND clk.UDF01 = CASE 
                                          WHEN ISNULL(clk.UDF01, '') <> '' THEN ISNULL(O.UserDefine02, '')
                                          ELSE clk.UDF01
                                     END
                     AND clk.UDF02 = CASE 
                                          WHEN ISNULL(clk.UDF02, '') <> '' THEN ISNULL(O.UserDefine03, '')
                                          ELSE clk.UDF02
                                     END
                     AND clk.UDF03 = CASE 
                                          WHEN ISNULL(clk.UDF03, '') <> '' THEN ISNULL(O.[Type], '')
                                          ELSE clk.UDF03
                                     END
         WHERE  (  O.UserDefine04 = '')
         AND (  O.ShipperKey <> '')
         AND O.DocType = 'E'
         AND O.[Status] < '5' 
         AND O.AddDate > @d_StartDate 
         AND clk.LISTNAME = N'AsgnTNo'
         AND clk.Code2 = '1'
         AND clk.Short = @cCarrierName
         GROUP BY clk.Long 
                         
         OPEN C_Carrier
   
         FETCH FROM C_Carrier INTO @cStorerKey, @cKeyName 
   
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @cCommand = N'EXEC [dbo].[isp_BatchAssignTrackingNo]' +
                            N'  @cKeyName = ''' + @cKeyName + ''' ' + 
                            N', @cCarrierName = ''' + @cCarrierName + ''' ' + 
                            N', @bSuccess  = 1 ' + 
                            N', @nErr      = 0 ' + 
                            N', @cErrMsg   = '''' ' + 
                            N', @bDebug    = 0 '

            IF NOT EXISTS(SELECT 1 FROM TCPSocket_QueueTask AS tqt WITH (NOLOCK)
                          WHERE tqt.CmdType='SQL'
                          AND   tqt.StorerKey = @cStorerKey 
                          AND   tqt.[Status] IN ('0','1') 
                          AND   tqt.TransmitLogKey = @cCarrierName 
                          AND   tqt.Cmd = @cCommand )
            BEGIN
      	      BEGIN TRY
                  EXEC isp_QCmd_SubmitTaskToQCommander 
                          @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others
                        , @cStorerKey        = @cStorerKey 
                        , @cDataStream       = 'AsgnTNo'
                        , @cCmdType          = 'SQL' 
                        , @cCommand          = @cCommand  
                        , @cTransmitlogKey   = @cCarrierName
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
       
             FETCH FROM C_Carrier INTO @cStorerKey, @cKeyName  
         END
   
         CLOSE C_Carrier
         DEALLOCATE C_Carrier    

          FETCH FROM C_Shipper INTO @cCarrierName 
      END
   
      CLOSE C_Shipper
      DEALLOCATE C_Shipper    

END


GO