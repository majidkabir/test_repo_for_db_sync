SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_925ExtScn01                                     */  
/*                                                                      */  
/* Purpose:       Indetex containerno validation                        */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-10-09 1.0  XLL045     FCR-859 init                              */  
/************************************************************************/  
  
CREATE   PROC  [RDT].[rdt_925ExtScn01] (
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nScn             INT,           
   @nInputKey        INT,           
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15), 
   @tExtScnData     VariableTable READONLY,
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
      @nStep_MBOL             INT,  @nScn_MBOL              INT,  
      @nStep_Truck            INT,  @nScn_Truck             INT,  
      @nStep_Option           INT,  @nScn_Option            INT,  
      @nStep_ScanPalletID     INT,  @nScn_ScanPalletID      INT,  
      @nStep_SealNo1st        INT,  @nScn_SealNo1st         INT,  
      @nStep_SealNo2nd        INT,  @nScn_SealNo2nd         INT,  
      @nStep_Success          INT,  @nScn_Success           INT,
      @nStep_ExtScn           INT  
   
   SELECT  
      @nStep_MBOL             = 1,   @nScn_MBOL             = 6400,  
      @nStep_Truck            = 2,   @nScn_Truck            = 6401,  
      @nStep_Option           = 3,   @nScn_Option           = 6402,  
      @nStep_ScanPalletID     = 4,   @nScn_ScanPalletID     = 6403,  
      @nStep_SealNo1st        = 5,   @nScn_SealNo1st        = 6404,  
      @nStep_SealNo2nd        = 6,   @nScn_SealNo2nd        = 6405,  
      @nStep_Success          = 7,   @nScn_Success   = 6406,
      @nStep_ExtScn           = 99

   DECLARE 
      @nCheckContainer        NVARCHAR(20),
      @cContainerNo           NVARCHAR(20),
      @cTruckID               NVARCHAR(20),
      @cMBOLKey               NVARCHAR(10)

   SELECT
   @nScn             = Scn,
   @nStep            = Step,
   @cMBOLKey         = V_String1
   FROM rdt.RDTMOBREC
   WHERE Mobile = @nMobile


   SET @nCheckContainer = rdt.RDTGetConfig( @nFunc, 'CheckContainer', @cStorerKey)
   IF @nCheckContainer = '0'
   BEGIN
      SET @nCheckContainer = ''
   END

   IF @nFunc = 925
   BEGIN
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @nCheckContainer = '1'
            BEGIN
               -- Go to extend screen process
               SET @nAfterStep = @nStep_ExtScn
               SET @nAfterScn = @nScn_Truck
               GOTO Quit
            END
         END
      END
      ELSE IF @nStep = 3
      BEGIN
         IF @nInputKey = 0
         BEGIN
            IF @nCheckContainer = '1'
            BEGIN
               -- Go to extend screen process
               SET @nAfterStep = @nStep_ExtScn
               SET @nAfterScn = @nScn_Truck
               GOTO Quit
            END
         END
      END
      ELSE IF @nStep = 99
      BEGIN
         IF @nScn = 6401
         BEGIN
            IF @nInputKey = 0
            BEGIN
               -- Prepare Previous Screen Variable
               SET @cOutField01 = ''
          
               -- GOTO Previous Screen
               SET @nAfterScn = @nScn_MBOL
               SET @nAfterStep = @nStep_MBOL
               GOTO Quit
            END
            -- When entered with an empty id
            ELSE IF @nInputKey = 1
            BEGIN
               SET @cTruckID = ISNULL(RTRIM(@cInField01),'')

               -- Validate blank
               IF @cTruckID = ''
               BEGIN
                  SET @nErrNo = 225903
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Truck ID
                  GOTO Step_99_Fail
               END
               --ELSE IF LEN(@cTruckID) > 11
               --BEGIN
                  --SET @nErrNo = 225904
                  --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Truck ID Length Exceeds 11'
                  --GOTO Step_99_Fail
               --End

               IF rdt.RDTGetConfig( @nFunc, 'CheckContainer', @cStorerKey) = '1'
               BEGIN
                  -- get containerno
                  SELECT @cContainerNo = ISNULL(ContainerNo, '')
                  FROM dbo.MBOL WITH(NOLOCK)
                  WHERE MbolKey = @cMBOLKey
                  
                  IF @cContainerNo = ''
                  BEGIN
                     -- if not exists, update scanned content into containerno
                     UPDATE dbo.MBOL SET ContainerNo = @cTruckID
                     WHERE MbolKey = @cMBOLKey
                  END
                  ELSE IF @cContainerNo <> @cTruckID
                  BEGIN
                     -- if scanned content <> containerno, pop up error, wrong contaner
                     SET @nErrno = 225901
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrno, @cLangCode, 'DSP') -- wrong container
                     GOTO Step_99_Fail
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM dbo.IDS_VEHICLE WITH (NOLOCK) WHERE  VehicleNumber =  @cTruckID)
                  BEGIN
                     SET @nErrNo = 225902
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Truck Not Check In
                     GOTO Step_99_Fail
                  END
               END

               -- Prepare Next Screen Variable
               SET @cOutField01 = @cTruckID
                
               -- GOTO Next Screen
               SET @nAfterScn = @nScn_Option
               SET @nAfterStep = @nStep_Option
            END
         END
      END
   END
END

Step_99_Fail:
BEGIN
   GOTO Quit
END

Quit:

GO