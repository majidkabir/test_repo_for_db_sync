SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Inquiry_V7                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Inquiry                                                     */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author     Purposes                                 */
/* 20-Apr-2018 1.0  James      WMS4458. Created                         */
/* 12-Jul-2018 1.1  James      INC0300607 - Fix dynamic lottable not    */
/*                             display correctly (james01)              */
/* 29-Oct-2018 1.2  Gan        Performance tuning                       */
/* 01-Nov-2018 1.3  James      Bug fix (james02)                        */
/* 15-Nov-2018 1.4  Ung        Temp fix for HM emergency Nov 11         */
/* 03-Jan-2019 1.5  James      WMS7485 - Enhance on sku/upc input       */
/*                             handling (james03)                       */
/* 05-Jun-2019 1.6  Ung        WMS7485 Temporary fix                    */
/* 30-Aug-2019 1.7  James      WMS-10415 Remove Qty hold and replace    */
/*                             with Pendingmovein (james04)             */
/* 09-Jun-2021 1.8  YeeKung    WMS-17216 Add LOCLookUP (yeekung01)      */
/* 27-Sep-2023 1.9  Ung        WMS-23678 Split Decode for ID and SKU    */
/* 26-Oct-2023 2.0  YeeKung    WMS-23936 Add LocLookUPSP (yeekung02)    */
/* 20-Nov-2023 2.1  YeeKung    WMS-23981 Add new sku config screen      */
/*                             (yeekung03)                              */
/* 13-Dec-2023 2.2  Ung        Fix QTY not group by lottables           */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_Inquiry_V7] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
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

   @cPUOM_Desc  NVARCHAR( 5),
   @cMUOM_Desc  NVARCHAR( 5),

   @nPQTY_Avail FLOAT,
   @nMQTY_Avail FLOAT,
   @nPQTY_Alloc FLOAT,
   @nMQTY_Alloc FLOAT,
   @nPUOM_Div   INT,
   @nPQTY_Hold  FLOAT,
   @nMQTY_Hold  FLOAT,
   @nPQTY_PMV   FLOAT,
   @nMQTY_PMV   FLOAT,

   @cRDTDefaultUOM         NVARCHAR(10),
   @cPackkey               NVARCHAR(10),
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
   @cPUOM         NVARCHAR( 1),

   @nTotalRec     INT,
   @nCurrentRec   INT,

   @cInquiry_LOC  NVARCHAR( 30),
   @cInquiry_ID   NVARCHAR( 18),
   @cInquiry_SKU  NVARCHAR( 20),
   @nMQty_RPL     FLOAT,
   @nPQty_RPL     FLOAT,
   @nMQty_TTL     FLOAT,
   @nPQty_TTL     FLOAT,
   @nMQty_Pick    FLOAT,
   @nPQty_Pick    FLOAT,
   @cDecodeSP     NVARCHAR( 20),
   @cBarcode      NVARCHAR( 60),
   @nQty          INT,
   @cSQL          NVARCHAR( MAX),
   @cSQLParam     NVARCHAR( MAX),
   @cUserDefine01 NVARCHAR( 60),
   @cUserDefine02 NVARCHAR( 60),
   @cUserDefine03 NVARCHAR( 60),
   @cUserDefine04 NVARCHAR( 60),
   @cUserDefine05 NVARCHAR( 60),
   @cSKUConfig    NVARCHAR( 20),

   @cDecodeLabelNo      NVARCHAR( 20),
   @cSKUBarcode         NVARCHAR( 30),
   @cSKUBarcode1        NVARCHAR( 20),
   @cSKUBarcode2        NVARCHAR( 20),
   @cChkStorerKey       NVARCHAR( 15),
   @cCustomInquiryRule_SP  NVARCHAR( 20),
   @cType               NVARCHAR( 10),

   @nQTY_TTL            INT,
   @nQTY_Hold           INT,
   @nQTY_Alloc          INT,
   @nQTY_Pick           INT,
   @nQTY_RPL            INT,
   @nQTY_Avail          INT,
   @nSKUCnt             INT,

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
   @cHasLottable  NVARCHAR( 1),
   @cLOCLookUP   NVARCHAR(20),  --(yeekung01)

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
   @cFieldAttr15 NVARCHAR( 1)

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
   @cSKUDescr  = V_SKUDescr,

   @nTotalRec    = V_Integer1,
   @nCurrentRec  = V_Integer2,
   @nPQTY_Avail  = V_Integer3,
   @nPQTY_Alloc  = V_Integer4,
   @nPQTY_PMV    = V_Integer5,
   @nMQTY_Avail  = V_Integer6,
   @nMQTY_Alloc  = V_Integer7,
   @nMQTY_PMV    = V_Integer8,
   @nMQTY_TTL    = V_Integer9,
   @nMQTY_RPL    = V_Integer10,
   @nPQTY_TTL    = V_Integer11,
   @nPQTY_RPL    = V_Integer12,
   @nMQTY_Pick   = V_Integer13,
   @nPQTY_Pick   = V_Integer14,

   @cInquiry_LOC = V_String1,
   @cInquiry_ID  = V_String2,
   @cInquiry_SKU = V_String3,
   @cPUOM_Desc   = V_String4,
   @cMUOM_Desc   = V_String5,
   @cDecodeSP    = V_String6,
   @cHasLottable = V_String7,
   @cSKUBarcode1           = V_String8,
   @cSKUBarcode2           = V_String9,
   @cLottableCode          = V_String10,
   @cCustomInquiryRule_SP  = V_String11,
   @cType                  = V_String12,
   @cLOCLookUP             = V_String13,  --(yeekung01)
   @cUserDefine01          = V_String14,
   @cUserDefine02          = V_String15,
   @cUserDefine03          = V_String16,
   @cUserDefine04          = V_String17,
   @cUserDefine05          = V_String18,
   @cSKUConfig             = V_String19,

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

-- Screen constant
DECLARE
   @nStep_LocIDSKU   INT,  @nScn_LocIDSKU   INT,
   @nStep_Result     INT,  @nScn_Result     INT,
   @nStep_Lottables  INT,  @nScn_Lottables  INT,
   @nStep_DataInquiry INT, @nScn_DataInquiry INT


SELECT
   @nStep_LocIDSKU   = 1,  @nScn_LocIDSKU    = 5140,
   @nStep_Result     = 2,  @nScn_Result      = 5141,
   @nStep_Lottables  = 3,  @nScn_Lottables   = 5142,
   @nStep_DataInquiry  = 4,  @nScn_DataInquiry   = 5143

IF @nFunc = 628 -- Inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_Start       -- Func = Inquiry
   IF @nStep = 1 GOTO Step_LocIDSKU    -- Scn = 5140. LOC, ID, SKU
   IF @nStep = 2 GOTO Step_Result      -- Scn = 5141. Result screen
   IF @nStep = 3 GOTO Step_Lottables   -- Scn = 5142. Result screen, Lottable
   IF @nStep = 4 GOTO Step_DataInquiry   -- Scn = 5143. Result screen, Extra data inquiry (Like SKU)
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 628. Menu
********************************************************************************/
Step_Start:
BEGIN
   -- Set the entry point
   SET @nScn = @nScn_LocIDSKU
   SET @nStep = @nStep_LocIDSKU

   -- Initiate var
   SET @cInquiry_LOC = ''
   SET @cInquiry_ID = ''
   SET @cInquiry_SKU = ''
   SET @cLOC = ''
   SET @cID = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cSKUBarcode = ''
   SET @cType = ''
   SET @cSKUConfig = ''

   SET @nTotalRec = 0
   SET @nCurrentRec = 0

   -- Get prefer UOM
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   SET @cCustomInquiryRule_SP = rdt.RDTGetConfig( @nFunc, 'CustomInquiryRule_SP', @cStorerKey)
   IF @cCustomInquiryRule_SP = '0'
      SET @cCustomInquiryRule_SP = ''

   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerkey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   --(yeekung01)
   SET @cLOCLookUP = rdt.rdtGetConfig( @nFunc, 'LOCLookUPSP', @cStorerKey)
   IF @cLOCLookUP = '0'
      SET @cLOCLookUP = ''

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 801. LOC, ID, SKU screen
   LOC (field01)
   ID  (field02)
   SKU (field03)
********************************************************************************/
Step_LocIDSKU:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cInquiry_LOC = @cInField01
      SET @cInquiry_ID = @cInField02
      SET @cInquiry_SKU = @cInField03

      -- Get no field keyed-in
      DECLARE @i INT
      SET @i = 0
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL SET @i = @i + 1
      IF @cInquiry_ID  <> '' AND @cInquiry_ID  IS NOT NULL SET @i = @i + 1
      IF @cInquiry_SKU <> '' AND @cInquiry_SKU IS NOT NULL SET @i = @i + 1

      IF @i = 0
      BEGIN
         SET @nErrNo = 123251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Value needed'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      IF @i > 1
      BEGIN
         SET @nErrNo = 123252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ID/LOC/SKUOnly'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_1_Fail
      END

      SELECT @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL,  @dLottable05 = NULL,
             @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',    @cLottable10 = '',
             @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL,  @dLottable15 = NULL,
             @cLOT = '', @cLOC = '', @cID = '', @cSKU = '', @cHasLottable = '', @nTotalRec = 0

      IF @cDecodeSP <> ''
      BEGIN
         -- Only one value can key in
         SELECT @cBarcode =
            CASE
               WHEN @cInquiry_LOC <> '' THEN @cInField01
               WHEN @cInquiry_ID  <> '' THEN @cInField02
               WHEN @cInquiry_SKU <> '' THEN @cInField03
            END

         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            IF @cInquiry_ID <> ''
            BEGIN
               SET @cID = ''
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cID         = @cID         OUTPUT,
                  @nQTY        = @nQTY        OUTPUT,
                  @cLottable01 = @cLottable01 OUTPUT,
                  @cLottable02 = @cLottable02 OUTPUT,
                  @cLottable03 = @cLottable03 OUTPUT,
                  @dLottable04 = @dLottable04 OUTPUT,
                  @dLottable05 = @dLottable05 OUTPUT,
                  @cLottable06 = @cLottable06 OUTPUT,
                  @cLottable07 = @cLottable07 OUTPUT,
                  @cLottable08 = @cLottable08 OUTPUT,
                  @cLottable09 = @cLottable09 OUTPUT,
                  @cLottable10 = @cLottable10 OUTPUT,
                  @cLottable11 = @cLottable11 OUTPUT,
                  @cLottable12 = @cLottable12 OUTPUT,
                  @dLottable13 = @dLottable13 OUTPUT,
                  @dLottable14 = @dLottable14 OUTPUT,
                  @dLottable15 = @dLottable15 OUTPUT,
                  @cType       = 'ID'

               IF @cID <> ''
                  SET @cInquiry_ID = @cID
            END

            IF @cInquiry_SKU <> ''
            BEGIN
               DECLARE @cUPC NVARCHAR( 30) = ''
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
                  @cUPC        = @cUPC        OUTPUT,
                  @nQTY        = @nQTY        OUTPUT,
                  @cLottable01 = @cLottable01 OUTPUT,
                  @cLottable02 = @cLottable02 OUTPUT,
                  @cLottable03 = @cLottable03 OUTPUT,
                  @dLottable04 = @dLottable04 OUTPUT,
                  @dLottable05 = @dLottable05 OUTPUT,
                  @cLottable06 = @cLottable06 OUTPUT,
                  @cLottable07 = @cLottable07 OUTPUT,
                  @cLottable08 = @cLottable08 OUTPUT,
                  @cLottable09 = @cLottable09 OUTPUT,
                  @cLottable10 = @cLottable10 OUTPUT,
                  @cLottable11 = @cLottable11 OUTPUT,
                  @cLottable12 = @cLottable12 OUTPUT,
                  @dLottable13 = @dLottable13 OUTPUT,
                  @dLottable14 = @dLottable14 OUTPUT,
                  @dLottable15 = @dLottable15 OUTPUT,
                  @cType       = 'UPC'

               IF @cUPC <> ''
                  SET @cInquiry_SKU = @cUPC
            END
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cBarcode, ' +
               ' @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT,   ' +
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
               ' @cLOC           NVARCHAR( 10)  OUTPUT, ' +
               ' @cID            NVARCHAR( 18)  OUTPUT, ' +
               ' @cSKU           NVARCHAR( 20)  OUTPUT, ' +
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
               @cLOC          OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT,
               @cLottable01   OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, @dLottable04    OUTPUT, @dLottable05    OUTPUT,
               @cLottable06   OUTPUT, @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, @cLottable10    OUTPUT,
               @cLottable11   OUTPUT, @cLottable12    OUTPUT, @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @nErrNo        OUTPUT, @cErrMsg        OUTPUT

            IF ISNULL(@nErrNo, 0) <> 0
               GOTO Step_1_Fail
            ELSE
            BEGIN
               -- Decode can output any value
               SET @cInquiry_LOC = CASE WHEN @cLOC <> '' THEN @cLOC ELSE '' END
               SET @cInquiry_ID = CASE WHEN @cID <> '' THEN @cID ELSE '' END
               SET @cInquiry_SKU = CASE WHEN @cSKU <> '' THEN @cSKU ELSE '' END
/*
               IF @cInquiry_LOC <> '' AND @cLOC <> '' SET @cInquiry_LOC = @cLOC
               IF @cInquiry_ID  <> '' AND @cID  <> '' SET @cInquiry_ID  = @cID
               IF @cInquiry_SKU <> '' AND @cSKU <> '' SET @cInquiry_SKU = @cSKU
*/
            END
         END
      END

      -- By LOC
      IF @cInquiry_LOC <> '' AND @cInquiry_LOC IS NOT NULL
      BEGIN
         IF @cLOCLookUP <> ''       --(yeekung01)
         BEGIN

            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cLOCLookUP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cLOCLookUP)
               + ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey'
               + ' , @cFacility, @cInquiry_LOC OUTPUT,@nErrNo     OUTPUT, @cErrMsg    OUTPUT '
               SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cFacility      NVARCHAR( 10), ' +
               ' @cInquiry_LOC   NVARCHAR( 30) OUTPUT, ' +
               ' @nErrNo         INT OUTPUT, ' +
               ' @cErrMsg        NVARCHAR(MAX) OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey
                  , @cFacility, @cInquiry_LOC OUTPUT,@nErrNo     OUTPUT,@cErrMsg    OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_1_Fail
            END
            ELSE IF  @cLOCLookUP='1'
            BEGIN
               EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
                  @cInquiry_LOC OUTPUT,
                  @nErrNo     OUTPUT,
                  @cErrMsg    OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_1_Fail
            END
         END


         DECLARE @cChkFacility NVARCHAR( 5)
         SELECT @cChkFacility = Facility
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cInquiry_LOC

         -- Validate LOC
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 123253
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 123254
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END
      END

      -- By ID
      IF @cInquiry_ID <> '' AND @cInquiry_ID IS NOT NULL
      BEGIN
         -- Validate ID
         IF NOT EXISTS (SELECT 1
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
            WHERE LOC.Facility = @cFacility
               AND LLI.ID = @cInquiry_ID)
         BEGIN
            SET @nErrNo = 123255
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid ID'
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_1_Fail
         END

         SET @nTotalRec = 0
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LLI.ID = @cInquiry_ID
         AND  (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)
         AND   EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
      END

      --WMS7485
      -- By SKU
      IF @cInquiry_SKU <> '' AND @cInquiry_SKU IS NOT NULL
      BEGIN
         EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cInquiry_SKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @n_Err         OUTPUT
         ,@cErrMsg     = @c_ErrMsg      OUTPUT

         -- Validate SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 123257
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
         END

         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 123258
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiSKUBarcod'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
         END

         EXEC [RDT].[rdt_GETSKU]
            @cStorerKey   = @cStorerKey
           ,@cSKU         = @cInquiry_SKU OUTPUT
           ,@bSuccess     = @bSuccess     OUTPUT
           ,@nErr         = @nErrNo       OUTPUT
           ,@cErrMsg      = @cErrMsg      OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 123256
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_1_Fail
         END

         SET @nTotalRec = 0
         SELECT @nTotalRec = COUNT( 1)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
         WHERE LOC.Facility = @cFacility
         AND   LLI.SKU = @cInquiry_SKU
         AND  (LLI.QTY + LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyExpected <> 0)
         AND   EXISTS (SELECT 1 FROM dbo.StorerGroup ST WITH (NOLOCK) WHERE LLI.StorerKey = ST.StorerKey AND StorerGroup = @cStorerKey)
      END

      IF @cCustomInquiryRule_SP <> '' AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomInquiryRule_SP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomInquiryRule_SP) +
           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM, ' +
           ' @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU, ' +
           ' @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT, ' +
           ' @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT, ' +
           ' @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT, ' +
           ' @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT, ' +
           ' @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT, ' +
           ' @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT, ' +
           ' @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT, ' +
           ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, ' +
           ' @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT, ' +
           ' @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, ' +
           ' @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT, ' +
           ' @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
           ' @cHasLottable   OUTPUT, @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT, ' +
           ' @nErrNo         OUTPUT, @cErrMsg        OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,                  '+
            '@nFunc           INT,                  '+
            '@cLangCode       NVARCHAR( 3),         '+
            '@nStep           INT,                  '+
            '@nInputKey       INT,                  '+
            '@cFacility       NVARCHAR( 5),         '+
            '@cType           NVARCHAR( 10),        '+
            '@cStorerkey      NVARCHAR( 15),        '+
            '@cPUOM           NVARCHAR( 1),         '+
            '@cInquiry_LOC    NVARCHAR( 10),        '+
            '@cInquiry_ID     NVARCHAR( 18),        '+
            '@cInquiry_SKU    NVARCHAR( 20),        '+
            '@cLOT            NVARCHAR( 10)  OUTPUT,'+
            '@cLOC            NVARCHAR( 10)  OUTPUT,'+
            '@cID             NVARCHAR( 18)  OUTPUT,'+
            '@cSKU            NVARCHAR( 20)  OUTPUT,'+
            '@cSKUDescr       NVARCHAR( 60)  OUTPUT,'+
            '@nTotalRec       INT            OUTPUT,'+
            '@nMQTY_TTL       INT            OUTPUT,'+
            '@nMQTY_PMV       INT            OUTPUT,'+
            '@nMQTY_Alloc     INT            OUTPUT,'+
            '@nMQTY_Pick      INT            OUTPUT,'+
            '@nMQTY_RPL       INT            OUTPUT,'+
            '@nMQTY_Avail     INT            OUTPUT,'+
            '@nPQTY_TTL       INT            OUTPUT,'+
            '@nPQTY_PMV       INT            OUTPUT,'+
            '@nPQTY_Alloc     INT            OUTPUT,'+
            '@nPQTY_Pick      INT            OUTPUT,'+
            '@nPQTY_RPL       INT            OUTPUT,'+
            '@nPQTY_Avail     INT            OUTPUT,'+
            '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
            '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
            '@cLottableCode   NVARCHAR( 30)  OUTPUT,'+
            '@cLottable01     NVARCHAR( 18)  OUTPUT,'+
            '@cLottable02     NVARCHAR( 18)  OUTPUT,'+
            '@cLottable03     NVARCHAR( 18)  OUTPUT,'+
            '@dLottable04     DATETIME       OUTPUT,'+
            '@dLottable05     DATETIME       OUTPUT,'+
            '@cLottable06     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable07     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable08     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable09     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable10     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable11     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable12     NVARCHAR( 30)  OUTPUT,'+
            '@dLottable13     DATETIME       OUTPUT,'+
            '@dLottable14     DATETIME       OUTPUT,'+
            '@dLottable15     DATETIME       OUTPUT,'+
            '@cHasLottable    NVARCHAR( 1)   OUTPUT,'+
            '@cUserDefine01   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine02   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine03   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine04   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine05   NVARCHAR( 60)  OUTPUT,'+
            '@cSKUConfig      NVARCHAR( 60)  OUTPUT,'+
            '@nErrNo          INT            OUTPUT,'+
            '@cErrMsg         NVARCHAR( 20)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM,
            @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU,
            @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT,
            @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT,
            @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT,
            @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT,
            @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT,
            @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT,
            @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT,
            @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT,
            @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT,
            @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT,
            @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT,
            @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
            @cHasLottable   OUTPUT,@cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT,
            @nErrNo         OUTPUT, @cErrMsg        OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_1_Fail
         END
      END
      ELSE
      BEGIN
         EXECUTE [RDT].[rdt_Inquiry_V7]
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cType,
            @cStorerkey,
            @cPUOM,
            @cInquiry_LOC,
            @cInquiry_ID,
            @cInquiry_SKU,
            @cLOT              OUTPUT,
            @cLOC              OUTPUT,
            @cID               OUTPUT,
            @cSKU              OUTPUT,
            @cSKUDescr         OUTPUT,
            @nTotalRec         OUTPUT,
            @nMQTY_TTL         OUTPUT,
            @nMQTY_PMV         OUTPUT,
            @nMQTY_Alloc       OUTPUT,
            @nMQTY_Pick        OUTPUT,
            @nMQTY_RPL         OUTPUT,
            @nMQTY_Avail       OUTPUT,
            @nPQTY_TTL         OUTPUT,
            @nPQTY_PMV         OUTPUT,
            @nPQTY_Alloc       OUTPUT,
            @nPQTY_Pick        OUTPUT,
            @nPQTY_RPL         OUTPUT,
            @nPQTY_Avail       OUTPUT,
            @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc        OUTPUT,
            @cLottableCode     OUTPUT,
            @cLottable01       OUTPUT,
            @cLottable02       OUTPUT,
            @cLottable03       OUTPUT,
            @dLottable04       OUTPUT,
            @dLottable05       OUTPUT,
            @cLottable06       OUTPUT,
            @cLottable07       OUTPUT,
            @cLottable08       OUTPUT,
            @cLottable09       OUTPUT,
            @cLottable10       OUTPUT,
            @cLottable11       OUTPUT,
            @cLottable12       OUTPUT,
            @dLottable13       OUTPUT,
            @dLottable14       OUTPUT,
            @dLottable15       OUTPUT,
            @cHasLottable      OUTPUT,
            @cUserDefine01     OUTPUT,
            @cUserDefine02     OUTPUT,
            @cUserDefine03     OUTPUT,
            @cUserDefine04     OUTPUT,
            @cUserDefine05     OUTPUT,
            @cSKUConfig        OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_1_Fail
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

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
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
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_PMV, 5)  AS NVARCHAR( 5)) END -- (james04)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END

      -- Go to next screen
      SET @nScn = @nScn_Result
      SET @nStep = @nStep_Result
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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
Step_Result:
BEGIN
   IF @nInputKey = 1      -- Yes or Send
   BEGIN
      SELECT @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = ''
      SELECT @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''

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
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      IF @cHasLottable = '1'
      BEGIN
         -- Go to lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Quit
      END
      ELSE IF  @cSKUConfig = '1'
      BEGIN
         SET @cOutField01 = @cUserDefine01
         SET @cOutField02 = @cUserDefine02
         SET @cOutField03 = @cUserDefine03
         SET @cOutField04 = @cUserDefine04
         SET @cOutField05 = @cUserDefine05
         -- Go to Data Inquiry screen
         SET @nScn = @nScn_DataInquiry
         SET @nStep = @nStep_DataInquiry

         GOTO Quit
      END
      BEGIN
         IF @nCurrentRec = @nTotalRec
         BEGIN
            SET @cSKU = ''
            SET @cLOC = ''
            SET @cID = ''
            SET @cLOT = ''
            SET @nCurrentRec = 0
            SET @cType = ''
         END
         ELSE
            SET @cType = 'Next'

         SET @cHasLottable = ''

         IF @cCustomInquiryRule_SP <> '' AND
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomInquiryRule_SP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomInquiryRule_SP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM, ' +
               ' @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU, ' +
               ' @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT, ' +
               ' @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT, ' +
               ' @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT, ' +
               ' @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT, ' +
               ' @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT, ' +
               ' @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT, ' +
               ' @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, ' +
               ' @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT, ' +
               ' @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, ' +
               ' @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT, ' +
               ' @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cHasLottable   OUTPUT, @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT, ' +
               ' @nErrNo         OUTPUT, @cErrMsg        OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT,                  '+
               '@nFunc           INT,                  '+
               '@cLangCode       NVARCHAR( 3),         '+
               '@nStep           INT,                  '+
               '@nInputKey       INT,                  '+
               '@cFacility       NVARCHAR( 5),         '+
               '@cType           NVARCHAR( 10),        '+
               '@cStorerkey      NVARCHAR( 15),        '+
               '@cPUOM           NVARCHAR( 1),         '+
               '@cInquiry_LOC    NVARCHAR( 10),        '+
               '@cInquiry_ID     NVARCHAR( 18),        '+
               '@cInquiry_SKU    NVARCHAR( 20),        '+
               '@cLOT            NVARCHAR( 10)  OUTPUT,'+
               '@cLOC            NVARCHAR( 10)  OUTPUT,'+
               '@cID             NVARCHAR( 18)  OUTPUT,'+
               '@cSKU            NVARCHAR( 20)  OUTPUT,'+
               '@cSKUDescr       NVARCHAR( 60)  OUTPUT,'+
               '@nTotalRec       INT            OUTPUT,'+
               '@nMQTY_TTL       INT            OUTPUT,'+
               '@nMQTY_PMV       INT            OUTPUT,'+
               '@nMQTY_Alloc     INT            OUTPUT,'+
               '@nMQTY_Pick      INT            OUTPUT,'+
               '@nMQTY_RPL       INT            OUTPUT,'+
               '@nMQTY_Avail     INT            OUTPUT,'+
               '@nPQTY_TTL       INT            OUTPUT,'+
               '@nPQTY_PMV       INT            OUTPUT,'+
               '@nPQTY_Alloc     INT            OUTPUT,'+
               '@nPQTY_Pick      INT            OUTPUT,'+
               '@nPQTY_RPL       INT            OUTPUT,'+
               '@nPQTY_Avail     INT            OUTPUT,'+
               '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
               '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
               '@cLottableCode   NVARCHAR( 30)  OUTPUT,'+
               '@cLottable01     NVARCHAR( 18)  OUTPUT,'+
               '@cLottable02     NVARCHAR( 18)  OUTPUT,'+
               '@cLottable03     NVARCHAR( 18)  OUTPUT,'+
               '@dLottable04     DATETIME       OUTPUT,'+
               '@dLottable05     DATETIME       OUTPUT,'+
               '@cLottable06     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable07     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable08     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable09     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable10     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable11     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable12     NVARCHAR( 30)  OUTPUT,'+
               '@dLottable13     DATETIME       OUTPUT,'+
               '@dLottable14     DATETIME       OUTPUT,'+
               '@dLottable15     DATETIME       OUTPUT,'+
               '@cHasLottable    NVARCHAR( 1)   OUTPUT,'+
               '@cUserDefine01   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine02   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine03   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine04   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine05   NVARCHAR( 60)  OUTPUT,'+
               '@cSKUConfig      NVARCHAR( 60)  OUTPUT,'+
               '@nErrNo          INT            OUTPUT,'+
               '@cErrMsg         NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM,
               @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU,
               @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT,
               @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT,
               @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT,
               @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT,
               @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT,
               @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT,
               @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT,
               @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT,
               @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT,
               @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT,
               @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT,
               @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cHasLottable   OUTPUT,@cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT,
               @nErrNo         OUTPUT, @cErrMsg        OUTPUT
         END
         ELSE
         BEGIN
            EXECUTE [RDT].[rdt_Inquiry_V7]
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cType,
            @cStorerkey,
            @cPUOM,
            @cInquiry_LOC,
            @cInquiry_ID,
            @cInquiry_SKU,
            @cLOT              OUTPUT,
            @cLOC              OUTPUT,
            @cID               OUTPUT,
            @cSKU              OUTPUT,
            @cSKUDescr         OUTPUT,
            @nTotalRec         OUTPUT,
            @nMQTY_TTL         OUTPUT,
            @nMQTY_PMV         OUTPUT,
            @nMQTY_Alloc       OUTPUT,
            @nMQTY_Pick        OUTPUT,
            @nMQTY_RPL         OUTPUT,
            @nMQTY_Avail       OUTPUT,
            @nPQTY_TTL         OUTPUT,
            @nPQTY_PMV         OUTPUT,
            @nPQTY_Alloc       OUTPUT,
            @nPQTY_Pick        OUTPUT,
            @nPQTY_RPL         OUTPUT,
            @nPQTY_Avail       OUTPUT,
            @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc        OUTPUT,
            @cLottableCode     OUTPUT,
            @cLottable01       OUTPUT,
            @cLottable02       OUTPUT,
            @cLottable03       OUTPUT,
            @dLottable04       OUTPUT,
            @dLottable05       OUTPUT,
            @cLottable06       OUTPUT,
            @cLottable07       OUTPUT,
            @cLottable08       OUTPUT,
            @cLottable09       OUTPUT,
            @cLottable10       OUTPUT,
            @cLottable11       OUTPUT,
            @cLottable12       OUTPUT,
            @dLottable13       OUTPUT,
            @dLottable14       OUTPUT,
            @dLottable15       OUTPUT,
            @cHasLottable      OUTPUT,
            @cUserDefine01     OUTPUT,
            @cUserDefine02     OUTPUT,
            @cUserDefine03     OUTPUT,
            @cUserDefine04     OUTPUT,
            @cUserDefine05     OUTPUT,
            @cSKUConfig        OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT
         END

         IF @nErrNo <> 0
         BEGIN
            IF @nTotalRec <> -1  -- -1 indicates no more record
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_1_Fail
            END
            ELSE
            BEGIN
               SET @nTotalRec = @nCurrentRec
            END
         END
         ELSE
            SET @nCurrentRec += 1

         -- Prep next screen var
         --SET @nCurrentRec = CASE WHEN @nTotalRec = @nCurrentRec THEN @nCurrentRec ELSE @nCurrentRec + 1 END
         SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @cLOC
         SET @cOutField06 = @cID

         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
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
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_PMV, 5)  AS NVARCHAR( 5)) END -- (james04)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @cInquiry_LOC <> '' EXEC rdt.rdtSetFocusField @nMobile, 1
      IF @cInquiry_ID <> '' EXEC rdt.rdtSetFocusField @nMobile, 2
      IF @cInquiry_SKU <> '' EXEC rdt.rdtSetFocusField @nMobile, 3

      -- Prepare prev screen var
      SET @cInquiry_LOC = ''
      SET @cInquiry_ID  = ''
      SET @cInquiry_SKU  = ''
      SET @cOutField01 = '' -- LOC
      SET @cOutField02 = '' -- ID
      SET @cOutField03 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn_LocIDSKU
      SET @nStep = @nStep_LocIDSKU
   END
END
GOTO Quit

/********************************************************************************
Step 3. Scn = 803. Lottables screen
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
Step_Lottables:
BEGIN
   IF @nInputKey = 1      -- Yes or Send
   BEGIN
      SELECT @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = ''
      SELECT @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''

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
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1
         GOTO Quit

      ELSE IF  @cSKUConfig = '1'
      BEGIN
         SELECT @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = ''
         SELECT @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''

         SET @cOutField01 = @cUserDefine01
         SET @cOutField02 = @cUserDefine02
         SET @cOutField03 = @cUserDefine03
         SET @cOutField04 = @cUserDefine04
         SET @cOutField05 = @cUserDefine05
         -- Go to Data Inquiry screen
         SET @nScn = @nScn_DataInquiry
         SET @nStep = @nStep_DataInquiry

         GOTO Quit
      END
      ELSE
      BEGIN
         IF @nCurrentRec = @nTotalRec
         BEGIN
            SET @cSKU = ''
            SET @cLOC = ''
            SET @cID = ''
            SET @cLOT = ''
            -- SET @nCurrentRec = 0
            SET @cType = ''
         END
         ELSE
            SET @cType = 'Next'

         IF @cCustomInquiryRule_SP <> '' AND
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomInquiryRule_SP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomInquiryRule_SP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM, ' +
               ' @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU, ' +
               ' @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT, ' +
               ' @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT, ' +
               ' @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT, ' +
               ' @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT, ' +
               ' @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT, ' +
               ' @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT, ' +
               ' @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT, ' +
               ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, ' +
               ' @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT, ' +
               ' @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, ' +
               ' @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT, ' +
               ' @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
               ' @cHasLottable   OUTPUT, @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT, ' +
               ' @nErrNo         OUTPUT, @cErrMsg        OUTPUT '

            SET @cSQLParam =
               '@nMobile         INT,                  '+
               '@nFunc           INT,                  '+
               '@cLangCode       NVARCHAR( 3),         '+
               '@nStep           INT,                  '+
               '@nInputKey       INT,                  '+
               '@cFacility       NVARCHAR( 5),         '+
               '@cType           NVARCHAR( 10),        '+
               '@cStorerkey      NVARCHAR( 15),        '+
               '@cPUOM           NVARCHAR( 1),         '+
               '@cInquiry_LOC    NVARCHAR( 10),        '+
               '@cInquiry_ID     NVARCHAR( 18),        '+
               '@cInquiry_SKU    NVARCHAR( 20),        '+
               '@cLOT            NVARCHAR( 10)  OUTPUT,'+
               '@cLOC            NVARCHAR( 10)  OUTPUT,'+
               '@cID             NVARCHAR( 18)  OUTPUT,'+
               '@cSKU            NVARCHAR( 20)  OUTPUT,'+
               '@cSKUDescr       NVARCHAR( 60)  OUTPUT,'+
               '@nTotalRec       INT            OUTPUT,'+
               '@nMQTY_TTL       INT            OUTPUT,'+
               '@nMQTY_PMV       INT            OUTPUT,'+
               '@nMQTY_Alloc     INT            OUTPUT,'+
               '@nMQTY_Pick      INT            OUTPUT,'+
               '@nMQTY_RPL       INT            OUTPUT,'+
               '@nMQTY_Avail     INT            OUTPUT,'+
               '@nPQTY_TTL       INT            OUTPUT,'+
               '@nPQTY_PMV       INT            OUTPUT,'+
               '@nPQTY_Alloc     INT            OUTPUT,'+
               '@nPQTY_Pick      INT            OUTPUT,'+
               '@nPQTY_RPL       INT            OUTPUT,'+
               '@nPQTY_Avail     INT            OUTPUT,'+
               '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
               '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
               '@cLottableCode   NVARCHAR( 30)  OUTPUT,'+
               '@cLottable01     NVARCHAR( 18)  OUTPUT,'+
               '@cLottable02     NVARCHAR( 18)  OUTPUT,'+
               '@cLottable03     NVARCHAR( 18)  OUTPUT,'+
               '@dLottable04     DATETIME       OUTPUT,'+
               '@dLottable05     DATETIME       OUTPUT,'+
               '@cLottable06     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable07     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable08     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable09     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable10     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable11     NVARCHAR( 30)  OUTPUT,'+
               '@cLottable12     NVARCHAR( 30)  OUTPUT,'+
               '@dLottable13     DATETIME       OUTPUT,'+
               '@dLottable14     DATETIME       OUTPUT,'+
               '@dLottable15     DATETIME       OUTPUT,'+
               '@cHasLottable    NVARCHAR( 1)   OUTPUT,'+
               '@cUserDefine01   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine02   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine03   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine04   NVARCHAR( 60)  OUTPUT,'+
               '@cUserDefine05   NVARCHAR( 60)  OUTPUT,'+
               '@cSKUConfig      NVARCHAR( 60)  OUTPUT,'+
               '@nErrNo          INT            OUTPUT,'+
               '@cErrMsg         NVARCHAR( 20)  OUTPUT '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM,
               @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU,
               @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT,
               @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT,
               @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT,
               @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT,
               @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT,
               @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT,
               @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT,
               @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT,
               @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT,
               @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT,
               @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT,
               @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
               @cHasLottable   OUTPUT,@cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT,
               @nErrNo         OUTPUT, @cErrMsg        OUTPUT
         END
         ELSE
         BEGIN
            EXECUTE [RDT].[rdt_Inquiry_V7]
            @nMobile,
            @nFunc,
            @cLangCode,
            @nStep,
            @nInputKey,
            @cFacility,
            @cType,
            @cStorerkey,
            @cPUOM,
            @cInquiry_LOC,
            @cInquiry_ID,
            @cInquiry_SKU,
            @cLOT              OUTPUT,
            @cLOC              OUTPUT,
            @cID               OUTPUT,
            @cSKU              OUTPUT,
            @cSKUDescr         OUTPUT,
            @nTotalRec         OUTPUT,
            @nMQTY_TTL         OUTPUT,
            @nMQTY_PMV         OUTPUT,
            @nMQTY_Alloc       OUTPUT,
            @nMQTY_Pick        OUTPUT,
            @nMQTY_RPL         OUTPUT,
            @nMQTY_Avail       OUTPUT,
            @nPQTY_TTL         OUTPUT,
            @nPQTY_PMV         OUTPUT,
            @nPQTY_Alloc       OUTPUT,
            @nPQTY_Pick        OUTPUT,
            @nPQTY_RPL         OUTPUT,
            @nPQTY_Avail       OUTPUT,
            @cPUOM_Desc        OUTPUT,
            @cMUOM_Desc        OUTPUT,
            @cLottableCode     OUTPUT,
            @cLottable01       OUTPUT,
            @cLottable02       OUTPUT,
            @cLottable03       OUTPUT,
            @dLottable04       OUTPUT,
            @dLottable05       OUTPUT,
            @cLottable06       OUTPUT,
            @cLottable07       OUTPUT,
            @cLottable08       OUTPUT,
            @cLottable09       OUTPUT,
            @cLottable10       OUTPUT,
            @cLottable11       OUTPUT,
            @cLottable12       OUTPUT,
            @dLottable13       OUTPUT,
            @dLottable14       OUTPUT,
            @dLottable15       OUTPUT,
            @cHasLottable      OUTPUT,
            @cUserDefine01     OUTPUT,
            @cUserDefine02     OUTPUT,
            @cUserDefine03     OUTPUT,
            @cUserDefine04     OUTPUT,
            @cUserDefine05     OUTPUT,
            @cSKUConfig        OUTPUT,
            @nErrNo            OUTPUT,
            @cErrMsg           OUTPUT
         END

         IF @nErrNo <> 0
         BEGIN
            IF @nTotalRec <> -1  -- -1 indicates no more record
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Quit
            END
            ELSE
            BEGIN
               SET @nTotalRec = @nCurrentRec
            END
         END
         ELSE
            SET @nCurrentRec += 1

         -- Prep next screen var
         -- SET @nCurrentRec = CASE WHEN @nTotalRec = @nCurrentRec THEN @nCurrentRec ELSE @nCurrentRec + 1 END
         SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @cLOC
         SET @cOutField06 = @cID

         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
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
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_PMV, 5)  AS NVARCHAR( 5)) END -- (james11)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                              THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                              ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END

         -- Go back previous screen
         SET @nScn = @nScn_Result
         SET @nStep = @nStep_Result
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prep next screen var
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
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
                         ELSE SPACE( 6) + CAST( @nMQTY_PMV  AS NVARCHAR( 5)) END -- (james11)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                         THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                         ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END

      -- Go to prev screen
      SET @nScn = @nScn_Result
      SET @nStep = @nStep_Result
   END
END
GOTO Quit

/********************************************************************************
Step 4. Scn = 5143. Result screen
   (field01)
   (field02)
   (field03)
   (field04)
   (field05)
   (field06)
   (field07)
   (field08)
   (field09)
   (field10)
********************************************************************************/
Step_DataInquiry:
BEGIN
   IF @nInputKey = 1      -- Yes or Send
   BEGIN
      SELECT @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = ''
      SELECT @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''

      IF @nCurrentRec = @nTotalRec
      BEGIN
         SET @cSKU = ''
         SET @cLOC = ''
         SET @cID = ''
         SET @cLOT = ''
         -- SET @nCurrentRec = 0
         SET @cType = ''
      END
      ELSE
         SET @cType = 'Next'

      IF @cCustomInquiryRule_SP <> '' AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cCustomInquiryRule_SP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cCustomInquiryRule_SP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM, ' +
            ' @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU, ' +
            ' @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT, ' +
            ' @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT, ' +
            ' @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT, ' +
            ' @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT, ' +
            ' @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT, ' +
            ' @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT, ' +
            ' @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT, ' +
            ' @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT, ' +
            ' @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT, ' +
            ' @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT, ' +
            ' @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT, ' +
            ' @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT, ' +
            ' @cHasLottable   OUTPUT, @cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT, ' +
            ' @nErrNo         OUTPUT, @cErrMsg        OUTPUT '

         SET @cSQLParam =
            '@nMobile         INT,                  '+
            '@nFunc           INT,                  '+
            '@cLangCode       NVARCHAR( 3),         '+
            '@nStep           INT,                  '+
            '@nInputKey       INT,                  '+
            '@cFacility       NVARCHAR( 5),         '+
            '@cType           NVARCHAR( 10),        '+
            '@cStorerkey      NVARCHAR( 15),        '+
            '@cPUOM           NVARCHAR( 1),         '+
            '@cInquiry_LOC    NVARCHAR( 10),        '+
            '@cInquiry_ID     NVARCHAR( 18),        '+
            '@cInquiry_SKU    NVARCHAR( 20),        '+
            '@cLOT            NVARCHAR( 10)  OUTPUT,'+
            '@cLOC            NVARCHAR( 10)  OUTPUT,'+
            '@cID             NVARCHAR( 18)  OUTPUT,'+
            '@cSKU            NVARCHAR( 20)  OUTPUT,'+
            '@cSKUDescr       NVARCHAR( 60)  OUTPUT,'+
            '@nTotalRec       INT            OUTPUT,'+
            '@nMQTY_TTL       INT            OUTPUT,'+
            '@nMQTY_PMV       INT            OUTPUT,'+
            '@nMQTY_Alloc     INT            OUTPUT,'+
            '@nMQTY_Pick      INT            OUTPUT,'+
            '@nMQTY_RPL       INT            OUTPUT,'+
            '@nMQTY_Avail     INT            OUTPUT,'+
            '@nPQTY_TTL       INT            OUTPUT,'+
            '@nPQTY_PMV       INT            OUTPUT,'+
            '@nPQTY_Alloc     INT            OUTPUT,'+
            '@nPQTY_Pick      INT            OUTPUT,'+
            '@nPQTY_RPL       INT            OUTPUT,'+
            '@nPQTY_Avail     INT            OUTPUT,'+
            '@cPUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
            '@cMUOM_Desc      NVARCHAR( 5)   OUTPUT,'+
            '@cLottableCode   NVARCHAR( 30)  OUTPUT,'+
            '@cLottable01     NVARCHAR( 18)  OUTPUT,'+
            '@cLottable02     NVARCHAR( 18)  OUTPUT,'+
            '@cLottable03     NVARCHAR( 18)  OUTPUT,'+
            '@dLottable04     DATETIME       OUTPUT,'+
            '@dLottable05     DATETIME       OUTPUT,'+
            '@cLottable06     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable07     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable08     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable09     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable10     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable11     NVARCHAR( 30)  OUTPUT,'+
            '@cLottable12     NVARCHAR( 30)  OUTPUT,'+
            '@dLottable13     DATETIME       OUTPUT,'+
            '@dLottable14     DATETIME       OUTPUT,'+
            '@dLottable15     DATETIME       OUTPUT,'+
            '@cHasLottable    NVARCHAR( 1)   OUTPUT,'+
            '@cUserDefine01   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine02   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine03   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine04   NVARCHAR( 60)  OUTPUT,'+
            '@cUserDefine05   NVARCHAR( 60)  OUTPUT,'+
            '@cSKUConfig      NVARCHAR( 60)  OUTPUT,'+
            '@nErrNo          INT            OUTPUT,'+
            '@cErrMsg         NVARCHAR( 20)  OUTPUT '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cType, @cStorerkey, @cPUOM,
            @cInquiry_LOC, @cInquiry_ID, @cInquiry_SKU,
            @cLOT           OUTPUT, @cLOC           OUTPUT, @cID            OUTPUT, @cSKU           OUTPUT,
            @cSKUDescr      OUTPUT, @nTotalRec      OUTPUT,
            @nMQty_TTL      OUTPUT, @nMQTY_PMV      OUTPUT, @nMQTY_Alloc    OUTPUT,
            @nMQty_Pick     OUTPUT, @nMQty_RPL      OUTPUT, @nMQTY_Avail    OUTPUT,
            @nPQty_TTL      OUTPUT, @nPQTY_PMV      OUTPUT, @nPQTY_Alloc    OUTPUT,
            @nPQty_Pick     OUTPUT, @nPQty_RPL      OUTPUT, @nPQTY_Avail    OUTPUT,
            @cPUOM_Desc     OUTPUT, @cMUOM_Desc     OUTPUT, @cLottableCode  OUTPUT,
            @cLottable01    OUTPUT, @cLottable02    OUTPUT, @cLottable03    OUTPUT,
            @dLottable04    OUTPUT, @dLottable05    OUTPUT, @cLottable06    OUTPUT,
            @cLottable07    OUTPUT, @cLottable08    OUTPUT, @cLottable09    OUTPUT,
            @cLottable10    OUTPUT, @cLottable11    OUTPUT, @cLottable12    OUTPUT,
            @dLottable13    OUTPUT, @dLottable14    OUTPUT, @dLottable15    OUTPUT,
            @cHasLottable   OUTPUT,@cUserDefine01 OUTPUT, @cUserDefine02  OUTPUT, @cUserDefine03  OUTPUT, @cUserDefine04  OUTPUT, @cUserDefine05  OUTPUT, @cSKUConfig OUTPUT,
            @nErrNo         OUTPUT, @cErrMsg        OUTPUT
      END
      ELSE
      BEGIN
         EXECUTE [RDT].[rdt_Inquiry_V7]
         @nMobile,
         @nFunc,
         @cLangCode,
         @nStep,
         @nInputKey,
         @cFacility,
         @cType,
         @cStorerkey,
         @cPUOM,
         @cInquiry_LOC,
         @cInquiry_ID,
         @cInquiry_SKU,
         @cLOT              OUTPUT,
         @cLOC              OUTPUT,
         @cID               OUTPUT,
         @cSKU              OUTPUT,
         @cSKUDescr         OUTPUT,
         @nTotalRec         OUTPUT,
         @nMQTY_TTL         OUTPUT,
         @nMQTY_PMV         OUTPUT,
         @nMQTY_Alloc       OUTPUT,
         @nMQTY_Pick        OUTPUT,
         @nMQTY_RPL         OUTPUT,
         @nMQTY_Avail       OUTPUT,
         @nPQTY_TTL         OUTPUT,
         @nPQTY_PMV         OUTPUT,
         @nPQTY_Alloc       OUTPUT,
         @nPQTY_Pick        OUTPUT,
         @nPQTY_RPL         OUTPUT,
         @nPQTY_Avail       OUTPUT,
         @cPUOM_Desc        OUTPUT,
         @cMUOM_Desc        OUTPUT,
         @cLottableCode     OUTPUT,
         @cLottable01       OUTPUT,
         @cLottable02       OUTPUT,
         @cLottable03       OUTPUT,
         @dLottable04       OUTPUT,
         @dLottable05       OUTPUT,
         @cLottable06       OUTPUT,
         @cLottable07       OUTPUT,
         @cLottable08       OUTPUT,
         @cLottable09       OUTPUT,
         @cLottable10       OUTPUT,
         @cLottable11       OUTPUT,
         @cLottable12       OUTPUT,
         @dLottable13       OUTPUT,
         @dLottable14       OUTPUT,
         @dLottable15       OUTPUT,
         @cHasLottable      OUTPUT,
         @cUserDefine01     OUTPUT,
         @cUserDefine02     OUTPUT,
         @cUserDefine03     OUTPUT,
         @cUserDefine04     OUTPUT,
         @cUserDefine05     OUTPUT,
         @cSKUConfig        OUTPUT,
         @nErrNo            OUTPUT,
         @cErrMsg           OUTPUT
      END

      IF @nErrNo <> 0
      BEGIN
         IF @nTotalRec <> -1  -- -1 indicates no more record
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nTotalRec = @nCurrentRec
         END
      END
      ELSE
         SET @nCurrentRec += 1

      -- Prep next screen var
      -- SET @nCurrentRec = CASE WHEN @nTotalRec = @nCurrentRec THEN @nCurrentRec ELSE @nCurrentRec + 1 END
      SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      SET @cOutField02 = @cSKU
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField05 = @cLOC
      SET @cOutField06 = @cID

      SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
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
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_PMV, 5)  AS NVARCHAR( 5)) END -- (james11)
      SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                           THEN LEFT( CAST( LEFT(@nPQTY_Avail, 5) AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5))
                           ELSE SPACE( 6) + CAST( LEFT(@nMQTY_Avail, 5) AS NVARCHAR( 5)) END

      -- Go back previous screen
      SET @nScn = @nScn_Result
      SET @nStep = @nStep_Result
   END

   IF @nInputKey = 0 -- Esc or No
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
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         '',      -- SourceKey
         @nFunc   -- SourceType

      IF @cHasLottable = '1'
      BEGIN
         -- Go to lottable screen
         SET @nScn = @nScn_Lottables
         SET @nStep = @nStep_Lottables

         GOTO Quit
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)
         SET @cOutField05 = @cLOC
         SET @cOutField06 = @cID

         SET @cOutField07 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( @cPUOM_Desc + REPLICATE(' ', 5), 5) + ' ' + @cMUOM_Desc
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
                            ELSE SPACE( 6) + CAST( @nMQTY_PMV  AS NVARCHAR( 5)) END -- (james11)
         SET @cOutField13 = CASE WHEN @cPUOM_Desc <> ''
                            THEN LEFT( CAST( @nPQTY_Avail AS NVARCHAR( 5)) + REPLICATE(' ', 6), 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5))
                            ELSE SPACE( 6) + CAST( @nMQTY_Avail AS NVARCHAR( 5)) END

         -- Go to prev screen
         SET @nScn = @nScn_Result
         SET @nStep = @nStep_Result
      END
   END
END
GOTO Quit

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
      V_SKUDescr   = @cSKUDescr,

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

      V_String1  = @cInquiry_LOC,
      V_String2  = @cInquiry_ID,
      V_String3  = @cInquiry_SKU,

      V_String4  = @cPUOM_Desc,
      V_String5  = @cMUOM_Desc,
      V_String6  = @cDecodeSP,
      V_String7  = @cHasLottable,
      V_String8  = @cSKUBarcode1,
      V_String9  = @cSKUBarcode2,
      V_String10 = @cLottableCode,
      V_String11 = @cCustomInquiryRule_SP,
      V_String12 = @cType,
      V_String13 = @cLOCLookUP,              --(yeekung03)
      V_String14 = @cUserDefine01 ,
      V_String15 = @cUserDefine02 ,
      V_String16 = @cUserDefine03 ,
      V_String17 = @cUserDefine04 ,
      V_String18 = @cUserDefine05 ,
      V_String19 = @cSKUConfig,

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