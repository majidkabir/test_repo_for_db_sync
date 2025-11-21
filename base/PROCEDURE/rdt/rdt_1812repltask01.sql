SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************************/
/* Store procedure: rdt_1812ReplTask01                                                   */
/* Copyright      : Maersk                                                               */
/* Customer       : Unilever                                                             */
/*                                                                                       */
/* Purpose: Trigger replenishment                                                        */
/*                                                                                       */
/* Date        Rev      Author    Purposes                                               */
/* 25-Oct-2024 1.0.0    YYS027    FCR-989 Created from v1.4 rdt_TM_CasePick_ClosePallet  */
/*                                for trigger replenishment submit to QCommander         */
/*                                used config ReplenTaskSP in rdt.storerconfig           */
/*****************************************************************************************/

CREATE   PROC [rdt].[rdt_1812ReplTask01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @cUserName      NVARCHAR(18),
   @cListKey       NVARCHAR(10),
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

   IF @bDebug>0
      SELECT 'rdt_1812ReplTask01','Enter'
   --print @cListKey
   --print @cUserName
   -- Get storer
   SELECT TOP 1 
      @cStorerKey = StorerKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND UserKey = @cUserName
      --AND Status = '5' -- 3=Fetch, 5=Picked, 9=Complete, --here, the task is confirm and closed, so don't use the condition status=5
   ORDER BY TaskDetailKey   

   --print '@cStorerKey:'+isnull(@cStorerKey,'')
   -- Get storer config
   SET @cReplenFlag = rdt.rdtGetConfig( @nFunc, 'ReplenFlag', @cStorerKey)
   IF @cReplenFlag = '0'
      SET @cReplenFlag = ''
   --print @cReplenFlag
   SET @nTranCount = @@TRANCOUNT
   
   --FOR FCR-989 the trigger replenishment is changed to submitted to QCommander
   IF @cReplenFlag = '1'
   BEGIN
      DECLARE @cLocEmptyOption  NVARCHAR(20)
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
      -- Get storer
      SELECT TOP 1
            @cStorerKey = StorerKey,
            @cSKU       = Sku,
            @cFromLOC     = FromLoc
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE ListKey = @cListKey
        AND UserKey = @cUserName
      ORDER BY TaskDetailKey

      SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
      SELECT @cLocEmptyOption = C_String14 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE  Mobile = @nMobile

      IF @bDebug>0
         SELECT 'rdt_1812ReplTask01',@cSKU,@cFromLOC,@cLocEmptyOption,@cStorerKey

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
         /*  --- original statement for trigger replenishment
         EXEC isp_ODMRPL01
               @c_Facility = @cFacility,
               @c_Storerkey = @cStorerKey,
               @c_SKU = @cSKU,
               @c_LOC = @cFromLOC,
               @c_ReplenType = N'T',
               @b_Success = @b_Success OUTPUT,
               @n_Err = @nErrNo OUTPUT,
               @c_ErrMsg = @cErrMsg OUTPUT,
               @b_Debug = 0
         */
         -----New code

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
               SELECT 'rdt_1812ReplTask01',@cFacility,@cIP,@cPORT,@cStorerKey,'Prepare:'+@cSQlCommand
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
            END TRY
            BEGIN CATCH
               SET @cErrMsg2 = ERROR_MESSAGE()
               PRINT @cErrMsg2   
               IF @bDebug>0
                  SELECT 'rdt_1812ReplTask01',@cFacility,@cIP,@cPORT,@cStorerKey,'ERROR:' + @cErrMsg2
               GOTO Quit               
            END CATCH   
            IF @bDebug>0
               SELECT 'rdt_1812ReplTask01',@cFacility,@cIP,@cPORT,@cStorerKey,'DONE:'+@cErrMsg2
      END
   END

Quit:
   IF @bDebug>0
      SELECT 'rdt_1812ReplTask01','Exit'
END

GO