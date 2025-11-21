SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Capture UCC before ship out. To detect short ship... etc    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2006-08-16 1.0  UngDH      Created                                   */
/* 2008-09-03 1.1  Vicky      Modify to cater for SQL2005 (Vicky01)     */
/* 2016-09-30 1.2  Ung        Performance tuning                        */  
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCOutboundVerify] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @i           INT, 
   @cOption     NVARCHAR( 1), 
   @cScanUCC    NVARCHAR( 5)

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

   @cLoadKey   NVARCHAR( 10), 
   @cUCC       NVARCHAR( 20), 
   @cQTY       NVARCHAR( 5), 
   @cTotalUCC  NVARCHAR( 5), 
   
   @cExternOrderKey1  NVARCHAR( 20), 
   @cExternOrderKey2  NVARCHAR( 20), 
   @cExternOrderKey3  NVARCHAR( 20), 
   @cExternOrderKey4  NVARCHAR( 20), 
   @cExternOrderKey5  NVARCHAR( 20), 
   @cExternOrderKey6  NVARCHAR( 20), 
   @cExternOrderKey7  NVARCHAR( 20), 
   @cExternOrderKey8  NVARCHAR( 20), 
   @cExternOrderKey9  NVARCHAR( 20), 
   @cExternOrderKey10 NVARCHAR( 20), 
   
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

   @cLoadKey   = V_String1, 
   @cUCC       = V_String2, 
   @cQTY       = V_String3, 
   @cTotalUCC  = V_String4, 
   
   @cExternOrderKey1 = V_String5, 
   @cExternOrderKey2 = V_String6, 
   @cExternOrderKey3 = V_String7, 
   @cExternOrderKey4 = V_String8, 
   @cExternOrderKey5 = V_String9, 
   @cExternOrderKey6 = V_String10, 
   @cExternOrderKey7 = V_String11, 
   @cExternOrderKey8 = V_String12, 
   @cExternOrderKey9 = V_String13, 
   @cExternOrderKey10= V_String14, 

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

IF @nFunc = 571  -- UCC Outbound verification
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = UCC Outbound verification
   IF @nStep = 1 GOTO Step_1   -- Scn = 680. LoadKey, ExternOrderKey1..10
   IF @nStep = 2 GOTO Step_2   -- Scn = 681. LoadKey, ExternOrderKey1..10
   IF @nStep = 3 GOTO Step_3   -- Scn = 682. LoadKey, UCC, QTY, Counter
   IF @nStep = 4 GOTO Step_4   -- Scn = 683. Message, option
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 571. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 680
   SET @nStep = 1

   -- Initiate var
   SET @cLoadKey  = ''
   SET @cUCC = ''
   SET @cQTY = ''
   SET @cTotalUCC = ''
   
   SET @cExternOrderKey1 = ''
   SET @cExternOrderKey2 = ''
   SET @cExternOrderKey3 = ''
   SET @cExternOrderKey4 = ''
   SET @cExternOrderKey5 = ''
   SET @cExternOrderKey6 = ''
   SET @cExternOrderKey7 = ''
   SET @cExternOrderKey8 = ''
   SET @cExternOrderKey9 = ''
   SET @cExternOrderKey10 = ''

   -- Init screen
   SET @cOutField01 = '' -- LoadKey
   SET @cOutField02 = '' -- Total ExternOrderKey
   SET @cOutField03 = '' -- ExternOrderKey1
   SET @cOutField04 = '' 
   SET @cOutField05 = '' 
   SET @cOutField06 = '' 
   SET @cOutField07 = '' 
   SET @cOutField08 = '' 
   SET @cOutField09 = '' 
   SET @cOutField10 = '' 
   SET @cOutField11 = '' 
   SET @cOutField12 = '' -- ExternOrderKey10
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 680. Load screen
   LoadKey           (field01)
   Total             (field02)
   ExternOrderKey01  (field03)
   ExternOrderKey02  (field04)
   ExternOrderKey03  (field05)
   ExternOrderKey04  (field06)
   ExternOrderKey05  (field07)
   ExternOrderKey06  (field08)
   ExternOrderKey07  (field09)
   ExternOrderKey08  (field10)
   ExternOrderKey09  (field11)
   ExternOrderKey10  (field12)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cLoadKey = @cInField01

      -- Validate blank
      IF @cLoadKey = '' OR @cLoadKey IS NULL
      BEGIN
         SET @nErrNo = 62176
         SET @cErrMsg = rdt.rdtgetmessage( 62176, @cLangCode,'DSP') --LoadKey needed
         GOTO Step_1_Fail
      END
      
      -- Get load info
      DECLARE @cStatus NVARCHAR( 10)
      SELECT @cStatus = Status
      FROM dbo.LoadPlan (NOLOCK) 
      WHERE LoadKey = @cLoadKey
      
      -- Validate LoadKey
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62177
         SET @cErrMsg = rdt.rdtgetmessage( 62177, @cLangCode,'DSP') -- Invalid Load
         GOTO Step_1_Fail
      END
      
      -- Validate load plan status
      IF @cStatus >= '9' -- 9=Closed, C-Cancel
      BEGIN
         SET @nErrNo = 62178
         SET @cErrMsg = rdt.rdtgetmessage( 62178, @cLangCode,'DSP') -- Load closed
         GOTO Step_1_Fail
      END
         
      -- Validate all pickslip already scan in
      IF EXISTS( SELECT 1
         FROM dbo.LoadPlan LP (NOLOCK)
            INNER JOIN dbo.PickHeader PH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
            LEFT OUTER JOIN dbo.PickingInfo [PI] (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
         WHERE LP.LoadKey = @cLoadKey
            AND [PI].ScanInDate IS NULL)
      BEGIN
         SET @nErrNo = 62179
         SET @cErrMsg = rdt.rdtgetmessage( 62179, @cLangCode,'DSP') -- Not Scan-in
         GOTO Step_1_Fail
      END
         
      -- Validate all pickslip already scan out
      IF EXISTS( SELECT 1
         FROM dbo.LoadPlan LP (NOLOCK)
            INNER JOIN dbo.PickHeader PH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
            LEFT OUTER JOIN dbo.PickingInfo [PI] (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
         WHERE LP.LoadKey = @cLoadKey
            AND [PI].ScanOutDate IS NULL)
      BEGIN
         SET @nErrNo = 62180
         SET @cErrMsg = rdt.rdtgetmessage( 62180, @cLangCode,'DSP') --Not Scan-out
         GOTO Step_1_Fail
      END
         
      -- Reset ExternOrderKey
      SET @cExternOrderKey1 = ''
      SET @cExternOrderKey2 = ''
      SET @cExternOrderKey3 = ''
      SET @cExternOrderKey4 = ''
      SET @cExternOrderKey5 = ''
      SET @cExternOrderKey6 = ''
      SET @cExternOrderKey7 = ''
      SET @cExternOrderKey8 = ''
      SET @cExternOrderKey9 = ''
      SET @cExternOrderKey10 = ''

      -- Get ExternOrderKey
      DECLARE @cExternOrderKey NVARCHAR( 20)
      DECLARE @curExternOrder CURSOR
      SET @curExternOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT OD.ExternOrderKey
         FROM dbo.LoadPlanDetail LPD (NOLOCK) 
            INNER JOIN dbo.OrderDetail OD (NOLOCK) ON (LPD.OrderKey = OD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
      OPEN @curExternOrder
      FETCH NEXT FROM @curExternOrder INTO @cExternOrderKey

      -- Loop ExternOrderKey
      SET @i = 1
      WHILE @@FETCH_STATUS = 0 AND @i <= 10
      BEGIN
         -- Populate ExternOrderKey
         IF @i = 1  SET @cExternOrderKey1  = @cExternOrderKey
         IF @i = 2  SET @cExternOrderKey2  = @cExternOrderKey
         IF @i = 3  SET @cExternOrderKey3  = @cExternOrderKey
         IF @i = 4  SET @cExternOrderKey4  = @cExternOrderKey
         IF @i = 5  SET @cExternOrderKey5  = @cExternOrderKey
         IF @i = 6  SET @cExternOrderKey6  = @cExternOrderKey
         IF @i = 7  SET @cExternOrderKey7  = @cExternOrderKey
         IF @i = 8  SET @cExternOrderKey8  = @cExternOrderKey
         IF @i = 9  SET @cExternOrderKey9  = @cExternOrderKey
         IF @i = 10 SET @cExternOrderKey10 = @cExternOrderKey
            
         SET @i = @i + 1
         FETCH NEXT FROM @curExternOrder INTO @cExternOrderKey
      END
            
      -- Prepare next screen var
      SET @cOutField01 = @cLoadKey
      SET @cOutField03 = @cExternOrderKey1
      SET @cOutField04 = @cExternOrderKey2
      SET @cOutField05 = @cExternOrderKey3
      SET @cOutField06 = @cExternOrderKey4
      SET @cOutField07 = @cExternOrderKey5
      SET @cOutField08 = @cExternOrderKey6
      SET @cOutField09 = @cExternOrderKey7
      SET @cOutField10 = @cExternOrderKey8
      SET @cOutField11 = @cExternOrderKey9
      SET @cOutField12 = @cExternOrderKey10

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLoadKey = ''
      SET @cOutField01 = '' -- LoadKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 680. Load screen
   LoadKey           (field01)
   ExternOrderKey01  (field03)
   ExternOrderKey02  (field04)
   ExternOrderKey03  (field05)
   ExternOrderKey04  (field06)
   ExternOrderKey05  (field07)
   ExternOrderKey06  (field08)
   ExternOrderKey07  (field09)
   ExternOrderKey08  (field10)
   ExternOrderKey09  (field11)
   ExternOrderKey10  (field12)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Get total UCC
      SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(OD.UserDefine01), '') + IsNull( RTRIM(OD.UserDefine02), '')) -- (Vicky01)
      FROM dbo.OrderDetail OD (NOLOCK)
      WHERE OD.LoadKey = @cLoadKey

      -- Get UCC scanned
      SELECT @cScanUCC = COUNT( 1)
      FROM rdt.rdtPPA (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey

      -- Prepare next screen var
      SET @cUCC = ''
      SET @cQTY = ''
      SET @cOutField01 = @cLoadKey
      SET @cOutField02 = '' -- UCC
      SET @cOutField03 = '' -- QTY
      SET @cOutField04 = @cScanUCC + '/' + @cTotalUCC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cLoadKey = ''
      SET @cOutField01 = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 681. UCC screen
   LoadKey (field01)
   UCC     (field02)
   QTY     (field03)
   Counter (field04)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField02

      -- Validate blank
      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 62181
         SET @cErrMsg = rdt.rdtgetmessage( 62181, @cLangCode,'DSP') -- UCC needed
         GOTO Step_3_Fail
      END

      -- Get UCC QTY
      DECLARE @nQTY INT
      SELECT @nQTY = IsNULL( SUM( OD.QtyAllocated + OD.QtyPicked), 0)
      FROM dbo.OrderDetail OD (NOLOCK)
      WHERE LoadKey = @cLoadKey
         AND IsNull( RTRIM(OD.UserDefine01), '') + IsNull( RTRIM(OD.UserDefine02), '') = @cUCC -- (Vicky01)
      
      -- Validate UCC
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 62182
         SET @cErrMsg = rdt.rdtgetmessage( 62182, @cLangCode,'DSP') -- Invalid UCC
         GOTO Step_3_Fail
      END

      -- Validate UCC double scan
      IF EXISTS( SELECT 1 
         FROM rdt.rdtPPA (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND UCC = @cUCC)
      BEGIN
         SET @nErrNo = 62183
         SET @cErrMsg = rdt.rdtgetmessage( 62183, @cLangCode,'DSP') -- Double scan
         GOTO Step_3_Fail
      END

      -- Save
      INSERT INTO rdt.rdtPPA (LoadKey, StorerKey, UCC) VALUES (@cLoadKey, @cStorerKey, @cUCC)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 62184
         SET @cErrMsg = rdt.rdtgetmessage( 62184, @cLangCode,'DSP') -- Ins PPA fail
         GOTO Step_3_Fail
      END

      -- Get UCC scanned
      SELECT @cScanUCC = COUNT( 1)
      FROM rdt.rdtPPA (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey

      -- Refresh current screen var
      SET @cQTY = CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField03 = @cQTY
      SET @cOutField04 = @cScanUCC + '/' + @cTotalUCC

      -- Remain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get UCC scanned
      SELECT @cScanUCC = COUNT( 1)
      FROM rdt.rdtPPA (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LoadKey = @cLoadKey
      
      IF @cScanUCC <> @cTotalUCC
      BEGIN
         -- Prepare next screen var
         DECLARE @nRemain INT
         SET @nRemain = CAST( @cTotalUCC AS INT) - CAST( @cScanUCC AS INT)
         SET @cOutField01 = @cTotalUCC
         SET @cOutField02 = @cScanUCC
         SET @cOutField03 = CAST( @nRemain AS NVARCHAR( 5))
         SET @cOutField04 = '' -- Option

         -- Go to message screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
         
         GOTO Quit
      END
      
      -- Reset Load screen var
      SET @cLoadKey = ''
      SET @cOutField01 = @cLoadKey

      -- Go to Load screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cUCC = ''
      SET @cOutField02 = '' -- UCC
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 683. Message dialog screen
   Total  (field01)
   Scan   (field02)
   Remain (field03)
   Option (field04)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField04

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62185
         SET @cErrMsg = rdt.rdtgetmessage( 62185, @cLangCode, 'DSP') -- Option needed
         GOTO Step_4_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62186
         SET @cErrMsg = rdt.rdtgetmessage( 62186, @cLangCode, 'DSP') -- Invalid Option
         GOTO Step_4_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Prepare Load screen var
         SET @cLoadKey = ''
         SET @cOutField01 = @cLoadKey

         -- Go to Load screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3

         GOTO Quit
      END
   END

   -- Get UCC scanned
   SELECT @cScanUCC = COUNT( 1)
   FROM rdt.rdtPPA (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND LoadKey = @cLoadKey

   -- Prepare prev screen var
   SET @cUCC = ''
   SET @cQTY = ''
   SET @cOutField01 = @cLoadKey
   SET @cOutField02 = '' -- UCC
   SET @cOutField03 = '' -- QTY
   SET @cOutField04 = @cScanUCC + '/' + @cTotalUCC

   -- Go to prev screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1

   GOTO Quit

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField04 = '' -- Option
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

      V_String1   = @cLoadKey, 
      V_String2   = @cUCC, 
      V_String3   = @cQTY, 
      V_String4   = @cTotalUCC,

      V_String5  = @cExternOrderKey1, 
      V_String6  = @cExternOrderKey2, 
      V_String7  = @cExternOrderKey3, 
      V_String8  = @cExternOrderKey4, 
      V_String9  = @cExternOrderKey5, 
      V_String10 = @cExternOrderKey6, 
      V_String11 = @cExternOrderKey7, 
      V_String12 = @cExternOrderKey8, 
      V_String13 = @cExternOrderKey9, 
      V_String14 = @cExternOrderKey10, 

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