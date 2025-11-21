SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Copyright: IDS                                                             */  
/* Purpose: SkipJack Split Shipment when Loading  SOS#227562                  */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2011-11-02 1.0  ChewKP     Created                                         */  
/* 2012-02-06 1.1  James      Misc fix (james01)                              */  
/* 2012-02-14 1.2  ChewKP     Misc changes (ChewKP01)                         */  
/* 2012-03-01 1.3  ChewKP     Misc Changes (ChewKP02)                         */  
/* 2012-03-02 1.4  ChewKP     Process Flow Change (ChewKP03)                  */  
/* 2012-03-02 1.5  James      Default door no (james02)                       */  
/* 2012-03-09 1.6  Shong      Bug fixing: Get Default Door, Start SQL Job,    */  
/*                            Update Door Status (Userdefine01)               */  
/* 2012-04-08 1.7  Ung        Remove default door logic                       */  
/*                            Remove IDS_VEHICLE                              */  
/* 2012-04-11 1.8  Shong      Initial OutField01 when back to Screen 1        */  
/* 2012-04-13 1.9  Ung        Change WCS carton overlap by MBOL only          */  
/* 2012-09-21 2.0  ChewKP     SOS#257059  Update EditDate when Status = '3'   */  
/*                            (ChewKP04)                                      */  
/* 2012-09-24 2.1  ChewKP     SOS#257138 Include validation by Lane (ChewKP05)*/  
/* 2012-09-27 2.2  James      SOS#257525 Bug fix (james03)                    */
/* 2016-09-30 2.3  Ung        Performance tuning                              */
/* 2018-11-16 2.4  TungGH     Performance                                     */   
/******************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_TruckLoading] (  
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
   @cOption     NVARCHAR( 1),  
   @nCount      INT,  
   @nRowCount   INT  
  
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
   @cPrinter   NVARCHAR( 20),  
   @cUserName  NVARCHAR( 18),  
  
   @nError        INT,  
   @b_success     INT,  
   @n_err         INT,  
   @c_errmsg      NVARCHAR( 250),  
   @cPUOM     NVARCHAR( 1),  
   @cInCartonNo   NVARCHAR(20),  
   @cMBOLKey      NVARCHAR(10),  
   @cDoorNo       NVARCHAR(10),  
   @cFirstCarton  NVARCHAR(20),  
   @cLastCarton   NVARCHAR(20),  
   @cPlaceOfLoadingQualifier NVARCHAR(10),  
   @cStatus       NVARCHAR(1),  
   @cActDoorNo    NVARCHAR(10),  
   @cLabelNo      NVARCHAR(20),  
   @cJobName      NVARCHAR(100),  
   @nRandom       INT,  
   @nUpper        INT,  
   @nLower        INT,  
   @nSeqFirst     INT, -- (ChewKP02)  
   @nSeqLast      INT, -- (ChewKP02)  
   @nLastAsFirst  NVARCHAR(1), -- (ChewKP03)  
   @cLaneNo       NVARCHAR(10), -- (ChewKP05)  
   @cLaneNoLast   NVARCHAR(10), -- (ChewKP05)  
  
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
   @cPrinter   = Printer,  
   @cUserName  = UserName,  
  
   @cPUOM       = V_UOM,  
   --@cOrderKey   = V_OrderKey,  
  
   @cMBOLKey    = V_String1,  
   @cActDoorNo  = V_String2,  
   @cFirstCarton = V_String3,  
   @cLastCarton  = V_String4,  
   @cInCartonNo  = V_String5,  
   @cDoorNo      = V_String6,  
   @nLastAsFirst = V_String7,  
  
  
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
Declare @n_debug INT  
  
SET @n_debug = 0  
  
  
  
IF @nFunc = 1648  -- TruckLoading  
BEGIN  
   -- Redirect to respective screen  
 IF @nStep = 0 GOTO Step_0   -- Truck Loading  
 IF @nStep = 1 GOTO Step_1   -- Scn = 2920. Door  
 IF @nStep = 2 GOTO Step_2   -- Scn = 2921. MBOLKey  
 IF @nStep = 3 GOTO Step_3   -- Scn = 2922. Carton No  
 IF @nStep = 4 GOTO Step_4   -- Scn = 2924. Sucess Message  
 IF @nStep = 5 GOTO Step_5   -- Scn = 2925. Sucess Message  
  
  
END  
  
--IF @nStep = 3  
--BEGIN  
-- SET @cErrMsg = 'STEP 3'  
-- GOTO QUIT  
--END  
  
  
--RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. func = 912. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Get prefer UOM  
   SET @cPUOM = ''  
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M WITH (NOLOCK)  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
 --SET @cAutoPackConfirm = rdt.RDTGetConfig( @nFunc, 'AutoPackConfirm', @cStorerKey)  
   --SET @nCasePackDefaultQty =  CAST(rdt.RDTGetConfig( @nFunc, 'CasePackDefaultQty', @cStorerKey) AS INT)  
  
   -- Initiate var  
    -- EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep  
  
  
   -- Init screen  
   SET @cOutField01 = ''  
   SET @cOutField02 = ''  
   SET @cOutField03 = ''  
  
   SET @cMBOLKey = ''  
   SET @cDoorNo = ''  
   SET @cActDoorNo = ''  
   SET @cInCartonNo = ''  
   SET @cFirstCarton = ''  
   SET @cLastCarton = ''  
  
   -- Set the entry point  
   SET @nScn = 2920  
   SET @nStep = 1  
  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. Scn = 2920.  
   Door (Input , Field01)  
  
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cActDoorNo = ISNULL(RTRIM(@cInField01),'')  
  
      -- Validate blank  
      IF ISNULL(RTRIM(@cActDoorNo), '') = ''  
      BEGIN  
         SET @nErrNo = 74155  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DoorNo req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      -- (ChewKP01)  
      IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)  
                     WHERE ListName = 'SPLTSHPMNT'  
                     AND Short = @cActDoorNo)  
      BEGIN  
         SET @nErrNo = 74180  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Door  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_1_Fail  
      END  
  
      -- Prepare Next Screen Variable  
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
  
      -- GOTO Next Screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  -- Inputkey = 1  
  
  
   IF @nInputKey = 0  
   BEGIN  
      -- EventLog - Sign In Function  
       EXEC RDT.rdt_STD_EventLog  
        @cActionType = '9', -- Sign in function  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep  
  
      --go to main menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
  
      -- DELETE SCAN TO TRUCK Record WHEN EXIT Status = '1'  
      --DELETE FROM rdt.RDTScanToTruck  
      --WHERE Status = '1'  
   END  
   GOTO Quit  
  
   STEP_1_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
   END  
END  
GOTO QUIT  
  
/********************************************************************************  
Step 2. Scn = 2921.  
   Door    (field01)  
   MBOLKey (field02, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cMBOLKey = ISNULL(RTRIM(@cInField02),'')  
  
      -- Validate blank  
      IF ISNULL(RTRIM(@cMBOLKey), '') = ''  
      BEGIN  
         SET @nErrNo = 74151  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL# req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail  
      END  
  
      IF NOT EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKEY =  @cMBOLKey)  
      BEGIN  
         SET @nErrNo = 74152  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid MBOL#  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail  
      END  
  
      SELECT @cStatus = Status  
      FROM dbo.MBOL WITH (NOLOCK)  
      WHERE MbolKey = @cMBOLKey  
  
      IF @cStatus = '9'  
      BEGIN  
         SET @nErrNo = 74153  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail  
      END  
  
      -- Check same MBOL open in other door  
      IF EXISTS( SELECT * FROM rdt.rdtScanToTruck WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND Door <> @cActDoorNo AND Status = '1')  
      BEGIN  
 SET @nErrNo = 74154  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOLAtDiffDoor  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail  
      END  
  
      UPDATE dbo.MBOL WITH (ROWLOCK)  
      SET PlaceOfLoading = @cActDoorNo  
      WHERE MBOLKey = @cMBOLKey  
     
      IF @@ERROR <> 0  
      BEGIN  
        SET @nErrNo = 74178  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDMBOLFAIL  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_2_Fail  
      END  
  
      -- Prepare Next Screen Variable  
      SET @cFirstCarton = ''  
      SET @cLastCarton = ''  
     
      SELECT @cFirstCarton = RefNo  
      FROM rdt.rdtScanToTruck WITH (NOLOCK)  
      WHERE MBOLKey = @cMBOLKey  
      AND Status = '1'  
     
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = @cMBOLKey  
      SET @cOutField03 = ''  
      SET @cOutField04 = ISNULL(@cFirstCarton,'')  
      SET @cOutField05 = CASE WHEN ISNULL(@cFirstCarton,'') = '' THEN 'SCAN 1ST CARTON NO' ELSE 'SCAN 2ND CARTON NO' END  
  
      -- GOTO Next Screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  -- Inputkey = 1  
  
  
 IF @nInputKey = 0  
   BEGIN  
        -- Prepare Previous Screen Variable  
   SET @cOutField01 = ''  
   SET @cOutField02 = ''  
  
       -- GOTO Previous Screen  
   SET @nScn = @nScn - 1  
     SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   STEP_2_FAIL:  
   BEGIN  
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = ''  
   END  
  
--    END  
END  
GOTO QUIT  
  
  
/********************************************************************************  
Step 3. Scn = 2922.  
   Door         (Field01)  
   MBOLKey      (Field02)  
   SCAN 1ST CARTON NO / SCAN 2ND CARTON NO   (Field05)  
   Carton No    (Field05, input)  
   First Carton (Field04)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      SET @cInCartonNo = ISNULL(RTRIM(@cInField03),'')  
  
      -- Validate blank  
      IF ISNULL(RTRIM(@cInCartonNo), '') = ''  
      BEGIN  
         SET @nErrNo = 74157  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonNo Req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail  
      END  
  
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)  
                     WHERE Storerkey = @cStorerKey  
                     AND LabelNo = @cInCartonNo )  
      BEGIN  
         SET @nErrNo = 74158  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Carton#  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail  
      END  
  
      IF NOT EXISTS (SELECT 1 FROM dbo.WCS_SORTATION WITH (NOLOCK)  
                     WHERE LabelNo = @cInCartonNo)  
      BEGIN  
         SET @nErrNo = 74171  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTNNotArrive  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail  
      END  
  
      --Check If Carton had already processed  -- (ChewKP02)  
      IF EXISTS (SELECT 1 FROM dbo.WCS_Sortation WITH (NOLOCK)  
                 WHERE LabelNo = @cInCartonNo  
                 AND Status = '9')  
      BEGIN  
         SET @nErrNo = 74186  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTNS Proceessed  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail  
      END  
  
      -- Get Seqno  
      DECLARE @nSeqNo INT  
      SET @cLaneNo = ''  
        
      SELECT @nSeqNo = SeqNo,  
             @cLaneNo = ISNULL(LP_LaneNumber,'') -- (ChewKP05)  
      FROM dbo.WCS_Sortation WITH (NOLOCK) WHERE LabelNo = @cInCartonNo  
        
  
      -- Check carton scanned between any processed first and last carton  
      IF EXISTS (SELECT 1   
         FROM rdt.rdtScanToTruck T WITH (NOLOCK)  
         WHERE Status >= '3'  
            AND @nSeqNo BETWEEN   
               (SELECT Top 1 SeqNo FROM dbo.WCS_Sortation W WITH (NOLOCK) WHERE LabelNo = T.RefNo AND LP_LaneNumber = @cLaneNo Order By SeqNo) -- (ChewKP05)  
            AND   
               (SELECT Top 1 SeqNo FROM dbo.WCS_Sortation W WITH (NOLOCK) WHERE LabelNo = T.URNNo AND LP_LaneNumber = @cLaneNo Order By SeqNo)) -- (ChewKP05)  
      BEGIN  
         SET @nErrNo = 74187  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CTNS Proceessed'  
         GOTO Step_3_Fail  
      END  
  
      -- If First Carton Same As Last Carton Go Step 5  
      IF EXISTS (SELECT 1 FROM rdt.RDTScanToTruck WITH (NOLOCK)  
                  WHERE MBolKey  = @cMBOLKey  
                  AND   RefNo    = @cInCartonNo  
                  AND   Status   = '1' )  
      BEGIN  
         -- Prepare Next Screen Variable  
         SET @cOutField01 = @cActDoorNo  
         SET @cOutField02 = @cMBOLKey  
         SET @cOutField03 = @cFirstCarton  
         SET @cOutField04 = ''  
  
         -- GOTO Next Screen  
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2  
  
         GOTO QUIT  
      END  
  
      --- Start  
      IF EXISTS ( SELECT 1 FROM rdt.rdtScanToTruck WITH (NOLOCK)  
                  WHERE MBolKey  = @cMBOLKey  
                  AND   RefNo    = @cFirstCarton  
                  AND   URNNo    = ''  
                  AND   Status   = '1' )  
      BEGIN  
          -- Last Carton SeqNumber cannot be less than first cartons -- (ChewKP02)  
          SET @nSeqFirst = 0  
          SET @nSeqLast = 0  
  
          SET @cLaneNo = ''      -- (ChewKP05)  
          SET @cLaneNoLast = ''  -- (ChewKP05)  
            
          SELECT @nSeqFirst = SeqNo  
                 ,@cLaneNo = ISNULL(LP_LaneNumber,'')       -- (ChewKP05)  
          FROM dbo.WCS_Sortation WITH (NOLOCK)  
          WHERE LabelNo = @cFirstCarton  
  
          SELECT @nSeqLast = SeqNo   
                 ,@cLaneNoLast = ISNULL(LP_LaneNumber,'')   -- (ChewKP05)  
          FROM dbo.WCS_Sortation WITH (NOLOCK)  
          WHERE LabelNo = @cInCartonNo  
  
          IF @nSeqLast < @nSeqFirst  
          BEGIN  
            SET @nErrNo = 74185  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SeqNo'  
            GOTO Step_3_Fail  
          END  
            
          IF @cLaneNo <> @cLaneNoLast  
          BEGIN  
            SET @nErrNo = 74192  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Lane'  
            GOTO Step_3_Fail  
          END  
  
            
          SET @cLastCarton = @cInCartonNo  
  
          -- Get JOB Name from CodeLKUP.ListName = 'SPLTSHPMNT'  
          SELECT @cJobName = ISNULL(Long,'')  
          FROM CodeLkup WITH (NOLOCK)  
          WHERE ListName = 'SPLTSHPMNT'  
          AND Short = @cActDoorNo  
  
          IF @cJobName = ''  
          BEGIN  
            SET @nErrNo = 74179  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoJOBFound'  
            GOTO Step_3_Fail  
          END  
  
          UPDATE rdt.rdtScanToTruck  
          SET URNNo = @cLastCarton,  
              Status = '3',  
              Editdate = GetDate() -- (ChewKP04)  
          WHERE RefNo = @cFirstCarton  
          AND MBOLKEy = @cMBOLKey  
--          AND AddWho = @cUserName  -- cannot use addwho as filtering because the 1st 
                                     -- person scan not need to be the person who end it
          AND Door = @cActDoorNo  -- (james03)

  
          IF @@ERROR <> 0  
          BEGIN  
             SET @nErrNo = 74168  
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Scan2Truck Fail'  
             GOTO Step_3_Fail  
          END  
            
            
  
          -- Post job execute at backend  
          EXEC MASTER.dbo.isp_StartSQLJob @c_ServerName=@@SERVERNAME, @c_JobName=@cJobName  
  
          -- Prepare Next Screen Variable  
          SET @cOutField01 = @cActDoorNo  
          SET @cOutField02 = @cMBOLKey  
          SET @cOutField03 = @cFirstCarton  
          SET @cOutField04 = @cLastCarton  
  
          -- GOTO Next Screen  
          SET @nScn = @nScn + 1  
          SET @nStep = @nStep + 1  
      END  
      ELSE  
      BEGIN  
          -- Check duplicate carton entered (james01)  
          IF EXISTS (SELECT 1 FROM rdt.RDTScanToTruck WITH (NOLOCK)  
                     WHERE (RefNo = @cInCartonNo OR URNNo = @cInCartonNo)) -- (ChewKPXX)  
          BEGIN  
               SET @nErrNo = 74177  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CTNScanned  
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO Step_3_Fail  
          END  
  
          --- If First Carton Scanned  
          SET @cFirstCarton = @cInCartonNo  
  
          INSERT INTO rdt.RdtScanToTruck (MBOLKey, LoadKey, CartonType, RefNo, URNNo, Status, Adddate, Door)  
          VALUES (@cMBOLKey, '', '', @cFirstCarton, '' , '1', GetDate(), @cActDoorNo)  
          IF @@ERROR <> 0  
          BEGIN  
               SET @nErrNo = 74161  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Scan2Truck Fail'  
               GOTO Step_3_Fail  
          END  
  
         -- Prepare Next Screen Variable  
         SET @cOutField01 = @cActDoorNo  
         SET @cOutField02 = @cMBOLKey  
         SET @cOutField03 = ''  
         SET @cOutField04 = @cFirstCarton  
         --SET @cOutField05 = @cLastCarton  
         SET @cOutField05 = CASE WHEN ISNULL(@cFirstCarton,'') = '' THEN 'SCAN 1ST CARTON NO' ELSE 'SCAN LAST CARTON NO' END -- (james02)  
  
      --GOTO Next Screen  
      --SET @nScn = @nScn - 1  
      --SET @nStep = @nStep - 1  
  
      END  
  
 END  -- Inputkey = 1  
  
  
 IF @nInputKey = 0  
 BEGIN  
  
       -- Prepare Previous Screen Variable  
       SET @cOutField01 = @cActDoorNo  
       SET @cOutField02 = ''  
  
  
       -- GOTO Previous Screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
 END  
 GOTO Quit  
  
   STEP_3_FAIL:  
   BEGIN  
  
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = @cMBOLKey  
      SET @cOutField03 = ''  
      SET @cOutField04 = ISNULL(@cFirstCarton,'')  
      SET @cOutField05 = CASE WHEN ISNULL(@cFirstCarton,'') = '' THEN 'SCAN 1ST CARTON NO' ELSE 'SCAN 2ND CARTON NO' END  
  
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = @cMBOLKey  
      SET @cOutField03 = ''  
      SET @cOutField04 = @cFirstCarton  
      --SET @cOutField05 = @cLastCarton  
      SET @cOutField05 = CASE WHEN ISNULL(@cFirstCarton,'') = '' THEN 'SCAN 1ST CARTON NO' ELSE 'SCAN 2ND CARTON NO' END  
   END  
  
  
END  
GOTO QUIT  
  
  
  
/********************************************************************************  
Step 4. Scn = 2923. Message screen  
   Door           (Field01)  
   MBOLKey        (Field02)  
   First CartonNo (Field03)    
   Last  CartonNo (Field04)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 OR  @nInputKey = 0 -- ENTER / ESC    
   BEGIN    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = ''  
      SET @cOutField02 = ''    
      SET @cOutField04 = ''  
          
      SET @cMBOLKey = ''    
      SET @cDoorNo = ''    
      SET @cActDoorNo = ''    
      SET @cInCartonNo = ''    
      SET @cFirstCarton = ''    
      SET @cLastCarton = ''    
          
      -- GOTO Screen 1 MBOLKey Screen    
      SET @nScn = @nScn - 3    
      SET @nStep = @nStep - 3        
   END  
END     
GOTO QUIT    
  
  
/********************************************************************************  
Step 5. Scn = 2924. Confirm first carton and last carton is same  
   Door           (Field01)  
   MBOLKey        (Field02)  
   First CartonNo (Field03)  
   Last Carton Same As First Carton ?  
   Option         (Field04, input) 1=Yes, 2=No  
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1  
   BEGIN  
      SET @cOption = ISNULL(RTRIM(@cInField04),'')  
  
      IF ISNULL(@cOption, '') = ''  
      BEGIN  
         SET @nErrNo = 74159  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option needed'  
         GOTO Step_5_Fail  
      END  
  
      IF @cOption NOT IN ('1', '2')  
      BEGIN  
         SET @nErrNo = 74160  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'  
         GOTO Step_5_Fail  
      END  
  
      IF @cOption = '1' --Yes  
      BEGIN  
         -- Last Carton SeqNumber cannot be less than first cartons -- (ChewKP02)  
         SET @nSeqFirst = 0  
         SET @nSeqLast = 0  
           
         SET @cLaneNo = ''      -- (ChewKP05)  
         SET @cLaneNoLast = ''  -- (ChewKP05)  
           
         SELECT @nSeqFirst = SeqNo  
                ,@cLaneNo = ISNULL(LP_LaneNumber,'')       -- (ChewKP05)  
         FROM dbo.WCS_Sortation WITH (NOLOCK)  
         WHERE LabelNo = @cFirstCarton  
  
         SELECT @nSeqLast = SeqNo   
                ,@cLaneNoLast = ISNULL(LP_LaneNumber,'')   -- (ChewKP05)  
         FROM dbo.WCS_Sortation WITH (NOLOCK)  
         WHERE LabelNo = @cInCartonNo  
  
         IF @nSeqLast < @nSeqFirst  
         BEGIN  
            SET @nErrNo = 74188  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SeqNo'  
           GOTO Step_5_Fail  
         END  
           
         IF @cLaneNo <> @cLaneNoLast  
          BEGIN  
            SET @nErrNo = 74193  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Lane'  
            GOTO Step_3_Fail  
          END  
  
         -- Check Any Carton In between the First and Last Cartons had been proceessed -- (ChewKP02)  
         IF EXISTS (SELECT 1   
            FROM dbo.WCS_Sortation WITH (NOLOCK)  
            WHERE LabelNo Between @cFirstCarton AND  @cInCartonNo  
            AND Status = '9')  
         BEGIN  
            SET @nErrNo = 74189  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CTNS Proceessed'  
            GOTO Step_5_Fail  
         END  
  
         SET @cLastCarton = @cInCartonNo  
  
         -- Get JOB Name from CodeLKUP.ListName = 'SPLTSHPMNT'  
         SELECT @cJobName = ISNULL(Long,'')  
         FROM CodeLkup WITH (NOLOCK)  
         WHERE ListName = 'SPLTSHPMNT'  
         AND Short = @cActDoorNo  
  
         IF @cJobName = ''  
         BEGIN  
            SET @nErrNo = 74190  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoJOBFound'  
            GOTO Step_5_Fail  
         END  
  
          UPDATE rdt.rdtScanToTruck  
          SET URNNo = @cLastCarton,  
              Status = '3',  
              Editdate = GetDate() -- (ChewKP04)   
          WHERE RefNo = @cFirstCarton  
          AND MBOLKEy = @cMBOLKey  
--          AND AddWho = @cUserName  -- cannot use addwho as filtering because the 1st 
                                     -- person scan not need to be the person who end it
          AND Door =  @cActDoorNo   -- (james03)
  
          IF @@ERROR <> 0  
          BEGIN  
               SET @nErrNo = 74191  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Scan2Truck Fail'  
               GOTO Step_5_Fail  
          END  
  
          -- Post job execute at backend  
          EXEC MASTER.dbo.isp_StartSQLJob @c_ServerName=@@SERVERNAME, @c_JobName=@cJobName  
  
          -- Prepare Next Screen Variable  
         SET @cOutField01 = @cActDoorNo  
         SET @cOutField02 = @cMBOLKey  
         SET @cOutField03 = @cFirstCarton  
         SET @cOutField04 = @cLastCarton  
  
          -- GOTO Next Screen  
          SET @nScn = @nScn - 1  
          SET @nStep = @nStep - 1  
      END  
      ELSE IF @cOption = '2'  
      BEGIN  
         -- Prepare Previous Screen Variable  
         SET @cOutField01 = @cActDoorNo  
         SET @cOutField02 = @cMBOLKey  
         SET @cOutField03 = ''  
         SET @cOutField04 = @cFirstCarton  
         SET @cOutField05 = @cLastCarton  
  
  
          -- GOTO Previous Screen  
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 2  
      END  
   END  -- Inputkey = 1  
  
   IF @nInputKey = 0  
   BEGIN  
      -- Prepare Previous Screen Variable  
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = @cMBOLKey  
      SET @cOutField03 = ''  
      SET @cOutField04 = @cFirstCarton  
      SET @cOutField05 = @cLastCarton  
  
      -- GOTO Previous Screen  
      SET @nScn = @nScn - 2  
      SET @nStep = @nStep - 2  
   END  
   GOTO Quit  
  
   STEP_5_FAIL:  
   BEGIN  
      SET @cOutField01 = @cActDoorNo  
      SET @cOutField02 = @cMBOLKey  
      SET @cOutField03 = @cFirstCarton  
      SET @cOutField04 = ''  
   END  
   GOTO Quit  
  
END  
GOTO QUIT  
  
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
      Printer   = @cPrinter,  
      -- UserName  = @cUserName,  
      InputKey  = @nInputKey,  
  
      V_UOM = @cPUOM,  
  
      V_String1 = @cMBOLKey,  
      V_String2 = @cActDoorNo,  
      V_String3 = @cFirstCarton,  
      V_String4 = @cLastCarton,  
      V_String5 = @cInCartonNo,  
      V_String6 = @cDoorNo,  
      V_String7 = @nLastAsFirst,  
  
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