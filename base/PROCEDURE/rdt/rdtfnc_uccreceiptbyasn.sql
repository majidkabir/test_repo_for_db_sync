SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdtfnc_UCCReceiptByASN                              */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: UCC Return                                                  */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2006-03-01 1.0  jwong    Created                                     */  
/* 2006-10-17 1.1  jwong    a) change scan sku part so that it can      */  
/*                             incorporate barcode feature like         */  
/*                             'altsku' or 'upc'                        */   
/*                          b) change displayed qty based on uom3       */     
/* 2007-01-29 1.2 James     c) sos#65746 Add Lottable01 - 05            */  
/* 2007-03-30 1.3 James     d) use rdt_receive as receipt lookup logic  */  
/* 2008-09-03 1.4 Vicky     Modify to cater for SQL2005 (Vicky01)       */  
/* 2008-11-03 1.5 Vicky     Remove XML part of code that is used to     */  
/*                          make field invisible and replace with new   */  
/*                          code (Vicky02)                              */  
/* 2009-10-12 1.6 Vicky     Add in isValidQTY function when parsing     */  
/*                          value to "int" variable (Vicky03)           */  
/* 2010-01-26 1.7 James     SOS203624 - Bug fix (james01)               */  
/* 2010-02-21 1.8 James     Performance tuning (james02)                */  
/* 2015-01-16 1.9 CSCHONG   New lottable 05 to 15 (CS01)                */  
/* 22-MAR-2017   2.0  JayLim  SQL2012 compatibility modification (Jay01)*/  
/************************************************************************/  
CREATE PROC [RDT].[rdtfnc_UCCReceiptByASN] (  
   @nMobile    INT,  
   @nErrNo     INT  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)  
AS  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
-- Define a variable  
DECLARE @nFunc      INT,  
      @nScn         INT,  
      @nStep        INT,  
      @cLangCode    NVARCHAR( 3),  
      @nMenu        INT,  
      @nInputKey    NVARCHAR( 3),   
      @cInField01   NVARCHAR( 60),      @cInField02  NVARCHAR( 60),  
      @cInField03   NVARCHAR( 60),      @cInField04  NVARCHAR( 60),  
      @cInField05   NVARCHAR( 60),      @cInField06  NVARCHAR( 60),  
      @cInField07   NVARCHAR( 60),      @cInField08  NVARCHAR( 60),  
      @cInField09   NVARCHAR( 60),      @cInField10  NVARCHAR( 60),  
      @cInField011  NVARCHAR( 60),      @cInField12  NVARCHAR( 60),  
      @cInField013  NVARCHAR( 60),      @cInField14  NVARCHAR( 60),  
      @cInField015  NVARCHAR( 60),       
      @cOutField01  NVARCHAR( 60),      @cOutField02  NVARCHAR( 60),     
      @cOutField03  NVARCHAR( 60),      @cOutField04  NVARCHAR( 60),     
      @cOutField05  NVARCHAR( 60),      @cOutField06  NVARCHAR( 60),     
      @cOutField07  NVARCHAR( 60),      @cOutField08  NVARCHAR( 60),     
      @cOutField09  NVARCHAR( 60),      @cOutField10  NVARCHAR( 60),     
      @cOutField11  NVARCHAR( 60),      @cOutField12  NVARCHAR( 60),     
      @cOutField13  NVARCHAR( 60),      @cOutField14  NVARCHAR( 60),     
      @cOutField15  NVARCHAR( 60),     
      @b_success    INT,  
      @n_err        INT,  
      @c_errmsg     NVARCHAR(215),    
      @nAddNewUCCReturn    INT,  
      @cStorerKey   NVARCHAR( 15),  
      @cFacility    NVARCHAR( 5),  
      @nRowCount    INT,  
      @cTOID        NVARCHAR( 18),  
      @cDisAllowDuplicateIdsOnRFRcpt   NVARCHAR( 1),  
      @cAllow_OverReceipt NVARCHAR( 1),  
      @cUCCNo       NVARCHAR( 20),  
      @cSKU         NVARCHAR( 20),   
      @cDescr       NVARCHAR( 30),   
      @cUOM         NVARCHAR( 10),  
      @cPPK         NVARCHAR( 30),  
      @nQTY         INT,  
      @cToLoc       NVARCHAR( 10),  
      @cPackKey     NVARCHAR( 10),  
      @cReceiptKey  NVARCHAR( 10),  
      @cReceiptLineNumber      NVARCHAR( 5),  
      @cNextReceiptLineNumber  NVARCHAR( 5),  
      @cExternPOKey NVARCHAR( 20),   
      @cPOKey       NVARCHAR( 20),  
      @cCartonCnt   NVARCHAR( 5),  
      @cTotalCartonCnt NVARCHAR( 5),  
      @cTotalPalletCnt NVARCHAR( 5),  
      @nCnt         INT,  
      @nMaxCnt  INT,  
      @cConfirm     NVARCHAR( 1),   
      @cDocType     NVARCHAR( 10),  
      @cASNStatus   NVARCHAR( 10),   
      @cStatus      NVARCHAR( 10),   
      @cUCCStatus   NVARCHAR( 10),   
      @nCaseCntQty  INT,   
      @nLocCount    INT,  
      @nExpectedQty INT,  
      @nBeforeReceivedQty      INT,  
      @cPQIndicator NVARCHAR( 10),  
      @cTempToID    NVARCHAR( 18),  
      @cTempToLoc   NVARCHAR( 18),   
      @cReceivedByUPC          NVARCHAR( 5),  
      @cExternKey   NVARCHAR( 20),  
      @cTariffkey   NVARCHAR( 10),  
      @cExternReceiptKey       NVARCHAR( 20),  
      @cExternLineNo NVARCHAR( 20),  
      @cPOLineNumber NVARCHAR( 5),  
      @cSourceKey    NVARCHAR( 20),   
      @cPackUOM      NVARCHAR( 1),  
      @cSValue       NVARCHAR( 10),  
      @cLottable01   NVARCHAR( 18),  
      @cLottable02   NVARCHAR( 18),  
      @cLottable03   NVARCHAR( 18),  
      @cLottable04   NVARCHAR( 20),  
      @cLottable05   NVARCHAR( 20),  
      @cLottable06   NVARCHAR( 30),      --(CS01)  
      @cLottable07   NVARCHAR( 30),      --(CS01)  
      @cLottable08   NVARCHAR( 30),      --(CS01)  
      @cLottable09   NVARCHAR( 30),      --(CS01)  
      @cLottable10   NVARCHAR( 30),      --(CS01)  
      @cLottable11   NVARCHAR( 30),      --(CS01)  
      @cLottable12   NVARCHAR( 30),      --(CS01)  
      @cLottable13   NVARCHAR( 20),      --(CS01)  
      @cLottable14   NVARCHAR( 20),      --(CS01)  
      @cLottable15   NVARCHAR( 20),      --(CS01)  
      @cUserdefine01 NVARCHAR( 30),   
      @cUserdefine02 NVARCHAR( 30),   
      @cUserdefine03 NVARCHAR( 30),   
      @cUserdefine04 NVARCHAR( 30),   
      @cUserdefine05 NVARCHAR( 30),   
      @cUserdefine06 DATETIME,   
      @cUserdefine07 DATETIME,   
      @cUserdefine08 NVARCHAR( 30),   
      @cUserdefine09 NVARCHAR( 30),   
      @cUserdefine10 NVARCHAR( 30),   
      @cXML          nVARCHAR(4000),    
      @cLotLabel01   NVARCHAR( 20),  
      @cLotLabel02   NVARCHAR( 20),  
      @cLotLabel03   NVARCHAR( 20),  
      @cLotLabel04   NVARCHAR( 20),  
      @cLotLabel05   NVARCHAR( 20),  
      @dLottable04   DATETIME,  
      @dLottable05   DATETIME,  
      @dLottable13   DATETIME,           --(CS01)   
      @dLottable14   DATETIME,           --(CS01)  
      @dLottable15   DATETIME,           --(CS01)  
      @cHasLottable  NVARCHAR( 1),    
      @cLottable05_Code NVARCHAR( 30) ,  
      @nFromScn      INT,  
      @nFromStep     INT,  
      @nCount        INT,  
      @cSourceType   NVARCHAR( 30),  
      @cCreateUCC    NVARCHAR( 1),  
      @cTempLottable01 NVARCHAR( 18),  
      @cTempLottable02 NVARCHAR( 18),  
      @cTempLottable03 NVARCHAR( 18),  
      @dTempLottable04 DATETIME,  
      @dTempLottable05 DATETIME,  
      @cTempLottable06 NVARCHAR( 30),       --(CS01)  
      @cTempLottable07 NVARCHAR( 30),       --(CS01)  
      @cTempLottable08 NVARCHAR( 30),       --(CS01)  
      @cTempLottable09 NVARCHAR( 30),       --(CS01)  
      @cTempLottable10 NVARCHAR( 30),       --(CS01)  
      @cTempLottable11 NVARCHAR( 30),       --(CS01)  
      @cTempLottable12 NVARCHAR( 30),       --(CS01)  
      @dTempLottable13 DATETIME,            --(CS01)  
      @dTempLottable14 DATETIME,            --(CS01)    
      @dTempLottable15 DATETIME,            --(CS01)  
      @nTempQtyExpected INT,  
      @cPrevReceiptLineNumber NVARCHAR( 5),  
      @cSKUCODE NVARCHAR( 20),   
      @nSKUCnt        INT       -- (james02)  
  
  
  
-- (Vicky02) - Start  
DECLARE  @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),  
         @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),  
         @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),  
         @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),  
         @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),  
         @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),  
         @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),  
         @cFieldAttr15 NVARCHAR( 1)  
-- (Vicky02) - End  
  
-- Getting Mobile information  
SELECT @nFunc      = Func,  
      @nScn        = Scn,  
      @nStep       = Step,  
      @nInputKey   = InputKey,  
      @cLangCode   = Lang_code,  
      @nMenu       = Menu,  
      @cFacility   = Facility,  
      @cStorerKey  = StorerKey,  
      @cInField01  = I_Field01,      @cInField02 = I_Field02,  
      @cInField03  = I_Field03,      @cInField04 = I_Field04,  
      @cInField05  = I_Field05,      @cInField06 = I_Field06,  
      @cInField07  = I_Field07,      @cInField08 = I_Field08,  
      @cInField09  = I_Field09,      @cInField10 = I_Field10,  
      @cInField011 = I_Field11,      @cInField12 = I_Field12,  
      @cInField013 = I_Field13,      @cInField14 = I_Field14,  
      @cInField015 = I_Field15,  
      @cOutField01 = O_Field01,      @cOutField02 = O_Field02,  
      @cOutField03 = O_Field03,      @cOutField04 = O_Field04,  
      @cOutField05 = O_Field05,      @cOutField06 = O_Field06,  
      @cOutField07 = O_Field07,      @cOutField08 = O_Field08,  
      @cOutField09 = O_Field09,      @cOutField10 = O_Field10,  
      @cOutField10 = O_Field10,      @cOutField12 = O_Field12,  
      @cOutField13 = O_Field13,      @cOutField14 = O_Field14,  
      @cOutField15 = O_Field15,  
      @cSKU              = V_SKU,            
      @cDescr            = V_SKUDescr,   
      @cUOM              = V_UOM,            
      @nQTY              = V_QTY,  
      @cLottable01       = V_Lottable01,   
      @cLottable02       = V_Lottable02,     
      @cLottable03       = V_Lottable03,           
      @dLottable04       = V_Lottable04,               
      @dLottable05       = V_Lottable05,    
      @cLottable06       = V_Lottable06,               --(CS01)  
      @cLottable07       = V_Lottable07,               --(CS01)  
      @cLottable08       = V_Lottable08,               --(CS01)  
      @cLottable09       = V_Lottable09,               --(CS01)  
      @cLottable10       = V_Lottable10,               --(CS01)  
      @cLottable11       = V_Lottable11,               --(CS01)  
      @cLottable12       = V_Lottable12,               --(CS01)  
      @dLottable13       = V_Lottable13,               --(CS01)  
      @dLottable14       = V_Lottable14,               --(CS01)  
      @dLottable15       = V_Lottable15,               --(CS01)             
      @cTOID             = V_ID,   
      @cUCCNo            = V_UCC,            
      @cToLoc            = V_Loc,   
      @cReceiptKey       = V_ReceiptKey,     
      @cPPK              = V_String1,        
      @cPQIndicator      = V_String2,  
      @cReceiptLineNumber= V_String3,  
      @cCartonCnt        = V_String4,        
      @cTotalCartonCnt   = V_String5,  
      @nMaxCnt           = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END, -- (Vicky03)  
      @cTotalPalletCnt   = V_String7,   
      @cExternPOKey      = V_String8,    
      @cPackKey          = V_String9,      
      @cExternKey        = V_String10,   
      @cTariffkey        = V_String11,   
      @nAddNewUCCReturn  = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12,  5), 0) = 1 THEN LEFT( V_String12,  5) ELSE 0 END, -- (Vicky03)  
      @cAllow_OverReceipt= V_String13,  
      @cPOKey            = V_String14,         
      @cPOLineNumber     = V_String15,  
      @nFromScn          = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String16,  5), 0) = 1 THEN LEFT( V_String16,  5) ELSE 0 END, -- (Vicky03)  
      @nFromStep         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String17,  5), 0) = 1 THEN LEFT( V_String17,  5) ELSE 0 END, -- (Vicky03)  
      @cCreateUCC        = V_String18,  
      @cReceivedByUPC    = V_String19,  
      -- (Vicky02) - Start  
      @cLotLabel01       = V_String20,  
      @cLotLabel02       = V_String21,  
      @cLotLabel03       = V_String22,  
      @cLotLabel04       = V_String23,  
      @cLotLabel05       = V_String24,  
  
      @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,  
      @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,  
      @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
      @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
      @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
      @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
      @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
      @cFieldAttr15 =  FieldAttr15  
      -- (Vicky02) - End  
      FROM   RDTMOBREC (NOLOCK)  
      WHERE Mobile = @nMobile  
  
-- Julian Date Lottables (declaration)  
DECLARE  
   @cJSPName           NVARCHAR( 250),  
   @cJListName         NVARCHAR( 10),  
   @cJStorerkey        NVARCHAR( 15),  
   @cJSku              NVARCHAR( 20),  
   @cJLottableLabel    NVARCHAR( 20),  
 @cJLottable01Value  NVARCHAR( 18),  
 @cJLottable02Value  NVARCHAR( 18),  
 @cJLottable03Value  NVARCHAR( 18),  
 @dtJLottable04Value DATETIME,  
 @dtJLottable05Value DATETIME,  
   @cJLottable06Value  NVARCHAR( 30),     --(CS01)  
 @cJLottable07Value  NVARCHAR( 30),     --(CS01)  
 @cJLottable08Value  NVARCHAR( 30),     --(CS01)  
   @cJLottable09Value  NVARCHAR( 30),     --(CS01)  
 @cJLottable10Value  NVARCHAR( 30),     --(CS01)  
 @cJLottable11Value  NVARCHAR( 30),     --(CS01)  
   @cJLottable12Value  NVARCHAR( 30),     --(CS01)  
   @dtJLottable13Value DATETIME,          --(CS01)  
 @dtJLottable14Value DATETIME,          --(CS01)  
 @dtJLottable15Value DATETIME,          --(CS01)  
 @cJLottable01       NVARCHAR( 18),  
 @cJLottable02       NVARCHAR( 18),  
 @cJLottable03       NVARCHAR( 18),  
 @dtJLottable04      DATETIME,  
 @dtJLottable05      DATETIME,  
   @cJLottable06       NVARCHAR( 30),    --(CS01)  
 @cJLottable07       NVARCHAR( 30),    --(CS01)  
 @cJLottable08       NVARCHAR( 30),    --(CS01)  
   @cJLottable09       NVARCHAR( 30),    --(CS01)  
 @cJLottable10       NVARCHAR( 30),    --(CS01)  
 @cJLottable11       NVARCHAR( 30),    --(CS01)  
   @cJLottable12       NVARCHAR( 30),    --(CS01)  
   @dtJLottable13      DATETIME,         --(CS01)  
 @dtJLottable14      DATETIME,         --(CS01)  
 @dtJLottable15      DATETIME,         --(CS01)  
 @cJLottable04       NVARCHAR( 18),  
 @cJLottable05       NVARCHAR( 18),  
   @cJLottable13       NVARCHAR( 30),    --(CS01)  
   @cJLottable14       NVARCHAR( 30),    --(CS01)  
 @cJLottable15       NVARCHAR( 30)     --(CS01)  
  
-- Commented (Vicky02) - Start  
-- -- Session Data used to enable/disable lottables  
-- -- Load session variable  
-- DECLARE @iDoc INT  
-- DECLARE @tSessionVar TABLE  
-- (  
--    VarName SYSNAME,   
--    Value   NVARCHAR( 60)  
-- )  
-- SELECT @cXML = XML FROM RDTSessionData WHERE Mobile = @nMobile  
-- EXEC sp_xml_preparedocument @iDoc OUTPUT, @cXML  
-- INSERT INTO @tSessionVar  
-- SELECT VarName, Value  
-- FROM OPENXML (@idoc, '/Root/Variable', 1) -- attribute centric mapping  
--    WITH (VarName SYSNAME,  
--          Value   NVARCHAR( 60))  
-- EXEC sp_xml_removedocument @iDoc  
--   
-- SELECT @cLotLabel01  = Value FROM @tSessionVar WHERE VarName = '@cLotLabel01'  
-- SELECT @cLotLabel02  = Value FROM @tSessionVar WHERE VarName = '@cLotLabel02'  
-- SELECT @cLotLabel03  = Value FROM @tSessionVar WHERE VarName = '@cLotLabel03'  
-- SELECT @cLotLabel04  = Value FROM @tSessionVar WHERE VarName = '@cLotLabel04'  
-- SELECT @cLotLabel05  = Value FROM @tSessionVar WHERE VarName = '@cLotLabel05'  
--   
-- -- Session screen  
-- DECLARE @tSessionScrn TABLE  
-- (  
-- Typ       NVARCHAR( 10),   
--    X         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
--    Y         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
--    Length    NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
--    [ID]      NVARCHAR( 10),   
--    [Default] NVARCHAR( 60),   
--    Value     NVARCHAR( 60),   
--    [NewID]   NVARCHAR( 10)  
-- )  
-- Commented (Vicky02) - End  
  
-- Redirect to respective screen  
IF @nStep = 0 GOTO Step_0   -- Menu. Func = 554  
IF @nStep = 1 GOTO Step_1   -- Scn = 984   scan receiptkey  
IF @nStep = 2 GOTO Step_2   -- Scn = 985   scan TOLOC, TOID, TOTAL CTNS  
IF @nStep = 3 GOTO Step_3   -- Scn = 986   scan UCC  
IF @nStep = 4 GOTO Step_4   -- Scn = 987   scan qty  
IF @nStep = 5 GOTO Step_5   -- Scn = 988   confirm screen  
IF @nStep = 6 GOTO Step_6   -- Scn = 989   < Max no. of carton  
IF @nStep = 7 GOTO Step_7   -- Scn = 990   confirm whether accept new UCC  
IF @nStep = 8 GOTO Step_8   -- Scn = 991   key in total ctns  
IF @nStep = 9 GOTO Step_9   -- Scn = 992   scan SKU/UPC  
IF @nStep = 10 GOTO Step_10 -- Scn = 993   received by UPC  
IF @nStep = 11 GOTO Step_11 -- Scn = 994   scan lottables01-05  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 554)  
   @nStep = 0  
********************************************************************************/  
Step_0:  
BEGIN  
-- Commented (Vicky02) - Start  
--    IF EXISTS (SELECT 1 FROM RDTSessionData WHERE Mobile = @nMobile)  
--       UPDATE RDTSessionData SET XML = '' WHERE Mobile = @nMobile  
--    ELSE  
--       INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)  
-- Commented (Vicky02) - End  
  
   SET @nScn = 984  
   SET @nStep = 1  
  
-- initialise all variable     
   SET @cTOID = ''  
   SET @cSKU  = ''  
   SET @cDescr = ''  
   SET @cUOM = ''  
   SET @cUCCNo = ''  
   SET @cPPK = ''  
   SET @cPQIndicator = ''  
   SET @nQTY = ''  
   SET @cToLoc = ''  
   SET @cReceiptKey = ''  
   SET @cReceiptLineNumber = ''  
   SET @cCartonCnt = '0'  
   SET @cTotalCartonCnt = '0'  
   SET @nMaxCnt = '0'  
   SET @cTotalPalletCnt = '0'  
   SET @cExternPOKey = ''  
   SET @cLottable01 = ''  
   SET @cLottable02 = ''  
   SET @cLottable03 = ''  
   SET @cExternKey = ''  
  
   -- (Vicky02) - Start  
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
   -- (Vicky02) - End  
END  
  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. screen (scn = 984)  
   ASN#: (@cInField01)  
********************************************************************************/  
Step_1:  
  
BEGIN  
  
   IF @nInputKey = 1      -- Yes OR Send  
   BEGIN  
      SET @cReceiptKey = @cInField01  
  
      IF (@cReceiptKey = '' OR @cReceiptKey IS NULL)   
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61101, @cLangCode, 'DSP') --61101 ASN# Required  
         GOTO Step_1_Fail        
      END  
      ELSE  
      IF EXISTS (SELECT 1 FROM dbo.RECEIPT (NOLOCK)   
         WHERE StorerKey = @cStorerKey AND RECEIPTKEY = @cReceiptKey)  
      BEGIN  
         SELECT   
            @cExternKey = ExternReceiptKey,   
            @cStatus = Status,   
            @cDocType = DocType,   
            @cASNStatus = ASNStatus   
         FROM dbo.RECEIPT (NOLOCK)   
         WHERE StorerKey = @cStorerKey   
            AND RECEIPTKEY = @cReceiptKey  
        
         IF ISNULL(LTRIM(RTRIM(@cDocType)),'') <> 'A'   
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61117, @cLangCode, 'DSP') --Wrong DocType  
            GOTO Step_1_Fail        
         END  
        
         IF ISNULL(LTRIM(RTRIM(@cASNStatus)),'') = '9' OR ISNULL(LTRIM(RTRIM(@cStatus)),'') = '9'   
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61118, @cLangCode, 'DSP') --ASN Closed  
            GOTO Step_1_Fail        
         END  
        
         IF ISNULL(LTRIM(RTRIM(@cASNStatus)),'') = 'CANC'   
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61119, @cLangCode, 'DSP') --ASN Cancelled  
            GOTO Step_1_Fail        
         END  
  
         IF EXISTS (SELECT 1 FROM RDT.NSQLCONFIG (NOLOCK)   
            WHERE CONFIGKEY = 'DefaultToLoc' AND NSQLValue = '1')  
  
         SELECT @cToLoc = SVALUE FROM rdt.STORERCONFIG (NOLOCK)   
            WHERE StorerKey = @cStorerKey AND CONFIGKEY = 'DefaultToLoc'  
      END  
      ELSE  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61102, @cLangCode, 'DSP') --ASN# Not Found  
            GOTO Step_1_Fail        
         END  
   END  
     
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
  
-- de-initialise all variable     
      SET @cTOID = ''  
      SET @cSKU  = ''  
      SET @cDescr = ''  
      SET @cUOM = ''  
      SET @cUCCNo = ''  
      SET @cPPK = ''  
      SET @cPQIndicator = ''  
      SET @nQTY = ''  
      SET @cToLoc = ''  
      SET @cReceiptKey = ''  
      SET @cReceiptLineNumber = ''  
      SET @cCartonCnt = '0'  
      SET @cTotalCartonCnt = '0'  
      SET @nMaxCnt = '0'  
      SET @cTotalPalletCnt = '0'  
      SET @cExternPOKey = ''  
      SET @cLottable02 = ''  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      -- Commented (Vicky02)  
      -- Delete session data  
      --DELETE RDTSessionData WHERE Mobile = @nMobile  
  
      GOTO Quit  
   END  
     
   Step_1_Next:  
   BEGIN  
      SET @nScn = 985  
      SET @nStep = 2  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cLottable01 = ''  
      SET @cLottable02 = ''  
      SET @cLottable03 = ''  
      SET @dLottable04 = NULL  
      SET @dLottable05 = NULL  
      SET @cLottable06 = ''         --(CS01)  
    SET @cLottable07 = ''         --(CS01)  
    SET @cLottable08 = ''         --(CS01)  
    SET @cLottable09 = ''         --(CS01)  
    SET @cLottable10 = ''         --(CS01)  
    SET @cLottable11 = ''         --(CS01)   
    SET @cLottable12 = ''         --(CS01)  
    SET @dLottable13 = NULL       --(CS01)  
    SET @dLottable14 = NULL       --(CS01)  
    SET @dLottable15 = NULL       --(CS01)  
      SET @cCartonCnt  = '0'  
      SET @nMaxCnt     = '0'  
      SET @cTotalPalletCnt = '0'  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      IF ISNULL(LTRIM(RTRIM(@cToLoc)),'') <> ''  
      BEGIN  
         SET @cOutField01 = @cToLoc  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
      END  
      ELSE  
      BEGIN  
         SET @cOutField01 = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
      END              
      GOTO Quit  
   END  
  
   Step_1_Fail:  
   BEGIN  
      SET @cReceiptKey = ''  
   END     
END  
GOTO Quit  
  
  
/********************************************************************************  
  
Step 2. screen (scn = 985)  
   TOLOC#: (@cInField01)  
   TOID#:   
   (@cInField02)  
   TOTAL CARTONS: (@cInField03)  
********************************************************************************/  
Step_2:  
  
BEGIN  
  
   IF @nInputKey = 1      -- Yes OR Send  
   BEGIN  
      SET @cToLoc = @cInField01  
      SET @cTOID  = @cInField02  
      SET @cTotalCartonCnt = @cInField03  
  
      --check whether allow duplicate pallet id  
      EXECUTE dbo.nspGetRight  
         NULL, -- Facility  
         @cStorerKey,    
         @cSKU,   
         'DisAllowDuplicateIdsOnRFRcpt',   
         @b_success                        OUTPUT,  
         @cDisAllowDuplicateIdsOnRFRcpt    OUTPUT,  
         @nErrNo                           OUTPUT,  
         @cErrMsg                          OUTPUT  
      IF @b_success <> 1  
      BEGIN  
         SET @nErrNo = 60301  
         SET @cErrMsg = rdt.rdtgetmessage( 60301, @cLangCode, 'DSP') --'nspGetRight'  
         GOTO Step_2_Fail  
      END  
  
      -- Storer config 'Allow_OverReceipt'  
      EXECUTE dbo.nspGetRight  
         NULL, -- Facility  
         @cStorerKey,    
         @cSKU,   
         'Allow_OverReceipt',   
         @b_success             OUTPUT,  
         @cAllow_OverReceipt    OUTPUT,  
         @nErrNo                OUTPUT,  
         @cErrMsg               OUTPUT  
      IF @b_success <> 1  
      BEGIN  
         SET @nErrNo = 60301  
         SET @cErrMsg = rdt.rdtgetmessage( 60301, @cLangCode, 'DSP') --'nspGetRight'  
         GOTO Step_2_Fail  
      END  
  
      --check whether allow duplicate pallet id  
--       SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue   
--       FROM dbo.NSQLConfig (NOLOCK)  
--       WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'     
  
--       --check whether allow overReceipt  
--       SELECT @nAllow_OverReceipt = NSQLValue   
--       FROM dbo.NSQLConfig (NOLOCK)  
--       WHERE ConfigKey = 'Allow_OverReceipt'     
  
      --ToLoc is blank  
      IF ISNULL(LTRIM(RTRIM(@cToLoc)),'') = ''     
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61103, @cLangCode, 'DSP') --ToLoc Required  
         SET @cToLoc = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_2_Fail        
      END     
      ELSE  
      IF NOT EXISTS(SELECT 1 FROM dbo.LOC (NOLOCK)   
         WHERE LOC = @cToLoc AND FACILITY = @cFacility)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61104, @cLangCode, 'DSP') --Loc not in fac  
         SET @cToLoc = ''  
         GOTO Step_2_Fail        
      END     
  
      --TOID is blank           
      IF ISNULL(LTRIM(RTRIM(@cTOID)),'') = ''   
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61105, @cLangCode, 'DSP') --TOID# Required  
         SET @cTOID = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO Step_2_Fail        
      END  
      ELSE  
      -- check if TOLOC is valid  
      IF EXISTS( SELECT [ID]      
         FROM dbo.LOTxLOCxID LOTxLOCxID (NOLOCK) INNER JOIN dbo.LOC LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)  
         WHERE [ID] = @cTOID  
            AND QTY > 0  
            AND LOC.Facility = @cFacility)  
      BEGIN  
         --allow duplicate TOID or not  
         IF @cDisAllowDuplicateIdsOnRFRcpt = '1'     
         BEGIN  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            SET @cErrMsg = rdt.rdtgetmessage( 61106, @cLangCode, 'DSP') --Duplicate TOID  
            SET @cTOID = ''  
            GOTO Step_2_Fail        
         END                  
      END  
  
      --check if TOID is tight to one loc  
      SELECT @nLocCount = COUNT(LOC) FROM dbo.LOTXLOCXID (NOLOCK)   
         WHERE STORERKEY = @cStorerKey AND ID = @cTOID  
         GROUP BY LOC, ID HAVING COUNT(LOC)>1  
      IF ISNULL(@nLocCount,0) >= 1  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61120, @cLangCode, 'DSP') --TOID Not Tight  
         SET @cTotalCartonCnt = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
     GOTO Step_2_Fail        
      END       
  
      SELECT @cTempToLoc = TOLOC FROM dbo.RECEIPTDETAIL (NOLOCK)   
         WHERE STORERKEY = @cStorerKey AND TOID = @cTOID   
  
      --if receiptdetail line found,   
      IF ISNULL(LTRIM(RTRIM(@cTempToLoc)),'') <> ''     
      BEGIN  
         IF @cTempToLoc <> @cToLoc   --if both toloc not same, error  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61120, @cLangCode, 'DSP') --TOID Not Tight  
            SET @cTotalCartonCnt = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Step_2_Fail        
         END                    
      END  
  
      --check if valid carton entered  
--      IF ISNUMERIC(CAST(@cTotalCartonCnt AS INT)) = 0 OR CAST(@cTotalCartonCnt AS INT) <= 0  
      IF rdt.rdtIsValidQty(@cTotalCartonCnt, 1) = 0     
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61107, @cLangCode, 'DSP') --Invalid carton  
         SET @cTotalCartonCnt = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Step_2_Fail        
      END       
  
      GOTO Step_2_Next  
   END  
     
   IF @nInputKey = 0 -- Esc OR No  
      BEGIN  
         SET @nScn  = 984  
         SET @nStep = 1  
         SET @cOutField01 = @cReceiptKey  
         GOTO QUIT  
      END  
     
   Step_2_Next:  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
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
      SET @cOutField11 = '0/' + LTRIM(RTRIM(@cTotalCartonCnt))  
      SET @nMaxCnt = '0'  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      GOTO Quit  
   END  
  
   Step_2_Fail:  
   BEGIN  
      SET @cOutField01 = @cToLoC  
      SET @cOutField02 = @cTOID  
      SET @cOutField03 = @cTotalCartonCnt  
   END     
END  
GOTO Quit  
  
  
/********************************************************************************  
Step 3. screen (scn = 986)  
  
   UCC#:   
   (@cInField01)  
   SKU/UPC:   
   xxxxxxxxxxxxxxxxxxxx  
   Desc: xxxxxxxxxx  
   xxxxxxxxxxxxxxxxxxxx  
   PPK/DU: xxxxxx  
   Lottable02/04  
   2 xxxxxxxxxxxxxxxxxx  
   4 xxxxxxxxxxxxxxxxxx  
   UOM: xxxxx Qty:xxxxx          
   Ctn: xx/xx  
********************************************************************************/  
Step_3:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cUCCNo = @cInField01  
  
      --max carton no and go back   
      IF CAST(@cCartonCnt AS INT) >= CAST(@cTotalCartonCnt AS INT) AND CAST(@cCartonCnt AS INT) > 0     
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61111, @cLangCode, 'DSP') -->Max No of CTN  
         SET @cUCCNo = ''  
         GOTO Step_3_Fail        
      END   
  
      IF EXISTS (SELECT 1 FROM RDT.NSQLCONFIG (NOLOCK)   
         WHERE CONFIGKEY = 'AddNwUCCR' AND NSQLValue = '1')  
  
      SELECT   
         @nAddNewUCCReturn = SVALUE   
      FROM rdt.STORERCONFIG (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
         AND CONFIGKEY = 'AddNwUCCR'  
  
      IF ISNULL(LTRIM(RTRIM(@cUCCNo)),'') = ''  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61108, @cLangCode, 'DSP') --UCC# Required  
         SET @cUCCNo = ''  
         GOTO Step_3_Fail        
      END  
  
      --get ucc count  
     SELECT   
         @nCnt = COUNT(UCCNo)   
      FROM dbo.UCC (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
         AND UCCNo = @cUCCNo   
  
      --check if multi sku per UCC  
      IF ISNULL(@nCnt,0) > 1  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61110, @cLangCode, 'DSP') --Multi Sku/ UCC  
         SET @cUCCNo = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail        
      END     
  
      SET @cPOKey = ''  
      SET @cPOLineNumber = ''  
  
      SELECT   
         @cPOKey = SOURCEKEY,   
         @cUCCStatus = STATUS   
      FROM dbo.UCC (NOLOCK)   
      WHERE StorerKey = @cStorerKey   
        AND UCCNo = @cUCCNo   
  
      --try to get POKey from receiptdetai line  
      IF ISNULL(LTRIM(RTRIM(@cPOKey)), '') = ''  
      BEGIN  
         SELECT TOP 1   
            @cPOKey = ExternReceiptKey   
         FROM dbo.ReceiptDetail (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
            AND ReceiptKey = @cReceiptKey  
      END  
  
      --make sure it's a valid POKey  
      SET @cPOKey = ISNULL(LTRIM(RTRIM(@cPOKey)), '')     
      IF LEN(@cPOKey) >= 10  
      BEGIN  
         SET @cPOLineNumber = SUBSTRING(@cPOKey, 11, 5)     
         SET @cPOKey = SUBSTRING(@cPOKey, 1, 10)     
         IF NOT EXISTS(SELECT 1 FROM dbo.PO PO (NOLOCK) INNER JOIN dbo.PODETAIL PODETAIL (NOLOCK) ON PO.POKEY = PODETAIL.POKEY AND PO.STORERKEY = PODETAIL.STORERKEY   
            WHERE PO.STORERKEY = @cStorerKey   
               AND PO.POKey = @cPOKey   
               AND PODETAIL.POLineNumber = @cPOLineNumber   
               AND PO.STATUS <> 'CANC')  
         BEGIN   -- POKey not found  
            SET @cPOKey = ''  
         END  
      END  
      ELSE   -- invalid POKey  
      BEGIN  
         SET @cPOKey = ''  
      END  
  
      --check UCC status  
      IF ISNULL(LTRIM(RTRIM(@cUCCStatus)), '') = '1' -- (Vicky01)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61112, @cLangCode, 'DSP') --UCC# Received  
         SET @cUCCNo = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail                                 
      END           
  
      --check if UCC status closed or shipped  
      IF ISNULL(LTRIM(RTRIM(@cUCCStatus)), '') <> '0' AND ISNULL(LTRIM(RTRIM(@cUCCStatus)), '') <> '9' -- (Vicky01)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61121, @cLangCode, 'DSP') --Invalid UCC  
         SET @cUCCNo = ''  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Step_3_Fail        
      END  
  
      --UCC not found  
      IF ISNULL(@nCnt,0) = 0     
      BEGIN  
         --not allowed add new UCC  
         IF ISNULL(@nAddNewUCCReturn,0) = 0     
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61109, @cLangCode, 'DSP') --UCC# Not Found  
            SET @cUCCNo = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_3_Fail        
         END  
  
         --allowed add new UCC  
         IF ISNULL(@nAddNewUCCReturn,0) = 1     
         BEGIN  
            SET @cReceivedByUPC = 'FALSE'  
            SET @nScn  = 992  
            SET @nStep = 9  
            SET @cOutField01 = @cUCCNo  
            SET @cOutField02 = ''  
            SET @cOutField03 = ''  
            SET @cOutField04 = ''  
            SET @cOutField05 = ''  
            SET @cOutField06 = ''  
            SET @cOutField07 = ''  
            SET @cOutField08 = ''  
            SET @cOutField09 = ''  
            SET @cOutField10 = ''  
            SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
            SET @cCreateUCC = '1'  
            -- (Vicky02) - Start  
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
            -- (Vicky02) - End  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO QUIT  
         END                    
                    
         IF ISNULL(@nAddNewUCCReturn,0) = 2   --prompt  
         BEGIN  
            SET @nScn  = 990  
            SET @nStep = 7  
            SET @cOutField01 = ''  
            GOTO QUIT  
         END                    
      END     
      ELSE   --ucc found  
      BEGIN     
      IF EXISTS (SELECT 1 FROM dbo.UCC (NOLOCK)   
         WHERE StorerKey = @cStorerKey   
            AND UCCNo = @cUCCNo)  
      BEGIN                
         SELECT   
            @cSKU = SKU,   
            @nQTY = QTY FROM dbo.UCC (NOLOCK)  
            WHERE StorerKey = @cStorerKey   
               AND UCCNo = @cUCCNo          
  
         SELECT   
            @cPackKey = PACKKEY,   
            @cDescr = DESCR,   
            @cPPK = PREPACKINDICATOR,   
            @cPQIndicator = PackQtyIndicator,   
            @cTariffkey = Tariffkey    
         FROM dbo.SKU (NOLOCK)  
         WHERE StorerKey = @cStorerKey   
            AND SKU = @cSKU  
  
         SELECT   
            @cReceiptLineNumber = ReceiptLineNumber   
         FROM dbo.RECEIPTDETAIL (NOLOCK)  
         WHERE StorerKey = @cStorerKey   
            AND RECEIPTKEY = @cReceiptKey   
            AND SKU = @cSKU             
  
         -- (Vicky_Temp)  
         SELECT   
            @cLottable01 = Lottable01,  
            @cLottable02 = Lottable02,     
            @cLottable03 = Lottable03,           
            @dLottable04 = Lottable04  
         FROM dbo.RECEIPTDETAIL (NOLOCK)  
         WHERE StorerKey = @cStorerKey   
            AND RECEIPTKEY = @cReceiptKey   
            AND ReceiptLinenumber = @cReceiptLineNumber  
            AND SKU = @cSKU        
         -- (Vicky_Temp)  
  
         SELECT   
               @cUOM = PACKUOM3,   
               @nCaseCntQty = PACK.CASECNT   
         FROM dbo.PACK PACK (NOLOCK)   
         WHERE PACKKEY = @cPackKey  
  
         SET @cCreateUCC = '0'  
               
         --received by UPC  
         IF @nCaseCntQty <> @nQTY     
         BEGIN  
            SET @nScn  = 993  
            SET @nStep = 10  
            SET @cReceivedByUPC = 'TRUE'  
            GOTO QUIT  
         END                                
         ELSE  
         BEGIN     
            SET @cReceivedByUPC = 'FALSE'  
         END     
      END   --end for UCC found  
      GOTO Step_3_Next  
   END   
   END  
     
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      --already scanned carton and prompt  
      IF (CAST(@cCartonCnt AS INT) < CAST(@cTotalCartonCnt AS INT)) AND CAST(@cCartonCnt AS INT) > 0     
         BEGIN  
            SET @nScn  = 989  
            SET @nStep = 6  
            SET @cOutField01 = ''  
            GOTO Quit  
         END  
  
      --max carton no and go back   
      IF CAST(@cCartonCnt AS INT) >= CAST(@cTotalCartonCnt AS INT) AND CAST(@cCartonCnt AS INT) > 0     
         BEGIN      --to step 2 screen to change total carton  
            SET @nScn  = 985     
            SET @nStep = 2  
            SET @cOutField01 = @cToLoc  
            SET @cOutField02 = ''  
            SET @cOutField03 = ''  
            SET @cCartonCnt = '0'  
            SET @cTotalCartonCnt = '0'  
            SET @cLottable01 = ''  
            SET @cLottable02 = ''  
            SET @cLottable03 = ''  
            SET @dLottable04 = NULL  
            SET @dLottable05 = NULL  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Quit  
         END  
      --not yet scanned and return to step 2 screen  
      SET @nScn  = 985     
      SET @nStep = 2  
      SET @cOutField01 = @cToLoc  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cCartonCnt = '0'  
      SET @cTotalCartonCnt = '0'  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      EXEC rdt.rdtSetFocusField @nMobile, 2  
      GOTO Quit  
   END  
  
   Step_3_Next:  
   BEGIN  
   -- (Vicky02) - Start  
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
   -- (Vicky02) - End  
  
   IF (rdt.RDTGetConfig( 0, 'ScanLot', @cStorerKey) = '1')   
      BEGIN   --if storerconfig 'scanlot' is on then goto scan lot screen  
         SET @nScn  = 994  
         SET @nStep = 11  
         --prepare lottable screen variable  
         SET @cOutField01 = ''  
         SET @cOutField03 = ''  
         SET @cOutField05 = ''  
         SET @cOutField07 = ''  
         SET @cOutField09 = ''  
  
      SELECT           
         @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),   
         @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),   
         @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),   
         @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),  
         @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),  
         @cLottable05_Code = IsNULL( S.Lottable05Label, '')  
      FROM dbo.SKU S (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   SKU = @cSKU  
  
      -- Turn on lottable flag (use later)  
      SET @cHasLottable = '0'  
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR  
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR  
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR  
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR  
         (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)  
      SET @cHasLottable = '1'  
  
      -- Initiate next screen var  
    IF @cHasLottable = '1'  
      BEGIN  
         -- Clear all outfields  
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
  
         -- Initiate labels  
         SELECT   
            @cOutField01 = 'Lottable01:',   
            @cOutField03 = 'Lottable02:',  
            @cOutField05 = 'Lottable03:',   
            @cOutField07 = 'Lottable04:',   
            @cOutField09 = 'Lottable05:'  
  
         -- Populate labels and lottables  
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL  
         BEGIN  
            SET @cFieldAttr02 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN                    
            SELECT @cOutField01 = @cLotLabel01  
  SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')  
         END  
  
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL  
         BEGIN  
            SET @cFieldAttr04 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN              
            SELECT @cOutField03 = @cLotLabel02  
            SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')  
         END  
  
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL  
         BEGIN  
            SET @cFieldAttr06 = 'O' -- (Vicky02)           
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN                    
            SELECT @cOutField05 = @cLotLabel03  
            SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')  
         END  
  
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL  
         BEGIN  
            SET @cFieldAttr08 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            SELECT  @cOutField07 = @cLotLabel04  
            IF ISDATE(@dLottable04) = 1  
            BEGIN  
               SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)  
            END  
         END  
  
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL  
         BEGIN  
            SET @cFieldAttr10 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            -- Lottable05 is usually RCP_DATE  
            IF @cLottable05_Code = 'RCP_DATE'  
            BEGIN  
               SET @dLottable05 = GETDATE()  
            END  
  
            SELECT  
               @cOutField09 = @cLotLabel05,   
               @cOutField10 = RDT.RDTFormatDate( @dLottable05)  
          END  
         END  
         SET @nFromScn = 986  
         SET @nFromStep = 3  
         EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field  
      END  
      ELSE  
      BEGIN  
         SET @nScn  = 988  
         SET @nStep = 5  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
         SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
         SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cPPK)), '') + '/' + ISNULL(LTRIM(RTRIM(@cPQIndicator)), '') -- (Vicky01)  
         SET @cOutField07 = @cLottable02  
         SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)  
         SET @cOutField09 = @cUOM   
         SET @cOutField10 = @nQTY   
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         SET @cReceiptLineNumber = ''  
         SET @cTempToID = ''  
         SET @cTempToLoc = ''  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         GOTO QUIT  
      END  
   END  
  
   Step_3_Fail:  
      BEGIN  
         SET @cOutField01 = ''      
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         GOTO Quit  
      END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. screen (scn = 987)  
  
   UCC#:   
   xxxxxxxxxxxxxxxxxxxx  
   Sku/UPC:   
   xxxxxxxxxxxxxxxxxxxx  
   Desc: xxxxxxxxxx  
   xxxxxxxxxxxxxxxxxxxx  
   PPK/DU: xxxxx  
   Lottable02/04:   
   2: xxxxxxxxxxxxxxxxxx   
   4: xxxxxxxxxxxxxxxxxx  
   UOM: xxxxx  
   Qty: (@cInField10)  
   Ctn: xx/xx  
********************************************************************************/  
Step_4:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      IF ISNULL(LTRIM(RTRIM(@cInField10)),'') = ''  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61122, @cLangCode, 'DSP') --Qty Required  
         EXEC rdt.rdtSetFocusField @nMobile, 9  
         GOTO Step_4_Fail        
      END     
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      --invalid qty entered           
      IF rdt.rdtIsValidQty(@cInField10, 1) = 0     
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61116, @cLangCode, 'DSP') --Invalid Qty  
         GOTO Step_4_Fail  
      END  
      SET @nQTY = @cInField10  
  
      --RDT check UCC.Qty against CaseCnt (0-qty follow casecnt; qty populate from pack but not checking)  
      IF NOT (rdt.RDTGetConfig( 0, 'UCCWithDynamicCaseCnt', @cStorerKey) = '1') --1=Dynamic case count  
      BEGIN  
         -- Get case count  
         SELECT   
            @nCaseCntQty = PACK.CASECNT   
         FROM dbo.SKU SKU (NOLOCK) INNER JOIN dbo.PACK PACK (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY   
         WHERE SKU.STORERKEY = @cStorerKey   
            AND SKU.SKU = @cSKU  
  
         IF @nQTY <> @nCaseCntQty  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61125, @cLangCode, 'DSP') --CaseCNT Diff  
            GOTO Step_4_Fail  
         END  
      END  
        
        --try to loop thru cursor and get range of possible records (not recomended, need imporovement)  
         IF @cPOKey = ''  
         BEGIN  
            DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
               SELECT   
                  RD.RECEIPTLINENUMBER,   
                  TOLOC,   
                  TOID,   
                  Lottable01,   
                  Lottable02,   
                  Lottable03,   
                  Lottable04,   
                  Lottable05                     
                  FROM dbo.Receipt R (NOLOCK)   
                  INNER JOIN dbo.ReceiptDetail RD (NOLOCK) ON R.StorerKey = RD.StorerKey AND R.ReceiptKey = RD.ReceiptKey   
                  WHERE R.StorerKey = @cStorerKey   
                     AND R.ReceiptKey = @cReceiptKey   
                     AND SKU = @cSKU   
            OPEN CUR_RECEIPTDETAIL  
            FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cReceiptLineNumber, @cTempToLoc, @cTempToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @dTempLottable05  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               IF (@cToLoc = @cTempToLoc OR @cTempToLoc = '')   
                  AND (@cTOID = @cTempToID OR @cTempToID = '')  --if same loc & same pallet id (need to check loc as well???)  
                  AND (@cTempLottable01 = '' OR @cTempLottable01 = @cLottable01)  
                  AND (@cTempLottable02 = '' OR @cTempLottable02 = @cLottable02)  
                  AND (@cTempLottable03 = '' OR @cTempLottable03 = @cLottable03)  
                  AND (@dTempLottable04 = NULL OR @dTempLottable04 = @dLottable04)  
                  AND (@dTempLottable05 = NULL OR @dTempLottable05 = @dLottable05)  
            BEGIN  
                     CLOSE CUR_RECEIPTDETAIL  
                     DEALLOCATE CUR_RECEIPTDETAIL                      
                     GOTO Process_4_1  
            END  
               ELSE  
                  FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cReceiptLineNumber, @cTempToLoc, @cTempToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @dTempLottable05  
            END                                   
            CLOSE CUR_RECEIPTDETAIL  
            DEALLOCATE CUR_RECEIPTDETAIL  
        
            GOTO Process_4_2   -- if receipt detail line not found, insert new  
         END  
         ELSE  
         BEGIN  
            SELECT   
               @cReceiptLineNumber = ReceiptLineNumber,   
               @cTempToID = TOID   
               FROM dbo.RECEIPT R (NOLOCK)   
               INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK) ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
               WHERE R.STORERKEY = @cStorerKey   
                  AND R.RECEIPTKEY = @cReceiptKey   
                  AND SKU = @cSKU   
                  AND RD.POKey = @cPOKey   
                  AND RD.POLineNumber = @cPOLineNumber  
                  --sos#65746 -start  
                  AND Lottable01 = @cLottable01   
                  AND Lottable02 = @cLottable02   
                  AND Lottable03 = @cLottable03   
                  AND Lottable04 = @dLottable04   
                  AND Lottable05 = @dLottable05   
                  --sos#65746 -end  
               IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> ''    --can found the corespondence receiptdetail line  
                  IF @cTempToID = ''   --toid is same  
                     GOTO Process_5_1   --then update only  
                  ELSE  
                     BEGIN  
                        SET @cReceiptLineNumber = ''  -- (james01)  
                        SELECT @cReceiptLineNumber = RD.RECEIPTLINENUMBER   
                           FROM dbo.RECEIPT R (NOLOCK)   
                           INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK)   
                           ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
                           WHERE R.STORERKEY = @cStorerKey AND R.RECEIPTKEY = @cReceiptKey AND SKU = @cSKU   
                           AND RD.POKEY = @cPOKey AND RD.POLineNumber = @cPOLineNumber AND TOID = @cTOID  
                        IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> ''    --can found the corespondence receiptdetail line                          
                           GOTO Process_4_1  
                        ELSE  
                           GOTO Process_4_2  
                     END                                   
               ELSE  
                  GOTO Process_4_2   --insert new line if receiptdetail line not found or loc not same or id not same  
            END  
  
            Process_4_1:  
            BEGIN  
               SELECT   
                  @nExpectedQty = QtyExpected,   
                  @nBeforeReceivedQty = BeforeReceivedQty   
                  FROM dbo.ReceiptDetail (NOLOCK)   
                  WHERE StorerKey = @cStorerKey   
                     AND ReceiptKey = @cReceiptKey   
                     AND ReceiptLineNumber = @cReceiptLineNumber  
  
               SELECT top 1   
                  @nTempQtyExpected = QtyExpected,   
                  @cPrevReceiptLineNumber = ReceiptLineNumber                     
                  FROM dbo.ReceiptDetail (NOLOCK)   
                  WHERE StorerKey = @cStorerKey   
                     AND ReceiptKey = @cReceiptKey   
                     AND SKU = @cSKU     
                     AND QtyExpected > 0  
                  ORDER BY ReceiptLineNumber  
  
               IF @nExpectedQty >= @nBeforeReceivedQty + @nQTY   --received qty is enough for current receiptdetail line  
                     UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)   
                        SET   
                           BeforeReceivedQty = BeforeReceivedQty + @nQTY,   
                           TOLOC = @cToLoc,   
                           TOID = @cTOID,  
                           Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END,    
                           Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END,    
                           Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END,    
                           Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE Lottable04 END,    
                           Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE Lottable05 END   
                        WHERE STORERKEY = @cStorerKey   
                           AND RECEIPTKEY = @cReceiptKey   
                           AND RECEIPTLINENUMBER = @cReceiptLineNumber  
               ELSE   --received qty is more than enough for current pallet, check for over receipt  
                  BEGIN  
                     IF @cAllow_OverReceipt <> '1'   --not allow over receipt  
                        BEGIN  
                           SET @cErrMsg = rdt.rdtgetmessage( 61124, @cLangCode, 'DSP') --61124 X Allow OverRcpt  
                           SET @nScn  = 986  
                           SET @nStep = 3  
                           SET @cOutField01 = @cUCCNo  
                           SET @cOutField02 = ''  
                           SET @cOutField03 = ''  
                           SET @cOutField04 = ''  
                           SET @cOutField05 = ''  
                           SET @cOutField06 = ''  
                           SET @cOutField07 = ''  
                           SET @cOutField08 = ''  
                           SET @cOutField09 = ''  
                           SET @cOutField10 = ''  
                           SET @cOutField11 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
                           GOTO Quit  
                        END                      
  
                     IF @cAllow_OverReceipt = '1'   --allow over receipt  
                        BEGIN  
                           UPDATE dbo.ReceiptDetail WITH (ROWLOCK)   
                              SET BeforeReceivedQty = BeforeReceivedQty + @nQTY,   
                              QtyExpected = CASE WHEN @nTempQtyExpected > 0 THEN QtyExpected + @nQTY ELSE QtyExpected END,   
                              Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END,    
                              Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END,    
                              Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END,    
                              Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE Lottable04 END,    
                              Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE Lottable05 END   
                              WHERE STORERKEY = @cStorerKey   
                                 AND RECEIPTKEY = @cReceiptKey   
                                 AND RECEIPTLINENUMBER = @cReceiptLineNumber  
  
                           UPDATE dbo.ReceiptDetail WITH (ROWLOCK)   
                              SET QtyExpected = QtyExpected - @nQTY   
                              WHERE STORERKEY = @cStorerKey   
                                 AND ReceiptKey = @cReceiptKey   
                                 AND ReceiptLineNumber = @cPrevReceiptLineNumber  
                                 AND QtyExpected > 0  
                        END  
  
                  END  
               GOTO Process_UCC  
            END  
  
         Process_4_2:  
         BEGIN  
            SELECT   
               @cNextReceiptLineNumber = MAX(ReceiptLineNumber)   
               FROM dbo.ReceiptDetail (NOLOCK)   
               WHERE StorerKey = @cStorerKey   
                  AND ReceiptKey = @cReceiptKey  
  
            IF ISNULL(LTRIM(RTRIM(@cNextReceiptLineNumber)), '') = ''  
         --if blank ASN detail, give it line number  
               SET @cNextReceiptLineNumber = '00001'  
            ELSE  
            --get the next receiptdetail line number                 
            SET @cNextReceiptLineNumber = CAST(@cNextReceiptLineNumber AS INT) + 1  
            SET @cNextReceiptLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(CHAR(5), @cNextReceiptLineNumber ) ) , 5)  
  
            IF ISNULL(LTRIM(RTRIM(@cPOKey)), '') <> '' AND ISNULL(LTRIM(RTRIM(@cPOLineNumber)), '') <> ''  
            BEGIN  
               SET @cReceiptLineNumber = ''  -- (james01)  
               SELECT @cReceiptLineNumber = RD.ReceiptLineNumber FROM dbo.Receipt R (NOLOCK)   
                  INNER JOIN dbo.ReceiptDetail RD (NOLOCK) ON R.StorerKey = RD.StorerKey AND R.ReceiptKey = RD.ReceiptKey   
                  WHERE R.StorerKey = @cStorerKey   
                     AND R.ReceiptKey = @cReceiptKey   
                     AND SKU = @cSKU   
                     AND RD.POKey = @cPOKey   
                     AND RD.POLineNumber = @cPOLineNumber   
                  ORDER BY RD.ReceiptLineNumber DESC  
            END  
  
            IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> ''  
            BEGIN  
               SELECT   
                  @nExpectedQty = QtyExpected,   
                  @nBeforeReceivedQty = BeforeReceivedQty   
                  FROM dbo.ReceiptDetail (NOLOCK)   
                  WHERE StorerKey = @cStorerKey   
                     AND ReceiptKey = @cReceiptKey   
                     AND ReceiptLineNumber = @cReceiptLineNumber  
        
               UPDATE dbo.ReceiptDetail WITH (ROWLOCK)   
                  SET QtyExpected = QtyExpected - @nQTY   
                  WHERE StorerKey = @cStorerKey   
                     AND ReceiptKey = @cReceiptKey   
                     AND ReceiptLineNumber = @cReceiptLineNumber  
            END  
  
            SET @cExternReceiptKey = ''  
            SET @cExternLineNo = ''  
  
            SELECT @cSourceKey = SourceKey   
               FROM dbo.UCC (NOLOCK)   
               WHERE StorerKey = @cStorerKey   
                  AND UCCNo = @cUCCNo   
                  AND Status = '0'  
  
            SET @cPOLineNumber = RIGHT(RTRIM(@cSourceKey), 5)  
  
            IF @cPOKey <> '' AND @cPOLineNumber <> ''  
            BEGIN  
               SELECT   
                  @cExternReceiptKey = ExternPOKey,   
                  @cExternLineNo = ExternLineNo   
                  FROM dbo.PODETAIL (NOLOCK)   
                  WHERE POKEY = @cPOKey   
                     AND POLineNumber = @cPOLineNumber   
                     AND SKU = @cSKU     
            END  
            ELSE  
            BEGIN  
               SELECT   
                  @cExternReceiptKey = ExternPOKey,   
                  @cExternLineNo = ExternLineNo   
                  FROM dbo.PODETAIL (NOLOCK)   
                  WHERE POKEY = @cPOKey   
                     AND SKU = @cSKU     
            END  
            
               INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber,   
                  ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, Status, DateReceived,    
                  QtyExpected, QtyAdjusted, QtyReceived, UOM, PackKey, VesselKey, VoyageKey, XdockKey,    
                  ContainerKey, ToLoc, ToLot, ToId, ConditionCode, Lottable01, Lottable02, Lottable03,    
                  Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, [Cube], GrossWgt, NetWgt, OtherUnit1,    
                  OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate, AddDate, AddWho, EditDate, EditWho,    
                  TrafficCop, ArchiveCop, TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode,    
                  FinalizeFlag, DuplicateFrom, BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag,    
                  POLineNumber, LoadKey, ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04,    
                  UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10) VALUES             
                 (@cReceiptKey, @cNextReceiptLineNumber, @cExternReceiptKey, @cExternLineNo,   
                  @cStorerKey, @cPOKey, @cSKU, '', '', '0',  GetDate(),   
                  @nQty, 0,  0, @cUOM, @cPackKey, '', '', '',   
                  '', @cToLoc, NULL, @cTOID, 'OK', @cLottable01, @cLottable02, @cLottable03,   
                  @dLottable04, @dLottable05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, GetDate(),    
                  GetDate(), user_name(), GetDate(), user_name(), NULL, NULL, @cTariffkey, 0, 0, '',    
                  'N', NULL, @nQTY, NULL, NULL, 'N', @cPOLineNumber, NULL, @cExternReceiptKey, '', '',   
                  '', '', '', NULL, NULL, '', '', '')  
            END  
         GOTO Process_UCC  
  
         Process_UCC:  
         BEGIN  
            IF ISNULL(LTRIM(RTRIM(@cNextReceiptLineNumber)),'') <> ''  
               SET @cReceiptLineNumber = @cNextReceiptLineNumber  
  
            IF NOT EXISTS (SELECT 1 FROM dbo.UCC (NOLOCK)   
               WHERE STORERKEY = @cStorerKey AND UCCNO = @cUCCNo)  
               BEGIN                            
                  INSERT INTO dbo.UCC (UCCNo, Storerkey, ExternKey, SKU, qty, Sourcekey, Sourcetype,   
                      Userdefined01, Userdefined02, Userdefined03,    
  
                      Status, Lot, Loc, Id, Receiptkey, ReceiptLineNumber, Orderkey, OrderLineNumber,   
                      WaveKey, PickDetailKey)  
                   VALUES  
                      (@cUCCNo, @cStorerKey, @cExternKey, @cSKU, @nQTY, ISNULL(LTRIM(RTRIM(@cReceiptKey)), '') + ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), ''), 'RECEIPT', -- (Vicky01)  
                      '','','', '1', '', @cToLoc, @cTOID, @cReceiptKey, @cReceiptLineNumber, '','', '', '')  
               END  
               ELSE  
               BEGIN  
                 IF @cReceivedByUPC = 'TRUE'  
                     UPDATE dbo.UCC WITH (ROWLOCK)   
                        SET RECEIPTKEY = @cReceiptKey, RECEIPTLINENUMBER = @cReceiptLineNumber,   
                        STATUS = '6', LOC = @cToLoc, ID = @cTOID, ExternKey = @cExternKey, EditDate=getdate(), EditWho=user_name()    
                        WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCNo AND SKU = @cSKU  
                  ELSE  
                     UPDATE dbo.UCC WITH (ROWLOCK)   
                        SET RECEIPTKEY = @cReceiptKey,   
                        RECEIPTLINENUMBER = @cReceiptLineNumber, STATUS = '1', LOC = @cToLoc,   
                        ID = @cTOID, ExternKey = @cExternKey, EditDate=getdate(), EditWho=user_name()    
                        WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCNo AND SKU = @cSKU          
               END           
         GOTO Step_4_Next  
         END  
      END  
     
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      GOTO Quit  
   END  
  
   Step_4_Next:  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
      SET @cCartonCnt = @cCartonCnt + 1  
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
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
--       SET @nScn  = 988  
--       SET @nStep = 5  
--       SET @cOutField01 = @cUCCNo  
--       SET @cOutField02 = ''  
--      SET @cOutField03 = @cSKU  
--       SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
--       SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
--       SET @cOutField06 = LTRIM(RTRIM(@cPPK)) + '/' + LTRIM(RTRIM(@cPQIndicator))  
--       SET @cOutField07 = @cLottable02  
--       SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)  
--       SET @cOutField09 = @cUOM   
--       SET @cOutField10 = @nQTY   
--       SET @cOutField11 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      GOTO Quit  
   END  
  
   Step_4_Fail:  
   BEGIN  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      GOTO QUIT  
   END  
  
END  
GOTO QUIT  
  
/********************************************************************************  
Step 5. screen (scn = 988)  
  
   UCC#:   
   xxxxxxxxxxxxxxxxxxxx  
   SKU/UPC:   
   xxxxxxxxxxxxxxxxxxxx  
   Desc: xxxxxxxxxx  
   xxxxxxxxxxxxxxxxxxxx  
   PPK/DU: xxxxx  
   Lottable02/04:   
   2 xxxxxxxxxxxxxxxxxx  
   4 xxxxxxxxxxxxxxxxxx  
   UOM xxxxx Qty: xxxxx       
   Ctn: xx/xx  
********************************************************************************/  
Step_5:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      IF @cPOKey = ''  
      BEGIN  
         DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
            SELECT   
               RD.RECEIPTLINENUMBER,   
               TOLOC,   
               TOID,  
               Lottable01,    
               Lottable02,    
               Lottable03,    
               Lottable04,    
               Lottable05    
            FROM dbo.RECEIPT R (NOLOCK)   
            INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK) ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
            WHERE R.STORERKEY = @cStorerKey   
               AND R.RECEIPTKEY = @cReceiptKey   
               AND SKU = @cSKU  
            OPEN CUR_RECEIPTDETAIL  
            FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cReceiptLineNumber, @cTempToLoc, @cTempToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @dTempLottable05  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               IF (@cToLoc = @cTempToLoc OR @cTempToLoc = '')   
                  AND (@cTOID = @cTempToID OR @cTempToID = '')  --if same loc & same pallet id (need to check loc as well???)  
                  AND (@cTempLottable01 = '' OR @cTempLottable01 = @cLottable01)  
                  AND (@cTempLottable02 = '' OR @cTempLottable02 = @cLottable02)  
                  AND (@cTempLottable03 = '' OR @cTempLottable03 = @cLottable03)  
                  AND (@dTempLottable04 = NULL OR @dTempLottable04 = @dLottable04)  
                  AND (@dTempLottable05 = NULL OR @dTempLottable05 = @dLottable05)  
               BEGIN  
                  CLOSE CUR_RECEIPTDETAIL  
                   DEALLOCATE CUR_RECEIPTDETAIL                      
                   GOTO Process_5_1  
               END  
               ELSE  
                  FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cReceiptLineNumber, @cTempToLoc, @cTempToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @dTempLottable05                 
            END                                   
            CLOSE CUR_RECEIPTDETAIL  
            DEALLOCATE CUR_RECEIPTDETAIL  
    
            GOTO Process_5_2   -- if receipt detail line not found, insert new line  
      END  
      ELSE  
      BEGIN  
         SET @cReceiptLineNumber = ''  
         SELECT @cReceiptLineNumber = RD.RECEIPTLINENUMBER, @cTempToID = TOID   
                  FROM dbo.RECEIPT R (NOLOCK)   
                     INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK)   
                     ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
                     WHERE R.STORERKEY = @cStorerKey   
                     AND R.RECEIPTKEY = @cReceiptKey AND SKU = @cSKU   
                     AND RD.POKEY = @cPOKey AND RD.POLineNumber = @cPOLineNumber  
                     --sos#65746 -start  
                     AND Lottable01 = @cLottable01   
                     AND Lottable02 = @cLottable02   
                     AND Lottable03 = @cLottable03   
                     AND Lottable04 = @dLottable04   
                     AND Lottable05 = @dLottable05   
                     --sos#65746 -end  
  
               IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> '' --can found the corespondence receiptdetail line  
                  IF @cTempToID = ''   --toid is same  
                     GOTO Process_5_1   --then update only  
                  ELSE  
                     BEGIN  
                        SET @cReceiptLineNumber = ''  
                        SELECT @cReceiptLineNumber = RD.RECEIPTLINENUMBER   
                           FROM dbo.RECEIPT R (NOLOCK)   
                              INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK)   
                              ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
                              WHERE R.STORERKEY = @cStorerKey   
                              AND R.RECEIPTKEY = @cReceiptKey AND SKU = @cSKU   
                              AND RD.POKEY = @cPOKey   
                              AND RD.POLineNumber = @cPOLineNumber   
                              AND TOID = @cTOID  
                              --sos#65746 -start  
                              AND Lottable01 = @cLottable01   
                              AND Lottable02 = @cLottable02   
                              AND Lottable03 = @cLottable03   
                              AND Lottable04 = @dLottable04   
                              AND Lottable05 = @dLottable05   
                              --sos#65746 -end  
                        IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> ''    --can found the corespondence receiptdetail line                          
                           GOTO Process_5_1  
                        ELSE  
                           GOTO Process_5_2  
                     END                                   
               ELSE  
                  GOTO Process_5_2   --insert new line if receiptdetail line not found or loc not same or id not same  
            END  
  
         Process_5_1:  
         BEGIN  
            SELECT   
               @nExpectedQty = QtyExpected,   
               @nBeforeReceivedQty = BeforeReceivedQty   
            FROM dbo.RECEIPTDETAIL (NOLOCK)   
            WHERE STORERKEY = @cStorerKey   
               AND RECEIPTKEY = @cReceiptKey   
               AND RECEIPTLINENUMBER = @cReceiptLineNumber  
            IF @nExpectedQty >= @nBeforeReceivedQty + @nQTY   --received qty is enough for current receiptdetail line  
            BEGIN  
               UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)   
                  SET   
                     BeforeReceivedQty = BeforeReceivedQty + @nQTY,   
                     TOLOC = @cToLoc,   
                     TOID = @cTOID,   
                     Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END,    
                     Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END,    
                     Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END,    
                     Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE Lottable04 END,    
                     Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE Lottable05 END   
                     WHERE STORERKEY = @cStorerKey   
                        AND RECEIPTKEY = @cReceiptKey   
                        AND RECEIPTLINENUMBER = @cReceiptLineNumber  
            END  
            ELSE   --received qty is more than enough, check for over receipt  
            BEGIN  
               IF @cAllow_OverReceipt <> '1'   --not allow over receipt  
               BEGIN  
                   SET @cErrMsg = rdt.rdtgetmessage( 61124, @cLangCode, 'DSP') --X Allow OverRcpt  
                   SET @nScn  = 986  
                   SET @nStep = 3  
                   SET @cOutField01 = @cUCCNo  
                   SET @cOutField02 = ''  
                   SET @cOutField03 = ''  
                   SET @cOutField04 = ''  
                   SET @cOutField05 = ''  
                   SET @cOutField06 = ''  
                   SET @cOutField07 = ''  
                   SET @cOutField08 = ''  
                   SET @cOutField09 = ''  
                   SET @cOutField10 = ''  
                   SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
                   GOTO Quit  
               END                
               IF @cAllow_OverReceipt = '1'   --allow over receipt  
               BEGIN  
                  UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)   
                   SET   
                     BeforeReceivedQty = BeforeReceivedQty + @nQTY,  
                     Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END,    
                     Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END,    
                     Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END,    
                     Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE Lottable04 END,    
                     Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE Lottable05 END   
                     WHERE STORERKEY = @cStorerKey   
                        AND RECEIPTKEY = @cReceiptKey   
                        AND RECEIPTLINENUMBER = @cReceiptLineNumber  
                END  
            END  
            UPDATE dbo.UCC WITH (ROWLOCK)   
               SET   
                  RECEIPTKEY = @cReceiptKey,   
                  RECEIPTLINENUMBER = @cReceiptLineNumber,   
                  STATUS = '1',   
                  LOC = @cToLoc,   
                  ID = @cTOID,   
                  ExternKey = @cExternKey, EditDate=getdate(), EditWho=user_name()    
                  WHERE STORERKEY = @cStorerkey   
                     AND UCCNO = @cUCCNo   
                     AND SKU = @cSKU  
            GOTO Step_5_Next  
            END  
  
         Process_5_2:  
         BEGIN  
            SELECT   
               @cNextReceiptLineNumber = MAX(ReceiptLineNumber)   
               FROM dbo.ReceiptDetail (NOLOCK)   
               WHERE StorerKey = @cStorerKey   
                  AND ReceiptKey = @cReceiptKey  
  -- if blank ASN detail  
               IF ISNULL(LTRIM(RTRIM(@cNextReceiptLineNumber)), '') = ''  
                  SET @cNextReceiptLineNumber = '00001'  
               ELSE  
                  --get next receipt line number  
                  SET @cNextReceiptLineNumber = CAST(@cNextReceiptLineNumber AS INT) + 1  
                  SET @cNextReceiptLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(CHAR(5), @cNextReceiptLineNumber ) ) , 5)  
  
               IF ISNULL(LTRIM(RTRIM(@cPOKey)), '') <> '' AND ISNULL(LTRIM(RTRIM(@cPOLineNumber)), '') <> ''  
               BEGIN  
                  SET @cReceiptLineNumber = ''  -- (james01)  
                  SELECT @cReceiptLineNumber = RD.RECEIPTLINENUMBER FROM dbo.RECEIPT R (NOLOCK)   
                     INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK)   
                     ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
                     WHERE R.STORERKEY = @cStorerKey AND R.RECEIPTKEY = @cReceiptKey AND SKU = @cSKU   
                     AND RD.POKEY = @cPOKey AND RD.POLineNumber = @cPOLineNumber   
                     ORDER BY RD.RECEIPTLINENUMBER DESC  
               END  
  
               IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> ''  
               BEGIN                                               
                  SELECT   
                     @nExpectedQty = QtyExpected,   
                     @nBeforeReceivedQty = BeforeReceivedQty   
                     FROM dbo.ReceiptDetail (NOLOCK)   
                     WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey   
                     AND ReceiptLineNumber = @cReceiptLineNumber  
        
                  UPDATE dbo.ReceiptDetail WITH (ROWLOCK)   
                     SET QtyExpected = QtyExpected - @nQTY,    
                     Lottable01 = CASE WHEN @cLottable01 <> '' THEN @cLottable01 ELSE Lottable01 END,    
                     Lottable02 = CASE WHEN @cLottable02 <> '' THEN @cLottable02 ELSE Lottable02 END,    
                     Lottable03 = CASE WHEN @cLottable03 <> '' THEN @cLottable03 ELSE Lottable03 END,    
                     Lottable04 = CASE WHEN @dLottable04 <> '' THEN @dLottable04 ELSE Lottable04 END,    
                     Lottable05 = CASE WHEN @dLottable05 <> '' THEN @dLottable05 ELSE Lottable05 END                     
                     WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey   
                     AND ReceiptLineNumber = @cReceiptLineNumber  
               END  
                   
               SET @cExternReceiptKey = ''  
               SET @cExternLineNo = ''  
  
                  SELECT   
                  @cSourceKey = SOURCEKEY   
                  FROM dbo.UCC (NOLOCK)   
                  WHERE STORERKEY = @cStorerKey   
                     AND UCCNo = @cUCCNo   
                     AND STATUS = '0'  
  
               SET @cPOLineNumber = RIGHT(RTRIM(@cSourceKey), 5)  
  
               IF @cPOKey <> '' AND @cPOLineNumber <> ''  
                  SELECT @cExternReceiptKey = ExternPOKey, @cExternLineNo = ExternLineNo FROM dbo.PODETAIL (NOLOCK)   
                     WHERE POKEY = @cPOKey AND POLineNumber = @cPOLineNumber AND SKU = @cSKU     
               ELSE  
                  SELECT @cExternReceiptKey = ExternPOKey, @cExternLineNo = ExternLineNo FROM dbo.PODETAIL (NOLOCK)   
                     WHERE POKEY = @cPOKey AND SKU = @cSKU     
  
               INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber,   
                  ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, Status, DateReceived,    
                  QtyExpected, QtyAdjusted, QtyReceived, UOM, PackKey, VesselKey, VoyageKey, XdockKey,    
                  ContainerKey, ToLoc, ToLot, ToId, ConditionCode, Lottable01, Lottable02, Lottable03,    
                  Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, [Cube], GrossWgt, NetWgt, OtherUnit1,    
                  OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate, AddDate, AddWho, EditDate, EditWho,   
                  TrafficCop, ArchiveCop, TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode,    
                  FinalizeFlag, DuplicateFrom, BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag,    
                  POLineNumber, LoadKey, ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04,    
                  UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10) VALUES             
               (@cReceiptKey, @cNextReceiptLineNumber, @cExternReceiptKey, @cExternLineNo,   
                  @cStorerKey, @cPOKey, @cSKU, '', '', '0',  GetDate(),   
                  @nQty, 0,  0, @cUOM, @cPackKey, '', '', '',   
                  '', @cToLoc, NULL, @cTOID, 'OK', @cLottable01, @cLottable02, @cLottable03,   
                  @dLottable04, @dLottable05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, GetDate(),    
                  GetDate(), user_name(), GetDate(), user_name(), NULL, NULL, @cTariffkey, 0, 0, '',    
                  'N', NULL, @nQTY, NULL, NULL, 'N', @cPOLineNumber, NULL, @cExternReceiptKey, '', '',   
                  '', '', '', NULL, NULL, '', '', '')  
  
               --added by james on 06/11/2006 start (to copy other field value as well when copy from other receiptdetail line  
                 
               --end add by james  
  
                  UPDATE dbo.UCC WITH (ROWLOCK)   
                     SET RECEIPTKEY = @cReceiptKey,   
                     RECEIPTLINENUMBER = @cNextReceiptLineNumber, STATUS = '1', LOC = @cToLoc,   
                     ID = @cTOID, ExternKey = @cExternKey, EditDate=getdate(), EditWho=user_name()    
                     WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCNo AND SKU = @cSKU  
  
               GOTO Step_5_Next  
            END  
/*    
      IF @cReceivedByUPC = 'FALSE'  
         SET @cSKUCODE = ''  
      ELSE  
         SET @cSKUCODE = @cSKU  
--         SET @cUCCNo = ''  
  
      SET @nErrNo = 0  
      EXECUTE rdt.rdt_Receive   
         0 ,  
--          @nFunc       ,   
         @nMobile     ,  
         @cLangCode   ,   
         @nErrNo      OUTPUT,  
         @cErrMsg     OUTPUT,   
         @cStorerKey  ,  
         @cFacility   ,   
         @cReceiptKey ,   
         @cPOKey      ,   
         @cToLOC      ,   
         @cToID       ,   
         @cSKUCODE    ,   
         @cUOM        , --*@cSKUUOM  
         @nQTY        , --*@nSKUQTY  
         @cUCCNo      ,   
         @cSKU        , --*@cUCCSKU  
         @nQTY        , --*@nUCCQTY  
         @cCreateUCC  ,    
         @cLottable01 ,      
         @cLottable02 ,      
         @cLottable03 ,      
         @dLottable04 ,      
         @dLottable05     
  
      IF @nErrNo <> 0  
      BEGIN  
         GOTO Step_4_Fail  
      END  
*/     
   END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      GOTO Quit  
   END  
  
   Step_5_Next:  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
      SET @cCartonCnt = CAST(@cCartonCnt AS INT) + 1   --increase carton count by 1  
      SET @cOutField01 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      GOTO Quit  
   END  
  
   Step_5_Fail:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
  
END  
GOTO QUIT  
  
/********************************************************************************  
Step 6. screen (scn = 989)  
< Max no. of carton  
Confirm ??: (@cInField01)  
1 = Yes 2 = No  
  
********************************************************************************/  
Step_6:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cConfirm = @cInField01  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      IF ISNULL(LTRIM(RTRIM(@cConfirm)), '') <> '1' AND ISNULL(LTRIM(RTRIM(@cConfirm)), '') <> '2' -- (Vicky01)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 4, @cLangCode, 'DSP') --Invalid Option  
         SET @cConfirm = ''  
         GOTO Step_6_Fail        
      END  
  
      --exit back to step 2 screen  
      IF ISNULL(LTRIM(RTRIM(@cConfirm)), '') = '1'    -- (Vicky01)  
      BEGIN  
         GOTO Step_6_Next  
      END  
  
      IF ISNULL(LTRIM(RTRIM(@cConfirm)), '') = '2' -- (Vicky01)  
      BEGIN  
         SET @nScn  = 986  
         SET @nStep = 3  
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
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END  
   END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
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
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      GOTO Quit  
   END  
  
   Step_6_Next:  
   BEGIN  
      SET @nScn  = 985  
      SET @nStep = 2  
      SET @cOutField01 = @cToLoc  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cLottable01 = ''  
      SET @cLottable02 = ''  
      SET @cLottable03 = ''  
      SET @dLottable04 = NULL  
      SET @dLottable05 = NULL  
      SET @cLottable06 = ''         --(CS01)  
    SET @cLottable07 = ''         --(CS01)  
    SET @cLottable08 = ''         --(CS01)  
    SET @cLottable09 = ''         --(CS01)  
    SET @cLottable10 = ''         --(CS01)  
    SET @cLottable11 = ''         --(CS01)   
    SET @cLottable12 = ''         --(CS01)  
    SET @dLottable13 = NULL       --(CS01)  
    SET @dLottable14 = NULL       --(CS01)  
    SET @dLottable15 = NULL       --(CS01)  
      SET @cTOID = ''  
      SET @cUCCNo = ''  
      SET @cSKU = ''  
      SET @cDescr = ''  
      SET @cPPK = ''  
      SET @cPQIndicator = ''  
      SET @nQTY = ''  
      SET @cUOM = ''  
      SET @cCartonCnt = '0'  
      SET @cTotalCartonCnt = ''  
      SET @cTotalPalletCnt = @cTotalPalletCnt  
      SET @cReceiptLineNumber = ''  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 2  
      GOTO Quit  
   END  
  
   Step_6_Fail:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
  
END  
GOTO QUIT  
/********************************************************************************  
Step 7. screen (scn = 990)  
Do you want to   
accept this UCC??  
(Y/N)(@cInField01)  
1 = Yes 2 = No  
  
********************************************************************************/  
Step_7:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cConfirm = @cInField01  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      IF ISNULL(LTRIM(RTRIM(@cConfirm)), '') <> '1' AND ISNULL(LTRIM(RTRIM(@cConfirm)), '') <> '2' -- (Vicky01)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 4, @cLangCode, 'DSP') --Invalid Option  
         SET @cConfirm = ''  
         GOTO Step_7_Fail        
      END  
     
      IF ISNULL(LTRIM(RTRIM(@cConfirm)), '') = '1'   --Yes -- (Vicky01)  
      BEGIN  
         GOTO Step_7_Next  
      END  
  
      IF ISNULL(LTRIM(RTRIM(@cConfirm)), '') = '2'   --No -- (Vicky01)  
      BEGIN  
         SET @nScn  = 986  
         SET @nStep = 3  
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
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         SET @cCreateUCC = '0'  
         EXEC rdt.rdtSetFocusField @nMobile, 1  
         GOTO Quit  
      END  
   END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      GOTO Quit  
   END  
  
   Step_7_Next:  
   BEGIN  
      SET @nScn = 992  
      SET @nStep = 9  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ''  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      SET @cCreateUCC = '1'  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 3  
      GOTO Quit  
   END  
  
   Step_7_Fail:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
  
END  
GOTO Quit  
  
/********************************************************************************  
Step 8. screen (scn = 991)  
   TOLOC#: xxxxxxxxxx  
   TOID#:   
   xxxxxxxxxxxxxxxxxx  
  
   TOTAL CTNS: (@cInField03)  
********************************************************************************/  
Step_8:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cTotalCartonCnt = @cInField03  
  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      IF ISNULL(LTRIM(RTRIM(@cInField03)),'') = ''  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61107, @cLangCode, 'DSP') --Total ctns required  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Step_8_Fail        
      END  
  
      IF CAST(@cInField03 AS INT) <= CAST(@cTotalCartonCnt AS INT)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61115, @cLangCode, 'DSP') --Invalid Carton  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Step_8_Fail        
      END  
  
      GOTO Step_8_Next  
   END        
  
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 984  
   SET @nStep = 4  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 3  
      GOTO Quit  
   END  
  
   Step_8_Next:  
   BEGIN  
      SET @nScn  = 984  
      SET @nStep = 4  
      SET @cOutField01 = @cUCCNo  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = ''  
      SET @cOutField10 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 3  
      GOTO Quit  
   END  
  
   Step_8_Fail:  
   BEGIN  
      SET @cOutField03 = @cTotalCartonCnt  
   END  
  
END  
GOTO Quit  
  
/********************************************************************************  
Step 9. screen (scn = 992)  
  
   UCC#:   
   xxxxxxxxxxxxxxxxxxxx  
   SKU/UPC:  
   (@cInField03)  
   Desc:   xxxxxxxxxx  
   xxxxxxxxxxxxxxxxxxxx  
   PPK: xxxxx  
   Lottable02/04:   
   2 xxxxxxxxxxxxxxxxxx  
   4 xxxxxxxxxxxxxxxxxx  
   UOM: xxxxx Qty:xxxxx  
   Ctn: xx/xx  
********************************************************************************/  
Step_9:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cSKU = @cInField03  
  
      IF ISNULL(LTRIM(RTRIM(@cSKU)),'') = ''  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61113, @cLangCode, 'DSP') --sku required  
         SET @cSKU = ''  
         GOTO Step_9_Fail        
      END     
  
      -- Performance tuning (james02) start  
      -- Check the validity of the SKU code entered  
      EXEC [RDT].[rdt_GETSKUCNT]  
       @cStorerKey  = @cStorerKey  
      ,@cSKU        = @cSKU  
      ,@nSKUCnt     = @nSKUCnt       OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @n_Err         OUTPUT  
      ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61114, @cLangCode, 'DSP') --'Invalid SKU'  
         SET @cSKU = ''  
         GOTO Step_9_Fail        
      END  
  
      -- Validate barcode return multiple SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 60436, @cLangCode, 'DSP') --'SKU had same barcode'  
         GOTO Step_9_Fail  
      END  
  
      -- Get the actual SKU code  
      EXEC [RDT].[rdt_GETSKU]  
       @cStorerKey  = @cStorerKey  
      ,@cSKU        = @cSKU          OUTPUT  
      ,@bSuccess    = @b_Success     OUTPUT  
      ,@nErr        = @n_Err         OUTPUT  
      ,@cErrMsg     = @c_ErrMsg      OUTPUT  
  
      -- Check whether SKU exists within ReceiptDetail  
      IF NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey  
         AND ReceiptKey = @cReceiptKey  
         AND SKU = @cSKU)  
      BEGIN  
         SET @cErrMsg = rdt.rdtgetmessage( 61123, @cLangCode, 'DSP') --SKU Not In ASN  
         SET @cSKU = ''  
         GOTO Step_9_Fail        
      END  
  
      -- Get SKU description  
      SELECT @cDescr = IsNULL( DescR, '') FROM dbo.SKU WITH (NOLOCK)   
      WHERE StorerKey = @cStorerKey  
         AND SKU = @cSKU  
      /*  
         SELECT   
            @nCount = COUNT( DISTINCT SKU.SKU),   
            @cSKU = MIN( SKU.SKU) -- using MIN() just to bypass SQL aggregate checking  
         FROM dbo.ReceiptDetail RD (NOLOCK)  
            INNER JOIN dbo.SKU SKU (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)  
            LEFT OUTER JOIN dbo.UPC UPC (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)  
         WHERE RD.ReceiptKey = @cReceiptKey  
            AND (@cInField03 IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cInField03)  
  
         IF @nCount = 0  
         BEGIN  
            -- Get SKU description  
            SELECT @cDescr = IsNULL( DescR, '')  
            FROM dbo.SKU SKU (NOLOCK)   
               LEFT OUTER JOIN dbo.UPC UPC (NOLOCK) ON (SKU.StorerKey = UPC.StorerKey AND SKU.SKU = UPC.SKU)  
            WHERE SKU.StorerKey = @cStorerKey   
               AND (@cInField03 IN (SKU.SKU, SKU.AltSKU, SKU.RetailSKU, SKU.ManufacturerSKU) OR UPC.UPC = @cInField01)  
     
            IF @@ROWCOUNT = 0  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61114, @cLangCode, 'DSP') --'Invalid SKU'  
               SET @cSKU = ''  
               GOTO Step_9_Fail        
            END   
            ELSE  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61123, @cLangCode, 'DSP') --SKU Not In ASN  
               SET @cSKU = ''  
               GOTO Step_9_Fail        
            END  
         END  
  
         IF @nCount > 1  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 60436, @cLangCode, 'DSP') --'SKU had same barcode'  
            GOTO Step_9_Fail  
         END  
      */  
      -- Performance tuning (james02) end  
  
         IF EXISTS (SELECT 1 FROM dbo.UCC (NOLOCK)   
            WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCNo)  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM dbo.UCC (NOLOCK)   
            WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCNo AND SKU = @cSKU)  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61115, @cLangCode, 'DSP') --SKU Not Match  
               SET @cSKU = ''  
               GOTO Step_9_Fail        
            END    
         END  
  
         SELECT @cPPK = PREPACKINDICATOR,   
            @cPQIndicator = PackQtyIndicator, @cTariffkey = Tariffkey   
            FROM dbo.SKU (NOLOCK)  
            WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
         SELECT @cPackKey = PACKKEY FROM dbo.RECEIPTDETAIL (NOLOCK)  
          WHERE StorerKey = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND SKU = @cSKU                       
  
         SELECT @cUOM = PACK.PackUOM3, @nCaseCntQty = PACK.CASECNT FROM dbo.SKU SKU (NOLOCK)   
            INNER JOIN dbo.PACK PACK (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY   
            WHERE SKU.STORERKEY = @cStorerKey AND SKU.SKU = @cSKU  
  
  
         SET @cReceivedByUPC = 'FALSE'  
         GOTO Step_9_Next                       
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 986  
      SET @nStep = 3  
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
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      GOTO Quit  
   END  
  
   Step_9_Next:  
   BEGIN  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      IF (rdt.RDTGetConfig( 0, 'ScanLot', @cStorerKey) = '1')   
      BEGIN   --if storerconfig 'scanlot' is on then goto scan lot screen  
         SET @nScn  = 994  
         SET @nStep = 11  
         --prepare lottable screen variable  
         SET @cOutField01 = ''  
         SET @cOutField03 = ''  
         SET @cOutField05 = ''  
    SET @cOutField07 = ''  
         SET @cOutField09 = ''  
  
      SELECT           
         @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),   
         @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),   
         @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),   
         @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),  
         @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),  
         @cLottable05_Code = IsNULL( S.Lottable05Label, '')  
      FROM dbo.SKU S (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   SKU = @cSKU  
  
      -- Turn on lottable flag (use later)  
      SET @cHasLottable = '0'  
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR  
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR  
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR  
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR  
         (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)  
      SET @cHasLottable = '1'  
  
      -- Initiate next screen var  
      IF @cHasLottable = '1'  
      BEGIN  
         -- Clear all outfields  
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
  
         -- Initiate labels  
         SELECT   
            @cOutField01 = 'Lottable01:',   
            @cOutField03 = 'Lottable02:',  
            @cOutField05 = 'Lottable03:',   
            @cOutField07 = 'Lottable04:',   
            @cOutField09 = 'Lottable05:'  
  
         -- Populate labels and lottables  
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL  
         BEGIN  
            SET @cFieldAttr02 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN                    
            SELECT @cOutField01 = @cLotLabel01  
            SET @cOutField02 = ISNULL(LTRIM(RTRIM(@cLottable01)), '')  
         END  
  
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL  
         BEGIN  
            SET @cFieldAttr04 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN              
            SELECT @cOutField03 = @cLotLabel02  
            SET @cOutField04 = ISNULL(LTRIM(RTRIM(@cLottable02)), '')  
         END  
  
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL  
         BEGIN  
            SET @cFieldAttr06 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN                    
            SELECT @cOutField05 = @cLotLabel03  
            SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cLottable03)), '')  
         END  
  
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL  
         BEGIN  
            SET @cFieldAttr08 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            SELECT  @cOutField07 = @cLotLabel04  
            IF ISDATE(@dLottable04) = 1  
            BEGIN  
               SET @cOutField08 = RDT.RDTFormatDate( @dLottable04)  
            END  
         END  
  
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL  
         BEGIN  
            SET @cFieldAttr10 = 'O' -- (Vicky02)           
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            -- Lottable05 is usually RCP_DATE  
            IF @cLottable05_Code = 'RCP_DATE'  
            BEGIN  
               SET @dLottable05 = GETDATE()  
            END  
  
            SELECT  
               @cOutField09 = @cLotLabel05,   
               @cOutField10 = RDT.RDTFormatDate( @dLottable05)  
          END  
         END  
         SET @nFromScn = 992  
         SET @nFromStep = 9  
         EXEC rdt.rdtSetFocusField @nMobile, 1   --set focus to 1st field  
      END  
      ELSE  
      BEGIN  
         SET @nScn  = 987  
         SET @nStep = 4  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
         SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
         SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cPPK)), '') + '/' + ISNULL(LTRIM(RTRIM(@cPQIndicator)), '') -- (Vicky01)  
         SET @cOutField07 = @cLottable02  
         SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)  
         SET @cOutField09 = @cUOM  
         SET @cOutField10 = @nCaseCntQty   --default populate case qty from pack  
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         SET @cReceiptLineNumber = ''  
         SET @cTempToID = ''  
         SET @cTempToLoc = ''  
  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
      END  
      GOTO Quit  
   END  
  
   Step_9_Fail:  
   BEGIN  
      SET @cOutField02 = ''  
      SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
      GOTO QUIT  
   END  
END  
  
/********************************************************************************  
Step 10. screen (scn = 993)  
UCC Qty is NOT valid  
  
Receive by UPC  
********************************************************************************/  
Step_10:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
         SET @nScn  = 992  
         SET @nStep = 9  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = ''  
         SET @cOutField10 = ''  
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)),'0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
--          EXEC rdt.rdtSetFocusField @nMobile, 2  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         GOTO QUIT                                
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
      BEGIN  
         SET @nScn  = 986  
         SET @nStep = 3  
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
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
--          EXEC rdt.rdtSetFocusField @nMobile, 1  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         GOTO QUIT                                
      END  
END  
  
/********************************************************************************  
Step 11. screen (scn = 994)  
  
   Lottable01:  
   (@cInField02)  
     
   Lottable02:  
   (@cInField04)  
     
   Lottable03:  
   (@cInField06)  
     
   Lottable04:  
   (@cInField08)  
  
   Lottable05:  
   (@cInField10)  
  
  
********************************************************************************/  
Step_11:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
         SET @cLottable01 = @cInField02  
         SET @cLottable02 = @cInField04  
         SET @cLottable03 = @cInField06  
         SET @cLottable04 = @cInField08  
         SET @cLottable05 = @cInField10  
  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
  
      -- Validate lottable01  
      IF ISNULL(LTRIM(RTRIM(@cLotLabel01)), '') <> ''   
      BEGIN  
         -- Validate empty  
         IF ISNULL(LTRIM(RTRIM(@cLottable01)), '') = ''   
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61126, @cLangCode, 'DSP') --Invalid Lot1   
            SET @cLottable01 = ''  
            SET @cOutField02 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_11_Fail  
         END  
      ELSE  
      BEGIN  
         /***************************************/   
         /*customization for lottable01 - start */     
         /****************************************/  
         SELECT @cJListName = 'LOTTABLE01'  
  
         SET @cJSPName = ''  
         SET @cJLottableLabel = ''  
              
         SELECT @cJLottableLabel = LOTTABLE01LABEL  
         FROM  dbo.SKU (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
            AND   SKU = @cSKU  
  
         SELECT @cJSPName = RTRIM(LONG)  
         FROM  dbo.CODELKUP (NOLOCK)  
         WHERE ListName = @cJListName  
            AND CODE = @cJLottableLabel  
  
         -- CodeLlup.Long = spname  
         IF @cJSPName <> '' AND @cJSPName IS NOT NULL  
         BEGIN  
            SELECT  
               @cJStorerkey        = @cStorerKey,  
               @cJSku              = @cSKU,  
               @cJLottableLabel    = @cJLottableLabel,  
             @cJLottable01Value  = @cLottable01,    
             @cJLottable02Value  = '',    
             @cJLottable03Value  = '',  
             @dtJLottable04Value = NULL,  
               @dtJLottable05Value = NULL,  
               @cJLottable06Value  = '',         --(CS01)   
             @cJLottable07Value  = '',         --(CS01)   
             @cJLottable08Value  = '',         --(CS01)  
               @cJLottable09Value  = '',         --(CS01)   
             @cJLottable10Value  = '',         --(CS01)   
             @cJLottable11Value  = '',         --(CS01)  
               @cJLottable12Value  = '',         --(CS01)  
               @dtJLottable13Value = NULL,        --(CS01)    
             @dtJLottable14Value = NULL,        --(CS01)   
             @dtJLottable15Value = NULL,        --(CS01)   
               @cJLottable01      = '',  
               @cJLottable02      = '',  
               @cJLottable03      = '',  
               @dtJLottable04     = NULL,  
               @dtJLottable05     = NULL,  
               @cJLottable04      = '',  
               @cJLottable05      = '',  
               @cJLottable06      = '',          --(CS01)  
             @cJLottable07      = '',          --(CS01)  
             @cJLottable08      = '',          --(CS01)  
               @cJLottable09      = '',          --(CS01)  
             @cJLottable10      = '',          --(CS01)  
             @cJLottable11      = '',          --(CS01)  
               @cJLottable12      = '',          --(CS01)  
               @dtJLottable13     = NULL,        --(CS01)   
             @dtJLottable14     = NULL,        --(CS01)  
              @dtJLottable15     = NULL,        --(CS01)  
               @cJLottable13      = '',          --(CS01)  
               @cJLottable14      = '',          --(CS01)  
               @cJLottable15      = '',          --(CS01)   
               @b_success         = 1,  
               @n_err             = 0,  
               @c_errmsg          = ''  
              
            EXECUTE dbo.ispLottableRule_Wrapper  
             @c_SPName           = @cJSPName,  
             @c_Listname         = @cJListName,  
             @c_Storerkey        = @cJStorerkey,  
             @c_Sku              = @cJSku,  
             @c_LottableLabel    = @cJLottableLabel,  
             @c_Lottable01Value  = @cJLottable01Value,  
             @c_Lottable02Value  = @cJLottable02Value,  
             @c_Lottable03Value  = @cJLottable03Value,  
             @dt_Lottable04Value = @dtJLottable04Value,  
             @dt_Lottable05Value = @dtJLottable05Value,  
               @c_Lottable06Value  = @cJLottable06Value,          --(CS01)  
             @c_Lottable07Value  = @cJLottable07Value,          --(CS01)  
             @c_Lottable08Value  = @cJLottable08Value,           --(CS01)  
               @c_Lottable09Value  = @cJLottable09Value,          --(CS01)  
             @c_Lottable10Value  = @cJLottable10Value,          --(CS01)  
             @c_Lottable11Value  = @cJLottable11Value,           --(CS01)  
               @c_Lottable12Value  = @cJLottable12Value,           --(CS01)  
               @dt_Lottable13Value = @dtJLottable13Value,          --(CS01)    
             @dt_Lottable14Value = @dtJLottable14Value,          --(CS01)   
             @dt_Lottable15Value = @dtJLottable15Value,          --(CS01)  
             @c_Lottable01       = @cJLottable01  OUTPUT,  
             @c_Lottable02       = @cJLottable02  OUTPUT,  
             @c_Lottable03       = @cJLottable03  OUTPUT,  
             @dt_Lottable04      = @dtJLottable04 OUTPUT,  
             @dt_Lottable05      = @dtJLottable05 OUTPUT,  
               @c_Lottable06       = @cJLottable06  OUTPUT,        --(CS01)  
             @c_Lottable07       = @cJLottable07  OUTPUT,        --(CS01)  
             @c_Lottable08       = @cJLottable08  OUTPUT,        --(CS01)  
               @c_Lottable09       = @cJLottable09  OUTPUT,        --(CS01)  
             @c_Lottable10       = @cJLottable10  OUTPUT,        --(CS01)  
             @c_Lottable11       = @cJLottable11  OUTPUT,        --(CS01)  
               @c_Lottable12       = @cJLottable12  OUTPUT,        --(CS01)  
               @dt_Lottable13      = @dtJLottable13 OUTPUT,        --(CS01)  
             @dt_Lottable14      = @dtJLottable14 OUTPUT,        --(CS01)  
             @dt_Lottable15      = @dtJLottable15 OUTPUT,        --(CS01)    
             @b_Success          = @b_Success     OUTPUT,  
             @n_Err              = @n_Err         OUTPUT,  
             @c_Errmsg           = @cErrmsg       OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN     
               EXEC rdt.rdtSetFocusField @nMobile, 2  
               GOTO Step_11_Fail  
            END  
            ELSE  
            BEGIN  
               -- Set Lottable04  
               IF @dtJLottable04 <> '' AND @dtJLottable04 IS NOT NULL  
               BEGIN  
                  SET @cJLottable04   = rdt.rdtFormatDate(@dtJLottable04)  
                  SET @cLottable04    = @cJLottable04  
                  SET @cInField08     = @cJLottable04  
                  SET @cOutField08    = @cJLottable04     
               END  
            END     
            -- Set focus to Lottable05  
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            END  
         /***************************************/   
         /*customization for lottable01 - end   */     
         /****************************************/  
      END  
      END  
  
      -- Validate lottable02  
      IF ISNULL(LTRIM(RTRIM(@cLotLabel02)), '') <> ''  
      BEGIN  
         -- Validate empty  
         IF ISNULL(LTRIM(RTRIM(@cLottable02)), '') = ''  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61127, @cLangCode, 'DSP') --Invalid Lot2   
            SET @cLottable02 = ''  
            SET @cOutField04 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 4  
            GOTO Step_11_Fail  
         END        
         ELSE  
         /************************************************************************************************/  
         /* UCC - Julian Date Lottables - Start                                                          */  
         /************************************************************************************************/  
         BEGIN  
            SELECT @cJListName = 'LOTTABLE02'  
  
            SET @cJSPName = ''  
            SET @cJLottableLabel = ''  
              
            SELECT @cJLottableLabel = LOTTABLE02LABEL  
            FROM  dbo.SKU (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SKU = @cSKU  
  
            SELECT @cJSPName = RTRIM(LONG)  
            FROM  dbo.CODELKUP (NOLOCK)  
            WHERE ListName = @cJListName  
            AND CODE = @cJLottableLabel  
  
            -- CodeLlup.Long = spname  
            IF @cJSPName <> '' AND @cJSPName IS NOT NULL  
            BEGIN  
               SELECT  
                  @cJStorerkey        = @cStorerKey,  
                  @cJSku              = @cSKU,  
                  @cJLottableLabel    = @cJLottableLabel,  
                @cJLottable01Value  = '',    
                @cJLottable02Value  = @cLottable02,    
                @cJLottable03Value  = '',  
                @dtJLottable04Value = NULL,  
                @dtJLottable05Value = NULL,  
                  @cJLottable06Value  = '',         --(CS01)   
                @cJLottable07Value  = '',         --(CS01)   
                @cJLottable08Value  = '',         --(CS01)  
                  @cJLottable09Value  = '',         --(CS01)   
                @cJLottable10Value  = '',         --(CS01)   
                @cJLottable11Value  = '',         --(CS01)  
                  @cJLottable12Value  = '',         --(CS01)  
                  @dtJLottable13Value = NULL,        --(CS01)    
                @dtJLottable14Value = NULL,        --(CS01)   
                @dtJLottable15Value = NULL,        --(CS01)   
                @cJLottable01      = '',  
                @cJLottable02      = '',  
                @cJLottable03      = '',  
                @dtJLottable04     = NULL,  
                 @dtJLottable05     = NULL,  
                  @cJLottable04      = '',  
                  @cJLottable05      = '',  
                  @cJLottable06      = '',          --(CS01)  
                @cJLottable07      = '',          --(CS01)  
                @cJLottable08      = '',          --(CS01)  
                  @cJLottable09      = '',          --(CS01)  
                @cJLottable10      = '',          --(CS01)  
                @cJLottable11      = '',          --(CS01)  
                  @cJLottable12      = '',          --(CS01)  
                  @dtJLottable13     = NULL,        --(CS01)   
                @dtJLottable14     = NULL,        --(CS01)  
                 @dtJLottable15     = NULL,        --(CS01)  
                  @cJLottable13      = '',          --(CS01)  
                  @cJLottable14      = '',          --(CS01)  
                  @cJLottable15      = '',          --(CS01)   
                  @b_success         = 1,  
                  @n_err             = 0,  
                  @c_errmsg          = ''  
              
               EXECUTE dbo.ispLottableRule_Wrapper  
                 @c_SPName           = @cJSPName,  
                 @c_Listname         = @cJListName,  
                 @c_Storerkey        = @cJStorerkey,  
                 @c_Sku              = @cJSku,  
                 @c_LottableLabel    = @cJLottableLabel,  
                 @c_Lottable01Value  = @cJLottable01Value,  
                 @c_Lottable02Value  = @cJLottable02Value,  
                 @c_Lottable03Value  = @cJLottable03Value,  
                 @dt_Lottable04Value = @dtJLottable04Value,  
                 @dt_Lottable05Value = @dtJLottable05Value,  
                     @c_Lottable06Value  = @cJLottable06Value,          --(CS01)  
                   @c_Lottable07Value  = @cJLottable07Value,          --(CS01)  
                   @c_Lottable08Value  = @cJLottable08Value,           --(CS01)  
                     @c_Lottable09Value  = @cJLottable09Value,          --(CS01)  
                   @c_Lottable10Value  = @cJLottable10Value,          --(CS01)  
                   @c_Lottable11Value  = @cJLottable11Value,           --(CS01)  
                     @c_Lottable12Value  = @cJLottable12Value,           --(CS01)  
                     @dt_Lottable13Value = @dtJLottable13Value,          --(CS01)    
                   @dt_Lottable14Value = @dtJLottable14Value,          --(CS01)   
                   @dt_Lottable15Value = @dtJLottable15Value,          --(CS01)  
                 @c_Lottable01       = @cJLottable01  OUTPUT,  
                 @c_Lottable02       = @cJLottable02  OUTPUT,  
                 @c_Lottable03       = @cJLottable03  OUTPUT,  
                 @dt_Lottable04      = @dtJLottable04 OUTPUT,  
                 @dt_Lottable05      = @dtJLottable05 OUTPUT,  
                     @c_Lottable06       = @cJLottable06  OUTPUT,        --(CS01)  
                   @c_Lottable07       = @cJLottable07  OUTPUT,        --(CS01)  
                   @c_Lottable08       = @cJLottable08  OUTPUT,        --(CS01)  
                     @c_Lottable09       = @cJLottable09  OUTPUT,        --(CS01)  
                   @c_Lottable10       = @cJLottable10  OUTPUT,        --(CS01)  
                   @c_Lottable11       = @cJLottable11  OUTPUT,        --(CS01)  
                     @c_Lottable12       = @cJLottable12  OUTPUT,        --(CS01)  
                     @dt_Lottable13      = @dtJLottable13 OUTPUT,        --(CS01)  
                   @dt_Lottable14      = @dtJLottable14 OUTPUT,        --(CS01)  
                   @dt_Lottable15      = @dtJLottable15 OUTPUT,        --(CS01)     
                 @b_Success          = @b_Success     OUTPUT,  
                 @n_Err              = @n_Err         OUTPUT,  
                 @c_Errmsg           = @cErrmsg       OUTPUT  
  
               IF @b_Success <> 1  
               BEGIN     
                  EXEC rdt.rdtSetFocusField @nMobile, 4  
                  GOTO Step_11_Fail  
               END  
               ELSE  
               BEGIN  
                  -- Set Lottable04  
                  IF @dtJLottable04 <> '' AND @dtJLottable04 IS NOT NULL  
                  BEGIN  
                     SET @cJLottable04   = rdt.rdtFormatDate(@dtJLottable04)  
                     SET @cLottable04    = @cJLottable04  
                     SET @cInField08     = @cJLottable04  
                     SET @cOutField08    = @cJLottable04     
                  END  
               END  
--                ELSE              
                  -- Set focus to Lottable05  
                  EXEC rdt.rdtSetFocusField @nMobile, 10  
--                END  
            END  
            /************************************************************************************************/  
            /* UCC - Julian Date Lottables - END                                 */  
            /************************************************************************************************/  
         END  
      END  
  
      -- Validate lottable03  
      IF ISNULL(LTRIM(RTRIM(@cLotLabel03)), '') <> ''   
      BEGIN  
         IF ISNULL(LTRIM(RTRIM(@cLottable03)), '') = ''   
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61128, @cLangCode, 'DSP') --Invalid Lot3  
            SET @cLottable03 = ''  
            SET @cOutField06 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 6  
            GOTO Step_11_Fail  
         END    
         /************************************************************************************************/  
         /* UCC - Julian Date Lottables - Start                                                          */  
         /************************************************************************************************/  
         BEGIN  
            SELECT @cJListName = 'LOTTABLE03'  
  
            SET @cJSPName = ''  
            SET @cJLottableLabel = ''  
              
            SELECT @cJLottableLabel = LOTTABLE03LABEL  
            FROM  dbo.SKU (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SKU = @cSKU  
  
            SELECT @cJSPName = RTRIM(LONG)  
            FROM  dbo.CODELKUP (NOLOCK)  
            WHERE ListName = @cJListName  
            AND CODE = @cJLottableLabel  
  
            -- CodeLlup.Long = spname  
            IF @cJSPName <> '' AND @cJSPName IS NOT NULL  
            BEGIN  
               SELECT  
                  @cJStorerkey        = @cStorerKey,  
                  @cJSku              = @cSKU,  
                  @cJLottableLabel    = @cJLottableLabel,  
                @cJLottable01Value  = '',    
                @cJLottable02Value  = '',    
                @cJLottable03Value  = @cLottable03,  
                @dtJLottable04Value = NULL,  
                @dtJLottable05Value = NULL,  
                  @cJLottable06Value  = '',         --(CS01)   
                @cJLottable07Value  = '',         --(CS01)   
                @cJLottable08Value  = '',         --(CS01)  
                  @cJLottable09Value  = '',         --(CS01)   
                @cJLottable10Value  = '',         --(CS01)   
                @cJLottable11Value  = '',         --(CS01)  
                  @cJLottable12Value  = '',         --(CS01)  
                  @dtJLottable13Value = NULL,        --(CS01)    
                @dtJLottable14Value = NULL,        --(CS01)   
                @dtJLottable15Value = NULL,        --(CS01)   
                @cJLottable01      = '',  
                @cJLottable02      = '',  
                @cJLottable03      = '',  
                @dtJLottable04     = NULL,  
                 @dtJLottable05     = NULL,  
                  @cJLottable04      = '',  
                  @cJLottable05      = '',  
                  @cJLottable06      = '',          --(CS01)  
                @cJLottable07      = '',          --(CS01)  
                @cJLottable08      = '',          --(CS01)  
                  @cJLottable09      = '',          --(CS01)  
                @cJLottable10      = '',          --(CS01)  
                @cJLottable11      = '',          --(CS01)  
                  @cJLottable12      = '',          --(CS01)  
                  @dtJLottable13     = NULL,        --(CS01)   
                @dtJLottable14     = NULL,        --(CS01)  
                 @dtJLottable15     = NULL,        --(CS01)  
                  @cJLottable13      = '',          --(CS01)  
                  @cJLottable14      = '',          --(CS01)  
                  @cJLottable15      = '',          --(CS01)   
                  @b_success         = 1,  
                  @n_err             = 0,  
                  @c_errmsg          = ''  
              
               EXECUTE dbo.ispLottableRule_Wrapper  
                 @c_SPName           = @cJSPName,  
                 @c_Listname         = @cJListName,  
                 @c_Storerkey        = @cJStorerkey,  
                 @c_Sku              = @cJSku,  
                 @c_LottableLabel    = @cJLottableLabel,  
                 @c_Lottable01Value  = @cJLottable01Value,  
                 @c_Lottable02Value  = @cJLottable02Value,  
                 @c_Lottable03Value  = @cJLottable03Value,  
                 @dt_Lottable04Value = @dtJLottable04Value,  
                 @dt_Lottable05Value = @dtJLottable05Value,  
                     @c_Lottable06Value  = @cJLottable06Value,          --(CS01)  
                   @c_Lottable07Value  = @cJLottable07Value,          --(CS01)  
                   @c_Lottable08Value  = @cJLottable08Value,           --(CS01)  
                     @c_Lottable09Value  = @cJLottable09Value,          --(CS01)  
                   @c_Lottable10Value  = @cJLottable10Value,          --(CS01)  
                   @c_Lottable11Value  = @cJLottable11Value,           --(CS01)  
                     @c_Lottable12Value  = @cJLottable12Value,           --(CS01)  
                     @dt_Lottable13Value = @dtJLottable13Value,          --(CS01)    
                   @dt_Lottable14Value = @dtJLottable14Value,          --(CS01)   
                   @dt_Lottable15Value = @dtJLottable15Value,          --(CS01)   
                 @c_Lottable01       = @cJLottable01  OUTPUT,  
                 @c_Lottable02       = @cJLottable02  OUTPUT,  
                 @c_Lottable03       = @cJLottable03  OUTPUT,  
                 @dt_Lottable04      = @dtJLottable04 OUTPUT,  
                 @dt_Lottable05      = @dtJLottable05 OUTPUT,  
                     @c_Lottable06       = @cJLottable06  OUTPUT,        --(CS01)  
                   @c_Lottable07       = @cJLottable07  OUTPUT,        --(CS01)  
                   @c_Lottable08       = @cJLottable08  OUTPUT,        --(CS01)  
                     @c_Lottable09       = @cJLottable09  OUTPUT,        --(CS01)  
                   @c_Lottable10       = @cJLottable10  OUTPUT,        --(CS01)  
                   @c_Lottable11       = @cJLottable11  OUTPUT,        --(CS01)  
                     @c_Lottable12       = @cJLottable12  OUTPUT,        --(CS01)  
                     @dt_Lottable13      = @dtJLottable13 OUTPUT,        --(CS01)  
                   @dt_Lottable14      = @dtJLottable14 OUTPUT,        --(CS01)  
                   @dt_Lottable15      = @dtJLottable15 OUTPUT,        --(CS01)    
                 @b_Success          = @b_Success     OUTPUT,  
                 @n_Err              = @n_Err         OUTPUT,  
                 @c_Errmsg           = @cErrmsg       OUTPUT  
  
               IF @b_Success <> 1  
               BEGIN     
                  EXEC rdt.rdtSetFocusField @nMobile, 6  
                  GOTO Step_11_Fail  
               END  
               ELSE  
               BEGIN  
                  -- Set Lottable04  
                  IF @dtJLottable04 <> '' AND @dtJLottable04 IS NOT NULL  
                  BEGIN  
                     SET @cJLottable04   = rdt.rdtFormatDate(@dtJLottable04)  
                     SET @cLottable04    = @cJLottable04  
                     SET @cInField08     = @cJLottable04  
                     SET @cOutField08    = @cJLottable04     
                  END  
--           ELSE  
                
                  -- Set focus to Lottable05  
                  EXEC rdt.rdtSetFocusField @nMobile, 10  
               END  
            END  
            /************************************************************************************************/  
            /* UCC - Julian Date Lottables - END                                 */  
            /************************************************************************************************/  
         END  
  
      END  
  
      -- Validate lottable04  
      IF ISNULL(LTRIM(RTRIM(@cLotLabel04)), '') <> ''   
      BEGIN  
         -- Validate empty  
         IF ISNULL(LTRIM(RTRIM(@cLottable04)), '') = ''   
         BEGIN  
      SET @cErrMsg = rdt.rdtgetmessage( 61129, @cLangCode, 'DSP') --Invalid Lot4  
            SET @cLottable04 = ''              
            SET @cOutField08 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 8  
            GOTO Step_11_Fail  
         END  
  
         -- Validate date  
         IF IsDate( @cLottable04) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61129, @cLangCode, 'DSP') --Invalid Lot4  
            SET @cLottable04 = ''              
            SET @cOutField08 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 8  
            GOTO Step_11_Fail  
         END  
         /************************************************************************************************/  
       /* UCC - Julian Date Lottables - Start                                                          */  
         /************************************************************************************************/  
         BEGIN  
            SELECT @cJListName = 'LOTTABLE04'  
  
            SET @cJSPName = ''  
            SET @cJLottableLabel = ''  
              
            SELECT @cJLottableLabel = LOTTABLE03LABEL  
            FROM  dbo.SKU (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SKU = @cSKU  
  
            SELECT @cJSPName = RTRIM(LONG)  
            FROM  dbo.CODELKUP (NOLOCK)  
            WHERE ListName = @cJListName  
            AND CODE = @cJLottableLabel  
  
            -- CodeLlup.Long = spname  
            IF @cJSPName <> '' AND @cJSPName IS NOT NULL  
            BEGIN  
               SELECT  
                  @cJStorerkey        = @cStorerKey,  
                  @cJSku              = @cSKU,  
                  @cJLottableLabel    = @cJLottableLabel,  
                @cJLottable01Value  = '',    
                @cJLottable02Value  = '',    
                @cJLottable03Value  = '',  
                @dtJLottable04Value = @cLottable04,  
                @dtJLottable05Value = NULL,  
                  @cJLottable06Value  = '',         --(CS01)   
                @cJLottable07Value  = '',         --(CS01)   
                @cJLottable08Value  = '',         --(CS01)  
                  @cJLottable09Value  = '',         --(CS01)   
                @cJLottable10Value  = '',         --(CS01)   
                @cJLottable11Value  = '',         --(CS01)  
                  @cJLottable12Value  = '',         --(CS01)  
                  @dtJLottable13Value = NULL,        --(CS01)    
                @dtJLottable14Value = NULL,        --(CS01)   
                @dtJLottable15Value = NULL,        --(CS01)   
                @cJLottable01      = '',  
                @cJLottable02      = '',  
                @cJLottable03      = '',  
                @dtJLottable04     = NULL,  
                 @dtJLottable05     = NULL,  
                  @cJLottable04      = '',  
                  @cJLottable05      = '',  
                  @cJLottable06      = '',          --(CS01)  
                @cJLottable07      = '',          --(CS01)  
                @cJLottable08      = '',          --(CS01)  
                  @cJLottable09      = '',          --(CS01)  
                @cJLottable10      = '',          --(CS01)  
                @cJLottable11      = '',          --(CS01)  
                  @cJLottable12      = '',          --(CS01)  
                  @dtJLottable13     = NULL,        --(CS01)   
                @dtJLottable14     = NULL,        --(CS01)  
                 @dtJLottable15     = NULL,        --(CS01)  
                  @cJLottable13      = '',          --(CS01)  
                  @cJLottable14      = '',          --(CS01)  
                  @cJLottable15      = '',          --(CS01)   
                  @b_success         = 1,  
                  @n_err             = 0,  
                  @c_errmsg          = ''  
              
               EXECUTE dbo.ispLottableRule_Wrapper  
                 @c_SPName           = @cJSPName,  
                 @c_Listname         = @cJListName,  
                 @c_Storerkey        = @cJStorerkey,  
                 @c_Sku              = @cJSku,  
                 @c_LottableLabel    = @cJLottableLabel,  
                 @c_Lottable01Value  = @cJLottable01Value,  
                 @c_Lottable02Value  = @cJLottable02Value,  
                 @c_Lottable03Value  = @cJLottable03Value,  
                 @dt_Lottable04Value = @dtJLottable04Value,  
                 @dt_Lottable05Value = @dtJLottable05Value,  
                     @c_Lottable06Value  = @cJLottable06Value,          --(CS01)  
                   @c_Lottable07Value  = @cJLottable07Value,          --(CS01)  
                   @c_Lottable08Value  = @cJLottable08Value,           --(CS01)  
                     @c_Lottable09Value  = @cJLottable09Value,          --(CS01)  
                   @c_Lottable10Value  = @cJLottable10Value,          --(CS01)  
                   @c_Lottable11Value  = @cJLottable11Value,           --(CS01)  
                     @c_Lottable12Value  = @cJLottable12Value,           --(CS01)  
                     @dt_Lottable13Value = @dtJLottable13Value,          --(CS01)    
                   @dt_Lottable14Value = @dtJLottable14Value,          --(CS01)   
                   @dt_Lottable15Value = @dtJLottable15Value,          --(CS01)   
                 @c_Lottable01       = @cJLottable01  OUTPUT,  
                 @c_Lottable02       = @cJLottable02  OUTPUT,  
                 @c_Lottable03       = @cJLottable03  OUTPUT,  
                 @dt_Lottable04      = @dtJLottable04 OUTPUT,  
                 @dt_Lottable05      = @dtJLottable05 OUTPUT,  
                     @c_Lottable06       = @cJLottable06  OUTPUT,        --(CS01)  
                   @c_Lottable07       = @cJLottable07  OUTPUT,        --(CS01)  
                   @c_Lottable08       = @cJLottable08  OUTPUT,        --(CS01)  
                     @c_Lottable09       = @cJLottable09  OUTPUT,        --(CS01)  
                   @c_Lottable10       = @cJLottable10  OUTPUT,        --(CS01)  
                   @c_Lottable11       = @cJLottable11  OUTPUT,        --(CS01)  
                     @c_Lottable12       = @cJLottable12  OUTPUT,        --(CS01)  
                     @dt_Lottable13      = @dtJLottable13 OUTPUT,        --(CS01)  
                   @dt_Lottable14      = @dtJLottable14 OUTPUT,        --(CS01)  
                   @dt_Lottable15      = @dtJLottable15 OUTPUT,        --(CS01)    
                 @b_Success          = @b_Success     OUTPUT,  
                 @n_Err              = @n_Err         OUTPUT,  
                 @c_Errmsg           = @cErrmsg       OUTPUT  
  
               IF @b_Success <> 1  
               BEGIN     
                  EXEC rdt.rdtSetFocusField @nMobile, 8  
                  GOTO Step_11_Fail  
               END  
               ELSE  
               BEGIN  
                  -- Set Lottable04  
                  IF @dtJLottable04 <> '' AND @dtJLottable04 IS NOT NULL  
                  BEGIN  
                     SET @cJLottable04   = rdt.rdtFormatDate(@dtJLottable04)  
                     SET @cLottable04    = @cJLottable04  
                     SET @cInField08     = @cJLottable04  
                     SET @cOutField08    = @cJLottable04     
                  END  
--           ELSE  
                
                  -- Set focus to Lottable05  
                  EXEC rdt.rdtSetFocusField @nMobile, 10  
               END  
            END  
            /************************************************************************************************/  
            /* UCC - Julian Date Lottables - END                                 */  
            /************************************************************************************************/  
      END  
      END  
  
      -- Validate lottable05  
      IF ISNULL(LTRIM(RTRIM(@cLotLabel05)), '') <> ''   
      BEGIN  
         -- Validate empty  
         IF ISNULL(LTRIM(RTRIM(@cLottable05)), '') = ''   
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61130, @cLangCode, 'DSP') --Invalid Lot5  
            SET @cLottable05 = ''              
            SET @cOutField10 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            GOTO Step_11_Fail  
         END    
         -- Validate date  
         IF IsDate( @cLottable05) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61130, @cLangCode, 'DSP') --Invalid Lot5  
            SET @cLottable05 = ''              
            SET @cOutField10 = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 10  
            GOTO Step_11_Fail  
         END  
      END  
  
      IF ISNULL(LTRIM(RTRIM(@cLottable04)), '') <> ''   
         SET @dLottable04 = CAST( @cLottable04 AS DATETIME)  
      ELSE  
         SET @dLottable04 = NULL  
  
IF ISNULL(LTRIM(RTRIM(@cLottable05)), '') <> ''   
         SET @dLottable05 = CAST( @cLottable05 AS DATETIME)  
      ELSE  
         SET @dLottable05 = NULL  
  
         GOTO Step_11_Next                       
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      IF @nFromScn = 986 AND @nFromStep = 3  
      BEGIN  
         SET @nScn  = 986  
         SET @nStep = 3  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = ''  
         SET @cOutField10 = ''  
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)   
         SET @cReceiptLineNumber = ''  
         SET @cTempToID = ''  
         SET @cTempToLoc = ''  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         GOTO QUIT  
      END  
      ELSE  
      BEGIN  
         SET @nScn  = 992  
         SET @nStep = 9  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = ''  
         SET @cOutField10 = ''  
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO QUIT  
      END  
   END  
  
   Step_11_Next:  
   BEGIN  
    IF @nFromScn = 986 AND @nFromStep = 3  
      BEGIN  
         SET @nScn  = 988  
         SET @nStep = 5  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
         SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
         SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cPPK)), '') + '/' + ISNULL(LTRIM(RTRIM(@cPQIndicator)), '') -- (Vicky01)  
         SET @cOutField07 = @cLottable02  
         SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)  
         SET @cOutField09 = @cUOM   
         SET @cOutField10 = @nQTY   
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         SET @cReceiptLineNumber = ''  
         SET @cTempToID = ''  
         SET @cTempToLoc = ''  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         GOTO QUIT  
      END  
      ELSE  
      BEGIN  
         SET @nScn  = 987  
         SET @nStep = 4  
         SET @cOutField01 = @cUCCNo  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
         SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
         SET @cOutField06 = ISNULL(LTRIM(RTRIM(@cPPK)), '') + '/' + ISNULL(LTRIM(RTRIM(@cPQIndicator)), '') -- (Vicky01)  
         SET @cOutField07 = @cLottable02  
         SET @cOutField08 = RDT.RDTFormatDate(@dLottable04)  
         SET @cOutField09 = @cUOM  
         SET @cOutField10 = @nCaseCntQty   --default populate case qty from pack  
         SET @cOutField11 = ISNULL(LTRIM(RTRIM(@cCartonCnt)), '0') + '/' + ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)), '0') -- (Vicky01)  
         SET @cReceiptLineNumber = ''  
         SET @cTempToID = ''  
         SET @cTempToLoc = ''  
         -- (Vicky02) - Start  
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
         -- (Vicky02) - End  
         GOTO Quit  
      END  
   END  
  
   Step_11_Fail:  
      BEGIN  
      -- (Vicky02) - Start  
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
      -- (Vicky02) - End  
  
      SELECT           
         @cLotLabel01 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable01Label AND C.ListName = 'LOTTABLE01' AND C.Code <> ''), ''),   
         @cLotLabel02 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable02Label AND C.ListName = 'LOTTABLE02' AND C.Code <> ''), ''),   
         @cLotLabel03 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable03Label AND C.ListName = 'LOTTABLE03' AND C.Code <> ''), ''),   
         @cLotLabel04 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable04Label AND C.ListName = 'LOTTABLE04' AND C.Code <> ''), ''),  
         @cLotLabel05 = IsNULL(( SELECT C.[Description] FROM dbo.CodeLKUP C (NOLOCK) WHERE C.Code = S.Lottable05Label AND C.ListName = 'LOTTABLE05' AND C.Code <> ''), ''),  
         @cLottable05_Code = IsNULL( S.Lottable05Label, '')  
      FROM dbo.SKU S (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   SKU = @cSKU  
  
      -- Turn on lottable flag (use later)  
      SET @cHasLottable = '0'  
      IF (@cLotLabel01 <> '' AND @cLotLabel01 IS NOT NULL) OR  
         (@cLotLabel02 <> '' AND @cLotLabel02 IS NOT NULL) OR  
         (@cLotLabel03 <> '' AND @cLotLabel03 IS NOT NULL) OR  
         (@cLotLabel04 <> '' AND @cLotLabel04 IS NOT NULL) OR  
         (@cLotLabel05 <> '' AND @cLotLabel05 IS NOT NULL)  
      SET @cHasLottable = '1'  
  
      -- Initiate next screen var  
      IF @cHasLottable = '1'  
      BEGIN  
         -- Initiate labels  
         SELECT   
            @cOutField01 = 'Lottable01:',   
            @cOutField03 = 'Lottable02:',  
            @cOutField05 = 'Lottable03:',   
            @cOutField07 = 'Lottable04:',   
            @cOutField09 = 'Lottable05:'  
  
         -- Populate labels and lottables  
         IF @cLotLabel01 = '' OR @cLotLabel01 IS NULL  
         BEGIN  
            SET @cFieldAttr02 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field02', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            SELECT @cOutField01 = @cLotLabel01  
            SELECT @cOutField02 = @cLottable01  
         END  
  
         IF @cLotLabel02 = '' OR @cLotLabel02 IS NULL  
         BEGIN  
            SET @cFieldAttr04 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field04', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            SELECT @cOutField03 = @cLotLabel02  
            SELECT @cOutField04 = @cLottable02  
         END  
  
         IF @cLotLabel03 = '' OR @cLotLabel03 IS NULL  
         BEGIN  
            SET @cFieldAttr06 = 'O' -- (Vicky02)  
             --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field06', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
           SELECT @cOutField05 = @cLotLabel03  
           SELECT @cOutField06 = @cLottable03  
         END  
  
         IF @cLotLabel04 = '' OR @cLotLabel04 IS NULL  
         BEGIN  
            SET @cFieldAttr08 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field08', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            SELECT  @cOutField07 = @cLotLabel04  
            SELECT  @cOutField08 = RDT.RDTFormatDate( @cLottable04 )             
         END  
  
         IF @cLotLabel05 = '' OR @cLotLabel05 IS NULL  
         BEGIN  
            SET @cFieldAttr10 = 'O' -- (Vicky02)  
            --INSERT INTO @tSessionScrn ([ID], [NewID], Typ, Length, [Default], Value) VALUES ('Field10', 'NULL', 'output', 'NULL', 'NULL', '')  
         END  
         ELSE  
         BEGIN  
            -- Lottable05 is usually RCP_DATE  
            IF @cLottable05_Code = 'RCP_DATE'  
            BEGIN  
               SET @dLottable05 = GETDATE()  
            END  
  
            SELECT  
               @cOutField09 = @cLotLabel05,   
               @cOutField10 = RDT.RDTFormatDate( @dLottable05)  
          END  
         END  
  
         GOTO QUIT  
      END  
END  
  
GOTO Quit  
  
Quit:  
BEGIN  
  
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK)  
   SET ErrMsg = @cErrMsg   , Func = @nFunc,  
   Step = @nStep,            Scn = @nScn,  
   O_Field01 = @cOutField01, O_Field02 =  @cOutField02,  
   O_Field03 = @cOutField03, O_Field04 =  @cOutField04,  
   O_Field05 = @cOutField05, O_Field06 =  @cOutField06,  
   O_Field07 = @cOutField07, O_Field08 =  @cOutField08,  
   O_Field09 = @cOutField09, O_Field10 =  @cOutField10,  
   O_Field11 = @cOutField11, O_Field12 =  @cOutField12,  
   O_Field13 = @cOutField13, O_Field14 =  @cOutField14,  
   O_Field15 = @cOutField15,   
   I_Field01 = '',   I_field02 = '',  
   I_Field03 = '',   I_field04 = '',  
   I_Field05 = '',   I_field06 = '',  
   I_Field07 = '',   I_field08 = '',  
   I_Field09 = '',   I_field10 = '',  
   I_Field11 = '',   I_field12 = '',  
   I_Field13 = '',   I_field14 = '',  
   I_Field15 = '',  
   V_SKU        = @cSKU,           
   V_SKUDescr   = @cDescr,   
   V_UOM        = @cUOM,            
   V_QTY        = @nQTY,  
   V_Lottable01 = @cLottable01,   
   V_Lottable02 = @cLottable02,   
   V_Lottable03 = @cLottable03,   
   V_Lottable04 = @dLottable04,   
   V_Lottable05 = @dLottable05,   
   V_ID         = @cTOID,   
   V_UCC        = @cUCCNo,          
   V_Loc        = @cToLoc,   
   V_ReceiptKey = @cReceiptKey,     
   V_String1    = @cPPK,            
   V_String2    = @cPQIndicator,  
   V_String3    = @cReceiptLineNumber,   
   V_String4    = @cCartonCnt,       
   V_String5    = @cTotalCartonCnt,  
   V_String6    = @nMaxCnt,          
   V_String7    = @cTotalPalletCnt,   
   V_String8    = @cExternPOKey,     
   V_String9    = @cPackKey,      
   V_String10   = @cExternKey,       
   V_String11   = @cTariffkey,   
   V_String12   = @nAddNewUCCReturn,  
   V_String13   = @cAllow_OverReceipt,   
   V_String14   = @cPOKey,   
   V_String15   = @cPOLineNumber,   
   V_String16   = @nFromScn,         
   V_String17   = @nFromStep,   
   V_String18   = @cCreateUCC,   
   V_String19   = @cReceivedByUPC,  
   -- (Vicky02) - Start  
   V_String20   = @cLotLabel01,  
   V_String21   = @cLotLabel02,  
   V_String22   = @cLotLabel03,  
   V_String23   = @cLotLabel04,  
   V_String24   = @cLotLabel05,  
  
   FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,  
   FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,  
   FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,  
   FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,  
   FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,  
   FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,  
   FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,  
   FieldAttr15  = @cFieldAttr15   
   -- (Vicky02) - End  
   WHERE Mobile = @nMobile  
  
END  

GO