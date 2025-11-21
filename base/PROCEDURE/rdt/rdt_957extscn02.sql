SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdt_957ExtScn02                                          */
/* Copyright: Maersk WMS                                                     */
/*                                                                           */
/* Purpose:                                                                  */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2024-07-04 1.0  NLT013   FCR-454 CREATE                                   */
/* 2024-11-07 1.0  NLT013   UWP-26694 update orderkey info for swapped UCC   */
/*                                                                           */
/*****************************************************************************/

CREATE   PROC [rdt].[rdt_957ExtScn02] (
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nScn             INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @tExtScnData      VariableTable READONLY,
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction          INT, --0 Jump Screen, 1 Prepare output fields .....
   @nAfterScn        INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @nCurrentStep        INT,
      @nCurrentScn         INT,
      @nRowCount           INT,
      @nTranCount          INT,

      @cExtendedValidateSP NVARCHAR( 20),
      @cExtendedUpdateSP   NVARCHAR( 20),
      @cExtendedInfoSP     NVARCHAR( 20),

      @cSSCC               NVARCHAR( 18),
      @cID                 NVARCHAR( 20),
      @cUCCNo              NVARCHAR( 18),
      @cUCCAllocated       NVARCHAR( 18),
      @cPickSlipNo         NVARCHAR( 10),
      @cSKU                NVARCHAR( 20),
      @cSKUStyle           NVARCHAR( 20),
      @cSKUSize            NVARCHAR( 10),
      @cDropID             NVARCHAR( 20),
      @cSwapUCCID          NVARCHAR( 20),
      @cSwapUCCLot         NVARCHAR( 10),
      @cSKUMeasurement     NVARCHAR( 5),
      @cOption             NVARCHAR( 1),
      @cUCCStatus          NVARCHAR( 1),
      @cSuggestUCC         NVARCHAR( 1),
      @cSuggestLoc         NVARCHAR( 10),
      @cToLoc              NVARCHAR( 10),
      @cUCCLoc             NVARCHAR( 10),
      @cLOT                NVARCHAR( 10),
      @cPickDetailKey      NVARCHAR( 18),
      @cUCCPicked          NVARCHAR( 10),
      @cToID               NVARCHAR( 20),
      @cPickZone           NVARCHAR( 10),
      @cOrderKey           NVARCHAR( 10),
      @cOrderLineNumber    NVARCHAR( 5),

      @nUCCQTY             INT,
      @nSSCCTotalQty       INT,
      @nQty                INT,
      @nQty1               INT,
      @nSSCCTotalScannedQty       INT,
      @cMoveQTYAlloc       NVARCHAR( 1),
      @cMoveQTYPick        NVARCHAR( 1),
      @cPickConfirmStatus  NVARCHAR( 1),
      @cPacKKey            NVARCHAR( 10),
      @nCaseCnt            INT

   SELECT 
      @nCurrentStep       = Step,
      @nCurrentScn         = Scn,
      @cPickSlipNo         = V_PickSlipNo,
      @cPickZone           = V_Zone,
      @cDropID             = V_String4,
      @cExtendedValidateSP = V_String21,
      @cExtendedUpdateSP   = V_String22,
      @cExtendedInfoSP     = V_String23,

      @cSSCC               = C_String1,
      @cSuggestUCC         = C_String2
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   -- Get storer config
   SET @cMoveQTYAlloc = rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', @cStorerKey)
   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   -- Check move alloc, but picked
   IF @cMoveQTYAlloc = '1' AND @cPickConfirmStatus = '5'
   BEGIN
      SET @nErrNo = 218913
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   -- Check move picked, but not pick confirm
   IF @cMoveQTYPick = '1' AND @cPickConfirmStatus < '5'
   BEGIN
      SET @nErrNo = 218914
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 957  --Pick Case
   BEGIN
      IF @nCurrentStep = 2 -- DropID
      BEGIN
         IF @nAction = 0 --Jump to 6387 SSCC
         BEGIN
            IF @nInputKey = 1 --Jump to 6387 SSCC
            BEGIN
               SET @cOutField01 = ''
               SET @nAfterScn = 6387
               SET @nAfterStep = 99

               GOTO Quit
            END
         END
      END
      ELSE IF @nCurrentStep = 99 -- Extended Screen
      BEGIN
         IF @nCurrentScn = 6387 -- SSCC
         BEGIN
            IF @nInputKey = 1
            BEGIN
               SET @cSSCC = @cInField01

               IF TRIM(@cSSCC) = ''
               BEGIN
                  SET @nErrNo = 218901
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SSCC Needed
                  GOTO Quit
               END

               SELECT TOP 1 
                  @cUCCNo     = ucc.UCCNo,
                  @cSKU       = pkd.Sku,
                  @cSKUStyle  = sku.Style, 
                  @cSKUSize   = sku.Size,
                  @cSKUMeasurement = sku.Measurement,
                  @cSuggestLoc  = ucc.Loc
               FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
               INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
               INNER JOIN dbo.SKU sku WITH(NOLOCK) ON pkd.StorerKey = sku.StorerKey AND pkd.Sku = sku.Sku
               WHERE pkh.StorerKey = @cStorerKey
                  AND pkh.PickHeaderKey = @cPickSlipNo
                  --AND pkd.ID = @cDropID
                  AND pkd.CaseID = @cSSCC
                  AND ucc.Status = '3'

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
               BEGIN
                  SET @nErrNo = 218902
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SSCC
                  GOTO Quit
               END

               SELECT @nSSCCTotalQty = SUM(pkd.Qty)
               FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
               INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
               INNER JOIN dbo.SKU sku WITH(NOLOCK) ON pkd.StorerKey = sku.StorerKey AND pkd.Sku = sku.Sku
               WHERE pkh.StorerKey = @cStorerKey
                  AND pkh.PickHeaderKey = @cPickSlipNo
                  --AND pkd.ID = @cDropID
                  AND pkd.CaseID = @cSSCC
                  AND ucc.Status = '3'

               SELECT @nSSCCTotalScannedQty = SUM(pkd.Qty)
               FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
               INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
               INNER JOIN dbo.SKU sku WITH(NOLOCK) ON pkd.StorerKey = sku.StorerKey AND pkd.Sku = sku.Sku
               WHERE pkh.StorerKey = @cStorerKey
                  AND pkh.PickHeaderKey = @cPickSlipNo
                  --AND pkd.ID = @cDropID
                  AND pkd.CaseID = @cSSCC
                  AND ((ucc.Status = '3' AND ISNULL(ucc.Userdefined08, '') = '1')
                     OR ucc.Status = '5')

               SELECT @cPacKKey = PackKey 
               FROM dbo.SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
               AND SKU = @cSKU
               
               SELECT @nCaseCnt = CaseCnt 
               FROM dbo.Pack WITH (NOLOCK) 
               WHERE PackKey = @cPackKey 
               
               IF @nCaseCnt > 0 
               BEGIN
                  SET @nQTY = @nSSCCTotalQty / @nCaseCnt
                  SET @nQty1 = ISNULL(@nSSCCTotalScannedQty, 0) / @nCaseCnt
               END
               ELSE
               BEGIN
                  SET @nQty = @nSSCCTotalQty
                  SET @nQty1 = ISNULL(@nSSCCTotalScannedQty, 0)
               END

               SET @cSuggestUCC = rdt.RDTGetConfig( @nFunc, 'SuggestUCC', @cStorerKey)
               IF @cSuggestUCC = '0'  
               BEGIN
                  SET @cSuggestUCC = ''
               END

               IF @cSuggestUCC = '1'
               BEGIN
                  SET @cOutField05 = @cUCCNo
               END
               ELSE
                  SET @cOutField05 = ''

               SET @cOutField01 = @cSuggestLoc
               SET @cOutField02 = @cSKUStyle
               SET @cOutField03 = @cSKUSize
               SET @cOutField04 = @cSKUMeasurement
               SET @cOutField06 = CAST (@nQty AS NVARCHAR(5))
               SET @cOutField07 = CAST (@nQty1 AS NVARCHAR(5))

               SET @nAfterScn = 6388
               SET @nAfterStep = 99
            END
            ELSE IF @nInputKey = 0
            BEGIN
               SELECT @nRowCount = COUNT(1)
               FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
               INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
               WHERE pkh.StorerKey = @cStorerKey
                  AND pkh.PickHeaderKey = @cPickSlipNo
                  --AND pkd.ID = @cDropID
                  AND ucc.Status = '3'
                  AND ISNULL(ucc.Userdefined08, '') = '1'

               IF @nRowCount = 0
               BEGIN
                  -- Prepare LOC screen var
                  SET @cOutField01 = @cPickSlipNo
                  SET @cOutField02 = '' --PickZone
                  SET @cOutField03 = '' --DropID

                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- PickZone

                  -- Enable field
                  SET @cFieldAttr07 = '' -- QTY
                  
                  SET @nAfterScn = 5291
                  SET @nAfterStep = 2

                  GOTO Quit
               END
               ELSE
               BEGIN
                  SET @cOutField01 = ''
                  SET @nAfterScn = 6410 --Close Pallet?
                  SET @nAfterStep = 99
               END
            END
            GOTO Quit
         END
         ELSE IF @nCurrentScn = 6388 -- UCCNo
         BEGIN
            IF @nInputKey = 1
            BEGIN
               SET @cUCCNo = TRIM(@cInField05)

               IF @cUCCNo = ''
               BEGIN
                  SET @nErrNo = 218903
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Needed
                  GOTO Quit
               END

               EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT
                  ,@cUCCNo -- UCC
                  ,@cStorerKey
                  ,'13'    -- 1=Received, 3=Alloc, 4=Replen

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 218904
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
                  GOTO Quit
               END

               SET @nRowCount = 0

               SELECT 
                  @cUCCStatus    = ucc.Status,
                  @cUCCPicked    = ISNULL(ucc.Userdefined08, ''),
                  @cUCCLoc       = ucc.Loc,
                  @cSKU          = ucc.Sku,
                  @nUCCQTY       = ucc.Qty,
                  @cPickDetailKey = pkd.PickDetailKey
               FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
               INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
               WHERE pkh.StorerKey = @cStorerKey
                  AND pkh.PickHeaderKey = @cPickSlipNo
                  --AND pkd.ID = @cDropID
                  AND pkd.CaseID = @cSSCC
                  AND pkd.DropID = @cUCCNo

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount > 0 --UCC belongs to current SSCC
               BEGIN
                  IF @cUCCStatus = '3' AND @cUCCPicked = '1'
                  BEGIN
                     SET @nErrNo = 218918
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Picked
                     GOTO Quit
                  END

                  IF @cUCCStatus <> '3'
                  BEGIN
                     SET @nErrNo = 218905
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
                     GOTO Quit
                  END
               END
               ELSE
               BEGIN --Swap UCC
                  SELECT TOP 1 
                     @cUCCAllocated = ucc1.UCCNo, 
                     @cID           = ucc1.ID,
                     @cUCCLoc       = ucc1.Loc,
                     @cSKU          = ucc1.Sku,
                     @nUCCQTY       = ucc1.Qty,
                     @cOrderKey     = ISNULL(ucc1.OrderKey, ''),
                     @cOrderLineNumber = ISNULL(ucc1.OrderLineNumber, ''),
                     @cSwapUCCID    = ucc2.Id,
                     @cSwapUCCLot   = ucc2.LOT,
                     @cPickDetailKey = pkd.PickDetailKey
                  FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
                  INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
                  INNER JOIN dbo.UCC ucc1 WITH(NOLOCK) ON ucc1.StorerKey = pkd.StorerKey AND ucc1.UCCNo = pkd.DropID
                  INNER JOIN LOTATTRIBUTE dia1 WITH(NOLOCK) ON ucc1.Lot = dia1.Lot
                  INNER JOIN dbo.UCC ucc2 WITH(NOLOCK) ON ucc1.StorerKey = ucc2.StorerKey AND ucc1.UCCNo <> ucc2.UCCNo AND ucc1.Sku = ucc2.Sku AND ucc1.Qty = ucc2.Qty AND ucc1.Loc = ucc2.Loc
                  INNER JOIN LOTATTRIBUTE dia2 WITH(NOLOCK) ON ucc2.Lot = dia2.Lot
                  WHERE pkh.StorerKey = @cStorerKey
                     AND pkh.PickHeaderKey = @cPickSlipNo
                     --AND pkd.ID = @cDropID
                     AND pkd.CaseID = @cSSCC
                     AND dia1.Lottable01 = dia2.Lottable01
                     AND ucc2.Status = '1'
                     AND ucc2.UCCNo = @cUCCNo
                     AND ucc1.Status = '3'

                  SELECT @nRowCount = @@ROWCOUNT

                  IF @nRowCount = 0 -- the swapped UCC is not valid
                  BEGIN
                     SET @nErrNo = 218906
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
                     GOTO Quit
                  END
               END 

               IF @nTranCount = 0
                  BEGIN TRANSACTION
               ELSE 
                  BEGIN TRANSACTION rdt_957ExtScn02_01

               BEGIN TRY
                  --swap UCC successfully, need update the pkd and UCC
                  IF @cUCCAllocated IS NOT NULL AND @cUCCAllocated <> @cUCCNo
                  BEGIN
                     EXEC [RDT].[rdt_957SwapID01]
                        @nMobile       = @nMobile,
                        @nFunc         = @nFunc,
                        @cLangCode     = @cLangCode,
                        @nStep         = @nStep,
                        @nInputKey     = @nInputKey,
                        @cFacility     = @cFacility,
                        @cStorerKey    = @cStorerKey,
                        @cPickSlipNo   = @cPickSlipNo,
                        @cPickZone     = '',
                        @cLOC          = @cUCCLoc,
                        @cSuggID       = @cID,
                        @cID           = @cSwapUCCID,
                        @cSKU          = @cSKU,
                        @nQTY          = @nUCCQTY,
                        @cLottable01   = '',
                        @cLottable02   = '',
                        @cLottable03   = '',
                        @dLottable04   = NULL,
                        @dLottable05   = NULL,
                        @cLottable06   = '',
                        @cLottable07   = '',
                        @cLottable08   = '',
                        @cLottable09   = '',
                        @cLottable10   = '',
                        @cLottable11   = '',
                        @cLottable12   = '',
                        @dLottable13   = NULL,
                        @dLottable14   = NULL,
                        @dLottable15   = NULL,
                        @nErrNo        = @nErrNo,
                        @cErrMsg       = @cErrMsg

                     IF @nErrNo <> 0
                     BEGIN
                         IF @nTranCount > 0
                           ROLLBACK TRAN rdt_957ExtScn02_01
                        ELSE
                           ROLLBACK TRAN
                           
                        SET @nErrNo = 218920
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SwapUCCFail
                        GOTO Quit
                     END

                     UPDATE dbo.PickDetail WITH(ROWLOCK)
                     SET
                        DropID = @cUCCNo
                     WHERE PickDetailKey = @cPickDetailKey

                     SET @cUDF01 = 'SWAPUCC'
                     SET @cUDF02 = @cSwapUCCID

                     UPDATE dbo.UCC WITH(ROWLOCK)
                     SET Status = '3',
                        Userdefined08 = '1',
                        OrderKey = @cOrderKey,
                        OrderLineNumber = @cOrderLineNumber
                     WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cUCCNo

                     UPDATE dbo.UCC WITH(ROWLOCK)
                     SET Status = '1',
                        OrderKey = '',
                        OrderLineNumber = ''
                     WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cUCCAllocated
                  END

                  IF @cUCCAllocated IS NULL
                  BEGIN
                     ---update UCC
                     UPDATE dbo.UCC WITH(ROWLOCK)
                     SET Userdefined08 = '1'
                     WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cUCCNo
                        AND Status = '3'
                  END
                  
                  UPDATE ord WITH(ROWLOCK)
                  SET ord.Status = '3'
                  FROM ORDERDETAIL ord
                  INNER JOIN dbo.PICKDETAIL pkd WITH(NOLOCK) ON ord.StorerKey = pkd.StorerKey AND ord.OrderKey = pkd.OrderKey AND ord.OrderLineNumber = pkd.OrderLineNumber
                  INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
                  INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
                  WHERE pkh.StorerKey = @cStorerKey
                     AND pkh.PickHeaderKey = @cPickSlipNo
                     --AND pkd.ID = @cDropID
                     AND pkd.CaseID = @cSSCC
                     AND pkd.Status < '5'
                     AND ucc.Status = '5'

                  UPDATE orm WITH(ROWLOCK)
                  SET orm.Status = '3'
                  FROM ORDERS orm
                  INNER JOIN 
                     (SELECT orm1.StorerKey, orm1.OrderKey, COUNT(1) AS totalOrderQty
                     FROM ORDERDETAIL ord1 WITH(NOLOCK)
                     INNER JOIN ORDERS orm1 WITH(NOLOCK) ON ord1.StorerKey = orm1.StorerKey AND ord1.OrderKey = orm1.OrderKey AND orm1.Status = '2'
                     INNER JOIN dbo.PICKDETAIL pkd1 WITH(NOLOCK) ON pkd1.StorerKey = ord1.StorerKey AND pkd1.OrderKey = ord1.OrderKey AND pkd1.OrderLineNumber = ord1.OrderLineNumber
                     INNER JOIN dbo.PICKHEADER pkh1 WITH(NOLOCK) ON pkd1.StorerKey = pkh1.StorerKey AND pkd1.OrderKey = pkh1.OrderKey
                     WHERE pkh1.StorerKey = @cStorerKey
                        AND pkh1.PickHeaderKey = @cPickSlipNo
                     GROUP BY orm1.StorerKey, orm1.OrderKey) AS orders
                     ON orm.StorerKey = orders.StorerKey AND orm.OrderKey = orders.OrderKey
                  LEFT JOIN 
                     (SELECT orm2.StorerKey, orm2.OrderKey, COUNT(1) AS pickedOrderQty
                     FROM ORDERDETAIL ord2 WITH(NOLOCK)
                     INNER JOIN ORDERS orm2 WITH(NOLOCK) ON ord2.StorerKey = orm2.StorerKey AND ord2.OrderKey = orm2.OrderKey AND orm2.Status = '2'
                     INNER JOIN dbo.PICKDETAIL pkd2 WITH(NOLOCK) ON pkd2.StorerKey = ord2.StorerKey AND pkd2.OrderKey = ord2.OrderKey AND pkd2.OrderLineNumber = ord2.OrderLineNumber
                     INNER JOIN dbo.PICKHEADER pkh2 WITH(NOLOCK) ON pkd2.StorerKey = pkh2.StorerKey AND pkd2.OrderKey = pkh2.OrderKey
                     WHERE pkh2.StorerKey = @cStorerKey
                        AND pkh2.PickHeaderKey = @cPickSlipNo
                        AND ord2.Status = '3'
                     GROUP BY orm2.StorerKey, orm2.OrderKey) AS pickedOrders
                     ON orm.StorerKey = pickedOrders.StorerKey AND orm.OrderKey = pickedOrders.OrderKey
                  WHERE orders.totalOrderQty = ISNULL(pickedOrders.pickedOrderQty, -1)
                     AND orm.Status = '2'

                  UPDATE dbo.PICKDETAIL WITH(ROWLOCK)
                  SET Status = @cPickConfirmStatus,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME()
                  WHERE StorerKey = @cStorerKey
                     AND PickDetailKey = @cPickDetailKey
               END TRY
               BEGIN CATCH
                  IF @nTranCount > 0
                     ROLLBACK TRAN rdt_957ExtScn02_01
                  ELSE
                     ROLLBACK TRAN

                  SET @nErrNo = 218909
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdDataFail
                  GOTO Quit
               END CATCH

               DECLARE @cUserName NVARCHAR( 18)
               SET @cUserName = SUSER_SNAME()

               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cLocation     = @cUCCLoc,
                  @cSKU          = @cSKU,
                  @nQTY          = @nUCCQTY,
                  @cRefNo1       = 'CONFIRM',
                  @cPickSlipNo   = @cPickSlipNo,
                  @cPickZone     = @cPickZone, 
                  @cDropID       = @cDropID

               SELECT TOP 1 
                  @cUCCNo     = ucc.UCCNo,
                  @cSKU       = pkd.Sku,
                  @cSKUStyle  = sku.Style, 
                  @cSKUSize   = sku.Size,
                  @cSKUMeasurement = sku.Measurement,
                  @cSuggestLoc  = ucc.Loc
               FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
               INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
               INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID
               INNER JOIN dbo.SKU sku WITH(NOLOCK) ON pkd.StorerKey = sku.StorerKey AND pkd.Sku = sku.Sku
               WHERE pkh.StorerKey = @cStorerKey
                  AND pkh.PickHeaderKey = @cPickSlipNo
                  --AND pkd.ID = @cDropID
                  AND pkd.CaseID = @cSSCC
                  AND ucc.Status = '3'
                  AND ISNULL(ucc.Userdefined08, '') = ''

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0 --NO UCC belongs to current SSCC, go back to SSCC screen
               BEGIN
                  SET @cOutField01 = ''
                  SET @nAfterScn = 6387
                  SET @nAfterStep = 99
                  GOTO Quit
               END
               ELSE
               BEGIN --SSCC is not finished
                  IF @cSuggestUCC = '1'
                  BEGIN
                     SET @cOutField05 = @cUCCNo
                  END
                  ELSE 
                     SET @cOutField05 = ''

                  SET @cOutField01 = @cSuggestLoc
                  SET @cOutField02 = @cSKUStyle
                  SET @cOutField03 = @cSKUSize
                  SET @cOutField04 = @cSKUMeasurement
                  
                  SET @nAfterScn = 6388
                  SET @nAfterStep = 99
                  GOTO Quit
               END
            END
            ELSE IF @nInputKey = 0
            BEGIN
               SET @cOutField01 = ''
               SET @nAfterScn = 6387
               SET @nAfterStep = 99

               GOTO Quit
            END
         END
         ELSE IF @nCurrentScn = 6389 --TOLOC
         BEGIN
            IF @nInputKey = 1
            BEGIN
               SET @cToLoc = @cInField01
               IF @cToLoc = ''
               BEGIN
                  SET @nErrNo = 218911
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLocNeeded
                  GOTO Quit
               END

               -- Check TOLOC valid
               IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND Facility = @cFacility)
               BEGIN
                  SET @nErrNo = 218919
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLOC
                  GOTO Quit
               END

               IF @nTranCount = 0
                  BEGIN TRANSACTION
               ELSE 
                  BEGIN TRANSACTION rdt_957ExtScn02_02

               BEGIN TRY
                  --Create Cursor to loop PickDetail 1 by 1
                  DECLARE C_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT 
                     ucc.UCCNo, ucc.Loc, ucc.Qty, ucc.Sku, ucc.LOT, pkd.PickDetailKey, pkd.ID
                  FROM dbo.PICKDETAIL pkd WITH(NOLOCK)
                  INNER JOIN dbo.PICKHEADER pkh WITH(NOLOCK) ON pkd.StorerKey = pkh.StorerKey AND pkd.OrderKey = pkh.OrderKey
                  INNER JOIN dbo.UCC ucc WITH(NOLOCK) ON ucc.StorerKey = pkd.StorerKey AND ucc.UCCNo = pkd.DropID AND ucc.Sku = pkd.Sku
                  WHERE pkh.StorerKey = @cStorerKey
                     AND pkh.PickHeaderKey = @cPickSlipNo
                     AND pkd.Status = @cPickConfirmStatus
                     --AND pkd.ID = @cDropID

                  OPEN C_UCC
                  FETCH NEXT FROM C_UCC INTO @cUCCNo, @cUCCLoc, @nUCCQTY, @cSKU, @cLOT, @cPickDetailKey, @cToID

                  WHILE (@@FETCH_STATUS <> -1)
                  BEGIN
                     -- Move UCC
                     EXEC RDT.rdt_Move
                        @nMobile     = @nMobile,
                        @cLangCode   = @cLangCode, 
                        @nErrNo      = @nErrNo  OUTPUT,
                        @cErrMsg     = @cErrMsg OUTPUT, 
                        @cSourceType = 'rdt_957ExtScn02', 
                        @cStorerKey  = @cStorerKey,
                        @cFacility   = @cFacility, 
                        @cFromLOC    = @cUCCLOC, 
                        @cToLOC      = @cToLOC, 
                        @cFromID     = @cToID,
                        @cToID       = @cDropID,
                        @cSKU        = @cSKU, 
                        @nQTY        = @nUCCQTY,
                        @nFunc       = @nFunc, 
                        @nQTYAlloc   = 0,
                        @nQTYPick    = @nUCCQTY,
                        @cDropID     = @cUCCNo, 
                        @cFromLOT    = @cLOT 

                     UPDATE dbo.UCC WITH(ROWLOCK)
                     SET Status = '5',
                        Userdefined08 = '',
                        Loc = @cToLoc,
                        ID = @cDropID
                     WHERE StorerKey = @cStorerKey
                        AND UCCNo = @cUCCNo

                     UPDATE dbo.PICKDETAIL WITH(ROWLOCK)
                     SET Loc = @cToLoc,
                        ID = @cDropID
                     WHERE PickDetailKey = @cPickDetailKey

                     IF @nErrNo <> 0
                     BEGIN
                        CLOSE C_UCC
                        DEALLOCATE C_UCC

                        SET @nErrNo = 218912
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoveUCCFail

                        IF @nTranCount > 0
                           ROLLBACK TRAN rdt_957ExtScn02_02
                        ELSE
                           ROLLBACK TRAN

                        GOTO Quit
                     END

                     -- Fetch Next From Cursor
                     FETCH NEXT FROM C_UCC INTO @cUCCNo, @cUCCLoc, @nUCCQTY, @cSKU, @cLOT, @cPickDetailKey, @cToID
                  END -- WHILE 1=1
                  CLOSE C_UCC
                  DEALLOCATE C_UCC
               END TRY
               BEGIN CATCH
                  SET @nErrNo = 218915
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropPalletFail

                  IF @nTranCount > 0
                     ROLLBACK TRAN rdt_957ExtScn02_02
                  ELSE
                     ROLLBACK TRAN

                  GOTO Quit
               END CATCH

               SET @cOutField01 = @cPickSlipNo
               SET @cOutField02 = '' --PickZone
               SET @cOutField03 = '' --DropID

               SET @nAfterScn = 5291  --Drop ID
               SET @nAfterStep = 2
            END
            ELSE IF @nInputKey = 0
            BEGIN
               SET @nAfterScn = 6387
               SET @nAfterStep = 99
            END
            GOTO Quit
         END
         ELSE IF @nCurrentScn = 6410 --Close Pallet?
         BEGIN
            IF @nInputKey = 1
            BEGIN
               SET @cOption = TRIM(@cInField01)

               IF @cOption = ''
               BEGIN
                  SET @nErrNo = 218916
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionNeeded
                  GOTO Quit
               END

               IF @cOption NOT IN ('1', '9')
               BEGIN
                  SET @nErrNo = 218917
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidOption
                  GOTO Quit
               END 

               IF @cOption = '1'
               BEGIN
                  SET @nAfterScn = 6389
                  SET @nAfterStep = 99
               END
               ELSE
               BEGIN
                  SET @nAfterScn = 6387
                  SET @nAfterStep = 99
               END
            END
            ELSE IF @nInputKey = 0
            BEGIN
               SET @nAfterScn = 6387
               SET @nAfterStep = 99
            END
            GOTO Quit
         END
      END
   END
Fail:
   
Quit:
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      C_String1 = @cSSCC,
      C_String2 = @cSuggestUCC
   WHERE Mobile = @nMobile

   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRANSACTION
END; 

SET QUOTED_IDENTIFIER OFF 

GO