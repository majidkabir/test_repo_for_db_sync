SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Copyright: IDS                                                             */    
/* Purpose: AnF Put To Light Put To Store                                     */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date       Rev  Author     Purposes                                        */    
/* 2013-11-25 1.0  ChewKP     Created                                         */    
/* 2014-04-28 1.1  Chee       Bug Fixes  (Chee01)                             */    
/* 2014-05-04 1.2  ChewKP     Validate Tote / Carton only 8 digit (ChewKP01)  */    
/* 2014-05-15 1.3  ChewKP     -No Need to scan PTSLoc when change Tote        */    
/*                            (ChewKP02)                                      */    
/* 2014-05-16 1.4  ChewKP     Update WCSRouting -- (ChewKP03)                 */    
/* 2014-05-22 1.5  ChewKP     Add Validation on Close Carton -- (ChewKP04)    */    
/* 2014-06-03 1.6  ChewKP     DctoDc Tote Pack direct close carton (ChewKP05) */    
/* 2014-06-05 1.7  Chee       Prevent empty wavekey when pickslip has child   */    
/*                            order generated (Chee02)                        */    
/* 2014-06-04 1.8  ChewKP     Include PickDetail.Status = '0' To check        */    
/*                            remaining Task for PTS (ChewKP06)               */    
/* 2014-06-16 1.9  ChewKP     Performance Tuning (ChewKP06)                   */    
/* 2014-07-16 2.0  ChewKP     Check PickQty = PackQty before allow to         */    
/*                            Close Carton (ChewKP07)                         */    
/* 2014-07-25 2.1  Leong      SOS# 316767 - Update WCSRouting before PTLTran. */    
/* 2014-12-12 2.2  ChewKP     Add Validation on DropID when change tote       */    
/*                            (ChewKP08)                                      */    
/* 2015-06-24 2.3  ChewKP     SOS#345886 - Fix Step3 ESC issues (ChewKP09)    */    
/* 2015-06-30 2.3  Leong      SOS#343844 - Revise insert DropId table.        */    
/* 2016-07-21 2.4  ChewKP     SOS#373755 - ANF WholeSale Project (ChewKP10)   */    
/* 2017-03-07 2.5  Ung        Performance tuning                              */   
/* 2021-11-28 2.6  YeeKun     WMS-18432 Add label update (yeekung01)          */   
/******************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_PTL_PTS] (    
   @nMobile    int,    
   @nErrNo     int  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max    
)    
AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE    
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
   @cPUOM         NVARCHAR( 10),    
   @bSuccess      INT,    
    
   @cCartID       NVARCHAR(10),    
   @cLightLoc     NVARCHAR(10),    
   @cToteNo       NVARCHAR(20),    
   @cLightLocKey  NVARCHAR(10),    
   @cPTSZone      NVARCHAR(10),    
   @cAssignmentType NVARCHAR(10),    
   @cDeviceProfileKey NVARCHAR(10),    
   @cModuleAddr       NVARCHAR(5),    
   @nTotalToteCount   INT,    
   @cOptions          NVARCHAR(1),    
   @cAssignDropID     NVARCHAR(20),    
   @cWCS              NVARCHAR(1),    
   @cUCCNo            NVARCHAR(20),    
   @cLabelPrinter     NVARCHAR(10),    
   @cPaperPrinter     NVARCHAR(10),    
   @cObjectID         NVARCHAR(20),    
   @cSKU              NVARCHAR(20),    
   @cOrderGroup       NVARCHAR(20),    
   @cObjectType       NVARCHAR(10),    
   @cSKUDescr         NVARCHAR(60),    
   @cCloseCartonID    NVARCHAR(20),    
   @cNewCartonID      NVARCHAR(20),    
   @cDeviceProfileLogKey  NVARCHAR(10),    
   @cRDTBartenderSP    NVARCHAR(40),    
   @cDefaultTrackNo    NVARCHAR(1),    
   @cExecStatements    NVARCHAR(4000),    
   @cExecArguments     NVARCHAR(4000),    
   @cOrderKey          NVARCHAR(10),    
   @cLoadKey           NVARCHAR(10),    
   @cPickSlipNo        NVARCHAR(10),    
   @n_CntTotal         INT,    
   @n_CntPrinted       INT,    
   @nPendingTote       INT,    
   @cUCCNextLoc        NVARCHAR(10),    
   @cConsigneeKey      NVARCHAR(15),    
   @cPTSLoc            NVARCHAR(10),    
   @cLabelNo           NVARCHAR(20),    
   @cWaveKey           NVARCHAR(10),    
   @cPrevWaveKey       NVARCHAR(10),    
   @cDropIDPTL         NVARCHAR(20),    
   @cSectionKey        NVARCHAR(10),    
   @cOrderType         NVARCHAR(10),    
   @cRegExpression     NVARCHAR(60), -- (ChewKP01)    
   @nSumTotalExpectedQty INT,    
   @nSumTotalPickedQty   INT,    
   @cErrMsg1            NVARCHAR( 20),    
   @cErrMsg2            NVARCHAR( 20),    
   @cErrMsg3            NVARCHAR( 20),    
   @cErrMsg4            NVARCHAR( 20),    
   @cErrMsg5            NVARCHAR( 20),    
   @nUCCQty             INT, -- (ChewKP03)    
   @cWasteStation       NVARCHAR( 10), -- (ChewKP03)    
   @cExtendedUpdateSP   NVARCHAR(30), -- (ChewKP04)    
   @cSQL                NVARCHAR(1000), -- (ChewKP04)    
   @cSQLParam           NVARCHAR(1000), -- (ChewKP04)    
   @nPTLKey             INT,    
   @n_DropIDPacked      INT, -- (ChewKP07)    
   @n_DropIDPicked      INT, -- (ChewKP07)    
   @cPackedLabelNo      NVARCHAR(20), -- (ChewKP07)    
   @cDropLoc            NVARCHAR(20), -- SOS#343844    
   @cUserDefine02 NVARCHAR(20),    
   @cUserDefine09 NVARCHAR(20),    
   @nMixCarton  NVARCHAR(20),    
   @cNewLabelNo NVARCHAR(20),    
   @cChildLabelNo NVARCHAR(20),    
   @nUpdNotes INT,    
   @nCartonNo INT,    
   @nTempCartonNo INT,    
   @cTempLabelNo NVARCHAR(20),    
   @cTempLabelLine NVARCHAR(20),    
   @cTempPickDetailKey NVARCHAR(20),    
   @cTempOrderKey NVARCHAR(20),    
   @cTempOrderLineNumber NVARCHAR(20),    
   @cPrevUserDefine09 NVARCHAR(20),  
    
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
    
   @cPUOM       = V_UOM,    
   @cLoadKey    = V_LoadKey,    
   @cPickSlipNo = V_PickSlipNo,    
   @cSKU        = V_SKU,    
   @cSKUDescr   = V_SKUDescr,    
   @cPTSZone    = V_Zone,    
    
    
   @cToteNo     = V_String1,    
   @cUCCNo      = V_String2,    
   @cObjectID   = V_String3,    
   @cCloseCartonID = V_String4,    
   @cNewCartonID = V_String5,    
   @cDeviceProfileLogKey = V_String6,    
   @cUCCNextLoc  = V_String7,    
   @cConsigneeKey = V_String8,    
   @cWCS          = V_String9,    
   @cPTSLoc       = V_String10,    
   @cObjectType   = V_String11,    
   @cPrevWaveKey  = V_String12,    
   @cExtendedUpdateSP = V_String13,    
   --@nTotalToteCount = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,    
   --@cAssignDropID   = V_String7,    
    
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
    
    
    
IF @nFunc = 816  -- PTL PTS    
BEGIN    
    
   -- Redirect to respective screen    
   IF @nStep = 0 GOTO Step_0   -- PTL - Put To Store    
   IF @nStep = 1 GOTO Step_1   -- Scn = 3730. PTS Zone , Paper Printer , Label Printer    
   IF @nStep = 2 GOTO Step_2   -- Scn = 3731. Tote ID / UCC No    
   IF @nStep = 3 GOTO Step_3   -- Scn = 3732. SKU Information, CLOSE TOTE ID    
   IF @nStep = 4 GOTO Step_4   -- Scn = 3733. New TOID , PTS LOC    
   IF @nStep = 5 GOTO Step_5   -- Scn = 3734. Short Pick    
    
END    
    
--IF @nStep = 3    
--BEGIN    
-- SET @cErrMsg = 'STEP 3'    
-- GOTO QUIT    
--END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. func = 816. Menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Get prefer UOM    
   SET @cPUOM = ''    
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA    
   FROM RDT.rdtMobRec M WITH (NOLOCK)    
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)    
   WHERE M.Mobile = @nMobile    
    
   -- Get WCS StorerConfig    
   SET @cWCS = ''    
    
   SELECT @cWCS = SVALUE    
   FROM dbo.StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND Facility    = @cFacility    
   AND ConfigKey   = 'WCS'    
    
   -- Initiate var    
 -- EventLog - Sign In Function    
   EXEC RDT.rdt_STD_EventLog    
     @cActionType = '1', -- Sign in function    
     @cUserID     = @cUserName,    
     @nMobileNo   = @nMobile,    
     @nFunctionID = @nFunc,    
     @cFacility   = @cFacility,    
     @cStorerKey  = @cStorerkey    
    
   -- (ChewKP05)    
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
   BEGIN    
      SET @cExtendedUpdateSP = ''    
   END    
    
   -- Init screen    
   SET @cOutField01 = ''    
   SET @cOutField02 = ''    
   SET @cOutField03 = ''    
    
   SET @cLoadKey    = ''    
   SET @cPickSlipNo = ''    
   SET @cSKU        = ''    
   SET @cSKUDescr   = ''    
   SET @cPTSZone    = ''    
    
   SET @cToteNo     = ''    
 SET @cUCCNo      = ''    
   SET @cObjectID   = ''    
   SET @cCloseCartonID =  ''    
   SET @cNewCartonID   =  ''    
   SET @cDeviceProfileLogKey = ''    
   SET @cUCCNextLoc   = ''    
   SET @cConsigneeKey = ''    
   --SET @cWCS          = ''    
   SET @cPTSLoc       = ''    
   SET @cObjectType   = ''    
   SET @cPrevWaveKey  = ''    
    
   -- Set the entry point    
   SET @nScn = 3730    
   SET @nStep = 1    
    
   EXEC rdt.rdtSetFocusField @nMobile, 1    
    
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. Scn = 3730.    
   PTSZone  (Input , Field01)    
   Label Printer (Input , Field02)    
   Paper Printer (Input , Field03)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
    
      SET @cPTSZone      = @cInField01    
      SET @cPaperPrinter = @cInField02    
      SET @cLabelPrinter = @cInField03    
    
      IF ISNULL(RTRIM(@cPTSZone),'') = ''    
      BEGIN    
         SET @nErrNo = 83801    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD PTSZONE'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         SET @cPTSZone = ''    
         GOTO STEP_1_FAIL    
      END    
    
      IF NOT EXISTS(SELECT 1 FROM PutawayZone pz WITH (NOLOCK)    
                    WHERE pz.PutawayZone = @cPTSZone)    
      BEGIN    
         SET @nErrNo = 83802    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'BAD PTSZONE'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         SET @cPTSZone = ''    
         GOTO STEP_1_FAIL    
      END    
    
      IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)    
                      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey    
                      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
                      INNER JOIN dbo.PutawayZone PZ WITH (NOLOCK) ON PZ.PutawayZone = Loc.PutawayZone    
                      WHERE Loc.PutawayZone = @cPTSZone    
                      AND DL.Status IN( '1','3') )    
      BEGIN    
         SET @nErrNo = 83842    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTSZoneNotAssigned'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         SET @cPTSZone = ''    
         GOTO STEP_1_FAIL    
      END    
    
      -- If Paper printer scan in    
--      IF ISNULL(@cPaperPrinter, '') = ''    
--      BEGIN    
--         SET @nErrNo = 83807    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter    
--         EXEC rdt.rdtSetFocusField @nMobile, 2    
--         SET @cPaperPrinter = ''    
--         GOTO STEP_1_FAIL    
--      END    
    
      IF ISNULL(@cPaperPrinter, '') <> ''    
      BEGIN    
         -- Check if printer setup correctly    
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cPaperPrinter))    
         BEGIN    
            SET @nErrNo = 83803    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV PAPER PRT'    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
         SET @cPaperPrinter = ''    
            GOTO STEP_1_FAIL    
         END    
    
         -- Overwrite existing printer with the one scanned in    
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET    
            EditDate = GETDATE(),     
            Printer_Paper = @cPaperPrinter    
         WHERE MOBILE = @nMOBILE    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83804    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PRT FAIL'    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            SET @cPaperPrinter = ''    
            GOTO STEP_1_FAIL    
         END    
    
         --SET @cPrinter_Paper = @cPaperPrinter    
      END    
    
       -- If Paper printer scan in    
      IF ISNULL(@cLabelPrinter, '') = ''    
      BEGIN    
         SET @nErrNo = 83808    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
         SET @cLabelPrinter = ''    
         GOTO STEP_1_FAIL    
      END    
    
      -- If Paper printer scan    
      IF ISNULL(@cLabelPrinter, '') <> ''    
      BEGIN    
         -- Check if printer setup correctly    
         IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrinter (NOLOCK) WHERE PrinterID = RTRIM(@cLabelPrinter))    
         BEGIN    
            SET @nErrNo = 83805    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INV LABEL PRT'    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            SET @cLabelPrinter = ''    
            GOTO STEP_1_FAIL    
         END    
    
         -- Overwrite existing printer with the one scanned in    
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET    
            EditDate = GETDATE(),     
            Printer = @cLabelPrinter    
         WHERE MOBILE = @nMOBILE    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83806    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PRT FAIL'    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            SET @cLabelPrinter = ''    
            GOTO STEP_1_FAIL    
         END    
    
         SET @cPrinter = @cLabelPrinter    
      END    
    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
    
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
        @cStorerKey  = @cStorerkey    
    
      -- Terminate All Light before Light Up    
      IF @cPTSZone <> ''    
      BEGIN    
         SET @cPTSLoc = ''    
         SELECT TOP 1 @cPTSLoc = D.DeviceID    
         FROM dbo.DeviceProfile D WITH (NOLOCK)    
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
         --INNER JOIN dbo.PTLTran PTL WITH (NOLOCK) ON PTL.DeviceID = Loc.Loc -- (ChewKPXX)    
         WHERE Loc.PutawayZone = @cPTSZone    
         --AND PTL.DeviceProfileLogKey = @cDeviceProfileLogKey (Chee01)    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran PTL WITH (NOLOCK)    
                         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = PTL.DeviceID    
                         WHERE Loc.PutawayZone = @cPTSZone    
                         AND   PTL.Status IN ( '0', '1', '3') )    
         BEGIN    
            EXEC [dbo].[isp_DPC_TerminateModule]    
                  @cStorerKey    
                 ,@cPTSLoc    
                 ,'0'    
                 ,@b_Success    OUTPUT    
                 ,@nErrNo       OUTPUT    
                 ,@cErrMsg      OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
                SET @cErrMsg = LEFT(@cErrMsg,1024)    
                GOTO Step_1_Fail    
            END    
         END    
      END    
    
      --go to main menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
      SET @cOutField01 = ''    
   END    
   GOTO Quit    
    
   STEP_1_FAIL:    
   BEGIN    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = @cPaperPrinter    
      SET @cOutField03 = @cLabelPrinter    
      --EXEC rdt.rdtSetFocusField @nMobile, 1    
   END    
END    
GOTO QUIT    
    
/********************************************************************************    
Step 2. Scn = 3731.    
   PTSZone / CartID  (field01)    
   Tote ID  / UCCNo  (field02, input)    
    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cObjectID = ISNULL(RTRIM(@cInField02),'')    
      SET @cCloseCartonID = ISNULL(RTRIM(@cInField03),'')    
    
      IF @cObjectID <> '' AND @cCloseCartonID <> ''    
      BEGIN    
             SET @nErrNo = 83846    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ScanOnly1Field'    
             EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
             GOTO Step_2_Fail    
      END    
    
      SET @cObjectType = ''    
    
      IF @cObjectID <> ''    
      BEGIN    
         IF @cObjectID = ''    
         BEGIN    
             SET @nErrNo = 83809    
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteIDOrUCCReq'    
             EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
             GOTO Step_2_Fail           END    
    
         -- Check If All Light Confirm before proceed to next Tote / UCC    
         IF @cDeviceProfileLogKey <> ''    
         BEGIN    
            -- If Scan ObjectID is Prev Trigger Object ID , enable relight , Else block from continuing    
            IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) WHERE DropID <> @cObjectID AND DeviceProfileLogKey = @cDeviceProfileLogKey AND Status = '1' )    
            BEGIN    
                SET @nErrNo = 83839    
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PrevTaskNotComplete'    
                EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
                GOTO Step_2_Fail    
            END    
            ELSE    
            BEGIN    
                 -- (ChewKP06)    
                SET @nPTLKey = 0    
                DECLARE CursorPTLTran CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                   SELECT PTLKey    
                   FROM dbo.PTLTran WITH (NOLOCK)    
                   WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                   AND   DropID              = @cObjectID    
                   AND   Status              = '1'    
                   ORDER BY PTLKey    
    
                OPEN CursorPTLTran    
                FETCH NEXT FROM CursorPTLTran INTO @nPTLKEy    
    
                WHILE @@FETCH_STATUS <> -1    
                BEGIN    
    
                  UPDATE dbo.PTLTran WITH (ROWLOCK)    
                     SET Status = '0'    
                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                  AND DropID = @cObjectID    
                  AND Status = '1'    
                  AND PTLKey = @nPTLKey    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                      SET @nErrNo = 83840    
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'    
                      EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
                      GOTO Step_2_Fail    
                  END    
    
                  FETCH NEXT FROM CursorPTLTran INTO @nPTLKEy    
                END    
                CLOSE CursorPTLTran    
                DEALLOCATE CursorPTLTran    
    
                UPDATE dbo.DropIDDetail WITH (ROWLOCK)    
                SET UserDefine02 = ''    
        WHERE ChildID = @cObjectID    
    
                IF @@ERROR <> 0    
                BEGIN    
                   SET @nErrNo = 86059    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDDetFail'    
                   EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
                   GOTO Step_2_Fail    
                END    
            END    
         END    
    
         IF LEN(ISNULL(RTRIM(@cObjectID),'')) > 8 --IF ISNUMERIC (@cObjectID) = '1'    
         BEGIN    
            SET @cObjectType = 'UCC'    
    
            SELECT TOP 1 @cLoadKey    = O.LoadKey    
                        ,@cPickSlipNo = PD.PickSlipNo    
                        ,@cWaveKey    = O.USerDefine09    
            FROM dbo.PickDetail PD WITH (NOLOCK)    
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
            WHERE PD.DropID = @cObjectID    
            AND   PD.StorerKey = @cStorerKey    
            AND   PD.Status = '3'    
         END    
         ELSE    
         BEGIN    
             SET @cObjectType = 'TOTE'    
    
--            SELECT TOP 1 @cLoadKey    = O.LoadKey    
--                              ,@cPickSlipNo = PD.PickSlipNo    
--                              ,@cWaveKey    = O.USerDefine09    
--            FROM dbo.PickDetail PD WITH (NOLOCK)    
--            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
--            WHERE PD.DropID = @cObjectID    
--            AND   PD.StorerKey = @cStorerKey    
--            AND   PD.Status = '5'    
    
              SELECT TOP 1  @cLoadKey    = LoadKey    
                           ,@cPickSlipNo = PickSlipNo    
               --            ,@cWaveKey    = O.USerDefine09    
              FROM dbo.DropID WITH (NOLOCK)    
              WHERE DropID = @cObjectID    
AND   Status = '5'    
    
              SELECT TOP 1 @cWaveKey = O.UserDefine09    
              FROM dbo.PickDetail PD WITH (NOLOCK)    
              INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKEy = PD.OrderKey    
              WHERE PD.PickSlipNo = @cPickSlipNo    
              AND   PD.Status = '5'    
              AND   O.Type <> 'CHDORD' -- (Chee02)    
         END    
    
         IF @cDeviceProfileLogKey = ''    
         BEGIN    
            SET @cPrevWaveKey = @cWaveKey    
         END    
         ELSE    
         BEGIN    
            IF @cWaveKey <> @cPrevWaveKey    
            BEGIN    
               SET @nErrNo = 83841    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ObjNotSameWaveKey'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
         END    
    
         SET @cToteNo = ''    
         SET @cUCCNo  = ''    
    
         IF @cObjectType = 'TOTE'    
         BEGIN    
   --         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cObjectID    
   --                         AND Status = '3' )    
   --         BEGIN    
   --            SET @nErrNo = 83811    
   --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNotPciked'    
   --            GOTO Step_2_Fail    
   --         END    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.StoreToLocDetail STL WITH (NOLOCK)    
                            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.UserDefine02 = STL.ConsigneeKey    
                            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
                            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey    
                            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc    
                            WHERE PD.DropID = @cObjectID    
                            AND   PD.PickSlipNo = @cPickSlipNo    
                            AND   O.LoadKey = @cLoadKey    
                            AND   PD.Status = '5'    
                            AND   PD.CaseID = ''    
            AND   STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END    
                            AND   Loc.PutawayZone = @cPTSZone )    
            BEGIN    
               SET @nErrNo = 86057    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongPTSZone'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cObjectID    
                            AND Status = '5' )    
            BEGIN    
               SET @nErrNo = 83811    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidTote'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
          IF NOT EXISTS ( SELECT 1 FROM PickDetail WITH (NOLOCK)    
                            WHERE StorerKey = @cStorerKey    
                            AND DropID = @cObjectID    
                            AND Status = '5' )    
            BEGIN    
               SET @nErrNo = 83816    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNotPick'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            SET @cToteNo = @cObjectID    
    
            -- (ChewKP05)    
            -- Extended Update Functions    
            IF @cExtendedUpdateSP <> ''    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
               BEGIN    
                  SET @cSKU = ''    
    
                  SELECT Top 1 @cOrderType    = O.Type    
                  FROM dbo.OrderDetail OD WITH (NOLOCK)    
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber    
                  WHERE PD.PickSlipNo        = @cPickSlipNo    
                  AND PD.DropID              = @cToteNo    
                  AND ISNULL(PD.CaseID, '')  = ''    
    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cObjectType, @cPickSlipNo, @cToteNo, @cLoadKey, @cWaveKey, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
                  SET @cSQLParam =    
                     '@nMobile        INT, ' +    
                     '@nFunc          INT, ' +    
                     '@cLangCode      NVARCHAR( 3), ' +    
                     '@cUserName      NVARCHAR( 18), ' +    
                     '@cFacility      NVARCHAR( 5), ' +    
                     '@cStorerKey     NVARCHAR( 15), ' +    
                     '@cObjectType    NVARCHAR( 10), ' +    
                     '@cPickSlipNo    NVARCHAR( 10), ' +    
                     '@cToteNo        NVARCHAR( 20), ' +    
                     '@cLoadKey       NVARCHAR( 10),  ' +    
                     '@cWaveKey       NVARCHAR( 10), ' +    
                     '@nErrNo         INT           OUTPUT, ' +    
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                       @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cObjectType, @cPickSlipNo, @cToteNo, @cLoadKey, @cWaveKey, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                  IF @nErrNo <> 0    
                  BEGIN    
                     GOTO QUIT    
                  END    
    
                  IF @cOrderType = 'DcToDc'    
                  BEGIN    
                     -- Return to Same Screen    
                     SET @cOutField01 = @cPTSZone    
                     SET @cOutField02 = ''    
                     SET @cOutField03 = ''    
    
                     GOTO QUIT    
                  END    
               END    
            END    
         END    
    
         IF @cObjectType = 'UCC'    
         BEGIN    
            IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cObjectID )    
            BEGIN    
               SET @nErrNo = 83812    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCNotExists'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)    
                            WHERE UCCNo = @cObjectID    
                            AND Status = '6' )    
            BEGIN    
               SET @nErrNo = 83813    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            IF NOT EXISTS ( SELECT 1 FROM PickDetail WITH (NOLOCK)    
                            WHERE StorerKey = @cStorerKey    
                            AND DropID = @cObjectID    
                            AND Status = '3' )    
            BEGIN    
               SET @nErrNo = 83815    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCNotPick'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.DropIDDetail DD WITH (NOLOCK)    
                            INNER JOIN dbo.DropID D WITH (NOLOCK) ON D.DropID = DD.DropID    
                            WHERE DD.ChildID = @cObjectID    
                            AND D.Status = '9' )    
            BEGIN    
               SET @nErrNo = 83814    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            IF EXISTS ( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK)    
                        WHERE ChildID = @cObjectID    
                        AND UserDefine02 = '1' )    
            BEGIN    
               SET @nErrNo = 83837    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCScanned'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            IF NOT EXISTS ( SELECT 1 FROM dbo.StoreToLocDetail STL WITH (NOLOCK)    
                            INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.UserDefine02 = STL.ConsigneeKey    
                            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
                            INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = O.OrderKey    
                            INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = STL.Loc    
                            WHERE PD.DropID = @cObjectID    
                            AND   PD.PickSlipNo = @cPickSlipNo    
                            AND   O.LoadKey = @cLoadKey    
                            AND   PD.Status = '3'    
                            AND PD.CaseID = ''    
                            AND   STL.StoreGroup = CASE WHEN O.Type = 'N' THEN RTRIM(O.OrderGroup) + RTRIM(O.SectionKey) ELSE 'OTHERS' END    
                            AND   Loc.PutawayZone = @cPTSZone  )    
            BEGIN    
               SET @nErrNo = 86058    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'WrongPTSZone'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            SET @cUCCNo = @cObjectID    
    
            SET @cSKU = ''    
            SET @cSKUDescr = ''    
    
            SELECT @cSKU = UCC.SKU    
             ,@cSKUDescr = SKU.Descr    
            FROM dbo.UCC UCC WITH (NOLOCK)    
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.SKU = UCC.SKU AND SKU.StorerKey = UCC.StorerKey    
            WHERE UCC.UCCNo = @cUCCNo    
    
            SET @cUCCNextLoc = ''    
            SET @nUCCQty     = 0    
            SET @nSumTotalExpectedQty = 0    
    
            -- (ChewKP03)    
            SELECT @nUCCQty = Qty    
            FROM dbo.UCC WITH (NOLOCK)    
            WHERE UCCNo = @cUCCNo    
    
            SELECT @nSumTotalExpectedQty = SUM(Qty)    
            FROM dbo.PickDetail WITH (NOLOCK)    
            WHERE DropID = @cUCCNo    
            AND PickSlipNo = @cPickSlipNo    
    
            IF  (ISNULL(@nUCCQty,0)  <> ISNULL(@nSumTotalExpectedQty,0) )    
            BEGIN    
               -- Get Next Loc    
               IF @cWCS = '1'    
               BEGIN    
                  SELECT @cUCCNextLoc = Short    
                  FROM dbo.CodeLkup WITH (NOLOCK)    
                  WHERE Listname = 'WCSROUTE'    
                  AND Code = 'WCS'    
                  -- Insert WCS Routing for Putaway --    
               END    
               ELSE    
               BEGIN    
                  -- Get UCCLoc by PickDetail.DropID = UCCNo , OrderKEy , LoadKey and Refer back to WCSRoute    
                  SET @cOrderGroup = ''    
                  SET @cSectionKey = ''    
                  SET @cOrderType  = ''    
    
                  SELECT TOP 1 @cOrderGroup = O.OrderGroup   , @cSectionKey = O.SectionKey, @cOrderType = O.Type    
                  FROM dbo.PickDetail PD WITH (NOLOCK)    
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey AND O.StorerKey = PD.StorerKey    
                  WHERE PD.DropID  = @cUCCNo    
                  AND PD.StorerKey = @cStorerKey    
    
                  SELECT @cUCCNextLoc = Short    
                  FROM dbo.CodeLkup WITH (NOLOCK)    
                  WHERE Listname = 'WCSROUTE'    
                  AND Code = CASE WHEN @cOrderType = 'N' THEN ISNULL(RTRIM(@cOrderGroup),'') + ISNULL(RTRIM(@cSectionKey),'') ELSE 'OTHERS' END    
               END    
            END    
            ELSE    
            BEGIN    
               IF @cWCS = '1'    
               BEGIN    
                  SET @cWasteStation = ''    
    
                  SELECT @cWasteStation = Short    
                  FROM dbo.Codelkup WITH (NOLOCK)    
                  WHERE ListName = 'WCSRoute'    
                  AND Code = 'EMPTY'    
    
                  SET @cUCCNextLoc = @cWasteStation    
               END    
            END    
         END    
    
         INSERT INTO TraceInfo (TraceName, TimeIn, TotalTime, Step1, Col1, Col2, Col3, Col4, Col5) -- SOS# 316767    
         VALUES ('rdtfnc_PTL_PTS', GETDATE(), '*UpdWCS*', @cWCS, @cPTSZone, @cObjectType, @cObjectID, @nMobile, @cUserName)    
    
         -- Update WCSRouting -- (ChewKP02) -- SOS# 316767    
         IF @cWCS = '1'    
         BEGIN    
            -- Update WCSRouting , WCSRoutingDetail    
            UPDATE dbo.WCSRoutingDetail    
            SET Status = '9'    
            WHERE ToteNo = @cObjectID    
            AND Status = '0'    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 86069    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRODetFail'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            UPDATE dbo.WCSRouting    
            SET Status = '9'    
            WHERE ToteNo = @cObjectID    
            AND Status = '0'    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 86070    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSROFail'    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
         END    
    
         -- Insert Into PTLTran    
         EXEC [RDT].[rdt_PTL_PTS_InsertPTLTran]    
              @nMobile     =  @nMobile    
             ,@nFunc       =  @nFunc    
             ,@cFacility   =  @cFacility    
             ,@cStorerKey  =  @cStorerKey    
             ,@cPTSZone    =  @cPTSZone    
             ,@cDropID     =  @cObjectID    
             ,@cDropIDType =  @cObjectType    
             ,@cUserName   =  @cUserName    
             ,@cLangCode   =  @cLangCode    
             ,@nErrNo      =  @nErrNo       OUTPUT    
             ,@cErrMsg     =  @cErrMsg      OUTPUT    
             ,@cDeviceProfileLogKey = @cDeviceProfileLogKey OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            --EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Step_2_Fail    
         END    
    
         -- Terminate All Light before Light Up    
         SET @cPTSLoc = ''    
         SELECT TOP 1 @cPTSLoc = D.DeviceID    
         FROM dbo.DeviceProfile D WITH (NOLOCK)    
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
         INNER JOIN dbo.PTLTran PTL WITH (NOLOCK) ON PTL.DeviceID = Loc.Loc    
         WHERE Loc.PutawayZone = @cPTSZone    
         --AND PTL.DeviceProfileLogKey = @cDeviceProfileLogKey    
    
         EXEC [dbo].[isp_DPC_TerminateModule]    
               @cStorerKey    
              ,@cPTSLoc    
              ,'0'    
              ,@b_Success    OUTPUT    
              ,@nErrNo       OUTPUT    
              ,@cErrMsg      OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
             SET @cErrMsg = LEFT(@cErrMsg,1024)    
             EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
             GOTO Step_2_Fail    
         END    
    
         -- Initial Light Command Start    
         EXEC [RDT].[rdt_PTL_PTS_LightUp]    
              @nMobile              =  @nMobile    
             ,@nFunc                =  @nFunc    
             ,@cFacility            =  @cFacility    
             ,@cStorerKey           =  @cStorerKey    
             ,@cPTSZone             =  @cPTSZone    
             ,@cDropID              =  @cObjectID    
             ,@cDropIDType          =  @cObjectType    
             ,@cDeviceProfileLogKey =  @cDeviceProfileLogKey    
             ,@cUserName            =  @cUserName    
             ,@cLangCode            =  @cLangCode    
             ,@nErrNo               =  @nErrNo       OUTPUT    
             ,@cErrMsg              =  @cErrMsg      OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
    
         -- Prepare Next Screen Variable    
         SET @cOutField01 = @cPTSZone    
         SET @cOutField02 = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
         SET @cOutField03 = CASE WHEN @cObjectType = 'TOTE' THEN 'MIXED SKU' ELSE @cSKU END    
         SET @cOutField04 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20)  END    
         SET @cOutField05 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 20) END    
         SET @cOutField06 = @cUCCNextLoc-- Residual UCC Location    
         SET @cOutField07 = ''    
    
          -- GOTO Next Screen    
          SET @nScn = @nScn + 1    
          SET @nStep = @nStep + 1    
      END    
    
      IF @cCloseCartonID <> ''    
      BEGIN    
         SELECT @cLoadKey = LoadKey    
               ,@cPickSlipNo = PickSlipNo    
         FROM dbo.DropID WITH (NOLOCK)    
         WHERE DropID = @cCloseCartonID    
    
         SELECT @cDeviceProfileLogKey = DeviceProfileLogKey    
         FROM dbo.DeviceProfileLog WITH (NOLOCK)    
         WHERE DropID = @cCloseCartonID    
         AND UserDefine02 = @cLoadKey    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                         WHERE DropID = @cCloseCartonID    
                         AND Status = '3'    
                         AND DeviceProfileLogKey = @cDeviceProfileLogKey)    
         BEGIN    
            SET @nErrNo = 83847    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                         WHERE PickSlipNo = @cPickSlipNo    
                         AND DropID = @cCloseCartonID )    
         BEGIN    
            SET @nErrNo = 83848    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNotPack'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
    
         IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                     WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                     AND Status = '1' )    
         BEGIN    
            SET @nErrNo = 86061    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackNotComplete'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
    
         SET @nPendingTote = 0    
         SET @cConsigneeKey = ''    
    
         SELECT @cConsigneeKey = ConsigneeKey    
         FROM dbo.DeviceProfileLog WITH (NOLOCK)    
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
         AND DropID = @cCloseCartonID    
         AND UserDefine02 = @cLoadKey    
    
         -- If Still Item to Pack , Prompt Error    
         IF EXISTS ( SELECT 1    
                     FROM dbo.PickDetail PD WITH (NOLOCK)    
                     INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
                     INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)    
                     WHERE PD.PickslipNo = @cPickSlipNo    
                     AND PD.Status IN ( '0', '3', '5' ) -- (ChewKP06)    
                     AND O.LoadKey = @cLoadKey    
                     AND OD.UserDefine02 = @cConsigneeKey    
                     AND PD.CaseID = ''    
                     AND PD.Qty <> 0 )    
         BEGIN    
            SET @nErrNo = 86062    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackNotComplete'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
         -- Short Pack on Carton --    
--         IF EXISTS ( SELECT 1 FROM dbo.PTLTRan WITH (NOLOCK)    
--                     WHERE PTL_Type = 'Pick2PTS'    
--                     AND DropID = @cCloseCartonID    
--                     AND SKU <> 'FTOTE'    
--                     AND DeviceProfileLogKey = @cDeviceProfileLogKey    
--                     AND ExpectedQty <> Qty )    
--         BEGIN    
--    
--            SET @cOutField01 = @cCloseCartonID    
--    
--            -- GOTO Screen 5    
--            SET @nScn = @nScn + 2    
--            SET @nStep = @nStep + 2    
--    
--            GOTO QUIT    
--    
--         END    


         -- Extended Update Functions    
         IF @cExtendedUpdateSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
            BEGIN    
               SET @cSKU = ''    
    
               SELECT Top 1 @cOrderType    = O.Type    
               FROM dbo.OrderDetail OD WITH (NOLOCK)    
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = OD.OrderKey    
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber    
               WHERE PD.PickSlipNo        = @cPickSlipNo    
               AND PD.DropID              = @cToteNo    
               AND ISNULL(PD.CaseID, '')  = ''    
    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cObjectType, @cPickSlipNo, @cToteNo, @cLoadKey, @cWaveKey,@cCloseCartonID, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @cSQLParam =    
                  '@nMobile        INT, ' +    
                  '@nFunc          INT, ' +    
                  '@cLangCode      NVARCHAR( 3), ' +    
                  '@cUserName      NVARCHAR( 18), ' +    
                  '@cFacility      NVARCHAR( 5), ' +    
                  '@cStorerKey     NVARCHAR( 15), ' +    
                  '@cObjectType    NVARCHAR( 10), ' +    
                  '@cPickSlipNo    NVARCHAR( 10), ' +    
                  '@cToteNo        NVARCHAR( 20), ' +    
                  '@cLoadKey       NVARCHAR( 10),  ' +    
                  '@cWaveKey       NVARCHAR( 10), ' +    
                  '@cCloseCartonID NVARCHAR( 20), ' +
                  '@nErrNo         INT           OUTPUT, ' +    
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cObjectType, @cPickSlipNo, @cToteNo, @cLoadKey, @cWaveKey,
                     @cCloseCartonID, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
               BEGIN    
                  GOTO QUIT    
               END    
            END    
         END  
  
         SET @cPackedLabelNo   = ''    
    
         SELECT Top 1 @cPackedLabelNo = LabelNo    
         FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
         AND DropID = @cCloseCartonID    
         AND StorerKey = @cStorerKey    
  
  
         DECLARE @tMixCarton1 TABLE ( UserDefine NVARCHAR( 36))    
    
    
         SELECT @nCartonNo = CartonNo      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         AND   LabelNo = @cLabelNo     
    
         DELETE FROM @tMixCarton1      
         INSERT INTO @tMixCarton1 (UserDefine)      
  SELECT OD.userdefine02 + OD.userdefine09      
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)      
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
         WHERE PD.Storerkey = @cStorerKey      
         AND   PD.CaseID = @cPackedLabelNo      
         AND   PD.[Status] = '5'      
         AND   LPD.LoadKey = @cLoadKey      
         GROUP BY OD.userdefine02 , OD.userdefine09      
    
         SELECT @nCount = COUNT(1) FROM @tMixCarton1      
               
         IF @nCount = 1      
            SET @nMixCarton = 0      
         ELSE      
            SET @nMixCarton = 1      
    
         SELECT       
            @cUserDefine02 = MAX( OD.UserDefine02),      
            @cUserDefine09 = MAX( OD.UserDefine09)      
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)      
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
         WHERE PD.Storerkey = @cStorerKey      
         AND   PD.CaseID = @cPackedLabelNo      
         AND   PD.[Status] = '5'      
         AND   LPD.LoadKey = @cLoadKey      
         GROUP BY OD.userdefine02 , OD.userdefine09      
    
         IF @nMixCarton = 0      
         BEGIN      
            IF EXISTS ( SELECT 1       
                        FROM dbo.STORER WITH (NOLOCK)      
                        WHERE StorerKey = @cUserDefine09      
                        AND   SUSR1 = 'C')      
            BEGIN      
               SET @nErrNo = 0      
               SET @cNewLabelNo = 'x' -- Pass in random value to avoid error            
               -- Generate ANF UCC Label No                
               EXEC isp_GLBL03                         
               @c_PickSlipNo  = @cPickSlipNo,                       
               @n_CartonNo    = '',            
               @c_LabelNo     = @cNewLabelNo    OUTPUT,            
               @cStorerKey    = @cStorerKey,            
               @cDeviceProfileLogKey = '',            
               @cConsigneeKey = @cUserDefine09,            
               @b_success     = @bSuccess   OUTPUT,                        
               @n_err         = @nErrNo     OUTPUT,                        
               @c_errmsg      = @cErrMsg    OUTPUT             
                  
            END      
            ELSE      
               SET @cNewLabelNo = @cPackedLabelNo      
      
            SET @nUpdNotes = 0      
         END      
      
         IF @nMixCarton = 1      
         BEGIN      
            IF EXISTS ( SELECT 1       
                        FROM dbo.STORER WITH (NOLOCK)      
                        WHERE StorerKey = @cUserDefine02      
                        AND   SUSR1 = 'P')      
            BEGIN      
               SET @nErrNo = 0      
               SET @cNewLabelNo = 'x' -- Pass in random value to avoid error            
               -- Generate ANF UCC Label No                
               EXEC isp_GLBL03                         
               @c_PickSlipNo  = @cPickSlipNo,                       
               @n_CartonNo    = '',            
               @c_LabelNo     = @cNewLabelNo    OUTPUT,            
               @cStorerKey    = @cStorerKey,            
               @cDeviceProfileLogKey = '',            
               @cConsigneeKey = @cUserDefine02,            
               @b_success     = @bSuccess   OUTPUT,                        
               @n_err         = @nErrNo     OUTPUT,                        
               @c_errmsg      = @cErrMsg    OUTPUT             
    
               SET @nUpdNotes = 0      
            END      
            ELSE      
               SET @cNewLabelNo = @cPackedLabelNo      
                        
            IF EXISTS ( SELECT 1       
                        FROM dbo.STORER WITH (NOLOCK)      
                        WHERE StorerKey = @cUserDefine09      
                        AND   SUSR1 = 'C')      
            BEGIN      
               SET @nUpdNotes = 1      
               SET @nErrNo = 0      
               SET @cChildLabelNo = 'x' -- Pass in random value to avoid error            
               -- Generate ANF UCC Label No                
               EXEC isp_GLBL03                         
               @c_PickSlipNo  = @cPickSlipNo,                       
               @n_CartonNo    = '',            
               @c_LabelNo     = @cChildLabelNo  OUTPUT,            
               @cStorerKey    = @cStorerKey,            
               @cDeviceProfileLogKey = '',            
               @cConsigneeKey = @cUserDefine09,            
               @b_success     = @bSuccess   OUTPUT,                        
               @n_err         = @nErrNo     OUTPUT,                        
               @c_errmsg      = @cErrMsg    OUTPUT             
            END                 
      
            SET @nUpdNotes = 1      
         END      
    
         DECLARE @curUpdPack1  CURSOR      
         SET @curUpdPack1 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR       
         SELECT CartonNo, LabelNo, LabelLine      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         AND   LabelNo = @cPackedLabelNo      
         OPEN @curUpdPack1      
         FETCH NEXT FROM @curUpdPack1 INTO @nTempCartonNo, @cTempLabelNo, @cTempLabelLine      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.PackDetail SET      
               LabelNo = @cNewLabelNo,       
               EditWho = SUSER_SNAME(),       
               EditDate = GETDATE()      
            WHERE PickSlipNo = @cPickSlipNo      
            AND   CartonNo = @nTempCartonNo      
            AND   LabelNo = @cTempLabelNo      
            AND   LabelLine = @cTempLabelLine      
                     
            IF @@ERROR <> 0      
            BEGIN            
               SET @nErrNo = 86629        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
               GOTO Step_2_Fail         
            END       
                     
            FETCH NEXT FROM @curUpdPack1 INTO @nTempCartonNo, @cTempLabelNo, @cTempLabelLine      
         END      
               
         DECLARE @curUpdPick1  CURSOR      
         SET @curUpdPick1 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber      
         FROM dbo.PickDetail PD WITH (NOLOCK)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)      
         WHERE lpd.LoadKey = @cLoadKey      
         AND   PD.[Status] = '5'      
         AND   PD.CaseID = @cPackedLabelNo      
         ORDER BY PD.OrderKey, PD.OrderLineNumber, PD.PickDetailKey      
         OPEN @curUpdPick1      
         FETCH NEXT FROM @curUpdPick1 INTO @cTempPickDetailKey, @cTempOrderKey, @cTempOrderLineNumber      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            IF @nUpdNotes = 1      
            BEGIN      
               SELECT @cUserDefine09 = UserDefine09       
               FROM dbo.ORDERDETAIL WITH (NOLOCK)      
               WHERE OrderKey = @cTempOrderKey      
               AND   OrderLineNumber = @cTempOrderLineNumber      
      
               IF ISNULL( @cUserDefine09, '') <> ''      
               BEGIN      
                  IF @cPrevUserDefine09 <> @cUserDefine09      
                  BEGIN      
                     IF EXISTS ( SELECT 1       
                                 FROM dbo.STORER WITH (NOLOCK)      
                                 WHERE StorerKey = @cUserDefine09      
                                 AND   SUSR1 = 'C')      
                     BEGIN      
                        SET @nErrNo = 0      
                        SET @cChildLabelNo = 'x' -- Pass in random value to avoid error     
                        -- Generate ANF UCC Label No                
                        EXEC isp_GLBL03                         
                        @c_PickSlipNo  = @cPickSlipNo,                       
                        @n_CartonNo    = @nCartonNo,            
                        @c_LabelNo     = @cChildLabelNo  OUTPUT,            
                        @cStorerKey    = @cStorerKey,            
                        @cDeviceProfileLogKey = '',            
                        @cConsigneeKey = @cUserDefine09,            
                        @b_success     = @bSuccess   OUTPUT,                        
                        @n_err         = @nErrNo     OUTPUT,                        
                        @c_errmsg      = @cErrMsg    OUTPUT             
                     END      
                     ELSE      
                        SET @cChildLabelNo = NULL      
                  END      
                           
                  UPDATE dbo.PickDetail SET      
                     CaseID = @cNewLabelNo,      
                     Notes = @cChildLabelNo,      
                     EditWho = SUSER_SNAME(),       
                     EditDate = GETDATE()      
                  WHERE PickDetailKey = @cTempPickDetailKey      
      
                  IF @@ERROR <> 0      
                  BEGIN            
                     SET @nErrNo = 86630        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
                     GOTO Step_3_Fail         
                  END       
                        
                  SET @cPrevUserDefine09 = @cUserDefine09      
               END      
               ELSE      
               BEGIN      
                  UPDATE dbo.PickDetail SET      
                     CaseID = @cNewLabelNo,      
                     EditWho = SUSER_SNAME(),       
                     EditDate = GETDATE()      
                  WHERE PickDetailKey = @cTempPickDetailKey      
      
                  IF @@ERROR <> 0      
                  BEGIN            
                     SET @nErrNo = 86630        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
                     GOTO Step_2_Fail         
                  END       
               END      
            END      
            ELSE      
            BEGIN      
               UPDATE dbo.PickDetail SET      
                  CaseID = @cNewLabelNo,      
                  EditWho = SUSER_SNAME(),       
                  EditDate = GETDATE()      
               WHERE PickDetailKey = @cTempPickDetailKey      
      
               IF @@ERROR <> 0      
               BEGIN            
                  SET @nErrNo = 86630        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
                  GOTO Step_2_Fail         
               END                   
            END      
            FETCH NEXT FROM @curUpdPick1 INTO @cTempPickDetailKey, @cTempOrderKey, @cTempOrderLineNumber      
         END    
    
         -- Update DeviceProfileLog.Status = '9'    
         UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)    
         SET Status = '9'    
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
         AND DropID = @cCloseCartonID    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83849    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDeviceProfileLogFail'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
    
         -- Print Label via BarTender --    
         SET @cRDTBartenderSP = ''    
         SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)    
    
         IF @cRDTBartenderSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')    
            BEGIN    
               SET @cLabelNo = ''    
               SELECT Top 1  @cLabelNo = LabelNo    
               FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE PickSlipNo = @cPickSlipNo    
               AND DropID = @cCloseCartonID    
    
               SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +    
                                       '   @nMobile               ' +    
                                       ' , @nFunc                 ' +    
                                       ' , @cLangCode             ' +    
                                       ' , @cFacility             ' +    
                                       ' , @cStorerKey            ' +    
                                       ' , @cLabelPrinter         ' +    
                                       ' , @cCloseCartonID        ' +    
                                       ' , @cLoadKey              ' +    
                                       ' , @cLabelNo              ' +    
                                       ' , @cUserName             ' +    
                                       ' , @nErrNo       OUTPUT   ' +    
                           ' , @cErrMSG      OUTPUT   '    
               SET @cExecArguments =    
                          N'@nMobile     int,                   ' +    
                          '@nFunc       int,                    ' +    
                          '@cLangCode   nvarchar(3),            ' +    
                          '@cFacility   nvarchar(5),            ' +    
                          '@cStorerKey  nvarchar(15),           ' +    
                          '@cLabelPrinter     nvarchar(10),     ' +    
                          '@cCloseCartonID    nvarchar(20),     ' +    
                          '@cLoadKey    nvarchar(10),           ' +    
                          '@cLabelNo    nvarchar(20),           ' +    
                          '@cUserName   nvarchar(18),           ' +    
                          '@nErrNo      int  OUTPUT,            ' +    
                          '@cErrMsg     nvarchar(1024) OUTPUT   '    
    
               EXEC sp_executesql @cExecStatements, @cExecArguments,    
                                     @nMobile    
                                   , @nFunc    
                                   , @cLangCode    
                                   , @cFacility    
                                   , @cStorerKey    
                                   , @cLabelPrinter    
                                   , @cCloseCartonID    
                                   , @cLoadKey    
                                   , @cLabelNo    
                 , @cUserName    
                                   , @nErrNo       OUTPUT    
                                   , @cErrMSG      OUTPUT    
    
                IF @nErrNo <> 0    
                BEGIN    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'    
                   EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
                   GOTO Step_2_Fail    
                END    
            END    
         END    
    
         -- Update DropID PTS Carton & Pick Carton --    
         UPDATE dbo.DropID WITH (ROWLOCK)    
         SET  Status = '9'    
            , LabelPrinted = 'Y'    
         WHERE DropID = @cCloseCartonID    
         AND LoadKey  = @cLoadKey    
         AND Status   = '3'    
         AND DropIDType = 'PTS'    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83850    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
            GOTO Step_2_Fail    
         END    
    
         -- Pack Confirm  --    
         SET @n_CntTotal   = 0    
         SET @n_CntPrinted = 0    
    
         SELECT @n_CntTotal = SUM(PD.QTY)    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
         INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey    
         WHERE PD.PickslipNo  = @cPickSlipNo    
         AND   LP.LoadKey     = @cLoadKey    
         AND   PD.StorerKey   = @cStorerKey    
         --AND   PD.Status      = '5'    
    
         SELECT @n_CntPrinted = SUM(PCD.QTY)    
         FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)    
         WHERE  PCD.PickSlipNo = @cPickSlipNo    
         AND    PCD.StorerKey  = @cStorerKey    
    
         IF @n_CntTotal = @n_CntPrinted    
         BEGIN    
            UPDATE dbo.PackHeader WITH (ROWLOCK)    
               SET STATUS = '9'    
            WHERE PICKSLIPNO = @cPickSlipNo    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 86051    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHeaderFail'    
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            -- Update PickingInfo    
            UPDATE dbo.PickingInfo WITH (ROWLOCK)    
               SET ScanOutdate = GetDate() , TrafficCop = NULL    
            WHERE PickSlipNo = @cPickSlipNo    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 86052    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickInfoFail'    
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
         END    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                         AND Status IN ( '1', '3' ) )    
         BEGIN    
            UPDATE  DP    
             SET   Status = '9'    
            FROM dbo.DeviceProfile DP WITH (NOLOCK)    
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID    
            WHERE  Loc.PutawayZone = @cPTSZone    
            AND   DP.DeviceProfileLogKey = @cDeviceProfileLogKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 86053    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDeviceProFail'    
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKP10)     
               GOTO Step_2_Fail    
            END    
    
            SET @nErrNo = 86054    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoMoreTAsk'    
    
            -- Prepare Next Screen Variable    
            -- Init screen    
            SET @cOutField01 = ''    
            SET @cOutField02 = ''    
            SET @cOutField03 = ''    
    
            SET @cToteNo    = ''    
            SET @cPTSZone   = ''    
            SET @cUCCNo     = ''    
            SET @cDeviceProfileLogKey  = ''    
    
            SET @cLoadKey    = ''    
            SET @cPickSlipNo = ''    
            SET @cSKU        = ''    
            SET @cSKUDescr   = ''    
            SET @cPTSZone    = ''    
    
            SET @cToteNo     = ''    
            SET @cUCCNo      = ''    
            SET @cObjectID   = ''    
            SET @cCloseCartonID =  ''    
            SET @cNewCartonID   =  ''    
            SET @cDeviceProfileLogKey = ''    
            SET @cUCCNextLoc   = ''    
            SET @cConsigneeKey = ''    
            SET @cWCS          = ''    
            SET @cPTSLoc       = ''    
            SET @cObjectType   = ''    
            SET @cPrevWaveKey  = ''    
    
            -- GOTO Screen 4    
            SET @nScn = @nScn - 1    
            SET @nStep = @nStep - 1    
    
            SET @nErrNo = 86055    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CartonClosed'    
    
            GOTO QUIT    
         END    
    
         -- IF Carton ID Is Scanned Remain on Same Screen    
         SET @cOutField01 = @cPTSZone    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         GOTO QUIT    
      END    
   END  -- Inputkey = 1    
    
   IF @nInputKey = 0    
   BEGIN    
      SET @cDeviceProfileLogKey = '' -- (Chee01)    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
    
      -- GOTO Previous Screen    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   STEP_2_FAIL:    
   BEGIN    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
   END    
END    
GOTO QUIT    
    
/********************************************************************************    
Step 3. Scn = 3732.    
    
   PTS Zone               (field01)    
   UCC / ToteNo           (field02)    
   SKU                    (field03)    
   SKU Descr 1            (field04)    
   SKU Descr 2            (field05)    
   UCC Loc                (field06)    
   CLOSE TOTE ID          (field07, input)    
    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
      SET @cCloseCartonID = ISNULL(RTRIM(@cInField07),'')    
    
      IF @cCloseCartonID <> ''    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                         WHERE DropID = @cCloseCartonID    
                         AND Status = '3'    
                         AND DeviceProfileLogKey = @cDeviceProfileLogKey)    
         BEGIN    
            SET @nErrNo = 83819    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'    
            GOTO Step_3_Fail    
         END    
    
         -- Pack Confirm  -- (ChewKP07)    
         SET @n_DropIDPacked   = 0    
         SET @n_DropIDPicked   = 0    
         SET @cPackedLabelNo   = ''    
    
         SELECT Top 1 @cPackedLabelNo = LabelNo    
         FROM dbo.PackDetail WITH (NOLOCK)    
         WHERE PickSlipNo = @cPickSlipNo    
         AND DropID = @cCloseCartonID    
         AND StorerKey = @cStorerKey    
    
         SELECT @n_DropIDPicked = SUM(PD.QTY)    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
         INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey    
         WHERE PD.PickslipNo  = @cPickSlipNo    
         AND   LP.LoadKey     = @cLoadKey    
         AND   PD.StorerKey   = @cStorerKey    
         AND   PD.CaseID      = @cPackedLabelNo    
         AND   PD.Status      = '5'    
    
         SELECT @n_DropIDPacked = SUM(PCD.QTY)    
         FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)    
         WHERE  PCD.PickSlipNo = @cPickSlipNo    
         AND    PCD.StorerKey  = @cStorerKey    
         AND    PCD.DropID     = @cCloseCartonID    
    
         IF ISNULL(@n_DropIDPicked,0) <> ISNULL(@n_DropIDPacked,0 )    
         BEGIN    
            SET @nErrNo = 86066    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickPackQtyNotMatch'    
            GOTO Step_3_Fail    
         END    
         -- (ChewKP04)    
--         IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                     WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
--                       AND CaseID = @cCloseCartonID    
--                       AND Status = '1' )    
--         BEGIN    
--            SET @nErrNo = 86071    
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightInProcess'    
--            GOTO Step_3_Fail    
--         END    
    
    
    
--         IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
--                  AND   Status = '1'    
--                  AND   CaseID = @cCloseCartonID )    
--         BEGIN    
--            SET @nErrNo = 83834    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'    
--            GOTO Step_3_Fail    
--         END    
    
--         -- Create PackDetail & PackConfirm --    
--         EXEC rdt.rdt_PTL_PTS_Confirm    
--                 @nMobile                 = @nMobile    
--                ,@nFunc                   = @nFunc    
--                ,@cFacility               = @cFacility    
--                ,@cStorerKey              = @cStorerKey    
--                ,@cPTSZone           = @cPTSZone    
--                ,@cDropID                 = @cCloseCartonID    
--                ,@cDropIDType             = @cObjectType    
--                ,@cDeviceProfileLogKey    = @cDeviceProfileLogKey    
--                ,@cUserName               = @cUserName    
--                ,@cLangCode               = @cLangCode    
--                ,@cLoadKey                = @cLoadKey    
--                ,@nErrNo                  = @nErrNo  OUTPUT    
--                ,@cErrMsg                 = @cERRMSG OUTPUT -- screen limitation, 20 char max    
--    
--         IF @nErrNo <> 0    
--         BEGIN    
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'    
--            GOTO Step_3_Fail    
--         END    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                         WHERE PickSlipNo = @cPickSlipNo    
                         AND DropID = @cCloseCartonID )    
         BEGIN    
            SET @nErrNo = 83838    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteNotPack'    
            GOTO Step_3_Fail    
         END    
  
         DECLARE @tMixCarton TABLE ( UserDefine NVARCHAR( 36))    
    
  
         SELECT @nCartonNo = CartonNo      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         AND   LabelNo = @cLabelNo     
    
         DELETE FROM @tMixCarton      
         INSERT INTO @tMixCarton (UserDefine)      
         SELECT OD.userdefine02 + OD.userdefine09      
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)      
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
         WHERE PD.Storerkey = @cStorerKey      
         AND   PD.CaseID = @cPackedLabelNo      
         AND   PD.[Status] = '5'      
         AND   LPD.LoadKey = @cLoadKey      
         GROUP BY OD.userdefine02 , OD.userdefine09      
    
         SELECT @nCount = COUNT(1) FROM @tMixCarton      
               
         IF @nCount = 1      
            SET @nMixCarton = 0      
         ELSE      
            SET @nMixCarton = 1      
    
         SELECT       
            @cUserDefine02 = MAX( OD.UserDefine02),      
            @cUserDefine09 = MAX( OD.UserDefine09)      
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)      
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)      
         WHERE PD.Storerkey = @cStorerKey      
         AND   PD.CaseID = @cPackedLabelNo      
         AND   PD.[Status] = '5'      
         AND   LPD.LoadKey = @cLoadKey      
         GROUP BY OD.userdefine02 , OD.userdefine09      
    
         IF @nMixCarton = 0      
         BEGIN      
            IF EXISTS ( SELECT 1       
                        FROM dbo.STORER WITH (NOLOCK)      
                        WHERE StorerKey = @cUserDefine09      
                        AND   SUSR1 = 'C')      
            BEGIN      
               SET @nErrNo = 0      
               SET @cNewLabelNo = 'x' -- Pass in random value to avoid error            
               -- Generate ANF UCC Label No                
               EXEC isp_GLBL03                         
               @c_PickSlipNo  = @cPickSlipNo,   
               @n_CartonNo    = '',            
               @c_LabelNo     = @cNewLabelNo    OUTPUT,            
               @cStorerKey    = @cStorerKey,            
               @cDeviceProfileLogKey = '',            
               @cConsigneeKey = @cUserDefine09,            
               @b_success     = @bSuccess   OUTPUT,                        
               @n_err         = @nErrNo     OUTPUT,                        
               @c_errmsg      = @cErrMsg    OUTPUT             
                  
            END      
            ELSE      
               SET @cNewLabelNo = @cPackedLabelNo      
      
            SET @nUpdNotes = 0      
         END      
      
         IF @nMixCarton = 1      
         BEGIN      
            IF EXISTS ( SELECT 1       
                        FROM dbo.STORER WITH (NOLOCK)      
                        WHERE StorerKey = @cUserDefine02      
                        AND   SUSR1 = 'P')      
            BEGIN      
               SET @nErrNo = 0      
               SET @cNewLabelNo = 'x' -- Pass in random value to avoid error            
               -- Generate ANF UCC Label No                
               EXEC isp_GLBL03                         
               @c_PickSlipNo  = @cPickSlipNo,                       
               @n_CartonNo    = '',            
               @c_LabelNo     = @cNewLabelNo    OUTPUT,            
               @cStorerKey    = @cStorerKey,            
               @cDeviceProfileLogKey = '',            
               @cConsigneeKey = @cUserDefine02,            
               @b_success     = @bSuccess   OUTPUT,                        
               @n_err         = @nErrNo     OUTPUT,                        
               @c_errmsg      = @cErrMsg    OUTPUT             
    
               SET @nUpdNotes = 0      
            END      
            ELSE      
               SET @cNewLabelNo = @cPackedLabelNo      
                        
            IF EXISTS ( SELECT 1       
                        FROM dbo.STORER WITH (NOLOCK)      
                        WHERE StorerKey = @cUserDefine09      
                        AND   SUSR1 = 'C')      
            BEGIN      
               SET @nUpdNotes = 1      
               SET @nErrNo = 0      
               SET @cChildLabelNo = 'x' -- Pass in random value to avoid error            
               -- Generate ANF UCC Label No                
               EXEC isp_GLBL03                         
               @c_PickSlipNo  = @cPickSlipNo,                       
               @n_CartonNo    = '',            
               @c_LabelNo     = @cChildLabelNo  OUTPUT,            
               @cStorerKey    = @cStorerKey,            
               @cDeviceProfileLogKey = '',            
               @cConsigneeKey = @cUserDefine09,            
               @b_success     = @bSuccess   OUTPUT,                        
               @n_err         = @nErrNo     OUTPUT,                        
               @c_errmsg      = @cErrMsg    OUTPUT             
            END                 
      
            SET @nUpdNotes = 1      
         END      
    
         DECLARE @curUpdPack  CURSOR      
         SET @curUpdPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR       
         SELECT CartonNo, LabelNo, LabelLine      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         AND   LabelNo = @cPackedLabelNo      
         OPEN @curUpdPack      
         FETCH NEXT FROM @curUpdPack INTO @nTempCartonNo, @cTempLabelNo, @cTempLabelLine      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.PackDetail SET      
               LabelNo = @cNewLabelNo,       
               EditWho = SUSER_SNAME(),       
               EditDate = GETDATE()      
            WHERE PickSlipNo = @cPickSlipNo      
            AND   CartonNo = @nTempCartonNo      
            AND   LabelNo = @cTempLabelNo      
            AND   LabelLine = @cTempLabelLine      
                     
            IF @@ERROR <> 0      
            BEGIN            
               SET @nErrNo = 86629        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
               GOTO Step_3_Fail         
            END       
                     
            FETCH NEXT FROM @curUpdPack INTO @nTempCartonNo, @cTempLabelNo, @cTempLabelLine      
         END      
               
         DECLARE @curUpdPick  CURSOR      
         SET @curUpdPick = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber      
         FROM dbo.PickDetail PD WITH (NOLOCK)      
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)      
         WHERE lpd.LoadKey = @cLoadKey      
         AND   PD.[Status] = '5'      
         AND   PD.CaseID = @cPackedLabelNo      
         ORDER BY PD.OrderKey, PD.OrderLineNumber, PD.PickDetailKey      
         OPEN @curUpdPick      
         FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey, @cTempOrderKey, @cTempOrderLineNumber      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            IF @nUpdNotes = 1      
            BEGIN      
               SELECT @cUserDefine09 = UserDefine09       
               FROM dbo.ORDERDETAIL WITH (NOLOCK)      
               WHERE OrderKey = @cTempOrderKey      
               AND   OrderLineNumber = @cTempOrderLineNumber      
      
               IF ISNULL( @cUserDefine09, '') <> ''      
               BEGIN      
                  IF @cPrevUserDefine09 <> @cUserDefine09      
                  BEGIN      
                     IF EXISTS ( SELECT 1       
                                 FROM dbo.STORER WITH (NOLOCK)      
                                 WHERE StorerKey = @cUserDefine09      
                                 AND   SUSR1 = 'C')      
                     BEGIN      
                        SET @nErrNo = 0      
                        SET @cChildLabelNo = 'x' -- Pass in random value to avoid error            
                        -- Generate ANF UCC Label No                
                        EXEC isp_GLBL03                         
                        @c_PickSlipNo  = @cPickSlipNo,                       
                        @n_CartonNo    = @nCartonNo,            
                        @c_LabelNo     = @cChildLabelNo  OUTPUT,            
                        @cStorerKey    = @cStorerKey,            
                        @cDeviceProfileLogKey = '',            
                        @cConsigneeKey = @cUserDefine09,            
                        @b_success     = @bSuccess   OUTPUT,                        
                        @n_err         = @nErrNo     OUTPUT,                        
                        @c_errmsg      = @cErrMsg    OUTPUT             
                     END      
                     ELSE      
                        SET @cChildLabelNo = NULL      
                  END      
                           
                  UPDATE dbo.PickDetail SET      
                     CaseID = @cNewLabelNo,      
                     Notes = @cChildLabelNo,      
                     EditWho = SUSER_SNAME(),       
                     EditDate = GETDATE()      
                  WHERE PickDetailKey = @cTempPickDetailKey      
      
                  IF @@ERROR <> 0      
                  BEGIN            
                     SET @nErrNo = 86630        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
                     GOTO Step_3_Fail         
                  END       
                        
                  SET @cPrevUserDefine09 = @cUserDefine09      
               END      
               ELSE      
               BEGIN      
                  UPDATE dbo.PickDetail SET      
                     CaseID = @cNewLabelNo,      
                     EditWho = SUSER_SNAME(),       
                     EditDate = GETDATE()      
                  WHERE PickDetailKey = @cTempPickDetailKey      
      
                  IF @@ERROR <> 0      
                  BEGIN            
                     SET @nErrNo = 86630        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
                     GOTO Step_3_Fail         
                  END       
               END      
            END      
            ELSE      
            BEGIN      
               UPDATE dbo.PickDetail SET      
                  CaseID = @cNewLabelNo,      
                  EditWho = SUSER_SNAME(),       
                  EditDate = GETDATE()      
               WHERE PickDetailKey = @cTempPickDetailKey      
      
               IF @@ERROR <> 0      
               BEGIN            
                  SET @nErrNo = 86630        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReLabelNo Fail       
                  GOTO Step_3_Fail         
               END                   
            END      
            FETCH NEXT FROM @curUpdPick INTO @cTempPickDetailKey, @cTempOrderKey, @cTempOrderLineNumber      
         END    
    
         -- Short Pack on Carton --    
--         IF EXISTS ( SELECT 1 FROM dbo.PTLTRan WITH (NOLOCK)    
--                     WHERE PTL_Type = 'Pick2PTS'    
--                     AND DropID = @cCloseCartonID    
--                     AND SKU <> 'FTOTE'    
--                     AND DeviceProfileLogKey = @cDeviceProfileLogKey    
--                     AND ExpectedQty <> Qty )    
--         BEGIN    
--    
--            SET @cOutField01 = @cCloseCartonID    
--    
--            -- GOTO Screen 5    
--            SET @nScn = @nScn + 2    
--            SET @nStep = @nStep + 2    
--    
--            GOTO QUIT    
--    
--         END    
    
         -- Update DeviceProfileLog.Status = '9'    
         UPDATE dbo.DeviceProfileLog WITH (ROWLOCK)    
         SET Status = '9'    
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
         AND DropID = @cCloseCartonID    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83829    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDeviceProfileLogFail'    
            GOTO Step_3_Fail    
         END    
    
         -- Print Label via BarTender --    
         SET @cRDTBartenderSP = ''    
         SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)    
    
         IF @cRDTBartenderSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')    
            BEGIN    
               SET @cLabelNo = ''    
               SELECT Top 1  @cLabelNo = LabelNo    
               FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE PickSlipNo = @cPickSlipNo    
               AND DropID = @cCloseCartonID    
    
               SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +    
                                       '   @nMobile               ' +    
                                       ' , @nFunc                 ' +    
                                       ' , @cLangCode             ' +    
                                   ' , @cFacility             ' +    
                                       ' , @cStorerKey            ' +    
                                       ' , @cLabelPrinter         ' +    
                                       ' , @cCloseCartonID        ' +    
                                       ' , @cLoadKey              ' +    
                                       ' , @cLabelNo              ' +    
                                       ' , @cUserName             ' +    
                                       ' , @nErrNo       OUTPUT   ' +    
                                       ' , @cErrMSG      OUTPUT   '    
               SET @cExecArguments =    
                          N'@nMobile     int,                   ' +    
                          '@nFunc int,                    ' +    
                          '@cLangCode nvarchar(3),            ' +    
                          '@cFacility   nvarchar(5),            ' +    
                          '@cStorerKey  nvarchar(15),           ' +    
                          '@cLabelPrinter     nvarchar(10),     ' +    
                          '@cCloseCartonID    nvarchar(20),     ' +    
                          '@cLoadKey    nvarchar(10),           ' +    
                          '@cLabelNo    nvarchar(20),           ' +    
                          '@cUserName   nvarchar(18),           ' +    
                          '@nErrNo      int  OUTPUT,            ' +    
                          '@cErrMsg     nvarchar(1024) OUTPUT   '    
    
               EXEC sp_executesql @cExecStatements, @cExecArguments,    
                                     @nMobile    
                                   , @nFunc    
                                   , @cLangCode    
                      , @cFacility    
                                   , @cStorerKey    
                                   , @cLabelPrinter    
                                   , @cCloseCartonID    
                                   , @cLoadKey    
                                   , @cLabelNo    
                                   , @cUserName    
                                   , @nErrNo       OUTPUT    
                                   , @cErrMSG      OUTPUT    
                IF @nErrNo <> 0    
                BEGIN    
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'    
                   GOTO Step_3_Fail    
                END    
            END    
         END    
    
         -- Update DropID PTS Carton & Pick Carton --    
         UPDATE dbo.DropID WITH (ROWLOCK)    
         SET  Status = '9'    
            , LabelPrinted = 'Y'    
         WHERE DropID = @cCloseCartonID    
         AND LoadKey  = @cLoadKey    
         AND Status   = '3'    
         AND DropIDType = 'PTS'    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83830    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'    
            GOTO Step_3_Fail    
         END    
    
         -- Pack Confirm  --    
         SET @n_CntTotal   = 0    
         SET @n_CntPrinted = 0    
    
         SELECT @n_CntTotal = SUM(PD.QTY)    
         FROM dbo.PickDetail PD WITH (NOLOCK)    
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
         INNER JOIN dbo.LoadPlanDetail LP WITH (NOLOCK) ON LP.OrderKey = PD.OrderKey    
         WHERE PD.PickslipNo  = @cPickSlipNo    
         AND   LP.LoadKey     = @cLoadKey    
         AND   PD.StorerKey   = @cStorerKey    
         --AND   PD.Status      = '5'    
    
         SELECT @n_CntPrinted = SUM(PCD.QTY)    
         FROM   dbo.PACKDETAIL PCD WITH (NOLOCK)    
         WHERE  PCD.PickSlipNo = @cPickSlipNo    
         AND    PCD.StorerKey  = @cStorerKey    
    
         IF @n_CntTotal = @n_CntPrinted    
         BEGIN    
            UPDATE dbo.PackHeader WITH (ROWLOCK)    
               SET STATUS = '9'    
            WHERE PICKSLIPNO = @cPickSlipNo    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 83836    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackHeaderFail'    
               GOTO Step_3_Fail    
            END    
    
            -- Update PickingInfo    
            UPDATE dbo.PickingInfo WITH (ROWLOCK)    
               SET ScanOutdate = GetDate() , TrafficCop = NULL    
            WHERE PickSlipNo = @cPickSlipNo    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 83843    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickInfoFail'    
               GOTO Step_3_Fail    
            END    
         END    
    
         -- Update DeviceProfile = 9 when no more Task    
--         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog DL WITH (NOLOCK)    
--            INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey    
--                       WHERE DL.UserDefineo02 = @cLoadKey    
--                         AND DL.Status < '9' )    
--         BEGIN    
--            -- Update PickingInfo    
--            UPDATE    
--               SET Status = '9'    
--            FROM dbo.DeviceProfile D WITH (NOLOCK)    
--            INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileKey = D.DeviceProfileKey    
--            AND DL.Status = '9'    
--            AND DL.UserDefine02 = @cLoadKey    
--    
--            IF @@ERROR <> 0    
--            BEGIN    
--               SET @nErrNo = 83843    
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickInfoFail'    
--               GOTO Step_3_Fail    
--            END    
--         END    
    
         -- If there is remaining Quantity to be put into the Tote for this Consignee go to Assign New Tote--    
         SET @nPendingTote = 0    
         SET @cConsigneeKey = ''    
    
         SELECT @cConsigneeKey = ConsigneeKey    
         FROM dbo.DeviceProfileLog WITH (NOLOCK)    
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
         AND DropID = @cCloseCartonID    
         AND UserDefine02 = @cLoadKey    
    
         -- Get New Carton    
         IF EXISTS ( SELECT 1    
                     FROM dbo.PickDetail PD WITH (NOLOCK)    
                     INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
                     INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)    
                     WHERE PD.PickslipNo = @cPickSlipNo    
                     AND PD.Status IN ( '0', '3', '5' )  -- (ChewKP06)`    
                     AND O.LoadKey = @cLoadKey    
                     AND OD.UserDefine02 = @cConsigneeKey    
                     AND PD.CaseID = ''  )    
         BEGIN    
            -- Prepare Next Screen Variable    
            SET @cOutField01 = @cCloseCartonID    
            SET @cOutField02 = ''    
            SET @cOutField03 = ''    
    
            -- GOTO Screen 4    
            SET @nScn = @nScn + 1    
            SET @nStep = @nStep + 1    
    
            GOTO QUIT    
         END    
    
         IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                         AND Status IN ( '1', '3' ) )    
         BEGIN    
            UPDATE  DP    
             SET   Status = '9'    
            FROM dbo.DeviceProfile DP WITH (NOLOCK)    
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID    
            WHERE  Loc.PutawayZone = @cPTSZone    
            AND   DP.DeviceProfileLogKey = @cDeviceProfileLogKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 83844    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDeviceProFail'    
               GOTO Step_3_Fail    
            END    
    
            SET @nErrNo = 83845    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NoMoreTAsk'    
    
            SET @cPTSLoc = ''    
            SELECT TOP 1 @cPTSLoc = D.DeviceID    
            FROM dbo.DeviceProfile D WITH (NOLOCK)    
            INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
            --INNER JOIN dbo.PTLTran PTL WITH (NOLOCK) ON PTL.DeviceID = Loc.Loc    
            WHERE Loc.PutawayZone = @cPTSZone    
    
            -- Terminate All Light before Light Up    
            EXEC [dbo].[isp_DPC_TerminateModule]    
                  @cStorerKey    
                 ,@cPTSLoc    
                 ,'0'    
                 ,@b_Success    OUTPUT    
                 ,@nErrNo       OUTPUT    
                 ,@cErrMsg      OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
                SET @cErrMsg = LEFT(@cErrMsg,1024)    
                GOTO Step_3_Fail    
            END    
    
            -- Prepare Next Screen Variable    
            -- Init screen    
            SET @cOutField01 = ''    
            SET @cOutField02 = ''    
            SET @cOutField03 = ''    
    
            SET @cToteNo    = ''    
  SET @cPTSZone   = ''    
            SET @cUCCNo     = ''    
            SET @cDeviceProfileLogKey  = ''    
    
            SET @cLoadKey    = ''    
            SET @cPickSlipNo = ''    
            SET @cSKU        = ''    
            SET @cSKUDescr   = ''    
            SET @cPTSZone    = ''    
    
            SET @cToteNo     = ''    
            SET @cUCCNo      = ''    
            SET @cObjectID   = ''    
            SET @cCloseCartonID =  ''    
            SET @cNewCartonID   =  ''    
            SET @cDeviceProfileLogKey = ''    
            SET @cUCCNextLoc   = ''    
 SET @cConsigneeKey = ''    
            SET @cWCS          = ''    
            SET @cPTSLoc       = ''    
            SET @cObjectType   = ''    
            SET @cPrevWaveKey  = ''    
    
            -- GOTO Screen 4    
            SET @nScn = @nScn - 2    
            SET @nStep = @nStep - 2    
    
            GOTO QUIT    
         END    
    
         SET @nErrNo = 86056    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CartonClosed'    
    
         -- IF Carton ID Is Scanned Remain on Same Screen    
         SET @cOutField01 = @cPTSZone    
         SET @cOutField02 = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
         SET @cOutField03 = CASE WHEN @cObjectType = 'TOTE' THEN 'MIXED SKU' ELSE @cSKU END    
         SET @cOutField04 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20)  END    
         SET @cOutField05 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 20) END    
         SET @cOutField06 = @cUCCNextLoc-- Residual UCC Location    
         SET @cOutField07 = ''    
    
         GOTO QUIT    
      END    
    
      -- Need to Validate is All Light Confirmed before process further --    
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                  AND   Status = '1' )    
      BEGIN    
         SET @nErrNo = 83820    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'    
         GOTO Step_3_Fail    
      END    
    
      SET @cPTSLoc = ''    
      SELECT TOP 1 @cPTSLoc = D.DeviceID    
      FROM dbo.DeviceProfile D WITH (NOLOCK)    
      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = D.DeviceID    
      --INNER JOIN dbo.PTLTran PTL WITH (NOLOCK) ON PTL.DeviceID = Loc.Loc    
      WHERE Loc.PutawayZone = @cPTSZone    
      --AND PTL.DeviceProfileLogKey = @cDeviceProfileLogKey    
    
      -- Terminate All Light before Light Up    
      EXEC [dbo].[isp_DPC_TerminateModule]    
            @cStorerKey    
           ,@cPTSLoc    
           ,'0'    
           ,@b_Success    OUTPUT    
           ,@nErrNo       OUTPUT    
           ,@cErrMsg      OUTPUT    
    
       IF @nErrNo <> 0    
       BEGIN    
          SET @cErrMsg = LEFT(@cErrMsg,1024)    
          GOTO Step_3_Fail    
       END    
    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
    
--      -- GOTO Next Screen -- Tote / UCC    
      SET @nScn = @nScn - 1    
      SET @nStep = @nStep - 1    
    
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- (ChewKPXX)    
    
      -- Alert User to put the Case on the Conveyor If Short Pick    
      IF @cWCS = '1'    
      BEGIN    
        IF @cObjectType = 'UCC'    
        BEGIN    
           SET @nSumTotalExpectedQty = 0    
           SET @nSumTotalPickedQty   = 0    
           SET @nUCCQty              = 0 -- (ChewKP03)    
    
           -- (ChewKP03)    
           SELECT @nUCCQty = Qty    
           FROM dbo.UCC WITH (NOLOCK)    
           WHERE UCCNo = @cUCCNo    
    
           SELECT @nSumTotalExpectedQty = SUM(Qty)    
           FROM dbo.PickDetail WITH (NOLOCK)    
           WHERE DropID = @cUCCNo    
           AND PickSlipNo = @cPickSlipNo    
    
           SELECT @nSumTotalPickedQty = SUM(Qty)    
           FROM dbo.PTLTran WITH (NOLOCK)    
           WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
           AND   DropID = @cUCCNo    
    
           IF  (ISNULL(@nSumTotalExpectedQty,0)  <> ISNULL(@nSumTotalPickedQty,0) )    
           BEGIN    
              SET @nErrNo = 86067    
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SHORT PICK UCC'    
    
               --SET @nErrNo = 0    
               SET @cErrMsg1 = @nErrNo    
               SET @cErrMsg2 = @cErrMsg    
               SET @cErrMsg3 = @cUCCNo    
               SET @cErrMsg4 = ''    
               SET @cErrMsg5 = ''    
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
               IF @nErrNo = 1    
               BEGIN    
                  SET @cErrMsg1 = ''    
                  SET @cErrMsg2 = ''    
      SET @cErrMsg3 = ''    
                  SET @cErrMsg4 = ''    
                  SET @cErrMsg5 = ''    
               END    
               GOTO QUIT    
           END    
    
           IF  (ISNULL(@nUCCQty,0)  <> ISNULL(@nSumTotalPickedQty,0) )    
           BEGIN    
              SET @nErrNo = 86068    
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'RESIDUAL PA'    
    
               --SET @nErrNo = 0    
               SET @cErrMsg1 = @nErrNo    
               SET @cErrMsg2 = @cErrMsg    
               SET @cErrMsg3 = @cUCCNo    
               SET @cErrMsg4 = ''    
               SET @cErrMsg5 = ''    
    
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5    
               IF @nErrNo = 1    
               BEGIN    
                  SET @cErrMsg1 = ''    
                  SET @cErrMsg2 = ''    
                  SET @cErrMsg3 = ''    
                  SET @cErrMsg4 = ''    
                  SET @cErrMsg5 = ''    
               END    
               GOTO QUIT    
           END    
         END    
      END    
   END  -- Inputkey = 1    
    
 IF @nInputKey = 0    
 BEGIN    
--      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
--                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
--                  AND   Status = '1' )    
--      BEGIN    
--         SET @nErrNo = 83833    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PickNotComplete'    
--         GOTO Step_3_Fail    
--      END    
    
      -- IF Tote when ESC Terminate Light --    
     IF @cObjectType = 'TOTE'    
     BEGIN    
          IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                      WHERE DropID = @cToteNo    
                      AND   Status = '1' )    
          BEGIN    
             SET @cPTSLoc = ''    
             SELECT @cPTSLoc = DeviceID    
             FROM dbo.PTLTRAN WITH (NOLOCK)    
             WHERE DropID = @cToteNo    
             AND Status = '1'    
             AND DeviceProfileLogKey = @cDeviceProfileLogKey    
    
             EXEC [dbo].[isp_DPC_TerminateModule]    
                   @cStorerKey    
                  ,@cPTSLoc    
                  ,'1'           -- 1= Off 1 Light , 0 = Off all Light Indicate Off This DeviceID only.    
                  ,@b_Success    OUTPUT    
                  ,@nErrNo       OUTPUT    
                  ,@cErrMsg      OUTPUT    
    
             IF @nErrNo <> 0    
             BEGIN    
                 SET @cErrMsg = LEFT(@cErrMsg,1024)    
                 GOTO Step_3_Fail    
             END    
    
             -- (ChewKP09)    
             DELETE FROM dbo.PTLTRAN WITH (ROWLOCK)    
             WHERE DropID = @cToteNo    
  AND Status = '1'    
             AND DeviceProfileLogKey = @cDeviceProfileLogKey    
    
             IF @@ERROR  <> 0    
             BEGIN    
                  SET @nErrNo = 86060    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPTLTranFail'    
                  GOTO Step_3_Fail    
             END    
    
         END    
     END    
     ELSE IF @cObjectType = 'UCC'    
     BEGIN    
          IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                      WHERE DropID = @cUCCNo -- (ChewKP09 )    
                      AND   Status = '1' )    
          BEGIN    
    
             SET @cPTSLoc = ''    
             SELECT @cPTSLoc = DeviceID    
             FROM dbo.PTLTRAN WITH (NOLOCK)    
             WHERE DropID = @cUCCNo    
             AND Status = '1'    
             --AND DeviceProfileLogKey = @cDeviceProfileLogKey    
    
             EXEC [dbo].[isp_DPC_TerminateModule]    
                   @cStorerKey    
                  ,@cPTSLoc    
                  ,'0'           -- 1= Off 1 Light , 0 = Off all Light Indicate Off This DeviceID only.    
                  ,@b_Success    OUTPUT    
                  ,@nErrNo       OUTPUT    
                  ,@cErrMsg      OUTPUT    
    
             IF @nErrNo <> 0    
             BEGIN    
                 SET @cErrMsg = LEFT(@cErrMsg,1024)    
                 GOTO Step_3_Fail    
             END    
    
             -- (ChewKP09)    
             DELETE FROM dbo.PTLTRAN WITH (ROWLOCK)    
             WHERE DropID = @cUCCNo    
             AND Status = '1'    
             AND DeviceProfileLogKey = @cDeviceProfileLogKey    
    
             IF @@ERROR  <> 0    
             BEGIN    
                  SET @nErrNo = 86073    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPTLTranFail'    
                  GOTO Step_3_Fail    
             END    
    
    
         END    
     END    
    
     -- Prepare Previous Screen Variable    
     SET @cOutField01 = @cPTSZone    
     SET @cOutField02 = ''    
     SET @cOutField03 = ''    
    
     -- GOTO Previous Screen    
     SET @nScn = @nScn - 1    
     SET @nStep = @nStep - 1    
 END    
 GOTO Quit    
    
 STEP_3_FAIL:    
 BEGIN    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
      SET @cOutField03 = CASE WHEN @cObjectType = 'TOTE' THEN 'MIXED SKU' ELSE @cSKU END    
      SET @cOutField04 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20)  END    
      SET @cOutField05 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 20) END    
      SET @cOutField06 = @cUCCNextLoc-- Residual UCC Location    
      SET @cOutField07 = ''    
 END    
END    
GOTO QUIT    
    
/********************************************************************************    
Step 4. Scn = 3733.    
    
   Close Tote ID (field01)    
   New Tote ID (input, field02)    
   PTS Loc     (input, field03)    
    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
    
    SET @cNewCartonID = ISNULL(RTRIM(@cInField02),'')    
    --SET @cLightLoc    = ISNULL(RTRIM(@cInField03),'')    -- (ChewKP02)    
    
      IF @cNewCartonID = ''    
      BEGIN    
         SET @nErrNo = 83822    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CartonIDReq'    
         SET @cNewCartonID = ''    
         --SET @cLightLoc    = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO STEP_4_FAIL    
      END    
    
      IF EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                  WHERE DropID = @cNewCartonID )    
      BEGIN    
         SET @nErrNo = 83823    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CartonExistInPTS'    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
   SET @cNewCartonID = ''    
         --SET @cLightLoc    = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO STEP_4_FAIL    
      END    
    
      SET @cRegExpression = ''    
      SELECT TOP 1 @cRegExpression = UDF01    
      FROM dbo.Codelkup WITH (NOLOCK)    
      WHERE ListName = 'XValidTote'    
    
      IF ISNULL(RTRIM(@cRegExpression),'')  <> ''    
      BEGIN    
         IF master.dbo.RegExIsMatch(@cRegExpression, RTRIM( @cNewCartonID), 1) <> 1   -- (ChewKP01)    
         BEGIN    
            SET @nErrNo = 86065    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidCartonID    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO STEP_4_FAIL    
         END    
      END    
    
-- (ChewKP02)    
--      IF @cLightLoc = ''    
--      BEGIN    
--         SET @nErrNo = 83824    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTSLocReq'    
--         EXEC rdt.rdtSetFocusField @nMobile, 2    
--         SET @cLightLoc = ''    
--         EXEC rdt.rdtSetFocusField @nMobile, 3    
--         GOTO STEP_4_FAIL    
--      END    
    
--      IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK)    
--                        WHERE Loc = @cLightLoc    
--                        AND PutawayZone = @cPTSZone )    
--      BEGIN    
--         SET @nErrNo = 83825    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LightLocDiffZone'    
--         SET @cLightLoc = ''    
--         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
--         GOTO STEP_4_FAIL    
--      END    
--    
--      SET @cModuleAddr = RIGHT(@cLightLoc,4)    
--    
      SELECT   @cDeviceProfileKey = DeviceProfileKey    
      FROM dbo.DeviceProfileLog WITH (NOLOCK)    
      --WHERE DeviceID     = @cLightLoc   -- (ChewKP02)    
      WHERE DropID = @cCloseCartonID    
      AND DeviceProfileLogKey = @cDeviceProfileLogKey    
      --AND DevicePosition = @cModuleAddr    
--    
--      IF ISNULL(@cDevicePRofileKey,'') = ''    
--      BEGIN    
--         SET @nErrNo = 83826    
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidPosition'    
--         SET @cLightLoc = ''    
--         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
--         GOTO STEP_4_FAIL    
--      END    
    
      -- Insert into LightLoc_Detail Table    
      IF NOT EXISTS (SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)    
                     WHERE DeviceProfileKey = @cDeviceProfileKey    
                     AND DropID = @cNewCartonID    
                     AND Status = '0' )    
      BEGIN    
         INSERT INTO DeviceProfileLog(DeviceProfileKey, OrderKey, DropID, Status, DeviceProfileLogKey, ConsigneeKey, UserDefine02)    
         SELECT DeviceProfileKey, '', @cNewCartonID, '3' , DeviceProfileLogKey, ConsigneeKey, UserDefine02    
         FROM dbo.DeviceProfileLog WITH (NOLOCK)    
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
         AND DropID = @cCloseCartonID    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83827    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDProfileLogFail'    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
            GOTO STEP_4_FAIL    
         END    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)    
                     WHERE DropID = @cNewCartonID )    
      BEGIN    
         SET @cDropLoc = ''    
         SELECT TOP 1 @cDropLoc = ISNULL(RTRIM(DeviceId),'')    
         FROM PTLTran WITH (NOLOCK)    
         WHERE CaseId = @cNewCartonID    
    
         INSERT INTO DROPID (DropID , DropLoc ,DropIDType , Status , Loadkey, PickSlipNo)    
         -- SOS#343844 (Start)    
         VALUES (@cNewCartonID, @cDropLoc, 'PTS', '3', @cLoadKey, @cPickSlipNo)    
         -- SELECT @cNewCartonID, DropLoc, DropIDType, '3', LoadKey, PickSlipNo    
         -- FROM dbo.DropID WITH (NOLOCK)    
         -- WHERE DropID = @cCloseCartonID    
         -- AND LoadKey = @cLoadKey    
         -- AND PickSlipNo = @cPickSlipNo    
         -- AND DropIDType = 'PTS' -- (ChewKPXX)    
         -- SOS#343844 (End)    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 83828    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsDropIDFail'    
 EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
            GOTO STEP_4_FAIL    
         END    
      END    
      ELSE  -- (ChewKP08)    
      BEGIN    
  SET @nErrNo = 86072    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDExist'    
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
         GOTO STEP_4_FAIL    
      END    
    
      -- (ChewKP06)    
      SET @nPTLKey = 0    
    
 DECLARE CursorPTLTranCaseID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
    
      SELECT PTLKey    
      FROM dbo.PTLTRAN WITH (NOLOCK)    
      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
      AND DropID = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
      AND CaseID = @cCloseCartonID    
      AND Status IN ('0', '1')    
      ORDER BY PTLKey    
    
      OPEN  CursorPTLTranCaseID    
      FETCH NEXT FROM CursorPTLTranCaseID INTO @nPTLKey    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         -- Update PTLTran to New Carton ID --    
         UPDATE dbo.PTLTran WITH (ROWLOCK)    
           SET CaseID = @cNewCartonID    
         WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
         AND DropID = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
         AND CaseID = @cCloseCartonID    
         AND Status IN ('0', '1')    
         AND PTLKey = @nPTLKey    
    
         IF @@ERROR <> 0    
         BEGIN    
               SET @nErrNo = 83832    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'    
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
               GOTO STEP_4_FAIL    
         END    
    
         FETCH NEXT FROM CursorPTLTranCaseID INTO @nPTLKey    
      END    
      CLOSE CursorPTLTranCaseID    
      DEALLOCATE CursorPTLTranCaseID    
    
      -- If there is remaining Quantity on the Old Carton ID and it is not short pick --    
      -- Relight the PTS for the cartonID with remaining Qty    
      IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)    
                  WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
                  AND CaseID = @cNewCartonID    
                  AND DropID = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
                  AND Status = '0' )    
      BEGIN    
    
         -- Initial Light Command Start    
--         EXEC [RDT].[rdt_PTL_PTS_InsertPTLTran]    
--           @nMobile     =  @nMobile    
--          ,@nFunc       =  @nFunc    
--          ,@cFacility   =  @cFacility    
--          ,@cStorerKey  =  @cStorerKey    
--          ,@cPTSZone    =  @cPTSZone    
--          ,@cDropID     =  @cObjectID    
--          ,@cDropIDType =  @cObjectType    
--          ,@cUserName   =  @cUserName    
--          ,@cLangCode   =  @cLangCode    
--          ,@nErrNo      =  @nErrNo       OUTPUT    
--          ,@cErrMsg     =  @cErrMsg      OUTPUT    
--          ,@cDeviceProfileLogKey = @cDeviceProfileLogKey OUTPUT    
    
         -- Initial Light Command Start    
         EXEC [RDT].[rdt_PTL_PTS_LightUp]    
              @nMobile              =  @nMobile    
             ,@nFunc                =  @nFunc    
             ,@cFacility            =  @cFacility    
             ,@cStorerKey           =  @cStorerKey    
             ,@cPTSZone             =  @cPTSZone    
             ,@cDropID              =  @cObjectID    
             ,@cDropIDType          =  @cObjectType    
             ,@cDeviceProfileLogKey =  @cDeviceProfileLogKey    
             ,@cUserName            =  @cUserName    
             ,@cLangCode            =  @cLangCode    
             ,@nErrNo               =  @nErrNo       OUTPUT    
             ,@cErrMsg              =  @cErrMsg      OUTPUT    
    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
            --EXEC rdt.rdtSetFocusField @nMobile, 1    
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- Light Position    
            GOTO Step_4_Fail    
         END    
      END    
    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
      SET @cOutField03 = CASE WHEN @cObjectType = 'TOTE' THEN 'MIXED SKU' ELSE @cSKU END    
      SET @cOutField04 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20)  END    
      SET @cOutField05 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 20) END    
      SET @cOutField06 = @cUCCNextLoc-- Residual UCC Location    
      SET @cOutField07 = ''    
    
      -- GOTO Next Screen -- Close Tote    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
 END  -- Inputkey = 1    
 GOTO QUIT    
    
-- IF @nInputKey = 0    
-- BEGIN    
--    
--         -- Prepare Next Screen Variable    
--         SET @cOutField01 = @cPTSZone    
--         SET @cOutField02 = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
--         SET @cOutField03 = CASE WHEN @cObjectType = 'TOTE' THEN 'MIXED SKU' ELSE @cSKU END    
--         SET @cOutField04 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20)  END    
--         SET @cOutField05 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 20) END    
--         SET @cOutField06 = @cUCCNextLoc-- Residual UCC Location    
--         SET @cOutField07 = ''    
--    
--         -- GOTO Next Screen -- Close Tote    
--         SET @nScn  = @nScn - 1    
--         SET @nStep = @nStep - 1    
--    
--    
--    
-- END    
-- GOTO Quit    
    
 STEP_4_FAIL:    
 BEGIN    
    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cCloseCartonID    
      SET @cOutField02 = @cNewCartonID    
      --SET @cOutField03 = @cLightLoc    
 END    
END    
GOTO QUIT    
    
/********************************************************************************    
Step 5. Scn = 3734.    
    
   Close Tote ID Short Pack (field01)    
    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
      GOTO QUIT    
    
      -- If there is remaining Quantity to be put into the Tote for this Consignee go to Assign New Tote--    
      --SET @nPendingTote = 0    
    
--      SELECT @nPendingTote = Count(DISTINCT D.DropID)    
--      FROM dbo.DropID D WITH (NOLOCK)    
--      INNER JOIN dbo.DeviceProfileLog DP WITH (NOLOCK) ON DP.DropID = D.DropID    
--      WHERE D.LoadKey              = @cLoadKey    
--      AND   D.PickSlipNo           = @cPickSlipNo    
--      AND   D.Status               <> '9'    
--      AND   DP.DeviceProfileLogKey = @cDeviceProfileLogKey    
--      AND   DP.ConsigneeKey        = @cConsigneeKey    
--    
--    
--      IF ISNULL(@nPendingTote,0) = 0    
--      BEGIN    
--         SELECT @nPendingTote = Count(DISTINCT PTL.DropID)    
--         FROM dbo.PTLTran PTL WITH (NOLOCK)    
--         WHERE PTL.DeviceProfileLogKey = @cDeviceProfileLogKey    
--         AND PTL.Status <> '9'    
--         AND PTL.ConsigneeKey = @cConsigneeKey    
--    
--      END    
    
--      SELECT @cConsigneeKey = ConsigneeKey    
--      FROM dbo.DeviceProfileLog WITH (NOLOCK)    
--      WHERE DeviceProfileLogKey = @cDeviceProfileLogKey    
--      AND DropID = @cCloseCartonID    
--      AND UserDefine02 = @cLoadKey    
--    
--      DECLARE @tPack2 TABLE    
--                (ConsigneeKey NVARCHAR(10),    
--                 PickSlipNo   NVARCHAR(10),    
--                 LoadKey      NVARCHAR(10),    
--                 DropIDPD     NVARCHAR(20),    
--                 DropIDPTL    NVARCHAR(20) )    
--    
--      INSERT INTO @tPack2    
--      SELECT OD.UserDefine02 , @cPickSlipNo, @cLoadKey, PD.DropID, ''    
--      FROM dbo.PickDetail PD WITH (NOLOCK)    
--      INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey    
--      INNER JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)    
--      WHERE PD.PickslipNo = @cPickslipNo    
--      AND PD.Status IN ( '3', '5' )    
--      AND O.LoadKey = @cLoadKey    
--      AND OD.UserDefine02 = @cConsigneeKey    
--    
--      DECLARE CUR_PTLTRAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
--    
--      SELECT DISTINCT PTL.DropID FROM dbo.PTLTRAN PTL    
--      INNER JOIN dbo.DeviceProfileLog DL WITH (NOLOCK) ON DL.DeviceProfileLogKey = PTL.DeviceProfileLogKey    
--      WHERE DL.ConsigneeKey = @cConsigneeKey    
--        AND DL.UserDefine02 = @cLoadKey    
--    
--    
--      OPEN CUR_PTLTRAN    
--      FETCH NEXT FROM CUR_PTLTRAN INTO @cDropIDPTL    
--      WHILE @@FETCH_STATUS <> -1    
--      BEGIN    
--    
--         IF EXISTS ( SELECT 1 FROM @tPack2    
--                     WHERE ConsigneeKey = @cConsigneeKey    
--                     AND LoadKey = @cLoadKey    
--                     AND PickSlipNo = @cPickSlipNo    
--                     AND DropIDPD = @cDropIDPTL )    
--         BEGIN    
--    
--            UPDATE @tPack2    
--            SET DropIDPTL = @cDropIDPTL    
--            WHERE ConsigneeKey = @cConsigneeKey    
--            AND LoadKey = @cLoadKey    
--            AND PickSlipNo = @cPickSlipNo    
--            AND DropIDPD = @cDropIDPTL    
--    
--         END    
--    
--         FETCH NEXT FROM CUR_PTLTRAN INTO @cDropIDPTL    
--    
--      END    
--      CLOSE CUR_PTLTRAN    
--      DEALLOCATE CUR_PTLTRAN    
--    
--      IF EXISTS ( SELECT 1 FROM @tPack2 WHERE ConsigneeKey = @cConsigneeKey    
--                                                AND ISNULL(DropIDPTL,'') = ''    
--                                                AND PickSlipNo = @cPickSlipNo    
--                                                AND LoadKey = @cLoadKey )    
--      BEGIN    
--    
--         -- Prepare Next Screen Variable    
--         SET @cOutField01 = @cCloseCartonID    
--         SET @cOutField02 = ''    
--         SET @cOutField03 = ''    
--    
--         -- GOTO Screen 4    
--         SET @nScn = @nScn - 1    
--         SET @nStep = @nStep - 1    
--    
--         GOTO QUIT    
--    
--      END    
--      ELSE    
--      BEGIN    
--        -- Prepare Next Screen Variable    
--        SET @cOutField01 = @cPTSZone    
--        SET @cOutField02 = ''    
--        SET @cOutField03 = ''    
--    
--        -- GOTO Next Screen -- Tote / UCC    
--        SET @nScn = @nScn - 3    
--        SET @nStep = @nStep - 3    
--    
--        GOTO QUIT    
--    
--      END    
    
   END  -- Inputkey = 1    
    
   IF @nInputKey = 0    
   BEGIN    
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cPTSZone    
      SET @cOutField02 = CASE WHEN @cObjectType = 'UCC' THEN @cUCCNo ELSE @cToteNo END    
      SET @cOutField03 = CASE WHEN @cObjectType = 'TOTE' THEN 'MIXED SKU' ELSE @cSKU END    
      SET @cOutField04 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 1, 20)  END    
      SET @cOutField05 = CASE WHEN @cObjectType = 'TOTE' THEN '' ELSE SUBSTRING( @cSKUDescr, 21, 20) END    
      SET @cOutField06 = @cUCCNextLoc-- Residual UCC Location    
      SET @cOutField07 = ''    
    
      -- GOTO Previous Screen    
      SET @nScn = @nScn - 2    
      SET @nStep = @nStep - 2    
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
    ErrMsg = @cErrMsg,    
      Func   = @nFunc,    
      Step   = @nStep,    
      Scn    = @nScn,    
    
      StorerKey = @cStorerKey,    
      Facility  = @cFacility,    
      Printer   = @cLabelPrinter,    
      Printer_Paper = @cPaperPrinter,    
    
      --UserName  = @cUserName,    
      Editdate  = GetDate(),    
      InputKey  = @nInputKey,    
    
      V_UOM        = @cPUOM,    
      V_LoadKey    = @cLoadKey    ,    
      V_PickSlipNo = @cPickSlipNo ,    
      V_SKU        = @cSKU        ,    
      V_SKUDescr   = @cSKUDescr   ,    
      V_Zone       = @cPTSZone    ,    
    
      V_String1 = @cToteNo              ,    
      V_String2 = @cUCCNo               ,    
      V_String3 = @cObjectID            ,    
      V_String4 = @cCloseCartonID       ,    
      V_String5 = @cNewCartonID         ,    
      V_String6 = @cDeviceProfileLogKey ,    
      V_String7 = @cUCCNextLoc          ,    
      V_String8 = @cConsigneeKey        ,    
      V_String9 = @cWCS                 ,    
      V_String10 = @cPTSLoc             ,    
      V_String11 = @cObjectType         ,    
      V_String12 = @cPrevWaveKey        ,    
      V_String13 = @cExtendedUpdateSP   ,    
    
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