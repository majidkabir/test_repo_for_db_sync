SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Stored Proc : isp_VNAInConfirm  		                                                */
/* Creation Date:                                                                      */
/* Copyright: Maersk WMS                                                               */
/* Written by:  NLT013                                                                 */
/*                                                                                     */
/* Purpose: Adjust inventory once WCS put the pallet to the destination location       */
/*                                                                                     */
/*                                                                                     */
/* Usage:                                                                              */
/*                                                                                     */
/* Local Variables:                                                                    */
/*                                                                                     */
/* Called By: isp_VNAActionConfirm_Wrapper                                             */
/*                                                                                     */
/* PVCS Version:                                                                       */
/*                                                                                     */
/* Version: Maersk WMS V2                                                              */
/*                                                                                     */
/* Data Modifications:                                                                 */
/*                                                                                     */
/* Updates:                                                                            */
/* Date         Author        Purposes                                                 */
/* 2002-03-08   NLT013        Getting from Taiwan Live                                 */
/***************************************************************************************/

CREATE PROC dbo.isp_VNAInConfirm(
   @cTaskDetailKey                  NVARCHAR(10),
   @nErrNo                          INT               OUTPUT,
   @cErrMsg                         NVARCHAR( 255)    OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   DECLARE
      @nMobile                      INT,
      @cLangCode                    NVARCHAR(3),
      @nFunc                        INT,

      @cSQL                         NVARCHAR(1000),
      @cSQLParam                    NVARCHAR(1000),
      @nTranCount                   INT,

      @cTaskType                    NVARCHAR( 10),
      @cTaskCode                    NVARCHAR( 10),
      @cFacility                    NVARCHAR( 5),
      @cStorerKey                   NVARCHAR( 15),

      @cUserKey                     NVARCHAR( 18),
      @cFromLoc                     NVARCHAR( 10),
      @cToLoc                       NVARCHAR( 10),
      @cLogicalToLoc                NVARCHAR( 10),
      @cID                          NVARCHAR( 18),
      @nQTY                         INT,
      @cSku                         NVARCHAR( 20),
      @cStatus                      NVARCHAR( 10),

      @cVNAIN                       NVARCHAR( 5) = 'VNAIN'

      SET @nFunc        = 1203

   SELECT 
      @cTaskType        = td.TaskType,
      @cTaskCode        = ISNULL(td.Message03, ''),
      @cFacility        = loc.Facility,
      @cStorerKey       = td.StorerKey,
      @cFromLoc         = td.FromLoc,
      @cToLoc           = ToLoc,
      @cID              = ToID,
      @nQTY             = Qty,
      @cSku             = Sku,
      @cUserKey         = UserKey,
      @cStatus          = td.Status
   FROM dbo.TaskDetail td WITH(NOLOCK)
   INNER JOIN dbo.Loc loc WITH(NOLOCK)
      ON td.FromLoc = loc.Loc
   INNER JOIN dbo.Loc loc1 WITH(NOLOCK)
      ON td.ToLoc = loc1.Loc
      AND loc.Facility = loc1.Facility
   WHERE td.TaskDetailKey = @cTaskDetailKey

   IF @cStatus <> '3'
   BEGIN
      SET @nErrNo = 212510
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Task Status
      GOTO Quit
   END

   SET @nMobile   = -1
   SET @cLangCode = 'ENG'

   IF @cTaskType <> @cVNAIN
   BEGIN
      SET @nErrNo = 212502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Not VNA IN Task
      RETURN
   END

   IF @cFromLoc = ''
   BEGIN
      SET @nErrNo = 212503
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No From Loc
      RETURN
   END

   IF @cToLoc = ''
   BEGIN
      SET @nErrNo = 212504
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No To Loc
      RETURN
   END

   IF @cID = ''
   BEGIN
      SET @nErrNo = 212505
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No ID
      RETURN
   END

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_VNAInConfirm -- For rollback or commit only our own transaction

   -- Execute move process
   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,
      @cLangCode   = @cLangCode, 
      @nErrNo      = @nErrNo  OUTPUT,
      @cErrMsg     = @cErrMsg OUTPUT, 
      @cSourceType = 'isp_VNAInConfirm', 
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility, 
      @cFromLOC    = @cFromLoc, 
      @cToLOC      = @cToLoc, 
      @cFromID     = @cID, 
      @cToID       = NULL,  -- NULL means not changing ID
      @nFunc       = 0

   IF @nErrNo <> 0
   BEGIN
      SET @nErrNo = 212539
      SET @cErrMsg = CONCAT_WS(',', rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP'),  @nErrNo, @cErrMsg )--Move Inentory Fail, details:
      GOTO RollBackTran
   END

   UPDATE dbo.TaskDetail WITH(ROWLOCK) 
   SET 
      Status = 9,
      EndTime = GETDATE(),
      EditDate = GETDATE(),
      EditWho  = SYSTEM_USER,
      Trafficcop = NULL,
      StatusMsg = ''
   WHERE TaskDetailKey = @cTaskDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 212509
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdTaskdetFail
      GOTO RollBackTran
   END

   -- Unlock SuggestedLOC
   EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK' 
      ,''        --@cLOC      
      ,@cID      --@cID       
      ,@cToLOC   --@cSuggLOC 
      ,''        --@cStorerKey
      ,@nErrNo  OUTPUT
      ,@cErrMsg OUTPUT
   
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 212516
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Unlock VNA Loc Fail
      GOTO RollBackTran
   END

   COMMIT TRAN isp_VNAInConfirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   IF @@TRANCOUNT > 0
      ROLLBACK TRAN isp_VNAInConfirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END



GO