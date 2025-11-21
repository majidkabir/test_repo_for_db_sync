SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_839ExtScn02                                     */  
/*                                                                      */  
/* Purpose:       For Defy                                              */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-08-14 1.0  Dennis     FCR-540. Created                          */  
/************************************************************************/  
  
CREATE   PROC  [RDT].[rdt_839ExtScn02] (
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
   @nAction          INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
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
   -- Screen constant
   DECLARE
      @nStep_PickSlipNo       INT,  @nScn_PickSlipNo     INT,
      @nStep_PickZone         INT,  @nScn_PickZone       INT,
      @nStep_SKUQTY           INT,  @nScn_SKUQTY         INT,
      @nStep_NoMoreTask       INT,  @nScn_NoMoreTask     INT,
      @nStep_ShortPick        INT,  @nScn_ShortPick      INT,
      @nStep_SkipLOC          INT,  @nScn_SkipLOC        INT,
      @nStep_ConfirmLOC       INT,  @nScn_ConfirmLOC     INT,
      @nStep_AbortPick        INT,  @nScn_AbortPick      INT,
      @nStep_VerifyID         INT,  @nScn_VerifyID       INT,
      @nStep_MultiSKU         INT,  @nScn_MultiSKU       INT,
      @nStep_DataCapture      INT,  @nScn_DataCapture    INT,
      @nStep_SerialNo         INT,  @nScn_SerialNo       INT
      
   SELECT
      @nStep_PickSlipNo       = 1,  @nScn_PickSlipNo     = 4640,
      @nStep_PickZone         = 2,  @nScn_PickZone       = 4641,
      @nStep_SKUQTY           = 3,  @nScn_SKUQTY         = 4642,
      @nStep_NoMoreTask       = 4,  @nScn_NoMoreTask     = 4643,
      @nStep_ShortPick        = 5,  @nScn_ShortPick      = 4644,
      @nStep_SkipLOC          = 6,  @nScn_SkipLOC        = 4645,
      @nStep_ConfirmLOC       = 7,  @nScn_ConfirmLOC     = 4646,
      @nStep_AbortPick        = 8,  @nScn_AbortPick      = 4647,
      @nStep_VerifyID         = 9,  @nScn_VerifyID       = 4648,
      @nStep_MultiSKU         = 10, @nScn_MultiSKU       = 3570,
      @nStep_DataCapture      = 11, @nScn_DataCapture    = 4649,
      @nStep_SerialNo         = 12, @nScn_SerialNo       = 4830
   DECLARE 
         @cSku                NVARCHAR(30),
         @cReceiptKey         NVARCHAR(10),
         @cSkuDesc            NVARCHAR(50),
         @cLOC                NVARCHAR(20),
         @cTOID               NVARCHAR(18),		   
         @cUOM                NVARCHAR(10),
         @cPOKey              NVARCHAR(10),
         @cBUSR1              NVARCHAR(30),
         @cUserName           NVARCHAR(18),
         @cSKULabel           NVARCHAR(1),
         @cPrinter            NVARCHAR(10),
         @cReceiptLineNumber      NVARCHAR( 5),
         @cDefaultPieceRecvQTY    NVARCHAR(5),
         @nSerialQTY          INT,
         @nMoreSNO            INT,
         @nBulkSNO            INT,
         @nBulkSNOQTY         INT,
         @nFromScn            INT,
         @nNOPOFlag           INT,
         @nQTY                INT

   DECLARE 
         @cBarcode            NVARCHAR( MAX),
         @cPrevBarcode        NVARCHAR(30),
         @cSKUValidated       NVARCHAR(2),
         @nBeforeReceivedQty  INT,
         @nQtyExpected        INT,
         @nToIDQTY            INT,
         @cPickSlipNo         NVARCHAR( 10),
         @cOption             NVARCHAR( 10),
         @cToLOC              NVARCHAR(50),
         @cMoveQTYPick        NVARCHAR( 1),
         @cPickConfirmStatus  NVARCHAR( 1),
         @cDropID             NVARCHAR( 20),
         @cSourceLoc          NVARCHAR( 10),
         @cSourceID           NVARCHAR( 18),
         @cPickedQty          INT,
         @nTranCount          INT

   SELECT @cOption = Value FROM @tExtScnData WHERE Variable = '@cOption'

   SET @cMoveQTYPick = rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', @cStorerKey)
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   -- Check move picked, but not pick confirm
   IF @cMoveQTYPick = '1' AND @cPickConfirmStatus < '5'
   BEGIN
      SET @nErrNo = 201802
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IncorrectSetup
      GOTO Quit
   END

   SELECT @nStep = Step,
         @nScn = Scn,
         @cDropID = V_String4,
         @cPickSlipNo = V_PickSlipNo
   FROM RDT.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 839
   BEGIN
      IF @nAction = 0
      BEGIN
         IF ISNULL(@nStep, 0) > 0 AND @nAfterStep = 1
         BEGIN
            IF @nInputKey = 1
            BEGIN
               SELECT TOP 1 @cToLOC = ISNULL(OI.OrderInfo10, '')
               FROM OrderInfo OI WITH (NOLOCK)
               INNER JOIN PICKHEADER P WITH (NOLOCK) ON P.OrderKey= OI.OrderKey
               WHERE P.PickHeaderKey = @cPickSlipNo AND P.StorerKey = @cStorerKey

               IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                           WHERE Facility = @cFacility
                           AND Loc = @cToLOC )
                  SET @cOutField01 = @cToLOC
               ELSE
                  SET @cOutField01 = ''
               SET @cOutField02 = ''

               SET @nAfterScn = 6417
               SET @nAfterStep = 99
               GOTO Quit
            END
         END
         IF @nStep = 5
         BEGIN
            IF @nInputKey = 1
            BEGIN
               IF @cOption = '3'
               BEGIN
                  SELECT @cToLOC = ISNULL(OI.OrderInfo10, '')
                  FROM OrderInfo OI WITH (NOLOCK)
                  INNER JOIN PICKHEADER P WITH (NOLOCK) ON P.OrderKey= OI.OrderKey
                  WHERE P.PickHeaderKey = @cPickSlipNo AND P.StorerKey = @cStorerKey

                  IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                              WHERE Facility = @cFacility
                              AND Loc = @cToLOC )
                     SET @cOutField01 = @cToLOC
                  ELSE
                     SET @cOutField01 = ''
                  SET @cOutField02 = ''
                  
                  SET @nAfterScn = 6417
                  SET @nAfterStep = 99
                  GOTO Quit
               END
            END
         END
      END
      IF @nAction = 1
      BEGIN
         IF @nStep = 99
         BEGIN
            IF @nScn = 6417
            BEGIN
               IF @nInputKey = 1
               BEGIN
                  SET @cToLOC = @cInField02

                  DECLARE
                     @cMODIFYTOLOC     NVARCHAR(10),
                     @cOrderKey        NVARCHAR(10)

                  IF @cToLOC IS NULL OR TRIM(@cToLOC) = ''
                  BEGIN
                     SET @nErrNo = 221306
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToLocNeeded
                     GOTO Quit
                  END

                  IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                            WHERE Facility = @cFacility
                             AND Loc = @cToLOC )
                  BEGIN
                     SET @nErrNo = 221307
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ToLoc
                     GOTO Quit
                  END

                  SET @cMODIFYTOLOC = rdt.RDTGetConfig( @nFunc, 'MODIFYTOLOC', @cStorerKey)

                  IF ISNULL(@cOutField01,'') <> '' AND @cToLOC <> @cOutField01 AND @cMODIFYTOLOC <> '1'
                  BEGIN
                     SET @nErrNo = 221301
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff TO LOC
                     GOTO Quit
                  END

                  DECLARE @curPKD CURSOR
                  SET @curPKD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT 
                        OrderKey, Loc, ID, Qty, Sku
                     FROM PICKDETAIL PKD WITH(NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND DropID = @cDropID
                        AND Status = @cPickConfirmStatus

                  SET @nTranCount = @@TRANCOUNT
                  IF @nTranCount = 0 
                     BEGIN TRANSACTION
                  ELSE
                     SAVE TRANSACTION rdt_839ExtScn02_01

                  BEGIN TRY
                     UPDATE OI
                     SET OrderInfo10 = @cToLOC
                     FROM OrderInfo OI WITH(ROWLOCK)
                     INNER JOIN PICKHEADER PKH WITH (NOLOCK) ON OI.OrderKey = PKH.OrderKey
                     WHERE PKH.PickHeaderKey = @cPickSlipNo 
                        AND PKH.StorerKey = @cStorerKey

                     OPEN @curPKD
                     FETCH NEXT FROM @curPKD INTO @cOrderKey, @cSourceLoc, @cSourceID, @cPickedQty, @cSku
                     WHILE @@FETCH_STATUS = 0
                     BEGIN

                        -- Move by SKU
                        EXECUTE rdt.rdt_Move
                           @nMobile        = @nMobile,
                           @cLangCode      = @cLangCode,
                           @nErrNo         = @nErrNo  OUTPUT,
                           @cErrMsg        = @cErrMsg OUTPUT,
                           @cSourceType    = 'rdt_839ExtScn02',
                           @cStorerKey     = @cStorerKey,
                           @cFacility      = @cFacility,
                           @cFromLOC       = @cSourceLoc,
                           @cToLOC         = @cToLOC,
                           @cFromID        = @cSourceID,
                           @cSKU           = @cSku,
                           @cToID          = @cDropID,
                           @cOrderKey      = @cOrderKey,
                           @nQTY           = @cPickedQty,
                           @nQTYPick       = @cPickedQty,
                           @nFunc          = @nFunc
                        
                        IF @nErrNo <> 0
                        BEGIN
                           IF @nTranCount = 0
                           BEGIN
                              ROLLBACK TRANSACTION
                           END
                           ELSE
                           BEGIN
                              IF XACT_STATE() <> -1
                              BEGIN
                                 ROLLBACK TRANSACTION rdt_839ExtScn02_01
                              END
                           END
                           
                           SET @nErrNo = 221304
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MoveItemFail
                           GOTO Quit
                        END

                     FETCH NEXT FROM @curPKD INTO @cOrderKey, @cSourceLoc, @cSourceID, @cPickedQty, @cSku
                     END
                     CLOSE @curPKD
                     DEALLOCATE @curPKD

                     WHILE @@TRANCOUNT > @nTranCount 
                        COMMIT TRANSACTION
                  END TRY
                  BEGIN CATCH
                     IF CURSOR_STATUS('LOCAL','@curPKD') IN (0 , 1)
                     BEGIN
                        CLOSE @curPKD
                        DEALLOCATE @curPKD
                     END

                     IF @nTranCount = 0
                     BEGIN
                        ROLLBACK TRANSACTION
                     END
                     ELSE
                     BEGIN
                        IF XACT_STATE() <> -1
                        BEGIN
                           ROLLBACK TRANSACTION rdt_839ExtScn02_01
                        END
                     END

                     SET @nErrNo = 221304
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MoveItemFail
                     GOTO Quit
                  END CATCH
                  GOTO Quit
               END
               ELSE IF @nInputKey = 0
               BEGIN
                  SET @nErrNo = 221302
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CannotReturn
                  GOTO Quit
               END
            END
         END
      END
   END
   GOTO Quit

Quit:
END


GO