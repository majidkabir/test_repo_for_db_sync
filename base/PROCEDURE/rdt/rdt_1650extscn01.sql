SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1650ExtScn01                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-07-17 1.0  NLT013     FCR-574. Created                          */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1650ExtScn01] (
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
      @nCBOLKey               INT,
      @cMBOLKey               NVARCHAR( 10),
      @cPalletID              NVARCHAR( 18),
      @nRowCount              INT,
      @cSpliCharacter         NCHAR(1)     = NCHAR(9999),
      @nTotalPalletQty        INT,
      @nScannedPalletQty      INT,
      @nCurrentStep           INT,
      @nCurrentScn            INT
   
   SELECT
      @nCurrentStep  = Step,
      @nCurrentScn   = Scn
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   --Forward/Back
   IF @nFunc = 1650
   BEGIN
      IF @nCurrentStep = 1
      BEGIN
         IF @nAction = 0
         BEGIN
            IF @nInputKey = 1
            BEGIN
               SELECT @cPalletID = Value FROM @tExtScnData WHERE Variable = '@cPalletID'
               SELECT @nCBOLKey = TRY_CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nCBOLKey'
               SELECT @cMBOLKey = Value FROM @tExtScnData WHERE Variable = '@cMBOLKey'
               
               IF @nCBOLKey IS NOT NULL AND @nCBOLKey > 0
               BEGIN
                  SELECT @nTotalPalletQty = COUNT(DISTINCT PD.ID)
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.CBOLKey = @nCBOLKey

                  SELECT @nScannedPalletQty = COUNT(DISTINCT PD.ID)
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.CBOLKey = @nCBOLKey
                     AND PD.Notes = 'SCANNED'
               END
               ELSE 
               BEGIN
                  IF @cMBOLKey IS NOT NULL AND @cMBOLKey <> ''
                  BEGIN
                     SELECT @nTotalPalletQty = COUNT(DISTINCT PD.ID)
                     FROM dbo.MBOL M WITH (NOLOCK)
                     INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                     WHERE M.Status <> '9'
                        AND M.Facility = @cFacility
                        AND M.MBOLKey = @cMBOLKey

                     SELECT @nScannedPalletQty = COUNT(DISTINCT PD.ID)
                     FROM dbo.MBOL M WITH (NOLOCK)
                     INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                     WHERE M.Status <> '9'
                        AND M.Facility = @cFacility
                        AND M.MBOLKey = @cMBOLKey
                        AND PD.Notes = 'SCANNED'
                  END
               END

               IF @nTotalPalletQty > 0
               BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK) 
                     SET Notes = 'SCANNED'
                  WHERE StorerKey = @cStorerKey 
                     AND ID = @cPalletID 
                     AND Status >= '5' 
                     AND Status < '9'

                  SET @nScannedPalletQty += 1

                  IF @nTotalPalletQty > @nScannedPalletQty
                  BEGIN
                     SET @cOutField01 = ''
                     SET @cOutField06 = 'Pallet Scanned: ' + TRY_CAST(ISNULL(@nScannedPalletQty, 0) AS NVARCHAR(5)) + '/' + TRY_CAST(@nTotalPalletQty AS NVARCHAR(5)) 

                     SET @nAfterScn = @nCurrentScn
                     SET @nAfterStep = @nCurrentStep
                  END 
               END
            END
            ELSE IF @nInputKey = 0
            BEGIN
               UPDATE RDT.RDTMOBREC WITH (ROWLOCK) 
               SET C_Integer5 = 0,
                  C_String30 = ''
               WHERE Mobile = @nMobile
            END
         END
      END
      ELSE IF @nCurrentStep = 2
      BEGIN
         IF @nAction = 0
         BEGIN
            IF @nInputKey = 0
            BEGIN
               SELECT @nCBOLKey = TRY_CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nCBOLKey'
               SELECT @cMBOLKey = Value FROM @tExtScnData WHERE Variable = '@cMBOLKey'
               
               IF @nCBOLKey IS NOT NULL AND @nCBOLKey > 0
               BEGIN
                  SELECT @nTotalPalletQty = COUNT(DISTINCT PD.DropID)
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.CBOLKey = @nCBOLKey

                  SELECT @nScannedPalletQty = COUNT(DISTINCT PD.DropID)
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.CBOLKey = @nCBOLKey
                     AND PD.Notes = 'SCANNED'
               END
               ELSE 
               BEGIN
                  IF @cMBOLKey IS NOT NULL AND @cMBOLKey <> ''
                  BEGIN
                     SELECT @nTotalPalletQty = COUNT(DISTINCT PD.DropID)
                     FROM dbo.MBOL M WITH (NOLOCK)
                     INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                     WHERE M.Status <> '9'
                        AND M.Facility = @cFacility
                        AND M.MBOLKey = @cMBOLKey

                     SELECT @nScannedPalletQty = COUNT(DISTINCT PD.DropID)
                     FROM dbo.MBOL M WITH (NOLOCK)
                     INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                     WHERE M.Status <> '9'
                        AND M.Facility = @cFacility
                        AND M.MBOLKey = @cMBOLKey
                        AND PD.Notes = 'SCANNED'
                  END
               END

               IF @nTotalPalletQty > 0
               BEGIN
                  SET @cOutField01 = ''
                  SET @cOutField06 = 'Pallet Scanned: ' + TRY_CAST(ISNULL(@nScannedPalletQty, 0) AS NVARCHAR(5)) + '/' + TRY_CAST(@nTotalPalletQty AS NVARCHAR(5)) 
               END
            END
            ELSE IF @nInputKey = 1
            BEGIN
               SET @cOutField01 = ''
               SET @cOutField06 = ''
            END
         END
      END
   END 
   GOTO Quit

Quit:
END

GO