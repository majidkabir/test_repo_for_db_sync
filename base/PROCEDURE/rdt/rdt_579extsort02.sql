SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_579ExtSort02                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Get statistics                                                    */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-05 1.0  Ung      WMS-4202 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_579ExtSort02] (
   @nMobile     INT,
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @nInputKey   INT,
   @cLangCode   NVARCHAR( 3),
   @cStorerkey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cType       NVARCHAR( 10), --STAT/CONFIRM
   @cLoadKey    NVARCHAR( 10) OUTPUT,
   @cUCCNo      NVARCHAR( 20),
   @cSKU        NVARCHAR( 20), 
   @nQTY        INT,
   @cScan       NVARCHAR( 5)  OUTPUT,
   @cTotal      NVARCHAR( 5)  OUTPUT,
   @cPOS        NVARCHAR( 20) OUTPUT,
   @cSortInf1   NVARCHAR( 20) OUTPUT,
   @cSortInf2   NVARCHAR( 20) OUTPUT,
   @cSortInf3   NVARCHAR( 20) OUTPUT,
   @cSortInf4   NVARCHAR( 20) OUTPUT,
   @cSortInf5   NVARCHAR( 20) OUTPUT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR(20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   IF @cType = 'CONFIRM'
   BEGIN
      DECLARE @bSuccess          INT
      DECLARE @cSortLoadKey      NVARCHAR( 10)
      DECLARE @cOrderKey         NVARCHAR( 10)
      DECLARE @cExternOrderKey   NVARCHAR( 30)
      DECLARE @cPickDetailKey    NVARCHAR( 10)
      DECLARE @cLOC              NVARCHAR( 10)
      DECLARE @cID               NVARCHAR( 18)
      DECLARE @cStatus           NVARCHAR( 1)
      DECLARE @cSKUDesc          NVARCHAR( 60)
      DECLARE @nQTY_Bal          INT
      DECLARE @nQTY_PD           INT

      SET @cSortLoadKey = ''
      SET @nQTY_Bal = @nQTY

      -- Check full case exist
      SELECT TOP 1
         @cSortLoadKey = LPD.LoadKey
      FROM rdt.rdtSortCaseLog L WITH (NOLOCK) 
         JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = L.LoadKey)
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
         JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE L.Mobile = @nMobile
         AND PD.SKU = @cSKU
         AND PD.Status < '5'
         AND PD.Status <> '4' -- Short
         AND PD.UOM = '2' -- case
         AND PD.CaseID <> 'SORTED'
         AND Pack.CaseCnt > 0
      GROUP BY LPD.LoadKey, PD.SKU, Pack.CaseCnt
      HAVING CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) > 0

      -- Check full case available
      IF @cSortLoadKey = ''
      BEGIN
         SET @nErrNo = 120601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No more case
         GOTO Quit
      END

      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_579ExtSort02 -- For rollback or commit only our own transaction

      -- Lock the sorting criteria
      IF NOT EXISTS( SELECT 1
         FROM rdt.rdtSortCaseLock WITH (NOLOCK)
         WHERE LoadKey = @cSortLoadKey
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND AddWho = SUSER_SNAME())
      BEGIN
         INSERT INTO rdt.rdtSortCaseLock( LoadKey, StorerKey, SKU, AddWho)
         VALUES (@cSortLoadKey, @cStorerKey, @cSKU, SUSER_SNAME())
         IF @@ERROR <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UCCLock. Retry
            GOTO Quit
         END
      END

      -- Loop PickDetail
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LPD.LoadKey = @cSortLoadKey
            AND PD.SKU = @cSKU
            AND PD.Status < '5'
            AND PD.Status <> '4' -- Short
            AND PD.UOM = '2' -- case
            AND PD.CaseID <> 'SORTED'
            AND Pack.CaseCnt > 0
         ORDER BY PD.OrderLineNumber
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = 'SORTED',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 120602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END

         -- PickDetail have less
         ELSE IF @nQTY_PD < @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               CaseID = 'SORTED',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 120603
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
         END

         -- PickDetail have more
         ELSE IF @nQTY_PD > @nQTY_Bal
         BEGIN
            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 120604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
               GOTO RollBackTran
            END

            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey,
               Notes
               , PickDetailKey,
               Status,
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey,
               'RefPDKey: ' + @cPickDetailKey + ', PDQty: '+ CAST(@nQTY_PD AS VARCHAR) + ', BalQty: ' + CAST(@nQTY_Bal AS VARCHAR) -- IN00289179
               , @cNewPickDetailKey,
               Status,
               @nQTY_PD - @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 120605
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
               GOTO RollBackTran
            END

            -- Split RefKeyLookup
            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
            BEGIN
               -- Insert into
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
               FROM RefKeyLookup WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 120606
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQTY_Bal,
               CaseID = 'SORTED',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 120607
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END

         IF @nQTY_Bal = 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END

      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 120608
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset error
         GOTO RollBackTran
      END

      -- Unlock the sorting criteria
      DECLARE @nRowRef INT
      SELECT @nRowRef = RowRef
      FROM rdt.rdtSortCaseLock WITH (NOLOCK)
      WHERE LoadKey = @cSortLoadKey
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND AddWho = SUSER_SNAME()

      IF @@ROWCOUNT = 1
      BEGIN
         DELETE rdt.rdtSortCaseLock
         WHERE @nRowRef = RowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 120609
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         DECLARE @curLog CURSOR
         SET @curLog = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM rdt.rdtSortCaseLock WITH (NOLOCK)
            WHERE LoadKey = @cSortLoadKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND AddWho = SUSER_SNAME()
         OPEN @curLog
         FETCH NEXT FROM @curLog INTO @nRowRef 
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtSortCaseLock
            WHERE @nRowRef = RowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 120610
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail
               GOTO Quit
            END
            FETCH NEXT FROM @curLog INTO @nRowRef 
         END
      END
      
      COMMIT TRAN rdt_579ExtSort02

      SELECT @cSKUDesc = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

      -- Output sort info
      SET @cSortInf4 = rdt.rdtgetmessage( 120611, @cLangCode, 'DSP') --QTY:
      
      SET @cPOS = ''
      SET @cSortInf1 = rdt.rdtFormatString( @cSKUDesc, 1, 20)
      SET @cSortInf2 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cSortInf3 = ''
      SET @cSortInf4 = RTRIM( @cSortInf4) + ' '+ CAST( @nQTY AS NVARCHAR( 5))
      SET @cSortInf5 = ''
      
      SET @cLoadKey = @cSortLoadKey
   END

   IF @cType = '' OR @cType = 'CONFIRM'
   BEGIN
      DECLARE @nScan  INT
      DECLARE @nTotal INT

      SET @nScan = 0
      SET @nTotal = 0

      -- All LoadKey
      IF @cType = ''
      BEGIN
         -- Get LoadKey
         SELECT @cLoadKey = LoadKey FROM rdt.rdtSortCaseLog WITH (NOLOCK) WHERE Mobile = @nMobile         
         IF @@ROWCOUNT > 1
            SET @cLoadKey = 'MULTI'
         
         SELECT 
            @nTotal = SUM( Total), 
            @nScan = SUM( Scan)
         FROM
         (
            SELECT 
               CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) AS Total, 
               CAST( SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY ELSE 0 END) / Pack.CaseCnt AS INT) AS Scan
            FROM rdt.rdtSortCaseLog L WITH (NOLOCK) 
               JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = L.LoadKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
               JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
            WHERE L.Mobile = @nMobile
               AND PD.QTY > 0
               AND PD.Status < '5'
               AND PD.Status <> '4' -- Short
               AND PD.UOM = '2'
               -- AND PD.CaseID = 'SORTED'
               AND Pack.CaseCnt > 0
            GROUP BY LPD.LoadKey, PD.SKU, Pack.CaseCnt
         ) AS A
      END
      
      -- Specific LoadKey
      ELSE
         SELECT 
            @nTotal = SUM( Total), 
            @nScan = SUM( Scan)
         FROM
         (
            SELECT 
               CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) AS Total, 
               CAST( SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY ELSE 0 END) / Pack.CaseCnt AS INT) AS Scan
            FROM LoadPlanDetail LPD WITH (NOLOCK)
               JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
               JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
               JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
            WHERE LPD.LoadKey = @cLoadKey
               AND PD.QTY > 0
               AND PD.Status < '5'
               AND PD.Status <> '4' -- Short
               AND PD.UOM = '2'
               -- AND PD.CaseID = 'SORTED'
               AND Pack.CaseCnt > 0
            GROUP BY LPD.LoadKey, PD.SKU, Pack.CaseCnt
         ) AS A
      
      SET @cScan = CAST( @nScan AS NVARCHAR(5))
      SET @cTotal = CAST( @nTotal AS NVARCHAR(5))
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_579ExtSort02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO