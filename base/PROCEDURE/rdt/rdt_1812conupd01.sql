SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************************/
/* Store procedure: rdt_1812ConUpd01                                                     */
/* Copyright      : Maersk                                                               */
/* Customer       : Unilever                                                             */
/*                                                                                       */
/* Purpose: Trigger replenishment                                                        */
/*                                                                                       */
/* Date        Rev      Author    Purposes                                               */
/* 2024-11-27  1.0.0    Dennis    FCR-1483 Created                                       */
/*****************************************************************************************/

CREATE   PROC [rdt].[rdt_1812ConUpd01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @cTaskdetailKey NVARCHAR( 10),
   @cNewTaskDetailKey  NVARCHAR( 10),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR(20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @cSQL           NVARCHAR(MAX)
   DECLARE @cSQLParam      NVARCHAR(MAX)

   DECLARE @cClosePalletSP NVARCHAR(20)
   DECLARE @cReplenFlag    NVARCHAR(20)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @b_Success      INT
   DECLARE @bDebug         INT = 0
   DECLARE @cLocEmptyOption  NVARCHAR(20)

   IF @bDebug>0
      SELECT 'rdt_1812ConUpd01','Enter'

   -- Get storer
   SELECT
      @cStorerKey = StorerKey,
      @cLocEmptyOption = C_String14
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Get storer config
   SET @cReplenFlag = rdt.rdtGetConfig( @nFunc, 'ReplenFlag', @cStorerKey)
   IF @cReplenFlag = '0'
      SET @cReplenFlag = ''
   
   SET @nTranCount = @@TRANCOUNT
   
   --FOR FCR-989 the trigger replenishment is changed to submitted to QCommander
   IF @cReplenFlag = '1'
   BEGIN
      DECLARE @cSQlCommand      NVARCHAR(MAX)
      DECLARE @cAPP_DB_Name     NVARCHAR(20)  
      , @cDataStream            VARCHAR(10)  
      , @nThreadPerAcct         INT  
      , @nThreadPerStream       INT  
      , @nMilisecondDelay       INT  
      , @cIP                    NVARCHAR(20)  
      , @cPORT                  NVARCHAR(5)  
      , @cIniFilePath           NVARCHAR(200)  
      , @cCmdType               NVARCHAR(10)  
      , @cTaskType              NVARCHAR(1)   
      , @bSuccess               INT        

      SELECT
            @cSKU       = Sku,
            @cFromLOC   = FromLoc
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey

      SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC

      IF @bDebug>0
         SELECT 'rdt_1812ConUpd01',@cSKU,@cFromLOC,@cLocEmptyOption,@cStorerKey

      --Operator say the location is empty /or/ qty hits min threshold
      IF ISNULL(RTRIM(@cLocEmptyOption), '') = '1' OR EXISTS(
         SELECT 1 FROM dbo.SKUXLOC SL(NOLOCK)
                          JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON SL.StorerKey = LLI.StorerKey AND SL.SKU = LLI.SKU AND SL.LOC = LLI.LOC
         WHERE SL.StorerKey = @cStorerKey
           AND SL.SKU = @cSKU
           AND SL.LOC = @cFromLOC
           AND SL.LocationType IN ( 'CASE','PALLET','PICK')
         GROUP BY
            SL.StorerKey,
            SL.SKU,
            SL.LOC,
            SL.QtyLocationMinimum
         HAVING (SUM(LLI.Qty) - SUM(LLI.QtyPicked) + SUM(LLI.PendingMoveIn)) <= SL.QtyLocationMinimum
      )
      BEGIN

         SET @cSQlCommand = N'
            DECLARE  @bSuccess INT,
                     @nErrNo   INT,
                     @cErrMsg  NVARCHAR(255) 
            EXEC [dbo].[isp_ODMRPL01]
               @c_Facility = ''' + @cFacility + ''',
               @c_Storerkey = ''' + @cStorerKey + ''',
               @c_SKU = ''' + @cSKU + ''',
               @c_LOC = ''' + @cFromLOC + ''',
               @c_ReplenType = N''T'',
               @b_Success = @bSuccess OUTPUT,
               @n_Err = @nErrNo OUTPUT,
               @c_ErrMsg = @cErrMsg OUTPUT,
               @b_Debug = 0'
         
         SELECT TOP 1 @cAPP_DB_Name       = APP_DB_Name,
                     @cDataStream        = DataStream,
                     @nThreadPerAcct     = ThreadPerAcct,
                     @nThreadPerStream   = ThreadPerStream,
                     @nMilisecondDelay   = MilisecondDelay,
                     @cIP                = [IP],
                     @cPORT              = [PORT],
                     @cIniFilePath       = IniFilePath,
                     @cCmdType           = CmdType,
                     @cTaskType          = TaskType
         FROM dbo.QCmd_TransmitlogConfig WITH (NOLOCK)
         WHERE TableName  = 'Replenishment'
            AND [App_Name] = 'WMS'
            AND  (StorerKey = @cStorerKey OR StorerKey = 'ALL')
         ORDER BY
            CASE WHEN StorerKey = @cStorerKey THEN 0 ELSE 1 END ASC 

         IF @@ROWCOUNT<=0
         BEGIN
            SET @nErrNo = 228001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NO replenishment config
            GOTO Quit
         END
         declare @nErrNo2         INT          
         declare @cErrMsg2        NVARCHAR(20)
         BEGIN TRY
            IF @bDebug>0
               SELECT 'rdt_1812ConUpd01',@cFacility,@cIP,@cPORT,@cStorerKey,'Prepare:'+@cSQlCommand
            EXEC isp_QCmd_SubmitTaskToQCommander
                  @cTaskType           = 'O' -- D=By Datastream, T=Transmitlog, O=Others
                  , @cStorerKey        = @cStorerKey
                  , @cDataStream       = ''
                  , @cCmdType          = 'SQL'
                  , @cCommand          = @cSQlCommand
                  , @cTransmitlogKey   = ''
                  , @nThreadPerAcct    = @nThreadPerAcct
                  , @nThreadPerStream  = @nThreadPerStream
                  , @nMilisecondDelay  = @nMilisecondDelay
                  , @nSeq              = 1
                  , @cIP               = @cIP
                  , @cPORT             = @cPORT
                  , @cIniFilePath      = @cIniFilePath
                  , @cAPPDBName        = @cAPP_DB_Name
                  , @bSuccess          = @bSuccess OUTPUT
                  , @nErr              = @nErrNo2  OUTPUT
                  , @cErrMsg           = @cErrMsg2 OUTPUT   
            UPDATE RDT.RDTMOBREC SET C_String14 = '' WHERE Mobile = @nMobile
         END TRY
         BEGIN CATCH
            SET @cErrMsg2 = ERROR_MESSAGE()
            PRINT @cErrMsg2   
            IF @bDebug>0
               SELECT 'rdt_1812ConUpd01',@cFacility,@cIP,@cPORT,@cStorerKey,'ERROR:' + @cErrMsg2
            GOTO Quit               
         END CATCH   
         IF @bDebug>0
            SELECT 'rdt_1812ConUpd01',@cFacility,@cIP,@cPORT,@cStorerKey,'DONE:'+@cErrMsg2
      END
   END

Quit:
   IF @bDebug>0
      SELECT 'rdt_1812ConUpd01','Exit'
END

GO