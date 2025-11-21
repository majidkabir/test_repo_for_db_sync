SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_877DecodeSP01_Confirm                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode GS1-128 barcode                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-05-2018  1.0  Ung         WMS-4846 Created                        */
/* 10-10-2018  1.1  Ung         WMS-6576 Add inner                      */
/* 05-08-2019  1.2  Ung         WMS-10008 Refine check dup case ID      */
/* 17-08-2022  1.3  YeeKung     Fix error message                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_877DecodeSP01_Confirm]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cPickSlipNo    NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_877DecodeSP01_Confirm

   DECLARE @bSuccess       INT
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @nCaseCNT       INT
   DECLARE @nInnerPack     INT
   DECLARE @nUOM           INT
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cCaseID        NVARCHAR( 18)
   DECLARE @cLottable01    NVARCHAR( 18)
   DECLARE @cLottable06    NVARCHAR( 30)
   DECLARE @cBarcode       NVARCHAR( MAX)
   DECLARE @nQTY_Bal       INT
   DECLARE @nQTY_PD        INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @curPD          CURSOR

   -- Loop PickDetail
   DECLARE @curCase CURSOR
   SET @curCase = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT CaseID, Lottable01, Lottable06, Barcode
      FROM rdt.rdtCaseIDCaptureLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
      ORDER BY RowRef
   OPEN @curCase
   FETCH NEXT FROM @curCase INTO @cCaseID, @cLottable01, @cLottable06, @cBarcode
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cSKU = ''

      -- Determine case or inner
      IF LEN( @cBarcode) = 45 -- CASE
      BEGIN
         -- Get random SKU
         SELECT @cSKU = PD.SKU
         FROM PickDetail PD WITH (NOLOCK)
            JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.DropID = ''
            AND PD.QTY > 0
            AND PD.UOM IN (1, 2)
            AND PD.QTY % CAST( Pack.CaseCnt AS INT) = 0
            AND PD.Status <> '4'
            AND LA.Lottable01 = @cLottable01
            AND LA.Lottable06 = @cLottable06
            AND SKU.SKUGroup = 'REG'
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'ORIGIN' AND Code = LA.Lottable03 AND StorerKey = @cStorerKey) -- L03 = country of origin

         -- Check SKU found to offset
         IF @cSKU = ''
         BEGIN
            SET @nErrNo = 190051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSKUForCaseID
            GOTO RollBackTran
         END

         -- Check duplicate case / inner ID
         IF EXISTS( SELECT 1
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.DropID = @cCaseID
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND LA.Lottable06 = @cLottable06)
         BEGIN
            SET @nErrNo = 190052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Duplicate Case
            GOTO RollBackTran
         END

         -- Get SKU info
         SELECT @nCaseCNT = Pack.CaseCNT
         FROM SKU WITH (NOLOCK)
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @nQTY_Bal = @nCaseCNT

         -- Loop PickDetail
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey, QTY
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.DropID = ''
               AND PD.QTY > 0
               AND PD.UOM IN (1, 2)
               AND PD.QTY % @nCaseCNT = 0
               AND PD.Status <> '4'
               AND LA.Lottable01 = @cLottable01
               AND LA.Lottable06 = @cLottable06
      END
      ELSE
      BEGIN
         -- Get random SKU
         SELECT @cSKU = PD.SKU
         FROM PickDetail PD WITH (NOLOCK)
            JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.StorerKey = @cStorerKey
            AND PD.DropID = ''
            AND PD.QTY > 0
            AND PD.UOM = 6
            AND PD.QTY % CAST( Pack.InnerPack AS INT) = 0
            AND PD.Status <> '4'
            AND LA.Lottable01 = @cLottable01
            -- AND LA.Lottable06 = @cLottable06
            AND SKU.SKUGroup = 'REG'
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID
            AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'ORIGIN' AND Code = LA.Lottable03 AND StorerKey = @cStorerKey) -- L03 = country of origin

         -- Check SKU found to offset
         IF @cSKU = ''
         BEGIN
            SET @nErrNo = 190053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSKUForInner
            GOTO RollBackTran
         END

         -- Check duplicate inner ID
         IF EXISTS( SELECT 1
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.DropID = @cCaseID
               AND PD.QTY > 0
               AND PD.Status <> '4')
         BEGIN
            SET @nErrNo = 190054
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DuplicateInner
            GOTO RollBackTran
         END

         -- Get SKU info
         SELECT @nInnerPack = Pack.InnerPack
         FROM SKU WITH (NOLOCK)
            JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @nQTY_Bal = @nInnerPack

         -- Loop PickDetail
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey, QTY
            FROM PickDetail PD WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.OrderKey = @cOrderKey
               AND PD.StorerKey = @cStorerKey
               AND PD.SKU = @cSKU
               AND PD.DropID = ''
               AND PD.QTY > 0
               AND PD.UOM = 6
               AND PD.QTY % @nInnerPack = 0
               AND PD.Status <> '4'
               AND LA.Lottable01 = @cLottable01
      END

      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nQTY_Bal
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cCaseID,
               Notes = @cBarcode,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190055
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
               DropID = @cCaseID,
               Notes = @cBarcode,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190056
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
               SET @nErrNo = 190057
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
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status,
               @nQTY_PD - @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190058
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
                  SET @nErrNo = 190059
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQTY_Bal,
               DropID = @cCaseID,
               Notes = @cBarcode,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 190060
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            SET @nQTY_Bal = 0 -- Reduce balance
         END

         IF @nQTY_Bal = 0
            BREAK

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY_PD
      END

      -- Check current case not fully offset
      IF @nQTY_Bal <> 0
      BEGIN
         SET @nErrNo = 190061
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Offset error
      END

      FETCH NEXT FROM @curCase INTO @cCaseID, @cLottable01, @cLottable06, @cBarcode
   END

   -- Clear log
   DELETE rdt.rdtCaseIDCaptureLog
   WHERE Mobile = @nMobile
      AND CaseID = @cCaseID

   COMMIT TRAN rdt_877DecodeSP01_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_877DecodeSP01_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO