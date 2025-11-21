SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store procedure: rdtfnc_PostPickAudit                                       */
/* Copyright      : LF Logistics                                               */
/*                                                                             */
/* Date       Rev  Author     Purposes                                         */
/* 05-03-2006 1.8  dhung      SOS# 45327. Support XB LB LP pick slip           */
/*                            Clean up source code                             */
/* 14-11-2008 1.9  jwong      Add filter by storerkey                          */
/* 25-11-2008 2.0  jwong      SOS121650 - Unilever RDT PPA Revision -          */
/*                            Accepting Loadkey for Scanning                   */
/* 20-02-2009 2.1  jwong      Performance tuning (james01)                     */
/* 30-04-2010 2.2  jwong      SOS170309 - Add in OrderKey (james02)            */
/* 08-05-2010 2.3  jwong      SOS169094 - Add in DropID (james03)              */
/* 04-04-2011 2.4  Ung        SOS211078                                        */
/*                            PPA CartonID:Add support PackDetail.DropID       */
/*                            PPA CartonID:Remove scan-in/out checking         */
/*                            PPA Order: modify scan-in/out checking           */
/*                            Replace rdtgetcfg with rdtGetConfig              */
/* 05-04-2011 2.5  Ung        SOS208274 Add piece scanning                     */
/*                            Migrate RDT storer configure:                    */
/*                            1) sh_ppasum to PPAShowSummary                   */
/*                            2) chk_ppatlr to PPACheckTolerance               */
/*                            Add RDT storer configure:                        */
/*                            1) PPAAllowSKUNotInPickList                      */
/*                            2) PPAAllowQTYExceedTolerance                    */
/*                            Clean up source code                             */
/* 11-01-2012 2.6  Leong      SOS# 233768 - Convert char to int                */
/* 20-12-2012 2.7  James      SOS264934 - Convert qty (james04)                */
/* 03-01-2013 2.8  Ung        SOS265337 Expand DropID 20 chars                 */
/*                            Add ExtendedUpdateSP                             */
/*                            Add PPAPromptDiscrepancy                         */
/* 26-03-2014 2.9  ChewKP     SOS#303019 - Add ExtendedValidateSP              */
/*                            (ChewKP01)                                       */
/* 14-05-2014 3.0  James      Various fixes (james05)                          */
/*                            Add InputKey as param for ExtendedUpdateSP       */
/*                            Add config to bypass pkslip must scan out        */
/* 27-05-2014 3.1  Ung        SOS311861 Add PPABlindCount                      */
/*                            Fix Tolerance cannot set negative value          */
/* 15-07-2014 3.2  Ung        SOS316336 Add ExtendedUpdateSP for step 1        */
/* 31-07-2014 3.3  Ung        SOS316605 Add Prefer UOM and QTY                 */
/* 30-01-2015 3.4  Ung        SOS331668 Add Print packing list screen          */
/* 22-12-2015 3.5  Leong      SOS359525 - Revise variable size.                */
/* 10-06-2016 3.6  Ung        SOS371045 Add DecodeSP                           */
/*                            Add PickConfirmStatus                            */
/* 30-09-2016 3.7  Ung        Performance tuning                               */
/* 10-03-2017 3.8  James      WMS1256 - Add scan pickdetail case id            */
/*                            Add ExtendedUpdateSP @ screen 3 (james06)        */
/*                            Extend @cPackQTYIndicator variable               */
/* 02-06-2017 3.9  James      Add new param in extendedupdatesp(james07)       */
/* 05-07-2017 4.0  Ung        WMS-2331 Add ExtendedInfoSP at screen 2          */
/*                            Migrate ExtendedInfoSP to VariableTable          */
/*                            Add PickDetail.ShipFlag (reuse DropID)           */
/* 06-12-2018 4.1  Ung        WMS-6842 Show PackQTYIndicator                   */
/*                            Add PreCartonization                             */
/*                            Add ExtendedUpdateSP at screen 3 ESC             */
/* 16-11-2018 4.1  Ung        WMS-6932 Add pallet ID                           */
/*                            Add custom DecodeSP                              */
/* 26-02-2019 4.2  YeeKung    WMS-8090 Add ShippingLabel printing              */
/*                            (yeekung01)                                      */
/* 28-03-2019 4.3  James      WMS-8002 Add TaskDetailKey field (james08)       */ 
/*                            Add capture data screen                          */
/* 17-04-2019 4.4  ChewKP     WMS-8593 Add EventLog (ChewKP02)                 */
/* 17-04-2019 4.5  James      WMS-7983 Add variable table to                   */
/*                            ExtendedValidateSP (james09)                     */
/* 05-11-2019 4.6 Chermaine   WMS-11031 Add EventLog (cc01)                    */
/* 19-02-2020 4.7 CheeMun     INC1045866-Bug Fix for RDT906                    */
/* 24-09-2019 4.8 YeeKung     INC0868161 Bug Fixed (yeekung02)                 */      
/* 13-02-2020 4.9 YeeKung     INC1039880 Added logic to prompt error           */      
/*                            if sku is invalid in lotxlocxid(yeekung03)       */       
/* 03-03-2020 5.0 YeeKung     Performance Tune (yeekung04)                     */
/* 29-04-2020 5.1 YeeKung     Performance Tune (yeekung05)                     */ 
/* 30-06-2021 5.2 YeeKung     WMS-17278 add reason code (yeekung06)            */         
/* 19-07-2021 5.3 Chermaine   WMS-17439 Add CaptureDataSP after scn2           */    
/*                            And Add ExtendedUOMSP in Scn 1                   */    
/*                            And Add CaptureDataColName config                */    
/*                            And Add CapturePackInfo Screen st8 (cc02)        */    
/* 21-12-2021 5.4 James       Bug fix (james10)                                */ 
/* 28-03-2022 5.5 James       WMS-17439 Bug fix ON DECODESP (james11)          */ 
/* 07-09-2022 5.6 James       WMS-20689 Add config to default qty onto         */
/*                            preferred uom default (james12)                  */
/* 19-05-2021 5.7 SeongYaik   Revise IF Statement (SY01)                       */
/* 18-08-2022 5.8 Ung         Fix CaptureDataSP after scn2                     */
/* 13-12-2022 5.9 Yeekung     WMS-20944 fix nvarchar(5)->6  (yeekung07)        */
/* 07-02-2022 6.0 YeeKung     WMS-21562 customize refno to support             */
/*                            trackingno  (yeekung08)                          */
/* 30-05-2023 6.1 James       WMS-22322 Enhance Qty convertion (james13)       */
/* 14-11-2023 6.2 Ung         WMS-23972 Add SkipChkPSlipMustScanIn             */
/* 14-11-2023 6.3 Ung         WMS-23960 Add PickConfirmStatus for pallet       */
/* 24-11-2023 6.4 YeeKung     UWP-11249Fix bug (yeekung08)                     */
/* 28-03-2024 6.5 YeeKung     UWP-16421 Add ExtendedvalidateSP                 */
/*                            (yeekung09)                                      */
/* 24-06-2024 6.6 NLT013      FCR-386 Add Extended Screen                      */
/* 21-11-2024 6.7.0 LJQ006    FCR-1109 Update Extend Screen and ExtInfo        */
/* 2024-12-31 6.8.0  NLT013   UWP-28680 fix rollback transaction issue.        */
/* 2025-02-05 6.9.0  CYU027   FCR-2630 Add Option=5 in step 5                  */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PostPickAudit] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @bSuccess      INT,
   @cErrMsg1      NVARCHAR( 125),
   @cErrMsg2      NVARCHAR( 125),
                  
   @nCQTY         INT,
   @nMQTY         INT,
   @nPQTY         INT,
   @nCSKU         INT,
   @nPSKU         INT,

   @nQTY          INT,
   @cSKUStat      NVARCHAR( 12),
   @cQTYStat      NVARCHAR( 12),
   @nRowRef       INT,
   @cExtendedInfo NVARCHAR( 20),
   @cOption       NVARCHAR( 1),
   @cDocType      NVARCHAR( 30), 
   @cDocNo        NVARCHAR( 20), 
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX), 
   @tExtInfo      VariableTable, 
   @tExtValidate  VariableTable, 
   @tExtUOM       VariableTable, --(cc02)
   @tExtScnData   VariableTable,

   @cSKUDesc      NVARCHAR( 60), 
   @cStyle        NVARCHAR( 20), 
   @cColor        NVARCHAR( 10), 
   @cSize         NVARCHAR( 10), 
   @cPUOM_Desc    NCHAR( 5), 
   @cMUOM_Desc    NCHAR( 5), 
   @nPUOM_Div     INT, 

   @nQTY_CHK      INT,
   @nPQTY_CHK     INT,
   @nMQTY_CHK     INT,
   @nQTY_PPA      INT,
   @nPQTY_PPA     INT,
   @nMQTY_PPA     INT

-- rdt.rdtMobRec variable
DECLARE
   @nFunc           INT,
   @nScn            INT,
   @nStep           INT,
   @nMenu           INT,
   @cLangCode       NVARCHAR( 3),
   @nInputKey       INT,

   @cStorer         NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cUserName       NVARCHAR(18),
   @cPrinter        NVARCHAR( 10),
   @cPrinterPpr  		NVARCHAR( 10), --(yeekung01)   

   @cPUOM           NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @cLoadKey        NVARCHAR( 10),
   @cPickSlipNo     NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cID             NVARCHAR( 18),
   @nFromScn        INT, 
   @nFromStep       INT, 
   @nTol            INT,           -- Tolerance %

   @cRefNo          NVARCHAR( 20), --(yeekung08)  
   @cDropID         NVARCHAR( 20),
   @cExternOrderKey NVARCHAR( 20),
   @cZone           NVARCHAR( 18),
   @cPicksSlipNo	  NVARCHAR( 10), --(yeekung01)    
   @cFromCartonNo   INT, --(yeekung01)    
   @cToCartonNo  	  INT, --(yeekung01)    
   @nPPA_QTY        INT, --(yeekung01)    
   @nPD_QTY         INT, --(yeekung01) 
   @nVariance       INT,

   @cPackQTYIndicator               NVARCHAR( 5),
   @cPrePackIndicator               NVARCHAR( 1),
   @cPPACartonIDByPackDetailDropID  NVARCHAR( 1),
   @cPPAAllowSKUNotInPickList       NVARCHAR( 1),
   @cPPADefaultQTY                  NVARCHAR( 1),
   @cPPAAllowQTYExceedTolerance     NVARCHAR( 1),
   @cConvertQTYSP                   NVARCHAR( 20),
   @cExtendedInfoSP                 NVARCHAR( 20),
   @cExtendedScnSP                  NVARCHAR( 20),
   @cPPACartonIDByPackDetailLabelNo NVARCHAR( 1),
   @cExtendedUpdateSP               NVARCHAR( 20),
   @cPPAPromptDiscrepancy           NVARCHAR( 1),
   @cExtendedValidateSP             NVARCHAR( 20), -- (ChewKP01)
   @cDisableQTYField                NVARCHAR( 1),  -- (james05)
   @cSkipChkPSlipMustScanIn         NVARCHAR( 1),
   @cSkipChkPSlipMustScanOut        NVARCHAR( 1),  -- (james05)
   @cPPABlindCount                  NVARCHAR( 1),
   @cPPAPrintPackListSP             NVARCHAR( 20),
   @cDecodeSP                       NVARCHAR( 20), 
   @cPickConfirmStatus              NVARCHAR( 1), 
   @cPPACartonIDByPickDetailCaseID  NVARCHAR( 1),  -- (james06)
   @cPreCartonization               NVARCHAR( 1), 
   @nTranCount                      INT,           -- (james06)
   @cMultiSKUBarcode                NVARCHAR( 1),
   @cUPC                            NVARCHAR( 30), --(yeekung02)
   --@cPackList          		         NVARCHAR( 20), -- (yeekung01)
   @cShipLabel            		      NVARCHAR( 20), -- (yeekung01)
   @cShippingContentLabel       		NVARCHAR( 20), -- (yeekung01)   
   @cCaptureData                    NVARCHAR( 1),
   @cCaptureDataSP                  NVARCHAR( 20),
   @cTaskDetailKey                  NVARCHAR( 10),
   @cTaskDefaultQty                 NVARCHAR( 1),
   @nTaskQty                        INT,
   @cTaskQty                        NVARCHAR( 5),
   @cCaptureDataInput               NVARCHAR( 60), --(cc02)
   @cExtendedUOMSP                  NVARCHAR( 20), --(cc02)
   @cCaptureDataColName             NVARCHAR( 20), --(cc02)
   @cCapturePackInfo                NVARCHAR( 20), --(cc02)
   @cCartonType                     NVARCHAR( 10), --(cc02)    
   @cCube                           NVARCHAR( 10), --(cc02)    
   @cWeight                         NVARCHAR( 10), --(cc02)    
   @cAllowWeightZero                NVARCHAR( 1),  --(cc02)    
   @cAllowCubeZero                  NVARCHAR( 1),  --(cc02)    
   @nCartonNo                       INT,           --(cc02) 
   @cPrintPackList                  NVARCHAR(1),
   @cReasonCode                     NVARCHAR(20),        
   @cCaptureReasonCode              NVARCHAR(1),  
   @cPPADefaultPQTY                 NVARCHAR( 1),
   @cExtendedRefNoSP                NVARCHAR(20),
   @cMultiColScan                   NVARCHAR(20),
   @nDecodeQty                      INT,
   @nAction                         INT,
   @nAfterScn                       INT,
   @nAfterStep                      INT,
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1), @cLottable01     NVARCHAR( 18),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1), @cLottable02     NVARCHAR( 18),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1), @cLottable03     NVARCHAR( 18),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1), @dLottable04     DATETIME,
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1), @dLottable05     DATETIME,
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1), @cLottable06     NVARCHAR( 30),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1), @cLottable07     NVARCHAR( 30),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1), @cLottable08     NVARCHAR( 30),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1), @cLottable09     NVARCHAR( 30),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1), @cLottable10     NVARCHAR( 30),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1), @cLottable11     NVARCHAR( 30),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1), @cLottable12     NVARCHAR( 30),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1), @dLottable13     DATETIME,
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1), @dLottable14     DATETIME,
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1), @dLottable15     DATETIME,
   @cInField16 NVARCHAR( 60),   @cOutField16 NVARCHAR( 60),    @cFieldAttr16 NVARCHAR( 1), 
   @cInField17 NVARCHAR( 60),   @cOutField17 NVARCHAR( 60),    @cFieldAttr17 NVARCHAR( 1), 
   @cInField18 NVARCHAR( 60),   @cOutField18 NVARCHAR( 60),    @cFieldAttr18 NVARCHAR( 1), 
   @cInField19 NVARCHAR( 60),   @cOutField19 NVARCHAR( 60),    @cFieldAttr19 NVARCHAR( 1), 
   @cInField20 NVARCHAR( 60),   @cOutField20 NVARCHAR( 60),    @cFieldAttr20 NVARCHAR( 1),
   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)

   DECLARE @tDataCapture   VariableTable

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,
   @nInputKey  = InputKey,

   @cStorer    = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cPrinterPpr= Printer_Paper,
   @cUserName  = UserName,

   @cPUOM       = V_UOM,
   @cSKU        = V_SKU,
   @cLoadKey    = V_LoadKey,
   @cPickSlipNo = V_PickSlipNo,
   @cOrderKey   = V_OrderKey,
   @cID         = V_ID, 
   @nFromScn    = V_FromScn, 
   @nFromStep        = V_FromStep, 
   @cTaskDetailKey  = V_TaskDetailKey, 
   
   @nTol            = V_Integer1, 
   
   @cRefNo          = V_String1,
   @cDropID         = V_String2,
   @cExternOrderKey = V_String3,
   @cZone           = V_String4,   
   @cCaptureDataSP  = V_String5,
   @cTaskQty        = V_String6, 
   @cTaskDefaultQty = V_String7, 
   @cPUOM_Desc      = V_String8,   
   @cPPADefaultPQTY = V_String9,
   
   @cPackQTYIndicator               = V_String10,
   @cPrePackIndicator               = V_String11,
   @cPPACartonIDByPackDetailDropID  = V_String12,
   @cPPAAllowSKUNotInPickList       = V_String13,
   @cPPADefaultQTY                  = V_String14,
   @cSkipChkPSlipMustScanIn         = V_String15,
   @cPPAAllowQTYExceedTolerance     = V_String16,
   @cConvertQTYSP                   = V_String17,
   @cExtendedInfoSP                 = V_String18,
   @cPPACartonIDByPackDetailLabelNo = V_String19,
   @cExtendedUpdateSP               = V_String20,
   @cPPAPromptDiscrepancy           = V_String21,
   @cExtendedValidateSP             = V_String22, -- (ChewKP01)
   @cDisableQTYField                = V_String23, -- (james05)
   @cSkipChkPSlipMustScanOut        = V_String24, -- (james05)
   @cPPABlindCount                  = V_String25,
   @cPPAPrintPackListSP             = V_String26,
   @cDecodeSP                       = V_String27,
   @cPickConfirmStatus              = V_String28,
   @cPPACartonIDByPickDetailCaseID  = V_String29,  -- (james06)
   @cPreCartonization               = V_String30,
   @cMultiSKUBarcode                = V_String31,
   @cShipLabel         			      = V_String32,  -- (yeekung01)
   @cShippingContentLabel     		= V_String33,  -- (yeekung01)
  -- @cPackList                       = V_String34,  -- (yeekung01) 
  	@cUPC                            = V_String35, --(yeekung02
  	@cCaptureDataInput               = V_String36,  --(cc02)
  	@cExtendedUOMSP                  = V_String37,  --(cc02)
  	@cCaptureDataColName             = V_String38,  --(cc02)   
  	@cCapturePackInfo                = V_String39,  --(cc02)  
  	@cCartonType                     = V_String40,  --(cc02)     
   @cCube                           = V_String41,  --(cc02)      
   @cWeight                         = V_String42,  --(cc02)   
   @cAllowWeightZero                = V_String43,  --(cc02)    
   @cAllowCubeZero                  = V_String44,  --(cc02)    
   @cReasonCode                     = V_String45,        
   @cCaptureReasonCode              = V_String46,  
   @cExtendedRefNoSP                = V_String47,
   @cMultiColScan                   = V_String48,
   @cExtendedScnSP                  = V_String49,

   @nAction                         = V_Integer2,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15,

   @cInField16 = I_Field16,   @cOutField16 = O_Field16,  @cFieldAttr16 = FieldAttr16,
   @cInField17 = I_Field17,   @cOutField17 = O_Field17,  @cFieldAttr17 = FieldAttr17,
   @cInField18 = I_Field18,   @cOutField18 = O_Field18,  @cFieldAttr18 = FieldAttr18,
   @cInField19 = I_Field19,   @cOutField19 = O_Field19,  @cFieldAttr19 = FieldAttr19,
   @cInField20 = I_Field20,   @cOutField20 = O_Field20,  @cFieldAttr20 = FieldAttr20

FROM rdt.rdtMobRec WITH (NOLOCK)
WHERE Mobile = @nMobile

/*
850 = all fields
851 = Refno
852 = PSNO
853 = LoadKey
854 = OrderKey
855 = DropID
906 = TaskDetailKey
*/

IF @nFunc in (850, 851, 852, 853, 854, 855, 844, 906)
BEGIN
   IF @nStep = 0 GOTO Step_0  -- Menu. Func = 850~855
   IF @nStep = 1 GOTO Step_1  -- Scn = 814. RefNo, PickSlipNo, LoadKey, OrderKey, DropID
   IF @nStep = 2 GOTO Step_2  -- Scn = 815. Statistic
   IF @nStep = 3 GOTO Step_3  -- Scn = 816. SKU, QTY
   IF @nStep = 4 GOTO Step_4  -- Scn = 817. Option. Discrepency found
   IF @nStep = 5 GOTO Step_5  -- Scn = 818. Option. Print pack list?
   IF @nStep = 6 GOTO Step_6  -- Scn = 3570. Multi SKU Barocde
   IF @nStep = 7 GOTO Step_7  -- Scn = 819. Verify Data Capture
   IF @nStep = 8 GOTO Step_8  -- Scn = 5980. Capture pack info  --(cc02)
   IF @nStep = 99 GOTO Step_99  -- Extend Screen

END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 850~855
********************************************************************************/
Step_0:
BEGIN
   -- Init var
   SELECT
      @cRefNo          = '',
      @cPickSlipNo     = '',
      @cLoadKey        = '',
      @cOrderKey       = '',
      @cDropID         = '',
      @cID             = '',
      @cExternOrderKey = '',
      @cZone           = '',
      @cSKU            = '',
      @nQty            = 0,
      @cTaskDetailKey  = ''

   SELECT 
      @cFieldAttr01  =  '',
      @cFieldAttr02  =  '',
      @cFieldAttr03  =  '',
      @cFieldAttr04  =  '',
      @cFieldAttr05  =  '',
      @cFieldAttr06  =  '',
      @cFieldAttr07  =  '',
      @cFieldAttr08  =  '',
      @cFieldAttr09  =  '',
      @cFieldAttr10  =  ''

   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer config
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorer)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorer)
   SET @cPickConfirmStatus = rdt.rdtGetConfig( @nFunc, 'PickConfirmStatus', @cStorer)
   SET @cPPAAllowQTYExceedTolerance = rdt.rdtGetConfig( @nFunc, 'PPAAllowQTYExceedTolerance', @cStorer)
   SET @cPPAAllowSKUNotInPickList = rdt.rdtGetConfig( @nFunc, 'PPAAllowSKUNotInPickList', @cStorer)
   SET @cPPABlindCount = rdt.rdtGetConfig( @nFunc, 'PPABlindCount', @cStorer)
   SET @cPPACartonIDByPackDetailDropID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailDropID', @cStorer)
   SET @cPPACartonIDByPackDetailLabelNo = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPackDetailLabelNo', @cStorer)
   SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorer)
   SET @cPPAPromptDiscrepancy = rdt.rdtGetConfig( @nFunc, 'PPAPromptDiscrepancy', @cStorer)
   SET @cPreCartonization = rdt.rdtGetConfig( @nFunc, 'PreCartonization', @cStorer)
   SET @cSkipChkPSlipMustScanIn = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanIn', @cStorer)
   SET @cSkipChkPSlipMustScanOut = rdt.rdtGetConfig( @nFunc, 'SkipChkPSlipMustScanOut', @cStorer)
   SET @nTol = rdt.rdtGetConfig( @nFunc, 'PPACheckTolerance', @cStorer) -- Get tolerance % setting

   SET @cPPAPrintPackListSP = rdt.rdtGetConfig( @nFunc, 'PPAPrintPackListSP', @cStorer)
   IF @cPPAPrintPackListSP = '0'
      SET @cPPAPrintPackListSP = ''
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorer)
   IF @cExtendedScnSP = '0'
      SET @cExtendedScnSP = ''
      
   SET @cPPADefaultQTY = rdt.rdtGetConfig( @nFunc, 'PPADefaultQTY', @cStorer)
   IF @cPPADefaultQTY = '0'
      SET @cPPADefaultQTY = ''
   SET @cConvertQTYSP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer)
   IF @cConvertQTYSP = '0'
      SET @cConvertQTYSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   SET @cMultiColScan = rdt.RDTGetConfig( @nFunc, 'MultiColScan', @cStorer)
   IF @cMultiColScan = '0'
      SET @cMultiColScan = ''
      
   --SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackMans', @cStorer)     --(yeekung01)
   --IF @cPackList = '0'
     -- SET @cPackList = ''
   SET @cShippingContentLabel = rdt.RDTGetConfig( @nFunc, 'ShipCttLbl', @cStorer)  --(yeekung01)
   IF @cShippingContentLabel = '0'
      SET @cShippingContentLabel = ''
   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLbl', @cStorer)    --(yeekung01)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   -- (james06)
   SET @cPPACartonIDByPickDetailCaseID = rdt.rdtGetConfig( @nFunc, 'PPACartonIDByPickDetailCaseID', @cStorer)

   -- Check scan-out, PickDetail.Status must = 5
   IF @cSkipChkPSlipMustScanOut = '0'
      SET @cPickConfirmStatus = '5'

   SET @cCaptureDataSP = rdt.rdtGetConfig( @nFunc, 'CaptureData', @cStorer)
   IF @cCaptureDataSP = '0'
      SET @cCaptureDataSP = ''

   SET @cTaskDefaultQty = rdt.rdtGetConfig( @nFunc, 'TaskDefaultQty', @cStorer)
   IF @cTaskDefaultQty = '0'
      SET @cTaskDefaultQty = ''
      
   --(cc02)
   SET @cExtendedUOMSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUOMSP', @cStorer)  
   IF @cExtendedUOMSP = '0'  
      SET @cExtendedUOMSP = ''  
   
   --(cc02)   
   SET @cCaptureDataColName = rdt.RDTGetConfig( @nFunc, 'CaptureDataColName', @cStorer)  
   IF @cCaptureDataColName = '0'  
      SET @cCaptureDataColName = 'CAPTURE DATA'  
      
   --(cc02)
   SET @cCapturePackInfo = rdt.RDTGetConfig( @nFunc, 'CapturePackInfo', @cStorer)  
   IF @cCapturePackInfo = '0'  
      SET @cCapturePackInfo = ''  
   SET @cAllowWeightZero = rdt.rdtGetConfig( @nFunc, 'AllowWeightZero', @cStorer)
   SET @cAllowCubeZero = rdt.rdtGetConfig( @nFunc, 'AllowCubeZero', @cStorer)    
   
   SET @cCaptureReasonCode = rdt.rdtGetConfig( @nFunc, 'CapReasonCode', @cStorer)        
   IF @cCaptureReasonCode = '0'        
      SET @cCaptureReasonCode = '' 
     
   SET @cPPADefaultPQTY = rdt.rdtGetConfig( @nFunc, 'PPADefaultPQTY', @cStorer)
   IF @cPPADefaultPQTY = '0'        
      SET @cPPADefaultPQTY = '' 

   SET @cExtendedRefNoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedRefNoSP', @cStorer)
   IF @cExtendedRefNoSP = '0'
      SET @cExtendedRefNoSP = ''

   -- EventLog - Sign In Function  
   -- (ChewKP02) 
   EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorer  

   -- Go to next screen
   SET @nScn = 814
   SET @nStep = 1

   -- Enable disable field
   IF @nFunc in ( 850, 851) SET @cFieldAttr01 = '' ELSE SET @cFieldAttr01 = 'O' --RefNo
   IF @nFunc in ( 850, 852) SET @cFieldAttr02 = '' ELSE SET @cFieldAttr02 = 'O' --PickSlipNo
   IF @nFunc in ( 850, 853) SET @cFieldAttr03 = '' ELSE SET @cFieldAttr03 = 'O' --LoadKey
   IF @nFunc in ( 850, 854) SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O' --OrderKey
   IF @nFunc in ( 850, 855) SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O' --DropID
   IF @nFunc in ( 850, 844) SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O' --ID
   IF @nFunc in ( 850, 906) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O' --TaskDetailKey
   IF @cExtendedScnSP <> ''
	   GOTO Step_99
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 814
   PICKSLIPNO (field01, input)
   REFNO      (field02, input)
   LOADKEY    (field03, input)
   ORDERKEY   (field04, input)
   CARTON ID  (field05, input)
   PALLET ID  (field06, input)
   TASKKEY    (field07, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      IF @nFunc in ( 850, 851) SET @cRefNo      = ISNULL( @cInField01, '') -- Refno
      IF @nFunc in ( 850, 852) SET @cPickSlipNo = ISNULL( @cInField02, '') -- PickSlipNo
      IF @nFunc in ( 850, 853) SET @cLoadKey    = ISNULL( @cInField03, '') -- LoadKey
      IF @nFunc in ( 850, 854) SET @cOrderKey   = ISNULL( @cInField04, '') -- OrderKey
      IF @nFunc in ( 850, 855) SET @cDropID     = ISNULL( @cInField05, '') -- DropID
      IF @nFunc in ( 850, 844) SET @cID         = ISNULL( @cInField06, '') -- PalletID
      IF @nFunc in ( 850, 906) SET @cTaskDetailKey = ISNULL( @cInField07, '') -- TaskDetailKey

      IF @nFunc = 850 -- All
      BEGIN
         IF @cRefNo      = '' AND
            @cPickSlipNo = '' AND
            @cLoadKey    = '' AND
            @cOrderKey   = '' AND
            @cDropID     = '' AND
            @cID         = '' AND 
            @cTaskDetailKey = ''
         BEGIN
            SET @nErrNo = 60851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Value required!
            GOTO Step_1_Fail
         END

         DECLARE @i INT
         SET @i = 0
         IF @cRefNo      <> '' SET @i = @i + 1
         IF @cPickSlipNo <> '' SET @i = @i + 1
         IF @cLoadKey    <> '' SET @i = @i + 1
         IF @cOrderKey   <> '' SET @i = @i + 1
         IF @cDropID     <> '' SET @i = @i + 1
         IF @cID         <> '' SET @i = @i + 1
         IF @cTaskDetailKey <> '' SET @i = @i + 1
         IF @i > 1 and @cMultiColScan =''
         BEGIN
            SET @nErrNo = 60852
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Key-in either 1
            GOTO Step_1_Fail
         END
      END

      IF @nFunc = 851 AND @cRefNo = ''
      BEGIN
         SET @nErrNo = 60853
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- REFNO req
         GOTO Step_1_Fail
      END

      IF @nFunc = 852 AND @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 60854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PSNO req
         GOTO Step_1_Fail
      END

      IF @nFunc = 853 AND @cLoadKey = ''
      BEGIN
         SET @nErrNo = 60855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- LOADKEY req
         GOTO Step_1_Fail
      END

      IF @nFunc = 854 AND @cOrderKey = ''
      BEGIN
         SET @nErrNo = 60856
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ORDERKEY req
         GOTO Step_1_Fail
      END

      IF @nFunc = 855 AND @cDropID = ''
      BEGIN
         SET @nErrNo = 60857
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- DROP ID req
         GOTO Step_1_Fail
      END

      IF @nFunc = 844 AND @cID = ''
      BEGIN
         SET @nErrNo = 60888
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PALLET ID req
         GOTO Step_1_Fail
      END

      IF @nFunc = 906 AND @cTaskDetailKey = ''
      BEGIN
         SET @nErrNo = 60889
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- TaskKey req
         GOTO Step_1_Fail
      END

      -- (ChewKP01)
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtValidate (Variable, Value) VALUES 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nQTY_PPA',     CAST( @nQTY_PPA AS NVARCHAR( 10))), 
               ('@nQTY_CHK',     CAST( @nQTY_CHK AS NVARCHAR( 10))), 
               ('@nRowRef',      CAST( @nRowRef AS NVARCHAR( 10))), 
               ('@nInputKey',    CAST( @nInputKey AS NVARCHAR( 1))), 
               ('@cUserName',    @cUserName)

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@cStorer        NVARCHAR( 15), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cRefNo         NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cLoadKey       NVARCHAR( 10), ' +
               '@cPickSlipNo    NVARCHAR( 10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT, ' + 
               '@cID            NVARCHAR( 18), ' + 
               '@cTaskDetailKey NVARCHAR( 10), ' + 
               '@tExtValidate   VARIABLETABLE READONLY'
            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate
            
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_1_Fail
            END
         END
      END

                 -- (ChewKP01)
      IF ISNULL(@cExtendedRefNoSP,'') <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedRefNoSP AND type = 'P')--yeekung08
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedRefNoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey,  @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,@cType, ' + 
            ' @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
            '@nMobile        INT, ' +                      
            '@nFunc          INT, ' +                      
            '@cLangCode      NVARCHAR( 3),  ' +            
            '@nStep          INT,           ' +            
            '@cStorer        NVARCHAR( 15), ' +            
            '@cFacility      NVARCHAR( 5),  ' +            
            '@cRefNo         NVARCHAR( 20), ' +            
            '@cOrderKey      NVARCHAR( 10), ' +            
            '@cDropID        NVARCHAR( 20), ' +            
            '@cLoadKey       NVARCHAR( 10), ' +            
            '@cPickSlipNo    NVARCHAR( 10), ' +            
            '@cID            NVARCHAR( 18),       '+       
            '@cTaskDetailKey NVARCHAR( 10),       '+       
            '@cSKU           NVARCHAR( 20),       ' +      
            '@cType          NVARCHAR( 20),       '+       
            '@nCSKU          INT  OUTPUT ,  '+             
            '@nCQTY          INT  OUTPUT ,  '+             
            '@nPSKU          INT OUTPUT,          '+       
            '@nPQTY          INT OUTPUT,          '+       
            '@nVariance      INT OUTPUT,   '+              
            '@nQTY_PPA       INT OUTPUT,          '+       
            '@nQTY_CHK       INT OUTPUT,          '+   
            '@nRowRef        INT OUTPUT,          '+ 
            '@nErrNo         INT           OUTPUT,'+       
            '@cErrMsg        NVARCHAR( 20) OUTPUT '        

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,'CHECK',
            @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT


            IF @nErrNo <> 0
            BEGIN
               GOTO Step_1_Fail
            END

         END
      END
      ELSE
      BEGIN

         -- Ref No
         IF @cRefNo <> '' AND @cRefNo IS NOT NULL --SY01
         BEGIN
            -- Validate load plan status
            IF NOT EXISTS( SELECT 1
               FROM dbo.LoadPlan WITH (NOLOCK)
               WHERE UserDefine10 = @cRefNo
                  AND Status <= '9') -- 9=Closed
            BEGIN
               SET @nErrNo = 60858
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Ref#
               EXEC rdt.rdtSetFocusField @nMobile, 1
               GOTO Step_1_Fail
            END

            IF @cSkipChkPSlipMustScanIn <> '1'
            BEGIN
               -- Validate all pickslip already scan in
               IF EXISTS( SELECT 1
                  FROM dbo.LoadPlan LP WITH (NOLOCK)
                     INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
                     LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
                  WHERE LP.UserDefine10 = @cRefNo
                     AND [PI].ScanInDate IS NULL)
               BEGIN
                  SET @nErrNo = 60859
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_1_Fail
               END
            END

            -- (james05)
            IF @cSkipChkPSlipMustScanOut <> '1'
            BEGIN
               -- Validate all pickslip already scan out
               IF EXISTS( SELECT 1
                  FROM dbo.LoadPlan LP WITH (NOLOCK)
                     INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
                     LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
                  WHERE LP.UserDefine10 = @cRefNo
                     AND [PI].ScanOutDate IS NULL)
               BEGIN
                  SET @nErrNo = 60860
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
                  EXEC rdt.rdtSetFocusField @nMobile, 1
                  GOTO Step_1_Fail
               END
            END
         END

         -- Pick Slip No
         IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL --SY01
         BEGIN
            SET @cOrderKey = ''  -- (james02)

            -- Get pickheader info
            DECLARE @cChkPickSlipNo NVARCHAR( 10)
            SELECT TOP 1
               @cChkPickSlipNo = PickHeaderKey,
               @cExternOrderKey = ExternOrderkey,
               @cOrderKey = OrderKey,
               @cZone = Zone
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo

            -- Validate pickslip no
            IF @cChkPickSlipNo = '' OR @cChkPickSlipNo IS NULL
            BEGIN
               SET @nErrNo = 60861
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid PS#
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_1_Fail
            END

            DECLARE @dScanInDate  DATETIME
            DECLARE @dScanOutDate DATETIME

            -- Get picking info
            SELECT TOP 1
               @dScanInDate = ScanInDate,
               @dScanOutDate = ScanOutDate
            FROM dbo.PickingInfo WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            IF @cSkipChkPSlipMustScanIn <> '1'
            BEGIN
               -- Validate pickslip not scan in
               IF @dScanInDate IS NULL
               BEGIN
                  SET @nErrNo = 60862
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not scan-in
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Step_1_Fail
               END
            END

            -- (james05)
            IF @cSkipChkPSlipMustScanOut <> '1'
            BEGIN
               -- Validate pickslip not scan out
               IF @dScanOutDate IS NULL
               BEGIN
                  SET @nErrNo = 60863
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not scan-out
                  EXEC rdt.rdtSetFocusField @nMobile, 2
                  GOTO Step_1_Fail
               END
            END
         END

         -- LoadKey
         IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
         BEGIN
            -- Validate load plan status
            IF NOT EXISTS( SELECT 1
               FROM dbo.LoadPlan WITH (NOLOCK)
               WHERE LoadKey = @cLoadKey
                  AND Status <= '9') -- 9=Closed
            BEGIN
               SET @nErrNo = 60864
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid LoadKey
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_1_Fail
            END

            IF @cSkipChkPSlipMustScanIn <> '1'
            BEGIN
               -- Validate all pickslip already scan in
               IF EXISTS( SELECT 1
                  FROM dbo.LoadPlan LP WITH (NOLOCK)
                     INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
                     LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
                  WHERE LP.LoadKey = @cLoadKey
                     AND [PI].ScanInDate IS NULL)
               BEGIN
                  SET @nErrNo = 60865
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_1_Fail
               END
            END

            -- (james05)
            IF @cSkipChkPSlipMustScanOut <> '1'
            BEGIN
               -- Validate all pickslip already scan out
               IF EXISTS( SELECT 1
                  FROM dbo.LoadPlan LP WITH (NOLOCK)
                     INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.ExternOrderKey = LP.LoadKey
                     LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
                  WHERE LP.LoadKey = @cLoadKey
                     AND [PI].ScanOutDate IS NULL)
               BEGIN
                  SET @nErrNo = 60866
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_1_Fail
               END
            END
         END

         -- OrderKey
         IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL --SY01
         BEGIN
            -- Validate order status
            IF NOT EXISTS( SELECT 1
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
                  AND StorerKey = @cStorer)
            BEGIN
               SET @nErrNo = 60867
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv OrderKey
               GOTO Step_1_Fail
            END

            IF @cSkipChkPSlipMustScanIn <> '1'
            BEGIN
               -- Validate pickslip already scan in
               IF EXISTS( SELECT 1
                  FROM dbo.PickHeader PH WITH (NOLOCK)
                     LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
                  WHERE PH.OrderKey = @cOrderKey
                     AND [PI].ScanInDate IS NULL)
               BEGIN
                  SET @nErrNo = 60868
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Not Scan-in
                  GOTO Step_1_Fail
               END
            END

            -- (james05)
            IF @cSkipChkPSlipMustScanOut <> '1'
            BEGIN
               -- Validate pickslip already scan out
               IF EXISTS( SELECT 1
                  FROM dbo.PickHeader PH WITH (NOLOCK)
                     LEFT OUTER JOIN dbo.PickingInfo [PI] WITH (NOLOCK) ON [PI].PickSlipNo = PH.PickHeaderKey
                  WHERE PH.OrderKey = @cOrderKey
                     AND [PI].ScanOutDate IS NULL)
               BEGIN
                  SET @nErrNo = 60869
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Not Scan-out
                  GOTO Step_1_Fail
               END
            END
         END

         -- DropID
         IF @cDropID <> '' AND @cDropID IS NOT NULL --SY01
         BEGIN
            -- Validate drop ID status
            IF @cPPACartonIDByPackDetailDropID = '1'
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.DropID = @cDropID
                     AND PH.StorerKey = @cStorer)
               BEGIN
                  SET @nErrNo = 60870
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv DropID
                  GOTO Step_1_Fail
               END
            END
            ELSE
            IF @cPPACartonIDByPackDetailLabelNo = '1'
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.LabelNo = @cDropID
                     AND PH.StorerKey = @cStorer)
               BEGIN
                  SET @nErrNo = 60880
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv Carton ID
                  GOTO Step_1_Fail
               END
            END
            ELSE
            IF @cPPACartonIDByPickDetailCaseID = '1'
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE CaseID = @cDropID
                     AND StorerKey = @cStorer
                     AND ShipFlag <> 'Y')
               BEGIN
                  SET @nErrNo = 60887
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv CaseID
                  GOTO Step_1_Fail
               END
            END
            ELSE
            BEGIN
               IF NOT EXISTS( SELECT 1
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE DropID = @cDropID
                     AND StorerKey = @cStorer
                     AND ShipFlag <> 'Y')
               BEGIN
                  SET @nErrNo = 60871
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv DropID
                  GOTO Step_1_Fail
               END
            END
         END

         -- Pallet ID
         IF @cID <> '' AND @cID IS NOT NULL --SY01
         BEGIN
            IF NOT EXISTS( SELECT 1
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
               WHERE LOC.Facility = @cFacility
                  AND LLI.StorerKey = @cStorer
                  AND LLI.ID = @cID
                  AND LLI.QTY > 0)
            BEGIN
               SET @nErrNo = 60870
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv PalletID
               GOTO Step_1_Fail
            END
         
         END

         -- TaskDetailKey
         IF @cTaskDetailKey <> '' AND @cTaskDetailKey IS NOT NULL --SY01
         BEGIN
            SELECT @nTaskQty = Qty
            FROM dbo.TaskDetail WITH (NOLOCK) 
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 60890
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Inv TaskKey
               GOTO Step_1_Fail
            END

            SET @cTaskQty = CAST( @nTaskQty AS NVARCHAR( 5))
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' + 
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT' 
            SET @cSQLParam =
               '@nMobile         INT,       ' +
               '@nFunc           INT,       ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cRefNo          NVARCHAR( 10), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLoadKey        NVARCHAR( 10), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQty            INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + 
               '@cID             NVARCHAR( 18), ' + 
               '@cTaskDetailKey  NVARCHAR( 10),  ' +
               '@cReasonCode     NVARCHAR( 20)  OUTPUT ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, '', 
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT      

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Show the statistic
      IF rdt.rdtGetConfig (@nFunc, 'PPAShowSummary', @cStorer) = '1'
      BEGIN
         SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, 
         @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorer, @cFacility, @cPUOM,
            @nCSKU = @nCSKU OUTPUT,
            @nCQTY = @nCQTY OUTPUT,
            @nPSKU = @nPSKU OUTPUT,
            @nPQTY = @nPQTY OUTPUT

         SET @cSKUStat = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
         SET @cQTYStat = CAST( @nCQty AS NVARCHAR( 10)) + '/' + CAST( @nPQty AS NVARCHAR( 10))
      END
      ELSE
      BEGIN
         SET @cSKUStat = ''
         SET @cQTYStat = ''
      END
      
      --(cc02)
      IF @cExtendedUOMSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUOMSP AND type = 'P')  
         BEGIN  
         	INSERT INTO @tExtUOM (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
               
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUOMSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtUOM, ' +
               ' @cPUOM OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtUOM        VariableTable READONLY, ' + 
               ' @cPUOM          NVARCHAR( 1)  OUTPUT,  ' +   
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorer, @tExtUOM, 
                @cPUOM OUTPUT, @nErrNo OUTPUT ,@cErrMsg OUTPUT
  
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKUStat
      SET @cOutField07 = @cQTYStat
      SET @cOutField08 = '' -- @cExtendedInfo
      SET @cOutField09 = @cID
      SET @cOutField10 = @cTaskDetailKey		--INC1045866

      -- Enable all fields
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField08 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- (ChewKP02) 
      EXEC RDT.rdt_STD_EventLog  
        @cActionType = '9', -- Sign in function  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorer

      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

      -- Enable all fields
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''

   SELECT 
      @cFieldAttr01  =  '',
      @cFieldAttr02  =  '',
      @cFieldAttr03  =  '',
      @cFieldAttr04  =  '',
      @cFieldAttr05  =  '',
      @cFieldAttr06  =  '',
      @cFieldAttr07  =  '',
      @cFieldAttr08  =  '',
      @cFieldAttr09  =  '',
      @cFieldAttr10  =  ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      IF ISNULL(@cMultiColScan,'')=''
      BEGIN
         -- Reset this screen var
         SET @cRefNo = ''
         SET @cPickSlipNo = ''
         SET @cLoadKey = ''
         SET @cOrderKey = ''
         SET @cDropID = ''
         SET @cID = ''
         SET @cTaskDetailKey = ''
      END
      ELSE
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadKey
         SET @cOutField04 = @cOrderKey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = @cSKUStat
         SET @cOutField07 = @cQTYStat
         SET @cOutField08 = '' -- @cExtendedInfo
         SET @cOutField09 = @cID
         SET @cOutField10 = @cTaskDetailKey		--INC1045866
      END
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 815. Statistic screen
   REFNO     (field01)
   PSNO      (field02)
   LOADKEY   (field03)
   ORDERKEY  (field04)
   CARTON ID (field05)
   SKU CKD   (field06)
   QTY CKD   (field07)
   EXT INFO  (field08)
   PALLET ID (field09)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Set next screen var
      SET @cSKU = ''
      SET @cPackQTYIndicator = ''
      SET @cPrePackIndicator = ''

      -- Disable QTY field
      IF @cDisableQTYField = '1'
      BEGIN
         SET @cFieldAttr09 = 'O' -- PQTY
         SET @cFieldAttr10 = 'O' -- MQTY
      END

      IF @cConvertQTYSP <> '' AND EXISTS( SELECT TOP 1 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         IF @cPUOM = '6'
            SET @cFieldAttr09 = 'O' -- @nPQTY
      END

      --(yeekung03)
      --IF @cPUOM <> '6'
      --   SET @cFieldAttr10 = 'O' -- MQTY
      
      SET @cOutField01 = '' --@cSKU
      SET @cOutField02 = '' --@cSKU
      SET @cOutField03 = '' --SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField04 = '' --SUBSTRING( @cSKUDesc, 21, 40)
      SET @cOutField05 = '' --@cStyle
      SET @cOutField06 = '' --@cColor
      SET @cOutField07 = '' --@cSize
      SET @cOutField08 = '' --@nPUOM_Div, @cPUOM_Desc, @cMUOM_Desc
      SET @cOutField09 = CASE WHEN @cPPADefaultPQTY <> '' THEN @cPPADefaultPQTY ELSE '' END --@nPUOM
      SET @cOutField10 = CASE WHEN @cTaskDefaultQty = '1' THEN @cTaskQty ELSE @cPPADefaultQTY END --@nMUOM
      SET @cOutField11 = '' --@nPQTY_CHK
      SET @cOutField12 = '' --@nMQTY_CHK
      SET @cOutField13 = '' --@nPQTY_PPA
      SET @cOutField14 = '' --@nMQTY_PPA
      SET @cOutField15 = '' --@cExtendedInfo
      SET @cOutField16 = '' --@cPackQTYIndicator
      EXEC rdt.rdtSetFocusField @nMobile, 1 --SKU

      
      --(cc02)
      INSERT INTO @tDataCapture (Variable, Value) VALUES 
         ('@cRefNo',       @cRefNo), 
         ('@cPickSlipNo',  @cPickSlipNo), 
         ('@cLoadKey',     @cLoadKey), 
         ('@cOrderKey',    @cOrderKey), 
         ('@cDropID',      @cDropID), 
         ('@cID',          @cID), 
         ('@cTaskDetailKey',  @cTaskDetailKey), 
         ('@cSKU',         @cSKU), 
         ('@cBarCode',     ''), 
         ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
         ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
         ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
         ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
         ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
         ('@cOption',      @cOption)

      SET @cCaptureData = '0'
      SET @cCaptureDataInput = ''
      EXEC rdt.rdt_PPAVerifyDataCapture @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, 'CHECK', @tDataCapture,
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
         @cCaptureData OUTPUT,@nErrNo      OUTPUT,  @cErrMsg      OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      IF @cCaptureData = '1'
      BEGIN
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = @cCaptureDataColName
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         
         SET @nFromScn = @nScn
         SET @nFromStep = @nStep
         
         -- Go to data capture screen
         SET @nScn = @nScn + 4
         SET @nStep = @nStep + 5

         GOTO Quit
      END
      
      SET @cCaptureDataInput = ''  --(cc02)
      -- Go to next screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
  
      -- Extended info  
      IF @cExtendedInfoSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')  
         BEGIN  
            INSERT INTO @tExtInfo (Variable, Value) VALUES   
               ('@cRefNo',       @cRefNo),   
               ('@cPickSlipNo',  @cPickSlipNo),   
               ('@cLoadKey',     @cLoadKey),   
               ('@cOrderKey',    @cOrderKey),   
               ('@cDropID',      @cDropID),   
               ('@cID',          @cID),   
               ('@cTaskDetailKey',  @cTaskDetailKey),  
               ('@cSKU',         @cSKU),   
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),   
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))),   
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))),   
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))),   
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))),   
               ('@cOption',      @cOption)  
              
            SET @cExtendedInfo = ''  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +  
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               ' @nMobile        INT,           ' +  
               ' @nFunc          INT,           ' +  
               ' @cLangCode      NVARCHAR( 3),  ' +  
               ' @nStep          INT,           ' +  
               ' @nAfterStep     INT,           ' +  
               ' @nInputKey      INT,           ' +  
               ' @cFacility      NVARCHAR( 5),  ' +  
               ' @cStorerKey     NVARCHAR( 15), ' +  
               ' @tExtInfo       VariableTable READONLY, ' +   
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +   
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo,   
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
           
            SET @cOutField15 = @cExtendedInfo  
         END  
      END  
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      -- Prompt discrepancy
      IF @cPPAPromptDiscrepancy = '1'
      BEGIN
         SELECT @nVariance = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, 
            @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorer, @cFacility, @cPUOM,
            @nVariance = @nVariance OUTPUT

         -- Discrepancy found
         IF @nVariance = 1
         BEGIN
         	-- Extended update      
            IF @cExtendedUpdateSP <> ''      
            BEGIN      
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')      
               BEGIN      
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
                     ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
                  SET @cSQLParam =      
                     '@nMobile         INT,       ' +      
                     '@nFunc           INT,       ' +      
                     '@cLangCode       NVARCHAR( 3),  ' +      
                     '@nStep           INT,           ' +      
                     '@nInputKey       INT,           ' +      
                     '@cStorerKey      NVARCHAR( 15), ' +      
                     '@cRefNo          NVARCHAR( 10), ' +      
                     '@cPickSlipNo     NVARCHAR( 10), ' +      
                     '@cLoadKey        NVARCHAR( 10), ' +      
                     '@cOrderKey       NVARCHAR( 10), ' +      
                     '@cDropID         NVARCHAR( 20), ' +      
                     '@cSKU            NVARCHAR( 20), ' +      
                     '@nQty            INT,           ' +      
                     '@cOption         NVARCHAR( 1),  ' +      
                     '@nErrNo          INT           OUTPUT, ' +      
                     '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
                     '@cID             NVARCHAR( 18), ' +       
                     '@cTaskDetailKey  NVARCHAR( 10), ' +        
                     '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, '',         
                     @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT     
      
                  IF @nErrNo <> 0      
                     GOTO Quit      
               END      
            END
            
            -- Go to discrepency screen      
            SET @cOutField01 = '' -- Option    
            SET @cFieldAttr02 = CASE WHEN @cCaptureReasonCode ='1' THEN '' ELSE 'o' END        
            SET @cOutField02 = @cReasonCode       
            SET @cInField02 = ''   
            
            SET @nScn = @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
         ELSE --(cc02)
         BEGIN
            INSERT INTO @tDataCapture (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@cBarCode',     ''), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)

            SET @cCaptureData = '0'
            SET @cCaptureDataInput = ''
            EXEC rdt.rdt_PPAVerifyDataCapture @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, 'CHECK', @tDataCapture,
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
               @cCaptureData OUTPUT,@nErrNo      OUTPUT,  @cErrMsg      OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         
         	-- No variance and only export order need to capture PackInfo
         	IF @cCapturePackInfo <> '' AND @cCaptureData = '1' 
         	BEGIN
         		-- Get PackInfo    
               SET @cCartonType = ''    
               SET @cWeight = ''    
               SET @cCube = ''    
               SET @cRefNo = ''   
               
               -- Prepare capturePackInfo screen var    
               SET @cOutField01 = @cCartonType    
               SET @cOutField02 = @cWeight   
               SET @cOutField03 = @cCube       
          
               -- Enable disable field    
               SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END    
               SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END    
               SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cCapturePackInfo) = 0 THEN 'O' ELSE '' END    
                         
               -- Position cursor    
               IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE    
               IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE    
               IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3     
                                
               SET @nFromScn = @nScn
               SET @nFromStep = @nStep
          
               -- Go to capture PackInfo screen    
               SET @nScn = 5980   
               SET @nStep = @nStep + 6    
               
                
               GOTO Quit    
         	END
         END
      END

      -- Prompt print packing list
      IF @cPPAPrintPackListSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPPAPrintPackListSP AND type = 'P')
         BEGIN
            SET @cPrintPackList = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPPAPrintPackListSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cOption, @cType, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cPrintPackList OUTPUT, @cID, @cTaskDetailKey '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cRefNo          NVARCHAR( 10), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLoadKey        NVARCHAR( 10), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cType           NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20)OUTPUT, ' +
               '@cPrintPackList  NVARCHAR( 1) OUTPUT, ' + 
               '@cID             NVARCHAR( 18), ' + 
               '@cTaskDetailKey  NVARCHAR( 10)  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cOption, 'CHECK',
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cPrintPackList OUTPUT, @cID, @cTaskDetailKey

            IF @cPrintPackList = '1'
            BEGIN
               -- Go to print pack list screen
               SET @cOutField01 = '' -- Option
               SET @nScn = @nScn + 3
               SET @nStep = @nStep + 3
               GOTO Step_99
            END
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, '',         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Reset prev screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''
      SET @cID = ''
      SET @cTaskDetailKey = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cID
      SET @cOutField07 = @cTaskDetailKey

      -- Enable disable field
      IF @nFunc in ( 850, 851) SET @cFieldAttr01 = '' ELSE SET @cFieldAttr01 = 'O' --RefNo
      IF @nFunc in ( 850, 852) SET @cFieldAttr02 = '' ELSE SET @cFieldAttr02 = 'O' --PickSlipNo
      IF @nFunc in ( 850, 853) SET @cFieldAttr03 = '' ELSE SET @cFieldAttr03 = 'O' --LoadKey
      IF @nFunc in ( 850, 854) SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O' --OrderKey
      IF @nFunc in ( 850, 855) SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O' --DropID
      IF @nFunc in ( 850, 844) SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O' --ID
      IF @nFunc in ( 850, 906) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O' --TaskDetailKey

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
      -- Go to extend screen label, if no config, will jump to previous step
      GOTO Step_99
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 816. SKU, QTY screen
   SKU            (field01, input)
   SKU            (field02)
   SKU desc1      (field03)
   SKU desc1      (field04)
   STYLE          (field05)
   COLOR SIZE     (field06, field07)
   DIV,PUOM,MUOM  (field08)
   PQTY           (field09, input)
   MQTY           (field10, input)
   PQTY_CHK       (field11)
   MQTY_CHK       (field12)
   PQTY_PPA       (field13)
   MQTY_PPA       (field14)
   ExtendedInfo   (field15)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cBarcode NVARCHAR( 60)
      --DECLARE @cUPC     NVARCHAR( 30)
      DECLARE @cPQTY    NVARCHAR( 5)
      DECLARE @cMQTY    NVARCHAR( 5)

      -- Screen mapping
      SET @cBarcode = @cInField01 -- SKU
      SET @cUPC = LEFT( @cInField01, 30) -- SKU
      SET @cPQTY = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END
      SET @cMQTY = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END

      -- Retain value
      SET @cOutField09 = CASE WHEN @cFieldAttr09 = 'O' THEN @cOutField09 ELSE @cInField09 END -- PQTY
      SET @cOutField10 = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END -- MQTY

      -- Validate SKU blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 60872
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- SKU required
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_3_Fail
      END

      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode, 
               @cUPC    = @cUPC    OUTPUT, 
               @nQTY    = @cMQTY   OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT, 
               @cErrMsg = @cErrMsg OUTPUT
            -- IF @nErrNo <> 0
            --    GOTO Step_3_Fail
         END
         
         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SELECT @cSKU = '', @nQTY = 0

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
               ' @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cBarcode, ' + 
               ' @cSKU OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile      INT,       ' +
               ' @nFunc        INT,       ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cRefNo       NVARCHAR( 10), ' +
               ' @cPickSlipNo  NVARCHAR( 10), ' +
               ' @cLoadKey     NVARCHAR( 10), ' +
               ' @cOrderKey    NVARCHAR( 10), ' +
               ' @cDropID      NVARCHAR( 20), ' +
               ' @cID          NVARCHAR( 18), ' +
               ' @cTaskDetailKey NVARCHAR( 10), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cSKU         NVARCHAR( 20) OUTPUT, ' +
               ' @nQTY         INT           OUTPUT, ' +
               ' @nErrNo       INT           OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, 
               @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cBarcode, 
               @cUPC OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail
            
            IF @nQTY > 0
               SET @cMQTY = CAST( @nQTY AS NVARCHAR( 5))
         END
      END

      DECLARE @nSKUCnt INT
      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorer
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 60873
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Step_3_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            SET @cDocType = ''
            SET @cDocNo = ''
            
            IF @cID <> ''
               SELECT @cDocType = 'LOTXLOCXID.ID', @cDocNo = @cID
            
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,
               'POPULATE',
               @cMultiSKUBarcode,
               @cStorer,
               @cUPC     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               @cDocType, 
               @cDocNo

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nScn = 3570
               SET @nStep = @nStep + 3
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
            BEGIN
               SET @nErrNo = 0
               SET @cSKU = @cUPC
            END
            
            IF @nErrNo = 2 --(yeekung03)      
            BEGIN      
               IF @cPPAAllowSKUNotInPickList = '1' --Not allow        
               BEGIN      
                  EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,          
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,          
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,          
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,          
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,          
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,          
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,          
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,          
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,          
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,          
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,          
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,          
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,          
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,          
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,          
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,          
                  'POPULATE',          
                  @cMultiSKUBarcode,          
                  @cStorer,          
                  @cUPC     OUTPUT,          
                  @nErrNo   OUTPUT,          
                  @cErrMsg  OUTPUT          
          
                  IF @nErrNo = 0 -- Populate multi SKU screen          
                  BEGIN          
                     -- Go to Multi SKU screen          
                     --SET @cErrMsg=@cUPC              
                     SET @nFromScn = @nScn          
                     SET @nScn = 3570          
                     SET @nStep = @nStep + 3          
                     GOTO Quit          
                  END          
                  IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen          
                  BEGIN          
                     SET @nErrNo = 0          
                     SET @cSKU = @cUPC          
                  END       
                  IF @nErrNo = 2 --No sku found         
                  BEGIN          
                     SET @nErrNo = 60891        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSkuFound        
                     GOTO Step_3_Fail            
                  END
           		END
           		ELSE
             	BEGIN          
                  SET @nErrNo = 60892        
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSkuFound        
                  GOTO Step_3_Fail            
               END       
            END
         END 
         ELSE
         BEGIN
            SET @nErrNo = 60885
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarcod
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''
            GOTO Step_3_Fail
         END
      END
      
      -- Get SKU
      EXEC rdt.rdt_GetSKU
          @cStorerKey  = @cStorer
         ,@cSKU        = @cUPC      OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 60886
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Step_3_Fail
      END
      SET @cSKU = @cUPC

      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtValidate (Variable, Value) VALUES 
               ('@cSKU',         @cSKU), 
               ('@nInputKey',    CAST( @nInputKey AS NVARCHAR( 1)))

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@cStorer        NVARCHAR( 15), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cRefNo         NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cLoadKey       NVARCHAR( 10), ' +
               '@cPickSlipNo    NVARCHAR( 10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT, ' + 
               '@cID            NVARCHAR( 18), ' + 
               '@cTaskDetailKey NVARCHAR( 10), ' + 
               '@tExtValidate   VARIABLETABLE READONLY'
            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate
            
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_3_Fail
            END
         END
      END

      --Get SKU Description, UOMQTY
      SELECT
         @cSKUDesc = SKU.Descr,
         @cStyle = SKU.Style,
         @cColor = SKU.Color,
         @cSize = SKU.Size,
         @cPackQTYIndicator = SKU.PackQTYIndicator,
         @cPrePackIndicator = SKU.PrePackIndicator,
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
         @nPUOM_Div = CAST(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorer
         AND SKU.SKU = @cSKU

      -- Check valid prepack indicator
      IF NOT ((@cPrePackIndicator = '2') AND (RDT.rdtIsValidQTY( @cPackQTYIndicator , 1) = 1))
         SET @cPackQTYIndicator = ''

      SET @nQTY_PPA = 0
      SET @nQTY_CHK = 0

            -- (ChewKP01)
      IF ISNULL(@cExtendedRefNoSP,'') <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedRefNoSP AND type = 'P')--yeekung08
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedRefNoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey,  @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,@cType, ' + 
            ' @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT,@nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
            '@nMobile        INT, ' +                      
            '@nFunc          INT, ' +                      
            '@cLangCode      NVARCHAR( 3),  ' +            
            '@nStep          INT,           ' +            
            '@cStorer        NVARCHAR( 15), ' +            
            '@cFacility      NVARCHAR( 5),  ' +            
            '@cRefNo         NVARCHAR( 20), ' +            
            '@cOrderKey      NVARCHAR( 10), ' +            
            '@cDropID        NVARCHAR( 20), ' +            
            '@cLoadKey       NVARCHAR( 10), ' +            
            '@cPickSlipNo    NVARCHAR( 10), ' +            
            '@cID            NVARCHAR( 18),       '+       
            '@cTaskDetailKey NVARCHAR( 10),       '+       
            '@cSKU           NVARCHAR( 20),       ' +      
            '@cType          NVARCHAR( 20),       '+       
            '@nCSKU          INT  OUTPUT ,  '+             
            '@nCQTY          INT  OUTPUT ,  '+             
            '@nPSKU          INT OUTPUT,          '+       
            '@nPQTY          INT OUTPUT,          '+       
            '@nVariance      INT OUTPUT,   '+              
            '@nQTY_PPA       INT OUTPUT,          '+       
            '@nQTY_CHK       INT OUTPUT,          '+   
            '@nRowRef        INT OUTPUT,          '+ 
            '@nErrNo         INT           OUTPUT,'+       
            '@cErrMsg        NVARCHAR( 20) OUTPUT '        

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo,  @cID, @cTaskDetailKey,@cSKU ,'QTY',
            @nCSKU OUTPUT,@nCQTY OUTPUT,@nPSKU OUTPUT, @nPQTY OUTPUT,@nVariance OUTPUT,@nQTY_PPA OUTPUT,@nQTY_CHK OUTPUT,@nRowRef OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT


            IF @nErrNo <> 0
            BEGIN
               GOTO QUIT
            END

         END
      END
      ELSE
      BEGIN
         -- RefNo
         IF @cRefNo <> '' AND @cRefNo IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND RefKey = @cRefNo

            -- Get pick QTY from load
            IF @nRowRef IS NULL
               SELECT @nQTY_PPA = SUM( PD.QTY)
               FROM dbo.OrderDetail AS OD WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                  INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
               WHERE LP.UserDefine10 = @cRefNo
                  AND OD.StorerKey = @cStorer
                  AND OD.SKU = @cSKU
                  AND PD.Status >= @cPickConfirmStatus
         END

         -- PickSlipNo
         IF @cPickSlipNo <> '' AND @cPickSlipNo IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND PickSlipNo = @cPickSlipNo

            -- Get pick QTY of the SKU
            IF @nRowRef IS NULL
            BEGIN
               IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
                  SELECT @nQTY_PPA = SUM( PD.QTY)
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON RKL.PickDetailKey = PD.PickDetailKey
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.SKU = @cSKU
                     AND PD.Status >= @cPickConfirmStatus
               ELSE
                  SELECT @nQTY_PPA = SUM( PD.QTY)
                  FROM dbo.OrderDetail OD WITH (NOLOCK)
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                     INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON Pack.PackKey = OD.PackKey
                  WHERE OD.LoadKey = @cExternOrderKey
                     AND OD.OrderKey = CASE WHEN @cOrderKey = '' THEN OD.OrderKey ELSE @cOrderKey END
                     AND PD.SKU = @cSKU
                     AND PD.Status >= @cPickConfirmStatus
            END
         END

         -- LoadKey
         IF @cLoadKey <> '' AND @cLoadKey IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND LoadKey = @cLoadKey

            -- Get pick QTY of the SKU
            IF @nRowRef IS NULL
               SELECT @nQTY_PPA = SUM( PD.QTY)
               FROM dbo.OrderDetail AS OD WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail AS PD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                  INNER JOIN dbo.LoadPlan AS LP WITH (NOLOCK) ON OD.LoadKey = LP.LoadKey
               WHERE LP.LoadKey = @cLoadKey
                  AND OD.StorerKey = @cStorer
                  AND OD.SKU = @cSKU
                  AND PD.Status >= @cPickConfirmStatus
         END

         -- OrderKey
         IF @cOrderKey <> '' AND @cOrderKey IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND OrderKey = @cOrderKey

            -- Get pick QTY from load
            IF @nRowRef IS NULL
               SELECT @nQTY_PPA = SUM( QTY)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
                  AND StorerKey = @cStorer
                  AND SKU = @cSKU
                  AND Status >= @cPickConfirmStatus
         END

         -- DropID
         IF @cDropID <> '' AND @cDropID IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND DropID = @cDropID

            -- Get pick QTY
            IF @nRowRef IS NULL
            BEGIN
               IF @cPPACartonIDByPackDetailDropID = '1'
                  SELECT @nQTY_PPA = SUM( CASE WHEN @cPreCartonization = '1' THEN PD.ExpQTY ELSE PD.QTY END)
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.DropID = @cDropID
                     AND PH.StorerKey = @cStorer
                     AND PD.SKU = @cSKU
               ELSE
               IF @cPPACartonIDByPackDetailLabelNo = '1'
                  SELECT @nQTY_PPA = SUM( CASE WHEN @cPreCartonization = '1' THEN PD.ExpQTY ELSE PD.QTY END)
                  FROM dbo.PackHeader PH WITH (NOLOCK)
                     INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)
                  WHERE PD.LabelNo = @cDropID
                     AND PH.StorerKey = @cStorer
                     AND PD.SKU = @cSKU
               ELSE
               IF @cPPACartonIDByPickDetailCaseID = '1'
                  SELECT @nQTY_PPA = SUM( QTY)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE CaseID = @cDropID
                     AND StorerKey = @cStorer
                     AND SKU = @cSKU
                     AND Status >= @cPickConfirmStatus
                     AND ShipFlag <> 'Y'
               ELSE
                  SELECT @nQTY_PPA = SUM( QTY)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE DropID = @cDropID
                     AND StorerKey = @cStorer
                     AND SKU = @cSKU
                     AND Status >= @cPickConfirmStatus
                     AND ShipFlag <> 'Y'
            END
         END

         -- ID
         IF @cID <> '' AND @cID IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND ID = @cID

            -- Get pick QTY
            IF @nRowRef IS NULL
            BEGIN
               IF @cPickConfirmStatus = '5'
                  SELECT @nQTY_PPA = SUM( QTYPicked)
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.Facility = @cFacility
                     AND ID = @cID
                     AND StorerKey = @cStorer
                     AND SKU = @cSKU
               ELSE IF @cPickConfirmStatus = '3'
                  SELECT @nQTY_PPA = SUM( QTYAllocated + QTYPicked)
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.Facility = @cFacility
                     AND ID = @cID
                     AND StorerKey = @cStorer
                     AND SKU = @cSKU
               ELSE
                  SELECT @nQTY_PPA = SUM( QTY)
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.Facility = @cFacility
                     AND ID = @cID
                     AND StorerKey = @cStorer
                     AND SKU = @cSKU
            END
         END


         -- TaskDetailKey
         IF @cTaskDetailKey <> '' AND @cTaskDetailKey IS NOT NULL
         BEGIN
            -- Get PPA details
            SELECT TOP 1
               @nQTY_PPA = PQTY,
               @nQTY_CHK = CQTY,
               @nRowRef = RowRef
            FROM rdt.rdtPPA WITH (NOLOCK)
            WHERE SKU = @cSKU
               AND StorerKey = @cStorer
               AND TaskDetailKey = @cTaskDetailKey

            -- Get pick QTY
            IF @nRowRef IS NULL
            BEGIN
               SELECT @nQTY_PPA = SUM( QTY)
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE SKU = @cSKU
               AND   StorerKey = @cStorer
               AND   TaskDetailKey = @cTaskDetailKey
            END
         END
      END

      -- Validate SKU not in pick list
      IF @nQTY_PPA IS NULL
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = rdt.rdtgetmessage( 60876, @cLangCode,'DSP') --SKU NotInList
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
         
         -- Reset error 0 here (james10)    
         SET @nErrNo = 0 

         IF @cPPAAllowSKUNotInPickList <> '1' --Not allow
            GOTO Step_3_Fail
      END

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT TOP 1 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nPQTY_CHK = 0
            SET @nPQTY_PPA = 0
            SET @nMQTY_CHK = @nQTY_CHK
            SET @nMQTY_PPA = @nQTY_PPA
            SET @cFieldAttr09 = 'O' -- @nPQTY
            IF @cDisableQTYField <> '1'
               EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY

            SET @nMQTY_PPA = @nQTY_PPA
            SET @nMQTY_CHK = @nQTY_CHK

            SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
            SET @cSQLParam =
               '@cType   NVARCHAR( 10), ' +
               '@cStorer NVARCHAR( 15), ' +
               '@cSKU    NVARCHAR( 20), ' +
               '@nQTY    INT OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nMQTY_CHK OUTPUT
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nMQTY_PPA OUTPUT
         END
         ELSE
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nPQTY_CHK = @nQTY_CHK / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_CHK = @nQTY_CHK % @nPUOM_Div -- Calc the remaining in master unit
            SET @nPQTY_PPA = @nQTY_PPA / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_PPA = @nQTY_PPA % @nPUOM_Div -- Calc the remaining in master unit
            IF @cDisableQTYField <> '1'
            BEGIN
               SET @cFieldAttr09 = '' -- @nPQTY
               EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
            END
         END
      END
      ELSE
      BEGIN
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nPQTY_CHK = 0
            SET @nPQTY_PPA = 0
            SET @nMQTY_CHK = @nQTY_CHK
            SET @nMQTY_PPA = @nQTY_PPA
            SET @cFieldAttr09 = 'O' -- @nPQTY
            IF @cDisableQTYField <> '1'
               EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nPQTY_CHK = @nQTY_CHK / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_CHK = @nQTY_CHK % @nPUOM_Div -- Calc the remaining in master unit
            SET @nPQTY_PPA = @nQTY_PPA / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY_PPA = @nQTY_PPA % @nPUOM_Div -- Calc the remaining in master unit
            IF @cDisableQTYField <> '1'
            BEGIN
               SET @cFieldAttr09 = '' -- @nPQTY
               EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
            END
         END
      END

      -- Display SKU info
      SET @cOutField01 = @cSKU
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField05 = @cStyle
      SET @cOutField06 = @cColor
      SET @cOutField07 = @cSize
      SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
      SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_CHK AS NVARCHAR(5)) END
      SET @cOutField12 = CAST( @nMQTY_CHK AS NVARCHAR(6)) --(yeekung07)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_PPA AS NVARCHAR(5)) END
      SET @cOutField14 = CAST( @nMQTY_PPA AS NVARCHAR(6)) --(yeekung07)
      SET @cOutField15 = '' -- @cExtendedInfo
      SET @cOutField16 = @cPackQTYIndicator

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Blind count
      IF @cPPABlindCount = '1'
      BEGIN
         SET @cOutField13 = '' -- @nPQTY_PPA
         SET @cOutField14 = '' -- @nMQTY_PPA
      END

      -- Validate QTY blank
      IF @cPQTY = '' AND @cMQTY = ''
      BEGIN
         SET @nErrNo = 60874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QTY required'
         GOTO Step_3_Fail
      END

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 60874
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
         GOTO Step_3_Fail
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 60875
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
         GOTO Step_3_Fail
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Convert key-in QTY to base QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @nQTY = @nMQTY

         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToBaseQTY', @cStorer, @cSKU, @nQTY OUTPUT
      END
      ELSE
      BEGIN
         -- Calc total QTY in master UOM
         SET @nQTY = rdt.rdtConvUOMQTY( @cStorer, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
         SET @nQTY = @nQTY + @nMQTY

         -- Multiply QTY if have prepack indicator
         IF @cPackQTYIndicator <> ''
         BEGIN
            SET @nQTY = @nQTY * CAST( @cPackQTYIndicator AS INT)
            SET @nPQTY = @nPQTY * CAST( @cPackQTYIndicator AS INT)
            SET @nMQTY = @nMQTY * CAST( @cPackQTYIndicator AS INT)
         END
      END

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 60875
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         EXEC rdt.rdtSetFocusField @nMobile, 10 --MQTY
         GOTO Step_3_Fail
      END

      -- Check tolerance
      IF @nTol >= 0
      BEGIN
         -- Only apply for SKU in pick list, so tolerance won't popup every time
         IF @nQTY_PPA > 0
         BEGIN
            -- Over tolerance (with QTY user keyed-in)
            IF (@nQTY + @nQTY_CHK) > (@nQTY_PPA * (1 + (@nTol * 0.01)))
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = rdt.rdtgetmessage( 60877, @cLangCode,'DSP') --Over Tolerance
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2

               IF @cPPAAllowQTYExceedTolerance <> '1' --Not allow
                  GOTO Step_3_Fail
            END
         END
      END

      INSERT INTO @tDataCapture (Variable, Value) VALUES 
         ('@cRefNo',       @cRefNo), 
         ('@cPickSlipNo',  @cPickSlipNo), 
         ('@cLoadKey',     @cLoadKey), 
         ('@cOrderKey',    @cOrderKey), 
         ('@cDropID',      @cDropID), 
         ('@cID',          @cID), 
         ('@cTaskDetailKey',  @cTaskDetailKey), 
         ('@cSKU',         @cSKU), 
         ('@cBarCode',     ''), 
         ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
         ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
         ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
         ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
         ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
         ('@cOption',      @cOption)

      SET @cCaptureData = '0'
      EXEC rdt.rdt_PPAVerifyDataCapture @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, 'CHECK', @tDataCapture,
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
         @cCaptureData OUTPUT,@nErrNo      OUTPUT,  @cErrMsg      OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      IF @cCaptureData = '1'
      BEGIN
         SET @cOutField01 = @cPickSlipNo
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = @cCaptureDataColName
         SET @cOutField05 = ''
         SET @cOutField06 = ''


         IF @cExtendedValidateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
            INSERT INTO @tExtValidate (Variable, Value) VALUES 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nQTY_PPA',     CAST( @nQTY_PPA AS NVARCHAR( 10))), 
               ('@nQTY_CHK',     CAST( @nQTY_CHK AS NVARCHAR( 10))), 
               ('@nRowRef',      CAST( @nRowRef AS NVARCHAR( 10))), 
               ('@nInputKey',    CAST( @nInputKey AS NVARCHAR( 1))), 
               ('@cUserName',    @cUserName)

               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, ' + 
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT,           ' +
                  '@cStorer        NVARCHAR( 15), ' +
                  '@cFacility      NVARCHAR( 5),  ' +
                  '@cRefNo         NVARCHAR( 10), ' +
                  '@cOrderKey      NVARCHAR( 10), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@cLoadKey       NVARCHAR( 10), ' +
                  '@cPickSlipNo    NVARCHAR( 10), ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT, ' + 
                  '@cID            NVARCHAR( 18), ' +
                  '@cTaskDetailKey NVARCHAR( 10), ' + 
                  '@tExtValidate   VariableTable READONLY ' 
            
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate 
            
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Step_1_Fail
               END
            END
         END

         EXEC rdt.rdtSetFocusField @nMobile, 3

         SET @nFromScn = @nScn
         SET @nFromStep = @nStep

         -- Go to data capture screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 4

         GOTO Quit
      END
            
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_3_Upd -- For rollback or commit only our own transaction

      -- (ChewKP02) 
      EXEC RDT.rdt_STD_EventLog  
        @cActionType = '3', -- Sign in function  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorer,
        @cRefNo1     = @cRefNo,
        @cPickSlipNo = @cPickSlipNo,
        @cLoadKey    = @cLoadKey,
        @cOrderKey   = @cOrderKey,
        @cDropID     = @cDropID,  
        @cCartonID   = @cDropID,  --(cc01)
        @cID         = @cID,
        @cSKU        = @cSKU,
        @nQty        = @nQTY 

      -- Insert PPA
      IF @nRowRef IS NULL
      BEGIN
         INSERT INTO rdt.rdtPPA WITH (ROWLOCK) 
         (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, 
         UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, ID, TaskDetailKey)
         VALUES 
         (@cRefNo, @cPickSlipNo, @cLoadKey, '', @cStorer, @cSKU, @cSKUDesc, @nQTY_PPA, @nQTY, '0', 
         @cUserName, GETDATE(), 1, 1, @cOrderKey, @cDropID, @cID, @cTaskDetailKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nErrNo = 60878
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail INS PPA
            GOTO Step_3_RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Update PPA
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nQTY,
            NoOfCheck = NoOfCheck + 1
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nErrNo = 60879
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail UPD PPA
            GOTO Step_3_RollBackTran
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, '',         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   

            IF @nErrNo <> 0
            BEGIN
               SET @nPQTY = 0
               SET @nMQTY = 0
               GOTO Step_3_RollBackTran
            END
         END
      END

      GOTO Step_3_Commit

      Step_3_RollBackTran:
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
         GOTO Reset_Qty
      END

      Step_3_Commit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      Reset_Qty:
      IF @nPUOM_Div > 0 AND @cPUOM <> '6' 
      BEGIN
         SET @nPQTY = @nPQTY/@nPUOM_Div--rdt.rdtConvUOMQTY( @cStorer, @cSKU, @cMQTY, 6, @cPUOM)
         SET @nMQTY = @cMQTY%@nPUOM_Div
      END

      -- Top up check QTY
      SET @nPQTY_CHK = @nPQTY_CHK + @nPQTY
      SET @nMQTY_CHK = @nMQTY_CHK + @nMQTY

      -- 1 task 1 sku. Go back screen 1 when scanned sku
      IF @nFunc = 906
      BEGIN
         -- Enable all fields
         SELECT @cFieldAttr01 = '', @cFieldAttr02 = '', @cFieldAttr03 = '',
                @cFieldAttr04 = '', @cFieldAttr05 = '', @cFieldAttr06 = '',
                @cFieldAttr07 = '', @cFieldAttr08 = '', @cFieldAttr09 = '',
                @cFieldAttr10 = '', @cFieldAttr11 = '', @cFieldAttr12 = '',
                @cFieldAttr15 = '', @cFieldAttr14 = '', @cFieldAttr13 = ''

         -- Enable disable field
         SET @cFieldAttr01 = 'O' --RefNo
         SET @cFieldAttr02 = 'O' --PickSlipNo
         SET @cFieldAttr03 = 'O' --LoadKey
         SET @cFieldAttr04 = 'O' --OrderKey
         SET @cFieldAttr05 = 'O' --DropID
         SET @cFieldAttr06 = 'O' --ID
         SET @cFieldAttr07 = ''  --TaskDetailKey

         --INC1045866(START)
		 -- Reset prev screen var
		 SET @cRefNo = ''
		 SET @cPickSlipNo = ''
		 SET @cLoadKey = ''
		 SET @cOrderKey = ''
		 SET @cDropID = ''
		 SET @cID = ''
		 SET @cTaskDetailKey = ''
		 SET @cCaptureDataInput = '' --(cc02)
		 
		 SET @cOutField01 = @cRefNo
		 SET @cOutField02 = @cPickSlipNo
		 SET @cOutField03 = @cLoadKey
		 SET @cOutField04 = @cOrderKey
		 SET @cOutField05 = @cDropID
		 SET @cOutField06 = @cID
		 SET @cOutField07 = @cTaskDetailKey
		 --INC1045866(END)
         
         -- Go to next screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2

         GOTO Quit
      END

      -- Display QTY info
      --SET @cSKU = ''
      SET @cOutField01 = '' --@cSKU
      SET @cOutField09 = CASE WHEN @cPPADefaultPQTY <> '' THEN @cPPADefaultPQTY ELSE '' END--@nPQTY
      SET @cOutField10 = CASE WHEN @cTaskDefaultQty = '1' THEN @cTaskQty ELSE @cPPADefaultQTY END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_CHK AS NVARCHAR(5)) END
      SET @cOutField12 = CAST( @nMQTY_CHK AS NVARCHAR(6)) --(yeekung07)
      SET @cOutField15 = '' -- @cExtendedInfo
      EXEC rdt.rdtSetFocusField @nMobile, 1 --SKU

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, '',         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      
      IF rdt.rdtGetConfig (@nFunc, 'PPAShowSummary', @cStorer) = '1'
      BEGIN
         SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorer, @cFacility, @cPUOM,
            @nCSKU = @nCSKU OUTPUT,
            @nCQTY = @nCQTY OUTPUT,
            @nPSKU = @nPSKU OUTPUT,
            @nPQTY = @nPQTY OUTPUT

         SET @cSKUStat = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
         SET @cQTYStat = CAST( @nCQTY AS NVARCHAR( 10)) + '/' + CAST( @nPQTY AS NVARCHAR( 10))

      END
      ELSE
      BEGIN
         SET @cSKUStat = ''
         SET @cQTYStat = ''
      END

		IF (@cDropID<>'') AND ((@cShipLabel <> '') OR (@cShippingContentLabel <> ''))--(yeekung04) (yeekung05)     
		BEGIN         
	      --(yeekung01)
	      SELECT
	      	@nPPA_QTY = ISNULL(SUM(PD.Qty),0)
	      FROM dbo.PackHeader PH WITH (NOLOCK)
	      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
	      WHERE PD.DropID = @cDropID
	      	AND PH.StorerKey = @cStorer

	      SELECT
	      	@nPD_QTY = ISNULL(SUM(Qty),0)
	      FROM dbo.PickDetail WITH (NOLOCK)
	      WHERE DropID = @cDropID
	      	AND StorerKey = @cStorer
	      	AND STATUS = '5'

	      IF (@nPPA_QTY = @nPD_QTY) --(yeekung01)
	      BEGIN

	         SELECT TOP 1
	         	@cPicksSlipNo=PD.PickSlipNo ,
	         	@cFromCartonNo=PD.CartonNo,
	        	 	@cToCartonNo=MAX(PD.CartonNo)
	         FROM dbo.PackHeader PH WITH (NOLOCK)
	         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
	         WHERE PD.DropID = @cDropID
	         AND PH.StorerKey = @cStorer
	         GROUP BY PD.PickSlipNo,PD.CartonNo

	         /*--Print packing manifest
	         IF @cPackList <> ''
	         BEGIN
	            DECLARE @tPackingManifests AS VariableTable
	            INSERT INTO @tPackingManifests (Variable, Value) VALUES ( '@cPicksSlipNo', @cPicksSlipNo)

	            -- Print label
	            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, '', @cPrinterPpr,
		            @cPackList, -- Report type
		            @tPackingManifests, -- Report params
		            'rdtfnc_PostPickAudit',
		            @nErrNo  OUTPUT,
		            @cErrMsg OUTPUT

	            IF @nErrNo <> 0
	               GOTO Step_3_Fail
	         END  */

	         IF @cShipLabel <> ''
	         BEGIN
	            DECLARE @tShippingLabels AS VariableTable
	            INSERT INTO @tShippingLabels (Variable, Value) VALUES ( '@cPicksSlipNo', @cPicksSlipNo)
	            INSERT INTO @tShippingLabels (Variable, Value) VALUES ( '@cFromCartonNo', @cFromCartonNo)
	            INSERT INTO @tShippingLabels (Variable, Value) VALUES ( '@cToCartonNo', @cToCartonNo)

	            -- Print label
	            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cPrinter, '',
		            @cShipLabel, -- Report type
		            @tShippingLabels, -- Report params
		            'rdtfnc_PostPickAudit',
		            @nErrNo  OUTPUT,
		            @cErrMsg OUTPUT

	            IF @nErrNo <> 0
	               GOTO Step_3_Fail
	         END
    
				--Print Shipping Content label
				IF @cShippingContentLabel <> ''    
				BEGIN    
					DECLARE @tShippingContentLabels AS VariableTable    
					INSERT INTO @tShippingContentLabels (Variable, Value) VALUES ( '@cPicksSlipNo', @cPicksSlipNo)    
					INSERT INTO @tShippingContentLabels (Variable, Value) VALUES ( '@cFromCartonNo', @cFromCartonNo)    
					INSERT INTO @tShippingContentLabels (Variable, Value) VALUES ( '@cToCartonNo', @cToCartonNo)    

					-- Print label    
					EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cPrinter,'',      
					@cShippingContentLabel, -- Report type    
					@tShippingContentLabels, -- Report params    
					'rdtfnc_PostPickAudit',     
					@nErrNo  OUTPUT,    
					@cErrMsg OUTPUT     

					IF @nErrNo <> 0    
						GOTO Step_3_Fail    
				END     
			END
		END

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKUStat
      SET @cOutField07 = @cQTYStat
      SET @cOutField08 = '' -- @cExtendedInfo
      SET @cOutField09 = @cID
      SET @cOutField10 = @cTaskDetailKey

      -- Enable QTY field
      SET @cFieldAttr09 = '' -- PQTY
      SET @cFieldAttr10 = '' -- MQTY

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField08 = @cExtendedInfo
         END
      END
   END

   Step_3_ExtScn_01:
   BEGIN
      -- If error happened, jump to fail section
      IF @nErrNo <> 0
         GOTO Step_3_Fail
      SET @nAction = 0 --Jump to Extended Screen
      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            DELETE FROM @tExtScnData
            INSERT INTO @tExtScnData (Variable, Value) VALUES 
            ('@cDropID',         @cDropID),
            ('@cRefNo',          @cRefNo),
            ('@cPickSlipNo',     @cPickSlipNo),
            ('@cLoadKey',        @cLoadKey),
            ('@cOrderKey',       @cOrderKey),
            ('@cSKU',            @cSKU), 
            ('@nInputKey',       CAST( @nInputKey AS NVARCHAR( 1))),
            ('@cID',             @cID)
            
            EXECUTE [RDT].[rdt_ExtScnEntry] 
               @cExtendedScnSP,  --855ExtScn01
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @tExtScnData,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
               @nAction, 
               @nScn OUTPUT,  @nStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT,
               @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
               @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
               @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
               @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
               @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
               @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
               @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
               @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
               @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
               @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END
   GOTO Quit

   Step_3_Fail:
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 817. Discrepancy screen
   DISCREPANCY FOUND
   1=Send to QC
   2=Exit anyway
   OPTION (field01)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01 -- Option
      SET @cReasonCode = CASE WHEN @cCaptureReasonCode='1' THEN @cInField02 ELSE '' END    

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 60881
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_4_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 60882
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_4_Fail
      END
      
      IF @cCaptureReasonCode='1'        
      BEGIN        
         IF @cReasonCode = ''        
         BEGIN        
            SET @nErrNo = 60893        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired        
            GOTO Step_4_Fail        
         END        
      END 

      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtValidate (Variable, Value) VALUES 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nQTY_PPA',     CAST( @nQTY_PPA AS NVARCHAR( 10))), 
               ('@nQTY_CHK',     CAST( @nQTY_CHK AS NVARCHAR( 10))), 
               ('@nRowRef',      CAST( @nRowRef AS NVARCHAR( 10))), 
               ('@nInputKey',    CAST( @nInputKey AS NVARCHAR( 1))), 
               ('@cUserName',    @cUserName),
               ('@cOption',      @cOption)

            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT,           ' +
               '@cStorer        NVARCHAR( 15), ' +
               '@cFacility      NVARCHAR( 5),  ' +
               '@cRefNo         NVARCHAR( 20), ' +
               '@cOrderKey      NVARCHAR( 10), ' +
               '@cDropID        NVARCHAR( 20), ' +
               '@cLoadKey       NVARCHAR( 10), ' +
               '@cPickSlipNo    NVARCHAR( 10), ' +
               '@nErrNo         INT           OUTPUT, ' +
               '@cErrMsg        NVARCHAR( 20) OUTPUT, ' + 
               '@cID            NVARCHAR( 18), ' + 
               '@cTaskDetailKey NVARCHAR( 10), ' + 
               '@tExtValidate   VARIABLETABLE READONLY'
            
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate
            
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_4_Fail
            END
         END
      END


      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, @cOption,         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   

            IF @nErrNo <> 0
               GOTO Step_4_Fail  
         END
      END

      -- Reset prev screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''
      SET @cID = ''
      SET @cTaskDetailKey = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cID
      SET @cOutField07 = @cTaskDetailKey

      -- Enable disable field
      IF @nFunc in ( 850, 851) SET @cFieldAttr01 = '' ELSE SET @cFieldAttr01 = 'O' --RefNo
      IF @nFunc in ( 850, 852) SET @cFieldAttr02 = '' ELSE SET @cFieldAttr02 = 'O' --PickSlipNo
      IF @nFunc in ( 850, 853) SET @cFieldAttr03 = '' ELSE SET @cFieldAttr03 = 'O' --LoadKey
      IF @nFunc in ( 850, 854) SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O' --OrderKey
      IF @nFunc in ( 850, 855) SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O' --DropID
      IF @nFunc in ( 850, 844) SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O' --ID
      IF @nFunc in ( 850, 906) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O' --TaskDetailKey

      -- Go to first screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
      GOTO Step_99
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      IF rdt.rdtGetConfig (@nFunc, 'PPAShowSummary', @cStorer) = '1'
      BEGIN
         SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorer, @cFacility, @cPUOM,
            @nCSKU = @nCSKU OUTPUT,
            @nCQTY = @nCQTY OUTPUT,
            @nPSKU = @nPSKU OUTPUT,
            @nPQTY = @nPQTY OUTPUT

         SET @cSKUStat = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
         SET @cQTYStat = CAST( @nCQTY AS NVARCHAR( 10)) + '/' + CAST( @nPQTY AS NVARCHAR( 10))
      END
      ELSE
      BEGIN
         SET @cSKUStat = ''
         SET @cQTYStat = ''
      END

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKUStat
      SET @cOutField07 = @cQTYStat
      SET @cOutField08 = '' -- @cExtendedInfo
      SET @cOutField09 = @cID
      SET @cOutField10 = @cTaskDetailKey

      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField08 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_4_Fail:
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 818. Print pack list
   PRINT PACKING LIST
   1 = YES
   2 = NO
   OPTION (field01)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01 -- Option

      -- Check option blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 60883
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- OptionRequired
         GOTO Step_5_Fail
      END

      -- Check option valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 60884
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid Option
         GOTO Step_5_Fail
      END

      -- Prompt print packing list
      IF @cPPAPrintPackListSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPPAPrintPackListSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPPAPrintPackListSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cOption, @cType, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cRefNo          NVARCHAR( 10), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLoadKey        NVARCHAR( 10), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cType           NVARCHAR( 10), ' +
               '@nErrNo          INT           OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' + 
               '@cID             NVARCHAR( 18), ' + 
               '@cTaskDetailKey        NVARCHAR( 10)  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cOption, 'PRINT',
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey

            IF @nErrNo <> 0
               GOTO Step_5_Fail
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, @cOption,         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Reset prev screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''
      SET @cID = ''
      SET @cTaskDetailKey = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cID
      SET @cOutField07 = @cTaskDetailKey

      -- Enable disable field
      IF @nFunc in ( 850, 851) SET @cFieldAttr01 = '' ELSE SET @cFieldAttr01 = 'O' --RefNo
      IF @nFunc in ( 850, 852) SET @cFieldAttr02 = '' ELSE SET @cFieldAttr02 = 'O' --PickSlipNo
      IF @nFunc in ( 850, 853) SET @cFieldAttr03 = '' ELSE SET @cFieldAttr03 = 'O' --LoadKey
      IF @nFunc in ( 850, 854) SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O' --OrderKey
      IF @nFunc in ( 850, 855) SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O' --DropID
      IF @nFunc in ( 850, 844) SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O' --ID
      IF @nFunc in ( 850, 906) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O' --TaskDetailKey

      -- Go to first screen
      SET @nScn = @nScn - 4
      SET @nStep = @nStep - 4
      GOTO Step_99
   END

   IF @nInputKey = 0 -- Esc OR No
   BEGIN
      IF rdt.rdtGetConfig (@nFunc, 'PPAShowSummary', @cStorer) = '1'
      BEGIN
         SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorer, @cFacility, @cPUOM,
            @nCSKU = @nCSKU OUTPUT,
            @nCQTY = @nCQTY OUTPUT,
            @nPSKU = @nPSKU OUTPUT,
            @nPQTY = @nPQTY OUTPUT

         SET @cSKUStat = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
         SET @cQTYStat = CAST( @nCQTY AS NVARCHAR( 10)) + '/' + CAST( @nPQTY AS NVARCHAR( 10))
      END
      ELSE
      BEGIN
         SET @cSKUStat = ''
         SET @cQTYStat = ''
      END

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKUStat
      SET @cOutField07 = @cQTYStat
      SET @cOutField08 = '' -- @cExtendedInfo
      SET @cOutField09 = @cID
      SET @cOutField10 = @cTaskDetailKey

      -- Go to prev screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField08 = @cExtendedInfo
         END
      END
   END
   GOTO Quit

   Step_5_Fail:
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2    (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMultiSKUBarcode,
         @cStorer,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END
   END

   SET @cPUOM_Desc =''
   SET @nPUOM_Div = ''

   --Get SKU Description, UOMQTY
   SELECT
      @cSKUDesc = SKU.Descr,
      @cStyle = SKU.Style,
      @cColor = SKU.Color,
      @cSize = SKU.Size,
      @cPackQTYIndicator = SKU.PackQTYIndicator,
      @cPrePackIndicator = SKU.PrePackIndicator,
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
      @nPUOM_Div = CAST(
         CASE @cPUOM
            WHEN '2' THEN Pack.CaseCNT
            WHEN '3' THEN Pack.InnerPack
            WHEN '6' THEN Pack.QTY
            WHEN '1' THEN Pack.Pallet
            WHEN '4' THEN Pack.OtherUnit1
            WHEN '5' THEN Pack.OtherUnit2
         END AS INT)
   FROM dbo.SKU SKU WITH (NOLOCK)
      INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @cStorer
      AND SKU.SKU = @cSKU

   SET @nQTY_PPA  = 0    
   SET @nQTY_CHK  = 0    
   SET @nMQTY_CHK = 0    
   SET @nQTY_PPA  = 0    
   SET @nPQTY_PPA = 0    
   SET @nMQTY_PPA = 0    

   -- Convert QTY
   IF @cConvertQTYSP <> '' AND EXISTS( SELECT TOP 1 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
   BEGIN
      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = 0
         SET @nPQTY_CHK = 0
         SET @nPQTY_PPA = 0
         SET @nMQTY_CHK = @nQTY_CHK
         SET @nMQTY_PPA = @nQTY_PPA
         SET @cFieldAttr09 = 'O' -- @nPQTY
         IF @cDisableQTYField <> '1'
            EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY

         SET @nMQTY_PPA = @nQTY_PPA
         SET @nMQTY_CHK = @nQTY_CHK

         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nMQTY_CHK OUTPUT
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nMQTY_PPA OUTPUT
      END
      ELSE
      BEGIN
         SET @nPQTY = 0
         SET @nMQTY = 0
         SET @nPQTY_CHK = @nQTY_CHK / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_CHK = @nQTY_CHK % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_PPA = @nQTY_PPA / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_PPA = @nQTY_PPA % @nPUOM_Div -- Calc the remaining in master unit
         IF @cDisableQTYField <> '1'
         BEGIN
            SET @cFieldAttr09 = '' -- @nPQTY
            EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
         END
      END
   END
   ELSE
   BEGIN
      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = 0
         SET @nPQTY_CHK = 0
         SET @nPQTY_PPA = 0
         SET @nMQTY_CHK = @nQTY_CHK
         SET @nMQTY_PPA = @nQTY_PPA
         SET @cFieldAttr09 = 'O' -- @nPQTY
         IF @cDisableQTYField <> '1'
            EXEC rdt.rdtSetFocusField @nMobile, 10 -- MQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = 0
         SET @nMQTY = 0
         SET @nPQTY_CHK = @nQTY_CHK / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_CHK = @nQTY_CHK % @nPUOM_Div -- Calc the remaining in master unit
         SET @nPQTY_PPA = @nQTY_PPA / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_PPA = @nQTY_PPA % @nPUOM_Div -- Calc the remaining in master unit
         IF @cDisableQTYField <> '1'
         BEGIN
            SET @cFieldAttr09 = '' -- @nPQTY
            EXEC rdt.rdtSetFocusField @nMobile, 9 -- PQTY
         END
      END
   END
   
      -- Display SKU info
   SET @cOutField01 = @cSKU
   SET @cOutField02 = @cSKU
   SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)
   SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20)
   SET @cOutField05 = @cStyle
   SET @cOutField06 = @cColor
   SET @cOutField07 = @cSize
   SET @cOutField08 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6)) + ' ' + @cPUOM_Desc + ' ' + @cMUOM_Desc
   SET @cOutField09 = CASE WHEN @cPPADefaultPQTY <> '' THEN @cPPADefaultPQTY ELSE '' END --@nPUOM
   SET @cOutField10 = CASE WHEN @cTaskDefaultQty = '1' THEN @cTaskQty ELSE @cPPADefaultQTY END --@nMUOM
   SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_CHK AS NVARCHAR(5)) END
   SET @cOutField12 = CAST( @nMQTY_CHK AS NVARCHAR(6)) --(yeekung07)
   SET @cOutField13 = CASE WHEN ISNULL(@cPUOM_Desc,'') = '' THEN '' ELSE CAST( @nPQTY_PPA AS NVARCHAR(5)) END
   SET @cOutField14 = CAST( @nMQTY_PPA AS NVARCHAR(6)) --(yeekung07)
   SET @cOutField15 = '' -- @cExtendedInfo
   SET @cOutField16 = @cPackQTYIndicator

   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep - 3

END
GOTO Quit

/********************************************************************************
Scn = 819. Data Capture
   PickSlipNo  (field01)
   Case ID     (field02, Input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
   	SET @cCaptureDataInput = @cInField03  --(cc02)
      
      INSERT INTO @tDataCapture (Variable, Value) VALUES 
         ('@cRefNo',       @cRefNo), 
         ('@cPickSlipNo',  @cPickSlipNo), 
         ('@cLoadKey',     @cLoadKey), 
         ('@cOrderKey',    @cOrderKey), 
         ('@cDropID',      @cDropID), 
         ('@cID',          @cID), 
         ('@cTaskDetailKey',  @cTaskDetailKey), 
         ('@cSKU',         @cSKU), 
         ('@cBarCode',     @cInField03), 
         ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
         ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
         ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
         ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
         ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
         ('@cOption',      @cOption)

      EXEC rdt.rdt_PPAVerifyDataCapture @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, 'UPDATE', @tDataCapture,
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
         @cCaptureData OUTPUT,@nErrNo      OUTPUT,  @cErrMsg      OUTPUT
         
      IF @nErrNo <> 0
         GOTO Quit

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step_7_Upd -- For rollback or commit only our own transaction
      
      -- Insert PPA
      IF @nRowRef IS NULL AND @cSKU <> '' --(cc02)
      BEGIN
         INSERT INTO rdt.rdtPPA WITH (ROWLOCK) 
         (Refkey, PickSlipno, LoadKey, Store, StorerKey, Sku, Descr, PQTY, CQTY, Status, 
         UserName, AddDate, NoOfCheck, UOMQty, OrderKey, DropID, ID, TaskDetailKey)
         VALUES 
         (@cRefNo, @cPickSlipNo, @cLoadKey, '', @cStorer, @cSKU, @cSKUDesc, @nQTY_PPA, @nQTY, '0', 
         @cUserName, GETDATE(), 1, 1, @cOrderKey, @cDropID, @cID, @cTaskDetailKey)

         IF @@ERROR <> 0
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nErrNo = 60878
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail INS PPA
            GOTO Step_7_RollBackTran
         END
      END
      ELSE IF @nRowRef IS NOT NULL --(cc02)
      BEGIN
         -- Update PPA
         UPDATE rdt.rdtPPA WITH (ROWLOCK) SET
            CQTY = CQTY + @nQTY,
            NoOfCheck = NoOfCheck + 1
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nPQTY = 0
            SET @nMQTY = 0
            SET @nErrNo = 60879
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Fail UPD PPA
            GOTO Step_7_RollBackTran
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, @cOption,         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   

            IF @nErrNo <> 0
            BEGIN
               SET @nPQTY = 0
               SET @nMQTY = 0
               GOTO Step_7_RollBackTran
            END
         END
      END

      GOTO Step_7_Commit

      Step_7_RollBackTran:
         ROLLBACK TRAN Step_7_Upd

      Step_7_Commit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      -- Top up check QTY
      SET @nPQTY_CHK = @nPQTY_CHK + @nPQTY
      SET @nMQTY_CHK = @nMQTY_CHK + @nMQTY

      -- Display QTY info
      SET @cSKU = ''
      SET @cOutField01 = '' --@cSKU
      SET @cOutField04 = '' 
      SET @cOutField09 = CASE WHEN @cPPADefaultPQTY <> '' THEN @cPPADefaultPQTY ELSE '' END--@nPQTY
      SET @cOutField10 = CASE WHEN @cTaskDefaultQty = '1' THEN @cTaskQty ELSE @cPPADefaultQTY END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc = '' THEN '' ELSE CAST( @nPQTY_CHK AS NVARCHAR(5)) END
      SET @cOutField12 = CAST( @nMQTY_CHK AS NVARCHAR(6)) --(yeekung07)
      SET @cOutField15 = '' -- @cExtendedInfo
      EXEC rdt.rdtSetFocusField @nMobile, 1 --SKU

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Go back SKU QTY screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @nFromStep = 2 -- Statistic
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cRefNo
         SET @cOutField02 = @cPickSlipNo
         SET @cOutField03 = @cLoadKey
         SET @cOutField04 = @cOrderKey
         SET @cOutField05 = @cDropID
         SET @cOutField06 = @cSKUStat
         SET @cOutField07 = @cQTYStat
         SET @cOutField08 = '' -- @cExtendedInfo
         SET @cOutField09 = @cID
         SET @cOutField10 = @cTaskDetailKey
         
         SET @nScn = @nFromScn
         SET @nStep = @nFromStep
      END
      ELSE
      BEGIN
         -- Set next screen var
         SET @cSKU = ''
         SET @cPackQTYIndicator = ''
         SET @cPrePackIndicator = ''

         -- Disable QTY field
         IF @cDisableQTYField = '1'
         BEGIN
            SET @cFieldAttr09 = 'O' -- PQTY
            SET @cFieldAttr10 = 'O' -- MQTY
         END

         IF @cConvertQTYSP <> '' AND EXISTS( SELECT TOP 1 1 FROM dbo.sysobjects WHERE name = @cConvertQTYSP AND type = 'P')
            SET @cFieldAttr09 = 'O' -- @nPQTY

         SET @cOutField01 = '' --@cSKU
         SET @cOutField02 = '' --@cSKU
         SET @cOutField03 = '' --SUBSTRING( @cSKUDesc, 1, 20)
         SET @cOutField04 = '' --SUBSTRING( @cSKUDesc, 21, 40)
         SET @cOutField05 = '' --@cStyle
         SET @cOutField06 = '' --@cColor
         SET @cOutField07 = '' --@cSize
         SET @cOutField08 = '' --@nPUOM_Div, @cPUOM_Desc, @cMUOM_Desc
         SET @cOutField09 = CASE WHEN @cPPADefaultPQTY <> '' THEN @cPPADefaultPQTY ELSE '' END--@nPUOM
         SET @cOutField10 = CASE WHEN @cTaskDefaultQty = '1' THEN @cTaskQty ELSE @cPPADefaultQTY END --@nMUOM
         SET @cOutField11 = '' --@nPQTY_CHK
         SET @cOutField12 = '' --@nMQTY_CHK
         SET @cOutField13 = '' --@nPQTY_PPA
         SET @cOutField14 = '' --@nMQTY_PPA
         SET @cOutField15 = '' --@cExtendedInfo
         SET @cOutField16 = '' --@cPackQTYIndicator
         EXEC rdt.rdtSetFocusField @nMobile, 1 --SKU

         -- Go to next screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit

/********************************************************************************    
Scn = 5980. Capture pack info    
   Carton Type (field01, input)    
   Cube        (field02, input)    
   Weight      (field03, input)    
********************************************************************************/    
Step_8:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cChkCartonType NVARCHAR( 10)    
        
      -- Screen mapping    
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END    
      SET @cCube           = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END    
      SET @cWeight         = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END    
      
      -- Carton type    
      IF @cFieldAttr01 = ''    
      BEGIN    
         -- Check blank    
         IF @cChkCartonType = ''    
         BEGIN    
            SET @nErrNo = 60894    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Quit    
         END    
             
         -- Get default cube    
         DECLARE @nDefaultCube FLOAT    
         SELECT @nDefaultCube = [Cube]    
         FROM Cartonization WITH (NOLOCK)    
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)    
         WHERE Storer.StorerKey = @cStorer   
            AND Cartonization.CartonType = @cChkCartonType    
    
         -- Check if valid    
         IF @@ROWCOUNT = 0    
         BEGIN    
            SET @nErrNo = 60895    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Quit    
         END    
    
         -- Different carton type scanned    
         IF @cChkCartonType <> @cCartonType    
         BEGIN    
            SET @cCartonType = @cChkCartonType    
            SET @cCube = rdt.rdtFormatFloat( @nDefaultCube)    
            --SET @cWeight = ''    
    
            SET @cOutField01 = @cCartonType    
            SET @cOutField02 = @cCube              
            SET @cOutField03 = @cWeight            
         END    
      END    
      
      -- Cube    
      IF @cFieldAttr02 = ''    
      BEGIN    
         -- Check blank    
         IF @cCube = ''    
         BEGIN    
            SET @nErrNo = 60899    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Quit    
         END    
    
         -- Check cube valid    
         IF @cAllowCubeZero = '1'    
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 20)    
         ELSE    
            SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)    
    
         IF @nErrNo = 0    
         BEGIN    
            SET @nErrNo = 60900    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            SET @cOutField02 = ''    
        GOTO QUIT    
         END    
         SET @nErrNo = 0    
         SET @cOutField02 = @cCube    
      END 
    
      -- Weight    
      IF @cFieldAttr03 = ''    
      BEGIN    
         -- Check blank    
         IF @cWeight = ''    
         BEGIN    
            SET @nErrNo = 60896    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Quit    
         END    
           
         -- Check format    --(cc04)  
         IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'Weight', @cWeight) = 0      
         BEGIN      
            SET @nErrNo = 60897     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format      
            EXEC rdt.rdtSetFocusField @nMobile, 3      
            GOTO Quit      
         END     
    
         ---- Check weight valid    
         --IF @cAllowWeightZero = '1'    
         --   SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 20)    
         --ELSE    
         --   SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)    
    
         --IF @nErrNo = 0    
         --BEGIN    
         --   SET @nErrNo = 60898    
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight    
         --   EXEC rdt.rdtSetFocusField @nMobile, 3    
         --   SET @cOutField03 = ''    
         --   GOTO QUIT    
         --END    
         --SET @nErrNo = 0    
         SET @cOutField03 = @cWeight    
      END    
    
      -- Default weight    
      --ELSE IF @cDefaultWeight IN ('2', '3')    
      --BEGIN    
      --   -- Weight (SKU only)    
      --   DECLARE @nWeight FLOAT    
      --   SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0)     
      --   FROM dbo.PackDetail PD WITH (NOLOCK)     
      --      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)    
      --   WHERE PD.PickSlipNo = @cPickSlipNo    
      --      AND PD.CartonNo = @nCartonNo    
    
      --   -- Weight (SKU + carton)    
      --   IF @cDefaultWeight = '3'    
      --   BEGIN             
      --      -- Get carton type info    
      --      DECLARE @nCartonWeight FLOAT    
      --      SELECT @nCartonWeight = CartonWeight    
      --      FROM Cartonization C WITH (NOLOCK)    
      --         JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)    
      --      WHERE S.StorerKey = @cStorer    
      --         AND C.CartonType = @cCartonType    
                   
      --      SET @nWeight = @nWeight + @nCartonWeight    
      --   END    
      --   SET @cWeight = rdt.rdtFormatFloat( @nWeight)    
      --END    
    
         
    
      IF @cExtendedValidateSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
            BEGIN
            INSERT INTO @tExtValidate (Variable, Value) VALUES 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nQTY_PPA',     CAST( @nQTY_PPA AS NVARCHAR( 10))), 
               ('@nQTY_CHK',     CAST( @nQTY_CHK AS NVARCHAR( 10))), 
               ('@nRowRef',      CAST( @nRowRef AS NVARCHAR( 10))), 
               ('@nInputKey',    CAST( @nInputKey AS NVARCHAR( 1))), 
               ('@cUserName',    @cUserName)

               SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, ' + 
                  ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate '
               SET @cSQLParam =
                  '@nMobile        INT, ' +
                  '@nFunc          INT, ' +
                  '@cLangCode      NVARCHAR( 3),  ' +
                  '@nStep          INT,           ' +
                  '@cStorer        NVARCHAR( 15), ' +
                  '@cFacility      NVARCHAR( 5),  ' +
                  '@cRefNo         NVARCHAR( 10), ' +
                  '@cOrderKey      NVARCHAR( 10), ' +
                  '@cDropID        NVARCHAR( 20), ' +
                  '@cLoadKey       NVARCHAR( 10), ' +
                  '@cPickSlipNo    NVARCHAR( 10), ' +
                  '@nErrNo         INT           OUTPUT, ' +
                  '@cErrMsg        NVARCHAR( 20) OUTPUT, ' + 
                  '@cID            NVARCHAR( 18), ' +
                  '@cTaskDetailKey NVARCHAR( 10), ' + 
                  '@tExtValidate   VariableTable READONLY ' 
            
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorer, @cFacility, @cRefNo, @cOrderKey, @cDropID, @cLoadKey, @cPickSlipNo, 
                  @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey, @tExtValidate 
            
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Step_1_Fail
               END
            END
         END   
    
      DECLARE @fCube FLOAT    
      DECLARE @fWeight FLOAT    
      DECLARE @fCartonQty FLOAT --(cc02)    
      SET @fCube = CAST( @cCube AS FLOAT)    
      SET @fWeight = CAST( @cWeight AS FLOAT)    
             
      SELECT TOP 1 
         @fCartonQty = SUM(qty),
         @nCartonNo = CartonNo,
         @cPickSlipNo = PickSlipNo 
      FROM packDetail WITH (NOLOCK) 
      WHERE storerKey = @cStorer 
      AND dropID = @cDropID
      GROUP BY CartonNo, PickSlipNo
    
      -- PackInfo    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)    
      BEGIN    
         INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType )    
         VALUES (@cPickSlipNo, @nCartonNo, @fCartonQty, @fWeight, @fCube, @cCartonType )      
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 179001    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail    
            GOTO Quit    
         END    
      END    
      ELSE    
      BEGIN    
         UPDATE dbo.PackInfo SET    
            CartonType = @cCartonType,    
            Weight = @fWeight,    
            [Cube] = @fCube
         WHERE PickSlipNo = @cPickSlipNo    
            AND CartonNo = @nCartonNo    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 179002    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail    
            GOTO Quit    
         END    
      END    
    
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, ' +       
               ' @cSKU, @nQty, @cOption, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT'        
            SET @cSQLParam =      
               '@nMobile         INT,       ' +      
               '@nFunc           INT,       ' +      
               '@cLangCode       NVARCHAR( 3),  ' +      
               '@nStep           INT,           ' +      
               '@nInputKey       INT,           ' +      
               '@cStorerKey      NVARCHAR( 15), ' +      
               '@cRefNo          NVARCHAR( 10), ' +      
               '@cPickSlipNo     NVARCHAR( 10), ' +      
               '@cLoadKey        NVARCHAR( 10), ' +      
               '@cOrderKey       NVARCHAR( 10), ' +      
               '@cDropID         NVARCHAR( 20), ' +      
               '@cSKU            NVARCHAR( 20), ' +      
               '@nQty            INT,           ' +      
               '@cOption         NVARCHAR( 1),  ' +      
               '@nErrNo          INT           OUTPUT, ' +      
               '@cErrMsg         NVARCHAR( 20) OUTPUT, ' +      
               '@cID             NVARCHAR( 18), ' +       
               '@cTaskDetailKey  NVARCHAR( 10), ' +        
               '@cReasonCode     NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQty, '',         
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cID, @cTaskDetailKey,@cReasonCode OUTPUT   

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
    
      -- Prompt print packing list
      IF @cPPAPrintPackListSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cPPAPrintPackListSP AND type = 'P')
         BEGIN
            SET @cPrintPackList = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cPPAPrintPackListSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cOption, @cType, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT, @cPrintPackList OUTPUT, @cID, @cTaskDetailKey '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cRefNo          NVARCHAR( 10), ' +
               '@cPickSlipNo     NVARCHAR( 10), ' +
               '@cLoadKey        NVARCHAR( 10), ' +
               '@cOrderKey       NVARCHAR( 10), ' +
               '@cDropID         NVARCHAR( 20), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cOption         NVARCHAR( 1),  ' +
               '@cType           NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20)OUTPUT, ' +
               '@cPrintPackList  NVARCHAR( 1) OUTPUT, ' + 
               '@cID             NVARCHAR( 18), ' + 
               '@cTaskDetailKey  NVARCHAR( 10)  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cSKU, @nQTY, @cOption, 'CHECK',
               @nErrNo OUTPUT, @cErrMsg OUTPUT, @cPrintPackList OUTPUT, @cID, @cTaskDetailKey

            IF @cPrintPackList = '1'
            BEGIN
               -- Go to print pack list screen
               SET @cOutField01 = '' -- Option
               SET @nScn = 818
               SET @nStep = @nStep - 3

               GOTO Quit
            END
         END
      END    
      
      -- Reset prev screen var
      SET @cRefNo = ''
      SET @cPickSlipNo = ''
      SET @cLoadKey = ''
      SET @cOrderKey = ''
      SET @cDropID = ''
      SET @cID = ''
      SET @cTaskDetailKey = ''

      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cID
      SET @cOutField07 = @cTaskDetailKey

      -- Enable disable field
      IF @nFunc in ( 850, 851) SET @cFieldAttr01 = '' ELSE SET @cFieldAttr01 = 'O' --RefNo
      IF @nFunc in ( 850, 852) SET @cFieldAttr02 = '' ELSE SET @cFieldAttr02 = 'O' --PickSlipNo
      IF @nFunc in ( 850, 853) SET @cFieldAttr03 = '' ELSE SET @cFieldAttr03 = 'O' --LoadKey
      IF @nFunc in ( 850, 854) SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O' --OrderKey
      IF @nFunc in ( 850, 855) SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O' --DropID
      IF @nFunc in ( 850, 844) SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O' --ID
      IF @nFunc in ( 850, 906) SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O' --TaskDetailKey

      -- Go to st 1
      SET @nScn = 814
      SET @nStep = @nStep - 7
      GOTO Step_99
   END
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF rdt.rdtGetConfig (@nFunc, 'PPAShowSummary', @cStorer) = '1'
      BEGIN
         SELECT @nCSKU = 0, @nCQTY = 0, @nPSKU = 0, @nPQTY = 0
         EXECUTE rdt.rdt_PostPickAudit_GetStat @nMobile, @nFunc, @cRefNo, @cPickSlipNo, @cLoadKey, @cOrderKey, @cDropID, @cID, @cTaskDetailKey, @cStorer, @cFacility, @cPUOM,
            @nCSKU = @nCSKU OUTPUT,
            @nCQTY = @nCQTY OUTPUT,
            @nPSKU = @nPSKU OUTPUT,
            @nPQTY = @nPQTY OUTPUT

         SET @cSKUStat = CAST( @nCSKU AS NVARCHAR( 10)) + '/' + CAST( @nPSKU AS NVARCHAR( 10))
         SET @cQTYStat = CAST( @nCQTY AS NVARCHAR( 10)) + '/' + CAST( @nPQTY AS NVARCHAR( 10))
      END
      ELSE
      BEGIN
         SET @cSKUStat = ''
         SET @cQTYStat = ''
      END

      -- Prepare next screen var
      SET @cOutField01 = @cRefNo
      SET @cOutField02 = @cPickSlipNo
      SET @cOutField03 = @cLoadKey
      SET @cOutField04 = @cOrderKey
      SET @cOutField05 = @cDropID
      SET @cOutField06 = @cSKUStat
      SET @cOutField07 = @cQTYStat
      SET @cOutField08 = '' -- @cExtendedInfo
      SET @cOutField09 = @cID
      SET @cOutField10 = @cTaskDetailKey

      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            INSERT INTO @tExtInfo (Variable, Value) VALUES 
               ('@cRefNo',       @cRefNo), 
               ('@cPickSlipNo',  @cPickSlipNo), 
               ('@cLoadKey',     @cLoadKey), 
               ('@cOrderKey',    @cOrderKey), 
               ('@cDropID',      @cDropID), 
               ('@cID',          @cID), 
               ('@cTaskDetailKey',  @cTaskDetailKey), 
               ('@cSKU',         @cSKU), 
               ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))), 
               ('@nCSKU',        CAST( @nCSKU AS NVARCHAR( 10))), 
               ('@nCQTY',        CAST( @nCQTY AS NVARCHAR( 10))), 
               ('@nPSKU',        CAST( @nPSKU AS NVARCHAR( 10))), 
               ('@nPQTY',        CAST( @nPQTY AS NVARCHAR( 10))), 
               ('@cOption',      @cOption)
            
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtInfo, ' +
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @tExtInfo       VariableTable READONLY, ' + 
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT, ' + 
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 4, @nStep, @nInputKey, @cFacility, @cStorer, @tExtInfo, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         
            SET @cOutField08 = @cExtendedInfo
         END
      END
   END 
END    
GOTO Quit    

Step_99:
BEGIN
   
   IF @cExtendedScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES 
            ('@cRefNo',       @cRefNo), 
            ('@cPickSlipNo',  @cPickSlipNo), 
            ('@cLoadKey',     @cLoadKey), 
            ('@cOrderKey',    @cOrderKey), 
            ('@cDropID',      @cDropID), 
            ('@cID',          @cID), 
            ('@cSKU',         @cSKU), 
            ('@cPUOM',        @cPUOM),
            ('@nQTY',         CAST( @nQTY AS NVARCHAR( 10))),
            ('@nScn',         CAST( @nScn AS NVARCHAR( 10)))
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScnSP,  --855ExtScn01
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_99_Fail

         IF (@cExtendedScnSP = 'rdt_855ExtScn01'
            AND @nStep = 2)
         BEGIN
            SET @cDropId = @cUDF01
            SET @nCSKU = CAST(@cUDF02 AS INT)
            SET @nPSKU = CAST(@cUDF03 AS INT)
            SET @nPQTY = CAST(@cUDF04 AS INT)
            SET @nCQTY = CAST(@cUDF05 AS INT)
            SET @cSKUStat = @cUDF06
            SET @cQTYStat = @cUDF07
            SET @cExtendedInfo = @cUDF08
            SET @cPPACartonIDByPackDetailLabelNo = @cUDF09
            SET @cPPACartonIDByPickDetailCaseID = @cUDF10
         END

         IF (@cExtendedScnSP = 'rdt_855ExtScn01'
            AND @nStep = 0)
         BEGIN
            SET @nFunc = @nMenu
         END
         IF (@cExtendedScnSP = 'rdt_855ExtScn01'
            AND @nStep = 99)
         BEGIN
            SET @nAction = CAST(@cUDF09 AS INT)
         END

         GOTO Quit
      END
   END

   Step_99_Fail:
      GOTO Quit
END

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

      StorerKey    = @cStorer,
      Facility     = @cFacility,
      Printer      = @cPrinter,
      Printer_Paper= @cPrinterPpr,  --(yeekung01) 
      -- UserName     = @cUserName,

      V_UOM        = @cPUOM,
      V_SKU        = @cSKU,
      V_LoadKey    = @cLoadKey,
      V_PickSlipNo = @cPickSlipNo,
      V_OrderKey   = @cOrderKey,
      V_ID         = @cID, 
      V_FromScn    = @nFromScn, 
      V_FromStep      = @nFromStep, 
      V_TaskDetailKey = @cTaskDetailKey, 
      
      V_Integer1   = @nTol, 

      V_String1  = @cRefNo,
      V_String2  = @cDropID,
      V_String3  = @cExternOrderKey,
      V_String4  = @cZone,
      V_String5  = @cCaptureDataSP,
      V_String6  = @cTaskQty, 
      V_String7  = @cTaskDefaultQty, 
      V_String8  = @cPUOM_Desc, 
      V_String9  = @cPPADefaultPQTY,

      V_String10 = @cPackQTYIndicator,
      V_String11 = @cPrePackIndicator,
      V_String12 = @cPPACartonIDByPackDetailDropID,
      V_String13 = @cPPAAllowSKUNotInPickList,
      V_String14 = @cPPADefaultQTY,
      V_String15 = @cSkipChkPSlipMustScanIn,
      V_String16 = @cPPAAllowQTYExceedTolerance,
      V_String17 = @cConvertQTYSP,
      V_String18 = @cExtendedInfoSP,
      V_String19 = @cPPACartonIDByPackDetailLabelNo,
      V_String20 = @cExtendedUpdateSP,
      V_String21 = @cPPAPromptDiscrepancy,
      V_String22 = @cExtendedValidateSP, -- (ChewKP01)
      V_String23 = @cDisableQTYField, -- (james05)
      V_String24 = @cSkipChkPSlipMustScanOut, -- (james05)
      V_String25 = @cPPABlindCount,
      V_String26 = @cPPAPrintPackListSP,
      V_String27 = @cDecodeSP,
      V_String28 = @cPickConfirmStatus,
      V_String29 = @cPPACartonIDByPickDetailCaseID,   -- (james06)
      V_String30 = @cPreCartonization,
      V_String31 = @cMultiSKUBarcode,
      V_String32 = @cShipLabel,  -- (yeekung01)
      V_String33 = @cShippingContentLabel,  -- (yeekung01)
      --V_String34 = @cPackList,  -- (yeekung01)
   	V_String35 = @cUPC, --(yeekung02) 
   	V_String36 = @cCaptureDataInput,    --(cc02)
   	V_String37 = @cExtendedUOMSP,       --(cc02)
      V_String38 = @cCaptureDataColName,  --(cc02) 
      V_String39 = @cCapturePackInfo,     --(cc02)
      V_String40 = @cCartonType,          --(cc02)     
      V_String41 = @cCube,                --(cc02)      
      V_String42 = @cWeight,              --(cc02) 
      V_String43 = @cAllowWeightZero,     --(cc02) 
      V_String44 = @cAllowCubeZero,       --(cc02)
      V_String45 = @cReasonCode,        
      V_String46 = @cCaptureReasonCode,   
      v_String47 = @cExtendedRefNoSP,
      V_String48 = @cMultiColScan,
      V_String49 = @cExtendedScnSP,

      V_Integer2 = @nAction,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01 = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02 = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03 = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04 = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05 = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06 = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07 = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08 = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09 = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10 = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11 = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12 = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13 = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14 = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15 = @cFieldAttr15,
      I_Field16 = @cInField16,  O_Field16 = @cOutField16,   FieldAttr16 = @cFieldAttr16,
      I_Field17 = @cInField17,  O_Field17 = @cOutField17,   FieldAttr17 = @cFieldAttr17,
      I_Field18 = @cInField18,  O_Field18 = @cOutField18,   FieldAttr18 = @cFieldAttr18,
      I_Field19 = @cInField19,  O_Field19 = @cOutField19,   FieldAttr19 = @cFieldAttr19,
      I_Field20 = @cInField20,  O_Field20 = @cOutField20,   FieldAttr20 = @cFieldAttr20

   WHERE Mobile = @nMobile
END

GO