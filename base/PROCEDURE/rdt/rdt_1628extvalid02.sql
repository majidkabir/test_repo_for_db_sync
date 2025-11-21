SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1628ExtValid02                                  */
/* Purpose: Cluster Pick Extended Validate SP for MAST                  */
/*          Only can pick orders with full case or discrete pick        */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 29-Nov-2017  1.0  James      WMS3221. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtValid02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cBarcode    NVARCHAR( 60),
           @cLottable02 NVARCHAR( 18),
           @dLottable04 DATETIME,
           @cFacility   NVARCHAR( 5),
           @cUCC_SKU    NVARCHAR( 20), 
           @cUserName   NVARCHAR( 18), 
           @cLot        NVARCHAR( 10),
           @cPickZone   NVARCHAR( 10),
           @cPutAwayZone NVARCHAR( 10),
           @bsuccess          INT,
           @nUCC_Qty          INT,
           @nRDTPickLockQTY   INT,
           @nTotalPickQty     INT,
           @nTranCount        INT,
           @nRowRef           INT,
           @nPickQty          INT,
           @nLot_Qty          INT,
           @nPDLot_Qty        INT
           

   SET @nErrNo = 0

   SELECT @cBarcode = I_FIELD03,
          @nQty = I_FIELD13,
          @cLottable02 = V_Lottable02,
          @dLottable04 = V_Lottable04,
          @cFacility = Facility,
          @cUserName = UserName,
          @cLot = V_LOT,
          @cPutAwayZone = V_String10,
          @cPickZone = V_String11
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 8
      BEGIN
         IF @cBarcode <> ''
         BEGIN
	         SELECT @bsuccess = 1
      
            -- Validate SKU/UPC
            EXEC dbo.nspg_GETSKU
               @c_StorerKey= @cStorerKey  OUTPUT
               ,@c_Sku      = @cBarcode    OUTPUT
               ,@b_Success  = @bSuccess    OUTPUT
               ,@n_Err      = @nErrNo      OUTPUT
               ,@c_ErrMsg   = @cErrMsg     OUTPUT

            -- User key in valid SKU/UPC, no need decode anymore
   	      IF @bSuccess = 1
            BEGIN
               DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT LOT, ISNULL( SUM( PickQty), 0) FROM RDT.rdtPickLock WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND Status = '1'
               AND AddWho = @cUserName
               AND LoadKey = @cLoadKey
               AND SKU = @cSKU
               AND LOC = @cLOC
               GROUP BY LOT
               OPEN CUR_LOOP
               FETCH NEXT FROM CUR_LOOP INTO @cLot, @nLot_Qty
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @nPDLot_Qty = SUM( Qty)
                  FROM dbo.PICKDETAIL WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   SKU = @cSKU
                  AND   LOC = @cLOC
                  AND   Lot = @cLot
                  AND   Status = '0'

                  IF @nPDLot_Qty > @cLot
                     BREAK

                  FETCH NEXT FROM CUR_LOOP INTO @cLot, @nLot_Qty
               END
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP

               IF NOT EXISTS ( SELECT 1 FROM RDT.rdtPickLock WITH (NOLOCK) 
                               WHERE StorerKey = @cStorerKey
                               AND Status = '1'
                               AND AddWho = @cUserName
                               AND LoadKey = @cLoadKey
                               AND SKU = @cSKU
                               AND LOC = @cLOC
                               AND Lot = @cLot
                               AND ISNULL( LabelNo, '') = '')
               BEGIN
                     INSERT INTO RDT.RDTPickLock
                     (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
                     , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey, PickQty, LabelNo)
                     SELECT TOP 1 WaveKey, LoadKey, Orderkey, '**' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey,
                     LOT, LOC, Lottable02, Lottable04, '1', AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey, @nQty, ''
                     FROM RDT.RDTPickLock WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND Status = '1'
                     AND AddWho = @cUserName
                     AND LoadKey = @cLoadKey
                     AND SKU = @cSKU
                     AND LOC = @cLOC
                     AND Lot = @cLot
                     AND ISNULL( LabelNo, '') <> ''

                     UPDATE TOP (1) RDT.RDTPickLock WITH (ROWLOCK) SET PickQty = PickQty - @nQty
                     WHERE StorerKey = @cStorerKey
                     AND Status = '1'
                     AND AddWho = @cUserName
                     AND LoadKey = @cLoadKey
                     AND SKU = @cSKU
                     AND LOC = @cLOC
                     AND Lot = @cLot
                     AND ISNULL( LabelNo, '') <> ''

               END

               GOTO Quit
            END
            ELSE
            BEGIN
               -- Ignore error return by nspg_getsku here
               -- We just need to check whether barcode is a valid SKU or not
               -- Further checking below
               SET @nErrNo = ''
               SET @cErrMsg = ''
            END

            -- Check scanned data is valid UCC
            IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   UCCNo = @cBarcode
                        AND   [Status] = '1')
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND   UCCNo = @cBarcode 
                           AND   [Status] = '1'
                           GROUP BY UCCNo 
                           HAVING COUNT( DISTINCT SKU) > 1)
               BEGIN
                  SET @nErrNo = 116101
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Mix ucc sku
                  GOTO Quit
               END

               -- Only UCC with single sku will allow here
               SELECT @cUCC_SKU = SKU, @nUCC_Qty = ISNULL( SUM( QTY), 0)
               FROM dbo.UCC WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cBarcode
               AND   [Status] = '1'
               GROUP BY SKU

               IF @cUCC_SKU <> @cSKU
               BEGIN
                  SET @nErrNo = 116102
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Sku x match
                  GOTO Quit
               END

               SET @nRDTPickLockQTY = 0
               SET @nTotalPickQty = 0

               IF @nFunc = 1628
               BEGIN
                  SELECT @nRDTPickLockQTY = SUM(PickQty)
                  FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND Status = '1'
                     AND AddWho = @cUserName
                     AND LoadKey = @cLoadKey
                     AND SKU = @cSKU
                     AND LOC = @cLOC
                     AND (( ISNULL(@cLottable02, '') = '') OR ( Lottable02 = @cLottable02))
                     AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(Lottable04, '') = @dLottable04))

                  SELECT @nTotalPickQty = ISNULL( SUM(PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
                  WHERE PD.StorerKey = @cStorerKey
                     AND PD.SKU = @cSKU
                     AND PD.LOC = @cLOC
                     AND PD.Status = '0'
                     AND LOC.Facility = @cFacility
                     AND (( ISNULL(@cLottable02, '') = '') OR ( LA.Lottable02 = @cLottable02))
                     AND (( ISNULL(@dLottable04, '') = '') OR ( ISNULL(LA.Lottable04, '') = @dLottable04))
                     AND LPD.LoadKey = @cLoadKey
               END
               ELSE
               BEGIN
                  SELECT @nRDTPickLockQTY = SUM(PickQty)
                  FROM RDT.RDTPickLock WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                     AND SKU = @cSKU
                     AND StorerKey = @cStorerKey
                     AND LOC = @cLOC
                     AND Status = '1'
                     AND AddWho = @cUserName

                  SELECT @nTotalPickQty = ISNULL( SUM(QTY), 0)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND LOC = @cLOC
                     AND SKU = @cSKU
                     AND OrderKey = @cOrderKey
                     AND Status = '0'
                     AND Lot = @cLOT
               END

               IF @nRDTPickLockQTY >  @nTotalPickQty
               BEGIN
                  SET @nErrNo = 116103
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Qty x match
                  GOTO Quit
               END

               IF EXISTS (
                  SELECT 1 FROM rdt.rdtPickLock RPL WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   SKU = @cSKU
                  AND   RPL.Status = '1'
                  AND   ( ISNULL( @cWaveKey, '') = '' OR RPL.WaveKey = @cWaveKey)
                  AND   ( ISNULL( @cLoadKey, '') = '' OR RPL.LoadKey = @cLoadKey)
                  AND   ( ISNULL( @cPickZone, '') = '' OR RPL.PickZone = @cPickZone)
                  AND   ( ISNULL( @cPutAwayZone, '') = 'ALL' OR RPL.PutAwayZone = @cPutAwayZone)
                  AND   RPL.AddWho = @cUserName
                  AND   RPL.LabelNo = @cBarcode
                  AND   EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
                                 WHERE PD.StorerKey = RPL.StorerKey
                                 AND   PD.OrderKey = RPL.OrderKey
                                 AND   PD.SKU = RPL.SKU
                                 AND   PD.LOC = RPL.LOC
                                 AND   [Status] = '0'))
               BEGIN
                  SET @nErrNo = 116104
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Double Scanned
                  GOTO Quit
               END

               SET @nTranCount = @@TRANCOUNT
               BEGIN TRAN
               SAVE TRAN rdt_1628ExtValid02

               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT ROWREF, PickQty FROM rdt.rdtPickLock RPL WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   SKU = @cSKU
               AND   RPL.Status = '1'
               AND   ( ISNULL( @cWaveKey, '') = '' OR RPL.WaveKey = @cWaveKey)
               AND   ( ISNULL( @cLoadKey, '') = '' OR RPL.LoadKey = @cLoadKey)
               AND   ( ISNULL( @cPickZone, '') = '' OR RPL.PickZone = @cPickZone)
               AND   ( ISNULL( @cPutAwayZone, '') = 'ALL' OR RPL.PutAwayZone = @cPutAwayZone)
               AND   RPL.AddWho = @cUserName
               AND   RPL.DropID = @cDropID
               AND   ISNULL( RPL.LabelNo, '') = ''
               AND   RPL.PickQty > 0
               AND   EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
                              WHERE PD.StorerKey = RPL.StorerKey
                              AND   PD.OrderKey = RPL.OrderKey
                              AND   PD.SKU = RPL.SKU
                              AND   PD.LOC = RPL.LOC
                              AND   [Status] = '0')
                              ORDER BY LOT
               OPEN CUR_UPD
               FETCH NEXT FROM CUR_UPD INTO @nRowRef, @nPickQty
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @nPickQty <= @nUCC_Qty
                  BEGIN
                     UPDATE RDT.rdtPickLock WITH (ROWLOCK) SET 
                        LabelNo = @cBarcode
                     WHERE ROWREF = @nRowRef

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 116105
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKLOG FAIL
                        ROLLBACK TRAN rdt_1628ExtValid02
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN rdt_1628ExtValid02
                        CLOSE CUR_UPD
                        DEALLOCATE CUR_UPD
                        GOTO Quit
                     END
                  END
                  ELSE  --IF @nPickQty > @nUCC_Qty
                  BEGIN
                     INSERT INTO RDT.RDTPickLock
                     (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey
                     , LOT, LOC, Lottable02, Lottable04, Status, AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey, PickQty, LabelNo)
                     SELECT TOP 1 WaveKey, LoadKey, Orderkey, '**' as OrderLineNumber, StorerKey, SKU, PutAwayZone, PickZone, PickDetailKey,
                     LOT, LOC, Lottable02, Lottable04, '1', AddWho, AddDate, DropID, PickSlipNo, Mobile, PackKey, @nPickQty - @nUCC_Qty, ''
                     FROM RDT.RDTPickLock WITH (NOLOCK)
                     WHERE ROWREF = @nRowRef

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 116106
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKLOG FAIL
                        ROLLBACK TRAN rdt_1628ExtValid02
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN rdt_1628ExtValid02
                        CLOSE CUR_UPD
                        DEALLOCATE CUR_UPD
                        GOTO Quit
                     END

                     UPDATE RDT.RDTPickLock WITH (ROWLOCK) SET
                        PickQty = @nUCC_Qty,
                        LabelNo = @cBarcode
                     WHERE ROWREF = @nRowRef

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 116107
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKLOG FAIL
                        ROLLBACK TRAN rdt_1628ExtValid02
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                           COMMIT TRAN rdt_1628ExtValid02
                        CLOSE CUR_UPD
                        DEALLOCATE CUR_UPD
                        GOTO Quit
                     END
                  END

                  SET @nUCC_Qty = @nUCC_Qty - @nPickQty
                  IF @nUCC_Qty <= 0
                     BREAK

                  FETCH NEXT FROM CUR_UPD INTO @nRowRef, @nPickQty
               END
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD

               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN rdt_1628ExtValid02
            END
         END   -- @cBarcode
      END
   END

QUIT:

GO