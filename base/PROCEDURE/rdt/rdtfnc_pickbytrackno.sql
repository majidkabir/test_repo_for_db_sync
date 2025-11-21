SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/      
/* Store procedure: rdtfnc_PickByTrackNo                                     */      
/* Copyright      : IDS                                                      */      
/*                                                                           */      
/* Purpose: SOS#206819 - Order Tracking No Capture                           */      
/*                                                                           */      
/* Modifications log:                                                        */      
/*                                                                           */      
/* Date       Rev  Author   Purposes                                         */      
/* 2011-03-07 1.0  ChewKP   Created                                          */      
/* 2011-05-09 1.1  ChewKP   SOS#215035 (ChewKP01)                            */      
/* 2011-05-27 1.2  ChewKP   SOS#214788 SOStatus Validation (ChewKP02)        */      
/* 2011-11-14 1.3  SPChin   SOS#230128 TrackNo Validation in rdt.rdtTrackLog */      
/* 2012-10-23 1.4  ChewKP   SOS#258902 Addtional Orders.SOStatus validation  */      
/*                          (ChewKP03)                                       */      
/* 2012-11-10 1.5  James    Temp remove regular expression (james01)         */      
/* 2013-01-10 1.6  James    Use CLR type regular expression (james02)        */      
/* 2013-04-11 1.7  ChewKP   SOS#274505 - Addtiional Screen (ChewKP04)        */  
/* 2013-07-23 1.8  ChewKP   SOS#284348 - Bartender Label Printing (ChewKP05) */  
/* 2013-10-28 1.9  SPChin   SOS293491 - Bug Fixed                            */  
/* 2014-09-15 2.0  Ung      SOS319577 Allow TrackNo reuse if order cancel    */
/* 2015-05-27 2.1  ChewKP   Performance Tuning (ChewKP06)                    */
/* 2015-06-18 2.2  ChewKP   SOS#344720 Print Pack List (ChewKP07)            */
/* 2015-09-02 2.3  ChewKP   SOS#351702 Add Extended Update (ChewKP08)        */  
/* 2015-08-24 2.4  Ung      SOS350720 Add BackendPickConfirm                 */
/* 2015-12-08 2.5  ChewKP   SOS#358644 Revise Pickdetail Update Logic(ChewKP09)*/
/* 2016-09-30 2.6  Ung      Performance tuning                               */
/* 2016-10-10 2.7  Ung      Performance tuning. ECOM bypass scan-in trigger  */
/* 2016-11-08 2.8  James    Order status check cater for BackendPickConfirm  */
/*                          config (james03)                                 */
/* 2016-11-11 2.9  James    Skip printing if printer = PDF                   */
/* 2017-01-06 3.0  ChewKP   Bug Fixes (ChewKP10)                             */
/* 2017-06-29 3.1  ChewKP   WMS-2268 - Add Config SkipTrackNo (ChewKP11)     */ 
/* 2017-09-25 3.2  ChewKP   WMS-2992 - Add ExtendedUpdate on Scn 4 (ChewKP12)*/
/* 2017-11-14 3.3  James    Fix tran count error (james04)                   */
/* 2018-02-08 3.4  James    WMS3969-Check status of SKU (james05)            */
/* 2018-09-25 3.5  TungGH   Perfomance tuning. Remove isvalidqty during      */
/*                          loading rdtmobrec                                */
/* 2018-12-24 3.6  ChewKP   Performance Tuning (CheWKP13)                    */
/* 2019-12-18 3.7  Chermaine WMS-11504 not update UserDefine04 (cc01)        */
/* 2020-04-27 3.8  James    WMS-13041 Add ExtendedValidateSP (james06)       */
/* 2020-05-22 3.9  James    WMS-13481 Add DecodeSP at step 1 (james07)       */
/*                          Move ExtendedUpdateSP at step3                   */
/*                          Add TrackingNo as alternate to UserDefine04      */
/* 2021-04-08 4.0  James    WMS-16024 Standarized use of TrackingNo (james08) */
/*****************************************************************************/      
      
CREATE PROC [RDT].[rdtfnc_PickByTrackNo](      
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
   @cPrinter_Paper      NVARCHAR(10),      
   @cUserName           NVARCHAR(18),      
      
   @cStorerKey          NVARCHAR(15),      
   @cFacility           NVARCHAR(5),      
      
   @cOrderKey           NVARCHAR(10),      
   @cTrackNo            NVARCHAR(18),      
   @cSKU                NVARCHAR(20),      
   @cTrackRegExp        NVARCHAR(255),      
   @nAllocatedQty       INT,      
   @nPickedQty          INT,      
   @nPickCheck          INT,      
   @nQty                INT,      
   @cInSKU              NVARCHAR(40),      
   @cDecodeLabelNo      NVARCHAR(20),      
   @cShipperKey         NVARCHAR(15),      
   @cPickDetailKey      NVARCHAR(10),      
   @nPDQty              INT,      
   @nPickDetailCheck    INT,      
   @nTrackLogCheck      INT,      
   @ErrMsgNextScreen    NVARCHAR(1),      
   @cErrMsg1            NVARCHAR( 20),      
   @cErrMsg2            NVARCHAR( 20),      
   @cErrMsg3            NVARCHAR( 20),      
   @cErrMsg4            NVARCHAR( 20),      
   @cErrMsg5            NVARCHAR( 20),      
   @cPickslipno         NVARCHAR( 10),      
   @cOrderTrackNo       NVARCHAR( 18),      
   @cOption             NVARCHAR(  1),      
   @cPDSKU              NVARCHAR( 20),      
   @cOrderActionFlag    NVARCHAR(  1),      
   @nQTY_PD             INT, -- (ChewKP01)      
   @nTotalPickedQty     INT, -- (ChewKP03)      
   @nTotalOrdPickedQty  INT, -- (ChewKP03)      
   @cDataStream         NVARCHAR( 4), -- (ChewKP03)      
   @cSKUDesc            NVARCHAR( 60), --(ChewKP04)  
   @nSKUCount           INT,       --(ChewKP04)  
   @nCount1             INT,       --(ChewKP04)  
   @cSuggestedSKU       NVARCHAR(20),  --(ChewKP04)  
   @cInSKU1             NVARCHAR(40),  --(CheWKP04)  
   @cInSKU2             NVARCHAR(40),  --(CheWKP04)  
   @cRDTBartenderSP     NVARCHAR(40),  --(ChewKP05)   
   @cDefaultTrackNo     NVARCHAR(1),   --(CheWKP05)  
   @cExecStatements     NVARCHAR(4000),--(ChewKP05)  
   @cExecArguments      NVARCHAR(4000),--(ChewKP05)  
   @cSuggestedTrackNo   NVARCHAR(18),  --(CheWKP05)  
   @cBackendPickConfirm NVARCHAR(1), 
   @nRowRef             INT, -- (ChewKP06)
   @cDataWindow         NVARCHAR(50), -- (ChewKP07)
   @cTargetDB           NVARCHAR(20), -- (ChewKP07)  
   @cExtendedUpdateSP   NVARCHAR(30), -- (ChewKP08)  
   @cSerialNo           NVARCHAR(30), -- (ChewKP08)  
   @cSQL                NVARCHAR(1000), -- (ChewKP08)    
   @cSQLParam           NVARCHAR(1000), -- (ChewKP08)     
   @cTrackNoCheckPickStatus NVARCHAR(1), -- (ChewKP01) 
   @cSkipTrackNo        NVARCHAR(1), -- (ChewKP11) 
   @nTranCount          INT,           -- (james04)
   @nErrNoCnt           INT,           -- (james04)
   @cSKUStatus          NVARCHAR( 10), -- (james05)
   @cExtendedValidateSP NVARCHAR( 20), -- (james06)
   @cExtValidate        VARIABLETABLE, -- (james06)
   @cDecodeSP           NVARCHAR( 20), -- (james07)
   @cBarcode            NVARCHAR( 60), -- (james07)
   @cTrackingNo         NVARCHAR( 60), -- (james07)
   @cUseTrackingNo      NVARCHAR( 20), -- (james07)

      
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
   @cFieldAttr15 NVARCHAR( 1),      
      
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),      
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),      
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),      
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),      
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)      
      
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
      
   @cOrderKey        = V_OrderKey,      
   @cSKU             = V_SKU,      
   @cTrackNo         = V_String1,      
   @cShipperKey      = V_String2,      
   @ErrMsgNextScreen = V_String3,      
   @cPickslipno      = V_String4,      
   @cOrderActionFlag = V_String5,      
   @cDecodeSP        = V_String6, -- (james07)  
   @cTrackingNo      = V_String7, -- (james07)  
   @cUseTrackingNo   = V_String8, -- (james07)  
   @cSuggestedSKU    = V_String9, -- (ChewKP04)     
   @cInSKU1          = V_String12, -- (ChewKP04)  
   @cInSKU2          = V_String13, -- (ChewKP04)  
   @cDefaultTrackNo  = V_String14, -- (ChewKP05)  
   @cSuggestedTrackNo = V_String15,-- (ChewKP05)  
   @cExtendedUpdateSP = V_String16, -- (ChewKP08)   
   @cBackendPickConfirm = V_String17, 
   @cTrackNoCheckPickStatus    = V_String18, -- (ChewKP09)
   @cSkipTrackNo        = V_String19, -- (ChewKP11) 
   @cSKUStatus          = V_String20, -- (james05) 
   @cExtendedValidateSP = V_String21, -- (james06)
     
   @nCount1          = V_Integer1,    
   @nSKUCount        = V_Integer2,
   @nAllocatedQty    = V_Integer3,   
   @nPickedQty       = V_Integer4,
   
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
IF @nFunc = 867      
BEGIN      
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 867      
   IF @nStep = 1 GOTO Step_1   -- Scn = 2710 Orderkey      
   IF @nStep = 2 GOTO Step_2   -- Scn = 2711 Track No      
   IF @nStep = 3 GOTO Step_3   -- Scn = 2712 SKU      
   IF @nStep = 4 GOTO Step_4   -- Scn = 2713 Success Message      
   IF @nStep = 5 GOTO Step_5   -- Scn = 2714 Options RESCAN / CONTINUE SCANNING      
   IF @nStep = 6 GOTO Step_6   -- Scn = 2715 1 UPC Multi SKU Selection Screen -- (ChewKP04)  
END      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step 0. Called from menu (func = 867)      
********************************************************************************/      
Step_0:      
BEGIN      
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
        SET @cExtendedUpdateSP = ''    
        
   SET @cTrackNoCheckPickStatus = rdt.RDTGetConfig( @nFunc, 'TrackNoCheckPickStatus', @cStorerKey)    
   IF @cTrackNoCheckPickStatus = '0'    
        SET @cTrackNoCheckPickStatus = ''            
        
   SET @cSkipTrackNo = rdt.RDTGetConfig( @nFunc, 'SkipTrackNo', @cStorerKey)    
   IF @cSkipTrackNo = '0'    
        SET @cSkipTrackNo = ''  

   -- (james05)
   SET @cSKUStatus  = ''
   SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)  
   IF @cSKUStatus = '0'
      SET @cSKUStatus = ''

   -- (james06)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
        SET @cExtendedValidateSP = ''   

   -- (james07)
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- (james07)
   SET @cUseTrackingNo = rdt.RDTGetConfig( @nFunc, 'UseTrackingNo', @cStorerKey)
   IF @cUseTrackingNo = '0'
      SET @cUseTrackingNo = ''

   -- Set the entry point      
   SET @nScn  = 2710      
   SET @nStep = 1      
      
   -- initialise all variable      
   SET @cOrderKey = ''      
   SET @cTrackNo = ''      
   SET @cOrderActionFlag = '1'      
   SET @cDefaultTrackNo = ''  

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
      
   -- Prep next screen var      
   SET @cOutField01 = ''      
END      
GOTO Quit      
      
/********************************************************************************      
Step 1. screen = 2710      
   OrderKey: (Field01, input)      
********************************************************************************/      
Step_1:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
 BEGIN      
      -- Screen mapping      
      SET @cOrderKey = ISNULL(RTRIM(@cInField01),'')      
      SET @cBarcode = ISNULL(RTRIM(@cInField01),'')
      
      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode, 
               @cUserDefine01 = @cOrderKey OUTPUT, 
               @nErrNo        = @nErrNo  OUTPUT, 
               @cErrMsg       = @cErrMsg OUTPUT,
               @cType         = 'UserDefine01'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cSKU, @cTrackNo , @cSerialNo, ' + 
               ' @cOrderKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cSKU         NVARCHAR( 20), ' +    
               ' @cTracKNo     NVARCHAR( 18), ' +   
               ' @cSerialNo    NVARCHAR( 30), ' +
               ' @cOrderKey    NVARCHAR( 10)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, 
               @cSKU, @cTrackNo , @cSerialNo, 
               @cOrderKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END
      
      SET @ErrMsgNextScreen = ''      
      SET @ErrMsgNextScreen = rdt.RDTGetConfig( @nFunc, 'ErrMsgNextScreen', @cStorerkey)      
      
      --When Lane is blank      
      IF @cOrderKey = ''      
      BEGIN      
         SET @nErrNo = 72441      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderKey req      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_1_Fail      
      END      
      
      --Check if Order exits      
      IF NOT EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)      
                     WHERE Orderkey = @cOrderkey      
                     AND Storerkey = @cStorerkey)      
      BEGIN      
          SET @nErrNo =  72453      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv OrderKey      
          EXEC rdt.rdtSetFocusField @nMobile, 1      
      
          IF @ErrMsgNextScreen = '1'      
          BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
          END      
      
          GOTO Step_1_Fail      
      END      
      
      -- (ChewKP02)      
      --Check if Order.SOStatus = 'HOLD'      
      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                 INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                     WHERE O.Orderkey = @cOrderkey      
                     AND O.Storerkey = @cStorerkey      
                     AND CL.Listname = 'SOStatus'      
                     AND CL.Code = 'HOLD'      
                     )      
      BEGIN      
         SET @nErrNo =  72467      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Hold!      
          EXEC rdt.rdtSetFocusField @nMobile, 1      
      
          IF @ErrMsgNextScreen = '1'      
          BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
          END      
      
          GOTO Step_1_Fail      
      END      
            
      -- (ChewKP03)      
      --Check if Order.SOStatus = 'PENDCANC'      
      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                 INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                     WHERE O.Orderkey = @cOrderkey      
                     AND O.Storerkey = @cStorerkey      
                     AND CL.Listname = 'SOStatus'      
                     AND CL.Code = 'PENDCANC'      
                     )      
      BEGIN      
         SET @nErrNo =  72470      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Waiting Cancel!      
          EXEC rdt.rdtSetFocusField @nMobile, 1      
      
          IF @ErrMsgNextScreen = '1'      
          BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
          END      
      
          GOTO Step_1_Fail      
      END      
        
      -- (ChewKP05)      
      --Check if Order.SOStatus = 'PENDCANC'      
      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
                 INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                     WHERE O.Orderkey = @cOrderkey      
                     AND O.Storerkey = @cStorerkey      
                     AND CL.Listname = 'SOStatus'      
                     AND CL.Code = 'CANC'      
                     )      
      BEGIN      
         SET @nErrNo =  72473      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Cancelled    
          EXEC rdt.rdtSetFocusField @nMobile, 1      
      
          IF @ErrMsgNextScreen = '1'      
          BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
          END      
      
          GOTO Step_1_Fail      
      END      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)      
                      WHERE OrderKey = @cOrderKey      
                      AND Storerkey = @cStorerKey      
                      AND Status ='0' 
                      AND ShipFlag <> 'P')   -- (james03)
      BEGIN      
          SET @nErrNo =  72442      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Picked      
          EXEC rdt.rdtSetFocusField @nMobile, 1      
      
          IF @ErrMsgNextScreen = '1'      
          BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
          END      
          GOTO Step_1_Fail      
      END      
      
      -- (james06)
      -- Extended validate      
      IF @cExtendedValidateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, ' + 
               ' @cExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile        INT, ' +    
               '@nFunc          INT, ' +    
               '@nStep          INT, ' +     
               '@cLangCode      NVARCHAR( 3),  ' +    
               '@cUserName      NVARCHAR( 18), ' +    
               '@cFacility      NVARCHAR( 5),  ' +    
               '@cStorerKey     NVARCHAR( 15), ' +    
               '@cOrderKey      NVARCHAR( 10), ' +    
               '@cSKU           NVARCHAR( 20), ' +    
               '@cTracKNo       NVARCHAR( 18), ' +   
               '@cSerialNo      NVARCHAR( 30), ' +    
               '@cExtValidate   VARIABLETABLE READONLY,  ' +
               '@nErrNo         INT           OUTPUT,    ' +    
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, 
               @cExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
         END
      END   

      -- Generate PickingInfo      
      SET @cPickSlipno = ''      
      SELECT @cPickSlipno = ISNULL(PickheaderKey,'')      
      FROM   dbo.PickHeader WITH (NOLOCK)      
      WHERE  OrderKey = @cOrderKey      
      
      -- Create Pickheader      
      IF ISNULL(RTRIM(@cPickSlipno) ,'')=''      
      BEGIN      
          EXECUTE dbo.nspg_GetKey      
          'PICKSLIP',      
          9,    
          @cPickslipno OUTPUT,      
          @b_success OUTPUT,      
          @nErrNo OUTPUT,      
          @cErrMsg OUTPUT      
      
          IF @nErrNo<>0      
          BEGIN      
              --ROLLBACK TRAN      
              SET @nErrNo = 72458      
              SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --GetDetKey Fail      
      
              IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
      
              GOTO Step_1_Fail      
          END      
      
          SELECT @cPickslipno = 'P'+@cPickslipno      
      
          BEGIN TRAN      
      
          INSERT INTO dbo.PICKHEADER      
            (      
              PickHeaderKey      
             ,ExternOrderKey      
             ,Orderkey      
             ,PickType      
             ,Zone      
             ,TrafficCop      
            )      
          VALUES      
            (      
              @cPickslipno      
             ,''      
             ,@cOrderKey      
             ,'0'      
             ,'D'      
             ,''      
            )      
      
          IF @@ERROR<>0      
          BEGIN      
              ROLLBACK TRAN      
              SET @nErrNo = 72459      
              SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --InstPKHdr Fail      
      
              IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
      
              GOTO Step_1_Fail      
          END      
          ELSE      
          BEGIN      
            COMMIT TRAN      
          END      
      
      END --ISNULL(@cPickSlipno, '') = ''      
      
      BEGIN TRAN      
      
      IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)      
      BEGIN
          INSERT INTO dbo.PickingInfo      
            (      
              PickSlipNo      
             ,ScanInDate      
             ,PickerID      
             ,ScanOutDate      
             ,AddWho
             ,TrafficCop   
            )      
          VALUES      
            (      
              @cPickSlipNo      
             ,GETDATE()      
             ,@cUserName      
             ,NULL      
             ,@cUserName
             ,'U'      
            )      
      
          IF @@ERROR<>0      
          BEGIN      
              ROLLBACK TRAN      
              SET @nErrNo = 72460      
              SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Scan In Fail      
      
              IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
      
              GOTO Step_1_Fail      
          END      
      END      
      COMMIT TRAN      
      
      -- Goto Option Screen when User Rescan Orderkey      
      IF EXISTS ( SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)      
                  Where OrderKey = @cOrderkey      
                  AND Storerkey = @cStorerkey )      
      BEGIN      
         SET @cOutField01 = ''      
         SET @nScn = @nScn + 4      
         SET @nStep = @nStep + 4      
      
         GOTO QUIT      
      END      
      
      SET @cOutField01 = @cOrderkey      
        
      -- (ChewKP05)  
      SET @cDefaultTrackNo = ''      
      SET @cDefaultTrackNo = rdt.RDTGetConfig( @nFunc, 'DefaultTrackNo', @cStorerkey)      
        
      IF @cDefaultTrackNo = '1'  
      BEGIN  
         SET @cSuggestedTrackNo = ''  
         --SELECT @cSuggestedTrackNo = UserDefine04  
         SELECT @cSuggestedTrackNo = TrackingNo -- (james08)
         FROM dbo.Orders WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND OrderKey = @cOrderKey   
           
         IF @cSuggestedTrackNo = ''  AND @cTrackingNo = ''
         BEGIN  
            SET @cSuggestedTrackNo = ''  
            SET @cTrackingNo = ''
            SET @cOutField02 = ''   
         END  
         ELSE  
         BEGIN  
            SET @cOutField02 = CASE WHEN @cUseTrackingNo = '1' AND @cTrackingNo <> '' THEN @cTrackingNo  
                               ELSE @cSuggestedTrackNo END  
         END  
           
      END  
      ELSE  
      BEGIN  
         SET @cOutField02 = ''      
      END  
        
        
      IF @cSkipTrackNo = '1' -- (ChewKP11) 
      BEGIN
         SET @nPickedQty = 0      
         SELECT @nPickedQty = SUM(Qty) FROM rdt.rdtTrackLog WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
         AND Storerkey = @cStorerkey      
         AND TrackNo = @cTrackNo      
         
         SET @nAllocatedQty = 0      
         SELECT @nAllocatedQty = SUM(Qty) FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
         AND Storerkey = @cStorerkey      
         
         SET @cOutField01 = @cOrderkey      
         SET @cOutField02 = @cTrackNo      
         SET @cOutField03 = ''      
         SET @cOutField04 = ISNULL(@nPickedQty,0)      
         SET @cOutField05 = ISNULL(@nAllocatedQty,0)    
         
         SET @nScn = @nScn + 2      
         SET @nStep = @nStep + 2      
      END
      ELSE
      BEGIN
         SET @nScn = @nScn + 1      
         SET @nStep = @nStep + 1      
      END
      
       -- insert to Eventlog      
       EXEC RDT.rdt_STD_EventLog      
           @cActionType   = '1', -- SignIn      
           @cUserID       = @cUserName,      
           @nMobileNo     = @nMobile,      
           @nFunctionID   = @nFunc,      
           @cFacility     = @cFacility,      
           @cStorerKey    = @cStorerkey,      
           @cRefNo1       = @cOrderkey,      
           @cRefNo2       = ''   
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      EXEC RDT.rdt_STD_EventLog      
      @cActionType   = '9', -- SignOut      
      @cUserID       = @cUserName,      
      @nMobileNo     = @nMobile,      
      @nFunctionID   = @nFunc,      
      @cFacility     = @cFacility,      
      @cStorerKey    = @cStorerkey,      
      @cRefNo1       = @cOrderkey,      
      @cRefNo2       = ''  
      
      -- Back to menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      
      SET @cOutField01 = ''      
      SET @cOrderKey = ''      
      
   END      
   GOTO Quit      
      
   Step_1_Fail:      
   BEGIN      
      SET @cOrderKey = ''      
      SET @cOutField01 = ''      
   END      
END      
GOTO Quit      
      
/********************************************************************************      
Step 2. screen = 2711      
   Orderkey (Field01)      
   Track No (Field02, Input)      
********************************************************************************/      
Step_2:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cTrackNo = @cInField02      
      
      IF ISNULL(@cTrackNo, '') = ''      
      BEGIN      
         SET @nErrNo = 72444      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNo req      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_2_Fail      
      END      
      
      SET @cShipperKey = ''      
      SET @cOrderTrackNo = ''      
      SELECT @cShipperKey = ShipperKey,      
             --@cOrderTrackNo = UserDefine04      
             @cOrderTrackNo = TrackingNo  -- (james08)
      FROM dbo.ORDERS WITH (NOLOCK)      
      WHERE Orderkey = @cOrderkey      
      AND Storerkey = @cStorerkey      

      IF @cUseTrackingNo = '1' AND @cTrackingNo <> ''
         SET @cOrderTrackNo = @cTrackingNo

      IF ISNULL(@cShipperKey,'') = ''      
      BEGIN      
         SET @nErrNo = 72455      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv ShipperKey      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_2_Fail      
      END      
      
      SET @cTrackRegExp = ''      
      SELECT @cTrackRegExp = Notes1 FROM dbo.Storer WITH (NOLOCK)      
      WHERE Storerkey = @cShipperKey      
      
      IF ISNULL(@cTrackRegExp,'') <> ''      
      BEGIN      
         IF master.dbo.RegExIsMatch(ISNULL(RTRIM(@cTrackRegExp),''),ISNULL(RTRIM(@cTrackNo),''), 1) <> 1 -- (james02)     
         BEGIN      
               SET @nErrNo = 72445      
               SET @cErrMsg = rdt.rdtgEtmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo      
               EXEC rdt.rdtSetFocusField @nMobile, 1      
      
               IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
      
               GOTO Step_2_Fail      
         END    
      END      
      
      --SOS#230128 Start      
      IF EXISTS (SELECT 1 FROM RDT.RDTTrackLog WITH (NOLOCK)      
                 WHERE TrackNo = ISNULL(RTRIM(@cTrackNo),''))      
      BEGIN      
         
         IF @cTrackNoCheckPickStatus = '1' -- (ChewKP09)
         BEGIN 
            IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                            WHERE Orderkey = @cOrderkey      
                              AND Storerkey = @cStorerkey      
                              AND Status = '0'  
                              AND ShipFlag <> 'P' ) 
            BEGIN
               SET @nErrNo = 72475      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoCompleted      
               EXEC rdt.rdtSetFocusField @nMobile, 1      
            
               IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
                  
               GOTO Step_2_Fail  
            END
         END
         ELSE
         BEGIN
            SET @nErrNo = 72469      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TrackNoInUsed      
            EXEC rdt.rdtSetFocusField @nMobile, 1      
         
            IF @ErrMsgNextScreen = '1'      
            BEGIN      
               --SET @nErrNo = 0      
               SET @cErrMsg1 = @nErrNo      
               SET @cErrMsg2 = @cErrMsg      
               SET @cErrMsg3 = ''      
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
            END      
               
            GOTO Step_2_Fail      
         END
      END      
      --SOS#230128 End      
      
      IF EXISTS (SELECT 1 FROM dbo.ORDERS WITH  (NOLOCK) 
                 WHERE Storerkey =  @cStorerKey      
                 --AND USerDefine04 = ISNULL(RTRIM(@cTrackNo),'')      
                 AND TrackingNo = ISNULL(RTRIM(@cTrackNo),'')  -- (james08)
                 AND Orderkey <> @cOrderkey
                 AND SOStatus <> 'CANC')      
      BEGIN      
             SET @nErrNo = 72456      
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv TrackNo'      
      
             IF @ErrMsgNextScreen = '1'      
             BEGIN      
               --SET @nErrNo = 0      
               SET @cErrMsg1 = @nErrNo      
               SET @cErrMsg2 = @cErrMsg      
               SET @cErrMsg3 = ''      
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
             END      
      
             GOTO Step_2_Fail      
      END      
      
      IF ISNULL(RTRIM(@cOrderTrackNo),'') <> ''      
      BEGIN      
         IF ISNULL(RTRIM(@cOrderTrackNo),'') <> ISNULL(RTRIM(@cTrackNo),'')      
         BEGIN      
               SET @nErrNo = 72461      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv TrackNo'      
      
      
               IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
               GOTO Step_2_Fail      
         END      
      END      

      IF @cOrderActionFlag = '1'      
      BEGIN      
         -- INSERT ALL SKU From Orders to Rdt.RdtTracKLog      
         BEGIN TRAN
      
         DECLARE CursorSKUInsert CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      
         SELECT SKU, SUM(Qty) -- (ChewKP01)      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            AND Status = '0'  
            AND ShipFlag <> 'P' -- (ChewKP09)
         GROUP By SKU      
         ORDER By SKU      
      
         OPEN CursorSKUInsert      
         FETCH NEXT FROM CursorSKUInsert INTO @cPDSKU, @nPDQty      
         WHILE @@FETCH_STATUS <> -1      
         BEGIN      
      
            IF NOT EXISTS ( SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK) -- (ChewKP09)
                            WHERE Mobile      = @nMobile 
                             AND UserName     = @cUserName
                             AND StorerKey    = @cStorerKey
                             AND Orderkey     = @cOrderKey 
                             AND TrackNo      = @cTrackNo 
                             AND SKU          = @cSKU
                             AND QtyAllocated = @nPDQty ) 
            BEGIN
               INSERT INTO rdt.rdtTrackLog ( Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, QtyAllocated)      
               VALUES (@nMobile, @cUserName, @cStorerkey, @cOrderKey, @cTrackNo, @cPDSKU, 0 , @nPDQty)      
         
                IF @@ERROR <> 0      
                BEGIN      
                     SET @nErrNo = 72465      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'      
                     ROLLBACK TRAN
         
                     IF @ErrMsgNextScreen = '1'      
                     BEGIN      
                        --SET @nErrNo = 0      
                        SET @cErrMsg1 = @nErrNo      
                        SET @cErrMsg2 = @cErrMsg      
                        SET @cErrMsg3 = ''      
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
                     END      
                     GOTO Step_2_Fail      
               END   
            END            
      
            FETCH NEXT FROM CursorSKUInsert INTO @cPDSKU, @nPDQty      
         END      
         CLOSE CursorSKUInsert      
         DEALLOCATE CursorSKUInsert      
      
         COMMIT TRAN
      
      END      
        
      -- (ChewKP05)  
      SET @cRDTBartenderSP = ''      
      SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)      
        
      IF @cRDTBartenderSP <> ''  
      BEGIN  
           
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')  
         BEGIN  
              
              
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +   
                                    '   @nMobile               ' +    
                                    ' , @nFunc                 ' +                     
                                    ' , @cLangCode             ' +        
                                    ' , @cFacility             ' +        
                                    ' , @cStorerKey            ' +     
                                    ' , @cPrinter              ' +     
                                    ' , @cOrderKey             ' +           
                                    ' , @cTrackNo              ' +   
                                    ' , @cUserName             ' +   
                                    ' , @nErrNo       OUTPUT   ' +  
                                    ' , @cErrMSG      OUTPUT   '   
  
               
            SET @cExecArguments =   
                      N'@nMobile     int,                    ' +  
                       '@nFunc       int,                    ' +      
                       '@cLangCode   nvarchar(3),            ' +      
                       '@cFacility   nvarchar(5),            ' +      
                       '@cStorerKey  nvarchar(15),           ' +      
                       '@cPrinter    nvarchar(10),           ' +     
                       '@cOrderKey   nvarchar(10),           ' +      
                       '@cTrackNo    nvarchar(10),           ' +      
                       '@cUserName   nvarchar(18),           ' +  
                       '@nErrNo      int  OUTPUT,            ' +  
                       '@cErrMsg     nvarchar(1024) OUTPUT   '   
                         
         
              
            EXEC sp_executesql @cExecStatements, @cExecArguments,   
                                  @nMobile                 
                                , @nFunc                                   
                                , @cLangCode                      
                                , @cFacility         
                                , @cStorerKey     
                                , @cPrinter              
                                , @cOrderKey                  
                                , @cTrackNo  
                                , @cUserName  
                                , @nErrNo       OUTPUT     
                                , @cErrMSG      OUTPUT     
               
             IF @@ERROR <> 0      
             BEGIN      
                  --SET @nErrNo = 72465      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'      
                  ROLLBACK TRAN      
      
                  IF @ErrMsgNextScreen = '1'      
                  BEGIN      
                     --SET @nErrNo = 0      
                     SET @cErrMsg1 = @nErrNo      
                     SET @cErrMsg2 = @cErrMsg      
                     SET @cErrMsg3 = ''      
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
                  END      
                  GOTO Step_2_Fail      
            END    
         END  
      END  
      
      SET @nPickedQty = 0      
      SELECT @nPickedQty = SUM(Qty) FROM rdt.rdtTrackLog WITH (NOLOCK)      
      WHERE Orderkey = @cOrderkey      
      AND Storerkey = @cStorerkey      
      AND TrackNo = @cTrackNo      
      
      SET @nAllocatedQty = 0      
      SELECT @nAllocatedQty = SUM(Qty) FROM dbo.PickDetail WITH (NOLOCK)      
      WHERE Orderkey = @cOrderkey      
      AND Storerkey = @cStorerkey      
      
      SET @cOutField01 = @cOrderkey      
      SET @cOutField02 = @cTrackNo      
      SET @cOutField03 = ''      
      SET @cOutField04 = ISNULL(@nPickedQty,0)      
      SET @cOutField05 = ISNULL(@nAllocatedQty,0)      
      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      SET @cOutField01 = @cOrderkey      
      SET @cOutField02 = ''      
        
      SET @nScn = @nScn - 1      
      SET @nStep = @nStep - 1      
   END      
   GOTO Quit      
      
   Step_2_Fail:      
   BEGIN      
        
      IF @cDefaultTrackNo = '1'  
      BEGIN  
           
         SET @cOutField02 = @cSuggestedTrackNo  
      END  
      ELSE  
      BEGIN  
           
         SET @cOutField02 = ''      
      END           
           
   END      
END      
GOTO Quit      
      
/********************************************************************************      
Step 3. screen = 2712      
   Orderkey (Field01)      
   Track No (Field02)      
   QTY EXP  (Field03)      
   QTY PICK (Field04)      
   SKU      (Field03, Input)      
********************************************************************************/      
Step_3:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cInSKU = ISNULL(RTRIM(@cInField03),'')      
        
      SET @cInSKU1 = LEFT(@cInSKU,20)  
      SET @cInSKU2 = SUBSTRING(@cInSKU,21,20)  
   
      IF ISNULL(@cInSKU, '') = ''      
      BEGIN      
         SET @nErrNo = 72447      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU req      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_3_Fail      
      END      
      
      SET @cDecodeLabelNo = ''      
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)      
      
      IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS293491  
      BEGIN      
         EXEC dbo.ispLabelNo_Decoding_Wrapper      
          @c_SPName     = @cDecodeLabelNo      
         ,@c_LabelNo    = @cInSKU      
         ,@c_Storerkey  = @cStorerkey      
         ,@c_ReceiptKey = ''      
         ,@c_POKey      = ''      
         ,@c_LangCode   = @cLangCode      
         ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU      
         ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE      
         ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR      
         ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE      
         ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY      
         ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#      
         ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- SerialNo#  
         ,@c_oFieled08  = @c_oFieled08 OUTPUT      
         ,@c_oFieled09  = @c_oFieled09 OUTPUT      
         ,@c_oFieled10  = @c_oFieled10 OUTPUT      
         ,@b_Success    = @b_Success   OUTPUT      
         ,@n_ErrNo      = @nErrNo      OUTPUT      
         ,@c_ErrMsg     = @cErrMsg     OUTPUT      
      
         IF ISNULL(@cErrMsg, '') <> ''      
         BEGIN      
            SET @cErrMsg = @cErrMsg      
            GOTO Step_3_Fail      
         END      
      
         SET @cSKU = @c_oFieled01      
         SET @cSerialNo = @c_oFieled07 -- (ChewKP08)  
      END      
      ELSE      
      BEGIN      
         SET @cSKU = ISNULL(@cInSKU,'')      
      END      
        
      --Performance tuning -- (ChewKP04)  
      EXEC [RDT].[rdt_GETSKUCNT]  
       @cStorerKey  = @cStorerkey  
      ,@cSKU        = @cInSKU                    
      ,@nSKUCnt     = @nCount1       OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @nErrNo        OUTPUT  
      ,@cErrMsg     = @cErrMsg       OUTPUT  
      ,@cSKUStatus  = @cSKUStatus
        
      -- Validate SKU/UPC  
      IF @nCount1 > 1   
      BEGIN  
           
         SELECT Top 1 @cSuggestedSKU = SKU   
         FROM dbo.UPC WITH (NOLOCK)  
         WHERE UPC = @cInSKU  
         AND StorerKey = @cStorerKey  
         Order By SKU  
           
         SELECT @cSKUDesc = CASE WHEN ISNULL(BUSR2,'') <> '' THEN BUSR2  
                          ELSE Descr  
                          END  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE SKU = @cSuggestedSKU  
         AND StorerKey = @cStorerKey  
           
         SET @nSKUCount = 1  
           
         SET @cOutField01 = CAST(@nSKUCount AS NVARCHAR(5)) + '/' + CAST(@nCount1 AS NVARCHAR(5))   
         SET @cOutField02 = @cSuggestedSKU  
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  
         SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)  
         SET @cOutField05 = ''  
           
         SET @nScn = @nScn + 3      
         SET @nStep = @nStep + 3      
           
         GOTO QUIT  
      END    
      
      EXEC [RDT].[rdt_GETSKU]      
               @cStorerKey  = @cStorerkey,      
               @cSKU        = @cSKU          OUTPUT,      
               @bSuccess    = @b_Success     OUTPUT,      
               @nErr        = @nErrNo        OUTPUT,      
               @cErrMsg     = @cErrMsg       OUTPUT,
               @cSKUStatus  = @cSKUStatus
      
      IF @nErrNo <> 0      
      BEGIN      
         SET @nErrNo = 72457      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_3_Fail      
      END      
      
      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)      
                     WHERE Orderkey = @cOrderkey      
                     AND Storerkey = @cStorerkey      
                     AND SKU = @cSKU      
                     AND Status = '0')      
      BEGIN      
         SET @nErrNo = 72448      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Changed      
         EXEC rdt.rdtSetFocusField @nMobile, 1      
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_3_Fail      
      END      
      
      -- (ChewKP02)      
      --Check if Order.SOStatus = 'HOLD'      
      IF EXISTS (SELECT 1 FROM dbo.Orders O WITH (NOLOCK)      
       INNER JOIN dbo.CodeLkup CL WITH (NOLOCK) ON CL.CODE = O.SOSTATUS      
                     WHERE O.Orderkey = @cOrderkey      
                     AND O.Storerkey = @cStorerkey      
                     AND CL.Listname = 'SOStatus'      
                     AND CL.Code = 'HOLD'      
                     )      
      BEGIN      
         SET @nErrNo =  72468      
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order Hold!      
          EXEC rdt.rdtSetFocusField @nMobile, 1      
      
          IF @ErrMsgNextScreen = '1'      
          BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
          END      
      
          GOTO Step_3_Fail      
      END      

      -- (james04)
      SET @nErrNoCnt = 0
      SET @nTranCount = @@TRANCOUNT    

      BEGIN TRAN    
      SAVE TRAN rdt_867Step3

      IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)      
                 WHERE Orderkey = @cOrderkey      
                 AND SKU = @cSKU      
                 AND TrackNo = @cTrackNo      
                 AND Storerkey = @cStorerkey )      
      BEGIN      
         SET @nAllocatedQty = 0      
         SELECT @nAllocatedQty = SUM(Qty) FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
         AND SKU = @cSKU      
         AND Storerkey = @cStorerkey      
      
         SET @nPickedQty = 0      
         SELECT @nPickedQty = SUM(Qty) FROM rdt.rdtTrackLog WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
         AND SKU = @cSKU      
         AND Storerkey = @cStorerkey      
         AND TrackNo = @cTrackNo      
      
         IF (@nPickedQty + 1) <= @nAllocatedQty      
         BEGIN      
            -- (ChewKP06) 
            SET @nRowRef = 0 
            SELECT @nRowRef = RowRef 
            FROM rdt.rdtTrackLog WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey      
            AND SKU = @cSKU      
            AND Storerkey = @cStorerkey      
            AND TrackNo = @cTrackNo  
            
            UPDATE rdt.rdtTrackLog      
            SET Qty = Qty + 1,      
            EditWho = @cUserName,      
            EditDate = GetDate()  
            WHERE RowRef = @nRowRef    

            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 72450      
               SET @nErrNoCnt = 1
               GOTO RollBackTran
            END    
         END      
         ELSE      
         BEGIN      
            SET @nErrNo = 72451    
            SET @nErrNoCnt = 1
            GOTO RollBackTran  
         END      
     END      
     ELSE      
     BEGIN      
         SET @nAllocatedQty = 0      
         SELECT @nAllocatedQty = SUM(Qty) FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
         AND SKU = @cSKU      
         AND Storerkey = @cStorerkey      
      
         INSERT INTO rdt.rdtTrackLog ( Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, QtyAllocated)      
         VALUES (@nMobile, @cUserName, @cStorerkey, @cOrderKey, @cTrackNo, @cSKU, 1 , @nAllocatedQty)      
      
          IF @@ERROR <> 0      
          BEGIN      
            SET @nErrNo = 72449   
            SET @nErrNoCnt = 1
            GOTO RollBackTran                  
         END      
     END      

     SET @nPickCheck = 0      
     SELECT @nPickDetailCheck = SUM(PD.QTY)      
     FROM PICKDETAIL PD WITH (NOLOCK)      
     WHERE PD.ORDERKEY = @cOrderKey      
     AND PD.Storerkey = @cStorerkey      
     AND PD.Status <> '5' AND ShipFlag <> 'P'
     
     SET @nTrackLogCheck = 0      
     SELECT @nTrackLogCheck = SUM(LG.QTY)      
     FROM rdt.rdtTrackLog LG WITH (NOLOCK)      
     WHERE LG.ORDERKEY = @cOrderKey      
     AND LG.Storerkey = @cStorerkey      
     AND LG.Status <> '9'      
      
     SET @nPickCheck = @nPickDetailCheck - @nTrackLogCheck      
      
     IF  @nPickCheck <> 0      
     BEGIN      
       SET @cOutField03 = ''      
     END      
     ELSE      
     BEGIN      
        DECLARE @cTrackLogSKU NVARCHAR( 20)
         -- Confirm PickDetail      
         DECLARE CursorTrackLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      
         SELECT SKU, Qty      
         FROM rdt.rdtTrackLog WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            AND TrackNo = @cTrackNo      
            AND Status = '0'      
         ORDER By SKU      
      
         OPEN CursorTrackLog      
         FETCH NEXT FROM CursorTrackLog INTO @cTrackLogSKU, @nQty      
         WHILE @@FETCH_STATUS <> -1      
         BEGIN      
            SET @nQTY_PD = @nQty -- (ChewKP01)      
      
            DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      
            SELECT PickDetailKey, Qty      
            FROM dbo.PickDetail WITH (NOLOCK)      
            WHERE Orderkey = @cOrderkey      
               AND Storerkey = @cStorerkey      
               AND SKU = @cTrackLogSKU      
               AND Status = '0'    
               AND ShipFlag <> 'P'  
            ORDER By PickDetailKey      
      
            OPEN CursorPickDetail      
            FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty      
            WHILE @@FETCH_STATUS <> -1      
            BEGIN      
                  -- (ChewKP01) Rework on PickDetail Update Logic      
                  IF @nQTY_PD = @nPDQty      
                  BEGIN      
                     IF @cBackendPickConfirm = '1'
                        UPDATE PickDetail WITH (ROWLOCK) SET 
                            ShipFlag = 'P',      
                            EditDate = GETDATE(),    
                            EditWho = SUSER_SNAME()
                        WHERE PickDetailkey = @cPickDetailKey          
                     ELSE
                        UPDATE PickDetail WITH (ROWLOCK) SET 
                            Status = '5',      
                            EditDate = GETDATE(),    
                            EditWho = SUSER_SNAME() 
                        WHERE PickDetailkey = @cPickDetailKey          
      
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @nErrNo = 72452   
                        SET @nErrNoCnt = 1   

                        CLOSE CursorPickDetail      
                        DEALLOCATE CursorPickDetail      

                        CLOSE CursorTrackLog      
                        DEALLOCATE CursorTrackLog  

                        GOTO RollBackTran
                     END      
                     SET @nQty_PD = 0      
                  END      
                  ELSE IF @nQTY_PD > @nPDQty      
                  BEGIN      
                     IF @cBackendPickConfirm = '1'
                        UPDATE PickDetail WITH (ROWLOCK) SET 
                            ShipFlag = 'P',  
                            EditDate = GETDATE(),    
                            EditWho = SUSER_SNAME()
                        WHERE PickDetailkey = @cPickDetailKey      
                     ELSE
                        UPDATE PickDetail WITH (ROWLOCK) SET 
                            Status = '5',  
                            EditDate = GETDATE(),    
                            EditWho = SUSER_SNAME()     
                        WHERE PickDetailkey = @cPickDetailKey      
      
                     IF @@ERROR <> 0      
                     BEGIN      
                        SET @nErrNo = 72466      
                        SET @nErrNoCnt = 1

                        CLOSE CursorPickDetail      
                        DEALLOCATE CursorPickDetail      

                        CLOSE CursorTrackLog      
                        DEALLOCATE CursorTrackLog  

                        GOTO RollBackTran
                     END      
                     SET @nQty_PD = @nQty_PD - @nPDQty      
                  END      
               FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty      
            END      
            CLOSE CursorPickDetail      
            DEALLOCATE CursorPickDetail      
      
            FETCH NEXT FROM CursorTrackLog INTO @cTrackLogSKU, @nQty      
         END      
      
         CLOSE CursorTrackLog      
         DEALLOCATE CursorTrackLog      
      
         -- (ChewKP06) 
         -- Confirm PickDetail     
         SET @nRowRef = 0 
         DECLARE CursorTrackLogUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      
         SELECT RowRef    
         FROM rdt.rdtTrackLog WITH (NOLOCK)      
         WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            AND TrackNo = @cTrackNo 
         ORDER By RowRef   
      
         OPEN CursorTrackLogUpdate      
         FETCH NEXT FROM CursorTrackLogUpdate INTO @nRowRef
         WHILE @@FETCH_STATUS <> -1      
         BEGIN      
            -- Update rdt.rdtTracklog      
            Update RDT.rdtTrackLog      
            SET Status = '9'    
            WHERE RowRef = @nRowRef
         
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 72454      
               SET @nErrNoCnt = 1

               CLOSE CursorTrackLogUpdate      
               DEALLOCATE CursorTrackLogUpdate   

               GOTO RollBackTran
            END      
            
            FETCH NEXT FROM CursorTrackLogUpdate INTO @nRowRef
            
         END
         CLOSE CursorTrackLogUpdate      
         DEALLOCATE CursorTrackLogUpdate   
         
         --ScanOut on  PickingInfo      
         UPDATE dbo.PickingInfo WITH (ROWLOCK)      
         SET ScanOutDate = GetDate()      
         WHERE PickSlipNo = @cPickSlipNo      
      
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 72464      

            SET @nErrNoCnt = 1 
            GOTO RollBackTran
         END      
      
         EXEC RDT.rdt_STD_EventLog      
            @cActionType   = '3', -- Confirm Picking      
            @cUserID       = @cUserName,      
            @nMobileNo     = @nMobile,      
            @nFunctionID   = @nFunc,      
            @cFacility     = @cFacility,      
            @cStorerKey    = @cStorerkey,      
            @cRefNo1       = @cOrderkey,      
            @cRefNo2       = @cTrackNo
     END      

      -- (ChewKP08)   
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
             
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            '@nMobile        INT, ' +    
            '@nFunc          INT, ' +    
            '@nStep          INT, ' +     
            '@cLangCode      NVARCHAR( 3),  ' +    
            '@cUserName      NVARCHAR( 18), ' +    
            '@cFacility      NVARCHAR( 5),  ' +    
            '@cStorerKey     NVARCHAR( 15), ' +    
            '@cOrderKey      NVARCHAR( 10), ' +    
            '@cSKU           NVARCHAR( 20), ' +    
            '@cTracKNo       NVARCHAR( 18), ' +   
            '@cSerialNo      NVARCHAR( 30), ' +    
            '@nErrNo         INT           OUTPUT, ' +    
            '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
            GOTO RollBackTran    
      END   

      GOTO CommitTrans
   
      RollBackTran:  
            ROLLBACK TRAN rdt_867Step3  

      CommitTrans:  
         WHILE @@TRANCOUNT > @nTranCount  
            COMMIT TRAN       
     
      IF @nErrNoCnt > 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
         GOTO Step_3_Fail
      END

     SET @nPickedQty = 0      
     SELECT @nPickedQty = SUM(Qty) FROM rdt.rdtTrackLog WITH (NOLOCK)      
     WHERE Orderkey = @cOrderkey      
     AND Storerkey = @cStorerkey      
     AND TrackNo = @cTrackNo      
     --AND @cUserName = @cUserName      
      
     SET @nAllocatedQty = 0      
     SELECT @nAllocatedQty = SUM(Qty)      
     FROM dbo.PickDetail WITH (NOLOCK)      
     WHERE Orderkey = @cOrderkey      
     AND Storerkey = @cStorerkey      
           
     SET @nTotalOrdPickedQty = 0       
     SET @nTotalPickedQty = 0      
           
     SELECT @nTotalOrdPickedQty = SUM(QtyPicked)      
     FROM OrderDetail  WITH (NOLOCK) 
     WHERE Orderkey = @cOrderkey      
     AND Storerkey = @cStorerkey      
           
     SELECT @nTotalPickedQty = SUM(Qty)      
     FROM dbo.PickDetail WITH (NOLOCK)      
     WHERE Orderkey = @cOrderkey      
     AND Storerkey = @cStorerkey      
     AND (Status = '5' OR ShipFlag = 'P')
      
     SET @cOutField04 = @nPickedQty      
     SET @cOutField05 = @nAllocatedQty      
           
     IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)      
                 WHERE Storerkey = @cStorerkey      
                 AND Orderkey = @cOrderkey      
                 AND (STATUS = '0' AND ShipFlag = '0'))                       
     BEGIN      
        -- (ChewKP03)       
        -- WebService Execution      
        IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)      
                    WHERE OrderKey = @cOrderKey      
                    AND StorerKey = @cStorerKey      
                    AND Status = '5' )      
        BEGIN      
            IF ISNULL(@nTotalOrdPickedQty,0) = ISNULL(@nTotalPickedQty,0)      
            BEGIN      
--               EXEC dbo.isp0000P_RG_WS_BAISON_UpdOrdSts      
--                    @cOrderKey      
--                  , @cStorerKey      
--                  , '0033'       
--                  , @b_Success OUTPUT      
--                  , @nErrNo    OUTPUT      
--                  , @cErrMsg   OUTPUT      
--                  , 0 -- @b_Debug      

              EXEC  [isp_WS_UpdPackOrdSts]  
                    @cOrderKey   
                  , @cStorerKey   
                  , @b_Success OUTPUT  
                  , @nErrNo    OUTPUT  
                  , @cErrMsg   OUTPUT    
            END      
        END
        
        -- (ChewKP07) 
        SELECT @cDataWindow = DataWindow,     
               @cTargetDB = TargetDB     
        FROM rdt.rdtReport WITH (NOLOCK)     
        WHERE StorerKey = @cStorerKey    
        AND   ReportType = 'TNOMANFEST'  
        
        IF ISNULL(RTRIM(@cDataWindow),'')  <> '' 
        BEGIN
           IF ISNULL(RTRIM(@cPrinter_Paper),'')   = ''
           BEGIN
               SET @nErrNo = 72474      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PaperPrinterReq'      
               --ROLLBACK TRAN  -- (ChewKP10) 
               IF @ErrMsgNextScreen = '1'      
                BEGIN      
                   --SET @nErrNo = 0      
                   SET @cErrMsg1 = @nErrNo      
                   SET @cErrMsg2 = @cErrMsg      
                   SET @cErrMsg3 = ''      
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
                END      
               GOTO Step_3_Fail      
           END
           
           -- Print PackList 
           IF @cPrinter_Paper <> 'PDF'
              EXEC RDT.rdt_BuiltPrintJob        
                @nMobile,      
                @cStorerKey,      
                'BAGMANFEST',              -- ReportType      
                'CUSTOMERMANIFEST',        -- PrintJobName      
                @cDataWindow,      
                @cPrinter_Paper,      
                @cTargetDB,      
                @cLangCode,      
                @nErrNo  OUTPUT,      
                @cErrMsg OUTPUT,       
                @cOrderKey,     
             ''
        END   
        
        SET @nScn = @nScn + 1      
        SET @nStep = @nStep + 1      
     END      
      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      
      
      IF @cSkipTrackNo = '1' -- (ChewKP11) 
      BEGIN
         SET @cOutField01 = ''      
         
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2    
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cOrderkey      
         SET @cOutField02 = @cTrackNo      
         SET @cOutField03 = ''      
      
         SET @nScn = @nScn - 1      
         SET @nStep = @nStep - 1    
         
      END  
   END      
   GOTO Quit      
      
   Step_3_Fail:      
   BEGIN      
      SET @cOutField03 = ''      
   END      
END      
GOTO Quit      
      
/********************************************************************************      
Step 4. screen = 2713      
   Success Message      
********************************************************************************/      
Step_4:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- (ChewKP12)   
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
             
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
         SET @cSQLParam =    
            '@nMobile        INT, ' +    
            '@nFunc          INT, ' +    
            '@nStep          INT, ' +     
            '@cLangCode      NVARCHAR( 3),  ' +    
            '@cUserName      NVARCHAR( 18), ' +    
            '@cFacility      NVARCHAR( 5),  ' +    
            '@cStorerKey     NVARCHAR( 15), ' +    
            '@cOrderKey      NVARCHAR( 10), ' +    
            '@cSKU           NVARCHAR( 20), ' +    
            '@cTracKNo       NVARCHAR( 18), ' +   
            '@cSerialNo      NVARCHAR( 30), ' +    
            '@nErrNo         INT           OUTPUT, ' +    
            '@cErrMsg        NVARCHAR( 20) OUTPUT'    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            GOTO Quit    
         END    
             
           
      END   
      
      SET @cOutField01 = ''      
      SET @nScn = @nScn - 3      
      SET @nStep = @nStep - 3      
   END      
END      
GOTO Quit      
      
/********************************************************************************      
Step 5. screen = 2714      
   Option      
********************************************************************************/      
Step_5:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
       --screen mapping      
      SET @cOption = ISNULL(@cInField01,'')      
      
      IF ISNULL(RTRIM(@cOption), '') = ''      
      BEGIN      
         SET @nErrNo = 72462      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      
         GOTO Step_5_Fail      
      END      
      
      IF ISNULL(RTRIM(@cOption), '') <> '1' AND ISNULL(RTRIM(@cOption), '') <> '9'      
      BEGIN      
         SET @nErrNo = 72463      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'      
         GOTO Step_5_Fail      
         IF @ErrMsgNextScreen = '1'      
         BEGIN      
            --SET @nErrNo = 0      
            SET @cErrMsg1 = @nErrNo      
            SET @cErrMsg2 = @cErrMsg      
            SET @cErrMsg3 = ''      
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
         END      
      END      
      
      IF @cOption = '1'      
      BEGIN      
         SET @cOrderActionFlag = '1'    
         
         -- (ChewKP09)   
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
                
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               '@nMobile        INT, ' +    
               '@nFunc          INT, ' +    
               '@nStep          INT, ' +     
               '@cLangCode      NVARCHAR( 3),  ' +    
               '@cUserName      NVARCHAR( 18), ' +    
               '@cFacility      NVARCHAR( 5),  ' +    
               '@cStorerKey     NVARCHAR( 15), ' +    
               '@cOrderKey      NVARCHAR( 10), ' +    
               '@cSKU           NVARCHAR( 20), ' +    
               '@cTracKNo       NVARCHAR( 18), ' +   
               '@cSerialNo      NVARCHAR( 30), ' +    
               '@nErrNo         INT           OUTPUT, ' +    
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @nStep, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, @cSKU, @cTrackNo, @cSerialNo, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
            BEGIN    
               GOTO Step_5_Fail    
            END    
                
              
         END     
      
         BEGIN TRAN      
         DELETE FROM rdt.rdtTrackLog      
         WHERE Orderkey = @cOrderkey      
      
         IF @@ERROR <> 0      
         BEGIN      
               SET @nErrNo = 72443      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelLog Failed'      
               ROLLBACK TRAN      
      
               IF @ErrMsgNextScreen = '1'      
               BEGIN      
                  --SET @nErrNo = 0      
                  SET @cErrMsg1 = @nErrNo      
                  SET @cErrMsg2 = @cErrMsg      
                  SET @cErrMsg3 = ''      
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
               END      
               GOTO Step_5_Fail      
         END      
         ELSE      
         BEGIN      
            COMMIT TRAN      
         END      
         
         
         IF @cSkipTrackNo = '1' -- (ChewKP11) 
         BEGIN
            --GOTO TrackNo Screen      
            SET @nPickedQty = 0      
            SELECT @nPickedQty = SUM(Qty) FROM rdt.rdtTrackLog WITH (NOLOCK)      
            WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            AND TrackNo = @cTrackNo      
            --AND @cUserName = @cUserName      
            
            SET @nAllocatedQty = 0      
            SELECT @nAllocatedQty = SUM(Qty) FROM dbo.PickDetail WITH (NOLOCK)      
            WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            
            SET @cOutField01 = @cOrderkey      
            SET @cOutField02 = @cTrackNo      
            SET @cOutField03 = ''      
            SET @cOutField04 = ISNULL(@nPickedQty,0)      
            SET @cOutField05 = ISNULL(@nAllocatedQty,0)    
            
         
            SET @nScn = @nScn - 2
            SET @nStep = @nStep - 2      
         END
         ELSE
         BEGIN
            --GOTO TrackNo Screen      
            SET @cOutField01 = @cOrderkey      
            SET @cOutField02 = ''      
         
            SET @nScn = @nScn - 3      
            SET @nStep = @nStep - 3      
         END
      END      
      
      IF @cOption = '9'      
      BEGIN      
         IF @cSkipTrackNo = '1' -- (ChewKP11) 
         BEGIN
            SET @nPickedQty = 0      
            SELECT @nPickedQty = SUM(Qty) FROM rdt.rdtTrackLog WITH (NOLOCK)      
            WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            AND TrackNo = @cTrackNo      
            --AND @cUserName = @cUserName      
            
            SET @nAllocatedQty = 0      
            SELECT @nAllocatedQty = SUM(Qty) FROM dbo.PickDetail WITH (NOLOCK)      
            WHERE Orderkey = @cOrderkey      
            AND Storerkey = @cStorerkey      
            
            SET @cOutField01 = @cOrderkey      
            SET @cOutField02 = @cTrackNo      
            SET @cOutField03 = ''      
            SET @cOutField04 = ISNULL(@nPickedQty,0)      
            SET @cOutField05 = ISNULL(@nAllocatedQty,0)    
            
         
            SET @nScn = @nScn - 2      
            SET @nStep = @nStep - 2      
         END
         ELSE
         BEGIN
            --GOTO TrackNo Screen      
            SET @cOrderActionFlag = ''      
         
            SET @cOutField01 = @cOrderkey      
            SET @cOutField02 = ''      
         
            SET @nScn = @nScn - 3      
            SET @nStep = @nStep - 3  
         END
      END      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      SET @cOutField01 = @cOrderkey      
  
      SET @nScn = @nScn - 4      
      SET @nStep = @nStep - 4      
   END      
   GOTO Quit      
      
   Step_5_Fail:      
   BEGIN      
      SET @cOutField01 = ''      
   END      
END      
GOTO Quit      
  
  
/********************************************************************************      
Step 6. screen = 2715      
   SKU  
   DESCR1  
   DESCR2  
   Option   
********************************************************************************/      
Step_6:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
       --screen mapping      
      SET @cOption = ISNULL(@cInField05,'')      
      
        
        
      IF @cOption <> ''  
      BEGIN  
         IF ISNULL(RTRIM(@cOption), '') <> '1'   
         BEGIN      
            SET @nErrNo = 72471      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid Option'      
            GOTO Step_6_Fail      
            IF @ErrMsgNextScreen = '1'      
            BEGIN      
               --SET @nErrNo = 0      
               SET @cErrMsg1 = @nErrNo      
               SET @cErrMsg2 = @cErrMsg      
               SET @cErrMsg3 = ''      
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
            END      
         END      
           
         IF @cOption = '1'      
         BEGIN      
              
            --GOTO SKU Screen      
            SET @cOutField01 = @cOrderkey      
            SET @cOutField02 = @cTrackNo      
            SET @cOutField03 = @cSuggestedSKU  
            SET @cOutField04 = ISNULL(@nPickedQty,0)      
            SET @cOutField05 = ISNULL(@nAllocatedQty,0)      
         
            SET @nScn = @nScn - 3      
            SET @nStep = @nStep - 3     
              
            GOTO QUIT   
         END      
           
      END  
        
        
      SET @cInSKU = @cInSKU1 + @cInSKU2  
        
        
      SELECT Top 1 @cSuggestedSKU = SKU   
      FROM dbo.UPC WITH (NOLOCK)  
      WHERE UPC = @cInSKU  
      AND StorerKey = @cStorerKey  
      AND SKU > @cSuggestedSKU  
      Order By SKU  
        
      IF @@ROWCOUNT = 0  
      BEGIN  
         -- No Record Loop back to First Record  
         SELECT Top 1 @cSuggestedSKU = SKU   
         FROM dbo.UPC WITH (NOLOCK)  
         WHERE UPC = @cInSKU  
         AND StorerKey = @cStorerKey  
         Order By SKU  
           
         SET @nSKUCount =  1  
         SET @cOutField01 = CAST(@nSKUCount AS NVARCHAR(5)) + '/' + CAST(@nCount1 AS NVARCHAR(5))   
      END  
      ELSE   
      BEGIN  
         SET @nSKUCount = @nSKUCount + 1  
         SET @cOutField01 = CAST(@nSKUCount AS NVARCHAR(5)) + '/' + CAST(@nCount1 AS NVARCHAR(5))   
      END  
        
              
      SELECT @cSKUDesc = CASE WHEN ISNULL(BUSR2,'') <> '' THEN BUSR2  
                         ELSE Descr  
                         END  
      FROM dbo.SKU WITH (NOLOCK)  
      WHERE SKU = @cSuggestedSKU  
      AND StorerKey = @cStorerKey  
        
               
      SET @cOutField02 = @cSuggestedSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)  
      SET @cOutField05 = ''  
        
        
        
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
       --GOTO SKU Screen      
      SET @cOutField01 = @cOrderkey      
      SET @cOutField02 = @cTrackNo      
      SET @cOutField03 = ''  
      SET @cOutField04 = ISNULL(@nPickedQty,0)      
      SET @cOutField05 = ISNULL(@nAllocatedQty,0)   
      
      SET @nScn = @nScn - 3      
      SET @nStep = @nStep - 3      
   END   
   GOTO Quit      
      
   Step_6_Fail:      
   BEGIN      
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
      Printer_Paper = @cPrinter_Paper,      
      -- UserName      = @cUserName,      
      
      V_OrderKey    = @cOrderKey,      
      V_SKU         = @cSKU,      
      V_String1     = @cTrackNo,      
      V_String2     = @cShipperKey,      
      V_String3     = @ErrMsgNextScreen,      
      V_String4     = @cPickslipno,      
      V_String5     = @cOrderActionFlag,    
      V_String6     = @cDecodeSP,      -- (james07)  
      V_String7     = @cTrackingNo,    -- (james07)  
      V_String8     = @cUseTrackingNo, -- (james07)  
      V_String9     = @cSuggestedSKU, -- (ChewKP04)    
      V_String12    = @cInSKU1,        -- (ChewKP04)  
      V_String13    = @cInSKU2,        -- (ChewKP04)  
      V_String14    = @cDefaultTrackNo, -- (ChewKP05)  
      V_String15    = @cSuggestedTrackNo, --(ChewKP05)  
      V_String16    = @cExtendedUpdateSP, -- (ChewKP08)  
      V_String17    = @cBackendPickConfirm, 
      V_String18    = @cTrackNoCheckPickStatus, -- (ChewKP09)
      V_String19    = @cSkipTrackNo, -- (ChewKP11) 
      V_String20    = @cSKUStatus,     -- (james05) 
      V_String21    = @cExtendedValidateSP,  -- (james06)

      V_Integer1    = @nCount1,    -- (ChewKP04)  
      V_Integer2    = @nSKUCount,  -- (ChewKP04)
      V_Integer3    = @nAllocatedQty, -- (ChewKP04)  
      V_Integer4    = @nPickedQty,    -- (ChewKP04)
      
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