SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdtfnc_BOMCreation                                     */  
/* Copyright      : IDS                                                    */  
/*                                                                         */  
/* Purpose: Build BOM when ComponentSKU scanned in                         */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date         Rev  Author     Purposes                                   */  
/* 2007-08-01   1.0  Vicky      Created                                    */  
/* 2007-09-16   1.1  Vicky      Change of Parameter sending to PrintJob    */  
/* 2007-09-19   1.2  Vicky      Add to print Bundle if no other Master     */  
/*                              setup                                      */  
/* 2007-09-20   1.3  Vicky      Add Error Msg when different Style is      */  
/*                              scanned                                    */  
/* 2007-09-24   1.4  Vicky      Pass in Style when matching BOM as style   */  
/*                              will not always be 15 chars                */  
/* 2007-10-12   1.5  Vicky      Take out checking on Storerkey when        */  
/*                              getting the Suffix   (Vicky01)             */  
/* 2007-10-13   1.6  Vicky      Check whether ComponentSKU scanned in      */  
/*                              is ParentSKU (Vicky01)                     */  
/* 2007-10-02   1.7  Vicky      SOS#88056 - Enhancement to cater Same      */  
/*                              BOM configuration but different Packkey    */  
/*                              configuration                              */  
/* 2007-11-20   1.8  Vicky      Add in another MatchSKU OUTPUT value for   */  
/*                              rdt_BOM_Packkey_Matching                   */  
/* 2008-11-03   1.9  Vicky      Remove XML part of code that is used to    */  
/*                              make field invisible (Vicky02)             */  
/* 2009-03-31   1.10 Vicky      SOS#133035- Get 10 Chars from Left from    */  
/*                              Style when create ParentSKU (Vicky03)      */  
/* 2009-04-01   1.11 LarryAu    Bug Fix on getting running number to       */  
/*                              assign to ParentSKU (Larry01)              */  
/* 2009-06-03   1.12 Vicky      Add Username when filter rdtBOMCreationLog */   
/*                              (Vicky04)                                  */  
/* 2009-07-08   1.13 Vicky      SOS#140937 - Check ParentSKU matching if   */  
/*                              ParentSKU being entered in Screen 1        */  
/*                              (Vicky05)                                  */  
/* 2009-10-23   1.14 Vicky      SOS#151310 - New screen to capture Length, */  
/*                              Width, Height and Weight (Vicky06)         */  
/* 2009-10-27   1.15 Vicky      Delete outstanding rdtBOMCreationLog       */  
/*                              record for User when login to module       */  
/*                              (Vicky07)                                  */  
/* 2010-05-21   1.16 Vicky      Fix: (Vicky08)                             */  
/*                              1. SOS#173692 - To fix issue with system   */  
/*                                 generated ParentSKU                     */  
/*                              2. Performane Tuning                       */  
/* 2010-06-08   1.17 Shong      Accept Customer BOM Label with SKU         */  
/* 2010-07-06   1.18 Ricky      Accept Customer BOM Label with Customer    */  
/*                              Sku (Ricky_1.18)                           */  
/* 2010-07-07   1.19 Ricky      Accept Customer BOM Label with Customer    */  
/*                              Sku (Ricky_1.19)                           */  
/* 2010-06-08   1.20 James      SOS175733 - Diana modification (james01)   */  
/*                              1. Skip scn 5 to 8 if config is on         */  
/*                              2. Skip length/width/height/weight scn     */  
/*                              3. Add new BOM confirmation screen         */  
/* 2010-07-30   1.21 James      Add configkey 'BOMDIMTOLERANCE' to control */  
/*                              dimension tolerance (james02)              */  
/* 2010-08-03   1.22 Vicky      Cube should be declare to Float (Vicky09)  */  
/* 2010-08-10   1.22 James      Bug Fix (james03)                          */  
/* 2010-09-04   1.23 ChewKP     Prevent ComponentSKU being created as      */  
/*                              BOMSKU aka ParentSKU (ChewKP01)            */  
/* 2011-01-10   1.24 James      SOS201407 - Bug fix (james04)              */  
/* 2011-10-20   1.25 James      SOS228361 - Limit no of label that allow   */  
/*                                          to print(james05)              */  
/* 2012-01-03   1.26 James      Fix tran count issue (james06)             */  
/* 2016-09-30   1.27 Ung        Performance tuning                         */
/* 2018-01-16   1.28 ChewKP     WMS-3767-Call rdt.rdtPrintJob (ChewKP02)   */
/* 2018-10-30   1.29 Gan        Performance tuning                         */
/***************************************************************************/  
  
CREATE PROC [RDT].[rdtfnc_BOMCreation](  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variables  
DECLARE  
   @b_success      INT,  
   @n_err          INT,  
   @c_errmsg       NVARCHAR( 250),  
   @i              INT,   
   @nTask          INT,    
   @cParentScn     NVARCHAR( 3),   
   @cOption        NVARCHAR( 1),   
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc  
  
-- RDT.RDTMobRec variables  
DECLARE  
   @nFunc          INT,  
   @nScn           INT,  
   @nStep          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nInputKey      INT,  
   @nMenu          INT,  
  
   @nPrevScn       INT,  
   @nPrevStep      INT,  
  
   @cStorerKey     NVARCHAR( 15),  
   @cUserName      NVARCHAR( 18),  
   @cFacility      NVARCHAR( 5),  
   @cPrinter       NVARCHAR( 10),  
  
--    @cParentSKU     NVARCHAR( 20),  
--    @cSysParentSKU  NVARCHAR( 20),  
   @cParentSKU     NVARCHAR( 18),  
   @cSysParentSKU  NVARCHAR( 18),  
   @cSKU           NVARCHAR( 20),  
   @cSKUDescr      NVARCHAR( 60),  
   @cUOM           NVARCHAR( 10),  
   @cQTY           NVARCHAR( 5),      
   @cSuffix        NVARCHAR( 5),   
   @cPackkey       NVARCHAR( 10),  
  
   @cOptionInner   NVARCHAR( 1),  
   @cOptionCase    NVARCHAR( 1),  
   @cOptionShipper NVARCHAR( 1),  
   @cOptionPallet  NVARCHAR( 1),  
  
   @cInnerPack     NVARCHAR( 5),  
   @cCase          NVARCHAR( 5),  
   @cShipper       NVARCHAR( 5),  
   @cPallet        NVARCHAR( 5),  
  
   @nInnerPack     INT,  
   @nCaseCnt       INT,  
   @nShipper       INT,  
   @nPallet        INT,  
  
   @cNoOfLabel     NVARCHAR( 6),  
   @cStyle         NVARCHAR( 20),  
   @cSKUFlag       NVARCHAR( 1),  
   @cResult        NVARCHAR( 1),  
   @cPrintBOMLabel NVARCHAR( 1),  
   @cPackCnt       NVARCHAR( 1),  
   @cPrevPackCnt   NVARCHAR( 1),  
   @cPrevStyle     NVARCHAR( 20),  
   @nSKUCnt        INT,  
   @nBOMSeq        INT,  
   @nPrevBOMSeq    INT,  
  
   @cMatchSKU      NVARCHAR( 20),  
   @cMatchPackkey  NVARCHAR( 10),  
   @cMatchInner    NVARCHAR( 5),  
   @cMatchCase     NVARCHAR( 5),  
   @cMatchShipper  NVARCHAR( 5),  
   @cMatchPallet   NVARCHAR( 5),  
  
   @nMatchInner    INT,  
   @nMatchCase     INT,  
   @nMatchShipper  INT,  
   @nMatchPallet   INT,  
   
   @nQtyAvail      INT,  
   @nSuffix        INT,  
   @nMatchFound    INT,  
  
   @cParentExt     NVARCHAR( 1), -- (Vicky05)  
   @c_BOMPackKey   NVARCHAR( 7), -- (Vicky05)  
  
   @nLength        Float,  -- (Vicky06)  
   @nWidth         Float,  -- (Vicky06)  
   @nHeight        Float,  -- (Vicky06)  
   @nStdGrossWgt   Float,  -- (Vicky06)  
   @nStdCube       Float,  -- (Vicky06)  
   @nCompStdGWgt   Float,  -- (Vicky06)  
   @nCompStdCube   Float,  -- (Vicky06)  
  
   @nSumBOMQTY     INT,   -- (Vicky06)  
   @nSkuCaseCnt    INT,   -- (Vicky06)  
   @cSkuPackkey    NVARCHAR(10), -- (Vicky06)   
   @cPackUOM1      NVARCHAR(10), -- (james01)   
   @cPackUOM3      NVARCHAR(10), -- (james01)   
--   @nCurStdCube    INT,      -- (james01)   
   @cBOMSKU        NVARCHAR(20), -- (james01)   
   @nSameCube      INT,      -- (james01)   
   @cBOMDIMTOLERANCE    NVARCHAR( 5),   -- (james02)  
   @nBOMDIMTOLERANCE    INT,        -- (james02)  
   @cMatchDimension     NVARCHAR(1),        -- (james02)  
   @cCheckDimension     NVARCHAR(1),        -- (james02)  
   @nCurStdCube         FLOAT,      -- (Vicky09)   
--   @nSameCube   FLOAT,      -- (Vicky09)   
   @nNoOfLabelAllowed   INT,     -- (james05)  
   @nTranCount          INT,     -- (james06)  
   @nNoOfLabel          INT,     -- (ChewKP02) 
  
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  
  
   -- (Vicky06) - Start  
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),  
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),  
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),  
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),  
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),  
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),  
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),  
   @cFieldAttr15 NVARCHAR( 1)  
   -- (Vicky06) - End  
  
-- Getting Mobile information  
SELECT  
   @nFunc            = Func,  
   @nScn             = Scn,  
   @nStep            = Step,  
   @nInputKey        = InputKey,  
   @nMenu            = Menu,  
   @cLangCode        = Lang_code,  
  
   @cStorerKey       = StorerKey,  
   @cFacility        = Facility,  
   @cUserName        = UserName,  
   @cPrinter         = Printer,  
     
   @cSKU             = V_SKU,  
   @cSKUDescr        = V_SKUDescr,  
   @cUOM             = V_UOM,  
   @cQTY             = V_QTY,  
   
   @nPrevScn         = V_FromScn,
   @nPrevStep        = V_FromStep,
   
   @nBOMSeq          = V_Integer1,
   @nPrevBOMSeq      = V_Integer2,
   @nInnerPack       = V_Integer3,
   @nCaseCnt         = V_Integer4,
   @nShipper         = V_Integer5,
   @nPallet          = V_Integer6,
   @nMatchInner      = V_Integer7,
   @nMatchCase       = V_Integer8,
   @nMatchShipper    = V_Integer9,
   @nMatchPallet     = V_Integer10,
   @nQtyAvail        = V_Integer11,
   @nMatchFound      = V_Integer12,
  
   @cParentSKU       = V_String1,  
   @cOption          = V_String2,  
  
   @cInnerPack       = V_String3,  
   @cCase            = V_String4,  
   @cShipper         = V_String5,  
   @cPallet          = V_String6,  
  
   @cOptionInner     = V_String7,  
   @cOptionCase      = V_String8,  
   @cOptionShipper   = V_String9,  
   @cOptionPallet    = V_String10,   
  
   @cNoOfLabel       = V_String11,  
   @cStyle           = V_String12,  
  -- @nBOMSeq          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END,  
  -- @nPrevBOMSeq      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String14, 5), 0) = 1 THEN LEFT( V_String14, 5) ELSE 0 END,  
  
  -- @nPrevScn         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String15, 5), 0) = 1 THEN LEFT( V_String15, 5) ELSE 0 END, -- Previous Screen  
  -- @nPrevStep        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16, 5), 0) = 1 THEN LEFT( V_String16, 5) ELSE 0 END, -- Previous Step  
  
   @cSysParentSKU    = V_String17,  
   @cSKUFlag         = V_String18,  
  
  -- @nInnerPack       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String19, 5), 0) = 1 THEN LEFT( V_String19, 5) ELSE 0 END,  
  -- @nCaseCnt         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String20, 5), 0) = 1 THEN LEFT( V_String20, 5) ELSE 0 END,  
  -- @nShipper         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,  
  -- @nPallet          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String22, 5), 0) = 1 THEN LEFT( V_String22, 5) ELSE 0 END,  
  
   @cPackkey     = V_String23,  
   @cResult          = V_String24,  
  
   @cMatchPackkey   = V_String25,  
   @cMatchInner      = V_String26,  
   @cMatchCase       = V_String27,  
   @cMatchShipper    = V_String28,  
   @cMatchPallet     = V_String29,  
  
  -- @nMatchInner      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String30, 5), 0) = 1 THEN LEFT( V_String30, 5) ELSE 0 END,  
  -- @nMatchCase       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String31, 5), 0) = 1 THEN LEFT( V_String31, 5) ELSE 0 END,  
  -- @nMatchShipper    = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String32, 5), 0) = 1 THEN LEFT( V_String32, 5) ELSE 0 END,  
  -- @nMatchPallet     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String33, 5), 0) = 1 THEN LEFT( V_String33, 5) ELSE 0 END,  
  
   @cMatchSKU        = V_String34,  
  -- @nQtyAvail        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String35, 5), 0) = 1 THEN LEFT( V_String35, 5) ELSE 0 END,  
  
   @cPackCnt         = V_String36,  
   @cPrevPackCnt     = V_String37,  
   @cPrevStyle       = V_String38,  
  
  -- @nMatchFound      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String39, 5), 0) = 1 THEN LEFT( V_String39, 5) ELSE 0 END,  
   @cParentExt       = V_String40, -- (Vicky05)  
  
   -- (Vicky06) - Start  
   @nLength          = CASE WHEN ISNUMERIC(V_ReceiptKey) = 1 THEN CAST(LEFT(V_ReceiptKey, 5) AS FLOAT) ELSE 0 END,  
   @nWidth           = CASE WHEN ISNUMERIC(V_POKey) = 1 THEN CAST(LEFT( V_POKey, 5) AS FLOAT) ELSE 0 END,  
   @nHeight          = CASE WHEN ISNUMERIC(V_LoadKey) = 1 THEN CAST(LEFT( V_LoadKey, 5) AS FLOAT) ELSE 0 END,  
   @nStdGrossWgt     = CASE WHEN ISNUMERIC(V_OrderKey) = 1 THEN CAST(LEFT( V_OrderKey, 5) AS FLOAT) ELSE 0 END,  
 --  @nStdCube         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_UCC, 5), 0) = 1 THEN LEFT( V_UCC, 5) ELSE 0 END,  
   -- (Vicky06) - End      
        
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
  
   -- (Vicky06) - Start  
   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
   -- (Vicky06) - End  
  
FROM rdt.rdtMobRec (NOLOCK)  
WHERE Mobile = @nMobile  
  
-- Screen constant  
DECLARE   
   @nStep_ParentSKU  INT,  @nScn_ParentSKU  INT,    
   @nStep_SKU        INT,  @nScn_SKU        INT,    
   @nStep_QTY        INT,  @nScn_QTY        INT,    
   @nStep_Option     INT,  @nScn_Option     INT,    
   @nStep_Inner      INT,  @nScn_Inner      INT,  
   @nStep_Case       INT,  @nScn_Case       INT,  
   @nStep_Shipper    INT,  @nScn_Shipper    INT,  
   @nStep_Pallet     INT,  @nScn_Pallet     INT,  
   @nStep_PrintLabel INT,  @nScn_PrintLabel INT,  
   @nStep_LWH        INT,  @nScn_LWH        INT, -- (Vicky06)  
                           @nScn_Option2    INT  -- (james01)  
  
SELECT  
   @nStep_ParentSKU  = 1,  @nScn_ParentSKU  = 1500,    
   @nStep_SKU        = 2,  @nScn_SKU        = 1501,    
   @nStep_QTY      = 3,  @nScn_QTY        = 1502,    
   @nStep_Option     = 4,  @nScn_Option     = 1503,    
   @nStep_Inner      = 5,  @nScn_Inner      = 1504,  
   @nStep_Case       = 6,  @nScn_Case       = 1505,  
   @nStep_Shipper    = 7,  @nScn_Shipper    = 1506,  
   @nStep_Pallet     = 8,  @nScn_Pallet     = 1507,  
   @nStep_PrintLabel = 9,  @nScn_PrintLabel = 1508,  
   @nStep_LWH        = 10, @nScn_LWH        = 1510, -- (Vicky06)  
                           @nScn_Option2    = 1511  -- (james01)  
  
IF @nFunc = 900  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start        -- Menu. Func = 900  
   IF @nStep = 1  GOTO Step_ParentSKU  -- Scn = 1500. ParentSKU  
   IF @nStep = 2  GOTO Step_SKU        -- Scn = 1501. SKU/UPC  
   IF @nStep = 3  GOTO Step_QTY        -- Scn = 1502. SKU/UPC, QTY  
   IF @nStep = 4  GOTO Step_Option     -- Scn = 1503. Option  
   IF @nStep = 5  GOTO Step_Inner      -- Scn = 1504. InnerPack  
   IF @nStep = 6  GOTO Step_Case       -- Scn = 1505. Case  
   IF @nStep = 7  GOTO Step_Shipper    -- Scn = 1506. Shipper  
   IF @nStep = 8  GOTO Step_Pallet     -- Scn = 1507. Pallet  
   IF @nStep = 9  GOTO Step_PrintLabel -- Scn = 1508. Print Label  
   IF @nStep = 10 GOTO Step_LWH        -- Scn = 1510. Length, Width, Height, Weight -- (Vicky06)  
   IF @nStep = 11 GOTO Step_Option     -- Scn = 1511. Option  
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step_Start. Func = 900  
********************************************************************************/  
Step_Start:  
BEGIN  
-- Commented (Vicky02) - Start  
--    -- Create the session data  
--    IF EXISTS (SELECT 1 FROM RDTSessionData (NOLOCK) WHERE Mobile = @nMobile)  
--       UPDATE RDTSessionData WITH (ROWLOCK) SET XML = '' WHERE Mobile = @nMobile  
--    ELSE  
--       INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)  
-- Commented (Vicky02) - End     
  
   -- Get prefer UOM  
   SELECT @cUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M (NOLOCK)  
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  
  
   IF ISNULL(@cPrinter , '') = ''  
   BEGIN  
     SELECT @cPrinter = U.DefaultPrinter  
     FROM RDT.rdtMobRec M (NOLOCK)  
      INNER JOIN RDT.rdtUser U (NOLOCK) ON (M.UserName = U.UserName)  
     WHERE M.Mobile = @nMobile  
   END  
  
   -- Purge outstanding records the maybe left over previously (Vicky07)  
   DELETE FROM RDT.rdtBOMCreationLog  
   WHERE  UserName = @cUserName   
   AND    Status < '9'  
  
   SET @nPrevBOMSeq = 0  
   SET @nBOMSeq = 0  
   SET @cSKUFlag = 'N'  
   SET @cInnerPack = '0'  
   SET @cCase = '0'  
   SET @cShipper = '0'  
   SET @cPallet = '0'  
   SET @cPackCnt = '0'  
   SET @cPrevStyle = ''  
   SET @nMatchFound = 0  
   SET @cParentExt = '0' -- (Vicky05)  
  
   -- Prepare ParentSKU screen var  
   SET @cOutField01 = '' -- ParentSKU  
  
   -- Go to ParentSKU screen  
   SET @nScn = @nScn_ParentSKU  
   SET @nStep = @nStep_ParentSKU  
   GOTO Quit  
  
   Step_Start_Fail:  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- ParentSKU  
   END  
END  
GOTO Quit  
  
  
/************************************************************************************  
Scn = 1500. ParentSKU  
   ParentSKU   (field01)  
************************************************************************************/  
Step_ParentSKU:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cParentSKU = @cInField01  
  
-- (Vicky05) - Start  
      -- Validate ParentSKU (if entered)  
      IF @cParentSKU <> ''   
      BEGIN  
     SET @cParentExt = '1'  -- Added by (Ricky_1.18)  
  
         /* Comment by (Ricky_1.18)  
         IF EXISTS (SELECT 1 FROM dbo.SKU SKU WITH (NOLOCK)  
                        WHERE SKU.Storerkey = @cStorerKey  
                        AND   SKU.SKU = @cParentSKU)  
         BEGIN  
             SET @cParentExt = '1'  
-- Comment By (Vicky05)  
--    SET @nErrNo = 63401  
--            SET @cErrMsg = rdt.rdtgetmessage( 63401, @cLangCode, 'DSP') --ParntSKU exist  
--            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ParentSKU  
--            GOTO ParentSKU_Fail  
         END  
         ELSE  
         BEGIN  
             SET @cParentExt = '0'   
         END  
         */  -- Comment by (Ricky_1.18)  
      END   
      ELSE  
      BEGIN  
             SET @cParentExt = '0'   
      END  
-- (Vicky05) - End  
  
  -- (ChewKP01)  
  IF NOT EXISTS ( SELECT 1 FROM dbo.BillOfMaterial WITH (NOLOCK) WHERE SKU = @cParentSKU )   
  BEGIN  
    SET @cParentSKU = ''    
  END  
    
   
  
      -- Prepare SKU screen var  
     SET @cOutField01 = @cParentSKU  
      SET @cOutField02 = '' -- SKU  
      SET @cOutField03 = '' -- SKUDescr  
      SET @cOutField04 = '' -- SKUDescr  
      SET @cOutField05 = '' -- Qty  
  
      SET @cPackCnt = '0'  
      SET @cPrevPackCnt = '0'  
      SET @cPrevStyle = ''  
  
      -- Go to SKU screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Back to menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = '' -- ParentSKU  
  
      SET @nInnerPack = 0  
      SET @nCaseCnt = 0  
      SET @nShipper = 0  
      SET @nPallet = 0  
  
   END  
   GOTO Quit  
  
   ParentSKU_Fail:  
   BEGIN  
      SET @cParentSKU = ''  
      SET @cOutField01 = '' -- ParentSKU  
   END  
END  
GOTO Quit  
  
  
/***********************************************************************************  
Scn = 1501. SKU screen  
   ParentSKU   (field01)  
   SKU/UPC     (field02, input)  
***********************************************************************************/  
Step_SKU:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cSKU = @cInField02 -- SKU  
  
      -- Validate blank  
      IF @cSKU = '' OR @cSKU IS NULL  
      BEGIN  
         SET @nErrNo = 63402  
         SET @cErrMsg = rdt.rdtgetmessage( 63402, @cLangCode, 'DSP') --SKU needed  
         EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU  
         GOTO SKU_Fail  
      END  
  
      -- Get SKU/UPC  
--      SELECT   
--         @nSKUCnt = COUNT( DISTINCT A.SKU),   
--         @cSKU = MIN( A.SKU) -- Just to bypass SQL aggregrate checking  
--      FROM   
--      (  
--         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.SKU = @cSKU  
--         UNION ALL  
--         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.AltSKU = @cSKU  
--         UNION ALL  
--         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.RetailSKU = @cSKU  
--         UNION ALL  
--         SELECT StorerKey, SKU FROM dbo.SKU SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU.ManufacturerSKU = @cSKU  
--         UNION ALL  
--         SELECT StorerKey, SKU FROM dbo.UPC UPC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UPC.UPC = @cSKU  
--      ) A  
  
      -- (Vicky08) - Start  
      EXEC RDT.rdt_GETSKUCNT     
         @cStorerKey  = @cStorerKey,     
         @cSKU        = @cSKU,        
         @nSKUCnt     = @nSKUCnt       OUTPUT,     
         @bSuccess    = @b_Success     OUTPUT,     
         @nErr        = @n_Err         OUTPUT,     
         @cErrMsg     = @c_ErrMsg      OUTPUT    
      -- (Vicky08) - End  
            
      -- Validate SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 63403  
         SET @cErrMsg = rdt.rdtgetmessage( 63403, @cLangCode, 'DSP') --Invalid SKU  
         EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU  
         GOTO SKU_Fail  
      END  
  
      -- Validate barcode return multiple SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 63404  
         SET @cErrMsg = rdt.rdtgetmessage( 63404 , @cLangCode, 'DSP') --MultiSKUBarcod  
         EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU  
         GOTO SKU_Fail  
      END  
  
      -- (Vicky08) - Start  
      -- Return actual SKU If barcode is scanned (SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU OR UPC.UPC)    
      EXEC [RDT].[rdt_GETSKU]      
         @cStorerKey  = @cStorerKey,     
         @cSKU        = @cSKU          OUTPUT,      
         @bSuccess    = @b_Success     OUTPUT,     
         @nErr        = @n_Err         OUTPUT,     
         @cErrMsg     = @c_ErrMsg      OUTPUT    
      -- (Vicky08) - End  
  
     -- Vicky01 (Start)  
      DECLARE @nParentSKUCheck int  
  
      IF rdt.RDTGetConfig( @nFunc, 'STDBOMINDICATOR', @cStorerKey) = 1  
      BEGIN  
         SELECT @nParentSKUCheck = COUNT(SIZE)  
         FROM dbo.SKU WITH (NOLOCK)  
       WHERE Storerkey = @cStorerKey  
         AND   SKU = @cSKU  
         AND   SKUGroup = 'BOM'  
      END  
      ELSE  
      BEGIN  
         SELECT @nParentSKUCheck = COUNT(SIZE)  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   SKU = @cSKU  
         AND   SIZE = '88888'  
      END  
  
      -- Validate SKU scanned is ParentSKU and Not  
      IF @nParentSKUCheck <> 0  
      BEGIN  
         SET @nErrNo = 63446  
         SET @cErrMsg = rdt.rdtgetmessage( 63446 , @cLangCode, 'DSP') --Invalid SKU  
         EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU  
         GOTO SKU_Fail  
      END  
      -- Vicky01 (End)  
  
      -- Added By Vicky on 20-Sept-2007 (Start)  
      DECLARE @cDStyle NVARCHAR(20)  
  
      IF @cPackCnt = '0'  
      BEGIN  
         SELECT @cPrevStyle = RTRIM(Style)  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   SKU = @cSKU  
  
         SET @cPrevPackCnt = '0'  
      END  
  
      IF @cPackCnt = '1'  
      BEGIN  
         SELECT @cDStyle = RTRIM(Style)  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   SKU = @cSKU  
          
         IF @cPrevStyle <> @cDStyle  
         BEGIN  
          SET @nErrNo = 63441  
          SET @cErrMsg = rdt.rdtgetmessage( 63441 , @cLangCode, 'DSP') --Diff Style  
          EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU  
          GOTO SKU_Fail  
         END  
      END  
      -- Added By Vicky on 20-Sept-2007 (End)  
  
      IF EXISTS (SELECT 1 FROM RDT.rdtBOMCreationLog WITH (NOLOCK)   
                 WHERE ComponentSKU = @cSKU  
                 AND   Status = '0'  
                 AND   MobileNo = @nMobile  
                 AND   UserName = @cUserName   
                 AND   Storerkey = @cStorerKey)  
      BEGIN  
            SET @nErrNo = 63405  
          SET @cErrMsg = rdt.rdtgetmessage( 63405, @cLangCode, 'DSP') --SKU scanned b4  
          EXEC rdt.rdtSetFocusField @nMobile, 02 -- SKU  
          GOTO SKU_Fail  
      END  
  
      IF rdt.RDTGetConfig( @nFunc, 'BOMUSEDESCR', @cStorerKey) = 1  
      BEGIN  
         SELECT @cSKUDescr = DESCR,  
                @cStyle = RTRIM(Style)  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   SKU = @cSKU  
      END  
      ELSE  
      BEGIN  
         SELECT @cSKUDescr = RTRIM(BUSR1) + ' ' + RTRIM(BUSR2),  
                @cStyle = RTRIM(Style)  
         FROM dbo.SKU WITH (NOLOCK)  
         WHERE Storerkey = @cStorerKey  
         AND   SKU = @cSKU  
      END  
  
      -- Prepare QTY screen var  
      SET @cOutField01 = @cParentSKU  
      SET @cOutField02 = @cSKU   
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField05 = '' -- Qty  
  
  
      -- Go to QTY screen  
      SET @nScn = @nScn_QTY  
      SET @nStep = @nStep_QTY  
  
      SET @nPrevScn = @nScn_SKU  
      SET @nPrevStep = @nStep_SKU  
  
   END -- InputKey = 1  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Go Confirmation Option Screen   
      -- Prepare Confirmation Option screen var  
      SET @cOutField01 = '1' -- Default Option  
    SET @cOutField02 = ''   
  
      SET @cPrevPackCnt = '0'  
      SET @cPackCnt = '1'  
      SET @cPrevStyle = ''  
      SET @cDStyle = ''  
  
      -- (Vicky05)  
      SET @nInnerPack = 0  
      SET @nCaseCnt = 0  
      SET @nShipper = 0  
      SET @nPallet = 0  
  
      -- Go to Confirmation Option screen  
      -- (james01)  
      IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  
      BEGIN  
         SET @nScn = @nScn_Option2  
         SET @nStep = @nStep_Option  
      END  
      ELSE  
      BEGIN  
         SET @nScn = @nScn_Option  
         SET @nStep = @nStep_Option  
      END  
   END  
   GOTO Quit  
  
   SKU_Fail:  
   BEGIN  
      SET @cSKU = ''  
      SET @cOutField01 = '' -- ParentSKU  
    SET @cOutField02 = '' -- SKU  
      EXEC rdt.rdtSetFocusField @nMobile, 04 -- SKU  
      GOTO Quit  
   END  
  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 1502. QTY screen  
   ParentSKU (field01)   
   SKU       (field02)   
   SKUDescr  (field03, field04)  
   QTY       (field05, input)  
********************************************************************************/  
Step_QTY:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Screen mapping  
      SET @cQTY = IsNULL( @cInField05, '')  
  
    IF @cQTY  = '' SET @cQTY  = '0' -- Blank taken as zero  
  
    IF RDT.rdtIsValidQTY( @cQTY, 1) = 0  
    BEGIN  
          SET @nErrNo = 63406  
          SET @cErrMsg = rdt.rdtgetmessage( 63406, @cLangCode, 'DSP') --Invalid QTY  
          EXEC rdt.rdtSetFocusField @nMobile, 08 -- QTY  
            SET @cQTY = '' -- set back to blank value -- (james01)  
          GOTO QTY_Fail  
    END  
  
      SET @nBOMSeq = @nPrevBOMSeq + 1  
      SET @nPrevBOMSeq = @nBOMSeq  
  
      -- Insert Data to RDT.rdtBOMCreationLog table  
       IF @cParentSKU <> '' --AND @cSysParentSKU = ''  
       BEGIN  
        IF NOT EXISTS (SELECT 1 FROM RDT.rdtBOMCreationLog WITH (NOLOCK)   
                       WHERE ParentSKU = @cParentSKU  
                         AND ComponentSKU = @cSKU  
                         AND Status = '0'  
                         AND MobileNo = @nMobile  
                         AND UserName = @cUserName   
                         AND Storerkey = @cStorerKey)  
        BEGIN  
           INSERT INTO RDT.rdtBOMCreationLog (Storerkey, ParentSKU, ComponentSKU, Style, Qty, SequenceNo, UserName, MobileNo)  
         VALUES (@cStorerKey, @cParentSKU, @cSKU, @cStyle, CAST(@cQTY as INT) , @nBOMSeq, @cUserName, @nMobile)  
        END  
       END  
       ELSE IF @cParentSKU = '' --AND @cSysParentSKU = ''  
       BEGIN  
  
--          SELECT @cSysParentSKU = RTRIM(@cStyle) + '00000'  
         SELECT @cSysParentSKU = LEFT(RTRIM(@cStyle), 10) + '000' -- (Vicky03)  
  
       IF NOT EXISTS (SELECT 1 FROM RDT.rdtBOMCreationLog WITH (NOLOCK)   
                        WHERE ParentSKU = @cSysParentSKU  
                          AND ComponentSKU = @cSKU  
                          AND Status = '0'  
                          AND MobileNo = @nMobile  
                          AND UserName = @cUserName   
                          AND Storerkey = @cStorerKey )  
         BEGIN  
          INSERT INTO RDT.rdtBOMCreationLog (Storerkey, ParentSKU, ComponentSKU, Style, Qty, SequenceNo, UserName, MobileNo)  
          VALUES (@cStorerKey, @cSysParentSKU, @cSKU, @cStyle, CAST(@cQTY as INT), @nBOMSeq, @cUserName, @nMobile)  
         END  
  
         SET @cParentSKU = @cSysParentSKU -- (Vicky05)  
       END  
   
        
      -- Go back to SKU Screen     
      -- Prep SKU screen var  
  SET @cOutField01 = @cParentSKU  
  SET @cOutField02 = ''  
  SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
  
      SET @nScn  = @nScn_SKU  
      SET @nStep = @nStep_SKU  
  
      SET @nPrevScn = @nScn_QTY  
      SET @nPrevStep = @nStep_QTY  
  
      IF @cPackCnt = '0'  
      BEGIN  
          SET @cPackCnt = '1'  
          SET @cPrevPackCnt = '1'  
      END  
   END   
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare SKU screen var  
      SET @cOutField01 = @cParentSKU  
      SET @cOutField02 = ''  
     SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      EXEC rdt.rdtSetFocusField @nMobile, 02  
  
      IF @cPrevPackCnt = '0'  
      BEGIN  
         SET @cPackCnt = '0'  
      END  
  
      -- Go to prev screen  
      SET @nScn = @nScn_SKU  
      SET @nStep = @nStep_SKU  
   END  
   GOTO Quit  
  
   QTY_Fail:  
   BEGIN  
      SET @cOutField01 = @cParentSKU  
      SET @cOutField02 = @cSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField05 = ''  
      EXEC rdt.rdtSetFocusField @nMobile, 05 -- qty  
      GOTO Quit  
   END  
    
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 1503. Option screen  
   Option (field01)  
********************************************************************************/  
Step_Option:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
   
      SET @cOption = @cInField01  
  
      -- Check if option is blank  
      IF @cOption = '' OR @cOption IS NULL  
      BEGIN  
         SET @nErrNo = 63407  
         SET @cErrMsg = rdt.rdtgetmessage(63407, @cLangCode, 'DSP') --Option required   
         GOTO Option_Fail        
      END        
  
      IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  -- (james01)  
      BEGIN  
         -- If this config turned on keystroke 9 is consider as keystroke 2  
         IF @cOption = '9'  
         BEGIN  
            SET @cOption = '2'  
         END  
         ELSE IF @cOption = '2'  
         BEGIN  
            SET @cOption = ''  
         END  
      END  
  
      -- Invalid option other than '1' or '2'  
      IF (@cOption <> '1' AND @cOption <> '2')   
    BEGIN  
         SET @nErrNo = 63408  
         SET @cErrMsg = rdt.rdtgetmessage(63408, @cLangCode, 'DSP') --Invalid option  
         GOTO Option_Fail        
      END        
  
      IF @cOption = '1' -- Create Pack   
      BEGIN  
         -- Go to LWH Screen (james01)  
         IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1 AND   
            rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 0  
         BEGIN  
            --prepare Label screen var  
            SET @cOutField01 = ''  
            SET @cOutField02 = ''  
            SET @cOutField03 = ''  
            SET @cOutField04 = ''  
          EXEC rdt.rdtSetFocusField @nMobile, 01  
  
            SET @cFieldAttr01 = ''  
            SET @cFieldAttr02 = ''  
            SET @cFieldAttr03 = ''  
            SET @cFieldAttr04 = ''  
  
    SET @cInField01 = ''  
    SET @cInField02 = ''  
    SET @cInField03 = ''  
    SET @cInField04 = ''  
         
            SET @nScn = @nScn_LWH  
            SET @nStep = @nStep_LWH  
  
            IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  -- (james01)  
            BEGIN  
               SET @nPrevScn = @nScn_Option2  
               SET @nPrevStep = @nStep_Option  
            END  
            ELSE  
            BEGIN  
               SET @nPrevScn = @nScn_Option  
               SET @nPrevStep = @nStep_Option  
            END  
  
            GOTO Quit  
         END  
  
         -- SELECT @cParentSKU = @cSysParentSKU -- Comment By (Vicky05)  
  
       -- Check matching BOM in BOM table  
         -- (Vicky04) -- Add new parameter @cUserName  
       EXEC RDT.rdt_BOM_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @cMatchSKU OUTPUT, @cResult OUTPUT, @cParentExt -- 24-09-2007 -- (Vicky05)  
           
  
         -- (Vicky05) - Start - If ParentSKU entered and no BOM match found  
         -- 1.17 Shong      Accept Customer BOM Label  
         IF @cResult <> '1' and @cSysParentSKU = '' AND @cParentExt = '0'  
         BEGIN  
            UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
               SET Status = '9'  
            WHERE Style = @cStyle  
            AND   Status = '0'  
            AND   MobileNo = @nMobile  
            AND   UserName = @cUserName  
            AND   ParentSKU = @cParentSKU  
  
            SET @nErrNo = 67251  
            SET @cErrMsg = rdt.rdtgetmessage(67251, @cLangCode, 'DSP') --BOM not match  
            GOTO Option_Fail   
         END  
         -- (Vicky05) - End  
  
       -- If got match, find packkey configuration  
       IF @cResult = '1'  
       BEGIN  
--          SELECT TOP 1 @cMatchPackkey = RTRIM(Packkey)  
--          FROM dbo.UPC WITH (NOLOCK)  
--          WHERE SKU = ISNULL(@cMatchSKU, '')  
--          AND   Storerkey = @cStorerKey  
  
--          SELECT @cMatchInner   = RTRIM(PACKUOM2),  
--                   @nMatchInner   = InnerPack,  
--                   @cMatchCase    = RTRIM(PACKUOM1),  
--                   @nMatchCase    = CaseCnt,  
--                   @cMatchShipper = RTRIM(PACKUOM8),  
--                 @nMatchShipper = OtherUnit1,  
--                   @cMatchPallet  = RTRIM(PACKUOM4),  
--                   @nMatchPallet  = Pallet  
--            FROM dbo.PACK WITH (NOLOCK)  
--            WHERE Packkey = @cMatchPackkey  
  
           -- Get Inventory  
           SELECT @nQtyAvail = SUM(SL.QTY)  
           FROM dbo.SKUxLOC SL WITH (NOLOCK)  
           JOIN RDT.rdtBOMCreationLog BCL WITH (NOLOCK)  
               ON (BCL.StorerKey = SL.Storerkey AND  
                   BCL.ComponentSKU = SL.SKU AND  
                   BCL.Status = '0' AND  
                   BCL.ParentSKU = @cParentSKU AND  
                   BCL.MobileNo = @nMobile AND   
                   BCL.Username = @cUserName) -- (Vicky04)  
           WHERE SL.Storerkey = @cStorerKey  
       END  
         ELSE  
         BEGIN  
           IF @cSysParentSKU <> ''  
           BEGIN  
                -- Get ParentSKU when not supply  
                --SELECT @cSuffix = RIGHT(MAX(RTRIM(BOM.SKU)),3)  
--                SELECT @cSuffix = MAX(RIGHT(RTRIM(BOM.SKU),3)) -- LARRY01  
--                FROM dbo.BillOfMaterial BOM WITH (NOLOCK)  
--                JOIN dbo.SKU SKU WITH (NOLOCK)  
--                   ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)  
--               -- WHERE BOM.Storerkey = @cStorerKey (Vicky01)  
--                --WHERE   SKU.Style = @cStyle  
--                WHERE LEFT(RTRIM(SKU.Style),10) = LEFT(RTRIM(@cStyle),10)  --LARRY01  
--  
--                SELECT @nSuffix = CAST(ISNULL(@cSuffix, '0') as INT) + 1  
--                                     
--                SELECT @cParentSKU = LEFT(RTRIM(@cStyle), 10) + RIGHT(RTRIM(REPLICATE(0,3) + CAST(@nSuffix as CHAR)), 3) -- (Vicky03)  
  
                -- (Vicky08) - Start  
                EXEC dbo.isp_GetNextParentSKU     
                     @c_Storerkey    = @cStorerKey,     
                     @c_Style        = @cStyle,    
                     @c_NewParentSKU = @cParentSKU OUTPUT  
  
                IF @cParentSKU = ''  
                BEGIN  
                  SET @nErrNo = 69541  
                  SET @cErrMsg = rdt.rdtgetmessage(69541, @cLangCode, 'DSP') --ErrGenParentSKU  
                  GOTO Option_Fail   
                END  
                -- (Vicky08) - End  
  
                UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                   SET ParentSKU = @cParentSKU  
                WHERE Style = @cStyle  
                AND   Status = '0'  
                AND   MobileNo = @nMobile  
                AND   UserName = @cUserName -- (Vicky04)  
   
              -- SET @cPackkey = RIGHT(RTRIM(@cParentSKU), 10) Comment By (Vicky05)  
           END  
            -- (Vicky05) - Comment Start  
            --           ELSE IF @cParentSKU <> '' AND @cSysParentSKU = ''  
            --           BEGIN  
                           -- SET @cPackkey = RIGHT(RTRIM(@cParentSKU), 10)  
            --           END  
            -- (Vicky05) - Comment End  
         END  
  
         IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1  -- (james01)  
         BEGIN  
  
            SELECT @nCaseCnt = 1 * CAST(@cQTY as INT)  
  
            -- No match found, insert BOM, SKU, UPC, Packkey  
            IF @cResult = '0'  
            BEGIN  
               BEGIN TRAN  
  
               -- Assign Packkey  
               SELECT @b_success=0  
               EXECUTE   nspg_getkey  
               'BOMPACK'  
               , 7  
               , @c_BOMPackKey OUTPUT  
               , @b_success OUTPUT  
               , @n_err OUTPUT  
               , @c_errmsg OUTPUT  
               IF @b_success=0  
               BEGIN  
                  ROLLBACK TRAN  
                  SET @nErrNo = 69546  
                  SET @cErrMsg = rdt.rdtgetmessage( 69546, @cLangCode, 'DSP') -- PackkeyErr  
                  GOTO Option_Fail  
               END  
  
               SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
  
               -- Insert SKU, BOM   
               EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
               IF @nErrNo <> 0  
               BEGIN  
              SET @cErrMsg = @cErrMsg  
                  GOTO Case_Fail  
               END  
  
               SET @cPackUOM1 = rdt.RDTGetConfig( @nFunc, 'DefaultPackUOM1', @cStorerKey)  
               SET @cPackUOM3 = rdt.RDTGetConfig( @nFunc, 'DefaultPackUOM3', @cStorerKey)  
  
      SET @cPackUOM1 = CASE WHEN ISNULL(@cPackUOM1, '') = '' THEN '' ELSE @cPackUOM1 END  
               SET @cPackUOM3 = CASE WHEN ISNULL(@cPackUOM3, '') = '' THEN 'PK' ELSE @cPackUOM3 END  
  
               IF EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK) WHERE PackKey = @cPackkey)  
               BEGIN  
                  ROLLBACK TRAN  
                  SET @nErrNo = 70474  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackkeyErr  
                  GOTO Option_Fail  
               END  
  
               -- Insert Pack Table (1 Record for ParentSKU)  
             INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM3, QTY)  
             VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN @cPackUOM1 ELSE '' END, @nCaseCnt, @cPackUOM3, 1)  
  
               -- Insert UPC (1 Record for ParentSKU)  
               IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
               (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
               BEGIN  
                INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
               END  
  
               -- Update RDT.rdtBOMCreationLog   
               UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                SET Status = '9'  
               WHERE ParentSKU = @cParentSKU  
             AND   Status = '0'  
             AND   MobileNo = @nMobile  
             AND   UserName = @cUserName  
               AND   Storerkey = @cStorerKey  
  
             IF @@ERROR = 0  
             BEGIN  
        COMMIT TRAN  
  
                 -- Go to LWH Screen   
                 IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
                 BEGIN  
                    --prepare Label screen var  
                  SET @cOutField01 = @cParentSKU  
                  SET @cOutField02 = ''  
  
                    SET @cFieldAttr01 = ''  
                    SET @cFieldAttr02 = ''  
                    SET @cFieldAttr03 = ''  
                    SET @cFieldAttr04 = ''  
  
                    -- Go to Label Screen   
                    SET @nScn = @nScn_PrintLabel  
                    SET @nStep = @nStep_PrintLabel  
                 END  
                 ELSE  
                 BEGIN  
       SET @cOutField01 = ''  
       SET @cOutField02 = ''  
       SET @cOutField03 = ''  
       SET @cOutField04 = ''  
  
       SET @cInField01 = ''  
       SET @cInField02 = ''  
       SET @cInField03 = ''  
       SET @cInField04 = ''  
  
            SET @nScn = @nScn_LWH  
            SET @nStep = @nStep_LWH  
                 END  
    
                 IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  -- (james01)  
                 BEGIN  
                SET @nPrevScn = @nScn_Option2  
                SET @nPrevStep = @nStep_Option  
                 END  
                 ELSE  
                 BEGIN  
                SET @nPrevScn = @nScn_Option  
                SET @nPrevStep = @nStep_Option  
                 END  
               END  
       ELSE  
       BEGIN  
             ROLLBACK TRAN  
             SET @nErrNo = 69547  
             SET @cErrMsg = rdt.rdtgetmessage( 69547, @cLangCode, 'DSP') -- Update Fail  
                 GOTO Option_Fail  
           END  
            END  -- Result = 0  
            ELSE  
            BEGIN -- Result = 1  
             -- Check matching Packkey  
             EXEC RDT.rdt_BOM_Packkey_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @nInnerPack, @nCaseCnt,  
                                              @nShipper, @nPallet, @nMatchFound OUTPUT, @cMatchSKU OUTPUT, @cParentExt   
  
               IF @nMatchFound > 0  
               BEGIN  
                  IF @cSysParentSKU = '' AND @cParentExt <> '1'  
                  BEGIN  
                     SET @nErrNo = 69548  
                 SET @cErrMsg = rdt.rdtgetmessage( 69548, @cLangCode, 'DSP') -- Pack for other  
                     GOTO Option_Fail  
                  END  
  
                  -- Match BOM, Packkey Found  
                  -- Update RDT.rdtBOMCreationLog   
                UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                 SET Status = '5',  
                         ParentSKU = @cMatchSKU --@cParentSKU  
              WHERE ParentSKU = @cParentSKU  
              AND   Status = '0'  
              AND   MobileNo = @nMobile  
              AND   UserName = @cUserName  
                AND   Storerkey = @cStorerKey  
   
                IF @@ERROR = 0  
                BEGIN  
           COMMIT TRAN  
  
             -- Go to LWH Screen   
                     IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
                     BEGIN  
                        --prepare Label screen var  
                      SET @cOutField01 = @cParentSKU  
                      SET @cOutField02 = ''  
  
                        SET @cFieldAttr01 = ''  
                        SET @cFieldAttr02 = ''  
                        SET @cFieldAttr03 = ''  
                        SET @cFieldAttr04 = ''  
  
                        -- Go to Label Screen   
                        SET @nScn = @nScn_PrintLabel  
                        SET @nStep = @nStep_PrintLabel  
                     END  
                     ELSE  
                     BEGIN  
        SET @cOutField01 = ''  
        SET @cOutField02 = ''  
        SET @cOutField03 = ''  
        SET @cOutField04 = ''  
   
        SET @cInField01 = ''  
        SET @cInField02 = ''  
        SET @cInField03 = ''  
        SET @cInField04 = ''  
         
                SET @nScn = @nScn_LWH  
                SET @nStep = @nStep_LWH  
                     END  
  
                     IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  -- (james01)  
                     BEGIN  
                    SET @nPrevScn = @nScn_Option2  
                    SET @nPrevStep = @nStep_Option  
                     END  
                     ELSE  
                     BEGIN  
                    SET @nPrevScn = @nScn_Option  
                    SET @nPrevStep = @nStep_Option  
                     END  
                  END  
                ELSE  
          BEGIN  
                 ROLLBACK TRAN  
                 SET @nErrNo = 69549  
                 SET @cErrMsg = rdt.rdtgetmessage( 69549, @cLangCode, 'DSP') -- Update Fail  
                     GOTO Option_Fail  
            END  
               END   -- @nMatchFound  
               ELSE  
               BEGIN  
                  IF @cParentExt = '1'   
                  BEGIN   
                     SET @nErrNo = 69550  
                 SET @cErrMsg = rdt.rdtgetmessage( 69550, @cLangCode, 'DSP') -- Pack not match  
            GOTO Option_Fail  
                  END  
    ELSE  
                  BEGIN  
                     IF @cSysParentSKU <> ''   
                     BEGIN  
                        EXEC dbo.isp_GetNextParentSKU     
                           @c_Storerkey    = @cStorerKey,     
                           @c_Style        = @cStyle,    
                           @c_NewParentSKU = @cParentSKU OUTPUT  
  
                        IF @cParentSKU = ''  
                        BEGIN  
                           SET @nErrNo = 69551  
                           SET @cErrMsg = rdt.rdtgetmessage(69551, @cLangCode, 'DSP') --ErrGenParentSKU  
                           GOTO Option_Fail   
                        END  
  
                        UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                           SET ParentSKU = @cParentSKU  
                        WHERE Style = @cStyle  
                        AND   Status = '0'  
                        AND   MobileNo = @nMobile  
                        AND   UserName = @cUserName -- (Vicky04)  
                     END  
  
                     -- Assign Packkey  
                     SELECT @b_success=0  
                     EXECUTE   nspg_getkey  
                        'BOMPACK'  
                    , 7  
                        , @c_BOMPackKey OUTPUT  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
                     IF @b_success=0  
                     BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 69552  
                        SET @cErrMsg = rdt.rdtgetmessage( 69552, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO Option_Fail  
                     END  
                     
                     SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
  
                     -- Insert SKU, BOM   
                     EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
                   IF @nErrNo <> 0  
                   BEGIN  
                  SET @cErrMsg = @cErrMsg  
                      GOTO Option_Fail  
                   END  
  
                     IF EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK) WHERE PackKey = @cPackkey)  
                     BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 70475  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO Option_Fail  
                     END  
  
                     -- Insert Pack Table (1 Record for ParentSKU)  
                     INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM3, QTY)  
                     VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END,  
                           @nCaseCnt, 'PK', 1)  
                                 
                     -- Insert UPC (1 Record for ParentSKU)  
                     IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
                     (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
                     BEGIN  
                        INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                        VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
                     END  
       
                   -- Update RDT.rdtBOMCreationLog   
                   UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                    SET Status = '9'  
                 WHERE ParentSKU = @cParentSKU  
                 AND   Status = '0'  
                 AND   MobileNo = @nMobile  
                 AND   UserName = @cUserName  
                   AND   Storerkey = @cStorerKey  
       
                   IF @@ERROR = 0  
                   BEGIN  
              COMMIT TRAN  
  
                -- Go to LWH Screen   
                        IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1   -- (james01)  
                        BEGIN  
                           --prepare Label screen var  
                         SET @cOutField01 = @cParentSKU  
                         SET @cOutField02 = ''  
  
                         SET @cFieldAttr01 = ''  
                         SET @cFieldAttr02 = ''  
                         SET @cFieldAttr03 = ''  
                         SET @cFieldAttr04 = ''  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                      END  
                      ELSE  
                      BEGIN  
        SET @cOutField01 = ''  
        SET @cOutField02 = ''  
        SET @cOutField03 = ''  
        SET @cOutField04 = ''  
          
        SET @cInField01 = ''  
        SET @cInField02 = ''  
        SET @cInField03 = ''  
        SET @cInField04 = ''  
         
                SET @nScn = @nScn_LWH  
                SET @nStep = @nStep_LWH  
                      END  
  
                      IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  -- (james01)  
                      BEGIN  
                     SET @nPrevScn = @nScn_Option2  
                     SET @nPrevStep = @nStep_Option  
                      END  
                      ELSE  
                      BEGIN  
                     SET @nPrevScn = @nScn_Option  
                     SET @nPrevStep = @nStep_Option  
                      END  
                  END  
              ELSE  
          BEGIN  
                 ROLLBACK TRAN  
                 SET @nErrNo = 69553  
                 SET @cErrMsg = rdt.rdtgetmessage( 69553, @cLangCode, 'DSP') -- Update Fail  
                     GOTO Option_Fail  
              END  
                 END -- @cParentExt = 0  
             END -- Matchfound = 0  
          END -- Result = 1  
        END  
        ELSE  
        BEGIN  
           --prepare Innerpack screen var  
           SET @cOutField01 = ''  
           SET @cOutField02 = '1'  -- anymore packs?  
  
           -- Go to next screen  
           SET @nScn = @nScn_Inner  
           SET @nStep = @nStep_Inner  
           EXEC rdt.rdtSetFocusField @nMobile, 04 -- #  
  
           -- (james01)  
           IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  
           BEGIN  
              SET @nPrevScn = @nScn_Option2  
              SET @nPrevStep = @nStep_Option  
           END  
           ELSE  
           BEGIN  
              SET @nPrevScn = @nScn_Option  
              SET @nPrevStep = @nStep_Option  
           END  
  
           GOTO Quit  
         END  
      END  
  
      IF @cOption = '2' -- Cancel Creation  
      BEGIN   
  
         DELETE FROM RDT.rdtBOMCreationLog  
--         WHERE ParentSKU = @cParentSKU  
--     AND   Status = '0'  
     WHERE   MobileNo = @nMobile  
     AND   UserName = @cUserName  
         AND   Storerkey = @cStorerKey  
  
  
       --prepare ParentSKU screen var  
       SET @cOutField01 = ''   
       SET @cOutField02 = ''   
       SET @cOutField03 = ''   
       SET @cOutField04 = ''   
       SET @cOutField05 = ''   
  
     SET @cInField01 = ''   
     SET @cInField02 = ''   
     SET @cInField03 = ''   
     SET @cInField04 = ''   
     SET @cInField05 = ''   
   
       SET @cParentSKU = ''  
       SET @cSysParentSKU = ''  
       SET @cSKU = ''  
       SET @cSKUDescr = ''  
       SET @cQTY = ''  
       SET @cStyle = ''  
       SET @nPrevBOMSeq = 0  
       SET @nBOMSeq = 0  
  
         SET @cSKUFlag = ''  
         SET @cResult = ''  
         SET @nSKUCnt = 0  
  
         SET @cMatchSKU = ''  
     SET @cMatchPackkey = ''  
     SET @cMatchInner = ''    
     SET @cMatchCase = ''     
     SET @cMatchShipper = ''  
     SET @cMatchPallet = ''   
  
     SET @nMatchInner = ''  
     SET @nMatchCase = ''  
     SET @nMatchShipper = ''  
     SET @nMatchPallet = ''  
         SET @nPrevScn = ''  
         SET @nPrevStep = ''  
       
         SET @nQtyAvail = 0  
  
       SET @cPrevPackCnt = '0'  
       SET @cPackCnt = '0'  
       SET @cPrevStyle = ''  
       SET @cDStyle = ''  
          
       -- Go to ParentSKU screen  
       SET @nScn = @nScn_ParentSKU  
       SET @nStep = @nStep_ParentSKU  
  
      GOTO Quit  
    END  
   END  
     
-- Do not allow ESC in Option Screen  
--    IF @nInputKey = 0 -- ESC  
--    BEGIN    
--       -- Prepare QTY screen var  
--       SET @cOutField01 = @cParentSKU  
--       SET @cOutField02 = @cSKU   
--       SET @cOutField03 = SUBSTRING( @cSKUDescr,  1, 20)  
--       SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
--       SET @cOutField05 = '' -- Qty  
--   
--     -- Go to previous screen  
--     SET @nScn = @nScn_QTY  
--     SET @nStep = @nStep_QTY  
--    END  
     
   GOTO Quit  
  
   Option_Fail:  
   BEGIN  
      SET @cOutField01 = ''--option  
      SET @cOption = ''  
   END  
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 1504. Confirmation Msg screen  
   ParentSKU (field01)  
********************************************************************************/  
-- Step_ConfirmMsg:  
-- BEGIN  
--    IF @nInputKey = 1 -- ENTER  
--    BEGIN  
--       IF @cParentSKU = ''  
--       BEGIN  
--         SET @cParentSKU = @cSysParentSKU  
--       END  
--   
--       --prepare Innerpack screen var  
--       SET @cOutField01 = ''  
--       SET @cOutField02 = '1'  -- anymore packs?  
--   
--       -- Go to Innerpack Screen   
--       SET @nScn = @nScn_Inner  
--     SET @nStep = @nStep_Inner  
--   
--       GOTO Quit  
--    END  
--   
--      
--    IF @nInputKey = 0 -- ESC  
--    BEGIN    
--       -- Go Confirmation Option Screen   
--       -- Prepare Confirmation Option screen var  
--     SET @cOutField01 = '1' -- Default Option  
--     SET @cOutField02 = ''   
--   
--       -- Go to Confirmation Option screen  
--       SET @nScn = @nScn_Option  
--       SET @nStep = @nStep_Option  
--    END  
--      
--    GOTO Quit  
--    
-- END  
-- GOTO Quit  
  
/********************************************************************************  
Scn = 1504. InnerPack screen  
   InnerPack (field01, input)  
   Option    (field02, input)  
********************************************************************************/  
Step_Inner:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
   
      SET @cInnerPack = @cInField01  
      SET @cOptionInner = @cInField02  
  
    IF @cInnerPack  = '' SET @cInnerPack  = '0' -- Blank taken as zero  
  
      IF RDT.rdtIsValidQTY( @cInnerPack, 0) = 0  
    BEGIN  
          SET @nErrNo = 63409  
          SET @cErrMsg = rdt.rdtgetmessage( 63409, @cLangCode, 'DSP') --Invalid Number  
          EXEC rdt.rdtSetFocusField @nMobile, 05 -- #  
          GOTO Inner_Fail  
    END  
  
      -- Check if option is blank  
      IF @cOptionInner = '' OR @cOptionInner IS NULL  
      BEGIN  
         SET @nErrNo = 63410  
         SET @cErrMsg = rdt.rdtgetmessage(63410, @cLangCode, 'DSP') --Option required   
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Option   
         GOTO Inner_Fail        
      END        
        
      -- Invalid option other than '1' or '2'  
      IF (@cOptionInner <> '1' AND @cOptionInner <> '2')   
    BEGIN  
         SET @nErrNo = 63411  
         SET @cErrMsg = rdt.rdtgetmessage(63411, @cLangCode, 'DSP') --Invalid option  
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Option   
         GOTO Inner_Fail        
      END        
  
      SET @nInnerPack = CAST(@cInnerPack as INT)  
  
      IF @cOptionInner = '1'  
      BEGIN  
        --prepare Case screen var  
        SET @cOutField01 = ''  
        SET @cOutField02 = '1'  -- anymore packs?  
          EXEC rdt.rdtSetFocusField @nMobile, 04 -- #  
   
        -- Go to Case Screen   
        SET @nScn = @nScn_Case  
      SET @nStep = @nStep_Case  
      END  
  
      IF @cOptionInner = '2' -- No more packs  
      BEGIN  
          -- No BOM match found, insert BOM, SKU, UPC, Packkey  
          IF @cResult = '0'  
          BEGIN  
  
             BEGIN TRAN  
  
            -- (Vicky05) - Start - Assign Packkey  
              SELECT @b_success=0  
              EXECUTE   nspg_getkey  
              'BOMPACK'  
              , 7  
              , @c_BOMPackKey OUTPUT  
              , @b_success OUTPUT  
              , @n_err OUTPUT  
              , @c_errmsg OUTPUT  
              IF @b_success=0  
              BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 67252  
                SET @cErrMsg = rdt.rdtgetmessage( 67252, @cLangCode, 'DSP') -- PackkeyErr  
                GOTO Inner_Fail  
              END  
             
            SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
            -- (Vicky05) - End - Assign Packkey  
  
             -- Insert SKU, BOM   
             -- (Vicky04) - Add new Parameter @cUserName  
             EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
             IF @nErrNo <> 0  
              GOTO Inner_Fail  
  
             IF EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK) WHERE PackKey = @cPackkey)  
             BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 70476  
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackkeyErr  
                GOTO Option_Fail  
             END  
  
             -- Insert Pack Table (1 Record for ParentSKU)  
           INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM2, InnerPack, PACKUOM3, QTY)  
           VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END,   
                  @nInnerPack, 'PK', 1)  
  
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
             (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
             BEGIN  
                -- Added by (Ricky_1.19)  
                INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
              VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'IP' END,   
        @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'IP')  
      /* -- Commented by (Ricky_1.19)  
              INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
              VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'IP')  
              */  
             END  
  
             -- Update RDT.rdtBOMCreationLog   
             UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
              SET Status = '9'  
           WHERE ParentSKU = @cParentSKU  
           AND   Status = '0'  
           AND   MobileNo = @nMobile  
           AND   UserName = @cUserName  
             AND   Storerkey = @cStorerKey  
  
             IF @@ERROR = 0  
             BEGIN  
       COMMIT TRAN  
                   
              -- (Vicky06) Length, Width, Height - Start  
              SELECT @nLength = [Length],  
                     @nWidth  = Width,  
                     @nHeight = Height,  
                     @nStdGrossWgt = StdGrossWgt,  
                     @nStdCube = StdCube  
              FROM dbo.SKU WITH (NOLOCK)  
              WHERE Storerkey = @cStorerKey  
              AND   SKU = @cParentSKU  
  
           --prepare LWH screen var  
              IF @nLength > 0  
              BEGIN  
                 SET @cFieldAttr01 = 'O'  
                 SET @cOutField01 = CAST(@nLength AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField01 = ''  
                 EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
  
              IF @nWidth > 0  
              BEGIN  
                 SET @cFieldAttr02 = 'O'  
                 SET @cOutField02 = CAST(@nWidth AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField02 = ''  
              END  
  
      IF @nHeight > 0  
              BEGIN  
             SET @cFieldAttr03 = 'O'  
                 SET @cOutField03 = CAST(@nHeight AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField03 = ''  
              END  
  
              IF @nStdGrossWgt > 0  
              BEGIN  
                 SET @cFieldAttr04 = 'O'  
                 SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField04 = ''  
              END  
  
              IF @nLength = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
              ELSE IF @nWidth = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 02  
              END  
              ELSE IF @nHeight = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 03  
              END  
              ELSE IF @nStdGrossWgt = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 04  
              END  
  
       -- Go to LWH Screen   
               IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  
               BEGIN  
                  --prepare Label screen var  
                SET @cOutField01 = @cParentSKU  
                SET @cOutField02 = ''  
  
                  SET @cFieldAttr01 = ''  
                  SET @cFieldAttr02 = ''  
                  SET @cFieldAttr03 = ''  
                  SET @cFieldAttr04 = ''  
  
                  -- Go to Label Screen   
                  SET @nScn = @nScn_PrintLabel  
                  SET @nStep = @nStep_PrintLabel  
               END  
               ELSE  
               BEGIN  
          SET @nScn = @nScn_LWH  
          SET @nStep = @nStep_LWH  
               END  
              -- (Vicky06) Length, Width, Height - End  
  
--         --prepare Label screen var  
--       SET @cOutField01 = @cParentSKU  
--       SET @cOutField02 = ''  
      
--       -- Go to Label Screen   
--       SET @nScn = @nScn_PrintLabel  
--       SET @nStep = @nStep_PrintLabel  
    
           SET @nPrevScn = @nScn_Inner  
           SET @nPrevStep = @nStep_Inner  
             END  
     ELSE  
     BEGIN  
           ROLLBACK TRAN  
           SET @nErrNo = 63412  
       SET @cErrMsg = rdt.rdtgetmessage( 63412, @cLangCode, 'DSP') -- Update Fail  
               GOTO Inner_Fail  
         END  
         END  -- Result = 0  
         ELSE  
         BEGIN -- Result = 1  
  
           -- Check matching Packkey  
            -- (Vicky04) - Add new parameter @cUsername  
          EXEC RDT.rdt_BOM_Packkey_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @nInnerPack, @nCaseCnt,  
                                              @nShipper, @nPallet, @nMatchFound OUTPUT, @cMatchSKU OUTPUT, @cParentExt -- (Vicky05)  
     
  
            IF @nMatchFound > 0  
            BEGIN  
                -- (Vicky05) - Start  
                IF @cSysParentSKU = '' AND @cParentExt <> '1'  
                BEGIN  
                    SET @nErrNo = 67264  
                SET @cErrMsg = rdt.rdtgetmessage( 67264, @cLangCode, 'DSP') -- Pack for other  
                    GOTO Inner_Fail  
                END  
                -- (Vicky05) - End  
  
                -- Match BOM, Packkey Found  
                -- Update RDT.rdtBOMCreationLog   
              UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
               SET Status = '5',  
                       ParentSKU = @cMatchSKU --@cParentSKU  
            WHERE ParentSKU = @cParentSKU  
            AND   Status = '0'  
            AND   MobileNo = @nMobile  
            AND   UserName = @cUserName  
              AND   Storerkey = @cStorerKey  
   
              IF @@ERROR = 0  
              BEGIN  
        COMMIT TRAN  
  
                     -- Set ParentSKU = Matched SKU                  
                     SET @cParentSKU = RTRIM(@cMatchSKU)  
  
                      -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
     @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cMatchSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
        BEGIN  
           EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
               -- Go to LWH Screen   
                       IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  
                       BEGIN  
                          --prepare Label screen var  
                        SET @cOutField01 = @cParentSKU  
                        SET @cOutField02 = ''  
  
                          SET @cFieldAttr01 = ''  
                          SET @cFieldAttr02 = ''  
                          SET @cFieldAttr03 = ''  
                          SET @cFieldAttr04 = ''  
  
                          -- Go to Label Screen   
                          SET @nScn = @nScn_PrintLabel  
                          SET @nStep = @nStep_PrintLabel  
                       END  
                       ELSE  
                       BEGIN  
                  SET @nScn = @nScn_LWH  
                  SET @nStep = @nStep_LWH  
                       END  
                       -- (Vicky06) Length, Width, Height - End  
  
                    
--                    --prepare Label screen var  
--            SET @cOutField01 = @cMatchSKU --'stop'--@cParentSKU  
--            SET @cOutField02 = ''  
--  
--              -- Go to Label Screen   
--            SET @nScn = @nScn_PrintLabel  
--            SET @nStep = @nStep_PrintLabel  
--        
                SET @nPrevScn = @nScn_Inner  
                SET @nPrevStep = @nStep_Inner  
              END  
            ELSE  
      BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 63413  
            SET @cErrMsg = rdt.rdtgetmessage( 63413, @cLangCode, 'DSP') -- Update Fail  
                GOTO Inner_Fail  
        END  
            END -- @nMatchFound > 0  
            ELSE  
            BEGIN  
                 IF @cParentExt = '1' -- (Vicky05)  
                 BEGIN   
                     SET @nErrNo = 67260  
                 SET @cErrMsg = rdt.rdtgetmessage( 67260, @cLangCode, 'DSP') -- Pack not match  
                     GOTO Inner_Fail  
                 END  
                 ELSE  
                 BEGIN  
                    IF @cSysParentSKU <> '' -- (Vicky05)  
                    BEGIN  
                         --SELECT @cSuffix = RIGHT(MAX(RTRIM(BOM.SKU)),3)  
--                         SELECT @cSuffix = MAX(RIGHT(RTRIM(BOM.SKU),3))  -- LARRY01  
--                         FROM dbo.BillOfMaterial BOM WITH (NOLOCK)  
--                         JOIN dbo.SKU SKU WITH (NOLOCK)  
--                            ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)  
--                         WHERE BOM.Storerkey = @cStorerKey  
--                         --AND   SKU.Style = @cStyle  
--                           AND LEFT(RTRIM(SKU.Style),10) = LEFT(RTRIM(@cStyle),10) -- LARRY01  
--  
--                         SELECT @nSuffix = CAST(ISNULL(@cSuffix, '0') as INT) + 1  
--                                              
--                         SELECT @cParentSKU = LEFT(RTRIM(@cStyle), 10) + RIGHT(RTRIM(REPLICATE(0,3) + CAST(@nSuffix as CHAR)), 3) -- (Vicky03)  
  
                         -- (Vicky08) - Start  
                         EXEC dbo.isp_GetNextParentSKU     
                              @c_Storerkey    = @cStorerKey,     
                              @c_Style        = @cStyle,    
                              @c_NewParentSKU = @cParentSKU OUTPUT  
  
                         IF @cParentSKU = ''  
                         BEGIN  
                           SET @nErrNo = 69542  
                           SET @cErrMsg = rdt.rdtgetmessage(69542, @cLangCode, 'DSP') --ErrGenParentSKU  
                           GOTO Inner_Fail   
                         END  
                         -- (Vicky08) - End  
  
                         UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                            SET ParentSKU = @cParentSKU  
           WHERE Style = @cStyle  
                         AND   Status = '0'  
                         AND   MobileNo = @nMobile  
                         AND   UserName = @cUserName -- (Vicky04)  
                     END  
    
                     -- SET @cPackkey = RIGHT(RTRIM(@cParentSKU), 10) -- Comment By (Vicky05)  
  
                    -- (Vicky05) - Start - Assign Packkey  
                      SELECT @b_success=0  
                      EXECUTE   nspg_getkey  
                      'BOMPACK'  
                      , 7  
                      , @c_BOMPackKey OUTPUT  
                      , @b_success OUTPUT  
                      , @n_err OUTPUT  
                      , @c_errmsg OUTPUT  
                      IF @b_success=0  
                      BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 67253  
                        SET @cErrMsg = rdt.rdtgetmessage( 67253, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO Inner_Fail  
                      END  
                     
                    SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
                    -- (Vicky05) - End - Assign Packkey  
  
  
                  -- Insert SKU, BOM   
                    -- (Vicky04) - Add new Parameter @cUserName  
                  EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
       
                  IF @nErrNo <> 0  
                   GOTO Inner_Fail  
  
                    IF EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK) WHERE PackKey = @cPackkey)  
                    BEGIN  
                       ROLLBACK TRAN  
                       SET @nErrNo = 70476  
 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackkeyErr  
                       GOTO Option_Fail  
                    END  
  
                  -- Insert Pack Table (1 Record for ParentSKU)  
                INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM2, InnerPack, PACKUOM3, QTY)  
                VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END,   
                       @nInnerPack, 'PK', 1)  
       
                  -- Insert UPC (1 Record for ParentSKU)  
                  IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
                    (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
                  BEGIN  
         -- Added by (Ricky_1.19)  
         INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
         VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'IP' END,   
           @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'IP')  
  
         /* -- Commented by (Ricky_1.19)  
         INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
         VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'IP')  
         */   
                  END  
       
                  -- Update RDT.rdtBOMCreationLog   
                  UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                   SET Status = '9'  
                WHERE ParentSKU = @cParentSKU  
                AND   Status = '0'  
                AND   MobileNo = @nMobile  
                AND   UserName = @cUserName  
                  AND   Storerkey = @cStorerKey  
       
                  IF @@ERROR = 0  
                  BEGIN  
            COMMIT TRAN  
  
                       -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                      EXEC rdt.rdtSetFocusField @nMobile, 02  
    END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
                      -- Go to LWH Screen   
                      IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  
                      BEGIN  
                         --prepare Label screen var  
                       SET @cOutField01 = @cParentSKU  
                       SET @cOutField02 = ''  
  
                         SET @cFieldAttr01 = ''  
                         SET @cFieldAttr02 = ''  
                         SET @cFieldAttr03 = ''  
                         SET @cFieldAttr04 = ''  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                      END  
                      ELSE  
                      BEGIN  
                 SET @nScn = @nScn_LWH  
                 SET @nStep = @nStep_LWH  
                      END  
                      -- (Vicky06) Length, Width, Height - End  
       
--              --prepare Label screen var  
--            SET @cOutField01 = @cParentSKU  
--            SET @cOutField02 = ''  
--           
--            -- Go to Label Screen   
--            SET @nScn = @nScn_PrintLabel  
--            SET @nStep = @nStep_PrintLabel  
         
                SET @nPrevScn = @nScn_Inner  
                SET @nPrevStep = @nStep_Inner  
                  END  
          ELSE  
          BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 63415  
                SET @cErrMsg = rdt.rdtgetmessage( 63415, @cLangCode, 'DSP') -- Update Fail  
                    GOTO Inner_Fail  
                  END  
                 END -- @cParentExt = 0  
             END -- Matchfound = 0  
         END -- Result = 1  
      END -- = 2  
  
      GOTO Quit  
   END  
  
    
   IF @nInputKey = 0 -- ESC  
   BEGIN    
      -- Prepare option screen var  
         SET @cOutField01 = '1'  
         SET @cOutField02 = ''   
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
  
         SET @cInnerPack = ''  
         SET @nInnerPack = 0  
         SET @cOptionInner = ''  
         SET @nMatchFound = 0  
         SET @cMatchSKU = ''  
  
      -- Go Option Screen   
         IF rdt.RDTGetConfig( @nFunc, 'DIFFOPTSCN', @cStorerKey) = 1  
         BEGIN  
            SET @nScn = @nScn_Option2  
            SET @nStep = @nStep_Option  
         END  
         ELSE  
      BEGIN  
            SET @nScn = @nScn_Option  
            SET @nStep = @nStep_Option  
         END  
  
         SET @nPrevScn = @nScn_Inner  
         SET @nPrevStep = @nStep_Inner  
   END  
     
   GOTO Quit  
  
  
   Inner_Fail:  
   BEGIN  
      SET @cOutField01 = '' --#   
      SET @cOutField02 = '1'  
      SET @cOptionInner = ''  
      --SET @nMatchFound = 0  
      SET @cMatchSKU = ''  
   END  
   
END  
GOTO Quit  
  
  
/********************************************************************************  
Scn = 1505. Case screen  
   Case    (field01, input)  
   Option  (field02, input)  
********************************************************************************/  
Step_Case:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
   
      SET @cCase = @cInField01  
      SET @cOptionCase = @cInField02  
  
    IF @cCase  = '' SET @cCase  = '0' -- Blank taken as zero  
  
      IF RDT.rdtIsValidQTY( @cCase, 0) = 0  
    BEGIN  
          SET @nErrNo = 63416  
          SET @cErrMsg = rdt.rdtgetmessage( 63416, @cLangCode, 'DSP') --Invalid Number  
          EXEC rdt.rdtSetFocusField @nMobile, 05 -- #  
          GOTO Case_Fail  
    END  
  
      -- Check if option is blank  
      IF @cOptionCase = '' OR @cOptionCase IS NULL  
      BEGIN  
         SET @nErrNo = 63417  
         SET @cErrMsg = rdt.rdtgetmessage(63417, @cLangCode, 'DSP') --Option required   
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Option   
         GOTO Case_Fail        
      END        
  
      -- Invalid option other than '1' or '2'  
      IF (@cOptionCase <> '1' AND @cOptionCase <> '2')   
    BEGIN  
         SET @nErrNo = 63418  
         SET @cErrMsg = rdt.rdtgetmessage(63418, @cLangCode, 'DSP') --Invalid option  
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Option   
         GOTO Case_Fail        
      END        
  
      SET @nCaseCnt = CAST(@cCase as INT)  
  
      IF @cOptionCase = '1'  
      BEGIN  
          IF @nCaseCnt > 0  
          BEGIN  
            IF @nInnerPack > 0  
            BEGIN  
               SELECT @nCaseCnt = @nInnerPack * @nCaseCnt  
            END  
          END    
  
        --prepare Shipper screen var  
        SET @cOutField01 = ''  
        SET @cOutField02 = '1'  -- anymore packs?  
   
        -- Go to Shipper Screen   
        SET @nScn = @nScn_Shipper  
      SET @nStep = @nStep_Shipper  
          EXEC rdt.rdtSetFocusField @nMobile, 04 -- #  
  
        SET @nPrevScn = @nScn_Case  
      SET @nPrevStep = @nStep_Case  
      END  
  
      IF @cOptionCase = '2' -- No more packs  
      BEGIN  
        IF @nCaseCnt > 0  
        BEGIN  
          IF @nInnerPack > 0  
          BEGIN  
             SELECT @nCaseCnt = @nInnerPack * @nCaseCnt  
          END  
        END    
  
         -- No match found, insert BOM, SKU, UPC, Packkey  
          IF @cResult = '0'  
          BEGIN  
             BEGIN TRAN  
  
            -- (Vicky05) - Start - Assign Packkey  
              SELECT @b_success=0  
              EXECUTE   nspg_getkey  
              'BOMPACK'  
              , 7  
              , @c_BOMPackKey OUTPUT  
              , @b_success OUTPUT  
              , @n_err OUTPUT  
              , @c_errmsg OUTPUT  
              IF @b_success=0  
              BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 67254  
                SET @cErrMsg = rdt.rdtgetmessage( 67254, @cLangCode, 'DSP') -- PackkeyErr  
                GOTO Inner_Fail  
              END  
             
            SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
            -- (Vicky05) - End - Assign Packkey  
  
             -- Insert SKU, BOM   
             -- (Vicky04) - Add new Parameter @cUserName  
             EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
             IF @nErrNo <> 0  
             BEGIN  
          SET @cErrMsg = @cErrMsg  
              GOTO Case_Fail  
             END  
  
             IF EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK) WHERE PackKey = @cPackkey)  
             BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 70477  
                SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackkeyErr  
                GOTO Inner_Fail  
             END  
  
             -- Insert Pack Table (1 Record for ParentSKU)  
           INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM2, InnerPack, PACKUOM3, QTY)  
           VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END,  
                  @nCaseCnt, CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END, @nInnerPack, 'PK', 1)  
  
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
             (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
             BEGIN  
              INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
              VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'IP')  
             END  
                            
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
             (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
             BEGIN  
              INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
--              VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  -- Shong  
              VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END,   
                     @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
             END  
  
             -- Update RDT.rdtBOMCreationLog   
             UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
              SET Status = '9'  
           WHERE ParentSKU = @cParentSKU  
           AND   Status = '0'  
           AND   MobileNo = @nMobile  
           AND   UserName = @cUserName  
             AND   Storerkey = @cStorerKey  
  
             IF @@ERROR = 0  
             BEGIN  
       COMMIT TRAN  
  
              -- (Vicky06) Length, Width, Height - Start  
              SELECT @nLength = [Length],  
                     @nWidth  = Width,  
                     @nHeight = Height,  
                     @nStdGrossWgt = StdGrossWgt,  
                     @nStdCube = StdCube  
              FROM dbo.SKU WITH (NOLOCK)  
              WHERE Storerkey = @cStorerKey  
              AND   SKU = @cParentSKU  
  
           --prepare LWH screen var  
              IF @nLength > 0  
              BEGIN  
                 SET @cFieldAttr01 = 'O'  
                 SET @cOutField01 = CAST(@nLength AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField01 = ''  
                 EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
  
              IF @nWidth > 0  
              BEGIN  
                 SET @cFieldAttr02 = 'O'  
                 SET @cOutField02 = CAST(@nWidth AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField02 = ''  
              END  
  
              IF @nHeight > 0  
              BEGIN  
                 SET @cFieldAttr03 = 'O'  
                 SET @cOutField03 = CAST(@nHeight AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField03 = ''  
              END  
  
              IF @nStdGrossWgt > 0  
              BEGIN  
                 SET @cFieldAttr04 = 'O'  
                 SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField04 = ''  
              END  
  
              IF @nLength = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
              ELSE IF @nWidth = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 02  
              END  
              ELSE IF @nHeight = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 03  
              END  
              ELSE IF @nStdGrossWgt = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 04  
              END  
  
              -- Go to LWH Screen   
              IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
              BEGIN  
                 --prepare Label screen var  
               SET @cOutField01 = @cParentSKU  
               SET @cOutField02 = ''  
  
                 SET @cFieldAttr01 = ''  
                 SET @cFieldAttr02 = ''  
                 SET @cFieldAttr03 = ''  
                 SET @cFieldAttr04 = ''  
  
                 -- Go to Label Screen   
                 SET @nScn = @nScn_PrintLabel  
                 SET @nStep = @nStep_PrintLabel  
              END  
              ELSE  
              BEGIN  
          SET @nScn = @nScn_LWH  
          SET @nStep = @nStep_LWH  
              END  
              -- (Vicky06) Length, Width, Height - End  
  
--         --prepare Label screen var  
--       SET @cOutField01 = @cParentSKU  
--       SET @cOutField02 = ''  
--      
--       -- Go to Label Screen   
--       SET @nScn = @nScn_PrintLabel  
--       SET @nStep = @nStep_PrintLabel  
    
           SET @nPrevScn = @nScn_Case  
           SET @nPrevStep = @nStep_Case  
             END  
     ELSE  
     BEGIN  
           ROLLBACK TRAN  
           SET @nErrNo = 63419  
           SET @cErrMsg = rdt.rdtgetmessage( 63419, @cLangCode, 'DSP') -- Update Fail  
               GOTO Case_Fail  
         END  
         END  -- Result = 0  
         ELSE  
         BEGIN -- Result = 1  
          -- Check matching Packkey  
            -- (Vicky04) - Add new Parameter @cUserName  
          EXEC RDT.rdt_BOM_Packkey_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @nInnerPack, @nCaseCnt,  
                                              @nShipper, @nPallet, @nMatchFound OUTPUT, @cMatchSKU OUTPUT, @cParentExt -- (Vicky05)  
  
   
            IF @nMatchFound > 0  
            BEGIN  
                -- (Vicky05) - Start  
                IF @cSysParentSKU = '' AND @cParentExt <> '1'  
                BEGIN  
                    SET @nErrNo = 67265  
                SET @cErrMsg = rdt.rdtgetmessage( 67265, @cLangCode, 'DSP') -- Pack for other  
                    GOTO Inner_Fail  
                END  
                -- (Vicky05) - End  
  
                -- Match BOM, Packkey Found  
                -- Update RDT.rdtBOMCreationLog   
              UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
               SET Status = '5',  
                       ParentSKU = @cMatchSKU --@cParentSKU  
            WHERE ParentSKU = @cParentSKU  
            AND   Status = '0'  
            AND   MobileNo = @nMobile  
            AND   UserName = @cUserName  
              AND   Storerkey = @cStorerKey  
   
              IF @@ERROR = 0  
              BEGIN  
        COMMIT TRAN  
  
                     -- Set ParentSKU = Matched SKU                  
                     SET @cParentSKU = RTRIM(@cMatchSKU)  
  
                      -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
              -- Go to LWH Screen   
                      IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
                      BEGIN  
                         --prepare Label screen var  
                       SET @cOutField01 = @cParentSKU  
                       SET @cOutField02 = ''  
  
                         SET @cFieldAttr01 = ''  
                         SET @cFieldAttr02 = ''  
                         SET @cFieldAttr03 = ''  
                         SET @cFieldAttr04 = ''  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                      END  
                      ELSE  
                      BEGIN  
                 SET @nScn = @nScn_LWH  
                 SET @nStep = @nStep_LWH  
                      END  
                      -- (Vicky06) Length, Width, Height - End  
  
--                --prepare Label screen var  
--        SET @cOutField01 = @cParentSKU  
--        SET @cOutField02 = ''  
--      
--          -- Go to Label Screen   
--        SET @nScn = @nScn_PrintLabel  
--        SET @nStep = @nStep_PrintLabel  
    
          SET @nPrevScn = @nScn_Case  
          SET @nPrevStep = @nStep_Case  
               END  
             ELSE  
       BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 63420  
            SET @cErrMsg = rdt.rdtgetmessage( 63420, @cLangCode, 'DSP') -- Update Fail  
                GOTO Case_Fail  
         END  
            END  
            ELSE  
            BEGIN  
                 IF @cParentExt = '1' -- (Vicky05)   
                 BEGIN   
                     SET @nErrNo = 67261  
                 SET @cErrMsg = rdt.rdtgetmessage( 67261, @cLangCode, 'DSP') -- Pack not match  
                     GOTO Inner_Fail  
                 END  
                 ELSE  
                 BEGIN  
                    IF @cSysParentSKU <> '' -- (Vicky05)  
                    BEGIN  
                         --SELECT @cSuffix = RIGHT(MAX(RTRIM(BOM.SKU)),3)  
--                         SELECT @cSuffix = MAX(RIGHT(RTRIM(BOM.SKU),3)) -- LARRY01  
--                         FROM dbo.BillOfMaterial BOM WITH (NOLOCK)  
--                         JOIN dbo.SKU SKU WITH (NOLOCK)  
--                            ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)  
--                         WHERE BOM.Storerkey = @cStorerKey  
--                         --AND   SKU.Style = @cStyle  
--                           AND LEFT(RTRIM(SKU.Style),10) = LEFT(RTRIM(@cStyle),10)  -- LARRY01  
--  
--                         SELECT @nSuffix = CAST(ISNULL(@cSuffix, '0') as INT) + 1  
--                                              
--                         SELECT @cParentSKU = LEFT(RTRIM(@cStyle), 10) + RIGHT(RTRIM(REPLICATE(0,3) + CAST(@nSuffix as CHAR)), 3) -- (Vicky03)  
  
    -- (Vicky08) - Start  
                         EXEC dbo.isp_GetNextParentSKU    
                              @c_Storerkey    = @cStorerKey,     
                              @c_Style        = @cStyle,    
                              @c_NewParentSKU = @cParentSKU OUTPUT  
  
                         IF @cParentSKU = ''  
                         BEGIN  
                           SET @nErrNo = 69543  
                           SET @cErrMsg = rdt.rdtgetmessage(69543, @cLangCode, 'DSP') --ErrGenParentSKU  
                           GOTO Inner_Fail   
                         END  
                         -- (Vicky08) - End  
  
    UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                            SET ParentSKU = @cParentSKU  
                         WHERE Style = @cStyle  
                         AND   Status = '0'  
                         AND   MobileNo = @nMobile  
                         AND   UserName = @cUserName -- (Vicky04)  
                   END  
                     -- SET @cPackkey = RIGHT(RTRIM(@cParentSKU), 10) -- Comment By (Vicky05)  
  
                   -- (Vicky05) - Start - Assign Packkey  
                   SELECT @b_success=0  
                   EXECUTE   nspg_getkey  
                      'BOMPACK'  
                      , 7  
                      , @c_BOMPackKey OUTPUT  
                      , @b_success OUTPUT  
                      , @n_err OUTPUT  
                      , @c_errmsg OUTPUT  
                      IF @b_success=0  
                      BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 67255  
                        SET @cErrMsg = rdt.rdtgetmessage( 67255, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO Inner_Fail  
                      END  
                     
                    SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
                    -- (Vicky05) - End - Assign Packkey  
  
                  -- Insert SKU, BOM   
                    -- (Vicky04) - Add new Parameter @cUserName  
                  EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
       
                  IF @nErrNo <> 0  
                  BEGIN  
               SET @cErrMsg = @cErrMsg  
                   GOTO Case_Fail  
                  END  
  
                    IF EXISTS (SELECT 1 FROM dbo.PACK WITH (NOLOCK) WHERE PackKey = @cPackkey)  
                    BEGIN  
                       ROLLBACK TRAN  
                       SET @nErrNo = 70475  
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PackkeyErr  
                       GOTO Inner_Fail  
                    END  
  
                  -- Insert Pack Table (1 Record for ParentSKU)  
                INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM2, InnerPack, PACKUOM3, QTY)  
                VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END,  
                       @nCaseCnt, CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END, @nInnerPack, 'PK', 1)  
       
                  -- Insert UPC (1 Record for ParentSKU)  
                  IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
                    (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
                  BEGIN  
                   INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                   VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'IP')  
                  END  
                                 
                  -- Insert UPC (1 Record for ParentSKU)  
                  IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
                    (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
                  BEGIN  
                   INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
--                   VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS') 1.17 Shong  
                   VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END, @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
                  END  
       
                  -- Update RDT.rdtBOMCreationLog   
                  UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                   SET Status = '9'  
                WHERE ParentSKU = @cParentSKU  
                AND   Status = '0'  
                AND   MobileNo = @nMobile  
            AND   UserName = @cUserName  
                  AND   Storerkey = @cStorerKey  
       
                  IF @@ERROR = 0  
                  BEGIN  
            COMMIT TRAN  
  
                      -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
              -- Go to LWH Screen   
                      IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1   -- (james01)  
                      BEGIN  
                         --prepare Label screen var  
                       SET @cOutField01 = @cParentSKU  
                       SET @cOutField02 = ''  
  
                         SET @cFieldAttr01 = ''  
                         SET @cFieldAttr02 = ''  
                         SET @cFieldAttr03 = ''  
                         SET @cFieldAttr04 = ''  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                      END  
                      ELSE  
                      BEGIN  
                 SET @nScn = @nScn_LWH  
                 SET @nStep = @nStep_LWH  
                      END  
                      -- (Vicky06) Length, Width, Height - End  
       
--              --prepare Label screen var  
--            SET @cOutField01 = @cParentSKU  
--            SET @cOutField02 = ''  
--           
--            -- Go to Label Screen   
--            SET @nScn = @nScn_PrintLabel  
--            SET @nStep = @nStep_PrintLabel  
         
                SET @nPrevScn = @nScn_Case  
                  SET @nPrevStep = @nStep_Case  
                 END  
             ELSE  
         BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 63422  
                SET @cErrMsg = rdt.rdtgetmessage( 63422, @cLangCode, 'DSP') -- Update Fail  
                    GOTO Case_Fail  
             END  
              END -- @cParentExt = 0  
          END -- Matchfound = 0  
       END -- Result = 1  
    END -- = 2  
  
      GOTO Quit  
   END  
  
    
   IF @nInputKey = 0 -- ESC  
   BEGIN    
    -- Prepare InnerPack screen var  
       SET @cOutField01 = @cInnerPack  
       SET @cOutField02 = '1'   
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
  
         SET @cCase = ''  
         SET @nCaseCnt = 0  
       SET @cOptionCase = ''  
         SET @nMatchFound = 0  
         SET @cMatchSKU = ''  
  
       -- Set InnerPack screen  
       SET @nScn = @nScn_Inner  
       SET @nStep = @nStep_Inner  
   END  
     
   GOTO Quit  
  
   Case_Fail:  
   BEGIN  
      SET @cOutField01 = '' --#   
      SET @cOutField02 = '1'  
      SET @cOptionCase = ''  
      SET @nMatchFound = 0  
      SET @cMatchSKU = ''  
   END  
   
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 1506. Shipper screen  
   Shipper (field01, input)  
   Option  (field02, input)  
********************************************************************************/  
Step_Shipper:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
   
      SET @cShipper = @cInField01  
      SET @cOptionShipper = @cInField02  
  
    IF @cShipper  = '' SET @cShipper  = '0' -- Blank taken as zero  
  
      IF RDT.rdtIsValidQTY( @cShipper, 0) = 0  
    BEGIN  
          SET @nErrNo = 63423  
          SET @cErrMsg = rdt.rdtgetmessage( 63423, @cLangCode, 'DSP') --Invalid Number  
          EXEC rdt.rdtSetFocusField @nMobile, 05 -- #  
          GOTO Shipper_Fail  
    END  
  
      -- Check if option is blank  
      IF @cOptionShipper = '' OR @cOptionShipper IS NULL  
      BEGIN  
         SET @nErrNo = 63424  
         SET @cErrMsg = rdt.rdtgetmessage(63424, @cLangCode, 'DSP') --Option required   
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Option   
         GOTO Shipper_Fail        
      END        
  
      -- Invalid option other than '1' or '2'  
      IF (@cOptionShipper <> '1' AND @cOptionShipper <> '2')   
    BEGIN  
         SET @nErrNo = 63425  
         SET @cErrMsg = rdt.rdtgetmessage(63425, @cLangCode, 'DSP') --Invalid option  
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Option   
         GOTO Shipper_Fail        
      END        
  
      SET @nShipper = CAST(@cShipper as INT)  
  
      IF @cOptionShipper = '1'  
      BEGIN  
         IF @nShipper > 0  
         BEGIN  
           IF @nCaseCnt > 0  
           BEGIN  
             SELECT @nShipper = @nCaseCnt * @nShipper   
           END  
           ELSE  
           BEGIN  
             IF @nInnerPack > 0  
             BEGIN  
                SELECT @nShipper = @nInnerPack * @nShipper  
             END  
           END    
         END  
  
        --prepare Shipper screen var  
        SET @cOutField01 = ''  
        SET @cOutField02 = '1'  -- anymore packs?  
  
   
        -- Go to Pallet Screen   
        SET @nScn = @nScn_Pallet  
      SET @nStep = @nStep_Pallet  
          EXEC rdt.rdtSetFocusField @nMobile, 04 -- #  
  
          SET @nPrevScn = @nScn_Shipper  
        SET @nPrevStep = @nStep_Shipper  
    END  
  
  
    IF @cOptionShipper = '2' -- No more packs  
    BEGIN  
        IF @nShipper > 0  
        BEGIN  
            IF @nCaseCnt > 0  
            BEGIN  
              SELECT @nShipper = @nCaseCnt * @nShipper   
            END  
            ELSE  
            BEGIN  
              IF @nInnerPack > 0  
              BEGIN  
                 SELECT @nShipper = @nInnerPack * @nShipper  
              END  
            END    
         END  
     
           -- No match found, insert BOM, SKU, UPC, Packkey  
          IF @cResult = '0'  
          BEGIN  
            BEGIN TRAN  
  
            -- (Vicky05) - Start - Assign Packkey  
            SELECT @b_success=0  
            EXECUTE   nspg_getkey  
            'BOMPACK'  
            , 7  
            , @c_BOMPackKey OUTPUT  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
            IF @b_success=0  
            BEGIN  
               ROLLBACK TRAN  
               SET @nErrNo = 67256  
               SET @cErrMsg = rdt.rdtgetmessage( 67256, @cLangCode, 'DSP') -- PackkeyErr  
               GOTO Inner_Fail  
            END  
             
            SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
            -- (Vicky05) - End - Assign Packkey  
  
             -- Insert SKU, BOM   
             -- (Vicky04) - Add new Parameter @cUserName  
             EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
             IF @nErrNo <> 0  
              GOTO Shipper_Fail  
             
             -- Insert Pack Table (1 Record for ParentSKU)  
           INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM2, InnerPack,  
                                         PACKUOM8, OtherUnit1, PACKUOM3, QTY)  
           VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey),   
                    CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END, @nCaseCnt,  
                    CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END, @nInnerPack,   
                    CASE WHEN @nShipper > 0 THEN 'SH' ELSE '' END,   
                  @nShipper, 'PK', 1)  
  
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
             (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
             BEGIN  
              INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
              VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, @cParentSKU, @cPackkey, 'IP')  
             END  
  
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
             (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
             BEGIN  
              INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
--              VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, @cParentSKU, @cPackkey, 'CS') 1.17 Shong  
              VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END, @cStorerKey, @cParentSKU, @cPackkey, 'CS')  
             END  
                
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nShipper > 0 AND NOT EXISTS -- (james04)    
             (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'SH' AND StorerKey = @cStorerKey)    
             BEGIN  
              INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
              VALUES(RTRIM(@cParentSKU) + 'SH', @cStorerKey, @cParentSKU, @cPackkey, 'SH')  
             END  
  
             -- Update RDT.rdtBOMCreationLog   
             UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
              SET Status = '9'  
           WHERE ParentSKU = @cParentSKU  
           AND   Status = '0'  
           AND   MobileNo = @nMobile  
           AND   UserName = @cUserName  
             AND   Storerkey = @cStorerKey  
  
             IF @@ERROR = 0  
             BEGIN  
       COMMIT TRAN  
  
              -- (Vicky06) Length, Width, Height - Start  
              SELECT @nLength = [Length],  
                     @nWidth  = Width,  
                     @nHeight = Height,  
                     @nStdGrossWgt = StdGrossWgt,  
                     @nStdCube = StdCube  
              FROM dbo.SKU WITH (NOLOCK)  
              WHERE Storerkey = @cStorerKey  
   AND   SKU = @cParentSKU  
  
           --prepare LWH screen var  
              IF @nLength > 0  
              BEGIN  
                 SET @cFieldAttr01 = 'O'  
                 SET @cOutField01 = CAST(@nLength AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField01 = ''  
                 EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
  
              IF @nWidth > 0  
              BEGIN  
                 SET @cFieldAttr02 = 'O'  
                 SET @cOutField02 = CAST(@nWidth AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField02 = ''  
              END  
  
              IF @nHeight > 0  
              BEGIN  
                 SET @cFieldAttr03 = 'O'  
                 SET @cOutField03 = CAST(@nHeight AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField03 = ''  
              END  
  
              IF @nStdGrossWgt > 0  
              BEGIN  
                 SET @cFieldAttr04 = 'O'  
                 SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField04 = ''  
              END  
  
              IF @nLength = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
              ELSE IF @nWidth = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 02  
              END  
              ELSE IF @nHeight = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 03  
              END  
              ELSE IF @nStdGrossWgt = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 04  
              END  
  
      -- Go to LWH Screen   
              IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
              BEGIN  
                 --prepare Label screen var  
                 SET @cOutField01 = @cParentSKU  
                 SET @cOutField02 = ''  
  
                 SET @cFieldAttr01 = ''  
                 SET @cFieldAttr02 = ''  
                 SET @cFieldAttr03 = ''  
                 SET @cFieldAttr04 = ''  
  
                 -- Go to Label Screen   
                 SET @nScn = @nScn_PrintLabel  
                 SET @nStep = @nStep_PrintLabel  
              END  
              ELSE  
              BEGIN  
         SET @nScn = @nScn_LWH  
         SET @nStep = @nStep_LWH  
              END  
              -- (Vicky06) Length, Width, Height - End  
  
--         --prepare Label screen var  
--       SET @cOutField01 = @cParentSKU  
--       SET @cOutField02 = ''  
--      
--       -- Go to Label Screen   
--       SET @nScn = @nScn_PrintLabel  
--       SET @nStep = @nStep_PrintLabel  
    
           SET @nPrevScn = @nScn_Shipper  
           SET @nPrevStep = @nStep_Shipper  
             END  
     ELSE  
     BEGIN  
           ROLLBACK TRAN  
           SET @nErrNo = 63426  
           SET @cErrMsg = rdt.rdtgetmessage( 63426, @cLangCode, 'DSP') -- Update Fail  
               GOTO Shipper_Fail  
         END  
         END  -- Result = 0  
         ELSE  
         BEGIN -- Result = 1  
          -- Check matching Packkey  
            -- (Vicky04) - Add new Parameter @cUserName  
          EXEC RDT.rdt_BOM_Packkey_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @nInnerPack, @nCaseCnt,  
                                              @nShipper, @nPallet, @nMatchFound OUTPUT, @cMatchSKU OUTPUT, @cParentExt -- (Vicky05)  
  
            IF @nMatchFound > 0  
            BEGIN  
                -- (Vicky05) - Start  
                IF @cSysParentSKU = '' AND @cParentExt <> '1'  
                BEGIN  
                    SET @nErrNo = 67266  
                SET @cErrMsg = rdt.rdtgetmessage( 67266, @cLangCode, 'DSP') -- Pack for other  
                    GOTO Inner_Fail  
                END  
                -- (Vicky05) - End  
  
                -- Match BOM, Packkey Found  
                -- Update RDT.rdtBOMCreationLog   
            UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
               SET Status = '5',  
                       ParentSKU = @cMatchSKU--@cParentSKU  
            WHERE ParentSKU = @cParentSKU  
            AND   Status = '0'  
            AND   MobileNo = @nMobile  
            AND   UserName = @cUserName  
              AND   Storerkey = @cStorerKey  
   
              IF @@ERROR = 0  
              BEGIN  
        COMMIT TRAN  
  
                     -- Set ParentSKU = Matched SKU                  
                   SET @cParentSKU = RTRIM(@cMatchSKU)  
  
                      -- (Vicky06) Length, Width, Height - Start  
                   SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
               -- Go to LWH Screen   
                       IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
                       BEGIN  
                          --prepare Label screen var  
                        SET @cOutField01 = @cParentSKU  
                        SET @cOutField02 = ''  
  
                          SET @cFieldAttr01 = ''  
                          SET @cFieldAttr02 = ''  
                          SET @cFieldAttr03 = ''  
                          SET @cFieldAttr04 = ''  
  
                          -- Go to Label Screen   
                          SET @nScn = @nScn_PrintLabel  
                          SET @nStep = @nStep_PrintLabel  
                       END  
                       ELSE  
                       BEGIN  
                  SET @nScn = @nScn_LWH  
                  SET @nStep = @nStep_LWH  
                       END  
                      -- (Vicky06) Length, Width, Height - End  
--  
--                --prepare Label screen var  
--        SET @cOutField01 = @cParentSKU  
--        SET @cOutField02 = ''  
--      
--          -- Go to Label Screen   
--        SET @nScn = @nScn_PrintLabel  
--        SET @nStep = @nStep_PrintLabel  
    
          SET @nPrevScn = @nScn_Shipper  
          SET @nPrevStep = @nStep_Shipper  
             END  
           ELSE  
     BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 63427  
            SET @cErrMsg = rdt.rdtgetmessage( 63427, @cLangCode, 'DSP') -- Update Fail  
                GOTO Shipper_Fail  
       END  
            END  
            ELSE  
            BEGIN  
                 IF @cParentExt = '1' -- (Vicky05)  
                 BEGIN   
                     SET @nErrNo = 67262  
                 SET @cErrMsg = rdt.rdtgetmessage( 67262, @cLangCode, 'DSP') -- Pack not match  
                     GOTO Inner_Fail  
                 END  
                 ELSE  
                 BEGIN  
                    IF @cSysParentSKU <> '' -- (Vicky05)  
                    BEGIN  
                         --SELECT @cSuffix = RIGHT(MAX(RTRIM(BOM.SKU)),3)  
--                         SELECT @cSuffix = MAX(RIGHT(RTRIM(BOM.SKU),3)) -- LARRY01  
--                         FROM dbo.BillOfMaterial BOM WITH (NOLOCK)  
--                         JOIN dbo.SKU SKU WITH (NOLOCK)  
--                            ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)  
--                         WHERE BOM.Storerkey = @cStorerKey  
--                         --AND   SKU.Style = @cStyle  
--                           AND LEFT(RTRIM(SKU.Style),10) = LEFT(RTRIM(@cStyle),10) -- LARRY01  
--  
--                         SELECT @nSuffix = CAST(ISNULL(@cSuffix, '0') as INT) + 1  
--                                              
--                         SELECT @cParentSKU = LEFT(RTRIM(@cStyle), 10) + RIGHT(RTRIM(REPLICATE(0,3) + CAST(@nSuffix as CHAR)), 3) -- (Vicky03)  
  
                         -- (Vicky08) - Start  
                         EXEC dbo.isp_GetNextParentSKU     
                              @c_Storerkey    = @cStorerKey,     
                              @c_Style        = @cStyle,    
                              @c_NewParentSKU = @cParentSKU OUTPUT  
  
                         IF @cParentSKU = ''  
                         BEGIN  
                           SET @nErrNo = 69544  
                           SET @cErrMsg = rdt.rdtgetmessage(69544, @cLangCode, 'DSP') --ErrGenParentSKU  
                           GOTO Inner_Fail   
                         END  
                         -- (Vicky08) - End  
  
                         UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                            SET ParentSKU = @cParentSKU  
                         WHERE Style = @cStyle  
                         AND   Status = '0'  
                         AND   MobileNo = @nMobile  
                         AND   UserName = @cUserName -- (Vicky04)  
                    END  
  
                     --SET @cPackkey = RIGHT(RTRIM(@cParentSKU), 10) -- Comment By (Vicky05)  
  
                    -- (Vicky05) - Start - Assign Packkey  
                      SELECT @b_success=0  
                      EXECUTE   nspg_getkey  
                      'BOMPACK'  
                      , 7  
                      , @c_BOMPackKey OUTPUT  
                      , @b_success OUTPUT  
                      , @n_err OUTPUT  
                      , @c_errmsg OUTPUT  
                      IF @b_success=0  
                      BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 67257  
                        SET @cErrMsg = rdt.rdtgetmessage( 67257, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO Inner_Fail  
                      END  
                     
                    SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
   -- (Vicky05) - End - Assign Packkey  
  
                  -- Insert SKU, BOM   
                    -- (Vicky04) - Add new Parameter @cUserName  
                  EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
       
                  IF @nErrNo <> 0  
                  BEGIN  
               SET @cErrMsg = @cErrMsg  
                   GOTO Case_Fail  
                  END  
  
                  -- Insert Pack Table (1 Record for ParentSKU)  
                INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM2, InnerPack,  
                                              PACKUOM8, OtherUnit1, PACKUOM3, QTY)  
                VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey),   
                         CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END, @nCaseCnt,  
                         CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END, @nInnerPack,   
                         CASE WHEN @nShipper > 0 THEN 'SH' ELSE '' END,   
                       @nShipper, 'PK', 1)  
       
                    -- Insert UPC (1 Record for ParentSKU)  
                  IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
                    (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
                  BEGIN  
                   INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                   VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, @cParentSKU, @cPackkey, 'IP')  
                  END  
       
                  -- Insert UPC (1 Record for ParentSKU)  
                  IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
                    (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
                  BEGIN  
                   INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
--                   VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, @cParentSKU, @cPackkey, 'CS') 1.17 Shong  
                   VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END, @cStorerKey, @cParentSKU, @cPackkey, 'CS')  
                  END  
                     
                  -- Insert UPC (1 Record for ParentSKU)  
                  IF @nShipper > 0 AND NOT EXISTS -- (james04)    
                    (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'SH' AND StorerKey = @cStorerKey)    
                  BEGIN  
                   INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                   VALUES(RTRIM(@cParentSKU) + 'SH', @cStorerKey, @cParentSKU, @cPackkey, 'SH')  
                  END  
       
                  -- Update RDT.rdtBOMCreationLog   
                  UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                   SET Status = '9'  
                WHERE ParentSKU = @cParentSKU  
                AND   Status = '0'  
                AND   MobileNo = @nMobile  
                AND   UserName = @cUserName  
                  AND   Storerkey = @cStorerKey  
       
                  IF @@ERROR = 0  
                  BEGIN  
            COMMIT TRAN  
  
                      -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
ELSE  
                      BEGIN  
    SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
               -- Go to LWH Screen   
                       IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  --(james01)  
                       BEGIN  
                          --prepare Label screen var  
                        SET @cOutField01 = @cParentSKU  
                        SET @cOutField02 = ''  
  
                          SET @cFieldAttr01 = ''  
           SET @cFieldAttr02 = ''  
                          SET @cFieldAttr03 = ''  
                          SET @cFieldAttr04 = ''  
  
                          -- Go to Label Screen   
                          SET @nScn = @nScn_PrintLabel  
                          SET @nStep = @nStep_PrintLabel  
                       END  
                       ELSE  
                       BEGIN  
                  SET @nScn = @nScn_LWH  
                  SET @nStep = @nStep_LWH  
                       END  
                      -- (Vicky06) Length, Width, Height - End  
       
--              --prepare Label screen var  
--            SET @cOutField01 = @cParentSKU  
--            SET @cOutField02 = ''  
--           
--            -- Go to Label Screen   
--            SET @nScn = @nScn_PrintLabel  
--            SET @nStep = @nStep_PrintLabel  
         
              SET @nPrevScn = @nScn_Shipper  
              SET @nPrevStep = @nStep_Shipper  
                 END  
             ELSE  
         BEGIN  
                ROLLBACK TRAN  
                SET @nErrNo = 63429  
                SET @cErrMsg = rdt.rdtgetmessage( 63429, @cLangCode, 'DSP') -- Update Fail  
                    GOTO Shipper_Fail  
             END  
              END -- PackExt = 0  
            END -- Matchfound = 0  
         END  -- Result = 1  
    END -- = 2  
  
      GOTO Quit  
   END  
  
    
   IF @nInputKey = 0 -- ESC  
   BEGIN    
    -- Go Case Screen   
    -- Prepare Case screen var  
       SET @cOutField01 = @cCase  
       SET @cOutField02 = '1'   
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
  
         SET @cShipper = ''  
         SET @nShipper = 0  
       SET @cOptionShipper = ''  
         SET @nMatchFound = 0  
        SET @cMatchSKU = ''  
  
       -- Go to next screen  
       SET @nScn = @nScn_Case  
       SET @nStep = @nStep_Case  
   END  
     
   GOTO Quit  
  
   Shipper_Fail:  
   BEGIN  
      SET @cOutField01 = '' --#   
      SET @cOutField02 = '1'  
      SET @cOptionShipper = ''  
      SET @nMatchFound = 0  
      SET @cMatchSKU = ''  
   END  
   
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 1507. Pallet screen  
   Pallet  (field01, input)  
********************************************************************************/  
Step_Pallet:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
   
      SET @cPallet = @cInField01  
  
    IF @cPallet  = '' SET @cPallet  = '0' -- Blank taken as zero  
  
      IF RDT.rdtIsValidQTY( @cPallet, 0) = 0  
    BEGIN  
          SET @nErrNo = 63430  
          SET @cErrMsg = rdt.rdtgetmessage( 63430, @cLangCode, 'DSP') --Invalid Number  
          EXEC rdt.rdtSetFocusField @nMobile, 05 -- #  
          GOTO Pallet_Fail  
    END  
        
      SET @nPallet = CAST(@cPallet as INT)  
  
      IF @nPallet > 0  
      BEGIN  
      IF @nShipper > 0  
      BEGIN  
            SELECT @nPallet = @nShipper * @nPallet  
        END  
        ELSE  
        BEGIN    
         IF @nCaseCnt > 0  
         BEGIN  
           SELECT @nPallet = @nCaseCnt * @nPallet   
         END  
         ELSE  
         BEGIN  
           IF @nInnerPack > 0  
           BEGIN  
              SELECT @nPallet = @nInnerPack * @nPallet  
           END  
         END    
       END  
       END  
  
        -- No match found, insert BOM, SKU, UPC, Packkey  
       IF @cResult = '0'  
       BEGIN  
         BEGIN TRAN  
  
         -- (Vicky05) - Start - Assign Packkey  
         SELECT @b_success=0  
         EXECUTE   nspg_getkey  
         'BOMPACK'  
         , 7  
         , @c_BOMPackKey OUTPUT  
         , @b_success OUTPUT  
         , @n_err OUTPUT  
         , @c_errmsg OUTPUT  
         IF @b_success=0  
         BEGIN  
            ROLLBACK TRAN  
            SET @nErrNo = 67258  
            SET @cErrMsg = rdt.rdtgetmessage( 67258, @cLangCode, 'DSP') -- PackkeyErr  
            GOTO Inner_Fail  
         END  
             
         SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
            -- (Vicky05) - End - Assign Packkey  
  
          -- Insert SKU, BOM   
          -- (Vicky04) - Add new Parameter @cUserName  
          EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
          IF @nErrNo <> 0  
           GOTO Pallet_Fail  
          
          -- Insert Pack Table (1 Record for ParentSKU)  
          INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM2, InnerPack,  
                                      PACKUOM4, Pallet, PACKUOM8, OtherUnit1, PACKUOM3, QTY)  
          VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey),   
                 CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END, @nCaseCnt,  
                 CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END, @nInnerPack,   
                 CASE WHEN @nPallet > 0 THEN 'PL' ELSE '' END, @nPallet,   
                 CASE WHEN @nShipper > 0 THEN 'SH' ELSE '' END,   
                 @nShipper, 'PK', 1)  
  
           -- Insert UPC (1 Record for ParentSKU)  
          IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
          (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
          BEGIN    
             INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)    
             VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, @cParentSKU, @cPackkey, 'IP')    
          END    
  
          -- Insert UPC (1 Record for ParentSKU)    
          IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
          (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
          BEGIN    
             INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)    
       VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END, @cStorerKey, @cParentSKU, @cPackkey, 'CS')    
          END    
  
  
          -- Insert UPC (1 Record for ParentSKU)    
          IF @nShipper > 0 AND NOT EXISTS -- (james04)    
          (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'SH' AND StorerKey = @cStorerKey)    
          BEGIN    
             INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)    
             VALUES(RTRIM(@cParentSKU) + 'SH', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'SH')    
          END    
    
            
          -- Insert UPC (1 Record for ParentSKU)    
          IF @nPallet > 0 AND NOT EXISTS -- (james04)    
          (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'PL' AND StorerKey = @cStorerKey)    
          BEGIN    
             INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)    
             VALUES(RTRIM(@cParentSKU) + 'PL', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'PL')    
          END    
  
          -- Update RDT.rdtBOMCreationLog   
          UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
             SET Status = '9'  
          WHERE ParentSKU = @cParentSKU  
          AND   Status = '0'  
          AND   MobileNo = @nMobile  
          AND   UserName = @cUserName  
          AND   Storerkey = @cStorerKey  
  
          IF @@ERROR = 0  
          BEGIN  
      COMMIT TRAN  
  
              -- (Vicky06) Length, Width, Height - Start  
             SELECT @nLength = [Length],  
                     @nWidth  = Width,  
                     @nHeight = Height,  
                     @nStdGrossWgt = StdGrossWgt,  
                     @nStdCube = StdCube  
              FROM dbo.SKU WITH (NOLOCK)  
              WHERE Storerkey = @cStorerKey  
              AND   SKU = @cParentSKU  
  
           --prepare LWH screen var  
              IF @nLength > 0  
              BEGIN  
                 SET @cFieldAttr01 = 'O'  
                 SET @cOutField01 = CAST(@nLength AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField01 = ''  
                 EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
  
              IF @nWidth > 0  
              BEGIN  
                 SET @cFieldAttr02 = 'O'  
                 SET @cOutField02 = CAST(@nWidth AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField02 = ''  
              END  
  
              IF @nHeight > 0  
              BEGIN  
                 SET @cFieldAttr03 = 'O'  
                 SET @cOutField03 = CAST(@nHeight AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField03 = ''  
              END  
  
              IF @nStdGrossWgt > 0  
              BEGIN  
                 SET @cFieldAttr04 = 'O'  
                 SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
              END  
              ELSE  
              BEGIN  
                 SET @cOutField04 = ''  
              END  
  
              IF @nLength = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 01  
              END  
              ELSE IF @nWidth = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 02  
              END  
              ELSE IF @nHeight = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 03  
              END  
              ELSE IF @nStdGrossWgt = 0  
              BEGIN  
                EXEC rdt.rdtSetFocusField @nMobile, 04  
              END  
  
      -- Go to LWH Screen   
              IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  -- (james01)  
              BEGIN  
                 --prepare Label screen var  
                 SET @cOutField01 = @cParentSKU  
                 SET @cOutField02 = ''  
  
                 SET @cFieldAttr01 = ''  
                 SET @cFieldAttr02 = ''  
 SET @cFieldAttr03 = ''  
                 SET @cFieldAttr04 = ''  
  
            -- Go to Label Screen   
                 SET @nScn = @nScn_PrintLabel  
                 SET @nStep = @nStep_PrintLabel  
              END  
              ELSE  
              BEGIN  
         SET @nScn = @nScn_LWH  
         SET @nStep = @nStep_LWH  
              END  
              -- (Vicky06) Length, Width, Height - End  
  
--        --prepare Label screen var  
--      SET @cOutField01 = @cParentSKU  
--      SET @cOutField02 = ''  
--     
--      -- Go to Label Screen   
--      SET @nScn = @nScn_PrintLabel  
--      SET @nStep = @nStep_PrintLabel  
   
          SET @nPrevScn = @nScn_Pallet  
          SET @nPrevStep = @nStep_Pallet  
          END  
    ELSE  
    BEGIN  
          ROLLBACK TRAN  
          SET @nErrNo = 63431  
          SET @cErrMsg = rdt.rdtgetmessage( 63431, @cLangCode, 'DSP') -- Update Fail  
            GOTO Pallet_Fail  
        END  
       END  -- Result = 0  
   
       IF @cResult = '1'  
       BEGIN  
           -- Check matching Packkey  
               -- (Vicky04) - Add new Parameter @cUserName  
           EXEC RDT.rdt_BOM_Packkey_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @nInnerPack, @nCaseCnt,  
                                               @nShipper, @nPallet, @nMatchFound OUTPUT, @cMatchSKU OUTPUT, @cParentExt -- (Vicky05)  
   
    
             IF @nMatchFound > 0  
             BEGIN  
                    -- (Vicky05) - Start  
                    IF @cSysParentSKU = '' AND @cParentExt <> '1'  
                    BEGIN  
                        SET @nErrNo = 67267  
                    SET @cErrMsg = rdt.rdtgetmessage( 67267, @cLangCode, 'DSP') -- Pack for other  
                        GOTO Inner_Fail  
                    END  
                    -- (Vicky05) - End  
  
                 -- Match BOM, Packkey Found  
                 -- Update RDT.rdtBOMCreationLog   
               UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                SET Status = '5',  
                        ParentSKU = @cMatchSKU--@cParentSKU  
             WHERE ParentSKU = @cParentSKU  
             AND   Status = '0'  
             AND   MobileNo = @nMobile  
             AND   UserName = @cUserName  
               AND   Storerkey = @cStorerKey  
    
               IF @@ERROR = 0  
               BEGIN  
         COMMIT TRAN  
   
                   -- Set ParentSKU = Matched SKU                  
                   SET @cParentSKU = RTRIM(@cMatchSKU)  
  
                      -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                    --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
                      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
                      -- Go to LWH Screen   
                      IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1   -- (james01)  
                      BEGIN  
                         --prepare Label screen var  
                       SET @cOutField01 = @cParentSKU  
                       SET @cOutField02 = ''  
  
                         SET @cFieldAttr01 = ''  
                         SET @cFieldAttr02 = ''  
                         SET @cFieldAttr03 = ''  
                         SET @cFieldAttr04 = ''  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                      END  
                      ELSE  
                      BEGIN  
                    SET @nScn = @nScn_LWH  
                    SET @nStep = @nStep_LWH  
                      END  
                      -- (Vicky06) Length, Width, Height - End  
   
--                 --prepare Label screen var  
--         SET @cOutField01 = @cParentSKU  
--         SET @cOutField02 = ''  
--       
--           -- Go to Label Screen   
--         SET @nScn = @nScn_PrintLabel  
--         SET @nStep = @nStep_PrintLabel  
     
              SET @nPrevScn = @nScn_Pallet  
              SET @nPrevStep = @nStep_Pallet  
              END  
            ELSE  
      BEGIN  
             ROLLBACK TRAN  
             SET @nErrNo = 63432  
             SET @cErrMsg = rdt.rdtgetmessage( 63432, @cLangCode, 'DSP') -- Update Fail  
                 GOTO Case_Fail  
        END  
             END  
             ELSE  
             BEGIN  
                 IF @cParentExt = '1' -- (Vicky05)  
                 BEGIN   
                     SET @nErrNo = 67263  
                 SET @cErrMsg = rdt.rdtgetmessage( 67263, @cLangCode, 'DSP') -- Pack not match  
                     GOTO Inner_Fail  
                 END  
                 ELSE  
                 BEGIN  
                    IF @cSysParentSKU <> '' -- (Vicky05)  
                    BEGIN  
                      --SELECT @cSuffix = RIGHT(MAX(RTRIM(BOM.SKU)),3)  
--                        SELECT @cSuffix = MAX(RIGHT(RTRIM(BOM.SKU),3)) -- LARRY01  
--                      FROM dbo.BillOfMaterial BOM WITH (NOLOCK)  
--                      JOIN dbo.SKU SKU WITH (NOLOCK)  
--                         ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)  
--                      WHERE BOM.Storerkey = @cStorerKey  
--                      --AND   SKU.Style = @cStyle  
--                          AND LEFT(RTRIM(SKU.Style),10) = LEFT(RTRIM(@cStyle),10)  -- LARRY01  
--       
--                      SELECT @nSuffix = CAST(ISNULL(@cSuffix, '0') as INT) + 1  
--                                           
--                      SELECT @cParentSKU = LEFT(RTRIM(@cStyle), 10) + RIGHT(RTRIM(REPLICATE(0,3) + CAST(@nSuffix as CHAR)), 3) -- (Vicky03)  
  
              -- (Vicky08) - Start  
                         EXEC dbo.isp_GetNextParentSKU     
                              @c_Storerkey    = @cStorerKey,     
                              @c_Style        = @cStyle,    
                              @c_NewParentSKU = @cParentSKU OUTPUT  
  
                         IF @cParentSKU = ''  
                         BEGIN  
                           SET @nErrNo = 69545  
                           SET @cErrMsg = rdt.rdtgetmessage(69545, @cLangCode, 'DSP') --ErrGenParentSKU  
                           GOTO Inner_Fail   
                         END  
                         -- (Vicky08) - End  
  
       
                      UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                         SET ParentSKU = @cParentSKU  
                      WHERE Style = @cStyle  
                      AND   Status = '0'  
                      AND   MobileNo = @nMobile  
                        AND   UserName = @cUserName -- (Vicky04)  
                    END  
   
                  -- SET @cPackkey = RIGHT(RTRIM(@cParentSKU), 10) -- Comment By (Vicky05)  
  
                    -- (Vicky05) - Start - Assign Packkey  
                      SELECT @b_success=0  
                      EXECUTE   nspg_getkey  
                      'BOMPACK'  
                      , 7  
                      , @c_BOMPackKey OUTPUT  
                      , @b_success OUTPUT  
                      , @n_err OUTPUT  
                      , @c_errmsg OUTPUT  
                      IF @b_success=0  
                      BEGIN  
                        ROLLBACK TRAN  
                        SET @nErrNo = 67259  
                        SET @cErrMsg = rdt.rdtgetmessage( 67259, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO Inner_Fail  
                      END  
                     
                    SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
                    -- (Vicky05) - End - Assign Packkey  
   
   
               -- Insert SKU, BOM   
                   -- (Vicky04) - Add new Parameter @cUserName  
               EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
    
               IF @nErrNo <> 0  
               BEGIN  
            SET @cErrMsg = @cErrMsg  
                GOTO Case_Fail  
               END  
   
             -- Insert Pack Table (1 Record for ParentSKU)  
             INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM2, InnerPack,  
                                         PACKUOM4, Pallet, PACKUOM8, OtherUnit1, PACKUOM3, QTY)  
             VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey),   
                    CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END, @nCaseCnt,  
                    CASE WHEN @nInnerPack > 0 THEN 'IP' ELSE '' END, @nInnerPack,   
                    CASE WHEN @nPallet > 0 THEN 'PL' ELSE '' END, @nPallet,   
                    CASE WHEN @nShipper > 0 THEN 'SH' ELSE '' END,   
                    @nShipper, 'PK', 1)  
     
              -- Insert UPC (1 Record for ParentSKU)  
             IF @nInnerPack > 0 AND NOT EXISTS -- (james04)    
                   (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'IP' AND StorerKey = @cStorerKey)    
             BEGIN  
                INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                VALUES(RTRIM(@cParentSKU) + 'IP', @cStorerKey, @cParentSKU, @cPackkey, 'IP')  
             END  
     
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
                   (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
             BEGIN  
                INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
--                VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, @cParentSKU, @cPackkey, 'CS') 1.17 Shong  
       VALUES(RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END, @cStorerKey, @cParentSKU, @cPackkey, 'CS')  
             END  
     
     
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nShipper > 0 AND NOT EXISTS -- (james04)    
                   (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'SH' AND StorerKey = @cStorerKey)    
             BEGIN  
                INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                VALUES(RTRIM(@cParentSKU) + 'SH', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'SH')  
             END  
     
             
             -- Insert UPC (1 Record for ParentSKU)  
             IF @nPallet > 0 AND NOT EXISTS -- (james04)    
                   (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + 'PL' AND StorerKey = @cStorerKey)    
             BEGIN  
                INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                VALUES(RTRIM(@cParentSKU) + 'PL', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'PL')  
             END  
     
             -- Update RDT.rdtBOMCreationLog   
             UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                SET Status = '9'  
             WHERE ParentSKU = @cParentSKU  
             AND   Status = '0'  
             AND   MobileNo = @nMobile  
             AND   UserName = @cUserName  
             AND   Storerkey = @cStorerKey  
    
               IF @@ERROR = 0  
               BEGIN  
         COMMIT TRAN  
  
                      -- (Vicky06) Length, Width, Height - Start  
                      SELECT @nLength = [Length],  
                             @nWidth  = Width,  
                             @nHeight = Height,  
                             @nStdGrossWgt = StdGrossWgt,  
                             @nStdCube = StdCube  
                      FROM dbo.SKU WITH (NOLOCK)  
                      WHERE Storerkey = @cStorerKey  
                      AND   SKU = @cParentSKU  
  
                   --prepare LWH screen var  
                      IF @nLength > 0  
                      BEGIN  
                         SET @cFieldAttr01 = 'O'  
                         SET @cOutField01 = CAST(@nLength AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField01 = ''  
                         EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
  
                      IF @nWidth > 0  
                      BEGIN  
                         SET @cFieldAttr02 = 'O'  
                         SET @cOutField02 = CAST(@nWidth AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField02 = ''  
                      END  
  
                      IF @nHeight > 0  
                      BEGIN  
                         SET @cFieldAttr03 = 'O'  
                         SET @cOutField03 = CAST(@nHeight AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField03 = ''  
                      END  
  
                      IF @nStdGrossWgt > 0  
                      BEGIN  
                         SET @cFieldAttr04 = 'O'  
                         SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
                      END  
                      ELSE  
                      BEGIN  
                         SET @cOutField04 = ''  
                      END  
  
                      IF @nLength = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 01  
                      END  
                      ELSE IF @nWidth = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 02  
                      END  
                      ELSE IF @nHeight = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 03  
                      END  
      ELSE IF @nStdGrossWgt = 0  
                      BEGIN  
                        EXEC rdt.rdtSetFocusField @nMobile, 04  
                      END  
  
              -- Go to LWH Screen   
                      IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1  --(james01)  
                      BEGIN  
                         --prepare Label screen var  
                       SET @cOutField01 = @cParentSKU  
                       SET @cOutField02 = ''  
  
                         SET @cFieldAttr01 = ''  
                         SET @cFieldAttr02 = ''  
                         SET @cFieldAttr03 = ''  
                         SET @cFieldAttr04 = ''  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                      END  
                      ELSE  
                      BEGIN  
                 SET @nScn = @nScn_LWH  
                 SET @nStep = @nStep_LWH  
                      END  
                      -- (Vicky06) Length, Width, Height - End  
  
    
--           --prepare Label screen var  
--         SET @cOutField01 = @cParentSKU  
--         SET @cOutField02 = ''  
--        
--         -- Go to Label Screen   
--         SET @nScn = @nScn_PrintLabel  
--         SET @nStep = @nStep_PrintLabel  
      
                SET @nPrevScn = @nScn_Pallet  
                SET @nPrevStep = @nStep_Pallet  
              END  
          ELSE  
      BEGIN  
             ROLLBACK TRAN  
             SET @nErrNo = 63434  
             SET @cErrMsg = rdt.rdtgetmessage( 63434, @cLangCode, 'DSP') -- Update Fail  
                 GOTO Case_Fail  
          END  
              END -- PackExt = 0  
           END -- Matchfound = 0  
       END -- Result = 1  
  
  
      GOTO Quit  
   END  
  
    
   IF @nInputKey = 0 -- ESC  
   BEGIN    
    -- Go Case Screen   
    -- Prepare Case screen var  
       SET @cOutField01 = @cShipper  
       SET @cOutField02 = '1'   
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
  
         SET @cPallet = ''  
         SET @nPallet = 0  
       SET @cOptionPallet = ''  
         SET @nMatchFound = 0  
         SET @cMatchSKU = ''  
  
       -- Go to next screen  
       SET @nScn = @nScn_Shipper  
       SET @nStep = @nStep_Shipper  
   END  
     
   GOTO Quit  
  
   Pallet_Fail:  
   BEGIN  
      SET @cOutField01 = '' --#  
      SET @cOutField02 = '1'   
      SET @cOptionPallet = ''  
      SET @nMatchFound = 0  
      SET @cMatchSKU = ''  
   END  
   
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 1508. Print Label screen  
   ParentSKU   (field01)  
   No Of Label (field02, input)  
********************************************************************************/  
Step_PrintLabel:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
  
       SET @cNoOfLabel = @cInField02    
  
   SET @cPrintBOMLabel = rdt.RDTGetConfig( 0, 'PrintBOMLabel', @cStorerKey)    
    
   IF (@cPrintBOMLabel = '0' OR @cPrintBOMLabel IS NULL OR @cPrintBOMLabel = '')  
       SET @cPrintBOMLabel = '0'  
   ELSE  
       SET @cPrintBOMLabel = '1'  
  
      IF @cNoOfLabel  = ''   
       BEGIN  
          SET @nErrNo = 63435  
          SET @cErrMsg = rdt.rdtgetmessage( 63435, @cLangCode, 'DSP') --Label needed  
          EXEC rdt.rdtSetFocusField @nMobile, 06 -- #  
          GOTO PrintLabel_Fail  
       END  
         
       IF @cPrintBOMLabel = '0'  
       BEGIN  
        -- not check for 0 coz optional to print  
        IF RDT.rdtIsValidQTY( @cNoOfLabel, 0) = 0  
      BEGIN  
           SET @nErrNo = 63436  
           SET @cErrMsg = rdt.rdtgetmessage( 63436, @cLangCode, 'DSP') --Invalid Number  
           EXEC rdt.rdtSetFocusField @nMobile, 06 -- #  
           GOTO PrintLabel_Fail  
      END  
       END  
       ELSE IF @cPrintBOMLabel = '1' -- check 0 coz must print  
       BEGIN  
        -- not check for 0 coz optional to print  
        IF RDT.rdtIsValidQTY( @cNoOfLabel, 1) = 0  
      BEGIN  
           SET @nErrNo = 63437  
           SET @cErrMsg = rdt.rdtgetmessage( 63437, @cLangCode, 'DSP') --Invalid Number  
           EXEC rdt.rdtSetFocusField @nMobile, 06 -- #  
           GOTO PrintLabel_Fail  
      END  
       END  
  
       -- Check if exceed no of label that allow to print (james05)  
       SET @nNoOfLabelAllowed = ISNULL(rdt.RDTGetConfig( @nFunc, 'NoOfLabelAllowed', @cStorerKey), 0)  
       IF @nNoOfLabelAllowed > 0 AND ( LEN(RTRIM(@cNoOfLabel)) > @nNoOfLabelAllowed)  
       BEGIN  
          SET @nErrNo = 70475  
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv No of LBL  
          EXEC rdt.rdtSetFocusField @nMobile, 06 -- #  
          GOTO PrintLabel_Fail  
       END  
  
       DECLARE @cDataWindow NVARCHAR( 50), @cTargetDB NVARCHAR(20), @cLevel NVARCHAR(30), @cPrintBundle NVARCHAR(1),  
               @cReportType NVARCHAR( 10)  
  
       SET @cPrintBundle = 'N'  
  
       IF EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK)   
                  WHERE UPC.StorerKey = @cStorerKey   
                  AND UPC.SKU = RTRIM(@cParentSKU)  
                  AND UPC.UOM = 'PL')  
       BEGIN  
          SELECT @cLevel = 'T'  
       END  
       ELSE IF EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK)   
                       WHERE UPC.StorerKey = @cStorerKey   
                       AND UPC.SKU = RTRIM(@cParentSKU)  
                       AND UPC.UOM = 'SH')  
       BEGIN  
          SELECT @cLevel = 'S'  
       END  
       ELSE IF EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK)   
                   WHERE UPC.StorerKey = @cStorerKey   
                   AND UPC.SKU = RTRIM(@cParentSKU)  
                   AND UPC.UOM = 'CS')  
       BEGIN  
          SELECT @cLevel = 'C'  
       END  
       ELSE IF EXISTS (SELECT 1 FROM dbo.UPC UPC WITH (NOLOCK)   
                   WHERE UPC.StorerKey = @cStorerKey   
                   AND UPC.SKU = RTRIM(@cParentSKU)  
                   AND UPC.UOM = 'IP')  
       BEGIN  
          SELECT @cLevel = 'I'  
       END  
       ELSE  
       BEGIN  
           IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1  -- (james01)  
           BEGIN  
              SELECT @cLevel = 'C'  
              SET @cPrintBundle = 'N'  
              IF NOT EXISTS (SELECT 1 FROM dbo.BillOfmaterial WITH (NOLOCK)  
              WHERE StorerKey = @cStorerKey  
                 AND SKU = @cParentSKU)  
              BEGIN  
                 SELECT TOP 1 @cParentSKU = SKU FROM dbo.BillOfmaterial WITH (NOLOCK)   
                 WHERE StorerKey = @cStorerKey  
                    AND ComponentSKU = @cSKU  
                    AND Qty = @cQty  
             END  
           END  
           ELSE  
           BEGIN  
              SELECT @cLevel = 'P'  
              SET @cPrintBundle = 'Y'  
           END  
       END  
         
       IF @cNoOfLabel <> '0'  
       BEGIN  
        IF @cPrintBundle = 'N'  
          BEGIN  
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')  
         FROM RDT.RDTReport WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   ReportType = 'MASTERLBL'  
  
             SET @cReportType = 'MASTERLBL'  
          END  
          ELSE  
          BEGIN  
         SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
                  @cTargetDB = ISNULL(RTRIM(TargetDB), '')   
         FROM RDT.RDTReport WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   ReportType = 'PPACKLBL'  
  
             SET @cReportType = 'PPACKLBL'  
          END  
   
        IF ISNULL(@cDataWindow, '') = ''  
        BEGIN  
           SET @nErrNo = 63438  
           SET @cErrMsg = rdt.rdtgetmessage( 63438, @cLangCode, 'DSP') --No Label Setup  
           EXEC rdt.rdtSetFocusField @nMobile, 06 -- #  
           GOTO PrintLabel_Fail  
        END  
  
        IF ISNULL(@cTargetDB, '') = ''  
        BEGIN  
           SET @nErrNo = 63440  
           SET @cErrMsg = rdt.rdtgetmessage( 63440, @cLangCode, 'DSP') --TgetDB Not Set  
           EXEC rdt.rdtSetFocusField @nMobile, 06 -- #  
           GOTO PrintLabel_Fail  
        END  
  
        -- Call printing spooler  
          -- Parm1 = Storerkey, Parm2 = ParentSKU, Parm3 = Level, Parm4 = NoOfCopy, Parm5 = Username, NoOfCopy = 1 (dummy)  
        --INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4, Parm5, Printer, NoOfCopy, Mobile, TargetDB)  
        --VALUES('PREPACKLBL', @cReportType, '0', RTRIM(@cDataWindow), 5, RTRIM(@cStorerKey), RTRIM(@cParentSKU), RTRIM(@cLevel), CAST(@cNoOfLabel as INT), RTRIM(@cUserName), RTRIM(@cPrinter), '1', @nMobile, @cTargetDB)  
        
        SET @nNoOfLabel = CAST(@cNoOfLabel as INT)
        
        EXEC RDT.rdt_BuiltPrintJob                     
            @nMobile,                    
            @cStorerKey,                    
            @cReportType,                    
            'PREPACKLBL',                    
            @cDataWindow,                    
            @cPrinter,                    
            @cTargetDB,                    
            @cLangCode,                    
            @nErrNo  OUTPUT,                     
            @cErrMsg OUTPUT,                    
            @cStorerKey,
            @cParentSKU,
            @cLevel,
            @nNoOfLabel,
            @cUserName
       END  
  
       -- Get ComponentSKU Info  
       SELECT @nSumBOMQTY = SUM(QTY)  
       FROM dbo.BillOfMaterial WITH (NOLOCK)  
       WHERE SKU = @cParentSKU  
       AND Storerkey = @cStorerKey  
  
       SELECT TOP 1 @cSkuPackkey = Packkey  
       FROM dbo.UPC WITH (NOLOCK)  
       WHERE SKU = @cParentSKU  
       AND Storerkey = @cStorerKey  
  
       SELECT @nSkuCaseCnt = CaseCnt  
       FROM dbo.PACK WITH (NOLOCK)  
       WHERE Packkey = @cSkuPackkey  
  
  -- Added by Ricky_1.19 to handle Innerpack with Case  
  IF @nSkuCaseCnt = 0  
   SET @nSkuCaseCnt = 1  
  
       IF @nSkuCaseCnt > 0  
       BEGIN  
         SELECT @nCompStdGWgt = @nStdGrossWgt / (@nSumBOMQTY * @nSkuCaseCnt)  
         IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1  -- (james01)     
         BEGIN  
            SELECT @nCompStdCube = (@nLength * @nWidth * @nHeight) /  (@nSumBOMQTY * @nSkuCaseCnt)  
         END  
         ELSE  
         BEGIN  
            SELECT @nCompStdCube = ((@nLength * @nWidth * @nHeight) / 1728) /  (@nSumBOMQTY * @nSkuCaseCnt)  
         END  
       END  
  
       -- Update to ComponentSKU  
       UPDATE dbo.SKU WITH (ROWLOCK)  
        SET StdGrossWgt = CASE WHEN StdGrossWgt = 0 THEN @nCompStdGWgt ELSE StdGrossWgt END,  
            StdCube = CASE WHEN ISNULL(StdCube, 0) = 0 THEN ISNULL(@nCompStdCube, 0) ELSE ISNULL(StdCube, 0) END  
       WHERE SKU IN (SELECT ComponentSKU FROM dbo.BillOfMaterial WITH (NOLOCK)   
                     WHERE SKU = @cParentSKU  
                     AND Storerkey = @cStorerKey)  
       AND Storerkey = @cStorerKey  
  
  
       UPDATE RDT.RDTBOMCreationLog WITH (ROWLOCK)  
          SET ParentSKU = @cParentSKU,  
              Status = '9'  
       WHERE Status = '1'  
       AND   Style = @cStyle  
       AND   MobileNo = @nMobile  
       AND   UserName = @cUserName -- (Vicky04)  
  
--        UPDATE RDT.RDTBOMCreationLog WITH (ROWLOCK)  
--           SET ParentSKU = @cParentSKU  
--        WHERE Status = '5'  
--        AND   Style = @cStyle  
--        AND   MobileNo = @nMobile  
  
     --prepare ParentSKU screen var  
     SET @cOutField01 = ''   
     SET @cOutField02 = ''   
     SET @cOutField03 = ''   
     SET @cOutField04 = ''   
     SET @cOutField05 = ''   
  
     SET @cInField01 = ''   
     SET @cInField02 = ''   
     SET @cInField03 = ''   
     SET @cInField04 = ''   
     SET @cInField05 = ''   
   
     SET @cParentSKU = ''  
     SET @cSysParentSKU = ''  
     SET @cSKU = ''  
     SET @cSKUDescr = ''  
     SET @cQTY = ''  
     SET @cStyle = ''  
     SET @nPrevBOMSeq = 0  
     SET @nBOMSeq = 0  
   
     SET @cSKUFlag = ''  
     SET @cResult = ''  
     SET @nSKUCnt = 0  
  
       SET @cMatchSKU = ''  
     SET @cMatchPackkey = ''  
   SET @cMatchInner = ''    
   SET @cMatchCase = ''     
   SET @cMatchShipper = ''  
   SET @cMatchPallet = ''   
   
     SET @nMatchInner = ''  
   SET @nMatchCase = ''  
   SET @nMatchShipper = ''  
   SET @nMatchPallet = ''  
     SET @nPrevScn = ''  
     SET @nPrevStep = ''  
         
       SET @cMatchSKU = ''  
       SET @nMatchFound = 0  
  
       SET @nScn = @nScn_ParentSKU  
       SET @nStep = @nStep_ParentSKU  
  
      GOTO Quit  
   END  
     
   IF @nInputKey = 0 -- ESC  
   BEGIN    
      IF rdt.RDTGetConfig( @nFunc, 'SKIPLWHSCN', @cStorerKey) = 1 -- (james01)  
      BEGIN  
         IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1 -- (james01)  
         BEGIN  
            -- Prepare ParentSKU screen var  
            SET @cOutField01 = '' -- ParentSKU  
  
            -- Go to ParentSKU screen  
            SET @nScn = @nScn_ParentSKU  
            SET @nStep = @nStep_ParentSKU  
         END  
         ELSE  
         BEGIN  
            -- Go back to Prev Screen   
            -- Prepare Prev screen var  
            SET @cOutField01 = CASE WHEN @nPrevScn = @nScn_Inner THEN @cInnerPack  
                                    WHEN @nPrevScn = @nScn_Case  THEN @cCase  
                                    WHEN @nPrevScn = @nScn_Shipper THEN @cShipper  
                                    WHEN @nPrevScn = @nScn_Pallet THEN @cPallet  
                                ELSE '' END    
          SET @cOutField02 = '1' -- Default Option  
  
            -- Go to Prev screen  
            SET @nScn = @nPrevScn  
            SET @nStep = @nPrevStep  
         END  
      END  
      ELSE  
      BEGIN  
         -- Go back to Prev Screen   
         -- Prepare Prev screen var  
         SET @cOutField01 = @nLength  
         SET @cOutField02 = @nWidth  
         SET @cOutField03 = @nHeight  
         SET @cOutField04 = @nStdGrossWgt  
  
         --Go to Prev screen  
         SET @nScn = @nScn_LWH  
         SET @nStep = @nStep_LWH  
      END  
   END  
     
   GOTO Quit  
  
   PrintLabel_Fail:  
   BEGIN  
      SET @cOutField01 = @cParentSKU  
      SET @cOutField02 = '' --#  
   END  
   
END  
GOTO Quit  
  
/************************************************************************************  
Scn = 1510. Length, Width, Height, Weight  
   LEN   (field01)  
   WDT   (field02)  
   HGT   (field03)  
   WGT   (field04)  
************************************************************************************/  
Step_LWH:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
  
  -- (james03) start  
  IF ISNUMERIC( @cInField01) = 0  
  BEGIN  
     SET @cInField01 = '0'  
  END  
  
  IF ISNUMERIC( @cInField02) = 0  
  BEGIN  
     SET @cInField02 = '0'  
  END  
  
  IF ISNUMERIC( @cInField03) = 0  
  BEGIN  
     SET @cInField03 = '0'  
  END  
  
  IF ISNUMERIC( @cInField04) = 0  
  BEGIN  
     SET @cInField04 = '0'  
  END  
  -- (james03) end  
    
      -- Screen mapping  
      SET @nLength = CAST(@cInField01 AS FLOAT)  
      SET @nWidth  = CAST(@cInField02 AS FLOAT)  
      SET @nHeight = CAST(@cInField03 AS FLOAT)  
      SET @nStdGrossWgt = CAST(@cInField04 AS FLOAT)  
  
  
  
      IF @cFieldAttr01 = 'O'  
      BEGIN  
        SET @nLength = CAST(@cOutField01 AS FLOAT)  
      END  
  
      IF @cFieldAttr02 = 'O'  
      BEGIN  
        SET @nWidth = CAST(@cOutField02 AS FLOAT)  
      END  
  
      IF @cFieldAttr03 = 'O'  
      BEGIN  
        SET @nHeight = CAST(@cOutField03 AS FLOAT)  
      END  
  
      IF @cFieldAttr04 = 'O'  
      BEGIN  
        SET @nStdGrossWgt = CAST(@cOutField04 AS FLOAT)   
      END  
  
      IF @nLength  = '' SET @nLength  = 0 -- Blank taken as zero  
      IF @nWidth   = '' SET @nWidth  = 0 -- Blank taken as zero  
      IF @nHeight  = '' SET @nHeight  = 0 -- Blank taken as zero  
      IF @nStdGrossWgt  = '' SET @nStdGrossWgt  = 0 -- Blank taken as zero  
  
  
      -- Check for 0 as well  
      IF @nLength = 0 OR @nLength < 0   
    BEGIN  
         SET @nErrNo = 67268  
         SET @cErrMsg = rdt.rdtgetmessage( 67268, @cLangCode, 'DSP') --Invalid LEN  
         EXEC rdt.rdtSetFocusField @nMobile, 01  
         GOTO LWH_Fail  
    END  
  
      IF @nWidth = 0 OR @nWidth < 0   
    BEGIN  
         SET @nErrNo = 67269  
         SET @cErrMsg = rdt.rdtgetmessage( 67269, @cLangCode, 'DSP') --Invalid WDT  
         EXEC rdt.rdtSetFocusField @nMobile, 02  
         GOTO LWH_Fail  
    END  
  
      IF @nHeight = 0 OR @nHeight < 0   
    BEGIN  
         SET @nErrNo = 67270  
         SET @cErrMsg = rdt.rdtgetmessage( 67270, @cLangCode, 'DSP') --Invalid HGT  
         EXEC rdt.rdtSetFocusField @nMobile, 03  
         GOTO LWH_Fail  
    END  
  
      IF @nStdGrossWgt = 0 OR @nStdGrossWgt < 0  
      BEGIN  
         IF rdt.RDTGetConfig( @nFunc, 'SKIPSTDGROSSWGT', @cStorerKey) = 0  -- (james01)  
         BEGIN  
            SET @nErrNo = 67271  
          SET @cErrMsg = rdt.rdtgetmessage( 67271, @cLangCode, 'DSP') --Invalid WGT  
          EXEC rdt.rdtSetFocusField @nMobile, 04  
          GOTO LWH_Fail  
       END  
      END  
  
      IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1   
         SET @cCheckDimension = '1'  
      ELSE  
         SET @cCheckDimension = '0'  
  
  -- use configkey to store dimension tolerance (james02)  
  SET @cBOMDIMTOLERANCE = rdt.RDTGetConfig( @nFunc, 'BOMDIMTOLERANCE', @cStorerKey)  
      IF ISNULL(@cBOMDIMTOLERANCE, '') <> '' AND @cBOMDIMTOLERANCE <> '0'  
      BEGIN  
     IF RDT.rdtIsValidQTY( @cBOMDIMTOLERANCE, 1) = 0  
     BEGIN  
            SET @nErrNo = 70472  
            SET @cErrMsg = rdt.rdtgetmessage( 70472, @cLangCode, 'DSP') -- Inv Tolerance  
            GOTO LWH_Fail  
     END  
     ELSE  
     BEGIN  
      SET @nBOMDIMTOLERANCE = CAST(@cBOMDIMTOLERANCE AS INT)  
     END  
  END  
      ELSE  
      BEGIN  
         -- If config not turned on then no tolerance level  
         SET @nBOMDIMTOLERANCE = 0  
      END  
  
      EXEC RDT.rdt_BOM_DimensionMatching   
         @cStorerkey,  
         @cParentSKU,   
         @cStyle,  
         @nLength,  
         @nWidth,  
         @nHeight,  
         @nStdGrossWgt,  
         @nMobile,  
         @cUsername,  
         @cMatchSKU          OUTPUT,  
         @cResult            OUTPUT,  
         @cMatchDimension    OUTPUT,   
         @nBOMDIMTOLERANCE,  
         @cParentExt,   
         @cCheckDimension        
  
--         EXEC RDT.rdt_BOM_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @cMatchSKU OUTPUT, @cResult OUTPUT, @cParentExt -- 24-09-2007 -- (Vicky05)  
  
      IF @cResult <> '1' and @cSysParentSKU = '' AND @cParentExt = '0'  
      BEGIN  
         UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
            SET Status = '9'  
         WHERE Style = @cStyle  
         AND   Status = '0'  
         AND   MobileNo = @nMobile  
         AND   UserName = @cUserName  
         AND   ParentSKU = @cParentSKU  
  
         SET @nErrNo = 69554  
         SET @cErrMsg = rdt.rdtgetmessage(69554, @cLangCode, 'DSP') --BOM not match  
         GOTO LWH_Fail   
      END  
  
      -- If got match, find packkey configuration  
      IF @cResult = '1'  
      BEGIN  
        -- Get Inventory  
        SELECT @nQtyAvail = SUM(SL.QTY)  
        FROM dbo.SKUxLOC SL WITH (NOLOCK)  
        JOIN RDT.rdtBOMCreationLog BCL WITH (NOLOCK)  
            ON (BCL.StorerKey = SL.Storerkey AND  
                BCL.ComponentSKU = SL.SKU AND  
                BCL.Status = '0' AND  
                BCL.ParentSKU = @cParentSKU AND  
                BCL.MobileNo = @nMobile AND   
                BCL.Username = @cUserName) -- (Vicky04)  
        WHERE SL.Storerkey = @cStorerKey  
      END  
      ELSE  
      BEGIN  
      IF @cSysParentSKU <> ''  
        BEGIN  
            IF ISNULL(@cParentSKU, '') = '' OR @cParentSKU = LEFT(RTRIM(@cStyle), 10) + '000'   -- (james06)  
            BEGIN  
                -- Get ParentSKU when not supply  
                EXEC dbo.isp_GetNextParentSKU     
                     @c_Storerkey    = @cStorerKey,     
                     @c_Style        = @cStyle,    
                     @c_NewParentSKU = @cParentSKU OUTPUT  
  
                IF @cParentSKU = ''  
                BEGIN  
                  SET @nErrNo = 69555  
                  SET @cErrMsg = rdt.rdtgetmessage(69555, @cLangCode, 'DSP') --ErrGenParentSKU  
                  GOTO LWH_Fail   
                END  
            END  
  
            UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
               SET ParentSKU = @cParentSKU  
            WHERE Style = @cStyle  
            AND   Status = '0'  
            AND   MobileNo = @nMobile  
            AND   UserName = @cUserName -- (Vicky04)  
        END  
      END  
  
      -- (james06)  
      SET @nTranCount = @@TRANCOUNT  
      BEGIN TRAN  
  
      SAVE TRAN LWH  
        
      IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1  -- (james01)  
      BEGIN  
         SELECT @nCaseCnt = 1   
  
       -- No match found, insert BOM, SKU, UPC, Packkey  
         IF @cResult = '0' AND @cMatchDimension = 0  
         BEGIN  
              
            --BEGIN TRAN   (james06)  
  
            -- Assign Packkey  
            SELECT @b_success=0  
            EXECUTE   nspg_getkey  
            'BOMPACK'  
            , 7  
            , @c_BOMPackKey OUTPUT  
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
            IF @b_success=0  
            BEGIN  
               ROLLBACK TRAN LWH  
               SET @nErrNo = 69556  
               SET @cErrMsg = rdt.rdtgetmessage( 69556, @cLangCode, 'DSP') -- PackkeyErr  
               GOTO LWH_Fail  
            END  
  
            SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
  
            -- Insert SKU, BOM   
            EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
            IF @nErrNo <> 0  
            BEGIN  
               ROLLBACK TRAN LWH  
             SET @cErrMsg = @cErrMsg  
               GOTO LWH_Fail  
            END  
  
            SET @cPackUOM1 = rdt.RDTGetConfig( @nFunc, 'DefaultPackUOM1', @cStorerKey)  
            SET @cPackUOM3 = rdt.RDTGetConfig( @nFunc, 'DefaultPackUOM3', @cStorerKey)  
  
            SET @cPackUOM1 = CASE WHEN ISNULL(@cPackUOM1, '') = '' THEN '' ELSE @cPackUOM1 END  
            SET @cPackUOM3 = CASE WHEN ISNULL(@cPackUOM3, '') = '' THEN 'PK' ELSE @cPackUOM3 END  
  
  
            -- Insert Pack Table (1 Record for ParentSKU)  
            INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM3, QTY)  
            VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN @cPackUOM1 ELSE '' END, @nCaseCnt, @cPackUOM3, 1)  
  
            -- Insert UPC (1 Record for ParentSKU)  
            IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
            (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
            BEGIN  
               INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
               VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
            END  
  
            SELECT @nStdCube = (@nLength * @nWidth * @nHeight)  
            -- Update to ParentSKU  
            UPDATE dbo.SKU WITH (ROWLOCK)  
              SET [Length] = CASE WHEN [Length] = 0 THEN @nLength ELSE [Length] END,  
                  Width  = CASE WHEN Width = 0 THEN @nWidth ELSE Width END,  
                  Height = CASE WHEN Height = 0 THEN @nHeight ELSE Height END,  
                  StdGrossWgt = CASE WHEN StdGrossWgt = 0 THEN @nStdGrossWgt ELSE StdGrossWgt END,  
                  StdCube = CASE WHEN ISNULL(StdCube, 0) = 0 THEN ISNULL(@nStdCube, 0) ELSE ISNULL(StdCube, 0) END  
            WHERE SKU = @cParentSKU  
            AND Storerkey = @cStorerKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               ROLLBACK TRAN LWH  
               SET @nErrNo = 70468  
               SET @cErrMsg = rdt.rdtgetmessage( 70468, @cLangCode, 'DSP') -- Update Fail  
               GOTO LWH_Fail  
            END  
  
            -- Update RDT.rdtBOMCreationLog   
            UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
               SET Status = '9'  
            WHERE ParentSKU = @cParentSKU  
            AND   Status = '0'  
            AND   MobileNo = @nMobile  
            AND   UserName = @cUserName  
            AND   Storerkey = @cStorerKey  
  
          IF @@ERROR = 0  
          BEGIN  
         --COMMIT TRAN  (james06)  
  
               --prepare Label screen var  
               SET @cOutField01 = @cParentSKU  
               SET @cOutField02 = ''  
  
               SET @cFieldAttr01 = ''  
               SET @cFieldAttr02 = ''  
    SET @cFieldAttr03 = ''  
               SET @cFieldAttr04 = ''  
  
               -- Go to Label Screen   
               SET @nScn = @nScn_PrintLabel  
               SET @nStep = @nStep_PrintLabel  
            END  
      ELSE  
      BEGIN  
            ROLLBACK TRAN LWH  
            SET @nErrNo = 69557  
            SET @cErrMsg = rdt.rdtgetmessage( 69557, @cLangCode, 'DSP') -- Update Fail  
              GOTO LWH_Fail  
          END  
         END  -- Result = 0  
         ELSE  
         BEGIN -- Result = 1  
            -- Check matching Packkey  
--            EXEC RDT.rdt_BOM_Packkey_Matching @cStorerKey, @cParentSKU, @cStyle, @nMobile, @cUserName, @nInnerPack, @nCaseCnt,  
--                                           @nShipper, @nPallet, @nMatchFound OUTPUT, @cMatchSKU OUTPUT, @cParentExt   
  
            IF @nMatchFound > 0  
            BEGIN  
               IF @cSysParentSKU = '' AND @cParentExt <> '1'  
               BEGIN  
                  ROLLBACK TRAN LWH  
                  SET @nErrNo = 69558  
                SET @cErrMsg = rdt.rdtgetmessage( 69558, @cLangCode, 'DSP') -- Pack for other  
                  GOTO LWH_Fail  
               END  
  
               -- If Std dimension differences is more than 5% than create a new BOM  
               IF @cMatchDimension = 0 --(james02)  
               BEGIN  
                  IF @cParentExt = '1'   
                  BEGIN   
                     ROLLBACK TRAN LWH  
                     SET @nErrNo = 69559  
                   SET @cErrMsg = rdt.rdtgetmessage( 69559, @cLangCode, 'DSP') -- Pack not match  
                     GOTO LWH_Fail  
                  END  
                  ELSE  
                  BEGIN  
                     IF @cSysParentSKU <> ''   
                     BEGIN  
                        EXEC dbo.isp_GetNextParentSKU     
                           @c_Storerkey    = @cStorerKey,     
                           @c_Style        = @cStyle,    
                           @c_NewParentSKU = @cParentSKU OUTPUT  
  
                        IF @cParentSKU = ''  
                        BEGIN  
                           ROLLBACK TRAN LWH  
                           SET @nErrNo = 69560  
                           SET @cErrMsg = rdt.rdtgetmessage(69560, @cLangCode, 'DSP') --ErrGenParentSKU  
                           GOTO LWH_Fail   
                        END  
  
                        UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                           SET ParentSKU = @cParentSKU  
                        WHERE Style = @cStyle  
                        AND   Status = '0'  
                        AND   MobileNo = @nMobile  
                        AND   UserName = @cUserName -- (Vicky04)  
                     END  
  
                     -- Assign Packkey  
                     SELECT @b_success=0  
                     EXECUTE   nspg_getkey  
                        'BOMPACK'  
                        , 7  
                        , @c_BOMPackKey OUTPUT  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
                     IF @b_success=0  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                        SET @nErrNo = 69561  
                        SET @cErrMsg = rdt.rdtgetmessage( 69561, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO LWH_Fail  
                     END  
                 
                    SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
  
                     -- Insert SKU, BOM   
                    EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
                     IF @nErrNo <> 0  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                    SET @cErrMsg = @cErrMsg  
                        GOTO LWH_Fail  
                     END  
  
                     -- Insert Pack Table (1 Record for ParentSKU)  
                     INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM3, QTY)  
    VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END,  
                           @nCaseCnt, 'PK', 1)  
                                 
                     -- Insert UPC (1 Record for ParentSKU)  
                     IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
                     (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
                     BEGIN  
                        INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                        VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
                     END  
    
                     -- Update to ParentSKU  
                     UPDATE dbo.SKU WITH (ROWLOCK)  
                       SET [Length] = CASE WHEN [Length] = 0 THEN @nLength ELSE [Length] END,  
                           Width  = CASE WHEN Width = 0 THEN @nWidth ELSE Width END,  
                           Height = CASE WHEN Height = 0 THEN @nHeight ELSE Height END,  
                           StdGrossWgt = CASE WHEN StdGrossWgt = 0 THEN @nStdGrossWgt ELSE StdGrossWgt END,  
                           StdCube = CASE WHEN ISNULL(StdCube, 0) = 0 THEN ISNULL(@nStdCube, 0) ELSE ISNULL(StdCube, 0) END  
                     WHERE SKU = @cParentSKU  
                     AND Storerkey = @cStorerKey  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                        SET @nErrNo = 70469  
                        SET @cErrMsg = rdt.rdtgetmessage( 70469, @cLangCode, 'DSP') -- Update Fail  
                        GOTO LWH_Fail  
                     END  
  
                     -- Update RDT.rdtBOMCreationLog   
                     UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                      SET Status = '9'  
                   WHERE ParentSKU = @cParentSKU  
                   AND   Status = '0'  
                   AND   MobileNo = @nMobile  
                   AND   UserName = @cUserName  
                     AND   Storerkey = @cStorerKey  
       
                     IF @@ERROR = 0  
                     BEGIN  
                    --COMMIT TRAN (james06)  
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                           COMMIT TRAN LWH  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                    END  
                ELSE  
            BEGIN  
                   ROLLBACK TRAN LWH  
                   SET @nErrNo = 69562  
                   SET @cErrMsg = rdt.rdtgetmessage( 69562, @cLangCode, 'DSP') -- Update Fail  
                       GOTO LWH_Fail  
                END  
                  END -- @cParentExt = 0  
               END  
               -- Match BOM, Packkey Found  
               -- Update RDT.rdtBOMCreationLog   
               UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                SET Status = '5',  
                      ParentSKU = @cMatchSKU --@cParentSKU  
             WHERE ParentSKU = @cParentSKU  
             AND   Status = '0'  
             AND   MobileNo = @nMobile  
             AND   UserName = @cUserName  
               AND   Storerkey = @cStorerKey  
  
               IF @@ERROR = 0  
               BEGIN  
          --COMMIT TRAN  
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                     COMMIT TRAN LWH  
  
                  -- Go to Label Screen   
                  SET @nScn = @nScn_PrintLabel  
                  SET @nStep = @nStep_PrintLabel  
               END  
               ELSE  
         BEGIN  
                ROLLBACK TRAN LWH  
                SET @nErrNo = 69563  
                SET @cErrMsg = rdt.rdtgetmessage( 69563, @cLangCode, 'DSP') -- Update Fail  
                  GOTO LWH_Fail  
           END  
           END   -- @nMatchFound  
            ELSE  
            BEGIN  
               IF @cParentExt = '1'   
               BEGIN   
                  ROLLBACK TRAN LWH  
                  SET @nErrNo = 69564  
                SET @cErrMsg = rdt.rdtgetmessage( 69564, @cLangCode, 'DSP') -- Pack not match  
                  GOTO LWH_Fail  
               END  
               ELSE  
               BEGIN  
                  IF @cSysParentSKU <> ''   
                  BEGIN  
                     EXEC dbo.isp_GetNextParentSKU     
                        @c_Storerkey    = @cStorerKey,     
                        @c_Style        = @cStyle,    
                        @c_NewParentSKU = @cParentSKU OUTPUT  
  
                     IF @cParentSKU = ''  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                        SET @nErrNo = 69565  
                        SET @cErrMsg = rdt.rdtgetmessage(69565, @cLangCode, 'DSP') --ErrGenParentSKU  
                        GOTO LWH_Fail   
                     END  
  
                     UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                        SET ParentSKU = @cParentSKU  
                     WHERE Style = @cStyle  
                     AND   Status = '0'  
                     AND   MobileNo = @nMobile  
                     AND   UserName = @cUserName -- (Vicky04)  
                  END  
  
                  IF @cMatchDimension = 0  
                  BEGIN  
                     -- Assign Packkey  
                     SELECT @b_success=0  
                     EXECUTE   nspg_getkey  
                        'BOMPACK'  
                        , 7  
                        , @c_BOMPackKey OUTPUT  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
                     IF @b_success=0  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                        SET @nErrNo = 70466  
                        SET @cErrMsg = rdt.rdtgetmessage( 70466, @cLangCode, 'DSP') -- PackkeyErr  
                        GOTO LWH_Fail  
                     END  
                     
                     SET @cPackkey = 'BOM' + RIGHT(REPLICATE('0', 7) + @c_BOMPackKey, 7)  
  
                     -- Insert SKU, BOM   
                     EXEC RDT.rdt_BOM_Insertion  @cStorerkey, @cParentSKU, @cPackkey, @nMobile, @cUserName, @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nFunc -- (james01)  
  
                     IF @nErrNo <> 0  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                    SET @cErrMsg = @cErrMsg  
                        GOTO LWH_Fail  
                     END  
  
                     -- Insert Pack Table (1 Record for ParentSKU)  
                     INSERT INTO dbo.PACK (Packkey, PackDescr, PACKUOM1, CaseCnt, PACKUOM3, QTY)  
                     VALUES(RTRIM(@cPackkey), RTRIM(@cPackkey), CASE WHEN @nCaseCnt > 0 THEN 'CS' ELSE '' END,  
                           @nCaseCnt, 'PK', 1)  
                              
                     -- Insert UPC (1 Record for ParentSKU)  
                     IF @nCaseCnt > 0 AND NOT EXISTS -- (james04)    
                     (SELECT 1 FROM dbo.UPC WITH (NOLOCK) WHERE UPC = RTRIM(@cParentSKU) + CASE WHEN @cParentExt = '1' THEN '' ELSE 'CS' END AND StorerKey = @cStorerKey)    
                     BEGIN  
                        INSERT INTO dbo.UPC (UPC, StorerKey, SKU, PackKey, UOM)  
                        VALUES(RTRIM(@cParentSKU) + 'CS', @cStorerKey, RTRIM(@cParentSKU), RTRIM(@cPackkey), 'CS')  
                     END  
    
                     -- Update to ParentSKU  
                     UPDATE dbo.SKU WITH (ROWLOCK)  
                       SET [Length] = CASE WHEN [Length] = 0 THEN @nLength ELSE [Length] END,  
                           Width  = CASE WHEN Width = 0 THEN @nWidth ELSE Width END,  
                  Height = CASE WHEN Height = 0 THEN @nHeight ELSE Height END,  
                           StdGrossWgt = CASE WHEN StdGrossWgt = 0 THEN @nStdGrossWgt ELSE StdGrossWgt END,  
                           StdCube = CASE WHEN ISNULL(StdCube, 0) = 0 THEN ISNULL(@nStdCube, 0) ELSE ISNULL(StdCube, 0) END  
                     WHERE SKU = @cParentSKU  
                     AND Storerkey = @cStorerKey  
  
                     IF @@ERROR <> 0  
                     BEGIN  
                        ROLLBACK TRAN LWH  
                        SET @nErrNo = 70470  
                        SET @cErrMsg = rdt.rdtgetmessage( 70470, @cLangCode, 'DSP') -- Update Fail  
                        GOTO LWH_Fail  
                     END  
  
                     -- Update RDT.rdtBOMCreationLog   
                     UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                      SET Status = '9'  
                   WHERE ParentSKU = @cParentSKU  
                   AND   Status = '0'  
                   AND   MobileNo = @nMobile  
                   AND   UserName = @cUserName  
                     AND   Storerkey = @cStorerKey  
       
                     IF @@ERROR = 0  
                     BEGIN  
                    --COMMIT TRAN  (james06)  
                    WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                        COMMIT TRAN LWH  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                    END  
                ELSE  
            BEGIN  
                   ROLLBACK TRAN LWH  
                   SET @nErrNo = 70467  
                   SET @cErrMsg = rdt.rdtgetmessage( 70467, @cLangCode, 'DSP') -- Update Fail  
                       GOTO LWH_Fail  
                END  
                  END  
                  ELSE  
                  BEGIN  
                     -- Update RDT.rdtBOMCreationLog   
                     UPDATE RDT.rdtBOMCreationLog WITH (ROWLOCK)  
                      SET Status = '9'  
                   WHERE ParentSKU = @cParentSKU  
                   AND   Status = '0'  
                   AND   MobileNo = @nMobile  
                   AND   UserName = @cUserName  
                     AND   Storerkey = @cStorerKey  
       
                     IF @@ERROR = 0  
                     BEGIN  
                    --COMMIT TRAN  (james06)  
                        WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                           COMMIT TRAN LWH  
  
                         -- Go to Label Screen   
                         SET @nScn = @nScn_PrintLabel  
                         SET @nStep = @nStep_PrintLabel  
                    END  
                ELSE  
            BEGIN  
                   ROLLBACK TRAN LWH  
                   SET @nErrNo = 70471  
                   SET @cErrMsg = rdt.rdtgetmessage( 70467, @cLangCode, 'DSP') -- Update Fail  
                       GOTO LWH_Fail  
                END  
                  END  
              END -- @cParentExt = 0  
          END -- Matchfound = 0  
       END -- Result = 1  
     END  
     ELSE  
     BEGIN  
      SELECT @nStdCube = (@nLength * @nWidth * @nHeight) / 1728  
  
      -- Update to ParentSKU  
      UPDATE dbo.SKU WITH (ROWLOCK)  
        SET [Length] = CASE WHEN [Length] = 0 THEN @nLength ELSE [Length] END,  
            Width  = CASE WHEN Width = 0 THEN @nWidth ELSE Width END,  
            Height = CASE WHEN Height = 0 THEN @nHeight ELSE Height END,  
            StdGrossWgt = CASE WHEN StdGrossWgt = 0 THEN @nStdGrossWgt ELSE StdGrossWgt END,  
            StdCube = CASE WHEN ISNULL(StdCube, 0) = 0 THEN ISNULL(@nStdCube, 0) ELSE ISNULL(StdCube, 0) END  
      WHERE SKU = @cParentSKU  
      AND Storerkey = @cStorerKey  
     END  
  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN LWH  
  
      --prepare Label screen var  
      IF rdt.RDTGetConfig( @nFunc, 'SKIPPACKCONF', @cStorerKey) = 1  -- (james01)  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM dbo.BillOfmaterial WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
           AND SKU = @cParentSKU)  
         BEGIN  
           SELECT TOP 1 @cParentSKU = SKU FROM dbo.BillOfmaterial WITH (NOLOCK)   
           WHERE StorerKey = @cStorerKey  
              AND ComponentSKU = @cSKU  
              AND Qty = @cQty  
         END  
      END  
  
    SET @cOutField01 = @cParentSKU  
    SET @cOutField02 = ''  
  
      SET @cFieldAttr01 = ''  
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr03 = ''  
      SET @cFieldAttr04 = ''  
  
      -- Go to Label Screen   
      SET @nScn = @nScn_PrintLabel  
      SET @nStep = @nStep_PrintLabel  
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Go back to Prev Screen   
      -- Prepare Prev screen var  
      SET @cOutField01 = CASE WHEN @nPrevScn = @nScn_Inner THEN @cInnerPack  
                              WHEN @nPrevScn = @nScn_Case  THEN @cCase  
                              WHEN @nPrevScn = @nScn_Shipper THEN @cShipper  
                              WHEN @nPrevScn = @nScn_Pallet THEN @cPallet  
                        ELSE '' END    
    SET @cOutField02 = '1' -- Default Option  
  
      SET @cFieldAttr01 = ''  
      SET @cFieldAttr02 = ''  
      SET @cFieldAttr03 = ''  
      SET @cFieldAttr04 = ''  
  
      -- Go to Prev screen  
      SET @nScn = @nPrevScn  
      SET @nStep = @nPrevStep  
   END  
   GOTO Quit  
  
   LWH_Fail:  
   BEGIN  
      -- rollback didn't decrease @@trancount  
      -- COMMIT statements for such transaction   
      -- decrease @@TRANCOUNT by 1 without making updates permanent  
      WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  
        
       IF @nLength > 0  
       BEGIN  
         SET @cFieldAttr01 = 'O'  
         SET @cOutField01 = CAST(@nLength AS CHAR)  
        END  
        ELSE  
        BEGIN  
           SET @cOutField01 = ''  
        END  
  
        IF @nWidth > 0  
        BEGIN  
           SET @cFieldAttr02 = 'O'  
           SET @cOutField02 = CAST(@nWidth AS CHAR)  
        END  
        ELSE  
        BEGIN  
           SET @cOutField02 = ''  
        END  
  
        IF @nHeight > 0  
        BEGIN  
           SET @cFieldAttr03 = 'O'  
           SET @cOutField03 = CAST(@nHeight AS CHAR)  
        END  
        ELSE  
        BEGIN  
           SET @cOutField03 = ''  
        END  
  
        IF @nStdGrossWgt > 0  
        BEGIN  
           SET @cFieldAttr04 = 'O'  
           SET @cOutField04 = CAST(@nStdGrossWgt AS CHAR)  
        END  
        ELSE  
        BEGIN  
           SET @cOutField04 = ''  
        END  
  
  
   END  
  
END  
GOTO Quit  
  
  
/********************************************************************************  
Quit. Update back to I/O table, ready to be pick up by JBOSS  
********************************************************************************/  
Quit:  
BEGIN  
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET  
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,  
      Func   = @nFunc,  
      Step   = @nStep,  
      Scn    = @nScn,  
  
      StorerKey    = @cStorerKey,  
      Facility     = @cFacility,  
      -- UserName     = @cUserName,  
      Printer      = @cPrinter,  
        
      V_SKU        = @cSKU,  
      V_SKUDescr   = @cSKUDescr,  
      V_UOM        = @cUOM,  
      V_QTY        = @cQTY,  
      
      V_FromScn      = @nPrevScn,
      V_FromStep     = @nPrevStep,
   
      V_Integer1     = @nBOMSeq,
      V_Integer2     = @nPrevBOMSeq,
      V_Integer3     = @nInnerPack,
      V_Integer4     = @nCaseCnt,
      V_Integer5     = @nShipper,
      V_Integer6     = @nPallet,
      V_Integer7     = @nMatchInner,
      V_Integer8     = @nMatchCase,
      V_Integer9     = @nMatchShipper,
      V_Integer10    = @nMatchPallet,
      V_Integer11    = @nQtyAvail,
      V_Integer12    = @nMatchFound,
      
      V_String1    = @cParentSKU,  
      V_String2    = @cOption,  
      
      V_String3    = @cInnerPack,  
      V_String4    = @cCase,  
      V_String5    = @cShipper,  
      V_String6    = @cPallet,  
  
      V_String7    = @cOptionInner,  
      V_String8    = @cOptionCase,  
      V_String9    = @cOptionShipper,  
      V_String10   = @cOptionPallet,  
  
      V_String11   = @cNoOfLabel,  
      V_String12   = @cStyle,  
      --V_String13   = @nBOMSeq,  
      --V_String14   = @nPrevBOMSeq,  
  
      --V_String15   = @nPrevScn,  
      --V_String16   = @nPrevStep,  
  
      V_String17   = @cSysParentSKU,  
      V_String18   = @cSKUFlag,  
  
      --V_String19   = @nInnerPack,  
      --V_String20   = @nCaseCnt,  
      --V_String21   = @nShipper,  
      --V_String22   = @nPallet,  
  
      V_String23   = @cPackkey,   
      V_String24   = @cResult,  
  
      V_String25   = @cMatchPackkey,  
      V_String26   = @cMatchInner,  
      V_String27   = @cMatchCase,  
      V_String28   = @cMatchShipper,  
      V_String29   = @cMatchPallet,  
  
      --V_String30   = @nMatchInner,  
      --V_String31   = @nMatchCase,  
      --V_String32   = @nMatchShipper,  
      --V_String33   = @nMatchPallet,  
  
      V_String34   = @cMatchSKU,  
      --V_String35   = @nQtyAvail,   
        
      V_String36   = @cPackCnt,  
      V_String37   = @cPrevPackCnt,  
      V_String38   = @cPrevStyle,  
  
      --V_String39   = @nMatchFound,  
      V_String40   = @cParentExt, -- (Vicky05)  
  
      -- (Vicky06) - Start  
      V_ReceiptKey = @nLength,  
      V_POKey      = @nWidth,  
      V_LoadKey    = @nHeight,  
      V_OrderKey   = @nStdGrossWgt,  
  --    V_PickSlipNo = @nStdCube,  
      -- (Vicky06) - End    
  
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
  
      -- (Vicky06) - Start  
      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,  
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,  
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,  
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,  
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,  
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,  
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,  
      FieldAttr15  = @cFieldAttr15   
      -- (Vicky06) - End  
  
   WHERE Mobile = @nMobile  
END  

GO