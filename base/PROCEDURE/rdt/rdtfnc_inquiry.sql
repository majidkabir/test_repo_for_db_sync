SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Inquiry                                      */
/* Copyright      : MAERSK                                              */
/*                                                                      */
/* Purpose: Inquiry                                                     */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2005-07-04 1.0  Manny      Created                                   */
/* 2006-07-03 1.1  Ung        SOS51719 Various enhancement              */
/*                            Clean up source                           */
/* 2007-03-01 1.2  Ung        Fix runtime error convert NVARCHAR to int  */
/* 2008-09-11 1.3  Shong      Use rdt.rdt_GETSKU for Performance Tuning */
/* 2008-11-18 1.4  James      Perfomance tuning (James01)               */
/* 2009-08-19 1.5  Vicky      SOS#144243 - Add QTY Hold and display     */
/*                            Lottable01-05 in next screen (Vicky01)    */
/* 2010-06-03 1.6  Shong      Remove Storer Restriction for LOC & ID Enq*/
/* 2010-09-15 1.7  Shong      Qty Available should exclude QtyReplen    */
/* 2010-10-03 1.8  James      Restructure scn & show qtyreplen (James02)*/
/* 2010-11-29 1.9  James      SOS197978 - Fix Descr not display issue & */
/*                            When press ESC go back prev rec (james03) */
/* 2011-01-26 2.0  ChewKP     SOS#202344 Allowed to display decimal in  */
/*                            RDT (ChewKP01)                            */
/* 2011-09-05 2.1  ChewKP     SOS#223334 Display Record where           */
/*                            QtyAval < 0 (ChewKP02)                    */
/* 2012-11-27 2.2  ChewKP     SOS#202344 Set display for only 5         */
/*                            Characters (CheWKP03)                     */
/* 2012-12-14 2.3  ChewKP     SOS#264888 Fix Decimal for UOM display    */
/*                            (ChewKP04)                                */
/* 2013-05-03 2.4  James      SOS276238 - Allow multi storer (james04)  */
/* 2013-11-15 2.5  SPChin     SOS295116 - Check INT for V_String21      */
/* 2015-01-09 2.6  Ung        SOS328884 Expand SKU field to 30 chars    */
/* 2015-02-13 2.7  Ung        SOS317571 Dynamic lottable                */
/* 2015-08-24 2.8  James      SOS315607 - Enable storergroup (james05)  */
/* 2016-02-01 2.9  James      Bug fix on storergroup validate (james06) */
/* 2016-02-17 3.0  James      Performance tuning (james07)              */
/* 2016-05-11 3.1  James      IN00025335 - Add storer checking (james08)*/
/* 2016-08-16 3.2  ChewKP     SOS#374245-Add Decode Function (ChewKP04) */
/* 2016-09-30 3.3  Ung        Performance tuning                        */
/* 2017-06-13 3.4  CheeMun    IN00374086-ISNULL @nErrNo                 */
/* 2018-02-08 3.5  James      WMS6250-Check status of SKU (james09)     */
/* 2018-10-29 3.6  Gan        Performance tuning                        */
/* 2019-07-11 3.7  James      WMS9710-Add DecodeSP (james10)            */
/*                            Add RDT format for ID                     */
/*                            Remove @nErrNo & @cErrMsg output          */
/*                            from rdt_Decode                           */
/* 2019-08-13 3.8  YeeKung    WMS-9385 Add Eventlog (yeekung01)         */
/* 2020-02-04 3.9  YeeKung    WMS12740 Add ExtendedinfoSP (yeekung02)   */
/* 2021-06-09 4.0  YeeKung    WMS-17216 Add LOCLookUP (yeekung03)       */ 
/* 2022-05-18 4.1  Ung        WMS-19661 Add MultiSKUBarcode             */
/* 2022-11-01 4.2  James      WMS-20940-Extend variable langth (james11)*/
/* 2023-10-02 4.3  YeeKung    WMS-23810 Add DispStyleColorSize          */
/*                           (yeekung04)                                */
/* 2019-08-30 4.4  James      WMS-10415 Remove Qty hold and replace with*/
/*                            Pendingmovein (james12)                   */
/* 2024-11-27 5.0.0 LJQ006    FCR-1292.Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Inquiry] (
   @nMobile    INT,
   @nErrNo     INT          OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_success           INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 20),

   @cPUOM_Desc  NVARCHAR( 5), -- Preferred UOM desc
   @cMUOM_Desc  NVARCHAR( 5), -- Master unit desc

   @nPQTY_Avail FLOAT, -- QTY avail in preferred UOM -- (ChewKP01)
   @nMQTY_Avail FLOAT, -- QTY avail in master UOM
   @nPQTY_Alloc FLOAT, -- QTY alloc in preferred UOM -- (ChewKP01)
   @nMQTY_Alloc FLOAT, -- QTY alloc in master UOM
   @nPUOM_Div   INT, -- UOM divider

--  (Vicky01) - Start
   @nPQTY_Hold  FLOAT, -- QTY Hold in preferred UOM -- (ChewKP01)
   @nMQTY_Hold  FLOAT, -- QTY Hold in master UOM
--  (Vicky01) - End

   @cQtyDisplayBySingleUOM NVARCHAR(1), -- (ChewKP01)
   @cRDTDefaultUOM         NVARCHAR(10),-- (ChewKP01)
   @cPackkey               NVARCHAR(10), -- (ChewKP01)
   @nMorePage              INT

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,
   @bSuccess   INT,

   @cStorerGroup  NVARCHAR( 20),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),

   @cLOT          NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cSKU          NVARCHAR( 20),
   @cSKUDescr     NVARCHAR( 60),
   @nFromScn      INT,
   @cPUOM         NVARCHAR( 1), -- Prefer UOM

   @nTotalRec     INT,
   @nCurrentRec   INT,

   @cInquiry_LOC  NVARCHAR( 10),
   @cInquiry_ID   NVARCHAR( 18),
   @cInquiry_SKU  NVARCHAR( 20),
   @nMQty_RPL     FLOAT,      -- (james02)
   @nPQty_RPL     FLOAT,      -- (james02) -- (ChewKP01)
   @nMQty_TTL     FLOAT,      -- (james02)
   @nPQty_TTL     FLOAT,      -- (james02) -- (ChewKP01)
   @nMQty_Pick    FLOAT,      -- (james02)
   @nPQty_Pick    FLOAT,      -- (james02) -- (ChewKP01)
   @cDecodeSP     NVARCHAR( 20), -- (ChewKP04)
   @cBarcode      NVARCHAR( 60), -- (ChewKP04)
   @cUPC          NVARCHAR( 30), -- (ChewKP04)
   @nQty          INT,           -- (ChewKP04)
   @cSQL          NVARCHAR( MAX), -- (ChewKP04)/(james11)
   @cSQLParam     NVARCHAR( MAX), -- (ChewKP04)/(james11)
   @cUserDefine01 NVARCHAR( 60),
   @cUserDefine02 NVARCHAR( 60),
   @cUserDefine03 NVARCHAR( 60),
   @cUserDefine04 NVARCHAR( 60),
   @cUserDefine05 NVARCHAR( 60),

   -- (james04)
   @nMultiStorer        INT,
   @cDecodeLabelNo      NVARCHAR( 20),
   @cMultiSKUBarcode    NVARCHAR( 1), 
   @cSKUBarcode         NVARCHAR( 30),
   @cSKUBarcode1        NVARCHAR( 20),
   @cSKUBarcode2        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 15),
   @cSKUStatus          NVARCHAR( 10) , -- (james09)
   @nMQTY_PMV           FLOAT,          -- (james12)
   @nPQTY_PMV           FLOAT,          -- (james1)
   
   @cLottableCode NVARCHAR( 30),
   @cLottable01 NVARCHAR( 18),
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,
   @dLottable05 DATETIME,
   @cLottable06 NVARCHAR( 30),
   @cLottable07 NVARCHAR( 30),
   @cLottable08 NVARCHAR( 30),
   @cLottable09 NVARCHAR( 30),
   @cLottable10 NVARCHAR( 30),
   @cLottable11 NVARCHAR( 30),
   @cLottable12 NVARCHAR( 30),
   @dLottable13 DATETIME,
   @dLottable14 DATETIME,
   @dLottable15 DATETIME,
   @cExtendedInfoSP     NVARCHAR( 20),    --(yeekung02)
   @cExtendedInfo       NVARCHAR( 20),     --(yeekung02)
   @cLOCLookUP          NVARCHAR(20),  --(yeekung03)
   @cDispStyleColorSize  NVARCHAR( 20), --(yeekung04)

   @cExtendedScnSP     NVARCHAR( 20),
   @nAction            INT,
   @tExtScnData        VariableTable,

 -- (james04)
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode = Lang_code,

   @cStorerGroup  = StorerGroup,
   @cStorerKey    = V_StorerKey,
   @cFacility     = Facility,

   @cLottable01 =  V_Lottable01,
   @cLottable02 =  V_Lottable02,
   @cLottable03 =  V_Lottable03,
   @dLottable04 =  V_Lottable04,
   @dLottable05 =  V_Lottable05,
   @cLottable06 =  V_Lottable06,
   @cLottable07 =  V_Lottable07,
   @cLottable08 =  V_Lottable08,
   @cLottable09 =  V_Lottable09,
   @cLottable10 =  V_Lottable10,
   @cLottable11 =  V_Lottable11,
   @cLottable12 =  V_Lottable12,
   @dLottable13 =  V_Lottable13,
   @dLottable14 =  V_Lottable14,
   @dLottable15 =  V_Lottable15,

   @cLOT       = V_LOT,
   @cLOC       = V_LOC,
   @cID        = V_ID,
   @cSKU       = V_SKU,
   @cPUOM      = V_UOM,
   @cSKUDescr  = V_SKUDescr, -- (james03)
   @nFromScn   = V_FromScn, 

   @nTotalRec     = V_Integer1,
   @nCurrentRec   = V_Integer2,
   @nPQTY_Avail   = V_Integer3,
   @nPQTY_Alloc   = V_Integer4,
   @nPQTY_PMV     = V_Integer5,
   @nMQTY_Avail   = V_Integer6,
   @nMQTY_Alloc   = V_Integer7,
   @nMQTY_PMV     = V_Integer8,
   @nMQTY_TTL     = V_Integer9,
   @nMQTY_RPL     = V_Integer10,
   @nPQTY_TTL     = V_Integer11,
   @nPQTY_RPL     = V_Integer12,
   @nMQTY_Pick    = V_Integer13,
   @nPQTY_Pick    = V_Integer14,
   @nMultiStorer  = V_Integer15,

   @cInquiry_LOC = V_String1,
   @cInquiry_ID  = V_String2,
   @cInquiry_SKU = V_String3,
   @cPUOM_Desc   = V_String6,
   @cMUOM_Desc   = V_String10,

   @cExtendedScnSP = V_String11,

   @cQtyDisplayBySingleUOM = V_String20, -- (ChewKP01)
   @cMultiSKUBarcode       = V_String21,
   @cSKUBarcode1           = V_String22, -- (james04)
   @cSKUBarcode2           = V_String23, -- (james04)
   @cLottableCode          = V_String24,
   @cSKUStatus             = V_String25, -- (james09)
   @cDecodeSP              = V_String26,
   @cExtendedInfoSP        = V_String27,  --(yeekung02)
   @cExtendedInfo          = V_String28,  --(yeekung02)
   @cLOCLookUP             = V_String29,  --(yeekung03) 
   @cDispStyleColorSize    = V_String30, --(yeekung04)

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

   @cFieldAttr01 = FieldAttr01,    @cFieldAttr02 = FieldAttr02,
   @cFieldAttr03 = FieldAttr03,    @cFieldAttr04 = FieldAttr04,
   @cFieldAttr05 = FieldAttr05,    @cFieldAttr06 = FieldAttr06,
   @cFieldAttr07 = FieldAttr07,    @cFieldAttr08 = FieldAttr08,
   @cFieldAttr09 = FieldAttr09,    @cFieldAttr10 = FieldAttr10,
   @cFieldAttr11 = FieldAttr11,    @cFieldAttr12 = FieldAttr12,
   @cFieldAttr13 = FieldAttr13,    @cFieldAttr14 = FieldAttr14,
   @cFieldAttr15 = FieldAttr15

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 555 -- Inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Inquiry
   IF @nStep = 1 GOTO Step_1   -- Scn = 801. LOC, ID, SKU
   IF @nStep = 2 GOTO Step_2   -- Scn = 802. Result screen
   IF @nStep = 3 GOTO Step_3   -- Scn = 803. Result screen - Lottable01 - 05
   IF @nStep = 4 GOTO Step_4   -- Scn = 3570  Multi SKU screen
   IF @nStep = 99 GOTO Step_99 -- Extended screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 555. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 801
   SET @nStep = 1

   -- Initiate var
   SET @cInquiry_LOC = ''
   SET @cInquiry_ID = ''
   SET @cInquiry_SKU = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cSKUBarcode = ''

   SET @nTotalRec = 0
   SET @nCurrentRec = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- (james04)
   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)

   -- (james09)
   SET @cSKUStatus  = ''
   SET @cSKUStatus = rdt.RDTGetConfig( @nFunc, 'SKUStatus', @cStorerkey)
   IF @cSKUStatus = '0'
      SET @cSKUStatus = ''

   -- (ChewKP04)
   SET @cDecodeSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)

   --(yeekung02)
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   SET @cLOCLookUP = rdt.rdtGetConfig( @nFunc, 'LOCLookUPSP', @cStorerKey)        
   IF @cLOCLookUP = '0'              
      SET @cLOCLookUP = ''         
   
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorerKey)
   SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtendedScnSP', @cStorerKey)    
     
    
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog   --(yeekung01)
     @cActionType = '1', -- Sign in function
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''

   -- Go to ext screen
   GOTO Step_99
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 801. LOC, ID, SKU screen
   LOC (field01)
   ID  (field02)
   SKU (field03)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cInquiry_LOC = @cInField01
      SET @cInquiry_ID = @cInField02
      SET @cInquiry_SKU = @cInField03
      SET @cSKUBarcode = @cInField03
      SET @cSKUBarcode1 = LEFT( @cInField03, 20)
      SET @cSKUBarcode2 = SUBSTRING( @cInField03, 21, 10)

      SET @cQtyDisplayBySingleUOM = '0'
      SET @cQtyDisplayBySingleUOM = rdt.RDTGetConfig( @nFunc, 'QtyDisplayBySingleUOM', @cStorerKey)    -- (ChewKP01)

      -- Get no field keyed-in
      DECLARE @i INT
      SET @i = 0
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL SET @i = @i + 1
      IF @cInquiry_ID  <> '' AND @cInquiry_ID  IS NOT NULL SET @i = @i + 1
      IF @cInquiry_SKU <> '' AND @cInquiry_SKU IS NOT NULL SET @i = @i + 1

      IF @i = 0
      BEGIN
         SET @nErrNo = 60676
         SET @cErrMsg = rdt.rdtgetmessage( 60676, @cLangCode, 'DSP') --'Value needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF @i > 1
      BEGIN
         SET @nErrNo = 60677
         SET @cErrMsg = rdt.rdtgetmessage( 60677, @cLangCode, 'DSP') --'ID/LOC/SKUOnly'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- By LOC
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL
      BEGIN
         IF @cLOCLookUP <> ''       --(yeekung03) 
         BEGIN        
            EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,         
               @cInquiry_LOC OUTPUT,         
               @nErrNo     OUTPUT,         
               @cErrMsg    OUTPUT        
  
            IF @nErrNo <> 0        
               GOTO Step_1_Fail        
         END    

         DECLARE @cChkFacility NVARCHAR( 5)
         SELECT @cChkFacility = Facility
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cInquiry_LOC

     -- Validate LOC
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 60678
            SET @cErrMsg = rdt.rdtgetmessage( 60678, @cLangCode, 'DSP') --'Invalid LOC'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 60679
            SET @cErrMsg = rdt.rdtgetmessage( 60679, @cLangCode, 'DSP') --'Diff facility'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      -- By ID
      IF @cInquiry_ID <> '' AND @cInquiry_ID IS NOT NULL
      BEGIN
       -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cInquiry_ID) = 0
         BEGIN
            SET @nErrNo = 60687
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_1_Fail
         END

         -- (james10)
         IF @cDecodeSP <> ''
         BEGIN
            IF @cDecodeSP = '1'
            BEGIN
               SET @cBarcode = @cInField02

               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cID     = @cInquiry_ID OUTPUT,
                  @cType   = 'ID'
            END
            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cBarcode = @cInField02

               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
                  ' @cID            OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT,   ' +
                  ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
                  ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
                  ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cBarcode       NVARCHAR( 60), ' +
                  ' @cID            NVARCHAR( 18)  OUTPUT, ' +
                  ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY           INT            OUTPUT, ' +
                  ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
                  ' @dLottable04    DATETIME       OUTPUT, ' +
                  ' @dLottable05    DATETIME       OUTPUT, ' +
                  ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
                  ' @dLottable13    DATETIME       OUTPUT, ' +
                  ' @dLottable14    DATETIME       OUTPUT, ' +
                  ' @dLottable15    DATETIME       OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cBarcode,
                  @cInquiry_ID   OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT

               IF ISNULL(@nErrNo, 0) <> 0
                  GOTO Step_1_Fail
            END
         END

         -- Validate ID
         IF NOT EXISTS (SELECT 1
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cInquiry_ID)
         BEGIN
            SET @nErrNo = 60680
            SET @cErrMsg = rdt.rdtgetmessage( 60680, @cLangCode, 'DSP') --'Invalid ID'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         -- (james07)
         SET @nTotalRec = 0
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LLI.ID = @cInquiry_ID
         AND  (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)
         AND   EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)

         IF @nTotalRec > 1
            SET @nMultiStorer = 1
      END

      /*
      -- Check storer group
      IF @cStorerGroup <> ''
      BEGIN
         -- If ID or SKU having more than 1 storer then is multi storer else turn multi storer off
         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     WHERE EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
                     AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                     GROUP BY ID
                     HAVING COUNT( DISTINCT StorerKey) > 1) OR
            EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               WHERE EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
                     AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)                             GROUP BY SKU
                     HAVING COUNT( DISTINCT StorerKey) > 1)
            SET @nMultiStorer = 1
         ELSE
         BEGIN
            -- (james06)
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.LOC = CASE WHEN ISNULL( @cInquiry_LOC, '') <> '' THEN @cInquiry_LOC ELSE LLI.LOC END
               AND LLI.ID = CASE WHEN ISNULL( @cInquiry_ID, '') <> '' THEN @cInquiry_ID ELSE LLI.ID END
               AND LLI.Sku = CASE WHEN ISNULL( @cInquiry_SKU, '') <> '' THEN @cInquiry_SKU ELSE LLI.Sku END

            -- Check storer not in storer group
            IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
            BEGIN
               SET @nErrNo = 60685
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_1_Fail
            END

            -- Set session storer
            SET @cStorerKey = @cChkStorerKey
            SET @nMultiStorer = 0
         END
      END
      */
      -- By SKU
      IF @cInquiry_SKU <> '' AND @cInquiry_SKU IS NOT NULL
      BEGIN
         SET @cDecodeLabelNo = ''
         SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)

         IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS271541
         BEGIN
            EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cSKUBarcode
            ,@c_Storerkey  = @cStorerkey
            ,@c_ReceiptKey = @nMobile
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT   -- AvlQTY

            IF ISNULL(@cErrMsg, '') <> ''
            BEGIN
               SET @cErrMsg = @cErrMsg
               GOTO Step_1_Fail
            END

            SET @cInquiry_SKU = @c_oFieled01
         END

         IF @cDecodeSP <> ''
         BEGIN
            SET @cBarcode = @cSKUBarcode

            -- Standard decode
            IF @cDecodeSP = '1'
            BEGIN
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                    @cUPC     = @cInquiry_SKU OUTPUT,
                    @cType    = 'UPC'
            END

            -- Customize decode
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
                  ' @cID          OUTPUT, @cSKU           OUTPUT, @nQTY           OUTPUT,   ' +
                  ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT, ' +
                  ' @cLottable06    OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT, ' +
                  ' @cLottable11    OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile        INT,           ' +
                  ' @nFunc          INT,           ' +
                  ' @cLangCode      NVARCHAR( 3),  ' +
                  ' @nStep          INT,           ' +
                  ' @nInputKey      INT,           ' +
                  ' @cStorerKey     NVARCHAR( 15), ' +
                  ' @cBarcode       NVARCHAR( 60), ' +
                  ' @cID            NVARCHAR( 18)  OUTPUT, ' +
                  ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY           INT            OUTPUT, ' +
                  ' @cLottable01    NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable02    NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable03    NVARCHAR( 18)  OUTPUT, ' +
                  ' @dLottable04    DATETIME       OUTPUT, ' +
                  ' @dLottable05    DATETIME       OUTPUT, ' +
                  ' @cLottable06    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable07    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable08    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable09    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable10    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable11    NVARCHAR( 30)  OUTPUT, ' +
                  ' @cLottable12    NVARCHAR( 30)  OUTPUT, ' +
                  ' @dLottable13    DATETIME       OUTPUT, ' +
                  ' @dLottable14    DATETIME       OUTPUT, ' +
                  ' @dLottable15    DATETIME       OUTPUT, ' +
                  ' @nErrNo         INT            OUTPUT, ' +
                  ' @cErrMsg        NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cBarcode,
                  @cID           OUTPUT, @cUPC           OUTPUT, @nQTY           OUTPUT,
                  @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
                  @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
                  @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
                  @nErrNo        OUTPUT, @cErrMsg        OUTPUT

               IF ISNULL(@nErrNo, 0) <> 0 --IN00374086
                  GOTO Step_1_Fail
               ELSE
                  SET @cInquiry_SKU = @cUPC
            END
         END

         -- (james07)
         SET @nTotalRec = 0
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LLI.SKU = @cInquiry_SKU
         AND  (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)
         AND   EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)

         IF @nTotalRec > 1
            SET @nMultiStorer = 1

         IF @nMultiStorer = '1'
            GOTO Skip_ValidateSKU

         DECLARE @nSKUCnt INT
         EXEC RDT.rdt_GetSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cInquiry_SKU
            ,@nSKUCnt     = @nSKUCnt   OUTPUT
            ,@bSuccess    = @bSuccess  OUTPUT
            ,@nErr        = @nErrNo    OUTPUT
            ,@cErrMsg     = @cErrMsg   OUTPUT

         -- Check SKU valid
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 60688
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
         END

         -- Validate barcode return multiple SKU
         IF @nSKUCnt > 1
         BEGIN
            IF @cMultiSKUBarcode IN ('1', '2')
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
                  @cStorerKey,
                  @cInquiry_SKU  OUTPUT,
                  @nErrNo        OUTPUT,
                  @cErrMsg       OUTPUT

               IF @nErrNo = 0 -- Populate multi SKU screen
               BEGIN
                  -- Go to Multi SKU screen
                  SET @nFromScn = @nScn
                  SET @nScn = 3570
                  SET @nStep = @nStep + 3
                  GOTO Quit
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 60689
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Step_1_Fail
            END
         END

         -- Get SKU
         EXEC [RDT].[rdt_GETSKU]
                        @cStorerKey   = @cStorerKey
         ,              @cSKU         = @cInquiry_SKU OUTPUT
         ,              @bSuccess     = @bSuccess     OUTPUT
         ,              @nErr         = @nErrNo       OUTPUT
         ,              @cErrMsg      = @cErrMsg      OUTPUT
         ,              @cSKUStatus   = @cSKUStatus

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 60681
            SET @cErrMsg = rdt.rdtgetmessage( 60681, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
         END
      END

      IF @cStorerGroup <> ''
      BEGIN
         -- (james06)
         SET @cChkStorerKey = ''

         -- (james06)
         IF ISNULL( @cInquiry_LOC, '') <> ''
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.LOC = @cInquiry_LOC
               AND (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)

         IF ISNULL( @cInquiry_ID, '') <> ''
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cInquiry_ID
               AND (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)

         IF ISNULL( @cInquiry_SKU, '') <> ''
            SELECT TOP 1 @cChkStorerKey = StorerKey
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.Sku = @cInquiry_SKU
               AND (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)

          -- (james08)
         -- Check if record exists in inventory table
         IF ISNULL( @cChkStorerKey, '') = ''
         BEGIN
            SET @nErrNo = 60686
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid record
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         -- Check storer not in storer group
         IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
         BEGIN
            SET @nErrNo = 60685
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         -- Set session storer
         SET @cStorerKey = @cChkStorerKey
         SET @nMultiStorer = 0
      END

      Skip_ValidateSKU:
      -- Get total record
      SET @nTotalRec = 0
--    Performance tuning  (James01)
--    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE
      IF @cInquiry_LOC <> ''
      BEGIN
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.LOC = @cInquiry_LOC
      END
      ELSE
      IF @cInquiry_ID <> ''
      BEGIN
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.ID  = @cInquiry_ID
      END
      ELSE
      BEGIN
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.SKU = @cInquiry_SKU
      END

      IF @nTotalRec = 0
      BEGIN
         SET @nErrNo = 60682
         SET @cErrMsg = rdt.rdtgetmessage( 60682, @cLangCode, 'DSP') --'No record'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      -- Get stock info
--    Performance tuning  (James01)
--    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE
      IF @cInquiry_LOC <> ''
      BEGIN
         SELECT TOP 1
            @cLOT = LLI.LOT,
            @cLOC = LLI.LOC,
            @cID = LLI.ID,
            @cSKU = LLI.SKU,
            @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                         ELSE    CAST( Style AS NCHAR(20)) +       
                                 CAST( Color AS NCHAR(10)) +       
                                 CAST( Size  AS NCHAR(10))  END   ,
            @cLottableCode = SKU.LottableCode,
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
            @nMQTY_Alloc = LLI.QTYAllocated,
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
             WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT),
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END,    -- (james02)
            @nMQTY_PMV = LLI.PendingMoveIN   -- (james12)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.LOC = @cInquiry_LOC
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping
      END
      ELSE IF @cInquiry_ID  <> ''
      BEGIN
         SELECT TOP 1
            @cLOT = LLI.LOT,
            @cLOC = LLI.LOC,
            @cID = LLI.ID,
            @cSKU = LLI.SKU,
            @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                         ELSE    CAST( Style AS NCHAR(20)) +       
                                 CAST( Color AS NCHAR(10)) +       
                                 CAST( Size  AS NCHAR(10))  END   ,
            @cLottableCode = SKU.LottableCode,
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
            @nMQTY_Alloc = LLI.QTYAllocated,
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT),
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END,    -- (james02)
            @nMQTY_PMV = LLI.PendingMoveIN   -- (james12)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.ID  = @cInquiry_ID
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping
      END
      ELSE
      BEGIN
         SELECT TOP 1
            @cLOT = LLI.LOT,
            @cLOC = LLI.LOC,
            @cID = LLI.ID,
            @cSKU = LLI.SKU,
            @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                         ELSE    CAST( Style AS NCHAR(20)) +       
                                 CAST( Color AS NCHAR(10)) +       
                                 CAST( Size  AS NCHAR(10))  END   ,
            @cLottableCode = SKU.LottableCode,
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
            @nMQTY_Alloc = LLI.QTYAllocated,
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT),
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END,    -- (james02)
            @nMQTY_PMV = LLI.PendingMoveIN   -- (james12)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.SKU = @cInquiry_SKU
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping
      END

      -- Validate if any result
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60683
         SET @cErrMsg = rdt.rdtgetmessage( 60683, @cLangCode, 'DSP') --'No record'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_1_Fail
      END

      -- Convert to prefer UOM QTY
      IF @cQtyDisplayBySingleUOM = '1' -- (ChewKP01)
      BEGIN
         -- GET Default Display UOM from SKUConfig First
         SET @cRDTDefaultUOM = ''

         SELECT @cRDTDefaultUOM = Data FROM dbo.SKUConfig WITH (NOLOCK)
         WHERE ConfigType = 'RDTDefaultUOM'
         AND SKU = @cSKU
         AND Storerkey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END

         -- IF DefaultUOM is not SET get the default UOM from RDT.
         IF ISNULL(@cRDTDefaultUOM,'') <> ''
         BEGIN
            SELECT @cPackkey = Packkey
            FROM dbo.SKU WITH (NOLOCK)
            WHERE SKU = @cSKU
            AND Storerkey = @cStorerkey

            SELECT TOP 1
               @cMUOM_Desc = Pack.PackUOM3,
               @cPUOM_Desc =
                  CASE
                     WHEN @cRDTDefaultUOM = Pack.PackUOM1 THEN Pack.PackUOM1 -- Case
                     WHEN @cRDTDefaultUOM = Pack.PackUOM2 THEN Pack.PackUOM2 -- Inner pack
                     WHEN @cRDTDefaultUOM = Pack.PackUOM3 THEN Pack.PackUOM3 -- Master unit
                     WHEN @cRDTDefaultUOM = Pack.PackUOM4 THEN Pack.PackUOM4 -- Pallet
                     WHEN @cRDTDefaultUOM = Pack.PackUOM8 THEN Pack.PackUOM8 -- Other unit 1
                     WHEN @cRDTDefaultUOM = Pack.PackUOM9 THEN Pack.PackUOM9 -- Other unit 2
                  END,
               @nPUOM_Div = CAST( IsNULL(
               CASE
                     WHEN @cRDTDefaultUOM = Pack.PackUOM1  THEN Pack.CaseCNT
                     WHEN @cRDTDefaultUOM = Pack.PackUOM2  THEN Pack.InnerPack
                     WHEN @cRDTDefaultUOM = Pack.PackUOM3  THEN Pack.QTY
                     WHEN @cRDTDefaultUOM = Pack.PackUOM4  THEN Pack.Pallet
                     WHEN @cRDTDefaultUOM = Pack.PackUOM8  THEN Pack.OtherUnit1
                     WHEN @cRDTDefaultUOM = Pack.PackUOM9  THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.PACK Pack WITH (NOLOCK)
            WHERE Pack.Packkey = @cPackkey
         END

         IF @nPUOM_Div = 0 -- UOM not setup
         BEGIN

            SET @cPUOM_Desc = ''
            SET @nPQTY_Alloc = 0
            SET @nPQTY_Avail = 0
            SET @nPQTY_PMV = 0 -- (james12)
            SET @nPQTY_TTL = 0 -- (james02)
            SET @nPQTY_RPL = 0 -- (james02)
            SET @nPQTY_Pick = 0
         END
         ELSE
         BEGIN
            SET @nMQTY_Avail = @nMQTY_Avail / @nPUOM_Div
            SET @nMQTY_Alloc = @nMQTY_Alloc / @nPUOM_Div
            SET @nMQTY_TTL   = @nMQTY_TTL / @nPUOM_Div  -- (james02)
            SET @nMQTY_RPL   = @nMQTY_RPL / @nPUOM_Div  -- (james02)
            SET @nMQTY_Pick  = @nMQTY_Pick / @nPUOM_Div  -- (james02)
            SET @nMQTY_PMV   = @nMQTY_PMV / @nPUOM_Div   -- (james12)
         END
      END
      ELSE
      BEGIN
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Alloc = 0
            SET @nPQTY_Avail = 0
            SET @nPQTY_PMV = 0 -- (james12)
            SET @nPQTY_TTL = 0 -- (james02)
            SET @nPQTY_RPL = 0 -- (james02)
            --SET @nMQTY_Pick = 0 -- (james02)  -- (ChewKP02)
         END
         ELSE
         BEGIN
            -- Calc QTY in preferred UOM
            SET @nPQTY_Avail = CAST(@nMQTY_Avail AS INT) / @nPUOM_Div  -- (ChewKP04)
            SET @nPQTY_Alloc = CAST(@nMQTY_Alloc AS INT) / @nPUOM_Div  -- (ChewKP04)
            SET @nPQTY_PMV   = CAST(@nMQTY_PMV   AS INT) / @nPUOM_Div -- (james12)
            SET @nPQTY_TTL   = CAST(@nMQTY_TTL   AS INT) / @nPUOM_Div  -- (james02) -- (ChewKP04)
            SET @nPQTY_RPL   = CAST(@nMQTY_RPL   AS INT) / @nPUOM_Div  -- (james02) -- (ChewKP04)
            SET @nPQTY_Pick  = CAST(@nMQTY_Pick  AS INT) / @nPUOM_Div  -- (james02) -- (ChewKP04)

            -- Calc the remaining in master unit
            SET @nMQTY_Avail = CAST(@nMQTY_Avail as INT)  % @nPUOM_Div
            SET @nMQTY_Alloc = CAST(@nMQTY_Alloc as INT)  % @nPUOM_Div
            SET @nMQTY_PMV   = CAST(@nMQTY_PMV   as INT) % @nPUOM_Div  -- (james12)
            SET @nMQTY_TTL   = CAST(@nMQTY_TTL   as INT)  % @nPUOM_Div   -- (james02)
            SET @nMQTY_RPL   = CAST(@nMQTY_RPL   as INT)  % @nPUOM_Div   -- (james02)
            SET @nMQTY_Pick  = CAST(@nMQTY_Pick  as INT)  % @nPUOM_Div   -- (james02)
         END
      END

      -- Prep next screen var
      SET @nCurrentRec = 1
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      IF @cQtyDisplayBySingleUOM = '1' -- (ChewKP01)
      BEGIN
         IF @cPUOM_Desc <> ''
         BEGIN
            SET @cOutField07 = @cPUOM_Desc
         END
         ELSE
         BEGIN
            SET @cOutField07 = @cMUOM_Desc
         END

         SET @cOutField08 = LTRIM(STR(@nMQTY_TTL,10,5))
         SET @cOutField09 = LTRIM(STR(@nMQTY_Alloc,10,5))
         SET @cOutField10 = LTRIM(STR(@nMQTY_Pick,10,5))
         SET @cOutField11 = LTRIM(STR(@nMQTY_RPL,10,5))
         SET @cOutField12 = LTRIM(STR(@nMQTY_PMV,10,5))
         SET @cOutField13 = LTRIM(STR(@nMQTY_Avail,10,5))
      END
      ELSE
      BEGIN
         -- start --(CheWKP03)
         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                            THEN @cPUOM_Desc + ' ' + @cMUOM_Desc
                            ELSE SPACE( 6) + @cMUOM_Desc END
         SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_TTL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_TTL, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_TTL, 5)   AS NVARCHAR( 5)) END
         SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_Alloc, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5)) END
         SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_Pick, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5)) END
         SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_RPL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_RPL, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_RPL, 5)   AS NVARCHAR( 5)) END -- (james02)
         SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_PMV, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_PMV, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_PMV, 5)   AS NVARCHAR( 5)) END -- (james12)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END
         -- end --(CheWKP03)
      END

      -- Add eventlog (yeekung01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '4',
         @nFunctionID   = @nFunc,
         @nMobileNo     = @nMobile,
         @cStorerKey    = @cStorerkey,
         @cFacility     = @cFacility,
         @cLocation     = @cInquiry_LOC,
         @cID           = @cInquiry_ID,
         @cSKU         = @cInquiry_SKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function (yeekung01)
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign out function
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
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cInquiry_LOC = ''
      SET @cInquiry_ID = ''
      SET @cInquiry_SKU = ''
      SET @cOutField01 = '' -- LOC
      SET @cOutField02 = '' -- ID
      SET @cOutField03 = '' -- SKU
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 802. Result screen
   Counter    (field01)
   SKU        (field02)
   Desc1      (field03
   Desc2      (field04)
   LOC        (field05)
   ID         (field06)
   UOM        (field07, 10)
   QTY AVL    (field08, 11)
   QTY ALC    (field09, 12)
   QTY HLD    (field13, 14)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1      -- Yes or Send
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 10, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

       SET @cOutField13 =''

      -- Extended info  (yeekung02)
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLOC, @cID, @cSKU, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +
               ' @nQTY,@cInquiry_LOC,@cInquiry_ID,@cInquiry_SKU,@cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cLOC          NVARCHAR( 10), ' +
               '@cID           NVARCHAR( 18), ' +
               '@cSKU          NVARCHAR( 20), ' +
               '@cLottable01   NVARCHAR( 18), ' +
               '@cLottable02   NVARCHAR( 18), ' +
               '@cLottable03   NVARCHAR( 18), ' +
               '@dLottable04   DATETIME,      ' +
               '@dLottable05   DATETIME,      ' +
               '@cLottable06   NVARCHAR( 30), ' +
               '@cLottable07   NVARCHAR( 30), ' +
               '@cLottable08   NVARCHAR( 30), ' +
               '@cLottable09   NVARCHAR( 30), ' +
               '@cLottable10   NVARCHAR( 30), ' +
               '@cLottable11   NVARCHAR( 30), ' +
               '@cLottable12   NVARCHAR( 30), ' +
               '@dLottable13   DATETIME,      ' +
               '@dLottable14   DATETIME,      ' +
               '@dLottable15   DATETIME,      ' +
               '@nQTY          INT,           ' +
               '@cInquiry_LOC  NVARCHAR( 10), ' +
               '@cInquiry_ID   NVARCHAR( 18), ' +
               '@cInquiry_SKU  NVARCHAR( 20), ' +
               '@cExtendedInfo NVARCHAR(20)  OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLOC, @cID, @cSKU,
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,
               @nQTY,@cInquiry_LOC,@cInquiry_ID,@cInquiry_SKU,@cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
              GOTO Quit

            SET @cOutField13 = @cExtendedInfo
         END
      END
      GOTO Step_99
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- LOC
      SET @cOutField02 = '' -- ID
      SET @cOutField03 = '' -- ID

      IF @cInquiry_LOC <> '' EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
      IF @cInquiry_ID  <> '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
      IF @cInquiry_SKU <> '' EXEC rdt.rdtSetFocusField @nMobile, 3

      SET @cInquiry_LOC = ''
      SET @cInquiry_ID  = ''
      SET @cInquiry_SKU  = ''

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      -- Go to ext screen
      GOTO Step_99
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 803. Result screen
   LOTTABLE01 (field01)
   LOTTABLE02 (field02)
   LOTTABLE03 (field03)
   LOTTABLE04 (field04)
   LOTTABLE05 (field05)
   LOTTABLE06 (field06)
   LOTTABLE07 (field07)
   LOTTABLE08 (field08)
   LOTTABLE09 (field09)
   LOTTABLE10 (field10)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1      -- Yes or Send
   BEGIN
      IF @nCurrentRec = @nTotalRec
      BEGIN
         IF ISNULL(@cInquiry_SKU, '') <> '' AND @nMultiStorer = 1
         BEGIN
            SET @cDecodeLabelNo = ''
            SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerkey)

            IF ISNULL(@cDecodeLabelNo,'') NOT IN ('','0')   --SOS271541
            BEGIN
               SET @cSKUBarcode = @cSKUBarcode1 + @cSKUBarcode2
               SET @c_oFieled01 = @cInquiry_SKU
               EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cSKUBarcode
               ,@c_Storerkey  = @cStorerkey
               ,@c_ReceiptKey = @nMobile
               ,@c_POKey      = ''
               ,@c_LangCode   = @cLangCode
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
               ,@c_oFieled07  = @c_oFieled07 OUTPUT
               ,@c_oFieled08  = @c_oFieled08 OUTPUT
               ,@c_oFieled09  = @c_oFieled09 OUTPUT
               ,@c_oFieled10  = @c_oFieled10 OUTPUT
               ,@b_Success    = @b_Success   OUTPUT
               ,@n_ErrNo      = @nErrNo      OUTPUT
               ,@c_ErrMsg     = @cErrMsg     OUTPUT   -- AvlQTY

               IF ISNULL(@cErrMsg, '') <> ''
               BEGIN
                  SET @cErrMsg = @cErrMsg
                  GOTO Step_1_Fail
               END

               SET @cInquiry_SKU = @c_oFieled01

               SELECT @nTotalRec = COUNT( 1)
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                  INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                  INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                  INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
                  AND LOC.Facility = @cFacility
                  AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0)
                  AND LLI.SKU = @cInquiry_SKU
            END
         END

         SET @cSKU = ''
         SET @cLOC = ''
         SET @cID = ''
         SET @cLOT = ''
         SET @nCurrentRec = 0
      END

--    Performance tuning  (James01)
--    Either LOC/ID/SKU, so break it into 3 statement and eliminate the CASE
      IF @cInquiry_LOC <> ''
      BEGIN
         SELECT TOP 1
            @cLOT = LLI.LOT,
            @cLOC = LLI.LOC,
            @cID = LLI.[ID],
            @cSKU = LLI.SKU,
            @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                         ELSE    CAST( Style AS NCHAR(20)) +       
                                 CAST( Color AS NCHAR(10)) +       
                                 CAST( Size  AS NCHAR(10))  END   ,
            @cLottableCode = SKU.LottableCode,
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
            @nMQTY_Alloc = LLI.QTYAllocated,
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),
            @nPUOM_Div = CAST(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END AS INT),
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END,    -- (james02)
            @nMQTY_PMV = LLI.PendingMoveIN   -- (james12)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.LOC = @cInquiry_LOC
            AND (LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT) > (@cSKU + @cLOC + @cID + @cLOT) -- next row
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT
      END
      ELSE IF @cInquiry_ID <> ''
      BEGIN
         SELECT TOP 1
            @cLOT = LLI.LOT,
            @cLOC = LLI.LOC,
            @cID = LLI.[ID],
            @cSKU = LLI.SKU,
            @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                         ELSE    CAST( Style AS NCHAR(20)) +       
                                 CAST( Color AS NCHAR(10)) +       
                                 CAST( Size  AS NCHAR(10))  END   ,
            @cLottableCode = SKU.LottableCode,
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
            @nMQTY_Alloc = LLI.QTYAllocated,
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),
            @nPUOM_Div = CAST(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END AS INT),
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END,    -- (james02)
            @nMQTY_PMV = LLI.PendingMoveIN   -- (james12)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.ID = @cInquiry_ID
            AND (LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT) > (@cSKU + @cLOC + @cID + @cLOT) -- next row
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT
      END
      ELSE
      BEGIN
         SELECT TOP 1
            @cLOT = LLI.LOT,
            @cLOC = LLI.LOC,
            @cID = LLI.[ID],
            @cSKU = LLI.SKU,
            @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                         ELSE    CAST( Style AS NCHAR(20)) +       
                                 CAST( Color AS NCHAR(10)) +       
                                 CAST( Size  AS NCHAR(10))  END   ,
            @cLottableCode = SKU.LottableCode,
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
            @nMQTY_Alloc = LLI.QTYAllocated,
            @nMQTY_Pick  = LLI.QTYPicked,
            @nMQTY_Avail = LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),
            @nPUOM_Div = CAST(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END AS INT),
            @cLottable01 = LA.Lottable01,
            @cLottable02 = LA.Lottable02,
            @cLottable03 = LA.Lottable03,
            @dLottable04 = LA.Lottable04,
            @dLottable05 = LA.Lottable05,
            @cLottable06 = LA.Lottable06,
            @cLottable07 = LA.Lottable07,
            @cLottable08 = LA.Lottable08,
            @cLottable09 = LA.Lottable09,
            @cLottable10 = LA.Lottable10,
            @cLottable11 = LA.Lottable11,
            @cLottable12 = LA.Lottable12,
            @dLottable13 = LA.Lottable13,
            @dLottable14 = LA.Lottable14,
            @dLottable15 = LA.Lottable15,
            @nMQty_TTL = LLI.Qty,        -- (james02)
            @nMQty_RPL = CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END,    -- (james02)
            @nMQTY_PMV = LLI.PendingMoveIN   -- (james12)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE LLI.StorerKey = CASE WHEN @nMultiStorer = 1 THEN LLI.StorerKey ELSE @cStorerKey END
            AND LOC.Facility = @cFacility
            --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
            AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
            AND LLI.SKU  = @cInquiry_SKU
            AND (LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT) > (@cSKU + @cLOC + @cID + @cLOT) -- next row
         ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT
      END

      -- Validate if any result
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 60684
         SET @cErrMsg = rdt.rdtgetmessage( 60684, @cLangCode, 'DSP') --'No record'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_1_Fail
      END

      -- Convert to prefer UOM QTY
      IF @cQtyDisplayBySingleUOM = '1' -- (ChewKP01)
      BEGIN
         -- GET Default Display UOM from SKUConfig First
         SET @cRDTDefaultUOM = ''

         SELECT @cRDTDefaultUOM = Data FROM dbo.SKUConfig WITH (NOLOCK)
         WHERE ConfigType = 'RDTDefaultUOM'
         AND SKU = @cSKU
         AND Storerkey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END

         -- IF DefaultUOM is not SET get the default UOM from RDT.
         IF ISNULL(@cRDTDefaultUOM,'') <> ''
         BEGIN
            SELECT @cPackkey = Packkey
            FROM dbo.SKU WITH (NOLOCK)
            WHERE SKU = @cSKU
            AND Storerkey = @cStorerkey


            SELECT TOP 1
            @cMUOM_Desc = Pack.PackUOM3,
            @cPUOM_Desc =
               CASE
                  WHEN @cRDTDefaultUOM = Pack.PackUOM1 THEN Pack.PackUOM1 -- Case
                  WHEN @cRDTDefaultUOM = Pack.PackUOM2 THEN Pack.PackUOM2 -- Inner pack
                  WHEN @cRDTDefaultUOM = Pack.PackUOM3 THEN Pack.PackUOM3 -- Master unit
                  WHEN @cRDTDefaultUOM = Pack.PackUOM4 THEN Pack.PackUOM4 -- Pallet
                  WHEN @cRDTDefaultUOM = Pack.PackUOM8 THEN Pack.PackUOM8 -- Other unit 1
                  WHEN @cRDTDefaultUOM = Pack.PackUOM9 THEN Pack.PackUOM9 -- Other unit 2
               END,
            @nPUOM_Div = CAST( IsNULL(
            CASE
                  WHEN @cRDTDefaultUOM = Pack.PackUOM1  THEN Pack.CaseCNT
                  WHEN @cRDTDefaultUOM = Pack.PackUOM2  THEN Pack.InnerPack
                  WHEN @cRDTDefaultUOM = Pack.PackUOM3  THEN Pack.QTY
                  WHEN @cRDTDefaultUOM = Pack.PackUOM4  THEN Pack.Pallet
                  WHEN @cRDTDefaultUOM = Pack.PackUOM8  THEN Pack.OtherUnit1
                  WHEN @cRDTDefaultUOM = Pack.PackUOM9  THEN Pack.OtherUnit2
               END, 1) AS INT)
            FROM dbo.PACK Pack WITH (NOLOCK)
            WHERE Pack.Packkey = @cPackkey
         END

         IF @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Alloc = 0
            SET @nPQTY_Avail = 0
            SET @nPQTY_PMV = 0 -- (james12)
            SET @nPQTY_TTL = 0 -- (james02)
            SET @nPQTY_RPL = 0 -- (james02)
            SET @nPQTY_Pick = 0
         END
         ELSE
         BEGIN
            SET @nMQTY_Avail = @nMQTY_Avail / @nPUOM_Div
            SET @nMQTY_Alloc = @nMQTY_Alloc / @nPUOM_Div
            SET @nMQTY_PMV   = @nMQTY_PMV / @nPUOM_Div  -- (james12)
            SET @nMQTY_TTL   = @nMQTY_TTL / @nPUOM_Div  -- (james02)
            SET @nMQTY_RPL   = @nMQTY_RPL / @nPUOM_Div  -- (james02)
            SET @nMQTY_Pick  = @nMQTY_Pick / @nPUOM_Div  -- (james02)
         END
      END
      ELSE
      BEGIN
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0 -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY_Alloc = 0
            SET @nPQTY_Avail = 0
            SET @nPQTY_PMV = 0 -- (james12)
            SET @nPQTY_TTL = 0 -- (james02)
            SET @nPQTY_RPL = 0 -- (james02)
         END
         ELSE
         BEGIN
            -- Calc QTY in preferred UOM
            SET @nPQTY_Avail = CAST(@nMQTY_Avail AS INT) / @nPUOM_Div -- (ChewKP04)
            SET @nPQTY_Alloc = CAST(@nMQTY_Alloc AS INT) / @nPUOM_Div -- (ChewKP04)
            SET @nPQTY_PMV   = CAST(@nMQTY_PMV   AS INT) / @nPUOM_Div -- (james12)
            SET @nPQTY_TTL   = CAST(@nMQTY_TTL   AS INT) / @nPUOM_Div  -- (james02)  -- (ChewKP04)
            SET @nPQTY_RPL   = CAST(@nMQTY_RPL   AS INT) / @nPUOM_Div  -- (james02)  -- (ChewKP04)
            SET @nPQTY_Pick  = CAST(@nMQTY_Pick  AS INT) / @nPUOM_Div  -- (james02)  -- (ChewKP04)

            -- Calc the remaining in master unit
            SET @nMQTY_Avail = CAST(@nMQTY_Avail as INT) % @nPUOM_Div
            SET @nMQTY_Alloc = CAST(@nMQTY_Alloc as INT) % @nPUOM_Div
            SET @nMQTY_PMV   = CAST(@nMQTY_PMV   as INT) % @nPUOM_Div  -- (james12)
            SET @nMQTY_TTL   = CAST(@nMQTY_TTL   as INT) % @nPUOM_Div  -- (james02)
            SET @nMQTY_RPL   = CAST(@nMQTY_RPL  as INT) % @nPUOM_Div   -- (james02)
            SET @nMQTY_Pick  = CAST(@nMQTY_Pick  as INT) % @nPUOM_Div   -- (james02)
         END
      END

      -- Prep next screen var
      SET @nCurrentRec = @nCurrentRec + 1
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID
--      IF @cPUOM_Desc = ''
--      BEGIN
--         SET @cOutField07 = '' -- @cPUOM_Desc
--         SET @cOutField08 = '' -- @nPQTY_Alloc
--         SET @cOutField09 = '' -- @nPQTY_Avail
--         SET @cOutField13 = '' -- @nPQTY_Hold -- (Vicky01)
--      END
--      ELSE
--      BEGIN
--         SET @cOutField07 = @cPUOM_Desc
--         SET @cOutField08 = CAST( @nPQTY_Avail AS NVARCHAR( 5))
--         SET @cOutField09 = CAST( @nPQTY_Alloc AS NVARCHAR( 5))
--         SET @cOutField13 = CAST( @nPQTY_Hold  AS NVARCHAR( 5)) -- (Vicky01)
--      END
      IF @cQtyDisplayBySingleUOM = '1' -- (ChewKP01)
      BEGIN
         IF @cPUOM_Desc <> ''
         BEGIN
            SET @cOutField07 = @cPUOM_Desc
         END
         ELSE
         BEGIN
            SET @cOutField07 = @cMUOM_Desc
         END

         SET @cOutField08 = LTRIM(STR(@nMQTY_TTL,10,5))
         SET @cOutField09 = LTRIM(STR(@nMQTY_Alloc,10,5))
         SET @cOutField10 = LTRIM(STR(@nMQTY_Pick,10,5))
         SET @cOutField11 = LTRIM(STR(@nMQTY_RPL,10,5))
         SET @cOutField12 = LTRIM(STR(@nMQTY_PMV,10,5))
         SET @cOutField13 = LTRIM(STR(@nMQTY_Avail,10,5))
      END
      ELSE
      BEGIN
         -- start --(CheWKP03)
         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                            THEN @cPUOM_Desc + ' ' + @cMUOM_Desc
                            ELSE SPACE( 6) + @cMUOM_Desc END
         SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_TTL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_TTL, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_TTL, 5)   AS NVARCHAR( 5)) END -- (james02)
         SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_Alloc, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST(LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Alloc, 5) AS NVARCHAR( 5)) END
         SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_Pick, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Pick, 5) AS NVARCHAR( 5)) END
         SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_RPL, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_RPL, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_RPL, 5)   AS NVARCHAR( 5)) END -- (james02)
         SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_PMV, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_PMV, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_PMV, 5)  AS NVARCHAR( 5)) END -- (james12)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END
         -- end --(CheWKP03)
      END

      -- Remain in current screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
--      SET @nCurrentRec = 1  -- (james03)
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                         THEN @cPUOM_Desc + ' ' + @cMUOM_Desc
                         ELSE SPACE( 6) + @cMUOM_Desc END
      SET @cOutField08 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_TTL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_TTL AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_TTL   AS NVARCHAR( 5)) END
      SET @cOutField09 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Alloc AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Alloc AS NVARCHAR( 5)) END
      SET @cOutField10 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Pick AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Pick AS NVARCHAR( 5)) END
      SET @cOutField11 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_RPL AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_RPL AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_RPL   AS NVARCHAR( 5)) END -- (james02)
      SET @cOutField12 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_PMV AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_PMV AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_PMV  AS NVARCHAR( 5)) END -- (james12)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END

      SET @cExtendedInfo=''
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 3570. Multi SKU
   SKU         (Field01)
   SKUDesc1    (Field02)
   SKUDesc2   (Field03)
   SKU         (Field04)
   SKUDesc1    (Field05)
   SKUDesc2    (Field06)
   SKU         (Field07)
   SKUDesc1    (Field08)
   SKUDesc2    (Field09)
   Option      (Field10, input)
********************************************************************************/
Step_4:
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
         @cStorerKey,
         @cInquiry_SKU  OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END
   END

   -- Prepare SKU screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = @cInquiry_SKU

   EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

   -- Go to next screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep - 3
   
   -- Go to ext screen
   GOTO Step_99
END
GOTO Quit

/********************************************************************************
ExtScn. Extend screen for customized requirements
********************************************************************************/
Step_99:
BEGIN
   IF @cExtendedScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
      BEGIN
         SET @nAction = 0

         INSERT INTO @tExtScnData (Variable, Value)
         VALUES
            ('@nTotalRec', CAST(@nTotalRec AS NVARCHAR(50))),
            ('@nCurrentRec', CAST(@nCurrentRec AS NVARCHAR(50))),
            ('@cInquiry_LOC', @cInquiry_LOC),
            ('@cInquiry_ID', @cInquiry_ID),
            ('@cInquiry_SKU', @cInquiry_SKU),
            ('@cPUOM_Desc', @cPUOM_Desc),
            ('@cMUOM_Desc', @cMUOM_Desc),
            ('@cSKUBarcode', @cSKUBarcode),
            ('@cSKUBarcode1', @cSKUBarcode1),
            ('@cSKUBarcode2', @cSKUBarcode2),
            ('@cLOC', @cLOC),
            ('@cID', @cID),
            ('@cSKU', @cSKU),
            ('@cSKUDescr', @cSKUDescr),
            ('@cPUOM_Desc', @cPUOM_Desc),
            ('@cMUOM_Desc', @cMUOM_Desc),
            ('@nMQTY_TTL', CAST(@nMQTY_TTL AS NVARCHAR(50))),
            ('@nMQTY_Alloc', CAST(@nMQTY_Alloc AS NVARCHAR(50))),
            ('@nMQTY_Pick', CAST(@nMQTY_Pick AS NVARCHAR(50))),
            ('@nMQTY_RPL', CAST(@nMQTY_RPL AS NVARCHAR(50))),
            ('@nMQTY_PMV', CAST(@nMQTY_PMV AS NVARCHAR(50))),
            ('@nMQTY_Avail', CAST(@nMQTY_Avail AS NVARCHAR(50))),
            ('@nPQTY_TTL', CAST(@nPQTY_TTL AS NVARCHAR(50))),
            ('@nPQTY_Alloc', CAST(@nPQTY_Alloc AS NVARCHAR(50))),
            ('@nPQTY_Pick', CAST(@nPQTY_Pick AS NVARCHAR(50))),
            ('@nPQTY_RPL', CAST(@nPQTY_RPL AS NVARCHAR(50))),
            ('@nPQTY_PMV', CAST(@nPQTY_PMV AS NVARCHAR(50))),
            ('@nPQTY_Avail', CAST(@nPQTY_Avail AS NVARCHAR(50)));

         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScnSP,  --855ExtScn01
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData,
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

            IF @cExtendedScnSP = 'rdt_555ExtScn01'
            BEGIN
               IF @nScn = 802
               BEGIN
                  IF @nInputKey = 1
                  BEGIN
                     SET @cLottableCode = @cUDF01
                     SET @cInquiry_ID   = @cUDF02
                     SET @cInquiry_SKU  = @cUDF03
                     SET @cInquiry_LOC  = @cUDF04
                     SET @cSKUBarcode   = @cUDF05
                     SET @cSKUBarcode1  = @cUDF06
                     SET @cSKUBarcode2  = @cUDF07
                     SET @nTotalRec     = CAST(@cUDF08 AS INT)
                     SET @nCurrentRec   = CAST(@cUDF09 AS INT)

                     SET @cLOC = @cUDF10
                     SET @cID = @cUDF11
                     SET @cSKU = @cUDF12
                     SET @cSKUDescr = @cUDF13
                     SET @cPUOM_Desc = @cUDF14
                     SET @cMUOM_Desc = @cUDF15

                     SET @nMQTY_TTL = CAST(@cUDF16 AS INT)
                     SET @nMQTY_Alloc = CAST(@cUDF17 AS INT)
                     SET @nMQTY_Pick = CAST(@cUDF18 AS INT)
                     SET @nMQTY_RPL = CAST(@cUDF19 AS INT)
                     SET @nMQTY_PMV = CAST(@cUDF20 AS INT)
                     SET @nMQTY_Avail = CAST(@cUDF21 AS INT)

                     SET @nPQTY_TTL = CAST(@cUDF22 AS INT)
                     SET @nPQTY_Alloc = CAST(@cUDF23 AS INT)
                     SET @nPQTY_Pick = CAST(@cUDF24 AS INT)
                     SET @nPQTY_RPL = CAST(@cUDF25 AS INT)
                     SET @nPQTY_PMV = CAST(@cUDF26 AS INT)
                     SET @nPQTY_Avail = CAST(@cUDF27 AS INT)
                     
                  END
               END
               IF @nScn = @nMenu
               BEGIN
                  SET @nFunc = @nMenu
               END
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
   UPDATE RDT.RDTMOBREC with (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      Facility  = @cFacility,

      V_StorerKey  = @cStorerKey,
      V_LOT        = @cLOT,
      V_LOC        = @cLOC,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_UOM        = @cPUOM,
      V_SKUDescr   = @cSKUDescr, -- (james03)
      V_FromScn    = @nFromScn, 

      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,
      V_Lottable06 = @cLottable06,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,
      V_Lottable09 = @cLottable09,
      V_Lottable10 = @cLottable10,
      V_Lottable11 = @cLottable11,
      V_Lottable12 = @cLottable12,
      V_Lottable13 = @dLottable13,
      V_Lottable14 = @dLottable14,
      V_Lottable15 = @dLottable15,

      V_String1  = @cInquiry_LOC,
      V_String2  = @cInquiry_ID,
      V_String3  = @cInquiry_SKU,

      --V_String4 = @nTotalRec,
      --V_String5 = @nCurrentRec,

      V_Integer1  = @nTotalRec,
      V_Integer2  = @nCurrentRec,
      V_Integer3  = @nPQTY_Avail,
      V_Integer4  = @nPQTY_Alloc,
      V_Integer5  = @nPQTY_PMV,
      V_Integer6  = @nMQTY_Avail,
      V_Integer7  = @nMQTY_Alloc,
      V_Integer8  = @nMQTY_PMV,
      V_Integer9  = @nMQTY_TTL,
      V_Integer10 = @nMQTY_RPL,
      V_Integer11 = @nPQTY_TTL,
      V_Integer12 = @nPQTY_RPL,
      V_Integer13 = @nMQTY_Pick,
      V_Integer14 = @nPQTY_Pick,
      V_Integer15 = @nMultiStorer,

      -- (Vicky01) - Start
      V_String6  = @cPUOM_Desc,
      --V_String7  = @nPQTY_Avail,
      --V_String8  = @nPQTY_Alloc,
      --V_String9  = @nPQTY_Hold,
      --V_String10 = @cMUOM_Desc,
      --V_String11 = @nMQTY_Avail,
      --V_String12 = @nMQTY_Alloc,
      --V_String13 = @nMQTY_Hold,
      --V_String14 = @nMQTY_TTL,
      --V_String15 = @nMQTY_RPL,
      --V_String16 = @nPQTY_TTL,
      --V_String17 = @nPQTY_RPL,
      --V_String18 = @nMQTY_Pick,
      --V_String19 = @nPQTY_Pick,

      -- (Vicky01) - End
      V_String11 = @cExtendedScnSP,

      V_String20 = @cQtyDisplayBySingleUOM, -- (ChewKP01)
      V_String21 = @cMultiSKUBarcode,
      V_String22 = @cSKUBarcode1,           -- (james04)
      V_String23 = @cSKUBarcode2,
      V_String24 = @cLottableCode,
      V_String25 = @cSKUStatus,             -- (james09)
      V_String26 = @cDecodeSP,
      V_String27 = @cExtendedInfoSP,         --(yeekung02)
      V_String28 = @cExtendedInfo,           --(yeekung02)
      V_String29 = @cLOCLookUP,
      V_String30 = @cDispStyleColorSize,     --(yeekung04)

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