SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PostPackSort_ClosePallet                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Close pallet and create tm task to move pallet              */
/*                                                                      */
/* Called from: rdtfnc_PostPackSort                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-09-26   1.0  James    WMS-10316. Created                        */
/* 2020-01-21   1.1  James    WMS-11753 Handle blank LocationCategory   */
/*                            by RDT config (james01)                   */
/* 2020-04-13   1.2  James    WMS-12735 Add MaxPallet checking (james02)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_PostPackSort_ClosePallet] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5), 
   @cCartonID        NVARCHAR( 20), 
   @cPalletID        NVARCHAR( 20), 
   @cLoadKey         NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cOption          NVARCHAR( 1), 
   @cPickDetailCartonID NVARCHAR( 20),    
   @tClosePallet        VariableTable READONLY, 
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @bSuccess          INT,
           @nRowCount         INT,
           @cLocationCategory NVARCHAR( 10),
           @cTaskdetailkey    NVARCHAR( 10),
           @cToLoc            NVARCHAR( 10),
           @cToLogicalLocation   NVARCHAR( 10),
           @cLogicalLocation     NVARCHAR( 10),
           @nPABookingKey     INT,
           @cUserName         NVARCHAR( 18),
           @cDefaultLocCategory   NVARCHAR( 10)  -- (james01)

   SET @nErrNo = 0

   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC AS r WITH (NOLOCK)
   WHERE r.Mobile = @nMobile
   
   SELECT @cLoadKey = LoadKey, @cLoc = LOC
   FROM rdt.rdtSortLaneLocLog WITH (NOLOCK)
   WHERE ID = @cPalletID
   AND   [Status] = '1'

   SELECT DISTINCT @cLocationCategory = LocationCategory
   FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
   WHERE LoadKey = @cLoadKey
   SET @nRowCount = @@ROWCOUNT

   IF @nRowCount = 0 OR ISNULL( @cLocationCategory, '') = ''
   BEGIN
      SET @cDefaultLocCategory = rdt.rdtGetConfig( @nFunc, 'DefaultLocCategory', @cStorerKey)
      -- If config not turn on, prompt error
      IF @cDefaultLocCategory = ''
      BEGIN
         SET @nErrNo = 144401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Lane
         GOTO Fail
      END

      -- If config turn on, default to svalue
      SET @cLocationCategory = @cDefaultLocCategory
   END

   -- If LoadPlanLaneDetail has 2 different value for locationcategory then use staging method
   IF @nRowCount > 1
      SET @cLocationCategory = 'STAGING'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_PostPackSort_ClosePallet

   IF @cLocationCategory = 'STAGING'
   BEGIN
      SELECT @cToLoc = LOC
      FROM dbo.LoadPlanLaneDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey

      SELECT @cToLogicalLocation = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLoc

      SELECT @cLogicalLocation = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLoc

      SELECT @bSuccess = 1  
      EXECUTE dbo.nspg_getkey  
         @KeyName       = 'TaskDetailKey',
         @fieldlength   = 10,
         @keystring     = @cTaskdetailkey   OUTPUT,
         @b_Success     = @bSuccess         OUTPUT,
         @n_err         = @nErrNo           OUTPUT,
         @c_errmsg      = @cErrMsg          OUTPUT  

      IF NOT @bSuccess = 1 OR ISNULL( @cTaskdetailkey, '') = ''
      BEGIN
         SET @nErrNo = 144402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
         GOTO RollBackTran
      END

      INSERT dbo.TASKDETAIL 
      ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot,
        FromLoc, FromID, ToLoc, ToID, SourceType,SourceKey, Priority, SourcePriority,
        Status, LogicalFromLoc, LogicalToLoc, PickMethod)  
      VALUES  
      ( @cTaskdetailkey, 'ASTMV', @cStorerkey, '', '', 0, 0, 0, '', 
        @cLoc, @cPalletID, @cToLoc, @cPalletID, 'rdt_PostPackSort_ClosePallet', '', '5', '9',
        '0', @cLogicalLocation, @cToLogicalLocation, 'FP')
            
      IF @@ERROR <> 0  
      BEGIN
         SET @nErrNo = 144403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreateMVTaskFail
         GOTO RollBackTran
      END       
   END
   ELSE IF @cLocationCategory = 'PACK&HOLD'
   BEGIN
      -- (james02)
      -- Find friend ( same loadkey)
      SELECT TOP 1 @cToLoc = TD.ToLoc
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.ToLoc = LOC.Loc)
      WHERE TD.LoadKey = @cLoadKey
      AND   TD.[Status] < '9'
      AND   TD.TaskType = 'ASTPA'
      AND   TD.Storerkey = @cStorerKey
      AND   TD.PickMethod = 'FP'
      AND   LOC.LocationCategory = 'PACK&HOLD'
      AND   LOC.Facility = @cFacility
      AND   LOC.STATUS = 'OK'
      GROUP BY LOC.PALogicalLoc, TD.ToLoc, LOC.MaxPallet
      HAVING LOC.MaxPallet >= ( COUNT( DISTINCT TD.ToID) + 1)
      ORDER BY LOC.PALogicalLoc, TD.ToLoc
      
      IF ISNULL( @cToLoc, '') = ''
         -- Search Empty Location 
         SELECT TOP 1 @cToLoc = LOC.LOC
         FROM LOC LOC WITH (NOLOCK)
         LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK) ON ( LOC.loc = LLI.LOC ) 
         WHERE LOC.Facility = @cFacility
         AND   LOC.LocationCategory = 'PACK&HOLD'
         AND   LOC.LOC <> @cLoc
         AND   LOC.STATUS = 'OK'
         GROUP BY LOC.PALogicalLoc, LOC.LOC
         HAVING ISNULL(SUM(LLI.QTY+LLI.PendingMoveIn),0)  = 0 
         ORDER BY LOC.PALogicalLoc, LOC.Loc

      IF ISNULL( @cToLoc, '') = ''
      BEGIN
         SET @nErrNo = 144404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pack&Hold
         GOTO RollBackTran
      END  

      SELECT @cToLogicalLocation = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cToLoc

      SELECT @cLogicalLocation = LogicalLocation
      FROM dbo.LOC WITH (NOLOCK)
      WHERE LOC = @cLoc

      -- Booking
      SET @nPABookingKey = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn 
         @cUserName     = @cUserName
        ,@cType         = 'LOCK'
        ,@cFromLOC      = @cLOC
        ,@cFromID       = @cPalletID
        ,@cSuggestedLOC = @cToLOC
        ,@cStorerKey    = @cStorerKey
        ,@nErrNo        = @nErrNo  OUTPUT
        ,@cErrMsg       = @cErrMsg OUTPUT
        ,@cSKU          = ''
        ,@nPutawayQTY   = 0
        ,@cUCCNo        = ''
        ,@cFromLOT      = ''
        ,@cToID         = @cPalletID
        ,@cTaskDetailKey = ''
        ,@nFunc         = @nFunc
        ,@nPABookingKey = @nPABookingKey OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   
      SELECT @bSuccess = 1  
      EXECUTE dbo.nspg_getkey  
         @KeyName       = 'TaskDetailKey',
         @fieldlength   = 10,
         @keystring     = @cTaskdetailkey   OUTPUT,
         @b_Success     = @bSuccess         OUTPUT,
         @n_err         = @nErrNo           OUTPUT,
         @c_errmsg      = @cErrMsg          OUTPUT  

      IF NOT @bSuccess = 1 OR ISNULL( @cTaskdetailkey, '') = ''
      BEGIN
         SET @nErrNo = 144405
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
         GOTO RollBackTran
      END

      INSERT dbo.TASKDETAIL 
      ( TaskDetailKey, TaskType, Storerkey, Sku, UOM, UOMQty, Qty, SystemQty, Lot,
        FromLoc, FromID, ToLoc, ToID, SourceType,SourceKey, Priority, SourcePriority,
        Status, LogicalFromLoc, LogicalToLoc, PickMethod, LoadKey)  
      VALUES  
      ( @cTaskdetailkey, 'ASTPA', @cStorerkey, '', '', 0, 0, 0, '', 
        @cLoc, @cPalletID, @cToLoc, @cPalletID, 'rdt_PostPackSort_ClosePallet', '', '5', '9',
        '0', @cLogicalLocation, @cToLogicalLocation, 'FP', @cLoadKey)
            
      IF @@ERROR <> 0  
      BEGIN
         SET @nErrNo = 144406
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CreatePATaskFail
         GOTO RollBackTran
      END       
   END

   UPDATE rdt.rdtSortLaneLocLog WITH (ROWLOCK) SET 
      Status = '9'
   WHERE Loc = @cLoc
   AND   ID = @cPalletID
   AND   [Status] = '1'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 144452
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Assign Loc Err
      GOTO RollBackTran  
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_PostPackSort_ClosePallet

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_PostPackSort_ClosePallet

   Fail:
END

GO