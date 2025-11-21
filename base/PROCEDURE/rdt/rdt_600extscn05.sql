SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_600ExtScn05                                     */  
/* CUSTOMER :   Unilever                                                */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-10-11 1.0  LJQ006     FCR-911  Created                          */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_600ExtScn05] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep INT,           
   @nScn  INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @tExtScnData   VariableTable READONLY,

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
   @nAction      INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT,
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
      @cRcptUoMConf         NVARCHAR(50),
      @cRcptUoM             NVARCHAR(1),
      @cReceiptKey          NVARCHAR(10),
      @cSKU                 NVARCHAR(20),
      @cRcptUomDesc         NVARCHAR(10),
      @nUOM_Div             INT,
      @cPackKey             NVARCHAR(10),
      @cMUOM_Desc           NVARCHAR(10),
      @cOption              NVARCHAR(1)
      
   DECLARE @tTmpPackUom TABLE (
      UomDesc NVARCHAR(10),
      UomDiv  INT,
      UomNo   NVARCHAR(1)
   );
      
   SELECT
   @nStep            = Step
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @cRcptUoMConf = rdt.rdtGetConfig(@nFunc,'RcptUoM',@cStorerKey)
   SELECT @cOption = Value FROM @tExtScnData WHERE Variable = '@cOption'

   SET @cUDF06 = @cRcptUomConf

   IF @nFunc = 600
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF ( @nStep IN (4, 5) OR (@nStep = 8 AND @cOption = 1) ) AND @nAfterScn = 4035
         BEGIN
            IF @nErrNo <> 0
            BEGIN
               GOTO Quit
            END
            
            IF @cRcptUomConf = 1
            BEGIN
               SELECT @cReceiptKey = Value FROM @tExtScnData WHERE Variable = '@cReceiptKey'
               SELECT @cSKU = Value FROM @tExtScnData WHERE Variable = '@cSKU'
               SELECT @cMUOM_Desc = Value FROM @tExtScnData WHERE Variable = '@cMUOM_Desc'
               SELECT @cPackKey = PackKey FROM dbo.SKU WITH(NOLOCK) WHERE SKU = @cSKU AND StorerKey = @cStorerKey
               -- insert all pack uoms into a table variable
               DELETE FROM @tTmpPackUom;
               INSERT INTO @tTmpPackUom (UomDesc, UomDiv, UomNo)
               (
                  SELECT PackUOM1, CaseCNT,'2' FROM dbo.PACK WITH(NOLOCK) WHERE PackKey = @cPackKey
                  UNION ALL
                  SELECT PackUOM2, InnerPack, '3' FROM dbo.PACK WITH(NOLOCK) WHERE PackKey = @cPackKey
                  UNION ALL
                  SELECT PackUOM3, QTY, '6' FROM dbo.PACK WITH(NOLOCK) WHERE PackKey = @cPackKey
                  UNION ALL
                  SELECT PackUOM4, Pallet, '1' FROM dbo.PACK WITH(NOLOCK) WHERE PackKey = @cPackKey
                  UNION ALL
                  SELECT PackUOM8, OtherUnit1, '4' FROM dbo.PACK WITH(NOLOCK) WHERE PackKey = @cPackKey
                  UNION ALL
                  SELECT PackUOM9, OtherUnit2, '5' FROM dbo.PACK WITH(NOLOCK) WHERE PackKey = @cPackKey
               )
               SELECT TOP 1 @cRcptUomDesc = UOM 
               FROM dbo.RECEIPTDETAIL WITH(NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
                  AND Sku = @cSKU
                  AND StorerKey = @cStorerKey
               ORDER BY ReceiptLineNumber ASC
               -- match the rcpt uom with pack uom and get the uom no
               SELECT TOP 1 
                  @cRcptUoM = UomNo,
                  @nUOM_Div = UomDiv
               FROM @tTmpPackUom 
               WHERE UomDesc = @cRcptUomDesc
                  AND UomDesc IS NOT NULL
               SET @cUDF04 = @cRcptUoM
               SET @cUDF05 = @nUOM_Div
               SET @cUDF07 = @cRcptUomDesc
               SET @cOutField05 = '1:' + CASE WHEN @nUOM_Div > 99999 THEN '*' ELSE CAST( @nUOM_Div AS NCHAR( 5)) END
               SET @cOutField06 = rdt.rdtRightAlign( @cRcptUomDesc, 5)
               -- when pd uom equals to master uom, only show one input box
               IF (@cRcptUomDesc = @cMUOM_Desc)
               BEGIN
                  SET @cOutField06 = ''
                  SET @cFieldAttr08 = 'O'
               END
               ELSE
               BEGIN
                  SET @cFieldAttr08 = ''
               END
               IF @cFieldAttr08 = ''
               BEGIN
                  EXEC rdt.rdtSetFocusField @nMobile, 8 -- PQTY
               END
               -- IF @cFieldAttr08 = 'O'
               -- BEGIN
               --    UPDATE RDT.RDTXML_Root WITH (ROWLOCK) SET Focus = NULL
               -- END
               SET @nAfterScn = 4035 -- GOTO Qty Scn
               SET @nAfterStep = 6 -- GOTO Qty Step
            END
         END
      END
   END
Quit:
END

GO