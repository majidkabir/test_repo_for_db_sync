SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SortLaneLoc_ClosePallet                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-01-04 1.0  Ung        SOS265198. Created                        */
/* 2013-12-09 1.1  Ung        SOS297221 Add Build pallet by Load        */
/* 2014-01-29 1.2  Ung        SOS300988 Add EventLog                    */
/* 2014-02-17 1.3  Ung        Fix pack confirm criteria                 */
/* 2014-05-21 1.4  Ung        SOS311570 Support TBL XDock               */
/* 2014-09-05 1.5  Ung        SOS311570 Support NMF XDock               */
/* 2014-09-22 1.6  Ung        SOS321203 XD gen task only status release */
/************************************************************************/

CREATE PROC [RDT].[rdt_SortLaneLoc_ClosePallet] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @cUserName   NVARCHAR( 18), 
   @cStorerKey  NVARCHAR( 15), 
   @cFacility   NVARCHAR( 5), 
   @cLane       NVARCHAR( 10),
   @cLOC        NVARCHAR( 10),
   @cID         NVARCHAR( 18), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nSuccess       INT
   DECLARE @cSOStatus      NVARCHAR(10)
   DECLARE @cTaskDetailKey NVARCHAR(10)
   DECLARE @cLoadKey       NVARCHAR(10)
   DECLARE @cToLOC         NVARCHAR(10)
   DECLARE @cLabelNo       NVARCHAR(20)
   DECLARE @cOrderKey      NVARCHAR(10) 
   DECLARE @cLastCarton    NVARCHAR( 1)
   DECLARE @cType          NVARCHAR( 2)
   DECLARE @cOrderType     NVARCHAR( 2)

   SET @cOrderType = ''
   SET @cSOStatus = ''
   SET @cLoadKey = ''
   SET @cToLOC = ''
   SET @cType = ''

   -- Get Lane LOC info
   SELECT 
      @cOrderKey = OrderKey, 
      @cLoadKey = LoadKey
   FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) 
   WHERE Lane = @cLane
      AND LOC = @cLOC
      AND ID = @cID
   
   -- Build pallet by Order
   IF @cOrderKey <> ''
   BEGIN
      -- Get Order info
      SELECT 
         @cOrderType = CASE WHEN RIGHT( Type, 2) = '-X' THEN 'XD' ELSE '' END, 
         @cSOStatus = SOStatus 
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey
         
      -- Check LoadPlan created
      IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
      BEGIN
         SET @nErrNo = 78851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- NotYetLoadPlan
         GOTO Quit
      END
   END
   
   -- Build pallet by Load
   IF @cLoadKey <> ''
   BEGIN
      -- Get dispatch lane
      SELECT TOP 1 
         @cToLOC = LOC
      FROM dbo.LoadPlanLaneDetail WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey 
         AND LocationCategory = 'STAGING'
         AND Status = '0' -- 0=Assigned, 9=Released
      ORDER BY LOC

      -- Check dispatch lane not assign
      IF @cToLOC = ''
      BEGIN
         SET @nErrNo = 78852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DPLaneNotAssgn
         GOTO Quit
      END
   END
   
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdtfnc_SortLaneLoc_ClosePallet

   -- Loop PickSlip
   DECLARE @nPackQTY INT
   DECLARE @nPickQTY INT
   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @curPickSlip CURSOR
   SET @curPickSlip = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PD.PickSlipNo 
      FROM DropID WITH (NOLOCK)
         JOIN DropIDDetail DID WITH (NOLOCK) ON (DropID.DropID = DID.DropID)
         JOIN PackDetail PD WITH (NOLOCK) ON (DID.ChildID = PD.LabelNo)
      WHERE DropID.DropID = @cID
   OPEN @curPickSlip
   FETCH NEXT FROM @curPickSlip INTO @cPickSlipNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status < '9')
      BEGIN
         SET @nPackQTY = 0
         SET @nPickQTY = 0
         SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
         SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '4'
         
         -- Determine order type
         SET @cType = ''
         SELECT @cType = 'XD'
         FROM Orders O WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.StorerKey = @cStorerKey
            AND PD.PickSlipNo = @cPickSlipNo
            AND RIGHT( O.Type, 2) = '-X'


         /*
         Last carton logic:
         1. If not fully pack (PickDetail.Status = 0 or 4), definitely not last carton
         2. If all carton pack and scanned (all PackDetail and DropID records tally), it is last carton
         */
         SET @cLastCarton = 'Y'

         -- 1. Check outstanding PickDetail
         IF @cType = 'XD'
         BEGIN
            IF @nPackQTY <> @nPickQTY
               SET @cLastCarton = 'N' 
         END
         ELSE
         BEGIN 
            IF EXISTS( SELECT TOP 1 1 FROM dbo.PickDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND (Status IN ('0', '4') AND QTY > 0))
               SET @cLastCarton = 'N' 
         END
         
         -- 2. Check all carton pack and scanned
         IF @cLastCarton = 'Y'
         BEGIN
            IF EXISTS( SELECT TOP 1 1 
               FROM dbo.PackDetail PD WITH (NOLOCK) 
                  LEFT JOIN dbo.DropIDDetail DID WITH (NOLOCK) ON (PD.DropID = DID.ChildID)
               WHERE PD.PickSlipNo = @cPickSlipNo 
                  AND DID.ChildID IS NULL)
               SET @cLastCarton = 'N' 
            ELSE
               SET @cLastCarton = 'Y'
         END

         IF @nPackQTY = @nPickQTY AND @cLastCarton = 'Y'
         BEGIN
            -- Pack confirm
            UPDATE PackHeader SET 
               Status = '9' 
            WHERE PickSlipNo = @cPickSlipNo
               AND Status <> '9'
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 78856
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
               GOTO RollBackTran
            END
            
            -- Loop UCC
            DECLARE @cUCCNo NVARCHAR(20)
            DECLARE @curUCC CURSOR
            SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT LabelNo 
               FROM PackDetail PD WITH (NOLOCK) 
                  JOIN dbo.UCC WITH (NOLOCK) ON (PD.LabelNo = UCC.UCCNo AND UCC.StorerKey = @cStorerKey)
               WHERE PickSlipNo = @cPickSlipNo
                  AND UCC.Status < '5' --5=Picked
            OPEN @curUCC
            FETCH NEXT FROM @curUCC INTO @cUCCNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update UCC
               UPDATE dbo.UCC SET
                  Status = '5' -- Picked
               WHERE StorerKey = @cStorerKey
                  AND UCCNo = @cUCCNo
               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 78863
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UCC Fail
                  GOTO RollBackTran
               END
               FETCH NEXT FROM @curUCC INTO @cUCCNo
            END
         END
      END
      FETCH NEXT FROM @curPickSlip INTO @cPickSlipNo
   END

   -- Unlock the LOC
   IF EXISTS( SELECT 1 FROM rdt.rdtSortLaneLocLog WITH (NOLOCK) WHERE Lane = @cLane AND LOC = @cLOC AND Status = '1') --In-use
   BEGIN
      -- Update sort lane loc status
      UPDATE rdt.rdtSortLaneLocLog SET
         OrderKey = '', 
         LoadKey  = '', 
         Status   = '0', -- Not use
         ID       = ''
      WHERE Lane = @cLane
         AND LOC = @cLOC 
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 78854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD Log Fail
         GOTO RollBackTran
      END
   END

   IF @cLoadKey = ''
      SELECT @cLoadKey = LoadKey FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

   -- Update DropID
   UPDATE dbo.DropID SET
      DropIDType = 'C',     -- Required by RDT TM Non-inventory move module 
      LoadKey = @cLoadKey   -- Required by RDT TM Non-inventory move module
   WHERE DropID = @cID
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 78855
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD DropIDFail
      GOTO RollBackTran
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Move
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cLocation     = @cLane, 
      @cRefNo1       = 'CLOSE', 
      @cDropID       = @cID

   -- Check cancel order
   IF @cSOStatus = 'CANC'
   BEGIN
      SET @nErrNo = 78857
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Order cancel
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '78856 ', @cErrMsg
      SET @nErrNo = 0
      SET @cErrMsg = ''
      GOTO Quit
   END

   -- Create next task
   IF (@cOrderType = 'XD' AND @cSOStatus <> 'RELEASED') OR  -- XDock order
      @cSOStatus = 'HOLD'                                   -- Normal order
   BEGIN
   	-- Get new TaskDetailKey
   	SET @nSuccess = 1
   	EXECUTE dbo.nspg_getkey
   		'TASKDETAILKEY'
   		, 10
   		, @cTaskdetailkey OUTPUT
   		, @nSuccess       OUTPUT
   		, @nErrNo         OUTPUT
   		, @cErrMsg        OUTPUT
      IF @nSuccess <> 1
      BEGIN
         SET @nErrNo = 78858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
         GOTO RollBackTran
      END 
      
      -- Create NMF task
      INSERT INTO TaskDetail (
         TaskDetailKey, TaskType, Status, UserKey, FromLOC, FromID, ToLOC, ToID, StorerKey, SourceType, Priority, SourcePriority, TrafficCop)
      VALUES (
         @cTaskDetailKey, 'NMF', '0', '', @cLane, @cID, '', @cID, @cStorerKey, 'rdt_SortLaneLoc_ClosePallet', 5, 5, NULL)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 78859
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail
         GOTO RollBackTran
      END
   END

   COMMIT TRAN rdtfnc_SortLaneLoc_ClosePallet
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdtfnc_SortLaneLoc_ClosePallet
Quit:         
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO