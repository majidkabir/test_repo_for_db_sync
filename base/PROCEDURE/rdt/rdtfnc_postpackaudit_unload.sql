SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_Unload                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SOS#68200 - To unload stock from truck                      */
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
/* 2007-03-01 1.0  Vicky    Created                                     */
/* 2008-07-01 1.1  Shong    Renumber the Error Message (Mistake)        */
/* 2016-09-30 1.2  Ung      Performance tuning                          */
/* 2018-11-09 1.3  Gan      Performance tuning                          */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_PostPackAudit_Unload] (
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
   @cLangCode  NVARCHAR(3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR(15),
   @cFacility  NVARCHAR(5), 

   @cVehicle   NVARCHAR(20), 
   @cRefNo1    NVARCHAR(20), 
   @cRefNo2    NVARCHAR(20), 
   @cRefNo3    NVARCHAR(20), 
   @cRefNo4    NVARCHAR(20), 
   @cRefNo5    NVARCHAR(20), 
   @cOption    NVARCHAR(1),
   @cCaseID    NVARCHAR(18),
   @cScan      NVARCHAR(5),

   @cConsigneeKey NVARCHAR(15),

   @nRefNoCnt  INT,
   @nStatusCnt INT,
   @nMinRowRef INT,
   @nScan      INT,
   
   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60), 
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60), 
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60), 
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60), 
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60), 
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60), 
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60), 
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60), 
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60), 
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60)

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
   @cRefNo1   = V_String2, 
   @cRefNo2   = V_String3, 
   @cRefNo3   = V_String4, 
   @cRefNo4   = V_String5, 
   @cRefNo5   = V_String6, 
   @cOption   = V_String7,
   @cScan     = V_String8,

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

IF @nFunc = 892 -- Unload
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Unload
   IF @nStep = 1 GOTO Step_1   -- Scn = 1206. Vehicle No, Ref No
   IF @nStep = 2 GOTO Step_2   -- Scn = 1207. Vehicle No, Stor
   IF @nStep = 3 GOTO Step_3   -- Scn = 1208. Vehicle No, Stor, Case/Tote, Scan
   IF @nStep = 4 GOTO Step_4   -- Scn = 1209. Option
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 891. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1206
   SET @nStep = 1

   -- Initiate var
   SET @cVehicle = ''
   SET @cRefNo1 = ''
   SET @cRefNo2 = ''
   SET @cRefNo3 = ''
   SET @cRefNo4 = ''
   SET @cRefNo5 = ''
   SET @cCaseID = ''
   SET @cConsigneeKey = ''
   SET @cScan = '0'
   SET @nScan = 0

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1200. Vehicle screen
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
            SET @nErrNo = 62927
            SET @cErrMsg = rdt.rdtgetmessage( 62927, @cLangCode, 'DSP') --'Vehicle No Req'
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
--           SET @nScn = @nScn + 1
--           SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SELECT @nRefNoCnt = COUNT(RowRef)
         FROM rdt.RDTCSAudit_Load (NOLOCK) 
         WHERE Vehicle = @cVehicle
          AND RefNo1 = @cRefNo1
          AND RefNo2 = @cRefNo2
          AND RefNo3 = @cRefNo3
          AND RefNo4 = @cRefNo4
          AND RefNo5 = @cRefNo5
          AND Storerkey = @cStorerKey

         IF @nRefNoCnt = 0
         BEGIN
            SET @nErrNo = 62928
            SET @cErrMsg = rdt.rdtgetmessage( 62928, @cLangCode, 'DSP') --'Invalid Trip'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END  

         SELECT @nStatusCnt = COUNT(RowRef)
         FROM rdt.RDTCSAudit_Load (NOLOCK) 
         WHERE Vehicle = @cVehicle
          AND RefNo1 = @cRefNo1
          AND RefNo2 = @cRefNo2
          AND RefNo3 = @cRefNo3
          AND RefNo4 = @cRefNo4
          AND RefNo5 = @cRefNo5
          AND Storerkey = @cStorerKey
          AND Status = '5'

         IF @nStatusCnt = 0
         BEGIN
            SET @nErrNo = 62929
            SET @cErrMsg = rdt.rdtgetmessage( 62929, @cLangCode, 'DSP') --'Trip closed'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END 
         -- Prep next screen var
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = ''
         SET @cInField02 = ''
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
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = @cRefNo1
      SET @cOutField03 = @cRefNo2
      SET @cOutField04 = @cRefNo3
      SET @cOutField05 = @cRefNo4
      SET @cOutField06 = @cRefNo5
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 1207. Vehicle No, store screen
   Vehicle No   (field01)
   Store        (field02)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
	   SET @cConsigneeKey = @cInField02

      IF @cConsigneeKey = '' OR  @cConsigneeKey IS NULL
      BEGIN
         SET @nErrNo = 62930
	      SET @cErrMsg = rdt.rdtgetmessage( 62930, @cLangCode, 'DSP') --'Stor needed'
         EXEC rdt.rdtSetFocusField @nMobile, 2
	      GOTO Step_2_Fail
      END

      IF @cConsigneeKey = 'ALL'
      BEGIN 
         SET @cInField01 = ''
         SET @cOutField01 = ''
       
         -- Go to last screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
         GOTO Quit
      END
      ELSE
      BEGIN
	      -- Validate ConsigneeKey
	      IF NOT EXISTS( SELECT 1
	         FROM dbo.Storer (NOLOCK) 
	         WHERE StorerKey = @cConsigneeKey)
	      BEGIN
	         SET @nErrNo = 62931
	         SET @cErrMsg = rdt.rdtgetmessage( 62931, @cLangCode, 'DSP') --'Invalid stor'
	         SET @cOutField02 = ''
	         EXEC rdt.rdtSetFocusField @nMobile, 2
	         GOTO Step_2_Fail
	      END
       END 

     DECLARE @nStorRef INT

     SELECT TOP 1 
        @nStorRef = RowRef
      FROM rdt.RDTCSAudit_Load (NOLOCK) 
      WHERE Vehicle = @cVehicle
      AND RefNo1 = @cRefNo1 
      AND RefNo2 = @cRefNo2
      AND RefNo3 = @cRefNo3 
      AND RefNo4 = @cRefNo4
      AND RefNo5 = @cRefNo5 
      AND Storerkey = @cStorerKey
      AND ConsigneeKey = @cConsigneeKey 
      AND Status = '5' 

     IF @@ROWCOUNT = 0
     BEGIN
	         SET @nErrNo = 62932
	         SET @cErrMsg = rdt.rdtgetmessage( 62932, @cLangCode, 'DSP') --'Stor Not In Trip'
	         SET @cOutField02 = ''
	         EXEC rdt.rdtSetFocusField @nMobile, 2
	         GOTO Step_2_Fail
     END
      
      -- Prepare next screen var
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = '' 
      SET @cOutField04  = '0'
      SET @cInField03 = ''
      SET @cInField04 = ''
      SET @nScan = 0
      SET @cScan = '0'
     

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
--      SET @cInField02 = ''
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = @cRefNo1
      SET @cOutField03 = @cRefNo2
      SET @cOutField04 = @cRefNo3
      SET @cOutField05 = @cRefNo4
      SET @cOutField06 = @cRefNo5

      EXEC rdt.rdtSetFocusField @nMobile, 1
      
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 3. scn = 1208. Vehicle no, Store, case/tote screen
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
         SET @nErrNo = 62933
         SET @cErrMsg = rdt.rdtgetmessage( 62933, @cLangCode, 'DSP') --'Case needed'
         GOTO Step_3_Fail
      END

      IF @cCaseID = 'ALL'
      BEGIN
         SET @cInField01 = ''
         SET @cOutField01 = ''
       
         -- Go to last screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         GOTO Quit
      END    

      DECLARE @nRowRef INT
      DECLARE @cChkConsigneeKey NVARCHAR( 15)

      -- Get CaseID (record are pumped in from PPP/PPA end pallet / tote)
      SELECT TOP 1
         @nRowRef = RowRef, 
         @cChkConsigneeKey = ConsigneeKey
      FROM RDT.RDTCSAudit_Load (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConsigneeKey = @cConsigneeKey  
         AND CaseID = @cCaseID
         AND Vehicle = @cVehicle
	      AND RefNo1 = @cRefNo1 
	      AND RefNo2 = @cRefNo2
	      AND RefNo3 = @cRefNo3 
	      AND RefNo4 = @cRefNo4
	      AND RefNo5 = @cRefNo5 
         AND Status = '5'
      ORDER BY GroupID DESC -- Take the latest CaseID (CaseID is not unique)

      -- Validate CaseID
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62934
         SET @cErrMsg = rdt.rdtgetmessage( 62934, @cLangCode, 'DSP') --'Case Not In Trip'
         GOTO Step_3_Fail
      END

      -- Update
      UPDATE RDT.rdtCSAudit_Load WITH (ROWLOCK) 
        SET Status = '0' ,
            Vehicle = '',
            Seal = '',
            RefNo1 = '',
            RefNo2 = '',
            RefNo3 = '',
            RefNo4 = '',
            RefNo5 = ''
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 62936
         SET @cErrMsg = rdt.rdtgetmessage( 62936, @cLangCode, 'DSP') --'Fail to UPD'
         GOTO Step_3_Fail
      END

      -- Refresh current screen var
      SET @cScan = CONVERT(CHAR(5), (CAST(@cScan AS INT) + 1))
--      SET @cScan = CONVERT(CHAR(5), @nScan)
      SET @cCaseID = ''
      SET @cOutField03 = '' -- CaseID
      SET @cOutField04 = @cScan

      -- Remain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cConsigneeKey = ''
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = '' -- Stor
      SET @cOutField03 = '' 

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
Step 4. scn = 1209. Option screen
   Option   (field01)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
	   SET @cOption = ''
	   SET @cOption = @cInField01

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 62935
	      SET @cErrMsg = rdt.rdtgetmessage( 62935, @cLangCode, 'DSP') --'Invalid Option'
	      GOTO Step_4_Fail
      END
     
      IF @cOption = '1' -- Update
      BEGIN
        IF @cConsigneeKey = 'ALL'
        BEGIN      
	        UPDATE RDT.rdtCSAudit_Load WITH (ROWLOCK) 
	            SET Status = '0',
		             Vehicle = '',
		             Seal = '',
		             RefNo1 = '',
		             RefNo2 = '',
		             RefNo3 = '',
		             RefNo4 = '',
		             RefNo5 = ''
	        WHERE Storerkey = @cStorerkey
             AND Vehicle = @cVehicle
             AND RefNo1 = @cRefNo1 
		       AND RefNo2 = @cRefNo2
		       AND RefNo3 = @cRefNo3 
		       AND RefNo4 = @cRefNo4
		       AND RefNo5 = @cRefNo5 
	          AND Status = '5'

				 IF @@ERROR <> 0
		       BEGIN
			         SET @nErrNo = 62937
			         SET @cErrMsg = rdt.rdtgetmessage( 62937, @cLangCode, 'DSP') --'Fail to UPD'
			         GOTO Step_4_Fail
		       END
       END
       ELSE IF (@cConsigneeKey <> 'ALL') AND (@cCaseID = 'ALL')
       BEGIN
	        UPDATE RDT.rdtCSAudit_Load WITH (ROWLOCK) 
	            SET Status = '0',
		             Vehicle = '',
		             Seal = '',
		             RefNo1 = '',
		             RefNo2 = '',
		             RefNo3 = '',
		             RefNo4 = '',
		             RefNo5 = '' 
	        WHERE Storerkey = @cStorerkey
             AND ConsigneeKey = @cConsigneeKey
             AND Vehicle = @cVehicle
             AND RefNo1 = @cRefNo1 
		       AND RefNo2 = @cRefNo2
		       AND RefNo3 = @cRefNo3 
		       AND RefNo4 = @cRefNo4
		       AND RefNo5 = @cRefNo5 
	          AND Status = '5'

				 IF @@ERROR <> 0
		       BEGIN
			         SET @nErrNo = 62938
			         SET @cErrMsg = rdt.rdtgetmessage( 62938, @cLangCode, 'DSP') --'Fail to UPD'
			         GOTO Step_4_Fail
		       END
       END
      END -- Option = 1

      IF @cOption = '2' -- Back
      BEGIN
        IF @cConsigneeKey = 'ALL'
        BEGIN
		      SET @cInField01 = ''
	         SET @cOutField01 = @cVehicle
            SET @cOutField02 = ''
            SET @cOption = ''

	         SET @nScn = @nScn - 2
	         SET @nStep = @nStep - 2
	         GOTO Quit
        END
        ELSE IF (@cConsigneeKey <> 'ALL') AND (@cCaseID = 'ALL')
        BEGIN
		      SET @cInField01 = ''
	         SET @cOutField01 = @cVehicle
            SET @cOutField02 = @cConsigneeKey
            SET @cOutField03 = ''
            SET @cOutField04 = '0' 
            SET @cOption = ''
  
	         SET @nScn = @nScn - 1
	         SET @nStep = @nStep - 1
	         GOTO Quit
        END
      END

      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = '' 
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to next screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     IF @cConsigneeKey = 'ALL'
     BEGIN
	      SET @cInField01 = ''
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = ''
         SET @cOption = ''

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
         GOTO Quit
     END
     ELSE IF (@cConsigneeKey <> 'ALL') AND (@cCaseID = 'ALL')
     BEGIN
	      SET @cInField01 = ''
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = @cConsigneeKey
         SET @cOutField03 = ''
         SET @cOutField04 = '0' 
         SET @cOption = ''

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
     END
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cInField01 = ''
      SET @cOutField01 = ''
      SET @cOption = ''
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
      V_CaseID       = @cCaseID,

      V_String1 = @cVehicle, 
      V_String2 = @cRefNo1, 
      V_String3 = @cRefNo2, 
      V_String4 = @cRefNo3, 
      V_String5 = @cRefNo4, 
      V_String6 = @cRefNo5, 
      V_String7 = @cOption,
      V_String8 = @cScan,

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