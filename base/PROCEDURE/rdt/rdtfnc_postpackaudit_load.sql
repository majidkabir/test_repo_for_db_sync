SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_Load                           */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: normal receipt                                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2006-05-31 1.0  UngDH    Created                                     */
/* 2007-02-28 1.1  jwong    sos#69044 Add Open Batch                    */
/* 2016-09-30 1.2  Ung      Performance tuning                          */
/* 2018-11-09 1.3  TungGH   Performance                                 */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_PostPackAudit_Load] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @i           INT

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 

   @cVehicle      NVARCHAR( 20), 
   @cConsigneeKey NVARCHAR( 15), 
   @cSeal         NVARCHAR( 20), 
   @cCaseID       NVARCHAR( 18), 
   @nScan         INT, 
   @cBatch    NVARCHAR( 15),
  
   @cRefNo1   NVARCHAR( 20), 
   @cRefNo2   NVARCHAR( 20), 
   @cRefNo3   NVARCHAR( 20), 
   @cRefNo4   NVARCHAR( 20), 
   @cRefNo5   NVARCHAR( 20), 
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Load RDT.RDTMobRec
SELECT 
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cConsigneeKey = V_ConsigneeKey, 
   @cCaseID       = V_CaseID, 

   @cVehicle  = V_String1, 
   @cSeal     = V_String2, 
   @cRefNo1   = V_String3, 
   @cRefNo2   = V_String4, 
   @cRefNo3   = V_String5, 
   @cRefNo4   = V_String6, 
   @cRefNo5   = V_String7, 
   @cBatch   = V_String8, 
   @nScan     = CASE WHEN IsNumeric( LEFT( V_String8, 5)) = 1 THEN LEFT( V_String8, 5) ELSE 0 END, 

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 568 -- Load
BEGIN
   -- Redirect to respective screen
--    IF @nStep = 0 GOTO Step_0   -- Func = Load
   IF @nStep = 0 GOTO Step_0   -- Scn = 639. Batch 
   IF @nStep = 1 GOTO Step_1   -- Scn = 640. Vehicle, Ref No 1-5
   IF @nStep = 2 GOTO Step_2   -- Scn = 641. Vehicle, Stor, Seal
   IF @nStep = 3 GOTO Step_3   -- Scn = 641. Vehicle, Stor, CaseID
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 568. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 640
   SET @nStep = 1

   -- Initiate var
   SET @cVehicle = ''
   SET @cConsigneeKey = ''
   SET @cCaseID  = ''
   SET @cSeal = ''
   SET @cRefNo1 = ''
   SET @cRefNo2 = ''
   SET @cRefNo3 = ''
   SET @cRefNo4 = ''
   SET @cRefNo5 = ''
   SET @nScan = 0
   SET @cBatch = ''

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
END
GOTO Quit

-- /********************************************************************************
-- Step 1. scn = 639. Batch screen
--    Batch   (field01)
-- ********************************************************************************/
-- Step_1:
-- BEGIN
--    IF @nInputKey = 1 -- Yes or Send
--    BEGIN
--       -- Screen mapping
--       SET @cBatch = @cInField01
-- 
--       -- Validate consignee blank
--       IF @cBatch = '' OR @cBatch IS NULL
--       BEGIN
--          SET @nErrNo = 62941
--          SET @cErrMsg = rdt.rdtgetmessage( 62941, @cLangCode, 'DSP') --62941^Batch needed
--          EXEC rdt.rdtSetFocusField @nMobile, 1
--          GOTO Step_1_Fail
--       END
-- 
--       -- Validate ConsigneeKey
--       IF NOT EXISTS( SELECT 1
--          FROM RDT.RDTCSAudit_Batch (NOLOCK) 
--          WHERE StorerKey = @cStorerKey AND Batch = @cBatch)
--       BEGIN
--          SET @nErrNo = 62949
--          SET @cErrMsg = rdt.rdtgetmessage( 62949, @cLangCode, 'DSP') --62949^BatchNotFound
--          SET @cOutField01 = ''
--          EXEC rdt.rdtSetFocusField @nMobile, 1
--          GOTO Step_1_Fail
--       END
-- 
--       -- Go to next screen
--       SET @nScn = @nScn + 1
--       SET @nStep = @nStep + 1
--    END
-- 
--    IF @nInputKey = 0 -- Esc or No
--    BEGIN
--       -- Back to menu
--       SET @nFunc = @nMenu
--       SET @nScn  = @nMenu
--       SET @nStep = 0
--       SET @cOutField01 = ''
--    END
--    GOTO Quit
-- 
--    Step_1_Fail:
-- END
-- GOTO Quit


/********************************************************************************
Step 1. Scn = 640. Vehicle screen
   Vehicle (field01)
   RefNo1  (field02)
   RefNo2  (field03)
   RefNo3  (field04)
   RefNo4  (field05)
   RefNo5  (field06)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Validate if anything changed or initial blank
      IF (@cVehicle <> @cInField01 OR
         @cRefNo1 <> @cInField02 OR
         @cRefNo2 <> @cInField03 OR
         @cRefNo3 <> @cInField04 OR
         @cRefNo4 <> @cInField05 OR
         @cRefNo5 <> @cInField06) OR
         @cInField01 = ''
      -- There are changes, remain in current screen
      BEGIN
         -- Set next field focus
         SET @i = 2 -- start from 2nd field
         IF @cInField02 <> '' SET @i = @i + 1
         IF @cInField03 <> '' SET @i = @i + 1
         IF @cInField04 <> '' SET @i = @i + 1
         IF @cInField05 <> '' SET @i = @i + 1
         IF @cInField06 <> '' SET @i = @i + 1
         IF @i > 6 SET @i = 2
         EXEC rdt.rdtSetFocusField @nMobile, @i
         
         -- Screen mapping
         SET @cVehicle = @cInField01
         SET @cRefNo1 = @cInField02
         SET @cRefNo2 = @cInField03
         SET @cRefNo3 = @cInField04
         SET @cRefNo4 = @cInField05
         SET @cRefNo5 = @cInField06

         -- Validate blank
         IF @cVehicle = '' OR @cVehicle IS NULL
         BEGIN
            SET @nErrNo = 60751
            SET @cErrMsg = rdt.rdtgetmessage( 60751, @cLangCode, 'DSP') --'Vehicle needed'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Retain key-in value
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = @cInField02
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cInField04
         SET @cOutField05 = @cInField05
         SET @cOutField06 = @cInField06

         -- Remain in current screen
         -- SET @nScn = @nScn + 1
         -- SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = '' -- Stor
         SET @cOutField03 = '' -- Seal
         EXEC rdt.rdtSetFocusField @nMobile, 2

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Vehicle
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 641. Stor screen
   Vehicle   (field01)
   Stor      (field02)
   Seal (field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cConsigneeKey = @cInField02
      SET @cSeal = @cInField03

      -- Save a copy
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @cSeal

      -- Validate consignee blank
      IF @cConsigneeKey = '' OR @cConsigneeKey IS NULL
      BEGIN
         SET @nErrNo = 60752
         SET @cErrMsg = rdt.rdtgetmessage( 60752, @cLangCode, 'DSP') --'Stor needed'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END

      -- Validate ConsigneeKey
      IF NOT EXISTS( SELECT 1
         FROM dbo.Storer (NOLOCK) 
         WHERE StorerKey = @cConsigneeKey)
      BEGIN
         SET @nErrNo = 60754
         SET @cErrMsg = rdt.rdtgetmessage( 60754, @cLangCode, 'DSP') --'Invalid stor'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END

      -- Validate Seal blank
      IF @cSeal = '' OR @cSeal IS NULL
      BEGIN
         SET @nErrNo = 60753
         SET @cErrMsg = rdt.rdtgetmessage( 60753, @cLangCode, 'DSP') --'Seal needed'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      -- Prepare next screen var
      SET @nScan = 0
      SET @cCaseID = ''
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = '' -- CaseID
      SET @cOutField04 = CAST( @nScan AS NVARCHAR( 5))

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cVehicle = ''
      SET @cRefNo1  = ''
      SET @cRefNo2  = ''
      SET @cRefNo3  = ''
      SET @cRefNo4  = ''
      SET @cRefNo5  = ''

      SET @cOutField01 = '' -- Vehicle
      SET @cOutField02 = '' -- RefNo1
      SET @cOutField03 = '' -- RefNo2
      SET @cOutField04 = '' -- RefNo3
      SET @cOutField05 = '' -- RefNo4
      SET @cOutField06 = '' -- RefNo5

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
END
GOTO Quit


/********************************************************************************
Step 3. scn = 643. Tote screen
   Vehicle   (field01)
   Stor      (field02)
   Case/Tote (field03)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cCaseID = @cInField03

      -- Save a copy
      SET @cOutField03 = @cCaseID

      -- Validate CaseID blank
      IF @cCaseID = '' OR @cCaseID IS NULL
      BEGIN
         SET @nErrNo = 60755
         SET @cErrMsg = rdt.rdtgetmessage( 60755, @cLangCode, 'DSP') --'CaseID needed'
         GOTO Step_3_Fail
      END

      DECLARE @nRowRef INT
      DECLARE @cChkConsigneeKey NVARCHAR( 15)

      -- Get CaseID (record are pumped in from PPP/PPA end pallet / tote)
      SELECT TOP 1
         @nRowRef = RowRef, 
         @cChkConsigneeKey = ConsigneeKey
      FROM RDT.RDTCSAudit_Load (NOLOCK)
      WHERE StorerKey = @cStorerKey
         -- AND ConsigneeKey = @cConsigneeKey  -- Remark for 'Stor is Diff' checking
         AND CaseID = @cCaseID
         AND Vehicle = '' -- Not loaded
         --AND Status = '0' -- Not loaded (close load not implement yet)
      ORDER BY GroupID DESC -- Take the latest CaseID (CaseID is not unique)

      -- Validate CaseID
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60756
         SET @cErrMsg = rdt.rdtgetmessage( 60756, @cLangCode, 'DSP') --'Invalid CaseID'
         GOTO Step_3_Fail
      END

      -- Validate ConsigneeKey
      IF @cChkConsigneeKey <> @cConsigneeKey
      BEGIN
         SET @nErrNo = 60757
         SET @cErrMsg = rdt.rdtgetmessage( 60757, @cLangCode, 'DSP') --'Stor is Diff'
         GOTO Step_3_Fail
      END

      -- Update
      UPDATE RDT.rdtCSAudit_Load WITH (ROWLOCK) SET
         Vehicle = @cVehicle, 
         Seal = @cSeal, 
         Status = '5',
         RefNo1 = @cRefNo1, 
         RefNo2 = @cRefNo2, 
         RefNo3 = @cRefNo3, 
         RefNo4 = @cRefNo4, 
         RefNo5 = @cRefNo5
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 60758
         SET @cErrMsg = rdt.rdtgetmessage( 60758, @cLangCode, 'DSP') --'Upd load fail'
         GOTO Step_3_Fail
      END

      -- Refresh current screen var
      SET @nScan = @nScan + 1
      SET @cCaseID = ''
      SET @cOutField03 = '' -- CaseID
      SET @cOutField04 = CAST( @nScan AS NVARCHAR( 5))

      -- Remain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cConsigneeKey = ''
      SET @cSeal = ''
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = '' -- Stor
      SET @cOutField03 = '' -- Seal

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField03 = '' -- CaseID
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 

      V_ConsigneeKey = @cConsigneeKey, 
      V_CaseID = @cCaseID, 

      V_String1 = @cVehicle, 
      V_String2 = @cSeal, 
      V_String3 = @cRefNo1, 
      V_String4 = @cRefNo2, 
      V_String5 = @cRefNo3, 
      V_String6 = @cRefNo4, 
      V_String7 = @cRefNo5, 
      V_String8 = @nScan, 
      V_String9 = @cBatch, 

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END


GO