SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Store procedure: rdtfnc_UCCCarton_Receive                            */          
/* Copyright      : IDS                                                 */          
/*                                                                      */          
/* Purpose: UCC Carton Receive with build UCC capability (SOS224115)    */          
/*                                                                      */          
/* Modifications log:                                                   */          
/*                                                                      */          
/* Date       Rev  Author   Purposes                                    */          
/* 2011-09-28 1.0  James    Created                                     */          
/* 2011-10-10 1.1  Shong    Getting SellerName from PO (SHONG001)       */  
/* 2011-10-11 1.2  ChewKP   Add RDT StorerConfig = ReceiptPOKeyByLPN    */    
/*                          (ChewKP01)                                  */    
/* 2011-10-14 1.3  Shong    Add RDT StorerConfig = PalletIDRequired     */  
/*                          (Shong01)                                   */  
/* 2011-10-27 1.4  Shong    Change POKey Lookup Logic (Shong02)         */  
/* 2011-11-04 1.5  James    Fix POKey assigned wrongly problem (james01)*/  
/* 2011-11-06 1.6  James    SOS228479 - Prompt to scan cube/weight if   */  
/*                          it is 0 (james02)                           */  
/* 2011-11-14 1.7  James    Enable UCC Return BY LPN (james02)          */  
/* 2011-12-09 1.8  James    Bug fix. Allow retrieve of Lot02 for same   */  
/*                          SKU different POs        (james03)          */  
/* 2011-12-13 1.9  James    Get the correct receiptlinenumber (james04) */  
/* 2011-12-19 2.0  ChewKP   Get ReceiptLineNumber by nspRFRC01 Outstring*/  
/*                          (ChewKP02)                                  */  
/* 2012-01-12 2.1  James    Change Weight to STDGROSSWGT (james05)      */  
/* 2012-02-01 2.2  ChewKP   Add In POKey filtering for RDT StorerConfig */  
/*                          ReceiptPOKeyByLPN (ChewKP03)                */    
/* 2012-02-08 2.3  Shong    Allow to received UCC with Status = 0       */  
/* 2012-02-15 2.4  James    Bug fix (james06)                           */  
/* 2012-02-22 2.5  James    Not allow to scan SKU=UCC (james07)         */  
/* 2012-03-12 2.6  Shong    Calling GetConfig RDTAddSKUtoASN with Func# */  
/* 2012-03-30 2.7  Shong    Add Record into Receipt Detail with PO Info */  
/* 2016-09-30 2.8  Ung      Performance tuning                          */   
/************************************************************************/          
  
CREATE  PROCEDURE [RDT].[rdtfnc_UCCCarton_Receive] (          
   @nMobile    INT,          
   @nErrNo     INT  OUTPUT,          
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max          
) AS  
SET NOCOUNT ON           
SET QUOTED_IDENTIFIER OFF           
SET ANSI_NULLS OFF          
SET CONCAT_NULL_YIELDS_NULL OFF            
          
-- Misc variable          
DECLARE           
   @cChkFacility NVARCHAR( 5),           
   @b_Success    INT,           
   @n_err        INT,           
   @c_errmsg     NVARCHAR( 250)     
    
          
-- Session variable          
DECLARE          
   @cReceiptKey         NVARCHAR( 10),           
   @cPOKey              NVARCHAR( 10),          
   @cLOC                NVARCHAR( 20),           
   @cSKU                NVARCHAR( 20),           
   @cUOM                NVARCHAR( 10),           
   @cID                 NVARCHAR( 18),           
   @cSKUDesc            NVARCHAR( 60),           
   @cQTY                NVARCHAR( 10),           
   @cReasonCode         NVARCHAR( 10),           
   @cIVAS               NVARCHAR( 20),           
   @cLotLabel01         NVARCHAR( 20),           
   @cLotLabel02         NVARCHAR( 20),           
   @cLotLabel03         NVARCHAR( 20),           
   @cLotLabel04         NVARCHAR( 20),           
   @cLotLabel05         NVARCHAR( 20),           
   @cLottable01         NVARCHAR( 18),           
   @cLottable02         NVARCHAR( 18),           
   @cLottable03         NVARCHAR( 18),           
   @cLottable04         NVARCHAR( 16),           
   @cLottable05         NVARCHAR( 16),           
   @cPackKey            NVARCHAR( 10),           
   @cPOKeyDefaultValue  NVARCHAR( 10),     
   @cAddSKUtoASN        NVARCHAR( 10),     
   @cExternPOKey        NVARCHAR( 20),     
   @cExternReceiptKey   NVARCHAR( 20),     
   @cExternLineNo       NVARCHAR( 20),     
   @cReceiptLineNo      NVARCHAR(  5),  
   @cNewReceiptLineNo   NVARCHAR(  5),     
   @cPrefUOM            NVARCHAR(  1),     
   @cSourcekey          NVARCHAR( 15),     
   @cDefaultLOT03       NVARCHAR( 18),     
   @cActQty             NVARCHAR( 10),    
   @cActSKU             NVARCHAR( 20),    
   @cPrevID             NVARCHAR( 18),    
   @cLPN                NVARCHAR( 20),    
   @cLabelNo            NVARCHAR( 20),    
   @cStyle              NVARCHAR( 20),    
   @cColor              NVARCHAR( 10),    
   @cSize               NVARCHAR( 5),    
   @cPrinter            NVARCHAR( 10),          
   @cLottable01_Code    NVARCHAR( 20),          
   @cLottable02_Code    NVARCHAR( 20),          
   @cLottable03_Code    NVARCHAR( 20),          
   @cLottable04_Code    NVARCHAR( 20),          
   @cLottable05_Code    NVARCHAR( 30),    
   @cLottableLabel      NVARCHAR( 20),          
   @cListName           NVARCHAR( 20),          
   @cShort              NVARCHAR( 10),          
   @cTempReceiptLineNo  NVARCHAR( 5),    
   @cPrevOp             NVARCHAR( 5),          
   @cScnOption          NVARCHAR( 1),          
   @cAutoGenID          NVARCHAR( 1),          
   @cPromptOpScn        NVARCHAR( 1),          
   @cUserName           NVARCHAR( 18),          
   @cCheckPLTID         NVARCHAR( 1),     
   @cPromptVerifyPKScn  NVARCHAR( 1),     
   @cDefaultToLoc       NVARCHAR( 20),      
   @cMultiPOASN         NVARCHAR( 1),       
   @cLOT                NVARCHAR( 10),       
   @c_outstring         NVARCHAR( 250),     
   @cSKUGroup           NVARCHAR( 10),     
   @cItemClass          NVARCHAR( 10),     
   @cSellerName         NVARCHAR( 45),     
   @cVASKey             NVARCHAR( 10),     
   @cVASLineNumber      NVARCHAR(  5),     
   @cVASStep            NVARCHAR( 128),    
   @cOption             NVARCHAR( 1),    
   @nASNExists          INT,          
   @nPOExists           INT,          
   @nSKUCnt             INT,    
   @nCount              INT,     
   @nLPNCount           INT,     
   @nTranCount          INT,    
   @nCountLot           INT,          
   @nPOCount            INT,           
   @nValid              INT,               
   @nActQTY             INT,    
   @nCurrStep           INT,    
   @nCurrScn            INT,    
   @dLottable04         DATETIME,           
   @dLottable05         DATETIME,          
   @dTempLottable04     DATETIME,          
   @dTempLottable05     DATETIME,          
   @cStoredProd         NVARCHAR( 250),    
   @cCheckPalletID_SP   NVARCHAR( 20),      
   @cSQLStatement       NVARCHAR(2000),    
   @cSQLParms           NVARCHAR(2000),    
   @cReceiptPOKeyByLPN  NVARCHAR(1),  
   @cSubReasonCode      NVARCHAR(10)    -- (james03)  
    
DECLARE    
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
   @cDecodeLabelNo NVARCHAR( 20)    
    
DECLARE     
   @cTempLottable01     NVARCHAR( 18),        
   @cTempLottable02     NVARCHAR( 18),        
   @cTempLottable03     NVARCHAR( 18),        
   @cTempLottable04     NVARCHAR( 16),        
   @cTempLottable05     NVARCHAR( 16)        
  
DECLARE @POKeyByLPN     NVARCHAR( 10)  
  
DECLARE  
 @cPD_UserDefine01  NVARCHAR(30),     
 @cPD_UserDefine02  NVARCHAR(30),    
 @cPD_UserDefine03  NVARCHAR(30),    
 @cPD_UserDefine04  NVARCHAR(30),    
 @cPD_UserDefine05  NVARCHAR(30),    
 @cPD_UserDefine06  DATETIME,   
 @cPD_UserDefine07  DATETIME,   
 @cPD_UserDefine08  NVARCHAR(30),    
 @cPD_UserDefine09  NVARCHAR(30),    
 @cPD_UserDefine10  NVARCHAR(30),   
 @cPD_Lottable01    NVARCHAR(18),  
 @cPD_Lottable02    NVARCHAR(18),  
 @cPD_Lottable03    NVARCHAR(18),  
 @cPD_Lottable04    DATETIME,  
 @cPD_Lottable05    DATETIME  
    
-- RDT.RDTMobRec variable          
DECLARE           
   @nFunc        INT,          
   @nScn         INT,          
   @nStep        INT,          
   @cLangCode    NVARCHAR( 3),          
   @nInputKey    INT,          
   @nMenu        INT,          
          
   @cStorer          NVARCHAR( 15),          
   @cFacility        NVARCHAR( 5),           
   @cChkReceiptKey   NVARCHAR( 10),          
   @cReceiptStatus   NVARCHAR( 10),          
   @cChkStorerKey    NVARCHAR( 15),          
   @nRowCount        INT,          
    
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),          
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),          
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),          
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),          
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),     
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),           
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),           
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),           
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),           
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),           
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
  
DECLARE   
   @cErrMsg1        NVARCHAR( 20),         -- (james01)  
   @cErrMsg2        NVARCHAR( 20),         -- (james01)  
   @cErrMsg3        NVARCHAR( 20),         -- (james01)  
   @cErrMsg4        NVARCHAR( 20),         -- (james01)  
   @cErrMsg5        NVARCHAR( 20),         -- (james01)  
   @cErrMsg6        NVARCHAR( 20)          -- (james01)  
     
-- Load RDT.RDTMobRec          
SELECT           
   @nFunc      = Func,          
   @nScn       = Scn,          
   @nStep      = Step,          
   @nInputKey  = InputKey,          
   @nMenu      = Menu,          
   @cLangCode  = Lang_code,          
   @cStorer    = StorerKey,          
   @cFacility  = Facility,          
   @cPrinter   = Printer,           
   @cUserName  = UserName,          
          
   @cUOM                = V_UOM,          
   @nActQTY             = V_QTY,           
   @cReceiptKey         = V_Receiptkey,           
   @cPOKey              = V_POKey,                
   @cLOC                = V_Loc,                  
   @cSKU                = V_SKU,                  
   @cID                 = V_ID,                   
   @cSKUDesc            = V_SKUDescr,                 
   @cLottable01         = V_Lottable01,           
   @cLottable02         = V_Lottable02,           
   @cLottable03         = V_Lottable03,           
   @cLottable04         = V_Lottable04,           
   @cLottable05         = V_Lottable05,           
   @cPOKeyDefaultValue  = V_String1,           
   @cAddSKUtoASN        = V_String2,           
   @cExternPOKey        = V_String3,           
   @cExternLineNo       = V_String4,           
   @cExternReceiptKey   = V_String5,           
   @cReceiptLineNo      = V_String6,           
   @cPrefUOM            = V_String7,           
   @cPrevID             = V_String8,           
   @cVASKey             = V_String9,           
   @cVASLineNumber      = V_String10,           
   @nLPNCount           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11, 5), 0) = 1 THEN LEFT( V_String11, 5) ELSE 0 END,      
   @nCurrStep           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12, 5), 0) = 1 THEN LEFT( V_String12, 5) ELSE 0 END,      
   @nCurrScn            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String13, 5), 0) = 1 THEN LEFT( V_String13, 5) ELSE 0 END,      
   @cLottable01_Code    = V_String14,           
   @cLottable02_Code    = V_String15,           
   @cLottable03_Code    = V_String16,           
   @cLottable04_Code    = V_String17,           
   @cLottable05_Code    = V_String18,           
   @cReasonCode         = V_String20,           
   @cSubReasonCode      = V_String21,         -- (james03)  
   @cLotLabel01         = V_String22,           
   @cLotLabel02         = V_String23,           
   @cLotLabel03         = V_String24,           
   @cLotLabel04         = V_String25,           
   @cLotLabel05         = V_String26,    
   @cPackKey            = V_String27,           
   @cPrevOp             = V_String29,           
   @cScnOption          = V_String30,           
   @cAutoGenID          = V_String31,           
   @cPromptOpScn        = V_String32,           
   @cPromptVerifyPKScn  = V_String37,           
   @cDefaultToLoc       = V_String38,           
   @cQTY                = V_String39,           
   @nPOCount            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String40, 5), 0) = 1 THEN LEFT( V_String40, 5) ELSE 0 END,        
    
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
FROM RDT.RDTMOBREC WITH (NOLOCK)          
WHERE Mobile = @nMobile         
    
-- Redirect to respective screen          
IF @nFunc = 1787  -- UCC Carton Receive    
OR @nFunc = 1788  -- UCC Carton Return    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Func = 1787. Menu          
   IF @nStep = 1 GOTO Step_1   -- Scn = 2910. ASN #          
   IF @nStep = 2 GOTO Step_2   -- Scn = 2911. LOC          
   IF @nStep = 3 GOTO Step_3   -- Scn = 2912. PAL ID          
   IF @nStep = 4 GOTO Step_4   -- Scn = 2913. SKU          
   IF @nStep = 5 GOTO Step_5   -- Scn = 2914. LPN          
   IF @nStep = 6 GOTO Step_6   -- Scn = 2915. LPN          
   IF @nStep = 7 GOTO Step_7   -- Scn = 2916. LPN (edit)       
   IF @nStep = 8 GOTO Step_8   -- Scn = 2917. VAS           
END          
    
RETURN -- Do nothing if incorrect step          
    
/********************************************************************************          
Step 0. func = 1787. Menu          
   @nStep = 0          
********************************************************************************/         
Step_0:          
BEGIN          
   SET @cPOKeyDefaultValue = ''          
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( 0, 'ReceivingPOKeyDefaultValue', @cStorer)            
             
   IF (@cPOKeyDefaultValue = '0' OR @cPOKeyDefaultValue IS NULL)          
      SET @cPOKeyDefaultValue = ''          
                
   SET @cOutField02 = @cPOKeyDefaultValue          
          
   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA          
   FROM RDT.rdtMobRec M WITH (NOLOCK)          
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)          
   WHERE M.Mobile = @nMobile          
  
   SET @cSubReasonCode = ''      -- (james03)  
        
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
  
   SET @cInField01 =''  
   SET @cInField02 =''  
   SET @cInField03 =''  
   SET @cInField04 =''  
   SET @cInField05 =''  
   SET @cInField06 =''  
   SET @cInField07 =''  
   SET @cInField08 =''  
   SET @cInField09 =''  
   SET @cInField10 =''  
   SET @cInField11 =''  
   SET @cInField12 =''  
   SET @cInField13 =''  
   SET @cInField14 =''  
   SET @cInField15 =''  
  
          
 -- EventLog - Sign In Function          
 EXEC RDT.rdt_STD_EventLog          
  @cActionType = '1', -- Sign in function          
  @cUserID     = @cUserName,          
  @nMobileNo   = @nMobile,          
  @nFunctionID = @nFunc,      
  @cFacility   = @cFacility,          
  @cStorerKey  = @cStorer          
         
   -- Initialise all variable when start...      
   SET @cLotLabel01=''      
   SET @cLotLabel02=''      
   SET @cLotLabel03=''      
   SET @cLotLabel04=''      
   SET @cLotLabel05=''      
   SET @cReceiptKey=''      
   SET @cPOKey     =''       
   SET @cLOC       =''           
   SET @cSKU       =''           
   SET @cUOM       =''           
   SET @cID        =''           
     
   -- Set the entry point          
   SET @nScn = 2910          
   SET @nStep = 1          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 1. Scn = 951. ASN #, PO# screen          
   ASN # (field01)          
   PO # (field02)          
********************************************************************************/          
Step_1:          
BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN          
      -- Screen mapping          
      SET @cReceiptKey = @cInField01          
      SET @cPOKey      = @cInField02        
                
      -- Validate at least one field must key-in          
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND          
         (@cPOKey = '' OR @cPOKey IS NULL OR @cPOKey = 'NOPO')     
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74051, @cLangCode, 'DSP')     
         GOTO Step_1_Fail          
      END          
  
      -- Both ASN & PO keyed-in          
      IF NOT (@cReceiptKey = '' OR @cReceiptKey IS NULL) AND          
         NOT (@cPOKey = '' OR @cPOKey IS NULL)           
      BEGIN          
         -- Get the ASN          
         SELECT           
            @cChkFacility = R.Facility,          
            @cChkStorerKey = R.StorerKey,          
            @cChkReceiptKey = R.ReceiptKey,           
            @cReceiptStatus = R.Status          
         FROM dbo.Receipt R WITH (NOLOCK)          
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey           
            WHERE R.ReceiptKey = @cReceiptKey          
            AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END          
            AND R.StorerKey = @cStorer          
         SET @nRowCount = @@ROWCOUNT          
          
         IF @nRowCount = 0          
         BEGIN          
            SET @nASNExists = 0          
            SET @nPOExists = 0          
          
            -- No row returned, either ASN or PO not exists          
            IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)          
               WHERE StorerKey = @cStorer          
                  AND ReceiptKey = @cReceiptKey)          
            BEGIN          
               SET @nASNExists = 1          
            END          
          
            IF EXISTS (SELECT 1 FROM dbo.RECEIPT R WITH (NOLOCK)          
               JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)          
               WHERE R.StorerKey = @cStorer          
                  AND RD.POKey = CASE WHEN @cPOKey = 'NOPO' THEN RD.POKey ELSE @cPOKey END)          
            BEGIN          
               SET @nPOExists = 1          
            END          
          
            -- Both ASN & PO also not exists          
            IF (@nASNExists = 0 AND @nPOExists = 0)          
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74052, @cLangCode, 'DSP') --'ASN&PONotExists'          
               SET @cOutField01 = '' -- ReceiptKey          
               SET @cOutField02 = '' -- POKey          
               SET @cReceiptKey = ''          
               SET @cPOKey = ''        
               EXEC rdt.rdtSetFocusField @nMobile, 1          
               GOTO Quit          
            END          
            ELSE          
            -- Only ASN not exists          
            IF @nASNExists = 0          
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74053, @cLangCode, 'DSP') --'ASN Not Exists'          
               SET @cOutField01 = '' -- ReceiptKey          
               SET @cOutField02 = @cPOKey -- POKey          
               SET @cReceiptKey = ''          
               EXEC rdt.rdtSetFocusField @nMobile, 1          
               GOTO Quit          
            END          
            ELSE          
            -- Only PO not exists          
            IF @nPOExists = 0          
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74054, @cLangCode, 'DSP') --'PO Not Exists'          
               SET @cOutField01 = @cReceiptKey          
               SET @cOutField02 = '' -- POKey          
               SET @cPOKey = ''          
               EXEC rdt.rdtSetFocusField @nMobile, 2          
               GOTO Quit          
            END          
         END          
      END          
      ELSE          
      -- Only ASN # keyed-in (POKey = blank)          
      IF (@cReceiptKey <> '' AND @cReceiptKey IS NOT NULL)          
      BEGIN          
         -- Validate whether ASN have multiple PO          
         DECLARE @cChkPOKey NVARCHAR( 10)          
         SELECT DISTINCT           
            @cChkPOKey = RD.POKey,           
            @cChkFacility = R.Facility,          
            @cChkStorerKey = R.StorerKey,          
            @cReceiptStatus = R.Status          
         FROM dbo.Receipt R WITH (NOLOCK)          
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey           
         WHERE RD.ReceiptKey = @cReceiptKey          
            AND RD.StorerKey = @cStorer          
         -- If return multiple row, the last row is taken & assign into var.           
         -- We want blank POKey to be assigned if multiple row returned, hence using the DESC          
         ORDER BY RD.POKey DESC           
         SET @nRowCount = @@ROWCOUNT          
    
         SET @nPOCount = @nRowCount    
                
         IF @nRowCount < 1          
         BEGIN          
            DECLARE @nRowCount1 INT          
       
            SELECT DISTINCT           
                @cChkFacility = R.Facility,          
                @cChkStorerKey = R.StorerKey,          
                @cReceiptStatus = R.Status          
            FROM dbo.Receipt R WITH (NOLOCK)          
            WHERE R.ReceiptKey = @cReceiptKey          
            AND R.StorerKey = @cStorer          
            SET @nRowCount1 = @@ROWCOUNT           
       
            IF @nRowCount1 < 1          
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74055, @cLangCode, 'DSP') --'ASN does not exists'          
               SET @cOutField01 = '' -- ReceiptKey          
               SET @cReceiptKey = ''          
               EXEC rdt.rdtSetFocusField @nMobile, 1          
               GOTO Quit          
            END                     
         END          
             
         -- Only 1 POKey should exists in the ReceiptDetail, otherwise error          
         -- Only exception is when blank POKey exists in the ReceiptDetail          
         -- Changes for Multiple PO in 1 ASN     
         -- Control by RDT Storer Config    
         SET @cMultiPOASN = ''    
         SET @cMultiPOASN = rdt.RDTGetConfig( @nFunc, 'AllowMultiPO', @cStorer)          
             
         IF @cMultiPOASN = '1'    
         BEGIN    
            IF @nRowCount > 1     
            BEGIN        
                  SET @cPOKey = ''    
            END        
            ELSE     
            BEGIN    
                  SET @cPOKey = @cChkPOKey        
            END          
         END    
         ELSE    
         BEGIN    
         IF @nRowCount > 1 AND @cChkPOKey <> ''    
         BEGIN        
            SET @cPOKey = ''    
            SET @cErrMsg = rdt.rdtgetmessage( 74056, @cLangCode, 'DSP') --'Multi PO in ASN'          
            SET @cOutField01 = '' -- ReceiptKey          
            SET @cReceiptKey = ''          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Quit          
         END          
             
         SET @cPOKey = @cChkPOKey      
             
       END        
      END          
      ELSE          
      -- Only PO # keyed-in, and not equal to 'NOPO'          
      IF @cPOKey <> '' AND @cPOKey IS NOT NULL AND          
         @cPOKey <> 'NOPO'           
      BEGIN          
         -- Validate whether PO have multiple ASN          
         SELECT DISTINCT           
            @cChkFacility = R.Facility,          
            @cChkStorerKey = R.StorerKey,          
            @cReceiptKey = R.ReceiptKey,           
            @cReceiptStatus = R.Status          
         FROM dbo.Receipt R WITH (NOLOCK)          
            INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey           
         WHERE RD.POKey = @cPOKey          
            AND RD.StorerKey = @cStorer          
         SET @nRowCount = @@ROWCOUNT          
             
         IF @nRowCount < 1          
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( 74057, @cLangCode, 'DSP') --'PO does not exists'          
            SET @cOutField02 = '' -- POKey          
            SET @cPOKey = ''          
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            GOTO Quit          
         END          
          
         IF @nRowCount > 1          
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( 74058, @cLangCode, 'DSP') --'Multi ASN in PO'          
            SET @cOutField02 = '' -- POKey          
            SET @cPOKey = ''          
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            GOTO Quit          
         END          
      END          
          
      -- Validate ASN in different facility          
      IF @cFacility <> @cChkFacility          
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74059, @cLangCode, 'DSP') --'ASN facility diff'          
         SET @cOutField01 = '' -- ReceiptKey          
         SET @cReceiptKey = ''          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
       GOTO Quit          
      END          
          
      -- Validate ASN belong to the storer          
      IF @cChkStorerKey IS NULL OR @cChkStorerKey = ''          
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74060, @cLangCode, 'DSP') --'ASN storer different'          
         SET @cOutField01 = '' -- ReceiptKey          
         SET @cReceiptKey = ''          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Quit          
      END          
          
      -- Validate ASN status          
      IF @cReceiptStatus = '9'          
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74061, @cLangCode, 'DSP') --'ASN is closed'          
         SET @cOutField01 = '' -- ReceiptKey          
         SET @cReceiptKey = ''          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Quit          
      END          
          
      SET @cDefaultToLoc = ''          
      SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorer) -- Parse in Function          
    
      IF @cDefaultToLoc = '0' OR @cDefaultToLoc = '' -- Storer config ReceiveDefaultToLoc not turn on    
      BEGIN    
         DECLARE @c_authority NVARCHAR(1)    
         SELECT @b_success = 0      
         EXECUTE nspGetRight     
            @cFacility,    
            @cStorer,    
            NULL, -- @cSKU    
            'ASNReceiptLocBasedOnFacility',    
            @b_success   OUTPUT,      
            @c_authority OUTPUT,       
            @n_err       OUTPUT,      
           @c_errmsg    OUTPUT    
    
         IF @b_success = '1'  AND @c_authority = '1'    
            SELECT @cDefaultToLoc = UserDefine04    
            FROM Facility WITH (NOLOCK)    
            WHERE Facility = @cFacility    
      END    
    
      --Start (Vanessa01)          
      IF ISNULL(RTRIM(@cDefaultToLoc),'0') <> '0'          
      BEGIN          
         SET @cOutField01 = ISNULL(RTRIM(@cDefaultToLoc),'0') -- LOC          
      END          
      ELSE          
      BEGIN          
         -- Init next screen var          
         SET @cOutField01 = '' -- LOC          
      END          
      --End (Vanessa01)          
  
      IF @nFunc = 1788  
      BEGIN  
         --check for TradeReturnASN  (james03)  
         IF EXISTS (SELECT 1 FROM dbo.RECEIPT WITH (NOLOCK)    
                    WHERE Receiptkey = @cReceiptkey    
                    AND   DocType <> 'R')    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 74087, @cLangCode, 'DSP') -- Not Return ASN    
            SET @cOutField01 = '' -- ReceiptKey          
            SET @cReceiptKey = ''          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Quit          
         END    
  
         -- Get Return Reason  
         SELECT @cSubReasonCode = ISNULL(ASNReason, '')  
         FROM dbo.Receipt WITH (NOLOCK)   
         WHERE StorerKey = @cStorer  
            AND Receiptkey = @cReceiptkey  
            AND DocType = 'R'  
  
         IF @cSubReasonCode = '' AND EXISTS     
         (SELECT 1 FROM dbo.STORERCONFIG WITH (NOLOCK)     
          WHERE Configkey = 'ReturnReason'    
            AND Storerkey = @cStorer    
            AND sValue = '1')   
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 74088, @cLangCode, 'DSP') -- RET REASON REQ    
            SET @cOutField01 = '' -- ReceiptKey          
            SET @cReceiptKey = ''          
            EXEC rdt.rdtSetFocusField @nMobile, 1          
            GOTO Quit          
         END    
      END  
        
      -- Go to next screen          
      SET @nScn = @nScn + 1          
      SET @nStep = @nStep + 1          
   END         
          
   IF @nInputKey = 0 -- Esc or No          
   BEGIN          
     -- EventLog - Sign Out Function          
     EXEC RDT.rdt_STD_EventLog          
       @cActionType = '9', -- Sign Out function          
       @cUserID     = @cUserName,          
       @nMobileNo   = @nMobile,          
       @nFunctionID = @nFunc,          
       @cFacility   = @cFacility,          
       @cStorerKey  = @cStorer          
          
      -- Back to menu          
      SET @nFunc = @nMenu          
      SET @nScn  = @nMenu          
      SET @nStep = 0          
          
      SET @cOutField01 = ''          
          
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
   END          
   GOTO Quit          
          
   Step_1_Fail:          
   BEGIN          
      -- Reset this screen var          
      SET @cOutField01 = '' -- ReceiptKey          
      SET @cOutField02 = '' -- POKey          
      SET @cReceiptKey = ''          
      SET @cPOKey = ''        
   END          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 2. Scn = 952. Location screen          
   LOC          
********************************************************************************/          
Step_2:          
BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN          
      -- Screen mapping          
      SET @cLOC = @cInField01 -- LOC          
          
      -- Validate compulsary field          
      IF @cLOC = '' OR @cLOC IS NULL          
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74062, @cLangCode, 'DSP') --'LOC is required'          
         GOTO Step_2_Fail          
  END          
          
      -- Get the location          
      DECLARE @cChkLOC NVARCHAR( 10)          
      SELECT           
         @cChkLOC = LOC,           
         @cChkFacility = Facility          
      FROM dbo.LOC WITH (NOLOCK)          
      WHERE LOC = @cLOC          
          
      -- Validate location          
      IF @cChkLOC IS NULL OR @cChkLOC = ''          
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74063, @cLangCode, 'DSP') --'Invalid LOC'          
         GOTO Step_2_Fail          
      END          
          
      -- Validate location not in facility          
      IF @cChkFacility <> @cFacility          
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74064, @cLangCode, 'DSP') --'LOC not in facility'          
         GOTO Step_2_Fail          
      END          
          
      -- Auto generate ID if RDT StorerConfigkey = AutoGenID turned on       
      SET @cAutoGenID = ''          
      SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer) -- Parse in Function          
    
      IF @cAutoGenID = '1' and (@cPrevOp = '' OR @cPrevOp = '1')          
      BEGIN           
         EXECUTE dbo.nspg_GetKey          
            'ID',           
            10 ,          
            @cID               OUTPUT,          
            @b_success    OUTPUT,          
            @n_err             OUTPUT,          
            @c_errmsg          OUTPUT          
    
         IF @b_success <> 1          
         BEGIN          
            SET @nErrNo = 74065          
            SET @cErrMsg = rdt.rdtgetmessage( 74065, @cLangCode, 'DSP') -- 'GetIDKey Fail'          
            GOTO Step_2_Fail          
         END          
         ELSE          
         BEGIN          
     -- Init next screen var          
             SET @cOutField01 = @cID -- ID          
         END          
      END          
      ELSE IF @cPrevOp = '2' -- Default Prev ID          
      BEGIN          
         -- Init next screen var          
         SET @cOutField01 = @cID -- ID          
      END          
      ELSE           
  BEGIN          
         -- Init next screen var          
         SET @cOutField01 = '' -- ID          
      END          
    
      SET @cPrevID = ''    
    
      -- Go to next screen          
      SET @nScn  = @nScn + 1          
      SET @nStep = @nStep + 1          
   END          
          
   IF @nInputKey = 0 -- Esc or No          
   BEGIN          
      -- Prepare prev screen var          
      SET @cOutField01 = @cReceiptKey          
      SET @cOutField02 = @cPOKey          
          
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1          
   END          
   GOTO Quit          
          
   Step_2_Fail:          
   BEGIN          
      -- Reset this screen var          
      SET @cOutField01 = '' -- LOC          
      SET @cLOC = ''          
   END          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 3. Scn = 953. Pallet ID screen          
   ID          
********************************************************************************/          
Step_3:          
BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN          
      -- Screen mapping          
      SET @cID = @cInField01 -- ID          
          
      -- Validate duplicate pallet ID          
      DECLARE @nDisAllowDuplicateIdsOnRFRcpt NVARCHAR(1)         
         
      SELECT @nDisAllowDuplicateIdsOnRFRcpt = ISNULL(NSQLValue,'')          
      FROM dbo.NSQLConfig WITH (NOLOCK)          
      WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'          
      IF @nDisAllowDuplicateIdsOnRFRcpt <> '1'  
      BEGIN  
         SELECT @nDisAllowDuplicateIdsOnRFRcpt = ISNULL(sValue,'')          
         FROM dbo.StorerConfig WITH (NOLOCK)          
         WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'   
         AND   StorerKey = @cStorer         
      END  
          
      IF (@nDisAllowDuplicateIdsOnRFRcpt = '1') AND           
         (@cID <> '' AND @cID IS NOT NULL)          
      BEGIN                   
         IF EXISTS( SELECT [ID]           
         FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)          
            INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)          
         WHERE [ID] = @cID          
            AND QTY > 0          
            AND LOC.Facility = @cFacility)          
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( 74066, @cLangCode, 'DSP') --'Duplicate PAL ID'          
            GOTO Step_3_Fail          
         END          
      END          
          
      SET @cCheckPLTID = ''          
      SET @cCheckPLTID = rdt.RDTGetConfig( @nFunc, 'CheckPLTID', @cStorer) -- Parse in Function          
          
      IF @cCheckPLTID = '1'          
      BEGIN          
         IF EXISTS (SELECT 1 FROM  dbo.ReceiptDetail RD WITH (NOLOCK)          
                    WHERE RD.ReceiptKey = @cReceiptKey          
                    AND RD.StorerKey = @cStorer          
                    AND RD.ToID = RTRIM(@cID)          
                    AND RD.BeforeReceivedQty > 0)          
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( 74067, @cLangCode, 'DSP') --'PLT ID Exists'    
            GOTO Step_3_Fail          
         END          
      END          
  
      -- (Shong01)  
      DECLARE @cPalletIDRequired NVARCHAR(1)  
        
      SET @cPalletIDRequired = '0'          
      SET @cPalletIDRequired = rdt.RDTGetConfig( @nFunc, 'PalletIDRequired', @cStorer) -- Parse in Function          
          
      IF @cPalletIDRequired = '1' AND ISNULL(RTRIM(@cID),'') = ''  
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74089, @cLangCode, 'DSP') --'PLT ID Required'          
         GOTO Step_3_Fail          
      END          
  
  
      -- Stored Proc to validate Pallet ID    
      SET @cCheckPalletID_SP = rdt.RDTGetConfig( @nFunc, 'CheckPalletID_SP', @cStorer)    
    
      IF ISNULL(@cCheckPalletID_SP, '') NOT IN ('', '0')    
      BEGIN    
         SET @cSQLStatement = N'EXEC rdt.' + RTRIM(@cCheckPalletID_SP) +    
             ' @cPalletID, @nValid OUTPUT, @nErrNo OUTPUT,  @cErrMsg OUTPUT'    
    
         SET @cSQLParms = N'@cPalletID    NVARCHAR( 18),        ' +    
                           '@nValid       INT      OUTPUT,  ' +    
                           '@nErrNo       INT      OUTPUT,  ' +    
                           '@cErrMsg      NVARCHAR(20) OUTPUT '    
    
         EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
                     @cID,    
                     @nValid  OUTPUT,    
                     @nErrNo  OUTPUT,    
                     @cErrMsg OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            GOTO Step_3_Fail    
         END    
    
         IF @nValid = 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 74068, @cLangCode, 'DSP') --Invalid PltID    
            GOTO Step_3_Fail    
         END    
      END     
    
      IF ISNULL(@cPrevID, '') <> '' AND ISNULL(@cPrevID, '') <> ISNULL(@cID, '')    
         AND rdt.RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorer) <> '1'  -- 1=Not finalize    
      BEGIN    
         SET @nTranCount = @@TRANCOUNT    
    
         BEGIN TRAN    
         SAVE TRAN Finalize_UCCReceive    
    
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
         SELECT DISTINCT ReceiptLineNumber     
         FROM dbo.UCC WITH (NOLOCK)     
         WHERE StorerKey = @cStorer    
         AND ReceiptKey = @cReceiptKey    
         AND ExternKey = CASE WHEN ISNULL(@cPOKey, '') = '' OR @cPOKey = 'NOPO' THEN ExternKey ELSE @cPOKey END    
         AND LOC = @cLOC    
         AND ID = @cPrevID    
         AND Status = '1'    
         ORDER BY 1    
    
         OPEN CUR_LOOP    
         FETCH NEXT FROM CUR_LOOP INTO @cTempReceiptLineNo     
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF ISNULL(@cTempReceiptLineNo, '') <> ''    
            BEGIN    
               IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)    
                          WHERE StorerKey = @cStorer    
                          AND ReceiptKey = @cReceiptKey    
                          AND ReceiptLineNumber = @cTempReceiptLineNo    
                          AND BeforeReceivedQTY > 0    
                          AND FinalizeFlag <> 'Y')    
               BEGIN    
                  -- Finalize ASN    
                  UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET    
                     QTYReceived = BeforeReceivedQTY,     
                     FinalizeFlag = 'Y',  
                     SubReasonCode = CASE WHEN @nFunc = 1788 AND ISNULL(@cSubReasonCode, '') <> '' -- (james03)  
                                     THEN @cSubReasonCode   
                                     ELSE SubReasonCode END  
                  WHERE StorerKey = @cStorer    
                  AND ReceiptKey = @cReceiptKey    
                  AND ReceiptLineNumber = @cTempReceiptLineNo    
                  AND BeforeReceivedQTY > 0    
                  AND FinalizeFlag <> 'Y'    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     ROLLBACK TRAN Finalize_UCCReceive    
                     SET @cErrMsg = rdt.rdtgetmessage( 74081, @cLangCode, 'DSP') --Finalize failed    
                     CLOSE CUR_LOOP    
                     DEALLOCATE CUR_LOOP    
                     GOTO Step_3_Fail    
                  END    
                  ELSE    
                  BEGIN    
                     -- Retrieve LOT to update UCC    
                     SET @cLOT = ''    
                     SELECT TOP 1 @cLOT = LOT FROM dbo.ITRN WITH (NOLOCK)  -- (james06)  
                     WHERE SourceKey = RTRIM(@cReceiptKey) + RTRIM(@cTempReceiptLineNo)    
                        AND TranType = 'DP'    
                        AND SourceType = 'ntrReceiptDetailUpdate'    
    
                     -- If cannot find in ITRN, try to look in Receiptdetail by SKU & Lottables    
                     IF ISNULL(@cLOT, '') = ''   
                     BEGIN    
                        SELECT TOP 1 @cLOT = LOT    
                        FROM dbo.ReceiptDetail RD WITH (NOLOCK)     
                        JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON     
                        (RD.StorerKey = LA.StorerKey AND     
                         RD.SKU = LA.SKU AND     
                         RD.Lottable01 = LA.Lottable01 AND     
                         RD.Lottable02 = LA.Lottable02 AND     
                         RD.Lottable03 = LA.Lottable03 AND     
                         ISNULL(RD.Lottable04, 0) = ISNULL(LA.Lottable04, 0) AND     
                         ISNULL(RD.Lottable05, 0) = ISNULL(LA.Lottable05, 0))    
                        WHERE RD.StorerKey = @cStorer    
                        AND RD.ReceiptKey = @cReceiptKey    
                        AND RD.ReceiptLineNumber = @cTempReceiptLineNo    
                        AND FinalizeFlag = 'Y'    
                     END    
    
                     IF ISNULL(@cLOT, '') = ''    
                     BEGIN    
                        ROLLBACK TRAN Finalize_UCCReceive    
                        SET @cErrMsg = rdt.rdtgetmessage( 74085, @cLangCode, 'DSP') --UPD UCC failed    
                       CLOSE CUR_LOOP    
                        DEALLOCATE CUR_LOOP    
                        GOTO Step_3_Fail    
                     END    
    
                     -- Update UCC with LOT    
                     UPDATE dbo.UCC WITH (ROWLOCK) SET     
                        LOT = @cLOT,     
                        EditDate = GETDATE(),     
                     EditWho = sUSER_NAME()     
                     WHERE StorerKey = @cStorer    
                     AND ReceiptKey = @cReceiptKey    
                     AND ReceiptLineNumber = @cTempReceiptLineNo    
    
                     IF @@ERROR <> 0    
                     BEGIN    
                        ROLLBACK TRAN Finalize_UCCReceive    
                        SET @cErrMsg = rdt.rdtgetmessage( 74082, @cLangCode, 'DSP') --UPD UCC failed    
                        CLOSE CUR_LOOP    
                        DEALLOCATE CUR_LOOP    
                        GOTO Step_3_Fail    
                     END    
                  END    
               END    
               FETCH NEXT FROM CUR_LOOP INTO @cTempReceiptLineNo     
            END    
--            CLOSE CUR_LOOP  (james06)  
--            DEALLOCATE CUR_LOOP    
         END    
         CLOSE CUR_LOOP    
         DEALLOCATE CUR_LOOP    
           
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN Finalize_UCCReceive    
      END    
    
        
      IF NOT EXISTS (SELECT 1 FROM dbo.PO PO WITH (NOLOCK)     
                     JOIN ReceiptDetail RD WITH (NOLOCK) ON PO.POKEY = RD.POKey    
                     WHERE RD.StorerKey = @cStorer     
                     AND RD.ReceiptKey = @cReceiptKey    
                     AND PO.UserDefine04 = 'Y')    
      BEGIN    
         SET @cLottable01 = ''    
    
         -- Get Lottable02. 1 PO 1 LOT02    
         IF ISNULL(@cPOKey, '') <> 'NOPO'    
         BEGIN    
            SELECT TOP 1 @cLottable02 = Lottable02     
            FROM dbo.PODetail WITH (NOLOCK)    
            WHERE StorerKey = @cStorer    
            AND POKey = @cPOKEY    
         END    
         ELSE    
         BEGIN    
            SELECT TOP 1 @cLottable02 = POD.Lottable02    
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)    
            JOIN dbo.PO PO WITH (NOLOCK) ON (RD.StorerKey = PO.StorerKey AND RD.POKey = PO.POKey)    
            JOIN dbo.PODetail POD WITH (NOLOCK) ON PO.POKEY = POD.POKey    
            WHERE RD.StorerKey = @cStorer    
            AND RD.ReceiptKey = @cReceiptKey    
            AND RD.FinalizeFlag = 'N'     -- (james03)  
         END    
    
         -- Get Lottable03    
         SET @cLottable03 = ISNULL(rdt.RDTGetConfig( @nFunc, 'DefaultLOT03', @cStorer), '')    
    
         IF (ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900')    
         BEGIN    
            SET @cLottable04 = ''    
         END    
    
         IF (ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900')    
         BEGIN    
            SET @cLottable05 = ''    
         END    
    
         -- Init next screen var          
         SET @cOutField01 = '' -- SKU          
         SET @cOutField02 = '' -- QTY    
         SET @cOutField03 = 'LOTTABLE01:' -- LotLabel01          
         SET @cOutField04 = @cLottable01 -- Lottable01          
         SET @cOutField05 = 'LOTTABLE02:' -- LotLabel02          
         SET @cOutField06 = @cLottable02 -- Lottable02          
         SET @cOutField07 = 'LOTTABLE03:' -- LotLabel03          
         SET @cOutField08 = @cLottable03 -- Lottable03          
         SET @cOutField09 = 'LOTTABLE04:' -- LotLabel04          
         SET @cOutField10 = @cLottable04 -- Lottable04          
         SET @cOutField11 = 'LOTTABLE05:' -- LotLabel05          
         SET @cOutField12 = '' -- Lottable05          
    
         SET @cFieldAttr04 = CASE WHEN @cOutField04 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr06 = CASE WHEN @cOutField06 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr08 = CASE WHEN @cOutField08 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr10 = CASE WHEN @cOutField10 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr12 = CASE WHEN @cOutField12 = '' THEN 'O' ELSE '' END    
    
         -- Store the ID currently scanned    
         SET @cPrevID = @cID    
    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
    
         -- Go to next screen          
         SET @nScn  = @nScn + 1          
         SET @nStep = @nStep + 1          
      END    
      ELSE  -- PO.UserDefine04 = 'Y'    
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
         SET @cOutField12 = '2'     -- Default to N    
         SET @cOutField13 = ''    
    
         -- Store the ID currently scanned    
         SET @cPrevID = @cID    
         SET @nLPNCount = 0    
    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
    
         -- Go to next screen          
         SET @nScn  = @nScn + 3          
         SET @nStep = @nStep + 3          
      END    
   END          
          
   IF @nInputKey = 0 -- Esc or No          
   BEGIN          
      IF rdt.RDTGetConfig( 0, 'RDT_NotFinalizeReceiptDetail', @cStorer) <> '1'  -- 1=Not finalize    
      BEGIN    
         -- If ESC from ID screen then check if any thing scanned or not    
         SET @nTranCount = @@TRANCOUNT    
    
         BEGIN TRAN    
         SAVE TRAN Finalize_UCCReceive    
    
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR     
         SELECT DISTINCT ReceiptLineNumber     
         FROM dbo.UCC WITH (NOLOCK)     
         WHERE StorerKey = @cStorer    
         AND ReceiptKey = @cReceiptKey    
         AND ExternKey = CASE WHEN ISNULL(@cPOKey, '') = '' OR @cPOKey = 'NOPO' THEN ExternKey ELSE @cPOKey END    
         AND LOC = @cLOC    
         AND ID = @cID    
         AND STATUS = '1'    
    
         OPEN CUR_LOOP    
         FETCH NEXT FROM CUR_LOOP INTO @cTempReceiptLineNo     
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF ISNULL(@cTempReceiptLineNo, '') <> ''    
           BEGIN    
               IF EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)    
                          WHERE StorerKey = @cStorer    
                          AND ReceiptKey = @cReceiptKey    
                          AND ReceiptLineNumber = @cTempReceiptLineNo    
                          AND BeforeReceivedQTY > 0    
                          AND FinalizeFlag <> 'Y')    
               BEGIN    
            -- Finalize ASN    
                  UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET    
                     QTYReceived = BeforeReceivedQTY,     
                     FinalizeFlag = 'Y',  
                     SubReasonCode = CASE WHEN @nFunc = 1788 AND ISNULL(@cSubReasonCode, '') <> '' -- (james03)  
                                     THEN @cSubReasonCode   
                                     ELSE SubReasonCode END  
                  WHERE StorerKey = @cStorer    
                  AND ReceiptKey = @cReceiptKey    
                  AND ReceiptLineNumber = @cTempReceiptLineNo    
                  AND BeforeReceivedQTY > 0    
                  AND FinalizeFlag <> 'Y'    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     ROLLBACK TRAN Finalize_UCCReceive    
                     SET @cErrMsg = rdt.rdtgetmessage( 74083, @cLangCode, 'DSP') --Finalize failed    
                     CLOSE CUR_LOOP    
                     DEALLOCATE CUR_LOOP    
                     GOTO Step_3_Fail    
                  END    
                  ELSE    
                  BEGIN    
                     -- Retrieve LOT to update UCC    
                     SET @cLOT = ''    
                     SELECT TOP 1 @cLOT = LOT FROM dbo.ITRN WITH (NOLOCK)    
                     WHERE SourceKey = RTRIM(@cReceiptKey) + RTRIM(@cTempReceiptLineNo)    
                        AND TranType = 'DP'    
                        AND SourceType = 'ntrReceiptDetailUpdate'    
    
                     -- If cannot find in ITRN, try to loon in ReceiptDetail by SKU & Lottables    
                     IF ISNULL(@cLOT, '') = ''    
                     BEGIN    
                        SELECT TOP 1 @cLOT = LOT    
                        FROM dbo.ReceiptDetail RD WITH (NOLOCK)     
                        JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON     
                        (RD.StorerKey = LA.StorerKey AND     
                         RD.SKU = LA.SKU AND     
                         RD.Lottable01 = LA.Lottable01 AND     
                         RD.Lottable02 = LA.Lottable02 AND     
                         RD.Lottable03 = LA.Lottable03 AND     
                         ISNULL(RD.Lottable04, 0) = ISNULL(LA.Lottable04, 0) AND     
                         ISNULL(RD.Lottable05, 0) = ISNULL(LA.Lottable05, 0))    
                        WHERE RD.StorerKey = @cStorer    
                        AND RD.ReceiptKey = @cReceiptKey    
                        AND RD.ReceiptLineNumber = @cTempReceiptLineNo    
                        AND FinalizeFlag = 'Y'    
                     END    
    
                     IF ISNULL(@cLOT, '') = ''    
                     BEGIN    
                        ROLLBACK TRAN Finalize_UCCReceive    
                        SET @cErrMsg = rdt.rdtgetmessage( 74086, @cLangCode, 'DSP') --UPD UCC failed    
                        CLOSE CUR_LOOP    
                        DEALLOCATE CUR_LOOP    
                        GOTO Step_3_Fail    
                     END    
    
                     -- Update UCC with LOT    
                     UPDATE dbo.UCC WITH (ROWLOCK) SET     
                        LOT = @cLot,     
                        EditDate = GETDATE(),     
                        EditWho = sUSER_NAME()     
                     WHERE StorerKey = @cStorer    
                     AND ReceiptKey = @cReceiptKey    
                     AND ReceiptLineNumber = @cTempReceiptLineNo    
    
                     IF @@ERROR <> 0    
                     BEGIN    
                        ROLLBACK TRAN Finalize_UCCReceive    
                        SET @cErrMsg = rdt.rdtgetmessage( 74084, @cLangCode, 'DSP') --UPD UCC failed    
                        CLOSE CUR_LOOP    
                        DEALLOCATE CUR_LOOP    
                        GOTO Step_3_Fail    
                     END    
                  END    
               END    
            END    
            FETCH NEXT FROM CUR_LOOP INTO @cTempReceiptLineNo     
         END    
         CLOSE CUR_LOOP    
         DEALLOCATE CUR_LOOP    
    
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN Finalize_UCCReceive    
      END -- Not Finalize for RDT Turn On    
    
      -- Prepare prev screen var          
      SET @cPrevID = ''    
      SET @cOutField01 = @cLOC          
          
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1          
   END          
   GOTO Quit          
          
   Step_3_Fail:          
   BEGIN          
      -- rollback didn't decrease @@trancount    
      -- COMMIT statements for such transaction     
      -- decrease @@TRANCOUNT by 1 without making updates permanent    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
    
      -- Reset this screen var          
      SET @cOutField01 = '' -- ID          
      SET @cID = ''          
   END          
END          
GOTO Quit          
          
          
/********************************************************************************          
Step 4. Scn = 2913. SKU screen          
   Qty         (input)    
   SKU         (input)    
   Lottables   (input)    
********************************************************************************/          
Step_4:          
BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN          
      SET @cActSKU   = @cInField01    
      SET @cLabelNo  = @cInField01    
      SET @cActQty   = @cInField02    
        
      SET @cLottable01 = @cInField03     
      SET @cLottable02 = @cInField06     
      SET @cLottable03 = @cInField08     
      SET @cLottable04 = @cInField10     
    
      -- Validate compulsary field          
      IF ISNULL(@cActSKU, '') = ''     
      BEGIN    
         SET @cActSKU = ''    
         SET @cSKU = ''    
         SET @cErrMsg = rdt.rdtgetmessage( 74069, @cLangCode, 'DSP') --SKU is needed    
         SET @cOutField01 = ''    
         SET @cOutField02 = @cActQty    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_4_Fail    
      END    
    
      SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)    
      IF @cDecodeLabelNo = '0'    
      BEGIN    
         SET @cDecodeLabelNo = ''    
      END    
    
      -- If Decoding label setup then use decoding stored proc to get sku details    
      IF ISNULL(@cDecodeLabelNo, '') <> ''    
      BEGIN    
         SET @cErrMsg = ''    
         SET @nErrNo = 0    
         EXEC dbo.ispLabelNo_Decoding_Wrapper    
             @c_SPName     = @cDecodeLabelNo    
            ,@c_LabelNo    = @cLabelNo    
            ,@c_Storerkey  = @cStorer    
            ,@c_ReceiptKey = ''    
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
            ,@c_ErrMsg     = @cErrMsg     OUTPUT    
    
         IF @nErrNo <> 0    
         BEGIN    
            SET @cActSKU = ''    
            SET @cSKU = ''    
            SET @cOutField01 = ''    
            SET @cOutField02 = @cActQty    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_4_Fail    
         END    
    
         SET @cSKU   = @c_oFieled01   -- SKU    
         SET @cStyle = @c_oFieled02 -- Style    
         SET @cColor = @c_oFieled03 -- Color    
         SET @cSize  = @c_oFieled04  -- Size    
    
         -- Get SKU Description    
         SELECT     
        @cSKUDesc = DESCR,     
            @cPackKey = PackKey,     
            @cSKUGroup = SKUGroup,     
            @cItemClass = ItemClass     
         FROM dbo.SKU WITH (NOLOCK)    
         WHERE StorerKey = @cStorer    
         AND SKU = @cSKU    
      END    
      BEGIN    
         EXEC [RDT].[rdt_GETSKUCNT]    
          @cStorerKey  = @cStorer    
         ,@cSKU        = @cActSKU    
         ,@nSKUCnt     = @nSKUCnt       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @n_Err         OUTPUT    
         ,@cErrMsg     = @c_ErrMsg      OUTPUT    
    
         IF @nSKUCnt = 0    
         BEGIN    
            SET @cActSKU = ''    
            SET @cSKU = ''    
            SET @cErrMsg = rdt.rdtgetmessage( 74070, @cLangCode, 'DSP') --'Invalid SKU'    
            SET @cOutField01 = ''    
            SET @cOutField02 = @cActQty    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_4_Fail    
         END    
    
         IF @nSKUCnt = 0    
         BEGIN    
            SET @cActSKU = ''    
            SET @cSKU = ''    
            SET @cErrMsg = rdt.rdtgetmessage( 74071, @cLangCode, 'DSP') --'SameBarcodeSKU'    
            SET @cOutField01 = ''    
            SET @cOutField02 = @cActQty    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
            GOTO Step_4_Fail    
         END    
    
         EXEC [RDT].[rdt_GETSKU]    
          @cStorerKey  = @cStorer    
         ,@cSKU        = @cActSKU       OUTPUT    
         ,@bSuccess    = @b_Success     OUTPUT    
         ,@nErr        = @n_Err         OUTPUT    
         ,@cErrMsg     = @c_ErrMsg      OUTPUT    
    
         SET @cSKU = @cActSKU    
    
         -- Get SKU Description, Style, Color & Size    
         SELECT     
            @cSKUDesc = DESCR,     
            @cStyle = Style,     
            @cColor = Color,     
            @cSize = Size,     
            @cPackKey = PackKey,     
            @cSKUGroup = SKUGroup,     
            @cItemClass = ItemClass     
         FROM dbo.SKU WITH (NOLOCK)    
         WHERE StorerKey = @cStorer    
         AND SKU = @cSKU    
           
      END    
    
      -- Get UOM    
      SET @cUOM = ''    
      SELECT TOP 1 @cUOM = UOM FROM dbo.ReceiptDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorer    
        AND ReceiptKey = @cReceiptKey    
        AND SKU = @cSKU    
    
      -- If uom is blank then get user prefered uom    
      IF ISNULL(@cUOM, '') = ''    
      BEGIN    
         SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA        
         FROM RDT.rdtMobRec M WITH (NOLOCK)        
         INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)        
         WHERE M.Mobile = @nMobile    
           
         --SET @cUOM =  @cPrefUOM   
      END    
  
      IF ISNULL(@cUOM, '') = '' AND ISNULL(RTRIM(@cPackKey),'') <> ''  
      BEGIN    
         SELECT @cUOM = P.PackUOM3 -- If not defined, default as EA        
         FROM  dbo.PACK P WITH (NOLOCK)        
         WHERE P.PackKey = @cPackKey       
      END        
          
      SET @cAddSKUtoASN = ''          
      --SET @cAddSKUtoASN = rdt.RDTGetConfig( 0, 'RDTAddSKUtoASN', @cStorer)    
      --Pass in Function Number, so that they can enable for either Normal or Return  
      SET @cAddSKUtoASN = rdt.RDTGetConfig( @nFunc, 'RDTAddSKUtoASN', @cStorer)           
    
      -- If config turned on then allow sku not in ASN & PO    
      IF ISNULL(@cAddSKUtoASN, '') <> '1'    
      BEGIN    
         IF NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)    
                        WHERE StorerKey = @cStorer    
                        AND ReceiptKey = @cReceiptKey    
                        AND SKU = @cSKU)    
         BEGIN          
            SET @cActSKU = ''    
            SET @cSKU = ''    
            SET @cErrMsg = rdt.rdtgetmessage( 74072, @cLangCode, 'DSP') --'SKU not in ASN'       
            SET @cOutField01 = ''       
            SET @cOutField02 = @cActQty    
     EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Step_4_Fail          
         END      
    
         -- Check SKU must exists in ASN+PO (james04)      
         IF ISNULL(@cPOKey, '') <> '' AND @cPOKey <> 'NOPO'      
         BEGIN  
          -- Added by SHONG on 10-Oct-2011 (SHONG001)  
            SET @cSellerName = ''  
          
          SELECT @cSellerName = ISNULL(p.SellerName,'')   
          FROM PO p WITH (NOLOCK)  
          WHERE p.POKey = @cPOKey  
            
            IF NOT EXISTS (SELECT 1 FROM dbo.PODETAIL WITH (NOLOCK)       
               WHERE StorerKey = @cStorer      
                  AND POKey = @cPOKey      
                  AND SKU = @cSKU)  -- james06    
            BEGIN          
               SET @cActSKU = ''    
               SET @cSKU = ''    
               SET @cErrMsg = rdt.rdtgetmessage( 74073, @cLangCode, 'DSP') --'SKU not in PO'          
               SET @cOutField01 = ''       
               SET @cOutField02 = @cActQty    
               EXEC rdt.rdtSetFocusField @nMobile, 2    
               GOTO Step_4_Fail          
            END    
         END  
         ELSE  
         BEGIN  
            -- Added by SHONG on 10-Oct-2011 (SHONG001)  
          SET @cSellerName = ''  
            
          SELECT TOP 1   
             @cSellerName = ISNULL(PO.SellerName,'')   
          FROM dbo.ReceiptDetail RD WITH (NOLOCK)   
          JOIN PODETAIL PD WITH (NOLOCK) ON PD.POKey = RD.POKey AND PD.POLineNumber = RD.POLineNumber  
          JOIN PO WITH (NOLOCK) ON PO.POKey = PD.POKey     
            WHERE RD.StorerKey = @cStorer    
              AND RD.ReceiptKey = @cReceiptKey    
              AND RD.SKU = @cSKU                         
         END      
      END -- ISNULL(@cAddSKUtoASN, '') <> '1'  
      ELSE  
      BEGIN  
       IF NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)    
                        WHERE StorerKey = @cStorer    
                        AND ReceiptKey = @cReceiptKey    
                        AND SKU = @cSKU)    
         BEGIN  
          SET @cNewReceiptLineNo = ''  
            
          SELECT @cNewReceiptLineNo = RIGHT( '0000' +   
                         CONVERT(VARCHAR(5), CAST(MAX(ReceiptLineNumber) AS INT) + 1),  
                         5)  
          FROM dbo.ReceiptDetail WITH (NOLOCK)    
            WHERE ReceiptKey = @cReceiptKey   
              
            IF ISNULL(RTRIM(@cNewReceiptLineNo),'') = ''  
               SET @cNewReceiptLineNo = '00001'   
            
          IF ISNULL(@cPOKey, '') <> 'NOPO' AND ISNULL(@cPOKey, '') <> ''  
          BEGIN  
               SET @cPD_UserDefine01  = ''    
               SET @cPD_UserDefine02  = ''   
               SET @cPD_UserDefine03  = ''   
               SET @cPD_UserDefine04  = ''   
               SET @cPD_UserDefine05  = ''   
               SET @cPD_UserDefine06  = ''   
               SET @cPD_UserDefine07  = ''   
               SET @cPD_UserDefine08  = ''   
               SET @cPD_UserDefine09  = ''   
               SET @cPD_UserDefine10  = ''  
               SET @cPD_Lottable01    = ''  
               SET @cPD_Lottable02    = ''  
               SET @cPD_Lottable03    = ''  
               SET @cPD_Lottable04    = ''  
               SET @cPD_Lottable05    = ''  
                            
           SELECT @cExternPOKey      = p.ExternPOKey,   
                  @cPD_UserDefine01  = p.UserDefine01,    
                  @cPD_UserDefine02  = p.UserDefine02,   
                  @cPD_UserDefine03  = p.UserDefine03,   
                  @cPD_UserDefine04  = p.UserDefine04,   
                  @cPD_UserDefine05  = p.UserDefine05,   
                  @cPD_UserDefine06  = p.UserDefine06,   
                  @cPD_UserDefine07  = p.UserDefine07,   
                  @cPD_UserDefine08  = p.UserDefine08,   
                  @cPD_UserDefine09  = p.UserDefine09,   
                  @cPD_UserDefine10  = p.UserDefine10,  
                  @cPD_Lottable01    = p.Lottable01,   
                  @cPD_Lottable02    = p.Lottable02,  
                  @cPD_Lottable03    = p.Lottable03,  
                  @cPD_Lottable04    = p.Lottable04,  
                  @cPD_Lottable05    = p.Lottable05   
           FROM PODETAIL p WITH (NOLOCK)   
           WHERE p.POKey = @cPOKey   
           ORDER BY p.POLineNumber   
          END   
          INSERT INTO RECEIPTDETAIL  
          (  
           ReceiptKey,  
           ReceiptLineNumber,  
           ExternReceiptKey,  
           ExternLineNo,  
           StorerKey,  
           POKey,  
           Sku,  
           AltSku,  
           Id,  
           [Status],  
           DateReceived,  
           QtyExpected,  
           QtyAdjusted,  
           QtyReceived,  
           UOM,  
           PackKey,  
           VesselKey,  
           VoyageKey,  
           XdockKey,  
           ContainerKey,  
           ToLoc,  
           ToLot,  
           ToId,  
           ConditionCode,  
           Lottable01,  
           Lottable02,  
           Lottable03,  
           Lottable04,  
           Lottable05,  
           CaseCnt,  
           InnerPack,  
           Pallet,  
           [Cube],  
           GrossWgt,  
           NetWgt,  
           OtherUnit1,  
           OtherUnit2,  
           UnitPrice,  
           ExtendedPrice,  
           EffectiveDate,  
           AddDate,  
           AddWho,  
           EditDate,  
           EditWho,  
           TrafficCop,  
           ArchiveCop,  
           TariffKey,  
           FreeGoodQtyExpected,  
           FreeGoodQtyReceived,  
           SubReasonCode,  
           FinalizeFlag,  
           DuplicateFrom,  
           BeforeReceivedQty,  
           PutawayLoc,  
           ExportStatus,  
           SplitPalletFlag,  
           POLineNumber,  
           LoadKey,  
           ExternPoKey,  
           UserDefine01,  
           UserDefine02,  
           UserDefine03,  
           UserDefine04,  
           UserDefine05,  
           UserDefine06,  
           UserDefine07,  
           UserDefine08,  
           UserDefine09,  
           UserDefine10  
          )  
          VALUES (   
             @cReceiptKey,  
           @cNewReceiptLineNo,  
           @cExternPOKey,  
           '', /* ExternLineNo */  
           @cStorer,  
           @cPOKey,  
           @cSKU, /* Sku */  
           '',    /* AltSku */  
           '',    /* Id */  
           '0',      /* [Status] */  
           GETDATE() /* DateReceived */,  
           @nActQTY  /* QtyExpected */,  
           0         /* QtyAdjusted */,  
           0         /* QtyReceived */,  
           @cUOM     /* UOM */,  
           @cPackKey /* PackKey */,  
           ''        /* VesselKey */,  
           ''        /* VoyageKey */,  
           ''        /* XdockKey */,  
           ''        /* ContainerKey */,  
           @cLOC     /* ToLoc */,  
           ''        /* ToLot */,  
           ISNULL(@cID,'')   /* ToId */,  
           'OK'     /* ConditionCode */,  
           CASE WHEN ISNULL(@cLottable01,'') = '' THEN @cPD_Lottable01 ELSE @cLottable01 END /* Lottable01 */,  
           CASE WHEN ISNULL(@cLottable02,'') = '' THEN @cPD_Lottable02 ELSE @cLottable02 END /* Lottable02 */,  
           CASE WHEN ISNULL(@cLottable03,'') = '' THEN @cPD_Lottable03 ELSE @cLottable03 END /* Lottable03 */,  
           ISNULL(@cLottable04, @cPD_Lottable04) /* Lottable04 */,  
           NULL         /* Lottable05 */,  
           0            /* CaseCnt */,  
           0            /* InnerPack */,  
           0            /* Pallet */,  
           0            /* [Cube] */,  
           0            /* GrossWgt */,  
           0            /* NetWgt */,  
           0            /* OtherUnit1 */,  
           0            /* OtherUnit2 */,  
           0            /* UnitPrice */,  
           0            /* ExtendedPrice */,  
           GETDATE()    /* EffectiveDate */,  
           GETDATE()    /* AddDate */,  
           SUSER_SNAME() /* AddWho */,  
           GETDATE()     /* EditDate */,  
           SUSER_SNAME() /* EditWho */,  
           NULL          /* TrafficCop */,  
     NULL          /* ArchiveCop */,  
           'XXXXXXXXXX'  /* TariffKey */,  
           0             /* FreeGoodQtyExpected */,  
           0             /* FreeGoodQtyReceived */,  
           ''            /* SubReasonCode */,  
           'N'           /* FinalizeFlag */,  
           ''            /* DuplicateFrom */,  
           0             /* BeforeReceivedQty */,  
           ''            /* PutawayLoc */,  
           ''            /* ExportStatus */,  
           ''            /* SplitPalletFlag */,  
           ''            /* POLineNumber */,  
           ''            /* LoadKey */,  
           @cExternPOKey /* ExternPoKey */,  
           @cPD_UserDefine01  /* UserDefine01 */,  
           @cPD_UserDefine02  /* UserDefine02 */,  
           @cPD_UserDefine03  /* UserDefine03 */,  
           @cPD_UserDefine04  /* UserDefine04 */,  
           @cPD_UserDefine05  /* UserDefine05 */,  
           @cPD_UserDefine06  /* UserDefine06 */,  
           @cPD_UserDefine07  /* UserDefine07 */,  
           @cPD_UserDefine08  /* UserDefine08 */,  
           @cPD_UserDefine09  /* UserDefine09 */,  
           @cPD_UserDefine10  /* UserDefine10 */  
          )          
         END   
      END -- @cAddSKUtoASN = '1'  
    
      -- Validate Qty    
      IF @cActQty = '0'    
      BEGIN    
         SET @cActQty = ''    
         SET @cErrMsg = rdt.rdtgetmessage( 74074, @cLangCode, 'DSP') --Invalid Qty    
         SET @cOutField01 = @cActSKU    
         SET @cOutField02 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Step_4_Fail    
      END    
    
      IF @cActQty  = ''   SET @cActQty  = '0' --'Blank taken as zero'    
      IF RDT.rdtIsValidQTY( @cActQty, 1) = 0    
      BEGIN    
         SET @cActQty = ''    
         SET @cErrMsg = rdt.rdtgetmessage( 74075, @cLangCode, 'DSP') --'Invalid QTY'    
         SET @cOutField01 = @cActSKU    
         SET @cOutField02 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Step_4_Fail    
      END    
    
      SET @nActQty = CAST(@cActQty AS INT)    
    
      -- Check If any VAS need to be shown    
      -- This screen will show after the Storer matches, the facility matches, the TYPE matches,     
      -- the Vendor matches, the Brand matches, the division matches the ASN information.     
      SELECT @cSQLStatement = ''    
      SET @cVASKey = ''  
      SET @cSQLStatement = N'SELECT @cVASKey = VASKey ' +    
                           'FROM dbo.VAS WITH (NOLOCK) ' +     
                           'WHERE StorerKey = N''' + RTRIM(@cStorer) + ''' ' +  -- StorerKey will always exists    
                           'AND [Type] = ''IVAS'' '                            -- IVAS FOR INBOUBND    
    
      -- Facility    
      IF ISNULL(@cFacility, '') <> ''    
      BEGIN    
         SET @cSQLStatement = RTRIM(@cSQLStatement) + ' AND Facility = N''' + RTRIM(@cFacility) + ''' '    
      END    
    
      -- Vendor (PO.SellerName)    
      IF ISNULL(@cSellerName, '') <> ''    
      BEGIN    
         SET @cSQLStatement = RTRIM(@cSQLStatement) + ' AND Vendor = N''' + RTRIM(@cSellerName) + ''' '    
      END    
    
      -- Brand (SKU.SKUGroup)    
      IF ISNULL(@cSKUGroup, '') <> ''    
      BEGIN    
         SET @cSQLStatement = RTRIM(@cSQLStatement) + ' AND BRAND = N''' + RTRIM(@cSKUGroup) + ''' '    
      END    
    
      -- Division (SKU.ItemClass)    
      IF ISNULL(@cItemClass, '') <> ''    
      BEGIN    
         SET @cSQLStatement = RTRIM(@cSQLStatement) + ' AND Division = N''' + RTRIM(@cItemClass) + ''' '    
      END    
    
      SET @cSQLParms = N'@cStorer            NVARCHAR(15), ' +    
                        '@cFacility          NVARCHAR( 5), ' +    
                        '@cSellerName        NVARCHAR(45), ' +    
                        '@cSKUGroup          NVARCHAR(10), ' +    
                        '@cItemClass         NVARCHAR(10), ' +    
                        '@cVASKey            NVARCHAR(10) OUTPUT '     
    
    
      EXEC sp_ExecuteSql @cSQLStatement    
    ,@cSQLParms     
                        ,@cStorer    
                        ,@cFacility    
                        ,@cSellerName    
                        ,@cSKUGroup    
                        ,@cItemClass    
                        ,@cVASKey         OUTPUT    
    
      IF ISNULL(@cVASKey, '') <> ''    
      -- VAS will show only 1 time per pallet    
      AND NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)     
                      WHERE StorerKey = @cStorer    
                      AND ReceiptKey = @cReceiptKey    
                      AND ID = @cID)    
      BEGIN    
         -- Remember current step & screen    
         SET @nCurrStep = @nStep    
         SET @nCurrScn = @nScn    
    
         SET @cVASStep = ''    
         SELECT TOP 1     
            @cVASStep = Step,     
            @cVASLineNumber = VASLineNumber     
         FROM dbo.VASDetail WITH (NOLOCK)     
         WHERE VASKey = @cVASKey     
         ORDER BY VASLineNumber    
    
         SET @cOutField01 = ''    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''    
         SET @cOutField08 = ''    
    
         SET @cOutField01 = CAST(@cVASLineNumber AS INT)    
         SET @cOutField02 = SUBSTRING(@cVASStep,   1, 20)    
         SET @cOutField03 = SUBSTRING(@cVASStep,  21, 20)    
         SET @cOutField04 = SUBSTRING(@cVASStep,  41, 20)    
         SET @cOutField05 = SUBSTRING(@cVASStep,  61, 20)    
         SET @cOutField06 = SUBSTRING(@cVASStep,  81, 20)    
         SET @cOutField07 = SUBSTRING(@cVASStep, 101, 20)    
         SET @cOutField08 = SUBSTRING(@cVASStep, 121,  8)    
    
         -- Goto VAS screen    
         SET @nStep = @nStep + 4    
         SET @nScn = @nScn + 4    
    
         GOTO Quit    
      END    
    
      SET @cDefaultLOT03 = ''    
      SET @cDefaultLOT03 = rdt.RDTGetConfig( @nFunc, 'DefaultLOT03', @cStorer)    
      IF ISNULL(@cDefaultLOT03, '') <> ''    
      BEGIN    
         -- Validate Lottable03    
         IF ISNULL(@cLottable03, '') = ''     
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( 74076, @cLangCode, 'DSP') --'Lottable03 required'          
            SET @cOutField01 = @cActQty    
            SET @cOutField02 = @cActSKU    
            EXEC rdt.rdtSetFocusField @nMobile, 8          
            GOTO Step_4_Fail          
         END            
    
         IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)     
                        WHERE ListName = 'QlityCode'    
                        AND CODE = @cLottable03)    
         BEGIN          
            SET @cErrMsg = rdt.rdtgetmessage( 74077, @cLangCode, 'DSP') --'Invalid Code'          
            SET @cOutField01 = @cActSKU   
            SET @cOutField02 = @cActQty     
            EXEC rdt.rdtSetFocusField @nMobile, 8          
            GOTO Step_4_Fail          
         END            
      END    
    
      SET @cAddSKUtoASN = ''          
      --SET @cAddSKUtoASN = rdt.RDTGetConfig( 0, 'RDTAddSKUtoASN', @cStorer)  
      --Pass in Function Number, so that they can enable for either Normal or Return  
      SET @cAddSKUtoASN = rdt.RDTGetConfig( @nFunc, 'RDTAddSKUtoASN', @cStorer)  
                  
          
      -- Get SKU description, IVAS, lot label          
      SELECT          
         @cSKUDesc = IsNULL( DescR, ''),           
         @cPackKey = PackKey,     
         @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),           
         @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),           
         @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),           
         @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),          
         @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),           
         @cLottable05_Code = IsNULL( S.Lottable05Label, ''),          
         @cLottable01_Code = IsNULL(S.Lottable01Label, ''),            
         @cLottable02_Code = IsNULL(S.Lottable02Label, ''),            
         @cLottable03_Code = IsNULL(S.Lottable03Label, ''),            
         @cLottable04_Code = IsNULL(S.Lottable04Label, '')             
      FROM dbo.SKU S WITH (NOLOCK)          
      WHERE StorerKey = @cStorer          
         AND SKU = @cSKU          
    
      -- Populate Lottables    
      IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR           
         (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')          
      BEGIN          
         
         --initiate @nCounter = 1          
         SET @nCountLot = 1          
          
         --retrieve value for pre lottable01 - 05          
         WHILE @nCountLot <=5 --break the loop when @nCount >5          
         BEGIN          
            IF @nCountLot = 1           
            BEGIN          
          SET @cListName = 'Lottable01'          
             SET @cLottableLabel = @cLottable01_Code          
            END          
            ELSE          
            IF @nCountLot = 2           
            BEGIN          
               SET @cListName = 'Lottable02'          
               SET @cLottableLabel = @cLottable02_Code          
            END          
            ELSE          
            IF @nCountLot = 3           
            BEGIN          
               SET @cListName = 'Lottable03'          
               SET @cLottableLabel = @cLottable03_Code          
            END          
            ELSE          
            IF @nCountLot = 4           
            BEGIN          
               SET @cListName = 'Lottable04'          
               SET @cLottableLabel = @cLottable04_Code          
            END          
            ELSE          
            IF @nCountLot = 5           
            BEGIN          
               SET @cListName = 'Lottable05'          
               SET @cLottableLabel = @cLottable05_Code          
            END          
          
            --get short, store procedure and lottablelable value for each lottable          
            SET @cShort = ''          
            SET @cStoredProd = ''          
            SELECT @cShort = ISNULL(RTRIM(C.Short),''),           
                 @cStoredProd = IsNULL(RTRIM(C.Long), '')          
            FROM dbo.CodeLkUp C WITH (NOLOCK)           
            JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)          
            WHERE C.ListName = @cListName          
            AND   C.Code = @cLottableLabel          
                   
            IF @cShort = 'PRE' AND @cStoredProd <> ''          
            BEGIN          
               IF @cListName = 'Lottable01'          
                  SET @cLottable01 = ''          
               ELSE IF @cListName = 'Lottable02'          
                  SET @cLottable02 = ''          
               ELSE IF @cListName = 'Lottable03'          
                  SET @cLottable03 = ''          
               ELSE IF @cListName = 'Lottable04'          
                  SET @dLottable04 = ''          
               ELSE IF @cListName = 'Lottable05'          
                  SET @dLottable05 = ''          
          
               SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)          
               WHERE StorerKey = @cStorer         
                  AND ReceiptKey = @cReceiptKey          
                  AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END          
                  AND SKU = @cSKU          
                  AND FinalizeFlag = 'N'          
               ORDER BY ReceiptLinenumber          
          
               SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')          
          
               EXEC dbo.ispLottableRule_Wrapper          
                  @c_SPName            = @cStoredProd,          
                  @c_ListName          = @cListName,          
                  @c_Storerkey         = @cStorer,          
                  @c_Sku               = @cSKU,          
                  @c_LottableLabel     = @cLottableLabel,          
                  @c_Lottable01Value   = '',          
                  @c_Lottable02Value   = '',          
                  @c_Lottable03Value   = '',          
                  @dt_Lottable04Value  = '',          
                  @dt_Lottable05Value  = '',          
                  @c_Lottable01        = @cLottable01 OUTPUT,          
                  @c_Lottable02        = @cLottable02 OUTPUT,          
                  @c_Lottable03        = @cLottable03 OUTPUT,          
                  @dt_Lottable04       = @dLottable04 OUTPUT,          
                  @dt_Lottable05       = @dLottable05 OUTPUT,          
                  @b_Success           = @b_Success   OUTPUT,          
                  @n_Err               = @nErrNo      OUTPUT,          
                  @c_Errmsg            = @cErrMsg     OUTPUT,          
                  @c_Sourcekey         = @cSourcekey,          
                  @c_Sourcetype        = 'RDTRECEIPT'          
          
               IF ISNULL(@cErrMsg, '') <> ''            
               BEGIN          
                  SET @cErrMsg = @cErrMsg          
                  GOTO Step_3_Fail          
                  BREAK             
               END            
          
               SET @cLottable01 = IsNULL( @cLottable01, '')          
               SET @cLottable02 = IsNULL( @cLottable02, '')          
               SET @cLottable03 = IsNULL( @cLottable03, '')          
               SET @dLottable04 = IsNULL( @dLottable04, 0)          
               SET @dLottable05 = IsNULL( @dLottable05, 0)          
                        
                IF @dLottable04 > 0          
                BEGIN          
                   SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)          
                END          
           
               IF @dLottable05 > 0          
               BEGIN          
                  SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)          
               END          
            END          
          
            -- increase counter by 1          
            SET @nCountLot = @nCountLot + 1          
         END -- nCount          
      END -- Lottable <> ''          
  
-----------  
      SET @cOutField03 = @cLottable01_Code  
      SET @cOutField05 = @cLottable02_Code  
      SET @cOutField07 = @cLottable03_Code  
      SET @cOutField09 = @cLottable04_Code  
      SET @cOutField11 = @cLottable05_Code  
  
      -- Validate lottable01    
      IF @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL    
      BEGIN    
         --SET @cLottable01 = @cOutField02--@cInField02    
         IF @cLottable01 = '' OR @cLottable01 IS NULL    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 60430, @cLangCode, 'DSP') --'Lottable01 required'    
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            SET @cOutField01 = @cActSKU   
            SET @cOutField02 = @cActQty                 
            GOTO Step_4_Fail    
         END    
      END    
    
      -- Validate lottable02    
      IF @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL    
      BEGIN    
         IF @cLottable02 = '' OR @cLottable02 IS NULL    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 60431, @cLangCode, 'DSP') --'Lottable02 required'    
            EXEC rdt.rdtSetFocusField @nMobile, 6    
            SET @cOutField01 = @cActSKU   
            SET @cOutField02 = @cActQty     
  
            GOTO Step_4_Fail    
         END    
      END    
    
      -- Validate lottable03    
      IF @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL    
      BEGIN    
         IF @cLottable03 = '' OR @cLottable03 IS NULL    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 60432, @cLangCode, 'DSP') --'Lottable03 required'    
            EXEC rdt.rdtSetFocusField @nMobile, 8    
            SET @cOutField01 = @cActSKU   
            SET @cOutField02 = @cActQty     
  
            GOTO Step_4_Fail    
         END    
      END    
    
      -- Validate lottable04    
      IF @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL    
      BEGIN    
         -- Validate empty    
         IF @cLottable04 = '' OR @cLottable04 IS NULL    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 60433, @cLangCode, 'DSP') --'Lottable04 required'    
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            SET @cOutField01 = @cActSKU   
            SET @cOutField02 = @cActQty     
                
            GOTO Step_4_Fail    
         END    
         -- Validate date    
         IF RDT.rdtIsValidDate( @cLottable04) = 0    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 60434, @cLangCode, 'DSP') --'Invalid date'    
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            SET @cOutField01 = @cActSKU   
            SET @cOutField02 = @cActQty     
        
            GOTO Step_4_Fail    
         END    
      END    
  
      -- (james02)  
      -- If the SKU has 0 cube OR if the SKU has 0 weight then prompt screen   
      -- show the message to measure the cube and weight with the Cubiscan  
      IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)   
                 WHERE StorerKey = @cStorer  
                 AND SKU = @cSKU  
--                 AND (ISNULL(Weight, 0) = 0 OR ISNULL(STDCUBE, 0) = 0))  
                 AND (ISNULL(STDGROSSWGT, 0) = 0 OR ISNULL(STDCUBE, 0) = 0))  -- (james05)  
      BEGIN  
         SET @nErrNo = 0  
         SET @cErrMsg1 = @cSKU  
         SET @cErrMsg2 = ''  
         SET @cErrMsg3 = ''  
         SET @cErrMsg4 = 'PLEASE MEASURE THE'  
         SET @cErrMsg5 = 'CUBE AND WEIGHT FOR'  
         SET @cErrMsg6 = 'THIS SKU/LOT'  
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
         @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, @cErrMsg6   
  
         IF @nErrNo = 1  
         BEGIN  
            SET @cErrMsg1 = ''  
            SET @cErrMsg2 = ''  
            SET @cErrMsg3 = ''  
            SET @cErrMsg4 = ''  
            SET @cErrMsg5 = ''  
            SET @cErrMsg6 = ''  
         END  
      END  
  
--------------          
      -- Init lot label          
      SET @cOutField01 = ''      -- LPN    
      SET @cOutField02 = @cSKU   -- SKU    
    
      IF ISNULL(rdt.RDTGetConfig( 0, 'SHOWSTYLECOLORSIZE', @cStorer), '') = ''    
      BEGIN    
         SET @cOutField03 = 'STYLE/COLOR/SIZE:'     
         SET @cOutField04 = RTRIM(@cStyle) + '/' + RTRIM(@cColor) + '/' + RTRIM(@cSize)    
      END    
      ELSE    
      BEGIN    
         SET @cOutField03 = SUBSTRING(@cSKUDesc, 1, 20)    
         SET @cOutField04 = SUBSTRING(@cSKUDesc, 21, 20)    
      END    
    
      SET @cOutField05 = @nActQty   -- Qty    
       
      -- Disable lot label and lottable field          
      IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL          
      BEGIN          
         SET @cFieldAttr06 = 'O'     
         SET @cOutField06 = ''          
      END          
      ELSE          
      BEGIN          
         -- Populate lot label and lottable          
         SET @cOutField06 = ISNULL(@cLottable01, '')           
      END          
    
      IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL          
      BEGIN          
         SET @cFieldAttr07 = 'O'     
         SET @cOutField07 = ''          
      END          
      ELSE          
      BEGIN          
         SET @cOutField07 = ISNULL(@cLottable02, '')      
      END          
       
      IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL          
      BEGIN          
         SET @cFieldAttr08 = 'O'     
         SET @cOutField08 = ''    
      END          
      ELSE          
      BEGIN          
         SET @cOutField08 = ISNULL(@cLottable03, '')      
      END          
          
      IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL          
      BEGIN          
         SET @cFieldAttr10 = 'O'     
         SET @cOutField10 = ''          
      END          
      ELSE          
      BEGIN          
         SELECT @cOutField10 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))     
    
         -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan     
         IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'    
         BEGIN    
            SET @cOutField09 = ''    
         END    
      END          
       
      IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL              
      BEGIN           
         SET @cFieldAttr10 = 'O'     
         SET @cOutField10 = ''          
      END          
      ELSE          
      BEGIN          
         SELECT @cOutField10 = RDT.RDTFormatDate(@cLottable05)     
    
         -- Check if lottable05 is blank/is 01/01/1900 then default system date. User no need to scan (james07)    
         IF @cLottable05_Code = 'RCP_DATE' OR ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable05) = '1900/01/01'    
         BEGIN    
            SET @cOutField10 = RDT.RDTFormatDate( GETDATE())    
         END    
      END             
    
  --------------------  
    
  --------------------  
      SET @nLPNCount = 0    
      SET @cOutField11 = RIGHT( '    ' + CAST(  '0' AS NVARCHAR( 5)), 5)    
    
      SET @nScn = @nScn + 1          
    SET @nStep = @nStep + 1          
   END          
          
   IF @nInputKey = 0 -- Esc or No          
   BEGIN          
      -- Prepare prev screen var          
      BEGIN          
         SET @cOutField01 = @cID          
             
         SET @cLottable01_Code = ''     
         SET @cLottable02_Code = ''     
         SET @cLottable03_Code = ''     
         SET @cLottable04_Code = ''     
             
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
           
         SET @cSKU = ''  
             
         SET @nScn = @nScn - 1          
         SET @nStep = @nStep - 1          
     END          
   END          
   GOTO Quit          
          
   Step_4_Fail:          
   BEGIN          
      SET @cLottable01_Code = ''     
      SET @cLottable02_Code = ''     
      SET @cLottable03_Code = ''     
      SET @cLottable04_Code = ''     
          
   END          
END          
GOTO Quit          
    
/********************************************************************************          
Step 5. Scn = 2914. SKU, QTY screen          
   LPN               (field01, input)          
   SKU               (field02, display)          
   STYLE, CLOR, SIZE (field03, display)          
   QTY               (field04, display)          
   LOTTABLES         (field05, display)          
********************************************************************************/          
Step_5:          
 BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN          
      -- Screen mapping          
      SET @cLPN = @cInField01    
    
      SELECT        
         @cLottable01 = CASE WHEN @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL THEN @cOutField06 ELSE '' END,         
         @cLottable02 = CASE WHEN @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL THEN @cOutField07 ELSE '' END,         
         @cLottable03 = CASE WHEN @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL THEN @cOutField08 ELSE '' END,         
         @cLottable04 = CASE WHEN @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL THEN @cOutField09 ELSE '' END     
    
      -- Validate UOM field          
      IF ISNULL(@cLPN, '') = ''     
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74078, @cLangCode, 'DSP') --'LPN is req'          
         GOTO Step_5_Fail          
      END          
  
      IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK)    
                 WHERE StorerKey = @cStorer    
                   AND UCCNo = @cLPN   
                   AND [STATUS] > '0')    
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74079, @cLangCode, 'DSP') --'LPN is Exists'          
         GOTO Step_5_Fail          
      END          
  
      -- (james07)  
      IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)    
                 WHERE StorerKey = @cStorer    
                   AND SKU = @cLPN )    
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74092, @cLangCode, 'DSP') --'SKU=LPN'          
         GOTO Step_5_Fail          
      END          
        
      SET @cReceiptPOKeyByLPN = ''    -- (ChewKP01)    
      SET @cReceiptPOKeyByLPN = rdt.RDTGetConfig( @nFunc, 'ReceiptPOKeyByLPN', @cStorer) -- (ChewKP01)    
      SET @POKeyByLPN = ''            -- (james01)  
        
      IF @cReceiptPOKeyByLPN = '1' -- (ChewKP01)    
      BEGIN    
       -- (Shong02) Change POKey Lookup  
         SELECT TOP 1 @POKeyByLPN = RD.POKey       -- (james01)  
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)    
         WHERE RD.ReceiptKey  = @cReceiptKey    
         AND RD.StorerKey     = @cStorer    
         AND RD.SKU           = @cSKU    
         AND RD.Lottable02    = @cLottable02   
         AND RD.POKey         = @cPOKey -- (ChewKP03)  
         ORDER BY CASE WHEN RD.QtyExpected >= (RD.BeforeReceivedQty + @nActQty) THEN 1 ELSE 2 END, RD.POKey, RD.POLineNumber  
     END     
          
      SET @nTranCount = @@TRANCOUNT    
    
      BEGIN TRAN    
      SAVE TRAN Confirm_UCCReceive    
    
      -- Not to set the POKEY = @POKeyByLPN because POKey can be NOPO  
      -- some checking will need to based on POKey = NOPO      (james01)  
      IF @POKeyByLPN = ''  
      BEGIN  
         EXEC dbo.nspRFRC01        
               @c_sendDelimiter = '|'        
            ,  @c_ptcid        = 'RDT'        
            ,  @c_userid       = 'RDT'        
            ,  @c_taskId       = 'RDT'        
            ,  @c_databasename = NULL        
            ,  @c_appflag      = null        
            ,  @c_recordType   = null        
            ,  @c_server       = null        
            ,  @c_receiptkey   = null        
            ,  @c_storerkey    = @cStorer        
            ,  @c_prokey       = @cReceiptKey        
            ,  @c_sku          = @cSKU        
            ,  @c_lottable01   = @cLottable01        
            ,  @c_lottable02   = @cLottable02        
            ,  @c_lottable03   = @cLottable03        
            ,  @d_lottable04   = @cLottable04        
            ,  @d_lottable05   = NULL        
            ,  @c_lot          = ''        
            ,  @c_pokey        = @cPOKey -- Can be 'NOPO'        
            ,  @n_qty          = @nActQty     
            ,  @c_uom          = @cUOM        
            ,  @c_packkey      = @cPackKey        
            ,  @c_loc          = @cLOC        
            ,  @c_id           = @cID        
            ,  @c_holdflag     = ''        
            ,  @c_other1       = ''        
            ,  @c_other2       = ''        
            ,  @c_other3       = ''         
            ,  @c_outstring    = @c_outstring  OUTPUT        
            ,  @b_Success      = @b_Success OUTPUT        
            ,  @n_err          = @n_err OUTPUT       
            ,  @c_errmsg       = @c_errmsg OUTPUT        
      END  
      ELSE  
      BEGIN  
         EXEC dbo.nspRFRC01        
               @c_sendDelimiter = '|'        
            ,  @c_ptcid        = 'RDT'        
            ,  @c_userid       = 'RDT'        
            ,  @c_taskId       = 'RDT'        
            ,  @c_databasename = NULL        
            ,  @c_appflag      = null        
            ,  @c_recordType   = null        
            ,  @c_server       = null        
            ,  @c_receiptkey   = null        
            ,  @c_storerkey    = @cStorer        
            ,  @c_prokey       = @cReceiptKey        
            ,  @c_sku          = @cSKU        
            ,  @c_lottable01   = @cLottable01        
            ,  @c_lottable02   = @cLottable02        
            ,  @c_lottable03   = @cLottable03        
            ,  @d_lottable04   = @cLottable04        
            ,  @d_lottable05   = NULL        
            ,  @c_lot          = ''        
            ,  @c_pokey        = @POKeyByLPN   
            ,  @n_qty          = @nActQty     
            ,  @c_uom   = @cUOM        
            ,  @c_packkey      = @cPackKey        
            ,  @c_loc          = @cLOC        
            ,  @c_id           = @cID        
            ,  @c_holdflag     = ''        
            ,  @c_other1       = ''        
            ,  @c_other2       = ''        
            ,  @c_other3       = ''         
            ,  @c_outstring    = @c_outstring  OUTPUT        
            ,  @b_Success      = @b_Success OUTPUT        
            ,  @n_err          = @n_err OUTPUT       
            ,  @c_errmsg       = @c_errmsg OUTPUT        
      END  
        
      IF @n_err <> 0    
      BEGIN          
         SET @cErrMsg = @c_errmsg     
         ROLLBACK TRAN Confirm_UCCReceive    
         GOTO Step_5_Fail          
      END     
      ELSE    
      BEGIN    
         
       INSERT INTO traceInfo (TraceName, TimeIn, [TimeOut], TotalTime, Col1, Col2, Col3)  
       VALUES ('InsertUCC', GETDATE(), GETDATE(), '',   
       [dbo].[fnc_GetDelimitedColumn] (@c_outstring, '|', 8),  
       [dbo].[fnc_GetDelimitedColumn] (@c_outstring, '|', 9),   
       LEFT(@cLPN, 20))  
   
         IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date      
         BEGIN                 
            SET @dLottable04 = CAST( @cLottable04 AS DATETIME)        
         END    
    
         -- Truncate the time portion    
         IF @dLottable04 IS NOT NULL    
            SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)    
    
         SET @cReceiptLineNo = ''    
         -- Get Receipt Line from RFRC01 OutString -- (ChewKP02)   
         SET @cReceiptLineNo = [dbo].[fnc_GetDelimitedColumn] (@c_outstring, '|', 9)   
           
           
--         SELECT TOP 1 @cReceiptLineNo = ReceiptLineNumber     
--         FROM dbo.ReceiptDetail WITH (NOLOCK)    
--         WHERE StorerKey = @cStorer    
--         AND ReceiptKey = @cReceiptKey    
--         AND POKey = CASE WHEN ISNULL(@cPOKey, '') = '' OR @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END    
--         AND TOLOC = @cLOC    
--         AND TOID = @cID    
--         AND SKU = @cSKU    
--         AND Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END    
--         AND Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN Lottable01 ELSE @cLottable02 END    
--         AND Lottable03 = CASE WHEN ISNULL(@cLottable03, '') = '' THEN Lottable01 ELSE @cLottable03 END    
--         AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)    
--         ORDER BY EditDate DESC        -- (james04)  
    
         -- Insert into UCC     
         IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK)    
                    WHERE StorerKey = @cStorer    
                      AND UCCNo = @cLPN)   
      BEGIN  
            UPDATE dbo.UCC   
               SET [STATUS] = '1',   
                   LOC = @cLOC,   
                   ReceiptKey = @cReceiptKey,   
                   ReceiptLineNumber = @cReceiptLineNo,   
                   ExternKey = @cPoKey,   
                   ID = @cID,             -- (james06)  
                   EditDate = GETDATE(),  -- (james06)   
                   EditWho = sUSER_NAME() -- (james06)  
            WHERE StorerKey = @cStorer    
              AND UCCNo = @cLPN  
              AND [Status] = '0'              
         END  
         ELSE  
         BEGIN  
            INSERT INTO dbo.UCC (StorerKey, UCCNo, Status, SKU, QTY, LOC, ID, ReceiptKey, ReceiptLineNumber,   
                                 ExternKey, SourceType)    
            VALUES (@cStorer, @cLPN, '1', @cSKU, @nActQTY, @cLOC, @cID, @cReceiptKey, @cReceiptLineNo,   
                    @cPoKey, 'UCCCarton_Receive')    
         END  
    
         IF @@ERROR <> 0    
         BEGIN    
            ROLLBACK TRAN Confirm_UCCReceive    
            SET @cErrMsg = rdt.rdtgetmessage( 74080, @cLangCode, 'DSP') --'INS UCC fail'          
            GOTO Step_5_Fail         
         END    
    
         -- (james03)  
         IF @nFunc = 1788 AND ISNULL(@cSubReasonCode, '') <> ''  
         BEGIN  
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET   
               SubReasonCode = CASE WHEN ISNULL(SubReasonCode, '') = ''   
                               THEN @cSubReasonCode ELSE SubReasonCode END,   
               Trafficcop = NULL  
            WHERE ReceiptKey = @cReceiptKey  
               AND ReceiptLineNumber = @cReceiptLineNo  
  
            IF @@ERROR <> 0  
            BEGIN    
               ROLLBACK TRAN Confirm_UCCReceive    
               SET @cErrMsg = rdt.rdtgetmessage( 74090, @cLangCode, 'DSP') --'INS UCC fail'          
               GOTO Step_5_Fail         
            END    
         END  
           
         SET @nLPNCount = @nLPNCount + 1    
         SET @cOutField01 = ''         -- LPN    
         SET @cOutField11 = RIGHT( '    ' + CAST(  @nLPNCount AS NVARCHAR( 5)), 5)    
      END    
    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN Confirm_UCCReceive    
   END -- Input = 1          
          
   IF @nInputKey = 0 -- Esc or No          
   BEGIN          
      IF (ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900')    
      BEGIN    
         SET @cLottable04 = ''    
      END    
    
      -- Init next screen var          
      SET @cOutField01 = @cSKU -- SKU    
      SET @cOutField02 = ''    -- Qty          
      SET @cOutField03 = 'LOTTABLE01:' -- LotLabel01          
      SET @cOutField04 = @cLottable01 -- Lottable01          
      SET @cOutField05 = 'LOTTABLE02:' -- LotLabel02          
      SET @cOutField06 = @cLottable02 -- Lottable02          
      SET @cOutField07 = 'LOTTABLE03:' -- LotLabel03          
      SET @cOutField08 = @cLottable03 -- Lottable03          
      SET @cOutField09 = 'LOTTABLE04:' -- LotLabel04          
 SET @cOutField10 = @cLottable04 -- Lottable04          
      SET @cOutField11 = 'LOTTABLE05:' -- LotLabel05          
      SET @cOutField12 = '' -- Lottable05          
    
      SET @cFieldAttr04 = CASE WHEN @cOutField04 = '' THEN 'O' ELSE '' END    
      SET @cFieldAttr06 = CASE WHEN @cOutField06 = '' THEN 'O' ELSE '' END    
      SET @cFieldAttr08 = CASE WHEN @cOutField08 = '' THEN 'O' ELSE '' END    
      SET @cFieldAttr10 = CASE WHEN @cOutField10 = '' THEN 'O' ELSE '' END    
      SET @cFieldAttr12 = CASE WHEN @cOutField12 = '' THEN 'O' ELSE '' END    
    
      SET @cInField03 = ''      
      SET @cInField06 = ''  
      SET @cInField08 = ''    
      SET @cInField10 = ''  
        
      SET @cDefaultLOT03 = ''    
      SET @cDefaultLOT03 = rdt.RDTGetConfig( @nFunc, 'DefaultLOT03', @cStorer)    
      IF ISNULL(@cDefaultLOT03, '') <> ''    
      BEGIN    
         SET @cOutField08 = @cDefaultLOT03    
         SET @cFieldAttr08 = ''    
      END    
    
      EXEC rdt.rdtSetFocusField @nMobile, 1    
         
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1          
   END          
   GOTO Quit          
          
   Step_5_Fail:          
   BEGIN          
      -- rollback didn't decrease @@trancount    
      -- COMMIT statements for such transaction     
      -- decrease @@TRANCOUNT by 1 without making updates permanent    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
    
      -- Retain the key-in value          
      SET @cLPN = ''    
      SET @cOutField01 = ''    
   END          
          
END          
GOTO Quit          
    
/********************************************************************************          
Step 6. Scn = 2915. LPN screen          
   LPN         (input)    
********************************************************************************/          
Step_6:          
BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN          
      -- Screen mapping          
      SET @cLPN = @cInField01    
      SET @cOption = @cInField12    
    
      SELECT        
         @cLottable01 = CASE WHEN @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL THEN @cOutField06 ELSE '' END,         
         @cLottable02 = CASE WHEN @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL THEN @cOutField07 ELSE '' END,         
         @cLottable03 = CASE WHEN @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL THEN @cOutField08 ELSE '' END,         
         @cLottable04 = CASE WHEN @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL THEN @cOutField09 ELSE '' END     
    
      -- Validate UOM field          
      IF ISNULL(@cLPN, '') = ''     
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74078, @cLangCode, 'DSP') --'LPN is req'          
         GOTO Step_5_Fail          
      END          
  
      -- (james07)  
      IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)    
                 WHERE StorerKey = @cStorer    
                   AND SKU = @cLPN )    
      BEGIN          
         SET @cErrMsg = rdt.rdtgetmessage( 74093, @cLangCode, 'DSP') --'SKU=LPN'          
         GOTO Step_5_Fail          
      END          
        
      IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK)    
                 WHERE StorerKey = @cStorer    
                 AND UCCNo = @cLPN)    
      BEGIN          
         -- If Option 2 (No change of LPN information) then need to check duplicate UCC    
         IF @cOption = '2'    
         BEGIN    
            SET @cErrMsg = rdt.rdtgetmessage( 74079, @cLangCode, 'DSP') --'LPN is Exists'          
            GOTO Step_5_Fail          
         END    
         ELSE    
         BEGIN    
            SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)    
            IF @cDecodeLabelNo = '0'    
            BEGIN    
               SET @cDecodeLabelNo = ''    
            END    
    
            -- If Decoding label setup then use decoding stored proc to get sku details    
            IF ISNULL(@cDecodeLabelNo, '') <> ''    
            BEGIN    
               SET @cErrMsg = ''    
               SET @nErrNo = 0    
               EXEC dbo.ispLabelNo_Decoding_Wrapper    
                   @c_SPName     = @cDecodeLabelNo    
                  ,@c_LabelNo    = @cLabelNo    
                  ,@c_Storerkey  = @cStorer    
                  ,@c_ReceiptKey = ''    
                  ,@c_POKey      = ''    
                  ,@c_LangCode  = @cLangCode   
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
                  ,@c_ErrMsg     = @cErrMsg     OUTPUT    
    
               IF @nErrNo <> 0    
               BEGIN    
                  SET @cLPN = ''    
                  GOTO Step_6_Fail    
               END    
    
               SET @cSKU = @c_oFieled01   -- SKU    
            END    
    
            -- (james02)  
            -- If the SKU has 0 cube OR if the SKU has 0 weight then prompt screen   
            -- show the message to measure the cube and weight with the Cubiscan  
            IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK)   
                       WHERE StorerKey = @cStorer  
                       AND SKU = @cSKU  
                       AND (ISNULL(Weight, 0) = 0 OR ISNULL(STDCUBE, 0) = 0))   
            BEGIN  
               SET @nErrNo = 0  
               SET @cErrMsg1 = @cSKU  
               SET @cErrMsg2 = ''  
               SET @cErrMsg3 = ''  
               SET @cErrMsg4 = 'PLEASE MEASURE THE'  
               SET @cErrMsg5 = 'CUBE AND WEIGHT FOR'  
               SET @cErrMsg6 = 'THIS SKU/LOT'  
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
               @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5, @cErrMsg6   
  
               IF @nErrNo = 1  
               BEGIN  
                  SET @cErrMsg1 = ''  
                  SET @cErrMsg2 = ''  
                  SET @cErrMsg3 = ''  
                  SET @cErrMsg4 = ''  
                  SET @cErrMsg5 = ''  
                  SET @cErrMsg6 = ''  
               END  
            END  
              
            SELECT @nActQty = Qty     
            FROM dbo.UCC WITH (NOLOCK)     
            WHERE StorerKey = @cStorer    
            AND UCCNo = @cLPN    
    
            -- Get SKU description, IVAS, lot label          
            SELECT          
               @cSKUDesc = IsNULL( DescR, ''),           
               @cPackKey = PackKey,     
               @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),           
               @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),           
               @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),           
               @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),          
               @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),           
               @cLottable05_Code = IsNULL( S.Lottable05Label, ''),          
               @cLottable01_Code = IsNULL(S.Lottable01Label, ''),            
               @cLottable02_Code = IsNULL(S.Lottable02Label, ''),            
               @cLottable03_Code = IsNULL(S.Lottable03Label, ''),            
               @cLottable04_Code = IsNULL(S.Lottable04Label, '')             
            FROM dbo.SKU S WITH (NOLOCK)          
            WHERE StorerKey = @cStorer          
               AND SKU = @cSKU          
    
            -- Populate Lottables    
            IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR           
               (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')          
            BEGIN          
               --initiate @nCounter = 1          
               SET @nCountLot = 1          
                
         --retrieve value for pre lottable01 - 05          
               WHILE @nCountLot <=5 --break the loop when @nCount >5          
               BEGIN          
                  IF @nCountLot = 1           
                  BEGIN          
                     SET @cListName = 'Lottable01'          
                     SET @cLottableLabel = @cLottable01_Code          
                  END          
                  ELSE          
                  IF @nCountLot = 2           
                  BEGIN          
                     SET @cListName = 'Lottable02'          
                     SET @cLottableLabel = @cLottable02_Code   
                  END          
                  ELSE          
                  IF @nCountLot = 3           
                  BEGIN          
                     SET @cListName = 'Lottable03'          
                     SET @cLottableLabel = @cLottable03_Code          
                  END          
                  ELSE          
                  IF @nCountLot = 4           
                  BEGIN          
                     SET @cListName = 'Lottable04'          
                     SET @cLottableLabel = @cLottable04_Code          
                  END          
                  ELSE          
                  IF @nCountLot = 5           
                  BEGIN          
                     SET @cListName = 'Lottable05'          
                     SET @cLottableLabel = @cLottable05_Code          
                  END          
             
                  --get short, store procedure and lottablelable value for each lottable          
                  SET @cShort = ''          
                  SET @cStoredProd = ''          
                  SELECT @cShort = ISNULL(RTRIM(C.Short),''),           
                       @cStoredProd = IsNULL(RTRIM(C.Long), '')          
                  FROM dbo.CodeLkUp C WITH (NOLOCK)           
                  JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)          
                WHERE C.ListName = @cListName          
                  AND   C.Code = @cLottableLabel          
                      
                  IF @cShort = 'PRE' AND @cStoredProd <> ''          
                  BEGIN          
                     IF @cListName = 'Lottable01'          
                        SET @cLottable01 = ''          
                     ELSE IF @cListName = 'Lottable02'          
                        SET @cLottable02 = ''          
                     ELSE IF @cListName = 'Lottable03'          
                        SET @cLottable03 = ''          
                     ELSE IF @cListName = 'Lottable04'          
                        SET @dLottable04 = ''          
                     ELSE IF @cListName = 'Lottable05'          
                        SET @dLottable05 = ''          
                
                     SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)          
                     WHERE StorerKey = @cStorer         
                        AND ReceiptKey = @cReceiptKey          
                        AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END          
                        AND SKU = @cSKU          
                        AND FinalizeFlag = 'N'          
                     ORDER BY ReceiptLinenumber          
             
                     SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')          
                
                     EXEC dbo.ispLottableRule_Wrapper          
                        @c_SPName            = @cStoredProd,          
                        @c_ListName          = @cListName,          
                        @c_Storerkey         = @cStorer,          
                        @c_Sku               = @cSKU,          
                        @c_LottableLabel     = @cLottableLabel,          
                        @c_Lottable01Value   = '',          
                        @c_Lottable02Value   = '',          
                        @c_Lottable03Value   = '',          
                        @dt_Lottable04Value  = '',          
                        @dt_Lottable05Value  = '',          
                        @c_Lottable01        = @cLottable01 OUTPUT,          
                        @c_Lottable02        = @cLottable02 OUTPUT,          
                        @c_Lottable03        = @cLottable03 OUTPUT,          
                        @dt_Lottable04       = @dLottable04 OUTPUT,          
                        @dt_Lottable05       = @dLottable05 OUTPUT,          
                        @b_Success           = @b_Success   OUTPUT,          
                        @n_Err               = @nErrNo      OUTPUT,          
                        @c_Errmsg   = @cErrMsg     OUTPUT,          
                        @c_Sourcekey         = @cSourcekey,          
                        @c_Sourcetype        = 'RDTRECEIPT'          
             
                     IF ISNULL(@cErrMsg, '') <> ''            
                     BEGIN          
                        SET @cErrMsg = @cErrMsg          
                        GOTO Step_6_Fail          
                        BREAK             
                     END            
             
                     SET @cLottable01 = IsNULL( @cLottable01, '')          
                     SET @cLottable02 = IsNULL( @cLottable02, '')          
                     SET @cLottable03 = IsNULL( @cLottable03, '')          
                     SET @dLottable04 = IsNULL( @dLottable04, 0)          
                     SET @dLottable05 = IsNULL( @dLottable05, 0)          
                              
                      IF @dLottable04 > 0          
                      BEGIN          
                         SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)          
                      END          
                 
                     IF @dLottable05 > 0          
                     BEGIN          
                        SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)          
                     END          
                  END          
                
                  -- increase counter by 1          
                  SET @nCountLot = @nCountLot + 1          
               END -- nCount          
            END -- Lottable <> ''          
    
            SET @cOutField01 = @cLPN      -- LPN    
            SET @cOutField02 = @cSKU      -- SKU    
            SET @cOutField03 = @nActQty   -- QTY    
    
            -- Init lot label        
            SELECT         
               @cOutField04 = 'Lottable01:',         
               @cOutField06 = 'Lottable02:',         
               @cOutField08 = 'Lottable03:',         
               @cOutField10 = 'Lottable04:'     
        
            -- Disable lot label and lottable field        
            IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL        
            BEGIN        
               SET @cFieldAttr05 = 'O'     
               SET @cOutField05 = ''        
            END        
            ELSE        
            BEGIN        
               -- Populate lot label and lottable        
               SELECT        
                @cOutField04 = @cLotLabel01,         
                  @cOutField05 = ISNULL(@cLottable01, '')     
            END        
        
            IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL        
            BEGIN        
               SET @cFieldAttr06 = 'O'     
              SET @cOutField06 = ''        
            END        
            ELSE        
            BEGIN        
               SELECT        
                  @cOutField05 = @cLotLabel02,         
                  @cOutField06 = ISNULL(@cLottable02, '')      
            END        
        
            IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL        
            BEGIN        
               SET @cFieldAttr08 = 'O'     
               SET @cOutField08 = ''        
            END        
            ELSE        
            BEGIN        
SELECT        
                  @cOutField07 = @cLotLabel03,         
                  @cOutField08 = ISNULL(@cLottable03, '')      
            END        
        
            IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL        
            BEGIN        
               SET @cFieldAttr10 = 'O'     
               SET @cOutField10 = ''        
            END        
            ELSE        
            BEGIN        
               SELECT        
                  @cOutField09 = @cLotLabel04,         
                  @cOutField10 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))         
            END        
    
            SET @cOutField12 = @nLPNCount      -- SCANNED    
    
            EXEC rdt.rdtSetFocusField @nMobile, 1    
               
            SET @nScn = @nScn + 1          
            SET @nStep = @nStep + 1          
         END    
      END          
      ELSE  -- LPN/UCC not exists    
      BEGIN    
         SELECT     
            @cSKU = SKU,     
            @nActQty = Qty     
         FROM dbo.UCC WITH (NOLOCK)     
         WHERE StorerKey = @cStorer    
         AND UCCNo = @cLPN    
    
         -- Get SKU description, IVAS, lot label          
         SELECT          
            @cSKUDesc = IsNULL( DescR, ''),           
            @cPackKey = PackKey,     
            @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),           
            @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),           
            @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),           
            @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),          
            @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),           
            @cLottable05_Code = IsNULL( S.Lottable05Label, ''),          
            @cLottable01_Code = IsNULL(S.Lottable01Label, ''),            
            @cLottable02_Code = IsNULL(S.Lottable02Label, ''),            
            @cLottable03_Code = IsNULL(S.Lottable03Label, ''),            
            @cLottable04_Code = IsNULL(S.Lottable04Label, '')             
         FROM dbo.SKU S WITH (NOLOCK)          
         WHERE StorerKey = @cStorer          
            AND SKU = @cSKU          
    
         -- Populate Lottables    
         IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR           
            (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')          
         BEGIN          
            --initiate @nCounter = 1          
            SET @nCountLot = 1          
             
            --retrieve value for pre lottable01 - 05          
          WHILE @nCountLot <=5 --break the loop when @nCount >5          
            BEGIN          
               IF @nCountLot = 1           
               BEGIN          
                  SET @cListName = 'Lottable01'          
 SET @cLottableLabel = @cLottable01_Code          
               END          
               ELSE          
               IF @nCountLot = 2           
               BEGIN          
                  SET @cListName = 'Lottable02'          
                  SET @cLottableLabel = @cLottable02_Code          
               END        
               ELSE          
               IF @nCountLot = 3           
               BEGIN          
                  SET @cListName = 'Lottable03'          
                  SET @cLottableLabel = @cLottable03_Code          
               END          
               ELSE          
               IF @nCountLot = 4           
               BEGIN          
                  SET @cListName = 'Lottable04'          
                  SET @cLottableLabel = @cLottable04_Code          
               END          
               ELSE          
               IF @nCountLot = 5           
               BEGIN          
                  SET @cListName = 'Lottable05'          
                  SET @cLottableLabel = @cLottable05_Code          
               END          
          
               --get short, store procedure and lottablelable value for each lottable          
               SET @cShort = ''          
               SET @cStoredProd = ''          
               SELECT @cShort = ISNULL(RTRIM(C.Short),''),     
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')          
               FROM dbo.CodeLkUp C WITH (NOLOCK)           
               JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)          
               WHERE C.ListName = @cListName          
               AND   C.Code = @cLottableLabel          
                   
               IF @cShort = 'PRE' AND @cStoredProd <> ''          
               BEGIN          
                  IF @cListName = 'Lottable01'          
                     SET @cLottable01 = ''          
                  ELSE IF @cListName = 'Lottable02'          
                     SET @cLottable02 = ''          
                  ELSE IF @cListName = 'Lottable03'          
                     SET @cLottable03 = ''          
                  ELSE IF @cListName = 'Lottable04'          
                     SET @dLottable04 = ''          
                  ELSE IF @cListName = 'Lottable05'          
                     SET @dLottable05 = ''          
             
                  SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)          
                  WHERE StorerKey = @cStorer         
                     AND ReceiptKey = @cReceiptKey          
                     AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END          
                     AND SKU = @cSKU          
                     AND FinalizeFlag = 'N'          
                  ORDER BY ReceiptLinenumber          
          
                  SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')          
             
                  EXEC dbo.ispLottableRule_Wrapper          
                     @c_SPName            = @cStoredProd,          
                     @c_ListName          = @cListName,          
                     @c_Storerkey         = @cStorer,          
                     @c_Sku               = @cSKU,          
                     @c_LottableLabel     = @cLottableLabel,          
                     @c_Lottable01Value   = '',          
                     @c_Lottable02Value   = '',          
                     @c_Lottable03Value   = '',          
                     @dt_Lottable04Value  = '',          
                     @dt_Lottable05Value  = '',          
                     @c_Lottable01        = @cLottable01 OUTPUT,      
                    @c_Lottable02        = @cLottable02 OUTPUT,          
                     @c_Lottable03        = @cLottable03 OUTPUT,          
                     @dt_Lottable04       = @dLottable04 OUTPUT,          
                     @dt_Lottable05       = @dLottable05 OUTPUT,          
                     @b_Success           = @b_Success   OUTPUT,          
                     @n_Err               = @nErrNo      OUTPUT,          
                     @c_Errmsg   = @cErrMsg     OUTPUT,          
                     @c_Sourcekey         = @cSourcekey,          
                @c_Sourcetype        = 'RDTRECEIPT'          
          
                  IF ISNULL(@cErrMsg, '') <> ''            
                  BEGIN          
                     SET @cErrMsg = @cErrMsg          
                     GOTO Step_6_Fail      
                     BREAK             
                  END            
          
                  SET @cLottable01 = IsNULL( @cLottable01, '')          
                  SET @cLottable02 = IsNULL( @cLottable02, '')          
                  SET @cLottable03 = IsNULL( @cLottable03, '')          
                  SET @dLottable04 = IsNULL( @dLottable04, 0)          
                  SET @dLottable05 = IsNULL( @dLottable05, 0)          
                           
                   IF @dLottable04 > 0          
                   BEGIN          
                      SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)          
                  END          
              
                  IF @dLottable05 > 0          
                  BEGIN          
                     SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)          
                  END          
               END          
             
               -- increase counter by 1          
               SET @nCountLot = @nCountLot + 1          
            END -- nCount          
         END -- Lottable <> ''          
    
         -- Get Lottable02. 1 PO 1 LOT02    
         IF ISNULL(@cPOKey, '') <> 'NOPO'    
         BEGIN    
            SELECT TOP 1 @cLottable02 = Lottable02     
            FROM dbo.PODetail WITH (NOLOCK)    
            WHERE StorerKey = @cStorer    
            AND POKey = @cPOKEY    
            AND SKU = @cSKU    
         END    
         ELSE    
         BEGIN    
            SELECT TOP 1 @cLottable02 = POD.Lottable02    
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)    
            JOIN dbo.PO PO WITH (NOLOCK) ON RD.POKey = PO.POKey    
            JOIN dbo.PODetail POD WITH (NOLOCK) ON PO.POKEY = POD.POKey    
            WHERE RD.StorerKey = @cStorer    
            AND RD.ReceiptKey = @cReceiptKey    
            AND POD.SKU = @cSKU    
         END    
    
         -- Get Lottable03    
         SET @cLottable03 = rdt.RDTGetConfig( @nFunc, 'DefaultLOT03', @cStorer)    
  
         SET @cReceiptPOKeyByLPN = ''    -- (ChewKP01)    
         SET @cReceiptPOKeyByLPN = rdt.RDTGetConfig( @nFunc, 'ReceiptPOKeyByLPN', @cStorer) -- (ChewKP01)    
         SET @POKeyByLPN = ''  
           
         IF @cReceiptPOKeyByLPN = '1' -- (ChewKP01)    
         BEGIN    
--            SELECT @POKeyByLPN = POKey FROM dbo.ReceiptDetail WITH (NOLOCK)    
--            WHERE ReceiptKey  = @cReceiptKey    
--            AND StorerKey     = @cStorer    
--            AND SKU           = @cSKU    
--            AND Lottable02    = @cLottable02    
  
          -- (Shong02) Change POKey Lookup  
            SELECT TOP 1 @POKeyByLPN = RD.POKey       -- (james01)  
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)    
            WHERE RD.ReceiptKey  = @cReceiptKey    
            AND RD.StorerKey     = @cStorer    
            AND RD.SKU           = @cSKU    
            AND RD.Lottable02    = @cLottable02   
            AND RD.POKey         = @cPOKey -- (ChewKP03)  
            ORDER BY CASE WHEN RD.QtyExpected >= (RD.BeforeReceivedQty + @nActQty) THEN 1 ELSE 2 END, RD.POKey, RD.POLineNumber  
         END     
  
         SET @nTranCount = @@TRANCOUNT    
    
         BEGIN TRAN    
         SAVE TRAN Confirm_UCCReceive    
  
    -- Not to set the POKEY = @POKeyByLPN because POKey can be NOPO  
         -- some checking will need to based on POKey = NOPO      (james01)  
         IF @POKeyByLPN = ''  
         BEGIN  
           
              
              
            EXEC dbo.nspRFRC01        
                  @c_sendDelimiter = null        
               ,  @c_ptcid        = 'RDT'        
               ,  @c_userid       = 'RDT'        
               ,  @c_taskId       = 'RDT'        
               ,  @c_databasename = NULL        
               ,  @c_appflag      = null        
               ,  @c_recordType   = null        
               ,  @c_server       = null        
               ,  @c_receiptkey   = null        
               ,  @c_storerkey    = @cStorer        
               ,  @c_prokey       = @cReceiptKey        
               ,  @c_sku          = @cSKU        
               ,  @c_lottable01   = @cLottable01        
               ,  @c_lottable02   = @cLottable02        
               ,  @c_lottable03   = @cLottable03        
               ,  @d_lottable04   = @cLottable04        
               ,  @d_lottable05   = NULL        
               ,  @c_lot          = ''        
               ,  @c_pokey        = @cPOKey -- can be 'NOPO'        
               ,  @n_qty          = @nActQty        
               ,  @c_uom          = @cUOM        
               ,  @c_packkey      = @cPackKey        
               ,  @c_loc          = @cLOC        
               ,  @c_id           = @cID        
               ,  @c_holdflag     = ''        
               ,  @c_other1       = ''        
               ,  @c_other2       = ''        
               ,  @c_other3       = ''      
               ,  @c_outstring    = @c_outstring  OUTPUT        
               ,  @b_Success      = @b_Success OUTPUT        
               ,  @n_err          = @n_err OUTPUT        
               ,  @c_errmsg       = @c_errmsg OUTPUT        
         END  
         ELSE  
         BEGIN  
              
              
              
            EXEC dbo.nspRFRC01        
                  @c_sendDelimiter = null        
               ,  @c_ptcid        = 'RDT'        
               ,  @c_userid       = 'RDT'        
               ,  @c_taskId       = 'RDT'        
               ,  @c_databasename = NULL        
               ,  @c_appflag      = null        
               ,  @c_recordType   = null        
               ,  @c_server       = null        
               ,  @c_receiptkey   = null        
               ,  @c_storerkey    = @cStorer        
               ,  @c_prokey       = @cReceiptKey        
               ,  @c_sku          = @cSKU        
               ,  @c_lottable01   = @cLottable01        
               ,  @c_lottable02   = @cLottable02        
               ,  @c_lottable03   = @cLottable03      
               ,  @d_lottable04   = @cLottable04        
               ,  @d_lottable05   = NULL        
               ,  @c_lot          = ''        
               ,  @c_pokey        = @POKeyByLPN   
               ,  @n_qty          = @nActQty        
               ,  @c_uom          = @cUOM        
               ,  @c_packkey      = @cPackKey        
               ,  @c_loc          = @cLOC        
               ,  @c_id           = @cID        
               ,  @c_holdflag     = ''        
               ,  @c_other1       = ''        
               ,  @c_other2       = ''        
               ,  @c_other3       = ''         
               ,  @c_outstring    = @c_outstring  OUTPUT        
               ,  @b_Success      = @b_Success OUTPUT        
               ,  @n_err          = @n_err OUTPUT        
               ,  @c_errmsg       = @c_errmsg OUTPUT       
         END  
           
         IF @n_err <> 0    
         BEGIN          
            SET @cErrMsg = @c_errmsg     
            ROLLBACK TRAN Confirm_UCCReceive    
            GOTO Step_6_Fail          
         END     
         ELSE    
         BEGIN    
            IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date      
            BEGIN                 
               SET @dLottable04 = CAST( @cLottable04 AS DATETIME)        
            END    
    
            -- Truncate the time portion    
            IF @dLottable04 IS NOT NULL    
               SET @dLottable04 = CONVERT( DATETIME, CONVERT( NVARCHAR( 10), @dLottable04, 120), 120)    
    
            SET @cReceiptLineNo = ''    
            -- Get Receipt Line from RFRC01 OutString -- (ChewKP02)   
            SET @cReceiptLineNo = [dbo].[fnc_GetDelimitedColumn] (@c_outstring, '|', 9)   
              
--            SELECT @cReceiptLineNo = MAX( ReceiptLineNumber)    
--            FROM dbo.ReceiptDetail WITH (NOLOCK)    
--            WHERE StorerKey = @cStorer    
--            AND ReceiptKey = @cReceiptKey    
--            AND POKey = CASE WHEN ISNULL(@cPOKey, '') = '' OR @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END    
--            AND TOLOC = @cLOC    
--            AND TOID = @cID    
--            AND SKU = @cSKU    
--            AND Lottable01 = CASE WHEN ISNULL(@cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END    
--            AND Lottable02 = CASE WHEN ISNULL(@cLottable02, '') = '' THEN Lottable01 ELSE @cLottable02 END    
--            AND Lottable03 = CASE WHEN ISNULL(@cLottable03, '') = '' THEN Lottable01 ELSE @cLottable03 END    
--            AND IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0)    
--            AND FinalizeFlag = 'Y'    
    
            -- Update UCC     
            UPDATE dbo.UCC WITH (ROWLOCK) SET     
               LOC = @cLOC,     
               ID = @cID,     
               ReceiptKey = @cReceiptKey,     
               ReceiptLineNumber = @cReceiptLineNo,     
               ExternKey = @cPoKey,     
               STATUS = '1',     
               EditDate = GETDATE(),     
               EditWho = sUSER_NAME()     
            WHERE StorerKey = @cStorer    
            AND UCCNo = @cLPN    
    
            IF @@ERROR <> 0    
            BEGIN    
               ROLLBACK TRAN Confirm_UCCReceive    
               SET @cErrMsg = rdt.rdtgetmessage( 74080, @cLangCode, 'DSP') --'INS UCC fail'          
               GOTO Step_6_Fail         
            END    
  
            -- (james03)  
            IF @nFunc = 1788 AND ISNULL(@cSubReasonCode, '') <> ''  
            BEGIN  
               UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET   
                  SubReasonCode = CASE WHEN ISNULL(SubReasonCode, '') = ''   
                                  THEN @cSubReasonCode ELSE SubReasonCode END,   
                  Trafficcop = NULL  
               WHERE ReceiptKey = @cReceiptKey  
                  AND ReceiptLineNumber = @cReceiptLineNo  
  
               IF @@ERROR <> 0  
               BEGIN    
                  ROLLBACK TRAN Confirm_UCCReceive    
                  SET @cErrMsg = rdt.rdtgetmessage( 74091, @cLangCode, 'DSP') --'INS UCC fail'          
                  GOTO Step_6_Fail         
               END    
            END  
         END    
    
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN Confirm_UCCReceive    
    
         SET @nLPNCount = @nLPNCount + 1    
    
         -- Prepare for next screen    
         SET @cOutField01 = ''      -- LPN    
         SET @cOutField02 = @cSKU      -- SKU    
    
         IF ISNULL(rdt.RDTGetConfig( 0, 'SHOWSTYLECOLORSIZE', @cStorer), '') = ''    
         BEGIN    
            SET @cOutField03 = 'STYLE/COLOR/SIZE:'     
            SET @cOutField04 = RTRIM(@cStyle) + '/' + RTRIM(@cColor) + '/' + RTRIM(@cSize)    
         END    
         ELSE    
         BEGIN    
            SET @cOutField03 = SUBSTRING(@cSKUDesc, 1, 20)    
            SET @cOutField04 = SUBSTRING(@cSKUDesc, 21, 20)    
         END    
    
         SET @cOutField05 = @nActQty   -- Qty    
          
         -- Disable lot label and lottable field          
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL          
         BEGIN          
            SET @cFieldAttr06 = 'O'     
            SET @cOutField06 = ''          
         END          
         ELSE          
         BEGIN          
  -- Populate lot label and lottable          
            SET @cOutField06 = ISNULL(@cLottable01, '')           
         END          
    
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL          
         BEGIN          
            SET @cFieldAttr07 = 'O'     
            SET @cOutField07 = ''          
         END          
         ELSE          
         BEGIN          
            SET @cOutField07 = ISNULL(@cLottable02, '')      
         END          
         
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL          
         BEGIN          
            SET @cFieldAttr08 = 'O'     
            SET @cOutField08 = ''    
         END          
         ELSE          
         BEGIN          
        SET @cOutField08 = ISNULL(@cLottable03, '')      
   END          
             
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL          
         BEGIN          
            SET @cFieldAttr09 = 'O'     
            SET @cOutField09 = ''       
         END          
         ELSE       
         BEGIN          
            SELECT @cOutField09 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))     
    
            -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan     
            IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'    
            BEGIN    
               SET @cOutField09 = ''    
            END    
         END          
          
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL              
         BEGIN           
            SET @cFieldAttr10 = 'O'     
            SET @cOutField10 = ''          
         END          
         ELSE          
         BEGIN          
            SELECT @cOutField10 = RDT.RDTFormatDate(@cLottable05)     
    
            -- Check if lottable05 is blank/is 01/01/1900 then default system date. User no need to scan (james07)    
            IF @cLottable05_Code = 'RCP_DATE' OR ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable05) = '1900/01/01'    
            BEGIN    
               SET @cOutField10 = RDT.RDTFormatDate( GETDATE())    
            END    
         END             
    
         SET @cOutField11 = RIGHT( '    ' + CAST(  @nLPNCount AS NVARCHAR( 5)), 5)      -- SCANNED    
         SET @cOutField12 = '2'      -- OPTION    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1          
   END    
   GOTO Quit          
    
   Step_6_Fail:    
   BEGIN    
      -- rollback didn't decrease @@trancount    
      -- COMMIT statements for such transaction     
 -- decrease @@TRANCOUNT by 1 without making updates permanent    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
    
      SET @cLPN = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************          
Step 7. Scn = 2916. Edit LPN          
   QTY    
   LOTTABLES    
********************************************************************************/          
Step_7:          
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN       
      SET @cActQty = @cInField01    
      SET @cLottable01 = @cInField05     
      SET @cLottable02 = @cInField07     
      SET @cLottable03 = @cInField08     
      SET @cLottable04 = @cInField11     
    
      -- Validate Qty    
      IF @cActQty = '0'    
      BEGIN    
         SET @cActQty = ''    
         SET @cErrMsg = rdt.rdtgetmessage( 74074, @cLangCode, 'DSP') --Invalid Qty    
         SET @cOutField01 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_7_Fail    
      END    
    
      IF @cActQty  = ''   SET @cActQty  = '0' --'Blank taken as zero'    
      IF RDT.rdtIsValidQTY( @cActQty, 1) = 0    
      BEGIN    
         SET @cActQty = ''    
         SET @cErrMsg = rdt.rdtgetmessage( 74075, @cLangCode, 'DSP') --'Invalid QTY'    
         SET @cOutField01 = ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_7_Fail    
      END    
    
      SET @nActQty = CAST(@cActQty AS INT)    
    
      SELECT        
         @cLottable01 = CASE WHEN @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL THEN @cInField02 ELSE '' END,         
         @cLottable02 = CASE WHEN @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL THEN @cInField04 ELSE '' END,         
         @cLottable03 = CASE WHEN @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL THEN @cInField06 ELSE '' END,         
         @cLottable04 = CASE WHEN @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL THEN @cInField08 ELSE '' END       
        
      --initiate @nCounter = 1        
      SET @nCountLot = 1        
        
      WHILE @nCountLot < = 5        
      BEGIN        
         IF @nCountLot = 1         
         BEGIN        
            SET @cListName = 'Lottable01'        
            SET @cLottableLabel = @cLottable01_Code        
         END        
         ELSE        
         IF @nCountLot = 2         
         BEGIN        
        SET @cListName = 'Lottable02'        
            SET @cLottableLabel = @cLottable02_Code        
         END        
         ELSE        
         IF @nCountLot = 3         
         BEGIN        
            SET @cListName = 'Lottable03'        
            SET @cLottableLabel = @cLottable03_Code        
         END        
         ELSE        
         IF @nCountLot = 4         
         BEGIN        
            SET @cListName = 'Lottable04'        
            SET @cLottableLabel = @cLottable04_Code        
         END        
         ELSE        
         IF @nCountLot = 5         
         BEGIN        
            SET @cListName = 'Lottable05'        
            SET @cLottableLabel = @cLottable05_Code        
         END        
        
         DECLARE @cTempSKU NVARCHAR(15)        
        
         SET @cShort = ''         
         SET @cStoredProd = ''        
         SET @cTempSKU = ''        
    
         SELECT @cShort = C.Short,         
         @cStoredProd = IsNULL( C.Long, '')        
         FROM dbo.CodeLkUp C WITH (NOLOCK)         
         WHERE C.Listname = @cListName        
         AND   C.Code = @cLottableLabel        
    
         IF @cShort = 'POST' AND @cStoredProd <> ''        
         BEGIN        
            IF rdt.rdtIsValidDate(@cLottable04) = 1 --valid date                   
               SET @dLottable04 = CAST( @cLottable04 AS DATETIME)        
        
            IF rdt.rdtIsValidDate(@cLottable05) = 1 --valid date        
               SET @dLottable05 = CAST( @cLottable05 AS DATETIME)        
        
            SELECT @cReceiptLineNo = ReceiptLineNumber     
            FROM dbo.UCC WITH (NOLOCK)    
            WHERE StorerKey = @cStorer    
            AND UCCNo = @cLPN    
    
            SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')        
        
            EXEC dbo.ispLottableRule_Wrapper        
               @c_SPName            = @cStoredProd,        
               @c_ListName          = @cListName,        
               @c_Storerkey         = @cStorer,        
               @c_Sku               = @cSku,        
               @c_LottableLabel     = @cLottableLabel,        
               @c_Lottable01Value   = @cLottable01,        
               @c_Lottable02Value   = @cLottable02,        
               @c_Lottable03Value   = @cLottable03,        
               @dt_Lottable04Value  = @dLottable04,        
               @dt_Lottable05Value  = @dLottable05,        
               @c_Lottable01        = @cTempLottable01 OUTPUT,        
               @c_Lottable02        = @cTempLottable02 OUTPUT,        
               @c_Lottable03        = @cTempLottable03 OUTPUT,        
               @dt_Lottable04       = @dTempLottable04 OUTPUT,        
               @dt_Lottable05       = @dTempLottable05 OUTPUT,        
               @b_Success           = @b_Success OUTPUT,        
               @n_Err               = @nErrNo      OUTPUT,        
               @c_Errmsg            = @cErrMsg     OUTPUT,        
               @c_Sourcekey         = @cSourcekey,        
               @c_Sourcetype        = 'RDTRECEIPT'         
        
            IF ISNULL(@cErrMsg, '') <> ''          
            BEGIN        
               SET @cErrMsg = @cErrMsg        
        
               IF @cListName = 'Lottable01'         
            EXEC rdt.rdtSetFocusField @nMobile, 4         
               ELSE IF @cListName = 'Lottable02'         
                  EXEC rdt.rdtSetFocusField @nMobile, 6         
               ELSE IF @cListName = 'Lottable03'         
                  EXEC rdt.rdtSetFocusField @nMobile, 8         
            ELSE IF @cListName = 'Lottable04'         
                  EXEC rdt.rdtSetFocusField @nMobile, 10         
    
               GOTO Step_7_Fail        
            END   
    
            SET @cTempLottable01 = IsNULL( @cTempLottable01, '')        
            SET @cTempLottable02 = IsNULL( @cTempLottable02, '')        
            SET @cTempLottable03 = IsNULL( @cTempLottable03, '')        
            SET @dTempLottable04 = IsNULL( @dTempLottable04, 0)        
            SET @dTempLottable05 = IsNULL( @dTempLottable05, 0)        
        
        
            SET @cOutField05 = CASE WHEN @cTempLottable01 <> '' THEN @cTempLottable01 ELSE @cLottable01 END        
            SET @cOutField07 = CASE WHEN @cTempLottable02 <> '' THEN @cTempLottable02 ELSE @cLottable02 END        
            SET @cOutField09 = CASE WHEN @cTempLottable03 <> '' THEN @cTempLottable03 ELSE @cLottable03 END        
            SET @cOutField11 = CASE WHEN @dTempLottable04 <> 0  THEN rdt.rdtFormatDate( @dTempLottable04) ELSE @cLottable04 END        
        
            SET @cLottable01 = IsNULL(@cOutField05, '')        
            SET @cLottable02 = IsNULL(@cOutField06, '')        
            SET @cLottable03 = IsNULL(@cOutField07, '')        
            SET @cLottable04 = IsNULL(@cOutField11, '')        
         END -- Short        
        
         --increase counter by 1        
         SET @nCountLot = @nCountLot + 1        
      END -- end of while        
        
      -- Validate lottable01        
      IF @cLotlabel01 <> '' AND @cLotlabel01 IS NOT NULL        
      BEGIN        
         IF @cLottable01 = '' OR @cLottable01 IS NULL        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( 60430, @cLangCode, 'DSP') --'Lottable01 required'        
            EXEC rdt.rdtSetFocusField @nMobile, 2        
            GOTO Step_7_Fail        
         END        
      END        
        
      -- Validate lottable02        
      IF @cLotlabel02 <> '' AND @cLotlabel02 IS NOT NULL        
      BEGIN        
         IF @cLottable02 = '' OR @cLottable02 IS NULL        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( 60431, @cLangCode, 'DSP') --'Lottable02 required'        
            EXEC rdt.rdtSetFocusField @nMobile, 4        
            GOTO Step_7_Fail        
         END        
      END        
        
      -- Validate lottable03        
      IF @cLotlabel03 <> '' AND @cLotlabel03 IS NOT NULL        
      BEGIN        
         IF @cLottable03 = '' OR @cLottable03 IS NULL        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( 60432, @cLangCode, 'DSP') --'Lottable03 required'        
            EXEC rdt.rdtSetFocusField @nMobile, 6        
            GOTO Step_7_Fail        
         END          
      END        
        
      -- Validate lottable04        
      IF @cLotlabel04 <> '' AND @cLotlabel04 IS NOT NULL        
      BEGIN        
         -- Validate empty        
       IF @cLottable04 = '' OR @cLottable04 IS NULL        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( 60433, @cLangCode, 'DSP') --'Lottable04 required'        
            EXEC rdt.rdtSetFocusField @nMobile, 8        
            GOTO Step_7_Fail        
         END        
        -- Validate date        
         IF RDT.rdtIsValidDate( @cLottable04) = 0        
         BEGIN        
            SET @cErrMsg = rdt.rdtgetmessage( 60434, @cLangCode, 'DSP') --'Invalid date'        
            EXEC rdt.rdtSetFocusField @nMobile, 8        
            GOTO Step_7_Fail        
         END        
      END        
    
      SET @nTranCount = @@TRANCOUNT    
    
      BEGIN TRAN    
      SAVE TRAN Edit_UCCReceive    
    
      SELECT @cReceiptLineNo = ReceiptLineNumber     
      FROM dbo.UCC WITH (NOLOCK)    
      WHERE StorerKey = @cStorer    
      AND UCCNo = @cLPN    
    
      -- Update UCC information    
      UPDATE dbo.UCC WITH (ROWLOCK) SET     
         Qty = @nActQty,     
  EditDate = GETDATE(),     
         EditWho = sUSER_sNAME()     
      WHERE StorerKey = @cStorer    
      AND UCCNo = @cLPN    
    
      IF @@ERROR <> 0    
      BEGIN    
         ROLLBACK TRAN Edit_UCCReceive    
     SET @cErrMsg = rdt.rdtgetmessage( 74082, @cLangCode, 'DSP') --UPD UCC failed    
         GOTO Step_7_Fail    
      END    
      ELSE    
      BEGIN    
         UPDATE ReceiptDetail WITH (ROWLOCK) SET     
            BeforeReceivedQty = BeforeReceivedQty - @nActQty,     
            Lottable01 = @cLottable01,     
            Lottable02 = @cLottable02,     
            Lottable03 = @cLottable03,     
            Lottable04 = @cLottable04     
         WHERE ReceiptKey = @cReceiptKey    
         AND ReceiptLineNumber = @cReceiptLineNo    
    
         IF @@ERROR <> 0    
         BEGIN    
            ROLLBACK TRAN Edit_UCCReceive    
            SET @cErrMsg = rdt.rdtgetmessage( 74082, @cLangCode, 'DSP') --UPD UCC failed    
            GOTO Step_7_Fail    
         END    
      END    
    
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
         COMMIT TRAN Edit_UCCReceive    
       
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1           
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN       
      SET @nScn = @nScn - 1          
      SET @nStep = @nStep - 1           
   END    
   GOTO Quit          
    
   Step_7_Fail:    
   BEGIN    
      -- rollback didn't decrease @@trancount    
      -- COMMIT statements for such transaction     
      -- decrease @@TRANCOUNT by 1 without making updates permanent    
      WHILE @@TRANCOUNT > @nTranCount    
         COMMIT TRAN    
   END    
END    
/********************************************************************************          
Step 8. Scn = 2917. Message          
   VAS INSTRUCTION    
********************************************************************************/          
Step_8:          
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN       
      SET @cVASStep = ''    
     SELECT TOP 1     
         @cVASStep = Step,     
         @cVASLineNumber = VASLineNumber     
      FROM dbo.VASDetail WITH (NOLOCK)     
      WHERE VASKey = @cVASKey AND VASLineNumber > @cVASLineNumber    
      ORDER BY VASLineNumber    
    
      -- If it is Last line in VASDetail then go back LPN screen    
      IF ISNULL(@cVASStep, '') = ''    
      BEGIN    
         -- Goto LPN screen    
         SET @nStep = @nStep - 3    
         SET @nScn = @nScn - 3    
    
         -- Prepare for LPN screen    
         SET @cDefaultLOT03 = ''    
         SET @cDefaultLOT03 = rdt.RDTGetConfig( @nFunc, 'DefaultLOT03', @cStorer)    
         IF ISNULL(@cDefaultLOT03, '') <> ''    
         BEGIN    
            -- Validate Lottable03    
            IF ISNULL(@cLottable03, '') = ''     
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74076, @cLangCode, 'DSP') --'Lottable03 required'          
               SET @cOutField01 = @cActQty    
               SET @cOutField02 = @cActSKU    
               EXEC rdt.rdtSetFocusField @nMobile, 8          
               GOTO Step_8_Fail          
            END            
    
            IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)     
                           WHERE ListName = 'QlityCode'    
                           AND CODE = @cLottable03)    
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74077, @cLangCode, 'DSP') --'Invalid Code'          
               SET @cOutField01 = @cActQty    
               SET @cOutField02 = @cActSKU    
               EXEC rdt.rdtSetFocusField @nMobile, 8          
               GOTO Step_8_Fail          
            END            
         END    
    
         SET @cAddSKUtoASN = ''          
         --SET @cAddSKUtoASN = rdt.RDTGetConfig( 0, 'RDTAddSKUtoASN', @cStorer)  
         --Pass in Function Number, so that they can enable for either Normal or Return            
         SET @cAddSKUtoASN = rdt.RDTGetConfig( @nFunc, 'RDTAddSKUtoASN', @cStorer)  
           
         -- Get SKU description, IVAS, lot label          
         SELECT          
            @cSKUDesc = IsNULL( DescR, ''),                     @cPackKey = PackKey,     
            @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),      
            @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),       
            @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),           
            @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),          
            @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),           
            @cLottable05_Code = IsNULL( S.Lottable05Label, ''),          
            @cLottable01_Code = IsNULL(S.Lottable01Label, ''),            
            @cLottable02_Code = IsNULL(S.Lottable02Label, ''),            
            @cLottable03_Code = IsNULL(S.Lottable03Label, ''),            
            @cLottable04_Code = IsNULL(S.Lottable04Label, '')             
         FROM dbo.SKU S WITH (NOLOCK)          
         WHERE StorerKey = @cStorer          
            AND SKU = @cSKU          
    
         -- Populate Lottables    
         IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR           
            (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')          
         BEGIN          
            
            --initiate @nCounter = 1          
            SET @nCountLot = 1          
             
            --retrieve value for pre lottable01 - 05          
            WHILE @nCountLot <=5 --break the loop when @nCount >5          
           BEGIN          
               IF @nCountLot = 1           
               BEGIN          
                  SET @cListName = 'Lottable01'          
                  SET @cLottableLabel = @cLottable01_Code          
               END          
               ELSE          
               IF @nCountLot = 2           
               BEGIN          
                  SET @cListName = 'Lottable02'          
                  SET @cLottableLabel = @cLottable02_Code          
               END          
               ELSE          
               IF @nCountLot = 3           
               BEGIN          
                  SET @cListName = 'Lottable03'          
                  SET @cLottableLabel = @cLottable03_Code          
           END          
               ELSE          
               IF @nCountLot = 4           
               BEGIN          
                  SET @cListName = 'Lottable04'          
                  SET @cLottableLabel = @cLottable04_Code          
               END          
               ELSE          
               IF @nCountLot = 5           
               BEGIN          
                  SET @cListName = 'Lottable05'          
                  SET @cLottableLabel = @cLottable05_Code          
               END          
  
               --get short, store procedure and lottablelable value for each lottable          
               SET @cShort = ''          
               SET @cStoredProd = ''          
               SELECT @cShort = ISNULL(RTRIM(C.Short),''),           
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')          
               FROM dbo.CodeLkUp C WITH (NOLOCK)           
               JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)          
               WHERE C.ListName = @cListName        
               AND   C.Code = @cLottableLabel          
                      
               IF @cShort = 'PRE' AND @cStoredProd <> ''          
               BEGIN          
                  IF @cListName = 'Lottable01'          
                     SET @cLottable01 = ''          
                  ELSE IF @cListName = 'Lottable02'          
                     SET @cLottable02 = ''          
                  ELSE IF @cListName = 'Lottable03'          
                     SET @cLottable03 = ''          
                  ELSE IF @cListName = 'Lottable04'      
                     SET @dLottable04 = ''          
                  ELSE IF @cListName = 'Lottable05'          
                     SET @dLottable05 = ''          
             
                  SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)          
                  WHERE StorerKey = @cStorer         
                     AND ReceiptKey = @cReceiptKey          
                     AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END          
                     AND SKU = @cSKU          
                     AND FinalizeFlag = 'N'          
                  ORDER BY ReceiptLinenumber          
             
                  SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')          
             
                  EXEC dbo.ispLottableRule_Wrapper          
                     @c_SPName            = @cStoredProd,          
                     @c_ListName          = @cListName,          
                     @c_Storerkey         = @cStorer,          
                     @c_Sku               = @cSKU,          
                     @c_LottableLabel     = @cLottableLabel,          
                     @c_Lottable01Value   = '',          
                     @c_Lottable02Value   = '',          
                     @c_Lottable03Value   = '',          
                     @dt_Lottable04Value  = '',          
                     @dt_Lottable05Value  = '',          
                     @c_Lottable01        = @cLottable01 OUTPUT,          
                     @c_Lottable02        = @cLottable02 OUTPUT,          
                     @c_Lottable03        = @cLottable03 OUTPUT,          
                     @dt_Lottable04       = @dLottable04 OUTPUT,          
                     @dt_Lottable05       = @dLottable05 OUTPUT,          
                     @b_Success           = @b_Success   OUTPUT,          
                     @n_Err               = @nErrNo      OUTPUT,          
                     @c_Errmsg   = @cErrMsg     OUTPUT,          
                     @c_Sourcekey         = @cSourcekey,          
                     @c_Sourcetype        = 'RDTRECEIPT'          
             
                  IF ISNULL(@cErrMsg, '') <> ''            
                  BEGIN          
                     SET @cErrMsg = @cErrMsg          
                    GOTO Step_8_Fail          
                     BREAK             
                  END            
             
                  SET @cLottable01 = IsNULL( @cLottable01, '')          
                  SET @cLottable02 = IsNULL( @cLottable02, '')          
                  SET @cLottable03 = IsNULL( @cLottable03, '')          
                  SET @dLottable04 = IsNULL( @dLottable04, 0)          
                  SET @dLottable05 = IsNULL( @dLottable05, 0)          
                           
                   IF @dLottable04 > 0          
                   BEGIN          
                      SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)          
                   END          
              
                  IF @dLottable05 > 0          
                  BEGIN          
                     SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)          
                  END          
               END          
             
               -- increase counter by 1          
     SET @nCountLot = @nCountLot + 1          
            END -- nCount          
       END -- Lottable <> ''          
             
         -- Init lot label          
         SET @cOutField01 = ''      -- LPN    
         SET @cOutField02 = @cSKU   -- SKU    
    
         IF ISNULL(rdt.RDTGetConfig( 0, 'SHOWSTYLECOLORSIZE', @cStorer), '') = ''    
         BEGIN    
            SET @cOutField03 = 'STYLE/COLOR/SIZE:'     
  SET @cOutField04 = RTRIM(@cStyle) + '/' + RTRIM(@cColor) + '/' + RTRIM(@cSize)    
        END    
         ELSE    
         BEGIN    
            SET @cOutField03 = SUBSTRING(@cSKUDesc, 1, 20)    
            SET @cOutField04 = SUBSTRING(@cSKUDesc, 21, 20)    
         END    
    
         SET @cOutField05 = @nActQty   -- Qty    
          
         -- Disable lot label and lottable field          
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL          
         BEGIN          
            SET @cFieldAttr06 = 'O'     
            SET @cOutField06 = ''          
         END          
         ELSE          
         BEGIN          
            -- Populate lot label and lottable          
            SET @cOutField06 = ISNULL(@cLottable01, '')           
         END          
    
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL          
         BEGIN          
            SET @cFieldAttr07 = 'O'     
            SET @cOutField07 = ''          
         END          
         ELSE          
         BEGIN          
            SET @cOutField07 = ISNULL(@cLottable02, '')      
         END          
          
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL          
         BEGIN          
            SET @cFieldAttr08 = 'O'     
            SET @cOutField08 = ''    
         END          
         ELSE          
         BEGIN          
            SET @cOutField08 = ISNULL(@cLottable03, '')      
         END          
             
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL          
         BEGIN          
            SET @cFieldAttr09 = 'O'     
            SET @cOutField09 = ''          
         END          
         ELSE          
         BEGIN          
            SELECT @cOutField09 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))     
    
            -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan     
            IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'    
            BEGIN    
               SET @cOutField09 = ''    
            END    
         END          
          
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL              
         BEGIN           
            SET @cFieldAttr10 = 'O'     
            SET @cOutField10 = ''          
         END          
         ELSE          
         BEGIN          
            SELECT @cOutField10 = RDT.RDTFormatDate(@cLottable05)     
    
            -- Check if lottable05 is blank/is 01/01/1900 then default system date. User no need to scan (james07)    
            IF @cLottable05_Code = 'RCP_DATE' OR ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable05) = '1900/01/01'    
            BEGIN    
               SET @cOutField10 = RDT.RDTFormatDate( GETDATE())    
            END    
         END             
    
         SET @nLPNCount = 0    
         SET @cOutField11 = RIGHT( '    ' + CAST(  '0' AS NVARCHAR( 5)), 5)    
    
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LPN          
         GOTO Quit          
      END    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField06 = ''    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''    
    
      SET @cOutField01 = CAST(@cVASLineNumber AS INT)    
      SET @cOutField02 = SUBSTRING(@cVASStep,   1, 20)    
      SET @cOutField03 = SUBSTRING(@cVASStep,  21, 20)    
      SET @cOutField04 = SUBSTRING(@cVASStep,  41, 20)    
      SET @cOutField05 = SUBSTRING(@cVASStep,  61, 20)   
      SET @cOutField06 = SUBSTRING(@cVASStep,  81, 20)    
      SET @cOutField07 = SUBSTRING(@cVASStep, 101, 20)    
      SET @cOutField08 = SUBSTRING(@cVASStep, 121,  8)    
   END    
    
   IF @nInputKey = 0 -- Esc or No          
   BEGIN       
      SET @cVASStep = ''    
      SELECT TOP 1     
         @cVASStep = Step,     
         @cVASLineNumber = VASLineNumber     
      FROM dbo.VASDetail WITH (NOLOCK)     
      WHERE VASKey = @cVASKey AND VASLineNumber < @cVASLineNumber    
      ORDER BY VASLineNumber DESC    
    
      -- If it is 1st line in VASDetail then go back LPN screen    
      IF ISNULL(@cVASStep, '') = ''    
      BEGIN    
         -- Goto LPN screen    
         SET @nStep = @nStep - 3    
         SET @nScn = @nScn - 3    
    
         -- Prepare for LPN screen    
         SET @cDefaultLOT03 = ''    
         SET @cDefaultLOT03 = rdt.RDTGetConfig( @nFunc, 'DefaultLOT03', @cStorer)    
         IF ISNULL(@cDefaultLOT03, '') <> ''    
         BEGIN    
            -- Validate Lottable03    
            IF ISNULL(@cLottable03, '') = ''     
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74076, @cLangCode, 'DSP') --'Lottable03 required'          
               SET @cOutField01 = @cActQty    
               SET @cOutField02 = @cActSKU    
               EXEC rdt.rdtSetFocusField @nMobile, 8          
               GOTO Step_8_Fail          
            END            
    
            IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)     
                           WHERE ListName = 'QlityCode'    
                           AND CODE = @cLottable03)    
            BEGIN          
               SET @cErrMsg = rdt.rdtgetmessage( 74077, @cLangCode, 'DSP') --'Invalid Code'          
               SET @cOutField01 = @cActQty    
               SET @cOutField02 = @cActSKU    
               EXEC rdt.rdtSetFocusField @nMobile, 8          
               GOTO Step_8_Fail          
            END            
         END    
    
         SET @cAddSKUtoASN = ''          
         --SET @cAddSKUtoASN = rdt.RDTGetConfig( 0, 'RDTAddSKUtoASN', @cStorer)  
         --Pass in Function Number, so that they can enable for either Normal or Return  
         SET @cAddSKUtoASN = rdt.RDTGetConfig( @nFunc, 'RDTAddSKUtoASN', @cStorer)  
                     
             
         -- Get SKU description, IVAS, lot label          
         SELECT          
           @cSKUDesc = IsNULL( DescR, ''),           
            @cPackKey = PackKey,     
            @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),           
            @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),           
            @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),           
            @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),          
            @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C WITH (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),           
            @cLottable05_Code = IsNULL( S.Lottable05Label, ''),          
            @cLottable01_Code = IsNULL(S.Lottable01Label, ''),            
            @cLottable02_Code = IsNULL(S.Lottable02Label, ''),            
         @cLottable03_Code = IsNULL(S.Lottable03Label, ''),            
            @cLottable04_Code = IsNULL(S.Lottable04Label, '')             
         FROM dbo.SKU S WITH (NOLOCK)          
         WHERE StorerKey = @cStorer          
            AND SKU = @cSKU          
    
         -- Populate Lottables    
         IF (IsNULL(@cLottable01_Code, '') <> '') OR (IsNULL(@cLottable02_Code, '') <> '') OR (IsNULL(@cLottable03_Code, '') <> '') OR           
            (IsNULL(@cLottable04_Code, '') <> '') OR (IsNULL(@cLottable05_Code, '') <> '')          
         BEGIN          
            
            --initiate @nCounter = 1          
            SET @nCountLot = 1          
             
            --retrieve value for pre lottable01 - 05          
            WHILE @nCountLot <=5 --break the loop when @nCount >5          
            BEGIN          
    IF @nCountLot = 1           
               BEGIN          
                  SET @cListName = 'Lottable01'          
                  SET @cLottableLabel = @cLottable01_Code          
               END          
  ELSE          
               IF @nCountLot = 2           
               BEGIN          
                  SET @cListName = 'Lottable02'          
                  SET @cLottableLabel = @cLottable02_Code     
               END          
               ELSE          
               IF @nCountLot = 3           
               BEGIN          
                  SET @cListName = 'Lottable03'          
                  SET @cLottableLabel = @cLottable03_Code          
               END          
               ELSE          
               IF @nCountLot = 4           
               BEGIN          
                  SET @cListName = 'Lottable04'          
                  SET @cLottableLabel = @cLottable04_Code          
               END          
               ELSE          
               IF @nCountLot = 5           
               BEGIN          
                  SET @cListName = 'Lottable05'          
                  SET @cLottableLabel = @cLottable05_Code          
               END          
             
               --get short, store procedure and lottablelable value for each lottable          
               SET @cShort = ''          
               SET @cStoredProd = ''          
               SELECT @cShort = ISNULL(RTRIM(C.Short),''),           
                    @cStoredProd = IsNULL(RTRIM(C.Long), '')          
               FROM dbo.CodeLkUp C WITH (NOLOCK)           
               JOIN RDT.StorerConfig S WITH (NOLOCK) ON (C.ListName = S.ConfigKey AND C.Code = S.SValue)          
               WHERE C.ListName = @cListName          
               AND   C.Code = @cLottableLabel          
                      
               IF @cShort = 'PRE' AND @cStoredProd <> ''          
               BEGIN          
                  IF @cListName = 'Lottable01'          
                     SET @cLottable01 = ''          
                  ELSE IF @cListName = 'Lottable02'          
                     SET @cLottable02 = ''          
                  ELSE IF @cListName = 'Lottable03'          
                     SET @cLottable03 = ''          
                  ELSE IF @cListName = 'Lottable04'          
                     SET @dLottable04 = ''          
                  ELSE IF @cListName = 'Lottable05'          
                     SET @dLottable05 = ''          
             
                  SELECT TOP 1 @cReceiptLineNo = ReceiptLinenumber FROM dbo.ReceiptDetail WITH (NOLOCK)          
                  WHERE StorerKey = @cStorer         
                     AND ReceiptKey = @cReceiptKey          
                     AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END          
                     AND SKU = @cSKU          
                     AND FinalizeFlag = 'N'          
                  ORDER BY ReceiptLinenumber          
             
                  SET @cSourcekey = ISNULL(RTRIM(@cReceiptKey), '') + ISNULL(RTRIM(@cReceiptLineNo), '')          
             
                  EXEC dbo.ispLottableRule_Wrapper          
                     @c_SPName            = @cStoredProd,          
                     @c_ListName          = @cListName,          
                     @c_Storerkey         = @cStorer,          
                     @c_Sku               = @cSKU,          
                     @c_LottableLabel    = @cLottableLabel,          
                     @c_Lottable01Value   = '',          
                     @c_Lottable02Value   = '',          
                     @c_Lottable03Value   = '',          
                     @dt_Lottable04Value  = '',          
                     @dt_Lottable05Value  = '',          
                     @c_Lottable01        = @cLottable01 OUTPUT,   
                     @c_Lottable02        = @cLottable02 OUTPUT,          
                     @c_Lottable03        = @cLottable03 OUTPUT,          
                     @dt_Lottable04       = @dLottable04 OUTPUT,   
                     @dt_Lottable05       = @dLottable05 OUTPUT,          
                     @b_Success           = @b_Success   OUTPUT,          
                     @n_Err               = @nErrNo      OUTPUT,          
                     @c_Errmsg   = @cErrMsg     OUTPUT,          
                     @c_Sourcekey         = @cSourcekey,          
                     @c_Sourcetype        = 'RDTRECEIPT'          
             
                  IF ISNULL(@cErrMsg, '') <> ''            
                  BEGIN          
                     SET @cErrMsg = @cErrMsg          
                     GOTO Step_8_Fail          
                     BREAK             
                  END            
             
                  SET @cLottable01 = IsNULL( @cLottable01, '')          
                  SET @cLottable02 = IsNULL( @cLottable02, '')          
                  SET @cLottable03 = IsNULL( @cLottable03, '')          
                  SET @dLottable04 = IsNULL( @dLottable04, 0)          
                  SET @dLottable05 = IsNULL( @dLottable05, 0)          
                           
                   IF @dLottable04 > 0          
                   BEGIN          
                      SET @cLottable04 = RDT.RDTFormatDate(@dLottable04)          
                   END          
              
                  IF @dLottable05 > 0          
                  BEGIN          
                     SET @cLottable05 = RDT.RDTFormatDate(@dLottable05)          
                  END          
               END          
             
               -- increase counter by 1          
               SET @nCountLot = @nCountLot + 1          
            END -- nCount          
         END -- Lottable <> ''          
             
         -- Init lot label          
         SET @cOutField01 = ''      -- LPN    
     SET @cOutField02 = @cSKU   -- SKU    
    
         IF ISNULL(rdt.RDTGetConfig( 0, 'SHOWSTYLECOLORSIZE', @cStorer), '') = ''    
         BEGIN    
            SET @cOutField03 = 'STYLE/COLOR/SIZE:'     
            SET @cOutField04 = RTRIM(@cStyle) + '/' + RTRIM(@cColor) + '/' + RTRIM(@cSize)    
         END    
         ELSE    
         BEGIN    
            SET @cOutField03 = SUBSTRING(@cSKUDesc, 1, 20)    
            SET @cOutField04 = SUBSTRING(@cSKUDesc, 21, 20)    
         END    
    
         SET @cOutField05 = @nActQty   -- Qty    
          
         -- Disable lot label and lottable field          
   IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL          
         BEGIN          
            SET @cFieldAttr06 = 'O'     
            SET @cOutField06 = ''          
         END          
         ELSE          
         BEGIN          
            -- Populate lot label and lottable          
            SET @cOutField06 = ISNULL(@cLottable01, '')           
         END          
    
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL          
         BEGIN          
            SET @cFieldAttr07 = 'O'     
            SET @cOutField07 = ''          
         END          
         ELSE          
         BEGIN          
            SET @cOutField07 = ISNULL(@cLottable02, '')      
         END          
          
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL          
         BEGIN          
            SET @cFieldAttr08 = 'O'     
            SET @cOutField08 = ''    
         END          
         ELSE          
         BEGIN          
            SET @cOutField08 = ISNULL(@cLottable03, '')      
         END          
             
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL          
         BEGIN          
            SET @cFieldAttr09 = 'O'     
            SET @cOutField09 = ''          
         END          
         ELSE          
         BEGIN          
            SELECT @cOutField09 = RDT.RDTFormatDate(ISNULL(@cLottable04, ''))     
    
            -- Check if lottable04 is blank/is 01/01/1900 then no need to default anything and let user to scan     
            IF ISNULL(@cLottable04, '') = '' OR RDT.RDTFormatDate(@cLottable04) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable04) = '1900/01/01'    
            BEGIN    
               SET @cOutField09 = ''    
            END    
         END          
          
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL              
         BEGIN           
            SET @cFieldAttr10 = 'O'     
            SET @cOutField10 = ''          
         END          
         ELSE          
         BEGIN          
            SELECT @cOutField10 = RDT.RDTFormatDate(@cLottable05)     
    
            -- Check if lottable05 is blank/is 01/01/1900 then default system date. User no need to scan (james07)    
            IF @cLottable05_Code = 'RCP_DATE' OR ISNULL(@cLottable05, '') = '' OR RDT.RDTFormatDate(@cLottable05) = '01/01/1900' OR RDT.RDTFormatDate(@cLottable05) = '1900/01/01'    
            BEGIN    
               SET @cOutField10 = RDT.RDTFormatDate( GETDATE())    
            END    
         END             
    
         SET @nLPNCount = 0    
         SET @cOutField11 = RIGHT( '    ' + CAST(  '0' AS NVARCHAR( 5)), 5)    
    
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- LPN         
         GOTO Quit    
      END    
    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField06 = ''    
      SET @cOutField07 = ''    
      SET @cOutField08 = ''    
    
      SET @cOutField01 = CAST(@cVASLineNumber AS INT)    
      SET @cOutField02 = SUBSTRING(@cVASStep,   1, 20)    
      SET @cOutField03 = SUBSTRING(@cVASStep,  21, 20)    
      SET @cOutField04 = SUBSTRING(@cVASStep,  41, 20)    
      SET @cOutField05 = SUBSTRING(@cVASStep,  61, 20)    
      SET @cOutField06 = SUBSTRING(@cVASStep,  81, 20)    
      SET @cOutField07 = SUBSTRING(@cVASStep, 101, 20)    
      SET @cOutField08 = SUBSTRING(@cVASStep, 121,  8)    
   END    
   GOTO Quit          
    
   Step_8_Fail:    
END    
Goto Quit    
    
/********************************************************************************          
Quit. Update back to I/O table, ready to be pick up by JBOSS          
********************************************************************************/          
Quit:          
BEGIN       
   SET @cInField01 =''  
   SET @cInField02 =''  
   SET @cInField03 =''  
   SET @cInField04 =''  
   SET @cInField05 =''  
   SET @cInField06 =''  
   SET @cInField07 =''  
   SET @cInField08 =''  
   SET @cInField09 =''  
   SET @cInField10 =''  
   SET @cInField11 =''  
   SET @cInField12 =''  
   SET @cInField13 =''  
   SET @cInField14 =''  
   SET @cInField15 =''  
  
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET           
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg,           
      Func   = @nFunc,          
      Step   = @nStep,          
      Scn    = @nScn,          
          
      StorerKey     = @cStorer,             
      Facility      = @cFacility,           
      Printer       = @cPrinter,              
      -- UserName      = @cUserName,           
          
      V_ReceiptKey = @cReceiptKey,           
      V_POKey      = @cPOKey,           
      V_Loc        = @cLOC,           
      V_SKU        = @cSKU,           
      V_UOM        = @cUOM,           
      V_ID         = @cID,           
      V_QTY        = @nActQty,                
      V_SKUDescr   = @cSKUDesc,               
          
      V_Lottable01 = @cLottable01,           
      V_Lottable02 = @cLottable02,           
      V_Lottable03 = @cLottable03,           
      V_Lottable04 = @cLottable04,           
      V_Lottable05 = @cLottable05,           
    
          
      V_String1    = @cPOKeyDefaultValue,           
      V_String2    = @cAddSKUtoASN,                 
      V_String3    = @cExternPOKey,                 
      V_String4    = @cExternLineNo,                
      V_String5    = @cExternReceiptKey,          
      V_String6    = @cReceiptLineNo,               
      V_String7    = @cPrefUOM,                     
      V_String8    = @cPrevID,      
      V_String9    = @cVASKey,    
      V_String10   = @cVASLineNumber,    
      V_String11   = @nLPNCount,          
      V_String12   = @nCurrStep,    
      V_String13   = @nCurrScn,    
    
      V_String14  = @cLottable01_Code,           
      V_String15   = @cLottable02_Code,           
      V_String16   = @cLottable03_Code,           
      V_String17   = @cLottable04_Code,           
      V_String18   = @cLottable05_Code,           
                
      V_String20   = @cReasonCode,            
      V_String21   = @cSubReasonCode,      -- (james03)            
      V_String22   = @cLotLabel01,            
      V_String23   = @cLotLabel02,            
      V_String24   = @cLotLabel03,            
      V_String25   = @cLotLabel04,            
      V_String26   = @cLotLabel05,            
      V_String27   = @cPackKey,               
          
      V_String29   = @cPrevOp,                
      V_String30   = @cScnOption,             
      V_String31   = @cAutoGenID,             
      V_String32   = @cPromptOpScn,           
      V_String37   = @cPromptVerifyPKScn,           
      V_String38   = @cDefaultToLoc,                
      V_String39   = @cQty,                         
      V_String40   = @nPOCount,               
          
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
          
   SET @cSKUDesc = rdt.rdtReplaceSpecialCharInXMLData( @cSKUDesc)          
END 
    



GO