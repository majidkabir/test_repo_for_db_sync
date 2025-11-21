SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_803ExtScn01                                    */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/*                     Ace Turtle                                       */      
/* Date       Rev  Author   Purposes                                    */      
/* 2022-11-01 1.0  JHU151    FCR-650 Created                            */ 
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_803ExtScn01] (
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
      @cResult01        NVARCHAR( 20),
      @cResult02        NVARCHAR( 20),
      @cResult03        NVARCHAR( 20),
      @cResult04        NVARCHAR( 20),
      @cResult05        NVARCHAR( 20),
      @cResult06        NVARCHAR( 20),
      @cResult07        NVARCHAR( 20),
      @cResult08        NVARCHAR( 20),
      @cResult09        NVARCHAR( 20),
      @cResult10        NVARCHAR( 20),
      @cOption                NVARCHAR(1), 
      @cMethod                NVARCHAR(1),
      @cPosition              NVARCHAR(10),
      @cUPC                   NVARCHAR(30), 
      @cSKU                   NVARCHAR(20),
      @cDeviceID     NVARCHAR( 20),
      @cDecodeSP              NVARCHAR(20),
      @cLastPos               NVARCHAR(5),
      @cLight                 NVARCHAR( 1),
      @cStation               NVARCHAR(10),
      @cExtendedValidateSP    NVARCHAR( 20),
      @cExtendedUpdateSP      NVARCHAR( 20),
      @cIPAddress    NVARCHAR( 40),
      @cSQL                   NVARCHAR(MAX),
      @cSQLParam              NVARCHAR(MAX),
      @cShort                 NVARCHAR(10),
      @bSuccess               INT

   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT
      @cStation         = V_String1,
      @cMethod          = V_String2,
      @cLastPos         = V_String3,
      @cDeviceID        = DeviceID,
      @cIPAddress       = V_String4,
      @cPosition        = V_String5,
      @cExtendedValidateSP = V_String20,
      @cExtendedUpdateSP   = V_String21,
      @cDecodeSP           = V_String23,
      @cLight              = V_String24,
      @cUPC                = V_String41,
      @cSKU                = V_SKU
	FROM rdt.rdtMobRec WITH (NOLOCK)
	WHERE Mobile = @nMobile
   
   SELECT
      @cShort = Short
   FROM CodeLKUP WITH (NOLOCK) 
   WHERE ListName = 'PTLPiece' 
      AND Code = @cMethod 
      AND StorerKey = @cStorerKey

   --Forward/Back
   IF @nFunc = 803
   BEGIN
      IF @nStep = 3 AND @nAction = 0
      BEGIN
         -- Inbound
         IF CHARINDEX('I', @cShort) > 0
         BEGIN
            SET @nAfterScn = @nScn
            SET @nAfterStep = 99
         END
         ELSE-- outbound keep original step
         BEGIN
            SET @nAfterScn = @nScn
            SET @nAfterStep = @nStep
         END
      END

      IF @nStep = 99
      BEGIN
         IF @nInputKey = 1 --ENTER
         BEGIN
            DECLARE @cBarcode NVARCHAR( 60)

            -- Screen mapping
            SET @cBarcode = @cInField11 -- SKU
            SET @cUPC = LEFT( @cInField11, 30)
            SET @cOption = @cInField13

            IF @cOption = '9' -- Close
            BEGIN
               IF @cPosition <> ''
               BEGIN
                  UPDATE dbo.DeviceProfile
                     SET Status = '9'
                  WHERE Storerkey = @cStorerKey
                  AND DevicePosition = @cPosition
                  AND DeviceID = @cStation

                  DECLARE @nRowRef     INT
                  DECLARE @cPalletID   NVARCHAR(20)
                  DECLARE @cReceiptKey NVARCHAR(30)
                  DECLARE @cLOC        NVARCHAR(20)
                  SELECT TOP 1 @nRowRef = RowRef,@cPalletID = SourceKey
                  FROM rdt.rdtPTLPieceLog WITH(NOLOCK)
                  WHERE position = @cPosition
                  ORDER BY RowRef DESC

                  -- rollback qty to pallet
                  UPDATE rdt.rdtPTLPieceLog
                  SET UserDefine02 = CAST(CAST(UserDefine02 AS INT) - 1 AS NVARCHAR(30))
                  WHERE RowRef = @nRowRef

                  SELECT @cReceiptKey = Receiptkey
                  FROM RECEIPTDETAIL WITH(NOLOCK)
                  WHERE Storerkey = @cStorerkey
                  AND ToId = @cPalletID
                  
                  -- get empty position
                  SELECT TOP 1      
                     @cIPAddress = DP.IPAddress,
                     @cLOC = DP.LOC,
                     @cPosition = DP.DevicePosition      
                  FROM dbo.DeviceProfile DP WITH (NOLOCK)      
                  WHERE DP.DeviceType = 'STATION'      
                     AND DP.DeviceID = @cStation
                     --AND Status <> '9'
                     AND NOT EXISTS( SELECT 1      
                        FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)      
                        WHERE Log.Station = @cStation      
                           AND Log.Position = DP.DevicePosition)
                  ORDER BY DP.LogicalPos, DP.DevicePosition

                  -- Check enuf position in station      
                  IF @@ROWCOUNT = 0
                  BEGIN      
                     SET @nErrNo = 228751      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos      
                     --SET @cOutField01 = ''      
                     GOTO Quit      
                  END    
                  
                  -- Save assign      
                  INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Loc, Position, Method, SourceKey, BatchKey, SKU, UserDefine02, DropID, StorerKey)     
                  VALUES      
                  (@cStation, @cIPAddress, @cLOC, @cPosition, @cMethod, @cPalletID, @cReceiptKey, @cSKU, '0', @cPalletID, @cStorerKey )    
                  IF @@ERROR <> 0      
                  BEGIN      
                     SET @nErrNo = 228752      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
                     GOTO Quit      
                  END
                  
               END
               GOTO Quit
            END

            -- Check blank
            IF @cBarcode = ''
            BEGIN
               SET @nErrNo = 228753
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU
               GOTO Step_3_Fail
            END
         
            -- Decode
            IF @cDecodeSP <> ''
            BEGIN
               -- Standard decode
               IF @cDecodeSP = '1'
               BEGIN
                  EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
                     @cUPC    = @cUPC     OUTPUT, 
                     @nErrNo  = @nErrNo   OUTPUT, 
                     @cErrMsg = @cErrMsg  OUTPUT
               END
               
               -- Customize decode
               ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cBarcode, ' +
                     ' @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     ' @nMobile      INT,           ' +
                     ' @nFunc        INT,           ' +
                     ' @cLangCode    NVARCHAR( 3),  ' +
                     ' @nStep        INT,           ' +
                     ' @nInputKey    INT,           ' +
                     ' @cFacility    NVARCHAR( 5),  ' +
                     ' @cStorerKey   NVARCHAR( 15), ' +
                     ' @cStation     NVARCHAR( 10), ' +
                     ' @cMethod      NVARCHAR( 10), ' +
                     ' @cBarcode     NVARCHAR( 60), ' +
                     ' @cUPC         NVARCHAR( 30)  OUTPUT, ' +
                     ' @nErrNo       INT            OUTPUT, ' +
                     ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cBarcode, 
                     @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Step_3_Fail
               END
            END

            -- Get SKU count
            DECLARE @nSKUCnt INT
            SET @nSKUCnt = 0
            EXEC RDT.rdt_GetSKUCNT
               @cStorerKey  = @cStorerKey
               ,@cSKU        = @cUPC
               ,@nSKUCnt     = @nSKUCnt   OUTPUT
               ,@bSuccess    = @bSuccess  OUTPUT
               ,@nErr        = @nErrNo    OUTPUT
               ,@cErrMsg     = @cErrMsg   OUTPUT

            -- Check SKU valid
            IF @nSKUCnt = 0
            BEGIN
               SET @nErrNo = 228754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
               GOTO Step_3_Fail
            END

            IF @nSKUCnt = 1
               EXEC rdt.rdt_GetSKU
                  @cStorerKey  = @cStorerKey
                  ,@cSKU        = @cUPC      OUTPUT
                  ,@bSuccess    = @bSuccess  OUTPUT
                  ,@nErr        = @nErrNo    OUTPUT
                  ,@cErrMsg     = @cErrMsg   OUTPUT
            /**
            -- Check barcode return multi SKU
            IF @nSKUCnt > 1
            BEGIN
               IF @cMultiSKUBarcode IN ('1', '2')
               BEGIN
                  EXEC rdt.rdt_PTLPiece_MultiSKU @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
                     @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
                     @cInField01 OUTPUT,  @cOutField01 OUTPUT,
                     @cInField02 OUTPUT,  @cOutField02 OUTPUT,
                     @cInField03 OUTPUT,  @cOutField03 OUTPUT,
                     @cInField04 OUTPUT,  @cOutField04 OUTPUT,
                     @cInField05 OUTPUT,  @cOutField05 OUTPUT,
                     @cInField06 OUTPUT,  @cOutField06 OUTPUT,
                     @cInField07 OUTPUT,  @cOutField07 OUTPUT,
                     @cInField08 OUTPUT,  @cOutField08 OUTPUT,
                     @cInField09 OUTPUT,  @cOutField09 OUTPUT,
                     @cInField10 OUTPUT,  @cOutField10 OUTPUT,
                     @cInField11 OUTPUT,  @cOutField11 OUTPUT,
                     @cInField12 OUTPUT,  @cOutField12 OUTPUT,
                     @cInField13 OUTPUT,  @cOutField13 OUTPUT,
                     @cInField14 OUTPUT,  @cOutField14 OUTPUT,
                     @cInField15 OUTPUT,  @cOutField15 OUTPUT,
                     'POPULATE',
                     @cMultiSKUBarcode,
                     @cUPC     OUTPUT,
                     @nErrNo   OUTPUT,
                     @cErrMsg  OUTPUT

                  IF @nErrNo = 0 -- Populate multi SKU screen
                  BEGIN
                     -- Go to Multi SKU screen
                     SET @nFromScn = @nScn
                     SET @nScn = 3570
                     SET @nStep = @nStep + 3
                     GOTO Quit
                  END
                  IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
                     SET @nErrNo = 0
               END
               ELSE       
               BEGIN
                  SET @nErrNo = 99509
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
                  GOTO Step_3_Fail
               END
            END**/
            SET @cSKU = @cUPC

            -- Confirm task
            EXEC rdt.rdt_PTLPiece_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cLight
               ,@cStation
               ,@cMethod
               ,@cSKU
               ,@cIPAddress OUTPUT
               ,@cPosition  OUTPUT
               ,@nErrNo     OUTPUT
               ,@cErrMsg    OUTPUT
               ,@cResult01  OUTPUT
               ,@cResult02  OUTPUT
               ,@cResult03  OUTPUT
               ,@cResult04  OUTPUT
               ,@cResult05  OUTPUT
               ,@cResult06  OUTPUT
               ,@cResult07  OUTPUT
               ,@cResult08  OUTPUT
               ,@cResult09  OUTPUT
               ,@cResult10  OUTPUT
            IF @nErrNo <> 0
            BEGIN
               GOTO Step_3_Fail
            END

            -- Prepare next screen var
            SET @cOutField01 = @cResult01
            SET @cOutField02 = @cResult02
            SET @cOutField03 = @cResult03
            SET @cOutField04 = @cResult04
            SET @cOutField05 = @cResult05
            SET @cOutField06 = @cResult06
            SET @cOutField07 = @cResult07
            SET @cOutField08 = @cResult08
            SET @cOutField09 = @cResult09
            SET @cOutField10 = @cResult10
            SET @cOutField11 = '' -- SKU
            SET @cOutField12 = @cLastPos
            
            -- Save last position
            SET @cLastPos = ''
            SELECT @cLastPos = LEFT( LogicalName, 5)
            FROM DeviceProfile WITH (NOLOCK)
            WHERE DeviceType = 'STATION'
               AND DeviceID = @cStation
               AND DeviceID <> ''
               AND ISNULL(IPAddress,'') =ISNULL(@cIPAddress,'')
               AND DevicePosition = @cPosition

           
            SET @cUDF01 = @cIPAddress
            SET @cUDF02 = @cPosition
            SET @cUDF03 = @cLight
            SET @cUDF04 = @cUPC
            SET @cUDF05 = @cLastPos
            SET @cUDF06 = @cSKU
            -- Remain in current screen
            SET @nAfterScn = @nScn
            SET @nAfterStep = @nStep
         END

         IF @nInputKey = 0
         BEGIN
            -- Extended validate
            IF @cExtendedUpdateSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption, ' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile      INT,           ' +
                     '@nFunc        INT,           ' +
                     '@cLangCode    NVARCHAR( 3),  ' +
                     '@nStep        INT,           ' +
                     '@nInputKey    INT,           ' +
                     '@cFacility    NVARCHAR( 5),  ' + 
                     '@cStorerKey   NVARCHAR( 15), ' +
                     '@cStation     NVARCHAR( 10), ' +
                     '@cMethod      NVARCHAR( 1),  ' +
                     '@cSKU         NVARCHAR( 20), ' +
                     '@cLastPos     NVARCHAR( 10), ' +
                     '@cOption      NVARCHAR( 1),  ' +
                     '@nErrNo       INT            OUTPUT, ' +
                     '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT
                  
                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END

            -- Dynamic assign  
            EXEC rdt.rdt_PTLPiece_Assign @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cStation, @cMethod, 'POPULATE-IN',  
               @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  
               @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  
               @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  
               @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  
               @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  
               @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  
               @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  
               @nScn        OUTPUT,  
               @nErrNo      OUTPUT,  
               @cErrMsg     OUTPUT  
            IF @nErrNo <> 0  
               GOTO Quit  

            SET @nAfterScn = @nScn
            SET @nAfterStep = 2  
         END
         GOTO Quit

         Step_3_Fail:
         BEGIN
            -- Blank the matrix 
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''
            SET @cOutField11 = '' -- SKU

         END

      END
   END 
   GOTO Quit

Quit:
END


SET QUOTED_IDENTIFIER OFF

GO