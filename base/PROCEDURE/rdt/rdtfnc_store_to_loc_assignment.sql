SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_Store_To_Loc_Assignment                           */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#175739 - Assign Consignee to PTS Location                    */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2010-06-09 1.0  Vicky    Created                                          */
/* 2010-07-02 1.1  Vicky    1 STORE = 1 LOC and add additional validation    */
/* 2010-07-14 1.2  Vicky    Add PTS Location Type Validation                 */
/* 2010-07-14 1.3  Vicky    Validation changes  (Vicky03)                    */
/* 2010-08-24 1.4  James    If LOC is assigned to another Store during task  */
/*                          release then not allow to reassign (james01)     */
/* 2010-11-11 1.5  James    Add Store Group (james02)                        */
/* 2011-01-13 1.6  James    Change action type for eventlog (james03)        */
/* 2016-09-30 1.7  Ung      Performance tuning                               */   
/* 2018-11-13 1.8  Gan      Performance tuning                               */
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_Store_To_Loc_Assignment](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @b_success           INT
        
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cConsigneekey       NVARCHAR(15),
   @cLOC                NVARCHAR(10),
   @cCompany1           NVARCHAR(20),   
   @cCompany2           NVARCHAR(20),    
   @cAdd_1a             NVARCHAR(20),
   @cAdd_1b             NVARCHAR(20),      
   @cAdd_2a             NVARCHAR(20),      
   @cAdd_2b             NVARCHAR(20),      
   @cAdd_3a             NVARCHAR(20),      
   @cAdd_3b             NVARCHAR(20),      
   @cZip                NVARCHAR(18),      
   @cCountry            NVARCHAR(20),     
   @cOption             NVARCHAR(1),
   @cStoreGroup         NVARCHAR(10),   -- (james02)
   @nPrevScn            INT,        -- (james02)
   @nPrevStep           INT,        -- (james03)

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
   @cFieldAttr15 NVARCHAR( 1)
            
-- Getting Mobile information
SELECT 
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer, 
   @cUserName        = UserName,
   
   @nPrevScn         = V_FromScn,
   @nPrevStep        = V_FromStep,

   @cConsigneekey    = V_ConsigneeKey,
   @cLOC             = V_Loc,
   @cCompany1        = V_String1,
   @cCompany2        = V_String2,
   @cAdd_1a          = V_String3,
   @cAdd_1b          = V_String4,
   @cAdd_2a          = V_String5,
   @cAdd_2b          = V_String6,
   @cAdd_3a          = V_String7,
   @cAdd_3b          = V_String8,
   @cZip             = V_String9,
   @cCountry         = V_String10,
   @cOption          = V_String11,
   @cStoreGroup      = V_String12,
  -- @nPrevScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END,
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,


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
IF @nFunc = 1754
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1754
   IF @nStep = 1 GOTO Step_1   -- Scn = 2370  Store
   IF @nStep = 2 GOTO Step_2   -- Scn = 2371  Address
   IF @nStep = 3 GOTO Step_3   -- Scn = 2372  Loc
   IF @nStep = 4 GOTO Step_4   -- Scn = 2373  Option
   IF @nStep = 5 GOTO Step_5   -- Scn = 2374  Store Group
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1754)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2370
   SET @nStep = 1

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
   SET @cConsigneekey = ''
   SET @cLOC          = ''
   SET @cCompany1     = ''
   SET @cCompany2     = ''
   SET @cAdd_1a       = ''
   SET @cAdd_1b       = ''
   SET @cAdd_2a       = ''
   SET @cAdd_2b       = ''
   SET @cAdd_3a       = ''
   SET @cAdd_3b       = ''
   SET @cZip          = ''
   SET @cCountry      = ''
   SET @cOption       = ''

   -- Prep next screen var   
   SET @cOutField01 = @cStorerkey 
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
   SET @cOutField05 = '' 
   SET @cOutField06 = '' 
   SET @cOutField07 = '' 
   SET @cOutField08 = '' 
   SET @cOutField09 = '' 
   SET @cOutField10 = '' 
   SET @cOutField11 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 2370
   STORER (Field01)
   STORE  (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cConsigneekey = @cInField02

      --When Consigneekey is blank
      IF @cConsigneekey = ''
      BEGIN
         SET @nErrNo = 69666
         SET @cErrMsg = rdt.rdtgetmessage( 69666, @cLangCode, 'DSP') --Store req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_1_Fail  
      END 

      IF NOT EXISTS (SELECT 1 FROM dbo.STORER WITH (NOLOCK) WHERE Storerkey = @cConsigneekey AND Type = '2')
      BEGIN
             SET @nErrNo = 69667
             SET @cErrMsg = rdt.rdtgetmessage( 69667, @cLangCode, 'DSP') --Invalid Store
             EXEC rdt.rdtSetFocusField @nMobile, 2
             GOTO Step_1_Fail  
      END

      SELECT @cCompany1     = LEFT(RTRIM(Company), 20),
             @cCompany2     = SUBSTRING(RTRIM(Company), 21,20),
             @cAdd_1a       = LEFT(RTRIM(Address1), 20),
             @cAdd_1b       = SUBSTRING(RTRIM(Address1), 21,20),
             @cAdd_2a       = LEFT(RTRIM(Address2), 20),
             @cAdd_2b       = SUBSTRING(RTRIM(Address2), 21,20),
             @cAdd_3a       = LEFT(RTRIM(Address3), 20),
             @cAdd_3b       = SUBSTRING(RTRIM(Address3), 21,20),
             @cZip          = RTRIM(Zip),
             @cCountry      = LEFT(RTRIM(Country), 20)
      FROM dbo.STORER WITH (NOLOCK) 
      WHERE Storerkey = @cConsigneekey 
      AND Type = '2'
        
      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cCompany1
      SET @cOutField03 = @cCompany2
      SET @cOutField04 = @cAdd_1a
      SET @cOutField05 = @cAdd_1b
      SET @cOutField06 = @cAdd_2a
      SET @cOutField07 = @cAdd_2b
      SET @cOutField08 = @cAdd_3a
      SET @cOutField09 = @cAdd_3b
      SET @cOutField10 = @cZip
      SET @cOutField11 = @cCountry

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @cConsigneekey = ''
      SET @cLOC          = ''
      SET @cCompany1     = ''
      SET @cCompany2     = ''
      SET @cAdd_1a       = ''
      SET @cAdd_1b       = ''
      SET @cAdd_2a       = ''
      SET @cAdd_2b       = ''
      SET @cAdd_3a       = ''
      SET @cAdd_3b       = ''
      SET @cZip          = ''
      SET @cCountry      = ''
      SET @cOption       = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cConsigneeKey = ''

      SET @cOutField01 = @cStorerkey
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2371
   STORE    (Field01, 02, 03)
   ADDRESS  (Field04, 05, 06, 07, 08, 09, 10, 11)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --prepare next screen variable
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cStorerKey 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
     SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @cConsigneekey = ''
      SET @cLOC          = ''
      SET @cCompany1     = ''
      SET @cCompany2     = ''
      SET @cAdd_1a       = ''
      SET @cAdd_1b       = ''
      SET @cAdd_2a       = ''
      SET @cAdd_2b       = ''
      SET @cAdd_3a       = ''
      SET @cAdd_3b       = ''
      SET @cZip          = ''
      SET @cCountry      = ''
      SET @cOption       = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2372
   STORE (Field01)
   LOC   (Field02, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02

      --When LOC is blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 69668
         SET @cErrMsg = rdt.rdtgetmessage( 69668, @cLangCode, 'DSP') --LOC req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_3_Fail  
      END 

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC AND Facility = @cFacility)
      BEGIN
             SET @nErrNo = 69669
             SET @cErrMsg = rdt.rdtgetmessage( 69669, @cLangCode, 'DSP') --Invalid TO LOC
             EXEC rdt.rdtSetFocusField @nMobile, 2
             GOTO Step_3_Fail
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cLOC AND Facility = @cFacility AND LocationType = 'DYNPICKP')
      BEGIN
             SET @nErrNo = 69676
             SET @cErrMsg = rdt.rdtgetmessage( 69676, @cLangCode, 'DSP') --Invalid LocType
             EXEC rdt.rdtSetFocusField @nMobile, 2
             GOTO Step_3_Fail
      END

      -- check if location being assigned to other Store
      IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK) WHERE LOC = @cLOC AND Consigneekey = @cConsigneeKey) -- (Vicky03)
      BEGIN
             SET @nErrNo = 69674
             SET @cErrMsg = rdt.rdtgetmessage( 69674, @cLangCode, 'DSP') --LOC Use by Store
             EXEC rdt.rdtSetFocusField @nMobile, 2
             GOTO Step_3_Fail
      END

--      IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK) WHERE LOC = @cLOC AND Consigneekey = @cConsigneeKey) -- (Vicky03)
--      BEGIN
--             SET @nErrNo = 69674
--             SET @cErrMsg = rdt.rdtgetmessage( 69674, @cLangCode, 'DSP') --LOC Use by Store
--             EXEC rdt.rdtSetFocusField @nMobile, 2
--             GOTO Step_3_Fail
--      END

--      IF EXISTS (SELECT 1 FROM dbo.StoreToLOCDetail WITH (NOLOCK) WHERE Consigneekey = @cConsigneeKey AND LOC <> @cLOC) -- (Vicky03)
--      BEGIN
--             SET @nErrNo = 69675
--             SET @cErrMsg = rdt.rdtgetmessage( 69675, @cLangCode, 'DSP') --StoreHasLocAssign
--             EXEC rdt.rdtSetFocusField @nMobile, 2
--             GOTO Step_3_Fail
--      END

      -- (james01)
      IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.LOC = @cLOC
            AND PD.Status < '9')
--      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)
--         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey)
--         WHERE O.StorerKey = @cStorerKey
--            AND O.ConsigneeKey = @cConsigneeKey
--            AND Status < '9')
      BEGIN
         SET @nErrNo = 69677
         SET @cErrMsg = rdt.rdtgetmessage( 69677, @cLangCode, 'DSP') --PTS WITH STORE
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_3_Fail
      END

      -- If LOC not exists
      IF NOT EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK) 
                     WHERE LOC = @cLOC)
      BEGIN
         SET @cOutField01 = @cStorerkey
         SET @cOutField02 = @cConsigneeKey 
         SET @cOutField03 = @cLOC 
         SET @cOutField04 = ''

         -- Remember where we are now
         SET @nPrevScn = @nScn
         SET @nPrevStep = @nStep

         -- Goto next screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2

         GOTO Quit
      END
      ELSE IF EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK) 
                      WHERE Consigneekey <> @cConsigneeKey AND LOC = @cLOC) -- (Vicky03)
      BEGIN
         -- Go to Reset Option Screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         SET @cOutField01 = ''
         SET @cOption = ''

         GOTO QUIT
      END
--      ELSE IF EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK) 
--                      WHERE Consigneekey = @cConsigneeKey)
--      BEGIN
--          SET @nErrNo = 69675
--          SET @cErrMsg = rdt.rdtgetmessage( 69675, @cLangCode, 'DSP') --StoreHasLocAssign
--          EXEC rdt.rdtSetFocusField @nMobile, 2
--          GOTO Step_3_Fail
--      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = @cCompany1
      SET @cOutField03 = @cCompany2
      SET @cOutField04 = @cAdd_1a
      SET @cOutField05 = @cAdd_1b
      SET @cOutField06 = @cAdd_2a
      SET @cOutField07 = @cAdd_2b
      SET @cOutField08 = @cAdd_3a
      SET @cOutField09 = @cAdd_3b
      SET @cOutField10 = @cZip
      SET @cOutField11 = @cCountry

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cLOC = ''

      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2373 (RESET)
   OPTION (Field01, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      IF @cOption = ''
      BEGIN
         SET @nErrNo = 69671
         SET @cErrMsg = rdt.rdtgetmessage( 69671, @cLangCode, 'DSP') --Option req
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_4_Fail  
      END 

      IF @cOption <> '1' AND @cOption <> '9'
      BEGIN
         SET @nErrNo = 69672
         SET @cErrMsg = rdt.rdtgetmessage( 69672, @cLangCode, 'DSP') --Invalid Option
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_4_Fail  
      END 

      IF @cOption = '1'
      BEGIN
         SET @cOutField01 = @cStorerkey
         SET @cOutField02 = @cConsigneeKey 
         SET @cOutField03 = @cLOC 
         SET @cOutField04 = ''

         -- Remember where we are now
         SET @nPrevScn = @nScn
         SET @nPrevStep = @nStep

         -- Goto next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END

      --prepare next screen variable
      SET @cOutField01 = @cStorerkey
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cConsigneekey
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_Fail:
   BEGIN
      SET @cOption = ''

      SET @cOutField01 = ''
    END
END
GOTO Quit

/********************************************************************************
Step 5. screen = 2374
   STORER       (Field01)
   STORE        (Field02)
   LOC          (Field01)
   STORE GROUP  (Field02, input)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cStoreGroup = @cInField04

      --When StoreGroup is blank
      IF @cStoreGroup = ''
      BEGIN
         SET @nErrNo = 69678
         SET @cErrMsg = rdt.rdtgetmessage( 69678, @cLangCode, 'DSP') --STOREGROUP req
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_5_Fail  
      END 

      -- Insert record
      BEGIN TRAN

      IF @nPrevStep = 3
      BEGIN
         -- Insert record
         INSERT INTO dbo.StoreToLocDetail (ConsigneeKey, LOC, Status, AddWho, AddDate, EditWho, EditDate, StoreGroup)
         VALUES (@cConsigneeKey, @cLOC, '1', @cUserName, GETDATE(), @cUserName, GETDATE(), @cStoreGroup)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69670
            SET @cErrMsg = rdt.rdtgetmessage( 69670, @cLangCode, 'DSP') --Ins StoreToLocDetail Fail
            GOTO Step_5_Fail   
         END

         SET @cErrMsg = 'Record Created'

         -- insert to Eventlog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '17', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cToLocation   = @cLOC,
            @cConsigneeKey = @cConsigneeKey,
            --@cRefNo1       = @cConsigneeKey,
            @cRefNo2       = 'ADD',
            @nStep         = @nStep
      END
      ELSE
      BEGIN
         -- Delete record
         BEGIN TRAN

         DELETE FROM dbo.StoreToLocDetail 
         WHERE LOC = @cLOC
         AND   Status =  '1'

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69673
            SET @cErrMsg = rdt.rdtgetmessage( 69673, @cLangCode, 'DSP') --DEL StoreToLocDetail Fail
            GOTO Step_5_Fail   
         END

         -- Insert record
         INSERT INTO dbo.StoreToLocDetail (ConsigneeKey, LOC, Status, AddWho, AddDate, EditWho, EditDate, StoreGroup)
         VALUES (@cConsigneeKey, @cLOC, '1', @cUserName, GETDATE(), @cUserName, GETDATE(), @cStoreGroup)

         IF @@ERROR <> 0
         BEGIN
            ROLLBACK TRAN
            SET @nErrNo = 69670
            SET @cErrMsg = rdt.rdtgetmessage( 69670, @cLangCode, 'DSP') --Ins StoreToLocDetail Fail
            GOTO Step_5_Fail   
         END

         SET @cErrMsg = 'Record Del & Created'

         -- insert to Eventlog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '17', -- Move
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cToLocation   = @cLOC,
            @cConsigneeKey = @cConsigneeKey,
            --@cRefNo1       = @cConsigneeKey,
            @cRefNo2       = 'DEL',
            @nStep         = @nStep
      END

      COMMIT TRAN

      -- initialise all variable
      SET @cConsigneekey = ''
      SET @cLOC          = ''
      SET @cCompany1     = ''
      SET @cCompany2     = ''
      SET @cAdd_1a       = ''
      SET @cAdd_1b       = ''
      SET @cAdd_2a       = ''
      SET @cAdd_2b       = ''
      SET @cAdd_3a       = ''
      SET @cAdd_3b       = ''
      SET @cZip          = ''
      SET @cCountry      = ''
      SET @cOption       = ''

      -- Prep next screen var   
      SET @cOutField01 = @cStorerkey 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = '' 
      SET @cOutField06 = '' 
      SET @cOutField07 = '' 
      SET @cOutField08 = '' 
      SET @cOutField09 = '' 
      SET @cOutField10 = '' 
      SET @cOutField11 = '' 

      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --prepare next screen variable
      IF @nPrevStep = 3
      BEGIN
         SET @cOutField01 = @cConsigneekey
         SET @cOutField02 = '' 
         SET @cLOC = ''

         SET @nScn = @nPrevScn
         SET @nStep = @nPrevStep
      END
      ELSE
      BEGIN
         SET @cOutField01 = ''
         SET @cOption = ''

         SET @nScn = @nPrevScn
         SET @nStep = @nPrevStep
      END

   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cStoreGroup = ''

      SET @cOutField01 = @cStorerkey
      SET @cOutField02 = @cConsigneeKey
      SET @cOutField03 = @cLOC
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

       StorerKey     = @cStorerKey,
       Facility      = @cFacility, 
       Printer       = @cPrinter,    
       -- UserName      = @cUserName,
       
       V_FromScn     = @nPrevScn,
       V_FromStep    = @nPrevStep,

       V_ConsigneeKey = @cConsigneekey,
       V_Loc          = @cLOC,        
       V_String1      = @cCompany1,    
       V_String2      = @cCompany2,    
       V_String3      = @cAdd_1a,      
       V_String4      = @cAdd_1b,      
       V_String5      = @cAdd_2a,      
       V_String6      = @cAdd_2b,      
       V_String7      = @cAdd_3a,      
       V_String8      = @cAdd_3b,      
       V_String9      = @cZip,         
       V_String10     = @cCountry,     
       V_String11     = @cOption, 
       V_String12     = @cStoreGroup,
       --V_String13     = @nPrevScn,
       --V_String14     = @nPrevStep,

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