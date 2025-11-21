SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/  
/* Store procedure: rdtfnc_ToteConsolidation                                 */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: Tote Consolidation                                               */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date       Rev  Author   Purposes                                         */  
/* 2010-08-11 1.0  ChewKP   SOS# 175742 Created                              */  
/* 2010-09-13 1.1  James    Get the correct consignee (james01)              */  
/* 2010-10-29 1.2  Shong    Do not Mix Load for From/To Tote                 */  
/* 2011-06-21 1.3  James    SOS218836 - Bug fix on PTS loc display (james02) */  
/* 2012-10-15 1.4  ChewKP   SOS#258419 - Addtional screen to Close Tote      */
/*                          after consolidation (ChewKP02)                   */
/* 2012-10-30 1.5  James    SOS260282 - Extra validation on tote (james03)   */  
/* 2013-03-28 1.6  ChewKP   SOS#273493 - Close Tote on Whole Tote (ChewKP03) */
/* 2014-05-29 1.7  James    SOS312212 - Extend variable DefaultToteLength    */
/*                          from 1 char to 2 char (james04)                  */
/* 2014-08-18 1.8  James    SOS316568 - Add extended printing (james05)      */
/* 2014-09-02 1.9  James    SOS319877 - Add international order processing   */
/*                          logic (james06)                                  */
/* 2015-08-05 2.0  James    SOS348965 - Add extended update (james07)        */
/* 2015-09-09 2.1  James    Add extended validate to step 4 & 5 (james08)    */
/* 2016-08-11 2.2  James    SOS370235 - Default To Tote# (james09)           */
/* 2016-09-30 2.3  Ung      Performance tuning                               */   
/* 2018-11-16 2.4  Gan      Performance tuning                               */
/*****************************************************************************/  

CREATE PROC [RDT].[rdtfnc_ToteConsolidation](  
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
    
  
   @cFromTote           NVARCHAR(18),  
   @cPickSlipNo         NVARCHAR(10),  
   @cConsigneekey       NVARCHAR(15),    
   @cPackkey            NVARCHAR(10),    
   @cPackUOM03           NVARCHAR(10),         
   @nQtyAvl             INT,  
   @cSKU                NVARCHAR(20),    
   @nQtyMV              INT,  
   @cToTote             NVARCHAR(18),  
   @cSKUFlag            NVARCHAR(1),  
   @cOption             NVARCHAR(1),  
   @cInSKU              NVARCHAR(20),  
   @cFromLoadkey        NVARCHAR(10),  
   @cToLoadkey          NVARCHAR(10),  
   @cTPickSlipNo        NVARCHAR(10),  
   @cTConsigneekey      NVARCHAR(15),    
   @cInToTote           NVARCHAR(18),  
   @cConsoOption        NVARCHAR(1),  
   @nSKUCnt             INT,  
   @n_Err               INT,  
   @c_ErrMsg            NVARCHAR(20),  
   @cQtyMV              NVARCHAR(5),  
   @nTotPack            INT,  
   @nTote_QTY           INT,  
   @nSumPackQTY         INT,  
   @nSumPickQTY         INT,  
   @cOrderKey           NVARCHAR(10),  
   @nCartonNo           INT,   
   @cLabelLine          NVARCHAR(5),  
   @cPDOrderkey         NVARCHAR(10),  
   @cPOrderkey          NVARCHAR(10),  
   @cPDPickSlipNo       NVARCHAR(10),  
   @cPTSLOC             NVARCHAR(10),  
   @cLabelPrinted       NVARCHAR(10),  
   @cManifestPrinted    NVARCHAR(10),  
   @cPickMethod         NVARCHAR(10),  
   @cDropIDStatus       NVARCHAR(10),  
   @cLoadKey            NVARCHAR(10),  
   @cReportType         NVARCHAR( 10),                  
   @cPrintJobName       NVARCHAR( 50),                  
   @cDataWindow         NVARCHAR( 50),                  
   @cTargetDB           NVARCHAR( 20),        
   @cPrinter_Paper      NVARCHAR( 10), -- (ChewKP02)      
   @cDefaultToteLength  NVARCHAR( 2),  -- (james03)/(james04)
   @cExtendedPrintSP    NVARCHAR( 20),  -- (james05)  
   @cSQL                NVARCHAR(MAX),  -- (james05)  
   @cSQLParam           NVARCHAR(MAX),  -- (james05)  
   @cSKUscan            NVARCHAR( 20),  -- (james06)  
   @cLOCscan            NVARCHAR( 20),  -- (james06)  
   @cDescr              NVARCHAR( 60),  -- (james06)  
   @cPTS_Station        NVARCHAR( 10),  -- (james06)  
   @cExtendedInfo       NVARCHAR( 20),  -- (james06)  
   @cExtendedInfoSP     NVARCHAR( 20),  -- (james06)  
   @cExtendedUpdateSP   NVARCHAR( 20),  -- (james07)       
   @cExtendedValidateSP NVARCHAR( 20),  -- (james07)   
   @nAfterStep          INT,            -- (james07)     
   @cDefaultTote_SP     NVARCHAR( 20),  -- (james09)   
   @cDefToToteNo        NVARCHAR( 20),  -- (james09)   
   
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
   @cPrinter_Paper   = Printer_Paper,     
   @cUserName        = UserName,     
     
   @cConsigneekey    = V_ConsigneeKey,  
   @cSKU             = V_SKU,  
   @cPTSLOC          = V_LOC,   
   @cPackUOM03       = V_UOM,  
   @cPickSlipNo      = V_String1,  
   @cFromTote        = V_String2,  
   @cPackkey         = V_String3,  
  -- @nQtyAvl          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 5), 0) = 1 THEN LEFT( V_String4, 5) ELSE 0 END,  
  -- @nQtyMV           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 5), 0) = 1 THEN LEFT( V_String5, 5) ELSE 0 END,  
   @cToTote          = V_String6,  
   @cConsoOption     = V_String7,  
   @cLabelPrinted    = V_String8,  
   @cLoadKey         = V_String9, 
   @cSkuScan         = V_String10, 
   @cLocScan         = V_String11, 
   
   @nQtyAvl          = V_Integer1,
   @nQtyMV           = V_Integer2,   
        
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
IF @nFunc = 973  
BEGIN  
   -- (ChewKP03)
   DECLARE @nStepCloseTote       INT,
            @nScnCloseTote        INT
   
   SET @nStepCloseTote       = 9
   SET @nScnCloseTote        = 2468            
       
          
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 973  
   IF @nStep = 1 GOTO Step_1   -- Scn = 2460  From Tote  
   IF @nStep = 2 GOTO Step_2   -- Scn = 2461  SKU/UPC  
   IF @nStep = 3 GOTO Step_3   -- Scn = 2462  Qty MV  
   IF @nStep = 4 GOTO Step_4   -- Scn = 2463  To Tote  
   IF @nStep = 5 GOTO Step_5   -- Scn = 2464  To Tote ( For Move by Whole Tote )  
   IF @nStep = 6 GOTO Step_6   -- Scn = 2465  OPTION (Create Tote)  
   IF @nStep = 7 GOTO Step_7   -- Scn = 2466  To Tote (Successful)  
   IF @nStep = 8 GOTO Step_8   -- Scn = 2467  Option  
   IF @nStep = 9 GOTO Step_9   -- Scn = 2468  Close Tote -- (ChewKP02)
   IF @nStep = 10 GOTO Step_10   -- Scn = 2469 SKU, LOC  -- (james06)
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 973)  
********************************************************************************/  
Step_0:  
BEGIN  
   -- Set the entry point  
   SET @nScn  = 2460  
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
   SET @cOutField12 = ''   
   SET @cOutField13 = ''   
   SET @cOutField14 = ''   
   SET @cOutField15 = ''   
END  
GOTO Quit  
  
/********************************************************************************  
Step 1. screen = 2460  
   FROM TOTE (Field01, input)  
     
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cFromTote    = ISNULL(@cInField01,'')  
        
      IF ISNULL(RTRIM(@cFromTote), '') = ''  
      BEGIN  
         SET @nErrNo = 70266  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToteNo Req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cOption  
         GOTO Quit  
      END   

      -- Check the length of tote no (james03); 0 = No Check  
      SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
      IF ISNULL(@cDefaultToteLength, '') = ''  
      BEGIN  
         SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup  
      END  
  
      IF @cDefaultToteLength <> '0'  
      BEGIN  
         IF LEN(RTRIM(@cFromTote)) <> @cDefaultToteLength  
         BEGIN  
            SET @nErrNo = 70307  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            SET @cOutField01 = ''  
            SET @cOutField02 = @cOption  
            GOTO Quit  
         END  
      END  
  
      -- (james03)  
      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)  
                 WHERE Listname = 'XValidTote'  
                    AND Code = SUBSTRING(RTRIM(@cFromTote), 1, 1))  
      BEGIN  
         SET @nErrNo = 70308  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTE NO  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cOption  
         GOTO Quit  
      END  
  
      -- Get the Pick Method for Tote   
      SET @cPickMethod=''  
      SET @cLabelPrinted=''  
      SET @cManifestPrinted=''  
      SET @cDropIDStatus=''  
        
      SELECT @cPickMethod = DropIDType,  
             @cLabelPrinted = LabelPrinted,   
             @cManifestPrinted = ManifestPrinted,  
             @cDropIDStatus=[Status]  
      FROM   DROPID WITH (NOLOCK)   
      WHERE  DROPID = @cFromTote   
         
      IF @cPickMethod <> 'PIECE'   
      BEGIN  
         SET @nErrNo = 70267  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cOption  
         GOTO Quit           
      END  
  
      IF @cManifestPrinted = 'Y' AND @cDropIDStatus <> '9'  
      BEGIN  
       SET @nErrNo = 70284  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Manifest Print  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cOption  
         GOTO Quit  
    END  
        
      IF @cLabelPrinted = 'Y' AND @cDropIDStatus <> '9'  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cFromTote )   
         BEGIN  
            SET @nErrNo = 70267  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            SET @cOutField01 = ''  
            SET @cOutField02 = @cOption  
            GOTO Quit  
         END            
      END  
      ELSE  
      BEGIN  
         IF NOT EXISTS (SELECT 1  
                        FROM dbo.PickDetail PD WITH (NOLOCK)     
                        JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey     
                        JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
                        JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)  
                        WHERE PD.StorerKey = @cStorerKey                  
                          AND PD.DropID = @cFromTote                  
                          AND PD.Status >= '5'                  
                          AND PD.Status < '9'    
                          AND PD.Qty > 0          
                          AND TD.PickMethod = 'PIECE'        
                          AND TD.Status = '9'       
                          AND O.Status < '9' )  
         BEGIN                  
            SET @nErrNo = 70614                  
            SET @cErrMsg = rdt.rdtgetmessage( 70614, @cLangCode, 'DSP') --Tote Cancel                  
            EXEC rdt.rdtSetFocusField @nMobile, 1                  
            GOTO Quit                    
         END                    
      END  
        
      IF @cDropIDStatus = '9'  
      BEGIN  
       SET @nErrNo = 70285  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Closed  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = ''  
         SET @cOutField02 = @cOption  
         GOTO Quit  
    END  
        
      IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)                   
                 JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
                 JOIN dbo.Dropid d WITH (NOLOCK) ON d.Dropid = TD.DropID AND d.Loadkey = TD.LoadKey             
                 WHERE PD.Storerkey = @cStorerkey     
                 AND TD.DropID = @cFromTote     
                 AND PD.Status < '5'            
                 AND PD.Qty > 0          
                 AND TD.PickMethod = 'PIECE'        
                 AND TD.Status = '9')                       
      OR NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)                  
                     WHERE Storerkey = @cStorerkey AND DropID = @cFromTote)                           
      BEGIN          
         SET @nErrNo = 70610                 
         SET @cErrMsg = rdt.rdtgetmessage( 70610, @cLangCode, 'DSP') --ToteNotPicked                
         EXEC rdt.rdtSetFocusField @nMobile, 1                  
         GOTO Quit                 
      END          
        
        
      IF NOT EXISTS (SELECT 1   
      FROM PICKDETAIL PD (NOLOCK)   
      INNER JOIN ORDERS O WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY    --(james01)  
      INNER JOIN DROPID DROPID WITH (NOLOCK) ON PD.DROPID = DROPID.DROPID AND O.LOADKEY = DROPID.LOADKEY  
      WHERE PD.DropID = @cFromTote  
         AND O.StorerKey = @cStorerKey  
         AND O.Status NOT IN ('9', 'CANC'))  
      BEGIN  
         SET @nErrNo = 70290  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Shipped  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_1_Fail    
      END  
  
      SELECT TOP 1 @cConsigneekey = O.ConsigneeKey, @cLoadKey = O.LoadKey, @cPTSLOC = TD.TOLOC  
      FROM dbo.PICKDETAIL PD (NOLOCK)   
      INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY    --(james01)  
      INNER JOIN dbo.DROPID DROPID WITH (NOLOCK) ON PD.DROPID = DROPID.DROPID AND O.LOADKEY = DROPID.LOADKEY  
      INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   -- (james02)  
      WHERE PD.DropID = @cFromTote  
         AND O.StorerKey = @cStorerKey  
         AND O.Status NOT IN ('9', 'CANC')  
  
      -- (james02)  
      IF ISNULL(@cPTSLOC, '') = ''  
      BEGIN  
         SELECT TOP 1 @cPTSLOC = LOC   
         FROM dbo.StoreToLocDetail WITH (NOLOCK)   
         WHERE ConsigneeKey = @cConsigneekey  
         AND   Status = '1'  
      END  
       
     -- EventLog - Sign Out Function  
      EXEC RDT.rdt_STD_EventLog  
         @cActionType = '1', -- Sign Out function  
         @cUserID     = @cUserName,  
         @nMobileNo   = @nMobile,  
         @nFunctionID = @nFunc,  
         @cFacility   = @cFacility,  
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep
        
      SET @cOutField01 = ''  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = @cPTSLOC  
      SET @cOutField04 = @cFromTote   
           
      SET @nStep = 8   
      SET @nScn  = 2467   
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
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
   END  
   GOTO Quit  
  
   Step_1_Fail:  
   BEGIN  
        
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 2. screen = 2461  
   FROM TOTE            (Field01)  
   STORER               (Field02)  
   SKU/UPC              (Field03 , Input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cInSKU = @cInField03  
  
      IF ISNULL(@cInSKU,'') = ''  
      BEGIN  
         SET @nErrNo = 70270  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Step_2_Fail    
      END  
  
      EXEC [RDT].[rdt_GETSKUCNT]      
         @cStorerKey  = @cStorerKey,      
         @cSKU        = @cInSKU,  
         @nSKUCnt     = @nSKUCnt       OUTPUT,  
         @bSuccess    = @b_Success     OUTPUT,  
         @nErr        = @n_Err         OUTPUT,  
         @cErrMsg     = @c_ErrMsg      OUTPUT  
               
      -- Validate SKU/UPC      
      IF @nSKUCnt = 0      
      BEGIN      
         SET @nErrNo = 70291      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'      
         GOTO Step_2_Fail      
      END      
         
      -- Validate barcode return multiple SKU      
      IF @nSKUCnt > 1      
      BEGIN      
         SET @nErrNo = 70292  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SameBarCodeSKU'  
         GOTO Step_2_Fail      
      END      
       
      EXEC [RDT].[rdt_GETSKU]      
         @cStorerKey  = @cStorerKey,  
         @cSKU        = @cInSKU        OUTPUT,  
         @bSuccess    = @b_Success     OUTPUT,  
         @nErr        = @n_Err         OUTPUT,  
         @cErrMsg     = @c_ErrMsg      OUTPUT  
  
     SET @cSKU = @cInSKU  
  
     SET @cPackkey = ''  
   SELECT @cPackkey = Packkey FROM dbo.SKU WITH (NOLOCK)  
   WHERE SKU = @cSKU   
   AND Storerkey = @cStorerkey   
  
   SET @cPackUOM03 = ''  
   SELECT @cPackUOM03 = PackUOM3 FROM dbo.PACK WITH (NOLOCK)  
   WHERE Packkey = @cPackkey  
     
     SET @nQtyAvl = 0  
       
     -- Tote Already Pack?   
     IF @cLabelPrinted = 'Y'  
     BEGIN  
      SELECT @nQtyAvl = ISNULL(SUM(PD.Qty), 0)   
      FROM dbo.PackDetail PD WITH (NOLOCK)  
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo     
         JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey    
         JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)          
         WHERE PD.StorerKey = @cStorerKey                  
           AND PD.DropID = @cFromTote                   
           AND PD.Qty > 0                
           AND O.Status < '9'         
         AND PD.SKU = @cSKU          
     END   
     ELSE  
     BEGIN  
        SELECT @nQtyAvl = ISNULL(SUM(PD.Qty), 0)      
         FROM dbo.PickDetail PD WITH (NOLOCK)     
         JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey     
         JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
         JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)          
         WHERE PD.StorerKey = @cStorerKey                  
           AND PD.DropID = @cFromTote                  
           AND PD.Status >= '5'                  
           AND PD.Status < '9'    
           AND PD.Qty > 0          
           AND TD.PickMethod = 'PIECE'        
           AND TD.Status = '9'       
           AND O.Status < '9'   
           AND TD.SKU = @cSKU  
     END  
  
     --prepare next screen variable  
     SET @cOutField01 = @cFromTote  
     SET @cOutField02 = @cConsigneekey  
     SET @cOutField03 = @cSKU  
     SET @cOutField04 = @cPackUOM03  
     SET @cOutField05 = @nQtyAvl  
     SET @cOutField06 = ''  
  
     SET @nScn = @nScn + 1  
     SET @nStep = @nStep + 1  
   END  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''   
      SET @cOutField02 = @cConsigneekey   
      SET @cOutField03 = @cPTSLOC   
      SET @cOutField04 = @cFromTote   
      SET @cOutField05 = ''   
      SET @cOutField06 = ''   
      SET @cOutField07 = ''   
      SET @cOutField08 = ''   
      SET @cOutField09 = ''   
      SET @cOutField10 = ''   
      SET @cOutField11 = ''   
     
      SET @cSKU = ''  
  
      SET @nScn  = 2467   
      SET @nStep = 8  
   END  
  
   GOTO Quit  
  
   Step_2_Fail:  
   BEGIN  
      SET @cOutField01 = @cFromTote  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. screen = 2462  
 From Tote     (Field01)  
 Store         (Field02)  
 SKU           (Field03)  
 UOM           (Field04)  
 Qty Avl       (Field05)  
 Qty MV        (Field06, Input)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
       -- Screen mapping  
      SET @cQtyMV = ISNULL(@cInField06,0)  
  
      IF @cQtyMV  = ''   SET @cQtyMV  = '0' --'Blank taken as zero'  
      IF rdt.rdtIsValidQTY( @cQtyMV, 1) = 0   
      BEGIN        
         SET @nErrNo = 70271         
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty        
         GOTO Step_3_Fail            
      END        
        
      SET @nQtyMV = CAST(@cQtyMV AS INT)  
  
      IF @nQtyMV > @nQtyAvl   
      BEGIN  
         SET @nErrNo = 70274  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYMV > QTYAVL  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_3_Fail    
      END  
        
      IF @nQtyMV < 0  
      BEGIN  
         SET @nErrNo = 70275  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_3_Fail    
      END  
          
      --prepare next screen variable  
      SET @cOutField01 = @cFromTote  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = @cPackUOM03  
      SET @cOutField05 = @nQtyMV  
      SET @cOutField06 = ''  
  
      SET @nScn   = @nScn + 1  
      SET @nStep  = @nStep + 1  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
        
     SET @cOutField01 = @cFromTote  
     SET @cOutField02 = @cConsigneekey  
     SET @cOutField03 = ''  
  
     SET @nScn = @nScn - 1  
     SET @nStep = @nStep - 1  
       
   END  
   GOTO Quit  
     
   Step_3_Fail:  
   BEGIN  
     SET @cOutField01 = @cFromTote  
     SET @cOutField02 = @cConsigneekey  
     SET @cOutField03 = @cSKU  
     SET @cOutField04 = @cPackUOM03  
     SET @cOutField05 = @nQtyAvl  
     SET @cOutField06 = ''  
   END  
     
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. screen = 2463   
  FROM Tote (Field01)  
  Store     (Field02)  
  SKU       (Field03)  
  UOM       (Field04)  
  QTY MV    (Field05)  
  TO Tote   (Field06, Input)     
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
       -- Screen mapping  
      SET @cToTote = @cInField06  
        
      -- Get the default to tote no (james09)
      SET @cDefaultTote_SP  = rdt.RDTGetConfig( @nFunc, 'DefaultToToteSP', @cStorerKey)      
      IF ISNULL(@cDefaultTote_SP, '') IN ('', '0')      
         SET @cDefaultTote_SP = ''  
      
      -- (james09)
      -- If tote not defaulted previously but config turned on, generate the tote no here
      IF @cToTote = '' AND 
         @cDefaultTote_SP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultTote_SP AND type = 'P') 
      BEGIN
         SET @cDefToToteNo = ''
         SET @nErrNo = 0
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDefaultTote_SP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromTote, @cConsigneekey, @cPTSLOC,  ' +
            ' @cSKU, @nQty, @cOption, @cToTote, @cDefToToteNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFromTote       NVARCHAR( 20), ' +
            '@cConsigneekey   NVARCHAR( 15), ' +
            '@cPTSLOC         NVARCHAR( 10), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQty            INT,           ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@cToTote         NVARCHAR( 20), ' +
            '@cDefToToteNo    NVARCHAR( 20)     OUTPUT,  ' +                        
            '@nErrNo          INT               OUTPUT,  ' +
            '@cErrMsg         NVARCHAR( 20)     OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromTote, @cConsigneekey, @cPTSLOC, 
            @cSKU, @nQtyMV, @cOption, @cToTote, @cDefToToteNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Step_4_Fail
         END

         SET @cToTote = @cDefToToteNo
      END

      IF ISNULL(@cToTote,'') = ''  
      BEGIN  
         SET @nErrNo = 70276  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToTote Req  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_4_Fail    
      END  

      IF @cToTote = @cFromTote   
      BEGIN  
         SET @nErrNo = 70285  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70285^Same Tote  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_4_Fail    
      END  

      -- Check the length of tote no (james03); 0 = No Check  
      SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
      IF ISNULL(@cDefaultToteLength, '') = ''  
      BEGIN  
         SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup  
      END  
  
      IF @cDefaultToteLength <> '0'  
      BEGIN  
         IF LEN(RTRIM(@cToTote)) <> @cDefaultToteLength  
         BEGIN  
            SET @nErrNo = 70309  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Step_4_Fail    
         END  
      END  
  
      -- (james03)  
      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)  
                 WHERE Listname = 'XValidTote'  
                    AND Code = SUBSTRING(RTRIM(@cToTote), 1, 1))  
      BEGIN  
         SET @nErrNo = 70310  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTE NO  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_4_Fail    
      END  
      
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                 WHERE DropID = @cToTote   
                 And ManifestPrinted = 'Y'  
                 AND STATUS <> '9')  
      BEGIN  
       SET @nErrNo = 70284  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Manifest Print  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_4_Fail    
      END  
  
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToTote And Status = '9')  
      BEGIN  
         SET @nErrNo = 70285  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Closed  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_4_Fail    
      END  
  
        -- (james07)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3), '  +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromTote       NVARCHAR( 20), ' +
               '@cToTote         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQtyMV          INT,        '    +
               '@cConsoOption    NVARCHAR( 1), '  +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'  


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_4_Fail    
         END
      END
      
      --OR NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE DropID = @cToTote)  
      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToTote AND STATUS < '9')        
      BEGIN  
         -- Goto Create New Tote Screen  
         -- Prepare next screen variable  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
         
           
         SET @nScn   = 2465  
         SET @nStep  = 6  
  
         GOTO Quit  
      END  
  
      SET @cToLoadkey = ''  
      SELECT @cToLoadkey = LoadKey  
      FROM   Dropid d WITH (NOLOCK) WHERE d.Dropid = @cToTote  
  
      SET @cFromLoadkey = ''  
      SELECT @cFromLoadkey = LoadKey  
      FROM   Dropid d WITH (NOLOCK) WHERE d.Dropid = @cFromTote   
        
      IF ISNULL(RTRIM(@cFromLoadkey),'') <> ISNULL(RTRIM(@cToLoadkey),'')   
      BEGIN  
         SET @nErrNo = 70286                                             
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --70286^DoNotMixLoad  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_4_Fail             
      END  
  
        
      SET @cTPickSlipNo = ''  
  
      -- (james01)  
      SET  @cTConsigneekey = ''  
      SELECT TOP 1 @cTConsigneekey = O.ConsigneeKey   
      FROM dbo.PackDetail PD WITH (NOLOCK)   
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey   
      JOIN dbo.Dropid D WITH (NOLOCK) ON D.Dropid = PD.DropID AND D.Loadkey = PH.LoadKey   
      WHERE PD.DropID = @cToTote   
         AND O.StorerKey = @cStorerKey   
         AND O.Status NOT IN ('9', 'CANC')  
  
  
      
      
      IF @cConsigneekey <> ISNULL(@cTConsigneekey , '' )   
      BEGIN  
         SET @nErrNo = 70277  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotSameStore  
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_4_Fail    
      END  
        
      -- EXECUTE CONFIRM MOVE (Start) --  
      EXEC rdt.rdt_ToteConsolidation_Confirm   
         @nMobile          ,  
         @cStorerKey       ,     
         @cPickSlipNo      ,  
         @cFromTote        ,  
         @cToTote          ,  
         @cLangCode        ,  
         @cUserName        ,  
         @cConsoOption     ,  
         @cSKU             ,  
         @cFacility        ,  
         @nFunc            ,  
         @nQtyMV           ,  
         @nErrNo           OUTPUT ,    
         @cErrMsg          OUTPUT  
           
      IF @nErrNo <> 0   
      BEGIN  
         SET @nErrNo = @nErrNo  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
         EXEC rdt.rdtSetFocusField @nMobile, 6  
         GOTO Step_4_Fail    
      END  
      -- EXECUTE CONFIRM MOVE (End) --  
      
      -- (james07)
      -- Extended update
      SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''

      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3), '  +
               '@nStep           INT,       '     + 
               '@nAfterStep      INT,       '     +                
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromTote       NVARCHAR( 20), ' +
               '@cToTote         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQtyMV          INT,        '    +
               '@cConsoOption    NVARCHAR( 1), '  +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0   
            BEGIN  
               EXEC rdt.rdtSetFocusField @nMobile, 6  
               GOTO Step_4_Fail    
            END  
         END
      END        

      --prepare next screen variable  
      SET @cOutField01 = @cToTote  
      SET @cOutField02 = ''  
      
      SET @nScn  = @nScn + 5
      SET @nStep = @nStep + 5
      
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SELECT @cPTS_Station = ISNULL( PutawayZone, '')
      FROM dbo.LOC WITH (NOLOCK) 
      WHERE LOC = @cPTSLOC
      AND Facility = @cFacility

      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                  WHERE ListName = 'PTS_INT' 
                  AND   Code = @cPTS_Station
                  AND   StorerKey = @cStorerKey)         
      BEGIN
         SET @cOutField01 = @cFromTote  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''   
         SET @cOutField05 = ''   

         EXEC rdt.rdtSetFocusField @nMobile, 2  -- SKU 

         SET @nScn = @nScn + 6  
         SET @nStep = @nStep + 6  
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cFromTote  
         SET @cOutField02 = @cConsigneekey  
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = @cPackUOM03  
         SET @cOutField05 = @nQtyAvl  
         SET @cOutField06 = ''  

         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1  
      END
   END  
   GOTO Quit  
     
   Step_4_Fail:  
   BEGIN  
      SET @cOutField01 = @cFromTote  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = @cPackUOM03  
      SET @cOutField05 = @nQtyMV  
      SET @cOutField06 = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 5. screen = 2464   
  FROM Tote (Field01)  
  Store     (Field02)  
  TO Tote   (Field03, Input)     
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
       -- Screen mapping  
      SET @cToTote = @cInField03  
        
      -- Get the default to tote no (james09)
      SET @cDefaultTote_SP  = rdt.RDTGetConfig( @nFunc, 'DefaultToToteSP', @cStorerKey)      
      IF ISNULL(@cDefaultTote_SP, '') IN ('', '0')      
         SET @cDefaultTote_SP = ''  

      -- (james09)
      -- If tote not defaulted previously but config turned on, generate the tote no here
      IF @cToTote = '' AND 
         @cDefaultTote_SP <> '' AND 
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultTote_SP AND type = 'P') 
      BEGIN
         SET @cDefToToteNo = ''
         SET @nErrNo = 0
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cDefaultTote_SP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromTote, @cConsigneekey, @cPTSLOC, ' +
            ' @cSKU, @nQty, @cOption, @cToTote, @cDefToToteNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,           ' +
            '@nFunc           INT,           ' +
            '@cLangCode       NVARCHAR( 3),  ' +
            '@nStep           INT,           ' +
            '@nInputKey       INT,           ' +
            '@cStorerkey      NVARCHAR( 15), ' +
            '@cFromTote       NVARCHAR( 20), ' +
            '@cConsigneekey   NVARCHAR( 15), ' +
            '@cPTSLOC         NVARCHAR( 10), ' +
            '@cSKU            NVARCHAR( 20), ' +
            '@nQty            INT,           ' +
            '@cOption         NVARCHAR( 1),  ' +
            '@cToTote         NVARCHAR( 20), ' +
            '@cDefToToteNo    NVARCHAR( 20)     OUTPUT,  ' +                        
            '@nErrNo          INT               OUTPUT,  ' +
            '@cErrMsg         NVARCHAR( 20)     OUTPUT   '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFromTote, @cConsigneekey, @cPTSLOC, 
            @cSKU, @nQtyMV, @cOption, @cToTote, @cDefToToteNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
            GOTO Step_5_Fail
         END

         SET @cToTote = @cDefToToteNo
      END

      IF ISNULL(@cToTote,'') = ''  
      BEGIN  
         SET @nErrNo = 70278  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToTote Req  
         GOTO Step_5_Fail    
      END  

      -- Check the length of tote no (james03)/(james04); 0 = No Check  
      SET @cDefaultToteLength  = rdt.RDTGetConfig( @nFunc, 'DefaultToteLength', @cStorerKey)  
      IF ISNULL(@cDefaultToteLength, '') = ''  
      BEGIN  
         SET @cDefaultToteLength = '8'  -- make it default to 8 digit if not setup  
      END  
  
      IF @cDefaultToteLength <> '0'  
      BEGIN  
         IF LEN(RTRIM(@cToTote)) <> @cDefaultToteLength  
         BEGIN  
            SET @nErrNo = 70311  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTENO LEN  
            GOTO Step_5_Fail    
         END  
      END  
  
      -- (james03)  
      IF EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)  
                 WHERE Listname = 'XValidTote'  
                    AND Code = SUBSTRING(RTRIM(@cToTote), 1, 1))  
      BEGIN  
         SET @nErrNo = 70312  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOTE NO  
         GOTO Step_5_Fail    
      END  
      
      IF EXISTS (SELECT 1 FROM dbo.Dropid WITH (NOLOCK)   
                 WHERE DropID = @cToTote   
                 AND ManifestPrinted = 'Y'  
                 AND STATUS <> '9')  
      BEGIN  
         SET @nErrNo = 70284  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Manifest Print  
         GOTO Step_5_Fail    
      END  
  
      -- (james07)
      -- Extended validate
      SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
      IF @cExtendedValidateSP = '0'
         SET @cExtendedValidateSP = ''

      IF @cExtendedValidateSP <> '' 
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,       '     +
               '@nFunc           INT,       '     +
               '@cLangCode       NVARCHAR( 3), '  +
               '@nStep           INT,       '     + 
               '@nInputKey       INT,       '     +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFromTote       NVARCHAR( 20), ' +
               '@cToTote         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQtyMV          INT,        '    +
               '@cConsoOption    NVARCHAR( 1), '  +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT'  


            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_5_Fail    
         END
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToTote AND STATUS < '9')        
      BEGIN  
         -- Goto Create New Tote Screen  
         -- Prepare next screen variable  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
           
         SET @nScn   = 2465  
         SET @nStep  = 6  
  
         GOTO Quit  
      END  
  
      IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToTote )  
      BEGIN  
         -- (james01)  
         SELECT @cTConsigneeKey = ''  
         SELECT TOP 1 @cTConsigneekey = O.ConsigneeKey, @cPickSlipNo = PD.PickSlipNo   
         FROM dbo.PackDetail PD WITH (NOLOCK)  
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo  
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey  
         JOIN dbo.DropID DropID WITH (NOLOCK)   
              ON DropID.DropID = PD.DropID and DropID.LoadKey = O.LoadKey  
         WHERE PD.DropID = @cToTote   
            AND O.StorerKey = @cStorerKey  
            AND O.Status NOT IN ('9', 'CANC')  
  
         IF @cConsigneekey <> ISNULL(@cTConsigneekey , '' )   
         BEGIN  
            SET @nErrNo = 70279  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotSameStore  
            GOTO Step_5_Fail    
         END  
  
         -- Check if from tote already packed. If not need to pack first  
  
         -- EXECUTE CONFIRM MOVE (Start) --  
         EXEC rdt.rdt_ToteConsolidation_Confirm   
            @nMobile         ,     
            @cStorerKey      ,     
            @cPickSlipNo     ,  
            @cFromTote       ,  
            @cToTote         ,  
            @cLangCode       ,  
            @cUserName       ,  
            @cConsoOption    ,  
            ''               ,   -- SKU (no need here as it is whole tote)   
            @cFacility       ,  
            @nFunc           ,              
            0                ,   -- Qty to move (same as above)  
            @nErrNo          OUTPUT ,    
            @cErrMsg         OUTPUT  
           
         IF @nErrNo <> 0   
         BEGIN  
            SET @nErrNo = @nErrNo  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            GOTO Step_5_Fail  --(james01)  
         END  
         -- EXECUTE CONFIRM MOVE (End) --  

         -- (james07)
         -- Extended update
         SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
         IF @cExtendedUpdateSP = '0'
            SET @cExtendedUpdateSP = ''

         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3), '  +
                  '@nStep           INT,       '     + 
                  '@nAfterStep      INT,       '     +                
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromTote       NVARCHAR( 20), ' +
                  '@cToTote         NVARCHAR( 20), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQtyMV          INT,        '    +
                  '@cConsoOption    NVARCHAR( 1), '  +
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0   
                  GOTO Step_5_Fail    
            END
         END   

         --prepare next screen variable  
         SET @cOutField01 = @cToTote  
         SET @cOutField02 = ''  
            
         SET @nScn   = @nScn + 2  
         SET @nStep  = @nStep + 2  
      END  
      ELSE  
      BEGIN  
         SET @nErrNo = 70267  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Tote  
         GOTO Step_5_Fail    
      END  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      SET @cOutField01 = ''   
      SET @cOutField02 = @cConsigneekey   
      SET @cOutField03 = @cPTSLOC   
      SET @cOutField04 = @cFromTote   
      SET @cOutField05 = ''   
      SET @cOutField06 = ''   
      SET @cOutField07 = ''   
      SET @cOutField08 = ''   
      SET @cOutField09 = ''   
      SET @cOutField10 = ''   
      SET @cOutField11 = ''   
     
      SET @cSKU = ''  
  
      SET @nScn  = 2467   
      SET @nStep = 8  
             
   END  
   GOTO Quit  
     
   Step_5_Fail:  
   BEGIN  
      SET @cOutField01 = @cFromTote  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 6. screen = 2465  
  OPTION (Field01, Input)     
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
       -- Screen mapping  
      SET @cOption = @cInField01  
           
      IF ISNULL(RTRIM(@cOption),'') = ''  
      BEGIN  
         SET @nErrNo = 70280  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_6_Fail    
      END  
  
      IF ISNUMERIC(@cToTote) = 0 OR CHARINDEX('.', @cToTote) > 0 --(james08)            
      BEGIN                  
         SET @nErrNo = 70607                  
         SET @cErrMsg = rdt.rdtgetmessage( 70607, @cLangCode, 'DSP') --INVALID TOTENO            
         GOTO Step_6_Fail                    
      END            
              
      IF ISNULL(RTRIM(@cOption),'') <> '1' AND ISNULL(RTRIM(@cOption),'') <> '9'  
      BEGIN  
         SET @nErrNo = 70281  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_6_Fail    
      END    
        
      IF @cOption = '1'  
      BEGIN  
         IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK) WHERE DropID = @cToTote AND Status = '9')                
         BEGIN    
            BEGIN TRAN    
       
            DELETE FROM DropID WHERE DropID = @cToTote AND Status = '9'    
       
            IF @@ERROR <> 0    
            BEGIN    
               ROLLBACK TRAN    
              SET @nErrNo = 70611                  
               SET @cErrMsg = rdt.rdtgetmessage( 70611, @cLangCode, 'DSP') --ReleasToteFail                  
               GOTO Step_6_Fail                  
            END    
            ELSE    
            BEGIN    
               COMMIT TRAN    
            END    
                
         END    
         ELSE    
         BEGIN    
            IF EXISTS (SELECT 1 FROM dbo.DROPID WITH (NOLOCK)                 
                       WHERE DropID = @cToTote      
                       AND Status < '9' )                
            BEGIN                
               SET @nErrNo = 70598                  
               SET @cErrMsg = rdt.rdtgetmessage( 70598, @cLangCode, 'DSP') --Tote4OtherStore                  
               EXEC rdt.rdtSetFocusField @nMobile, 5                  
               GOTO Step_6_Fail                   
            END                              
         END    
  
         IF EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)             
                    WHERE DropID = @cToTote     
                    AND ManifestPrinted = 'Y'    
                    AND STATUS < '9')            
         BEGIN                  
            SET @nErrNo = 70608                  
            SET @cErrMsg = rdt.rdtgetmessage( 70608, @cLangCode, 'DSP') --Tote is Closed            
            GOTO Step_6_Fail                    
         END                  
  
           
         IF NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)       
                        WHERE DropID = @cToTote)      
         BEGIN      
            SELECT @cPickSlipNo = PickSlipNo, @cLoadKey = LoadKey 
            FROM dbo.DropID WITH (NOLOCK) 
            WHERE DropID = @cFromTote

            IF ISNULL( @cPickSlipNo, '') = ''
               SELECT @cPickSlipNo = PickHeaderKey 
               FROM dbo.PickHeader WITH (NOLOCK) 
               WHERE LoadKey = @cLoadKey

            INSERT INTO dbo.DropID       
            (Dropid, Droploc, LabelPrinted, [Status], ManifestPrinted, Loadkey, PickSlipNo)    
            VALUES(@cToTote, @cPTSLOC, 'N', '0', 'N', ISNULL(@cLoadKey,''), @cPickSlipNo)      
                   
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 70595      
               SET @cErrMsg = rdt.rdtgetmessage( 70595, @cLangCode, 'DSP') --InsDropIdFail      
               GOTO Step_6_Fail        
            END      
         END      

         IF @cConsoOption = 'F'  
         BEGIN  
            SET @cSKU = ''  
            SET @nQtyMV=0  
         END  
                 
         EXEC rdt.rdt_ToteConsolidation_Confirm   
            @nMobile          ,     
            @cStorerKey       ,     
            @cPickSlipNo      ,  
            @cFromTote        ,  
            @cToTote          ,  
            @cLangCode        ,  
            @cUserName        ,  
            @cConsoOption     ,  
            @cSKU ,  
            @cFacility        ,  
            @nFunc            ,                 
            @nQtyMV           ,  
            @nErrNo           OUTPUT ,    
            @cErrMsg          OUTPUT        
         IF @nErrNo <> 0   
         BEGIN  
            SET @nErrNo = @nErrNo  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Step_4_Fail    
         END                                               
         -- EXECUTE CONFIRM MOVE (End) --  

         -- (james07)
         -- Extended update
         SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
         IF @cExtendedUpdateSP = '0'
            SET @cExtendedUpdateSP = ''

         IF @cExtendedUpdateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile         INT,       '     +
                  '@nFunc           INT,       '     +
                  '@cLangCode       NVARCHAR( 3), '  +
                  '@nStep           INT,       '     + 
                  '@nAfterStep      INT,       '     +                
                  '@nInputKey       INT,       '     +
                  '@cStorerKey      NVARCHAR( 15), ' +
                  '@cFromTote       NVARCHAR( 20), ' +
                  '@cToTote         NVARCHAR( 20), ' +
                  '@cSKU            NVARCHAR( 20), ' +
                  '@nQtyMV          INT,        '    +
                  '@cConsoOption    NVARCHAR( 1), '  +
                  '@nErrNo          INT            OUTPUT, ' +
                  '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cStorerKey, @cFromTote, @cToTote, @cSKU, @nQtyMV, @cConsoOption, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0   
               BEGIN  
                  EXEC rdt.rdtSetFocusField @nMobile, 6  
                  GOTO Step_4_Fail    
               END  
            END
         END   

         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToTote                
                       AND LabelPrinted = 'Y')                
         BEGIN                
            -- Printing process                  
            IF ISNULL(@cPrinter, '') = ''                  
            BEGIN                     
               SET @nErrNo = 69836                  
               SET @cErrMsg = rdt.rdtgetmessage( 69836, @cLangCode, 'DSP') --NoLoginPrinter                  
               GOTO Step_6_Fail                
            END                  

            SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
            IF @cExtendedPrintSP = '0'
               SET @cExtendedPrintSP = ''

            -- Extended update
            IF @cExtendedPrintSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, 
                       @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT, '            +
                     '@nFunc           INT, '            +
                     '@cLangCode       NVARCHAR( 3), '   +
                     '@nStep           INT, '            + 
                     '@nInputKey       INT, '            +
                     '@cStorerKey      NVARCHAR( 15), '  +
                     '@cCaseID         NVARCHAR( 18), '  +
                     '@cLOC            NVARCHAR( 10), '  +
                     '@cSKU            NVARCHAR( 20), '  +
                     '@cConsigneekey   NVARCHAR( 15), '  +
                     '@nQTY            INT, '  + 
                     '@cToToteNo       NVARCHAR( 18), '  +
                     '@cSuggPTSLOC     NVARCHAR( 10), '  +
                     '@nErrNo          INT   OUTPUT, '   +
                     '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToTote, '', @cSKU, @cConsigneekey, 0, 
                     @cToTote, '', @nErrNo OUTPUT, @cErrMsg OUTPUT
               END
            END
            ELSE
            BEGIN
               SET @cReportType = 'SORTLABEL'                  
               SET @cPrintJobName = 'PRINT_SORTLABEL'                  
                           
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),                  
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')                   
               FROM RDT.RDTReport WITH (NOLOCK)                   
               WHERE StorerKey = @cStorerKey                  
               AND   ReportType = @cReportType                  
                           
               IF ISNULL(@cDataWindow, '') = ''                  
               BEGIN                  
                  GOTO Step_6_Fail                
               END                  
                           
               IF ISNULL(@cTargetDB, '') = ''                  
               BEGIN                  
                  GOTO Step_6_Fail                
               END                  
                           
               SET @nErrNo = 0                  
               EXEC RDT.rdt_BuiltPrintJob                   
                  @nMobile,                  
                  @cStorerKey,                  
                  @cReportType,                  
                  @cPrintJobName,                  
                  @cDataWindow,                  
                  @cPrinter,                  
                  @cTargetDB,                  
                  @cLangCode,                  
                  @nErrNo  OUTPUT,                   
                  @cErrMsg OUTPUT,                  
                  @cStorerKey,                  
                  @cToTote                  
            END

            IF @nErrNo <> 0                  
            BEGIN                  
               GOTO Step_6_Fail                
            END                  
            ELSE                
            BEGIN                
               UPDATE DROPID WITH (ROWLOCK)                
               SET LabelPrinted = 'Y'                
               WHERE Dropid = @cToTote                                
            END                  
                            
         END  -- Print Tote Label                
  
         /*  
         IF @cConsoOption = 'F'  
         BEGIN  
            SET @cSKU = ''  
            SET @nQtyMV=0  
         END  
                 
         EXEC rdt.rdt_ToteConsolidation_Confirm   
            @nMobile          ,     
            @cStorerKey       ,     
            @cPickSlipNo      ,  
            @cFromTote        ,  
            @cToTote          ,  
            @cLangCode        ,  
            @cUserName        ,  
            @cConsoOption     ,  
            @cSKU ,  
            @cFacility        ,  
            @nFunc            ,                 
            @nQtyMV           ,  
            @nErrNo           OUTPUT ,    
            @cErrMsg          OUTPUT        
         IF @nErrNo <> 0   
         BEGIN  
            SET @nErrNo = @nErrNo  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')   
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Step_4_Fail    
         END                                               
         -- EXECUTE CONFIRM MOVE (End) --  
         */
         SET @cOutField01 = @cToTote  
                    
         SET @nScn   = 2466  
         SET @nStep  =  @nStep + 1  
         GOTO QUIT  
           
      END -- End Option = 1    
        
      IF @cOption = '9'  
      BEGIN  
         -- If the RDT config turn on then go back PTS Initial screen
         IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
         BEGIN
            SET @cOutField01 = ''

            -- Goto Tote Screen   
            SET @nFunc = 1811
            SET @nScn  = 3941     
            SET @nStep = 2      
            
            GOTO Quit
         END

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
           
         SET @nScn   = 2460  
         SET @nStep  =  1  
         GOTO QUIT  
      END        
   END -- IF @nInputKey = 1  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN  
        
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
      
      SET @cSKU = ''  
  
      SET @nScn = @nScn - 4   
      SET @nStep = @nStep - 4  
   END  
   GOTO Quit  
     
   Step_6_Fail:  
   BEGIN  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 7. screen = 2466   
  To Tote (Field01)  
********************************************************************************/  
Step_7:  
BEGIN  
   IF @nInputKey = 1 OR @nInputKey = 0  -- ENTER / ESC  
   BEGIN  
      -- initialise all variable  
      --prepare next screen variable  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''        
        
      IF @cConsoOption = 'F'  
      BEGIN  
         -- Release the DropID  
         UPDATE DROPID   
            SET STATUS = '9', EDITDATE=GETDATE(), EDITWHO=SUSER_SNAME()   
         WHERE DropID = @cFromTote  
           AND   STATUS < '9'  
  
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 71016    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'    
            GOTO Step_7_Fail  
         END  
   
         -- (ChewKP03)
         SET @nScn = @nScnCloseTote
         SET @nStep = @nStepCloseTote
         SET @cOutfield02 = '9'
         
         EXEC rdt.rdtSetFocusField @nMobile, 2           
      END  
      ELSE  
      BEGIN  
         IF @cLabelPrinted = 'Y'  
         BEGIN  
            SET @nQtyAvl=0  
            SELECT @nQtyAvl = ISNULL(SUM(PD.Qty), 0)   
            FROM dbo.PackDetail PD WITH (NOLOCK)  
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo     
               JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey    
               JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)          
               WHERE PD.StorerKey = @cStorerKey                  
                 AND PD.DropID = @cFromTote                   
                 AND PD.Qty > 0                
                 AND O.Status < '9'         
         END   
         ELSE  
         BEGIN  
            SET @nQtyAvl=0   
            SELECT @nQtyAvl = ISNULL(SUM(PD.Qty), 0)      
            FROM dbo.PickDetail PD WITH (NOLOCK)     
            JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey     
            JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
            JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  -- (SHONGxx)          
            WHERE PD.StorerKey = @cStorerKey                  
               AND PD.DropID = @cFromTote                  
               AND PD.Status >= '5'                  
               AND PD.Status < '9'    
               AND PD.Qty > 0          
               AND TD.PickMethod = 'PIECE'        
               AND TD.Status = '9'       
               AND O.Status < '9'                 
         END  
         IF  @nQtyAvl > 0   
         BEGIN  
            --prepare next screen variable  
            SET @cOutField01 = @cFromTote  
            SET @cOutField02 = @cConsigneekey  
            SET @cOutField03 = ''  
                      
            SET @nScn = 2461  
            SET @nStep = 2  
            EXEC rdt.rdtSetFocusField @nMobile, 1                      
         END  
         ELSE  
         BEGIN  
            -- Release the DropID  
            UPDATE DROPID   
               SET STATUS = '9', EDITDATE=GETDATE(), EDITWHO=SUSER_SNAME()   
            WHERE DropID = @cFromTote  
            AND   STATUS < '9'  
  
            IF @@ERROR <> 0    
            BEGIN    
              SET @nErrNo = 71016    
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'    
              GOTO Step_7_Fail  
            END  
  
            -- If the RDT config turn on then go back PTS Initial screen
            IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
            BEGIN
               SET @cOutField01 = ''

               -- Goto Tote Screen   
               SET @nFunc = 1811
               SET @nScn  = 3941     
               SET @nStep = 2      
               
               GOTO Quit
            END
      
            SET @nScn = 2460  
            SET @nStep = 1  
            EXEC rdt.rdtSetFocusField @nMobile, 1      
         END  
      END  
        
   END  
   GOTO QUIT  
     
   Step_7_Fail:  
   BEGIN  
      SET @cOutField01 = @cToTote  
      SET @cOutField02 = ''  
    END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 8. screen = 2467   
  To Tote (Field01)  
  Merge Tote:  
********************************************************************************/  
Step_8:  
BEGIN  
   IF @nInputKey = 1   -- ENTER / ESC  
   BEGIN  
      SET @cOption         = ISNULL(@cInField01,'')  
      SET @cConsigneekey   = @cOutField02
      SET @cPTSLOC         = @cOutField03
      SET @cFromTote       = @cOutField04

      IF ISNULL(RTRIM(@cOption),'') = ''  
      BEGIN  
         SET @nErrNo = 70268  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      IF ISNULL(RTRIM(@cOption),'') <> '1' AND ISNULL(RTRIM(@cOption),'') <> '9'  
      BEGIN  
         SET @nErrNo = 70269  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         SET @cOutField01 = ''  
         GOTO Quit  
      END  
  
      IF @cOption = '1' -- Whole   
      BEGIN  
         SET @cConsoOption = 'F'  
  
         --prepare next screen variable  
         SET @cOutField01 = @cFromTote  
         SET @cOutField02 = @cConsigneekey  
         SET @cOutField03 = ''  
         SET @cOutField04 = @cPTSLOC  
  
         SET @nScn  = 2464  
         SET @nStep = 5  
      END  
  
      IF @cOption = '9'  
      BEGIN  
         SET @cConsoOption = 'P'  
  
          --prepare next screen variable  
         SET @cOutField01 = @cFromTote  
         SET @cOutField02 = @cConsigneekey  
         SET @cOutField03 = ''  
     
         SET @nScn  = 2461  
         SET @nStep = 2  
      END  
  
        
   END  
     
   IF @nInputKey = 0  
   BEGIN  
      -- If the RDT config turn on then go back PTS Initial screen
      IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
      BEGIN
         SET @cOutField01 = ''

         -- Goto Tote Screen   
         SET @nFunc = 1811
         SET @nScn  = 3941     
         SET @nStep = 2      
         
         GOTO Quit
      END

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
      
      SET @cSKU = ''        
      SET @nScn = 2460  
      SET @nStep = 1  
      EXEC rdt.rdtSetFocusField @nMobile, 1          
   END  
   GOTO QUIT  
  
   Step_8_Fail:  
   BEGIN  
      SET @cOutField01 = @cToTote  
      SET @cOutField02 = ''  
    END  
  
END -- Step_8  

/********************************************************************************    
Step 9. screen = 2468    
   Option (Field01)    
********************************************************************************/    
Step_9:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField02 
    
      IF ISNULL(@cOption, '') = ''    
      BEGIN    
         SET @nErrNo = 70295    
         SET @cErrMsg = rdt.rdtgetmessage( 70295, @cLangCode, 'DSP') --Option req    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_9_Fail      
      END     
    
      IF ISNULL(@cOption, '') <> '1' AND ISNULL(@cOption, '') <> '9'    
      BEGIN    
         SET @nErrNo = 70296
         SET @cErrMsg = rdt.rdtgetmessage( 70296, @cLangCode, 'DSP') --Invalid Option    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_9_Fail      
      END     
    
      IF @cOption = '1'    
      BEGIN    
         -- Printing process    
         IF ISNULL(@cPrinter, '') = ''    
         BEGIN       
            SET @nErrNo = 70297 
            SET @cErrMsg = rdt.rdtgetmessage( 70297, @cLangCode, 'DSP') --NoLabelPrinter    
            GOTO Step_9_Fail    
         END    
    
   
         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToTote    
                       AND LabelPrinted = 'Y')     
         BEGIN    
            SET @cExtendedPrintSP = rdt.rdtGetConfig( @nFunc, 'ExtendedPrintSP', @cStorerKey)
            IF @cExtendedPrintSP = '0'
               SET @cExtendedPrintSP = ''

            -- Extended update
            IF @cExtendedPrintSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedPrintSP AND type = 'P')
               BEGIN
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPrintSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cCaseID, @cLOC, @cSKU, @cConsigneekey, @nQTY, 
                       @cToToteNo, @cSuggPTSLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile         INT, '            +
                     '@nFunc           INT, '            +
                     '@cLangCode       NVARCHAR( 3), '   +
                     '@nStep           INT, '            + 
                     '@nInputKey       INT, '            +
                     '@cStorerKey      NVARCHAR( 15), '  +
                     '@cCaseID         NVARCHAR( 18), '  +
                     '@cLOC            NVARCHAR( 10), '  +
                     '@cSKU            NVARCHAR( 20), '  +
                     '@cConsigneekey   NVARCHAR( 15), '  +
                     '@nQTY            INT, '  + 
                     '@cToToteNo       NVARCHAR( 18), '  +
                     '@cSuggPTSLOC     NVARCHAR( 10), '  +
                     '@nErrNo          INT   OUTPUT, '   +
                     '@cErrMsg         NVARCHAR( 20)  OUTPUT'  

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cToTote, '', @cSKU, @cConsigneekey, 0, 
                     @cToTote, '', @nErrNo OUTPUT, @cErrMsg OUTPUT
               END
            END
            ELSE
            BEGIN
               SET @cReportType = 'SORTLABEL'    
               SET @cPrintJobName = 'PRINT_SORTLABEL'    
       
               SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                      @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
               FROM RDT.RDTReport WITH (NOLOCK)     
               WHERE StorerKey = @cStorerKey    
               AND   ReportType = @cReportType    
       
               IF ISNULL(@cDataWindow, '') = ''    
               BEGIN    
                  SET @nErrNo = 70298    
                  SET @cErrMsg = rdt.rdtgetmessage( 70298, @cLangCode, 'DSP') --DWNOTSetup    
                  GOTO Step_9_Fail    
               END    
       
               IF ISNULL(@cTargetDB, '') = ''    
               BEGIN    
                  SET @nErrNo = 70299
                  SET @cErrMsg = rdt.rdtgetmessage( 70299, @cLangCode, 'DSP') --TgetDBNotSet    
                  GOTO Step_9_Fail    
               END    
       
               SET @nErrNo = 0    
               EXEC RDT.rdt_BuiltPrintJob     
                  @nMobile,    
                  @cStorerKey,    
                  @cReportType,    
                  @cPrintJobName,    
                  @cDataWindow,    
                  @cPrinter,    
                  @cTargetDB,    
                  @cLangCode,    
                  @nErrNo  OUTPUT,    
                  @cErrMsg OUTPUT,    
                  @cStorerKey,    
                  @cToTote    
            END

            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 70300    
               SET @cErrMsg = rdt.rdtgetmessage( 70300, @cLangCode, 'DSP') --'InsertPRTFail'    
               GOTO Step_9_Fail    
            END    
            ELSE    
            BEGIN    
               BEGIN TRAN    

               UPDATE DROPID WITH (ROWLOCK)     
                  SET LabelPrinted = 'Y'     
               WHERE DropID = @cToTote    
               IF @@ERROR <> 0     
               BEGIN    
                  SET @nErrNo = 70301
                  SET @cErrMsg = rdt.rdtgetmessage( 70301, @cLangCode, 'DSP') --'UpdDropIdFailed'    
                  ROLLBACK TRAN    
                  GOTO Step_9_Fail    
               END    
                                                  
               COMMIT TRAN    
            END    
         END    

         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE DropID = @cToTote    
                       AND ManifestPrinted = 'Y')    
         BEGIN    
            SET @cReportType = 'SORTMANFES'    
            SET @cPrintJobName = 'PRINT_SORTMANFES'    
    
            IF ISNULL(@cPrinter_Paper, '') = ''    
            BEGIN    
               SET @nErrNo = 70302
               SET @cErrMsg = rdt.rdtgetmessage( 70302, @cLangCode, 'DSP') --NoPaperPrinter    
                GOTO Step_9_Fail    
            END    
    
            SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),    
                   @cTargetDB = ISNULL(RTRIM(TargetDB), '')     
            FROM RDT.RDTReport WITH (NOLOCK)     
            WHERE StorerKey = @cStorerKey    
            AND   ReportType = @cReportType    
    
            IF ISNULL(@cDataWindow, '') = ''    
            BEGIN    
               SET @nErrNo = 70303   
               SET @cErrMsg = rdt.rdtgetmessage( 70303, @cLangCode, 'DSP') --DWNOTSetup    
               GOTO Step_9_Fail    
            END    
    
            IF ISNULL(@cTargetDB, '') = ''    
            BEGIN    
               SET @nErrNo = 70304    
               SET @cErrMsg = rdt.rdtgetmessage( 70304, @cLangCode, 'DSP') --TgetDBNotSet    
               GOTO Step_9_Fail    
            END    
    
            BEGIN TRAN    
    
            SET @nErrNo = 0    
            EXEC RDT.rdt_BuiltPrintJob     
               @nMobile,    
               @cStorerKey,    
               @cReportType,    
               @cPrintJobName,    
               @cDataWindow,    
               @cPrinter_Paper,     
               @cTargetDB,    
               @cLangCode,    
               @nErrNo  OUTPUT,    
               @cErrMsg OUTPUT,    
               @cStorerKey,    
               @cToTote    
    
            IF @nErrNo <> 0    
            BEGIN    
               SET @nErrNo = 70305    
               SET @cErrMsg = rdt.rdtgetmessage( 70305, @cLangCode, 'DSP') --'InsertPRTFail'    
               ROLLBACK TRAN    
               GOTO Step_9_Fail    
            END    
            ELSE    
            BEGIN    
                UPDATE DROPID WITH (ROWLOCK)     
                 SET ManifestPrinted = 'Y'     
                WHERE DropID = @cToTote    
                IF @@ERROR <> 0     
                BEGIN    
                  SET @nErrNo = 70306    
                  SET @cErrMsg = rdt.rdtgetmessage( 70306, @cLangCode, 'DSP') --'UpdDropIdFailed'    
                  ROLLBACK TRAN    
                  GOTO Step_9_Fail    
                END    
                                                          
               COMMIT TRAN    
            END                                
         END    
             
         
      END    

      -- If the RDT config turn on then go back PTS Initial screen
      IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
      BEGIN
         SET @cOutField01 = ''

         -- Goto Tote Screen   
         SET @nFunc = 1811
         SET @nScn  = 3941     
         SET @nStep = 2      
         
         GOTO Quit
      END

      -- (ChewKP03)
      IF @cConsoOption = 'F'
      BEGIN
         SET @cOutField01 = ''
       
         
         SET @nScn = @nScn - 8 
         SET @nStep = @nStep - 8
         
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cToTote
       
         
         SET @nScn = @nScn - 2 
         SET @nStep = @nStep - 2
      END
   END    
    
--   IF @nInputKey = 0 -- ESC    
--   BEGIN    
--      SET @cOutField01 = ''    
--    
--      SET @cToTote = ''    
--      SET @cOption = ''    
--  
--      SET @nScn = @nScn - 1    
--      SET @nStep = @nStep - 1    
--   END    
   GOTO Quit    
    
   Step_9_Fail:    
   BEGIN    
      SET @cOption = ''    
    
      SET @cOutField02 = ''    
   END    
    
END    
GOTO Quit    

/********************************************************************************  
Step 10. screen = 2469  
   SKU      (Field01, input)  
   TO LOC   (Field02, input)  
********************************************************************************/  
Step_10:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cSKUscan = ISNULL(@cInField02,'')  
      SET @cLOCscan = ISNULL(@cInField05,'')  
      SET @cFromTote = @cOutField01

      IF ISNULL( @cSKUscan, '') = '' AND ISNULL( @cLOCscan, '') = ''
      BEGIN      
         SET @nErrNo = 50605      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU & LOC req  
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Quit      
      END      

      -- Validate blank      
      IF ISNULL(@cSKUscan, '') = ''      
      BEGIN      
         SET @nErrNo = 70313      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU req      
         GOTO Step_10_SKU_Fail      
      END      
      
      IF ISNULL(@cSKUscan, '') <> ''      
      BEGIN      
         -- If not BOM SKU scanned, check for other posibilities      
         EXEC [RDT].[rdt_GETSKU]      
            @cStorerKey    = @cStorerKey      
           ,@cSKU          = @cSKUscan     OUTPUT      
           ,@bSuccess      = @b_Success    OUTPUT      
           ,@nErr          = @nErrNo       OUTPUT      
           ,@cErrMsg       = @cErrMsg      OUTPUT      
      END      

      SET @cSKU = @cSKUscan

      SET @cPackkey = ''  
      SELECT @cPackkey = Packkey, @cDescr = Descr FROM dbo.SKU WITH (NOLOCK)  
      WHERE SKU = @cSKU   
      AND Storerkey = @cStorerkey   

      SET @cPackUOM03 = ''  
      SELECT @cPackUOM03 = PackUOM3 FROM dbo.PACK WITH (NOLOCK)  
      WHERE Packkey = @cPackkey  

      SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)
      
      IF ISNULL(@cPackUOM03, '') = ''
      BEGIN      
         SET @nErrNo = 70314      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UOM      
         GOTO Step_10_SKU_Fail      
      END      
      
      -- Reset variables     
      SET @cConsigneekey = ''      
      SET @cPTSLOC = ''      
      
     -- Get the 1st Consignee + LOC      
      SELECT TOP 1 @cConsigneekey = O.ConsigneeKey, @cLoadKey = O.LoadKey, @cPTSLOC = TD.TOLOC  
      FROM dbo.PICKDETAIL PD (NOLOCK)   
      INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY    
      INNER JOIN dbo.DROPID DROPID WITH (NOLOCK) ON PD.DROPID = DROPID.DROPID AND O.LOADKEY = DROPID.LOADKEY  
      INNER JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
      WHERE PD.DropID = @cFromTote  
         AND O.StorerKey = @cStorerKey  
         AND O.Status NOT IN ('9', 'CANC')  
         
      IF ISNULL(@cConsigneekey, '') = ''      
      BEGIN      
         SET @nErrNo = 70315      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO STORE FOUND      
         GOTO Step_10_SKU_Fail      
      END      
      
      IF ISNULL(@cPTSLOC, '') = ''      
      BEGIN      
         SET @nErrNo = 50601      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NO LOC FOUND      
         GOTO Step_10_SKU_Fail      
      END      

      IF ISNULL( @cLOCscan,'') = '' AND ISNULL( @cSkuScan,'') <> ''
      BEGIN      
         SET @cOutField03 = SUBSTRING( @cDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cDescr, 21, 20)
         EXEC rdt.rdtSetFocusField @nMobile, 5    
         GOTO Quit      
      END     

      -- If Suggested LOC in PickDetail is Full, then get the next available PTS LOC      
      IF ISNULL(@cLOCscan, '') <> ISNULL(@cPTSLOC, '')      
      BEGIN      
         IF NOT EXISTS (SELECT 1 FROM dbo.StoreToLocDetail WITH (NOLOCK)      
                        WHERE LOC = @cLOCscan AND ConsigneeKey = @cConsigneekey)      
         BEGIN      
            SET @nErrNo = 50603      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid TO LOC      
            GOTO Step_10_LOC_Fail      
         END      
      
         UPDATE dbo.StoreToLocDetail WITH (ROWLOCK)      
           SET LocFull = 'Y',      
               EditDate = GETDATE(),      
               EditWho = @cUserName      
         WHERE LOC = @cPTSLOC      
         AND   ConsigneeKey = @cConsigneekey      
         AND   LocFull = 'N'      
      
         IF @@Error <> 0      
         BEGIN      
            SET @nErrNo = 50604      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdStoretoLocFail      
            EXEC rdt.rdtSetFocusField @nMobile, 3      
            GOTO Step_10_LOC_Fail      
         END      
      
         SET @cPTSLOC = @cLOCscan      
      END      

/*
      SELECT @nQtyAvl = ISNULL(SUM(PD.Qty), 0)      
      FROM dbo.PickDetail PD WITH (NOLOCK)     
      JOIN dbo.ORDERS o WITH (NOLOCK) ON o.OrderKey = PD.OrderKey     
      JOIN dbo.TaskDetail TD WITH (NOLOCK) ON PD.TaskDetailKey = TD.TaskDetailKey   
      JOIN dbo.DropId DI WITH (NOLOCK) ON DI.DropID = PD.DropID AND DI.Loadkey = O.LoadKey  
      WHERE PD.StorerKey = @cStorerKey                  
      AND   PD.DropID = @cFromTote                  
      AND   PD.Status >= '5'                  
      AND   PD.Status < '9'    
      AND   PD.Qty > 0          
      AND   TD.PickMethod = 'PIECE'        
      AND   TD.Status = '9'       
      AND   O.Status < '9'   
      AND   TD.SKU = @cSKU  
      
      SET @nQtyMV = @nQtyAvl

      SET @cConsoOption = 'P'  

      --prepare next screen variable  
      SET @cOutField01 = @cFromTote  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = @cPackUOM03  
      SET @cOutField05 = @nQtyMV  
      SET @cOutField06 = ''  
*/
      -- Get stored proc name for extended info (james06)
      SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
      IF @cExtendedInfoSP = '0'
         SET @cExtendedInfoSP = ''

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''

            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromTote, @cSKU, @nQtyMv, @cToTote, @cConsoOption, @c_oFieled01 OUTPUT'
            
            SET @cSQLParam =
               '@nMobile       INT, ' + 
               '@nFunc         INT, ' + 
               '@cLangCode     NVARCHAR( 3),  ' + 
               '@nStep         INT, ' + 
               '@nInputKey     INT, ' + 
               '@cStorerKey    NVARCHAR( 15), ' + 
               '@cFromTote     NVARCHAR( 18), ' + 
               '@cSKU          NVARCHAR( 20), ' +
               '@nQtyMv        INT, ' +
               '@cToTote       NVARCHAR( 18), ' +
               '@cConsoOption  NVARCHAR( 1),  ' +
               '@c_oFieled01   NVARCHAR( 20) OUTPUT ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFromTote, @cSKU, @nQtyMv, @cToTote, @cConsoOption, @cExtendedInfo OUTPUT
         END
      END
      
      SET @cConsoOption = 'F'  

      --prepare next screen variable  
      SET @cOutField01 = @cFromTote  
      SET @cOutField02 = @cConsigneekey  
      SET @cOutField03 = ''  
      SET @cOutField04 = @cPTSLOC  
      SET @cOutField05 = @cExtendedInfo

      SET @nScn  = 2464  
      SET @nStep = 5  
   END

   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- If the RDT config turn on then go back PTS Initial screen
      IF rdt.RDTGetConfig( @nFunc, 'PTS_INITIAL_SCN', @cStorerKey) = 1
      BEGIN
         SET @cOutField01 = ''

         -- Goto Tote Screen   
         SET @nFunc = 1811
         SET @nScn  = 3941     
         SET @nStep = 2      
         
         GOTO Quit
      END

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
        
      SET @nScn   = 2460  
      SET @nStep  =  1  
   END    
   GOTO Quit    
    
   Step_10_SKU_Fail:    
   BEGIN    
      SET @cSkuScan = ''    
      SET @cOutField02 = ''  
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = @cLocScan  -- Keep loc value

      EXEC rdt.rdtSetFocusField @nMobile, 2 
   END    
   GOTO Quit

   Step_10_LOC_Fail:    
   BEGIN    
      SET @cLocScan = ''    
      SET @cOutField05 = ''    
      SET @cOutField02 = @cSkuScan  -- Keep sku value

      EXEC rdt.rdtSetFocusField @nMobile, 5 
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
      Printer_Paper = @cPrinter_Paper,
      -- UserName      = @cUserName,  
          
      V_ConsigneeKey     = @cConsigneekey,   
      V_SKU              = @cSKU,            
      V_UOM              = @cPackUOM03,  
      V_LOC              = @cPTSLOC,      
      
      V_Integer1     = @nQtyAvl,
      V_Integer2     = @nQtyMV,

      V_String1      = @cPickSlipNo,  
      V_String2      = @cFromTote,  
      V_String3      = @cPackkey,  
      --V_String4      = @nQtyAvl,  
      --V_String5      = @nQtyMV,  
      V_String6      = @cToTote,  
      V_String7      = @cConsoOption,  
      V_String8      = @cLabelPrinted,   
      V_String9      = @cLoadKey,   
      V_String10     = @cSkuScan, 
      V_String11     = @cLocScan, 
  
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