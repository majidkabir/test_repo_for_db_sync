SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
     
/******************************************************************************/       
/* Copyright: LF                                                              */       
/* Purpose: IDSSG UNITY WMS-488                                               */       
/*                                                                            */       
/* Modifications log:                                                         */       
/*                                                                            */       
/* Date       Rev  Author     Purposes                                        */       
/* 2016-10-05 1.0  ChewKP     Created. WMS-488                                */      
/* 2017-04-14 1.1  ChewKP     WMS-1629 - Display LabelNo (ChewKP01)				*/
/* 2017-07-18 1.2  ChewKP     WMS-2393 - Display Position or ConsigneeKey     */
/*                            (ChewKP02)                                      */
/* 2017-11-23 1.3  ChewKP     WMS-3491 - Validate DropID Scan (ChewKP03)      */
/* 2018-10-25 1.4  TungGH     Performance                                     */
/******************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_UNI_PTS] (      
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
         
   @nError            INT,      
   @b_success         INT,      
   @n_err             INT,           
   @c_errmsg          NVARCHAR( 250),       
   @cPUOM             NVARCHAR( 10),          
   @bSuccess          INT,      
      
   @cPTSZone            NVARCHAR(10),      
   @cUserID             NVARCHAR(18),    
   @cDropID             NVARCHAR(20),    
   @cSQL                NVARCHAR(1000),     
   @cSQLParam           NVARCHAR(1000),     
   @cExtendedUpdateSP   NVARCHAR(30),      
   @nTotalAssignDropID  INT,    
   @cOption             NVARCHAR(1),    
   @cSuggLoc            NVARCHAR(10),    
   @cLightModeColor     NVARCHAR(5),    
   @cLightMode          NVARCHAR(10),    
   @cPTSLoc             NVARCHAR(10),  
   @cWaveKey            NVARCHAR(10),  
   @cPTLWaveKey         NVARCHAR(10),  
   @nMaxDropID          INT,  
   @nAssignDropID       INT,  
   @cExtendedValidateSP NVARCHAR(30),    
   @cDecodeLabelNo      NVARCHAR(20),        
   @cDefaultQTY         NVARCHAR(5),  
   @cDisableSKUField    NVARCHAR(1),  
   @cGeneratePackDetail NVARCHAR(1),  
   @cGetNextTaskSP      NVARCHAR(30),  
   @cLabelNo            NVARCHAR(20),  
   @cSuggPTSPosition    NVARCHAR(20),  
   @cLoadKey            NVARCHAR(10), -- Check  
   @cSuggSKU            NVARCHAR(20),  
   @cSKUDescr           NVARCHAR(60),   
   @nExpectedQty        INT,    
   @nDropIDCount        INT,  
   @cPTSPosition        NVARCHAR(20),  
   @cPUOM_Desc          NVARCHAR( 5),    
   @cMUOM_Desc          NVARCHAR( 5),    
   --@cScnText            NVARCHAR(20),  
   @nPUOM_Div           INT, -- UOM divider    
   @nQTY_Avail          INT, -- QTY available in LOTxLOCXID    
   @nQTY                INT, -- Pack.QTY    
   @nPQTY               INT, -- Preferred UOM QTY    
   @nMQTY               INT, -- Master unit QTY    
   @nActQTY             INT, -- Actual replenish QTY    
   @nActMQTY            INT, -- Actual keyed in master QTY    
   @nActPQTY            INT, -- Actual keyed in prefered QTY    
   @cScnLabel           NVARCHAR(20),  
   @cScnText            NVARCHAR(20),  
   @nCountScanTask      INT, -- Check  
   @nTotalTaskCount     INT, -- Check  
   @cSKU                NVARCHAR(20),  
   @cActPQTY            NVARCHAR( 5),    
   @cActMQTY            NVARCHAR( 5),  
   @cSKULabel           NVARCHAR(20),  
   @nSKUValidated       INT,    
   @nUCCQTY             INT,  
   @cUCC                NVARCHAR(20),  
   @nSKUCnt             INT,  
   @cPutawayZone        NVARCHAR(10), -- Check  
   @cReplenishmentKey   NVARCHAR(10), -- Check   
   @cFromLoc            NVARCHAR(10), -- Check  
   @cFromID             NVARCHAR(18), -- Check  
   @cSuggToLoc          NVARCHAR(10), -- Check  
   @cToLabelNo          NVARCHAR(20),   
   @cSuggLabelNo        NVARCHAR(20),  
   @cActToLoc           NVARCHAR(10), -- Check  
   @cOptions            NVARCHAR(1),   
   @cDefaultToLoc       NVARCHAR(10), -- Check  
   @cSuggDropID         NVARCHAR(20),  
   @cPTSLogKey          NVARCHAR(10),   
   @cShort              NVARCHAR(1), 
   @cDefaultPosition    NVARCHAR(20),
   @cLottableCode       NVARCHAR(30),   
   @nMorePage           INT,  
   @cLot            NVARCHAR(10), 
   @cDefaultToLabel NVARCHAR(1),
   @cExtendedInfoSP NVARCHAR(30),
   @cConsigneeKey   NVARCHAR(30),
   @nTotalPickedQty  INT,
   @nTotalPackedQty  INT,
   @cToteNo         NVARCHAR(20),

   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
            
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
   --@cLightMode  = LightMode,  
   @cSKU       = V_SKU,  
   @cSKUDescr   = V_SKUDescr,  
   
   @cLot        = V_Lot,  
   @cPUOM     = V_UOM,         
         
   @cExtendedUpdateSP        = V_String1,     
   @cExtendedValidateSP      = V_String2,    
   @cDecodeLabelNo           = V_String3,    
   @cDefaultQTY              = V_String4,    
   @cDisableSKUField         = V_String5,     
   @cGeneratePackDetail      = V_String6,     
   @cGetNextTaskSP           = V_String7,  
   @cSuggPTSPosition         = V_string8,   
   @cSuggSKU                 = V_String9,   
   @cSuggDropID              = V_String10,  
   @cMUOM_Desc               = V_String11,    
   @cPUOM_Desc               = V_String12,      
   @cScnText                 = V_String13,   
   --@nExpectedQTY             = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,    
   @nSKUValidated            = V_String15,  
   @cPTSLogKey               = V_String16,  
   --@nTotalAssignDropID       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 5), 0) = 1 THEN LEFT( V_String6, 5) ELSE 0 END,        
   --@nMaxDropID               = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 5), 0) = 1 THEN LEFT( V_String7, 5) ELSE 0 END,           
   --@nQty                     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String23, 5), 0) = 1 THEN LEFT( V_String23, 5) ELSE 0 END,    
   @cPTSPosition             = V_String24,
   @cScnLabel                = V_String25,
   @cShort                   = V_String26,   
   @cDropID                  = V_String27, 
   @cDefaultPosition         = V_String28,   
   @cDefaultToLabel          = V_String29,
   @cExtendedInfoSP          = V_String30,
   @cToteNo						  = V_String31, -- (ChewKP01) 
         
   @nPUOM_Div                = V_PUOM_Div,    
   @nMQTY                    = V_MQTY,    
   @nPQTY                    = V_PQTY,   
   @nExpectedQTY             = V_QTY,  
       
   @nActMQTY                 = V_Integer1,    
   @nActPQTY                 = V_Integer2,    
   @nActQty                  = V_Integer3,
      
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
      
      
IF @nFunc = 761  -- PTS Sort And Pack      
BEGIN      
         
   -- Redirect to respective screen      
   IF @nStep = 0 GOTO Step_0   -- PTS Sort And Pack   
   IF @nStep = 1 GOTO Step_1   -- Scn = 4720. DropID  
   IF @nStep = 2 GOTO Step_2   -- Scn = 4721. Position    
   IF @nStep = 3 GOTO Step_3   -- Scn = 4722. SKU , Qty      
   IF @nStep = 4 GOTO Step_4   -- Scn = 4723. Message    
   IF @nStep = 5 GOTO Step_5   -- Scn = 4724. Message
   
         
END      
      
--IF @nStep = 3      
--BEGIN      
-- SET @cErrMsg = 'STEP 3'      
-- GOTO QUIT      
--END      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. func = 761. Menu      
********************************************************************************/      
Step_0:      
BEGIN      
   -- Get prefer UOM      
   SET @cPUOM = ''      
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA      
   FROM RDT.rdtMobRec M WITH (NOLOCK)      
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)      
   WHERE M.Mobile = @nMobile      
       
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'      
   BEGIN    
      SET @cExtendedUpdateSP = ''    
   END    

 
     
   SET @cDefaultQTY = rdt.RDTGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)      
   SET @cDisableSKUField = rdt.RDTGetConfig( @nFunc, 'DisableSKUField', @cStorerKey)   
   SET @cGeneratePackDetail = rdt.RDTGetConfig( @nFunc, 'GeneratePackDetail', @cStorerKey)   
     
   SET @cGetNextTaskSP = rdt.RDTGetConfig( @nFunc, 'GetNextTaskSP', @cStorerKey)    
   IF @cGetNextTaskSP = '0'      
   BEGIN    
      SET @cGetNextTaskSP = ''    
   END      
   
   SET @cDefaultPosition = rdt.RDTGetConfig( @nFunc, 'DefaultPosition', @cStorerKey)    
   IF @cDefaultPosition = '0'      
   BEGIN    
      SET @cDefaultPosition = ''    
   END        

      
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
           
   SET @cSuggPTSPosition      = '' 
   SET @cSuggSKU              = '' 
   SET @cSuggDropID           = '' 
   SET @cMUOM_Desc            = '' 
   SET @cPUOM_Desc            = '' 
   SET @cScnText              = '' 
   SET @nExpectedQTY          = 0 
   SET @nSKUValidated         = 0 
   SET @cPTSLogKey            = '' 
   SET @nPUOM_Div             = 0 
   SET @nMQTY                 = 0 
   SET @nPQTY                 = 0 
   SET @nActMQTY              = 0 
   SET @nActPQTY              = 0 
   SET @nActQty               = 0 
   SET @nQty                  = 0 
   SET @cPTSPosition          = '' 
   SET @cScnLabel             = '' 
   SET @cShort                = '' 
   SET @cDropID               = '' 
   
   -- Init screen      
   SET @cOutField01 = ''       
   SET @cOutField02 = ''      
     
   -- Clear PTS Log      
   DELETE FROM rdt.rdtPTSLog WITH (ROWLOCK)  
   WHERE AddWho = @cUserName  
      
   -- Set the entry point      
   SET @nScn = 4720      
   SET @nStep = 1      
         
   EXEC rdt.rdtSetFocusField @nMobile, 1      
         
END      
GOTO Quit      
      
      
/********************************************************************************      
Step 1. Scn = 4720.      
   DropID         (field01 , input)      
   Scanned DropID (field02)      
    
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cDropID = ISNULL(RTRIM(@cInField01),'')      
          
      IF @cDropID = ''      
      BEGIN      
           
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK)  
                         WHERE AddWho = @cUserName  
                         AND Status = '0' )   
         BEGIN  
            SET @nErrNo = 104701      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDReq    
            GOTO Step_1_Fail      
         END  
         ELSE  
         BEGIN  
            -- Get Next Task  
  
            SET @cPTSLogKey         = '' 
            SET @cSuggPTSPosition   = ''
            SET @cSuggSKU           = ''
            SET @nExpectedQty       = ''
            SET @cScnText           = ''
            SET @cSuggDropID        = ''
  
            IF @cGetNextTaskSP <> '' 
            BEGIN    
               SET @cPTSLogKey = ''

               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +     
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                  
                  SET @cSQLParam =    
                     '@nMobile        INT,            ' +    
                     '@nFunc          INT,            ' +    
                     '@cLangCode      NVARCHAR(3),    ' +    
                     '@nStep          INT,            ' +    
                     '@cUserName      NVARCHAR( 18),  ' +     
                     '@cFacility      NVARCHAR( 5),   ' +     
                     '@cStorerKey     NVARCHAR( 15),  ' +     
                     '@cDropID        NVARCHAR( 20),  ' +     
                     '@cSKU           NVARCHAR( 20),  ' +     
                     '@nQty           INT,            ' +     
                     '@cLabelNo       NVARCHAR( 20),  ' +     
                     '@cPTSPosition   NVARCHAR( 20),  ' + 
                     '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +  
                     '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
                     '@cScnText       NVARCHAR( 20) OUTPUT, ' + 
                     '@nErrNo         INT OUTPUT, ' +      
                     '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                      
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                     @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT  
                  
                  IF @nErrNo <> 0  
                  BEGIN
                     SET @nErrNo = 104722      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask      
                     GOTO Step_1_Fail    
                  END

                  SELECT TOP 1   
                        @cSuggPTSPosition = PTSPosition   
                      , @cSuggSKU         = PTSLOG.SKU   
                      , @nExpectedQty     = PTSLOG.ExpectedQty  
                      , @cScnText         = PTSLOG.ConsigneeKey  
                      , @cSuggDropID      = PTSLog.DropID  
                      , @cLot             = PTSLog.Lot
                      , @cToteNo          = PTSLog.LabelNo --(ChewKP01) 
                  FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
                  WHERE PTSLOG.StorerKey = @cStorerKey  
                  AND PTSLOG.AddWho = @cUserName  
                  AND PTSLogKey = @cPTSLogKey
                  
                  

               END    
            END  -- IF @cGetNextTaskSP <> ''    
                      
  
            SET @cOutField01 = @cSuggPTSPosition + ' - ' + @cScnText -- (ChewKP02) 
            
            IF @cDefaultPosition = '1'
            BEGIN
               SET @cOutField02 = @cSuggPTSPosition 
            END
            ELSE
            BEGIN
               SET @cOutField02 = ''  
            END
            
            -- GOTO Next Screen      
            SET @nScn = @nScn + 1      
            SET @nStep = @nStep + 1      
            GOTO QUIT  
              
              
         END  
      END      
      
      -- (ChewKP03) 
      SELECT TOP 1 @cWaveKey = WaveKey            
      FROM RDT.RDTAssignLoc WITH (NOLOCK)    
      Order By EditDate Desc   
         
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)  
                      WHERE StorerKey = @cStorerKey  
                      AND DropID = @cDropID  
                      AND Status = '5'
                      AND WaveKey = @cWaveKey )   
      BEGIN  
         SET @nErrNo = 104702      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID    
         GOTO Step_1_Fail      
      END    
      
      IF EXISTS ( SELECT 1 FROM rdt.rdtPTSLog WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID 
                  AND Status < '9' ) 
      BEGIN
         SET @nErrNo = 104719      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDExist    
         GOTO Step_1_Fail   
      END
        
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    

        

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         
            SET @cSQLParam =    
                  '@nMobile        INT,            ' +    
                  '@nFunc          INT,            ' +    
                  '@cLangCode      NVARCHAR(3),    ' +    
                  '@nStep          INT,            ' +    
                  '@cUserName      NVARCHAR( 18),  ' +     
                  '@cFacility      NVARCHAR( 5),   ' +     
                  '@cStorerKey     NVARCHAR( 15),  ' +     
                  '@cDropID        NVARCHAR( 20),  ' +     
                  '@cSKU           NVARCHAR( 20),  ' +     
                  '@nQty           INT,            ' +     
                  '@cToLabelNo     NVARCHAR( 20),  ' +     
                  '@cPTSLogKey     NVARCHAR( 20),  ' +  
                  '@cShort         NVARCHAR(1),    ' +    
                  '@cSuggLabelNo   NVARCHAR(20) OUTPUT,   ' +    
                  '@nErrNo         INT OUTPUT,     ' +      
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                   
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT   
        
            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
         END    
      END  -- IF @cExtendedUpdateSP <> ''    
    
        
      SELECT @nDropIDCount = Count(Distinct DropID)  
      FROM rdt.rdtPTSLog WITH (NOLOCK)   
      WHERE AddWho = @cUserName  
      AND Status = '0'  
    
          
       -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cPTSZone    
      SET @cOutField01 = ''  
      SET @cOutField02 = @nDropIDCount   
        
    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
--    -- EventLog - Sign In Function      
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
  
   END      
   GOTO Quit      
      
   STEP_1_FAIL:      
   BEGIN      
      SELECT @nDropIDCount = Count(Distinct DropID)  
      FROM rdt.rdtPTSLog WITH (NOLOCK)   
      WHERE AddWho = @cUserName  
      AND Status = '0'  
  
      -- Prepare Next Screen Variable      
      SET @cOutField01 = ''    
      SET @cOutField02 = @nDropIDCount  
      
   END      
END       
GOTO QUIT      
      
      
/********************************************************************************      
Step 2. Scn = 4721.       
       
   PTSPosition          (field01)      
   PTSPosition          (field02, input)    
         
         
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1      
   BEGIN      
      SET @cPTSPosition = ISNULL(RTRIM(@cInField02),'')      
        
          
      IF @cPTSPosition = ''      
      BEGIN      
         SET @nErrNo = 104704      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTSPosReq'      
         GOTO Step_2_Fail    
      END      
        
      IF @cPTSPosition <> @cSuggPTSPosition   
      BEGIN  
         SET @nErrNo = 104705  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTSPosNotSame'      
         GOTO Step_2_Fail    
      END  
      
      SET @cSKUDescr = ''
      SET @cMUOM_Desc = ''
      SET @cPUOM_Desc = ''
      
        
      -- Get Pack info    
      SELECT    
         @cLottableCode = SKU.LottableCode,
         @cSKUDescr = SKU.Descr,  
         @cMUOM_Desc = Pack.PackUOM3,    
         @cPUOM_Desc =    
      CASE @cPUOM    
               WHEN '2' THEN Pack.PackUOM1 -- Case    
               WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
               WHEN '6' THEN Pack.PackUOM3 -- Master unit    
               WHEN '1' THEN Pack.PackUOM4 -- Pallet    
               WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
               WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
            END,    
         @nPUOM_Div = CAST( IsNULL(    
            CASE @cPUOM    
               WHEN '2' THEN Pack.CaseCNT    
               WHEN '3' THEN Pack.InnerPack    
               WHEN '6' THEN Pack.QTY    
               WHEN '1' THEN Pack.Pallet    
               WHEN '4' THEN Pack.OtherUnit1    
               WHEN '5' THEN Pack.OtherUnit2    
            END, 1) AS INT)    
      FROM dbo.SKU SKU WITH (NOLOCK)    
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE SKU.StorerKey = @cStorerKey    
         AND SKU.SKU = @cSuggSKU   
        
        
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0  -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY = 0    
         SET @nMQTY = @nExpectedQTY    
      END    
      ELSE    
      BEGIN    
         SET @nPQTY = @nExpectedQTY / @nPUOM_Div  -- Calc QTY in preferred UOM    
         SET @nMQTY = @nExpectedQTY % @nPUOM_Div  -- Calc the remaining in master unit    
      END    
        
      -- Prep QTY screen var    
      SET @cOutField01 = @cSuggDropID  
        
      IF @cGetNextTaskSP = ''  
      BEGIN  
         SET @cOutField02 = 'CONSIGNEEKEY:'  
         SET @cOutField03 = @cScnText
      END  
      ELSE  
      BEGIN  
         SET @cOutField02 = @cScnLabel  
         SET @cOutField03 = @cSuggPTSPosition + '-' + @cScnText -- (ChewKP02)
      END  
            
      SET @cOutField05 = ''
      SET @cOutField06 = ''     

      SET @cOutField04 = @cSuggSKU    
      SET @cOutField05 = SUBSTRInG(@cSKUDescr, 1, 20)    
      SET @cOutField06 = SUBSTRInG(@cSKUDescr, 21, 20)    
        
      SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU      
      SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END      
      SET @cOutField08 = @cToteNo -- (ChewKP01)   
                                     
      IF @cPUOM_Desc = ''    
      BEGIN    
             
         --SET @cOutField08 = '' -- @cPUOM_Desc    
         SET @cOutField10 = '' -- @nPQTY    
         SET @cOutField12 = '' -- @nActPQTY    
         --SET @cOutField14 = '' -- @nPUOM_Div    
         -- Disable pref QTY field    
         SET @cFieldAttr12 = 'O'     
             
      END    
      ELSE    
      BEGIN    
         --SET @cOutField08 = @cPUOM_Desc    
         SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))    
         SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END -- '' -- @nActPQTY    
         --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))    
      END    
      
      
      --SET @cOutField09 = @cMUOM_Desc    
      SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))    
      SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE  '' END -- '' -- @nActPQTY    
          
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc    
          
      SET @nCountScanTask = 0     
      --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))    
    
      SET @cSKU = ''     
      SET @cInField12 = ''     
      SET @cInField13 = ''     
      SET @nActPQTY = 0    
      SET @nActMQTY = 0    
      SET @nSKUValidated = 0   
  
      -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
  
      --EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU    
        
            
            
   END  -- Inputkey = 1      
         
   IF @nInputKey = 0       
   BEGIN      
       -- Prepare Previous Screen Variable      
       SET @cOutField01 = ''   
         
       SELECT @nDropIDCount = Count(Distinct DropID)  
       FROM rdt.rdtPTSLog WITH (NOLOCK)   
       WHERE AddWho = @cUserName  
       AND Status = '0'  
    
       SET @cOutField02 = @nDropIDCount  
         
       SET @cOutField03 = ''      
       SET @cOutField04 = ''      
       SET @cOutField05 = ''    
                
       -- GOTO Previous Screen      
       SET @nScn = @nScn - 1      
       SET @nStep = @nStep - 1      
             
         
   END      
   GOTO Quit      
         
   Step_2_Fail:      
   BEGIN      
            
      -- Prepare Next Screen Variable      
      --SET @cOutField01 = @cPTSZone    
      SET @cOutField01 = @cSuggPTSPosition + ' - ' + @cScnText  -- (ChewKP02)   
      SET @cOutField02 = CASE WHEN @cDefaultPosition = '1' THEN @cSuggPTSPosition ELSE '' END
      SET @cOutField03 = ''      
            
   END      
      
END       
GOTO QUIT      
      
/********************************************************************************      
Step 3. Scn = 4722.       
       
   DropID    (Field01)    
   OutField1 (Field02)  
   OutField2 (Field03)  
   SKU       (Field04)    
   SKU Desc1 (Field05)    
   SKU Desc2 (Field06)  
   SKU       (Field07, input)    
   PUOM MUOM (Field09)    
   ESP QTY   (Field10, Field11)    
   ACT QTY   (Field12, Field13, both input)    
         
         
********************************************************************************/      
Step_3:      
BEGIN    
   IF @nInputKey = 1      -- Yes OR Send    
   BEGIN    
             
        
      -- Screen mapping    
      SET @cActPQTY = IsNULL( @cInField12, '')    
      SET @cActMQTY = IsNULL( @cInField13, '')    
      SET @cSKULabel = IsNULL( RTRIM(@cInField07), '')    
          
   
  
      IF ISNULL(RTRIM(@cSKULabel),'')  = '' AND @cDisableSKUField = '0' --AND @nSKUValidated = 0    
      BEGIN    
         SET @nErrNo = 104706    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUReq    
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU    
         GOTO Step_3_Fail    
      END    
          
          
      -- Retain the key-in value    
      SET @cOutField12 = @cInField12 -- Pref QTY    
      SET @cOutField13 = @cInField13 -- Master QTY  
      
      
      IF  ISNULL(RTRIM(@cActPQTY),'')  <> ''     
      BEGIN    
         IF RDT.rdtIsValidQTY( @cActPQTY, 0) = 0     
         BEGIN    
            SET @nErrNo = 104710    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'    
            EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY    
            GOTO Step_3_Fail    
         END    
      END    
    
    
      IF ISNULL(RTRIM(@cActMQTY),'')  <> ''    
      BEGIN    
         IF RDT.rdtIsValidQTY( @cActMQTY, 0) = 0    
         BEGIN    
            SET @nErrNo = 104711    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'    
            EXEC rdt.rdtSetFocusField @nMobile, 13 -- MQTY    
            GOTO Step_3_Fail    
         END    
      END    
    
    
    
      --SET @nActQTY = 0     
    
      -- Calc total QTY in master UOM    
      SET @nActPQTY = CAST( @cActPQTY AS INT)    
      SET @nActMQTY = CAST( @cActMQTY AS INT)    
      SET @nActQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @nActPQTY, @cPUOM, 6) -- Convert to QTY in master UOM    
  
      SET @nActQTY = ISNULL(@nActQTY,0)    + ISNULL(@nActMQTY,0)        

      IF @nSKUValidated = 1      
         SET @nActMQTY = ISNULL(@nActMQTY,0)    +ISNULL(@nActQTY,0)     
  
          
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
             
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT,' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         
         SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@nQty           INT,            ' +     
               '@cToLabelNo     NVARCHAR( 20),  ' +     
               '@cPTSLogKey     NVARCHAR( 20),  ' +  
               '@cShort         NVARCHAR(1),    ' +    
               '@cSuggLabelNo   NVARCHAR(20) OUTPUT, ' +    
               '@nErrNo         INT OUTPUT,     ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQTY, @cToLabelNo, @cPTSLogKey, @cShort, @cSuggLabelNo OUTPUT, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
               
               
         IF @nErrNo <> 0    
         BEGIN    
            GOTO Step_3_Fail    
         END    
         
  
      END      
      
    
      SET @nSKUValidated = 1   
  
      SET @cOutField12 = CASE WHEN @cFieldAttr12 = 'O' THEN '' ELSE CAST( @nActPQTY AS NVARCHAR( 5)) END -- PQTY    
      SET @cOutField13 = CAST( @nActMQTY AS NVARCHAR( 5)) -- MQTY    
      --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))    
    
          
      -- QTY fulfill    
      --IF @nActQTY = @nExpectedQTY    
      --BEGIN    
         
      SELECT TOP 1 @cWaveKey = O.UserDefine09
            ,@cConsigneeKey = O.ConsigneeKey 
      FROM rdt.rdtPTSLog PTSLog WITH (NOLOCK) 
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PTSLog.OrderKey
      WHERE PTSLog.StorerKey = @cStorerKey
      AND PTSLog.PTSLogKey = @cPTSLogKey 
      
      
      IF @cGetNextTaskSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +     
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                  
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@nQty           INT,            ' +     
               '@cLabelNo       NVARCHAR( 20),  ' +     
               '@cPTSPosition   NVARCHAR( 20),  ' + 
               '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +  
               '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
               '@cScnText       NVARCHAR( 20) OUTPUT, ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
            IF @nErrNo <> 0    
            BEGIN
               SET @nErrNo = 104723    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask   
               GOTO Step_3_Fail
            END
   
            IF ISNULL(@cPTSLogKey,'')  <> '' 
            BEGIN
               SET @cSuggPTSPosition   = ''
               SET @cSuggSKU           = ''
               SET @nExpectedQty       = ''
               SET @cScnText           = ''
               SET @cSuggDropID        = ''
               
      
               SELECT TOP 1   
                     @cSuggPTSPosition = PTSPosition   
                   , @cSuggSKU         = PTSLOG.SKU   
                   , @nExpectedQty     = PTSLOG.ExpectedQty  
                   , @cScnText         = PTSLOG.ConsigneeKey  
                   , @cSuggDropID      = PTSLog.DropID  
                   , @cPTSLogKey       = PTSLog.PTSLogKey  
                   , @cLot             = PTSLog.Lot
                   , @cToteNo          = PTSLog.LabelNo --(ChewKP01) 
               FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
               WHERE PTSLOG.StorerKey = @cStorerKey  
               AND PTSLOG.AddWho = @cUserName  
               AND PTSLOG.PTSLogKey = @cPTSLogKey
            END
        END    
      END  -- IF @cGetNextTaskSP <> ''    
  
      IF ISNULL(@cPTSLogKey,'')  = ''
      BEGIN
         
         SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
           AND PD.Status    IN ('0', '5' )
           AND PD.Qty > 0
           AND O.ConsigneeKey = @cConsigneeKey
           AND PD.WaveKey = @cWaveKey
         
         SELECT @nTotalPackedQty = ISNULL(SUM(PackD.QTY),0)
         FROM dbo.PackDetail PackD WITH (NOLOCK)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
         WHERE O.ConsigneeKey = @cConsigneeKey
         AND O.UserDefine09 = @cWaveKey
         
         IF @nTotalPickedQty  = @nTotalPackedQty 
         BEGIN
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1      
      
            GOTO QUIT 
         END
         ELSE
         BEGIN
            SET @nScn  = @nScn + 2
            SET @nStep = @nStep + 2      
      
            GOTO QUIT 
         END
      END
      ELSE 
      BEGIN
         --INSERT INTO TraceINfo (traceName , timein , col1, col2, col3 ) 
         --VALUES ( 'rdtfnc_UNI_PTS' , getdate() , @cPTSLogKey, @cSuggPTSPosition, @cPTSPosition ) 
         
         SELECT @nTotalPickedQty = ISNULL(SUM(PD.QTY),0)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
           AND PD.Status    IN ('0', '5' )
           AND PD.Qty > 0
           AND O.ConsigneeKey = @cConsigneeKey
           AND PD.WaveKey = @cWaveKey
         
         SELECT @nTotalPackedQty = ISNULL(SUM(PackD.QTY),0)
         FROM dbo.PackDetail PackD WITH (NOLOCK)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PackD.PickSlipNo
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
         WHERE O.ConsigneeKey = @cConsigneeKey
         AND O.UserDefine09 = @cWaveKey
         
         --SET @nTotalPickedQty = 1 
         --SET @nTotalPackedQty = 1 

         IF @nTotalPickedQty  = @nTotalPackedQty 
         BEGIN
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1      
      
            GOTO QUIT 
         END
         
         IF @cSuggPTSPosition = @cPTSPosition 
         BEGIN
            
            SET @cSKUDescr = '' 
            SET @cMUOM_Desc = ''
            SET @cPUOM_Desc = ''
            SET @nPUOM_Div = '' 
   
            
            SELECT    
            @cSKUDescr = SKU.Descr,  
            @cMUOM_Desc = Pack.PackUOM3,    
            @cPUOM_Desc =    
               CASE @cPUOM    
                  WHEN '2' THEN Pack.PackUOM1 -- Case    
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit    
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet    
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
               END,    
            @nPUOM_Div = CAST( IsNULL(    
               CASE @cPUOM    
                  WHEN '2' THEN Pack.CaseCNT    
                  WHEN '3' THEN Pack.InnerPack    
                  WHEN '6' THEN Pack.QTY    
                  WHEN '1' THEN Pack.Pallet    
                  WHEN '4' THEN Pack.OtherUnit1    
                  WHEN '5' THEN Pack.OtherUnit2    
               END, 1) AS INT)    
            FROM dbo.SKU SKU WITH (NOLOCK)    
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
            WHERE SKU.StorerKey = @cStorerKey    
               AND SKU.SKU = @cSuggSKU   
              
              
            -- Convert to prefer UOM QTY    
            IF @cPUOM = '6' OR -- When preferred UOM = master unit    
               @nPUOM_Div = 0  -- UOM not setup    
            BEGIN    
               SET @cPUOM_Desc = ''    
               SET @nPQTY = 0    
               SET @nMQTY = @nExpectedQTY    
            END    
            ELSE    
            BEGIN    
               SET @nPQTY = @nExpectedQTY / @nPUOM_Div  -- Calc QTY in preferred UOM    
               SET @nMQTY = @nExpectedQTY % @nPUOM_Div  -- Calc the remaining in master unit    
            END    
              
            -- Prep QTY screen var    
            SET @cOutField01 = @cSuggDropID  
              
            IF @cGetNextTaskSP = ''  
            BEGIN  
               SET @cOutField02 = 'CONSIGNEEKEY:'  
               SET @cOutField03 = @cScnText
            END  
            ELSE  
            BEGIN  
               SET @cOutField02 = @cScnLabel  
               SET @cOutField03 = @cSuggPTSPosition + '-' + @cScnText -- (ChewKP02)  
            END  
           
        
            SET @cOutField04 = @cSuggSKU    
            SET @cOutField05 = SUBSTRInG(@cSKUDescr, 1, 20)    
            SET @cOutField06 = SUBSTRInG(@cSKUDescr, 21, 20)    
              
            SET @cFieldAttr07 = CASE WHEN @cDisableSKUField = '1' THEN 'O' ELSE '' END --SKU      
            SET @cOutField07 = CASE WHEN @cDisableSKUField = '1' THEN @cSuggSKU ELSE '' END      
            SET @cOutField08 = @cToteNo -- (ChewKP01) 
              
            IF @cPUOM_Desc = ''    
            BEGIN    
                   
               --SET @cOutField08 = '' -- @cPUOM_Desc    
               SET @cOutField10 = '' -- @nPQTY    
               SET @cOutField12 = '' -- @nActPQTY    
               --SET @cOutField14 = '' -- @nPUOM_Div    
               -- Disable pref QTY field    
               SET @cFieldAttr12 = 'O'     
                   
            END    
            ELSE    
            BEGIN    
               --SET @cOutField08 = @cPUOM_Desc    
               SET @cOutField10 = CAST( @nPQTY AS NVARCHAR( 5))    
               SET @cOutField12 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nPQTY AS NVARCHAR( 5))   ELSE  '' END -- '' -- @nActPQTY    
               --SET @cOutField14 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))    
            END    
            
            
            --SET @cOutField09 = @cMUOM_Desc    
            SET @cOutField11 = CAST( @nMQTY as NVARCHAR( 5))    
            SET @cOutField13 = CASE WHEN @cDefaultQty = '1' THEN CAST( @nMQTY as NVARCHAR( 5)) ELSE  '' END -- '' -- @nActPQTY    
                
            SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + RIGHT('     ' + CAST(@cPUOM_Desc AS VARCHAR(5)), 5) + ' ' + @cMUOM_Desc   
                                                 
              
                
            --SET @nCountScanTask = 0     
            --SET @cOutField15 = CAST( @nCountScanTask AS NVARCHAR( 3)) + '/'  + CAST( @nTotalTaskCount AS NVARCHAR( 3))    
          
            SET @cSKU = ''     
            SET @cInField12 = ''     
            SET @cInField13 = ''     
            SET @nActPQTY = 0    
            SET @nActMQTY = 0    
            SET @nSKUValidated = 0   
        
            -- GOTO Next Screen      
            --SET @nScn = @nScn - 1      
            --SET @nStep = @nStep - 1     
        
            --EXEC rdt.rdtSetFocusField @nMobile, 7 -- SKU   
            
            GOTO QUIT
            
            
         END
         ELSE
         BEGIN
            
            SET @cOutField01 = @cSuggPTSPosition + ' - ' + @cScnText -- (ChewKP02) 
         
            IF @cDefaultPosition = '1'
            BEGIN
               SET @cOutField02 = @cSuggPTSPosition
            END
            ELSE
            BEGIN
               SET @cOutField02 = ''  
            END
            
            SET @nScn  = @nScn - 1 
            SET @nStep = @nStep - 1     
          
            GOTO QUIT    
            
            
         END
      END
             
--      END    
          
      -- Qty Short Manual Goto Short Screen    
--      IF (@nActQTY < @nExpectedQTY) OR (@nActQTY > @nExpectedQTY) --AND ISNULL(RTRIM(@cSKULabel),'')  = '' --AND @nSKUValidated = 1    
--      BEGIN    
--         
--         --SET @cERRMSG = @nSKUValidated    
--         SET @cOutField01 = ''  
--         SET @cOutField02 = ''    
--             
--         -- Go to next screen    
--         SET @nScn  = @nScn + 2    
--         SET @nStep = @nStep + 2    
--             
--         GOTO QUIT  
--      END    
    

    
         
   END    
    
   IF @nInputKey = 0 -- ESC    
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
          
          
      SET @cOutField01 = @cSuggPTSPosition + ' - ' + @cScnText -- (ChewKP02) 
      SET @cOutField02 = CASE WHEN @cDefaultPosition = '1' THEN @cSuggPTSPosition ELSE '' END  
    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1     
    
      GOTO QUIT    
    
    
    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN    
      -- - Start    
      SET @cFieldAttr12 = ''    
      -- - End    
    
      IF @cPUOM_Desc = ''    
         -- Pref QTY is always enable (as screen defination). When reach error, it will quit directly and forgot    
         -- to disable the Pref QTY field. So centralize disable it here for all fail condition    
         -- Disable pref QTY field    
         SET @cFieldAttr12 = 'O'     
             
      SET @cOutField07 = @cSKU  
    
      SET @cOutField12 = '' -- ActPQTY    
      SET @cOutField13 = '' -- ActMQTY    
   END    
END    
GOTO Quit     
      
/********************************************************************************      
Step 4. Scn = 4503.       
    
   ToLabelNo       (field01)      
   ToLabelNo       (field02, input)      
         
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1  --OR @nInputKey = 0 
   BEGIN      
     
      IF @cGetNextTaskSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetNextTaskSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextTaskSP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cDropID, @cSKU, @nQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT, ' +     
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                  
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cDropID        NVARCHAR( 20),  ' +     
               '@cSKU           NVARCHAR( 20),  ' +     
               '@nQty           INT,            ' +     
               '@cLabelNo       NVARCHAR( 20),  ' +     
               '@cPTSPosition   NVARCHAR( 20),  ' + 
               '@cPTSLogKey     NVARCHAR( 20) OUTPUT,  ' +  
               '@cScnLabel      NVARCHAR( 20) OUTPUT, ' +
               '@cScnText       NVARCHAR( 20) OUTPUT, ' + 
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @cUserName, @cFacility, @cStorerKey, @cSuggDropID, @cSKU, @nActQty, @cLabelNo, @cPTSPosition, @cPTSLogKey OUTPUT, @cScnLabel OUTPUT,  @cScnText OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT  
        
            IF @nErrNo <> 0    
            BEGIN
               SET @nErrNo = 104723    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoTask   
               GOTO Step_4_Fail
            END

            IF ISNULL(@cPTSLogKey,'' )  <> ''
            BEGIN
               SET @cSuggPTSPosition   = ''
               SET @cSuggSKU           = ''
               SET @nExpectedQty       = ''
               SET @cScnText           = ''
               SET @cSuggDropID        = ''
               
   
               SELECT TOP 1   
                     @cSuggPTSPosition = PTSPosition   
                   , @cSuggSKU         = PTSLOG.SKU   
                   , @nExpectedQty     = PTSLOG.ExpectedQty  
                   , @cScnText         = PTSLOG.ConsigneeKey  
                   , @cSuggDropID      = PTSLog.DropID  
                   , @cPTSLogKey       = PTSLog.PTSLogKey  
                   , @cLot             = PTSLog.Lot
                   , @cToteNo          = PTSLog.LabelNo --(ChewKP01) 
               FROM rdt.rdtPTSLog PTSLOG WITH (NOLOCK)   
               WHERE PTSLOG.StorerKey = @cStorerKey  
               AND PTSLOG.AddWho = @cUserName  
               AND PTSLOG.PTSLogKey = @cPTSLogKey
            END
         END    
      END  -- IF @cGetNextTaskSP <> ''    
   

      IF ISNULL(@cPTSLogKey,'')  = ''
      BEGIN
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1      
  
         GOTO QUIT 
      END
      ELSE 
      BEGIN
         
         SET @cOutField01 = @cSuggPTSPosition + ' - ' + @cScnText -- (ChewKP02) 
         
         IF @cDefaultPosition = '1'
         BEGIN
            SET @cOutField02 = @cSuggPTSPosition
         END
         ELSE
         BEGIN
            SET @cOutField02 = ''  
         END
         
         SET @nScn  = @nScn - 2 
         SET @nStep = @nStep - 2     
       
         GOTO QUIT    
      END
          
            
   END  -- Inputkey = 1      
   
   GOTO QUIT 

   Step_4_Fail:    
   BEGIN    
        
    
      --SET @cOutField01 = @cSuggLabelNo  
      SET @cOutField02 = ''     
   END        
      

      
END       
GOTO QUIT      
  
/********************************************************************************      
Step 5. Scn = 4723.       
    
         
********************************************************************************/      
Step_5:      
BEGIN      
   IF @nInputKey = 1  --OR @nInputKey = 0 
   BEGIN      
     
      SET @cOutField01 = ''
     
      SET @nScn  = @nScn - 4
      SET @nStep = @nStep - 4      
  
      GOTO QUIT 
                 
   END  -- Inputkey = 1      
      
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
      Printer   = @cPrinter,       
      --UserName  = @cUserName,     
      EditDate  = GetDate() ,  
      InputKey  = @nInputKey,   
      LightMode = @cLightMode,  
            
      V_SKUDescr = @cSKUDescr,  
      V_UOM = @cPUOM,  
      V_SKU = @cSKU,     
      V_Lot = @cLot,
    
      V_String1 = @cExtendedUpdateSP   ,      
      V_String2 = @cExtendedValidateSP ,      
      V_String3 = @cDecodeLabelNo      ,      
      V_String4 = @cDefaultQTY         ,      
      V_String5 = @cDisableSKUField    ,      
      V_String6 = @cGeneratePackDetail ,      
      V_String7 = @cGetNextTaskSP,   
      V_String8 = @cSuggPTSPosition,   
      V_String9 = @cSuggSKU,  
      V_String10 = @cSuggDropID,  
      V_String11 = @cMUOM_Desc,    
      V_String12 = @cPUOM_Desc,    
      V_String13 = @cScnText,   
      --V_String14 = @nExpectedQTY,  
      V_String15 = @nSKUValidated,  
      V_String16 = @cPTSLogKey,    
      --V_String23 = @nQty,   
      V_String24 = @cPTSPosition,
      V_String25 = @cScnLabel,
      V_String26 = @cShort,
      V_String27 = @cDropID,
      V_String28 = @cDefaultPosition,
      V_String29 = @cDefaultToLabel, 
      V_String30 = @cExtendedInfoSP,
      V_String31 = @cToteNo, -- (ChewKP01) 
      
      V_PUOM_Div = @nPUOM_Div ,  
      V_MQTY     = @nMQTY     ,  
      V_PQTY     = @nPQTY     ,
      V_QTY      = @nExpectedQTY, 
       
      V_Integer1 = @nActMQTY  ,  
      V_Integer2 = @nActPQTY  ,  
      V_Integer3 = @nActQty   ,

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