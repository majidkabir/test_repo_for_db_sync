SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_Putaway                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Putaway                                                     */
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
/* Date       Rev  Author   Purposes                                    */
/* 2005-10-06 1.0  UngDH    Created                                     */
/* 2006-05-30 1.1  Shong    Enhancement                                 */
/* 2006-07-07 1.1  MaryVong SOS54191 Add SKUDescr and QTY conversion    */
/* 2006-09-18 1.2  MaryVong Add in BEGIN TRAN while execute nspRFPA02   */
/* 2008-03-02 1.3  Vicky    Modify to cater for SQL2005 (Vicky01)       */
/* 2009-06-05 1.4  James    Cater for comingle LOT (james01)            */
/* 2009-06-29 1.5  Shong    Bug Fixing                                  */
/* 2009-07-31 1.6  Vicky    Add in EventLog (Vicky06)                   */
/* 2009-10-27 1.7  James    Bug fix (james02)                           */
/* 2010-12-23 1.8  Shong    Adidas Project - Allow user to change Qty   */
/*                          for Putaway                                 */
/* 2010-12-29 1.9  James    SOS200885 - Enable label decoding (james03) */
/* 2011-01-04 2.0  ChewKP   Bug Fixes (ChewKP01)                        */
/* 2011-01-12      James    SOS200195 - Default SKU & LOC if only 1 rec */
/*                          found by ID (james04)                       */
/* 2011-02-24      Leong    SOS# 206770 - Add TraceInfo for nspRDTPASTD */
/* 2011-03-02      Audrey   SOS# 206770 - change I_Field12 to V_String6 */
/*                          (ang01)                                     */
/* 2011-05-12      James    Bug Fixes (James05)                         */
/* 2012-06-11      Ung      SOS24639 change QTY to UOM QTY field        */
/*                          Clean up source                             */
/* 2012-11-27      James    Add config to control whether to default    */
/*                          Act Qty (james06)                           */
/* 2013-03-14      SPChin   SOS271271 - No need check qty if field is   */
/*                          disabled                                    */
/* 2013-04-30 2.6  James    Allow 6 digit on V_Qty (james06)            */
/* 2013-06-10 2.7  Ung      SOS280709 Suppport concurrent putaway       */
/* 2014-01-13 2.8  ChewKP   SOS#300767 Bug Fixes (ChewKP02)             */
/* 2014-02-20 2.9  James    Bug fix (james07)                           */
/* 2014-04-07 3.0  Ung      SOS307608 Add ExtendedValidateSP            */
/* 2014-05-14 3.1  Shong    Making use of Label Decode oField07 as From */
/*                          Loc (Shong01)                               */
/* 2015-05-12 3.2  James    SOS341660 - Allow 7 digit on V_Qty (james08)*/
/* 2016-09-30 3.3  Ung      Performance tuning                          */  
/* 2018-10-04 3.4  Gan      Performance tuning                          */
/* 2024-06-25 3.5  JHU51    FCR-349 add SCN 924 for DEFY                */
/* 2024-11-18 3.6  CYU027   FCR-1205 Add extPA SP entry for Granite     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdtfnc_Putaway] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Other var use in this stor proc
DECLARE
   @b_Success         INT,
   @n_err             INT,
   @c_errmsg          NVARCHAR( 250),
   @c_outstring       NVARCHAR( 255),
   @cSQL              NVARCHAR( MAX),
   @cSQLParam         NVARCHAR( MAX)

-- Variable for RDT.RDTMobRec
DECLARE
   @nFunc           INT,
   @nScn            INT,
   @nStep           INT,
   @cLangCode       NVARCHAR( 3),
   @nInputKey       INT,
   @nMenu           INT,

   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cUserName       NVARCHAR( 18),

   @cID             NVARCHAR( 20),
   @cFromLOC        NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @cSKUDesc        NVARCHAR( 60),
   @cPUOM           NVARCHAR( 10),

   @cDecodeLabelNo  NVARCHAR( 20),
   @cMUOM_Desc      NVARCHAR( 5),
   @cPUOM_Desc      NVARCHAR( 5),
   @nPUOM_Div       INT,
   @nPQTY_PWY       INT,
   @nMQTY_PWY       INT,
   @nQTY_PWY        INT,
   @nPQTY           INT,
   @nMQTY           INT,
   @nQTY            INT,
   @cSuggestedLOC   NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @cExtendedValidateSP NVARCHAR( 20),
   @cExtendedScreenSP   NVARCHAR( 20), --(JHU151)
   @tExtScnData			VariableTable, --(JHU151)
   @nAction             INT, --(JHU151)
   @cPickAndDropLoc     NVARCHAR( 10),
   @nPABookingKey       INT,          --V3.6 JCH507
   @nPAErrNo            INT,          --V3.6 JCH507
   @cUCC                NVARCHAR( 20),--V3.6 JCH507

   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1),

   @cLottable01  NVARCHAR( 18), @cLottable02  NVARCHAR( 18), @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME, @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30), @cLottable07  NVARCHAR( 30), @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30), @cLottable10  NVARCHAR( 30), @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME, @dLottable14  DATETIME, @dLottable15  DATETIME,

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

-- Getting Mobile information
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,

   @cFromLOC   = V_LOC,
   @cSKU       = V_SKU,
   @cID        = V_ID,
   @cSKUDesc   = V_SKUDescr,
   @cPUOM      = V_UOM,
   --@nQTY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_QTY, 7), 0) = 1 THEN LEFT( V_QTY, 7) ELSE 0 END, -- (james08)

   @cDecodeLabelNo = V_String1,
   @cMUOM_Desc     = V_String2,
   @cPUOM_Desc     = V_String3,
   --@nPUOM_Div      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String4, 7), 0) = 1 THEN LEFT( V_String4, 7) ELSE 0 END,    = V_Integer
   --@nPQTY_PWY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5, 7), 0) = 1 THEN LEFT( V_String5, 7) ELSE 0 END,
   --@nMQTY_PWY      = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6, 7), 0) = 1 THEN LEFT( V_String6, 7) ELSE 0 END,
   --@nQTY_PWY       = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String7, 7), 0) = 1 THEN LEFT( V_String7, 7) ELSE 0 END,
   --@nPQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String8, 7), 0) = 1 THEN LEFT( V_String8, 7) ELSE 0 END,
   --@nMQTY          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9, 7), 0) = 1 THEN LEFT( V_String9, 7) ELSE 0 END,
   @cSuggestedLOC  = V_String10,
   @cFinalLOC      = V_String11,
   @cExtendedValidateSP = V_String12,
   @cExtendedScreenSP = V_String13,--(JHU151)
   @nQTY       = V_Integer1,
   @nPQTY_PWY  = V_Integer2,
   @nMQTY_PWY  = V_Integer3,
   @nQTY_PWY   = V_Integer4,
   
   @nPUOM_Div  = V_PUOM_Div,
   @nPQTY      = V_PQTY,
   @nMQTY      = V_MQTY,

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

FROM RDTMOBREC M (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 520
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Func = 520. Menu
   IF @nStep = 1 GOTO Step_1   -- Scn  = 920. ID, SKU, FromLOC
   IF @nStep = 2 GOTO Step_2   -- Scn  = 921. QTY
   IF @nStep = 3 GOTO Step_3   -- Scn  = 922. Suggested LOC, ToLOC
   IF @nStep = 4 GOTO Step_4   -- Scn  = 923. Msg
   IF @nStep = 99 GOTO Step_99 -- Ext Screen (924)
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 520. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Get preferred UOM
   SELECT @cPUOM = DefaultUOM FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName

   -- Get storer configure
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorerKey)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''

   --JHU151
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScreenSP = '0'
      SET @cExtendedScreenSP = ''

   --Initialize Outfield Values
   SET @cOutField01 = '' --ID
   SET @cOutField02 = @cStorerKey
   SET @cOutField03 = '' --SKU
   SET @cOutField04 = '' --FromLOC

   -- Enable all fields
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

   -- Set the entry point
   SET @nScn = 920
   SET @nStep = 1

   --JHU151   
   IF @cExtendedScreenSP <> ''
   BEGIN
      SET @cOutField02 = ''
      SET @nStep = 99
      SET @nScn = 924
      
   END

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 920. ID/SKU/FromLOC screen
   ID     (field01, input)
   Storer (field02)
   SKU    (field03, input)
   LOC    (field04, input)
********************************************************************************/
Step_1:
BEGIN


   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cLabelNo NVARCHAR( 32)

      -- Screen mapping
      SET @cID = @cInField01
      SET @cLabelNo = @cInField03
      SET @cSKU = @cInField03
      SET @cFromLOC = @cInField04

      -- Retain input
      SET @cOutField01 = @cInField01 -- ID
      SET @cOutField03 = @cInField03 -- SKU
      SET @cOutField04 = @cInField04 -- FromLOC

      -- Check ID and SKU blank
      IF @cID = '' AND @cSKU = ''
      BEGIN
         SET @nErrNo = 63801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NeedID/SKU/LOC
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = '' --ID
         GOTO Quit
      END

      -- Check ID
      IF @cID <> ''
      BEGIN
         -- Count SKU, LOC on ID
         DECLARE @nSKUCount INT
         DECLARE @nLOCCount INT
         SET @nSKUCount = 0
        SET @nLOCCount = 0
         SELECT
            @nSKUCount = COUNT( DISTINCT LLI.SKU),
            @nLOCCount = COUNT( DISTINCT LOC.LOC)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND ID = @cID
            AND (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  -- (james07)

         -- Check ID valid
         IF @nSKUCount = 0
         BEGIN
            SET @nErrNo = 63802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid ID
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = '' --ID
            GOTO Quit
         END

         -- Auto retrieve SKU, if only 1 SKU on ID
         IF @nSKUCount = 1 AND @cSKU = '' AND rdt.RDTGetConfig( @nFunc, 'GetDefaultSKUByID', @cStorerKey) = 1
         BEGIN
            SELECT TOP 1 @cSKU = SKU
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE StorerKey = @cStorerKey
               AND Facility = @cFacility
               AND ID = @cID
               AND (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  -- (james07)

            SET @cOutField03 = @cSKU
         END

         -- Auto retrieve LOC, if only 1 LOC on ID
         IF @nLOCCount = 1 AND @cFromLOC = '' AND rdt.RDTGetConfig( @nFunc, 'GetDefaultLOCByID', @cStorerKey) = 1
         BEGIN
            SELECT TOP 1 @cFromLOC = LLI.LOC
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE StorerKey = @cStorerKey
               AND Facility = @cFacility
               AND ID = @cID
               AND (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  -- (james07)

            SET @cOutField04 = @cFromLOC
         END

         -- Go to next field
         IF @cSKU = ''
            EXEC rdt.rdtSetFocusField @nMobile, 3
         ELSE IF @cFromLOC = ''
            EXEC rdt.rdtSetFocusField @nMobile, 4
      END

      -- Check SKU blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 63820
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU
         EXEC rdt.rdtSetFocusField @nMobile, 3 --SKU
         SET @cOutField03 = '' --SKU
         GOTO Quit
      END

      -- If len of the input is > 20 characters then this is not a SKU
      -- use label decoding (shong01)
      IF LEN( @cLabelNo) >= 20 AND @cDecodeLabelNo <> ''
      BEGIN
         DECLARE
            @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
            @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
            @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
            @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
            @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

         EXEC dbo.ispLabelNo_Decoding_Wrapper
             @c_SPName     = @cDecodeLabelNo
            ,@c_LabelNo    = @cLabelNo
            ,@c_Storerkey  = @cStorerKey
            ,@c_ReceiptKey = ''
            ,@c_POKey      = ''
            ,@c_LangCode   = @cLangCode
            ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
            ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
            ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
            ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
            ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
            ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
            ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- FromLoc
            ,@c_oFieled08  = @c_oFieled08 OUTPUT
            ,@c_oFieled09  = @c_oFieled09 OUTPUT
            ,@c_oFieled10  = @c_oFieled10 OUTPUT
            ,@b_Success    = @b_Success   OUTPUT
            ,@n_ErrNo      = @nErrNo      OUTPUT
            ,@c_ErrMsg     = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         SET @cSKU = @c_oFieled01
         -- (Shong01)
         IF @cFromLOC = '' AND ISNULL(RTRIM(@c_oFieled07),'') <> ''
            SET @cFromLOC = @c_oFieled07
      END

      -- Get SKU barcode count
      DECLARE @nSKUCnt INT
      EXEC RDT.rdt_GETSKUCNT
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU,
         @nSKUCnt     = @nSKUCnt       OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 63803
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         EXEC rdt.rdtSetFocusField @nMobile, 3 --SKU
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 63804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
         EXEC rdt.rdtSetFocusField @nMobile, 3 --SKU
         SET @cOutField03 = ''
         GOTO Quit
      END

      -- Get SKU code
      EXEC [RDT].[rdt_GETSKU]
         @cStorerKey  = @cStorerKey,
         @cSKU        = @cSKU          OUTPUT,
         @bSuccess    = @b_Success     OUTPUT,
         @nErr        = @n_Err         OUTPUT,
         @cErrMsg     = @c_ErrMsg      OUTPUT

      SET @cOutField03 = @cSKU

      -- Check LOC
      IF @cFromLOC = ''
      BEGIN
         SET @nErrNo = 63821
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need FROM LOC
         EXEC rdt.rdtSetFocusField @nMobile, 4 --FromLOC
         SET @cOutField04 = '' --FromLOC
         GOTO Quit
      END

      -- Check LOC valid
      IF NOT EXISTS ( SELECT 1 FROM dbo.LOC LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 63807
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidFromLoc
         EXEC rdt.rdtSetFocusField @nMobile, 4 --FromLOC
         SET @cOutField04 = ''
         GOTO Quit
      END
      SET @cOutField04 = @cFromLOC

      -- Get LLI count
      DECLARE @nRecCnt INT
      SET @nRecCnt = 0
      SELECT @nRecCnt = COUNT(1)
      FROM
      (
         SELECT 1 B
         FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         WHERE Storerkey = @cStorerKey
            AND SKU = @cSKU
            AND LLI.LOC = @cFromLOC
            AND ID = CASE WHEN @cID = '' THEN ID ELSE @cID END
         GROUP BY LLI.LOC, LLI.ID, LLI.SKU
         HAVING SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0
      ) A

      -- Check no LLI to putaway
      IF @nRecCnt = 0
      BEGIN
         -- Check QTY to putaway
         IF EXISTS( SELECT 1
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE Storerkey = @cStorerKey
               AND SKU = @cSKU
               AND LLI.LOC = @cFromLOC
               AND ID = CASE WHEN @cID = '' THEN ID ELSE @cID END
            GROUP BY LLI.LOC, LLI.ID, LLI.SKU)
         BEGIN
            SET @nErrNo = 63805
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoQTYtoPutaway
         END
         ELSE
         BEGIN
            SET @nErrNo = 63808
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Rec Found
         END
         GOTO Quit
      END

      -- Check multi LLI to putaway
      IF @nRecCnt > 1
      BEGIN
         SET @nErrNo = 63809
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiRec Found
         GOTO Quit
      END

      -- Get LLI info
      SELECT TOP 1
         @cSKU     = LLI.SKU,
         @cID      = LLI.ID,
         @cFromLOC = LLI.LOC,
         @nQTY_PWY = SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated)
      FROM dbo.LotxLocxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE Storerkey = @cStorerKey
         AND LLI.LOC = @cFromLOC
         AND ID = CASE WHEN @cID = '' THEN ID ELSE @cID END
         AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
      GROUP BY LLI.LOC, LLI.ID, LLI.SKU
      HAVING SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0

      -- Get SKU info
      SELECT
         @cSKUDesc = S.Descr,
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
      FROM dbo.SKU S (NOLOCK)
         INNER JOIN dbo.Pack Pack (nolock) ON (S.PackKey = Pack.PackKey)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0 -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY_PWY = 0
         SET @nPQTY  = 0
         SET @nMQTY_PWY = @nQTY_PWY
         SET @cFieldAttr11 = 'O' -- @nPQTY_PWY
         SET @cInField13 = ''
      END
      ELSE
      BEGIN
         SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cID
      SET @cOutField02 = @cStorerKey
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField07 = @cPUOM_Desc
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 6)) END
      SET @cOutField10 = CAST( @nMQTY_PWY AS NVARCHAR( 6))
      SET @cOutField11 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'NotDefaultPAQty', @cStorerKey) = 1 THEN '' ELSE     -- (james06)
                         CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 6)) END END
      SET @cOutField12 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'NotDefaultPAQty', @cStorerKey) = 1 THEN '' ELSE     -- (james06)
                         CAST( @nMQTY_PWY AS NVARCHAR( 6)) END
      SET @cOutField13 = @cFromLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Sign Out
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 921. QTY screen
   ID        (field01)
   Storer    (field02)
   SKU       (field03)
   DESC1     (field04)
   DESC2     (field05)
   UOM ratio (field06)
   PUOM      (field07)
   MUOM      (field08)
   PQTY_PWY  (field09)
   MQTY_PWY  (field10)
   PQTY      (field11, input)
   MQTY      (field12, input)
   FROMLOC   (field13)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cPQTY       NVARCHAR( 5)
      DECLARE @cMQTY       NVARCHAR( 5)

-- screen mapping
      -- SOS271271
      -- Only when field is enable then get the qty
      SET @cPQTY = CASE WHEN ISNULL(@cFieldAttr11, '') = '' THEN ISNULL( @cInField11, '') ELSE '' END
      SET @cMQTY = CASE WHEN ISNULL(@cFieldAttr12, '') = '' THEN ISNULL( @cInField12, '') ELSE '' END

      -- Validate PQTY
      IF @cPQTY = '' SET @cPQTY = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 63810
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- PQTY
         GOTO Quit
      END

      -- Validate MQTY
      IF @cMQTY  = '' SET @cMQTY  = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 63811
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- MQTY
         GOTO Quit
      END

      -- Calc total QTY in master UOM
      SET @nPQTY = CAST( @cPQTY AS INT)
      SET @nMQTY = CAST( @cMQTY AS INT)
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @nQTY = @nQTY + @nMQTY

      -- Validate QTY
      IF @nQTY = 0
      BEGIN
         SET @nErrNo = 63812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY needed
         GOTO Quit
      END

      -- Validate QTY to move more than QTY avail
      IF @nQTY > @nQTY_PWY
      BEGIN
         SET @nErrNo = 63813
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTYPWY NotEnuf
         GOTO Quit
      END

      -- V3.6 JCH507 Start
      -- Get suggest LOC
      SET @nPAErrNo = 0
      SET @nPABookingKey = 0

      EXEC rdt.rdt_Putaway_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility
         ,@cFromLOC
         ,@cID
         ,'' --NO LOT
         ,'' --NO UCC
         ,@cSKU
         ,@nQTY
         ,@cSuggestedLOC   OUTPUT
         ,@cPickAndDropLoc OUTPUT
         ,@nPABookingKey   OUTPUT
         ,@nPAErrNo  OUTPUT
         ,@cErrMsg         OUTPUT
      IF @nPAErrNo <> 0 AND
         @nPAErrNo <> -1 -- No suggested LOC
      BEGIN
         SET @nErrNo = @nPAErrNo
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END

      -- V3.6 JCH507 END

     -- Check any suggested LOC
      IF @cSuggestedLOC = ''
      BEGIN
         SET @nErrNo = 63814
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitableLOC
      END

      -- Check valid suggested LOC
      IF @cSuggestedLOC = 'SEE_SUPV'
      BEGIN
         SET @nErrNo = 63815
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuggestedLOC
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cSuggestedLOC
      SET @cOutField02 = '' -- FinalLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen variable
      SET @cOutField01 = '' -- ID
      SET @cOutField02 = @cStorerKey
      SET @cOutField03 = '' -- SKU
      SET @cOutField04 = '' -- FromLOC
      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   --JHU151
  IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 922
   Suggested LOC  (field01)
   Final LOC      (field02, input)
********************************************************************************/
Step_3:
BEGIN
 IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cFinalLOC = @cInField02

      -- Check blank final LOC
      IF @cFinalLOC = ''
      BEGIN
         SET @nErrNo = 63816
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need Final LOC
         GOTO Quit
      END

      -- Check from loc different facility
      DECLARE @cChkFacility NVARCHAR(5)
      SELECT @cChkFacility = Facility FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 63817
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid LOC
         GOTO Quit
      END

      -- Check from loc different facility
      IF @cChkFacility <> @cFacility
      BEGIN
         SET @nErrNo = 63818
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff facility
         GOTO Quit
      END

      -- Check if suggested LOC match
      IF @cSuggestedLOC <> @cFinalLOC
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'PAMatchSuggestLOC', @cStorerKey) = 1
         BEGIN
            SET @nErrNo = 63819
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOC Not Match
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cID             NVARCHAR( 18), ' +
               '@cFromLOC        NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTY            INT,           ' +
               '@cSuggestedLOC   NVARCHAR( 10), ' +
               '@cFinalLOC       NVARCHAR( 10), ' +
               '@nErrNo          INT OUTPUT,    ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFacility, @cID, @cFromLOC, @cSKU, @nQTY, @cSuggestedLOC, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Execute putaway process
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,
         '',      --@cByLOT, optional
         @cFromLOC,
         @cID,
         @cStorerKey,
         @cSKU,
         @nQTY,
         @cFinalLOC,
         '', --@cLabelType OUTPUT, -- optional
         '', --@cUCC,      OUTPUT, -- optional
         @nErrNo     OUTPUT,
         @cErrMsg    OUTPUT
      IF @nErrNo <> 0
         GOTO Quit

      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --@cSuggFromLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Unlock SuggestedLOC
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --@cSuggFromLOC
         ,@cID
         ,@cSuggestedLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT

      -- Prepare prev screen variable
      SET @cOutField01 = @cID
      SET @cOutField02 = @cStorerKey
      SET @cOutField03 = @cSKU
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 1, 20)
      SET @cOutField05 = SUBSTRING( @cSKUDesc, 21, 20)
      SET @cOutField06 = '1:' + CAST( @nPUOM_Div AS NVARCHAR( 6))
      SET @cOutField07 = @cPUOM_Desc
      SET @cOutField08 = @cMUOM_Desc
      SET @cOutField09 = CASE WHEN @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY_PWY AS NVARCHAR( 5)) END
      SET @cOutField10 = CAST( @nMQTY_PWY AS NVARCHAR( 5))
      SET @cOutField11 = ''
      SET @cOutField12 = ''
      SET @cOutField13 = @cFromLOC

      -- Go to prev screen
      SET @nScn  = @nScn  - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 4. scn = 923. Message screen
   Msg
********************************************************************************/
Step_4:
BEGIN
   -- Prepare prev screen variable
   SET @cOutField01 = '' -- ID
   SET @cOutField02 = @cStorerKey
   SET @cOutField03 = '' -- SKU
   SET @cOutField04 = '' -- FromLOC

   -- Go to ID/SKU/FromLOC screen
   SET @nScn  = @nScn - 3
   SET @nStep = @nStep - 3

   --JHU151
   IF @cExtendedScreenSP = '0'
   BEGIN
      SET @cExtendedScreenSP = ''
   END
   IF @cExtendedScreenSP <> ''
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END
END
GOTO Quit


--JHU151
Step_99:
BEGIN
   IF @cExtendedScreenSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES 	
         ('@nMenu',     CONVERT(Nvarchar(20),@nMenu)),
         ('@cUserName', @cUserName)

         EXECUTE [RDT].[rdt_ExtScnEntry] 
         @cExtendedScreenSP, 
         @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nAction, 
         @nScn     OUTPUT,  @nStep OUTPUT,
         @nErrNo   OUTPUT, 
         @cErrMsg  OUTPUT,
         @cUDF01   OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
         @cUDF04   OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
         @cUDF07   OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
         @cUDF10   OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
         @cUDF13   OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
         @cUDF16   OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
         @cUDF19   OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
         @cUDF22   OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
         @cUDF25   OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
         @cUDF28   OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         SET @nFunc = @cUDF01
         
         IF @nScn = 921
         BEGIN
            SET @cSKU = @cUDF02
            SET @cFromLOC = @cUDF03
            SET @cSKUDesc = @cUDF04
            SET @cPUOM = @cUDF05
            SET @nPQTY_PWY = @cUDF06
            SET @nMQTY_PWY = @cUDF07
            SET @nQTY_PWY = @cUDF08
            SET @nPUOM_Div = @cUDF09
            SET @nPQTY = @cUDF10
            SET @nMQTY = @cUDF11
            SET @cID = @cUDF12
         END

         IF @nErrNo <> 0
            GOTO Step_99_Fail
      END
   END

   GOTO Quit

Step_99_Fail:
   BEGIN
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,
      Func = @nFunc,        
      Step = @nStep,
      Scn = @nScn,

      Facility  = @cFacility,
      StorerKey = @cStorerKey,
      -- UserName  = @cUserName,

      V_LOC      = @cFromLOC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDesc,
      V_ID       = @cID,
      V_UOM      = @cPUOM,
      --V_QTY      = @nQTY,

      V_String1  = @cDecodeLabelNo,
      V_String2  = @cMUOM_Desc,
      V_String3  = @cPUOM_Desc,
      --V_String4  = @nPUOM_Div ,
      --V_String5  = @nPQTY_PWY ,
      --V_String6  = @nMQTY_PWY ,
      --V_String7  = @nQTY_PWY,
      --V_String8  = @nPQTY,
      --V_String9  = @nMQTY,
      V_String10 = @cSuggestedLOC,
      V_String11 = @cFinalLOC,
      V_String12 = @cExtendedValidateSP,
      V_String13 = @cExtendedScreenSP,--(JHU151)
      V_Integer1  = @nQTY,
      V_Integer2  = @nPQTY_PWY,
      V_Integer3  = @nMQTY_PWY,
      V_Integer4  = @nQTY_PWY,
      
      V_PUOM_Div  = @nPUOM_Div,
      V_PQTY      = @nPQTY,
      V_MQTY      = @nMQTY,

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