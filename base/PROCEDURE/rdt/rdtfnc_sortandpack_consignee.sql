SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                
/* Store procedure: rdtfnc_SortAndPack_Consignee                        */                
/* Copyright      : LFL                                                 */                
/*                                                                      */                
/* Purpose: Sort, then pick and pack                                    */                
/*                                                                      */                
/* Modifications log:                                                   */                
/*                                                                      */                
/* Date       Rev  Author     Purposes                                  */                
/* 2020-11-05 1.0  Chermaine  WMS-15185 Created                         */                
/* 2021-06-30 1.1  James      WMS-17406 Add rdt_STD_EventLog (james01)  */  
/************************************************************************/                
                
CREATE PROC [RDT].[rdtfnc_SortAndPack_Consignee] (                
   @nMobile    INT,                
   @nErrNo     INT  OUTPUT,                
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max                
) AS                
                
SET NOCOUNT ON                
SET ANSI_NULLS OFF                
SET QUOTED_IDENTIFIER OFF                
SET CONCAT_NULL_YIELDS_NULL OFF                
                
-- Misc variable                
DECLARE             
   @b_Success     INT,                 
   @cExtendedInfo NVARCHAR(20),                
   @cSQL          NVARCHAR(1000),                 
   @cSQLParam     NVARCHAR(1000)                
            
            
DECLARE @tCartonManifest AS VariableTable            
                               
-- RDT.RDTMobRec variable                
DECLARE                
   @nFunc       INT,                
   @nScn        INT,                
   @nStep       INT,                
   @cLangCode   NVARCHAR( 3),                
   @nInputKey   INT,                
   @nMenu       INT,                
                
   @cStorerKey  NVARCHAR( 15),                
   @cFacility   NVARCHAR( 5),                
   @cUserName   NVARCHAR( 18),                
   @cPaperPrinter  NVARCHAR( 10),             
   @cLabelPrinter  NVARCHAR( 10),            
               
   @cWaveKey      NVARCHAR( 10),            
   @cBatchkey     NVARCHAR( 10),            
   @cPosition     NVARCHAR( 10),            
   @cPalletID     NVARCHAR( 20),            
   @cDecodeSKU    NVARCHAR( 20),            
   @cOption       NVARCHAR( 1),             
   @nQTY          INT,             
   @nQtyScan      INT,            
   @nFromWave     INT,            
   @nLogQty       INT,            
                
   @cLoadKey      NVARCHAR( 10),              
   @cBarcode      NVARCHAR( 20),                
   @cSKU          NVARCHAR( 20),               
   @cUCCNo        NVARCHAR( 20),            
   @cSKUDescr     NVARCHAR( 60),                
   @cConsigneeKey NVARCHAR( 15),                
   @cOrderKey     NVARCHAR( 10),                 
   @cLabelNo      NVARCHAR( 20),              
   @cPackData     NVARCHAR( 1),            
   @nLoadQTY      INT,             
   @nWaveQTY      INT,             
                  
   @cLoadKeyCMF   NVARCHAR( 10),              
   @cSKUCMF       NVARCHAR( 20),            
   @cUCCNoCMF     NVARCHAR( 20),            
   @cLabelNoCMF   NVARCHAR( 20),             
   @nQtyCMF       INT,            
            
   @cAutoPrintCartonLabel  NVARCHAR( 1),            
   @cCartonManifest        NVARCHAR( 10),            
   @cCartonType            NVARCHAR( 10),             
            
   @cPickSlipNo            NVARCHAR( 10),               
   @nCartonNo              INT,             
               
   @c_oFieled01 NVARCHAR( 20), @c_oFieled02 NVARCHAR( 20),            
   @c_oFieled03 NVARCHAR( 20), @c_oFieled04 NVARCHAR( 20),    
   @c_oFieled05 NVARCHAR( 20), @c_oFieled06 NVARCHAR( 20),            
   @c_oFieled07 NVARCHAR( 20), @c_oFieled08 NVARCHAR( 20),            
   @c_oFieled09 NVARCHAR( 20), @c_oFieled10 NVARCHAR( 20),            
   @c_oFieled11 NVARCHAR( 20), @c_oFieled12 NVARCHAR( 20),            
   @c_oFieled13 NVARCHAR( 20), @c_oFieled14 NVARCHAR( 20),            
   @c_oFieled15 NVARCHAR( 20),            
            
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
   @nFunc       = Func,                
   @nScn        = Scn,                
   @nStep       = Step,                
   @nInputKey   = InputKey,                
   @nMenu       = Menu,                
   @cLangCode   = Lang_code,                
                
   @cStorerKey  = StorerKey,                
   @cFacility   = Facility,                
   @cUserName   = UserName,               
   @cPaperPrinter    = Printer_Paper,             
   @cLabelPrinter    = Printer,             
                
   @cLoadKey      = V_LoadKey,                
   @cSKU          = V_SKU,                
   @cSKUDescr     = V_SKUDescr,                
   @cConsigneeKey = V_ConsigneeKey,                
   @cOrderKey     = V_OrderKey,                 
   @cLabelNo      = V_CaseID,             
   @nCartonNo     = V_Cartonno,               
               
   @nLoadQTY      = V_Integer1,            
   @nQtyScan      = V_Integer2,            
   @nFromWave     = V_Integer3,         
   @nlogQty       = V_Integer4,        
   @nWaveQTY      = V_Integer5,      
               
   @cWaveKey          = V_String1,            
   @cBatchKey         = V_String2,             
   @cPosition         = V_String3,             
   @cPalletID         = V_String4,            
   @cPackData         = V_String5,            
   @cAutoPrintCartonLabel = V_String6,            
   @cCartonManifest   = V_String7,            
   @cPickSlipNo       = V_String8,             
   @cCartonType       = V_String9,             
   @cUCCNo            = V_String10,             
   @cOption           = V_String11,      
           
            
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
                
FROM RDTMOBREC (NOLOCK)                
WHERE Mobile = @nMobile                
                
-- Redirect to respective screen                
IF @nFunc = 1851               
BEGIN                
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1851                
   IF @nStep = 1 GOTO Step_1   -- Scn = 5860. Wave/batchkey/ LabelNo                
   IF @nStep = 2 GOTO Step_2   -- Scn = 5861. UCC               
   IF @nStep = 3 GOTO Step_3   -- Scn = 5862. Label                
   --IF @nStep = 4 GOTO Step_4   -- Scn = 5863. Print Carton                
            
END                
RETURN -- Do nothing if incorrect step                
                
                
/********************************************************************************                
Step 0. Called from menu                
********************************************************************************/                
Step_0:                
BEGIN                
   -- Set the entry point                
   SET @nScn = 5860                
   SET @nStep = 1                
            
   ---- Get StorerConfig                
   SET @cAutoPrintCartonLabel = rdt.RDTGetConfig( @nFunc, 'AutoPrintCartonLabel', @cStorerKey)                
            
   SET @cCartonManifest = rdt.RDTGetConfig( @nFunc, 'CartonManifest', @cStorerKey)            
   IF @cCartonManifest = '0'            
      SET @cCartonManifest = ''            
               
   -- Clear previous stored record            
   --DELETE FROM RDT.rdtSortAndPackLog            
   --WHERE AddWho = @cUserName            
                     
   -- Logging                
   EXEC RDT.rdt_STD_EventLog                
      @cActionType = '1', -- Sign in function                
      @cUserID     = @cUserName,                
      @nMobileNo   = @nMobile,                
      @nFunctionID = @nFunc,                
      @cFacility   = @cFacility,                
      @cStorerKey  = @cStorerkey            
            
   -- Prep next screen var               
   --SET @cLoadKey         = ''    ----update 2021-05-24            
   SET @cSKU             = ''            
   SET @cConsigneeKey    = ''            
   SET @cOrderKey        = ''            
   SET @cLabelNo         = ''            
   SET @cPickSlipNo      = ''            
   SET @cUCCNo           = ''            
   SET @cCartonType      = ''            
   SET @cExtendedInfo    = ''            
   SET @nLoadQTY         = 0            
   SET @nCartonNo        = 0            
            
   SET @cOutField01 = ''  -- LoadKey    
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
                
   EXEC rdt.rdtSetFocusField @nMobile, 1                
END                
GOTO Quit                
                
                
/********************************************************************************                
Step 1. Wave Screen = 5860                
   WAVE KEY    (Field01, input)                
   BATCH KEY   (Field02, input)            
   Label NO    (Field03, input)            
********************************************************************************/                
Step_1:                
BEGIN                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @cWaveKey = @cInField01            
      SET @cBatchKey = @cInField02               
      SET @cLabelNo = @cInField03                      
                
      -- Check blank                
      IF @cWaveKey = '' AND @cBatchKey = '' AND @cLabelNo = ''            
      BEGIN                
         SET @nErrNo = 160451                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key Either One                
         GOTO Step_1_Fail                
      END             
                  
      -- Check either one                
      IF @cWaveKey <> '' AND @cBatchKey <> '' AND @cLabelNo <> ''            
      BEGIN                
         SET @nErrNo = 160452                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key Either One                
         GOTO Step_1_Fail                
      END              
                  
      -- Check valid batchKey       
      -- When scan batchKey do Sorting and Packing         
      IF @cBatchKey <> ''            
      BEGIN            
       IF NOT EXISTS( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE UserDefine09 = @cBatchKey)                
         BEGIN                
            SET @nErrNo = 160453                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidBatchKey                
            GOTO Step_1_Fail                
         END              
                     
         -- Check Same Facility            
         IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) WHERE UserDefine09 = @cBatchKey AND Facility = @cFacility )             
         BEGIN            
            SET @nErrNo = 160454                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff Facility                
            GOTO Step_1_Fail              
         END            
                  
         -- Check Same Storer            
         IF NOT EXISTS ( SELECT 1            
                           FROM ORDERS O WITH (NOLOCK)             
                           JOIN LoadPlanDetail LPD WITH (NOLOCK) ON O.orderKey = LPD.OrderKey            
                           JOIN LoadPlan LP WITH (NOLOCK) ON LPD.LoadKey = LP.LoadKey            
                           WHERE LP.UserDefine09 = @cBatchKey            
                           AND O.storerKey = @cStorerKey )             
         BEGIN            
            SET @nErrNo = 160455                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff Storer                
            GOTO Step_1_Fail              
         END                
                     
         SET @nFromWave = 0                 
      END            
                  
      -- Check valid waveKey 
      -- When scan wakeKey do Sorting only         
      IF @cWaveKey <> ''            
      BEGIN            
       IF NOT EXISTS ( SELECT 1            
                        FROM ORDERS O WITH (NOLOCK)             
                        JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (O.orderKey = LPD.OrderKey)  
                        JOIN LoadPlan LP WITH (NOLOCK) ON (LPD.LoadKey = LP.LoadKey)            
                        WHERE O.UserDefine09 = @cWaveKey )            
         BEGIN            
            SET @nErrNo = 160456                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidWaveKey                
            GOTO Step_1_Fail            
         END            
                     
         -- Check Same Facility            
         IF NOT EXISTS ( SELECT 1            
                        FROM ORDERS O WITH (NOLOCK)             
                        JOIN LoadPlanDetail LPD WITH (NOLOCK) ON O.orderKey = LPD.OrderKey            
                        JOIN LoadPlan LP WITH (NOLOCK) ON LPD.LoadKey = LP.LoadKey            
                        WHERE O.UserDefine09 = @cWaveKey         
                AND LP.facility = @cFacility )             
         BEGIN            
            SET @nErrNo = 160457                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff Facility                
            GOTO Step_1_Fail              
         END            
                  
         -- Check Same Storer            
         IF NOT EXISTS ( SELECT 1            
                           FROM ORDERS O WITH (NOLOCK)             
                           JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (O.orderKey = LPD.OrderKey)           
                           JOIN LoadPlan LP WITH (NOLOCK) ON (LPD.LoadKey = LP.LoadKey)           
                           WHERE O.UserDefine09 = @cWaveKey            
                           AND O.storerKey = @cStorerKey )             
         BEGIN            
            SET @nErrNo = 160458                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Diff Storer                
            GOTO Step_1_Fail              
         END            
                     
         SET @nFromWave = 1            
                   
      END            
                  
                  
      IF @cLabelNo <> ''            
      BEGIN            
         if EXISTS (select 1 from rdt.rdtSortAndPackLog WITH (NOLOCK) where storerKey = @cStorerKey and status = 9 and LabelNo = @cLabelNo)            
         BEGIN            
            SET @nErrNo = 160484                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Carton Closed                
            GOTO Step_1_Fail            
         END            
                     
         DECLARE @curCFM CURSOR             
         SET @curCFM = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
            SELECT loadKey,SKU,UCC,QTY,labelNo            
            FROM rdt.rdtSortAndPackLog WITH (NOLOCK)              
            WHERE StorerKey = @cStorerKey              
               AND QTY > 0              
               AND Status = 0              
               AND labelNo = @cLabelNo            
               AND WaveKey = ''            
            ORDER BY RowRef              
              
         OPEN @curCFM              
         FETCH NEXT FROM @curCFM INTO @cLoadKeyCMF, @cSkuCMF, @cUCCNoCMF, @nQtyCMF, @cLabelNoCMF              
         WHILE @@FETCH_STATUS = 0        
         BEGIN              
            EXEC rdt.rdt_SortAndPackConsignee_Confirm @nMobile, @nFunc, @cLangCode
            ,@cLoadKeyCMF, @cStorerKey, @cSkuCMF, @cUCCNoCMF, @nQtyCMF, @cLabelNoCMF, @cCartonType                 
            ,@nErrNo        OUTPUT                
            ,@cErrMsg     OUTPUT              
            
            IF @nErrNo <> 0                
               GOTO Step_2_Fail              
                           
            Update rdt.rdtSortAndPackLog WITH (ROWLOCK) SET             
               status = 9             
            WHERE LoadKey = @cLoadKeyCMF              
               AND StorerKey = @cStorerKey              
               AND QTY > 0              
               AND Status = 0              
               --AND mobile = @nMobile              
               AND SKU = @cSkuCMF            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 160485          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
               GOTO Step_1_Fail               
            END            
                        
            FETCH NEXT FROM @curCFM INTO @cLoadKeyCMF, @cSkuCMF,@cUCCNoCMF, @nQtyCMF, @cLabelNoCMF              
         END             
                     
         --print Label            
         IF @cAutoPrintCartonLabel = '1'            
         BEGIN            
            --auto print carton            
            IF @cCartonManifest <> ''            
            BEGIN             
               SELECT 
                  @cPickSlipNo = pickslipNo, 
                  @nCartonNo = cartonNo 
               FROM packDetail WITH (NOLOCK) 
               WHERE storerKey = @cStorerKey 
               AND LabelNo = @cLabelNo 
               GROUP BY pickslipNo,cartonNo
                           
               -- Common params            
               DELETE @tCartonManifest            
               INSERT INTO @tCartonManifest (Variable, Value) VALUES             
                  ( '@cStorerKey',     @cStorerKey), --@c_Storerkey            
                  ( '@cPickSlipNo',    @cPickSlipNo), --@c_PickSlipNo            
                  ( '@nStartCartonNo', CAST( @nCartonNo AS NVARCHAR(10))), --@c_StartCartonNo            
                  ( '@nEndCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))--@c_EndCartonNo            
             
               -- Print label            
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,             
                  @cCartonManifest, -- Report type            
                  @tCartonManifest, -- Report params            
                  'rdtfnc_SortAndPack_Consignee',             
                  @nErrNo  OUTPUT,            
                  @cErrMsg OUTPUT            
            
               IF @nErrNo <> 0            
                  GOTO Quit            
            
            END            
         END            
      END            
      ELSE IF @cLabelNo = ''            
      BEGIN            
         SET @cOutField01 = ''   --SKU/UCC            
         SET @cOutField02 = (CASE WHEN @cLoadKey='' OR @cLoadKey IS NULL THEN '' ELSE LEFT(@cLoadKey,6)+' - '+RIGHT(@cLoadKey,4) END)    ---MODIFIED               
         SET @cOutField03 = @cBatchKey                
         SET @cOutField04 = @cPosition            
         SET @cOutField05 = @cPalletID                
         SET @cOutField06 = CONVERT(NVARCHAR(5),@nlogQty) + '/' + CONVERT(NVARCHAR(10),@nWaveQTY)            
         SET @cOutField07 = '' --option             
                  
         -- Go to SKU screen                
         SET @nScn  = @nScn + 1                
         SET @nStep = @nStep + 1            
                     
         EXEC rdt.rdtSetFocusField @nMobile, 1--sku            
      END            
      ELSE            
      BEGIN            
         SET @cOutField01 = ''  -- WaveKey              
         SET @cOutField02 = ''  -- BatchKey            
         SET @cOutField03 = ''  -- LabelNo            
      END            
                  
                  
      GOTO Quit            
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN              -- Logging                
  EXEC RDT.rdt_STD_EventLog                
         @cActionType = '9', -- Sign Out function                
         @cUserID     = @cUserName,                
         @nMobileNo   = @nMobile,                
         @nFunctionID = @nFunc,                
         @cFacility   = @cFacility,                
         @cStorerKey  = @cStorerkey            
                
      -- Back to menu                
      SET @nFunc = @nMenu                
      SET @nScn  = @nMenu                
      SET @nStep = 0                
      SET @cOutField01 = '' -- Clean up for menu option                
                
   END                
   GOTO Quit                
                
   Step_1_Fail:                
   BEGIN                
      SET @cBatchkey = ''                
      SET @cWaveKey = ''                
   END                
END                
GOTO Quit     
       
                
/********************************************************************************     
Step 2. SKU Screen = 5861                
   UCC         (Field01 input)               
   LOADKEY     (Field02)            
   BATCHKEY    (Field03)                 
   POSITION    (Field04)            
   PALLETID    (Field05)            
   TOTAL QTY   (Field06)            
   CLOSE CARTON(Field08, input)                      
********************************************************************************/                
Step_2:                
BEGIN                
   IF @nInputKey = 1 -- ENTER                
   BEGIN                
      -- Screen mapping                
      SET @cBarcode = @cInField01             
      SET @cOption = @cInField07            
      SET @cSKU = ''            
      SET @cUCCNo = ''            
                  
      -- Check blank                
      IF @cBarcode = '' AND @cOption NOT IN ('','0')            
      BEGIN                
         SET @nErrNo = 160459                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UCC                
         GOTO Step_2_Fail                
      END             
                  
      IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cBarcode AND storerKey = @cStorerKey)            
      BEGIN            
         SET @cUCCNo = @cBarcode              
         SELECT 
            @nQtyScan = QTY 
         FROM UCC WITH (NOLOCK) 
         WHERE storerKey = @cStorerKey 
         AND uccNo = @cUCCNo            
      END            
      ELSE            
      BEGIN            
         SET @nErrNo = 160488                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC                
         GOTO Step_2_Fail       
      END            
                  
      IF @cUCCNo <> ''            
      BEGIN            
         IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UCCNo = @cUCCNo)            
         BEGIN            
            SET @nErrNo = 160488                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC                
            GOTO Quit            
         END            
                
         IF (SELECT COUNT(UCC_RowRef) FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UCCNo = @cUCCNo) >1            
         BEGIN            
            SET @nErrNo = 160489                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC >1 SKU                 
            GOTO Quit            
         END            
            
         IF EXISTS (SELECT 1 FROM rdt.rdtSortAndPackLog WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UCC = @cUCCNo)            
         BEGIN            
            SET @nErrNo = 160490                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ucc Scanned                 
            GOTO Quit            
         END            
                
         SELECT 
            @cSKU = SKU 
         FROM UCC WITH (NOLOCK) 
         WHERE Storerkey = @cStorerKey 
         AND UCCNo = @cUCCNo                  
      END            
            
      IF @cSKU <> ''            
      BEGIN            
       -- Get SKU count                
         DECLARE @nSKUCnt INT                
         EXEC [RDT].[rdt_GETSKUCNT]                
             @cStorerKey  = @cStorerKey                
            ,@cSKU        = @cSKU                
            ,@nSKUCnt     = @nSKUCnt       OUTPUT                
            ,@bSuccess    = @b_Success     OUTPUT                
            ,@nErr        = @nErrNo        OUTPUT                
            ,@cErrMsg     = @cErrMsg       OUTPUT                
                   
         -- Validate SKU/UPC                
         IF @nSKUCnt = 0                
         BEGIN                
            SET @nErrNo = 160461                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU                
            GOTO Step_2_Fail                
         END                
                   
         -- Validate barcode return multiple SKU           
         IF @nSKUCnt > 1                
         BEGIN                
            SET @nErrNo = 160462                
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU                
            GOTO Step_2_Fail                
         END      
         
         -- Get SKU                
         EXEC [RDT].[rdt_GETSKU]                
             @cStorerKey  = @cStorerKey                
            ,@cSKU        = @cSKU          OUTPUT                
            ,@bSuccess    = @b_Success     OUTPUT                
            ,@nErr        = @nErrNo        OUTPUT                
            ,@cErrMsg     = @cErrMsg       OUTPUT                
                                   
        EXEC rdt.rdt_SortAndPack_Consignee_GetTask @nMobile, @nFunc, @cLangCode, @cUserName, @cWaveKey, @cBatchkey,@cStorerKey, @cSKU, @cUCCNo            
            ,@cBatchkey       OUTPUT            
            ,@cLoadKey        OUTPUT            
            ,@cSKU            OUTPUT            
            ,@cConsigneeKey   OUTPUT                
            ,@cOrderKey       OUTPUT                
            ,@cPosition       OUTPUT                
            ,@cPalletID       OUTPUT                
            ,@cPackData       OUTPUT            
            ,@nLoadQTY        OUTPUT             
            ,@nErrNo          OUTPUT                
            ,@cErrMsg         OUTPUT             
            
                        
         IF @nErrNo <> 0               
         GOTO Step_2_Fail                
            
         --wave ->sorting Only (SKU/UCC), batch->sorting and packing (SKU)            
         IF @nFromWave = 1            
         BEGIN      
         	SELECT 
         	   @nQty = SUM(Qty) + @nQtyScan 
         	FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
         	WHERE StorerKey = @cStorerKey   
         	AND WaveKey = @cWaveKey  
         	AND SKU = @cSKU    
         	          
            SELECT 
               @nLogQty = COUNT(1) 
            FROM rdt.rdtSortAndPackLog 
            WHERE StorerKey = @cStorerKey 
            AND WaveKey = @cWaveKey  
            --AND sku = @cSKU             
     
            --Compute Total Qty of the Wave            
            SELECT 
               @nWaveQTY = SUM(O.QTY)  
            FROM (  
                    SELECT SKU, SUM(PD.QTY) / PK.CaseCnt AS QTY  
                    FROM LOADPLAN LP WITH (NOLOCK)  
                     LEFT JOIN ORDERS O WITH (NOLOCK) ON (LP.LOADKEY = O.LOADKEY)  
                     LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (O.ORDERKEY = PD.ORDERKEY)  
                     LEFT JOIN PACK PK WITH (NOLOCK) ON (PD.PACKKEY = PK.PACKKEY)  
                    WHERE O.UserDefine09 = @cWaveKey  
                     AND PD.UOM = 2  
                    GROUP BY PK.CaseCnt, SKU  
                  ) O          
          
            IF (@nQty > @nLoadQTY) OR (@nLogQty >= @nWaveQTY )          
            BEGIN            
               SET @nErrNo = 160464                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Over Pack                
               GOTO Step_2_Fail            
            END    
                    
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtSortAndPackLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND loadKey = @cLoadKey AND SKU = @cSKU AND UCC = @cUccNo AND WaveKey = @cWaveKey)            
            BEGIN            
               INSERT INTO rdt.rdtSortAndPackLog ( Mobile, Username, StorerKey, LoadKey, [Status], WaveKey, BatchKey, SKU, UCC, QTY, CartonType )            
               VALUES (@nMobile, @cUserName, @cStorerKey, @cLoadKey, '0', @cWaveKey, @cBatchkey, @cSKU, @cUccNo, @nQtyScan, RIGHT(@cPalletID,10))            
                        
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 160463                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InsertLogFail                
                  GOTO Step_2_Fail               
               END       
  
               EXEC RDT.rdt_STD_EventLog  
                  @cActionType   = '3', -- Picking    
                  @cUserID       = @cUserName,    
                  @nMobileNo     = @nMobile,    
                  @nFunctionID   = @nFunc,    
                  @cFacility     = @cFacility,    
                  @cStorerKey    = @cStorerKey,    
                  @cWaveKey      = @cWaveKey,    
                  @cLabelNo      = @cLabelNo,  
                  @cUCC          = @cUCCNo,    
                  @cRefNo3       = @cBatchkey,  
                  @nQTY          = @nQtyScan,  
                  @cSKU          = @cSKU,  
                  @cLoadKey      = @cLoadKey,  
                  @cCartonType   = @cCartonType  
            END            
            ELSE            
            BEGIN            
               UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
                  QTY = @nQty + @nQtyScan 
               WHERE StorerKey = @cStorerKey 
               AND loadKey = @cLoadKey 
               AND SKU = @cSKU 
               AND UCC = @cUccNo 
               AND WaveKey = @cWaveKey            
                       
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 160465                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
                  GOTO Step_2_Fail               
               END             
            END    
                               
            SELECT 
               @nLogQty = COUNT(1) 
            FROM rdt.rdtSortAndPackLog 
            WHERE StorerKey = @cStorerKey 
            AND WaveKey = @cWaveKey        
         END --end @nFromWave = 1            
                   
                
         IF @nFromWave = 0 AND @cUccNo = ''            
         BEGIN                      
            SELECT 
               @nQty = SUM(Qty) + @nQtyScan 
            FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
            AND loadKey = @cLoadKey 
            AND SKU = @cSKU 
            AND WaveKey = '' 
            AND batchKey = @cBatchkey 
            AND STATUS = 0            
                       
            IF @nQty > @nLoadQTY            
            BEGIN           
               SET @nErrNo = 160467                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Over Pack                
               GOTO Step_2_Fail            
            END            
                      
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtSortAndPackLog WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND loadKey = @cLoadKey AND SKU = @cSKU AND WaveKey = '' AND batchKey = @cBatchkey AND STATUS = 0)            
            BEGIN        
               INSERT INTO rdt.rdtSortAndPackLog ( Mobile, Username, StorerKey, LoadKey, [Status], WaveKey, BatchKey, SKU, UCC, QTY, CartonType)            
               VALUES            
               (@nMobile, @cUserName, @cStorerKey, @cLoadKey, '0', '', @cBatchkey, @cSKU, @cUccNo, @nQtyScan, RIGHT(@cPalletID,10))            
                        
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 160466                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InsertLogFail                
                  GOTO Step_2_Fail               
               END            
            END            
            ELSE            
            BEGIN            
               UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
                  QTY = @nQty + @nQtyScan 
               WHERE StorerKey = @cStorerKey 
               AND loadKey = @cLoadKey 
               AND SKU = @cSKU 
               AND UCC = @cUCCNo 
               AND WaveKey = '' 
               AND batchKey = @cBatchkey 
               AND LabelNo <> '' 
               AND STATUS = 0      
                      
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 160468                
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
                  GOTO Step_2_Fail               
               END              
            END            
          
            SELECT 
               @nLogQty = COUNT(1) 
            FROM rdt.rdtSortAndPackLog 
            WHERE StorerKey = @cStorerKey 
            AND WaveKey = @cWaveKey   
            ---AND sku = @cSKU              
            
            SELECT 
               @nWaveQTY = COUNT(1) 
            FROM LOADPLAN LP WITH (NOLOCK) 
            LEFT JOIN ORDERS O WITH (NOLOCK) ON (LP.LOADKEY=O.LOADKEY)LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (O.ORDERKEY=PD.ORDERKEY)           
            WHERE O.UserDefine09 = @cWaveKey           
            AND PD.UOM=2           
         END            
     
         SET @cOutField01 = ''   --SKU/UCC            
         SET @cOutField02 = (CASE WHEN @cLoadKey='' OR @cLoadKey IS NULL THEN '' ELSE LEFT(@cLoadKey,6)+' - '+RIGHT(@cLoadKey,4) END)   ---MODIFIED               
         SET @cOutField03 = @cBatchKey                
         SET @cOutField04 = @cPosition            
         SET @cOutField05 = @cPalletID                
         SET @cOutField06 = CONVERT(NVARCHAR(5),@nlogQty) + '/' + CONVERT(NVARCHAR(10),@nWaveQTY)            
         SET @cOutField07 = '' --option            
            
         SET @nScn  = @nScn               
         SET @nStep = @nStep            
                     
         EXEC rdt.rdtSetFocusField @nMobile, 1  -- SKU             
                     
         --generate label for batchKey for 1st time           
         IF EXISTS (SELECT 1 
                    FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
                    WHERE StorerKey = @cStorerKey 
                    AND loadKey = @cLoadKey 
                    AND labelNo = '' 
                    AND WaveKey = '' 
                    AND batchKey = @cBatchkey 
                    AND STATUS = 0) AND @nFromWave = 0            
         BEGIN            
            EXECUTE dbo.nsp_GenLabelNo              
               @cOrderKey,              
               @cStorerKey,              
               @c_labelno     = @cLabelNo  OUTPUT,              
               @n_cartonno    = @nCartonNo OUTPUT,              
               @c_button      = '',              
               @b_success     = @b_success OUTPUT,              
               @n_err         = @nErrNo    OUTPUT,              
               @c_errmsg      = @cErrMsg   OUTPUT              
              
            IF @b_success <> 1              
            BEGIN              
               SET @nErrNo = 160469              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabel Fail'              
               GOTO Step_2_Fail              
            END              
                           
            SET @cOutField01 = @cLabelNo                        
             
            --go to labelNo scn            
            SET @nScn  = @nScn + 1              
            SET @nStep = @nStep + 1            
         END                
      END -- @cSKU <> ''            
                     
                  
      --Close Carton for batchKey            
      IF @cOption = 1 AND @nFromWave = 0            
      BEGIN             
       DECLARE @curCFM1 CURSOR              
         SET @curCFM1 = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
            SELECT loadKey,SKU,UCC,QTY,labelNo            
            FROM rdt.rdtSortAndPackLog WITH (NOLOCK)              
            WHERE StorerKey = @cStorerKey              
               AND QTY > 0              
               AND Status = 0              
               --AND mobile = @nMobile             
               AND labelNo = @cLabelNo            
             AND WaveKey = ''            
            ORDER BY RowRef              
              
         OPEN @curCFM1              
         FETCH NEXT FROM @curCFM1 INTO @cLoadKeyCMF, @cSkuCMF, @cUCCNoCMF, @nQtyCMF, @cLabelNoCMF              
         WHILE @@FETCH_STATUS = 0              
         BEGIN              
            EXEC rdt.rdt_SortAndPackConsignee_Confirm @nMobile, @nFunc, @cLangCode
            ,@cLoadKeyCMF, @cStorerKey, @cSkuCMF, @cUCCNoCMF, @nQtyCMF, @cLabelNoCMF, @cCartonType                 
            ,@nErrNo        OUTPUT                
            ,@cErrMsg       OUTPUT              
            
            IF @nErrNo <> 0                
               GOTO Step_2_Fail              
            
            Update rdt.rdtSortAndPackLog WITH (ROWLOCK) SET             
               status = 9             
            WHERE LoadKey = @cLoadKeyCMF              
               AND StorerKey = @cStorerKey              
               AND QTY > 0              
               AND Status = 0              
               --AND mobile = @nMobile              
               AND SKU = @cSkuCMF            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 160477                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
               GOTO Step_2_Fail        
            END            
            
            FETCH NEXT FROM @curCFM1 INTO @cLoadKeyCMF, @cSkuCMF,@cUCCNoCMF, @nQtyCMF, @cLabelNoCMF              
         END              
                     
         --print label            
         IF @cPackData = '1'             
         BEGIN            
            IF @cAutoPrintCartonLabel = '1'            
            BEGIN            
               --auto print carton            
               IF @cCartonManifest <> ''            
               BEGIN            
     
                  SELECT 
                     @cPickSlipNo = pickslipNo, 
                     @nCartonNo = cartonNo 
                  FROM packDetail WITH (NOLOCK) 
                  WHERE storerKey = @cStorerKey 
                  AND LabelNo = @cLabelNo 
                  GROUP BY pickslipNo,cartonNo       
                       
                  -- Common params            
                  DELETE @tCartonManifest            
                  INSERT INTO @tCartonManifest (Variable, Value) VALUES             
                     ( '@cStorerKey',     @cStorerKey),             
                     ( '@cPickSlipNo',    @cPickSlipNo),             
                     ( '@nStartCartonNo', CAST( @nCartonNo AS NVARCHAR(10))),             
                     ( '@nEndCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))            
            
                  -- Print label            
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,             
                     @cCartonManifest, -- Report type            
                     @tCartonManifest, -- Report params            
                     'rdtfnc_SortAndPack_Consignee',             
                     @nErrNo  OUTPUT,            
                     @cErrMsg OUTPUT            
            
                  IF @nErrNo <> 0            
                     GOTO Quit            
            
               END            
            END            
         END            
                     
         -- Prepare next screen var                
         SET @cLoadKey = ''                
         SET @cWaveKey = ''            
         SET @cBatchKey = ''            
         SET @cLabelNo = ''             
         SET @cOutField01 = '' --WaveKey                
         SET @cOutField02 = '' --BatchKey                
         SET @cOutField03 = '' --LabelNo                
                
         -- Go to prev screen                
         SET @nScn  = @nScn - 1                
         SET @nStep = @nStep - 1              
      END  -- if option  =1            
   END  -- IF @nInputKey = 1 -- ENTER              
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
      -- Prepare next screen var                
      --SET @cLoadKey = ''                
      --SET @cWaveKey = ''            
      --SET @cBatchKey = ''            
      --SET @cLabelNo = ''             
      SET @cOutField01 = '' --WaveKey                
      SET @cOutField02 = '' --BatchKey                
      SET @cOutField03 = '' --LabelNo                
                
      -- Go to prev screen                
      SET @nScn  = @nScn - 1                
      SET @nStep = @nStep - 1        
END                
   GOTO Quit                
                
   Step_2_Fail:                
   BEGIN                
      SET @cSKU = ''              
      SET @cUCCNo = ''            
      SET @cLabelNo = ''            
      SET @cOutField02 = '' --SKU                
      SET @cOutField03 = '' --UCC                
   END                
END                
GOTO Quit                
                
                
/********************************************************************************                
Step 3. Label Screen 5862                
   LABELNO  (Field01)                
   LABELNO  (Field02 input)                   
********************************************************************************/                
Step_3:                
BEGIN                
   IF @nInputKey = 1 -- ENTER       
   BEGIN                
                
      -- Screen mapping                
      SET @cLabelNo = @cInField02                
            
      -- Get next task                
      IF @cLabelNo = ''                
      BEGIN                
         SET @cLabelNo =  @cOutField01            
      END            
                  
      IF EXISTS (SELECT 1 FROM rdt.rdtSortAndPackLog WHERE labelNo = @cLabelNo AND STATUS = 9)            
      BEGIN            
         SET @nErrNo = 160478              
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Carton Closed              
         GOTO Step_3_Fail            
      END            
                  
      IF EXISTS (SELECT 1 FROM rdt.rdtSortAndPackLog WHERE storerKey = @cStorerKey AND labelNo = @cLabelNo  AND batchKey = @cBatchKey AND WaveKey = '' AND loadKey <> @cLoadKey)            
      BEGIN            
         SET @nErrNo = 160483            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- InvalidLabelNo              
         GOTO Step_3_Fail            
      END            
                  
      UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET             
         labelNo = @cLabelNo            
      WHERE StorerKey = @cStorerKey             
      AND loadKey = @cLoadKey             
      AND SKU = @cSKU            
      AND STATUS = 0            
                  
      IF @@ERROR <> 0            
      BEGIN            
         SET @nErrNo = 160479                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
         GOTO Step_3_Fail               
      END            
                  
      SELECT 
         @nQty = SUM(Qty) 
      FROM rdt.rdtSortAndPackLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
      AND loadKey = @cLoadKey 
      AND SKU = @cSKU 
      AND WaveKey = '' 
      AND batchKey = @cBatchkey 
      AND STATUS = 0            
                  
      UPDATE rdt.rdtSortAndPackLog WITH (ROWLOCK) SET 
         QTY = @nQty + 1 
      WHERE StorerKey = @cStorerKey 
      AND loadKey = @cLoadKey 
      AND SKU = @cSKU 
      AND WaveKey = '' 
      AND batchKey = @cBatchkey 
      AND LabelNo <> '' 
      AND STATUS = 0     
             
      SELECT 
         @nQtyScan = SUM (qty) 
      FROM rdt.rdtSortAndPackLog 
      WHERE StorerKey = @cStorerKey 
      AND loadKey = @cLoadKey 
      AND WaveKey = '' 
      AND batchKey = @cBatchkey 
      AND sku = @cSKU 
      AND STATUS = 0            
                  
      IF @@ERROR <> 0            
      BEGIN            
         SET @nErrNo = 160480                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
         GOTO Step_3_Fail               
      END            
                  
      --go to SKU screen                
      SET @cOutField01 = '' --SKU/UCC            
      SET @cOutField02 = (CASE WHEN @cLoadKey='' OR @cLoadKey IS NULL THEN '' ELSE LEFT(@cLoadKey,6)+' - '+RIGHT(@cLoadKey,4) END)   -----Modified              
      SET @cOutField03 = @cBatchKey                
      SET @cOutField04 = @cPosition            
      SET @cOutField05 = @cPalletID   --PalletID                  
      SET @cOutField06 = CONVERT(NVARCHAR(5),@nQtyScan) + '/' + CONVERT(NVARCHAR(5),@nLoadQTY)           
      SET @cOutField07 = '' --option            
            
      SET @nScn  = @nScn - 1               
      SET @nStep = @nStep - 1            
                  
      --Close Carton            
      IF @cOption = 1 AND @nFromWave = 0            
      BEGIN             
         DECLARE @curCFMLabel CURSOR              
         SET @curCFMLabel = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
            SELECT loadKey,SKU,UCC,QTY,labelNo            
            FROM rdt.rdtSortAndPackLog WITH (NOLOCK)              
            WHERE StorerKey = @cStorerKey              
               AND QTY > 0              
               AND Status = 0              
               --AND mobile = @nMobile             
               AND labelNo = @cLabelNo            
               AND WaveKey = ''            
            ORDER BY RowRef              
              
         OPEN @curCFMLabel              
         FETCH NEXT FROM @curCFMLabel INTO @cLoadKeyCMF, @cSkuCMF, @cUCCNoCMF, @nQtyCMF, @cLabelNoCMF              
         WHILE @@FETCH_STATUS = 0              
         BEGIN              
            EXEC rdt.rdt_SortAndPackConsignee_Confirm @nMobile, @nFunc, @cLangCode
            ,@cLoadKeyCMF, @cStorerKey, @cSkuCMF, @cUCCNoCMF, @nQtyCMF, @cLabelNoCMF, @cCartonType                 
            ,@nErrNo        OUTPUT                
            ,@cErrMsg       OUTPUT              
            
            IF @nErrNo <> 0                
             GOTO Step_2_Fail              
            
            Update rdt.rdtSortAndPackLog WITH (ROWLOCK) SET             
               status = 9             
            WHERE LoadKey = @cLoadKeyCMF              
               AND StorerKey = @cStorerKey              
               AND QTY > 0              
               AND Status = 0              
               --AND mobile = @nMobile              
               AND SKU = @cSkuCMF            
            
            IF @@ERROR <> 0            
            BEGIN            
               SET @nErrNo = 160477                
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UpdateLogFail                
               GOTO Step_2_Fail               
            END            
            
            FETCH NEXT FROM @curCFMLabel INTO @cLoadKeyCMF, @cSkuCMF,@cUCCNoCMF, @nQtyCMF, @cLabelNoCMF              
         END              
                     
         --print label            
         IF @cPackData = '1'             
         BEGIN            
            IF @cAutoPrintCartonLabel = '1'            
            BEGIN            
               --auto print carton            
               IF @cCartonManifest <> ''            
               BEGIN                       
                  SELECT 
                     @cPickSlipNo = pickslipNo, 
                     @nCartonNo = cartonNo 
                  FROM packDetail WITH (NOLOCK) 
                  WHERE storerKey = @cStorerKey 
                  AND LabelNo = @cLabelNo 
                  GROUP BY pickslipNo,cartonNo     
                         
                  -- Common params            
                  DELETE @tCartonManifest            
                  INSERT INTO @tCartonManifest (Variable, Value) VALUES             
                     ( '@cStorerKey',     @cStorerKey),             
                     ( '@cPickSlipNo',    @cPickSlipNo),             
                     ( '@nStartCartonNo', CAST( @nCartonNo AS NVARCHAR(10))),             
                     ( '@nEndCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))            
            
                  -- Print label            
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,             
                     @cCartonManifest, -- Report type            
                     @tCartonManifest, -- Report params            
                     'rdtfnc_SortAndPack_Consignee',             
                     @nErrNo  OUTPUT,            
                     @cErrMsg OUTPUT            
            
                  IF @nErrNo <> 0            
                     GOTO Quit            
               END            
            END            
         END            
                     
         -- Prepare next screen var                
         SET @cLoadKey = ''                
         SET @cWaveKey = ''            
         SET @cBatchKey = ''            
         SET @cLabelNo = ''             
         SET @cOutField01 = '' --WaveKey              
         SET @cOutField02 = '' --BatchKey                
         SET @cOutField03 = '' --LabelNo                
    
         -- Go to prev screen                
         SET @nScn  = @nScn - 2                
         SET @nStep = @nStep - 2              
      END  -- if option  =1               
   END                
                
   IF @nInputKey = 0 -- ESC                
   BEGIN                
    DELETE rdt.rdtSortAndPackLog  where StorerKey = @cStorerKey AND loadKey = @cLoadKey AND SKU = @cSKU AND WaveKey = '' AND batchKey = @cBatchkey AND LabelNo = ''            
      -- Prepare prev screen var                
      SET @cOutField01 = ''  -- SKU              
      SET @cOutField02 = ''  -- UCC            
      SET @cOutField03 = @cBatchKey  -- BatchKey            
      SET @cOutField04 = ''  -- LoadKey            
      SET @cOutField05 = ''  -- Position            
      SET @cOutField06 = ''  -- PalletID            
      SET @cOutField07 = ''  -- totalQty            
      SET @cOutField08 = ''  -- Option             
            
      -- Reset variable when finish packing the SKU            
      SET @cUCCNo = ''            
      SET @cOrderKey = ''            
      SET @cSKU = ''            
      SET @cUCCNo = ''            
      SET @cLabelNo = ''            
      SET @cWaveKey = ''            
      SET @cPalletID = ''            
      SET @cLoadKey = ''            
      SET @cConsigneeKey = ''            
                
      -- Go to wave screen                
      SET @nScn  = @nScn - 1                
      SET @nStep = @nStep - 1                   
   END                
   GOTO Quit                
                
   Step_3_Fail:                
   BEGIN            
    SET @cOutField02 = ''  -- LabelNo            
      --SET @cUCCNo = ''            
      --SET @cOrderKey = ''            
      --SET @cSKU = ''            
      --SET @cUCCNo = ''            
      --SET @cLabelNo = ''            
      --SET @cBatchkey = ''            
      --SET @cWaveKey = ''            
      --SET @cPalletID = ''            
      --SET @cLoadKey = ''            
      --SET @cConsigneeKey = ''            
   END            
END                
GOTO Quit                
            
/********************************************************************************            
Step 4. Print Screen 5863             
   Option (field01, input)            
********************************************************************************/            
--Step_4:            
--BEGIN            
--   IF @nInputKey = 1 -- ENTER            
--   BEGIN            
--      -- Screen mapping            
--      SET @cOption = @cInField01            
            
--      -- Validate blank            
--   IF @cOption = ''            
--      BEGIN          
--         SET @nErrNo = 160481            
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OptionRequired            
--         GOTO Quit            
--      END            
            
--      -- Validate option            
--      IF @cOption <> '1' AND @cOption <> '2'            
--      BEGIN            
--         SET @nErrNo = 160482            
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option            
--         EXEC rdt.rdtSetFocusField @nMobile, 1  -- Option            
--         SET @cOutField01 = ''            
--         GOTO Quit            
--      END            
            
--      IF @cOption = '1'  -- Yes            
--      BEGIN                
--         -- Carton manifest            
--         IF @cCartonManifest <> ''            
--         BEGIN            
--            -- Common params            
--            DECLARE @tCartonManifest AS VariableTable            
--            INSERT INTO @tCartonManifest (Variable, Value) VALUES             
--         ( '@cStorerKey',     @cStorerKey),             
--               ( '@cPickSlipNo',    @cPickSlipNo)             
--               --( '@cFromDropID',    @cFromDropID),             
--             --( '@cPackDtlDropID', @cPackDtlDropID),             
--               --( '@cLabelNo',       @cLabelNo),             
--               --( '@nCartonNo',      CAST( @nCartonNo AS NVARCHAR(10)))            
            
--            -- Print label            
--            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,             
--               @cCartonManifest, -- Report type            
--               @tCartonManifest, -- Report params            
--               'rdtfnc_Pack',             
--               @nErrNo  OUTPUT,            
--               @cErrMsg OUTPUT            
            
--            IF @nErrNo <> 0            
--               GOTO Quit            
            
--            -- Prepare next screen var                
--            SET @cLoadKey = ''                
--            SET @cOutField01 = '' --LoadKey                
                
--            -- Go to prev screen                
--            SET @nScn  = @nScn - 3                
--       SET @nStep = @nStep - 3            
--         END            
--      END            
--   END            
            
--   IF @nInputKey = 0 -- ESC            
--   BEGIN            
--      -- Prepare next screen var                
--      SET @cLoadKey = ''                
--      SET @cOutField01 = '' --LoadKey                
                
--      -- Go to prev screen                
--      SET @nScn  = @nScn - 3                
--      SET @nStep = @nStep - 3            
                  
            
--   END            
--END            
--GOTO Quit            
            
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
                
      StorerKey  = @cStorerKey,                
      Facility   = @cFacility,                
      Printer_Paper  = @cPaperPrinter,             
      Printer        = @cLabelPrinter,            
                
      V_LoadKey  = @cLoadKey,  ---              
      V_SKU      = @cSKU,                
      V_SKUDescr = @cSKUDescr,                
      V_ConsigneeKey = @cConsigneeKey,                
      V_OrderKey = @cOrderKey,                 
      V_CaseID   = @cLabelNo,                  
      V_Cartonno = @nCartonNo,               
               
      V_Integer1  = @nLoadQTY,            
      V_Integer2  = @nQtyScan,            
      V_Integer3  = @nFromWave,        
      V_Integer4  = @nlogQty,        
      V_Integer5  = @nWaveQTY,            
               
      V_String1  = @cWaveKey,                 
      V_String2  = @cBatchKey,                 
      V_String3  = @cPosition,            
      V_String4  = @cPalletID,            
      V_String5  = @cPackData,            
      V_String6  = @cAutoPrintCartonLabel,                 
      V_String7  = @cCartonManifest,             
      V_String8  = @cPickSlipNo,              
      V_String9  = @cCartonType,             
      V_String10 = @cUCCNo,             
      V_String11 = @cOption,             
     
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
                
      FieldAttr01  = @cFieldAttr01, FieldAttr02  = @cFieldAttr02,                  
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