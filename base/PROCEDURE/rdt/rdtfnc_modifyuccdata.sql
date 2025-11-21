SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_ModifyUCCData                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Direct modify UCC data                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2008-04-29  1.0  Ung      Created                                    */
/* 15-Jul-2010 1.1  KHLim    Replace USER_NAME to sUSER_sName           */
/* 20-Jul-2010 1.2  TLTing   Remove DB Hard Coding                      */
/* 23-Jul-2010 1.3  KHLim    SET CONCAT_NULL_YIELDS_NULL OFF            */
/* 20-Oct-2011 1.4  SHONG    Update Receipt Detail If Not Finalize      */
/*                    (SOS228769) Only execute if Configkey turn on     */
/* 09-Dec-2011 1.5  ChewKP   OffSet ReceiptDetail by UCC (ChewKP01)     */
/* 10-Dec-2011 1.6  James    Close cursor (james01)                     */
/* 19-Dec-2011 1.7  Shong    Revise Update Receipt Detail Qty Logic     */
/* 28-May-2013 1.8  Leong    SOS#277977 - Revise Receipt Finalized and  */
/*                                        UCC verification              */
/* 13-Aug-2013 1.9  Ung      SOS286649 Support multi SKU UCC            */
/* 30-Sep-2016 2.0  Ung      Performance tuning                         */
/* 02-Nov-2018 2.1  TungGH   Performance                                */
/* 04-May-2020 2.2  James    WMS13049-Add ID, dynamic lottable (james02)*/
/*                           ExtendedValidateSP, ExtendedUpdateSP       */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_ModifyUCCData] (
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
   @cChkFacility NVARCHAR( 5),
   @bSuccess     INT, 
   @nSKUCnt      INT,
   @nRowCount    INT,
   @cXML         NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

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

   @cUCC        NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cLOT        NVARCHAR( 10),
   @cLOC        NVARCHAR( 10),
   @cID         NVARCHAR( 18),
   @cStatus     NVARCHAR( 1),
   @nQTY        INT,
   @cQTY        NVARCHAR( 5),
   @nSUMBeforeReceivedQty INT,
   @nSUMQtyExpected       INT,
   @cLottable01           NVARCHAR(18),
   @cLottable02           NVARCHAR(18),
   @cLottable03           NVARCHAR(18),
   @dLottable04           DATETIME,
   @dLottable05           DATETIME,
   @cLottable06           NVARCHAR( 30),
   @cLottable07           NVARCHAR( 30),
   @cLottable08           NVARCHAR( 30),
   @cLottable09           NVARCHAR( 30),
   @cLottable10           NVARCHAR( 30),
   @cLottable11           NVARCHAR( 30),
   @cLottable12           NVARCHAR( 30),
   @dLottable13           DATETIME,
   @dLottable14           DATETIME,
   @dLottable15           DATETIME,
   @nRowID                INT,

   @nUCC_Cnt              INT,
   @nMorePage             INT,
   @nFromScn              INT,
   @nMultiSKUUCC          INT,
   @nHasLottable          INT,
   @cLottableCode         NVARCHAR( 30),
   @cPalletID             NVARCHAR( 20),
   @cExtendedValidateSP   NVARCHAR( 20),
   @cExtendedUpdateSP     NVARCHAR( 20),
   @tExtValidVar          VARIABLETABLE,
   @tExtUpdateVar         VARIABLETABLE,
   @cSQL                  NVARCHAR( MAX), 
   @cSQLParam             NVARCHAR( MAX),    
   
   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1),
   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

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

   @cUCC        = V_UCC,
   @cSKU        = V_SKU,
   
   @cPalletID           = V_String1,
   @cExtendedValidateSP = V_String2,
   @cExtendedUpdateSP   = V_String3,
   @cLottableCode       = V_String4,

   @nFromScn            = V_Integer1,
   @nMultiSKUUCC        = V_Integer2,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDT.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 882 -- Modify UCC Data
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 882
   IF @nStep = 1 GOTO Step_1   -- Scn = 1480. UCC
   IF @nStep = 2 GOTO Step_2   -- Scn = 1481. SKU
   IF @nStep = 3 GOTO Step_3   -- Scn = 1482. UCC, LOT, LOC, ID, Status, QTY
   IF @nStep = 4 GOTO Step_4   -- Scn = 3490. Lottable  
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 882)
********************************************************************************/
Step_0:
BEGIN
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP IN ('0', '')
      SET @cExtendedValidateSP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP IN ('0', '')
      SET @cExtendedUpdateSP = ''
      
   -- Set the entry point
   SET @nScn = 1480
   SET @nStep = 1

   SET @cPalletID = ''
   SET @cUCC = ''
   
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   
   EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID        
   -- Init var
   -- Prep next screen var
END
GOTO Quit

/********************************************************************************
Step 1. Screen = 1480
   ID:  (Field01, input)
   UCC: (Field02, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      SET @cPalletID = @cInField01
      SET @cUCC = @cInField02

      IF ISNULL( @cPalletID, '') <> '' AND ISNULL( @cUCC, '') = ''
      BEGIN
         SET @cOutField01 = @cPalletID
         SET @cOutField02 = @cUCC
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC   
         GOTO Quit
      END
      
      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 64151
         SET @cErrMsg = rdt.rdtgetmessage( 64151, @cLangCode, 'DSP') --'UCC needed'
         GOTO Step_1_UCC_Fail
      END

      IF rdt.RDTGetConfig( @nFunc, 'UCC_DisableUpdateReceivedUCC', @cStorerkey) = '1'  
         AND EXISTS (SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK)  
                     WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC AND Status > 0)  
      BEGIN  
         SET @nErrNo = 64172  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'UCC Received'  
         GOTO Step_1_UCC_Fail  
      END  
  
      -- SOS#277977 (Start)
      IF EXISTS ( SELECT TOP 1 U.Receiptkey
                  FROM dbo.UCC U WITH (NOLOCK)
                  INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON RD.ReceiptKey = U.ReceiptKey
                         AND U.ReceiptLineNumber = 'MANY'
                  WHERE U.StorerKey = @cStorerKey
                    AND U.UCCNo = @cUCC )
      BEGIN
         SET @nErrNo = 64168
         SET @cErrMsg = rdt.rdtgetmessage(64168, @cLangCode, 'DSP') --'MANY Rcpt Line'
         GOTO Step_1_UCC_Fail
      END
      -- SOS#277977 (End)

      SELECT @nUCC_Cnt = COUNT(1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC

      -- Check if UCC exists
      IF @nUCC_Cnt = 0
      BEGIN
         SET @nErrNo = 64152
         SET @cErrMsg = rdt.rdtgetmessage( 64152, @cLangCode, 'DSP') --'UCC not exist'
         GOTO Step_1_UCC_Fail
      END

      SET @nMultiSKUUCC = 0
            
      -- Check if UCC is MultiSKU/PO
      IF @nUCC_Cnt > 1
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerkey) = '1'
         BEGIN
            -- Prep next screen var
            SET @cOutField01 = @cUCC
            SET @cOutField02 = '' -- SKU
            
            SET @nMultiSKUUCC = 1
            
            -- Go to next screen
            SET @nScn  = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Quit
         END
         
         SET @nErrNo = 64153
         SET @cErrMsg = rdt.rdtgetmessage( 64153, @cLangCode, 'DSP') --'UCCMultiSKU/PO'
         GOTO Step_1_UCC_Fail         
      END

      -- Get UCC info
      SELECT TOP 1
         @cSKU = SKU,
         @cLOT = LOT,
         @cLOC = LOC,
         @cID = ID,
         @cStatus = Status,
         @nQTY = QTY
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
      ORDER BY 1
      
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletID, @cUCC, @cLOT, @cLOC, @cID, @cSKU, @nQty, @cStatus, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' + 
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @cLOT           NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQty           INT,           ' +
               ' @cStatus        NVARCHAR( 1),  ' +               
               ' @tExtValidVar   VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cPalletID, @cUCC, @cLOT, @cLOC, @cID, @cSKU, @nQty, @cStatus, @tExtValidVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit            
         END
      END
      
      SELECT @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      SELECT 
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE Lottable10 = @cUCC
      
      IF @@ROWCOUNT = 0
         SET @nHasLottable = 0
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtLottableCode (NOLOCK) 
                         WHERE Function_ID = @nFunc
                         AND   LottableCode = @cLottableCode
                         AND   StorerKey = @cStorerKey)
            SET @nHasLottable = 0
         ELSE
            SET @nHasLottable = 1
      END
      
      SELECT @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = ''  
      SELECT @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''  

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 1, 
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

      IF @nHasLottable = 1 -- Yes  
      BEGIN  
         -- Go to dynamic lottable screen  
         SET @nFromScn = @nScn  
         SET @nScn = @nScn + 3  
         SET @nStep = @nStep + 3
      END  
      ELSE  
      BEGIN  
         -- Prep next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cLOT
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cID
         SET @cOutField05 = @cStatus
         SET @cOutField06 = CAST( @nQTY AS NVARCHAR( 5))
         SET @cOutField07 = @cSKU
         EXEC rdt.rdtSetFocusField @nMobile, 6

         -- Go to next screen
         SET @nScn  = @nScn + 2
         SET @nStep = @nStep + 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_ID_Fail:
   BEGIN
      SET @cPalletID = ''
      SET @cOutField01 = ''
      SET @cOutField02 = @cUCC
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ID        
   END

   Step_1_UCC_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField01 = @cPalletID
      SET @cOutField02 = ''
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC        
   END

END
GOTO Quit


/********************************************************************************
Step 2. Screen = 1481
   UCC:     (Field01)
   SKU/UPC: (Field02, input01)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1      -- Yes OR Send
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField02

      -- Check blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 64169
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --'SKU needed'
         GOTO Step_2_Fail
      END

      -- Get SKU barcode count
      EXEC rdt.rdt_GETSKUCNT
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 64170
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_2_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 64171
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
         GOTO Step_2_Fail
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerkey  = @cStorerKey
         ,@cSKU        = @cSKU          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU in UCC
      IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC AND SKU = @cSKU)
      BEGIN
         SET @nErrNo = 64168
         SET @cErrMsg = rdt.rdtgetmessage(64168, @cLangCode, 'DSP') --'SKU not in UCC'
         GOTO Step_2_Fail
      END
      
      -- Get UCC info
      SELECT
         @cLOT = LOT,
         @cLOC = LOC,
         @cID = ID,
         @cStatus = Status,
         @nQTY = QTY
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
         AND SKU = @cSKU

      SELECT @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      SELECT 
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE Lottable10 = @cUCC
      AND   SKU = @cSKU

      IF @@ROWCOUNT = 0
         SET @nHasLottable = 0
      ELSE
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtLottableCode (NOLOCK) 
                         WHERE Function_ID = @nFunc
                         AND   LottableCode = @cLottableCode
                         AND   StorerKey = @cStorerKey)
            SET @nHasLottable = 0
         ELSE
            SET @nHasLottable = 1
      END

      SELECT @cOutField01 = '', @cOutField02 = '', @cOutField03 = '', @cOutField04 = '', @cOutField05 = ''  
      SELECT @cOutField06 = '', @cOutField07 = '', @cOutField08 = '', @cOutField09 = '', @cOutField10 = ''  

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'DISPLAY', 'POPULATE', 5, 1, 
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

      IF @nHasLottable = 1 -- Yes  
      BEGIN  
         -- Go to dynamic lottable screen  
         SET @nFromScn = @nScn  
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2
      END  
      ELSE  
      BEGIN  
         -- Prep next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cLOT
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cID
         SET @cOutField05 = @cStatus
         SET @cOutField06 = CAST( @nQTY AS NVARCHAR( 5))
         SET @cOutField07 = @cSKU
         EXEC rdt.rdtSetFocusField @nMobile, 6

         -- Go to next screen
         SET @nScn  = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cPalletID = ''
      SET @cUCC = ''
      
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- UCC        
            
      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen = 1482
   UCC      (Field01)
   SKU/UPC: (Field07)
   LOT      (Field02, input)
   LOC      (Field03, input)
   ID       (Field04, input)
   Status   (Field05, input)
   QTY      (Field06, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @nQtyBeforeUpdate     INT,
              @cRcptDetFinalize     NVARCHAR(1),
              @cUCC_UpdRcptDetQty   NVARCHAR(1),
              @cReceiptKey          NVARCHAR(10),
              @cReceiptLineNumber   NVARCHAR(5),
              @nBeforeReceivedQty   INT,
              @nQtyAdjust           INT,
              @nQtyExpected         INT,
              @cPrevLoc             NVARCHAR(10),
              @cPrevID              NVARCHAR(18),
              @cByPassTolerance     NVARCHAR( 1),
              @nTolerancePercentage INT,
              @cAllow_OverReceipt   NVARCHAR(1),
              @cDuplicateFrom       NVARCHAR(5),
              @cPOKey               NVARCHAR(18),
              @cPOLineNumber        NVARCHAR(5),
              @cFinalizeFlag        NVARCHAR(1)

      -- Screen mapping
      SET @cLOT = @cInField02
      SET @cLOC = @cInField03
      SET @cID = @cInField04
      SET @cStatus = @cInField05
      SET @cQTY = @cInField06

      SET @cUCC_UpdRcptDetQty = rdt.RDTGetConfig( @nFunc, 'UCC_UpdRcptDetQty', @cStorerkey)

      IF @cUCC_UpdRcptDetQty = '1'
      BEGIN
         SELECT @cPrevLoc = LOC,
                @cPrevID  = ID
         FROM dbo.UCC WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   UCCNo = @cUCC

         IF NOT EXISTS(
            SELECT 1
            FROM dbo.UCC UCC (NOLOCK)
            WHERE UCC.StorerKey = @cStorerKey
               AND UCC.SKU   = @cSKU
               AND UCC.LOC   = @cLOC
               AND UCC.ID    = @cID
               AND UCC.UCCNo = @cUCC)
         BEGIN
            SET @cLOC = @cPrevLoc
            SET @cID = @cPrevID

            SET @cOutField04 = @cPrevID
            SET @cOutField03 = @cPrevLOC

            SET @nErrNo = 64162
            SET @cErrMsg = rdt.rdtgetmessage( 64162, @cLangCode, 'DSP') --'64162^OnlyQtyAllow'
                                                                        --12345678901234567890
            GOTO Step_3_Fail
         END

         -- Check QTY
         IF RDT.rdtIsValidQTY(@cQTY, 0) = 0 -- 1=Check for zero also
         BEGIN
            SET @nErrNo = 64157
            SET @cErrMsg = rdt.rdtgetmessage( 64157, @cLangCode, 'DSP') --'Invalid QTY'
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         -- Check LOC
         IF @cLOC <> ''
            AND NOT EXISTS(SELECT 1  FROM dbo.LOC (NOLOCK)
                           WHERE LOC = @cLOC AND Facility = @cFacility)
         BEGIN
            SET @nErrNo = 64154
            SET @cErrMsg = rdt.rdtgetmessage( 64154, @cLangCode, 'DSP') --'LOC Diff FAC'
            GOTO Step_3_Fail
         END

         -- Check LOT LOC ID
         IF @cLOT <> '' AND @cLOC <> ''
            AND NOT EXISTS(SELECT 1
                           FROM dbo.LOTxLOCxID LLI (NOLOCK)
                              INNER JOIN dbo.LOC LOC (NOLOCK) ON (LLI.LOC = LOC.LOC)
                           WHERE LLI.StorerKey = @cStorerKey
                              AND LLI.SKU = @cSKU
                              AND LLI.LOT = @cLOT
                              AND LLI.LOC = @cLOC
                              AND LLI.ID = @cID)
         BEGIN
            SET @nErrNo = 64155
            SET @cErrMsg = rdt.rdtgetmessage( 64155, @cLangCode, 'DSP') --'LLI not match'
            GOTO Step_3_Fail
         END

         -- Check QTY
         IF RDT.rdtIsValidQTY( @cQTY, 1) = 0 -- 1=Check for zero also
         BEGIN
            SET @nErrNo = 64157
            SET @cErrMsg = rdt.rdtgetmessage( 64157, @cLangCode, 'DSP') --'Invalid QTY'
            GOTO Step_3_Fail
         END
      END

      -- Check status
      IF @cStatus <> '0' AND
         @cStatus <> '1' AND
         @cStatus <> '2' AND
         @cStatus <> '3' AND
         @cStatus <> '4' AND
         @cStatus <> '5' AND
         @cStatus <> '6' AND
         @cStatus <> '9'
      BEGIN
         SET @nErrNo = 64156
         SET @cErrMsg = rdt.rdtgetmessage( 64156, @cLangCode, 'DSP') --'Bad Status'
         GOTO Step_3_Fail
      END

      SET @nQTY = CAST( @cQTY AS INT)

      /*
      -- (james02)
      SET @nUCC_Qty = 0
      SELECT ISNULL(@nUCC_Qty, 0) FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCC

      -- QTY to adjust cannot exceed original UCC QTY
      IF @nQTY > @nUCC_Qty
      BEGIN
         SET @nErrNo = 64167
         SET @cErrMsg = rdt.rdtgetmessage( 64167, @cLangCode, 'DSP') --'QTY ADJ>UCCQTY'
         GOTO Step_3_Fail
      END
      */
      SET @nErrNo = 0
      DECLARE @nTranCount  INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN Step3_UPDUCC -- For rollback or commit only our own transaction

      IF @cUCC_UpdRcptDetQty = '1'
      BEGIN
         -- Update BeforeReceivedQty by Lottable & SKU
         -- (ChewKP01)
         SET @nSUMBeforeReceivedQty =  0
         SET @nSUMQtyExpected = 0
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = ''
         SET @dLottable05 = ''
         SET @nRowcount = 1
         SET @cFinalizeFlag = 'N'
         SET @nBeforeReceivedQty = 0

         SELECT TOP 1
                @nQtyBeforeUpdate   = U.QTY,
                @cReceiptKey        = U.Receiptkey,
                @cReceiptLineNumber = U.ReceiptLineNumber, -- (ChewKP01)
                @cPrevLoc           = U.LOC,
                @cPrevID            = U.ID,
                @cLottable01        = RD.Lottable01,
                @cLottable02        = RD.Lottable02,
                @cLottable03        = RD.Lottable03,
                @dLottable04        = RD.Lottable04,
                @dLottable05        = RD.Lottable05,
                @cPOKey             = RD.PoKey,
                @cPOLineNumber      = RD.POLineNumber,
                @cFinalizeFlag      = ISNULL(RD.FinalizeFlag,'N'),
                @nBeforeReceivedQty = RD.BeforeReceivedQty
                --@nSUMBeforeReceivedQty = SUM(RD.BeforeReceivedQty),
                --@nSUMQtyExpected = SUM(QtyExpected)
         FROM dbo.UCC u WITH (NOLOCK)
         INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON RD.ReceiptKey = U.ReceiptKey AND RD.ReceiptLineNumber = U.ReceiptLineNumber
         WHERE U.StorerKey = @cStorerKey
           AND U.UCCNo = @cUCC
         --GROUP BY U.QTY, U.Receiptkey, U.LOC, U.ID, RD.Lottable01, RD.Lottable02, RD.Lottable03, RD.Lottable04, RD.Lottable05
         --Order By RD.BeforeReceivedQty desc

         -- SOS#277977 (Start)
         IF ISNULL(RTRIM(@cReceiptKey),'') = ''
         BEGIN
            SELECT TOP 1
                   @nQtyBeforeUpdate   = U.QTY,
                   @cReceiptKey        = U.Receiptkey,
                   @cReceiptLineNumber = U.ReceiptLineNumber,
                   @cPrevLoc           = U.LOC,
                   @cPrevID            = U.ID,
                   @cLottable01        = RD.Lottable01,
                   @cLottable02        = RD.Lottable02,
                   @cLottable03        = RD.Lottable03,
                   @dLottable04        = RD.Lottable04,
                   @dLottable05        = RD.Lottable05,
                   @cPOKey             = RD.PoKey,
                   @cPOLineNumber      = RD.POLineNumber,
                   @cFinalizeFlag      = ISNULL(RD.FinalizeFlag,'N'),
                   @nBeforeReceivedQty = RD.BeforeReceivedQty
            FROM dbo.UCC u WITH (NOLOCK)
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON RD.ReceiptKey = U.ReceiptKey AND RD.ToId = U.Id
            WHERE U.StorerKey = @cStorerKey
              AND U.UCCNo = @cUCC
         END
         -- SOS#277977 (End)

         IF @cFinalizeFlag = 'Y'
         BEGIN
            SET @nErrNo = 64159
            SET @cErrMsg = rdt.rdtgetmessage( 64159, @cLangCode, 'DSP') --'64159^Rcpt Finalized
            GOTO RollBackTran_Step3_UPDUCC
         END

         -- (james02)
         IF @nQTY = 0  -- If take off whole qty from ucc
         BEGIN
            SET @nQtyAdjust = 0 - @nQtyBeforeUpdate
         END
         ELSE -- If qty to adjust = ucc qty, means no change in qty (user accidentally pressed)
         IF @nQTY = @nQtyBeforeUpdate
         BEGIN
            SET @nQtyAdjust = 0
         END
         ELSE
         BEGIN  -- If add more ucc qty
            SET @nQtyAdjust = @nQTY - @nQtyBeforeUpdate
         END

         -- ELSE -- If take off partial qty from ucc
         -- IF @nQTY < @nQtyBeforeUpdate
         -- BEGIN
         --    SET @nQtyAdjust = 0 - @nQTY
         -- END

         SELECT @nSUMQtyExpected = PD.QtyOrdered
         FROM  dbo.PODetail PD WITH (NOLOCK)
         WHERE POKey      = @cPOKey
         AND   POLineNumber = @cPOLineNumber

         SELECT @nSUMBeforeReceivedQty = SUM(RD.BeforeReceivedQty),
                @nSUMQtyExpected = SUM(RD.QtyExpected)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   POKey      = @cPOKey
         AND   POLineNumber = @cPOLineNumber

         IF @nQtyAdjust > @nSUMBeforeReceivedQty
         BEGIN
            SET @nErrNo = 64160
            SET @cErrMsg = rdt.rdtgetmessage( 64160, @cLangCode, 'DSP') --'64160^Bad UCC Qty'
            GOTO RollBackTran_Step3_UPDUCC
         END

         SET @cByPassTolerance     = '0'
         SET @cAllow_OverReceipt   = '0'
         SET @nTolerancePercentage = 0
         SET @bSuccess = 1

         -- If Over received
         IF (@nQtyAdjust + @nSUMBeforeReceivedQty) > @nSUMQtyExpected
         BEGIN
            EXECUTE nspGetRight
                  @cFacility,
                  @cStorerkey,
                  @cSKU,
                  'Allow_OverReceipt',
                  @bSuccess             OUTPUT,
                  @cAllow_OverReceipt   OUTPUT,
                  @nErrNo               OUTPUT,
                  @cErrmsg              OUTPUT

            IF @cAllow_OverReceipt = '1'
            BEGIN
               EXECUTE nspGetRight
                     @cFacility,
                     @cStorerkey,
                     NULL,
                     'ByPassTolerance',
                     @bSuccess           OUTPUT,
                     @cByPassTolerance   OUTPUT,
                     @nErrNo             OUTPUT,
                     @cErrMsg            OUTPUT

               IF @cByPassTolerance = '0'
               BEGIN
                  SET @nTolerancePercentage = 0
                  SELECT @nTolerancePercentage =
                                                CASE
                                                   WHEN SKU.SUSR4 IS NOT NULL AND IsNumeric( SKU.SUSR4) = 1
                                                   THEN CAST( SKU.SUSR4 AS INT)
                                                   ELSE 0
                                                END
                  FROM SKU WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   Sku = @cSKU

                  IF @nTolerancePercentage > 0
                  BEGIN
                     IF (@nQtyAdjust + @nSUMBeforeReceivedQty) > (@nSUMQtyExpected * (1 + (@nTolerancePercentage * 0.01)))
                     BEGIN
                        SET @nErrNo = 64164
                        SET @cErrMsg = rdt.rdtgetmessage( 64164, @cLangCode, 'DSP') --64164^OvrTolerance
                        GOTO RollBackTran_Step3_UPDUCC
                     END
                  END
               END
            END
            ELSE
            BEGIN
               SET @nErrNo = 64163
               SET @cErrMsg = rdt.rdtgetmessage( 64163, @cLangCode, 'DSP') --'64163^OverReceived'
               GOTO RollBackTran_Step3_UPDUCC
            END
         END

         IF (@nBeforeReceivedQty + @nQtyAdjust) >= 0
         BEGIN
            UPDATE RD WITH (ROWLOCK)
               SET BeforeReceivedQty = BeforeReceivedQty + @nQtyAdjust,
                 TrafficCop = NULL
            FROM dbo.RECEIPTDETAIL RD
            WHERE RD.ReceiptKey = @cReceiptKey
            AND   RD.ReceiptLineNumber = @cReceiptLineNumber
            AND   RD.FinalizeFlag <> 'Y'

            IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
            BEGIN
               SET @nErrNo = 64161
               SET @cErrMsg = rdt.rdtgetmessage( 64161, @cLangCode, 'DSP') --'64161^Upd Rcpt Fail'
               GOTO RollBackTran_Step3_UPDUCC
            END
         END
         ELSE
         BEGIN
            IF @nBeforeReceivedQty > 0
            BEGIN
               UPDATE RD WITH (ROWLOCK)
                  SET BeforeReceivedQty = BeforeReceivedQty - @nBeforeReceivedQty,
                    TrafficCop = NULL
               FROM dbo.RECEIPTDETAIL RD
               WHERE RD.ReceiptKey = @cReceiptKey
               AND   RD.ReceiptLineNumber = @cReceiptLineNumber
               AND   RD.FinalizeFlag <> 'Y'

               IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
               BEGIN
                  SET @nErrNo = 64161
                  SET @cErrMsg = rdt.rdtgetmessage( 64161, @cLangCode, 'DSP') --'64161^Upd Rcpt Fail'
                  GOTO RollBackTran_Step3_UPDUCC
               END
               SET @nQtyAdjust = @nBeforeReceivedQty + @nQtyAdjust
            END

            WHILE @nQtyAdjust > 0
            BEGIN
               SELECT TOP 1
                     @cReceiptLineNumber = RD.ReceiptLineNumber,
                     @nBeforeReceivedQty = RD.BeforeReceivedQty
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               WHERE RD.ReceiptKey = @cReceiptKey
                 AND RD.PoKey = @cPOKey
                 AND RD.POLineNumber = @cPOLineNumber
                 AND RD.FinalizeFlag <> 'Y'
                 AND RD.TOLOC = @cPrevLoc
                 AND RD.TOID  = @cPrevID
                 AND RD.Lottable01 = @cLottable01
                 AND RD.Lottable02 = @cLottable02
                 AND RD.Lottable03 = @cLottable03
                 AND RD.Lottable04 = @dLottable04
                 AND RD.Lottable05 = @dLottable05
                 AND RD.BeforeReceivedQty > 0
                 AND RD.ReceiptLineNumber <> @cReceiptLineNumber

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 64161
                  SET @cErrMsg = rdt.rdtgetmessage( 64161, @cLangCode, 'DSP') --'64161^Upd Rcpt Fail'
                  GOTO RollBackTran_Step3_UPDUCC
               END

               IF (@nBeforeReceivedQty + @nQtyAdjust) >= 0
               BEGIN
                  UPDATE RD WITH (ROWLOCK)
                     SET BeforeReceivedQty = BeforeReceivedQty + @nQtyAdjust,
                         TrafficCop = NULL
                  FROM dbo.RECEIPTDETAIL RD
                  WHERE RD.ReceiptKey = @cReceiptKey
                  AND   RD.ReceiptLineNumber = @cReceiptLineNumber
                  AND   RD.FinalizeFlag <> 'Y'

                  IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
                  BEGIN
                     SET @nErrNo = 64161
                     SET @cErrMsg = rdt.rdtgetmessage( 64161, @cLangCode, 'DSP') --'64161^Upd Rcpt Fail'
                     GOTO RollBackTran_Step3_UPDUCC
                  END

                  BREAK
               END
               ELSE
               IF @nBeforeReceivedQty > 0
               BEGIN
                  UPDATE RD WITH (ROWLOCK)
                  SET BeforeReceivedQty = BeforeReceivedQty - @nBeforeReceivedQty,
                  TrafficCop = NULL
                  FROM dbo.RECEIPTDETAIL RD
                  WHERE RD.ReceiptKey = @cReceiptKey
                  AND   RD.ReceiptLineNumber = @cReceiptLineNumber
                  AND   RD.FinalizeFlag <> 'Y'

                  IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
                  BEGIN
                     SET @nErrNo = 64161
                     SET @cErrMsg = rdt.rdtgetmessage( 64161, @cLangCode, 'DSP') --'64161^Upd Rcpt Fail'
                     GOTO RollBackTran_Step3_UPDUCC
                  END
                  SET @nQtyAdjust = @nBeforeReceivedQty + @nQtyAdjust
               END
            END -- WHILE @nQtyAdjust > 0
         END -- If Before Received Qty < UCC Adjust Qty
      END -- @cUCC_UpdRcptDetQty = '1'

      IF @cUCC_UpdRcptDetQty = '1' AND @nQty = 0
      BEGIN
         DELETE dbo.UCC
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND [Status] IN ('0','1')

         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 64165
            SET @cErrMsg = rdt.rdtgetmessage( 64165, @cLangCode, 'DSP') --64165^Del UCC Fail
            GOTO RollBackTran_Step3_UPDUCC
         END
      END
      ELSE
      BEGIN
         -- Update UCC
         UPDATE dbo.UCC SET
            LOT = @cLOT,
            LOC = @cLOC,
            ID = @cID,
            Status = @cStatus,
            QTY = @nQTY,
            EditDate = GETDATE(),
            EditWho = sUser_sName() + '*'
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC
            AND SKU = @cSKU

         IF @@ERROR <> 0 OR @@ROWCOUNT <> 1
         BEGIN
            SET @nErrNo = 64158
            SET @cErrMsg = rdt.rdtgetmessage( 64158, @cLangCode, 'DSP') --'UPD UCC fail'
            GOTO RollBackTran_Step3_UPDUCC
         END
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletID, @cUCC, @cLOT, @cLOC, @cID, @cSKU, @nQty, @cStatus, @tExtUpdateVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' + 
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cPalletID      NVARCHAR( 20), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @cLOT           NVARCHAR( 10), ' +
               ' @cLOC           NVARCHAR( 10), ' +
               ' @cID            NVARCHAR( 18), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQty           INT,           ' +
               ' @cStatus        NVARCHAR( 1),  ' +               
               ' @tExtUpdateVar  VariableTable READONLY, ' + 
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,  
               @cPalletID, @cUCC, @cLOT, @cLOC, @cID, @cSKU, @nQty, @cStatus, @tExtUpdateVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran_Step3_UPDUCC            
         END
      END

      COMMIT TRAN Step3_UPDUCC
      GOTO Quit_Step3_UPDUCC

      RollBackTran_Step3_UPDUCC:
         ROLLBACK TRAN Step3_UPDUCC -- Only rollback change made here
      Quit_Step3_UPDUCC:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      
      IF @nErrNo <> 0
         GOTO Step_3_Fail

      SELECT @nUCC_Cnt = COUNT(1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC

      IF @nUCC_Cnt = 1
      BEGIN
         -- Prep next screen var
         SET @cUCC = ''
         SET @cOutField01 = ''
           
         -- Go to next screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cSKU = ''
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SELECT @nUCC_Cnt = COUNT(1)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC

      IF @nUCC_Cnt = 1
      BEGIN
         -- Go to prev screen
         SET @nScn  = @nScn - 2
         SET @nStep = @nStep - 2
         SET @cUCC = ''
         SET @cOutField01 = ''
      END
      ELSE
      BEGIN
         -- Go to prev screen
         SET @nScn  = @nScn - 1
         SET @nStep = @nStep - 1
         SET @cSKU = ''
         SET @cOutField02 = ''
      END
   END
   GOTO Quit

   Step_3_Fail:
END
GOTO Quit

/********************************************************************************  
Step 5. Scn = 3490. Dynamic lottables  
   Label01    (field01)  
   Lottable01 (field02, input)  
   Label02    (field03)  
   Lottable02 (field04, input)  
   Label03    (field05)  
   Lottable03 (field06, input)  
   Label04    (field07)  
   Lottable04 (field08, input)  
   Label05    (field09)  
   Lottable05 (field10, input)  
********************************************************************************/  
Step_4:  
BEGIN  
   IF @nInputKey = 1 -- Yes or Send  
   BEGIN  
      -- Dynamic lottable  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1,   
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
         @cReceiptKey,  
         @nFunc  
  
      IF @nErrNo <> 0  
         GOTO Quit  
  
      IF @nMorePage = 1 -- Yes  
         GOTO Quit  
  
      -- Enable field  
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5  
      SET @cFieldAttr04 = ''  
      SET @cFieldAttr06 = ''  
      SET @cFieldAttr08 = ''  
      SET @cFieldAttr10 = ''  

      -- Get UCC info
      SELECT TOP 1
         @cLOT = LOT,
         @cLOC = LOC,
         @cID = ID,
         @cStatus = Status,
         @nQTY = QTY
      FROM dbo.UCC (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
         AND SKU = @cSKU
      ORDER BY 1

         -- Prep next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cLOT
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cID
      SET @cOutField05 = @cStatus
      SET @cOutField06 = CAST( @nQTY AS NVARCHAR( 5))
      SET @cOutField07 = @cSKU
      EXEC rdt.rdtSetFocusField @nMobile, 6

      -- Go to next screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN  
      -- Dynamic lottable  
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,   
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
         @cReceiptKey,  
         @nFunc  
  
      IF @nMorePage = 1 -- Yes  
         GOTO Quit  
  
      -- Enable field  
      SET @cFieldAttr02 = '' -- Dynamic lottable 1..5  
      SET @cFieldAttr04 = '' --  
      SET @cFieldAttr06 = '' --  
      SET @cFieldAttr08 = '' --  
      SET @cFieldAttr10 = '' --  

      IF @nMultiSKUUCC = 0
      BEGIN
         -- Load prev screen var  
         SET @cOutField01 = @cPalletID  
         SET @cOutField02 = @cUCC

         -- Go back to prev screen  
         SET @nScn = @nFromScn  
         SET @nStep = @nStep - 3  
      END
      ELSE
      BEGIN
         -- Prep next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = '' -- SKU
            
         -- Go to next screen
         SET @nScn  = @nScn -2
         SET @nStep = @nStep -2
      END
   END  
   GOTO Quit  
  
   Step_4_Fail:  
  
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
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,

      V_UCC     = @cUCC,
      V_SKU     = @cSKU,
      
      V_String1 = @cPalletID,
      V_String2 = @cExtendedValidateSP,
      V_String3 = @cExtendedUpdateSP,
      V_String4 = @cLottableCode,
      
      V_Integer1 = @nFromScn,
      V_Integer2 = @nMultiSKUUCC,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END

GO