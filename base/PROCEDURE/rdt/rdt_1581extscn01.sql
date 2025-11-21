SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1581ExtScn01                                    */  
/*                                                                      */  
/* Purpose:       For Defy                                              */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-07-24 1.0  JHU151     FCR-549. Created                          */  
/************************************************************************/  
  
CREATE   PROC  [RDT].[rdt_1581ExtScn01] (
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
         @nToIDQTY            INT

   SET @nAfterScn = @nScn
   SET @nAfterStep = @nStep

   IF @nFunc = 1581
   BEGIN
      IF @nAction = 3
      BEGIN
         IF @nStep = 5
         BEGIN         
            IF @nInputKey = 1
            BEGIN
               DECLARE @cLottable01Local    NVARCHAR(20)
               DECLARE @cLottable02Local    NVARCHAR(20)

               SELECT @cLottable02Local = Value FROM @tExtScnData WHERE Variable = '@cTempLottable02'

               SELECT @cLottable01Local = ISNULL(UDF01,'')
               FROM CodeLkUp WITH(NOLOCK)
               WHERE Code = @nFunc 
               AND storerkey = @cStorerKey 
               AND ListName = 'LOT1_2LINK' 
               AND UDF02 = @cLottable02Local

               SET @cUDF01 = @cLottable01Local
               GOTO QUIT
            END
         END
      END

      IF @nAction = 0
      BEGIN
         IF @nStep = 9
         BEGIN
            IF @nInputKey = 1
            BEGIN
               DECLARE @cSerialNo           NVARCHAR(50),
                        @cAddRCPTValidtn     NVARCHAR(10)

               SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddSerialValidtn', @cStorerKey)
               SET @cSerialNo = @cInField04

               IF @cAddRCPTValidtn = '1'
               BEGIN
                  SELECT
                     @cSku = V_SKU,
                     @cSerialNo = V_MAX
                  FROM   RDTMOBREC (NOLOCK)
                  WHERE  Mobile = @nMobile

                  IF CHARINDEX(@cSku,@cSerialNo,1) <> 1
                     OR LEN(@cSerialNo) <= LEN(@cSku)
                     OR LEN(@cSku) NOT IN (6,10)
                  BEGIN
                     SET @nAfterScn = 6413
                     SET @nAfterStep = 98
                     SET @cOutField01 = @cSerialNo
                     SET @cOutField02 = ''
                  END
               END
            END
         END
      END

      IF @nStep = 98
      BEGIN
         -- Getting Mobile information
         SELECT
            @cFacility   = Facility,
            @cUserName   = UserName,
            @cPrinter    = Printer,
            @cReceiptKey = V_ReceiptKey,
            @cPOKey      = V_POKey,
            @cLOC        = V_LOC,
            @cTOID       = V_ID,
            @cSKU        = V_SKU,
            @cSKUDesc    = V_SKUDescr,
            @nQTY        = V_QTY,
            @nFromScn    = V_FromScn,
            @cBarcode    = V_Barcode,
            @nToIDQTY           = V_Integer2,
            @nBeforeReceivedQty = V_Integer3,
            @nQtyExpected       = V_Integer4,
            @nNOPOFlag          = V_Integer6,
            @cPrevBarcode            = V_String6,
            @cDefaultPieceRecvQTY    = V_String8,
            @cUOM                    = V_String9,	  
            @cSKULabel               = V_String31,		   
            @cSKUValidated           = V_String37
         FROM rdt.rdtMobRec (NOLOCK)
         WHERE  Mobile = @nMobile

         -- SERIAL CONFIRM
         IF @nScn = 6413
         BEGIN
         
            IF @nInputKey = 1
            BEGIN
               DECLARE @cOption    NVARCHAR(1)

               SET @cOption = @cInField02   
               -- Check invalid option YES/NO
               IF @cOption NOT IN ('1', '9')
               BEGIN
                  SET @nErrNo = 64296
                  SET @cErrMsg = rdt.rdtgetmessage( 64296, @cLangCode, 'DSP') --Invalid option
                  GOTO Quit
               END
            
               -- capture sn
               SET @nAfterScn = 4831
               SET @nAfterStep = 9
               SET @cUDF01 = @cOption
               SET @cOutField01 = @cSKU
               SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
               SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
               SET @cOutField04 = '' -- SerialNo
               
               IF @cOption = 9
               BEGIN
                  GOTO Quit                  
               END

               -- Update SKU setting
               EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'UPDATE', 'ASN', @cReceiptKey,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
                  @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
                  @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn,
                  @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '2'

               IF @nErrNo = -1
               BEGIN
                  -- Get QTY statistic
                  SELECT
                  @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
                  @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
                  FROM dbo.ReceiptDetail WITH (NOLOCK)
                  WHERE Receiptkey = @cReceiptKey
                  AND   SKU        = @cSKU
                  AND   ToID       = @cToID
                  AND   ToLoc      = @cLoc
                  AND   Storerkey  = @cStorerKey

                  SET @cSKUValidated = '0'

                  -- Prepare next screen variable
                  SET @cPrevBarcode = ''
                  SET @cOutField01 = @cToID
                  SET @cOutField02 = '' -- sku
                  SET @cOutField03 = '' -- sku desc1
                  SET @cOutField04 = '' -- sku desc2
                  SET @cOutField05 = @cDefaultPieceRecvQTY
                  SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
                  SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10)) -- To ID QTY
                  SET @cOutField11 = @cSKU -- last SKU
                  SET @cOutField12 = @cUOM -- last UOM
                  SET @cOutField15 = '' -- @cExtendedInfo

                  SET @cBarcode = ''

                  SET @cInField05 = @cDefaultPieceRecvQTY
                  EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

                  -- Go to SKU QTY screen		

                  SET @nAfterScn = @nFromScn
                  SET @nAfterStep = 5

                  GOTO Quit
               END

               IF @nErrNo <> 0 -- (james31)
                  GOTO Quit

               DECLARE @nRDQTY INT
               IF @nBulkSNO > 0
                  SET @nRDQTY = @nBulkSNOQTY
               ELSE IF @cSerialNo <> ''
                  SET @nRDQTY = @nSerialQTY
               ELSE
                  SET @nRDQTY = @nQTY

               -- Receive
               EXEC rdt.rdt_PieceReceiving_Confirm
                  @nFunc      = @nFunc,
                  @nMobile       = @nMobile,
                  @cLangCode     = @cLangCode,
                  @nErrNo        = @nErrNo OUTPUT,
                  @cErrMsg       = @cErrMsg OUTPUT,
                  @cStorerKey    = @cStorerKey,
                  @cFacility     = @cFacility,
                  @cReceiptKey   = @cReceiptKey,
                  @cPOKey        = @cPoKey,  -- (ChewKP01)
                  @cToLOC        = @cLOC,
                  @cToID         = @cTOID,
                  @cSKUCode      = @cSKU,
                  @cSKUUOM       = @cUOM,
                  @nSKUQTY       = @nRDQTY,
                  @cUCC          = '',
                  @cUCCSKU       = '',
                  @nUCCQTY       = '',
                  @cCreateUCC    = '',
                  @cLottable01   = @cLottable01,
                  @cLottable02   = @cLottable02,
                  @cLottable03   = @cLottable03,
                  @dLottable04   = @dLottable04,
                  @dLottable05   = NULL,
                  @nNOPOFlag     = @nNOPOFlag,
                  @cConditionCode = 'OK',
                  @cSubreasonCode = '',
                  @cReceiptLineNumber = @cReceiptLineNumber OUTPUT,
                  @cSerialNo      = @cSerialNo,
                  @nSerialQTY     = @nSerialQTY,
                  @nBulkSNO       = @nBulkSNO,
                  @nBulkSNOQTY    = @nBulkSNOQTY

               IF @nErrno <> 0
                  GOTO Quit
               ELSE
                  SET @cSKUValidated = '0'

               -- (james23)
               SELECT @cBUSR1 = BUSR1
               FROM dbo.SKU WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   Sku = @cSKU

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '2', -- Receiving
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cLocation     = @cLOC,
                  @cID           = @cTOID,
                  @cSKU          = @cSku,
                  @cUOM          = @cUOM,
                  @nQTY          = @nRDQTY,
                  @cReceiptKey   = @cReceiptKey,
                  @cPOKey        = @cPOKey,
                  @cLottable01   = @cLottable01,
                  @cLottable02   = @cLottable02,
                  @cLottable03   = @cLottable03,
                  @dLottable04   = @dLottable04,
                  @nStep         = @nStep,
                  @cSerialNo     = @cSerialNo,
                  @cRefNo3       = @cBUSR1,
                  @cRefNo2       = @cReceiptLineNumber

               IF @nMoreSNO = 1
                  GOTO Quit

               -- Get ToIDQTY
               SELECT @nToIDQTY = ISNULL( SUM( BeforeReceivedQty), 0)
               FROM   dbo.Receiptdetail WITH (NOLOCK)
               WHERE  receiptkey = @cReceiptkey
               AND    toloc = @cLOC
               AND    toid = @cTOID
               AND    Storerkey = @cStorerKey

               -- Get QTY statistic
               SELECT
                  @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
                  @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE Receiptkey = @cReceiptKey
               --AND   POKey      = @cPOKey
               AND   SKU        = @cSKU
               AND   ToID       = @cToID
               AND   ToLoc      = @cLoc
               AND   Storerkey  = @cStorerKey

               -- Print SKU label
               IF @cSKULabel = '1'
                  EXEC rdt.rdt_PieceReceiving_SKULabel @nFunc, @nMobile, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cPrinter,
                  @cReceiptKey,
                  @cLOC,
                  @cToID,
                  @cSKU,
                  @nQTY,
                  @cLottable01,
                  @cLottable02,
                  @cLottable03,
                  @dLottable04,
                  @dLottable05,
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               -- Prepare SKU fields
               SET @cOutField01 = @cToID
               SET @cOutField02 = '' -- SKU
               SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
               SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
               SET @cOutField05 = @cDefaultPieceRecvQTY
               SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
               SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))
               SET @cOutField11 = @cSKU -- last SKU
               SET @cOutField12 = @cUOM -- last UOM
               SET @cOutField15 = '' -- @cExtendedInfo

               SET @cBarcode = ''

               SET @cInField05 = @cDefaultPieceRecvQTY
               EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

               -- Go to SKU QTY screen
               SET @nAfterScn = @nFromScn
               SET @nAfterStep = 5
            END
         END
      END
   END


Quit:
   IF @nStep = 98
   BEGIN
      IF @nScn = 6413
	  BEGIN
		
		
		IF @nInputKey = 1 AND @cOption IN (1,9)
		BEGIN
		   SET @cUDF01 = @cBarcode
		   SET @cUDF02 = @cPrevBarcode
		   SET @cUDF03 = @cSKUValidated
		   SET @cUDF04 = @nBeforeReceivedQty
		   SET @cUDF05 = @nQtyExpected
		   SET @cUDF06 = @nToIDQTY
		   SET @cUDF07 = '' -- V_MAX
		   

		END
	  END 
   END
END


GO