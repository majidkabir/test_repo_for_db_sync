SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_BatchAssignTrackingNo                          */    
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
/* Date         Author   Rev   Purposes                                 */    
/* 25-Apr-2017  Shong    1.0   Initial Version                          */ 
/* 28-Sep-2017  TLTING01 2.2   Bug fix                                  */ 
/* 20-Oct-2017  TLTING02 2.3   exclude online courier orders            */  
/* 12-Jul-2018  TLTING03 2.5   exclude sostatus by codelkup             */
/* 18-Aug-2021  NJOW01   2.6   WMS-14231 add config to change carrier   */
/*                             field mapping                            */
/* 22-Oct-2021  TLTING   2.7   Enhance delay - AsgnTNoDly               */
/* 02-Aug-2022  NJOW02   2.8   WMS-19622 skip assign track# by platform */
/*                             & shipperkey in codelkup                 */   
/************************************************************************/  
CREATE PROC [dbo].[isp_BatchAssignTrackingNo] (
   @cKeyName NVARCHAR(50),
   @cCarrierName NVARCHAR(10),
   @bSuccess INT OUTPUT,
   @nErr INT OUTPUT,
   @cErrMsg NVARCHAR(250) OUTPUT,
   @bDebug INT = 0
)
AS 
BEGIN
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @nTrackBatchNo   INT,
           @cTrackBatchNo   NVARCHAR(10), 
           @nRowID          BIGINT,
           @nStartTCnt      INT,
           @nContinue       INT

   DECLARE @cOrderKey       NVARCHAR(10),
           @cTrackingNo     NVARCHAR(20),
           @dStartTime      DATETIME 

   DECLARE @nRowRef         BIGINT,
           @cCarrierRef1    NVARCHAR(40),
           @nSuccessFlag    INT,
           @nRetry          INT,
           @nTotalOrder     INT,
           @cSQL            NVARCHAR(1000),
           @nTotalRec       INT,
           @b_TryOnce       INT = 0 
   DECLARE @nDelayMins      INT = 0,    -- stv01
           @cDelayValue     NVARCHAR(10) -- stv01
           
   SET @nStartTCnt = @@TRANCOUNT

   IF NOT EXISTS (SELECT 1 FROM CartonTrack_Pool AS ctp WITH(NOLOCK) 
                  WHERE ctp.CarrierName =  @cCarrierName AND ctp.KeyName = @cKeyName )
   BEGIN
   	RETURN 
   END

   IF OBJECT_ID('tempdb..#CartonTrack') IS NOT NULL
       DROP TABLE #CartonTrack

   CREATE TABLE #CartonTrack
   (
      RowRef          BIGINT,
      TrackingNo      NVARCHAR(20),
      CarrierRef1     NVARCHAR(40)
   )

   SET @nStartTCnt = @@TRANCOUNT
   SET @nContinue = 1

   -- Delete all the outstanding orders for same key name and carrier
   DECLARE C_TRACKNO_WIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowID
   FROM ORDERS_TRACKNO_WIP WITH (NOLOCK)
   WHERE KeyName = @cKeyName 
   AND   CarrierName = @cCarrierName 

   OPEN C_TRACKNO_WIP

   FETCH FROM C_TRACKNO_WIP INTO @nRowID

   WHILE @@FETCH_STATUS = 0
   BEGIN
      DELETE FROM ORDERS_TRACKNO_WIP
      WHERE RowID = @nRowID

      FETCH FROM C_TRACKNO_WIP INTO @nRowID
   END   
   CLOSE C_TRACKNO_WIP
   DEALLOCATE C_TRACKNO_WIP

   EXEC isp_GetKeySequence 
        @cKeyName = 'TrackBatchNo',
        @cPrefixed = '',
        @nFieldLength = 10,
        @cKeystring = @cTrackBatchNo OUTPUT,
        @bSuccess = @bSuccess OUTPUT,
        @nErr = @nErr OUTPUT,
        @cErrmsg = @cErrMsg OUTPUT,
        @bResultSet = 1,
        @nBatch = 1

   SET @nTrackBatchNo = CAST(@cTrackBatchNo AS INT)

   -- Commit all transaction
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN

   -- stv01 Get delay mins (Max 10 )
   SELECT @cDelayValue = Short 
   FROM Codelkup(nolock) WHERE Listname ='AsgnTNoDly' and Code = 'AssignTrackingNo'

   IF ISNUMERIC(@cDelayValue) = 1  
   BEGIN   
     SET @nDelayMins = cast(@cDelayValue as INT)
   END
   ELSE
   BEGIN
     SET @nDelayMins = 0  
   END
   
   IF   @nDelayMins > 10
   BEGIN
      SET @nDelayMins = 10 
   END
   -- stv01
   
   INSERT INTO ORDERS_TRACKNO_WIP
     (
       TrackBatchNo,
       KeyName,
       CarrierName,
       OrderKey
     )
   SELECT TOP 4000 @nTrackBatchNo, @cKeyName, @cCarrierName, o.OrderKey
   FROM   ORDERS o WITH (NOLOCK)
   WHERE  (o.UserDefine04 IS NULL OR o.UserDefine04 = '')
   AND (o.ShipperKey IS NOT NULL AND o.ShipperKey <> '')
   AND o.DocType = 'E'
   AND o.sostatus <> 'PENDGET'    -- tlting02
   AND NOT EXISTS ( SELECT 1 FROM codelkup (NOLOCK) WHERE codelkup.LISTNAME = 'SOSTAXTNO' AND codelkup.code = O.sostatus ) --tlting03
   AND O.status <> 'CANC'   
   AND o.Adddate <= DATEADD(MINUTE, 0 - @nDelayMins ,GETDATE())   -- stv01
   AND EXISTS(SELECT 1 
              FROM CODELKUP AS clk WITH (NOLOCK)
              OUTER APPLY(SELECT Authority, Option1 from dbo.fnc_getright2(clk.notes, clk.storerkey,'','AsgnTnoGetCarrierFrom')) CFG  --NJOW01             
              WHERE clk.Storerkey = o.StorerKey
              AND clk.Short = CASE WHEN CFG.Authority=  '1' AND CFG.Option1 = 'M_FAX2' THEN O.M_Fax2 ELSE O.Shipperkey END  --NJOW01               
              AND clk.Notes = o.Facility
              AND clk.LISTNAME = 'AsgnTNo'
              AND clk.UDF01 = CASE 
                                   WHEN ISNULL(clk.UDF01, '') <> '' THEN ISNULL(o.UserDefine02, '')
                                   ELSE clk.UDF01
                              END
              AND clk.UDF02 = CASE 
                                   WHEN ISNULL(clk.UDF02, '') <> '' THEN ISNULL(o.UserDefine03, '')
                                   ELSE clk.UDF02
                              END
              AND clk.UDF03 = CASE 
                                   WHEN ISNULL(clk.UDF03, '') <> '' THEN ISNULL(o.[Type], '')
                                   ELSE clk.UDF03
                              END
              AND clk.Long = @cKeyName
              AND clk.Short = @cCarrierName )             
   AND NOT EXISTS(SELECT 1 FROM CODELKUP CL (NOLOCK)
      	           WHERE CL.Listname = 'SKIPTRKNO'
      	           AND CL.Storerkey = o.Storerkey
      	           AND CL.Short = o.Shipperkey
      	           AND CL.Long = o.ECOM_Platform) --NJOW02          
   ORDER BY CASE WHEN o.[Status] IN ('1','2') THEN 1 ELSE 2 END, o.OrderKey 

   SET @dStartTime = GETDATE()

   SET @nTotalOrder = 0 
   SELECT @nTotalOrder = COUNT(*)
   FROM   ORDERS_TRACKNO_WIP WITH (NOLOCK)
   WHERE TrackBatchNo = @nTrackBatchNo 

   IF @nTotalOrder > 0 
   BEGIN         
       SET @cSQL = N'SELECT TOP ' + CAST(@nTotalOrder AS VARCHAR(10)) + 
      N'  ctp.RowRef, ctp.TrackingNo, ISNULL(ctp.CarrierRef1, '''') ' +
      ' FROM CartonTrack_Pool AS ctp WITH(NOLOCK) ' +
      ' WHERE ctp.CarrierName =  @cCarrierName ' +
      ' AND ctp.KeyName =  @cKeyName ' +
      ' AND   ctp.CarrierRef2 = '''' ' +   -- tlting01
      ' AND   ctp.LabelNo = '''' ' +         -- tlting01
      ' ORDER BY ctp.RowRef '

       --PRINT @cSQL

       INSERT INTO #CartonTrack
         (
           RowRef,
           TrackingNo,
           CarrierRef1
         )
       --EXEC (@cSQL)
       EXEC sp_ExecuteSQL @cSQL, N'@cCarrierName nvarchar(30), @cKeyName nvarchar(30)', @cCarrierName, @cKeyName


       SET @nTotalRec = 0

       DECLARE C_CartonTrack CURSOR LOCAL FAST_FORWARD READ_ONLY 
       FOR
           SELECT RowRef,
                  TrackingNo,
                  CarrierRef1
           FROM   #CartonTrack WITH (NOLOCK) 

       OPEN C_CartonTrack

       FETCH FROM C_CartonTrack INTO @nRowRef, @cTrackingNo, @cCarrierRef1

       WHILE @@FETCH_STATUS = 0
       BEGIN
           SET @cOrderKey = ''

           SELECT TOP 1 
                  @cOrderKey = OrderKey, 
                  @nRowID = ot.RowID
           FROM   ORDERS_TRACKNO_WIP AS ot WITH (NOLOCK)
           WHERE ot.TrackBatchNo = @nTrackBatchNo
           ORDER BY ot.RowID

           IF @cOrderKey = ''
             BREAK 

       	  BEGIN TRAN TRAN_ORDER 

           IF ISNULL(RTRIM(@cTrackingNo), '') <> '' 
           BEGIN
              SET @nSuccessFlag = 0      

              DELETE FROM dbo.CartonTrack_Pool WITH (ROWLOCK)
              WHERE RowRef = @nRowRef 

              SET @nSuccessFlag = @@ROWCOUNT
           END
           IF @nSuccessFlag > 0
           BEGIN
              SET @nSuccessFlag = 0
              BEGIN TRY
                 INSERT INTO dbo.CartonTrack
                    ( TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef1, CarrierRef2 )
                 VALUES
                    ( @cTrackingNo, @cCarrierName, @cKeyName , @cOrderKey, @cCarrierRef1, 'GET' )

                 SET @nSuccessFlag = @@ROWCOUNT
              END TRY
              BEGIN CATCH
                 INSERT INTO ERRLOG
                 ( LogDate,     UserId, ErrorID,
                 	SystemState, Module, ErrorText )
                 SELECT GETDATE(), SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), 'isp_BatchAssignTrackingNo', ERROR_MESSAGE()

                 DELETE FROM #CartonTrack
                 WHERE  RowRef = @nRowRef

                 SET @nSuccessFlag = 0
              END CATCH
           END
           IF @nSuccessFlag = 0
           BEGIN
              SET @nRetry = ISNULL(@nRetry, 0) + 1  

              IF @nRetry > 3
                 GOTO EXIT_SP
              ELSE
                 GOTO GET_NEXT_TRACKING_NO
           END

           BEGIN TRY
              EXEC  [dbo].[ispAsgnTNo3]
                   @c_OrderKey    = @cOrderKey
                 , @c_TrackingNo  = @cTrackingNo
                 , @b_Success     = @bSuccess OUTPUT
                 , @n_Err         = @nErr OUTPUT
                 , @c_ErrMsg      = @cErrMsg OUTPUT
                 , @b_Debug       = @bDebug

              IF @bSuccess = 1
              BEGIN
                 DELETE FROM #CartonTrack
                 WHERE  RowRef = @nRowRef

                 DELETE FROM ORDERS_TRACKNO_WIP WITH (ROWLOCK)
                 WHERE RowID = @nRowID

                 WHILE @@TRANCOUNT > 0 
                   COMMIT TRANSACTION TRAN_PER_ORDER;              
              END
              ELSE 
              BEGIN                               	  
              	  IF @@TRANCOUNT > 0 
              	     ROLLBACK TRANSACTION;

                 DELETE FROM ORDERS_TRACKNO_WIP WITH (ROWLOCK)
                 WHERE RowID = @nRowID

                 INSERT INTO ERRLOG
                 ( LogDate, UserId, ErrorID, SystemState, Module, ErrorText )
                 VALUES( GETDATE(), SUSER_SNAME(), '0', '1', 'ispAsgnTNo3', @cErrMsg)               	     
              END
           END TRY 
           BEGIN CATCH 
               PRINT 'ispAsgnTNo3 Failed'
           END CATCH

           SET @nTotalRec = @nTotalRec + 1

           IF @bDebug = 1
           BEGIN
               PRINT 'Duration: ' + CAST(DATEDIFF(second, @dStartTime, GETDATE()) AS VARCHAR(5)) + 
                     ', Records: ' + CAST(@nTotalRec AS VARCHAR(10))   
           END

           GET_NEXT_TRACKING_NO:
           FETCH FROM C_CartonTrack INTO @nRowRef, @cTrackingNo, @cCarrierRef1
       END

       CLOSE C_CartonTrack
       DEALLOCATE C_CartonTrack       
   END -- IF @nTotalOrder > 0

   EXIT_SP:
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

      EXECUTE nsp_LogError @nErr, @cErrmsg, 'isp_BatchAssignTrackingNo'    
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
END -- Procedure  

GO