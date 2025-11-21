SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_ReplenTo_Inquiry                                  */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Replenishment To Inquiry                                         */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2013-09-23 1.0  Chee     Created                                          */  
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-10-09 1.2  TungGH   Performance                                      */   
/* 2018-12-19 1.3  Ung      Performance tuning                               */
/* 2021-12-03 1.4  James    WMS-18466 Add PickStatus (james01)               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_ReplenTo_Inquiry](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @bSuccess           INT
        
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

   @cLPNNo              NVARCHAR(20),
   @cID                 NVARCHAR(18),
   @cUOM                NVARCHAR(10),
   @cFinalLOC           NVARCHAR(10),
   @cPutawayZone        NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cPickStatus         NVARCHAR(1),
   @cNotCheckPickStatus NVARCHAR(1),
   
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

   @cPickStatus      = V_String1,
   @cNotCheckPickStatus = V_String2,
   
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
IF @nFunc = 1802
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1802
   IF @nStep = 1 GOTO Step_1   -- Scn = 3670  Scan LPN
   IF @nStep = 2 GOTO Step_2   -- Scn = 3671  ReplenTo info
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1802)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 3670
   SET @nStep = 1

   -- Get storer config  
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)  
   SET @cNotCheckPickStatus = rdt.RDTGetConfig( @nFunc, 'NotCheckPickStatus', @cStorerKey)
      
   -- initialise all variable
   SET @cLPNNo = ''
   SET @cID = ''
   SET @cUOM = ''
   SET @cFinalLOC = ''
   SET @cPutawayZone = ''

   -- Prep next screen var 
   SET @cInField01 = ''  
   SET @cOutField01 = '' 
   SET @cOutField02 = '' 
   SET @cOutField03 = '' 
   SET @cOutField04 = '' 
   SET @cOutField05 = '' 
   SET @cOutField06 = '' 

END
GOTO Quit

/********************************************************************************
Step 1. screen = 3670
   REPLEN TO INQUIRY

   LPN: 
   (Field01, input01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLPNNo = @cInField01

      -- Check LPN
      IF ISNULL(@cLPNNo, '') = ''
      BEGIN
         SET @nErrNo = 82801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NEED LPN  
         GOTO Step_1_Fail  
      END

      IF @cNotCheckPickStatus <> '1'
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM PickDetail WITH (NOLOCK) 
                       WHERE StorerKey = @cStorerKey 
                       AND DropID = @cLPNNo 
                       AND Status = @cPickStatus)  -- (james01)
         BEGIN
            SET @nErrNo = 82802  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV LPN  
            GOTO Step_1_Fail  
         END
      END
      
      SELECT
         @cID = TD.ToID,
         @cUOM = TD.UOM,
         @cFinalLOC = TD.LogicalToLoc,
         @cSKU = TD.SKU
      FROM TaskDetail TD (NOLOCK)
      JOIN PickDetail PD (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)
      WHERE PD.StorerKey = @cStorerKey 
      AND PD.DropID = @cLPNNo
      AND TD.TaskType = 'RPF'
      AND TD.Status = '9'

      IF ISNULL(@cID, '') = ''
      BEGIN
         SET @nErrNo = 82803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RPF INCOMPLETE 
         GOTO Step_1_Fail  
      END

      IF NOT EXISTS(SELECT 1 FROM TaskDetail (NOLOCK) WHERE StorerKey = @cStorerKey AND TaskType = 'RP1' AND FromID = @cID)
      BEGIN
         SET @nErrNo = 82804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RP1 NOT GEN 
         GOTO Step_1_Fail  
      END

      IF @cUOM <> '2'
         SELECT @cPutawayZone = PutawayZone FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU  

      -- Prep next screen var 
      SET @cOutField01 = @cID
      SET @cOutField02 = @cLPNNo
      SET @cOutField03 = @cUOM
      SET @cOutField04 = @cFinalLoc

      IF ISNULL(@cPutawayZone, '') <> '' 
      BEGIN
         SET @cOutField05 = 'Zone:'
         SET @cOutField06 = @cPutawayZone
      END

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0 

      SET @cLPNNo = ''
      SET @cID = ''
      SET @cUOM = ''
      SET @cFinalLOC = ''
      SET @cPutawayZone = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cLPNNo = ''
      SET @cID = ''
      SET @cUOM = ''
      SET @cFinalLOC = ''
      SET @cPutawayZone = ''

      SET @cInField01 = ''  
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
   END

END
GOTO Quit

/********************************************************************************
Step 2. screen = 3671
   REPLEN TO INQUIRY

   PALLET ID: 
   (Field01, display01)
   LPN:
   (Field02, display02)
   UOM:
   (Field03, display03)
   Final LOC:
   (Field04, display04)
   (Field05, display05)
   (Field06, display06)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      SET @cLPNNo = ''
      SET @cID = ''
      SET @cUOM = ''
      SET @cFinalLOC = ''
      SET @cPutawayZone = ''

      SET @cInField01 = ''  
      SET @cOutField01 = '' 
      SET @cOutField02 = '' 
      SET @cOutField03 = '' 
      SET @cOutField04 = '' 
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
   END  
   GOTO Quit
   
   Step_2_Fail:
      GOTO Quit
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
      
      V_String1     = @cPickStatus,
      V_String2     = @cNotCheckPickStatus,

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