SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764CreateTask06                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-01-29  1.0  James     WMS-15656. Created                        */
/* 2022-02-21  1.1  yeekung   WMS-18718 add wave.userdefine01 (yeekung01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_1764CreateTask06] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @cUserName      NVARCHAR( 15), 
   @cListKey       NVARCHAR( 10),
   @nErrNo         INT          OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
   DECLARE @nSuccess          INT
   DECLARE @cTaskDetailKey    NVARCHAR( 10)
   DECLARE @cNewTaskDetailKey NVARCHAR( 10)
   DECLARE @cStatus           NVARCHAR( 10)
   DECLARE @cToLOC            NVARCHAR( 10)
   DECLARE @cToLOCPAZone      NVARCHAR( 10)
   DECLARE @cToLOCAreaKey     NVARCHAR( 10)
   DECLARE @cSourceType       NVARCHAR( 30)
   DECLARE @cOrgTaskKey       NVARCHAR( 30)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cStorerkey        NVARCHAR( 15)
   DECLARE @cFromLoc          NVARCHAR( 10)
   DECLARE @cFromID           NVARCHAR( 18)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @nPABookingKey     INT = 0
	DECLARE @cOutField01       NVARCHAR( 20)
	DECLARE @cOutField02       NVARCHAR( 20)
   DECLARE @cOutField03       NVARCHAR( 20)
   DECLARE @cOutField04       NVARCHAR( 20)
   DECLARE @cOutField05       NVARCHAR( 20)
   DECLARE @cOutField06       NVARCHAR( 20)
   DECLARE @cOutField07       NVARCHAR( 20)
   DECLARE @cOutField08       NVARCHAR( 20)
   DECLARE @cOutField09       NVARCHAR( 20)
   DECLARE @cOutField10       NVARCHAR( 20)
	DECLARE @cOutField11       NVARCHAR( 20)
	DECLARE @cOutField12       NVARCHAR( 20)
   DECLARE @cOutField13       NVARCHAR( 20)
   DECLARE @cOutField14       NVARCHAR( 20)
   DECLARE @cOutField15       NVARCHAR( 20)
   DECLARE @cOrdType          NVARCHAR( 10)
   DECLARE @cPutawayZone      NVARCHAR( 10)
   DECLARE @cLOT              NVARCHAR( 10)
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @nQTY              INT
   DECLARE @nIsFromYogaMat    INT = 0
   DECLARE @nLoseID           INT
   DECLARE @cWavekey          NVARCHAR(20)

   -- Init var
   SET @nErrNo = 0
   SET @cErrMsg = ''
   SET @nTranCount = @@TRANCOUNT
   SET @cSourceType = 'rdt_1764CreateTask06'

   SELECT @cFacility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   -- Get ToLOC from latest transit task
   SELECT TOP 1 
      @cStatus = Status 
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
   ORDER BY 
      TransitCount DESC, -- Get initial task
      CASE WHEN Status = '9' THEN 1 ELSE 2 END -- RefTask that fetch to perform together, still Status=3

   -- Task not completed/SKIP/CANCEL
   IF @cStatus <> '9'
      RETURN

   -- Get suggested putaway loc
   SELECT TOP 1 
      @cFromLoc = FromLoc, 
      @cFromID = FromID, 
      @cSKU = Sku, 
      @cStorerkey = Storerkey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE ListKey = @cListKey
      AND TransitCount = 0 -- Original task
      --AND FinalLOC <> ''
   ORDER BY 1

   -- Get extended putaway
   DECLARE @cExtendedPutawaySP NVARCHAR(20)
   SET @cExtendedPutawaySP = rdt.rdtGetConfig( @nFunc, 'ExtendedPutawaySP', @cStorerKey)
   IF @cExtendedPutawaySP = '0'
      SET @cExtendedPutawaySP = ''  
   

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1764CreateTask06 -- For rollback or commit only our own transaction
   
   -- Loop original task
   DECLARE @curRPTLog CURSOR
   SET @curRPTLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT TaskDetailKey, FromLoc
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE ListKey = @cListKey
         AND TransitCount = 0 -- Original task
         --AND FinalLOC <> ''
   OPEN @curRPTLog
   FETCH NEXT FROM @curRPTLog INTO @cOrgTaskKey, @cFromLoc
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT TOP 1 @cOrdType = O.[Type],@cWavekey=pd.WaveKey
      FROM dbo.PICKDETAIL PD WITH (NOLOCK)
      JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
      WHERE PD.TaskDetailKey = @cOrgTaskKey
      ORDER BY 1
      
      SELECT @cPutawayZone = PutawayZone
      FROM dbo.LOC WITH (NOLOCK)
      WHERE Facility = @cFacility
      AND   Loc = @cFromLoc

      
      IF EXISTS (SELECT 1 
            FROM wave (nolock)
            where wavekey=@cwavekey
            and userdefine01<>'') and  @cPutawayZone <> 'LULUCP'
      BEGIN
         BREAK
      END
      
      IF @cOrdType = 'LULUECOM' OR @cPutawayZone = 'LULUCP'
      BEGIN
         SET @nErrNo = 0
         EXEC [RDT].[rdt_513SuggestLOC13] 
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @cStorerkey    = @cStorerkey,
            @cFacility     = @cFacility,
            @cFromLoc      = @cFromLoc,
            @cFromID       = @cFromID,
            @cSKU          = @cSKU,
            @nQTY          = 0,
            @cToID         = '',
            @cToLOC        = '',
            @cType         = 'LOCK',
            @nPABookingKey = @nPABookingKey  OUTPUT,
	         @cOutField01   = @cOutField01    OUTPUT,
	         @cOutField02   = @cOutField02    OUTPUT,
            @cOutField03   = @cOutField03    OUTPUT,
            @cOutField04   = @cOutField04    OUTPUT,
            @cOutField05   = @cOutField05    OUTPUT,
            @cOutField06   = @cOutField06    OUTPUT,
            @cOutField07   = @cOutField07    OUTPUT,
            @cOutField08   = @cOutField08    OUTPUT,
            @cOutField09   = @cOutField09    OUTPUT,
            @cOutField10   = @cOutField10    OUTPUT,
	         @cOutField11   = @cOutField11    OUTPUT,
	         @cOutField12   = @cOutField12    OUTPUT,
            @cOutField13   = @cOutField13    OUTPUT,
            @cOutField14   = @cOutField14    OUTPUT,
            @cOutField15   = @cOutField15    OUTPUT,
            @nErrNo        = @nErrNo         OUTPUT,
            @cErrMsg       = @cErrMsg        OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 162951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get PALOC Err
            GOTO Fail
         END

         IF ISNULL( @cOutField01, '') = ''
         BEGIN
            SET @nErrNo = 162952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get PALOC Err
            GOTO Fail
         END
         ELSE
            SET @cToLOC = @cOutField01

         SELECT @cCaseID = CaseID, @nQTY = Qty
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cOrgTaskKey
         
         SELECT TOP 1 @cLOT = Lot
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cCaseID
         ORDER BY 1
         
         -- Lock SuggestedLOC  
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'  
            ,@cFromLoc  
            ,@cFromID   
            ,@cToLOC  
            ,@cStorerKey  
            ,@nErrNo  OUTPUT  
            ,@cErrMsg OUTPUT  
            ,@cSKU        = @cSKU  
            ,@nPutawayQTY = @nQTY     
            ,@cUCCNo      = @cCaseID  
            ,@cFromLOT    = @cLOT  
            ,@nPABookingKey = @nPABookingKey OUTPUT
               
         SET @nSuccess = 1
         EXECUTE dbo.nspg_getkey
            'TASKDETAILKEY'
            , 10
            , @cNewTaskDetailKey OUTPUT
            , @nSuccess          OUTPUT
            , @nErrNo            OUTPUT
            , @cErrMsg           OUTPUT
         IF @nSuccess <> 1
         BEGIN
            SET @nErrNo = 162953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
            GOTO Fail
         END

         -- Get LOC info
         SET @cToLOCPAZone = ''
         SET @cToLOCAreaKey = ''
         SELECT @cToLOCPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
         SELECT @cToLOCAreaKey = AreaKey FROM AreaDetail WITH (NOLOCK) WHERE PutawayZone = @cToLOCPAZone 

         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
                     WHERE TD.TaskDetailKey = @cOrgTaskKey
                     AND   TD.TaskType = 'RPF'
                     AND   TD.[Status] = '9'
                     AND   LOC.PutawayZone = 'LULUCP'
                     AND   LOC.Facility = @cFacility)
            SET @nIsFromYogaMat = 1

         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON TD.ToLoc = LOC.LOC
                     WHERE TaskDetailKey = @cOrgTaskKey
                     AND   LOC.LoseId = '1')
            SET @nLoseID = 1
         ELSE
            SET @nLoseID = 0
                     
         -- Insert final task
         INSERT INTO TaskDetail (
            TaskDetailKey, TaskType, Status, UserKey, PickMethod, TransitCount, AreaKey, SourceType, FromLOC, FromID, 
            ToLOC, ToID, StorerKey, SKU, LOT, UOMQty, QTY, ListKey, SourceKey, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop, 
            Caseid)
         SELECT
            @cNewTaskDetailKey, 'ASTRPT', '0', '', 'PP', 1, @cToLOCAreaKey, @cSourceType, ToLOC, CASE WHEN @nLoseID = 1 THEN '' ELSE ToID END, 
            @cToLOC AS ToLOC, '' AS ToID, StorerKey, SKU, LOT, UOMQty, QTY, ListKey, TaskDetailKey, WaveKey, LoadKey, Priority, SourcePriority, NULL, 
            CASE WHEN @nIsFromYogaMat = 1 THEN ToID ELSE CaseID END AS CaseID
         FROM TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cOrgTaskKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 162954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
            GOTO RollBackTran
         END
         
         SELECT @cCaseID = CaseID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cNewTaskDetailKey
         
         UPDATE dbo.PickDetail SET
            DropID = @cCaseID,
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE TaskDetailKey = @cOrgTaskKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 162955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPKDropIDErr
            GOTO RollBackTran
         END
         
      END
      
      FETCH NEXT FROM @curRPTLog INTO @cOrgTaskKey, @cFromLoc
   END

   COMMIT TRAN rdt_1764CreateTask06 -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764CreateTask06 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO