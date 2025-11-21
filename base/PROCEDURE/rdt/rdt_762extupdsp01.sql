SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_762ExtUpdSP01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-01-2022  1.0  yeekung     WMS18620. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_762ExtUpdSP01] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR(3),   
   @nStep          INT,           
   @cUserName      NVARCHAR( 18), 
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15), 
   @cDropID        NVARCHAR( 20), 
   @cSKU           NVARCHAR( 20), 
   @nQty           INT,           
   @cToLabelNo     NVARCHAR( 20), 
   @cPTSLogKey     NVARCHAR( 20), 
   @cShort         NVARCHAR(1),   
   @cSuggLabelNo   NVARCHAR(20) OUTPUT, 
   @nErrNo         INT OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cNewTaskDetailKey NVARCHAR(20),
           @cFromloc NVARCHAR(20),
           @cLot   NVARCHAR(20),
           @cUom   NVARCHAR(20),
           @cPutawayZone NVARCHAR(20),
           @bSuccess INT,
           @nTranCount INT

	DECLARE @curPD CURSOR
   DECLARE @cToLOC            NVARCHAR( 10)  
   DECLARE @cToLOCPAZone      NVARCHAR( 10)  
   DECLARE @cToLOCAreaKey     NVARCHAR( 10)  
	DECLARE @cPickConfirmStatus       nvarchar(1)
	DECLARE @cOutField01    NVARCHAR( 20)  
	DECLARE @cOutField02    NVARCHAR( 20)  
   DECLARE @cOutField03    NVARCHAR( 20)  
   DECLARE @cOutField04    NVARCHAR( 20)  
   DECLARE @cOutField05    NVARCHAR( 20)  
   DECLARE @cOutField06    NVARCHAR( 20)  
   DECLARE @cOutField07    NVARCHAR( 20)  
   DECLARE @cOutField08    NVARCHAR( 20)  
   DECLARE @cOutField09    NVARCHAR( 20)  
   DECLARE @cOutField10    NVARCHAR( 20)  
	DECLARE @cOutField11    NVARCHAR( 20)  
	DECLARE @cOutField12    NVARCHAR( 20)  
   DECLARE @cOutField13    NVARCHAR( 20)  
   DECLARE @cOutField14    NVARCHAR( 20)  
   DECLARE @cOutField15    NVARCHAR( 20)  
	DECLARE @nPABookingKey  INT = 0  
	DECLARE @nUOMQty			INT

	DECLARE	@nPTSQty INT,
				@nQTY_Bal INT,
				@cPickDetailKey NVARCHAR(20),
				@nQTY_PD INT

	DECLARE @cNewPickDetailKey NVARCHAR( 10)  

   SET @nTranCount=@@TRANCOUNT

   BEGIN TRAN 
   SAVE TRAN rdt_762ExtUpdSP01

	SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)
   IF @cPickConfirmStatus NOT IN ('3', '5')
      SET @cPickConfirmStatus = '5'


	IF @nStep= 1
	BEGIN
		INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )
      SELECT PD.Loc, '0', @cDropID, '' ,PD.StorerKey, '','', PD.SKU, PD.Loc, PD.Lot, PD.UOM
            ,SUM(PD.Qty), 0, '', @nFunc, GetDate(), @cUserName
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      WHERE PD.StorerKey = @cStorerKey
      AND PD.DropID = @cDropID
      AND PD.Status = @cPickConfirmStatus
      AND PD.CaseID = ''
		group by  PD.Loc,PD.StorerKey, PD.SKU, PD.Loc, PD.Lot, PD.UOM

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 181051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPTSLogFail
         GOTO rollbacktran
      END
	END
	IF @nstep=3
	BEGIN
		
		select @nPTSQty=ExpectedQty
		from rdt.rdtPTSLog (NOLOCK)
		WHERE PTSLogKey = @cPTSLogKey

		DECLARE	@cOldlottable03 NVARCHAR(30),
					@cNewlottable03 NVARCHAR(30),
               @cWavekey       NVARCHAR(20)


      SELECT @cWavekey=pd.WaveKey
		FROM dbo.PickDetail PD WITH (NOLOCK)
		WHERE PD.StorerKey = @cStorerKey
		AND PD.DropID = @cDropID
		and pd.sku=@cSKU

		IF EXISTS( SELECT 1
						FROM dbo.PickDetail PD WITH (NOLOCK)
						WHERE PD.StorerKey = @cStorerKey
						AND PD.DropID = @cToLabelNo
						AND PD.Status = @cPickConfirmStatus)
		BEGIN
         DECLARE @cOLDSKU NVARCHAR(20)

			SELECT @cOldlottable03=lot.Lottable03,@cOLDSKU=PD.sku
			FROM dbo.PickDetail PD WITH (NOLOCK)
			JOIN lotattribute lot (nolock) on pd.sku=lot.sku and pd.lot=lot.lot
			WHERE PD.StorerKey = @cStorerKey
			AND PD.DropID = @cToLabelNo
			AND PD.Status = @cPickConfirmStatus

			SELECT @cNewlottable03=lot.Lottable03
			FROM dbo.PickDetail PD WITH (NOLOCK)
			JOIN lotattribute lot (nolock) on pd.sku=lot.sku and pd.lot=lot.lot
			WHERE PD.StorerKey = @cStorerKey
			AND PD.DropID = @cDropID
			and pd.sku=@cSKU
			AND PD.Status = @cPickConfirmStatus

			IF @cNewlottable03<>@cOldlottable03 AND @cOLDSKU=@cSKU
			BEGIN
				SET @nErrNo = 181074
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DiffCOO'
				GOTO ROLLBACKTRAN
			END
		END

		IF @nPTSQty=@nQty
		BEGIN
			-- Update rdt.rdtPTSLog
			UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
			SET  Status = '9' -- In Progress
				, LabelNo = @cToLabelNo
				, EditDate = GetDate()
			WHERE PTSLogKey = @cPTSLogKey

			IF @@ERROR <>0
			BEGIN
				SET @nErrNo = 181052
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdPTSLogFail'
				GOTO ROLLBACKTRAN
			END
		END
		ELSE IF @nPTSQty>@nQty
		BEGIN
			INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )
			SELECT PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty-@nQty, Qty, Remarks, Func, AddDate, AddWho 
			from rdt.rdtPTSLog (NOLOCK)
			WHERE PTSLogKey = @cPTSLogKey

			IF @@ERROR <>0
			BEGIN
				SET @nErrNo = 181053
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InsPTSLogFail'
				GOTO ROLLBACKTRAN
			END

			-- Update rdt.rdtPTSLog
			UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
			SET  Status = '9' -- In Progress
				, LabelNo = @cToLabelNo
				,qty=@nqty
				, EditDate = GetDate()
			WHERE PTSLogKey = @cPTSLogKey

			IF @@ERROR <>0
			BEGIN
				SET @nErrNo = 181054
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdPTSLogFail'
				GOTO ROLLBACKTRAN
			END
		END

		SET @nQTY_Bal=@nQty

		SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT PD.PickDetailKey, PD.QTY   
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
      WHERE PD.StorerKey = @cStorerKey
			AND PD.DropID = @cDropID
			AND PD.Status = @cPickConfirmStatus
			AND PD.CaseID = ''
			AND PD.SKU=@csku
         AND PD.Status <> '4'

		OPEN @curPD 

		-- Loop PickDetail    
		FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD    
		WHILE @@FETCH_STATUS = 0    
		BEGIN    
			-- Exact match    
			IF @nQTY_PD = @nQTY_Bal    
			BEGIN  
				 -- Confirm PickDetail    
				UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
					Status = @cPickConfirmStatus,    
					dropid = @cToLabelNo,    
					EditDate = GETDATE(),    
					EditWho  = SUSER_SNAME()    
				WHERE PickDetailKey = @cPickDetailKey    
				IF @@ERROR <> 0    
				BEGIN    
					SET @nErrNo = 181055    
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
					GOTO RollBackTran   
				END
				SET @nQTY_Bal = 0
         END   
			ELSE IF @nQTY_PD < @nQTY_Bal    
			BEGIN    
				-- Confirm PickDetail    
				UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
					Status = @cPickConfirmStatus,    
					dropid = @cToLabelNo, 
					EditDate = GETDATE(),    
					EditWho  = SUSER_SNAME()    
				WHERE PickDetailKey = @cPickDetailKey    
				IF @@ERROR <> 0    
				BEGIN    
					SET @nErrNo = 181056    
					SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
					GOTO RollBackTran    
				END    
    
				SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance    
			END    
			-- PickDetail have more    
			ELSE IF @nQTY_PD > @nQTY_Bal    
			BEGIN    
				 -- Get new PickDetailkey       
            EXECUTE dbo.nspg_GetKey    
               'PICKDETAILKEY',    
               10 ,    
               @cNewPickDetailKey OUTPUT,    
               @bSuccess          OUTPUT,    
               @nErrNo            OUTPUT,    
               @cErrMsg           OUTPUT    
            IF @bSuccess <> 1    
            BEGIN    
               SET @nErrNo = 181057    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey    
               GOTO RollBackTran    
            END    
    
            -- Create new a PickDetail to hold the balance    
            INSERT INTO dbo.PickDetail (    
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,    
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,    
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
               PickDetailKey,    
               Status,    
               QTY,    
               TrafficCop,    
               OptimizeCop,  
               Channel_ID )      --(cc01)    
            SELECT    
					CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,    
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,    
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
               @cNewPickDetailKey,    
               Status,    
               @nQTY_PD - @nQTY_Bal, -- QTY    
               NULL, -- TrafficCop    
               '1',   -- OptimizeCop   
               Channel_ID --(cc01)    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE PickDetailKey = @cPickDetailKey

				IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 181058    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail    
               GOTO RollBackTran    
            END   

				-- Change orginal PickDetail with exact QTY (with TrafficCop)    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               QTY = @nQTY_Bal,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME(),    
               Trafficcop = NULL    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 181059    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
               GOTO RollBackTran    
            END    
    
            -- Confirm orginal PickDetail with exact QTY    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               Status = @cPickConfirmStatus,    
               DropID = @cToLabelNo,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME()    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 181060    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
               GOTO RollBackTran    
            END    
			END

			FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
		END

		CLOSE @curPD
		DEALLOCATE @curPD


		SELECT @cFromloc = ptsposition,
				 @cLot = lot,
				 @cUom = uom
		FROM rdt.rdtPTSLog WITH (NOLOCK)
		WHERE PTSLogKey = @cPTSLogKey

		SELECT @cPutawayZone = PutawayZone  
		FROM dbo.LOC WITH (NOLOCK)  
		WHERE Facility = @cFacility  
			AND   Loc = @cFromLoc 

		SELECT @nUOMQty=qty
		from UCC WITH (NOLOCK)
		where UCCNO=@cDropID
			AND Storerkey=@cStorerKey

      IF (ISNULL(@cShort,'')  in('',0))
      BEGIN

		   IF NOT EXISTS( SELECT 1 from taskdetail (nolock)
					   where tasktype='ASTRPT'
						   AND storerkey=@cStorerKey
						   AND sku=@cSKU
						   AND fromloc=@cFromloc
						   AND lot=@cLot
                     and caseid=@cDropID
						   AND status=0)
		   BEGIN

			   SET @nErrNo = 0  
            EXEC [RDT].[rdt_513SuggestLOC13]   
               @nMobile       = @nMobile,  
               @nFunc         = @nFunc,  
               @cLangCode     = @cLangCode,  
               @cStorerkey    = @cStorerkey,  
               @cFacility     = @cFacility,  
               @cFromLoc      = @cFromLoc,  
               @cFromID       = @cDropID,  
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
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get PALOC Err  
               GOTO RollBackTran  
            END  
  
			   IF ISNULL( @cOutField01, '') = ''  
			   BEGIN  
				   SET @nErrNo = 181061  
				   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get PALOC Err  
				   GOTO RollBackTran  
			   END  
			   ELSE  
				   SET @cToLOC = @cOutField01  
			
			   SET @nPABookingKey = 0
           
			   -- Lock SuggestedLOC    
			   EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'    
				   ,@cFromLOC			= @cFromLoc    
				   ,@cFromID			= ''     
				   ,@cSuggestedLOC	= @cToLOC    
				   ,@cStorerKey		= @cStorerKey    
				   ,@nErrNo				= @nErrNo OUTPUT    
				   ,@cErrMsg			= @cErrMsg OUTPUT    
				   ,@cSKU				= @cSKU    
				   ,@nPutawayQTY		= @nQty       
				   ,@cFromLOT			= @cLot    
				   ,@nPABookingKey	= @nPABookingKey OUTPUT

				   -- Get LOC info  
			   SET @cToLOCPAZone = ''  
			   SET @cToLOCAreaKey = ''  
			   SELECT @cToLOCPAZone = PutawayZone FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC  
			   SELECT @cToLOCAreaKey = AreaKey FROM AreaDetail WITH (NOLOCK) WHERE PutawayZone = @cToLOCPAZone

			   SET @bSuccess = 1  
			   EXECUTE dbo.nspg_getkey  
				   'TASKDETAILKEY'  
				   , 10  
				   , @cNewTaskDetailKey OUTPUT  
				   , @bSuccess          OUTPUT  
				   , @nErrNo            OUTPUT  
				   , @cErrMsg           OUTPUT  
			   IF @bSuccess <> 1  
			   BEGIN  
				   SET @nErrNo = 181062  
				   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey  
				   GOTO ROLLBACKTRAN  
			   END    

			   INSERT INTO TaskDetail (  
						   TaskDetailKey, TaskType, Status, UserKey, PickMethod, TransitCount, AreaKey, SourceType, FromLOC, FromID,   
						   ToLOC, ToID, StorerKey, SKU, LOT, UOMQty, QTY, ListKey, SourceKey, WaveKey, LoadKey, Priority, SourcePriority, TrafficCop,   
						   Caseid)    
			   VALUES   
				   (@cNewTaskDetailKey,'ASTRPT','0',@cUserName,'PP',1,@cToLOCAreaKey,'rdt_762ExtUpdSP01',@cfromloc,''
				   ,@cToLOC,'',@cStorerKey,@cSKU,@cLot,@nUOMQty,@nUOMQty-@nQty,'','',@cWavekey,'','9','9',NULL,
				   @cdropid)
			   IF @@ERROR <> 0  
			   BEGIN  
				   SET @nErrNo = 181063  
				   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail  
				   GOTO ROLLBACKTRAN  
			   END 
		   END
		   ELSE
		   BEGIN
			
			   select @cToLOC=toloc 
			   from taskdetail WITH (ROWLOCK)
			   where tasktype='ASTRPT'
				   AND storerkey=@cStorerKey
				   AND sku=@cSKU
				   AND fromloc=@cFromloc
				   AND lot=@cLot
				   AND status=0
               and caseid=@cDropID

			   -- Lock SuggestedLOC    
			   EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'    
				   ,@cFromLOC			= @cFromLoc    
				   ,@cFromID			= ''     
				   ,@cSuggestedLOC	= @cToLOC    
				   ,@cStorerKey		= @cStorerKey    
				   ,@nErrNo				= @nErrNo OUTPUT    
				   ,@cErrMsg			= @cErrMsg OUTPUT    
				   ,@cSKU				= @cSKU    
				   ,@nPutawayQTY		= @nQty       
				   ,@cFromLOT			= @cLot    
				   ,@nPABookingKey	= @nPABookingKey OUTPUT

			   UPDATE taskdetail WITH (ROWLOCK)
			   set qty=qty-@nQty
			   where tasktype='ASTRPT'
				   AND storerkey=@cStorerKey
				   AND sku=@cSKU
				   AND fromloc=@cFromloc
				   AND lot=@cLot
				   AND status=0

			   IF @@ERROR <> 0  
			   BEGIN  
				   SET @nErrNo = 181064  
				   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InsTaskDetFail  
				   GOTO ROLLBACKTRAN  
			   END 
		   END
      END
	END

	IF @nStep =4
	BEGIN
		DECLARE @cOption NVARCHAR(1)

		SELECT @cOption=I_Field01
		from rdt.rdtmobrec (nolock)
		where mobile=@nMobile

		IF @cOption='1'
		BEGIN
			-- Update rdt.rdtPTSLog
			UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
			SET  Status = '9' -- In Progress
				, LabelNo = @cToLabelNo
				, EditDate = GetDate()
			WHERE PTSLogKey = @cPTSLogKey

			IF @@ERROR <> 0  
			BEGIN  
				SET @nErrNo = 181065  
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPTSLogFail  
				GOTO ROLLBACKTRAN  
			END 

         SET @nQTY_Bal=@nQty

			SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT PD.PickDetailKey, PD.QTY   
			FROM dbo.PickDetail PD WITH (NOLOCK) 
			JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
			WHERE PD.StorerKey = @cStorerKey
				AND PD.DropID = @cDropID
				AND PD.Status = @cPickConfirmStatus
				AND PD.CaseID = ''
				AND PD.SKU=@csku

			OPEN @curPD 

			-- Loop PickDetail    
			FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD    
			WHILE @@FETCH_STATUS = 0    
			BEGIN    
				-- Exact match    
				IF @nQTY_PD = @nQTY_Bal    
				BEGIN  
					 -- Confirm PickDetail    
					UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
						Status = @cPickConfirmStatus,    
						--dropid = @cToLabelNo,    
						EditDate = GETDATE(),    
						EditWho  = SUSER_SNAME()    
					WHERE PickDetailKey = @cPickDetailKey    
					IF @@ERROR <> 0    
					BEGIN    
						SET @nErrNo = 181066    
						SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
						GOTO RollBackTran   
					END
					SET @nQTY_Bal = 0
				END   
				ELSE IF @nQTY_PD < @nQTY_Bal    
				BEGIN    
					-- Confirm PickDetail    
					UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
						Status = @cPickConfirmStatus,    
						--dropid = @cToLabelNo, 
						EditDate = GETDATE(),    
						EditWho  = SUSER_SNAME()    
					WHERE PickDetailKey = @cPickDetailKey    
					IF @@ERROR <> 0    
					BEGIN    
						SET @nErrNo = 181067    
						SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
						GOTO RollBackTran    
					END    
    
					SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance    
				END    
				-- PickDetail have more    
				ELSE IF @nQTY_PD > @nQTY_Bal    
				BEGIN    

               IF @nQTY_Bal=0
               BEGIN
                  -- Change orginal PickDetail with exact QTY (with TrafficCop)    
					   UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
						   status = '4',    
						   EditDate = GETDATE(),    
						   EditWho  = SUSER_SNAME(),    
						   Trafficcop = NULL    
					   WHERE PickDetailKey = @cPickDetailKey 

					   IF @@ERROR <> 0    
					   BEGIN    
						   SET @nErrNo = 181070    
						   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
						   GOTO RollBackTran    
					   END  
               END
               ELSE
               BEGIN
						   -- Get new PickDetailkey      
					   EXECUTE dbo.nspg_GetKey    
						   'PICKDETAILKEY',    
						   10 ,    
						   @cNewPickDetailKey OUTPUT,    
						   @bSuccess          OUTPUT,    
						   @nErrNo            OUTPUT,    
						   @cErrMsg           OUTPUT    
					   IF @bSuccess <> 1    
					   BEGIN    
						   SET @nErrNo = 181069    
						   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey    
						   GOTO RollBackTran    
					   END    
    
					   -- Create new a PickDetail to hold the balance    
					   INSERT INTO dbo.PickDetail (    
						   CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,    
						   UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,    
						   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
						   EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
						   PickDetailKey,    
						   Status,    
						   QTY,    
						   TrafficCop,    
						   OptimizeCop,  
						   Channel_ID )      --(cc01)    
					   SELECT    
						   CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,    
						   UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,    
						   CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,    
						   EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,    
						   @cNewPickDetailKey,    
						   '4',    
						   @nQTY_PD - @nQTY_Bal, -- QTY    
						   NULL, -- TrafficCop    
						   '1',   -- OptimizeCop   
						   Channel_ID --(cc01)    
					   FROM dbo.PickDetail WITH (NOLOCK)    
					   WHERE PickDetailKey = @cPickDetailKey

					   IF @@ERROR <> 0    
					   BEGIN    
						   SET @nErrNo = 181070    
						   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
						   GOTO RollBackTran    
					   END    

					   -- Change orginal PickDetail with exact QTY (with TrafficCop)    
					   UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
						   QTY = @nQTY_Bal,    
						   EditDate = GETDATE(),    
						   EditWho  = SUSER_SNAME(),    
						   Trafficcop = NULL    
					   WHERE PickDetailKey = @cPickDetailKey    
					   IF @@ERROR <> 0    
					   BEGIN    
						   SET @nErrNo = 181071    
						   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
						   GOTO RollBackTran    
					   END   
               END

               SET @nQTY_Bal =0
				END

				FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
			END
		END
		IF @cOption='9'
		BEGIN
			select @nPTSQty=ExpectedQty
			from rdt.rdtPTSLog (NOLOCK)
			WHERE PTSLogKey = @cPTSLogKey

			INSERT INTO rdt.rdtPTSLog ( PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty, Qty, Remarks, Func, AddDate, AddWho )
			SELECT PTSPosition, Status, DropID, LabelNo, StorerKey, ConsigneeKey, OrderKey, SKU, Loc, Lot, UOM
                                     ,ExpectedQty-@nQty, Qty, Remarks, Func, AddDate, AddWho 
			from rdt.rdtPTSLog (NOLOCK)
			WHERE PTSLogKey = @cPTSLogKey

			IF @@ERROR <>0
			BEGIN
				SET @nErrNo = 181072
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INSPTSLogFail'
				GOTO ROLLBACKTRAN
			END

			-- Update rdt.rdtPTSLog
			UPDATE rdt.rdtPTSLog WITH (ROWLOCK)
			SET  Status = '9' -- In Progress
				--, LabelNo = @cToLabelNo
				,qty=@nqty
				, EditDate = GetDate()
			WHERE PTSLogKey = @cPTSLogKey

			IF @@ERROR <>0
			BEGIN
				SET @nErrNo = 181073
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdPTSLogFail'
				GOTO ROLLBACKTRAN
			END
		END

	END

	GOTO QUIT
END

ROLLBACKTRAN:
   ROLLBACK TRAN rdt_762ExtUpdSP01
QUIT:
   WHILE @@TRANCOUNT> @nTranCount
      COMMIT TRAN 

GO