SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_ShortPickCarton                              */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 22-07-2018  1.0  Ung        WMS-5919 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_ShortPickCarton](
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

	@cCartonID      NVARCHAR( 20),
	@cTotalSKU      NVARCHAR( 5),
	@cQTYAlloc      NVARCHAR( 5),
   @cQTYShort      NVARCHAR( 5), 
   @cQTYPick       NVARCHAR( 5),

   @cSPCartonIDByPickDetailCaseID NVARCHAR( 1),

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

   @cCartonID        = V_CaseID, 

   @cTotalSKU        = V_String1,
   @cQTYAlloc        = V_String2,
   @cQTYShort        = V_String3,
   @cQTYPick         = V_String4,

   @cSPCartonIDByPickDetailCaseID = V_String21,

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

IF @nFunc = 881
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 881
   IF @nStep = 1  GOTO Step_1  -- Scn = 5200. CartonID
   IF @nStep = 2  GOTO Step_2  -- Scn = 5201. Info
   IF @nStep = 3  GOTO Step_3  -- Scn = 5202. Confirm short pick?
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step_Start. Func = 881
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cSPCartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'SPCartonIDByPickDetailCaseID', @cStorerKey)

   -- Set the entry point
   SET @nScn = 5200
   SET @nStep = 1

   -- Prepare next screen var
   SET @cOutField01 = '' -- CartonID
END
GOTO Quit


/********************************************************************************
Scn = 5200. ID
   ID  (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
       -- Screen mapping
       SET @cCartonID = @cInField01
       
		-- Check if blank
		IF @cCartonID = ''
		BEGIN
	      SET @nErrNo = 126901
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need carton ID
	      GOTO Quit
		END

      IF @cSPCartonIDByPickDetailCaseID = '1'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE CaseID = @cCartonID
               AND StorerKey = @cStorerKey
               AND ShipFlag <> 'Y')
         BEGIN
            SET @nErrNo = 126902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv CaseID
            GOTO Quit
         END

         -- Get stat
         SELECT 
            @cTotalSKU = COUNT( DISTINCT SKU), 
            @cQTYAlloc = SUM( CASE WHEN PD.Status = 0 THEN PD.QTY ELSE 0 END), 
            @cQTYShort = SUM( CASE WHEN PD.Status = 4 THEN PD.QTY ELSE 0 END), 
            @cQTYPick  = SUM( CASE WHEN PD.Status IN (3,5) THEN PD.QTY ELSE 0 END)
         FROM PickDetail PD WITH (NOLOCK)
         WHERE CaseID = @cCartonID
            AND StorerKey = @cStorerKey
            AND ShipFlag <> 'Y'
      END
      
      ELSE
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.PickDetail WITH (NOLOCK)
            WHERE DropID = @cCartonID
               AND StorerKey = @cStorerKey
               AND ShipFlag <> 'Y')
         BEGIN
            SET @nErrNo = 126903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv DropID
            GOTO Quit
         END

         -- Get stat
         SELECT 
            @cTotalSKU = COUNT( DISTINCT SKU), 
            @cQTYAlloc = SUM( CASE WHEN PD.Status = 0 THEN PD.QTY ELSE 0 END), 
            @cQTYShort = SUM( CASE WHEN PD.Status = 4 THEN PD.QTY ELSE 0 END), 
            @cQTYPick  = SUM( CASE WHEN PD.Status IN (3,5) THEN PD.QTY ELSE 0 END)
         FROM PickDetail PD WITH (NOLOCK)
         WHERE DropID = @cCartonID
            AND StorerKey = @cStorerKey
            AND ShipFlag <> 'Y'
      END

      -- Prepare next screen var
      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cTotalSKU
      SET @cOutField03 = @cQTYShort
      SET @cOutField04 = @cQTYAlloc
      SET @cOutField05 = @cQTYPick

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
Scn = 5201. Info screen
   ID        (field01)
   Total SKU (field02)
   QTY ALLOC (field03)
   QTY SHORT (field04)
   QTY PICK  (field05)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = '' -- Option

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- CartonID

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Scn = 5202. Option Screen
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
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 126904
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         EXEC RDT.rdt_ShortPickCarton_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
            @cCartonID,
            @cTotalSKU, 
            @cQTYAlloc,
            @cQTYShort,
            @cQTYPick,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         -- Prepare next screen var
         SET @cOutField01 = '' -- CartonID

         -- Go to prev screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END

      IF @cOption = '9' -- No
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cCartonID
         SET @cOutField02 = @cTotalSKU
         SET @cOutField04 = @cQTYShort
         SET @cOutField03 = @cQTYAlloc
         SET @cOutField05 = @cQTYPick

         -- Go to prev screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare next screen var
      SET @cOutField01 = @cCartonID
      SET @cOutField02 = @cTotalSKU
      SET @cOutField04 = @cQTYShort
      SET @cOutField03 = @cQTYAlloc
      SET @cOutField05 = @cQTYPick

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
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
      V_CaseID     = @cCartonID, 

      V_String1    = @cTotalSKU,
      V_String2    = @cQTYAlloc,
      V_String3    = @cQTYShort,
      V_String4    = @cQTYPick, 
      
      V_String21   = @cSPCartonIDByPickDetailCaseID, 

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