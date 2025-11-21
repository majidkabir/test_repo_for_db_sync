SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_555ExtScn01                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Customer: LVSUSA                                                     */
/*                                                                      */  
/* Date       Rev     Author     Purposes                               */  
/* 2024-11-25 1.0.0   LJQ006     FCR-1292. Created                      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_555ExtScn01] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep INT,           
   @nScn  INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15), 

   @tExtScnData   VariableTable READONLY,

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  @cLottable01 NVARCHAR( 18) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,  @cLottable02 NVARCHAR( 18) OUTPUT,  
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  @cLottable03 NVARCHAR( 18) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,  @dLottable04 DATETIME      OUTPUT,  
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,  @dLottable05 DATETIME      OUTPUT,  
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,  @cLottable06 NVARCHAR( 30) OUTPUT, 
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  @cLottable07 NVARCHAR( 30) OUTPUT, 
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  @cLottable08 NVARCHAR( 30) OUTPUT, 
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  @cLottable09 NVARCHAR( 30) OUTPUT, 
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  @cLottable10 NVARCHAR( 30) OUTPUT, 
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  @cLottable11 NVARCHAR( 30) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  @cLottable12 NVARCHAR( 30) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  @dLottable13 DATETIME      OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  @dLottable14 DATETIME      OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  @dLottable15 DATETIME      OUTPUT,
   @nAction      INT, --0 Jump Screen, 2. Prepare output fields, Step = 99 is a new screen
   @nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT,
   @cUDF01  NVARCHAR( 250) OUTPUT, @cUDF02 NVARCHAR( 250) OUTPUT, @cUDF03 NVARCHAR( 250) OUTPUT,
   @cUDF04  NVARCHAR( 250) OUTPUT, @cUDF05 NVARCHAR( 250) OUTPUT, @cUDF06 NVARCHAR( 250) OUTPUT,
   @cUDF07  NVARCHAR( 250) OUTPUT, @cUDF08 NVARCHAR( 250) OUTPUT, @cUDF09 NVARCHAR( 250) OUTPUT,
   @cUDF10  NVARCHAR( 250) OUTPUT, @cUDF11 NVARCHAR( 250) OUTPUT, @cUDF12 NVARCHAR( 250) OUTPUT,
   @cUDF13  NVARCHAR( 250) OUTPUT, @cUDF14 NVARCHAR( 250) OUTPUT, @cUDF15 NVARCHAR( 250) OUTPUT,
   @cUDF16  NVARCHAR( 250) OUTPUT, @cUDF17 NVARCHAR( 250) OUTPUT, @cUDF18 NVARCHAR( 250) OUTPUT,
   @cUDF19  NVARCHAR( 250) OUTPUT, @cUDF20 NVARCHAR( 250) OUTPUT, @cUDF21 NVARCHAR( 250) OUTPUT,
   @cUDF22  NVARCHAR( 250) OUTPUT, @cUDF23 NVARCHAR( 250) OUTPUT, @cUDF24 NVARCHAR( 250) OUTPUT,
   @cUDF25  NVARCHAR( 250) OUTPUT, @cUDF26 NVARCHAR( 250) OUTPUT, @cUDF27 NVARCHAR( 250) OUTPUT,
   @cUDF28  NVARCHAR( 250) OUTPUT, @cUDF29 NVARCHAR( 250) OUTPUT, @cUDF30 NVARCHAR( 250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- declare variables
   DECLARE
      @nMenu      INT,
      @bSuccess   INT,
      @cStorerGroup  NVARCHAR( 20),
      @cSumSKULocID     NVARCHAR(1),
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
      @cExtendedInfoSP     NVARCHAR( 20),    --(yeekung02)
      @cExtendedInfo       NVARCHAR( 20),     --(yeekung02)
      @cLOCLookUP          NVARCHAR(20),  --(yeekung03)
      @cDispStyleColorSize  NVARCHAR( 20), --(yeekung04)

      -- (james04)
      @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
      @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
      @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
      @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
      @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
      @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
      @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
      @c_oFieled15 NVARCHAR(20),

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
      

   SET @nErrNo = 0
   SET @cErrMsg = ''

   -- get storerconfig
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

   SET @cSumSKULocID = rdt.rdtGetConfig( @nFunc, 'SumSKULocID', @cStorerkey)
   IF @cSumSKULocID = '0'
      SET @cSumSKULocID = ''
   
   -- all the logic start at the beginning of step, so get variables directly from iotable
   SELECT 
      @nStep = Step,
      @nMenu = Menu,
      @cPUOM = V_UOM,
      @cStorerGroup = StorerGroup,
      @nFromScn = V_FromScn,
      @nMultiStorer = V_Integer15,
      @cSKUStatus = V_String25,
      @cDecodeSP= V_String26,
      @cExtendedInfoSP= V_String27,
      @cLOCLookUP= V_String29,
      @cDispStyleColorSize= V_String30
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @nTotalRec = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nTotalRec'
   SELECT @nCurrentRec = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nCurrentRec'
   SELECT @cInquiry_LOC = Value FROM @tExtScnData WHERE Variable = '@cInquiry_LOC'
   SELECT @cInquiry_ID = Value FROM @tExtScnData WHERE Variable = '@cInquiry_ID'
   SELECT @cInquiry_SKU = Value FROM @tExtScnData WHERE Variable = '@cInquiry_SKU'
   SELECT @cPUOM_Desc = Value FROM @tExtScnData WHERE Variable = '@cPUOM_Desc'
   SELECT @cMUOM_Desc = Value FROM @tExtScnData WHERE Variable = '@cMUOM_Desc'

   SELECT @cSKUBarcode = Value FROM @tExtScnData WHERE Variable = '@cSKUBarcode'
   SELECT @cSKUBarcode1 = Value FROM @tExtScnData WHERE Variable = '@cSKUBarcode1'
   SELECT @cSKUBarcode2 = Value FROM @tExtScnData WHERE Variable = '@cSKUBarcode2'
   SELECT @cLOC = Value FROM @tExtScnData WHERE Variable = '@cLOC'
   SELECT @cID = Value FROM @tExtScnData WHERE Variable = '@cID'
   SELECT @cSKU = Value FROM @tExtScnData WHERE Variable = '@cSKU'
   SELECT @cSKUDescr = Value FROM @tExtScnData WHERE Variable = '@cSKUDescr'
   SELECT @cPUOM_Desc = Value FROM @tExtScnData WHERE Variable = '@cPUOM_Desc'
   SELECT @cMUOM_Desc = Value FROM @tExtScnData WHERE Variable = '@cMUOM_Desc'

   SELECT @nMQTY_TTL = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMQTY_TTL'
   SELECT @nMQTY_Alloc = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMQTY_Alloc'
   SELECT @nMQTY_Pick = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMQTY_Pick'
   SELECT @nMQTY_RPL = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMQTY_RPL'
   SELECT @nMQTY_PMV = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMQTY_PMV'
   SELECT @nMQTY_Avail = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nMQTY_Avail'

   SELECT @nPQTY_TTL = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPQTY_TTL'
   SELECT @nPQTY_Alloc = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPQTY_Alloc'
   SELECT @nPQTY_Pick = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPQTY_Pick'
   SELECT @nPQTY_RPL = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPQTY_RPL'
   SELECT @nPQTY_PMV = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPQTY_PMV'
   SELECT @nPQTY_Avail = CAST(Value AS INT) FROM @tExtScnData WHERE Variable = '@nPQTY_Avail'

   IF @nFunc = 555
   BEGIN
      IF @nStep IN (0, 4)
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @nAction = 0
            BEGIN
               IF @cSumSKULocID <> ''
               BEGIN
                  SET @nAfterScn = 801
                  SET @nAfterStep = 99
                  GOTO Quit
               END
            END
         END
      END
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @nAction = 0
            BEGIN
               IF @cSumSKULocID <> ''
               BEGIN
                  SET @nAfterScn = 803
                  SET @nAfterStep = 99
                  GOTO Quit
               END
            END
         END
         IF @nInputKey = 0
         BEGIN
            IF @nAction = 0
            BEGIN
               IF @cSumSKULocID <> ''
               BEGIN
                  SET @nAfterScn = 801
                  SET @nAfterStep = 99
                  GOTO Quit
               END
            END
         END
      END
      IF @nStep = 99
      BEGIN
         IF @nScn = 801
         BEGIN
            IF @nInputKey = 1
            BEGIN
               IF @nAction = 0
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
                     SET @nErrNo = 229776
                     SET @cErrMsg = rdt.rdtgetmessage( 229776, @cLangCode, 'DSP') --'Value needed'
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Step_1_99_Fail
                  END

                  IF @i > 1
                  BEGIN
                     SET @nErrNo = 229777
                     SET @cErrMsg = rdt.rdtgetmessage( 229777, @cLangCode, 'DSP') --'ID/LOC/SKUOnly'
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Step_1_99_Fail
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
                           GOTO Step_1_99_Fail        
                     END    

                     DECLARE @cChkFacility NVARCHAR( 5)
                     SELECT @cChkFacility = Facility
                     FROM dbo.LOC WITH (NOLOCK)
                     WHERE LOC = @cInquiry_LOC

                     -- Validate LOC
                     IF @@ROWCOUNT = 0
                     BEGIN
                        SET @nErrNo = 229778
                        SET @cErrMsg = rdt.rdtgetmessage( 229778, @cLangCode, 'DSP') --'Invalid LOC'
                        EXEC rdt.rdtSetFocusField @nMobile, 1
                        GOTO Step_1_99_Fail
                     END

                     IF @cChkFacility <> @cFacility
                     BEGIN
                        SET @nErrNo = 229779
                        SET @cErrMsg = rdt.rdtgetmessage( 229779, @cLangCode, 'DSP') --'Diff facility'
                        EXEC rdt.rdtSetFocusField @nMobile, 1
                        GOTO Step_1_99_Fail
                     END
                  END

                  -- By ID
                  IF @cInquiry_ID <> '' AND @cInquiry_ID IS NOT NULL
                  BEGIN
                   -- Check barcode format
                     IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cInquiry_ID) = 0
                     BEGIN
                        SET @nErrNo = 229787
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
                        GOTO Step_1_99_Fail
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
                              GOTO Step_1_99_Fail
                        END
                     END

                     -- Validate ID
                     IF NOT EXISTS (SELECT 1
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                           INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                        WHERE LOC.Facility = @cFacility
                           AND LLI.ID = @cInquiry_ID)
                     BEGIN
                        SET @nErrNo = 229780
                        SET @cErrMsg = rdt.rdtgetmessage( 229780, @cLangCode, 'DSP') --'Invalid ID'
                        EXEC rdt.rdtSetFocusField @nMobile, 2
                        GOTO Step_1_99_Fail
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
                           GOTO Step_1_99_Fail
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
                              GOTO Step_1_99_Fail
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
                        SET @nErrNo = 229788
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
                        EXEC rdt.rdtSetFocusField @nMobile, 3
                        GOTO Step_1_99_Fail
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
                           SET @nErrNo = 229789
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
                           EXEC rdt.rdtSetFocusField @nMobile, 3
                           GOTO Step_1_99_Fail
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
                        SET @nErrNo = 229781
                        SET @cErrMsg = rdt.rdtgetmessage( 229781, @cLangCode, 'DSP') --'Invalid SKU'
                        EXEC rdt.rdtSetFocusField @nMobile, 3
                        GOTO Step_1_99_Fail
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
                        SET @nErrNo = 229786
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid record
                        EXEC rdt.rdtSetFocusField @nMobile, 2
                        GOTO Step_1_99_Fail
                     END

                     -- Check storer not in storer group
                     IF NOT EXISTS (SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cChkStorerKey)
                     BEGIN
                        SET @nErrNo = 229785
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotInStorerGrp
                        EXEC rdt.rdtSetFocusField @nMobile, 2
                        GOTO Step_1_99_Fail
                     END

                     -- Set session storer
                     SET @cStorerKey = @cChkStorerKey
                     SET @nMultiStorer = 0
                  END

                  Skip_ValidateSKU:
                  -- Get total record
                  SET @nTotalRec = 0
                  IF @cInquiry_LOC <> ''
                  BEGIN
                     SELECT @nTotalRec = COUNT(DISTINCT LLI.SKU + LLI.LOC + LLI.ID)
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
                     SELECT @nTotalRec = COUNT(DISTINCT LLI.SKU + LLI.LOC + LLI.ID)
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
                     SELECT @nTotalRec = COUNT(DISTINCT LLI.SKU + LLI.LOC + LLI.ID)
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
                     SET @nErrNo = 229782
                     SET @cErrMsg = rdt.rdtgetmessage( 229782, @cLangCode, 'DSP') --'No record'
                     EXEC rdt.rdtSetFocusField @nMobile, 1
                     GOTO Step_1_99_Fail
                  END

                  -- Get stock info
                  IF @cInquiry_LOC <> ''
                  BEGIN
                     SELECT TOP 1
                        -- @cLOT = LLI.LOT,
                        @cLOC = LLI.LOC,
                        @cID = LLI.ID,
                        @cSKU = LLI.SKU,
                        @cSKUDescr = CASE WHEN @cDispStyleColorSize='0' THEN SKU.Descr
                                     ELSE    CAST( Style AS NCHAR(20)) +       
                                             CAST( Color AS NCHAR(10)) +       
                                             CAST( Size  AS NCHAR(10))  END   ,
                        -- @cLottableCode = SKU.LottableCode,
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
                        @nMQTY_Alloc = SUM(LLI.QTYAllocated),
                        @nMQTY_Pick  = SUM(LLI.QTYPicked),
                        @nMQTY_Avail = SUM(LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),
                        @nPUOM_Div = CAST( IsNULL(
                        CASE @cPUOM
                              WHEN '2' THEN Pack.CaseCNT
                              WHEN '3' THEN Pack.InnerPack
                              WHEN '6' THEN Pack.QTY
                              WHEN '1' THEN Pack.Pallet
                              WHEN '4' THEN Pack.OtherUnit1
                         WHEN '5' THEN Pack.OtherUnit2
                           END, 1) AS INT),
                        -- @cLottable01 = LA.Lottable01,
                        -- @cLottable02 = LA.Lottable02,
                        -- @cLottable03 = LA.Lottable03,
                        -- @dLottable04 = LA.Lottable04,
                        -- @dLottable05 = LA.Lottable05,
                        -- @cLottable06 = LA.Lottable06,
                        -- @cLottable07 = LA.Lottable07,
                        -- @cLottable08 = LA.Lottable08,
                        -- @cLottable09 = LA.Lottable09,
                        -- @cLottable10 = LA.Lottable10,
                        -- @cLottable11 = LA.Lottable11,
                        -- @cLottable12 = LA.Lottable12,
                        -- @dLottable13 = LA.Lottable13,
                        -- @dLottable14 = LA.Lottable14,
                        -- @dLottable15 = LA.Lottable15,
                        @nMQty_TTL = SUM(LLI.Qty),        -- (james02)
                        @nMQty_RPL = SUM(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),    -- (james02)
                        @nMQTY_PMV = SUM(LLI.PendingMoveIN)   -- (james12)
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                        INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                        INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                        INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                     WHERE LOC.Facility = @cFacility
                        --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
                        AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
                        AND LLI.LOC = @cInquiry_LOC
                        -- ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping
                        GROUP BY LLI.SKU, LLI.LOC, LLI.ID, SKU.Descr, SKU.Style, SKU.Color, 
                           SKU.Size, SKU.LottableCode, Pack.PackUOM3, Pack.PackUOM1, Pack.PackUOM2, 
                           Pack.PackUOM4, Pack.PackUOM8, Pack.PackUOM9, Pack.CaseCNT, Pack.InnerPack, 
                           Pack.QTY, Pack.Pallet, Pack.OtherUnit1, Pack.OtherUnit2
                        ORDER BY LLI.SKU + LLI.LOC + LLI.ID
                  END
                  ELSE IF @cInquiry_ID  <> ''
                  BEGIN
                     SELECT TOP 1
                        -- @cLOT = LLI.LOT,
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
                        @nMQTY_Alloc = SUM(LLI.QTYAllocated),
                        @nMQTY_Pick  = SUM(LLI.QTYPicked),
                        @nMQTY_Avail = SUM(LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),
                        @nPUOM_Div = CAST( IsNULL(
                        CASE @cPUOM
                              WHEN '2' THEN Pack.CaseCNT
                              WHEN '3' THEN Pack.InnerPack
                              WHEN '6' THEN Pack.QTY
                              WHEN '1' THEN Pack.Pallet
                              WHEN '4' THEN Pack.OtherUnit1
                              WHEN '5' THEN Pack.OtherUnit2
                           END, 1) AS INT),
                        -- @cLottable01 = LA.Lottable01,
                        -- @cLottable02 = LA.Lottable02,
                        -- @cLottable03 = LA.Lottable03,
                        -- @dLottable04 = LA.Lottable04,
                        -- @dLottable05 = LA.Lottable05,
                        -- @cLottable06 = LA.Lottable06,
                        -- @cLottable07 = LA.Lottable07,
                        -- @cLottable08 = LA.Lottable08,
                        -- @cLottable09 = LA.Lottable09,
                        -- @cLottable10 = LA.Lottable10,
                        -- @cLottable11 = LA.Lottable11,
                        -- @cLottable12 = LA.Lottable12,
                        -- @dLottable13 = LA.Lottable13,
                        -- @dLottable14 = LA.Lottable14,
                        -- @dLottable15 = LA.Lottable15,
                        @nMQty_TTL = SUM(LLI.Qty),        -- (james02)
                        @nMQty_RPL = SUM(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),    -- (james02)
                        @nMQTY_PMV = SUM(LLI.PendingMoveIN)   -- (james12)
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                        INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                        INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                        INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                        INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                     WHERE LOC.Facility = @cFacility
                        --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
                        AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
                        AND LLI.ID  = @cInquiry_ID
                     -- ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping
                     GROUP BY LLI.SKU, LLI.LOC, LLI.ID, SKU.Descr, SKU.Style, SKU.Color, 
                           SKU.Size, SKU.LottableCode, Pack.PackUOM3, Pack.PackUOM1, Pack.PackUOM2, 
                           Pack.PackUOM4, Pack.PackUOM8, Pack.PackUOM9, Pack.CaseCNT, Pack.InnerPack, 
                           Pack.QTY, Pack.Pallet, Pack.OtherUnit1, Pack.OtherUnit2
                     ORDER BY LLI.SKU + LLI.LOC + LLI.ID
                  END
                  ELSE
                  BEGIN
                     SELECT TOP 1
                        -- @cLOT = LLI.LOT,
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
                        @nMQTY_Alloc = SUM(LLI.QTYAllocated),
                        @nMQTY_Pick  = SUM(LLI.QTYPicked),
                        @nMQTY_Avail = SUM(LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),
                        @nPUOM_Div = CAST( IsNULL(
                        CASE @cPUOM
                              WHEN '2' THEN Pack.CaseCNT
                              WHEN '3' THEN Pack.InnerPack
                              WHEN '6' THEN Pack.QTY
                              WHEN '1' THEN Pack.Pallet
                              WHEN '4' THEN Pack.OtherUnit1
                              WHEN '5' THEN Pack.OtherUnit2
                           END, 1) AS INT),
                        -- @cLottable01 = LA.Lottable01,
                        -- @cLottable02 = LA.Lottable02,
                        -- @cLottable03 = LA.Lottable03,
                        -- @dLottable04 = LA.Lottable04,
                        -- @dLottable05 = LA.Lottable05,
                        -- @cLottable06 = LA.Lottable06,
                        -- @cLottable07 = LA.Lottable07,
                        -- @cLottable08 = LA.Lottable08,
                        -- @cLottable09 = LA.Lottable09,
                        -- @cLottable10 = LA.Lottable10,
                        -- @cLottable11 = LA.Lottable11,
                        -- @cLottable12 = LA.Lottable12,
                        -- @dLottable13 = LA.Lottable13,
                        -- @dLottable14 = LA.Lottable14,
                        -- @dLottable15 = LA.Lottable15,
                        @nMQty_TTL = SUM(LLI.Qty),        -- (james02)
                        @nMQty_RPL = SUM(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),    -- (james02)
                        @nMQTY_PMV = SUM(LLI.PendingMoveIN)   -- (james12)
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
                     -- ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT -- Needed for looping
                     GROUP BY LLI.SKU, LLI.LOC, LLI.ID, SKU.Descr, SKU.Style, SKU.Color, 
                           SKU.Size, SKU.LottableCode, Pack.PackUOM3, Pack.PackUOM1, Pack.PackUOM2, 
                           Pack.PackUOM4, Pack.PackUOM8, Pack.PackUOM9, Pack.CaseCNT, Pack.InnerPack, 
                           Pack.QTY, Pack.Pallet, Pack.OtherUnit1, Pack.OtherUnit2
                     ORDER BY LLI.SKU + LLI.LOC + LLI.ID
                  END

                  -- Validate if any result
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET @nErrNo = 229783
                     SET @cErrMsg = rdt.rdtgetmessage( 229783, @cLangCode, 'DSP') --'No record'
                     EXEC rdt.rdtSetFocusField @nMobile, 3
                     GOTO Step_1_99_Fail
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

                  -- Go to result screen
                  SET @nAfterScn = 802
                  SET @nAfterStep = 2

                  SET @cUDF01 = @cLottableCode
                  SET @cUDF02 = @cInquiry_ID
                  SET @cUDF03 = @cInquiry_SKU
                  SET @cUDF04 = @cInquiry_LOC
                  SET @cUDF05 = @cSKUBarcode
                  SET @cUDF06 = @cSKUBarcode1
                  SET @cUDF07 = @cSKUBarcode2
                  SET @cUDF08 = CAST(@nTotalRec AS NVARCHAR(255))
                  SET @cUDF09 = CAST(@nCurrentRec AS NVARCHAR(255))
                  SET @cUDF10 = @cLOC
                  SET @cUDF11 = @cID
                  SET @cUDF12 = @cSKU
                  SET @cUDF13 = @cSKUDescr
                  SET @cUDF14 = @cPUOM_Desc
                  SET @cUDF15 = @cMUOM_Desc

                  SET @cUDF16 = CAST(@nMQTY_TTL AS NVARCHAR(255))
                  SET @cUDF17 = CAST(@nMQTY_Alloc AS NVARCHAR(255))
                  SET @cUDF18 = CAST(@nMQTY_Pick AS NVARCHAR(255))
                  SET @cUDF19 = CAST(@nMQTY_RPL AS NVARCHAR(255))
                  SET @cUDF20 = CAST(@nMQTY_PMV AS NVARCHAR(255))
                  SET @cUDF21 = CAST(@nMQTY_Avail AS NVARCHAR(255))

                  SET @cUDF22 = CAST(@nPQTY_TTL AS NVARCHAR(255))
                  SET @cUDF23 = CAST(@nPQTY_Alloc AS NVARCHAR(255))
                  SET @cUDF24 = CAST(@nPQTY_Pick AS NVARCHAR(255))
                  SET @cUDF25 = CAST(@nPQTY_RPL AS NVARCHAR(255))
                  SET @cUDF26 = CAST(@nPQTY_PMV AS NVARCHAR(255))
                  SET @cUDF27 = CAST(@nPQTY_Avail AS NVARCHAR(255))


                  GOTO Quit

                  Step_1_99_Fail:
                  BEGIN
                     -- Reset this screen var
                     SET @cInquiry_LOC = ''
                     SET @cInquiry_ID = ''
                     SET @cInquiry_SKU = ''
                     SET @cOutField01 = '' -- LOC
                     SET @cOutField02 = '' -- ID
                     SET @cOutField03 = '' -- SKU
                  END
                  GOTO Quit
               END
            END
            IF @nInputKey = 0
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
               SET @nAfterScn = @nMenu
               SET @nAfterStep = 0
               SET @cOutField01 = ''

               GOTO Quit
            END
         END
         IF @nScn = 803
         BEGIN
            IF @nInputKey = 1
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
                           GOTO Step_1_99_Fail
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

               IF @cInquiry_LOC <> ''
               BEGIN
                  SELECT TOP 1
                     -- @cLOT = LLI.LOT,
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
                     @nMQTY_Alloc = SUM(LLI.QTYAllocated),
                     @nMQTY_Pick  = SUM(LLI.QTYPicked),
                     @nMQTY_Avail = SUM(LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),
                     @nPUOM_Div = CAST(
                        CASE @cPUOM
                           WHEN '2' THEN Pack.CaseCNT
                           WHEN '3' THEN Pack.InnerPack
                           WHEN '6' THEN Pack.QTY
                           WHEN '1' THEN Pack.Pallet
                           WHEN '4' THEN Pack.OtherUnit1
                           WHEN '5' THEN Pack.OtherUnit2
                        END AS INT),
                     -- @cLottable01 = LA.Lottable01,
                     -- @cLottable02 = LA.Lottable02,
                     -- @cLottable03 = LA.Lottable03,
                     -- @dLottable04 = LA.Lottable04,
                     -- @dLottable05 = LA.Lottable05,
                     -- @cLottable06 = LA.Lottable06,
                     -- @cLottable07 = LA.Lottable07,
                     -- @cLottable08 = LA.Lottable08,
                     -- @cLottable09 = LA.Lottable09,
                     -- @cLottable10 = LA.Lottable10,
                     -- @cLottable11 = LA.Lottable11,
                     -- @cLottable12 = LA.Lottable12,
                     -- @dLottable13 = LA.Lottable13,
                     -- @dLottable14 = LA.Lottable14,
                     -- @dLottable15 = LA.Lottable15,
                     @nMQty_TTL = SUM(LLI.Qty),        -- (james02)
                     @nMQty_RPL = SUM(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),    -- (james02)
                     @nMQTY_PMV = SUM(LLI.PendingMoveIN)   -- (james12)
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                     INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                     INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                  WHERE LOC.Facility = @cFacility
                     --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
                     AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
                     AND LLI.LOC = @cInquiry_LOC
                     -- AND (LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT) > (@cSKU + @cLOC + @cID + @cLOT) -- next row
                     AND (LLI.SKU + LLI.LOC + LLI.ID) > (@cSKU + @cLOC + @cID)
                  -- ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT
                  GROUP BY LLI.SKU, LLI.LOC, LLI.ID, SKU.Descr, SKU.Style, SKU.Color, 
                           SKU.Size, SKU.LottableCode, Pack.PackUOM3, Pack.PackUOM1, Pack.PackUOM2, 
                           Pack.PackUOM4, Pack.PackUOM8, Pack.PackUOM9, Pack.CaseCNT, Pack.InnerPack, 
                           Pack.QTY, Pack.Pallet, Pack.OtherUnit1, Pack.OtherUnit2
                  ORDER BY LLI.SKU + LLI.LOC + LLI.ID
               END
               ELSE IF @cInquiry_ID <> ''
               BEGIN
                  SELECT TOP 1
                     -- @cLOT = LLI.LOT,
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
                     @nMQTY_Alloc = SUM(LLI.QTYAllocated),
                     @nMQTY_Pick  = SUM(LLI.QTYPicked),
                     @nMQTY_Avail = SUM(LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),
                     @nPUOM_Div = CAST(
                        CASE @cPUOM
                           WHEN '2' THEN Pack.CaseCNT
                           WHEN '3' THEN Pack.InnerPack
                           WHEN '6' THEN Pack.QTY
                           WHEN '1' THEN Pack.Pallet
                           WHEN '4' THEN Pack.OtherUnit1
                           WHEN '5' THEN Pack.OtherUnit2
                        END AS INT),
                     -- @cLottable01 = LA.Lottable01,
                     -- @cLottable02 = LA.Lottable02,
                     -- @cLottable03 = LA.Lottable03,
                     -- @dLottable04 = LA.Lottable04,
                     -- @dLottable05 = LA.Lottable05,
                     -- @cLottable06 = LA.Lottable06,
                     -- @cLottable07 = LA.Lottable07,
                     -- @cLottable08 = LA.Lottable08,
                     -- @cLottable09 = LA.Lottable09,
                     -- @cLottable10 = LA.Lottable10,
                     -- @cLottable11 = LA.Lottable11,
                     -- @cLottable12 = LA.Lottable12,
                     -- @dLottable13 = LA.Lottable13,
                     -- @dLottable14 = LA.Lottable14,
                     -- @dLottable15 = LA.Lottable15,
                     @nMQty_TTL = SUM(LLI.Qty),        -- (james02)
                     @nMQty_RPL = SUM(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),    -- (james02)
                     @nMQTY_PMV = SUM(LLI.PendingMoveIN)  -- (james12)
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                     INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                     INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)
                     INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                     INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
                  WHERE LOC.Facility = @cFacility
                     --AND (LLI.QTY - LLI.QTYPicked) > 0  -- (ChewKP02)
                     AND (LLI.QTY <> 0 OR LLI.QtyAllocated <> 0 OR LLI.QtyPicked <> 0 OR LLI.QtyExpected <> 0) -- (ChewKP02)
                     AND LLI.ID = @cInquiry_ID
                     -- AND (LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT) > (@cSKU + @cLOC + @cID + @cLOT) -- next row
                     AND (LLI.SKU + LLI.LOC + LLI.ID ) > (@cSKU + @cLOC + @cID)
                  -- ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT
                  GROUP BY LLI.SKU, LLI.LOC, LLI.ID, SKU.Descr, SKU.Style, SKU.Color, 
                           SKU.Size, SKU.LottableCode, Pack.PackUOM3, Pack.PackUOM1, Pack.PackUOM2, 
                           Pack.PackUOM4, Pack.PackUOM8, Pack.PackUOM9, Pack.CaseCNT, Pack.InnerPack, 
                           Pack.QTY, Pack.Pallet, Pack.OtherUnit1, Pack.OtherUnit2
                  ORDER BY LLI.SKU + LLI.LOC + LLI.ID
               END
               ELSE
               BEGIN
                  SELECT TOP 1
                     -- @cLOT = LLI.LOT,
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
                     @nMQTY_Alloc = SUM(LLI.QTYAllocated),
                     @nMQTY_Pick  = SUM(LLI.QTYPicked),
                     @nMQTY_Avail = SUM(LLI.QTY - LLI.QTYPicked - LLI.QTYAllocated - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)),
                     @nPUOM_Div = CAST(
                        CASE @cPUOM
                           WHEN '2' THEN Pack.CaseCNT
                           WHEN '3' THEN Pack.InnerPack
                           WHEN '6' THEN Pack.QTY
                           WHEN '1' THEN Pack.Pallet
                           WHEN '4' THEN Pack.OtherUnit1
                           WHEN '5' THEN Pack.OtherUnit2
                        END AS INT),
                     -- @cLottable01 = LA.Lottable01,
                     -- @cLottable02 = LA.Lottable02,
                     -- @cLottable03 = LA.Lottable03,
                     -- @dLottable04 = LA.Lottable04,
                     -- @dLottable05 = LA.Lottable05,
                     -- @cLottable06 = LA.Lottable06,
                     -- @cLottable07 = LA.Lottable07,
                     -- @cLottable08 = LA.Lottable08,
                     -- @cLottable09 = LA.Lottable09,
                     -- @cLottable10 = LA.Lottable10,
                     -- @cLottable11 = LA.Lottable11,
                     -- @cLottable12 = LA.Lottable12,
                     -- @dLottable13 = LA.Lottable13,
                     -- @dLottable14 = LA.Lottable14,
                     -- @dLottable15 = LA.Lottable15,
                     @nMQty_TTL = SUM(LLI.Qty),        -- (james02)
                     @nMQty_RPL = SUM(CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END),    -- (james02)
                     @nMQTY_PMV = SUM(LLI.PendingMoveIN)   -- (james12)
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
                     -- AND (LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT) > (@cSKU + @cLOC + @cID + @cLOT) -- next row
                  -- ORDER BY LLI.SKU + LLI.LOC + LLI.ID + LLI.LOT
                     AND (LLI.SKU + LLI.LOC + LLI.ID) > (@cSKU + @cLOC + @cID)
                  GROUP BY LLI.SKU, LLI.LOC, LLI.ID, SKU.Descr, SKU.Style, SKU.Color, 
                           SKU.Size, SKU.LottableCode, Pack.PackUOM3, Pack.PackUOM1, Pack.PackUOM2, 
                           Pack.PackUOM4, Pack.PackUOM8, Pack.PackUOM9, Pack.CaseCNT, Pack.InnerPack, 
                           Pack.QTY, Pack.Pallet, Pack.OtherUnit1, Pack.OtherUnit2
                  ORDER BY LLI.SKU + LLI.LOC + LLI.ID
               END

               -- Validate if any result
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 229784
                  SET @cErrMsg = rdt.rdtgetmessage( 229784, @cLangCode, 'DSP') --'No record'
                  EXEC rdt.rdtSetFocusField @nMobile, 3
                  GOTO Step_1_99_Fail
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

               SET @cUDF01 = @cLottableCode
               SET @cUDF02 = @cInquiry_ID
               SET @cUDF03 = @cInquiry_SKU
               SET @cUDF04 = @cInquiry_LOC
               SET @cUDF05 = @cSKUBarcode
               SET @cUDF06 = @cSKUBarcode1
               SET @cUDF07 = @cSKUBarcode2
               SET @cUDF08 = CAST(@nTotalRec AS NVARCHAR(255))
               SET @cUDF09 = CAST(@nCurrentRec AS NVARCHAR(255))
               SET @cUDF10 = @cLOC
               SET @cUDF11 = @cID
               SET @cUDF12 = @cSKU
               SET @cUDF13 = @cSKUDescr
               SET @cUDF14 = @cPUOM_Desc
               SET @cUDF15 = @cMUOM_Desc
               SET @cUDF16 = CAST(@nMQTY_TTL AS NVARCHAR(255))
               SET @cUDF17 = CAST(@nMQTY_Alloc AS NVARCHAR(255))
               SET @cUDF18 = CAST(@nMQTY_Pick AS NVARCHAR(255))
               SET @cUDF19 = CAST(@nMQTY_RPL AS NVARCHAR(255))
               SET @cUDF20 = CAST(@nMQTY_PMV AS NVARCHAR(255))
               SET @cUDF21 = CAST(@nMQTY_Avail AS NVARCHAR(255))
               SET @cUDF22 = CAST(@nPQTY_TTL AS NVARCHAR(255))
               SET @cUDF23 = CAST(@nPQTY_Alloc AS NVARCHAR(255))
               SET @cUDF24 = CAST(@nPQTY_Pick AS NVARCHAR(255))
               SET @cUDF25 = CAST(@nPQTY_RPL AS NVARCHAR(255))
               SET @cUDF26 = CAST(@nPQTY_PMV AS NVARCHAR(255))
               SET @cUDF27 = CAST(@nPQTY_Avail AS NVARCHAR(255))

               -- Remain in current screen
               SET @nAfterScn = 802
               SET @nAfterStep = 2
               GOTO Quit
            END
            IF @nInputKey = 0
            BEGIN
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

               SET @cUDF09 = CAST(@nCurrentRec AS NVARCHAR(4))

               -- Go to prev screen
               SET @nAfterScn = 802
               SET @nAfterStep = 2
               GOTO Quit
            END
         END
      END   
   END

   

Quit:
END

GO