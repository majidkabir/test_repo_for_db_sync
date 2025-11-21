SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Store procedure: rdt_898ExtScn01                                         */
/* Copyright      : Maersk                                                  */
/*                                                                          */
/* Purpose: Capture pallet type, weight, height for billing purpose         */
/*                                                                          */
/* Date       Rev    Author   Purposes                                      */
/* 2024-03-12 1.0    Ung      WMS-26411 base rdt_600ExtScn03                */
/* 2024-11-28 1.1    YYS027   configkey: from ExtendedScreenSP to ExtScnSP  */
/****************************************************************************/

CREATE   PROC [rdt].[rdt_898ExtScn01] (
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
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT,
   @cUDF30  NVARCHAR( MAX)  OUTPUT   --to support max length parameter output
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Screen constant
   DECLARE @nScn_ID           INT = 1302
   DECLARE @nScn_ClosePallet  INT = 1311
   DECLARE @nScn_PalletInfo   INT = 6446

   -- Session var
   DECLARE @cPalletType NVARCHAR(20)
   DECLARE @cWeight     NVARCHAR(10)
   DECLARE @cHeight     NVARCHAR(10)

   DECLARE
      @cReceiptKey NVARCHAR( 10),
      @cPOKey      NVARCHAR( 10),
      @cLOC        NVARCHAR( 10),
      @cToID       NVARCHAR( 18),
      @cUCC        NVARCHAR( 20),
      @cSKU        NVARCHAR( 20),
      @cQTY        NVARCHAR( 20),
      @nQTY        INT,
      @cParam1     NVARCHAR( 20),
      @cParam2     NVARCHAR( 20),
      @cParam3     NVARCHAR( 20),
      @cParam4     NVARCHAR( 20),
      @cParam5     NVARCHAR( 20),
      @cOption     NVARCHAR( 1)

   SELECT @cReceiptKey = Value FROM @tExtScnData WHERE Variable = '@cReceiptKey'
   SELECT @cPOKey      = Value FROM @tExtScnData WHERE Variable = '@cPOKey'
   SELECT @cLOC        = Value FROM @tExtScnData WHERE Variable = '@cLOC'
   SELECT @cToID       = Value FROM @tExtScnData WHERE Variable = '@cToID'
   SELECT @cUCC        = Value FROM @tExtScnData WHERE Variable = '@cUCC'
   SELECT @cSKU        = Value FROM @tExtScnData WHERE Variable = '@cSKU'
   SELECT @cQTY        = Value FROM @tExtScnData WHERE Variable = '@cQTY'
   SELECT @cParam1     = Value FROM @tExtScnData WHERE Variable = '@cParam1'
   SELECT @cParam2     = Value FROM @tExtScnData WHERE Variable = '@cParam2'
   SELECT @cParam3     = Value FROM @tExtScnData WHERE Variable = '@cParam3'
   SELECT @cParam4     = Value FROM @tExtScnData WHERE Variable = '@cParam4'
   SELECT @cParam5     = Value FROM @tExtScnData WHERE Variable = '@cParam5'
   SELECT @cOption     = Value FROM @tExtScnData WHERE Variable = '@cOption'

   SELECT @nQTY        = CONVERT(INT,@cQTY)      WHERE ISNUMERIC(@cQTY)=1

   IF @nFunc = 898 -- UCC receive
   BEGIN
      IF @nStep = 12 -- Close pallet
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Option
            IF @cOption IN ('2', '3') -- 2=YES, 3=YES AND PUTAWAY
            BEGIN
               SET @cFieldAttr02 = '' -- Count UCC               

               -- Pallet info screen
               SET @cOutField01 = '' -- PalletType
               SET @cOutField02 = '' -- Weight
               SET @cOutField03 = '' -- Height
               
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- PalletType

               SET @nAfterScn = @nScn_PalletInfo
               SET @nAfterStep = 99

               GOTO Quit
            END
         END
      END

      IF @nStep = 99 -- Customize screens
      BEGIN
         IF @nScn = @nScn_PalletInfo -- Capture pallet info screen 
         BEGIN
            IF @nInputKey = 1 -- ENTER
            BEGIN
               -- Screen mapping
               SET @cPalletType = @cInField01
               SET @cWeight = @cInField02
               SET @cHeight = @cInField03

               -- Check blank
               IF @cPalletType = ''
               BEGIN
                  SET @nErrNo = 225251
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Type
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- PalletType
                  GOTO Quit
               END
               SET @cOutField01 = @cPalletType 
               
               -- Check pallet type valid
               IF NOT EXISTS( SELECT 1 FROM dbo.PalletMaster WITH (NOLOCK) WHERE Pallet_Type = @cPalletType)
               BEGIN
                  SET @nErrNo = 225252
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PalletType
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- PalletType
                  SET @cOutField01 = ''
                  GOTO Quit
               END
               
               -- Check weight valid
               IF rdt.rdtIsValidQty( @cWeight, 21) = 0 -- 21 = Check zero
               BEGIN
                  SET @nErrNo = 225253
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  SET @cOutField02 = ''
                  GOTO QUIT
               END

               -- Check weight range  
               IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'WEIGHT', 'FLOAT', @cWeight) = 0  
               BEGIN  
                  SET @nErrNo = 225254
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  SET @cOutField02 = ''
                  GOTO Quit
               END
               SET @cOutField02 = @cWeight
               
               -- Check weight valid
               IF rdt.rdtIsValidQty( @cHeight, 21) = 0 -- 21 = Check zero
               BEGIN
                  SET @nErrNo = 225255
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid height
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  SET @cOutField03 = ''
                  GOTO QUIT
               END
               
               -- Check height range
               IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'HEIGHT', 'FLOAT', @cHeight) = 0  
               BEGIN  
                  SET @nErrNo = 225256
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  SET @cOutField03 = ''
                  GOTO Quit
               END
               SET @cOutField03 = @cHeight
               
               -- Confirm
               IF NOT EXISTS( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) WHERE PalletKey = @cToID)
               BEGIN
                  -- Get pallet type info
                  --DECLARE @cUDF01 NVARCHAR( 60) = ''
                  --DECLARE @cUDF02 NVARCHAR( 60) = ''
                  SELECT
                     @cUDF01 = ISNULL( UDF01, ''),
                     @cUDF02 = ISNULL( UDF02, '')
                  FROM dbo.CodeLKUP WITH (NOLOCK)
                  WHERE ListName = 'PALLETDIMS'
                     AND Code = @cPalletType
                     AND StorerKey = @cStorerKey
                  
                  INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status, Height, GrossWgt, PalletType, Length, Width)
                  VALUES (@cToID, @cStorerKey, '0', @cHeight, @cWeight, @cPalletType, TRY_CAST( @cUDF01 AS FLOAT), TRY_CAST( @cUDF02 AS FLOAT))
               
                  UPDATE dbo.Pallet SET
                     Status = '9', 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME()
                  WHERE PalletKey = @cToID
               END
               
               -- Prepare next screen var
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = @cLOC
               SET @cOutField04 = ''
               SET @cFieldAttr02 = '' -- Count UCC
               
               -- Go to ID screen
               SET @nAfterScn = @nScn_ID
               SET @nAfterStep = 3

               GOTO Quit
            END
            
            IF @nInputKey = 0 -- ESC
            BEGIN
               -- Go to close pallet screen
               SET @cOutField01 = '' --Option
               SET @cOutField02 = '' --Count UCC

               EXEC rdt.rdtSetFocusField @nMobile, 1 --Option

               IF rdt.RDTGetConfig( @nFunc, 'ClosePalletCountUCC', @cStorerKey) <> '1'
                  SET @cFieldAttr02 = 'O' -- Count UCC
      			
      			SET @nAfterScn = @nScn_ClosePallet
      			SET @nAfterStep = 12
            END
		   END
      END
   END
   
Quit:

END

SET QUOTED_IDENTIFIER OFF 

GO