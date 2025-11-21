SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ConfirmShortPick                             */
/* Copyright      : Maersk                                              */
/* FBR: 85867                                                           */
/* Purpose: Print carton label                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev   Author     Purposes                               */
/* 11-Mar-2012  1.0   Ung        SOS238698 Created                      */
/* 30-Sep-2016  1.1   Ung        Performance tuning                     */
/* 21-Nov-2024  1.2.0 Dennis     FCR-1349 Extended Update               */
/* 27-Nov-2022  1.3.0 PXL009     UWP-27586 correct the step jump        */
/************************************************************************/

CREATE   PROC rdt.rdtfnc_ConfirmShortPick(
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables


-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cPrinter       NVARCHAR( 10),

	@cWaveKey       NVARCHAR( 10),
	@cLoadKey       NVARCHAR( 10),
	@cOrderKey      NVARCHAR( 10),
   @cShort         NVARCHAR( 6), 
   @cPick          NVARCHAR( 6),
   @nFocusField    INT,
   @cOrderCount    NVARCHAR( 5), 
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1) 

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cPrinter         = Printer,

   @cLoadKey         = V_LoadKey, 
   @cOrderKey        = V_OrderKey,

   @cShort           = V_String1,
   @cPick            = V_String2,
   @nFocusField      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String3,  5), 0) = 1 THEN LEFT( V_String3,  5) ELSE 0 END,

   @cWaveKey         = V_String4,
   @cOrderCount      = V_String5, 

   @cExtendedUpdateSP   = V_String10,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 869
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 869
   IF @nStep = 1  GOTO Step_1  -- Scn = 3050. WaveKey, LoadKey, OrderKey
   IF @nStep = 2  GOTO Step_2  -- Scn = 3051. Info
   IF @nStep = 3  GOTO Step_3  -- Scn = 3052. Option
   IF @nStep = 4  GOTO Step_4  -- Scn = 3052. Option
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 869
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 3050
   SET @nStep = 1

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

   -- Prepare next screen var
   SET @nFocusField = 1
   SET @cOutField01 = '' -- WaveKey
   SET @cOutField02 = '' -- LoadKey
   SET @cOutField03 = '' -- OrderKey

   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''
END
GOTO Quit


/********************************************************************************
Scn = 3050. WaveKey / LoadKey / OrderKey
   WaveKey  (field01, input)
   LoadKey  (field02, input)
   OrderKey (field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       -- Screen mapping
       SET @cWaveKey = @cInField01
       SET @cLoadKey = @cInField02
       SET @cOrderKey = @cInField03
       
		-- Check if blank
		IF @cWaveKey = '' AND @cLoadKey = '' AND @cOrderKey = ''
		BEGIN
	      SET @nErrNo = 75501
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need value
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO Quit
		END

		-- Check if key-in more then 1
		DECLARE @i INT
		SET @i = 0
		IF @cWaveKey <> '' SET @i = @i + 1
		IF @cLoadKey <> '' SET @i = @i + 1 
		IF @cOrderKey <> '' SET @i = @i + 1
		IF @i <> 1
		BEGIN
	      SET @nErrNo = 75502
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Key-in OneOnly
	      EXEC rdt.rdtSetFocusField @nMobile, 01
	      GOTO Quit
		END

      DECLARE @nOrderCount INT
      DECLARE @nShort      INT
      DECLARE @nPick       INT

		IF @cWaveKey <> ''
		BEGIN
		   -- Check valid WaveKey
			IF NOT EXISTS (SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey)
			BEGIN
		      SET @nErrNo = 75503
		      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWaveKey
		      EXEC rdt.rdtSetFocusField @nMobile, 01
		      GOTO Quit
			END
         
         -- Check not yet pick
			IF EXISTS (SELECT 1
            FROM PickDetail PD WITH (NOLOCK)
               INNER JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
               INNER JOIN WaveDetail WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
            WHERE WD.WaveKey = @cWaveKey
               AND PD.Status < '3'
               AND PD.QTY > 0)
			BEGIN
		      SET @nErrNo = 75504
		      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFinishPick
		      EXEC rdt.rdtSetFocusField @nMobile, 01
		      GOTO Quit
			END
			
         -- Get stat
         SELECT 
            @nOrderCount = COUNT( DISTINCT OD.OrderKey), 
            @nShort = SUM( CASE WHEN PD.Status = 4 THEN PD.QTY ELSE 0 END), 
            @nPick  = SUM( CASE WHEN PD.Status = 5 THEN PD.QTY ELSE 0 END)
         FROM PickDetail PD WITH (NOLOCK)
            INNER JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
            INNER JOIN WaveDetail WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
         WHERE WD.WaveKey = @cWaveKey

         --set field focus on field no. 1
         SET @nFocusField = 1
      END


		IF @cLoadKey <> ''
		BEGIN
		   -- Check valid LoadKey
			IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan (NOLOCK) WHERE LoadKey = @cLoadKey)
			BEGIN
		      SET @nErrNo = 75505
		      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoadKey
		      EXEC rdt.rdtSetFocusField @nMobile, 02
		      GOTO Quit
			END

         -- Check not yet pick
			IF EXISTS (SELECT 1
            FROM PickDetail PD WITH (NOLOCK)
               INNER JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
            WHERE OD.LoadKey = @cLoadKey
               AND PD.Status < '3'
               AND PD.QTY > 0)
			BEGIN
		      SET @nErrNo = 75506
		      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFinishPick
		      EXEC rdt.rdtSetFocusField @nMobile, 02
		      GOTO Quit
			END

         -- Get stat
         SELECT 
            @nOrderCount = COUNT( DISTINCT OD.OrderKey), 
            @nShort = SUM( CASE WHEN PD.Status = 4 THEN PD.QTY ELSE 0 END), 
            @nPick  = SUM( CASE WHEN PD.Status = 5 THEN PD.QTY ELSE 0 END)
         FROM PickDetail PD WITH (NOLOCK)
            INNER JOIN OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
         WHERE OD.LoadKey = @cLoadKey

         --set field focus on field no. 2
         SET @nFocusField = 2
      END

		IF @cOrderKey <> ''
		BEGIN
		   -- Check valid OrderKey
			IF NOT EXISTS (SELECT 1 FROM dbo.Orders (NOLOCK) WHERE OrderKey = @cOrderKey)
			BEGIN
		      SET @nErrNo = 75507
		      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid OrdKey
		      EXEC rdt.rdtSetFocusField @nMobile, 03
		      GOTO Quit
			END

         -- Check not yet pick
			IF EXISTS (SELECT 1 
			   FROM PickDetail PD WITH (NOLOCK) 
			   WHERE PD.OrderKey = @cOrderKey 
			      AND PD.Status < '3' 
			      AND PD.QTY > 0)
			BEGIN
		      SET @nErrNo = 75508
		      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotFinishPick
		      EXEC rdt.rdtSetFocusField @nMobile, 03
		      GOTO Quit
			END

         -- Get stat
         SELECT 
            @nOrderCount = 1, 
            @nShort = SUM( CASE WHEN PD.Status = 4 THEN PD.QTY ELSE 0 END), 
            @nPick  = SUM( CASE WHEN PD.Status = 5 THEN PD.QTY ELSE 0 END)
         FROM PickDetail PD WITH (NOLOCK)
         WHERE PD.OrderKey = @cOrderKey

         --set field focus on field no. 3
         SET @nFocusField = 3
      END

      SET @cOrderCount = CAST( ISNULL( @nOrderCount, 0) AS NVARCHAR( 5))
      SET @cShort = CAST( ISNULL( @nShort, 0) AS NVARCHAR( 10))
      SET @cPick = CAST( ISNULL( @nPick, 0) AS NVARCHAR( 10))

      -- Prepare next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = @cOrderCount
      SET @cOutField05 = @cPick
      SET @cOutField06 = @cShort

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Scn = 3051. Info screen
   WaveKey    (field01)
   LoadKey    (field02)
   OrderKey   (field03)
   OrderCount (field04)
   Short      (field05)
   Pick       (field06)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Check any short
		IF @cShort = '0'
		BEGIN
	      SET @nErrNo = 75509
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No short pick
	      GOTO Quit
		END

      -- Prepare next screen var
      SET @cOutField01 = '' -- Option

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- WaveKey
      SET @cOutField02 = '' -- LoadKey
      SET @cOutField03 = '' -- OrderKey

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1

      --set focus on previous scanned field
      EXEC rdt.rdtSetFocusField @nMobile, @nFocusField
   END
END
GOTO Quit


/********************************************************************************
Scn = 3052. Option Screen
   OPTION (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cOption NVARCHAR(1)

      -- Screen mapping
      SET @cOption = @cInField01

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 75510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         EXEC RDT.rdt_ConfirmShortPick @nMobile, @nFunc, @cLangCode,
            @cWaveKey,
            @cLoadKey, 
            @cOrderkey,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit
      END
            -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cOption, @cLoadKey, @cOrderKey,@cWaveKey, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT,           ' +
               '@nFunc          INT,           ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@nInputKey      INT,           ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cOption        NVARCHAR(  1), ' +
               '@cLoadKey       NVARCHAR( 10), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cWaveKey       NVARCHAR( 10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cOption, @cLoadKey, @cOrderKey,@cWaveKey,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Quit
            END
         END
      END

      IF @cOption = '1' -- Yes
      BEGIN
          -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END

      IF @cOption = '2' -- No
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cWaveKey
         SET @cOutField02 = @cLoadKey
         SET @cOutField03 = @cOrderKey
         SET @cOutField04 = @cOrderCount
         SET @cOutField05 = @cPick
         SET @cOutField06 = @cShort

         -- Go to prev screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cWaveKey
      SET @cOutField02 = @cLoadKey
      SET @cOutField03 = @cOrderKey
      SET @cOutField04 = @cOrderCount
      SET @cOutField05 = @cPick
      SET @cOutField06 = @cShort

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Scn = 3053. Message Screen
   All short pick QTY
   unallocated
   
   All orders have been
   pack confirmed and 
   scanned out
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- WaveKey
      SET @cOutField02 = '' -- LoadKey
      SET @cOutField03 = '' -- OrderKey
   
      -- Back to wave/load/order screen
      SET @nScn  = @nScn - 3
      SET @nStep = @nStep - 3
      
      --set focus on previous scanned field
      EXEC rdt.rdtSetFocusField @nMobile, @nFocusField
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      -- UserName     = @cUserName,
      Printer      = @cPrinter,
      V_LoadKey    = @cLoadKey, 
      V_OrderKey   = @cOrderKey,

      V_String1    = @cShort,
      V_String2    = @cPick,
      V_String3    = @nFocusField,
      V_String4    = @cWaveKey, 
      V_String5    = @cOrderCount, 

      V_String10   = @cExtendedUpdateSP,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15  = @cFieldAttr15 
      
   WHERE Mobile = @nMobile
END

SET QUOTED_IDENTIFIER OFF

GO