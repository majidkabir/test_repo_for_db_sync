SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdtfnc_PrePalletizeSort                             */    
/* Copyright      : MAERSK                                              */    
/*                                                                      */    
/* Purpose: Pre palletize sorting                                       */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Rev  Author   Purposes                                  */    
/* 2020-01-23   1.0  James    WMS11430. Created                         */    
/* 2020-08-26   1.1  CheeMun  INC1250618-Delete UCC if from Step_Qty SCN*/    
/* 2021-04-06   1.2  James    WMS-16725 UCC can be receiptdetail        */    
/*                            userdefine01 (james01)                    */    
/*                            Add default to id value                   */    
/*                            Add flow thru to id screen                */    
/* 2021-05-06   1.3  YeeKung  INC1491514 change fromscn and fromstep to */    
/*                            V_integer (yeekung01)                     */    
/* 2021-08-12   1.4  Chermain WMS-17254 Add Config back to Step10 (cc01)*/  
/* 2021-10-20   1.5  Chermain WMS-18096 Add decode SKU at st7           */  
/*                            Add ExtValidate SP in st4                 */  
/*                            Add ClsPltCond config for st4 (cc02)      */  
/* 2022-03-03   1.6  James    Addhoc fix remove use of variable         */  
/*                            @cNewUCCWithMultiSKU (james02)            */  
/* 2023-02-02   1.7  James    WMS-21588 Bug fix on extendedinfo(james03)*/
/* 2023-01-18   1.8  James    WMS-22995 Allow create new ucc with multi */
/*                            sku (james04)                             */
/* 2023-08-16   1.9  James    WMS-23334 Add UCC format check (james05)  */
/* 2023-10-27   2.0  James    WMS-23878 Add packinfo entry (james06)    */
/* 2024-11-06   2.1.0 XLL045  FCR-1066  Add cPosition                   */
/*                            Check UserDefine02 in UCC                 */
/*                            Upd beforereceivedqty                     */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdtfnc_PrePalletizeSort] (    
   @nMobile    int,    
   @nErrNo     int  OUTPUT,    
   @cErrMsg    NVARCHAR(125) OUTPUT    
) AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- RDT.RDTMobRec variable    
DECLARE    
   @nFunc       INT,    
   @nScn        INT,    
   @nStep       INT,    
   @nAfterStep  INT,    
   @cLangCode   NVARCHAR( 3),    
   @nInputKey   INT,    
   @nMenu       INT,    
   @nMorePage   INT,    
   @bSuccess    INT,    
   @nTranCount  INT,    
   @nFromScn    INT,        --INC1250618    
   @nFromStep   INT,        --INC1250618    
    
   @cStorerKey  NVARCHAR( 15),    
   @cFacility   NVARCHAR( 5),    
   @cUserName           NVARCHAR( 18),    
   @cSKU                NVARCHAR( 20),    
   @cSKUDesc            NVARCHAR( 60),    
   @cUOM                NVARCHAR( 10),    
   @nQty                INT,    
   @cQTY                NVARCHAR( 10),    
   @cSQL                NVARCHAR( MAX),     
   @cSQLParam           NVARCHAR( MAX),     
    
   @cPrePltGetPosSP     NVARCHAR( 20),    
   @cReceiptKey         NVARCHAR( 10),    
   @cPOKey              NVARCHAR( 10),    
   @cLane               NVARCHAR( 10),    
   @cUCC                NVARCHAR( 20),     
   @cToID               NVARCHAR( 18),    
   @cSuggID             NVARCHAR( 18),    
   @cChkFacility        NVARCHAR( 5),     
   @cChkStorerKey       NVARCHAR( 15),    
   @cChkReceiptKey      NVARCHAR( 10),    
   @cReceiptStatus      NVARCHAR( 10),    
   @cUCCStatus          NVARCHAR( 10),    
   @cPosition           NVARCHAR( 20),    
   @cRecordCount        NVARCHAR( 20),    
   @cReceiveDefaultToLoc   NVARCHAR( 20),    
   @cExtendedInfo       NVARCHAR( 20),    
   @cExtendedInfoSP     NVARCHAR( 20),    
   @cExtendedValidateSP NVARCHAR( 20),    
   @cExtendedUpdateSP   NVARCHAR( 20),
   @cReceiveonUCCScan  NVARCHAR( 20),    
   @tExtValidVar        VariableTable,    
   @tExtUpdateVar       VariableTable,    
   @tExtInfoVar         VariableTable,          
   @cPalletizeAllowAddNewUCC  NVARCHAR( 1),    
   @cAllowOverrideSuggID      NVARCHAR( 20),    
   @cOption             NVARCHAR( 1),    
   @cLottableCode   NVARCHAR( 30),    
   @cDisableQTYField    NVARCHAR( 1),    
   @cMultiSKUBarcode    NVARCHAR( 1),          
   @cVerifySKU          NVARCHAR( 1),          
   @cCheckSKUInASN      NVARCHAR( 1),         
   @cActSKU             NVARCHAR( 20),    
   @cUCCWithDynamicCaseCnt NVARCHAR(10),    
   @nCaseCntQty         INT = 0,    
   @cClosePallet        NVARCHAR( 1),    
   @cPositionInUsed     NVARCHAR( 20),    
   @cUCCPosition        NVARCHAR( 20),    
   @cLaneInUsed         NVARCHAR( 10),    
   @cGoToEndSort        NVARCHAR( 1),     --(cc01)  
   @cRetainAsn          NVARCHAR( 1),     --(cc01)  
   @nFromToID           INT,              --(cc01)  
   @cDecodeSP           NVARCHAR( 20),    --(cc02)  
   @cSKUBarcode         NVARCHAR( 60),    --(cc02)  
   @cSkipQtyScn         NVARCHAR( 1),     --(cc02)  
   @cNewUCCWithMultiSKU NVARCHAR( 1),     --(cc02)  
   @cUPC                NVARCHAR( 30),    --(cc02)  
   @cUserDefine01       NVARCHAR( 60),    --(cc02)  
   @cUserDefine02       NVARCHAR( 60),    --(cc02)  
   @cUserDefine03       NVARCHAR( 60),    --(cc02)  
   @cUserDefine04       NVARCHAR( 60),    --(cc02)  
   @cUserDefine05       NVARCHAR( 60),    --(cc02)  
   @cClsPltCond         NVARCHAR( 1),     --(cc02)  
   @cCond               NVARCHAR( 10),    --(cc02)  
    
   @cLottable01         NVARCHAR( 18),    
   @cLottable02         NVARCHAR( 18),    
   @cLottable03         NVARCHAR( 18),    
   @dLottable04         DATETIME,    
   @dLottable05         DATETIME,    
   @cLottable06         NVARCHAR( 30),    
   @cLottable07         NVARCHAR( 30),    
   @cLottable08         NVARCHAR( 30),    
   @cLottable09         NVARCHAR( 30),    
   @cLottable10         NVARCHAR( 30),    
   @cLottable11         NVARCHAR( 30),    
   @cLottable12         NVARCHAR( 30),    
   @dLottable13         DATETIME,    
   @dLottable14         DATETIME,    
   @dLottable15         DATETIME,    
    
   @cPreLottable01      NVARCHAR( 18),    
   @cPreLottable02      NVARCHAR( 18),    
   @cPreLottable03      NVARCHAR( 18),    
   @dPreLottable04      DATETIME,    
   @dPreLottable05      DATETIME,    
   @cPreLottable06      NVARCHAR( 30),    
   @cPreLottable07      NVARCHAR( 30),    
   @cPreLottable08      NVARCHAR( 30),    
   @cPreLottable09      NVARCHAR( 30),    
   @cPreLottable10      NVARCHAR( 30),    
   @cPreLottable11      NVARCHAR( 30),    
   @cPreLottable12      NVARCHAR( 30),    
   @dPreLottable13      DATETIME,    
   @dPreLottable14      DATETIME,    
   @dPreLottable15      DATETIME,    
     
   @cUCCNoLookUpSP      NVARCHAR( 20),    
   @cBarcode            NVARCHAR( 60),    
   @cDefaultToId        NVARCHAR( 1),    
   @cFlowThruToIDScn    NVARCHAR( 1),   
   @cAllowUCCMultiSKU   NVARCHAR( 1),
   @tExtUCC             VARIABLETABLE,
   @cCapturePackInfoSP  NVARCHAR( 20),
   @cPackInfo           NVARCHAR( 10),
   @cCartonType         NVARCHAR( 10),
   @cCube               NVARCHAR( 10),
   @cWeight             NVARCHAR( 10),
   @cRefNo              NVARCHAR( 20),
   @cDefaultCartonType  NVARCHAR( 20),
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),    
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),    
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),    
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),    
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),    
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),    
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),    
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),    
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),    
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),    
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),    
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),    
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),    
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),    
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)    
    
-- Getting Mobile information    
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
    
   @cReceiptKey = V_ReceiptKey,    
   @cPOKey      = V_POKey,    
   @cLane       = V_LOC,    
   @cToID       = V_ID,    
   @cUCC        = V_UCC,    
   @cSKU        = V_SKU,    
   @cSKUDesc    = V_SKUDescr,    
   @nQTY        = V_QTY,    
   @cUOM        = V_UOM,    
    
   @nCaseCntQty = V_Integer1,    
   @nFromScn    = V_Integer2,       --INC1250618 (yeekung01)    
   @nFromStep   = V_Integer3,       --INC1250618 (yeekung01)    
   @nFromToID   = V_Integer4,       --(cc01)  
   @nAfterStep  = V_Integer5,       --(cc02)  
     
   @nFromScn    = V_FromScn,    
   @nFromStep   = V_FromStep,    
          
   @cLottable01   = V_Lottable01,    
   @cLottable02   = V_Lottable02,    
   @cLottable03   = V_Lottable03,    
   @dLottable04   = V_Lottable04,    
   @dLottable05   = V_Lottable05,    
   @cLottable06   = V_Lottable06,    
   @cLottable07   = V_Lottable07,    
   @cLottable08   = V_Lottable08,    
   @cLottable09   = V_Lottable09,    
   @cLottable10   = V_Lottable10,    
   @cLottable11   = V_Lottable11,    
   @cLottable12   = V_Lottable12,    
   @dLottable13   = V_Lottable13,    
   @dLottable14   = V_Lottable14,    
   @dLottable15   = V_Lottable15,    
       
   @cPreLottable01      = V_String1,    
   @cPreLottable02      = V_String2,    
   @cPreLottable03      = V_String3,    
   @dPreLottable04      = CASE WHEN rdt.rdtIsValidDate( V_String4) = 1 THEN CAST( V_String4 AS DATETIME) ELSE NULL END,    
   @dPreLottable05      = CASE WHEN rdt.rdtIsValidDate( V_String5) = 1 THEN CAST( V_String5 AS DATETIME) ELSE NULL END,    
   @cPreLottable06      = V_String6,    
   @cPreLottable07      = V_String7,    
   @cPreLottable08      = V_String8,    
   @cPreLottable09      = V_String9,    
   @cPreLottable10      = V_String10,    
   @cPreLottable11      = V_String11,    
   @cPreLottable12      = V_String12,    
   @dPreLottable13      = CASE WHEN rdt.rdtIsValidDate( V_String13) = 1 THEN CAST( V_String13 AS DATETIME) ELSE NULL END,    
   @dPreLottable14      = CASE WHEN rdt.rdtIsValidDate( V_String14) = 1 THEN CAST( V_String14 AS DATETIME) ELSE NULL END,    
   @dPreLottable15      = CASE WHEN rdt.rdtIsValidDate( V_String15) = 1 THEN CAST( V_String15 AS DATETIME) ELSE NULL END,    
       
   @cDisableQTYField    = V_String16,    
   @cMultiSKUBarcode    = V_String17,    
   @cVerifySKU          = V_String18,    
   @cCheckSKUInASN      = V_String19,    
   @cPosition           = V_String20,    
    
   @cPrePltGetPosSP        = V_String21,    
   @cReceiveDefaultToLoc   =  V_String22,    
   @cExtendedInfoSP        =  V_String23,    
   @cExtendedValidateSP    =  V_String24,    
   @cExtendedUpdateSP      =  V_String25,    
   @cPalletizeAllowAddNewUCC =  V_String26,    
   @cSuggID                = V_String27,    
   @cAllowOverrideSuggID   = V_String28,    
   @cLottableCode          = V_String29,    
   @cGoToEndSort           = V_String30,        --(cc01)  
   @cRetainAsn             = V_String31,        --(cc01)  
   @cDecodeSP              = V_String32,        --(cc02)  
   @cNewUCCWithMultiSKU    = V_String33,        --(cc02)  
   @cClsPltCond            = V_String34,        --(cc02)  
   @cCond                  = V_String35,        --(cc02)  
   @cUCCNoLookUpSP         = V_String36,
   @cDefaultToId           = V_String37,
   @cFlowThruToIDScn       = V_String38,
   @cAllowUCCMultiSKU      = V_String39,
   @cCapturePackInfoSP     = V_String40,
   @cPackInfo              = V_String41,
   @cDefaultCartonType     = V_String42,
   @cReceiveonUCCScan  = V_String43,
   
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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15    
  
FROM rdt.RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    
    
-- Screen constant    
DECLARE    
   @nStep_ASNLane          INT,  @nScn_ASNLane        INT,    
   @nStep_UCC              INT,  @nScn_UCC            INT,    
   @nStep_TOID             INT,  @nScn_TOID           INT,    
   @nStep_ClosePallet      INT,  @nScn_ClosePallet    INT,    
   @nStep_CreateUCC        INT,  @nScn_CreateUCC      INT,    
   @nStep_PreLottable      INT,  @nScn_PreLottable    INT,    
   @nStep_SKU              INT,  @nScn_SKU            INT,    
   @nStep_Qty              INT,  @nScn_Qty            INT,    
   @nStep_OverridePallet   INT,  @nScn_OverridePallet INT,    
   @nStep_EndSort          INT,  @nScn_EndSort        INT,    
   @nStep_Msg              INT,  @nScn_Msg            INT,    
   @nStep_VerifySKU        INT,  @nScn_VerifySKU      INT,    
   @nStep_MultiSKU         INT,  @nScn_MultiSKU       INT,
   @nStep_PackInfo         INT,  @nScn_PackInfo       INT
    
SELECT    
   @nStep_ASNLane        = 1,    @nScn_ASNLane        = 5660,    
   @nStep_UCC            = 2,    @nScn_UCC            = 5661,    
   @nStep_TOID           = 3,    @nScn_TOID           = 5662,    
   @nStep_ClosePallet    = 4,    @nScn_ClosePallet    = 5663,    
   @nStep_CreateUCC      = 5,    @nScn_CreateUCC      = 5664,    
   @nStep_PreLottable    = 6,    @nScn_PreLottable    = 3990,          
   @nStep_SKU            = 7,    @nScn_SKU            = 5665,    
   @nStep_Qty            = 8,    @nScn_Qty            = 5666,    
   @nStep_OverridePallet = 9,    @nScn_OverridePallet = 5667,    
   @nStep_EndSort        = 10,   @nScn_EndSort        = 5668,    
   @nStep_Msg            = 11,   @nScn_Msg            = 5669,    
   @nStep_VerifySKU      = 12,   @nScn_VerifySKU      = 3951,          
   @nStep_MultiSKU       = 13,   @nScn_MultiSKU       = 3570,
   @nStep_PackInfo       = 14,   @nScn_PackInfo       = 6310
       
    
IF @nFunc = 1841 -- Pre Palletize Sort     
BEGIN    
   -- Redirect to respective screen    
   IF @nStep = 0 GOTO Step_0           -- Func = Inquiry SKU    
   IF @nStep = 1 GOTO Step_ASNLane     -- Scn = 5660. ASN, LANE    
   IF @nStep = 2 GOTO Step_UCC         -- Scn = 5661. UCC    
   IF @nStep = 3 GOTO Step_TOID        -- Scn = 5662. TO ID    
   IF @nStep = 4 GOTO Step_ClosePallet -- Scn = 5663. CLOSE PALLET    
   IF @nStep = 5 GOTO Step_CreateUCC   -- Scn = 5664. CREATE UCC    
   IF @nStep = 6 GOTO Step_PreLottable -- Scn = 3990. PRE LOTTABLE    
   IF @nStep = 7 GOTO Step_SKU         -- Scn = 5665. SKU    
   IF @nStep = 8 GOTO Step_Qty         -- Scn = 5666. QTY    
   IF @nStep = 9 GOTO Step_OverridePallet -- Scn = 5667. Override pallet    
   IF @nStep = 10 GOTO Step_EndSort    -- Scn = 5668. End Sort    
   IF @nStep = 11 GOTO Step_Msg        -- Scn = 5669. Msg    
   IF @nStep = 14 GOTO Step_PackInfo   -- Scn = 6310. PackInfo    
END    
    
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. func = 1825. Menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Initialize value    
   SET @cReceiptKey = ''    
   SET @cLane = ''    
   SET @cOption = ''    
   SET @cNewUCCWithMultiSKU = '0'  --(cc02)  
   SET @cSuggID = '' --(cc02)  
    
   SET @cPrePltGetPosSP = rdt.RDTGetConfig( @nFunc, 'PrePltGetPosSP', @cStorerkey)    
   IF @cPrePltGetPosSP IN ('0', '')    
      SET @cPrePltGetPosSP = ''    
    
   -- Get receive DefaultToLoc    
   SET @cReceiveDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)    
   IF @cReceiveDefaultToLoc IN ('', '0')    
      SET @cReceiveDefaultToLoc = ''    
    
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)    
   IF @cExtendedInfoSP IN ('0', '')    
      SET @cExtendedInfoSP = ''    
    
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)    
   IF @cExtendedValidateSP IN ('0', '')    
      SET @cExtendedValidateSP = ''    
    
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)    
   IF @cExtendedUpdateSP IN ('0', '')    
      SET @cExtendedUpdateSP = ''    

   SET @cReceiveonUCCScan = rdt.RDTGetConfig( @nFunc, 'ReceiveonUCCScan', @cStorerKey)
   IF @cReceiveonUCCScan IN ('0', '')
      SET @cReceiveonUCCScan = ''   
    
   SET @cPalletizeAllowAddNewUCC = rdt.RDTGetConfig( @nFunc, 'PalletizeAllowAddNewUCC', @cStorerkey)    
   SET @cAllowOverrideSuggID = rdt.RDTGetConfig( @nFunc, 'AllowOverrideSuggID', @cStorerkey)    
   SET @cDisableQTYField = rdt.RDTGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)    
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorerKey)    
   SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorerKey)    
   SET @cCheckSKUInASN = rdt.RDTGetConfig( @nFunc, 'CheckSKUInASN', @cStorerKey)     
   SET @cGoToEndSort = rdt.RDTGetConfig( @nFunc, 'GoToEndSort', @cStorerKey) --(cc01)  
   SET @cRetainAsn = rdt.RDTGetConfig( @nFunc, 'RetainAsn', @cStorerKey) --(cc01)  
     
   SET @cClsPltCond = rdt.RDTGetConfig( @nFunc, 'ClsPltCond', @cStorerKey) --(cc02)  
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)      --(cc02)  
   IF @cDecodeSP = '0'        
      SET @cDecodeSP = ''   

   SET @cUCCNoLookUpSP = rdt.RDTGetConfig( @nFunc, 'UCCNoLookUpSP', @cStorerkey)
   IF @cUCCNoLookUpSP IN ('0', '')
      SET @cUCCNoLookUpSP = ''

   SET @cDefaultToId = rdt.RDTGetConfig( @nFunc, 'DefaultToId', @cStorerkey)
   SET @cFlowThruToIDScn = rdt.RDTGetConfig( @nFunc, 'FlowThruToIDScn', @cStorerkey)

   SET @cAllowUCCMultiSKU = rdt.RDTGetConfig( @nFunc, 'AllowUCCMultiSKU', @cStorerkey)

   SET @cCapturePackInfoSP = rdt.RDTGetConfig( @nFunc, 'CapturePackInfoSP', @cStorerKey)
   IF @cCapturePackInfoSP = '0'
      SET @cCapturePackInfoSP = ''

   SET @cDefaultCartonType=rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
   IF @cDefaultCartonType = '0'
      SET @cDefaultCartonType = ''

   -- Prep next screen var    
   SET @cOutField01 = '' -- ASN    
   SET @cOutField02 = RTRIM( @cReceiveDefaultToLoc) -- Lane    
    
   SET @nScn = @nScn_ASNLane    
   SET @nStep = @nStep_ASNLane    
    
   -- EventLog    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign-in    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerKey,    
      @nStep       = @nStep    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Scn = 5660    
   ASN      (field01, input)       
   LANE     (field02, input)    
********************************************************************************/    
Step_ASNLane:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Screen mapping    
      SET @cReceiptKey = @cInField01    
      SET @cLane = @cInField02    
      SET @cOption = @cInField03    
    
      IF ISNULL( @cReceiptKey, '') = ''     
      BEGIN    
         SET @nErrNo = 147701    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN    
         GOTO Step_ASNLane1_Fail    
      END    
    
      IF ISNULL( @cOption, '') <> ''    
      BEGIN    
         IF @cOption <> '1'    
         BEGIN    
            SET @nErrNo = 112406    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option    
            SET @cOutField03 = ''    
            GOTO Quit    
         END    
    
         SET @cOutField01 = ''    
    
         SET @nScn = @nScn_EndSort    
         SET @nStep = @nStep_EndSort    
             
         GOTO Quit    
         /*    
         --SET @cFieldAttr02 = ''    
         --SET @cFieldAttr04 = ''    
         --SET @cFieldAttr06 = ''    
         --SET @cFieldAttr08 = ''    
         --SET @cFieldAttr10 = ''    
    
         --SET @nScn = @nScn + 3    
         --SET @nStep = @nStep + 3    
    
         */    
      END    
          
      IF ISNULL( @cLane, '') = ''    
      BEGIN    
         SET @nErrNo = 147702    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane    
         GOTO Step_ASNLane2_Fail    
      END    
    
      IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)    
                      WHERE ReceiptKey = @cReceiptKey    
                      AND   ToLoc = @cLane)    
      BEGIN    
         SET @nErrNo = 147732    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lane    
         GOTO Step_ASNLane2_Fail    
      END    
          
      -- Get the ASN info    
      SELECT    
         @cChkFacility = Facility,    
         @cChkStorerKey = StorerKey,    
         @cChkReceiptKey = ReceiptKey,    
         @cReceiptStatus = ASNStatus,    
         @cPOKey = POKey    
      FROM dbo.Receipt WITH (NOLOCK)    
      WHERE ReceiptKey = @cReceiptKey    
    
      IF @@ROWCOUNT = 0    
      BEGIN    
         SET @nErrNo = 147703    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN not exists    
         GOTO Step_ASNLane1_Fail    
      END    
    
      -- Validate ASN in different facility    
      IF @cFacility <> @cChkFacility    
      BEGIN    
         SET @nErrNo = 147704    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility    
         GOTO Step_ASNLane1_Fail    
      END    
    
      -- Validate ASN belong to the storer    
      IF @cStorerKey <> @cChkStorerKey    
      BEGIN    
         SET @nErrNo = 147705    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff storer    
         GOTO Step_ASNLane1_Fail    
      END    
    
      -- Validate ASN status    
      IF @cReceiptStatus = '9'    
      BEGIN    
         SET @nErrNo = 147706    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN is closed    
         GOTO Step_ASNLane1_Fail    
      END    
    
      -- Get the Lane info    
      SELECT @cChkFacility = Facility    
      FROM dbo.LOC WITH (NOLOCK)     
      WHERE LOC = @cLane    
    
      IF @@ROWCOUNT = 0    
      BEGIN    
         SET @nErrNo = 147707    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Lane    
         GOTO Step_ASNLane2_Fail    
      END    
    
      -- Validate ASN in different facility    
      IF @cFacility <> @cChkFacility    
      BEGIN    
         SET @nErrNo = 147708    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff facility    
         GOTO Step_ASNLane2_Fail    
      END    

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1),  ' +
               ' @cPosition      NVARCHAR( 20), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_UCC_Fail
         END
      END
      
      SET @cUCC = ''    
    
      -- Prep next screen var    
      SET @cOutField01 = @cReceiptKey    
      SET @cOutField02 = @cLane    
      SET @cOutField03 = ''    
      SET @cOutField15 = ''

      -- Goto UCC screen    
      SET @nScn  = @nScn_UCC    
      SET @nStep = @nStep_UCC    
   END    
    
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
      -- EventLog    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign-Out    
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
      SET @cOutField01 = ''    
   END    
   GOTO Quit    
    
   Step_ASNLane1_Fail:    
   BEGIN    
      -- Reset this screen var    
      SET @cReceiptKey = ''    
      SET @cOutField01 = ''    
      SET @cOutField02 = @cLane    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
   END    
   GOTO Quit    
    
   Step_ASNLane2_Fail:    
   BEGIN    
      -- Reset this screen var    
      SET @cLane = ''    
      SET @cOutField01 = @cReceiptKey    
      SET @cOutField02 = ''    
      EXEC rdt.rdtSetFocusField @nMobile, 2    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Scn = 5661.     
   ASN         (field01)    
   LANE        (field02)    
   UCC         (field03, input)    
********************************************************************************/    
Step_UCC:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Screen mapping    
      SET @cUCC = @cInField03    
      SET @cBarcode = @cInField03
      
      IF ISNULL( @cUCC, '') = ''    
      BEGIN    
         SET @nErrNo = 147709    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC required    
         GOTO Step_UCC_Fail    
      END    

      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cUCC) = 0  
      BEGIN  
         SET @nErrNo = 147735  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format  
         GOTO Step_UCC_Fail  
      END 

      -- Lookup field is SP
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cUCCNoLookUpSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cUCCNoLookUpSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cLane, @cBarcode, ' +
            ' @cUCCNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile       INT,           ' +
            '@nFunc         INT,           ' +
            '@cLangCode     NVARCHAR( 3),  ' +
            '@nStep         INT,           ' +
            '@nInputKey     INT,           ' +
            '@cFacility     NVARCHAR( 5),  ' +
            '@cStorerKey    NVARCHAR( 15), ' +
            '@cReceiptKey   NVARCHAR( 10), ' +
            '@cLane         NVARCHAR( 10), ' +
            '@cBarcode      NVARCHAR( 60), ' +
            '@cUCCNo        NVARCHAR( 20) OUTPUT, ' +
            '@nErrNo        INT           OUTPUT, ' +
            '@cErrMsg       NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cLane, @cBarcode,
            @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END
      ELSE
      BEGIN
         SELECT @cUCCStatus = [Status],
                @cSKU   = SKU
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC

         IF @@ROWCOUNT = 0
         BEGIN
            IF @cPalletizeAllowAddNewUCC <> '1'
            BEGIN
               SET @nErrNo = 147710
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Not Exists
               GOTO Step_UCC_Fail
            END
            ELSE
            BEGIN
               SET @cOutField01 = ''

               -- Goto create new ucc screen
               SET @nScn  = @nScn_CreateUCC
               SET @nStep = @nStep_CreateUCC

               GOTO Quit
            END
         END

         IF @cUCCStatus <> '0'
         BEGIN
            SET @nErrNo = 147711
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC Received
            GOTO Step_UCC_Fail
         END
      END
    
      -- Extended validate    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar, ' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nAfterStep     INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cFacility      NVARCHAR( 5),  ' +     
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cReceiptKey    NVARCHAR( 10), ' +    
               ' @cLane          NVARCHAR( 10), ' +    
               ' @cUCC           NVARCHAR( 20), ' +    
               ' @cToID          NVARCHAR( 18), ' +    
               ' @cSKU           NVARCHAR( 20), ' +    
               ' @nQty           INT,           ' +    
               ' @cOption        NVARCHAR( 1),  ' +                   
               ' @cPosition      NVARCHAR( 20), ' +    
               ' @tExtValidVar   VariableTable READONLY, ' +     
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,      
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Step_UCC_Fail                
         END    
      END    
    
      SET @nErrNo = 0    
      SET @cSuggID = ''    
      EXEC [RDT].[rdt_PrePalletizeSort]     
         @nMobile       = @nMobile,    
         @nFunc         = @nFunc,     
         @cLangCode     = @cLangCode,    
         @nStep         = @nStep,     
         @nInputKey     = @nInputKey,     
         @cStorerKey    = @cStorerKey,     
         @cFacility     = @cFacility,     
         @cReceiptKey   = @cReceiptKey,     
         @cLane         = @cLane,     
         @cUCC          = @cUCC,      
         @cSKU          = @cSKU,    
         @cType         = 'GET.POS',      
         @cCreateUCC    = '0',           
         @cLottable01   = NULL,          
         @cLottable02   = NULL,          
         @cLottable03   = NULL,          
         @dLottable04   = NULL,               
         @dLottable05   = NULL,               
         @cLottable06   = NULL,          
         @cLottable07   = NULL,          
         @cLottable08   = NULL,          
         @cLottable09   = NULL,          
         @cLottable10   = NULL,          
         @cLottable11   = NULL,          
         @cLottable12   = NULL,          
         @dLottable13   = NULL,               
         @dLottable14   = NULL,               
         @dLottable15   = NULL,               
         @cPosition     = @cPosition      OUTPUT,       
         @cToID         = @cSuggID        OUTPUT,      
         @cClosePallet  = @cClosePallet   OUTPUT,    
         @nErrNo        = @nErrNo         OUTPUT,     
         @cErrMsg       = @cErrMsg        OUTPUT     
    
      IF @nErrNo <> 0    
         GOTO Step_UCC_Fail    
    
     IF @cExtendedInfoSP <> '' AND     
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cExtendedInfo = ''    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +         
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
              ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar, ' +    
              ' @cExtendedInfo OUTPUT '             
         SET @cSQLParam =        
            ' @nMobile        INT,           ' +    
            ' @nFunc          INT,           ' +    
            ' @cLangCode      NVARCHAR( 3),  ' +    
            ' @nStep          INT,           ' +    
            ' @nAfterStep     INT,           ' +    
            ' @nInputKey      INT,           ' +    
            ' @cFacility      NVARCHAR( 5),  ' +     
            ' @cStorerKey     NVARCHAR( 15), ' +    
            ' @cReceiptKey    NVARCHAR( 10), ' +    
            ' @cLane          NVARCHAR( 10), ' +    
            ' @cUCC           NVARCHAR( 20), ' +    
            ' @cToID          NVARCHAR( 18), ' +    
            ' @cSKU           NVARCHAR( 20), ' +    
            ' @nQty           INT,           ' +    
            ' @cOption        NVARCHAR( 1),  ' +                   
            ' @cPosition      NVARCHAR( 20), ' +    
            ' @tExtInfoVar    VariableTable READONLY, ' +     
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT    '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,    
            @cReceiptKey, @cLane, @cUCC, @cSuggID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar,    
            @cExtendedInfo OUTPUT     
      END    
          
      -- EventLog --(cc01)    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '4',    
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerKey,    
         @nStep       = @nStep,    
         @cUCC        = @cUCC,    
         @cReceiptKey = @cReceiptKey,    
         @cLane       = @cLane       

      -- Custom PackInfo field setup
      SET @cPackInfo = ''
      IF @cCapturePackInfoSP <> ''
      BEGIN
         -- Custom SP to get PackInfo setup
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cCapturePackInfoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cCapturePackInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cLane, @cUCC, @cSKU, ' +
               ' @nErrNo      OUTPUT, ' +
               ' @cErrMsg     OUTPUT, ' +
               ' @cPackInfo   OUTPUT, ' +
               ' @cWeight     OUTPUT, ' +
               ' @cCube       OUTPUT, ' +
               ' @cRefNo      OUTPUT, ' +
               ' @cCartonType OUTPUT'
            SET @cSQLParam =
               '@nMobile     INT,           ' +
               '@nFunc       INT,           ' +
               '@cLangCode   NVARCHAR( 3),  ' +
               '@nStep       INT,           ' +
               '@nInputKey   INT,           ' +
               '@cFacility   NVARCHAR( 5),  ' +
               '@cStorerKey  NVARCHAR( 15), ' +
               '@cReceiptKey NVARCHAR( 10), ' +
               '@cLane       NVARCHAR( 10), ' +
               '@cUCC        NVARCHAR( 20), ' +
               '@cSKU        NVARCHAR( 20), ' +
               '@nErrNo      INT           OUTPUT, ' +
               '@cErrMsg     NVARCHAR( 20) OUTPUT, ' +
               '@cPackInfo   NVARCHAR( 3)  OUTPUT, ' +
               '@cWeight     NVARCHAR( 10) OUTPUT, ' +
               '@cCube       NVARCHAR( 10) OUTPUT, ' +
               '@cRefNo      NVARCHAR( 20) OUTPUT, ' +
               '@cCartonType NVARCHAR( 10) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cReceiptKey, @cLane, @cUCC, @cSKU,
               @nErrNo      OUTPUT,
               @cErrMsg     OUTPUT,
               @cPackInfo   OUTPUT,
               @cWeight     OUTPUT,
               @cCube       OUTPUT,
               @cRefNo      OUTPUT,
               @cCartonType OUTPUT
         END
         ELSE
            -- Setup is non SP
            SET @cPackInfo = @cCapturePackInfoSP
      END

      -- Capture pack info
      IF @cPackInfo <> ''
      BEGIN
         SET @nScn = @nScn_PackInfo
         SET @nStep = @nStep_PackInfo
         -- Get PackInfo
         SET @cCartonType = ''
         SET @cWeight = ''
         SET @cCube = ''
         SET @cRefNo = ''

         -- Prepare LOC screen var
         SET @cOutField01 = CASE WHEN ISNULL(@cCartonType ,'') ='' AND ISNULL(@cDefaultCartonType,'')<>''  THEN @cDefaultCartonType ELSE @cCartonType end
         SET @cOutField02 = @cWeight
         SET @cOutField03 = @cCube
         SET @cOutField04 = @cRefNo

         -- Enable disable field
         SET @cFieldAttr01 = CASE WHEN CHARINDEX( 'T', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr02 = CASE WHEN CHARINDEX( 'C', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr03 = CASE WHEN CHARINDEX( 'W', @cPackInfo) = 0 THEN 'O' ELSE '' END
         SET @cFieldAttr04 = CASE WHEN CHARINDEX( 'R', @cPackInfo) = 0 THEN 'O' ELSE '' END
 
         -- Position cursor
         IF @cFieldAttr01 = '' AND @cOutField01 = ''  EXEC rdt.rdtSetFocusField @nMobile, 1 ELSE
         IF @cFieldAttr02 = '' AND @cOutField02 = '0' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr03 = '' AND @cOutField03 = '0' EXEC rdt.rdtSetFocusField @nMobile, 3 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = ''  EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE 

         -- Go to next screen
         SET @nScn = @nScn_PackInfo
         SET @nStep = @nStep_PackInfo

         GOTO Quit
      END
             
      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cPosition    
      SET @cOutField03 = @cSuggID    
      SET @cOutField04 = CASE WHEN @cDefaultToId = '1' THEN @cSuggID ELSE '' END
      SET @cOutField15 = @cExtendedInfo    
    
      -- Goto TOID screen    
      SET @nScn  = @nScn_TOID    
      SET @nStep = @nStep_TOID    

      IF @cFlowThruToIDScn = '1'
         GOTO Step_TOID
   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
    IF @cRetainAsn <> '1' --(cc01)  
    BEGIN  
     SET @cReceiptKey = ''  
     SET @cOutField01 = '' -- ASN  
    END  
    ELSE  
    BEGIN  
     SET @cOutField01 = @cReceiptKey  
    END  
    
      -- Prep prev screen var     
      SET @cLane = @cReceiveDefaultToLoc    
      SET @cUCC = ''    
    
      SET @cOutField02 = @cLane    
    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
          
      SET @nScn  = @nScn_ASNLane    
      SET @nStep = @nStep_ASNLane    
   END    
   GOTO Quit    
    
   Step_UCC_Fail:    
   BEGIN    
      SET @cUCC = ''    
      SET @cOutField03 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 3. Scn = 5662. TO ID    
   UCC         (field01)    
   POSITION    (field02)    
   TO ID       (field03, input)    
********************************************************************************/    
Step_TOID:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send       
   BEGIN    
      -- Screen mapping    
      SET @cSuggID = ISNULL( @cOutField03, '')    
      SET @cToID = @cInField04    
    
      IF ISNULL( @cToID, '') = ''    
      BEGIN    
         SET @nErrNo = 147712    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOID required    
         GOTO Step_TOID_Fail    
      END    
    
      -- Check barcode format          
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'TOID', @cToID) = 0          
      BEGIN          
         SET @nErrNo = 147713          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format          
         GOTO Step_TOID_Fail          
      END      
    
      -- Get current pallet id position    
      SELECT TOP 1 @cPositionInUsed = Position,     
                   @cLaneInUsed = Loc    
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)    
      WHERE ID = @cToID    
      AND   Status = '1'    
      ORDER BY 1    
          
      -- Get current ucc assign position    
      SELECT TOP 1 @cUCCPosition = Position    
      FROM rdt.rdtPreReceiveSort WITH (NOLOCK)    
      WHERE ReceiptKey = @cReceiptKey    
      AND   UCCNo = @cUCC    
      AND   Status = '1'    
      ORDER BY 1    
      /*
      -- Check if To id already in used in other position    
      IF ISNULL( @cPositionInUsed, '') <> '' AND ( @cUCCPosition <> @cPositionInUsed)    
      BEGIN          
         SET @nErrNo = 147733          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToID in used          
         GOTO Step_TOID_Fail          
      END      
      */    
      IF ISNULL( @cPositionInUsed, '') <> '' AND ( @cLane <> @cLaneInUsed)    
      BEGIN          
         SET @nErrNo = 147734          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Diff Lane          
         GOTO Step_TOID_Fail          
      END      
          
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1),  ' +
               ' @cPosition      NVARCHAR( 20), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_TOID_Fail
         END
      END
      
      IF @cSuggID <> '' AND ( @cSuggID <> @cToID)    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @cAllowOverrideSuggID AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cAllowOverrideSuggID) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, ' +     
               ' @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, @cSuggID, @cToID, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cStorerkey      NVARCHAR( 15), ' +    
               '@cFacility       NVARCHAR( 5),  ' +    
               '@cReceiptKey     NVARCHAR( 20), ' +    
               '@cLane           NVARCHAR( 10), ' +    
               '@cUCC            NVARCHAR( 20), ' +     
               '@cSKU            NVARCHAR( 20), ' +     
               '@cSuggID         NVARCHAR( 18), ' +      
               '@cToID           NVARCHAR( 18), ' +      
               '@nErrNo          INT            OUTPUT, ' +    
              '@cErrMsg         NVARCHAR( 20)  OUTPUT  '     
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey,     
               @cFacility, @cReceiptKey, @cLane, @cUCC, @cSKU, @cSuggID, @cToID,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo NOT IN (0, -1)    
               GOTO Step_TOID_Fail    
         END    
         ELSE    
         BEGIN    
            IF @cAllowOverrideSuggID = '1'    
               SET @nErrNo = -1    
            ELSE    
            BEGIN    
               SET @nErrNo = 147714          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PltID NotMatch           
               GOTO Step_TOID_Fail          
            END    
         END    
             
         IF @nErrNo IN ( 0, -1)    
         BEGIN    
            -- Prep next screen var    
            SET @cOutField01 = ''    
                
            SET @nScn  = @nScn_OverridePallet    
            SET @nStep = @nStep_OverridePallet    
            GOTO Quit    
         END    
      END    
    
      SET @nErrNo = 0    
      EXEC [RDT].[rdt_PrePalletizeSort]     
         @nMobile       = @nMobile,    
         @nFunc         = @nFunc,     
         @cLangCode     = @cLangCode,    
         @nStep         = @nStep,     
         @nInputKey     = @nInputKey,     
         @cStorerKey    = @cStorerKey,     
         @cFacility     = @cFacility,     
         @cReceiptKey   = @cReceiptKey,     
         @cLane         = @cLane,     
         @cUCC          = @cUCC,      
         @cSKU          = @cSKU,    
         @cType         = 'UPD.ID',      
         @cCreateUCC    = '0',           
         @cLottable01   = NULL,          
         @cLottable02   = NULL,          
         @cLottable03   = NULL,          
         @dLottable04   = NULL,               
         @dLottable05   = NULL,               
         @cLottable06   = NULL,          
         @cLottable07   = NULL,          
         @cLottable08   = NULL,          
         @cLottable09   = NULL,          
         @cLottable10   = NULL,          
         @cLottable11   = NULL,          
         @cLottable12   = NULL,          
         @dLottable13   = NULL,               
         @dLottable14   = NULL,               
         @dLottable15   = NULL,               
         @cPosition     = @cPosition      OUTPUT,       
         @cToID         = @cToID          OUTPUT,       
         @cClosePallet  = @cClosePallet   OUTPUT,    
         @nErrNo        = @nErrNo         OUTPUT,     
         @cErrMsg       = @cErrMsg        OUTPUT     
    
      IF @nErrNo <> 0    
         GOTO Step_TOID_Fail    
      
      -- Extended validate    
      IF @cExtendedUpdateSP <> ''    
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtUpdateVar, ' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nAfterStep     INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cFacility      NVARCHAR( 5),  ' +     
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cReceiptKey    NVARCHAR( 10), ' +    
               ' @cLane          NVARCHAR( 10), ' +    
               ' @cUCC           NVARCHAR( 20), ' +    
               ' @cToID          NVARCHAR( 18), ' +    
               ' @cSKU           NVARCHAR( 20), ' +    
               ' @nQty           INT,           ' +    
               ' @cOption        NVARCHAR( 1),  ' +                   
               ' @cPosition      NVARCHAR( 20), ' +    
               ' @tExtUpdateVar  VariableTable READONLY, ' +     
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
         
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,      
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtUpdateVar,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
         
            IF @nErrNo <> 0    
            BEGIN     
               GOTO Step_TOID_Fail    
            END                
         END    
         
      END

      IF @cClosePallet = '1'    
      BEGIN    
       --(cc02)  
       IF @cClsPltCond = '1'  
       BEGIN  
        SET @cFieldAttr03 = ''  
       END  
       ELSE  
       BEGIN  
        SET @cFieldAttr03 = 'O'  
       END   
          
         -- Prep next screen var    
         SET @cOutField01 = ''    
         SET @cOutField02 = @cToID  
         SET @cOutField03 = '' --Cond    --(cc02)  
         SET @nFromToID = 1  
    
         SET @nScn  = @nScn_ClosePallet    
         SET @nStep = @nStep_ClosePallet    
         SET @nAfterStep = @nStep_ClosePallet
      END    
      ELSE    
      BEGIN    
         SET @cUCC = ''    
    
         -- Prep next screen var    
         SET @cOutField01 = @cReceiptKey    
         SET @cOutField02 = @cLane    
         SET @cOutField03 = ''    
    
         -- Goto UCC screen    
         SET @nScn  = @nScn_UCC    
         SET @nStep = @nStep_UCC                
         SET @nAfterStep = @nStep_UCC
      END    

     IF @cExtendedInfoSP <> '' AND
         EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cExtendedInfo = ''
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
              ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
              ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar, ' +
              ' @cExtendedInfo OUTPUT '
         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @cReceiptKey    NVARCHAR( 10), ' +
            ' @cLane          NVARCHAR( 10), ' +
            ' @cUCC           NVARCHAR( 20), ' +
            ' @cToID          NVARCHAR( 18), ' +
            ' @cSKU           NVARCHAR( 20), ' +
            ' @nQty           INT,           ' +
            ' @cOption        NVARCHAR( 1),  ' +
            ' @cPosition      NVARCHAR( 20), ' +
            ' @tExtInfoVar    VariableTable READONLY, ' +
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT    '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep_TOID, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
            @cReceiptKey, @cLane, @cUCC, @cSuggID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar,
            @cExtendedInfo OUTPUT

            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
      END
   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
      SET @nErrNo = 0    
          
      --INC1250618 (START)    
      IF (@nFromScn = 5666 AND @nFromStep = 8)    
      BEGIN    
         IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNO = @cUCC AND STORERKEY = @cStorerKey AND STATUS = '0')    
         BEGIN    
            DELETE FROM UCC WHERE UCCNO = @cUCC AND STORERKEY = @cStorerKey AND STATUS = '0'    
        END    
             
         SET @nFromScn = ''    
         SET @nFromStep = ''    
      END    
      --INC1250618 (END)    
          
      EXEC [RDT].[rdt_PrePalletizeSort]     
         @nMobile       = @nMobile,    
         @nFunc         = @nFunc,     
         @cLangCode     = @cLangCode,    
         @nStep         = @nStep,     
         @nInputKey     = @nInputKey,     
         @cStorerKey    = @cStorerKey,     
         @cFacility     = @cFacility,     
         @cReceiptKey   = @cReceiptKey,     
         @cLane         = @cLane,     
         @cUCC          = @cUCC,      
         @cSKU          = @cSKU,    
         @cType         = 'DEL.UCC',      
         @cCreateUCC    = '0',           
         @cLottable01   = NULL,          
         @cLottable02   = NULL,          
         @cLottable03   = NULL,          
         @dLottable04   = NULL,               
         @dLottable05   = NULL,               
         @cLottable06   = NULL,          
         @cLottable07   = NULL,          
         @cLottable08   = NULL,          
         @cLottable09   = NULL,          
         @cLottable10   = NULL,          
         @cLottable11   = NULL,          
         @cLottable12   = NULL,          
         @dLottable13   = NULL,               
         @dLottable14   = NULL,               
         @dLottable15   = NULL,               
         @cPosition     = @cPosition      OUTPUT,       
         @cToID         = @cToID          OUTPUT,       
         @cClosePallet  = @cClosePallet   OUTPUT,    
         @nErrNo        = @nErrNo         OUTPUT,     
         @cErrMsg       = @cErrMsg        OUTPUT     
    
      IF @nErrNo <> 0    
         GOTO Step_TOID_Fail    
    
      SET @cUCC = ''    
    
      -- Prep next screen var    
      SET @cOutField01 = @cReceiptKey    
      SET @cOutField02 = @cLane    
      SET @cOutField03 = ''    
                
      SET @nScn  = @nScn_UCC    
      SET @nStep = @nStep_UCC    
   END    
   GOTO Quit    
    
   Step_TOID_Fail:    
   BEGIN    
      SET @cTOID = ''    
      SET @cOutField03 = @cSuggID    
      SET @cOutField04 = ''    
          
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 4. Scn = 5663. CLOSE PALLET    
   OPTION       (field01, input)  
   PalletID     (field02)  
   Cond         (field03, input)        
********************************************************************************/    
Step_ClosePallet:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Screen mapping          
      SET @cOption = @cInField01  
      SET @cCond   = @cInField03            
    
      -- Check invalid option          
      IF @cOption = ''          
      BEGIN          
         SET @nErrNo = 147730          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Required    
         GOTO Step_ClosePallet_Fail          
      END      
        
      -- Check invalid option          
      IF @cOption NOT IN ('1', '2')          
      BEGIN          
         SET @nErrNo = 147731          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option          
         GOTO Step_ClosePallet_Fail          
      END    
          
      -- Extended validate  --(cc02)  
      INSERT INTO @tExtValidVar (Variable, Value) VALUES   
      ('@cCond',       @cCond)  
        
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar, ' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nAfterStep     INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cFacility      NVARCHAR( 5),  ' +     
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cReceiptKey    NVARCHAR( 10), ' +    
               ' @cLane          NVARCHAR( 10), ' +    
               ' @cUCC           NVARCHAR( 20), ' +    
               ' @cToID          NVARCHAR( 18), ' +    
               ' @cSKU           NVARCHAR( 20), ' +    
               ' @nQty           INT,           ' +    
               ' @cOption        NVARCHAR( 1),  ' +                   
               ' @cPosition      NVARCHAR( 20), ' +    
               ' @tExtValidVar   VariableTable READONLY, ' +     
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,      
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Step_UCC_Fail                
         END    
      END    
          
      IF @cOption = '1'    
      BEGIN    
         SET @nErrNo = 0    
         EXEC [RDT].[rdt_PrePalletizeSort_ClosePallet]     
            @nMobile       = @nMobile,    
            @nFunc         = @nFunc,     
            @cLangCode     = @cLangCode,    
            @nStep         = @nStep,     
            @nInputKey     = @nInputKey,     
            @cStorerKey    = @cStorerKey,     
            @cFacility     = @cFacility,     
            @cReceiptKey   = @cReceiptKey,     
            @cLane         = @cLane,     
            @cPosition     = @cPosition,       
            @cToID         = @cToID,       
            @nErrNo        = @nErrNo         OUTPUT,     
            @cErrMsg       = @cErrMsg        OUTPUT     
                
         IF @nErrNo <> 0    
            GOTO Step_ClosePallet_Fail     

         SET @cOutField01 = ''    
         SET @cOutField02 = 'PA TASK CREATED'    
                
         SET @nScn  = @nScn_Msg    
         SET @nStep = @nStep_Msg    
         GOTO Quit    
      END    
      ELSE    
      BEGIN    
         SET @cUCC = ''    
    
         -- Prep next screen var    
         SET @cOutField01 = @cReceiptKey    
         SET @cOutField02 = @cLane    
         SET @cOutField03 = ''    
    
         -- Goto UCC screen    
         SET @nScn  = @nScn_UCC    
         SET @nStep = @nStep_UCC     
         GOTO Quit    
      END    

   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
      SET @cUCC = ''    
    
      -- Prep next screen var    
      SET @cOutField01 = @cReceiptKey    
      SET @cOutField02 = @cLane    
      SET @cOutField03 = ''    
    
      -- Goto UCC screen    
      SET @nScn  = @nScn_UCC    
      SET @nStep = @nStep_UCC     
   END    
   GOTO Quit    
    
   Step_ClosePallet_Fail:    
   BEGIN    
      SET @cOption = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 5. Scn = 5664. CREATE UCC    
   OPTION       (field01, input)    
********************************************************************************/    
Step_CreateUCC:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Screen mapping          
      SET @cOption = @cInField01          
    
      -- Check invalid option          
      IF @cOption = ''          
      BEGIN          
         SET @nErrNo = 147717          
         SET @cErrMsg = rdt.rdtgetmessage( 64289, @cLangCode, 'DSP') --Option Required    
         GOTO Step_CreateUCC_Fail          
      END      
          
      -- Check invalid option          
      IF @cOption NOT IN ('1', '2')          
      BEGIN          
         SET @nErrNo = 147718          
         SET @cErrMsg = rdt.rdtgetmessage( 64289, @cLangCode, 'DSP') --Invalid option          
         GOTO Step_CreateUCC_Fail          
      END          
          
      IF @cOption = '1'    
      BEGIN    
         -- Reset data    
         SELECT @cSKU = '', @nQTY = 0,    
            @cLottable01 = '', @cLottable02 = '', @cLottable03 = '',    @dLottable04 = NULL, @dLottable05 = NULL,    
            @cLottable06 = '', @cLottable07 = '', @cLottable08 = '',    @cLottable09 = '',   @cLottable10 = '',    
            @cLottable11 = '', @cLottable12 = '', @dLottable13 = NULL,  @dLottable14 = NULL, @dLottable15 = NULL,     
    
            @cPreLottable01 = '', @cPreLottable02 = '', @cPreLottable03 = '',   @dPreLottable04 = NULL, @dPreLottable05 = NULL,    
            @cPreLottable06 = '', @cPreLottable07 = '', @cPreLottable08 = '',   @cPreLottable09 = '',   @cPreLottable10 = '',    
            @cPreLottable11 = '', @cPreLottable12 = '', @dPreLottable13 = NULL, @dPreLottable14 = NULL, @dPreLottable15 = NULL    
    
         -- Dynamic lottable (PRE at storer level)    
         SET @cSKU = ''    
         SET @cLottableCode = ''    
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'POPULATE', 5, 1,    
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,    
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,    
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,    
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,    
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,    
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,    
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,    
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,    
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,    
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,    
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,    
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,    
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,    
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,    
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,    
            @nMorePage   OUTPUT,    
            @nErrNo      OUTPUT,    
            @cErrMsg     OUTPUT,    
            @cReceiptKey,    
            @nFunc    
    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         IF @nMorePage = 1 -- Yes    
         BEGIN    
            -- Go to dynamic lottable screen    
            SET @nScn = @nScn_PreLottable    
            SET @nStep = @nStep_PreLottable    
    
            GOTO Quit    
         END    
             
         -- Goto SKU screen    
         SET @cOutField01 = @cUCC  
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''      
         SET @cOutField06 = ''   -- SKU    
         SET @cOutField07 = ''   -- QTY  
           
         SET @nAfterStep = @nStep --(cc02)    
         SET @nScn = @nScn_SKU    
         SET @nStep = @nStep_SKU    
           
         GOTO Quit    
      END    
      ELSE    
      BEGIN    
         SET @cUCC = ''    
             
         SET @cOutField01 = @cReceiptKey    
         SET @cOutField02 = @cLane    
         SET @cOutField03 = ''    
    
         -- Goto UCC screen    
         SET @nScn  = @nScn_UCC    
         SET @nStep = @nStep_UCC      
         GOTO Quit           
      END    
    
   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cPosition    
      SET @cOutField03 = @cSuggID    
      SET @cOutField15 = @cExtendedInfo    
    
      SET @nScn  = @nScn_TOID    
      SET @nStep = @nStep_TOID    
   END    
   GOTO Quit    
    
   Step_CreateUCC_Fail:    
   BEGIN    
      SET @cOption = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 6. Scn = 3990. Pre lottables    
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
Step_PreLottable:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Dynamic lottable    
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'CHECK', 5, 1,    
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,    
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,    
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,    
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,    
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,    
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,    
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,    
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,    
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,    
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,    
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,    
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,    
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,    
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,    
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,    
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
    
      -- Copy to actual lottable    
      SET @cLottable01 = @cPreLottable01    
      SET @cLottable02 = @cPreLottable02    
      SET @cLottable03 = @cPreLottable03    
      SET @dLottable04 = @dPreLottable04    
      SET @dLottable05 = @dPreLottable05    
      SET @cLottable06 = @cPreLottable06    
      SET @cLottable07 = @cPreLottable07    
      SET @cLottable08 = @cPreLottable08    
      SET @cLottable09 = @cPreLottable09    
      SET @cLottable10 = @cPreLottable10    
      SET @cLottable11 = @cPreLottable11    
      SET @cLottable12 = @cPreLottable12    
      SET @dLottable13 = @dPreLottable13    
      SET @dLottable14 = @dPreLottable14    
      SET @dLottable15 = @dPreLottable15    
          
      -- Goto SKU screen    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cInField01    
      SET @cOutField03 = @cInField04    
      SET @cOutField04 = @cInField06    
      SET @cOutField05 = @cInField08    
      SET @cOutField06 = ''   -- SKU    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''
      SET @cOutField09 = ''
      SET @cOutField10 = ''   -- Qty
      SET @cOutField15 = ''
      
      SET @nQTY = 0

      SET @nAfterStep = @nStep           --(cc02)  
      SET @nScn = @nScn_SKU    
      SET @nStep = @nStep_SKU    
        
      GOTO Quit    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Dynamic lottable    
      SET @cSKU = ''    
      SET @cLottableCode = ''    
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorerKey, @cSKU, @cLottableCode, 'PRECAPTURE', 'POPULATE', 5, 1,    
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cPreLottable01 OUTPUT,    
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cPreLottable02 OUTPUT,    
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cPreLottable03 OUTPUT,    
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dPreLottable04 OUTPUT,    
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dPreLottable05 OUTPUT,    
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cPreLottable06 OUTPUT,    
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cPreLottable07 OUTPUT,    
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cPreLottable08 OUTPUT,    
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cPreLottable09 OUTPUT,    
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cPreLottable10 OUTPUT,    
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cPreLottable11 OUTPUT,    
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cPreLottable12 OUTPUT,    
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dPreLottable13 OUTPUT,    
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dPreLottable14 OUTPUT,    
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dPreLottable15 OUTPUT,    
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
    
      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cPosition    
      SET @cOutField03 = @cSuggID    
      SET @cOutField15 = @cExtendedInfo    
    
      SET @nScn  = @nScn_TOID    
      SET @nStep = @nStep_TOID    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 7. Scn = 5665. SKU    
   UCC         (field01)    
   LOTTABLEnn  (field02)    
   LOTTABLEnn  (field03)    
   LOTTABLEnn  (field04)    
   LOTTABLEnn  (field05)    
   SKU         (field06, input)    
********************************************************************************/    
Step_SKU:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      --Screen mapping    
      SET @cActSku = @cInField06    
      SET @cSKUBarcode = @cInField06   --(cc02)  
    
      --check if sku is null    
      IF @cActSku = ''    
      BEGIN    
         IF @cDisableQTYField = '0' OR (@cDisableQTYField = '1' AND @nQTY = 0)    
         BEGIN             
            SET @nErrNo = 147719    
            SET @cErrMsg = rdt.rdtgetmessage(63143, @cLangCode, 'DSP') --SKU required    
            GOTO Step_SKU_Fail    
         END    
      END    
        
      -- Decode  --(cc02)       
      IF @cDecodeSP <> ''        
      BEGIN              
         -- Standard decode        
         IF @cDecodeSP = '1'        
         BEGIN        
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cSKUBarcode,         
               @cToID      OUTPUT, @cUPC        OUTPUT, @nQTY        OUTPUT,         
               @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @dLottable05 OUTPUT,        
               @cLottable06 OUTPUT, @cLottable07 OUTPUT, @cLottable08 OUTPUT, @cLottable09 OUTPUT, @cLottable10 OUTPUT,        
               @cLottable11 OUTPUT, @cLottable12 OUTPUT, @dLottable13 OUTPUT, @dLottable14 OUTPUT, @dLottable15 OUTPUT,        
               @cUserDefine01 OUTPUT, @cUserDefine02 OUTPUT, @cUserDefine03 OUTPUT, @cUserDefine04 OUTPUT, @cUserDefine05 OUTPUT,          
               @cType   = 'UPC'          
         END        
                 
         -- Customize decode        
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cSKUBarcode, @cReceiptKey, @cLane, @cUCC, ' +     
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05, ' +    
               ' @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, ' +        
               ' @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15, ' +       
               ' @cSkipQtyScn OUTPUT, @cToID  OUTPUT, @cSKU  OUTPUT, @nQTY  OUTPUT, @nErrNo   OUTPUT, @cErrMsg  OUTPUT '       
                                
            SET @cSQLParam =        
               ' @nMobile      INT,             ' +        
               ' @nFunc        INT,             ' +        
               ' @cLangCode    NVARCHAR( 3),    ' +        
               ' @nStep        INT,             ' +       
               ' @nAfterStep   INT,             ' +       
               ' @nInputKey    INT,             ' +      
               ' @cFacility    NVARCHAR( 5),    ' +       
               ' @cStorerKey   NVARCHAR( 15),   ' +      
               ' @cSKUBarcode  NVARCHAR( 60),   ' +    
               ' @cReceiptKey  NVARCHAR( 10),   ' +     
               ' @cLane        NVARCHAR( 10),   ' +    
               ' @cUCC         NVARCHAR( 20),   ' +    
               ' @cLottable01  NVARCHAR( 18),   ' +      
               ' @cLottable02  NVARCHAR( 18),   ' +      
               ' @cLottable03  NVARCHAR( 18),   ' +      
               ' @dLottable04  DATETIME,        ' +      
               ' @dLottable05  DATETIME,        ' +    
               ' @cLottable06  NVARCHAR( 30),   ' +      
               ' @cLottable07  NVARCHAR( 30),   ' +      
               ' @cLottable08  NVARCHAR( 30),   ' +      
               ' @cLottable09  NVARCHAR( 30),   ' +      
               ' @cLottable10  NVARCHAR( 30),   ' +      
               ' @cLottable11  NVARCHAR( 30),   ' +      
               ' @cLottable12  NVARCHAR( 30),   ' +      
               ' @dLottable13  DATETIME,        ' +      
               ' @dLottable14  DATETIME,        ' +      
               ' @dLottable15  DATETIME,        ' +          
               ' @cSkipQtyScn  Nvarchar( 1)   OUTPUT, ' +  
               ' @cToID        NVARCHAR( 18)  OUTPUT, ' +        
               ' @cSKU         NVARCHAR( 20)  OUTPUT, ' +        
               ' @nQTY         INT            OUTPUT, ' +             
               ' @nErrNo       INT            OUTPUT, ' +        
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,        
               @cSKUBarcode, @cReceiptKey, @cLane, @cUCC,        
               @cLottable01, @cLottable02, @cLottable03, @dLottable04, @dLottable05,  
               @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10,       
               @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15,  
               @cSkipQtyScn OUTPUT, @cToID  OUTPUT, @cSKU  OUTPUT, @nQTY  OUTPUT, @nErrNo   OUTPUT, @cErrMsg  OUTPUT    
        
            IF @nErrNo <> 0        
               GOTO Step_SKU_Fail        
                       
            IF @cSKU <> ''        
               SET @cActSku = @cSKU      
         END         
      END      
         
      -- Get SKU/UPC    
      DECLARE @nSKUCnt INT    
      SET @nSKUCnt = 0    
    
      EXEC RDT.rdt_GETSKUCNT    
            @cStorerKey  = @cStorerKey    
         ,@cSKU        = @cActSku    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @bSuccess      OUTPUT    
         ,@nErr        = @nErrNo        OUTPUT    
         ,@cErrMsg     = @cErrMsg       OUTPUT    
    
      -- Validate SKU/UPC    
      IF @nSKUCnt = 0    
      BEGIN    
         SET @nErrNo = 147720    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
         GOTO Step_SKU_Fail    
      END    
    
      IF @nSKUCnt = 1    
         EXEC [RDT].[rdt_GETSKU]    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cActSku       OUTPUT    
            ,@bSuccess    = @bSuccess      OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
    
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
               @cActSku  OUTPUT,    
               @nErrNo   OUTPUT,    
               @cErrMsg  OUTPUT,    
               'ASN',    -- DocType    
               @cReceiptKey    
    
            IF @nErrNo = 0 -- Populate multi SKU screen    
            BEGIN    
               -- Go to Multi SKU screen    
               SET @nScn = @nScn_MultiSKU    
               SET @nStep = @nStep_MultiSKU    
               GOTO Quit    
            END    
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen    
               SET @nErrNo = 0    
         END    
         ELSE    
         BEGIN    
            SET @nErrNo = 147721    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod    
            GOTO Step_SKU_Fail    
         END    
      END    
    
      -- Check SKU in ASN    
      IF @cCheckSKUInASN = '1'    
      BEGIN    
         IF NOT EXISTS( SELECT 1    
            FROM dbo.Receiptdetail WITH (NOLOCK)    
            WHERE Receiptkey = @cReceiptKey    
               AND StorerKey = @cStorerKey    
               AND SKU = @cActSku)    
         BEGIN    
            SET @nErrNo = 147722    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not in ASN    
            GOTO Step_SKU_Fail    
         END    
      END    
    
      -- Get SKU info    
      SELECT    
         @cSKUDesc = ISNULL( DescR, ''),    
         @cLottableCode = LottableCode,    
         @cUOM = Pack.PackUOM3    
      FROM dbo.SKU SKU WITH (NOLOCK)    
         JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE SKU.StorerKey = @cStorerKey    
         AND SKU.SKU = @cActSku    
             
      IF @cDisableQTYField = '1'
      BEGIN
         -- Check same SKU
         IF @cActSKU <> @cSKU AND @nQTY > 0 AND @cAllowUCCMultiSKU = 0
         BEGIN
            SET @nErrNo = 147723
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Different SKU'
            GOTO Step_SKU_Fail
         END

         EXEC [RDT].[rdt_PrePalletizeSort_UCC] 
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cReceiptKey   = @cReceiptKey,
            @cPOKey        = @cPOKey,
            @cLane         = @cLane,
            @cUCC          = @cUCC,
            @cToID         = @cToID,
            @cSKU          = @cActSKU,
            @nQty          = @nQty,
            @tExtUCC       = @tExtUCC,
            @nErrNo        = @nErrNo   OUTPUT,
            @cErrMsg       = @cErrMsg  OUTPUT

         IF @nErrNo <> 0
            GOTO Step_SKU_Fail
            
         SET @cSKU = @cActSKU

         -- Top up QTY
         SET @nQTY = @nQTY + 1

         -- Prepare current screen var
         SET @cOutField06 = '' -- SKU/UPC
         SET @cOutField07 = @cSKU
         SET @cOutField08 = SUBSTRING( @cSKUDesc,1,20)
         SET @cOutField09 = SUBSTRING( @cSKUDesc,21,20)
         SET @cOutField10 = CAST( @nQTY AS NVARCHAR( 5))

         -- Remain in current screen
         --GOTO Step_SKU_Fail
      END
      ELSE
      BEGIN
         SET @cSKU = @cActSKU

         -- Prep next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cSKU
         SET @cOutField03 = SUBSTRING( @cSKUDesc,1,20)
         SET @cOutField04 = SUBSTRING( @cSKUDesc,21,20)
         SET @cOutField05 = ''   -- Qty

         SET @nScn  = @nScn_Qty
         SET @nStep = @nStep_Qty
      END
             
      SET @cSKU = @cActSKU    
             
      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cSKU    
      SET @cOutField03 = SUBSTRING( @cSKUDesc,1,20)    
      SET @cOutField04 = SUBSTRING( @cSKUDesc,21,20)    
      SET @cOutField05 = ''   -- Qty    
      SET @cOutField07 = @nQTY   
    
      SET @nScn  = @nScn_Qty    
      SET @nStep = @nStep_Qty             
  
   END    
       
   IF @nInputKey = 0 -- Esc or No
   BEGIN
   	-- If it is piece scanning and already scanned something
   	-- goto to id screen
   	IF @nQty > 0 AND @cDisableQTYField = '1'
   	BEGIN
         SET @nErrNo = 0
         EXEC [RDT].[rdt_PrePalletizeSort]
            @nMobile       = @nMobile,
            @nFunc         = @nFunc,
            @cLangCode     = @cLangCode,
            @nStep         = @nStep,
            @nInputKey     = @nInputKey,
            @cStorerKey    = @cStorerKey,
            @cFacility     = @cFacility,
            @cReceiptKey   = @cReceiptKey,
            @cLane         = @cLane,
            @cUCC          = @cUCC,
            @cSKU          = @cSKU,
            @cType         = 'GET.POS',
            @cCreateUCC    = '1',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = @dLottable05,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15,
            @cPosition     = @cPosition      OUTPUT,
            @cToID         = @cSuggID        OUTPUT,
            @cClosePallet  = @cClosePallet   OUTPUT,
            @nErrNo        = @nErrNo         OUTPUT,
            @cErrMsg       = @cErrMsg        OUTPUT

         IF @nErrNo <> 0
            GOTO Step_SKU_Fail

         -- Prep next screen var
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cPosition
         SET @cOutField03 = @cSuggID
         SET @cOutField04 = ''
         SET @cOutField15 = ''

         --INC1250618
         SET @nFromScn  = @nScn_SKU
         SET @nFromStep = @nStep_SKU

         -- Goto TOID screen
         SET @nScn  = @nScn_TOID
         SET @nStep = @nStep_TOID
   	END
   	ELSE
   	BEGIN
         SET @cUCC = ''

         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cLane
         SET @cOutField03 = ''

         -- Goto UCC screen
         SET @nScn  = @nScn_UCC
         SET @nStep = @nStep_UCC
      END
   END

   IF @cExtendedInfoSP <> '' AND
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
   BEGIN
      SET @cExtendedInfo = ''
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar, ' +
            ' @cExtendedInfo OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nAfterStep     INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5),  ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cReceiptKey    NVARCHAR( 10), ' +
         ' @cLane          NVARCHAR( 10), ' +
         ' @cUCC           NVARCHAR( 20), ' +
         ' @cToID          NVARCHAR( 18), ' +
         ' @cSKU           NVARCHAR( 20), ' +
         ' @nQty           INT,           ' +
         ' @cOption        NVARCHAR( 1),  ' +
         ' @cPosition      NVARCHAR( 20), ' +
         ' @tExtInfoVar    VariableTable READONLY, ' +
         ' @cExtendedInfo  NVARCHAR( 20) OUTPUT    '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
         @cReceiptKey, @cLane, @cUCC, @cSuggID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar,
         @cExtendedInfo OUTPUT
         
      IF @cExtendedInfo <> ''
         SET @cOutField15 = @cExtendedInfo
   END
      
   GOTO Quit

   Step_SKU_Fail:
   BEGIN
      SET @cActSKU = ''
      SET @cOutField06 = ''
   END
END    
GOTO Quit    
    
/********************************************************************************    
Step 8. Scn = 5666. QTY    
   UCC         (field01)    
   SKU         (field02)    
   DESCR       (field03)    
   DESCR       (field04)    
   QTY         (field05, input)    
********************************************************************************/    
Step_Qty:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      --screen mapping    
      SET @cQty = @cInField05    
    
      --check if qty is null    
      IF @cQty = '' OR @cQty IS NULL    
      BEGIN    
         SET @nErrNo = 147724    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --QTY required    
         GOTO Step_Qty_Fail    
      END    
    
      --check if qty is valid    
      IF rdt.rdtIsValidQty(@cQty, 1) = 0    
      BEGIN    
         SET @nErrNo = 147725    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Invalid Qty    
         GOTO Step_Qty_Fail    
      END    
      SET @nQTY = CAST( @cQTY AS INT)    
    
      --if UCCWithDynamicCaseCnt is setup = 0, casecnt must equal with qty    
      IF UPPER(@cUCC) <> 'NOUCC'-- no effect on noucc    
      BEGIN    
         SET @cUCCWithDynamicCaseCnt = ''    
         SELECT @cUCCWithDynamicCaseCnt = SValue    
         FROM RDT.StorerConfig WITH (NOLOCK)    
         WHERE StorerKey = @cStorerKey    
            AND ConfigKey = 'UCCWithDynamicCaseCnt'    
         IF ISNULL(@cUCCWithDynamicCaseCnt,'0') = '0' --0=check against Pack.CaseCnt  1=Dynamic case count    
         BEGIN    
            -- Get case count    
            SELECT @nCaseCntQty = Pack.CaseCnt    
               FROM dbo.Sku Sku WITH (NOLOCK)    
               JOIN dbo.Pack Pack WITH (NOLOCK) ON Sku.Packkey = Pack.Packkey    
            WHERE Sku.Storerkey = @cStorerKey    
               AND Sku.sku = @cSku    
    
            --prompt error if @cQty <> @nCaseCntQty    
            IF @nQTY <> @nCaseCntQty    
            BEGIN    
               SET @nErrNo = 147726    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseCnt Diff    
               GOTO Step_Qty_Fail    
            END    
         END    
      END          
    
      -- Handling transaction    
      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN Step_Qty_AddUCC -- For rollback or commit only our own transaction    
        
      EXEC [RDT].[rdt_PrePalletizeSort_UCC] 
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cLane         = @cLane,
         @cUCC          = @cUCC,
         @cToID         = @cToID,
         @cSKU          = @cSKU,
         @nQty          = @nQty,
         @tExtUCC       = @tExtUCC,
         @nErrNo        = @nErrNo   OUTPUT,
         @cErrMsg       = @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN Step_Qty_AddUCC
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Step_QTY_Fail
      END               
        
      -- Extended validate    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtUpdateVar, ' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nAfterStep     INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cFacility      NVARCHAR( 5),  ' +     
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cReceiptKey    NVARCHAR( 10), ' +    
               ' @cLane          NVARCHAR( 10), ' +    
               ' @cUCC           NVARCHAR( 20), ' +    
               ' @cToID          NVARCHAR( 18), ' +    
               ' @cSKU           NVARCHAR( 20), ' +    
               ' @nQty           INT,           ' +    
               ' @cOption        NVARCHAR( 1),  ' +                   
               ' @cPosition      NVARCHAR( 20), ' +    
               ' @tExtUpdateVar  VariableTable READONLY, ' +     
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,      
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtUpdateVar,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               ROLLBACK TRAN Step_Qty_AddUCC    
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                  COMMIT TRAN    
               GOTO Step_QTY_Fail    
            END                
         END    
      END    
    
      COMMIT TRAN Step_Qty_AddUCC    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN     
    
      SET @nErrNo = 0    
      EXEC [RDT].[rdt_PrePalletizeSort]     
         @nMobile       = @nMobile,    
         @nFunc         = @nFunc,     
         @cLangCode     = @cLangCode,    
         @nStep         = @nStep,     
         @nInputKey     = @nInputKey,     
         @cStorerKey    = @cStorerKey,     
         @cFacility     = @cFacility,     
         @cReceiptKey   = @cReceiptKey,     
         @cLane         = @cLane,     
         @cUCC          = @cUCC,      
         @cSKU          = @cSKU,    
         @cType         = 'GET.POS',      
         @cCreateUCC    = '1',           
         @cLottable01   = @cLottable01,          
         @cLottable02   = @cLottable02,          
         @cLottable03   = @cLottable03,          
         @dLottable04   = @dLottable04,               
         @dLottable05   = @dLottable05,               
         @cLottable06   = @cLottable06,          
         @cLottable07   = @cLottable07,          
         @cLottable08   = @cLottable08,          
         @cLottable09   = @cLottable09,          
         @cLottable10   = @cLottable10,          
         @cLottable11   = @cLottable11,          
         @cLottable12   = @cLottable12,          
         @dLottable13   = @dLottable13,               
         @dLottable14   = @dLottable14,               
         @dLottable15   = @dLottable15,               
         @cPosition     = @cPosition      OUTPUT,       
         @cToID         = @cSuggID        OUTPUT,      
         @cClosePallet  = @cClosePallet   OUTPUT,    
         @nErrNo        = @nErrNo         OUTPUT,     
         @cErrMsg       = @cErrMsg        OUTPUT     
    
      IF @nErrNo <> 0    
         GOTO Step_QTY_Fail    
    
      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cPosition    
      SET @cOutField03 = @cSuggID    
      SET @cOutField04 = ''    
      SET @cOutField15 = @cExtendedInfo    
        
      INSERT INTO traceInfo (TRACEname,timein,col1,col2,col3,col4,col5)  
      VALUES('cc',GETDATE(),@cSuggID,@cPosition,@cUCC,@cSKU,@cLane)  
          
      --INC1250618    
      SET @nFromScn  = @nScn_Qty         
      SET @nFromStep = @nStep_Qty     
          
      -- Goto TOID screen    
      SET @nScn  = @nScn_TOID    
      SET @nStep = @nStep_TOID          
   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
      -- Goto SKU screen    
      SET @cOutField01 = @cUCC    
      SET @cOutField06 = ''   -- SKU    
        
      SET @nAfterStep = @nStep   --(cc02)       
      SET @nScn = @nScn_SKU    
      SET @nStep = @nStep_SKU    
        
      GOTO Quit    
   END    
   GOTO Quit    
    
   Step_QTY_Fail:    
   BEGIN    
      SET @cQty = ''    
      SET @cOutField05 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 9. Scn = 5667. OVERRIDE PALLET    
   OPTION       (field01, input)    
********************************************************************************/    
Step_OverridePallet:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Screen mapping          
      SET @cOption = @cInField01          
    
      -- Check invalid option          
      IF @cOption = ''          
      BEGIN          
         SET @nErrNo = 147728          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option Required    
         GOTO Step_OverridePallet_Fail          
      END      
          
      -- Check invalid option          
      IF @cOption NOT IN ('1', '2')          
      BEGIN          
         SET @nErrNo = 147729          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option          
         GOTO Step_OverridePallet_Fail           
      END          
          
      IF @cOption = '1'    
      BEGIN    
         SET @nErrNo = 0    
         EXEC [RDT].[rdt_PrePalletizeSort]     
            @nMobile       = @nMobile,    
            @nFunc         = @nFunc,     
            @cLangCode     = @cLangCode,    
            @nStep         = @nStep,     
            @nInputKey     = @nInputKey,     
            @cStorerKey    = @cStorerKey,     
            @cFacility     = @cFacility,     
            @cReceiptKey   = @cReceiptKey,     
            @cLane         = @cLane,     
            @cUCC          = @cUCC,      
            @cSKU          = @cSKU,    
            @cType         = 'UPD.ID',      
            @cCreateUCC    = '0',           
            @cLottable01   = NULL,          
            @cLottable02   = NULL,          
            @cLottable03   = NULL,          
            @dLottable04   = NULL,               
            @dLottable05   = NULL,               
            @cLottable06   = NULL,          
            @cLottable07   = NULL,          
            @cLottable08   = NULL,          
            @cLottable09   = NULL,          
            @cLottable10   = NULL,          
            @cLottable11   = NULL,          
            @cLottable12   = NULL,          
            @dLottable13   = NULL,               
            @dLottable14   = NULL,               
            @dLottable15   = NULL,               
            @cPosition     = @cPosition      OUTPUT,       
            @cToID         = @cToID          OUTPUT,       
            @cClosePallet  = @cClosePallet   OUTPUT,    
            @nErrNo        = @nErrNo         OUTPUT,     
            @cErrMsg       = @cErrMsg        OUTPUT     
    
         IF @nErrNo <> 0    
            GOTO Step_OverridePallet_Fail    
    
         IF @cClosePallet = '1'    
         BEGIN    
          --(cc02)  
          IF @cClsPltCond = '1'  
          BEGIN  
           SET @cFieldAttr03 = ''  
          END  
          ELSE  
          BEGIN  
           SET @cFieldAttr03 = 'O'  
          END  
         
            -- Prep next screen var    
            SET @cOutField01 = ''    
            SET @cOutField03 = '' --Cond --(cc02)  
            SET @nFromToID = 1  
    
            SET @nScn  = @nScn_ClosePallet    
            SET @nStep = @nStep_ClosePallet    
         END    
         ELSE    
         BEGIN    
            SET @cUCC = ''    
    
            -- Prep next screen var    
            SET @cOutField01 = @cReceiptKey    
            SET @cOutField02 = @cLane    
            SET @cOutField03 = ''    
    
            -- Goto UCC screen    
            SET @nScn  = @nScn_UCC    
            SET @nStep = @nStep_UCC                
         END        
      END    
      ELSE    
      BEGIN    
         SET @cTOID = ''    
             
         -- Prep next screen var    
         SET @cOutField01 = @cUCC    
         SET @cOutField02 = @cPosition    
         SET @cOutField03 = @cSuggID    
         SET @cOutField04 = ''    
         SET @cOutField15 = @cExtendedInfo    
             
         -- Goto TOID screen    
         SET @nScn  = @nScn_TOID    
         SET @nStep = @nStep_TOID           
      END    
    
   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
      SET @cOption = ''    
          
      -- Prep next screen var    
      SET @cOutField01 = ''    
   END    
   GOTO Quit    
    
   Step_OverridePallet_Fail:    
   BEGIN    
      SET @cOption = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 10. Scn = 5668. END SORT    
   TO ID       (field01, input)    
********************************************************************************/    
Step_EndSort:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
      -- Screen mapping          
      SET @cToID = @cInField01          
    
      IF @cToID = ''          
      BEGIN          
         SET @nErrNo = 147715          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOID Required    
         GOTO Step_EndSort_Fail          
      END      
          
      IF @cToID <> '99'      
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK)    
                         WHERE ReceiptKey = @cReceiptKey    
                         AND   ID = @cToID    
                         AND   [Status] = '1')    
         BEGIN    
            SET @nErrNo = 147716    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOID Not Exists    
            GOTO Quit    
         END             
      END    
        
      --(cc02)  
      IF @cClsPltCond = '1'  
      BEGIN  
       SET @cFieldAttr03 = ''  
      END  
      ELSE  
      BEGIN  
       SET @cFieldAttr03 = 'O'  
      END  
    
      -- Prep next screen var    
      SET @cOutField01 = ''    
      SET @cOutField02 = @cToID  
      SET @cOutField03 = '' --Cond --(cc02)      
      SET @nFromToID = 0  
    
      SET @nScn  = @nScn_ClosePallet    
      SET @nStep = @nStep_ClosePallet    
          
      GOTO Quit    
   END    
       
   IF @nInputKey = 0 -- Esc or No    
   BEGIN    
    --  IF @cRetainAsn <> '1' --(cc01)  
    --BEGIN  
    -- SET @cReceiptKey = ''  
    -- SET @cOutField01 = '' -- ASN  
    --END  
    --ELSE  
    --BEGIN  
    -- SET @cOutField01 = @cReceiptKey  
    --END  
      
      -- Initialize value  
      SET @cReceiptKey = ''  
      SET @cLane = ''  
      SET @cOption = ''  
     
      -- Prep next screen var  
      SET @cOutField01 = '' -- ASN  
      SET @cOutField02 = RTRIM( @cReceiveDefaultToLoc) -- Lane  
      SET @cOutField03 = ''  
  
      SET @nScn = @nScn_ASNLane  
      SET @nStep = @nStep_ASNLane  
   END    
   GOTO Quit    
    
   Step_EndSort_Fail:    
   BEGIN    
      SET @cToID = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 11. Scn = 5669. QTY    
   UCC         (field01)    
   SKU         (field02)    
   DESCR       (field03)    
   DESCR       (field04)    
   QTY         (field05, input)    
********************************************************************************/    
Step_Msg:    
BEGIN    
   IF @nInputKey = 1 -- Yes or Send    
   BEGIN    
    --(cc01)  
    IF @cGoToEndSort = '1'  
    BEGIN  
     IF @nFromToID = 1  
     BEGIN  
      -- Prep next screen var    
            SET @cOutField01 = @cReceiptKey    
            SET @cOutField02 = @cLane    
            SET @cOutField03 = ''  
  
            SET @nScn = @nScn_UCC  
            SET @nStep = @nStep_UCC  
            GOTO Quit  
     END  
     ELSE  
     BEGIN  
      SET @cOutField01 = ''  
  
            SET @nScn = @nScn_EndSort  
            SET @nStep = @nStep_EndSort  
            GOTO Quit  
     END  
       
    END  
      
      -- Initialize value    
      SET @cReceiptKey = ''    
      SET @cLane = ''    
      SET @cOption = ''    
       
      -- Prep next screen var    
      SET @cOutField01 = '' -- ASN    
      SET @cOutField02 = RTRIM( @cReceiveDefaultToLoc) -- Lane    
      SET @cOutField03 = ''    
    
      SET @nScn = @nScn_ASNLane    
      SET @nStep = @nStep_ASNLane    
   END    
END    
GOTO Quit    


/********************************************************************************
Scn = 6310. Capture pack info
   Carton Type (field01, input)
   Cube        (field02, input)
   Weight      (field03, input)
   RefNo       (field04, input)
********************************************************************************/
Step_PackInfo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cChkCartonType NVARCHAR( 10)

      -- Screen mapping
      SET @cChkCartonType  = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END
      SET @cWeight         = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END
      SET @cCube           = CASE WHEN @cFieldAttr03 = '' THEN @cInField03 ELSE @cOutField03 END
      SET @cRefNo          = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END

      -- Carton type
      IF @cFieldAttr01 = ''
      BEGIN
         -- Check blank
         IF @cChkCartonType = ''
         BEGIN
            SET @nErrNo = 147736
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Get default cube
         DECLARE @nDefaultCube FLOAT
         SELECT @nDefaultCube = [Cube]
         FROM Cartonization WITH (NOLOCK)
            INNER JOIN Storer WITH (NOLOCK) ON (Storer.CartonGroup = Cartonization.CartonizationGroup)
         WHERE Storer.StorerKey = @cStorerKey
            AND Cartonization.CartonType = @cChkCartonType

         -- Check if valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 147737
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CTN TYPE
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END

         -- Different carton type scanned
         IF @cChkCartonType <> @cCartonType
         BEGIN
            SET @cCartonType = @cChkCartonType
            SET @cCube = rdt.rdtFormatFloat( @nDefaultCube)
            SET @cWeight = ''

            SET @cOutField01 = @cCartonType
            SET @cOutField02 = @cWeight
            SET @cOutField03 = @cCube
         END
      END

      -- Weight
      IF @cFieldAttr02 = ''
      BEGIN
         -- Check blank
         IF @cWeight = ''
         BEGIN
            SET @nErrNo = 147738
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'Weight', @cWeight) = 0
         BEGIN
            SET @nErrNo = 147739
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END

         -- Check weight valid
         SET @nErrNo = rdt.rdtIsValidQty( @cWeight, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 147740
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid weight
            EXEC rdt.rdtSetFocusField @nMobile, 2
            SET @cOutField02 = ''
            GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField02 = @cWeight
      END

      -- Cube
      IF @cFieldAttr03 = ''
      BEGIN
         -- Check blank
         IF @cCube = ''
         BEGIN
            SET @nErrNo = 147741
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END

         -- Check cube valid
         SET @nErrNo = rdt.rdtIsValidQty( @cCube, 21)

         IF @nErrNo = 0
         BEGIN
            SET @nErrNo = 147742
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid cube
            EXEC rdt.rdtSetFocusField @nMobile, 3
            SET @cOutField03 = ''
        GOTO QUIT
         END
         SET @nErrNo = 0
         SET @cOutField03 = @cCube
      END

      -- RefNo    --(cc01)
      IF @cFieldAttr04 = ''
      BEGIN
         -- Check blank
         IF @cRefNo = ''
         BEGIN
            SET @nErrNo = 147743
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need RefNo
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit
         END
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nAfterStep     INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cReceiptKey    NVARCHAR( 10), ' +
               ' @cLane          NVARCHAR( 10), ' +
               ' @cUCC           NVARCHAR( 20), ' +
               ' @cToID          NVARCHAR( 18), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1),  ' +
               ' @cPosition      NVARCHAR( 20), ' +
               ' @tExtValidVar   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT,   ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtValidVar,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN    
      SAVE TRAN rdt_PrePalletizeSort_PackInfo  

      INSERT INTO @tExtUCC (Variable, Value) VALUES ('@cCartonType', @cCartonType)  
      INSERT INTO @tExtUCC (Variable, Value) VALUES ('@cWeight',     @cWeight)
      INSERT INTO @tExtUCC (Variable, Value) VALUES ('@cCube',       @cCube)
      INSERT INTO @tExtUCC (Variable, Value) VALUES ('@cRefNo',      @cRefno)

      EXEC [RDT].[rdt_PrePalletizeSort_UCC] 
         @nMobile       = @nMobile,
         @nFunc         = @nFunc,
         @cLangCode     = @cLangCode,
         @nStep         = @nStep,
         @nInputKey     = @nInputKey,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorerKey,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cLane         = @cLane,
         @cUCC          = @cUCC,
         @cToID         = @cToID,
         @cSKU          = @cActSKU,
         @nQty          = @nQty,
         @tExtUCC       = @tExtUCC,
         @nErrNo        = @nErrNo   OUTPUT,
         @cErrMsg       = @cErrMsg  OUTPUT

      IF @nErrNo <> 0
         GOTO PackInfo_RollBackTran

      -- Extended validate    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +    
               ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtUpdateVar, ' +    
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nAfterStep     INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cFacility      NVARCHAR( 5),  ' +     
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cReceiptKey    NVARCHAR( 10), ' +    
               ' @cLane          NVARCHAR( 10), ' +    
               ' @cUCC           NVARCHAR( 20), ' +    
               ' @cToID          NVARCHAR( 18), ' +    
               ' @cSKU           NVARCHAR( 20), ' +    
               ' @nQty           INT,           ' +    
               ' @cOption        NVARCHAR( 1),  ' +                   
               ' @cPosition      NVARCHAR( 20), ' +    
               ' @tExtUpdateVar  VariableTable READONLY, ' +     
               ' @nErrNo         INT           OUTPUT,   ' +    
               ' @cErrMsg        NVARCHAR( 20) OUTPUT    '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,      
               @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtUpdateVar,    
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN    
               ROLLBACK TRAN Step_Qty_AddUCC    
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
                  COMMIT TRAN    
               GOTO Step_QTY_Fail    
            END                
         END    
      END    

      GOTO PackInfo_Quit

      PackInfo_RollBackTran:
            ROLLBACK TRAN rdt_PrePalletizeSort_PackInfo
      PackInfo_Quit:
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN

      
      --Enable back field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''

      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cPosition    
      SET @cOutField03 = @cSuggID    
      SET @cOutField04 = CASE WHEN @cDefaultToId = '1' THEN @cSuggID ELSE '' END
      SET @cOutField15 = @cExtendedInfo    
    
      -- Goto TOID screen    
      SET @nScn  = @nScn_TOID    
      SET @nStep = @nStep_TOID    

      IF @cFlowThruToIDScn = '1'
         GOTO Step_TOID
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      --Enable back field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''

      -- Prep next screen var    
      SET @cOutField01 = @cUCC    
      SET @cOutField02 = @cPosition    
      SET @cOutField03 = @cSuggID    
      SET @cOutField04 = CASE WHEN @cDefaultToId = '1' THEN @cSuggID ELSE '' END
      SET @cOutField15 = @cExtendedInfo    
    
      -- Goto TOID screen    
      SET @nScn  = @nScn_TOID    
      SET @nStep = @nStep_TOID    

      IF @cFlowThruToIDScn = '1'
         GOTO Step_TOID
   END

   IF @cExtendedInfoSP <> '' AND
      EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
   BEGIN
      SET @cExtendedInfo = ''
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cReceiptKey, @cLane, @cUCC, @cToID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar, ' +
            ' @cExtendedInfo OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nAfterStep     INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5),  ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cReceiptKey    NVARCHAR( 10), ' +
         ' @cLane          NVARCHAR( 10), ' +
         ' @cUCC           NVARCHAR( 20), ' +
         ' @cToID          NVARCHAR( 18), ' +
         ' @cSKU           NVARCHAR( 20), ' +
         ' @nQty           INT,           ' +
         ' @cOption        NVARCHAR( 1),  ' +
         ' @cPosition      NVARCHAR( 20), ' +
         ' @tExtInfoVar    VariableTable READONLY, ' +
         ' @cExtendedInfo  NVARCHAR( 20) OUTPUT    '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep_TOID, @nAfterStep, @nInputKey, @cFacility, @cStorerKey,
         @cReceiptKey, @cLane, @cUCC, @cSuggID, @cSKU, @nQty, @cOption, @cPosition, @tExtInfoVar,
         @cExtendedInfo OUTPUT

         IF @cExtendedInfo <> ''
            SET @cOutField15 = @cExtendedInfo
   END
   GOTO Quit
   
   Step_PackInfo_Quit:

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
      UserName  = @cUserName,    
    
      V_ReceiptKey = @cReceiptKey,    
      V_POKey      = @cPOKey,    
      V_LOC        = @cLane,    
      V_ID         = @cToID,    
      V_UCC        = @cUCC,    
      V_SKU        = @cSKU,    
      V_SKUDescr   = @cSKUDesc,    
      V_QTY        = @nQTY,    
      V_UOM        = @cUOM,    
    
      V_Integer1   = @nCaseCntQty,    
      V_Integer2   = @nFromScn,       --INC1250618 (yeekung01)    
      V_Integer3   = @nFromStep,      --INC1250618 (yeekung01)    
      V_Integer4   = @nFromToID,      --(cc01)  
      V_Integer5   = @nAfterStep,     --(cc02)  
             
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
    
      V_String1    = @cPreLottable01,    
      V_String2    = @cPreLottable02,    
      V_String3    = @cPreLottable03,    
      V_String4    = rdt.rdtFormatDate( @dPreLottable04),    
      V_String5    = rdt.rdtFormatDate( @dPreLottable05),    
      V_String6    = @cPreLottable06,    
      V_String7    = @cPreLottable07,    
      V_String8    = @cPreLottable08,    
      V_String9    = @cPreLottable09,    
      V_String10   = @cPreLottable10,    
      V_String11   = @cPreLottable11,    
      V_String12   = @cPreLottable12,    
      V_String13   = rdt.rdtFormatDate( @dPreLottable13),    
      V_String14   = rdt.rdtFormatDate( @dPreLottable14),    
      V_String15   = rdt.rdtFormatDate( @dPreLottable15),    
    
      V_String16 = @cDisableQTYField,    
      V_String17 = @cMultiSKUBarcode,    
      V_String18 = @cVerifySKU,    
      V_String19 = @cCheckSKUInASN,    
      V_String20 = @cPosition,    
      V_String21 = @cPrePltGetPosSP,    
      V_String22 = @cReceiveDefaultToLoc,    
      V_String23 = @cExtendedInfoSP,    
      V_String24 = @cExtendedValidateSP,    
      V_String25 = @cExtendedUpdateSP,    
      V_String26 = @cPalletizeAllowAddNewUCC,    
      V_String27 = @cSuggID,    
      V_String28 = @cAllowOverrideSuggID,    
      V_String29 = @cLottableCode,    
      V_String30 = @cGoToEndSort,   --(cc01)  
      V_String31 = @cRetainAsn,     --(cc01)  
      V_String32 = @cDecodeSP,      --(cc02)  
      V_String33 = @cNewUCCWithMultiSKU, --(cc02)  
      V_String34 = @cClsPltCond,    --(cc02)  
      V_String35 = @cCond,          --(cc02)  
      V_String36 = @cUCCNoLookUpSP,
      V_String37 = @cDefaultToId,
      V_String38 = @cFlowThruToIDScn,
      V_String39 = @cAllowUCCMultiSKU,
      V_String40 = @cCapturePackInfoSP,
      V_String41 = @cPackInfo,
      V_String42 = @cDefaultCartonType,
      V_String43 = @cReceiveonUCCScan,
   
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