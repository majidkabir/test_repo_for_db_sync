SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_EndScan                        */
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
/* 2006-01-19 1.0  UngDH    Created                                     */
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-11-09 1.2  Gan      Performance tuning                          */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_PostPackAudit_EndScan] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF

-- Misc variable
DECLARE 
   @cOption    NVARCHAR( 1), 
   @cType      NVARCHAR( 1), -- 'P'= pallet, 'T'= tote
   @nError     INT, 
   @nRowCount  INT, 
   @cPalletID  NVARCHAR( 18), 
   @cCaseID    NVARCHAR( 10), 
   @cConsigneeKey NVARCHAR( 15), 
   @cRefNo1    NVARCHAR( 20),
   @cRefNo2    NVARCHAR( 20),
   @cRefNo3    NVARCHAR( 20),
   @cRefNo4    NVARCHAR( 20),
   @cRefNo5    NVARCHAR( 20)

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorer    NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   @cLOC       NVARCHAR( 10), 
   
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

   @cStorer    = StorerKey,
   @cFacility  = Facility,
   @cLOC       = V_LOC, 

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

-- Redirect to respective screen
IF @nFunc = 564 -- Pallet
BEGIN
   IF @nStep = 0 GOTO Step_P0   -- Func = Pallet
   IF @nStep = 1 GOTO Step_P1   -- Scn = 630. Option
   IF @nStep = 2 GOTO Step_P2   -- Scn = 631. Message
END

IF @nFunc = 565 -- Case
BEGIN
   IF @nStep = 0 GOTO Step_C0   -- Func = Case
   IF @nStep = 1 GOTO Step_C1   -- Scn = 632. Option
   IF @nStep = 2 GOTO Step_C2   -- Scn = 633. Message
END

RETURN -- Do nothing if incorrect step


/*-------------------------------------------------------------------------------

                                  PALLET SECTION 

-------------------------------------------------------------------------------*/


/********************************************************************************
Step P0. func = 564. Menu
********************************************************************************/
Step_P0:
BEGIN
   -- Set the entry point
   SET @nScn = 630
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step P1. Scn = 620. Pallet ID screen
   Option (field01)
********************************************************************************/
Step_P1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60801, @cLangCode, 'DSP') --'Invalid option'
         GOTO Step_P1_Fail
      END

      IF @cOption = '2'
      BEGIN
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
         GOTO Quit
      END

      /* Note:
         - The workstation can only have 1 open pallet / tote at a time
         - All record belong to a pallet / tote, status can either be all '0' or '5' or '9'.
           0 = Open
           5 = Closed
           9 = Printed

         Assumption:
         - Since workstation is not key-in, we take workstation from rdtMobRec.V_LOC, which stamp by 
           PPA scan module. But V_LOC can be overwrite by other module also, for e.g. RDT receiving. 
           That means workstation that run PPA do not switch to run other function
      */

      -- Get pallet ID
      SELECT TOP 1 
         @cPalletID = PalletID, 
         @cConsigneeKey = ConsigneeKey
      FROM rdt.rdtCSAudit (NOLOCK)
      WHERE StorerKey = @cStorer
         AND Workstation = @cLOC
         AND Status = '0' -- Open
      IF @@ROWCOUNT = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60802, @cLangCode, 'DSP') --'No open pallet'
         GOTO Step_P1_Fail
      END

      -- Close pallet
      EXECUTE rdt.rdt_PostPackAudit_EndScan
         @nFunc = @nFunc, 
         @cStorerKey = @cStorer, 
         @cConsigneeKey = @cConsigneeKey, 
         @cType = 'P', 
         @cID = @cPalletID, 
         @cWorkstation = @cLOC, 
         @cRefNo1 = '', -- RefNo1..5 only applicable for case
         @cRefNo2 = '',
         @cRefNo3 = '',
         @cRefNo4 = '',
         @cRefNo5 = '',
         @nErrNo = @nErrNo OUTPUT,
         @cErrMsg = @cErrMsg OUTPUT, 
         @cLangCode = @cLangCode

      IF @nErrNo <> 0
         GOTO Step_P1_Fail

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
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

   Step_P1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step P2. scn = 628. Message screen
   Msg
********************************************************************************/
Step_P2:
BEGIN
   IF @nInputKey = 0 OR @nInputKey = 1 -- Esc or No / Yes or Send
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit


/*-------------------------------------------------------------------------------

                                  CASE SECTION 

-------------------------------------------------------------------------------*/


/********************************************************************************
Step C0. func = 565. Menu
********************************************************************************/
Step_C0:
BEGIN
   -- Set the entry point
   SET @nScn = 632
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step C1. Scn = 622. Option screen
   Option (field01)
********************************************************************************/
Step_C1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Validate blank
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60803, @cLangCode, 'DSP') --'Invalid option'
         GOTO Step_C1_Fail
      END

      IF @cOption = '2'
      BEGIN
         -- Back to menu
         SET @nFunc = @nMenu
         SET @nScn  = @nMenu
         SET @nStep = 0
         SET @cOutField01 = ''
         GOTO Quit
      END

      /* Note:
         - The workstation can only have 1 open pallet / tote at a time
         - All record belong to a pallet / tote, status can either be all '0' or '5' or '9'.
           0 = Open
           5 = Close
           9 = Printed

         Assumption:
         - Since workstation is not key-in, we take workstation from rdtMobRec.V_LOC, which stamp by 
           PPA scan module. But V_LOC can be overwrite by other module also, for e.g. RDT receiving. 
           That means workstation that run PPA do not switch to run other function
      */
      -- Get case ID
      SELECT TOP 1 
         @cCaseID = CaseID, 
         @cConsigneeKey = ConsigneeKey, 
         @cRefNo1 = RefNo1,
         @cRefNo2 = RefNo2,
         @cRefNo3 = RefNo3,
         @cRefNo4 = RefNo4,
         @cRefNo5 = RefNo5
      FROM rdt.rdtCSAudit (NOLOCK)
      WHERE StorerKey = @cStorer
         AND Workstation = @cLOC
         AND Status = '0' -- Open
      IF @@ROWCOUNT = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 60804, @cLangCode, 'DSP') --'No open case'
         GOTO Step_C1_Fail
      END

      -- Close case
      EXECUTE rdt.rdt_PostPackAudit_EndScan
         @nFunc = @nFunc, 
         @cStorerKey = @cStorer, 
         @cConsigneeKey = @cConsigneeKey, 
         @cType = 'C', 
         @cID = @cCaseID, 
         @cWorkstation = @cLOC, 
         @cRefNo1 = @cRefNo1,
         @cRefNo2 = @cRefNo2,
         @cRefNo3 = @cRefNo3,
         @cRefNo4 = @cRefNo4,
         @cRefNo5 = @cRefNo5,
         @nErrNo = @nErrNo OUTPUT,
         @cErrMsg = @cErrMsg OUTPUT, 
         @cLangCode = @cLangCode

      IF @nErrNo <> 0
         GOTO Step_C1_Fail

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END


   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
      GOTO Quit
   END
   GOTO Quit

   Step_C1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step C2. scn = 623. Message screen
   Msg
********************************************************************************/
Step_C2:
BEGIN
   IF @nInputKey = 0 OR @nInputKey = 1 -- Esc or No / Yes or Send
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
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

      StorerKey = @cStorer,
      Facility  = @cFacility, 
      V_LOC     = @cLOC, 

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