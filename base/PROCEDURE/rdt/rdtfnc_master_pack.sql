SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Master_Pack                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: LCI Master Packing (SOS228355)                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2011-11-15 1.0  James    Created                                     */
/* 2012-02-02 1.1  ChewKP   Various Fixes (ChewKP01)                    */
/* 2012-02-08 1.2  ChewKP   Sent GS1Label Socket Msg to WCS (ChewKP02)  */
/* 2012-02-14 1.3  ChewKP   Enable Re-trigger of MEssage (ChewKP03)     */
/* 2012-02-14 1.4  ChewKP   Fix Counter Issues (ChewKP04)               */
/* 2012-02-15 1.5  Chee     Add FilePath parameter in                   */
/*                          isp_TCPSocket_ClientSocketOut (Chee01)      */
/* 2012-02-15 1.5  ChewKP   Change Master Pack to accomodate Re-Print of*/
/*                          GS1 Label from FunctionID = (ChewKP05)      */
/* 2012-02-24 1.6  ChewKP   Change on WCS CartonConsol (ChewKP06)       */
/* 2012-02-27 1.7  James    Various bug fixes (james01)                 */
/* 2012-02-29 1.8  ChewKP   Update PackDetail.RefNo2 when same MasterLPN*/
/*                          had been print (ChewKP07)                   */
/* 2012-03-01 1.9  ChewKP   Add Weight Input Screen (ChewKP08)          */
/* 06-04-2012 2.0  ChewKP   Extend DropID = 20 (ChewKP09)               */
/* 10-04-2012 2.1  Shong    Change <CR> to NVARCHAR(13)                 */
/* 13-04-2012 2.2  Ung      Fix child lookup (ung01)                    */
/*                          Revise step 7, added rdt.rdtMasterPackLog   */
/*                          Revise CARTONCONSOL message                 */
/*                          Change PackDetail.RefNo2 to be new SSCC no  */
/*                          Fix orphan rescan check                     */
/* 28-05-2012 2.3  Ung      SOS245083 change master and child carton    */
/*                          on tracking no, print GS1 (ung02)           */
/*                          Clean up source                             */
/* 2016-09-30 2.4  Ung      Performance tuning                          */
/* 2018-11-02 2.5  TungGH   Performance                                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_Master_Pack] (
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
   @b_Success        INT,
   @n_err            INT,
   @c_errmsg         NVARCHAR( 250),
   @b_Debug          INT,
   @cOption          NVARCHAR( 1),
   @cDropID          NVARCHAR( 20),
   @cLabelLine       NVARCHAR( 5),
   @cRefno2          NVARCHAR(30),
   @cLabelNo         NVARCHAR( 20),
   @cChild_LabelNo   NVARCHAR( 20),
   @cGS1TemplatePath NVARCHAR( 120),
   @cBatchNo         NVARCHAR( 20),
   @cDataDtl         NVARCHAR( 1000),
   @c_Data_Out       NVARCHAR( 4000),
   @c_MessageNum_Out NVARCHAR( 10)

-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @cPrinter      NVARCHAR( 10),
   @cLabelPrinter NVARCHAR( 10),
   @cPaperPrinter NVARCHAR( 10),
   @cUserName     NVARCHAR( 18),
   
   @cLPN          NVARCHAR( 20),
   @cMPK          NVARCHAR( 20),
   @cType         NVARCHAR( 10), 
   @nFromStep     INT,
   @nFromScn      INT,
   @nLPNCount     INT,
   @nTotalLPN     INT,
--   @cMasterLabelPrinted NVARCHAR( 10),

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
   @cLabelPrinter = Printer,
   @cPaperPrinter = Printer_Paper,
   @cUserName  = UserName,

   @cLPN       = V_String1,
   @cMPK       = V_String2,
   @cType      = V_String3,
   
   @nFromStep  = V_FromStep,
   @nFromScn   = V_FromScn,
      
   @nLPNCount  = V_Integer1,
   @nTotalLPN  = V_Integer2,
--   @cMasterLabelPrinted = V_String8,

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
FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 952  -- LCI Master Packing
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 952. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn = 2970. MPK/LPN/TOTE
   IF @nStep = 2 GOTO Step_2   -- Scn = 2971. LPN (child)
   IF @nStep = 3 GOTO Step_3   -- Scn = 2972. MPK
   IF @nStep = 4 GOTO Step_4   -- Scn = 2973. Message (apply master/child label)
   IF @nStep = 5 GOTO Step_5   -- Scn = 2974. LPN (alone). Conveyable?
   IF @nStep = 6 GOTO Step_6   -- Scn = 2975. Conveyable=Yes. Message apply label
   IF @nStep = 7 GOTO Step_7   -- Scn = 2976. Conveyable=No. Put into tote
   IF @nStep = 8 GOTO Step_8   -- Scn = 2977. Weight
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 953. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
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

 -- EventLog - Sign In Function
 EXEC RDT.rdt_STD_EventLog
   @cActionType = '1', -- Sign in function
   @cUserID     = @cUserName,
   @nMobileNo   = @nMobile,
   @nFunctionID = @nFunc,
   @cFacility   = @cFacility,
   @cStorerKey  = @cStorerKey,
   @nStep       = @nStep

   -- Initialise all variable when start...
   SET @cOutField01 =''

--   SET @cMasterLabelPrinted = ''
   SET @cType = ''

   -- Set the entry point
   SET @nScn = 2970
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 2970. MPK/LPN screen
   MPK/LPN  (field01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Check blank
      IF ISNULL(@cInField01, '') = ''
      BEGIN
         SET @nErrNo = 74701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- LPN required
         GOTO Step_1_Fail
      END

      SET @cMPK = ''
      SET @cLPN = ''

      -- Assume it is Master Case ID
      IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND Refno = @cInField01)
      BEGIN
         SET @cMPK = UPPER(@cInField01)
         SET @cType = 'MASTER'

         -- Get total LPN
         SET @nTotalLPN = 0
         SELECT @nTotalLPN = COUNT( DISTINCT DropID) FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Refno = @cMPK
   
         -- Get LPN count
         SET @nLPNCount = 0
         SELECT @nLPNCount = COUNT( DISTINCT PD.DropID)
         FROM dbo.PackDetail PD WITH (NOLOCK)
            INNER JOIN dbo.DropIDDetail D WITH (NOLOCK) ON D.ChildID = PD.DropID
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Refno = @cMPK

         -- Check if all LPN scanned
         IF @nLPNCount >= @nTotalLPN
         BEGIN
            SET @nErrNo = 74702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Fully Packed
            GOTO Step_1_Fail
         END

         -- Get master label printed
--         SET @cMasterLabelPrinted = ''
--         SELECT @cMasterLabelPrinted = LabelPrinted FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cMPK AND DropIDType = 'MASTER'

         -- Prepare next screen var
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = @cMPK
         SET @cOutField03 = '' --LPN

         -- Go to LPN screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1

         GOTO Quit
      END
      ELSE
      -- Not Master Case ID then it is child LPN
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND DropID = @cInField01
            AND RefNo <> '') --(ung01)
         BEGIN
            SET @cLPN = UPPER(@cInField01)
            SET @cType = 'CHILD'
            
            -- Check if LPN scanned
            IF EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cLPN)
            BEGIN
              SET @nErrNo = 74704
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- LPN Scanned
              GOTO Step_1_Fail
            END

            -- Get MPK
            SELECT @cMPK = UPPER(RefNo) FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cLPN

            -- Get master label printed
--            SET @cMasterLabelPrinted = ''
--            SELECT @cMasterLabelPrinted = LabelPrinted FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cMPK AND DropIDType = 'MASTER'

            -- Get total LPN
            SELECT @nTotalLPN = COUNT( DISTINCT DropID) FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Refno = @cMPK
      
            -- Get LPN count
            SELECT @nLPNCount = COUNT( DISTINCT PD.DropID)
            FROM dbo.PackDetail PD WITH (NOLOCK)
               INNER JOIN dbo.DropIDDetail D WITH (NOLOCK) ON D.ChildID = PD.DropID
            WHERE PD.StorerKey = @cStorerKey
               AND PD.Refno = @cMPK

            -- Increase counter by 1
            SET @nLPNCount = @nLPNCount + 1
            
            -- Prepare next screen var
            SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
            SET @cOutField02 = '' --MPK
            SET @cOutField03 = @cLPN

            -- Go to MPK screen
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
         ELSE
         -- If it is not Master Case ID, not child LPN then check if it Orphan LPN
         BEGIN
            IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                       AND DropID = @cInField01)
            BEGIN
               SET @cLPN = UPPER(@cInField01)
               SET @cType = 'ORPHAN'

               -- Check if LPN scanned
               IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cInField01 AND DropIDType = 'ORPHAN')
               BEGIN
                  SET @nErrNo = 74703
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- LPN Scanned
                  GOTO Step_1_Fail
               END

               -- Remember current scn & step
               SET @nFromScn = @nScn
               SET @nFromStep = @nStep

               -- Go to weight screen
               SET @nScn = @nScn + 7
               SET @nStep = @nStep + 7

               GOTO Quit
            END
            ELSE
            BEGIN
               -- Tote
            	IF EXISTS(SELECT 1 FROM rdt.rdtMasterPackLog WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND Facility = @cFacility
                         AND ToteNo = @cInField01)
               BEGIN
               	SET @cLPN = 'NO'
               	SET @cType = 'TOTE'
               	
                  -- Check if tote closed
                  IF EXISTS (SELECT 1 FROM rdt.rdtMasterPackLog WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey
                         AND Facility = @cFacility
                         AND ToteNo = @cInField01
                         AND Status = '9')
                  BEGIN
                     SET @nErrNo = 74732
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Tote closed
                     GOTO Step_1_Fail
                  END
                  
               	SET @cOutField02 = UPPER(@cInField01) --Tote
               	SET @cOutField03 = '' --Tote full?
               	EXEC rdt.rdtSetFocusField @nMobile, 3 --Tote full?
               	
                  -- Go to tote screen
                  SET @nScn  = @nScn  + 6
                  SET @nStep = @nStep + 6 
               END
               ELSE
               BEGIN
                  SET @nErrNo = 74727
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- Invalid LPN
                  GOTO Step_1_Fail               	
               END
            END
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerKey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''

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

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- LPN
      SET @cMPK = ''
      SET @cLPN = ''
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 2971. LPN (child) screen
   99 OF 99 (field01)
   MPK      (field02)
   LPN      (field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLPN = @cInField03

      -- Check blank
      IF ISNULL(@cLPN, '') = ''
      BEGIN
         SET @nErrNo = 74706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPN is needed
         GOTO Step_2_Fail
      END

      -- Check LPN valid
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cLPN AND Refno = @cMPK)
      BEGIN
         SET @nErrNo = 74707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LPN
         GOTO Step_2_Fail
      END

      -- Check LPN scanned
      IF EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE ChildID = @cLPN )
      BEGIN
         SET @nErrNo = 74708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- LPN Scanned
         GOTO Step_2_Fail
      END

      -- Increase counter by 1
      SET @nLPNCount = @nLPNCount + 1

      IF @nLPNCount = @nTotalLPN
      BEGIN
         SET @cOutField01 = '' -- Weight

         -- Remember current scn & step
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep

         -- Go to weight screen
         SET @nScn = @nScn + 6
         SET @nStep = @nStep + 6
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = @cMPK
         SET @cOutField03 = @cLPN
         SET @cOutField04 = 'TO INNER'
         SET @cOutField05 = 'CARTON'
         SET @cOutField06 = ''

         -- Go to MPK/LPN message screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cMPK = ''
      SET @cLPN = ''
      SET @cOutField01 = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLPN = ''
      SET @cOutField03 = '' -- LPN
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 2972. MPK screen
   99 OF 99 (field01)
   MPK      (field02, input)
   LPN      (field03)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cMPK = @cInField02
      SET @cLPN = @cOutField03

      -- Check MPK blank
      IF ISNULL(@cMPK, '') = ''
      BEGIN
         SET @nErrNo = 74709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MPK IS needed'
         GOTO Step_3_Fail
      END

      -- Check MPK valid
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cLPN AND Refno = @cMPK)
      BEGIN
         SET @nErrNo = 74710
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID MPK'
         GOTO Step_3_Fail
      END

      IF @nLPNCount = @nTotalLPN
      BEGIN
         SET @cOutField01 = '' -- Weight

         -- Remember current scn & step
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep

         -- Go to weight screen
         SET @nScn = @nScn + 5
         SET @nStep = @nStep + 5
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = @cMPK
         SET @cOutField03 = @cLPN
         SET @cOutField04 = 'TO INNER'
         SET @cOutField05 = 'CARTON'
         SET @cOutField06 = ''

         -- Go to MPK/LPN message screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cMPK = ''
      SET @cLPN = ''
      SET @cOutField01 = '' 

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cMPK = ''
      SET @cOutField02 = '' -- MPK
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 2973. MPK/LPN message screen
   99 OF 99            (field01)
   MPK                 (field02)
   LPN                 (field03)
   APPLY GS1/UCC LABEL (field04)
   TO MASTER/INNER     (field04)
   CARTON              (field04)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Print master label upon last LPN
      IF @nLPNCount = @nTotalLPN --@cMasterLabelPrinted <> 'Y'
      BEGIN
         -- Get a new label no for MPK
         EXECUTE isp_GenUCCLabelNo
            @cStorerKey,
            @cRefNo2     OUTPUT,
            @b_Success   OUTPUT,
            @n_Err       OUTPUT,
            @c_ErrMsg    OUTPUT

         -- Update entire master pack RefNo2
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET
            Refno2 = @cRefNo2,
            ArchiveCop = NULL
         WHERE StorerKey = @cStorerKey
            AND Refno = @cMPK
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74711
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode ,'DSP') --'UpdPackDtlFail
            GOTO Quit
         END

         -- Use same Child GS1Label to print. Else nothing will be generated for Master LPN
         SELECT TOP 1 @cLabelNo = LabelNo 
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            --AND DropID = @cLPN
            AND Refno = @cMPK

         -- Get GS1 template file
         SET @cGS1TemplatePath = ''
         SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

         -- Print GS1 label for master carton
         SET @b_success = 0
         EXEC dbo.isp_PrintGS1Label
            @c_DropID    = '',
            @c_PrinterID = @cLabelPrinter,
            @c_BtwPath   = @cGS1TemplatePath,
            @c_PickSlipNo = '',
            @n_CartonNoParm = '',
            @c_MBOLKey = '',
            @b_Success   = @b_success OUTPUT,
            @n_Err       = @nErrNo    OUTPUT,
            @c_Errmsg    = @cErrMsg   OUTPUT,
            @c_LabelNo   = @cLabelNo,
            @c_BatchNo   = @cBatchNo  OUTPUT, -- (ChewKP02)
            @c_WCSProcess = 'Y',
            @c_CartonType = 'MASTER'

         IF @nErrNo <> 0 OR @b_success = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode ,'DSP')
            GOTO Quit
         END

         -- Get master pack UPC (tracking no)
         DECLARE @cUPC NVARCHAR(30)
         SET @cUPC = ''
         SELECT TOP 1 @cUPC = UPC FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND Refno = @cMPK AND UPC <> ''

         -- Update entire master pack UPC
         IF @cUPC <> ''
         BEGIN
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               UPC = @cUPC,
               ArchiveCop = NULL
            WHERE StorerKey = @cStorerKey
               AND Refno = @cMPK
               AND UPC = ''
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74733
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode ,'DSP') --'UpdPackDtlFail
               GOTO Quit
            END
         END

--         SET @cMasterLabelPrinted = 'Y'

         -- Insert master pack dropid  (james01)
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cMPK)
         BEGIN
            INSERT INTO dbo.DROPID (DropID, DropIDType, LabelPrinted, AddWho, AddDate, EditWho, EditDate)
            VALUES (UPPER(@cMPK), 'MASTER', 'Y', 'rdt.' + suser_sname(), GETDATE(), 'rdt.' + suser_sname(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74712
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsDropIDFail
               GOTO Quit
            END
         END
            

         -- Insert child LPN into dropid detail    (james01)
         IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cMPK AND ChildID = @cLPN)
         BEGIN
            INSERT INTO dbo.DropIDDetail (DropID, ChildID, AddWho, AddDate, EditWho, EditDate)
            VALUES (UPPER(@cMPK), UPPER(@cLPN), 'rdt.' + suser_sname(), GETDATE(), 'rdt.' + suser_sname(), GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 74713
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsDIDFail
               GOTO Quit
            END
         END

         UPDATE XML_MESSAGE
            SET STATUS = '0'
         WHERE BATCHNO = @cBatchNo

         SET @cRefNo2 = UPPER(@cRefNo2)
         SET @cMPK    = UPPER(@cMPK)

         EXECUTE dbo.isp_TCP_WCS_GS1_Label_OUT
            @c_BatchNo        = @cBatchNo
          , @b_Debug          = @b_Debug
          , @b_Success        = @b_Success  OUTPUT
          , @n_Err            = @nErrNo     OUTPUT
          , @c_Errmsg         = @cErrMsg    OUTPUT
          , @c_DeleteGS1      = 'N'
          , @c_StorerKey      = @cStorerKey
          , @c_Facility       = @cFacility
          , @c_LabelNo        = @cRefNo2
          , @c_DropID         = @cMPK

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode ,'DSP')
            GOTO Quit
         END
      END

      SET @cChild_LabelNo = ''
      SET @cLabelLine = ''
      SELECT TOP 1 @cChild_LabelNo = LabelNo, @cLabelLine = LabelLine
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cLPN
      AND Refno = @cMPK

      -- Get GS1 template file
      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

      -- Print GS1 label for child carton
      SET @b_success = 0
      EXEC dbo.isp_PrintGS1Label
         @c_DropID    = '',
         @c_PrinterID = @cLabelPrinter,
         @c_BtwPath   = @cGS1TemplatePath,
         @c_PickSlipNo = '',
         @n_CartonNoParm = '',
         @c_MBOLKey = '',
         @b_Success   = @b_success OUTPUT,
         @n_Err       = @nErrNo    OUTPUT,
         @c_Errmsg    = @cErrMsg   OUTPUT,
         @c_LabelNo   = @cChild_LabelNo,
         @c_BatchNo   = @cBatchNo  OUTPUT, -- (ChewKP02)
         @c_WCSProcess = 'Y',
         @c_CartonType = 'CHILD'

      IF @nErrNo <> 0 OR @b_success = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode ,'DSP')
         GOTO Quit
      END

      -- Insert Child LPN (james01)
      IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cMPK AND ChildID = @cLPN )
      BEGIN
         INSERT INTO dbo.DROPIDDetail (DropID, ChildID,  AddWho, AddDate, EditWho, EditDate)
         VALUES (UPPER(@cMPK), UPPER(@cLPN), 'rdt.' + suser_sname(), GETDATE(), 'rdt.' + suser_sname(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74714
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsDropIDFail
            GOTO QUIT
         END
      END

      IF @nLPNCount <> @nTotalLPN
      BEGIN
         SET @cLPN = ''
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = @cMPK
         SET @cOutField03 = '' --LPN

         -- Goto screen 2 for another child LPN
         SET @nStep = @nStep - 2
         SET @nScn = @nScn - 2
      END
      ELSE
      BEGIN
         -- GEN DATA 14 for WCS
         EXECUTE nspg_GetKey
            'TCPOUTLog',
            8,
            @c_MessageNum_Out OUTPUT,
            @b_success        OUTPUT,
            @n_Err            OUTPUT,
            @c_ErrMsg         OUTPUT

         --SET @c_Data_Out = '<STX>' +
         SET @c_Data_Out = LEFT(ISNULL(RTRIM('CARTONCONSOL'), '') + SPACE(15),15) +
                           LEFT(ISNULL(RTRIM(@cStorerKey), '') + SPACE(15),15) +
                           LEFT(ISNULL(RTRIM(@cFacility), '') + SPACE(5),5) +
                           LEFT(UPPER(ISNULL(RTRIM(@cRefNo2), '')) + SPACE(20),20) +
                           '<CR>'

         -- Loop child
         SET @cDataDtl = ''
         DECLARE curChild CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UPPER(DropID)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND RefNo = @cMPK
         OPEN curChild
         FETCH NEXT FROM curChild INTO @cDropID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Get label info
            SET @cLabelNo = ''
            SET @cLabelLine = ''
            SELECT TOP 1
               @cLabelNo = LabelNo,
               @cLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID

            -- Build child string
            SET @cDataDtl = @cDataDtl +
               LEFT(ISNULL(RTRIM(@cLabelLine), '') + SPACE(5),5) +
               LEFT(UPPER(ISNULL(RTRIM(@cDropID), '')) + SPACE(20),20) +
               LEFT(UPPER(ISNULL(RTRIM(@cLabelNo), '')) + SPACE(20),20) + '<CR>'

            FETCH NEXT FROM curChild INTO @cDropID
         END
         CLOSE curChild
         DEALLOCATE curChild

         -- Build TCP message
         SET @c_Data_Out = RTRIM( @c_Data_Out) + RTRIM( LEFT( @cDataDtl, LEN( @cDataDtl) - 4)) -- Take out last <CR>

         -- Insert TCP message
         INSERT INTO TCPSocket_OUTLog (MessageNum, MessageType, Data, Status, StorerKey)
         VALUES (@c_MessageNum_Out, 'SEND', @c_Data_Out, '0', @cStorerKey)

         -- Send TCP message
         EXECUTE dbo.isp_TCP_WCS_CARTONCONSOL_OUT
               @c_MessageNum_Out = @c_MessageNum_Out
             , @b_Debug          = @b_Debug
             , @b_Success        = @b_Success  OUTPUT
             , @n_Err            = @nErrNo     OUTPUT
             , @c_ErrMsg         = @cErrMsg    OUTPUT

         SET @cMPK = ''
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         -- Goto back to MPK/LPN screen
         SET @nStep = @nStep - 3
         SET @nScn = @nScn - 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nLPNCount = @nTotalLPN
      BEGIN
         -- Go back to weight screen
         SET @cOutField01  = '' -- Weight
         SET @nStep = @nStep + 4
         SET @nScn = @nScn + 4
      END
      ELSE IF @cType = 'MASTER'
      BEGIN
         -- Get LPN count
         SELECT @nLPNCount = COUNT( DISTINCT PD.DropID)
         FROM dbo.PackDetail PD WITH (NOLOCK)
            INNER JOIN dbo.DropIDDetail D WITH (NOLOCK) ON D.ChildID = PD.DropID
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Refno = @cMPK
         
         -- Prepare next screen var
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = @cMPK
         SET @cOutField03 = '' --LPN
         
         -- Go back to LPN screen
         SET @nStep = @nStep - 2
         SET @nScn = @nScn - 2
      END
      ELSE IF @cType = 'CHILD'
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = '' --MPK
         SET @cOutField03 = @cLPN

         -- Go back to MPK screen
         SET @nStep = @nStep - 1
         SET @nScn = @nScn - 1
      END
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 2974. Conveyable screen
   MPK   : NO
   LPN         (field01)
   Conveyable? (field02, input)
   1=YES  2=NO
********************************************************************************/
Step_5:
 BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField02

      -- Check blank
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 74717
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OPTION IS REQ'
         GOTO Step_5_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 74718
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID OPTION'
         GOTO Step_5_Fail
      END

      IF @cOption = '1'
      BEGIN
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      
      IF @cOption = '2'
      BEGIN
         SET @cOutField01 = @cLPN
         SET @cOutField02 = '' --Tote
         SET @cOutField03 = '' --Option
         EXEC rdt.rdtSetFocusField @nMobile, 2
         
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cMPK = ''
      SET @cLPN = ''
      SET @cOutField01 = ''

      -- Go back to MPK/LPN screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
   END
   GOTO Quit

   Step_5_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit


/********************************************************************************
Step 6. Scn = 2975. Message screen
   MPK   : NO
   LPN   : XXXXXXXXXX
   
   APPLY GS1/UCC 
   LABEL TO CARTON
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Get LabelNo
      SET @cChild_LabelNo = ''
      SELECT TOP 1 @cChild_LabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cLPN

      -- Get GS1 template file
      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

      -- Print GS1 label for orphan carton
      SET @b_success = 0
      EXEC dbo.isp_PrintGS1Label
         @c_DropID    = '',
         @c_PrinterID = @cLabelPrinter,
         @c_BtwPath   = @cGS1TemplatePath,
         @c_PickSlipNo = '',
         @n_CartonNoParm = '',
         @c_MBOLKey = '',
         @b_Success   = @b_success OUTPUT,
         @n_Err       = @nErrNo    OUTPUT,
         @c_Errmsg    = @cErrMsg   OUTPUT,
         @c_LabelNo   = @cChild_LabelNo,
         @c_BatchNo   = @cBatchNo  OUTPUT, -- (ChewKP02)
         @c_WCSProcess = 'Y',
         @c_CartonType = 'NORMAL'

      IF @nErrNo <> 0 OR @b_success = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode ,'DSP')
         GOTO Quit
      END

      -- Insert Child LPN as Header  (james01)
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cLPN)
      BEGIN
         UPDATE dbo.DROPID SET 
            DropIDType = 'ORPHAN' 
         WHERE DropID = @cLPN
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74730
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- UpdDropIDFail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         INSERT INTO dbo.DROPID (DropID, DropIDType, LabelPrinted, AddWho, AddDate, EditWho, EditDate)
         VALUES (@cLPN, 'ORPHAN', 'Y', 'rdt.' + suser_sname(), GETDATE(), 'rdt.' + suser_sname(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74719
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsDropIDFail
            GOTO Quit
         END
      END

      -- Prepare next screen var
      SET @cMPK = ''
      SET @cLPN = ''
      SET @cOutField01 = ''

      -- Go back to MPK/LPN screen
      SET @nScn = @nScn - 5
      SET @nStep = @nStep - 5
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = @cLPN
      SET @cOutField02 = '' -- Option

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 7. Scn = 2976. Tote screen
   MPK   : NO
   LPN   :           (field02)
   APPLY GS1/UCC 
   LABEL TO CARTON
   TOTE #            (field02, input)
   TOTE FULL (Y/N)   (field03, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cToteNo NVARCHAR( 20)
      
      -- Screen mapping
      SET @cToteNo = @cInField02
      SET @cOption = @cInField03
      
      -- Check tote blank
      IF ISNULL(@cToteNo, '') = '' 
      BEGIN
         SET @nErrNo = 74720
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TOTE # REQ'
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      SET @cOutField02 = @cInField02

      -- Check option blank
      IF ISNULL(@cOption, '') = ''
      BEGIN
         SET @nErrNo = 74721
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OPTION IS REQ'
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 74722
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID OPTION'
         SET @cOutField03 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      SET @cOutField03 = @cInField03

      -- Reclose tote (user forgot to close)
      IF @cType = 'TOTE'
      BEGIN
         IF @cOption = '1' 
      	   GOTO CLOSE_TOTE
      	
      	IF @cOption = '2'
      	BEGIN
            -- Go back to MPK/LPN screen
            SET @cOutField01 = ''
      
            SET @nScn = @nScn - 6
            SET @nStep = @nStep - 6
            
            GOTO Quit
      	END
      END   
      
      -- Get label no
      SET @cLabelNo = ''
      SELECT TOP 1 @cLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cLPN

      -- Get GS1 template file
      SET @cGS1TemplatePath = ''
      SELECT @cGS1TemplatePath = NSQLDescrip FROM RDT.NSQLCONFIG WITH (NOLOCK) WHERE ConfigKey = 'GS1TemplatePath'

      -- Print GS1 label for orphan carton
      SET @b_success = 0
      EXEC dbo.isp_PrintGS1Label
         @c_DropID    = '',
         @c_PrinterID = @cLabelPrinter,
         @c_BtwPath   = @cGS1TemplatePath,
         @c_PickSlipNo = '',
         @n_CartonNoParm = '',
         @c_MBOLKey = '',
         @b_Success   = @b_success OUTPUT,
         @n_Err       = @nErrNo    OUTPUT,
         @c_Errmsg    = @cErrMsg   OUTPUT,
         @c_LabelNo   = @cLabelNo,
         @c_BatchNo   = @cBatchNo  OUTPUT, -- (ChewKP02)
         @c_WCSProcess = 'Y',
         @c_CartonType = 'NORMAL'

      -- Insert child LPN as MASTER
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cLPN)
      BEGIN
         UPDATE dbo.DROPID SET 
            DropIDType = 'ORPHAN' 
         WHERE DropID = @cLPN
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74731
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- UpdDropIDFail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         INSERT INTO dbo.DROPID (DropID, DropIDType, LabelPrinted, AddWho, AddDate, EditWho, EditDate)
         VALUES (@cLPN, 'ORPHAN', 'Y', 'rdt.' + suser_sname(), GETDATE(), 'rdt.' + suser_sname(), GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74729
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsDropIDFail
            GOTO Quit
         END
      END

      -- Insert MasterPackLog
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtMasterPackLog WITH (NOLOCK) WHERE ToteNo = @cToteNo AND DropID = @cLPN AND Status = '0')
      BEGIN
         INSERT INTO rdt.rdtMasterPackLog (StorerKey, Facility, ToteNo, DropID, Status, AddWho, AddDate, EditWho, EditDate)
         VALUES (@cStorerKey, @cFacility, @cToteNo, @cLPN, '0', 'rdt.' + suser_sname(), GETDATE(), 'rdt.' + suser_sname(), GETDATE())
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 74728
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  -- InsMSPkLogFail
            GOTO Quit
         END
      END
      
CLOSE_TOTE:
      IF @cOption = '1' -- Tote full
      BEGIN
         -- GEN DATA 14 for WCS
         EXECUTE nspg_GetKey
            'TCPOUTLog',
            8,
            @c_MessageNum_Out OUTPUT,
            @b_success        OUTPUT,
            @n_Err            OUTPUT,
            @c_ErrMsg         OUTPUT

         --SET @c_Data_Out = '<STX>' +
         SET @c_Data_Out = LEFT(ISNULL(RTRIM('CARTONCONSOL'), '') + SPACE(15),15) +
                           LEFT(ISNULL(RTRIM(@cStorerKey), '') + SPACE(15),15) +
                           LEFT(ISNULL(RTRIM(@cFacility), '') + SPACE(5),5) +
                           LEFT(UPPER(ISNULL(RTRIM(@cToteNo), '')) + SPACE(20),20) +
                           '<CR>'

         -- Loop child
         SET @cDataDtl = ''
         DECLARE curChild CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UPPER(DropID)
            FROM rdt.rdtMasterPackLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND Facility = @cFacility
               AND ToteNo = @cToteNo
               AND Status = '0'
         OPEN curChild
         FETCH NEXT FROM curChild INTO @cDropID
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Get label info
            SET @cLabelNo = ''
            SET @cLabelLine = ''
            SELECT TOP 1
               @cLabelNo = LabelNo,
               @cLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID

            -- Build child string
            SET @cDataDtl = @cDataDtl +
               LEFT(ISNULL(RTRIM(@cLabelLine), '') + SPACE(5),5) +
               LEFT(UPPER(ISNULL(RTRIM(@cDropID), '')) + SPACE(20),20) +
               LEFT(UPPER(ISNULL(RTRIM(@cLabelNo), '')) + SPACE(20),20) + '<CR>'

            FETCH NEXT FROM curChild INTO @cDropID
         END
         CLOSE curChild
         DEALLOCATE curChild

         -- Build TCP message
         SET @c_Data_Out = RTRIM( @c_Data_Out) + RTRIM( LEFT( @cDataDtl, LEN( @cDataDtl) - 4)) -- Take out last <CR>

         -- Insert TCP message
         INSERT INTO TCPSocket_OUTLog (MessageNum, MessageType, Data, Status, StorerKey)
         VALUES (@c_MessageNum_Out, 'SEND', @c_Data_Out, '0', @cStorerKey)

         -- Send TCP message
         EXECUTE dbo.isp_TCP_WCS_CARTONCONSOL_OUT
               @c_MessageNum_Out = @c_MessageNum_Out
             , @b_Debug          = @b_Debug
             , @b_Success        = @b_Success  OUTPUT
             , @n_Err            = @nErrNo     OUTPUT
             , @c_ErrMsg         = @cErrMsg    OUTPUT

         -- Close tote
         UPDATE rdt.rdtMasterPackLog SET
            Status = '9'
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND ToteNo = @cToteNo
            AND Status = '0'
      END
      -- (ung02) end

      -- Go back to MPK/LPN screen
      SET @cOutField01 = ''

      SET @nScn = @nScn - 6
      SET @nStep = @nStep - 6
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cType = 'TOTE'
      BEGIN
         -- Back to MPK/LPN/TOTE screen
         SET @cOutField01 = '' --MPK/LPN/TOTE   
         SET @nScn = @nScn - 6
         SET @nStep = @nStep - 6
      END
      ELSE
      BEGIN
         -- Back to conveyable screen
         SET @cOutField01 = @cLPN
         SET @cOutField02 = '' --Conveyable?
   
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END
   GOTO Quit
END
GOTO Quit


/********************************************************************************
Step 8. Scn = 2978. Weight
   Weight (field01, input)
********************************************************************************/
Step_8:
 BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cWeight NVARCHAR(5)
      DECLARE @fWeight FLOAT
      
      -- Screen mapping
      SET @cWeight = ISNULL(@cInField01,'')

      -- Check blank
      IF ISNULL(@cWeight, '') = ''
      BEGIN
         SET @nErrNo = 74723
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Weight REQ'
         GOTO Step_8_Fail
      END

      -- Check weight valid
      IF RDT.rdtIsValidQTY( @cWeight, 21) = 0
      BEGIN
         SET @nErrNo = 74724
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Weight'
         GOTO Step_8_Fail
      END

      -- Check weight neg
      IF CAST( @cWeight AS FLOAT) < 0
      BEGIN
         SET @nErrNo = 74725
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY must > 0'
         GOTO Step_8_Fail
      END

      SET @fWeight = CAST(@cWeight AS FLOAT  )

      IF @cType IN ('MASTER', 'CHILD')
         UPDATE dbo.PackInfo SET 
            Weight = @fWeight
         FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN PackInfo WITH (NOLOCK) ON (PD.PickSlipNo = PackInfo.PickSlipNo AND PD.CartonNo = PackInfo.CartonNo)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.RefNo = @cMPK
      ELSE
         UPDATE dbo.PackInfo SET 
            Weight = @fWeight
         FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN PackInfo WITH (NOLOCK) ON (PD.PickSlipNo = PackInfo.PickSlipNo AND PD.CartonNo = PackInfo.CartonNo)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.DropID = @cLPN

      IF @@Error <> 0
      BEGIN
         SET @nErrNo = 74726
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail
         GOTO Step_8_Fail
      END

      -- Get PickSlipNo, CartonNo
      DECLARE @cPickSlipNo NVARCHAR( 10) 
      DECLARE @nCartonNo INT
      SET @nCartonNo = 0
      SET @cPickSlipNo = ''
      SELECT 
         @cPickSlipNo = PickSlipNo, 
         @nCartonNo = CartonNo 
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND DropID = @cLPN

      -- Get LabelNo
      DECLARE @cAgile_LabelNo NVARCHAR(20)
      SET @cAgile_LabelNo = ''
      SELECT TOP 1 @cAgile_LabelNo = LabelNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cLPN

      EXEC [dbo].[isp1156P_Agile_Rate]
          @cPickSlipNo
         ,@nCartonNo
         ,@cAgile_LabelNo
         ,@b_Success      OUTPUT
         ,@nErrNo         OUTPUT
         ,@cErrMsg        OUTPUT

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Step_8_Fail
      END

      IF @cType IN ('MASTER', 'CHILD')
      BEGIN
         SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
         SET @cOutField02 = @cMPK
         SET @cOutField03 = @cLPN
         IF @nLPNCount = @nTotalLPN --@cMasterLabelPrinted = 'Y'
         BEGIN
            SET @cOutField04 = 'TO MASTER & INNER'
            SET @cOutField05 = 'CARTON'
            SET @cOutField06 = 'PLACE ON CONVEYOR'
         END
         ELSE
         BEGIN
            SET @cOutField04 = 'TO INNER'
            SET @cOutField05 = 'CARTON'
            SET @cOutField06 = ''
         END

         -- Go to message screen
         SET @nScn  = @nScn - 4
         SET @nStep = @nStep - 4
      END
      
      IF @cType = 'ORPHAN'
      BEGIN
         -- Prepare Next Screen Variable
         SET @cOutField01 = @cLPN
         SET @cOutField02 = '' -- Conveyable

         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nFromStep = 1
      BEGIN
         SET @cOutField01 = '' --MPK/LPN
      END
      ELSE
      BEGIN
         -- Get LPN count
         SELECT @nLPNCount = COUNT( DISTINCT PD.DropID)
         FROM dbo.PackDetail PD WITH (NOLOCK)
            INNER JOIN dbo.DropIDDetail D WITH (NOLOCK) ON D.ChildID = PD.DropID
         WHERE PD.StorerKey = @cStorerKey
            AND PD.Refno = @cMPK
               
         IF @nFromStep = 2
         BEGIN
            SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST( @nTotalLPN AS NVARCHAR(3))
            SET @cOutField02 = @cMPK
            SET @cOutField03 = '' --LPN
         END
   
         IF @nFromStep = 3
         BEGIN
            SET @cOutField01 = CAST( @nLPNCount AS NVARCHAR(3)) + ' OF ' + CAST(@nTotalLPN AS NVARCHAR(3))
            SET @cOutField02 = '' --MPK
            SET @cOutField03 = @cLPN
         END
      END

      SET @nScn = @nFromScn
      SET @nStep = @nFromStep
   END
   GOTO Quit

   Step_8_Fail:
   BEGIN
      SET @cOutField01 = ''
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey   = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cLabelPrinter ,
      Printer_Paper = @cPaperPrinter ,
      -- UserName      = @cUserName,

      V_String1    = @cLPN,
      V_String2    = @cMPK,
      V_String3    = @cType,
      
      V_FromStep   = @nFromStep,
      V_FromScn    = @nFromScn,
      
      V_Integer1   = @nLPNCount,
      V_Integer2   = @nTotalLPN,
--      V_String8    = @cMasterLabelPrinted,

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