SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_838ExtScn01                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-06-19 1.0  JHU151     FCR-352. Created                          */
/* 2024-10-24 1.1  TLE109     FCR-990. Packing Serial Number Validation */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_838ExtScn01] (
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
      @cPickSlipNo            NVARCHAR( 10),
      @cSKU                   NVARCHAR( 20),
      @cOrdKey                NVARCHAR( 10),
      @cExtOrderKey           NVARCHAR( 50),
      @cJumpType              NVARCHAR( 10),
      @cPackDtlDropID         NVARCHAR( 20),
      @cFromDropID            NVARCHAR( 20),
      @cPrintPackList         NVARCHAR( 1),
      @cDisableQTYField       NVARCHAR( 1),
      @nPickedQTY             INT,
      @nPackedQTY             INT,
      @cSerialNo              NVARCHAR( 30)


   -- SET @nErrNo = 0
   -- SET @cErrMsg = ''

   SELECT @cPickSlipNo = Value FROM @tExtScnData WHERE Variable = '@cPickSlipNo'
   SELECT @cSKU = Value FROM @tExtScnData WHERE Variable = '@cSKU'
   SELECT @cJumpType = Value FROM @tExtScnData WHERE Variable = '@cJumpType'
   
   SELECT
	   @cPackDtlDropID      = V_String9,
	   @cDisableQTYField    = V_String26,
	   @cFromDropID         = V_String20,
      @cSerialNo           = V_Max
	FROM rdt.rdtMobRec WITH (NOLOCK)
	WHERE Mobile = @nMobile

   --Forward/Back
   IF @nFunc = 838
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @nErrNo <> 0
         BEGIN
            GOTO Quit
         END
         IF @nAction = 3
         BEGIN
            IF @nInputKey = 1
            BEGIN
               
               IF rdt.RDTGetConfig( @nFunc, 'DefaultPSSKUQty', @cStorerkey) = '1'
               BEGIN
                  SELECT @cOrdKey = OrderKey, @cExtOrderKey = ExternOrderKey     
                  FROM dbo.PickHeader WITH (NOLOCK)     
                  WHERE PickHeaderKey = @cPickSlipNo

                  IF ISNULL(@cOrdKey, '') <> ''
                  BEGIN
                     SELECT @npickedQty = SUM(Qty),
                        @nPackedQTY = MAX(pack.packedqty)
                     FROM dbo.PickHeader PH (NOLOCK)     
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
                     LEFT OUTER JOIN
                     (SELECT SUM(qty) AS packedqty,PAD.PickSlipNo,PAD.StorerKey,PAD.SKU
                        FROM dbo.PackDetail PAD WITH(NOLOCK)
                        WHERE PAD.PickSlipNo = @cPickSlipNo
                        AND PAD.StorerKey = @cStorerKey
                        AND PAD.sku = @cSku
                     GROUP BY PAD.PickSlipNo,PAD.StorerKey,PAD.SKU) pack
                        ON PD.Storerkey = pack.StorerKey
                        AND PD.Sku = pack.SKU
                     WHERE PH.PickHeaderKey = @cPickSlipNo    
                     AND	  PD.Status = N'5'
                     AND   PD.StorerKey  = @cStorerKey
                     AND   PD.SKU = @cSKU
                     GROUP BY PD.SKU
                  END
                  ELSE
                  BEGIN
                     SELECT @nPickedQTY = SUM(Qty),
                     @nPackedQTY = MAX(pack.packedqty)
                     FROM dbo.PickHeader PH (NOLOCK)     
                     JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
                     JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) 
                     LEFT OUTER JOIN
                     (SELECT SUM(qty) AS packedqty,PAD.PickSlipNo,PAD.StorerKey,PAD.SKU
                        FROM dbo.PackDetail PAD WITH(NOLOCK)
                        WHERE PAD.PickSlipNo = @cPickSlipNo
                        AND PAD.StorerKey = @cStorerKey
                        AND PAD.sku = @cSku
                     GROUP BY PAD.PickSlipNo,PAD.StorerKey,PAD.SKU) pack
                        ON PD.Storerkey = pack.StorerKey
                        AND PD.Sku = pack.SKU
                     WHERE PH.PickHeaderKey = @cPickSlipNo    
                     AND   PD.Status = N'5'
                     AND   PD.StorerKey  = @cStorerKey
                     AND   PD.SKU = @cSKU
                     GROUP BY PD.SKU
                  END
                  
                  IF ISNULL(@nPickedQTY,0) = 0
                  BEGIN
                     SET @nErrNo = 216902
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Not yet picked 
                     GOTO Quit
                  END
                  ELSE
                  BEGIN
                     SET @nPickedQTY = @nPickedQTY - ISNULL(@nPackedQty,0)
                  END
                  SET @cUDF30 = 'Y'
               END
               ELSE
               BEGIN
                  SET @nPickedQTY = 0
               END

               IF @nPickedQTY = 0
               BEGIN
                  SET @cOutField08 = ''
               END
               ELSE
               BEGIN
                  SET @cOutField08 = @nPickedQTY
               END
            END
         END
		
      END
      ELSE IF @nStep = 2
      BEGIN
         IF @nErrNo <> 0
         BEGIN
            GOTO Quit
         END
         IF @nAction = 0
         BEGIN
            IF @nScn = 4651
            BEGIN
               IF @cJumpType = 'Forward'
               BEGIN
                  SET @nAfterScn = 4652
                  SET @nAfterStep = 3

                  -- Prepare next screen var
                  SET @cOutField01 = 'NEW'
                  SET @cOutField02 = '0/0'
                  SET @cOutField03 = ''  -- SKU
                  SET @cOutField04 = ''  -- SKU
                  SET @cOutField05 = ''  -- Desc 1
                  SET @cOutField06 = ''  -- Desc 2
                  SET @cOutField07 = '0' -- Packed
                  SET @cOutField08 = ''  -- QTY
                  SET @cOutField09 = '0' -- CartonQTY
                  SET @cOutField11 = '' -- UOM
                  SET @cOutField12 = '' -- PUOM
                  SET @cOutField13 = '' -- MUOM
                  SET @cOutField14 = '' -- PQTY
                  SET @cOutField15 = '' -- ExtendedInfo

                  SET @cFieldAttr08 = CASE WHEN @cDisableQTYField = '1' THEN 'O' ELSE '' END
                  SET @cFieldAttr14 = 'O'
               END
               ELSE
               BEGIN

                  IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')
                  BEGIN
                     -- Pack confirm
                     SET @cPrintPackList = ''
                     EXEC rdt.rdt_Pack_PackConfirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                        ,@cPickSlipNo
                        ,@cFromDropID
                        ,@cPackDtlDropID
                        ,@cPrintPackList OUTPUT
                        ,@nErrNo         OUTPUT
                        ,@cErrMsg        OUTPUT
                        
                  END
                  
                  
                  SET @nAfterScn = 4650
                  SET @nAfterStep = 1

                  -- Prepare prev screen var
                  SET @cOutField01 = ''
                  SET @cOutField02 = '' -- FromDropID
                  SET @cOutField03 = '' -- ToDropID
               END
            END
         END
      END
      ELSE IF @nStep = 9
      BEGIN
         IF @nErrNo <> 0 AND @nErrNo <> 100250  ---- ErrNo 100251: Defy Jump to Scn 6449
         BEGIN
            GOTO Quit
         END
         SET @nErrNo = 0
         SET @cErrMsg = ''
         IF @nAction = 0
         BEGIN
            IF @nInputKey = 1
            BEGIN
               DECLARE  @cAddRCPTValidtn     NVARCHAR(10)
               SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddSerialValidtn', @cStorerKey)
               IF @cAddRCPTValidtn = '1'
               BEGIN
                  SET @nAfterScn = 6449
                  SET @nAfterStep = 99
                  SET @cOutField01 = @cSerialNo
                  SET @cOutField03= ''
                  GOTO Quit
               END
            END
         END
      END
      ELSE IF @nStep = 99
      BEGIN
         IF @nErrNo <> 0
         BEGIN
            GOTO Quit
         END
         IF @nInputKey = 1
         BEGIN
            IF @nScn = 6449
            BEGIN
               DECLARE @cOption    NVARCHAR(1)
               SET @cOption = @cInField03
               IF @cOption NOT IN ('1', '9')
               BEGIN
                  SET @nErrNo = 216903
                  SET @cErrMsg = rdt.rdtgetmessage( 216903, @cLangCode, 'DSP')  --216903^InvalidOption
                  GOTO Quit
               END

               SET @cUDF01 = @cOption
               SET @nAfterScn = 4831
               SET @nAfterStep = 9

               IF @cOption = "9"
               BEGIN
                  UPDATE rdt.rdtMobRec SET 
                     V_Max = '', 
                     EditDate = GETDATE()
                  WHERE Mobile = @nMobile
               END


            END
         END

         IF @nInputKey = 0
         BEGIN
            IF @nScn = 6449
            BEGIN
               SET @nAfterScn = 4831
               SET @nAfterStep = 9
            END
         END
      END
   END 
   GOTO Quit

Quit:
END


SET QUOTED_IDENTIFIER OFF

GO