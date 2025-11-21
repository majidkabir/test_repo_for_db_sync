SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_600ExtScn02                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-06-26 1.0  Dennis     FCR-396. Created                          */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_600ExtScn02] (
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
      @nRowCount                 INT,
      @cExtendedUpdateSP         NVARCHAR( 20),
      @cExtendedValidateSP       NVARCHAR( 20),
      @cExtendedInfoSP           NVARCHAR( 20),

      @cSortTopLane              NVARCHAR( 30), 
      @cRefNo                    NVARCHAR( 20),
      @cPickSlipNo               NVARCHAR( 10),
      @cLoadKey                  NVARCHAR( 10),
      @cOrderKey                 NVARCHAR( 10),
      @cID                       NVARCHAR( 18),
      @cOption                   NVARCHAR( 1),
      @cInputKey                 NVARCHAR( 1),
      @cSKU                      NVARCHAR( 20),
      @cMUOM_Desc                NCHAR( 5),
      @nUOM_Div                  INT,
      @cTaskDetailKey            NVARCHAR( 20),
      @nQTY                      INT,
      @cPUOM                     NVARCHAR( 1),
      @cPGOption                 NVARCHAR( 1),
      @cPalletKey                NVARCHAR( 20),
      @cLane                     NVARCHAR( 30),
      @cStatus                   NVARCHAR( 1),
      @cTrackNo                  NVARCHAR( 40),  
      @nCnt                      INT,
      @nSumPick                  INT,
      @nSumPack                  INT,
      @nTranCount                INT,
      @bReturnCode               INT,
      @cMBOLKey                  NVARCHAR( 10), 
      @cPGDesc                   NVARCHAR( 50),
      @cPalletCloseStatus        NVARCHAR( 10), 
      @ctemp_OutField15          NVARCHAR( 60), 
      @cScanPalletToLane         NVARCHAR( 1)

   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT @cSKU = Value FROM @tExtScnData WHERE Variable = '@cSKU'
   SELECT @cID = Value FROM @tExtScnData WHERE Variable = '@cID'
   SELECT @cUDF01 = Value FROM @tExtScnData WHERE Variable = '@cPUOM_Desc'
   SELECT @cUDF02 = CONCAT(Value,'') FROM @tExtScnData WHERE Variable = '@nPUOM_Div'
   SELECT @ctemp_OutField15 = Value FROM @tExtScnData WHERE Variable = '@ctemp_OutField15'

   IF @nFunc = 600
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nStep = 4 AND @nAfterScn = 4035-- SKU Screen
         BEGIN
            GOTO AcceptDecimal
         END
         IF @nStep = 5 AND @nAfterScn = 4035-- Lottable Screen
         BEGIN
            GOTO AcceptDecimal
         END
      END
   END

   GOTO Quit
AcceptDecimal:
BEGIN
   -- Get SKU default UOM
   DECLARE @cSKUDefaultUOM NVARCHAR( 10)
   SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorerKey)
   IF @cSKUDefaultUOM = '0'
      SET @cSKUDefaultUOM = ''
	  UPDATE RDT.RDTMOBREC SET V_String47 = @cSKUDefaultUOM WHERE Mobile=@nMobile
   -- Check SKU default UOM in pack key
   IF @cSKUDefaultUOM <> ''
   BEGIN
      IF NOT EXISTS (SELECT 1
         FROM dbo.Pack P WITH (NOLOCK)
         INNER JOIN dbo.Sku S WITH (NOLOCK) ON (S.PackKey = P.PackKey)
         WHERE SKU = @cSKU 
            AND  S.StorerKey = @cStorerKey
            AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
      BEGIN
         SET @nErrNo = 64284
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INV SKUDEFUOM
         GOTO Fail_Exit
      END
      SET @cUDF01 = @cSKUDefaultUOM --UOM

      -- Get UOM divider
      SET @nUOM_Div = 0
      SELECT @nUOM_Div =
      CASE
            WHEN @cSKUDefaultUOM = PackUOM1 THEN P.CaseCnt
            WHEN @cSKUDefaultUOM = PackUOM2 THEN P.InnerPack
            WHEN @cSKUDefaultUOM = PackUOM3 THEN P.QTY
            WHEN @cSKUDefaultUOM = PackUOM4 THEN P.Pallet
            WHEN @cSKUDefaultUOM = PackUOM5 THEN P.Cube
            WHEN @cSKUDefaultUOM = PackUOM6 THEN P.GrossWgt
            WHEN @cSKUDefaultUOM = PackUOM7 THEN P.NetWgt
            WHEN @cSKUDefaultUOM = PackUOM8 THEN P.OtherUnit1
            WHEN @cSKUDefaultUOM = PackUOM9 THEN P.OtherUnit2
         END,
         @cPUOM = 
         CASE
            WHEN @cSKUDefaultUOM = PackUOM1 THEN '2'
            WHEN @cSKUDefaultUOM = PackUOM2 THEN '3'
            WHEN @cSKUDefaultUOM = PackUOM3 THEN '6'
            WHEN @cSKUDefaultUOM = PackUOM4 THEN '1'
            WHEN @cSKUDefaultUOM = PackUOM5 THEN '7'
            WHEN @cSKUDefaultUOM = PackUOM6 THEN '8'
            WHEN @cSKUDefaultUOM = PackUOM7 THEN '9'
            WHEN @cSKUDefaultUOM = PackUOM8 THEN '4'
            WHEN @cSKUDefaultUOM = PackUOM9 THEN '5'
         END
      FROM dbo.Pack P WITH (NOLOCK)
      INNER JOIN dbo.Sku S WITH (NOLOCK) ON (S.PackKey = P.PackKey)
      WHERE SKU = @cSKU 
      AND  S.StorerKey = @cStorerKey

      IF @nUOM_Div = 0
         SET @nUOM_Div = 1

      SET @cUDF02 = CONCAT(@nUOM_Div,'')
      SET @cUDF03 = @cPUOM
      SET @cOutField05 = '1:' + CASE WHEN @nUOM_Div > 99999 THEN '*' ELSE CAST( @nUOM_Div AS NCHAR( 5)) END
      SET @cOutField06 = @cSKUDefaultUOM
      SET @cOutField07 = '' --MUOM DESC
      SET @cOutField09 = '' --MUOM Input
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = 'O'    
      SET @nAfterScn = 4035 -- QTY Screen
      SET @nAfterStep = 6
   END
   GOTO Quit
END
Fail_Exit:
BEGIN
   IF @nStep = 4
      GOTO GOTO_SCN_SKU
   ELSE IF @nStep = 5
      GOTO GOTO_SCN_LOTTABLES
END
GOTO_SCN_SKU:
BEGIN
   -- Init next screen var
   SET @cOutField01 = @cID
   SET @cOutField02 = ''
   SET @cOutField03 = '' -- SKUDesc1
   SET @cOutField04 = '' -- SKUDesc2
   SET @cOutField05 = ''
   SET @nAfterStep = 4
   SET @nAfterScn = 4033
   GOTO Quit
END
GOTO_SCN_LOTTABLES:
BEGIN
   SET @cOutField15 = @ctemp_OutField15
   SET @nAfterStep = 5
   SET @nAfterScn = 3990
   GOTO Quit
END
Quit:
END

GO