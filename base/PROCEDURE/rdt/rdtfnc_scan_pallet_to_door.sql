SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Scan_Pallet_To_Door                               */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#316783 - Standard/Generic Scan To Door module                */
/*                       Use Pallet ID instead of Drop ID                    */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2015-05-21 1.0  James    Created (Modified from rdtfnc_Scan_To_Door)      */
/* 2016-02-01 1.1  James    SOS316783-Enhancement on MBOL retrieval (james01)*/
/* 2016-09-30 1.2  Ung      Performance tuning                               */
/* 2018-10-25 1.3  TungGH   Performance                                      */
/* 2024-05-21 1.4  Dennis   FCR-336 Check Digit                              */
/* 2024-05-31 1.5  Cuize    UWP-20116 Add storerKey in WHERE condition       */
/* 2024-07-17 1.6  NLT013   FCR-574 Add Extended Screen SP                   */
/* 2024-08-22 1.7  JHU151   UWP-23409 incorrect mapping of LPN to MBOL       */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Scan_Pallet_To_Door](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
-- Misc variable
DECLARE
   @b_success           INT

-- Define a variable
DECLARE
   @nFunc                  INT,
   @nScn                   INT,
   @nStep                  INT,
   @cLangCode              NVARCHAR(3),
   @nMenu                  INT,
   @nInputKey              NVARCHAR( 3),
   @cPrinter               NVARCHAR( 10),
   @cUserName              NVARCHAR( 18),
   @cStorerGroup           NVARCHAR( 20),
   @cStorerKey             NVARCHAR( 15),
   @cChkStorerKey          NVARCHAR( 15),
   @cFacility              NVARCHAR( 5),

   @cPalletID              NVARCHAR( 18),
   @cDoor                  NVARCHAR( 20),
   @cActDoor               NVARCHAR( 20),
   @cLoadkey               NVARCHAR( 10),
   @cOrderkey              NVARCHAR( 10),
   @cMBOLKey               NVARCHAR( 10),
   @cOption                NVARCHAR( 1), 
   @cExtendedValidateSP    NVARCHAR( 20), 
   @cExtendedUpdateSP      NVARCHAR( 20),  
   @cSQL                   NVARCHAR( 1000), 
   @cSQLParam              NVARCHAR( 1000), 
   @nCBOLKey               INT,
   @nStorer_Cnt            INT,
   @cLOCCheckDigitSP       NVARCHAR( 20),

   @cExtScnSP              NVARCHAR( 20),
   @tExtScnData            VariableTable,
   @nAction                INT,

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1),

   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,

   @cUDF01  NVARCHAR( 250) ,    @cUDF02 NVARCHAR( 250) ,       @cUDF03 NVARCHAR( 250) ,
   @cUDF04  NVARCHAR( 250) ,    @cUDF05 NVARCHAR( 250) ,       @cUDF06 NVARCHAR( 250) ,
   @cUDF07  NVARCHAR( 250) ,    @cUDF08 NVARCHAR( 250) ,       @cUDF09 NVARCHAR( 250) ,
   @cUDF10  NVARCHAR( 250) ,    @cUDF11 NVARCHAR( 250) ,       @cUDF12 NVARCHAR( 250) ,
   @cUDF13  NVARCHAR( 250) ,    @cUDF14 NVARCHAR( 250) ,       @cUDF15 NVARCHAR( 250) ,
   @cUDF16  NVARCHAR( 250) ,    @cUDF17 NVARCHAR( 250) ,       @cUDF18 NVARCHAR( 250) ,
   @cUDF19  NVARCHAR( 250) ,    @cUDF20 NVARCHAR( 250) ,       @cUDF21 NVARCHAR( 250) ,
   @cUDF22  NVARCHAR( 250) ,    @cUDF23 NVARCHAR( 250) ,       @cUDF24 NVARCHAR( 250) ,
   @cUDF25  NVARCHAR( 250) ,    @cUDF26 NVARCHAR( 250) ,       @cUDF27 NVARCHAR( 250) ,
   @cUDF28  NVARCHAR( 250) ,    @cUDF29 NVARCHAR( 250) ,       @cUDF30 NVARCHAR( 250)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cStorerGroup     = StorerGroup, 
   @cFacility        = Facility,
   @cStorerKey       = V_StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,
   @cPalletID        = V_ID,
   @cLoadkey         = V_Loadkey,
   @cOrderkey        = V_Orderkey,

   @cDoor            = V_String1,
   @cMBOLkey         = V_String2,
   @cExtScnSP        = V_String3,
   
   @nCBOLKey         = V_Integer1,
   @cLOCCheckDigitSP = C_String1,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1650
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1650
   IF @nStep = 1 GOTO Step_1   -- Scn = 4200   PALLET ID
   IF @nStep = 2 GOTO Step_2   -- Scn = 4201   TO DOOR
   IF @nStep = 3 GOTO Step_3   -- Scn = 4202   OPTION : Close truck 
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1650)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4200
   SET @nStep = 1
   SET @cLOCCheckDigitSP = rdt.rdtGetConfig(@nFunc, 'LOCCheckDigitSP', @cStorerKey)

   SET @cExtScnSP = rdt.rdtGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtScnSP = '0'
      SET @cExtScnSP = ''

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- initialise all variable
   SET @cPalletID = ''
   SET @cDoor = ''

   -- Prep next screen var
   SET @cOutField01 = ''
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4200
   Pallet ID (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletID = @cInField01

      --When PalletID is blank
      IF @cPalletID = ''
      BEGIN
         SET @nErrNo = 54501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID req
         GOTO Step_1_Fail
      END
      /*
      --ID Not Exists
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   ID = @cPalletID
                     AND  [Status] >= '5'
                     AND  [Status] < '9')
      BEGIN
         SET @nErrNo = 54502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Plt ID
         GOTO Step_1_Fail
      END
      */
      SELECT @nStorer_Cnt = COUNT( DISTINCT StorerKey)
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE ID = @cPalletID
      AND  [Status] >= '5'
      AND  [Status] < '9'

      IF @nStorer_Cnt = 0
      BEGIN
         SET @nErrNo = 54502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Plt ID
         GOTO Step_1_Fail
      END

      -- 1 pallet only 1 storer
      IF @nStorer_Cnt > 1
      BEGIN
         SET @nErrNo = 54512
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID mix storer
         GOTO Step_1_Fail
      END
      
      SELECT TOP 1 @cChkStorerKey = StorerKey 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE ID = @cPalletID
      AND  [Status] >= '5'
      AND  [Status] < '9'

      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 54513
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
      END
      -- Check if all contain for the pallet belong to 1 mbol (james02)
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey 
                     AND PD.OrderLineNumber = OD.OrderLineNumber)
                  WHERE OD.StorerKey = @cStorerKey
                  AND   ISNULL( OD.MBOLKey, '') <> ''
                  AND   PD.Status >= '5'
                  AND   PD.Status < '9'
                  AND   PD.ID = @cPalletID                  
                  GROUP BY OD.MBOLKey
                  HAVING COUNT( DISTINCT MBOLKey) > 1)
      BEGIN
         SET @nErrNo = 54503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT >1 MBOL
         GOTO Step_1_Fail
      END

      -- 1 Pallet only go to 1 MBOL (james01)
      IF EXISTS ( SELECT 1
                  FROM dbo.MBOL M WITH (NOLOCK)
                  JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON ( M.MBOLKey = MD.MBOLKey)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = MD.OrderKey)
                  WHERE M.Status <> '9'
                  AND   PD.ID = @cPalletID
                  AND   PD.storerKey = @cStorerKey
                  GROUP BY PD.ID
                  HAVING COUNT( DISTINCT M.MBOLKEY) > 1)
      BEGIN
         SET @nErrNo = 54514
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltMultiMbol
         GOTO Step_1_Fail
      END

      SET @cLoadkey = ''
      SET @cOrderkey = ''
      SET @cMBOLKey = ''

      SELECT TOP 1 @cLoadkey = OD.LoadKey, @cOrderkey = OD.OrderKey
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey 
         AND PD.OrderLineNumber = OD.OrderLineNumber)
      WHERE OD.StorerKey = @cStorerKey
      AND   PD.Status >= '5'
      AND   PD.Status < '9'
      AND   PD.ID = @cPalletID                  

      IF ISNULL( @cLoadkey, '') = ''
      BEGIN
         SET @nErrNo = 54504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID No Loadkey
         GOTO Step_1_Fail
      END

      -- Get MBOLkey
      -- 1 pallet go to 1 mbol only
      SELECT TOP 1 @cMBOLKey = M.MBOLKey
      FROM dbo.MBOL M WITH (NOLOCK)
      JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON ( M.MBOLKey = MD.MBOLKey)
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.OrderKey = MD.OrderKey)
      WHERE M.Status <> '9'
      AND   MD.Loadkey = @cLoadkey
      AND   PD.ID = @cPalletID
      AND   PD.storerKey = @cStorerKey


      IF ISNULL( @cMBOLKey, '') = ''
      BEGIN
         SET @nErrNo = 54505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No MBOL
         GOTO Step_1_Fail
      END

      IF EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND Status = '9')
      BEGIN
         SET @nErrNo = 54506
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
         GOTO Step_1_Fail
      END

      -- Get Door
      SELECT @nCBOLKey = ISNULL( CBOLKey, 0) FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      IF @nCBOLKey = 0
         SELECT @cDoor = RTRIM( ISNULL( PlaceOfLoading, '')) FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey
      ELSE
         SELECT @cDoor = RTRIM( ISNULL( Userdefine01, '')) FROM dbo.CBOL WITH (NOLOCK) WHERE CBOLKey = @nCBOLKey

      IF @cDoor = ''
      BEGIN
          SET @nErrNo = 54507
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Door Not Assigned
          GOTO Step_1_Fail
      END

      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletID       NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END

      --prepare next screen variable
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cDoor

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'ScanToDoorCloseTruck', @cStorerkey) = '1'
      BEGIN
         -- Go to close truck screen
         SET @cOutField01 = '' -- Option

         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END

      -- EventLog - Sign Out Function
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END

   Step_1_Jump:
   BEGIN
      IF @cExtScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
         BEGIN
            SET @nAction = 0
            DELETE FROM @tExtScnData

            INSERT INTO @tExtScnData (Variable, Value) VALUES
               ('@cPalletID',             @cPalletID),
               ('@nCBOLKey',              TRY_CAST(@nCBOLKey AS NVARCHAR(20))),
               ('@cMBOLKey',              @cMBOLKey)

            EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtScnSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nAction, 
            @nScn     OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cPalletID = ''
      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 4201)
   PALLET ID:  (Field01)
   DOOR:       (Field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cActDoor = @cInField03

      --When Door is blank
      IF @cActDoor = ''
      BEGIN
         SET @nErrNo = 54508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Door req
         GOTO Step_2_Fail
      END

      IF @cLOCCheckDigitSP = '1'
      BEGIN
         EXEC rdt.rdt_LOCLookUp_CheckDigit @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
            @cActDoor    OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      IF @cActDoor <> @cDoor
      BEGIN
         SET @nErrNo = 54509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Door
         GOTO Step_2_Fail
      END

      -- (james03)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletID       NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF ISNULL( @cExtendedUpdateSP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile          INT,           ' +
            '@nFunc            INT,           ' +
            '@nStep            INT,           ' +
            '@cLangCode        NVARCHAR( 3),  ' +
            '@nInputKey        INT,           ' +
            '@cStorerKey       NVARCHAR( 15), ' +             
            '@cPalletID        NVARCHAR( 20), ' +
            '@cMbolKey         NVARCHAR( 10), ' +
            '@cDoor            NVARCHAR( 20), ' +
            '@cOption          NVARCHAR( 1),  ' +
            '@nAfterStep       INT,           ' + 
            '@nErrNo           INT           OUTPUT, ' +
            '@cErrMsg          NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @cLangCode, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_2_Fail

      END

      -- insert to Eventlog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4', -- Move
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerkey,
         @cToLocation   = @cActDoor,
         @cToID         = @cPalletID,
         @cLoadkey      = @cLoadkey,
         @cOrderkey     = @cOrderkey,
         @cRefNo3       = 'SCNPL2DOOR',
         @nStep         = @nStep

      --prepare next screen variable
      SET @cPalletID = ''
      SET @cOutField01 = ''
      SET @cOutField06 = ''
      
      -- Go back prev screen to scan next Pallet ID
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletID       NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END

      --prepare prev screen variable
      SET @cPalletID = ''
      SET @cOutField01 = ''
      SET @cOutField06 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   Step_2_Jump:
   BEGIN
      IF @cExtScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
         BEGIN
            SET @nAction = 0
            DELETE FROM @tExtScnData

            INSERT INTO @tExtScnData (Variable, Value) VALUES
               ('@nCBOLKey',              TRY_CAST(@nCBOLKey AS NVARCHAR(20))),
               ('@cMBOLKey',              @cMBOLKey)

            EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtScnSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nAction, 
            @nScn     OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

            IF @nErrNo <> 0
               GOTO Step_1_Fail
         END
      END
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cActDoor = ''

      -- Reset this screen var
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = @cDoor
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 4202)
   CLOSE TRUCK?
   1=YES
   2=NO
   OPTION: (Field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption= @cInField01

      -- Check blank
      IF ISNULL( @cOption, '') = ''
      BEGIN
         SET @nErrNo = 54510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req
         GOTO Step_3_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1','2')
      BEGIN
         SET @nErrNo = 54511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Option
         SET @cOutField01 = '' -- Option
         GOTO Step_3_Fail
      END

      -- (james03)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN

         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletID       NVARCHAR( 20), ' +
               '@cMbolKey        NVARCHAR( 10), ' +
               '@cDoor           NVARCHAR( 20), ' +
               '@cOption         NVARCHAR( 1), '  +
               '@nAfterStep      INT,           ' + 
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF ISNULL( @cExtendedUpdateSP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@nStep           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nInputKey       INT,           ' + 
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cPalletID       NVARCHAR( 20), ' +
            '@cMbolKey        NVARCHAR( 10), ' +
            '@cDoor           NVARCHAR( 20), ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@nAfterStep      INT,           ' + 
            '@nErrNo          INT           OUTPUT, ' + 
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail
   
      END

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
      -- Back to Pallet ID screen
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF ISNULL( @cExtendedUpdateSP, '') <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @cLangCode, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@nStep           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nInputKey       INT,           ' + 
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cPalletID       NVARCHAR( 20), ' +
            '@cMbolKey        NVARCHAR( 10), ' +
            '@cDoor           NVARCHAR( 20), ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@nAfterStep      INT,           ' + 
            '@nErrNo          INT           OUTPUT, ' + 
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @nInputKey, @cStorerKey, @cPalletID, @cMbolKey, @cDoor, @cOption, @nStep,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOption = ''

      -- Reset this screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
  END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       Facility      = @cFacility,
       Printer       = @cPrinter,
       -- UserName      = @cUserName,

       V_StorerKey   = @cStorerKey, 
       V_Loadkey     = @cLoadkey,
       V_Orderkey    = @cOrderkey,
       V_ID          = @cPalletID,

       V_String1     = @cDoor,
       V_String2     = @cMBOLKey,
       V_String3     = @cExtScnSP,
       
       V_Integer1    = @nCBOLKey,
       C_String1     = @cLOCCheckDigitSP,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END

GO