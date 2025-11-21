SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/          
/*Store procedure: rdtfnc_DTC_Dispatch                                       */          
/*Copyright      : IDS                                                       */          
/*                                                                           */          
/*Purpose: SOS#313692 - EComm Order Despatch                                 */          
/*                                                                           */          
/*Modifications log:                                                         */          
/*                                                                           */          
/*Date       Rev  Author   Purposes                                          */          
/*2014-06-23 1.0  ChewKP   Created                                           */          
/*2014-09-11 1.1  Chee     Bug Fix - Add order type filter (Chee01)          */          
/*2014-09-25 1.2  Chee     Bug Fix - Filter by pickslipno to prevent reuse   */          
/*                         tote issue (Chee02)                               */          
/*2015-01-08 1.3  Leong    SOS# 329265 - Filter PickDetail.Qty = 0           */          
/*                         SOS# 326971 - Do not update PackDetail.Qty = 0    */          
/*                                       at reason scn if pack confirm done. */          
/*2015-03-26 1.4  ChewKP   SOS#336932 - Add WaveKey, LoadKey Input (ChewKP01)*/          
/*2015-04-18 1.5  ChewKP   SOS#338518 - Pop Up Message Screen (ChewKP02)     */          
/*2015-07-23 1.6  ChewKP   SOS#342179 - Include different Orders.Type        */          
/*                                      Various fixes (ChewKP03)             */          
/*2015-08-10 1.7  ChewKP   SOS#349748 - Allow Pickdetail.Status = '3' for    */          
/*                         DTC (ChewKP04)                                    */          
/*2015-08-24 1.8  Ung      SOS350720 Add BackendShipConfirm                  */               
/*2015-09-22 1.9  ChewKP   SOS#352693 - Exclude SOStatus = PENDPACK & HOLD   */          
/*                         Orders (ChewKP05)                                 */          
/*2015-11-05 1.10 ChewKP   SOS#355775 (ChewKP06)                             */          
/*2016-01-20 1.11 ChewKP   SOS#361618 - Fix Reuse Tote Issues (CheWKP08)     */          
/*2016-09-30 1.12 Ung      Performance tuning                                */          
/*2016-10-14 1.13 ChewKP   WMS-510 Add Order Type SS, EX (ChewKP09)          */          
/*2016-11-12 1.14 James    Replace Batch DELETE/UPDATE (james01)             */          
/*                         Bug fix on SKU input                              */          
/*2017-01-06 1.15 James    WMS893 Enlarge SKU input to 60 chars (james02)    */          
/*2017-03-03 1.16 ChewKP   WMS-1240 Add Config OrderWithTrackNo (CheWKP10)   */          
/*2017-11-13 1.17 Ung      Performance tuning                                */          
/*2018-02-08 1.18 James    WMS3967-Check status of SKU (james03)             */          
/*2018-03-16 1.19 James    Fix double bytes display issue (james04)          */          
/*2018-08-22 1.20 SWT01    Performance tuning                                */          
/*2018-09-25 1.21 TungGH   Perfomance tuning. Remove isvalidqty during       */          
/*                         loading rdtmobrec                                 */          
/*2018-10-31 1.22 TungGH   Perfomance tuning. add @nStep = @nStep            */          
/*2018-09-13 1.23 ChewKP   WMS-6213 Add DefaultCursor (chewKP11)             */          
/*2018-11-16 1.25 James    Add check if sku blank (james05)                  */          
/*2018-12-04 1.26 James    WMS-7147 Add custom get orders sp (james06)       */          
/*2019-01-10 1.27 ChewKP   WMS-7607 DTC allow without DropID (ChewKP12)      */        
/*2019-07-25 1.28 James    WMS-9971/9880 Add new order type (james07)   */          
/*2019-10-07 1.29 James    Perfomance tuning (james08)     */          
/*2020-02-24 1.30 James    WMS-11634 Add ExtendedValidateSP for LoadKey/  */        
/*                         WaveKey @ screen 1 (james09)                      */          
/*2020-05-19 1.31 YeeKung  WMS-13131 Add Cartontype Scn (yeekung01)          */           
/*2020-04-06 1.32 James    WMS-12726 Add new order type (james10)            */          
/*2020-04-01 1.33 yeekung    WMS-16778 Add serialno screen (james10)         */            
/*2021-04-19 1.34 James    WMS-16779 Add skip printer req by config (james11)*/          
/*                         Fix ttl qty not refresh after scan tracking no    */        
/*2021-05-25 1.35 James    WMS-17083-Add default ctn type (james12)          */        
/*2021-04-08 1.36 James    WMS-16024 Standarized use of TrackingNo (james13) */        
/*2021-05-27 1.37 James    WMS-17077 Add RefNo lookup (james14)              */        
/*2021-06-04 1.38 James    WMS-17180 Add config to determine whether use     */        
/*                         Udf04 or TrackingNo as system tracking no(james14)*/        
/*2021-07-05 1.39 James    WMS-17437 Add GetOrders_SP at step 1 (james15)    */        
/*2021-07-22 1.40 Chermain WMS-17410 Add Weight in scn7 & Add VariableTable  */        
/*                         table for externalUpdateSP & Add ExtInfo st7(cc01)*/        
/*2022-02-28 1.41 James    Fix for carton type screen not show (james16)     */    
/*                         Fix carton type screen fieldattr not reset        */    
/*2022-06-01 1.42 James    WMS-19811 Add pack info range check (james17)     */  
/*                         Add Refno valid format check                      */  
/*2021-01-27 1.43 YeeKung  WMS-18630 ADd GetOrders_SP at step 1 wavekey      */      
/*                         (yeekung)                                         */   
/*2022-06-07 1.44 James    WMS-19882 Add Std SKU decode sp (james16)         */  
/*2022-06-09 1.45 yeekung WMS-19312 Fix extendedinfo (yeekung03)             */  
/*2022-07-28 1.46 James    WMS-20110 Enhance packinfo screen (james18)       */  
/*2022-10-21 1.47 KuanYee  INC1935847 Recorrect S7 cExtendedValidateSP (KY01)*/     
/*2022-07-26 1.48 yeekung  WMS-20327 supprt two method (yeekung04)           */
/*2022-11-17 1.49 James    WMS-20370 Bug fix (james19)                       */ 
/*2022-10-20 1.50 YeeKung  WMS-21027 Add eventlog (yeekung05)                */ 
/*2022-11-30 1.51 YeeKung  JSM-114083 Fix for nototeflag keep back to step 1 */
/*                                    (yeekung06)                            */
/*2023-03-30 1.52 YeeKung  WMS-22041 Add extendedinfo in ctnscn (yeekung07)  */
/*2023-05-23 1.53 YeeKung  WMS-22408 Add orderkeyout in ctntype (yeekung08)  */
/*2023-07-21 1.54 YeeKung  WMS-22755 Fix the serialno bug fix (yeekung09)    */
/*****************************************************************************/          
CREATE    PROC [RDT].[rdtfnc_DTC_Dispatch](          
   @nMobile    INT,          
   @nErrNo     INT  OUTPUT,          
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max          
) AS          
          
SET NOCOUNT ON          
SET QUOTED_IDENTIFIER OFF          
SET ANSI_NULLS OFF          
SET CONCAT_NULL_YIELDS_NULL OFF          
          
-- Misc variable          
DECLARE          
   @b_success           INT          
          
          
DECLARE @c_NewLineChar NVARCHAR(2)          
SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)          
          
-- Define a variable          
DECLARE          
   @nFunc               INT,          
   @nScn                INT,          
   @nStep               INT,          
   @cLangCode           NVARCHAR(3),          
   @nMenu               INT,          
   @nInputKey           NVARCHAR(3),          
   @cPrinter            NVARCHAR(10),          
   @cPrinter_Paper      NVARCHAR(10),          
   @cUserName           NVARCHAR(18),          
          
   @cStorerKey          NVARCHAR(15),          
   @cFacility           NVARCHAR(5),          
          
   @cOrderkey           NVARCHAR(10),          
   @cSingles            NVARCHAR(10),          
   @cMultis             NVARCHAR(10),          
   @cToteNo             NVARCHAR(20),          
   @cDropIDType         NVARCHAR(10),          
   @cSku                NVARCHAR(20),          
   @cReasonCode         NVARCHAR(10),          
   @cRSN_Descr          NVARCHAR(60),      
   @cModuleName         NVARCHAR(45),          
   @cAlertMessage       NVARCHAR(250),          
   @cWCSKey             NVARCHAR(10),          
   @cOption             NVARCHAR(1),          
   @nToteCnt            int,          
   @cOtherTote          NVARCHAR(18),          
   @cUnPickOrderkey     NVARCHAR(10),    
   @nOrderCount         INT,          
   @nSUM_PackQTY        INT,          
   @nSUM_PickQTY        INT,          
   @nSKU_Picked_TTL     INT,          
   @nSKU_Packed_TTL     INT,          
   @cPickSlipNo         NVARCHAR(10),          
   @nPrevScn            INT,          
   @nPrevStep           INT,          
   @cSQL                NVARCHAR(1000),          
   @cSQLParam           NVARCHAR(1000),          
   @cExtendedValidateSP NVARCHAR(30),          
   @cExtendedUpdateSP   NVARCHAR(30),          
   @cInSku              NVARCHAR(20),          
   @cDecodeLabelNo      NVARCHAR(20),          
   @nSKUCnt             INT,          
   @nQty                INT,          
   @cShowTrackNoScn     NVARCHAR(1),          
   @cTrackNo            NVARCHAR(20),          
   @cShipperKey         NVARCHAR(15),          
   @cOrderTrackNo       NVARCHAR(20),          
   @cTrackRegExp        NVARCHAR(255),          
   @cNextOrderKey       NVARCHAR(10),          
   @cDefaultTrackNo     NVARCHAR(1),          
   @cSuggestedTrackNo   NVARCHAR(20),          
   @cTrackNoFlag        NVARCHAR(1),          
   @cOrderKeyOut        NVARCHAR(10),          
   @nTotalPickedQty     INT,          
   @nTotalScannedQty    INT,          
   @cLoaDKey            NVARCHAR(10),          
   @cWaveKey            NVARCHAR(10), -- (ChewKP01)           
   @cNoToteFlag         NVARCHAR(1),  -- (ChewKP01)           
   @nRefCount           INT,          -- (ChewKP01)          
   @cCartonType         NVARCHAR(20), --(yeekung01)           
   @cScanCTSCN          NVARCHAR(5), --(yeekung01)                         
   @cCartongroup        NVARCHAR(10),  --(yeekung01)                    
   @cPickStatus         NVARCHAR(1),   --(yeekung01)                    
   @cExtendedinfoSP     NVARCHAR(20),   --(yeekung01)                  
   @cExtendedinfo       NVARCHAR(20),   --(yeekung01)    
   @cMultiMethod        NVARCHAR(20),  
             
   @cErrMsg1            CHAR( 20), -- (ChewKP02)           
   @cErrMsg2            CHAR( 20), -- (ChewKP02)           
   @cErrMsg3            CHAR( 20), -- (ChewKP02)           
   @cErrMsg4            CHAR( 20), -- (ChewKP02)           
   @cErrMsg5            CHAR( 20), -- (ChewKP02)           
   @cGenPackDetail      NVARCHAR(1),          
   @cBackendPickConfirm NVARCHAR(1),               
   @cDropIDStatus       NVARCHAR(5), -- (CKPCheck)                
   @nRowRef             INT,          
   @cBarcode            NVARCHAR( 60),          
   @cOrderWithTrackNo   NVARCHAR(1) , -- (ChewKP10)           
   @cSKUStatus          NVARCHAR(10) , -- (james03)           
   @cDefaultCursor      NVARCHAR(1),          
   @cGetOrders_SP       NVARCHAR(20),          
   @cNotCheckDropIDTable NVARCHAR(1), -- (ChewKP12)           
   @cEcomSingleFlag      NVARCHAR(1), -- (ChewKP12)          
   @cPaperPrinterNotReq  NVARCHAR(1), -- (james11)        
   @cLabelPrinterNotReq  NVARCHAR(1), -- (james11)        
   @cLastOrderKey        NVARCHAR( 10),        
   @cDefaultCtnType      NVARCHAR( 10),   -- (james12)        
   @cSerialNo           NVARCHAR( 30),       -- ( yeekung02)          
   @cSerialNoCapture    NVARCHAR( 1),        -- ( yeekung02)          
   @nSerialQTY          INT,                 -- ( yeekung01)          
   @nMoreSNO            INT,               
   @nBulkSNO            INT,               
   @nBulkSNOQTY         INT,          
   @cSKUDesc            NVARCHAR(20),           
   @cUseUdf04AsTrackNo  NVARCHAR(1),   -- (james14)        
   @cCube               NVARCHAR( 10),  --(cc01)        
   @cWeight             NVARCHAR( 10),  --(cc01)        
   @cRefNo              NVARCHAR( 20),  --(cc01)        
   @cRefNoLookupSP      NVARCHAR( 20),   -- (james14)       
   @cRefNoInsLogSP      NVARCHAR( 20),   -- (james14)      
   @tExtUpd             VariableTable,  --(cc01)        
   @cAllowWeightZero    NVARCHAR( 1),   --(cc01)         
   @cAllowCubeZero      NVARCHAR( 1),   --(cc01)        
   @cDecodeSP           NVARCHAR( 20),    
   @cUPC                NVARCHAR( 30),  
     
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
          
   SET @cSingles     = 'SINGLES'          
   SET @cMultis      = 'MULTIS'          
   SET @cToteNo      = ''          
   SET @cDropIDType  = ''          
          
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
   @cPickslipNo      = V_PickSlipNo ,          
   @cOrderKey        = V_OrderKey,          
   @cLoadKey         = V_LoadKey,          
          
   @cToteno             = V_String1,      
   @cDropIDType         = V_String2,          
   @cDefaultCtnType     = V_String3,        
   @cSku                = V_String4,          
   @cPaperPrinterNotReq = V_String5,        
   @cLabelPrinterNotReq = V_String6,        
   @cDecodeLabelNo      = V_String7,          
   @cExtendedValidateSP = V_String8,          
   @cExtendedUpdateSP   = V_String9,          
   @cShowTrackNoScn     = V_String10,          
   @cNextOrderKey       = V_String11,          
   @cDefaultTrackNo     = V_String12,          
   @cUseUdf04AsTrackNo  = V_String13,   -- (james14)        
   @cWaveKey            = V_String15, -- (ChewKP01)           
   @cNoToteFlag         = V_String16, -- (ChewKP01)           
   @cGenPackDetail      = V_String17,           
   @cBackendPickConfirm = V_String18,             
   @cOrderWithTrackNo   = V_String19, -- (ChewKP10)           
   @cSKUStatus          = V_String20, -- (james03)           
   @cDefaultCursor      = V_String21,           
   @cGetOrders_SP       = V_String22,           
   @cNotCheckDropIDTable = V_String23,           
   @cCartonType         = V_String24,             
   @cScanCTSCN          = V_String25,                        
   @cCartongroup        = V_String26,                    
   @cPickStatus         = V_string27, --(yeekung01)       
   @cExtendedinfoSP     = V_string28, --(yeekung01)                
   @cExtendedinfo       = V_string29, --(yeekung01)           
   @cSerialNoCapture    = V_String30, --(yeekung02)             
   @cCube               = V_String31,  --(cc01)        
   @cWeight             = V_String32,  --(cc01)        
   @cRefNo              = V_String33,  --(cc01)        
   @cRefNoInsLogSP      = V_String34,      
   @cDecodeSP           = V_String35,  
   @cMultiMethod        = V_String36, --(yeekung03)  
     
   @nPrevScn         = V_FromScn,          
   @nPrevStep        = V_FromStep,          
   @nTotalPickedQty  = V_Integer1,          
   @nTotalScannedQty = V_Integer2,          
             
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
IF @nFunc = 841          
BEGIN          
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 814          
   IF @nStep = 1 GOTO Step_1   -- Scn = 3910  ToteNo          
   IF @nStep = 2 GOTO Step_2 -- Scn = 3911  Singles/Doubles Order Sku          
   --IF @nStep = 3 GOTO Step_3   -- Scn = 3912  Multis Order SKU          
   IF @nStep = 3 GOTO Step_3   -- Scn = 3912  ReasonCode          
   IF @nStep = 4 GOTO Step_4   -- Scn = 3913  Multi ToteNo          
   IF @nStep = 5 GOTO Step_5   -- Scn = 3914  Park Tote          
   IF @nStep = 6 GOTO Step_6   -- Scn = 3915  Scan Track No          
   IF @nStep = 7 GOTO Step_7   -- Scn = 3916  Scan CartonType         
   IF @nStep = 8 GOTO Step_8  -- Scn = 4830. Serial no           
END          
          
RETURN -- Do nothing if incorrect step          
          
/********************************************************************************          
Step 0. Called from menu (func = 841)          
********************************************************************************/          
Step_0:          
BEGIN          
   -- Set the entry point          
   SET @nScn  = 3910          
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
          
          
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)          
   IF @cExtendedUpdateSP = '0'          
   BEGIN          
      SET @cExtendedUpdateSP = ''          
   END          
  
             
   SET @cMultiMethod = rdt.RDTGetConfig( @nFunc, 'MultiMethod', @cStorerKey)          
   IF @cMultiMethod = '0'          
   BEGIN          
      SET @cMultiMethod = ''          
   END          
             
   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)          
   IF @cDefaultCursor = '0'          
   BEGIN          
      SET @cDefaultCursor = ''          
   END          
                          
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)                          
   IF @cExtendedValidateSP = '0'                          
   BEGIN                          
      SET @cExtendedValidateSP = ''                          
   END           
             
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)                    
   IF @cExtendedInfoSP = '0'                    
      SET @cExtendedInfoSP = ''     
        
   SET @cExtendedInfo = ''  
                          
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)                          
   IF @cDecodeLabelNo = '0'                          
      SET @cDecodeLabelNo = ''                     
                     
   SET @cPickStatus = rdt.RDTGetConfig( @nFunc, 'PickStatus', @cStorerKey)        --(yeekung01)                  
   IF @cPickStatus = '0'                          
   BEGIN                          
      SET @cPickStatus = '0'                          
   END           
           
   SET @cShowTrackNoScn = rdt.RDTGetConfig( @nFunc, 'ShowTrackNoScn', @cStorerKey)          
          
   SET @cDefaultTrackNo = ''          
   SET @cDefaultTrackNo = rdt.RDTGetConfig( @nFunc, 'DefaultTrackNo', @cStorerkey)          
          
   SET @cGenPackDetail  = ''          
   SET @cGenPackDetail = rdt.RDTGetConfig( @nFunc, 'GenPackDetail', @cStorerkey)            
             
   -- (ChewKP10)           
   SET @cOrderWithTrackNo  = ''          
   SET @cOrderWithTrackNo = rdt.RDTGetConfig( @nFunc, 'OrderWithTrackNo', @cStorerkey)            
             
   -- (james03)          
   SET @cSKUStatus  = ''          
   SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)            
   IF @cSKUStatus = '0'          
     SET @cSKUStatus = ''          
          
   SET @cGetOrders_SP = rdt.RDTGetConfig( @nFunc, 'GetOrders_SP', @cStorerkey)            
   IF @cGetOrders_SP = '0'          
      SET @cGetOrders_SP = ''          
          
   -- (ChewKP12)           
   SET @cNotCheckDropIDTable = rdt.RDTGetConfig( @nFunc, 'NotCheckDropIDTable', @cStorerkey)            
   IF @cNotCheckDropIDTable = '0'          
      SET @cNotCheckDropIDTable = ''            
        
   -- (yeekung01)                           
   SET @cScanCTSCN = rdt.RDTGetConfig( @nFunc, 'ScanCartonType', @cStorerkey)                            
   IF @cScanCTSCN = '0'                          
      SET @cScanCTSCN = ''          
                     
   IF @cScanCTSCN = '1' --(cc01)        
      SET @cScanCTSCN = 'T'        
                          
       -- (yeekung01)                           
   SET @cCartongroup = rdt.RDTGetConfig( @nFunc, 'Cartongroup', @cStorerkey)                            
   IF @cCartongroup = '0'                          
      SET @cCartongroup = ''                   
        
   -- (james11)        
   SET @cPaperPrinterNotReq = rdt.RDTGetConfig( @nFunc, 'PaperPrinterNotReq', @cStorerkey)        
   SET @cLabelPrinterNotReq = rdt.RDTGetConfig( @nFunc, 'LabelPrinterNotReq', @cStorerkey)        
        
   -- (james12)        
   SET @cDefaultCtnType = rdt.RDTGetConfig( @nFunc, 'DefaultCtnType', @cStorerkey)        
   IF @cDefaultCtnType = '0'                          
      SET @cDefaultCtnType = ''                   
  
   -- (james14)      
   SET @cRefNoInsLogSP = rdt.RDTGetConfig( @nFunc, 'RefNoInsLogSP', @cStorerkey)      
   IF @cRefNoInsLogSP = '0'                      
      SET @cRefNoInsLogSP = ''          
  
   --(yeekung02)          
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)            
        
   --(james14)        
   SET @cUseUdf04AsTrackNo = rdt.RDTGetConfig( @nFunc, 'UseUdf04AsTrackNo', @cStorerKey)        
  
   -- (james16)    
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)    
   IF @cDecodeSP = '0'    
      SET @cDecodeSP = ''    
        
   SET @b_success = 0                
   EXECUTE nspGetRight                
      @cFacility,                
      @cStorerKey,                
      NULL, -- @cSKU                
      'BackendPickConfirm',                
      @b_success   OUTPUT,                
      @cBackendPickConfirm OUTPUT,                
      @nErrNo      OUTPUT,                
      @cErrMsg     OUTPUT            
                
   IF @cDefaultCursor <> ''                
      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor          
                
   --initialise all variables          
   SET @cToteNo      = ''          
   SET @cDropIDType  = ''          
   SET @cOrderkey    = ''          
   SET @cSku         = ''          
   SET @cReasonCode  = ''          
   SET @cRSN_Descr   = ''          
   SET @cModuleName  = ''          
   SET @cAlertMessage = ''          
   SET @cWCSKey      = ''          
   SET @cOption      = ''          
   SET @nToteCnt     = 0          
   SET @cOtherTote   = ''          
   SET @cPickslipNo  = ''          
   --SET @cDecodeLabelNo = '' (james02)          
   SET @nTotalScannedQty   = 0          
   SET @nTotalPickedQty    = 0          
          
   -- Prep next screen var          
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
          
/********************************************************************************          
Step 1. screen = 3910          
   TOTE NO:          
   DROPID  (Field01, input)          
********************************************************************************/          
Step_1:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cToteno  = @cInField01          
      SET @cWaveKey = @cInField02          
      SET @cLoadKey = @cInField03          
      SET @cRefno   = @cInField04   
                
      /****************************          
       VALIDATION          
      ****************************/          
      -- Check Printer ID          
      IF ISNULL(@cPrinter, '') = ''          
      BEGIN          
         IF @cLabelPrinterNotReq <> '1'        
         BEGIN        
            SET @nErrNo = 90451          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Printer ID req          
            GOTO Step_1_Fail        
         END          
      END          
          
      -- Start          
      IF ISNULL(@cPrinter_Paper, '') = ''          
      BEGIN          
         IF @cPaperPrinterNotReq <> '1'        
         BEGIN        
            SET @nErrNo = 90452          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPaperPrinter          
            GOTO Step_1_Fail          
         END        
      END          
      -- End          
  
      -- (james14)         
      -- Lookup ref no           
      IF @cRefNo <> ''            
      BEGIN              
         SET @cRefNoLookupSP = rdt.RDTGetConfig( @nFunc, 'RefNoLookupSP', @cStorerkey)                                  
         IF @cRefNoLookupSP = '0'                                 
            SET @cRefNoLookupSP = ''                        
            -- Custom get orderkey sp. Can do swap lot inside the sp and insert ecommlog                
         IF @cRefNoLookupSP <> '' AND EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = @cRefNoLookupSP AND type = 'P')     
         BEGIN                   
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cRefNoLookupSP) +                      
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cRefNo,                          
            @cToteNo OUTPUT, @cWaveKey OUTPUT, @cLoadKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '                   
            SET @cSQLParam =                      
            '@nMobile                     INT,           ' +                    
            '@nFunc                       INT,           ' +                    
            '@cLangCode                   NVARCHAR( 3),  ' +                 
            '@nStep                       INT,           ' +                    
            '@nInputKey                   INT,           ' +                    
            '@cStorerkey                  NVARCHAR( 15), ' +                    
            '@cRefNo                      NVARCHAR( 20), ' +                    
            '@cToteNo                     NVARCHAR( 20) OUTPUT,     ' +                    
            '@cWaveKey                    NVARCHAR( 10) OUTPUT,     ' +                    
            '@cLoadKey                    NVARCHAR( 10) OUTPUT,     ' +                    
            '@nErrNo                      INT           OUTPUT,     ' +             
            '@cErrMsg                     NVARCHAR( 20) OUTPUT      '                  
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                      
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cRefNo,                        
            @cToteNo OUTPUT, @cWaveKey OUTPUT, @cLoadKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT                    
            IF @nErrNo <> 0                 
            BEGIN                    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')                     
               GOTO Step_1_Fail                 
            END           
         END             
      END      
  
      -- (ChewKP01)           
      IF ISNULL(RTRIM(@cWavekey),'')  <> '' OR ISNULL(RTRIM(@cLoadKey),'')  <> ''           
      BEGIN           
         SET @nTotalPickedQty = 0           
         SET @nTotalScannedQty = 0           
          
          
         IF ISNULL(RTRIM(@cWavekey),'')  <> ''          
         BEGIN          
            IF NOT EXISTS ( SELECT 1 FROM dbo.Wave WITH (NOLOCK)          
                              WHERE WaveKey = @cWavekey )           
            BEGIN          
               SET @nErrNo = 90484          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidWaveKey          
               GOTO Step_1_Fail          
            END          
          
            --SELECT @nTotalPickedQty = Count(WD.OrderKey)           
            -- Performance Tuning (SWT01)                 
            SELECT @nTotalPickedQty  = SUM(1),          
                     @nTotalScannedQty = SUM(CASE WHEN O.[Status] = '5' THEN 1 ELSE 0 END)          
            FROM dbo.WaveDetail WD WITH (NOLOCK)          
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = WD.OrderKey          
            WHERE WD.WaveKey = @cWaveKey          
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
                         
               -- SWT01 Combine this count to above...          
               --SELECT @nTotalScannedQty = Count(OrderKey)          
               --FROM dbo.Orders WITH (NOLOCK)           
               --WHERE UserDefine09 = @cWaveKey          
               --AND Status = '5'          
               --AND SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)                  
                         
         END          
                      
         IF ISNULL(RTRIM(@cLoadKey),'')  <> ''          
         BEGIN          
            IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK)          
                              WHERE LoadKey = @cLoadKey )           
            BEGIN          
               SET @nErrNo = 90485          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidLoadKey          
               GOTO Step_1_Fail          
            END          
          
            --SELECT @nTotalPickedQty = Count(LD.OrderKey)           
            --SWT01          
            SELECT @nTotalPickedQty  = SUM(1),          
                     @nTotalScannedQty = SUM(CASE WHEN O.[Status] = '5' THEN 1 ELSE 0 END)                         
            FROM dbo.Orders O WITH (NOLOCK)           
            WHERE O.LoadKey = @cLoadKey          
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
          
            -- SWT01 Combine this count to above...          
            --SELECT @nTotalScannedQty = Count(OrderKey)          
            --FROM dbo.Orders WITH (NOLOCK)           
            --WHERE LoadKey = @cLoadKey          
            --AND Status = '5'          
            --AND SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
          
         END          
        
         -- (james09)        
         IF @cExtendedValidateSP <> ''          
         BEGIN          
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')          
            BEGIN          
          
               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +          
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo, @cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '          
               SET @cSQLParam =          
          '@nMobile        INT, ' +          
                  '@nFunc          INT, ' +          
                  '@cLangCode      NVARCHAR( 3),  ' +          
                  '@nStep          INT, ' +          
                  '@cStorerKey     NVARCHAR( 15), ' +          
                  '@cToteno        NVARCHAR( 20), ' +          
                  '@cSKU           NVARCHAR( 20), ' +          
                  '@cPickSlipNo    NVARCHAR( 10), ' +          
                  '@cSerialNo      NVARCHAR( 30), ' +          
                  '@nSerialQTY     INT,           ' +              
                  '@nErrNo         INT           OUTPUT, ' +          
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'          
          
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo, @cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT          
          
               IF @nErrNo <> 0          
                  GOTO Step_1_Fail          
            END          
         END          
            
         -- Custom get orderkey sp. Can do swap lot inside the sp and insert ecommlog        
         IF @cGetOrders_SP <> ''        
            AND EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetOrders_SP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetOrders_SP) +        
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cToteno,         
            @cWaveKey, @cLoadKey, @cSKU, @cPickSlipNo, @cTrackNo, @cDropIDType, @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
            '@nMobile        INT, ' +        
            '@nFunc          INT, ' +        
            '@cLangCode      NVARCHAR( 3),  ' +        
            '@nStep          INT, ' +        
            '@nInputKey      INT, ' +        
            '@cUserName      NVARCHAR( 18), ' +        
            '@cFacility      NVARCHAR( 5), ' +        
            '@cStorerKey     NVARCHAR( 15), ' +        
            '@cToteno        NVARCHAR( 20), ' +        
            '@cWaveKey       NVARCHAR( 10), ' +        
            '@cLoadKey       NVARCHAR( 10), ' +        
            '@cSKU           NVARCHAR( 20), ' +        
            '@cPickSlipNo    NVARCHAR( 10), ' +        
            '@cTrackNo       NVARCHAR( 20), ' +        
            '@cDropIDType    NVARCHAR( 10),  ' +       
            '@cOrderkey      NVARCHAR( 10) OUTPUT, ' +        
            '@nErrNo         INT           OUTPUT, ' +        
            '@cErrMsg        NVARCHAR( 20) OUTPUT'        
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cToteno,         
            @cWaveKey, @cLoadKey, @cSKU, @cPickSlipNo, @cTrackNo, @cDropIDType, @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT        
  
            IF @nErrNo <> 0        
            BEGIN        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')       
               GOTO Step_1_Fail        
            END        
         END        
         SET @cNoToteFlag = '1'          
                      
         SET @cOutField02 = ''          
         SET @cOutField03 = ''             
         SET @cOutField04 = ''          
          
         SET @cOutField05 = @nTotalPickedQty          
         SET @cOutField06 = @nTotalScannedQty          
                
         SET @nScn = @nScn + 1          
         SET @nStep = @nStep + 1          
          
         GOTO QUIT           
          
      END          
                
      SET @cNoToteFlag = ''          
          
      --When ToteNo is blank          
      IF @cToteno = ''          
      BEGIN          
         SET @nErrNo = 90453          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote req          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Step_1_Fail          
      END          
          
      -- when tote does not exist in dropid          
      -- (ChewKP12)          
                
          
      IF @cNotCheckDropIDTable = '1'          
      BEGIN          
         SET @cPickSlipNo = ''           
          
         SELECT TOP 1 @cLoadKey = O.LoadKey           
                     ,@cEcomSingleFlag = O.ECOM_SINGLE_Flag          
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey          
         INNER JOIN dbo.LoadPlanDetail LD WITH (NOLOCK) ON LD.OrderKey = O.OrderKey           
         WHERE PD.Storerkey = @cStorerkey          
         AND ISNULL(O.ECOM_SINGLE_Flag,'') <> ''           
         AND PD.Qty > 0          
         AND PD.DropID = @cToteNo          
         AND PD.CaseID = ''          
         AND (PD.Status IN ( '3', '5' ) OR PD.ShipFlag = 'P')          
         ORDER BY PD.Editdate Desc          
                   
         IF @cEcomSingleFlag = 'S'          
            SET @cDropIDType = 'SINGLES'          
         ELSE          
            SET @cDropIDType = 'MULTIS'          
                   
                   
         IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
                 INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey          
                 INNER JOIN dbo.LoadPlanDetail LD WITH (NOLOCK) ON LD.OrderKey = O.OrderKey           
                 WHERE PD.Storerkey = @cStorerkey          
                    AND PD.DropID = @cToteno          
                    --AND PD.Status IN ('3', '4') -- (ChewKP04)           
                    AND PD.Status = '4' -- (ChewKP04)           
                    AND PD.QTY > 0          
                    --AND PH.PickHeaderKey = @cPickSlipNo          
                    AND LD.LoadKey = @cLoadKey          
                    AND PD.CaseID = ''  )          
         BEGIN          
            SET @nErrNo = 90491          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShortPickFound          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Step_1_Fail          
         END          
          
         -- check any item on tote not picked or any picks exists for this tote          
         IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
                    INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey          
                    INNER JOIN dbo.LoadPlanDetail LD WITH (NOLOCK) ON LD.OrderKey = O.OrderKey           
                    WHERE PD.Storerkey = @cStorerkey          
                    AND PD.Qty > 0          
                    AND PD.DropID = @cToteNo          
                    --AND PH.PickHeaderKey = @cPickSlipNo          
                    AND LD.LoadKey = @cLoadKey          
                    AND PD.CaseID = ''          
                    --AND PD.Status = '5'   ) -- (ChewKP04)           
                    AND (PD.Status IN ( '3', '5' ) OR PD.ShipFlag = 'P')) -- (ChewKP04)              
         BEGIN          
            SET @nErrNo = 90492          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Step_1_Fail          
         END          
      END           
      ELSE          
      BEGIN          
         IF NOT EXISTS (SELECT 1 FROM dbo.DROPID DROPID WITH (NOLOCK) WHERE DROPID.DropID = @cToteno          
                        AND Status < '9')          
         BEGIN          
            SET @nErrNo = 90454          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote not exists          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Step_1_Fail          
         END          
                   
         SELECT   @cPickSlipNo = PickSlipNo          
                , @cDropIDType = DropIDType          
                , @cLoadKey    = LoadKey          
         FROM dbo.DropID WITH (NOLOCK)          
         WHERE DropID = @cToteNo          
         AND Status = '5'          
          
         IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
                 INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
                 INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
                 WHERE PD.Storerkey = @cStorerkey          
                    AND PD.DropID = @cToteno          
       --AND PD.Status IN ('3', '4') -- (ChewKP04)           
                    AND PD.Status = '4' -- (ChewKP04)           
                    AND PD.QTY > 0          
                    --AND PH.PickHeaderKey = @cPickSlipNo          
                    AND O.LoadKey = @cLoadKey          
                    AND PD.CaseID = ''  )          
         BEGIN          
            SET @nErrNo = 90455          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ShortPickFound          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Step_1_Fail          
         END          
          
         -- check any item on tote not picked or any picks exists for this tote          
         IF NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
                    INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
                    INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
                    WHERE PD.Storerkey = @cStorerkey          
                    AND PD.Qty > 0          
                    AND PD.DropID = @cToteNo          
                    --AND PH.PickHeaderKey = @cPickSlipNo          
                    AND O.LoadKey = @cLoadKey          
                    AND PD.CaseID = ''          
                    --AND PD.Status = '5'   ) -- (ChewKP04)           
                  AND (PD.Status IN ( '3', '5' ) OR PD.ShipFlag = 'P')) -- (ChewKP04)              
         BEGIN          
            SET @nErrNo = 90456          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Picked          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Step_1_Fail          
         END          
      END          
             
               
                
      -- (ChewKP05)          
--      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
--                 INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
--                 INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
--                 WHERE PD.Storerkey = @cStorerkey          
--                    AND PD.DropID = @cToteno          
--                    AND PD.Status IN ( '3', '5' )  -- (ChewKP04)           
--                    AND PD.QTY > 0          
--                    AND O.LoadKey = @cLoadKey          
--                    AND PD.CaseID = ''          
--                    AND O.SOStatus = 'PENDCANC' )           
--      BEGIN          
--         SET @nErrNo = 90488          
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdPENDCANC          
--         EXEC rdt.rdtSetFocusField @nMobile, 1          
--         GOTO Step_1_Fail          
--      END          
--                
--      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
--                 INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
--                 INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
--                 WHERE PD.Storerkey = @cStorerkey          
--                    AND PD.DropID = @cToteno          
--                    AND PD.Status IN ( '3', '5' )  -- (ChewKP04)           
--                    AND PD.QTY > 0          
--                    AND O.LoadKey = @cLoadKey          
--                    AND PD.CaseID = ''          
--                    AND O.SOStatus = 'PENDPACK' )           
--      BEGIN          
--         SET @nErrNo = 90489          
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdPENDPACK          
--         EXEC rdt.rdtSetFocusField @nMobile, 1          
--         GOTO Step_1_Fail          
--      END          
--                
--      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)          
--                 INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
--                 INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
--                 WHERE PD.Storerkey = @cStorerkey          
--                    AND PD.DropID = @cToteno          
--                    AND PD.Status IN ( '3', '5' )  -- (ChewKP04)           
--                    AND PD.QTY > 0          
--                    AND O.LoadKey = @cLoadKey          
--                    AND PD.CaseID = ''          
--                    AND O.SOStatus = 'HOLD' )          
--      BEGIN          
--         SET @nErrNo = 90490          
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdHOLD          
--         EXEC rdt.rdtSetFocusField @nMobile, 1          
--         GOTO Step_1_Fail          
--      END        
          
      IF @cExtendedValidateSP <> ''            
      BEGIN            
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')            
         BEGIN            
            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +            
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo, @cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '            
            SET @cSQLParam =            
               '@nMobile        INT, ' +            
               '@nFunc          INT, ' +            
               '@cLangCode      NVARCHAR( 3),  ' +            
               '@nStep          INT, ' +            
               '@cStorerKey     NVARCHAR( 15), ' +            
               '@cToteno        NVARCHAR( 20), ' +            
               '@cSKU           NVARCHAR( 20), ' +            
               '@cPickSlipNo    NVARCHAR( 10), ' +          
               '@cSerialNo    NVARCHAR( 30)  OUTPUT,'+           
               '@nSerialQTY   INT            OUTPUT,'+             
               '@nErrNo         INT           OUTPUT, ' +            
               '@cErrMsg        NVARCHAR( 20) OUTPUT'            
            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,            
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo, @cSerialNo, @nSerialQTY,@nErrNo OUTPUT, @cErrMsg OUTPUT            
            
            IF @nErrNo <> 0            
            BEGIN            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnNotFrSameLoad            
               GOTO Step_1_Fail            
            END            
            
         END            
      END            
          
      DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
      SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)           
      WHERE ToteNo = @cToteno           
      AND   Status = '9'          
      OPEN CUR_DEL          
      FETCH NEXT FROM CUR_DEL INTO @nRowRef    
      WHILE @@FETCH_STATUS <> -1          
      BEGIN          
         DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef          
         FETCH NEXT FROM CUR_DEL INTO @nRowRef          
      END          
      CLOSE CUR_DEL          
      DEALLOCATE CUR_DEL          
          
      --DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE ToteNo = @cToteno AND Status = '9'          
          
      /****************************          
       Calculate # of Totes          
      ****************************/          
      SET @nToteCnt = 1          
      SET @cOutField01 = ''          
      SET @cOutField02 = ''          
      SET @cOutField03 = ''          
      SET @cOutField04 = ''          
      SET @cOutField05 = ''          
      SET @cOutField06 = ''          
          
      -- retrieve other totes          
      IF @cDropIDType = @cMultis          
      BEGIN          
         DECLARE CUR_TOTE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR          
         SELECT DISTINCT ISNULL(RTRIM(PK1.DROPID),'')          
         FROM  dbo.PICKDETAIL PK1 WITH (NOLOCK)          
         INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PK1.OrderKey          
         WHERE PK1.StorerKey = @cStorerKey          
         AND   PH.PickHeaderKey = @cPickSlipNo          
         AND   PK1.CaseID = ''          
         --AND   PK1.Status = '5' -- (ChewKP04)          
         AND   (PK1.Status IN ( '3',  '5') OR PK1.ShipFlag = 'P') -- (ChewKP04)                  
         ORDER BY ISNULL(RTRIM(PK1.DROPID),'')          
          
         OPEN CUR_TOTE          
         FETCH NEXT FROM CUR_TOTE INTO @cOtherTote          
         WHILE @@FETCH_STATUS <> -1          
         BEGIN          
            IF @cOtherTote = ''          
            BEGIN          
               SET @cOtherTote = 'PICK NOT START'          
            END          
          
            IF @nToteCnt = 1 SET @cOutField01 = @cOtherTote          
            IF @nToteCnt = 2 SET @cOutField02 = @cOtherTote          
            IF @nToteCnt = 3 SET @cOutField03 = @cOtherTote          
            IF @nToteCnt = 4 SET @cOutField04 = @cOtherTote          
            IF @nToteCnt = 5 SET @cOutField05 = @cOtherTote          
            IF @nToteCnt = 6 SET @cOutField06 = @cOtherTote          
          
            SET @nToteCnt = @nToteCnt + 1          
            FETCH NEXT FROM CUR_TOTE INTO @cOtherTote          
         END          
         CLOSE CUR_TOTE          
         DEALLOCATE CUR_TOTE          
          
     
--         IF ISNULL(RTRIM(@cOutField01),'') <> '' OR ISNULL(RTRIM(@cOutField02),'') <> ''          
--         OR ISNULL(RTRIM(@cOutField03),'') <> '' OR ISNULL(RTRIM(@cOutField04),'') <> ''          
--         OR ISNULL(RTRIM(@cOutField05),'') <> '' OR ISNULL(RTRIM(@cOutField06),'') <> ''          
--         BEGIN          
--      GOTO PARK_TOTE          
--         END          
         IF @nToteCnt > 2          
         BEGIN          
            GOTO PARK_TOTE          
         END          
      END          
          
      /****************************          
       INSERT INTO rdtECOMMLog          
      ****************************/          
      -- (james15)      
      -- Custom get orderkey sp. Can do swap lot inside the sp and insert ecommlog        
      IF @cGetOrders_SP <> ''        
         AND EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetOrders_SP AND type = 'P')        
      BEGIN        
         SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetOrders_SP) +        
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cToteno,         
              @cWaveKey, @cLoadKey, @cSKU, @cPickSlipNo, @cTrackNo, @cDropIDType, @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
         SET @cSQLParam =        
            '@nMobile        INT, ' +        
            '@nFunc          INT, ' +        
            '@cLangCode      NVARCHAR( 3),  ' +        
            '@nStep          INT, ' +        
            '@nInputKey      INT, ' +        
            '@cUserName      NVARCHAR( 18), ' +        
            '@cFacility      NVARCHAR( 5), ' +        
            '@cStorerKey     NVARCHAR( 15), ' +        
            '@cToteno        NVARCHAR( 20), ' +        
            '@cWaveKey       NVARCHAR( 10), ' +        
            '@cLoadKey       NVARCHAR( 10), ' +        
            '@cSKU           NVARCHAR( 20), ' +        
            '@cPickSlipNo    NVARCHAR( 10), ' +        
            '@cTrackNo       NVARCHAR( 20), ' +        
            '@cDropIDType    NVARCHAR( 10),  ' +       
            '@cOrderkey      NVARCHAR( 10) OUTPUT, ' +        
            '@nErrNo         INT           OUTPUT, ' +                    
            '@cErrMsg        NVARCHAR( 20) OUTPUT'        
      
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cToteno,         
            @cWaveKey, @cLoadKey, @cSKU, @cPickSlipNo, @cTrackNo, @cDropIDType, @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
         IF @nErrNo <> 0        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')       
            GOTO Step_1_Fail        
         END        
      END        
      ELSE       
      BEGIN      
         IF @cOrderWithTrackNo = '1'     
         BEGIN     
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
            SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()    
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)    
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey    
            WHERE PK.DROPID = @cToteNo    
              AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P') -- (ChewKP04)             
              AND PK.CaseID = ''    
              AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                             'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08)   --(yeekung01)  
              AND PK.Qty > 0 -- SOS# 329265    
              AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)     
              AND (( @cUseUdf04AsTrackNo = '1' AND ISNULL( O.UserDefine04, '') <> '') OR ( ISNULL(O.TrackingNo ,'') <> ''))   -- (james14)  
            GROUP BY PK.OrderKey, PK.SKU    
         END    
         ELSE    
         BEGIN    
            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
            SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()    
            FROM dbo.PICKDETAIL PK WITH (NOLOCK)    
            JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey    
            WHERE PK.DROPID = @cToteNo    
              AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P') -- (ChewKP04)             
              AND PK.CaseID = ''    
              AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                             'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08)   --(yeekung01)  
              AND PK.Qty > 0 -- SOS# 329265    
              AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)     
            GROUP BY PK.OrderKey, PK.SKU    
         END    
         IF @@ROWCOUNT = 0 -- No data inserted    
         BEGIN    
            --ROLLBACK TRAN    
            SET @nErrNo = 90457    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'    
            GOTO Step_1_Fail    
         END    
       
         IF @@ERROR <> 0    
         BEGIN    
            --ROLLBACK TRAN    
            SET @nErrNo = 90458    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'    
            GOTO Step_1_Fail    
         END    
      END  
          
      /****************************          
       prepare next screen variable          
      ****************************/          
      SET @cOutField01 = @cDropIDType          
          
          
--      IF @cDropIDType = @cMultis          
--      BEGIN          
          
      IF @cDropIDType = @cMultis          
      BEGIN          
         SELECT @cOrderkey = MIN(Orderkey)          
         FROM  rdt.rdtECOMMLog WITH (NOLOCK)          
         WHERE ToteNo = @cToteNo          
         AND   Status < '5'          
         AND   Mobile = @nMobile          
      END          
      ELSE          
      BEGIN          
         SET @cOrderkey = ''          
      END          
          
      SET @nTotalScannedQty = 0          
      SELECT @nTotalScannedQty = SUM(QTY)          
      FROM dbo.PickDetail PD WITH (NOLOCK)          
      INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
      WHERE PD.DropID = @cToteNo          
      --AND PD.Status = '5' -- (ChewKP04)           
      AND (PD.Status IN  ('3','5') OR PD.ShipFlag = 'P')  -- (ChewKP04)                   
      AND PD.CaseID <> ''          
      AND O.LoadKey = @cLoadKey          
      AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
      AND PH.PickHeaderKey = @cPickSlipNo -- (Chee02)           
          
      SELECT @nTotalPickedQty  = SUM(ExpectedQty)          
      FROM rdt.rdtECOMMLog WITH (NOLOCK)          
      WHERE ToteNo = @cToteNo          
      AND Status = '0'          
      AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END          
      AND AddWho = @cUserName          
   
      SET @cOutField02 = @cToteno          
      SET @cOutField03 = @cOrderkey   --multis order will have only 1 order in the tote          
      SET @cOutField04 = ''          
      SET @cOutField05 = @nTotalPickedQty          
      SET @cOutField06 = ISNULL(@nTotalScannedQty, 0 )          
        
      SET @nScn = @nScn + 1          
      SET @nStep = @nStep + 1          
--      END          
          
      GOTO QUIT          
          
      PARK_TOTE:          
      BEGIN          
         SET @nScn = @nScn + 3          
         SET @nStep = @nStep + 3          
      END          
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
      SET @cToteNo      = ''          
      SET @cDropIDType  = ''          
   END          
   GOTO Quit          
          
   Step_1_Fail:          
   BEGIN          
      SET @cToteNo = ''          
      SET @cDropIDType  = ''          
      SET @cOutField01 = ''          
          
   END          
END          
GOTO Quit          
          
/********************************************************************************          
Step 2. screen = 3911          
   ToteNo:          
   TOTENo   (Field01, display)          
   SKU/UPC:          
   SKU/UPC  (Field02, input)          
********************************************************************************/          
Step_2:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cInSku    = @cInField04          
      SET @cBarcode  = @cInField04  -- (james02)          
      SET @cUPC = LEFT( @cInField04, 30) -- SKU  
        
      IF ISNULL(@cInSKU, '') = ''          
      BEGIN          
         SET @nErrNo = 90491          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU req          
         GOTO Step_2_Fail          
      END          
        
      IF @cInSku <> ''          
      BEGIN          
         -- Decode label          
         IF ISNULL(@cDecodeLabelNo,'')  <> ''          
         BEGIN          
          
            --SET @c_oFieled09 = @cDropID          
            --SET @c_oFieled10 = @cTaskDetailKey          
          
            SET @cErrMsg = ''          
            SET @nErrNo = 0     
            EXEC dbo.ispLabelNo_Decoding_Wrapper          
                @c_SPName     = @cDecodeLabelNo          
               ,@c_LabelNo    = @cBarcode          
               ,@c_Storerkey  = @cStorerKey          
               ,@c_ReceiptKey = ''          
               ,@c_POKey      = ''          
               ,@c_LangCode   = @cLangCode          
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU          
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE          
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR          
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE          
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY          
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- LOT          
               ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Label Type          
               ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- UCC          
               ,@c_oFieled09  = @c_oFieled09 OUTPUT          
               ,@c_oFieled10  = @c_oFieled10 OUTPUT          
               ,@b_Success    = @b_Success   OUTPUT          
               ,@n_ErrNo      = @nErrNo      OUTPUT    
               ,@c_ErrMsg     = @cErrMsg     OUTPUT          
          
            IF @nErrNo <> 0          
               GOTO Step_2_Fail          
          
            SET @cSKU  = ISNULL( @c_oFieled01, '')          
        
            IF @cSerialNoCapture IN('1','3')          
            BEGIN          
               SET @cSerialNo=@c_oFieled09           
               SET @nSerialQty=@c_oFieled10          
               SET @nqty=CASE WHEN @nSerialQTY=0 THEN @nqty ELSE @nSerialQTY END           
            END          
            --SET @nUCCQTY = CAST( ISNULL( @c_oFieled05, '') AS INT)          
            --SET @cUCC    = ISNULL( @c_oFieled08, '')          
         END          
         ELSE          
         BEGIN          
            -- Decode  
            IF @cDecodeSP <> ''  
            BEGIN  
               -- Standard decode  
               IF @cDecodeSP = '1'  
               BEGIN  
                  EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,  
                     @cUPC    = @cUPC       OUTPUT,  
                     @nErrNo  = @nErrNo     OUTPUT,  
                     @cErrMsg = @cErrMsg    OUTPUT  
                  IF @nErrNo <> 0  
                     GOTO Quit  
               END  
  
               -- Customize decode  
      ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')  
               BEGIN  
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +  
                     ' @cToteno, @cWaveKey, @cLoadKey, @cPickSlipNo, @cTrackNo, @cDropIDType, @cBarcode ' +  
                     ' @cSKU OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
                  SET @cSQLParam =  
                     ' @nMobile        INT,           ' +  
                     ' @nFunc          INT,           ' +  
                     ' @cLangCode      NVARCHAR( 3),  ' +  
                     ' @nStep          INT,           ' +  
                     ' @nInputKey      INT,           ' +  
                     ' @cFacility      NVARCHAR( 5),  ' +  
                     ' @cStorerKey     NVARCHAR( 15), ' +  
                     ' @cToteno        NVARCHAR( 20), ' +    
                     ' @cWaveKey       NVARCHAR( 10), ' +    
                     ' @cLoadKey       NVARCHAR( 10), ' +    
                     ' @cPickSlipNo    NVARCHAR( 10), ' +    
                     ' @cTrackNo       NVARCHAR( 20), ' +    
                     ' @cDropIDType    NVARCHAR( 10),  ' +   
                     ' @cBarcode       NVARCHAR( 60), ' +  
                     ' @cUPC           NVARCHAR( 20)  OUTPUT, ' +  
                     ' @nErrNo         INT            OUTPUT, ' +  
                     ' @cErrMsg        NVARCHAR( 20)  OUTPUT'  
  
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
                     @cToteno, @cWaveKey, @cLoadKey, @cPickSlipNo, @cTrackNo, @cDropIDType, @cBarcode,  
                     @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
                  IF @nErrNo <> 0  
                     GOTO Quit  
               END  
  
               SET @cSku = @cUPC  
            END  
            ELSE    
            BEGIN    
               SET @cSKU  = @cInSku    
            END  
         END          
      END          
      ELSE          
      BEGIN          
         SET @cSku = @cInSku  -- (james01)          
      END          
          
       -- Get SKU barcode count          
      SET @nSKUCnt = 0          
          
      EXEC rdt.rdt_GETSKUCNT          
          @cStorerKey  = @cStorerKey          
         ,@cSKU        = @cSKU          
         ,@nSKUCnt     = @nSKUCnt       OUTPUT          
         ,@bSuccess    = @b_Success     OUTPUT          
         ,@nErr        = @nErrNo        OUTPUT          
         ,@cErrMsg     = @cErrMsg OUTPUT          
         ,@cSKUStatus  = @cSKUStatus          
          
          
      -- Check SKU/UPC          
      IF @nSKUCnt = 0          
      BEGIN          
         SET @nErrNo = 90459          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU          
                   
         -- (ChewKP02)           
         --SET @nErrNo = 0          
         -- (james04)          
         -- Comment by james due to the double bytes char display issue          
         --SET @cErrMsg1 = @nErrNo          
         --SET @cErrMsg2 = @cErrMsg          
                   
         IF ISNULL(RTRIM(@cOrderKey),'')  <> ''           
         BEGIN          
            SET @cErrMsg3 = 'FOR ORDERKEY:'          
            SET @cErrMsg4 = @cOrderKey          
            SET @cErrMsg5 = ''          
         END          
                   
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,          
            @nErrNo, @cErrMsg, @cErrMsg3, @cErrMsg4, @cErrMsg5          
                   
                                     
         GOTO Step_2_Fail          
      END          
          
   -- Check multi SKU barcode          
      IF @nSKUCnt > 1          
      BEGIN          
         SET @nErrNo = 90460          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod          
         GOTO Step_2_Fail          
      END          
          
      -- Get SKU code          
      EXEC rdt.rdt_GETSKU          
          @cStorerKey  = @cStorerKey          
         ,@cSKU        = @cSKU          OUTPUT          
         ,@bSuccess    = @b_Success     OUTPUT          
         ,@nErr        = @nErrNo        OUTPUT          
         ,@cErrMsg     = @cErrMsg       OUTPUT          
         ,@cSKUStatus  = @cSKUStatus          
          
      -- Custom get orderkey sp. Can do swap lot inside the sp and insert ecommlog          
      IF @cGetOrders_SP <> ''          
         AND EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = @cGetOrders_SP AND type = 'P')          
      BEGIN          
         SET @cSQL = 'EXEC rdt.' + RTRIM(@cGetOrders_SP) +          
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cToteno,           
              @cWaveKey, @cLoadKey, @cSKU, @cPickSlipNo, @cTrackNo, @cDropIDType, @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '          
         SET @cSQLParam =          
            '@nMobile        INT, ' +          
            '@nFunc          INT, ' +          
            '@cLangCode      NVARCHAR( 3),  ' +          
            '@nStep          INT, ' +          
            '@nInputKey      INT, ' +          
            '@cUserName      NVARCHAR( 18), ' +          
            '@cFacility      NVARCHAR( 5), ' +          
            '@cStorerKey     NVARCHAR( 15), ' +          
            '@cToteno        NVARCHAR( 20), ' +          
            '@cWaveKey       NVARCHAR( 10), ' +          
            '@cLoadKey       NVARCHAR( 10), ' +          
            '@cSKU           NVARCHAR( 20), ' +          
            '@cPickSlipNo    NVARCHAR( 10), ' +          
            '@cTrackNo       NVARCHAR( 20), ' +          
            '@cDropIDType    NVARCHAR( 10),  ' +         
            '@cOrderkey      NVARCHAR( 10) OUTPUT, ' +          
            '@nErrNo         INT           OUTPUT, ' +          
            '@cErrMsg        NVARCHAR( 20) OUTPUT'          
        
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cToteno,           
            @cWaveKey, @cLoadKey, @cSKU, @cPickSlipNo, @cTrackNo, @cDropIDType, @cOrderkey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT          
          
         IF @nErrNo <> 0          
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnNotFrSameLoad          
            GOTO Step_2_Fail          
         END       
      END          
      ELSE   
      IF @cNoToteFlag = '1'          
      BEGIN          
                      
          
         /****************************          
            INSERT INTO rdtECOMMLog          
         ****************************/          
                      
         IF ISNULL( @cRefNo, '') <> ''      
         BEGIN      
            IF @cRefNoInsLogSP <> ''        
            BEGIN        
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRefNoInsLogSP AND type = 'P')        
               BEGIN        
                  SET @nErrNo = 0      
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cRefNoInsLogSP) +        
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cToteNo, @cWaveKey, @cLoadKey, @cSKU, @cDropIDType, @cUserName,       
                       @cOrderkey OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT'                        
                  SET @cSQLParam =        
  '@nMobile        INT, ' +        
                     '@nFunc          INT, ' +        
                     '@cLangCode      NVARCHAR( 3),  ' +       
                     '@nStep          NVARCHAR( 18), ' +       
                     '@nInputKey      NVARCHAR( 5),  ' +       
                     '@cStorerKey     NVARCHAR( 15), ' +       
                     '@cRefNo         NVARCHAR( 20), ' +       
                     '@cToteNo        NVARCHAR( 20), ' +       
                     '@cWaveKey       NVARCHAR( 10), ' +       
                     '@cLoadKey       NVARCHAR( 10), ' +       
                     '@cSKU           NVARCHAR( 20), ' +       
                     '@cDropIDType    NVARCHAR( 10), ' +       
                     '@cUserName      NVARCHAR( 18), ' +    
                     '@cOrderkey      NVARCHAR( 10) OUTPUT, ' +    
                     '@nErrNo         INT           OUTPUT, ' +        
                     '@cErrMsg        NVARCHAR( 20) OUTPUT  '                    
                        
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                        
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cToteNo, @cWaveKey, @cLoadKey, @cSKU, @cDropIDType, @cUserName,     
                     @cOrderkey OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT               
                        
                  IF @nErrNo <> 0       
                     GOTO Step_2_Fail        
        
               END        
            END        
         END      
         ELSE       
         BEGIN      
            IF ISNULL(RTRIM(@cWaveKey),'')  <> ''     
            BEGIN    
               IF @cOrderWithTrackNo = '1' -- (ChewKP10)     
               BEGIN     
                  INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
                  SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
                  FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey       
                  JOIN WAVEDETAIL AS w WITH(NOLOCK) ON w.OrderKey = O.OrderKey     
                  WHERE W.WaveKey = ISNULL(RTRIM(@cWaveKey),'')     
                     AND PK.StorerKey = @cStorerKey     
                     AND PK.SKU = @cSKU      
                     AND PK.Status = '0'  AND PK.ShipFlag = '0' --(ChewKP09)    
                     AND PK.CaseID = ''                            
                     AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                                       'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08) --(yeekung01)    
                     AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)     
                     AND PK.Qty > 0 -- SOS# 329265      
                     AND (( @cUseUdf04AsTrackNo = '1' AND ISNULL( O.UserDefine04, '') <> '') OR ( ISNULL(O.TrackingNo ,'') <> ''))   -- (james14)  
                     AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                                       WHERE RE.OrderKey = O.OrderKey      
                                       AND Status < '9'  )       
                  GROUP BY PK.OrderKey, PK.SKU      
               END    
               ELSE    
               BEGIN    
                  INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
                  SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
                  FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey       
                  JOIN WAVEDETAIL AS w WITH(NOLOCK) ON w.OrderKey = O.OrderKey     
                  WHERE W.WaveKey = ISNULL(RTRIM(@cWaveKey),'')     
                     AND PK.StorerKey = @cStorerKey                        
                     AND PK.SKU = @cSKU      
                     AND PK.Status = '0'  AND PK.ShipFlag = '0' --(ChewKP09)    
                     AND PK.CaseID = ''      
                     AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                                       'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08)   --(yeekung01)  
                     AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)     
                     AND PK.Qty > 0 -- SOS# 329265      
                     AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                                       WHERE RE.OrderKey = O.OrderKey      
                                       AND Status < '9'  )       
                  GROUP BY PK.OrderKey, PK.SKU      
               END    
            END    
            ELSE IF ISNULL(RTRIM(@cLoadKey),'')  <> ''     
            BEGIN    
               IF @cOrderWithTrackNo = '1' -- (ChewKP10)     
               BEGIN    
                  INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
                  SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
                  FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')    
                  WHERE PK.SKU = @cSKU      
                     AND PK.Status = '0' AND PK.ShipFlag = '0' --(ChewKP09)    
                     AND PK.CaseID = ''      
                     AND PK.StorerKey = @cStorerKey      
                     AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                                    'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08)   --(yeekung01)  
                     AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD' , 'PENDCANC' ) -- (ChewKP05)     
                     AND PK.Qty > 0 -- SOS# 329265      
                     AND (( @cUseUdf04AsTrackNo = '1' AND ISNULL( O.UserDefine04, '') <> '') OR ( ISNULL(O.TrackingNo ,'') <> ''))   -- (james14)  
                     AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                                       WHERE RE.OrderKey = O.OrderKey       
                                       AND Status < '9'  )       
                  GROUP BY PK.OrderKey, PK.SKU      
               END    
               ELSE    
               BEGIN    
                  INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)    
                  SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()      
                  FROM dbo.PICKDETAIL PK WITH (NOLOCK)      
                  JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey AND O.LoadKey = ISNULL(RTRIM(@cLoadKey),'')    
                  WHERE PK.SKU = @cSKU      
                     AND PK.Status = '0' AND PK.ShipFlag = '0' --(ChewKP09)    
                     AND PK.CaseID = ''      
                     AND PK.StorerKey = @cStorerKey      
                     AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',   
                                    'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08)   --(yeekung01)  
                     AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD' , 'PENDCANC' ) -- (ChewKP05)     
                     AND PK.Qty > 0 -- SOS# 329265      
                     AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)       
                                       WHERE RE.OrderKey = O.OrderKey       
                                       AND Status < '9'  )       
                  GROUP BY PK.OrderKey, PK.SKU      
               END    
            END    
                   
            IF @@ROWCOUNT = 0 -- No data inserted    
            BEGIN    
               --ROLLBACK TRAN    
               SET @nErrNo = 90481    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'    
               GOTO Step_2_Fail    
            END    
             
            IF @@ERROR <> 0    
            BEGIN    
               --ROLLBACK TRAN    
               SET @nErrNo = 90482    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'    
               GOTO Step_2_Fail    
            END    
         END  
                      
            --IF @@ROWCOUNT = 0 -- No data inserted          
            --BEGIN          
            --   --ROLLBACK TRAN          
            --   SET @nErrNo = 90481          
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'          
            --   GOTO Step_2_Fail          
            --END          
                
            --IF @@ERROR <> 0          
            --BEGIN          
            --   --ROLLBACK TRAN          
            --   SET @nErrNo = 90482          
            --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'          
            --   GOTO Step_2_Fail          
            --END          
                      
         SELECT @cOrderKey = OrderKey          
         FROM rdt.rdtECOMMLog (NOLOCK)           
         WHERE Mobile = @nMobile          
         AND SKU      = @cSKU          
         AND Status   = '0'          
       
         IF ISNULL(RTRIM(@cOrderKey),'' ) = ''          
         BEGIN          
            SET @nErrNo = 90483          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvalidOrderKey'          
            GOTO Step_2_Fail          
         END          
                      
         SET @cPickslipNo = ''          
          
         SELECT @cPickSlipNo = PickHeaderKey          
         FROM dbo.PickHeader WITH (NOLOCK)          
         WHERE OrderKey = @cOrderKey           
      END          
      ELSE          
      BEGIN          
         -- Check If SKU exists in TOTE          
         IF NOT EXISTS (SELECT TOP 1 1            
                        FROM dbo.Pickdetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))            
                        WHERE  PD.StorerKey = @cStorerKey            
                           --AND PD.Status = '5' -- (ChewKP04)            
                           AND (PD.Status IN ( '3', '5') OR PD.ShipFlag = 'P') -- (ChewKP04)                     
                           AND PD.DropID = @cToteNo            
                           AND PD.SKU = @cSku            
                           AND PD.CaseID = '' )    
         BEGIN          
            SET @nErrNo = 90461          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID SKU'          
                      
            -- (ChewKP02)           
            --SET @nErrNo = 0          
            --SET @cErrMsg1 = @nErrNo          
            --SET @cErrMsg2 = @cErrMsg          
                      
         IF ISNULL(RTRIM(@cOrderKey),'')  <> ''           
            BEGIN          
               SET @cErrMsg3 = 'FOR ORDERKEY:'          
               SET @cErrMsg4 = @cOrderKey          
               SET @cErrMsg5 = ''          
           END          
                      
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,          
               @nErrNo, @cErrMsg, @cErrMsg3, @cErrMsg4, @cErrMsg5          
                         
            GOTO Step_2_Fail          
         END          
      END          
  
      IF @cMultiMethod ='1' --(yeekung03)  
      BEGIN  
                    
          /****************************          
            INSERT INTO rdtECOMMLog          
         ****************************/          
                      
         IF ISNULL( @cRefNo, '') <> ''      
         BEGIN      
            IF @cRefNoInsLogSP <> ''        
            BEGIN        
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRefNoInsLogSP AND type = 'P')        
               BEGIN        
                  SET @nErrNo = 0      
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cRefNoInsLogSP) +        
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cToteNo, @cWaveKey, @cLoadKey, @cSKU, @cDropIDType, @cUserName,      
                     @cOrderkey OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT'                        
                  SET @cSQLParam =        
                     '@nMobile        INT, ' +        
                     '@nFunc          INT, ' +        
                     '@cLangCode      NVARCHAR( 3),  ' +       
                     '@nStep          NVARCHAR( 18), ' +       
                     '@nInputKey      NVARCHAR( 5),  ' +       
                     '@cStorerKey     NVARCHAR( 15), ' +       
                     '@cRefNo         NVARCHAR( 20), ' +       
                     '@cToteNo        NVARCHAR( 20), ' +       
                     '@cWaveKey       NVARCHAR( 10), ' +       
                     '@cLoadKey       NVARCHAR( 10), ' +       
                     '@cSKU           NVARCHAR( 20), ' +       
                     '@cDropIDType    NVARCHAR( 10), ' +       
                     '@cUserName      NVARCHAR( 18), ' +    
                     '@cOrderkey      NVARCHAR( 10) OUTPUT, ' +  
                     '@nErrNo         INT           OUTPUT, ' +        
                     '@cErrMsg        NVARCHAR( 20) OUTPUT  '                    
                        
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                        
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cToteNo, @cWaveKey, @cLoadKey, @cSKU, @cDropIDType, @cUserName,     
                     @cOrderkey OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT               
                        
                  IF @nErrNo <> 0       
                     GOTO Step_2_Fail        
        
               END        
            END        
         END    
      END  
        
      -- Serial No              
      IF @cSerialNoCapture IN ('1', '3')  AND ISNULL(@cSerialNo,'')='' -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY              
      BEGIN              
          
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc,@nqty, 'CHECK', 'PICKSLIP', @cPickSlipNo,               
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,              
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,              
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,              
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,              
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,              
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,              
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,              
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,              
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,              
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,              
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,              
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,              
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,              
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,              
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,              
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,               
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,               
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '3'              
                       
         IF @nErrNo <> 0              
            GOTO Quit              
              
         IF @nMoreSNO = 1              
         BEGIN              
            -- Go to Serial No screen           
            SET @nPrevScn=  @nScn          
            SET @nScn = 4831              
            SET @nStep = @nStep + 6              
              
            GOTO Quit              
         END              
      END                   
              
      IF @cExtendedValidateSP <> ''          
      BEGIN          
          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')          
         BEGIN          
          
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +          
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo, @cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '          
            SET @cSQLParam =          
               '@nMobile        INT, ' +          
               '@nFunc          INT, ' +          
               '@cLangCode      NVARCHAR( 3),  ' +          
               '@nStep          INT, ' +          
               '@cStorerKey     NVARCHAR( 15), ' +          
               '@cToteno        NVARCHAR( 20), ' +          
               '@cSKU           NVARCHAR( 20), ' +          
               '@cPickSlipNo    NVARCHAR( 10), ' +          
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,           ' +           
               '@nErrNo        INT           OUTPUT, ' +          
               '@cErrMsg        NVARCHAR( 20) OUTPUT'          
          
          
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo ,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT          
          
            IF @nErrNo <> 0          
         BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnNotFrSameLoad          
               GOTO Step_2_Fail          
            END          
          
         END          
      END          
                    
      IF @cExtendedUpdateSP <> ''          
      BEGIN          
          
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')          
          BEGIN          
             SET @cTrackNoFlag = '0'          
             SET @cOrderKeyOut = ''          
          
             INSERT INTO @tExtUpd (Variable, Value) VALUES         
               ('@cCube',        @cCube),        
               ('@cWeight',      @cWeight),        
               ('@cRefNo',       @cRefNo),         
               ('@cWaveKey',     @cWaveKey),        
               ('@cLoadKey',     @cLoadKey),         
               ('@cOption',    @cOption)               
                            
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                            
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                  @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd '                           
             SET @cSQLParam =                            
                '@nMobile        INT, ' +                            
                '@nFunc          INT, ' +                            
                '@cLangCode      NVARCHAR( 3),  ' +                            
                '@cUserName      NVARCHAR( 18), ' +                            
                '@cFacility      NVARCHAR( 5),  ' +                      
                '@cStorerKey     NVARCHAR( 15), ' +                            
                '@cToteNo        NVARCHAR( 20), ' +                            
                '@cSKU           NVARCHAR( 20), ' +                            
                '@nStep          INT,           ' +                            
                '@cPickSlipNo    NVARCHAR( 10), ' +                            
                '@cOrderkey      NVARCHAR( 10), ' +                            
                '@cTrackNo       NVARCHAR( 20), ' +                          
                '@cTrackNoFlag   NVARCHAR( 1) OUTPUT,  ' +                            
                '@cOrderKeyOut   NVARCHAR( 10)OUTPUT,  ' +                            
                '@nErrNo         INT           OUTPUT, ' +                            
                '@cErrMsg        NVARCHAR( 20) OUTPUT,'   +                        
                '@cCartonType    NVARCHAR( 20),'+          
                '@cSerialNo      NVARCHAR( 30), ' +               
                '@nSerialQTY     INT,'  +                
                '@tExtUpd        VariableTable READONLY '            
                            
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                            
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd                          
                          
             IF @nErrNo < 0 -- (ChewKP06)           
             BEGIN          
               --SET @nErrNo = 0                
               SET @cErrMsg1 = 'WayBill Not Found'          
               --SET @cErrMsg2 = @cErrMsg                
               SET @cErrMsg3 = ''                
               SET @cErrMsg4 = ''                
               SET @cErrMsg5 = ''                
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,                
                  @cErrMsg1, @cErrMsg, @cErrMsg3, @cErrMsg4, @cErrMsg5                
                         
               SET @cErrMsg = ''          
             END          
             ELSE IF @nErrNo > 0           
             BEGIN          
                GOTO Step_2_Fail          
             END          
          END          
      END          
          
      IF @cExtendedInfoSP <> ''                          
      BEGIN                          
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')                          
         BEGIN                          
                          
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +                          
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cLoadKey,@cWavekey,@nInputKey, @cSerialNo, @nSerialQTY, @cExtendedinfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '                          
            SET @cSQLParam =            
               '@nMobile        INT, ' +                          
               '@nFunc          INT, ' +                          
               '@cLangCode      NVARCHAR( 3),  ' +                          
               '@nStep          INT, ' +                          
               '@cStorerKey     NVARCHAR( 15), ' +                          
               '@cToteno        NVARCHAR( 20), ' +                          
               '@cSKU           NVARCHAR( 20), ' +                          
               '@cPickSlipNo    NVARCHAR( 10), ' +                
               '@cLoadKey       NVARCHAR( 20), ' +                
               '@cWavekey       NVARCHAR( 20), ' +                
               '@nInputKey      INT,           ' +                
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,           ' +                 
               '@cExtendedinfo  NVARCHAR( 20) OUTPUT, ' +                         
               '@nErrNo         INT           OUTPUT, ' +                          
               '@cErrMsg        NVARCHAR( 20) OUTPUT'                          
                          
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                          
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cLoadKey,@cWavekey,@nInputKey, @cSerialNo, @nSerialQTY, @cExtendedinfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT                          
                          
            IF @nErrNo <> 0                          
               GOTO Step_2_Fail                          
         END                          
      END 
                               
      -- EventLog   (yeekung05)     
      EXEC RDT.rdt_STD_EventLog        
         @cActionType = '4', -- Packing       
         @cUserID     = @cUserName,        
         @nMobileNo   = @nMobile,        
         @nFunctionID = @nFunc,        
         @cFacility   = @cFacility,        
         @cStorerKey  = @cStorerKey,        
         @nStep       = @nStep,
         @cLoadKey    = @cLoadKey,
         @cSKU        = @cSKU,
         @cRefNo1     = @cRefno,
         @cDropID     = @cToteno,
         @cWaveKey    = @cWaveKey   
            
      /****************************          
       Prepare Next Screen          
      ****************************/          
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno          
         AND Mobile = @nMobile AND Status < '5')          
      BEGIN          
               
         -- tote completed, so need to return to 1st screen          
          
         -- Check if all SKU in this tote picked and packed (james01)          
         -- Check total picked & unshipped qty          
         IF @cNoToteFlag <> '1'        
         BEGIN
            IF @cNotCheckDropIDTable = '1'  
            BEGIN  
               SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)          
               FROM dbo.Pickdetail PD WITH (NOLOCK)          
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
               WHERE O.StorerKey = @cStorerKey          
                  AND O.Status <> '9'           
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')          
                  AND (PD.Status IN ('3', '5') OR PD.ShipFlag = 'P')                  
                  AND PD.DropID = @cToteNo          
            END  
            ELSE  
            BEGIN  
               SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)        
               FROM dbo.Pickdetail PD WITH (NOLOCK)        
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey        
               JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY        
               JOIN rdt.rdtEcommLog ELOG WITH (NOLOCK) ON ELOG.OrderKey = PD.OrderKey AND ELOG.SKU = PD.SKU AND ELOG.ToteNo = PD.DropID -- (ChewKP08)         
               WHERE O.StorerKey = @cStorerKey        
                  AND O.Status <> '9'         
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')        
                  AND (PD.Status = '5' OR PD.ShipFlag = 'P')                
                  AND PD.DropID = @cToteNo        
                  AND ELOG.ToteNo = @cToteNo   -- (ChewKP08)         
                  AND ELOG.AddWho = @cUserName -- (ChewKP08)           
                  AND ELOG.Status = '9'        -- (ChewKP08)           
            END
                        
                   
            IF @cGenPackDetail = '1'          
            BEGIN 
                         
               IF @cNotCheckDropIDTable = '1'          
               BEGIN       
                  -- Check total packed & unshipped qty          
                  SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)          
                  FROM dbo.Packdetail PD WITH (NOLOCK)          
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo          
                  JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey
                  WHERE O.StorerKey = @cStorerKey          
                     AND O.Status <> '9'           
                     AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')          
                     AND PD.DropID = @cToteNo    
               END
               ELSE
               BEGIN
                   -- Check total packed & unshipped qty          
                  SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)          
                  FROM dbo.Packdetail PD WITH (NOLOCK)          
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo          
                  JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey 
                  JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY          
                  WHERE O.StorerKey = @cStorerKey          
                     AND O.Status <> '9'           
                     AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')          
                     AND PD.DropID = @cToteNo   
               END
            END          
            ELSE          
            BEGIN          
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(SCannedQTY), 0)          
               FROM rdt.rdtEcommLog WITH (NOLOCK)            
               WHERE ToteNo = @cToteNo             
               AND AddWho = @cUserName             
               AND Status = '9'          
                         
            END          
         END          
         ELSE          
         BEGIN          
            SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)          
            FROM dbo.Pickdetail PD WITH (NOLOCK)          
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
            WHERE O.StorerKey = @cStorerKey          
               AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')          
               --AND PD.Status = '5'          
               AND PD.OrderKey = @cOrderKeyOut          
                      
            IF @cGenPackDetail = '1'          
            BEGIN              
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)          
               FROM dbo.Pickdetail PD WITH (NOLOCK)          
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
               WHERE O.StorerKey = @cStorerKey          
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')          
                  AND (PD.Status = '5' OR PD.ShipFlag = 'P')             
                  AND PD.OrderKey = @cOrderKeyOut             
                  AND PD.CaseID <> ''          
            END          
            ELSE          
            BEGIN          
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)          
               FROM dbo.Pickdetail PD WITH (NOLOCK)          
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
               WHERE O.StorerKey = @cStorerKey          
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')          
                  AND (PD.Status = '5' OR PD.ShipFlag = 'P')                 
                  AND PD.OrderKey = @cOrderKeyOut             
                  --AND PD.CaseID <> ''          
            END          
         END          
                   
    
                   
         -- Close DropID when pick & pack qty matches          
         IF @nSKU_Picked_TTL <> @nSKU_Packed_TTL          
         BEGIN          
            IF @cTrackNoFlag = '1'          
            BEGIN        
               --(cc01)        
               IF @cScanCTSCN <> ''                      
               BEGIN                  
                  -- Get PackInfo          
                  SET @cCartonType = ''          
                  SET @cWeight = ''          
                  SET @cCube = ''          
                  SET @cRefNo = ''          
                         
                  SET @cOutField02 = ''    
                  SET @cOutField03 = ''    
                  SET @cOutField04 = ''    
                  SET @cOutField07 = ''  
                  SET @cOrderKey = @cOrderKeyOut  
                         
                  --set default Value        
                  SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
                                   
                  -- Enable disable field          
                  SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                  SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                  SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                  SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                  SET @cFieldAttr08 = '' -- QTY          
                
                  -- Position cursor          
                  IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                  IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                  IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                  IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4


                  SET @cOutField08 = @cExtendedinfo --(yeekung07)
                
                  -- Go to next screen          
                  SET @nScn = @nScn + 5          
                  SET @nStep = @nStep + 5          
                      
                  GOTO Quit          
               END          
               IF @cShowTrackNoScn = '1'          
               BEGIN        
                  IF @cDefaultTrackNo = '1'          
                  BEGIN          
                     SET @cSuggestedTrackNo = ''          
        
                     IF @cUseUdf04AsTrackNo = '1'        
                        SELECT @cSuggestedTrackNo = UserDefine04          
                        FROM dbo.Orders WITH (NOLOCK)          
                        WHERE StorerKey = @cStorerKey          
                        AND OrderKey = @cOrderKeyOut          
                     ELSE        
                        SELECT @cSuggestedTrackNo = TrackingNo        
                        FROM dbo.Orders WITH (NOLOCK)          
                        WHERE StorerKey = @cStorerKey          
                        AND OrderKey = @cOrderKeyOut          
        
                     SET @cOrderKey = @cOrderKeyOut          
                  END          

                  SET @cOrderKey = @cOrderKeyOut  
                  SET @cOutField01 = @cOrderKey          
                  SET @cOutfield02 = @cSuggestedTrackNo          
          
                  SET @nScn = @nScn + 4          
                  SET @nStep = @nStep + 4          
               END          
               ELSE          
               BEGIN       
                  SET @cOrderKey = @cOrderKeyOut  
                  SET @nTotalScannedQty = @nTotalScannedQty + 1          
            
                  SET @cOutField01 = @cDropIDType          
                  SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)          
                  SET @cOutField03 = @cOrderKey          
                  SET @cOutField04 = ''          
             
                  SET @cOutField05 = @nTotalPickedQty          
                  SET @cOutField06 = @nTotalScannedQty         
                  SET @cOutField07 = @cExtendedinfo              
               END          
            END          
            ELSE          
            BEGIN          
             
               SET @nTotalScannedQty = @nTotalScannedQty + 1     
               
               SET @cOrderKey = @cOrderKeyOut              
               SET @cOutField01 = @cDropIDType          
               SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)          
               SET @cOutField03 = @cOrderKey          
               SET @cOutField04 = ''          
          
               SET @cOutField05 = @nTotalPickedQty          
               SET @cOutField06 = @nTotalScannedQty        
               SET @cOutField07 = @cExtendedinfo             
                               
--                  SET @cSKU = ''          
--                  SET @cOutField01 = @cToteNo          
--                  SET @cOutField02 = ''          
            END          
         END          
         ELSE          
         BEGIN          
            --(Kc05)          
            --(KC04) - start          
            IF EXISTS( SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cToteNo AND Status < '9')          
            BEGIN          
               UPDATE dbo.DROPID WITH (Rowlock)          
               SET   Status = '9'          
                    ,Editdate = GetDate()          
               WHERE DropID = @cToteNo          
               -- AND   Status < '9'          
          
               IF @@ERROR <> 0          
               BEGIN          
                  SET @nErrNo = 90462          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'          
                  GOTO Step_2_Fail          
               END          
            END          
            --(Kc04) - end          
                      
            SET @cDropIDStatus = ''              
            SELECT @cDropIDStatus = Status               
            FROM dbo.DropID WITH (NOLOCK)               
            WHERE DropID = @cToteNo               
                          
                          
            IF @cShowTrackNoScn = '1'          
            BEGIN          
               IF @cTrackNoFlag = '1'          
               BEGIN          
                  --(cc01)        
                  IF @cScanCTSCN <> ''                      
                  BEGIN                  
                     -- Get PackInfo          
                     SET @cCartonType = ''          
                     SET @cWeight = ''          
                     SET @cCube = ''          
                     SET @cRefNo = ''  
                     SET @cOrderKey = @cOrderKeyOut  
                                   
                     --set default Value        
                     SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
                     SET @cOutField02 = ''        
                     SET @cOutField03 = ''        
                     SET @cOutField04 = ''           
                                   
                     -- Enable disable field          
                     SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr08 = '' -- QTY          
                
                     -- Position cursor          
                     IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                     IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                     IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                     IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
                
                     SET @cOutField08 = @cExtendedinfo --(yeekung07)

                     -- Go to next screen          
                     SET @nScn = @nScn + 5          
                     SET @nStep = @nStep + 5          
                      
                     GOTO Quit          
                  END           
          
                  IF @cDefaultTrackNo = '1'          
                  BEGIN          
                     SET @cSuggestedTrackNo = ''          
                             
                     IF @cUseUdf04AsTrackNo = '1'        
                        SELECT @cSuggestedTrackNo = UserDefine04          
                        FROM dbo.Orders WITH (NOLOCK)          
                        WHERE StorerKey = @cStorerKey          
                        AND OrderKey = @cOrderKeyOut          
                     ELSE        
                        SELECT @cSuggestedTrackNo = TrackingNo        
                        FROM dbo.Orders WITH (NOLOCK)          
                        WHERE StorerKey = @cStorerKey          
                        AND OrderKey = @cOrderKeyOut          
        
                     SET @cOrderKey = @cOrderKeyOut          
                  END          
          
                  SET @cOutField01 = @cOrderKey          
                  SET @cOutfield02 = @cSuggestedTrackNo          
          
                  SET @nScn = @nScn + 4          
                  SET @nStep = @nStep + 4          
               END          
               ELSE          
               BEGIN          
                  -- Tote is Finish Back to Main Screen          
                  DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
                  SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)           
                  WHERE ToteNo = @cToteno           
                  AND   AddWho = @cUserName          
                  OPEN CUR_DEL          
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef          
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN          
          
                     DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef          
                     IF @@ERROR <> 0          
                     BEGIN          
                        CLOSE CUR_DEL          
                        DEALLOCATE CUR_DEL          
                        SET @nErrNo = 90487          
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
                        GOTO Step_2_Fail          
                     END          
          
                     FETCH NEXT FROM CUR_DEL INTO @nRowRef          
                  END          
                  CLOSE CUR_DEL          
                  DEALLOCATE CUR_DEL          
          
                  --DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName          
             
                  --IF @@ERROR <> 0          
                  --BEGIN          
                  --   SET @nErrNo = 90487          
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
                  --   GOTO Step_2_Fail          
                  --END          
    
                      
                               
                  SET @cOutField01  = ''          
                  SET @cToteNo      = ''          
                  SET @cDropIDType  = ''          
                  SET @cOrderkey    = ''          
                  SET @cSku         = ''          
                            
                  SET @cLoadKey    = ''           
                  SET @cWaveKey    = ''           
                  SET @cOutField02 = ''           
                  SET @cOutField03 = ''           
                            
             
                  SET @nScn = @nScn - 1          
                  SET @nStep = @nStep - 1          
               END          
            END          
            ELSE          
            BEGIN          
               IF @cNoToteFlag <> '1'          
               BEGIN          
                  DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
                  SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)           
                  WHERE ToteNo = @cToteno           
                  AND AddWho = @cUserName          
                  OPEN CUR_DEL          
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef          
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN          
          
                     DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef          
                     IF @@ERROR <> 0          
                     BEGIN          
                        CLOSE CUR_DEL          
                        DEALLOCATE CUR_DEL          
                        SET @nErrNo = 90478          
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
                        GOTO Step_2_Fail          
                     END          
          
                     FETCH NEXT FROM CUR_DEL INTO @nRowRef          
                  END          
                  CLOSE CUR_DEL          
                  DEALLOCATE CUR_DEL          
          
                  --DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName          
             
                  --IF @@ERROR <> 0          
                  --BEGIN          
                  --   SET @nErrNo = 90478          
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
                  --   GOTO Step_2_Fail          
                  --END          
                  --(chewKP24022022)     
                  IF @cScanCTSCN <> ''                      
                  BEGIN                  
                     -- Get PackInfo          
                     SET @cCartonType = ''          
                     SET @cWeight = ''          
                     SET @cCube = ''          
                     SET @cRefNo = ''  
                     
                                   
                     --set default Value        
                     SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
                     SET @cOutField02 = ''        
                     SET @cOutField03 = ''        
                     SET @cOutField04 = ''          
                                   
                     -- Enable disable field          
                     SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr08 = '' -- QTY          
                
                     -- Position cursor          
                     IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                     IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                     IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                     IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
                     
                     SET @cOutField08 = @cExtendedinfo --(yeekung07)

                     SET @cOrderkey    = @cOrderKeyOut    
                
                     -- Go to next screen          
                     SET @nScn = @nScn + 5          
                     SET @nStep = @nStep + 5          
                      
                     GOTO Quit          
                  END    
                  SET @cOutField01  = ''          
                  SET @cToteNo      = ''          
                  SET @cDropIDType  = ''          
                  SET @cOrderkey    = ''          
                  SET @cSku         = ''      
                            
                  SET @cLoadKey    = '' -- (ChewKP02)          
                  SET @cWaveKey    = '' -- (ChewKP02)          
                  SET @cOutField02 = '' -- (ChewKP02)          
                  SET @cOutField03 = '' -- (ChewKP02)                                      
             
                  SET @nScn = @nScn - 1          
                  SET @nStep = @nStep - 1          
               END          
               ELSE          
               BEGIN          
                  DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
                  SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)           
                  WHERE ToteNo = @cToteno           
                  AND   AddWho = @cUserName          
                  OPEN CUR_DEL          
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef          
                  WHILE @@FETCH_STATUS <> -1          
                  BEGIN          
          
                     DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef          
                     IF @@ERROR <> 0          
                     BEGIN          
                        CLOSE CUR_DEL          
                        DEALLOCATE CUR_DEL          
                        SET @nErrNo = 90486          
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
                        GOTO Step_2_Fail          
                     END          
          
                     FETCH NEXT FROM CUR_DEL INTO @nRowRef          
                  END          
                  CLOSE CUR_DEL          
                  DEALLOCATE CUR_DEL          
          
                  --DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName          
                            
                  --IF @@ERROR <> 0          
                  --BEGIN          
                  --   SET @nErrNo = 90486          
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
                  --   GOTO Step_2_Fail          
                  --END          
                  
                  SET @nTotalPickedQty = 0           
                  SET @nTotalScannedQty = 0           
          
                  IF ISNULL(RTRIM(@cLoadKey),'')  <> '' OR ISNULL(RTRIM(@cWaveKey),'')  <> ''           
                  BEGIN          
                     SET @nRefCount = 0           
          
                     IF EXISTS (SELECT PD.* FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)      --(yeekung01)                    
                                    INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ORDERKEY = LPD.ORDERKEY                          
                                    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY                          
                                    WHERE LPD.LoadKey = @cLoadKey                          
                                    AND PD.StorerKey = @cStorerKey                          
                                    AND PD.Status IN( '0'  ,@cPickStatus)                         
                                    AND PD.ShipFlag <> 'P'                          
                                    AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) )           
                     BEGIN          
                        SET @nRefCount = 1           
                        /*        
                        SELECT @nTotalPickedQty = Count(O.OrderKey)           
        FROM dbo.Orders O WITH (NOLOCK)           
                        WHERE O.LoadKey = @cLoadKey          
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
          
                        SELECT @nTotalScannedQty = Count(OrderKey)          
                        FROM dbo.Orders WITH (NOLOCK)           
                        WHERE LoadKey = @cLoadKey   
                        AND Status = '5'          
                        AND SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
                        */        
        
                        SELECT @nTotalPickedQty = Count( LPD.OrderKey)           
                        FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)        
                        JOIN dbo.Orders O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)        
                        WHERE LPD.LoadKey = @cLoadKey          
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
          
                        SELECT @nTotalScannedQty = Count( LPD.OrderKey)          
                        FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)        
                        JOIN dbo.Orders O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)        
                        WHERE LPD.LoadKey = @cLoadKey          
                        AND O.Status = '5'          
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)         
                     END          
                               
                     
                     IF EXISTS (SELECT PD.* FROM dbo.WaveDetail WD WITH (NOLOCK)          
                                    INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ORDERKEY = WD.ORDERKEY          
                                    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY          
                                    WHERE WD.WaveKey = @cWaveKey          
                                    AND PD.StorerKey = @cStorerKey          
                                    AND PD.Status = '0'           
                                    AND PD.ShipFlag <> 'P'          
                                    AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) )           
                     BEGIN          
                        SET @nRefCount = 1          
          
                        SELECT @nTotalPickedQty  = Count(O.OrderKey),           
           @nTotalScannedQty = SUM(CASE WHEN O.Status = '5' THEN 1 ELSE 0 END)          
                        FROM dbo.WaveDetail WD WITH (NOLOCK)          
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey          
                        WHERE WD.WaveKey = @cWaveKey          
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
          
                        --SELECT @nTotalScannedQty = Count(O.OrderKey)          
                        --FROM dbo.Orders O WITH (NOLOCK)           
                        --JOIN WAVEDETAIL AS w WITH(NOLOCK) ON w.OrderKey = dbo.Orders.OrderKey          
                        --WHERE w.WaveKey = @cWaveKey          
                        --AND O.Status = '5'          
                        --AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
                     END          
                               
                        
          
                     IF @nRefCount = 0 -- No More PickDetail Go to Screen 1           
                     BEGIN          
                      --(cc01)        
                        IF @cScanCTSCN <> ''                      
                        BEGIN                  
                           -- Get PackInfo          
                           SET @cCartonType = ''          
                           SET @cWeight = ''          
                           SET @cCube = ''          
                           SET @cRefNo = ''     
                           SET @cOrderKey = @cOrderKeyOut  
                        
                           --set default Value        
                           SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
                           SET @cOutField02 = ''        
                           SET @cOutField03 = ''        
                           SET @cOutField04 = ''           
                                   
                           -- Enable disable field          
                           SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr08 = '' -- QTY          
                
                           -- Position cursor          
                           IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                           IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                           IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                           IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          

                           SET @cOutField08 = @cExtendedinfo --(yeekung07)                

                           -- Go to next screen          
                           SET @nScn = @nScn + 5          
                           SET @nStep = @nStep + 5          
                      
                           GOTO Quit          
                        END          
                                
                        SET @cOutField01  = ''          
                        SET @cToteNo      = ''          
                        SET @cDropIDType  = ''          
                        SET @cOrderkey    = ''          
                        SET @cSku         = ''          
                
                        SET @cLoadKey    = ''           
                        SET @cWaveKey    = ''           
                        SET @cOutField02 = ''           
                        SET @cOutField03 = ''           
                                  
                   
                        SET @nScn = @nScn - 1          
                        SET @nStep = @nStep - 1          
                     END          
                     ELSE          
                     BEGIN          
                      --(cc01)        
                        IF @cScanCTSCN <> ''                      
                        BEGIN                  
                           -- Get PackInfo          
                           SET @cCartonType = ''          
                           SET @cWeight = ''          
                           SET @cCube = ''          
                           SET @cRefNo = ''          
                           SET @cOrderKey = @cOrderKeyOut  
                                   
                           --set default Value        
                           SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
                           SET @cOutField02 = ''        
                           SET @cOutField03 = ''        
                           SET @cOutField04 = ''       
                                   
                           -- Enable disable field          
                           SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr08 = '' -- QTY          
                
                           -- Position cursor          
                           IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                           IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                           IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                           IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          

                           SET @cOutField08 = @cExtendedinfo --(yeekung07)                
                           
                           -- Go to next screen          
                           SET @nScn = @nScn + 5          
                           SET @nStep = @nStep + 5          
                      
                           GOTO Quit          
                        END          
                                
                        SET @cOutField01 = @cDropIDType          
                        SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)          
                        SET @cOutField03 = @cOrderKey          
                        SET @cOutField04 = ''          
             
                        SET @cOutField05 = @nTotalPickedQty          
                        SET @cOutField06 = @nTotalScannedQty        
                        SET @cOutField07 = @cExtendedinfo            
                     END          
                  END           
               END          
            END          
         END          
      END          
      ELSE          
      BEGIN          
         SET @nTotalScannedQty = ISNULL(@nTotalScannedQty,0)  + 1         
                 
         --(cc01)        
         IF @cScanCTSCN <> ''                      
    BEGIN                  
            -- Get PackInfo          
            SET @cCartonType = ''          
            SET @cWeight = ''          
            SET @cCube = ''          
            SET @cRefNo = ''  
            SET @cOrderKey = @cOrderKeyOut  
                                   
            --set default Value        
            SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
            SET @cOutField02 = ''        
            SET @cOutField03 = ''        
            SET @cOutField04 = ''        
                    
                                   
            -- Enable disable field          
            SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr08 = '' -- QTY          
                
            -- Position cursor          
            IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
            IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
            IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
            IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
           
            SET @cOutField08 = @cExtendedinfo --(yeekung07)                

            -- Go to next screen          
            SET @nScn = @nScn + 5          
            SET @nStep = @nStep + 5          
                      
            GOTO Quit          
         END            
          
         IF @cTrackNoFlag = '1'          
         BEGIN          
            IF @cShowTrackNoScn = '1'          
            BEGIN          
               IF @cDefaultTrackNo = '1'          
               BEGIN          
                  SET @cSuggestedTrackNo = ''        
                                
                  IF @cUseUdf04AsTrackNo = '1'        
                     SELECT @cSuggestedTrackNo = UserDefine04          
                     FROM dbo.Orders WITH (NOLOCK)          
                     WHERE StorerKey = @cStorerKey          
                     AND OrderKey = @cOrderKeyOut          
                  ELSE                                  
                     SELECT @cSuggestedTrackNo = TrackingNo        
                     FROM dbo.Orders WITH (NOLOCK)          
                     WHERE StorerKey = @cStorerKey          
                     AND OrderKey = @cOrderKeyOut          
          
                  SET @cOrderKey = @cOrderKeyOut          
               END          
          
               SET @cOutField01 = @cOrderKey          
               SET @cOutfield02 = @cSuggestedTrackNo          
          
             SET @nScn = @nScn + 4          
               SET @nStep = @nStep + 4          
            END   
            ELSE          
            BEGIN   
               SET @cOrderKey = @cOrderKeyOut  
               SET @cOutField01 = @cDropIDType          
               SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)          
               SET @cOutField03 = @cOrderKey          
               SET @cOutField04 = ''          
          
               SET @cOutField05 = @nTotalPickedQty          
               SET @cOutField06 = @nTotalScannedQty          
            END          
         END          
         ELSE          
         BEGIN          
          --(cc01)        
            IF @cScanCTSCN <> ''                      
            BEGIN   
               -- Get PackInfo          
               SET @cCartonType = ''          
               SET @cWeight = ''          
               SET @cCube = ''          
               SET @cRefNo = ''   
               SET @cOrderKey = @cOrderKeyOut  
                                   
               --set default Value        
               SET @cOutField07 = CASE WHEN @cDefaultCtnType <> '' THEN @cDefaultCtnType ELSE '' END        
               SET @cOutField02 = ''        
               SET @cOutField03 = ''        
               SET @cOutField04 = ''         
                                   
               -- Enable disable field          
               SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr08 = '' -- QTY          
                
               -- Position cursor          
               IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
               IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
               IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
               IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
            
               SET @cOutField08 = @cExtendedinfo --(yeekung07)                
            
               -- Go to next screen          
               SET @nScn = @nScn + 5          
               SET @nStep = @nStep + 5          
                      
               GOTO Quit          
            END            
                    
            -- loop same screen          
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno          
             AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5'          
               AND Orderkey = @cOrderkey)                   --(Kc03)          
            BEGIN          
               -- sku fully scanned for the order          
               SET @cSKU = ''          
            END        
                      
            SET @cOutField01 = @cDropIDType          
            SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)          
            SET @cOutField03 = @cOrderKey          
            SET @cOutField04 = ''          
            SET @cOutField07 = @cExtendedinfo --(yeekung01)  
          
          
            SET @cOutField05 = @nTotalPickedQty          
            SET @cOutField06 = @nTotalScannedQty          
          
          
         END          
      END          
   END          
          
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
      SET @cInField01  = ''          
          
      -- Remember the current scn & step          
      SET @nScn = @nScn + 1   --ESC screen          
      SET @nStep = @nStep + 1          
          
   END          
   GOTO Quit          
          
   Step_2_Fail:          
   BEGIN          
         SET @cOutField01 = @cDropIDType          
         SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)          
         SET @cOutField03 = @cOrderKey          
         SET @cOutField04 = ''          
   END          
END          
GOTO Quit          
          
--/********************************************************************************          
--Step 3. screen = 3912          
--   ToteNo:          
--   TOTENo   (Field01, display)          
--   Orderkey:          
--   Orderkey (Field02, display)          
--   SKU/UPC:          
--   SKU/UPC  (Field03, input)          
--********************************************************************************/          
--Step_3:          
--BEGIN          
--   IF @nInputKey = 1 -- ENTER          
--   BEGIN          
--      -- Screen mapping          
--      SET @cSku    = @cInField03          
--          
--      -- Check If SKU exists in TOTE (james06)          
--      IF NOT EXISTS (SELECT 1          
--         FROM dbo.Pickdetail PD WITH (NOLOCK)          
--         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
--         JOIN DROPID DI WITH (NOLOCK) ON pd.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY          
--         WHERE O.StorerKey = @cStorerKey          
--            AND O.Status NOT IN ('9', 'CANC')          
--        AND PD.Status = '5'          
--            AND PD.DropID = @cToteNo          
--            AND PD.SKU = @cSku)          
--      BEGIN          
--         SET @nErrNo = 71445          
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID SKU'          
--         GOTO Step_3_Fail          
--      END          
--          
--      -- (james04)          
--      -- Check total picked & unshipped qty for this SKU          
--      SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)          
--      FROM dbo.Pickdetail PD WITH (NOLOCK)          
--      JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
--      JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY          
--      WHERE O.StorerKey = @cStorerKey          
--         AND O.Status NOT IN ('9', 'CANC')          
--         AND PD.Status = '5'          
--         AND PD.DropID = @cToteNo          
--         AND PD.SKU = @cSku          
--          
--      -- Check total packed & unshipped qty for this SKU          
--      SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)          
--      FROM dbo.Packdetail PD WITH (NOLOCK)          
--      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo          
--     JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey          
--      JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY          
--      WHERE O.StorerKey = @cStorerKey          
--         AND O.Status NOT IN ('9', 'CANC')          
--         AND PD.DropID = @cToteNo          
--         AND PD.SKU = @cSku          
--          
--      IF @nSKU_Picked_TTL > @nSKU_Packed_TTL          
--      BEGIN          
--         EXEC rdt.rdt_EcommDispatch_Confirm          
--            @nMobile       = @nMobile,          
--            @cPrinter      = @cPrinter,          
--            @cLangCode     = @cLangCode,          
--            @nErrNo        = @nErrNo OUTPUT,          
--            @cErrMsg       = @cErrMsg OUTPUT,          
--            @cOrderkey     = @cOrderkey OUTPUT,          
--            @cStorerKey    = @cStorerKey,          
--            @cSku          = @cSku,          
--            @cToteno       = @cToteNo,          
--            @cDropIDType   = @cDropIDType,          
--            @cPrinter_Paper = @cPrinter_Paper,  -- (Vicky01)          
--            @cPrevOrderkey = @cOrderkey,         --(Kc03)          
--            @nFunc         = @nFunc,            --(Kc06)          
--        @cFacility     = @cFacility,        --(Kc06)          
--            @cUserName     = @cUserName         --(Kc06)          
--          
--         IF @nErrno <> 0          
--         BEGIN          
--           SET @nErrNo = @nErrNo          
--           SET @cErrMsg = @cErrMsg          
--           GOTO Step_3_Fail          
--         END          
--      END          
--      ELSE          
--      BEGIN          
--         SET @nErrNo = 69912          
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Qty Exceeded'          
--         GOTO Step_3_Fail          
--      END          
--          
--      /****************************          
--       Prepare Next Screen          
--      ****************************/          
--      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno          
--         AND Mobile = @nMobile AND Status < '5')          
--      BEGIN          
--         -- tote completed, so need to return to 1st screen          
--          
--         -- Check if all SKU in this tote picked and packed (james01)          
--         -- Check total picked & unshipped qty          
--         SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)          
--         FROM dbo.Pickdetail PD WITH (NOLOCK)          
--         JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey          
--         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY          
-- WHERE O.StorerKey = @cStorerKey          
--            AND O.Status NOT IN ('9', 'CANC')          
--            AND PD.Status = '5'          
--            AND PD.DropID = @cToteNo          
--          
--         -- Check total packed & unshipped qty          
--         SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)          
--         FROM dbo.Packdetail PD WITH (NOLOCK)          
--         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo          
--         JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey          
--         JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY          
--         WHERE O.StorerKey = @cStorerKey          
--            AND O.Status NOT IN ('9', 'CANC')          
--            AND PD.DropID = @cToteNo          
--          
--         -- Close DropID when pick & pack qty matches          
--         IF @nSKU_Picked_TTL <> @nSKU_Packed_TTL          
--         BEGIN          
--            SET @cSKU = ''          
--          
--            SET @cOutField01 = @cToteNo          
--            SET @cOutField02 = @cOrderkey          
--            SET @cOutField03 = ''--@cSku  -- (Vicky02)          
--         END          
--         ELSE          
--         BEGIN          
--            --(KC04) - start          
--            UPDATE dbo.DROPID WITH (Rowlock)          
--            SET   Status = '9'          
--            WHERE DropID = @cToteNo          
--            AND   Status < '9'          
--          
--            IF @@ERROR <> 0          
--            BEGIN          
--               SET @nErrNo = 69901          
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'          
--               GOTO Step_2_Fail          
--            END          
--            --(Kc04) - end          
--          
--            -- (Shong01)          
--          EXEC [dbo].[nspInsertWCSRouting]          
--             @cStorerKey          
--            ,@cFacility          
--            ,@cToteNo          
--            ,'ECOMM_DSPT'          
--            ,'D'          
--            ,''          
--            ,@cUserName          
--            ,0          
--            ,@b_Success          OUTPUT          
--            ,@nErrNo             OUTPUT    
--            ,@cErrMsg   OUTPUT          
--          
--            IF @nErrNo <> 0          
--            BEGIN     
--               SET @nErrNo = @nErrNo          
--               SET @cErrMsg = @cErrMsg  --rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdWCSRouteFail'          
--               GOTO Step_3_Fail          
--            END          
--          
--            DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName          
--          
--            IF @@ERROR <> 0          
--            BEGIN          
--               ROLLBACK TRAN          
--          
--               SET @nErrNo = 71442          
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DelEcomLogFail'          
--               GOTO Step_2_Fail          
--            END          
--          
--            SET @cOutField01 = ''          
--            SET @cToteNo      = ''          
--            SET @cDropIDType  = ''          
--            SET @cOrderkey   = ''          
--            SET @cSku         = ''          
--            SET @nScn = @nScn - 2          
--            SET @nStep = @nStep - 2          
--         END          
--      END          
--    ELSE          
--      BEGIN          
--         -- loop same screen          
--         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno          
--            AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5')          
--         BEGIN          
--            -- sku fully scanned for the tote          
--            SET @cSKU = ''          
--         END          
--          
--         SET @cOutField01 = @cToteNo          
--         SET @cOutField02 = @cOrderkey          
--         SET @cOutField03 = ''--@cSku  -- (Vicky02)          
--      END          
--   END          
--          
--   IF @nInputKey = 0 -- ESC          
--   BEGIN          
--      SET @cOutField01 = ''          
--      SET @cOutField02 = ''          
--      SET @cOutField03 = ''          
--      SET @cOutField04 = ''          
--      SET @cOutField05 = ''          
--      SET @cOutField06 = ''          
--      SET @cOutField07 = ''          
--      SET @cOutField08 = ''          
--      SET @cOutField09 = ''          
--      SET @cOutField10 = ''          
--      SET @cOutField11 = ''          
--      SET @cInField01  = ''          
--          
--      -- Remember the current scn & step          
--      SET @nPrevScn = @nScn          
--      SET @nPrevStep = @nStep          
--          
--      SET @nScn = @nScn + 1   --ESC screen          
--      SET @nStep = @nStep + 1          
--   END          
--   GOTO Quit          
--          
--   Step_3_Fail:          
--   BEGIN          
--      SET @cOutField03 = ''          
--   END          
--END          
--GOTO Quit          
          
/********************************************************************************          
Step 3. screen = 3913          
   RSN: REASONCODE (Field01, display)          
********************************************************************************/          
Step_3:          
BEGIN          
   IF @nInputKey = 1 -- ENTER/ESC          
   BEGIN          
      -- Screen mapping          
      SET @cReasonCode    = @cInField01          
          
      --When Reason is blank          
      IF @cReasonCode = ''          
      BEGIN          
         SET @nErrNo = 90463          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason Req          
         GOTO Step_3_Fail          
      END          
          
      IF NOT EXISTS (SELECT 1 FROM dbo.TaskManagerReason WITH (NOLOCK) WHERE TaskManagerReasonKey = @cReasonCode)          
      BEGIN          
         SET @nErrNo = 90464          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Reason'          
         GOTO Step_3_Fail          
      END          
          
--      IF NOT EXISTS( SELECT TOP 1 1          
--                      FROM CodeLKUP WITH (NOLOCK)          
--                      WHERE ListName = 'RDTTASKRSN'    
--                      AND StorerKey = @cStorerKey          
--                      AND Code = @cTTMTaskType          
--                      AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))          
--      BEGIN          
--        SET @nErrNo = 90465          
--        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason          
--        GOTO Step_3_Fail          
--      END          
          
          
      SELECT @cRSN_Descr = Descr FROM dbo.TaskManagerReason WITH (NOLOCK)          
      WHERE TaskManagerReasonKey = @cReasonCode          
          
      SELECT @cModuleName = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) WHERE Message_id = @nFunc          
          
      SET @cAlertMessage = 'Discontinue from EComm Dispatch Task for Tote: ' + @cToteNo          
          
      IF @cOrderkey <> ''          
         SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' Orderkey: ' + ISNULL(@cOrderkey,'')  + ISNULL(@c_NewLineChar,'')          
      IF @cSku <> ''          
         SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' SKU: ' + ISNULL(@cSku,'')  + ISNULL(@c_NewLineChar,'')          
          
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' UID: ' + ISNULL(@cUserName,'')  + ISNULL(@c_NewLineChar,'')          
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' MOB: ' + CAST(@nMobile AS NVARCHAR( 5)) + ISNULL(@c_NewLineChar,'')          
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' DateTime: ' + CONVERT(CHAR,GETDATE(), 103) + ISNULL(@c_NewLineChar,'')          
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' RSN: ' + ISNULL(@cReasonCode,'') + ISNULL(@c_NewLineChar,'')          
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'') + ' RSN Desc: ' + ISNULL(@cRSN_Descr,'')  + ISNULL(@c_NewLineChar,'')          
      SET @cAlertMessage = ISNULL(RTRIM(@cAlertMessage),'')          
          
      SELECT @b_Success = 1          
      EXECUTE dbo.nspLogAlert          
       @c_ModuleName   = @cModuleName,          
       @c_AlertMessage = @cAlertMessage,          
     @n_Severity     = 0,          
       @b_success      = @b_Success OUTPUT,          
       @n_err          = @nErrNo OUTPUT,          
       @c_errmsg       = @cErrmsg OUTPUT          
          
      IF NOT @b_Success = 1          
      BEGIN          
        GOTO Step_3_Fail          
     END          
          
      --BEGIN TRAN          
          
      -- set status to indicate error during processing          
      DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
      SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)           
      WHERE ToteNo = @cToteno           
      AND   Status IN ('0','1')          
      AND   AddWho = @cUserName          
     OPEN CUR_UPD          
      FETCH NEXT FROM CUR_UPD INTO @nRowRef          
      WHILE @@FETCH_STATUS <> -1          
      BEGIN          
          
         UPDATE rdt.rdtECOMMLog WITH (ROWLOCK)          
         SET   Status = '5',          
               ErrMsg = @cAlertMessage          
         WHERE RowRef = @nRowRef          
          
         IF @@ERROR <> 0          
         BEGIN          
            CLOSE CUR_UPD          
            DEALLOCATE CUR_UPD          
            SET @nErrNo = 90466          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPDECOMLOGFail          
            GOTO Step_3_Fail          
         END          
          
         FETCH NEXT FROM CUR_UPD INTO @nRowRef      
      END          
      CLOSE CUR_UPD          
      DEALLOCATE CUR_UPD          
          
      --UPDATE rdt.rdtECOMMLog WITH (ROWLOCK)          
      --SET   Status = '5',          
      --      ErrMsg = @cAlertMessage          
--WHERE ToteNo = @cToteNo          
      --AND   Status IN ('0','1')          
      --AND   AddWho = @cUserName          
          
      --IF @@ERROR <> 0          
      --BEGIN          
      --   --ROLLBACK TRAN          
     --   SET @nErrNo = 90466          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDECOMLOGFail'          
      --   GOTO Step_3_Fail          
      --END          
          
          
      -- Update packdetail.qty = 0 with those orders which start packing halfway          
      -- so that later they can pack again after the tote comes back from QC          
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR          
      SELECT DISTINCT OrderKey, SKU          
      FROM rdt.rdtECOMMLog WITH (NOLOCK)          
      WHERE ToteNo = @cToteNo          
      AND   AddWho = @cUserName          
      AND   EXISTS(SELECT 1 FROM rdt.rdtECOMMLog ECOM2  WITH (NOLOCK)          
             WHERE ECOM2.SCANNEDQTY <> ECOM2.ExpectedQty          
             AND   ECOM2.Orderkey = rdt.rdtECOMMLog.Orderkey          
             AND   ECOM2.ToteNo = @cToteNo          
             AND   ECOM2.AddWho = @cUserName)          
          
      OPEN CUR_LOOP          
      FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cSKU          
      WHILE @@FETCH_STATUS <> - 1          
      BEGIN          
         -- Get pickslipno          
         SET @cPickSlipNo = '' -- SOS# 326971          
         SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK)          
         WHERE StorerKey = @cStorerKey          
            AND OrderKey = @cOrderKey          
            AND Status = '0' -- SOS# 326971          
          
         SELECT @cPickSlipNo = ISNULL(RTRIM(@cPickSlipNo),'') -- SOS# 326971          
          
         IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)          
                    WHERE PickSlipNo = @cPickSlipNo          
                    AND SKU = @cSKU          
                    AND StorerKey = @cStorerKey          
                    AND QTY > 0)          
         BEGIN          
            -- put ArchiveCop here to avoid delete packdetail line when qty = 0 by trigger          
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET          
               QTY = 0, ArchiveCop = NULL          
            WHERE PickSlipNo = @cPickSlipNo          
            AND SKU = @cSKU          
            AND StorerKey = @cStorerKey          
            AND QTY > 0          
          
            IF @@ERROR <> 0          
            BEGIN          
               --ROLLBACK TRAN          
               CLOSE CUR_LOOP          
               DEALLOCATE CUR_LOOP          
               SET @nErrNo = 90467          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReversePACFail'          
               GOTO Step_3_Fail          
            END          
         END          
          
         FETCH NEXT FROM CUR_LOOP INTO @cOrderKey, @cSKU          
      END          
      CLOSE CUR_LOOP          
      DEALLOCATE CUR_LOOP          
          
      -- Delete what ever for this tote which is not complete by orders          
      DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR           
      SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)           
      WHERE ToteNo = @cToteno           
      AND Status = '5'          
      AND   AddWho = @cUserName          
      OPEN CUR_DEL          
      FETCH NEXT FROM CUR_DEL INTO @nRowRef          
      WHILE @@FETCH_STATUS <> -1          
      BEGIN          
          
         DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef          
         IF @@ERROR <> 0          
         BEGIN          
            CLOSE CUR_DEL          
            DEALLOCATE CUR_DEL          
            SET @nErrNo = 90468          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
            GOTO Step_3_Fail          
         END          
          
         FETCH NEXT FROM CUR_DEL INTO @nRowRef          
      END          
      CLOSE CUR_DEL          
      DEALLOCATE CUR_DEL          
          
      --DELETE FROM rdt.rdtECOMMLog          
      --WHERE ToteNo = @cToteNo          
 --AND Status = '5'          
      --AND AddWho = @cUserName          
          
      --IF @@ERROR <> 0          
      --BEGIN          
      --   --ROLLBACK TRAN          
      --   SET @nErrNo = 90468          
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDECOMLOGFail'          
      --   GOTO Step_3_Fail          
      --END          
          
      --COMMIT TRAN          
          
      /****************************          
       Prepare Next Screen          
      ****************************/          
      SET @cOutField01 = ''          
      SET @cToteNo = ''          
      SET @cDropIDType = ''          
      SET @cSKU = ''          
      SET @cOrderkey = ''          
      SET @nScn = @nScn - 2          
      SET @nStep = @nStep - 2          
                
      IF @cDefaultCursor <> ''                
         EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor          
   END          
          
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      SET @cOutField01 = @cDropIDType          
      SET @cOutField02 = @cToteNo --'' --@cSku          
      SET @cOutField03 = @cOrderKey          
      SET @cOutField04 = ''          
          
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1          
   END          
          
   GOTO Quit          
          
   Step_3_Fail:          
   BEGIN          
      SET @cOutField01 = ''          
   END          
END          
GOTO Quit          
          
/********************************************************************************          
Step 4. screen = 3914          
   More Tote To be Scanned, Continue?          
   TOTENo   (Field01, display)          
   TOTENo   (Field02, display)          
   TOTENo   (Field03, display)          
   TOTENo   (Field04, display)          
   TOTENo   (Field05, display)          
   TOTENo   (Field06, display)          
   Option   (Field07, input)          
********************************************************************************/          
Step_4:          
BEGIN          
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cOption    = @cInField07          
          
      --When Option is blank          
      IF @cOption = ''          
      BEGIN          
         SET @nErrNo = 90469          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Req          
    GOTO Step_4_Fail          
      END          
          
      IF @cOption <> '1' AND @cOption <> '9'          
      BEGIN          
         SET @nErrNo = 90470          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option          
         GOTO Step_4_Fail          
      END          
          
      IF @cOption = '1' -- continue          
      BEGIN          
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)          
          
         SELECT @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()          
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)   
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey          
         WHERE PK.DROPID = @cToteNo          
           --AND PK.Status = '5' -- (ChewKP04)          
           AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P') -- (ChewKP04)                  
           AND PK.CaseID = ''          
           AND PK.Qty > 0 -- SOS# 329265          
           --AND PK.PickSlipNo = @cPickSlipNo          
           AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',         
                          'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C','0')   -- (Chee01) -- (ChewKP09) -- (james07) -- (james08)   --(yeekung01)        
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
         GROUP BY PK.OrderKey, PK.SKU          
          
         IF @@ROWCOUNT = 0 -- No data inserted          
         BEGIN          
            SET @nErrNo = 90471          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'          
            GOTO Step_4_Fail          
         END          
          
         IF @@ERROR <> 0          
         BEGIN          
            SET @nErrNo = 90472          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Ins EcommFail'          
            GOTO Step_4_Fail          
         END          
      END -- option = '1'          
          
      /****************************          
       prepare next screen variable          
      ****************************/          
      IF @cOption = '1'          
      BEGIN          
         SET @cOutField01 = @cToteno          
         SET @cOutField02 = ''          
         SET @cOutField03 = ''          
          
         SELECT @cOrderkey = MIN(Orderkey)          
         FROM  rdt.rdtECOMMLog WITH (NOLOCK)          
         WHERE ToteNo = @cToteNo          
         AND   Status < '5'          
         AND   Mobile = @nMobile          
          
         SET @cOutField01 = @cDropIDType          
         SET @cOutField02 = @cToteNo --'' --@cSku          
         SET @cOutField03 = @cOrderKey          
         SET @cOutField04 = ''          
          
         SET @nScn = @nScn - 2          
         SET @nStep = @nStep - 2          
          
      END -- @cOption = '1'          
      ELSE IF @cOption = '9' -- park tote          
      BEGIN          
         SET @cOutField01 = ''     
         SET @cOutField02 = ''          
         SET @cOutField03 = ''          
                   
         SET @nScn = @nScn + 1          
         SET @nStep = @nStep + 1          
      END          
   END -- inputkey = 1          
          
--   IF @nInputKey = 0 -- ESC          
--   BEGIN          
--      SET @cOutField01 = ''          
--      SET @cOutField02 = ''          
--      SET @cOutField03 = ''          
--      SET @cOutField04 = ''          
--      SET @cOutField05 = ''          
--      SET @cOutField06 = ''          
--      SET @cOutField07 = ''          
--      SET @cOutField08 = ''          
--      SET @cOutField09 = ''          
--      SET @cOutField10 = ''          
--      SET @cOutField11 = ''          
--      SET @cInField01  = ''          
--          
--      SET @nScn = @nScn - 4   --ESC screen          
--      SET @nStep = @nStep - 4          
--   END          
   GOTO Quit          
          
   Step_4_Fail:          
   BEGIN          
      SET @cOutField07 = ''          
   END          
END          
GOTO Quit          
        
/********************************************************************************          
Step 5. screen = 3914          
   PARK TOTE (display)          
********************************************************************************/          
Step_5:          
BEGIN          
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC          
   BEGIN       
      /****************************          
       Prepare Next Screen          
     ****************************/          
      SET @cOutField01 = ''          
      SET @cToteNo = ''          
      SET @cDropIDType = ''          
      SET @cSKU = ''          
      SET @cOrderkey = ''          
      SET @nScn = @nScn - 4          
      SET @nStep = @nStep - 4          
                
      IF @cDefaultCursor <> ''                
         EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor          
   END          
END          
GOTO Quit          
          
/********************************************************************************          
Step 6. screen = 3915          
   OrderKey (field01)          
   TrackNo  (field02, input)          
********************************************************************************/          
Step_6:          
BEGIN          
   IF @nInputKey = 1          
   BEGIN          
          
          
      SET @cTrackNo = ISNULL(RTRIM(@cInField02),'' )          
          
        
      IF @cTrackNo = ''          
      BEGIN          
         SET @nErrNo = 90473          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'TrackNoReq'          
         GOTO Step_6_Fail          
      END          
          
      SET @cShipperKey = ''          
      SET @cOrderTrackNo = ''          
              
      IF @cUseUdf04AsTrackNo = '1'        
         SELECT @cShipperKey = ShipperKey,          
                @cOrderTrackNo = UserDefine04          
         FROM dbo.ORDERS WITH (NOLOCK)          
         WHERE Orderkey = @cOrderkey          
         AND Storerkey = @cStorerkey          
      ELSE        
         SELECT @cShipperKey = ShipperKey,          
                @cOrderTrackNo = TrackingNo        
         FROM dbo.ORDERS WITH (NOLOCK)          
         WHERE Orderkey = @cOrderkey          
         AND Storerkey = @cStorerkey        
              
      SET @cTrackRegExp = ''          
      SELECT @cTrackRegExp = Notes1 FROM dbo.Storer WITH (NOLOCK)          
      WHERE Storerkey = @cShipperKey          
          
      IF ISNULL(@cTrackRegExp,'') <> ''          
      BEGIN          
          
         IF rdt.rdtIsRegExMatch(ISNULL(RTRIM(@cTrackRegExp),''),ISNULL(RTRIM(@cTrackNo),'')) <> 1          
         BEGIN          
               SET @nErrNo = 90474          
      SET @cErrMsg = rdt.rdtgEtmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo          
               EXEC rdt.rdtSetFocusField @nMobile, 1          
               GOTO Step_6_Fail          
         END          
      END          
          
      IF EXISTS (SELECT 1 FROM RDT.RDTTrackLog WITH (NOLOCK)          
                 WHERE TrackNo = ISNULL(RTRIM(@cTrackNo),''))          
      BEGIN          
         SET @nErrNo = 90475          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoInUsed          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Step_6_Fail          
      END          
          
            
          
      IF EXISTS (SELECT 1 FROM dbo.ORDERS WITH  (NOLOCK)          
                 WHERE Storerkey =  @cStorerKey          
                 AND (( @cUseUdf04AsTrackNo = '1' AND USerDefine04 = ISNULL( @cTrackNo, '')) OR         
                      ( TrackingNo = ISNULL(@cTrackNo, '')))        
                 AND Orderkey <> @cOrderkey)          
      BEGIN          
         SET @nErrNo = 90476          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv TrackNo'          
         GOTO Step_6_Fail          
      END          
          
          
      IF @cExtendedUpdateSP <> ''            
      BEGIN            
            
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
          BEGIN            
             SET @cTrackNoFlag = '0'            
             SET @cOrderKeyOut = ''            
            
             INSERT INTO @tExtUpd (Variable, Value) VALUES         
               ('@cCube',        @cCube),        
               ('@cWeight',      @cWeight),        
               ('@cRefNo',       @cRefNo),         
               ('@cWaveKey',     @cWaveKey),        
               ('@cLoadKey',     @cLoadKey),         
               ('@cOption',      @cOption)               
                            
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                            
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                  @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd '                           
             SET @cSQLParam =                        
                '@nMobile        INT, ' +                            
                '@nFunc          INT, ' +                            
                '@cLangCode      NVARCHAR( 3),  ' +                            
                '@cUserName      NVARCHAR( 18), ' +                            
                '@cFacility      NVARCHAR( 5),  ' +                            
                '@cStorerKey     NVARCHAR( 15), ' +                            
                '@cToteNo        NVARCHAR( 20), ' +                            
                '@cSKU           NVARCHAR( 20), ' +                            
                '@nStep          INT,           ' +                            
                '@cPickSlipNo    NVARCHAR( 10), ' +                            
                '@cOrderkey      NVARCHAR( 10), ' +                            
                '@cTrackNo       NVARCHAR( 20), ' +                          
                '@cTrackNoFlag   NVARCHAR( 1) OUTPUT,  ' +                            
                '@cOrderKeyOut   NVARCHAR( 10)OUTPUT,  ' +                            
                '@nErrNo         INT           OUTPUT, ' +                            
                '@cErrMsg        NVARCHAR( 20) OUTPUT,'   +                        
                '@cCartonType    NVARCHAR( 20),'+          
                '@cSerialNo      NVARCHAR( 30), ' +               
        '@nSerialQTY     INT,'  +                
                '@tExtUpd        VariableTable READONLY '            
                            
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                            
             @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd                               
                           
             IF @nErrNo <> 0            
                GOTO Step_6_Fail            
          END            
      END            
          
          
                
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno          
                     AND Mobile = @nMobile AND Status < '5' )          
      BEGIN          
                   
         IF ISNULL(RTRIM(@cToteNo),'')  <> ''          
         BEGIN          
            SET @cOutField01 = ''          
            SET @cOutField02 = '' -- (ChewKP01)           
            SET @cOutField03 = '' -- (ChewKP01)           
             
            SET @nScn = @nScn - 5          
            SET @nStep = @nStep - 5          
         END          
         ELSE IF ISNULL(RTRIM(@cLoadKey),'')  <> '' OR ISNULL(RTRIM(@cWaveKey),'')  <> ''           
         BEGIN          
            SET @nOrderCount = 0           
            SET @nRefCount = 0           
                      
            IF ISNULL(RTRIM(@cLoadKey),'')  <> ''          
            BEGIN          
               SELECT @nRefCount = Count(OrderKey)          
               FROM dbo.LoadPlanDetail WITH (NOLOCK)          
               WHERE LoadKey = @cLoadKey          
                         
               SELECT @nOrderCount = Count( Distinct O.OrderKey)           
               FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)          
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = ECOMM.OrderKey          
               WHERE ECOMM.OrderKey IN (SELECT OrderKey FROM dbo.LoadplanDetail WITH (NOLOCK)          
                                        WHERE LoadKey = @cLoadKey )           
                         
                         
            END          
            ELSE           
            BEGIN          
               SELECT @nRefCount = Count(OrderKey)          
               FROM dbo.WaveDetail WITH (NOLOCK)          
               WHERE WaveKey = @cWaveKey          
                         
               SELECT @nOrderCount = Count( Distinct O.OrderKey)           
               FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)   
               INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = ECOMM.OrderKey          
               WHERE ECOMM.OrderKey IN (SELECT OrderKey FROM dbo.WaveDetail WITH (NOLOCK)          
                                        WHERE WaveKey = @cWaveKey )           
            END          
                      
                      
            IF ISNULL(@nRefCount,0 )  = ISNULL(@nOrderCount,0)           
            BEGIN          
               SET @cOutField01 = ''          
               SET @cOutField02 = ''           
               SET @cOutField03 = ''          
                
               SET @nScn = @nScn - 5          
               SET @nStep = @nStep - 5          
            END          
            ELSE          
            BEGIN          
               SELECT Top 1 @cLastOrderKey = OrderKey          
               FROM rdt.rdtECOMMLog WITH (NOLOCK)          
               WHERE   EditWho = @cUserName          
               AND Status = '9'          
               ORDER BY EditDate DESC        
        
               IF ISNULL(RTRIM(@cWavekey),'')  <> '' OR ISNULL(RTRIM(@cLoadKey),'')  <> ''           
   BEGIN           
                  SET @nTotalPickedQty = 0           
                  SET @nTotalScannedQty = 0           
        
                  SELECT @nTotalPickedQty  = SUM(1),          
                         @nTotalScannedQty = SUM(CASE WHEN O.[Status] = '5' THEN 1 ELSE 0 END)          
                  FROM dbo.WaveDetail WD WITH (NOLOCK)          
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = WD.OrderKey          
                  WHERE (( @cWavekey <> '' AND O.UserDefine09 = @cWaveKey) OR ( @cLoadKey <> '' AND O.LoadKey = @cLoadKey))        
                  AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )         
               END          
               ELSE        
               BEGIN        
                  SET @nTotalScannedQty = 0          
                  SELECT @nTotalScannedQty = SUM(QTY)          
                  FROM dbo.PickDetail PD WITH (NOLOCK)          
                  INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
                  WHERE PD.DropID = @cToteNo          
                  AND (PD.Status IN  ('3','5') OR PD.ShipFlag = 'P')          
                  AND PD.CaseID <> ''          
                  AND O.LoadKey = @cLoadKey          
                  AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )         
                  AND PH.PickHeaderKey = @cPickSlipNo         
          
                  SELECT @nTotalPickedQty  = SUM(ExpectedQty)          
                  FROM rdt.rdtECOMMLog WITH (NOLOCK)          
                  WHERE ToteNo = @cToteNo          
                  AND Status = '0'          
                  AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END          
                  AND AddWho = @cUserName          
               END        
          
              
               -- Back to SKU Screen          
               SET @cOutField01 = @cDropIDType          
               SET @cOutField02 = @cToteNo          
               SET @cOutField03 = @cLastOrderKey--@cOrderKey          
               SET @cOutField04 = ''          
               SET @cOutField05 = @nTotalPickedQty          
               SET @cOutField06 = @nTotalScannedQty          
                
               SET @nScn = @nScn - 4          
               SET @nStep = @nStep - 4          
            END          
                      
         END          
      END          
      ELSE          
      BEGIN          
         SELECT Top 1 @cLastOrderKey = OrderKey          
         FROM rdt.rdtECOMMLog WITH (NOLOCK)          
         WHERE   EditWho = @cUserName          
         AND Status = '9'          
         ORDER BY EditDate DESC        
        
--         IF (ISNULL(RTRIM(@cWavekey),'')  <> '' OR ISNULL(RTRIM(@cLoadKey),'')  <> '')         
         IF (ISNULL(RTRIM(@cWavekey),'')  <> '' OR ISNULL(RTRIM(@cLoadKey),'')  <> '') AND @cToteNo = ''   --(cc01)        
         BEGIN           
            SET @nTotalPickedQty = 0           
            SET @nTotalScannedQty = 0           
        
            SELECT @nTotalPickedQty  = SUM(1),          
                     @nTotalScannedQty = SUM(CASE WHEN O.[Status] = '5' THEN 1 ELSE 0 END)          
            FROM dbo.WaveDetail WD WITH (NOLOCK)          
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = WD.OrderKey          
            WHERE (( @cWavekey <> '' AND O.UserDefine09 = @cWaveKey) OR ( @cLoadKey <> '' AND O.LoadKey = @cLoadKey))        
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )         
         END          
         ELSE        
         BEGIN        
            SET @nTotalScannedQty = 0          
            SELECT @nTotalScannedQty = SUM(QTY)          
   FROM dbo.PickDetail PD WITH (NOLOCK)          
            INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey          
            INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey          
            WHERE PD.DropID = @cToteNo          
            AND (PD.Status IN  ('3','5') OR PD.ShipFlag = 'P')          
            AND PD.CaseID <> ''          
            AND O.LoadKey = @cLoadKey          
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )         
            --AND PH.PickHeaderKey = @cPickSlipNo --(cc01)        
          
            SELECT @nTotalPickedQty  = SUM(ExpectedQty)          
            FROM rdt.rdtECOMMLog WITH (NOLOCK)          
            WHERE ToteNo = @cToteNo          
            AND Status = '0'          
            AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END          
            AND AddWho = @cUserName          
         END        
                 
         -- Back to SKU Screen          
         SET @cOutField01 = @cDropIDType          
         SET @cOutField02 = @cToteNo          
         SET @cOutField03 = @cLastOrderKey--@cOrderKey          
         SET @cOutField04 = ''          
         SET @cOutField05 = @nTotalPickedQty          
         SET @cOutField06 = @nTotalScannedQty          
          
         SET @nScn = @nScn - 4          
         SET @nStep = @nStep - 4          
      END          
          
--      SET @cNextOrderKey  = ''          
--          
--      SELECT Top 1 @cNextOrderKey = OrderKey          
--      FROM rdt.rdtECOMMLog WITH (NOLOCK)          
--      WHERE ToteNo = @cToteNo          
--      AND Status = '9'          
--      AND OrderKey > @cOrderKey          
--      GROUP BY OrderKey          
--      ORDER BY OrderKey          
          
--      IF @cNextOrderKey = ''          
--      BEGIN          
--         DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName          
--          
--         IF @@ERROR <> 0          
--         BEGIN          
--            SET @nErrNo = 90477          
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail          
--         END          
--          
--         -- Remember the current scn & step          
--         SET @cOutField01 = ''          
--          
--         SET @nScn = @nScn - 5          
--      SET @nStep = @nStep - 5          
--      END          
--      ELSE          
--      BEGIN          
--         -- Stay same screen for all Orders          
--         SET @cOrderKey = @cNextOrderKey          
--          
--         SET @cOutField01 = @cNextOrderKey          
--         SET @cOutField02 = ''          
--          
--      END          
   END          
          
--   IF @nInputKey = 0 -- ESC          
--   BEGIN          
--      SET @cOutField01 = ''          
--      SET @cOutField02 = ''          
--      SET @cOutField03 = ''          
--      SET @cOutField04 = ''          
--     SET @cOutField05 = ''          
--      SET @cOutField06 = ''          
--      SET @cOutField07 = ''          
--      SET @cOutField08 = ''          
--      SET @cOutField09 = ''          
--      SET @cOutField10 = ''          
--      SET @cOutField11 = ''          
--      SET @cInField01  = ''          
--          
--      -- Remember the current scn & step          
--      SET @nScn = @nScn + 1   --ESC screen          
--      SET @nStep = @nStep + 1          
--          
--   END          
   GOTO Quit          
          
   Step_6_Fail:          
   BEGIN          
      SET @cOutField01 = @cOrderKey          
      SET @cOutField02 = ''          
   END          
          
END          
GOTO Quit          
        
/********************************************************************************                   
Step 7 screen = 3916                       
   Carton Type (field07, input)          
   Cube        (field02, input)          
   Weight      (field03, input)          
   RefNo       (field04, input)                       
********************************************************************************/                          
Step_7:                          
BEGIN                          
   IF @nInputKey = 1                          
   BEGIN                         
      --SET @cCartonType =@cInField07                   
              
      SET @cCartonType  = CASE WHEN @cFieldAttr07 = '' THEN @cInField07 ELSE @cOutField07 END          
      SET @cCube        = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END          
      SET @cWeight      = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END          
      SET @cRefNo       = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END             
              
      ---- Carton type          
      IF @cFieldAttr07 = ''        
      BEGIN        
       IF ISNULL(@cCartonType,'')=''                      
         BEGIN                      
            SET @nErrNo = 90493                          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv TrackNo'                          
            GOTO Step_7_Fail                        
         END           
  
         IF NOT EXISTS (SELECT 1 FROM CARTONIZATION (NOLOCK) WHERE CARTONTYPE=@cCartonType AND CartonizationGroup = @cCartongroup)                      
         BEGIN                        
            SET @nErrNo = 90494                          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackInfoFail'                          
            GOTO Step_7_Fail                               
         END         
      END                
              
      -- Weight          
      IF @cFieldAttr03 = ''          
      BEGIN          
         -- Check blank          
         IF @cWeight = ''          
         BEGIN          
            SET @nErrNo = 90499          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight     
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END       
            SET @cOutField02 = CASE WHEN @cFieldAttr02 = '' THEN @cCube ELSE '' END  
            SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN @cRefNo ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 3         
            GOTO Quit          
         END          
          
         -- Check weight valid          
         IF @cAllowWeightZero = '1'          
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)          
         ELSE          
            SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)          
          
         IF @nErrNo = 0          
         BEGIN          
            SET @nErrNo = 90500          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight        
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END  
            SET @cOutField02 = CASE WHEN @cFieldAttr02 = '' THEN @cCube ELSE '' END  
            SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN @cRefNo ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 3       
            SET @cOutField02 = ''          
            GOTO QUIT          
         END          
  
         -- Check valid weight range    
         IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'WEIGHT', 'FLOAT', @cWeight) = 0    
         BEGIN    
            SET @nErrNo = 172053  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range  
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END  
            SET @cOutField02 = CASE WHEN @cFieldAttr02 = '' THEN @cCube ELSE '' END  
            SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN @cRefNo ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            SET @cOutField02 = ''  
            GOTO QUIT  
         END  
           
         SET @nErrNo = 0          
         SET @cOutField02 = @cWeight          
      END          
              
      -- Cube          
      IF @cFieldAttr02 = ''          
      BEGIN          
         -- Check blank          
         IF @cCube = ''          
         BEGIN          
            SET @nErrNo = 172051          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube          
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END  
            SET @cOutField03 = CASE WHEN @cFieldAttr03 = '' THEN @cWeight ELSE '' END  
            SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN @cRefNo ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 2         
            GOTO Quit          
         END          
          
         -- Check cube valid          
         IF @cAllowCubeZero = '1'          
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20)          
         ELSE          
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)          
          
         IF @nErrNo = 0          
         BEGIN          
            SET @nErrNo = 172052          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube          
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END  
            SET @cOutField03 = CASE WHEN @cFieldAttr03 = '' THEN @cWeight ELSE '' END  
            SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN @cRefNo ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            SET @cOutField03 = ''          
            GOTO QUIT          
         END          
  
         -- Check valid weight range    
         IF rdt.rdtIsValidRange( @nFunc, @cStorerKey, 'CUBE', 'FLOAT', @cCube) = 0    
         BEGIN    
            SET @nErrNo = 172054  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Range  
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END  
            SET @cOutField03 = CASE WHEN @cFieldAttr03 = '' THEN @cWeight ELSE '' END  
            SET @cOutField04 = CASE WHEN @cFieldAttr04 = '' THEN @cRefNo ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            SET @cOutField03 = ''  
            GOTO QUIT  
         END  
  
         SET @nErrNo = 0          
         SET @cOutField03 = @cCube          
      END          
                         
      -- Refno          
      IF @cFieldAttr04 = ''        
      BEGIN        
         -- Check barcode format    
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'REFNO', @cRefNo) = 0    
         BEGIN    
            SET @nErrNo = 172055    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format    
            SET @cOutField07 = CASE WHEN @cFieldAttr07 = '' THEN @cCartonType ELSE '' END  
            SET @cOutField02 = CASE WHEN @cFieldAttr02 = '' THEN @cCube ELSE '' END  
            SET @cOutField03 = CASE WHEN @cFieldAttr03 = '' THEN @cWeight ELSE '' END  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            SET @cOutField04 = ''  
            GOTO Quit    
         END    
  
         SET @cOutField04 = @cRefNo          
      END                
  
      IF @cExtendedUpdateSP <> ''                            
      BEGIN                                      
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')                            
          BEGIN                            
             SET @cTrackNoFlag = '0'                            
             SET @cOrderKeyOut = ''                     
    
             INSERT INTO @tExtUpd (Variable, Value) VALUES         
               ('@cCube',        @cCube),        
               ('@cWeight',      @cWeight),        
               ('@cRefNo',       @cRefNo),         
               ('@cWaveKey',     @cWaveKey),        
               ('@cLoadKey',     @cLoadKey),         
               ('@cOption',      @cOption)               
                            
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                            
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                  @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd '                           
             SET @cSQLParam =                            
                '@nMobile        INT, ' +                            
                '@nFunc          INT, ' +                            
                '@cLangCode      NVARCHAR( 3),  ' +                            
                '@cUserName      NVARCHAR( 18), ' +                            
                '@cFacility      NVARCHAR( 5),  ' +                         
                '@cStorerKey     NVARCHAR( 15), ' +                            
                '@cToteNo        NVARCHAR( 20), ' +                    
                '@cSKU           NVARCHAR( 20), ' +                            
                '@nStep          INT,           ' +                            
                '@cPickSlipNo    NVARCHAR( 10), ' +                            
                '@cOrderkey      NVARCHAR( 10), ' +                            
                '@cTrackNo       NVARCHAR( 20), ' +                          
                '@cTrackNoFlag   NVARCHAR( 1) OUTPUT,  ' +                            
                '@cOrderKeyOut   NVARCHAR( 10)OUTPUT,  ' +                            
                '@nErrNo         INT           OUTPUT, ' +                            
                '@cErrMsg        NVARCHAR( 20) OUTPUT,'   +                        
                '@cCartonType    NVARCHAR( 20),'+          
                '@cSerialNo      NVARCHAR( 30), ' +               
                '@nSerialQTY     INT,'  +                
                '@tExtUpd        VariableTable READONLY '            
                            
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                            
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd                          
                            
             IF @nErrNo <> 0 -- (yeekung01)                             
             BEGIN                            
                GOTO Step_7_Fail                            
             END                            
          END                      
      END                            
                      
     --(cc01)        
      IF @cExtendedInfoSP <> ''                            
      BEGIN                            
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')                            
         BEGIN                            
                            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +                            
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cLoadKey,@cWavekey,@nInputKey,@cSerialNo, @nSerialQTY,@cExtendedinfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '                          
            SET @cSQLParam =                            
               '@nMobile        INT, ' +                            
               '@nFunc          INT, ' +                            
               '@cLangCode      NVARCHAR( 3),  ' +                            
               '@nStep          INT, ' +                            
               '@cStorerKey     NVARCHAR( 15), ' +                            
               '@cToteno        NVARCHAR( 20), ' +                            
               '@cSKU           NVARCHAR( 20), ' +                            
               '@cPickSlipNo    NVARCHAR( 10), ' +                  
               '@cLoadKey       NVARCHAR( 20), ' +                  
               '@cWavekey       NVARCHAR( 20), ' +                  
               '@nInputKey      INT,           ' +          
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,           ' +                  
               '@cExtendedinfo  NVARCHAR( 20) OUTPUT, ' +                           
               '@nErrNo         INT           OUTPUT, ' +                            
               '@cErrMsg        NVARCHAR( 20) OUTPUT'                            
                            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,       
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cLoadKey,@cWavekey,@nInputKey,@cSerialNo, @nSerialQTY,@cExtendedinfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT                            
                            
            IF @nErrNo <> 0                            
               GOTO quit                            
         END                            
      END         
              
      IF @cTrackNoFlag = '1'                          
      BEGIN                          
         IF @cShowTrackNoScn = '1'                          
         BEGIN                          
   --                   SELECT Top 1 @cOrderKey = OrderKey                          
   --                     FROM rdt.rdtECOMMLog WITH (NOLOCK)                          
   --                     WHERE ToteNo = @cToteNo                          
   --                     AND Status = '9'                          
   --                     GROUP BY OrderKey                          
   --                     ORDER BY OrderKey                          
                          
            IF @cDefaultTrackNo = '1'                          
            BEGIN                          
               SET @cSuggestedTrackNo = ''        
        
               IF @cUseUdf04AsTrackNo = '1'                          
                  SELECT @cSuggestedTrackNo = UserDefine04                          
                  FROM dbo.Orders WITH (NOLOCK)                          
                  WHERE StorerKey = @cStorerKey                          
                  AND OrderKey = @cOrderKeyOut                          
               ELSE        
                  SELECT @cSuggestedTrackNo = TrackingNo        
                  FROM dbo.Orders WITH (NOLOCK)                          
                  WHERE StorerKey = @cStorerKey                          
                     AND OrderKey = @cOrderKeyOut                          
        
               SET @cOrderKey = @cOrderKeyOut                          
            END                          
                          
            SET @cOutField01 = @cOrderKey                          
            SET @cOutfield02 = @cSuggestedTrackNo                 
            SET @cOutfield03 = @cExtendedinfo        
            SET @cInField07 =''                
            SET @cFieldAttr02 =  ''   
                          
            SET @nScn = @nScn -1                          
            SET @nStep = @nStep -1                         
         END          
         ELSE                          
         BEGIN                          
            --IF @nTotalPickedQty=0 and @nTotalScannedQty=0            
            --(cc01) if not more orderKey  back to screen1        
            IF NOT EXISTS (SELECT 1          
                  FROM rdt.rdtECOMMLog WITH (NOLOCK)          
                  WHERE ToteNo = @cToteNo          
                  AND Status <> '9'          
                  --AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END          
                  AND AddWho = @cUserName )        
                  --HAVING SUM(ExpectedQty) = sum(ScannedQty)        
            BEGIN                      
               SET @cOutField01  = ''                          
               SET @cToteNo      = ''                          
               SET @cDropIDType  = ''                          
               SET @cOrderkey    = ''                          
               SET @cSku         = ''                          
                                                  
               SET @cLoadKey    = ''                           
               SET @cWaveKey    = ''                           
               SET @cOutField02 = ''                    
               SET @cOutField03 = ''              
               SET @cInField07 =''                             
                                                  
               SET @nScn = @nScn - 6                      
               SET @nStep = @nStep - 6                       
            END                      
            ELSE                      
            BEGIN                      
               SET @cOutField01 = @cDropIDType                          
               SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)                          
               SET @cOutField03 = @cOrderKey                          
               SET @cOutField04 = ''                          
                          
               SET @cOutField05 = @nTotalPickedQty                          
               SET @cOutField06 = @nTotalScannedQty                 
               SET @cOutField07 = @cExtendedinfo                 
               SET @cInField07 =''                        
                                  
               SET @nScn = @nScn -5                          
               SET @nStep = @nStep -5                       
            END                      
         END                        
      END                      
      ELSE                          
      BEGIN                          
                               
         --IF @nTotalPickedQty=0 and @nTotalScannedQty=0                  
         --IF EXISTS (SELECT 1        
         --      FROM rdt.rdtECOMMLog WITH (NOLOCK)        
         --      WHERE ToteNo = @cToteNo        
         --      AND Status = '0'        
         --      AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END        
         --      AND AddWho = @cUserName       
         --      HAVING SUM(ExpectedQty) = sum(ScannedQty))     --(cc01)      

         --yeekung06
         IF @cNoToteFlag <> '1' 
         BEGIN
            IF NOT EXISTS (SELECT 1        -- (james19)
                  FROM rdt.rdtECOMMLog WITH (NOLOCK)        
                  WHERE ToteNo = @cToteNo        
                  AND Status <> '9'        
                  AND AddWho = @cUserName )      
            BEGIN                      
                  SET @cOutField01  = ''                          
                  SET @cToteNo      = ''                          
                  SET @cDropIDType  = ''                          
                  SET @cOrderkey    = ''                          
                  SET @cSku         = ''                          
                                      
                  SET @cLoadKey    = ''                           
                  SET @cWaveKey    = ''                           
                  SET @cOutField02 = ''                           
                  SET @cOutField03 = ''                           
                  SET @cInField07 =''                                                  
                           
                  SET @nScn = @nScn - 6                      
                  SET @nStep = @nStep - 6                          
            END                      
            ELSE                      
            BEGIN                      
               SET @cOutField01 = @cDropIDType                          
               SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)                          
               SET @cOutField03 = @cOrderKey                          
               SET @cOutField04 = ''                          
                          
               SET @cOutField05 = @nTotalPickedQty                 
               SET @cOutField06 = @nTotalScannedQty                
               SET @cOutField07 = @cExtendedinfo                         
                                  
               SET @nScn = @nScn -5                          
               SET @nStep = @nStep -5                       
            END          
         END
         ELSE
         BEGIN
            SET @nTotalPickedQty = 0           
            SET @nTotalScannedQty = 0           
          
            IF ISNULL(RTRIM(@cLoadKey),'')  <> '' OR ISNULL(RTRIM(@cWaveKey),'')  <> ''           
            BEGIN          
               SET @nRefCount = 0           
          
               IF EXISTS (SELECT PD.* FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)      --(yeekung01)                    
                              INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ORDERKEY = LPD.ORDERKEY                          
                              INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY                          
                              WHERE LPD.LoadKey = @cLoadKey                          
                              AND PD.StorerKey = @cStorerKey                          
                              AND PD.Status IN( '0'  ,@cPickStatus)                         
                              AND PD.ShipFlag <> 'P'                          
                              AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) )           
               BEGIN          
                  SET @nRefCount = 1           

                  SELECT @nTotalPickedQty = Count( LPD.OrderKey)           
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)        
                  JOIN dbo.Orders O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)        
                  WHERE LPD.LoadKey = @cLoadKey          
                  AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
          
                  SELECT @nTotalScannedQty = Count( LPD.OrderKey)          
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)        
                  JOIN dbo.Orders O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)        
                  WHERE LPD.LoadKey = @cLoadKey          
                  AND O.Status = '5'          
                  AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)         
               END          
                               
                     
               IF EXISTS (SELECT PD.* FROM dbo.WaveDetail WD WITH (NOLOCK)          
                              INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ORDERKEY = WD.ORDERKEY          
                              INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY          
                              WHERE WD.WaveKey = @cWaveKey          
                              AND PD.StorerKey = @cStorerKey          
                              AND PD.Status = '0'           
                              AND PD.ShipFlag <> 'P'          
                              AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) )           
               BEGIN          
                  SET @nRefCount = 1          
          
                  SELECT @nTotalPickedQty  = Count(O.OrderKey),           
                           @nTotalScannedQty = SUM(CASE WHEN O.Status = '5' THEN 1 ELSE 0 END)          
                  FROM dbo.WaveDetail WD WITH (NOLOCK)          
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey          
                  WHERE WD.WaveKey = @cWaveKey          
                  AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
              
               END          
                               
               IF @nRefCount = 0 -- No More PickDetail Go to Screen 1           
               BEGIN                      
                  SET @cOutField01  = ''                          
                  SET @cToteNo      = ''                          
                  SET @cDropIDType  = ''                          
                  SET @cOrderkey    = ''                          
                  SET @cSku         = ''                          
                                      
                  SET @cLoadKey    = ''                           
                  SET @cWaveKey    = ''                           
                  SET @cOutField02 = ''                           
                  SET @cOutField03 = ''                           
                  SET @cInField07 =''                                                  
                           
                  SET @nScn = @nScn - 6                     
                  SET @nStep = @nStep - 6                        
               END                      
               ELSE                      
               BEGIN                      
                  SET @cOutField01 = @cDropIDType                          
                  SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)                          
                  SET @cOutField03 = @cOrderKey                          
                  SET @cOutField04 = ''                          
                          
                  SET @cOutField05 = @nTotalPickedQty                 
                  SET @cOutField06 = @nTotalScannedQty                
                  SET @cOutField07 = @cExtendedinfo                         
                                  
                  SET @nScn = @nScn -5                          
                  SET @nStep = @nStep -5                       
               END          
            END        

         END
      END                      
      SET @cFieldAttr07 = ''           
      SET @cFieldAttr02 = ''        
      SET @cFieldAttr03 = ''         
      SET @cFieldAttr04 = ''        
   END                       
                      
   IF @nInputKey = 0                        
   BEGIN                         
    ---- Enable back field    
    --  SET @cFieldAttr07 = ''          --KY01
    --  SET @cFieldAttr02 = ''          
    --  SET @cFieldAttr03 = ''          
    --  SET @cFieldAttr04 = ''          
    
      IF @cExtendedValidateSP <> ''            
      BEGIN            
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')            
         BEGIN            
            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +            --KY01
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '            
            SET @cSQLParam =            
               '@nMobile        INT, ' +            
               '@nFunc          INT, ' +            
               '@cLangCode      NVARCHAR( 3),  ' +            
               '@nStep          INT, ' +            
               '@cStorerKey     NVARCHAR( 15), ' +        
               '@cToteno        NVARCHAR( 20), ' +            
               '@cSKU           NVARCHAR( 20), ' +            
               '@cPickSlipNo    NVARCHAR( 10), ' +            
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,           ' +           
               '@nErrNo         INT           OUTPUT, ' +            
               '@cErrMsg        NVARCHAR( 20) OUTPUT'            
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,            
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT            
            
            IF @nErrNo <> 0            
            BEGIN                   
               GOTO Step_7_Fail            
            END            
            
         END            
      END            

            
      IF @cExtendedUpdateSP <> ''            
      BEGIN            
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')            
         BEGIN            
            SET @cTrackNoFlag = '0'            
            SET @cOrderKeyOut = ''            
            
            INSERT INTO @tExtUpd (Variable, Value) VALUES         
            ('@cCube',        @cCube),     
            ('@cWeight',      @cWeight),        
            ('@cRefNo',       @cRefNo),         
            ('@cWaveKey',     @cWaveKey),        
            ('@cLoadKey',     @cLoadKey),         
            ('@cOption',      @cOption)               
                            
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                            
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd '                           
            SET @cSQLParam =                            
               '@nMobile        INT, ' +                            
               '@nFunc          INT, ' +                            
               '@cLangCode      NVARCHAR( 3),  ' +                            
               '@cUserName      NVARCHAR( 18), ' +                            
               '@cFacility      NVARCHAR( 5),  ' +                            
               '@cStorerKey     NVARCHAR( 15), ' +                            
               '@cToteNo        NVARCHAR( 20), ' +                            
               '@cSKU           NVARCHAR( 20), ' +                            
               '@nStep          INT,           ' +                            
               '@cPickSlipNo    NVARCHAR( 10), ' +                            
               '@cOrderkey      NVARCHAR( 10), ' +                            
               '@cTrackNo       NVARCHAR( 20), ' +                          
               '@cTrackNoFlag   NVARCHAR( 1) OUTPUT,  ' +                            
               '@cOrderKeyOut   NVARCHAR( 10)OUTPUT,  ' +                            
               '@nErrNo         INT           OUTPUT, ' +                            
               '@cErrMsg        NVARCHAR( 20) OUTPUT,'   +                        
               '@cCartonType    NVARCHAR( 20),'+          
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,'  +                
               '@tExtUpd        VariableTable READONLY '            
                            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                            
               @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd                            
                            
            IF @nErrNo <> 0       
            BEGIN  
               GOTO STEP_7_fail            
            END            
         END            
      END                     
                             
      SET @cOutField01 = @cDropIDType                          
      SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)                            
      SET @cOutField03 = @cOrderKey                          
      SET @cOutField04 = ''                   
                          
      SET @cOutField05 = @nTotalPickedQty                          
      SET @cOutField06 = @nTotalScannedQty                         
      SET @cOutField07 = @cExtendedinfo   
      
   -- Enable back field    
      SET @cFieldAttr07 = ''        --TESTING KY01  
      SET @cFieldAttr02 = ''          
      SET @cFieldAttr03 = ''          
      SET @cFieldAttr04 = ''      
                
      SET @nScn = @nScn -5                          
      SET @nStep = @nStep -5                       
                         
   END                      
   GOTO QUIT                 
                        
   Step_7_Fail:                          
   BEGIN                          
  SET @cOutField07 = ''                 
      SET @cCartonType=''                         
   END                          
                          
END              
GOTO Quit                          
        
/********************************************************************************              
Step 8. Screen = 4830. Serial No            
   SKU            (Field01)              
   SKUDesc1       (Field02)              
   SKUDesc2       (Field03)              
   SerialNo       (Field04, input)              
   Scan           (Field05)              
********************************************************************************/              
Step_8:              
BEGIN              
   IF @nInputKey = 1 -- ENTER              
   BEGIN              
      -- Update SKU setting              
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDesc, @nQTY, 'UPDATE', 'PICKSLIP', @cPickSlipNo,               
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,              
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,              
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,              
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,              
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,              
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,              
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,              
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,              
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,              
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,              
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,              
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,              
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,              
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,              
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,              
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,               
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn,               
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '3'              
              
      IF @nErrNo <> 0              
         GOTO Quit              
              
      DECLARE @nPackSerialQTY INT              
      IF @nBulkSNO > 0              
         SET @nPackSerialQTY = @nBulkSNOQTY              
      ELSE IF @cSerialNo <> ''              
         SET @nPackSerialQTY = @nSerialQTY              
      ELSE              
         SET @nPackSerialQTY = @nQTY            
                   
      IF @cExtendedValidateSP <> ''            
      BEGIN            
            
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')            
         BEGIN            
            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +            
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT '            
            SET @cSQLParam =            
               '@nMobile        INT, ' +            
               '@nFunc          INT, ' +            
               '@cLangCode      NVARCHAR( 3),  ' +            
               '@nStep          INT, ' +            
               '@cStorerKey     NVARCHAR( 15), ' +        
               '@cToteno        NVARCHAR( 20), ' +            
               '@cSKU           NVARCHAR( 20), ' +           
               '@cPickSlipNo    NVARCHAR( 10), ' +            
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,           ' +           
               '@nErrNo         INT           OUTPUT, ' +            
               '@cErrMsg        NVARCHAR( 20) OUTPUT'            
    
            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,            
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cSerialNo, @nSerialQTY, @nErrNo OUTPUT, @cErrMsg OUTPUT            
            
            IF @nErrNo <> 0            
            BEGIN            
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CtnNotFrSameLoad            
               GOTO quit            
            END            
            
         END            
      END            
            
      IF @cExtendedUpdateSP <> ''            
      BEGIN            
            
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')            
          BEGIN            
             SET @cTrackNoFlag = '0'            
             SET @cOrderKeyOut = ''            
            
             INSERT INTO @tExtUpd (Variable, Value) VALUES         
               ('@cCube',        @cCube),        
               ('@cWeight',      @cWeight),        
               ('@cRefNo',       @cRefNo),         
               ('@cWaveKey',     @cWaveKey),        
               ('@cLoadKey',     @cLoadKey),         
               ('@cOption',      @cOption)               
                            
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                            
                ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                  @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd '                           
             SET @cSQLParam =                            
                '@nMobile        INT, ' +                            
                '@nFunc          INT, ' +                            
                '@cLangCode      NVARCHAR( 3),  ' +                            
                '@cUserName      NVARCHAR( 18), ' +                            
                '@cFacility      NVARCHAR( 5),  ' +                            
                '@cStorerKey     NVARCHAR( 15), ' +                            
                '@cToteNo        NVARCHAR( 20), ' +                            
                '@cSKU           NVARCHAR( 20), ' +                            
                '@nStep          INT,           ' +                            
                '@cPickSlipNo    NVARCHAR( 10), ' +                            
                '@cOrderkey      NVARCHAR( 10), ' +                            
                '@cTrackNo       NVARCHAR( 20), ' +                          
                '@cTrackNoFlag   NVARCHAR( 1) OUTPUT,  ' +                            
                '@cOrderKeyOut   NVARCHAR( 10)OUTPUT,  ' +                            
                '@nErrNo         INT           OUTPUT, ' +                            
                '@cErrMsg        NVARCHAR( 20) OUTPUT,'   +                        
                '@cCartonType    NVARCHAR( 20),'+          
                '@cSerialNo      NVARCHAR( 30), ' +               
                '@nSerialQTY     INT,'  +                
                '@tExtUpd        VariableTable READONLY '            
                            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                            
                @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cToteNo, @cSKU, @nStep, @cPickSlipNo, @cOrderKey, @cTrackNo, @cTrackNoFlag OUTPUT, @cOrderKeyOut OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT, @cCartonType, @cSerialNo, @nSerialQTY, @tExtUpd                            
                            
            IF @nErrNo < 0 -- (ChewKP06)             
            BEGIN            
               --SET @nErrNo = 0                  
               SET @cErrMsg1 = 'WayBill Not Found'            
               --SET @cErrMsg2 = @cErrMsg                  
               SET @cErrMsg3 = ''                  
               SET @cErrMsg4 = ''                  
               SET @cErrMsg5 = ''                  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,                  
                  @cErrMsg1, @cErrMsg, @cErrMsg3, @cErrMsg4, @cErrMsg5                  
                           
               SET @cErrMsg = ''            
            END            
             ELSE IF @nErrNo > 0             
             BEGIN            
                GOTO quit            
             END            
      END            
      END            
            
      IF @cExtendedInfoSP <> ''                            
      BEGIN                            
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')                            
         BEGIN                            
                            
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +                            
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cLoadKey,@cWavekey,@nInputKey,@cSerialNo, @nSerialQTY,@cExtendedinfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '                            
            SET @cSQLParam =                            
               '@nMobile        INT, ' +                            
               '@nFunc          INT, ' +                            
               '@cLangCode      NVARCHAR( 3),  ' +                            
               '@nStep          INT, ' +                            
               '@cStorerKey     NVARCHAR( 15), ' +                            
               '@cToteno        NVARCHAR( 20), ' +                            
               '@cSKU           NVARCHAR( 20), ' +                     
               '@cPickSlipNo    NVARCHAR( 10), ' +                  
               '@cLoadKey       NVARCHAR( 20), ' +                  
               '@cWavekey       NVARCHAR( 20), ' +                  
               '@nInputKey      INT,           ' +          
               '@cSerialNo      NVARCHAR( 30), ' +               
               '@nSerialQTY     INT,           ' +                  
               '@cExtendedinfo  NVARCHAR( 20) OUTPUT, ' +                           
               '@nErrNo         INT           OUTPUT, ' +                            
               '@cErrMsg        NVARCHAR( 20) OUTPUT'                            
                            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                            
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cToteno, @cSKU, @cPickSlipNo,@cLoadKey,@cWavekey,@nInputKey,@cSerialNo, @nSerialQTY,@cExtendedinfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT                            
                            
            IF @nErrNo <> 0                            
               GOTO quit                            
         END                            
      END                     
          
       /****************************            
       Prepare Next Screen            
      ****************************/            
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno            
         AND Mobile = @nMobile AND Status < '5')            
      BEGIN            
         -- tote completed, so need to return to 1st screen            
            
         -- Check if all SKU in this tote picked and packed (james01)            
         -- Check total picked & unshipped qty            
         IF @cNoToteFlag <> '1'            
         BEGIN            
            SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)            
            FROM dbo.Pickdetail PD WITH (NOLOCK)            
           JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey            
            JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY            
            JOIN rdt.rdtEcommLog ELOG WITH (NOLOCK) ON ELOG.OrderKey = PD.OrderKey AND ELOG.SKU = PD.SKU AND ELOG.ToteNo = PD.DropID -- (ChewKP08)             
            WHERE O.StorerKey = @cStorerKey            
               AND O.Status <> '9'             
               AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')            
               AND (PD.Status = '5' OR PD.ShipFlag = 'P')                    
               AND PD.DropID = @cToteNo            
               AND ELOG.ToteNo = @cToteNo   -- (ChewKP08)             
               AND ELOG.AddWho = @cUserName -- (ChewKP08)               
               AND ELOG.Status = '9'        -- (ChewKP08)               
                           
                     
            IF @cGenPackDetail = '1'            
            BEGIN            
               -- Check total packed & unshipped qty            
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)            
               FROM dbo.Packdetail PD WITH (NOLOCK)            
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo            
               JOIN dbo.Orders O WITH (NOLOCK) ON PH.StorerKey = O.StorerKey AND PH.OrderKey = O.OrderKey            
               JOIN DROPID DI WITH (NOLOCK) ON PD.DROPID = DI.DROPID AND DI.LOADKEY = O.LOADKEY            
               WHERE O.StorerKey = @cStorerKey            
                  AND O.Status <> '9'             
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')            
                  AND PD.DropID = @cToteNo            
            END            
            ELSE            
            BEGIN            
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(SCannedQTY), 0)            
               FROM rdt.rdtEcommLog WITH (NOLOCK)              
               WHERE ToteNo = @cToteNo               
               AND AddWho = @cUserName               
               AND Status = '9'            
                           
            END            
         END            
         ELSE            
         BEGIN            
            SELECT @nSKU_Picked_TTL = ISNULL(SUM(PD.QTY), 0)            
            FROM dbo.Pickdetail PD WITH (NOLOCK)            
            JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey            
            WHERE O.StorerKey = @cStorerKey            
               AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')            
               --AND PD.Status = '5'            
               AND PD.OrderKey = @cOrderKeyOut            
                        
            IF @cGenPackDetail = '1'            
            BEGIN                
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)            
               FROM dbo.Pickdetail PD WITH (NOLOCK)            
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey            
               WHERE O.StorerKey = @cStorerKey            
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')            
                  AND (PD.Status = '5' OR PD.ShipFlag = 'P')                   
                  AND PD.OrderKey = @cOrderKeyOut               
                  AND PD.CaseID <> ''            
            END            
            ELSE            
            BEGIN            
               SELECT @nSKU_Packed_TTL = ISNULL(SUM(PD.QTY), 0)            
               FROM dbo.Pickdetail PD WITH (NOLOCK)            
               JOIN dbo.Orders O WITH (NOLOCK) ON PD.StorerKey = O.StorerKey AND PD.OrderKey = O.OrderKey            
              WHERE O.StorerKey = @cStorerKey            
                  AND O.SOStatus NOT IN ('9', 'CANC', 'PENDPACK', 'PENDCANC' , 'HOLD')            
         AND (PD.Status = '5' OR PD.ShipFlag = 'P')                   
                  AND PD.OrderKey = @cOrderKeyOut               
                  --AND PD.CaseID <> ''            
            END            
         END            
                     
         -- Close DropID when pick & pack qty matches            
         IF @nSKU_Picked_TTL <> @nSKU_Packed_TTL            
         BEGIN            
            IF @cTrackNoFlag = '1'            
            BEGIN            
               IF @cShowTrackNoScn = '1'            
               BEGIN            
                  IF @cDefaultTrackNo = '1'            
                  BEGIN            
                     SET @cSuggestedTrackNo = ''            
                             
                     IF @cUseUdf04AsTrackNo = '1'        
                        SELECT @cSuggestedTrackNo = UserDefine04            
                        FROM dbo.Orders WITH (NOLOCK)            
                        WHERE StorerKey = @cStorerKey            
                        AND OrderKey = @cOrderKeyOut            
                     ELSE        
                        SELECT @cSuggestedTrackNo = TrackingNo            
                        FROM dbo.Orders WITH (NOLOCK)            
                        WHERE StorerKey = @cStorerKey            
                        AND OrderKey = @cOrderKeyOut            
        
                     SET @cOrderKey = @cOrderKeyOut            
                  END            
            
                  SET @cOutField01 = @cOrderKey            
                  SET @cOutfield02 = @cSuggestedTrackNo            
            
                  SET @nScn = @nPrevScn + 4            
                  SET @nStep = @nStep -2           
               END            
               ELSE            
               BEGIN            
                  SET @nTotalScannedQty = @nTotalScannedQty + 1            
                              
                  SET @cOutField01 = @cDropIDType            
                  SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)            
                  SET @cOutField03 = @cOrderKey            
                  SET @cOutField04 = ''            
               
                  SET @cOutField05 = @nTotalPickedQty            
                  SET @cOutField06 = @nTotalScannedQty           
          
                  SET @nScn = @nPrevScn            
                  SET @nStep = @nStep -6      --(yeekung09)   
                  SET @cOutField07 = @cExtendedinfo                
               END            
            END            
            ELSE            
            BEGIN            
               SET @nTotalScannedQty = @nTotalScannedQty + 1            
                              
               SET @cOutField01 = @cDropIDType            
               SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)            
               SET @cOutField03 = @cOrderKey            
               SET @cOutField04 = ''            
            
               SET @cOutField05 = @nTotalPickedQty            
               SET @cOutField06 = @nTotalScannedQty          
               SET @cOutField07 = @cExtendedinfo               
                                 
               SET @nScn = @nPrevScn            
               SET @nStep = @nStep -6       
            END            
         END    
         ELSE            
         BEGIN            
            --(Kc05)            
            --(KC04) - start            
            IF EXISTS( SELECT 1 FROM dbo.DROPID WITH (NOLOCK) WHERE DropID = @cToteNo AND Status < '9')            
            BEGIN            
               UPDATE dbo.DROPID WITH (Rowlock)            
               SET   Status = '9'            
                    ,Editdate = GetDate()            
               WHERE DropID = @cToteNo            
               -- AND   Status < '9'            
            
               IF @@ERROR <> 0            
               BEGIN            
                  SET @nErrNo = 90495          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIdFail'            
                  GOTO quit            
               END            
            END            
            --(Kc04) - end            
           
            SET @cDropIDStatus = ''                
            SELECT @cDropIDStatus = Status                 
            FROM dbo.DropID WITH (NOLOCK)                 
            WHERE DropID = @cToteNo                 
                            
            IF @cShowTrackNoScn = '1'            
            BEGIN            
               IF @cTrackNoFlag = '1'            
               BEGIN            
                  --(cc01)        
                  IF @cScanCTSCN <> ''                      
                  BEGIN         
                     -- Get PackInfo          
                     SET @cCartonType = ''          
                     SET @cWeight = ''          
                     SET @cCube = ''          
                     SET @cRefNo = ''          
                                   
                     --set default Value        
                     SET @cOutField07 = ''        
                                   
                     -- Enable disable field          
                     SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                     SET @cFieldAttr08 = '' -- QTY          
                
                     -- Position cursor          
                     IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                     IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                     IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                     IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
                     -- Go to next screen          
                     SET @nScn = @nPrevScn + 5         
                     SET @nStep = @nStep - 1         
                      
                     GOTO Quit          
                  END          
            
                  IF @cDefaultTrackNo = '1'            
                  BEGIN            
                     SET @cSuggestedTrackNo = ''            
                             
                     IF @cUseUdf04AsTrackNo = '1'        
                        SELECT @cSuggestedTrackNo = UserDefine04            
                        FROM dbo.Orders WITH (NOLOCK)            
                        WHERE StorerKey = @cStorerKey            
                        AND OrderKey = @cOrderKeyOut            
                     ELSE        
                        SELECT @cSuggestedTrackNo = TrackingNo            
                   FROM dbo.Orders WITH (NOLOCK)            
                        WHERE StorerKey = @cStorerKey            
                        AND OrderKey = @cOrderKeyOut            
                             
                     SET @cOrderKey = @cOrderKeyOut            
                  END            
            
                  SET @cOutField01 = @cOrderKey            
                  SET @cOutfield02 = @cSuggestedTrackNo            
            
                  SET @nScn = @nScn + 4            
                  SET @nStep = @nStep + 4            
               END            
               ELSE            
               BEGIN            
                  -- Tote is Finish Back to Main Screen            
                  DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR             
                  SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)             
                  WHERE ToteNo = @cToteno             
                  AND   AddWho = @cUserName            
                  OPEN CUR_DEL            
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef            
                  WHILE @@FETCH_STATUS <> -1            
                  BEGIN            
            
                     DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef            
                     IF @@ERROR <> 0            
                     BEGIN            
                        CLOSE CUR_DEL            
                        DEALLOCATE CUR_DEL            
                        SET @nErrNo = 90496            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail            
                        GOTO quit            
                     END            
            
                     FETCH NEXT FROM CUR_DEL INTO @nRowRef            
                  END            
                  CLOSE CUR_DEL            
                  DEALLOCATE CUR_DEL            
            
                  --DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName            
               
                  --IF @@ERROR <> 0            
                  --BEGIN            
                  --   SET @nErrNo = 90487            
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail            
                  --   GOTO Step_2_Fail            
                  --END            
                              
                  SET @cOutField01  = ''            
                  SET @cToteNo      = ''            
                  SET @cDropIDType  = ''            
                  SET @cOrderkey    = ''            
                  SET @cSku         = ''            
                              
                  SET @cLoadKey    = ''             
                  SET @cWaveKey    = ''             
                  SET @cOutField02 = ''             
                  SET @cOutField03 = ''             
                              
               
                  SET @nScn = @nPrevScn - 1          
                  SET @nStep = @nStep - 7            
               END            
            END            
            ELSE            
            BEGIN            
                           
               IF @cNoToteFlag <> '1'            
               BEGIN            
                  DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR             
                  SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)             
                  WHERE ToteNo = @cToteno             
                  AND   AddWho = @cUserName            
                  OPEN CUR_DEL            
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef            
                  WHILE @@FETCH_STATUS <> -1            
                  BEGIN            
            
              DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef            
                     IF @@ERROR <> 0            
                     BEGIN            
                        CLOSE CUR_DEL            
                        DEALLOCATE CUR_DEL            
                        SET @nErrNo = 90497            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail            
                        GOTO quit          
                     END            
            
                     FETCH NEXT FROM CUR_DEL INTO @nRowRef            
                  END            
                  CLOSE CUR_DEL            
                  DEALLOCATE CUR_DEL            
            
                  --DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName            
               
                  --IF @@ERROR <> 0            
     --BEGIN            
                  --   SET @nErrNo = 90478            
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail            
                  --   GOTO Step_2_Fail            
                  --END            
            
                  SET @cOutField01  = ''            
                  SET @cToteNo      = ''            
                  SET @cDropIDType  = ''            
                  SET @cOrderkey    = ''            
                  SET @cSku         = ''            
                              
                  SET @cLoadKey    = '' -- (ChewKP02)            
                  SET @cWaveKey    = '' -- (ChewKP02)            
                  SET @cOutField02 = '' -- (ChewKP02)            
                  SET @cOutField03 = '' -- (ChewKP02)            
                              
               
                  SET @nScn = @nPrevScn - 1            
                  SET @nStep = @nStep - 7           
               END            
               ELSE            
               BEGIN            
                  DECLARE CUR_DEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR             
                  SELECT ROWREF FROM RDT.rdtECOMMLOG WITH (NOLOCK)             
                  WHERE ToteNo = @cToteno             
                  AND   AddWho = @cUserName            
                  OPEN CUR_DEL            
                  FETCH NEXT FROM CUR_DEL INTO @nRowRef            
                  WHILE @@FETCH_STATUS <> -1            
                  BEGIN            
            
                     DELETE FROM RDT.rdtECOMMLOG WITH (ROWLOCK) WHERE RowRef = @nRowRef            
                     IF @@ERROR <> 0            
                     BEGIN            
                        CLOSE CUR_DEL            
                        DEALLOCATE CUR_DEL            
                        SET @nErrNo = 90498            
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail            
                        GOTO Quit            
                     END            
            
                     FETCH NEXT FROM CUR_DEL INTO @nRowRef            
                  END            
                  CLOSE CUR_DEL            
                  DEALLOCATE CUR_DEL            
            
                  --DELETE FROM rdt.rdtECOMMLog WITH (ROWLOCK) WHERE ToteNo = @cToteNo AND AddWho = @cUserName            
                              
                  --IF @@ERROR <> 0            
                  --BEGIN            
                  --   SET @nErrNo = 90486            
                  --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DelEcommLogFail            
                  --   GOTO Step_2_Fail            
       --END            
                              
                  SET @nTotalPickedQty = 0             
                  SET @nTotalScannedQty = 0             
            
                  IF ISNULL(RTRIM(@cLoadKey),'')  <> '' OR ISNULL(RTRIM(@cWaveKey),'')  <> ''             
                  BEGIN            
                     SET @nRefCount = 0             
            
                     IF EXISTS (SELECT PD.* FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)      --(yeekung01)                      
                          INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ORDERKEY = LPD.ORDERKEY                            
                                    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY                            
                                    WHERE LPD.LoadKey = @cLoadKey                            
                                    AND PD.StorerKey = @cStorerKey                            
                                    AND PD.Status IN( '0'  ,@cPickStatus)                           
                                    AND PD.ShipFlag <> 'P'                            
                                    AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) )             
                     BEGIN            
                        SET @nRefCount = 1             
                        /*          
  SELECT @nTotalPickedQty = Count(O.OrderKey)             
                        FROM dbo.Orders O WITH (NOLOCK)             
                        WHERE O.LoadKey = @cLoadKey            
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)             
            
                        SELECT @nTotalScannedQty = Count(OrderKey)            
                        FROM dbo.Orders WITH (NOLOCK)             
                        WHERE LoadKey = @cLoadKey            
                        AND Status = '5'            
                        AND SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
                        */          
          
                        SELECT @nTotalPickedQty = Count( LPD.OrderKey)             
                        FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)          
                        JOIN dbo.Orders O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)          
                        WHERE LPD.LoadKey = @cLoadKey            
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)             
            
                        SELECT @nTotalScannedQty = Count( LPD.OrderKey)            
                        FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)          
                        JOIN dbo.Orders O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)          
                        WHERE LPD.LoadKey = @cLoadKey            
                        AND O.Status = '5'            
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)           
                     END            
                                 
                   
                     IF EXISTS (SELECT PD.* FROM dbo.WaveDetail WD WITH (NOLOCK)            
                                    INNER JOIN dbo.ORDERS O WITH (NOLOCK) ON O.ORDERKEY = WD.ORDERKEY            
                                    INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.ORDERKEY = O.ORDERKEY            
                                    WHERE WD.WaveKey = @cWaveKey            
                                    AND PD.StorerKey = @cStorerKey            
                             AND PD.Status = '0'             
                                    AND PD.ShipFlag <> 'P'            
                                    AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) )             
                     BEGIN            
                        SET @nRefCount = 1            
            
                        SELECT @nTotalPickedQty  = Count(O.OrderKey),             
                               @nTotalScannedQty = SUM(CASE WHEN O.Status = '5' THEN 1 ELSE 0 END)         
                        FROM dbo.WaveDetail WD WITH (NOLOCK)            
                        INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey            
                        WHERE WD.WaveKey = @cWaveKey            
                        AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)             
            
                        --SELECT @nTotalScannedQty = Count(O.OrderKey)            
                        --FROM dbo.Orders O WITH (NOLOCK)             
                        --JOIN WAVEDETAIL AS w WITH(NOLOCK) ON w.OrderKey = dbo.Orders.OrderKey            
                        --WHERE w.WaveKey = @cWaveKey            
                        --AND O.Status = '5'            
                        --AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)             
                     END            
                                 
                          
            
                     IF @nRefCount = 0 -- No More PickDetail Go to Screen 1             
                     BEGIN            
                        --(cc01)        
                        IF @cScanCTSCN <> ''                      
                        BEGIN                  
                           -- Get PackInfo          
                           SET @cCartonType = ''          
                           SET @cWeight = ''          
                           SET @cCube = ''          
                           SET @cRefNo = ''          
                                   
                           --set default Value        
                           SET @cOutField07 = ''        
                                   
                           -- Enable disable field          
                           SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr08 = '' -- QTY          
                
                           -- Position cursor          
                           IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                           IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                           IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                           IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
                           -- Go to next screen          
                           SET @nScn = @nPrevScn + 5           
                           SET @nStep = @nStep - 1          
                      
                           GOTO Quit          
                        END          
                                  
                        SET @cOutField01  = ''            
                        SET @cToteNo      = ''            
                        SET @cDropIDType  = ''            
                        SET @cOrderkey    = ''            
                        SET @cSku         = ''            
                                    
                        SET @cLoadKey    = ''             
                        SET @cWaveKey    = ''             
                        SET @cOutField02 = ''             
                        SET @cOutField03 = ''             
                                    
                     
                        SET @nScn = @nPrevScn - 1            
                        SET @nStep = @nStep - 7          
                     END            
                     ELSE            
                     BEGIN            
                     --(cc01)                              
                        IF @cScanCTSCN <> ''                      
                        BEGIN                  
                           -- Get PackInfo          
                           SET @cCartonType = ''          
                           SET @cWeight = ''          
                           SET @cCube = ''          
                           SET @cRefNo = ''          
                                   
                           --set default Value        
                           SET @cOutField07 = ''        
                                   
                           -- Enable disable field          
                           SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
                           SET @cFieldAttr08 = '' -- QTY          
                
                           -- Position cursor          
                           IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
                           IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
                           IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
                           IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
                           -- Go to next screen          
                           SET @nScn = @nPrevScn + 5        
                           SET @nStep = @nStep - 1          
                      
                           GOTO Quit          
                        END          
                                  
                        SET @cOutField01 = @cDropIDType            
                        SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)            
                        SET @cOutField03 = @cOrderKey            
                        SET @cOutField04 = ''            
               
                        SET @cOutField05 = @nTotalPickedQty            
                        SET @cOutField06 = @nTotalScannedQty          
                        SET @cOutField07 = @cExtendedinfo           
                                  
                        SET @nScn = @nPrevScn            
                        SET @nStep = @nStep -6               
                     END            
                                 
                  END                      
               END            
                             
            END            
         END            
      END            
      ELSE            
      BEGIN            
         SET @nTotalScannedQty = ISNULL(@nTotalScannedQty,0)  + 1           
                   
         IF @cScanCTSCN <> ''                      
         BEGIN                  
            -- Get PackInfo          
            SET @cCartonType = ''          
            SET @cWeight = ''          
            SET @cCube = ''          
            SET @cRefNo = ''          
                                   
           --set default Value        
            SET @cOutField07 = ''        
                                   
           -- Enable disable field          
            SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
            SET @cFieldAttr08 = '' -- QTY          
                
            -- Position cursor          
            IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
            IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
            IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
            IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
            -- Go to next screen          
            SET @nScn = @nPrevScn + 5           
            SET @nStep = @nStep - 1          
                      
            GOTO Quit          
         END           
            
         IF @cTrackNoFlag = '1'            
         BEGIN            
            IF @cShowTrackNoScn = '1'            
            BEGIN            
--                     SELECT Top 1 @cOrderKey = OrderKey            
--                     FROM rdt.rdtECOMMLog WITH (NOLOCK)            
--                     WHERE ToteNo = @cToteNo            
--                     AND Status = '9'            
--               GROUP BY OrderKey            
--                     ORDER BY OrderKey            
            
               IF @cDefaultTrackNo = '1'            
               BEGIN            
                  SET @cSuggestedTrackNo = ''            
                          
                  IF @cUseUdf04AsTrackNo = '1'        
                     SELECT @cSuggestedTrackNo = UserDefine04            
                     FROM dbo.Orders WITH (NOLOCK)            
                     WHERE StorerKey = @cStorerKey            
                        AND OrderKey = @cOrderKeyOut            
                  ELSE        
                     SELECT @cSuggestedTrackNo = TrackingNo            
                     FROM dbo.Orders WITH (NOLOCK)            
                     WHERE StorerKey = @cStorerKey            
                        AND OrderKey = @cOrderKeyOut        
                             
                  SET @cOrderKey = @cOrderKeyOut            
               END            
            
               SET @cOutField01 = @cOrderKey            
               SET @cOutfield02 = @cSuggestedTrackNo            
            
               SET @nScn = @nPrevScn + 4            
               SET @nStep = @nStep -2            
            END            
            ELSE            
            BEGIN            
               SET @cOutField01 = @cDropIDType            
               SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)            
               SET @cOutField03 = @cOrderKey            
               SET @cOutField04 = ''            
            
               SET @cOutField05 = @nTotalPickedQty            
               SET @cOutField06 = @nTotalScannedQty            
          
               SET @nScn = @nPrevScn            
               SET @nStep = @nStep -6            
            END            
         END            
         ELSE            
         BEGIN            
          IF @cScanCTSCN <> ''                      
            BEGIN                  
               -- Get PackInfo          
               SET @cCartonType = ''          
               SET @cWeight = ''          
               SET @cCube = ''          
               SET @cRefNo = ''          
                                 
               --set default Value        
               SET @cOutField07 = ''        
                                   
               -- Enable disable field          
               SET @cFieldAttr07 = CASE WHEN CHARINDEX( 'T', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cScanCTSCN) = 0 THEN 'O' ELSE '' END          
               SET @cFieldAttr08 = '' -- QTY          
                
               -- Position cursor          
               IF @cFieldAttr07 = '' AND @cOutField07 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE          
               IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE          
               IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE          
               IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4          
                
               -- Go to next screen          
               SET @nScn = @nPrevScn + 5           
               SET @nStep = @nStep - 1          
                      
               GOTO Quit          
            END            
                      
            -- loop same screen            
            IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cToteno            
             AND Mobile = @nMobile AND SKU = @cSKU AND ExpectedQty > ScannedQty AND Status < '5'            
               AND Orderkey = @cOrderkey)                   --(Kc03)        
            BEGIN            
               -- sku fully scanned for the order            
               SET @cSKU = ''            
            END          
                        
            SET @cOutField01 = @cDropIDType            
            SET @cOutField02 = @cToteNo --'' --@cSku  -- (Vicky02)            
            SET @cOutField03 = @cOrderKey            
            SET @cOutField04 = ''            
            
            
            SET @cOutField05 = @nTotalPickedQty            
            SET @cOutField06 = @nTotalScannedQty            
          
            SET @nScn = @nPrevScn            
            SET @nStep = @nStep -6            
         END            
      END            
              
   END              
        
   IF @nInputKey = 0 -- ENTER             
   BEGIN          
      SET @nTotalScannedQty = 0            
      SELECT @nTotalScannedQty = SUM(QTY)            
      FROM dbo.PickDetail PD WITH (NOLOCK)            
      INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey            
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey            
      WHERE PD.DropID = @cToteNo            
      --AND PD.Status = '5' -- (ChewKP04)             
      AND (PD.Status IN  ('3','5') OR PD.ShipFlag = 'P')  -- (ChewKP04)                     
      AND PD.CaseID <> ''            
      AND O.LoadKey = @cLoadKey            
      AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' ) -- (ChewKP05)             
      AND PH.PickHeaderKey = @cPickSlipNo -- (Chee02)             
            
      SELECT @nTotalPickedQty  = SUM(ExpectedQty)            
      FROM rdt.rdtECOMMLog WITH (NOLOCK)            
      WHERE  Status = '0'            
      AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END            
      AND AddWho = @cUserName            
            
      SET @cOutField02 = @cToteno            
      SET @cOutField03 = @cOrderkey   --multis order will have only 1 order in the tote            
      SET @cOutField04 = ''            
      SET @cOutField05 = @nTotalPickedQty            
      SET @cOutField06 = ISNULL(@nTotalScannedQty, 0 )            
            
      -- Remember the current scn & step            
      SET @nScn = @nPrevScn   --ESC screen            
      SET @nStep = @nStep - 6            
      GOTO QUIT          
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
                 
       V_PickSlipNo  = @cPickslipNo,          
       V_OrderKey    = @cOrderkey,      
       V_LoadKey     = @cLoadKey,          
          
       V_String1      = @cToteNo,          
       V_String2      = @cDropIDType,          
       V_String3      = @cDefaultCtnType,        
       V_String4      = @cSku,          
       V_String5      = @cPaperPrinterNotReq,        
       V_String6      = @cLabelPrinterNotReq,        
        
       V_String7      = @cDecodeLabelNo,          
       V_String8      = @cExtendedValidateSP,          
       V_String9      = @cExtendedUpdateSP,          
       V_String10     = @cShowTrackNoScn,          
       V_String11     = @cNextOrderKey,          
       V_String12     = @cDefaultTrackNo,          
       V_String13     = @cUseUdf04AsTrackNo,   -- (james14)        
       V_String15     = @cWaveKey, -- (ChewKP01)           
       V_String16     = @cNoToteFlag, -- (ChewKP01)           
       V_String17     = @cGenPackDetail,           
       V_String18     = @cBackendPickConfirm,          
       V_String19     = @cOrderWithTrackNo, -- (ChewKP10)          
       V_String20     = @cSKUStatus, -- (james03)           
       V_String21     = @cDefaultCursor,          
       V_String22     = @cGetOrders_SP,          
       V_String23     = @cNotCheckDropIDTable,         
       V_String24     = @cCartonType,                       
       V_String25     = @cScanCTSCN,                      
       V_String26     = @cCartongroup,                   
       V_String27     = @cPickStatus,                 
       V_String28     = @cExtendedinfoSP,                 
       V_String29     = @cExtendedinfo,          
       V_String30     = @cSerialNoCapture, --(yeekung02)            
       V_String31     = @cCube, --(cc01)        
       V_String32     = @cWeight,   --(cc01)        
       V_String33     = @cRefNo,  --(cc01)        
       V_String34     = @cRefNoInsLogSP,          
       V_String35     = @cDecodeSP,  
       V_String36     = @cMultiMethod,  
         
       V_FromScn      = @nPrevScn,          
       V_FromStep     = @nPrevStep,          
       V_Integer1     = @nTotalPickedQty,          
       V_Integer2     = @nTotalScannedQty,          
          
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