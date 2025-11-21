SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/   
/* Copyright: IDS                                                             */   
/* Purpose: ZARA Carton ID Receiving SOS#243508                               */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2012-05-09 1.0  ChewKP     Created                                         */  
/* 2012-10-15 1.1  ChewKP     SOS#258706 Change Screen design on Screen 5,    */
/*                            New StorerConfig, Label Validation (ChewKP01)   */ 
/* 2012-12-27 1.2  James      SOS265346 - Add new To Loc screen (james01)     */
/* 2013-07-22 1.3  James      SOS283528 - (james02)                           */
/*                            1. Default receipt # in To ID scn               */
/*                            2. Change the "CtnRcvAllowNewLoc" logic         */
/* 2013-08-26 1.4  James      SOS287456 - Check label length (james03)        */
/* 2016-10-05 1.5  James      Perf tuning                                     */
/* 2018-10-30 1.6  Gan        Performance tuning                              */
/* 2023-02-10 1.7  James      WMS-21643 Enhance label length check (james04)  */
/******************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_CartonIDReceiving] (  
   @nMobile    int,  
   @nErrNo     int  OUTPUT,  
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max  
)  
AS  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE   
   @cOption     NVARCHAR( 1),  
   @nCount      INT,  
   @nRowCount   INT  
  
-- RDT.RDTMobRec variable  
DECLARE   
   @nFunc      INT,  
   @nScn       INT,  
   @nStep      INT,  
   @cLangCode  NVARCHAR( 3),  
   @nInputKey  INT,  
   @nMenu      INT,  
  
   @cStorerKey NVARCHAR( 15),  
   @cFacility  NVARCHAR( 5),   
   @cPrinter   NVARCHAR( 20),   
   @cUserName  NVARCHAR( 18),  
     
   @b_success     INT,  
   @cToLoc                 NVARCHAR(10),
   @cChkFacility           NVARCHAR( 5),   
   @cID                    NVARCHAR(18),
   @cReceiptKey            NVARCHAR(10),
   @cAutoGenID             NVARCHAR(20),
   @cCartonID              NVARCHAR(20),
   @cExternPOKey           NVARCHAR(30),
   @cExternPOKey1          NVARCHAR(20),
   @cExternPOKey2          NVARCHAR(20),
   @cToID                  NVARCHAR(18),
   @cAutoID                NVARCHAR(18),
   @cDefaultPieceRecvQTY   NVARCHAR(10),
   @cInSKU                 NVARCHAR(20),
   @cConditionCode         NVARCHAR(1),
   @cQtyReceived           NVARCHAR(10),
   @cSKUDesc               NVARCHAR(60),
   @nQtyExpected           NVARCHAR(10),
   @nTotalQtyReceived      NVARCHAR(10),
   @cDefaultCondition      NVARCHAR(1),
   @cSKU                   NVARCHAR(20),
   @nQtyReceived           INT,
   @cDefaultToLoc          NVARCHAR(10),
   @cDisAllowRDTOverReceipt NVARCHAR(1), -- (ChewKP01)
   @nTotalCartonQty        NVARCHAR(10), -- (ChewKP01)
   @nTotalQtyExpected      INT,          -- (james02)

   @cPrevSKU                  NVARCHAR( 20),  -- (james01)
   @cSLoc1                    NVARCHAR( 10),  -- (james01)
   @cSLoc2                    NVARCHAR( 10),  -- (james01)
   @cSLoc3                    NVARCHAR( 10),  -- (james01)
   @cSLoc4                    NVARCHAR( 10),  -- (james01)
   @cSLoc5                    NVARCHAR( 10),  -- (james01)
   @cCtnRcvWithSuggestedLoc   NVARCHAR( 1),   -- (james01)
   @cCtnRcvGetSuggestedLoc_SP NVARCHAR( 20),  -- (james01)
   @cToLocFacility            NVARCHAR( 5),   -- (james01)
   @nPrevScn                  INT,           -- (james01)
   @nPrevStp                  INT,           -- (james01)
   @nQtyScanned               INT,           -- (james01)
   @nTotalASNQty              INT,           -- (james01)
   @nTotalExpectedQty         INT,           -- (james01)
   @cPOKeyDefaultValue        NVARCHAR( 10),  -- (james01)
   @cPoKeyValue               NVARCHAR( 10),  -- (james01)
   @cUOM                      NVARCHAR( 10),  -- (james01)
   @cPackKey                  NVARCHAR( 10),  -- (james01)
   @cReceiptLineNumber        NVARCHAR( 5),   -- (james01)
   @cFacPrefix                NVARCHAR( 5),   -- (james01)

   @cLottable01               NVARCHAR( 10),  -- (james01)
   @cLottable02               NVARCHAR( 10),  -- (james01)
   @cLottable03               NVARCHAR( 10),  -- (james01)
   @dLottable04               DATETIME,  
   @dLottable05               DATETIME,  

   @cErrMsg1                  NVARCHAR( 20),  -- (james01)
   @cErrMsg2                  NVARCHAR( 20),  -- (james01)
   @cErrMsg3                  NVARCHAR( 20),  -- (james01)
   @cErrMsg4                  NVARCHAR( 20),  -- (james01)
   @cErrMsg5                  NVARCHAR( 20),  -- (james01)
   @cOutstring                NVARCHAR( 255), -- (james01)
   @nCartonIDChecked          INT,
   
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),

   @c_ExecStatements          NVARCHAR(4000),
   @c_ExecArguments           NVARCHAR(4000),
   
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
   @cLangCode  = Lang_code,  
  
   @cStorerKey = StorerKey,  
   @cFacility  = Facility,  
   @cPrinter   = Printer,   
   @cUserName  = UserName,  
   
   @cToLoc        = V_Loc,
   @cToID         = V_ID,
   @cReceiptKey   = V_ReceiptKey,
   @cSKU          = V_SKU,
   @cSKUDesc      = V_SKUDescr,
   @cUOM          = V_UOM,  
   
   @nPrevScn      = V_FromScn,
   @nPrevStp      = V_FromStep,
   
   @nTotalQtyReceived   = V_Integer1,
   @nTotalCartonQty     = V_Integer2,
   @nQtyExpected        = V_Integer3,
   @nQtyScanned         = V_Integer4,
   
   @cExternPOKey1       = V_String1,
   @cCartonID           = V_String2,
   @cConditionCode      = V_String3,
   @cQtyReceived        = V_String4,
  -- @nTotalQtyReceived   = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String5,  5), 0) = 1 THEN LEFT( V_String5,  5) ELSE 0 END,
  -- @nTotalCartonQty     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String6,  5), 0) = 1 THEN LEFT( V_String6,  5) ELSE 0 END,
   @cExternPOKey2       = V_String7,
   @cDefaultPieceRecvQTY = V_String8,
  -- @nQtyExpected        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String9,  5), 0) = 1 THEN LEFT( V_String9,  5) ELSE 0 END,
  -- @nPrevScn            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10,  5), 0) = 1 THEN LEFT( V_String10,  5) ELSE 0 END,
  -- @nPrevStp            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11,  5), 0) = 1 THEN LEFT( V_String11,  5) ELSE 0 END,
  -- @nQtyScanned         = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String12,  5), 0) = 1 THEN LEFT( V_String12,  5) ELSE 0 END,
   @cPrevSKU            = V_String13,
   
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,  
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,  
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,  
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,  
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,  
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,  
   @cFieldAttr15 =  FieldAttr15  
  
FROM RDTMOBREC (NOLOCK)  
WHERE Mobile = @nMobile  
  
Declare @n_debug INT  
  
SET @n_debug = 0  
  
IF @nFunc = 597  -- Tote Receiving  
BEGIN  
   -- Redirect to respective screen  
 IF @nStep = 0 GOTO Step_0   -- CartonID Receiving
 IF @nStep = 1 GOTO Step_1   -- Scn = 3100. ASN
 IF @nStep = 2 GOTO Step_2   -- Scn = 3101. Pallet ID  
 IF @nStep = 3 GOTO Step_3   -- Scn = 3102. To Loc
 IF @nStep = 4 GOTO Step_4   -- Scn = 3103. Carton ID
 IF @nStep = 5 GOTO Step_5   -- Scn = 3104. SKU
 IF @nStep = 6 GOTO Step_6   -- Scn = 3105. Suggested LOC
 IF @nStep = 7 GOTO Step_7   -- Scn = 3106. LOC not match
     
END  
  
/********************************************************************************  
Step 0. func = 597. Menu  
********************************************************************************/  
Step_0:  
BEGIN  
   
   -- Initiate var  
    -- EventLog - Sign In Function  
    EXEC RDT.rdt_STD_EventLog  
     @cActionType = '1', -- Sign in function  
     @cUserID     = @cUserName,  
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerKey,
     @nStep       = @nStep

   -- Init screen  
   SET @cOutField01 = ''   
           
   -- Set the entry point  
   SET @nScn = 3100  
   SET @nStep = 1  
   
END  
GOTO Quit  

/********************************************************************************  
Step 1. Scn = 3100.   
   ASN (Input , Field01)  
     
********************************************************************************/  
Step_1:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      SET @cReceiptKey = ISNULL(RTRIM(@cInField01),'')  
      
       -- When both ASN is blank
      IF @cReceiptKey = ''
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76251, @cLangCode, 'DSP') --'ASN Req'
         GOTO Step_1_Fail
      END
      
      -- Check if receiptkey exists
      IF NOT EXISTS (SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76252, @cLangCode, 'DSP') --'ASN not exists'
         GOTO Step_1_Fail
      END
      
      -- Check diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Facility = @cFacility)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76253, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_1_Fail
      END

      -- Check diff storer
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorerKey)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76254, @cLangCode, 'DSP') --'Diff storer'
         GOTO Step_1_Fail
      END
      
      -- Validate ASN status
      IF EXISTS ( SELECT 1 FROM dbo.Receipt WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND StorerKey = @cStorerKey
                  AND Facility = @cFacility
                  AND Status = '9')
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76255, @cLangCode, 'DSP') --'ASN is closed'
         GOTO Step_1_Fail
      END
      
      SET @cExternPOKey = ''
      SELECT @cExternPOKey = UserDefine02
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey  = @cReceiptKey
      AND   StorerKey   = @cStorerKey
      
      SET @cExternPOKey1 = SUBSTRING( RTRIM(@cExternPOKey), 1, 6)  -- ExternPOKey1
      SET @cExternPOKey2 = SUBSTRING( RTRIM(@cExternPOKey), 7, 24)  -- ExternPOKey1

      -- If carton receiving with suggested loc then no need goto to loc screen (james01)
      IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1'
      BEGIN
         SET @cOutField01 = @cReceiptKey  
         SET @cOutField02 = @cExternPOKey1
         SET @cOutField03 = @cExternPOKey2
         SET @cOutField04 = ''  

         -- If config turned on, default to id as receiptkey (james02)
         IF rdt.RDTGetConfig( @nFunc, 'ToIDDefaul2tReceiptKey', @cStorerKey) = '1'
            SET @cOutField05 = @cReceiptKey
         ELSE
            SET @cOutField05 = ''
         
         -- GOTO Next Screen  
         SET @nScn = @nScn + 2  
         SET @nStep = @nStep + 2  
      END
      ELSE
      BEGIN
         SET @cDefaultToLoc = ''
         SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey) -- Parse in Function
         
         -- Prepare Next Screen Variable  
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cExternPOKey1
         SET @cOutField03 = @cExternPOKey2
         
         IF @cDefaultToLoc = ''
         BEGIN
            SET @cOutField04 = ''  
         END
         ELSE
         BEGIN
            SET @cOutField04 = @cDefaultToLoc
         END
           
         -- GOTO Next Screen  
         SET @nScn = @nScn + 1  
         SET @nStep = @nStep + 1  
      END
   END  -- Inputkey = 1  
  
   IF @nInputKey = 0   
   BEGIN  
      -- EventLog - Sign In Function  
       EXEC RDT.rdt_STD_EventLog  
        @cActionType = '9', -- Sign in function  
        @cUserID     = @cUserName,  
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerKey,
        @nStep       = @nStep
          
      --go to main menu  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
   END  
   GOTO Quit  
  
   STEP_1_FAIL:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
END   
GOTO QUIT  

/********************************************************************************  
Step 2. Scn = 3101.   
   ASN         (field01)  
   ExternPOKey (field02)  
   ExternPOKey (field03)  
   ToLoc       (field04, input)  
********************************************************************************/  
Step_2:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      SET @cToLoc = ISNULL(RTRIM(@cInField04),'')  
      
      -- Check blank LOC
      IF @cToLOC = '' 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76256, @cLangCode, 'DSP') --'LOC required'
         GOTO Step_2_Fail
      END

      -- Check invalid LOC
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76257, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END
      
       -- Check different facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC
            AND FACILITY = @cFacility)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76258, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_2_Fail
      END  

      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternPOKey1
      SET @cOutField03 = @cExternPOKey2
      SET @cOutField04 = @cToLoc  
      
      -- If config turned on, default to id as receiptkey (james02)
      IF rdt.RDTGetConfig( @nFunc, 'ToIDDefaul2tReceiptKey', @cStorerKey) = '1'
         SET @cOutField05 = @cReceiptKey
      ELSE
         SET @cOutField05 = ''
        
      -- GOTO Next Screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  -- Inputkey = 1  
  
   IF @nInputKey = 0   
   BEGIN  
      -- Prepare Next Screen Variable  
      SET @cOutField01 = '' 
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
        
      -- GOTO Previous Screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   STEP_2_FAIL:  
   BEGIN  
      SET @cOutField04 = ''  
   END  

END   
GOTO QUIT    
  
/********************************************************************************  
Step 3. Scn = 3102.   
   ASN         (Field01)
   ExternPOkey1 (Field02)
   ExternPOkey2 (Field03)
   ToLoc       (Field04)
   To ID       (Input , Field05)  
********************************************************************************/  
Step_3:  
BEGIN  
   IF @nInputKey = 1 --ENTER  
   BEGIN  
      SET @cToID = ISNULL(RTRIM(@cInField05),'')  
        
      SET @cAutoID = ''
      SET @cAutoGenID = ''
      
      SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorerKey)
      
      -- Auto generate ID
      IF @cAutoGenID = '1'
      BEGIN
         EXECUTE dbo.nspg_GetKey
            'ID',
            10 ,
            @cAutoID    OUTPUT,
            @b_success  OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @b_success <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 76259, @cLangCode, 'DSP') --GetIDKey Fail
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cAutoGenID AND type = 'P')  
         BEGIN
            DECLARE @cSQL      NVARCHAR(1000)
            DECLARE @cSQLParam NVARCHAR(1000)
            
            SET @cSQL = 'EXEC ' + RTRIM( @cAutoGenID) + ' @cReceiptKey, @cToLOC, @cAutoID OUTPUT'  
            SET @cSQLParam = 
               '@cReceiptKey NVARCHAR( 10), ' +  
               '@cToLOC      NVARCHAR( 10), ' +  
               '@cAutoID     NVARCHAR( 18) OUTPUT'  

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
                @cReceiptKey 
               ,@cToLOC
               ,@cAutoID  OUTPUT
         END
      END
      IF @cAutoID <> '' SET @cTOID = @cAutoID
      
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternPOKey1
      SET @cOutField03 = @cExternPOKey2
      SET @cOutField04 = CASE WHEN rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1' THEN '' ELSE @cToLoc END 
      SET @cOutField05 = @cTOID  
      SET @cOutField06 = ''
        
      -- GOTO Next Screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
   END  -- Inputkey = 1  
  
   IF @nInputKey = 0   
   BEGIN  
      -- If carton receiving with suggested loc then no need goto to loc screen (james01)
      IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1'
      BEGIN
         SET @cOutField01 = @cReceiptKey  
         SET @cOutField02 = @cExternPOKey1
         SET @cOutField03 = @cExternPOKey2
         SET @cOutField04 = ''  
         SET @cOutField05 = ''
           
         -- GOTO ASN Screen  
         SET @nScn = @nScn - 2  
         SET @nStep = @nStep - 2  
      END
      ELSE
      BEGIN
         -- Prepare Next Screen Variable  
         SET @cOutField01 = @cReceiptKey  
         SET @cOutField02 = @cExternPOKey
         SET @cOutField03 = ''
         SET @cOutField04 = ''
           
         -- GOTO Previous Screen  
         SET @nScn = @nScn - 1  
         SET @nStep = @nStep - 1  
      END
   END  
   GOTO Quit  
  
   STEP_3_FAIL:  
   BEGIN  
      -- If config turned on, default to id as receiptkey (james02)
      IF rdt.RDTGetConfig( @nFunc, 'ToIDDefaul2tReceiptKey', @cStorerKey) = '1'
         SET @cOutField05 = @cReceiptKey
      ELSE
         SET @cOutField05 = ''
   END  
END   
GOTO QUIT  
  
/********************************************************************************  
Step 4. Scn = 3013.   
     
   ASN         (Field01)
   ExternPOkey1 (Field02)
   ExternPOkey2 (Field03)
   ToLoc       (Field04)
   To ID       (Field05)
   Carton ID   (Input , Field06)  
     
********************************************************************************/  
Step_4:  
BEGIN  
    IF @nInputKey = 1 --ENTER  
    BEGIN  
      SET @cCartonID = ISNULL(RTRIM(@cInField06),'')  
    
      IF @cCartonID = '' 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76260, @cLangCode, 'DSP') --'CartonID Req'
         GOTO Step_4_Fail
      END

      -- (james04)
      SET @nCartonIDChecked = 0
      
      -- If already setup check format then no need check for carton length below
      IF EXISTS ( SELECT 1
                  FROM CodeLkup WITH (NOLOCK)   
                  WHERE ListName = 'RDTFormat'   
                  AND Code = RTRIM( CAST( @nFunc AS NVARCHAR(5))) + '-CartonID'   
                  AND StorerKey = @cStorerKey)
      BEGIN
         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'CartonID', @cCartonID) = 0
         BEGIN
            SET @nErrNo = 76285
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Step_4_Fail
         END
      
      	SET @nCartonIDChecked = 1
      END
      
      -- (ChewKP01)
      IF Len(@cCartonID) NOT IN (16, 20) AND @nCartonIDChecked = 0 -- (james03)
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76272, @cLangCode, 'DSP') --'Invalid CartonID'
         GOTO Step_4_Fail
      END 

      -- Exclude the check digits (james01)
      -- If length of the carton is < 20 digits and rdt config turned on to ignore last/check digits
      -- else take the full carton id
      IF ISNULL(rdt.RDTGetConfig( @nFunc, 'CtnRcvTakeFullCartonID', @cStorerKey), '') <> '1' 
         AND LEN( RTRIM( @cCartonID)) < 20  -- (james03)
      BEGIN
         --SET @cCartonID = left( @cCartonID, 15)  
         SET @cCartonID = SUBSTRING( RTRIM(@cCartonID), 1, LEN( RTRIM( @cCartonID)) - 1)  -- (james03)
      END
      
      -- (ChewKP01)
      SET @cDisAllowRDTOverReceipt =  ''
      SET @cDisAllowRDTOverReceipt = rdt.RDTGetConfig( @nFunc, 'DisAllowRDTOverReceipt', @cStorerKey) -- Parse in Function
      SET @cExternPOKey = RTRIM(@cExternPOKey1) + RTRIM(@cExternPOKey2)
      
      IF @cDisAllowRDTOverReceipt = '1'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND ReceiptKey = @cReceiptKey
                        AND UserDefine02 = @cExternPOKey
                        AND UserDefine01 = @cCartonID )
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( 76273, @cLangCode, 'DSP') --'NotAllowOverReceipt'
            EXEC rdt.rdtSetFocusField @nMobile, 2 
            GOTO Step_4_Fail
         END                     
      END
      
      SET @cDefaultPieceRecvQTY = ''      
      SET @cDefaultPieceRecvQTY = rdt.RDTGetConfig( @nFunc, 'DefaultPieceRecvQTY', @cStorerKey)
      
      IF @cDefaultPieceRecvQTY = '0'
      BEGIN
            SET @cDefaultPieceRecvQTY = ''
      END
      
      SET @cDefaultCondition = ''
      SET @cDefaultCondition = rdt.RDTGetConfig( @nFunc, 'DefaultConditionCode', @cStorerKey)
      
      SET @nQtyScanned = 0 -- (james01)

      -- Total qty for current receipt + current carton (can contain multiple sku)
      SELECT 
         @nTotalQtyExpected = ISNULL(SUM(QtyExpected), 0), 
         @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine01 = @cCartonID

      SELECT  @nQtyExpected = ISNULL(SUM(QtyExpected), 0)  -- Total expected qty for carton + sku
             ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0) -- Total qty received for carton + sku
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE  ReceiptKey   = @cReceiptKey
         AND StorerKey    = @cStorerKey
         AND UserDefine01 = @cCartonID
         AND SKU          = @cSKU
            
      -- Prepare Next Screen Variable  
      SET @cOutField01 = @cCartonID  
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = @cDefaultCondition
      SET @cOutField06 = @cDefaultPieceRecvQTY 
      SET @cOutField07 = CASE WHEN @nTotalQtyReceived = 0 THEN '-' ELSE @nTotalQtyReceived END
--      SET @cOutField08 = CASE WHEN @nTotalCartonQty = 0 THEN '-' ELSE @nTotalCartonQty END
      SET @cOutField08 = CASE WHEN @nQtyExpected = 0 THEN '-' ELSE @nQtyExpected END
      SET @cOutField09 = CASE WHEN @nTotalCartonQty = 0 THEN '-' ELSE @nTotalCartonQty END
      SET @cOutField10 = CASE WHEN @nTotalQtyExpected = 0 THEN '-' ELSE @nTotalQtyExpected END
        
      --GOTO Next Screen  
      SET @nScn = @nScn + 1  
      SET @nStep = @nStep + 1  
         
    END  -- Inputkey = 1  
  
    IF @nInputKey = 0   
    BEGIN  
      IF @@Error <> 0 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76262, @cLangCode, 'DSP') --'DelRcpLogFail'
         GOTO Step_4_Fail
      END
         
      -- Prepare Previous Screen Variable  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternPOKey1
      SET @cOutField03 = @cExternPOKey2
      SET @cOutField04 = @cToLoc  

      -- If config turned on, default to id as receiptkey (james02)
      IF rdt.RDTGetConfig( @nFunc, 'ToIDDefaul2tReceiptKey', @cStorerKey) = '1'
         SET @cOutField05 = @cReceiptKey
      ELSE
         SET @cOutField05 = ''
         
       -- GOTO Previous Screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
    END  
    GOTO Quit  
  
    STEP_4_FAIL:  
    BEGIN  
       SET @cOutField06 = ''
    END  
END   
GOTO QUIT  
  
  
  
/********************************************************************************  
Step 5. Scn = 3073.   
   Carton ID    (Field01)  
   SKU          (Input, Field02)    
   Descr 1      (Field03)    
   Descr 2      (Field04)    
   Condtion Code (Input, Field05)  
   Qty to RCV   (Input, Field06)    
   Qty          (Field07) / (Field08)
     
********************************************************************************/  
Step_5:  
BEGIN  
   IF @nInputKey = 1 
   BEGIN  
      SET @cInSKU          = ISNULL(RTRIM(@cInField02),'')  
      SET @cConditionCode  = ISNULL(RTRIM(@cInField05),'')  
      SET @cQtyReceived    = ISNULL(RTRIM(@cInField06),'')  
      
      IF @cInSKU = '' 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76263, @cLangCode, 'DSP') --'SKU Req'
         GOTO Step_5_Fail
      END
      
      SELECT @b_success = 1
      EXEC dbo.nspg_GETSKU
                     @cStorerKey
      ,              @cInSKU     OUTPUT
      ,              @b_success  OUTPUT
      ,              @nErrNo     OUTPUT
      ,              @cErrMsg    OUTPUT

   	IF @b_success = 0
   	BEGIN
         -- Invalid Sku
         SET @cErrMsg = rdt.rdtgetmessage( 76264, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_5_Fail
      END
      ELSE
      BEGIN
         SET @cSKU = @cInSKU
      END

      IF @cConditionCode = '' 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76265, @cLangCode, 'DSP') --'ConditionCodeReq'
         EXEC rdt.rdtSetFocusField @nMobile, 2 
         GOTO Step_5_Fail
      END      
      
      IF @cConditionCode NOT IN ('0', '1')
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76266, @cLangCode, 'DSP') --'Invalid Code'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_5_Fail
      END
      
      IF @cQtyReceived = '' 
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76267, @cLangCode, 'DSP') --'QtyRcv Req'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_5_Fail
      END 

      IF rdt.rdtIsValidQty( @cQtyReceived, 21) = 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 76268, @cLangCode, 'DSP') --'Invalid Qty'
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_5_Fail
      END

      SET @cSKUDesc = ''
      SET @nQtyReceived = 0 
      SET @nQtyExpected = 0
      SET @nTotalQtyReceived = 0
      
      SELECT
           @cSKUDesc = IsNULL( DescR, ''), 
           @cPackKey = PackKey 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE SKU      = @cSKU
      AND StorerKey  = @cStorerKey

      SELECT  
         @cUOM = PACK.PackUOM3  
      FROM dbo.Pack Pack WITH (NOLOCK)  
      WHERE PackKey = @cPackKey  
       
      IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                      WHERE  ReceiptKey   = @cReceiptKey
                      AND StorerKey    = @cStorerKey
                      AND UserDefine01 = @cCartonID
                      AND SKU          = @cSKU  
                      AND UserDefine08 = '' ) 
      BEGIN                      
         SELECT  @nQtyExpected = SUM(QtyExpected)
                ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine01 = @cCartonID
            AND SKU          = @cSKU
      END
      ELSE
      BEGIN
         SELECT @nQtyExpected = SUM(QtyExpected)
                ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine08 = @cCartonID
            AND SKU          = @cSKU
            
      END
      
      SET @nQtyReceived  = CAST (@cQtyReceived AS INT)
      SET @nTotalQtyReceived = @nTotalQtyReceived + @nQtyReceived
     
      SET @cExternPOKey = RTRIM(@cExternPOKey1) + RTRIM(@cExternPOKey2)

      -- Receive
      -- If suggested loc is required then move confirm receive to next screen   -- (james01)
      IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) <> '1' 
      BEGIN
         EXEC rdt.rdt_CartonIDReceiving_Confirm
               @nFunc          = @nFunc
              ,@nMobile        = @nMobile
              ,@cLangCode      = @cLangCode
              ,@cFacility      = @cFacility
              ,@cReceiptKey    = @cReceiptKey
              ,@cStorerKey     = @cStorerKey
              ,@cSKU           = @cSKU
              ,@cExternPOKey   = @cExternPOKey
              ,@cToLoc         = @cToLoc
              ,@cToID          = @cToID
              ,@cCartonId      = @cCartonId 
              ,@nQtyReceived   = @nQtyReceived
              ,@cConditionCode = @cConditionCode
              ,@nErrNo         = @nErrNo OUTPUT
              ,@cErrMsg        = @cErrMsg OUTPUT

         IF @nErrno <> 0
         BEGIN
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
             GOTO Step_5_Fail
         END

      -- Total qty for current receipt + current carton (can contain multiple sku)
         SELECT 
            @nTotalQtyExpected = ISNULL(SUM(QtyExpected), 0), 
            @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE  ReceiptKey   = @cReceiptKey
               AND StorerKey    = @cStorerKey
               AND @cCartonID IN (UserDefine01, UserDefine08)
                  
         /*
         -- Get Total Carton Qty -- (ChewKP01)
         SET @nTotalCartonQty = 0
         IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                         WHERE  ReceiptKey   = @cReceiptKey
                         AND StorerKey    = @cStorerKey
                         AND UserDefine01 = @cCartonID
                         AND SKU          = @cSKU  
                         AND UserDefine08 = '' ) 
         BEGIN
         
            SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE  ReceiptKey   = @cReceiptKey
                  AND StorerKey    = @cStorerKey
                  AND UserDefine01 = @cCartonID
         END
         ELSE
         BEGIN
            SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
            FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE  ReceiptKey   = @cReceiptKey
                  AND StorerKey    = @cStorerKey
                  AND UserDefine08 = @cCartonID
         END
         */
         -- Prepare Next Screen Variable  
         SET @cOutField01 = @cCartonID  
         SET @cOutField02 = ''
         SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField05 = @cConditionCode
         SET @cOutField06 = @cDefaultPieceRecvQTY
         SET @cOutField07 = RTRIM(CAST ( @nTotalQtyReceived AS NVARCHAR(5))) 
--         SET @cOutField08 = RTRIM(CAST ( @nTotalCartonQty AS NVARCHAR(5)))
         SET @cOutField08 = RTRIM(CAST ( @nQtyExpected AS NVARCHAR(5)))
         SET @cOutField09 = RTRIM(CAST ( @nTotalCartonQty AS NVARCHAR(5)))
         SET @cOutField10 = RTRIM(CAST ( @nTotalQtyExpected AS NVARCHAR(5)))

      END
      ELSE
      BEGIN
         -- (james01)
         IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1' 
         BEGIN
            SET @nErrNo = 0
            SET @cCtnRcvGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'CtnRcvGetSuggestedLoc_SP', @cStorerKey)
            IF ISNULL(@cCtnRcvGetSuggestedLoc_SP, '') NOT IN ('', '0')
            BEGIN
               EXEC RDT.RDT_CtnRcvGetSuggestedLoc_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cCtnRcvGetSuggestedLoc_SP
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@c_ReceiptKey    = @cReceiptKey
                  ,@c_FromLoc       = ''
                  ,@c_ToLoc         = ''
                  ,@c_FromID        = @cToID
                  ,@c_ToID          = @cToID
                  ,@n_QtyReceived   = @nQtyReceived
                  ,@c_oFieled01     = @c_oFieled01    OUTPUT
                  ,@c_oFieled02     = @c_oFieled02    OUTPUT
                  ,@c_oFieled03     = @c_oFieled03    OUTPUT
                  ,@c_oFieled04     = @c_oFieled04    OUTPUT
                  ,@c_oFieled05     = @c_oFieled05    OUTPUT
                  ,@c_oFieled06     = @c_oFieled06    OUTPUT
                  ,@c_oFieled07     = @c_oFieled07    OUTPUT
                  ,@c_oFieled08     = @c_oFieled08    OUTPUT
                  ,@c_oFieled09     = @c_oFieled09    OUTPUT
                  ,@c_oFieled10     = @c_oFieled10    OUTPUT
                  ,@c_oFieled11     = @c_oFieled11    OUTPUT
                  ,@c_oFieled12     = @c_oFieled12    OUTPUT
                  ,@c_oFieled13     = @c_oFieled13    OUTPUT
                  ,@c_oFieled14     = @c_oFieled14    OUTPUT
                  ,@c_oFieled15     = @c_oFieled15    OUTPUT
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT
            END
            
            -- If config turned on, default to Loc (james02)
            SET @cDefaultToLOC =  rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)

            SET @cOutField01 = @cSKU  
            SET @cOutField02 = '1. ' + @c_oFieled01
            SET @cOutField03 = '2. ' + @c_oFieled02
            SET @cOutField04 = '3. ' + @c_oFieled03
            SET @cOutField05 = '4. ' + @c_oFieled04
            SET @cOutField06 = '5. ' + @c_oFieled05
            SET @cOutField07 = CASE WHEN ISNULL(@cDefaultToLOC, '') = '' THEN '' ELSE @cDefaultToLOC END  -- To Loc
            
            -- GOTO Next Screen  
            SET @nScn = @nScn + 1   
            SET @nStep = @nStep + 1  
         
            GOTO Quit
         END
      END
   END  -- Inputkey = 1  
   
   IF @nInputKey = 0   
   BEGIN  
      SET @cOutField01 = @cReceiptKey  
      SET @cOutField02 = @cExternPOKey1
      SET @cOutField03 = @cExternPOKey2
      SET @cOutField04 = @cToLoc  
      SET @cOutField05 = @cTOID  
      SET @cOutField06 = ''
              
      -- GOTO Previous Screen  
      SET @nScn = @nScn - 1  
      SET @nStep = @nStep - 1  
    END  
    GOTO Quit  
  
    STEP_5_FAIL:  
    BEGIN  
       SET @cOutField02 = ''
    END  
END   
GOTO QUIT  

/********************************************************************************  
Step 6. Scn = 3105.   
   SKU          (Field01)
   LOC1         (Field02)
   LOC1         (Field03)
   LOC1         (Field04)
   LOC1         (Field05)
   LOC1         (Field06)
   TO LOC       (Input, Field07)    
********************************************************************************/  
Step_6:  
BEGIN  
   IF @nInputKey = 1 
   BEGIN  
--      SET @cSLoc1 = RIGHT(RTRIM(@cOutField02), LEN(RTRIM(@cOutField02)) - 3)
      
      SET @cSLoc1 = CASE WHEN SUBSTRING(@cOutField02, 4, 10) <> '' THEN RIGHT(RTRIM(@cOutField02), LEN(RTRIM(@cOutField02)) - 3) ELSE '' END
      SET @cSLoc2 = CASE WHEN SUBSTRING(@cOutField03, 4, 10) <> '' THEN RIGHT(RTRIM(@cOutField03), LEN(RTRIM(@cOutField03)) - 3) ELSE '' END
      SET @cSLoc3 = CASE WHEN SUBSTRING(@cOutField04, 4, 10) <> '' THEN RIGHT(RTRIM(@cOutField04), LEN(RTRIM(@cOutField04)) - 3) ELSE '' END
      SET @cSLoc4 = CASE WHEN SUBSTRING(@cOutField05, 4, 10) <> '' THEN RIGHT(RTRIM(@cOutField05), LEN(RTRIM(@cOutField05)) - 3) ELSE '' END
      SET @cSLoc5 = CASE WHEN SUBSTRING(@cOutField06, 4, 10) <> '' THEN RIGHT(RTRIM(@cOutField06), LEN(RTRIM(@cOutField06)) - 3) ELSE '' END
      SET @cToLoc = ISNULL(@cInField07,'')  
    
      IF ISNULL(@cToLoc, '') = '' 
      BEGIN
         SET @nErrNo = 76274    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --LOC required    
         GOTO Step_6_Fail    
      END 

      -- Verify LOC
      IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                     WHERE LOC = @cToLoc 
                     AND   Facility = @cFacility) 
      BEGIN
         SET @nErrNo = 76282    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid LOC 
         GOTO Step_6_Fail    
      END 

      -- If config turned on, default to Loc (james02)
      SET @cDefaultToLOC =  rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)

      -- If first suggested loc is not blank then to loc must be in between SLoc1 - SLoc5
      IF RTRIM(@cSLoc1) <> ''
      BEGIN
         -- If ToLoc is not in one of the suggested LOC or default ToLoc 
         IF SUBSTRING(@cToLoc, 2, LEN(RTRIM(@cToLoc)) - 1) NOT IN (
            CASE WHEN @cSLoc1 = '' THEN '' ELSE SUBSTRING(@cSLoc1, 2, LEN(RTRIM(@cSLoc1)) - 1) END,
            CASE WHEN @cSLoc2 = '' THEN '' ELSE SUBSTRING(@cSLoc2, 2, LEN(RTRIM(@cSLoc2)) - 1) END,
            CASE WHEN @cSLoc3 = '' THEN '' ELSE SUBSTRING(@cSLoc3, 2, LEN(RTRIM(@cSLoc3)) - 1) END,
            CASE WHEN @cSLoc4 = '' THEN '' ELSE SUBSTRING(@cSLoc4, 2, LEN(RTRIM(@cSLoc4)) - 1) END,
            CASE WHEN @cSLoc5 = '' THEN '' ELSE SUBSTRING(@cSLoc5, 2, LEN(RTRIM(@cSLoc5)) - 1) END,
            CASE WHEN @cDefaultToLOC = '' THEN '' ELSE SUBSTRING(@cDefaultToLOC, 2, LEN(RTRIM(@cDefaultToLOC)) - 1) END)  -- (james02)
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'CtnRcvAllowNewLoc', @cStorerKey) = '1'
            BEGIN
               SET @cOutField01 = ''
               
               -- GOTO Next Screen  
               SET @nScn = @nScn + 1   
               SET @nStep = @nStep + 1  
               
               GOTO Quit
            END
            ELSE
            BEGIN
               SET @nErrNo = 76275    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid LOC    
               GOTO Step_6_Fail
            END
         END
      END
      ELSE
      BEGIN -- (james02)
         IF @cToLoc <> @cDefaultToLOC
         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'CtnRcvAllowNewLoc', @cStorerKey) = '1'
            BEGIN
               SET @cOutField01 = ''
               
               -- GOTO Next Screen  
               SET @nScn = @nScn + 1   
               SET @nStep = @nStep + 1  
               
               GOTO Quit
            END
            ELSE
            BEGIN
               SET @nErrNo = 76284    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid LOC    
               GOTO Step_6_Fail
            END
         END
      END
      
      IF rdt.RDTGetConfig( @nFunc, 'CtnRcvGetFacilityPrefix', @cStorerKey) = '1'
      BEGIN
         -- In inditex case, product need to move from facility A to facility B
         -- but physical loc is without prefix of A or B. So user scan loc and depends 
         -- on user login facility then append facility prefix to the loc  (james01)
         SELECT @cFacPrefix = Short from dbo.CodeLKUP WITH (NOLOCK) 
         WHERE Listname = 'GETFACPREF'
         AND   Code = @cFacility
         
         IF ISNULL(@cFacPrefix, '') = ''
         BEGIN
            SET @nErrNo = 76281    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --No Fac Prefix 
            GOTO Step_6_Fail    
         END 
         ELSE
         BEGIN
            -- If ToLOC same as the default To LOC then no need swap (james02)
            IF (@cToLoc <> @cDefaultToLOC) AND ISNULL(@cDefaultToLOC, '') <> ''
               SET @cToLoc = RTRIM(@cFacPrefix) + SUBSTRING(@cToLoc, 2, LEN(RTRIM(@cToLoc)) - 1)
         END
      END
      
      IF NOT EXISTS (SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                     WHERE LOC = @cToLoc
                     AND   Facility = @cFacility
                     AND   HostWHCode = 'RECEIVED')
      BEGIN
         SET @nErrNo = 76276    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid LOC    
         GOTO Step_6_Fail
      END
      
      GOTO Carton_ID_Receive
    
   END  -- Inputkey = 1  
   
   IF @nInputKey = 0   
   BEGIN  
      SET @cDefaultPieceRecvQTY = ''      
      SET @cDefaultPieceRecvQTY = rdt.RDTGetConfig( @nFunc, 'DefaultPieceRecvQTY', @cStorerKey)
      
      IF @cDefaultPieceRecvQTY = '0'
      BEGIN
         SET @cDefaultPieceRecvQTY = ''
      END
      
      SET @cDefaultCondition = ''
      SET @cDefaultCondition = rdt.RDTGetConfig( @nFunc, 'DefaultConditionCode', @cStorerKey)

      SELECT
           @cSKUDesc = IsNULL( DescR, ''), 
           @cPackKey = PackKey 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE SKU      = @cSKU
      AND StorerKey  = @cStorerKey

      -- Total qty for current receipt + current carton (can contain multiple sku)
      SELECT 
         @nTotalQtyExpected = ISNULL(SUM(QtyExpected), 0), 
         @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine01 = @cCartonID

      SELECT  @nQtyExpected = SUM(QtyExpected)  -- Total expected qty for carton + sku
             ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0) -- Total qty received for carton + sku
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE  ReceiptKey   = @cReceiptKey
         AND StorerKey    = @cStorerKey
         AND UserDefine01 = @cCartonID
         AND SKU          = @cSKU
         
      -- Prepare Next Screen Variable  
      SET @cOutField01 = @cCartonID
      SET @cOutField02 = ''
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField05 = @cDefaultCondition
      SET @cOutField06 = @cDefaultPieceRecvQTY 
--      SET @cOutField07 = CAST ( @nQtyReceived AS NVARCHAR(5))
--      SET @cOutField08 = CAST ( @nQtyExpected AS NVARCHAR(5))
      SET @cOutField07 = @nTotalQtyReceived
      --SET @cOutField08 = @nTotalCartonQty
      SET @cOutField08 = @nQtyExpected
      SET @cOutField09 = @nTotalCartonQty
      SET @cOutField10 = @nTotalQtyExpected


      
        
       -- GOTO Previous Screen  
      SET @nScn = @nScn - 1 
      SET @nStep = @nStep - 1  
   END  
   GOTO Quit  
  
   STEP_6_FAIL:  
   BEGIN  
      SET @cToLoc = ''
      SET @cOutField07 = ''
   END  
END   
GOTO QUIT   

/********************************************************************************  
Step 7. Scn = 3106.   
   Message
   Option       (Input, Field01)    
********************************************************************************/  
Step_7:  
BEGIN  
   IF @nInputKey = 1 
   BEGIN  
      SET @cOption = @cInField01
    
      IF ISNULL(@cOption, '') = '' 
      BEGIN
         SET @nErrNo = 76277    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req 
         GOTO Step_7_Fail    
      END 

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 76278    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option    
         GOTO Step_7_Fail    
      END 

      IF @cOption = '1'
      BEGIN
         IF rdt.RDTGetConfig( @nFunc, 'CtnRcvGetFacilityPrefix', @cStorerKey) = '1'
         BEGIN
            -- In inditex case, product need to move from facility A to facility B
            -- but physical loc is without prefix of A or B. So user scan loc and depends 
            -- on user login facility then append facility prefix to the loc  (james01)
            SELECT @cFacPrefix = Short from dbo.CodeLKUP WITH (NOLOCK) 
            WHERE Listname = 'GETFACPREF'
            AND   Code = @cFacility
            
            IF ISNULL(@cFacPrefix, '') = ''
            BEGIN
               SET @nErrNo = 76283    
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --No Fac Prefix 
               GOTO Step_7_Fail    
            END 
            ELSE
               SET @cToLoc = RTRIM(@cFacPrefix) + SUBSTRING(@cToLoc, 2, LEN(RTRIM(@cToLoc)) - 1)
         END

         SELECT @cToLocFacility = Facility 
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE LOC = @cToLoc
         AND   HostWHCode = 'RECEIVED'
                        
         IF ISNULL(@cToLocFacility, '') = ''
         BEGIN
            SET @nErrNo = 76279    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid LOC    
            GOTO Step_7_Fail    
         END 

         IF @cToLocFacility <> @cFacility
         BEGIN
            SET @nErrNo = 76280    
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Diff Fac    
            GOTO Step_7_Fail    
         END 
         
         GOTO Carton_ID_Receive
      END
      ELSE
      BEGIN
         -- (james01)
         IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1' 
         BEGIN
            SET @nErrNo = 0
            SET @cCtnRcvGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'CtnRcvGetSuggestedLoc_SP', @cStorerKey)
            IF ISNULL(@cCtnRcvGetSuggestedLoc_SP, '') NOT IN ('', '0')
            BEGIN
               EXEC RDT.RDT_CtnRcvGetSuggestedLoc_Wrapper
                   @n_Mobile        = @nMobile
                  ,@n_Func          = @nFunc
                  ,@c_LangCode      = @cLangCode
                  ,@c_SPName        = @cCtnRcvGetSuggestedLoc_SP
                  ,@c_Storerkey     = @cStorerKey
                  ,@c_SKU           = @cSKU
                  ,@c_ReceiptKey    = @cReceiptKey
                  ,@c_FromLoc       = ''
                  ,@c_ToLoc         = ''
                  ,@c_FromID        = @cToID
                  ,@c_ToID          = @cToID
                  ,@n_QtyReceived   = @nQtyReceived
                  ,@c_oFieled01     = @c_oFieled01    OUTPUT
                  ,@c_oFieled02     = @c_oFieled02    OUTPUT
                  ,@c_oFieled03     = @c_oFieled03    OUTPUT
                  ,@c_oFieled04     = @c_oFieled04    OUTPUT
                  ,@c_oFieled05     = @c_oFieled05    OUTPUT
                  ,@c_oFieled06     = @c_oFieled06    OUTPUT
                  ,@c_oFieled07     = @c_oFieled07    OUTPUT
                  ,@c_oFieled08     = @c_oFieled08    OUTPUT
                  ,@c_oFieled09     = @c_oFieled09    OUTPUT
                  ,@c_oFieled10     = @c_oFieled10    OUTPUT
                  ,@c_oFieled11     = @c_oFieled11    OUTPUT
                  ,@c_oFieled12     = @c_oFieled12    OUTPUT
                  ,@c_oFieled13     = @c_oFieled13    OUTPUT
                  ,@c_oFieled14     = @c_oFieled14    OUTPUT
                  ,@c_oFieled15     = @c_oFieled15    OUTPUT
                  ,@b_Success       = @b_Success      OUTPUT
                  ,@n_ErrNo         = @nErrNo         OUTPUT
                  ,@c_ErrMsg        = @cErrMsg        OUTPUT
            END
         
            SET @cOutField01 = @cSKU  
            SET @cOutField02 = '1. ' + @c_oFieled01
            SET @cOutField03 = '2. ' + @c_oFieled02
            SET @cOutField04 = '3. ' + @c_oFieled03
            SET @cOutField05 = '4. ' + @c_oFieled04
            SET @cOutField06 = '5. ' + @c_oFieled05
            SET @cOutField07 = ''   -- To Loc

            -- GOTO prev Screen  
            SET @nScn = @nScn - 1   
            SET @nStep = @nStep - 1  
         END
      END
   END  -- Inputkey = 1  
   
   IF @nInputKey = 0   
   BEGIN  
      -- (james01)
      IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1' 
      BEGIN
         SET @nErrNo = 0
         SET @cCtnRcvGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'CtnRcvGetSuggestedLoc_SP', @cStorerKey)
         IF ISNULL(@cCtnRcvGetSuggestedLoc_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_CtnRcvGetSuggestedLoc_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cCtnRcvGetSuggestedLoc_SP
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ReceiptKey    = @cReceiptKey
               ,@c_FromLoc       = ''
               ,@c_ToLoc         = ''
               ,@c_FromID        = @cToID
               ,@c_ToID          = @cToID
               ,@n_QtyReceived   = @nQtyReceived
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT
         END
         
         SET @cOutField01 = @cSKU  
         SET @cOutField02 = '1. ' + @c_oFieled01
         SET @cOutField03 = '2. ' + @c_oFieled02
         SET @cOutField04 = '3. ' + @c_oFieled03
         SET @cOutField05 = '4. ' + @c_oFieled04
         SET @cOutField06 = '5. ' + @c_oFieled05
         SET @cOutField07 = ''   -- To Loc

         -- GOTO prev Screen  
         SET @nScn = @nScn - 1   
         SET @nStep = @nStep - 1  
      END
   END  
   GOTO Quit  
  
   STEP_7_FAIL:  
   BEGIN  
     SET @cOutField01 = ''
   END  
END   
GOTO QUIT   

Carton_ID_Receive:
BEGIN
   SET @cSKUDesc = ''
   SET @nQtyReceived = 0 
   SET @nQtyExpected = 0
   SET @nTotalQtyReceived = 0
   
   SELECT
        @cSKUDesc = IsNULL( DescR, '')
   FROM dbo.SKU WITH (NOLOCK)
   WHERE SKU      = @cSKU
   AND StorerKey  = @cStorerKey
   
   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                   WHERE  ReceiptKey   = @cReceiptKey
                   AND StorerKey    = @cStorerKey
                   AND UserDefine01 = @cCartonID
                   AND SKU          = @cSKU  
                   AND UserDefine08 = '' ) 
   BEGIN                      
      SELECT  @nQtyExpected = SUM(QtyExpected)
             ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE  ReceiptKey   = @cReceiptKey
         AND StorerKey    = @cStorerKey
         AND UserDefine01 = @cCartonID
         AND SKU          = @cSKU
--      insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5) values
--      ('cartonid', getdate(), @cReceiptKey, @cStorerKey, @cCartonID, @cSKU, @nQtyExpected)
   END
   ELSE
   BEGIN
      SELECT @nQtyExpected = SUM(QtyExpected)
             ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE  ReceiptKey   = @cReceiptKey
         AND StorerKey    = @cStorerKey
         AND UserDefine08 = @cCartonID
         AND SKU          = @cSKU
         
   END
   
   SET @nQtyReceived  = CAST (@cQtyReceived AS INT)
   SET @nTotalQtyReceived = @nTotalQtyReceived + @nQtyReceived
  
   SET @cExternPOKey = RTRIM(@cExternPOKey1) + RTRIM(@cExternPOKey2)

   -- Receive
   EXEC rdt.rdt_CartonIDReceiving_Confirm
         @nFunc          = @nFunc
        ,@nMobile        = @nMobile
        ,@cLangCode      = @cLangCode
        ,@cFacility      = @cFacility
        ,@cReceiptKey    = @cReceiptKey
        ,@cStorerKey     = @cStorerKey
        ,@cSKU           = @cSKU
        ,@cExternPOKey   = @cExternPOKey
        ,@cToLoc         = @cToLoc
        ,@cToID          = @cToID
        ,@cCartonId      = @cCartonId 
        ,@nQtyReceived   = @nQtyReceived
        ,@cConditionCode = @cConditionCode
        ,@nErrNo         = @nErrNo OUTPUT
        ,@cErrMsg        = @cErrMsg OUTPUT
 
   IF @nErrno <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
      -- (james01)
      IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) = '1' 
      BEGIN
         SET @nErrNo = 0
         SET @cCtnRcvGetSuggestedLoc_SP = rdt.RDTGetConfig( @nFunc, 'CtnRcvGetSuggestedLoc_SP', @cStorerKey)
         IF ISNULL(@cCtnRcvGetSuggestedLoc_SP, '') NOT IN ('', '0')
         BEGIN
            EXEC RDT.RDT_CtnRcvGetSuggestedLoc_Wrapper
                @n_Mobile        = @nMobile
               ,@n_Func          = @nFunc
               ,@c_LangCode      = @cLangCode
               ,@c_SPName        = @cCtnRcvGetSuggestedLoc_SP
               ,@c_Storerkey     = @cStorerKey
               ,@c_SKU           = @cSKU
               ,@c_ReceiptKey    = @cReceiptKey
               ,@c_FromLoc       = ''
               ,@c_ToLoc         = ''
               ,@c_FromID        = @cToID
               ,@c_ToID          = @cToID
               ,@n_QtyReceived   = @nQtyReceived
               ,@c_oFieled01     = @c_oFieled01    OUTPUT
               ,@c_oFieled02     = @c_oFieled02    OUTPUT
               ,@c_oFieled03     = @c_oFieled03    OUTPUT
               ,@c_oFieled04     = @c_oFieled04    OUTPUT
               ,@c_oFieled05     = @c_oFieled05    OUTPUT
               ,@c_oFieled06     = @c_oFieled06    OUTPUT
               ,@c_oFieled07     = @c_oFieled07    OUTPUT
               ,@c_oFieled08     = @c_oFieled08    OUTPUT
               ,@c_oFieled09     = @c_oFieled09    OUTPUT
               ,@c_oFieled10     = @c_oFieled10    OUTPUT
               ,@c_oFieled11     = @c_oFieled11    OUTPUT
               ,@c_oFieled12     = @c_oFieled12    OUTPUT
               ,@c_oFieled13     = @c_oFieled13    OUTPUT
               ,@c_oFieled14     = @c_oFieled14    OUTPUT
               ,@c_oFieled15     = @c_oFieled15    OUTPUT
               ,@b_Success       = @b_Success      OUTPUT
               ,@n_ErrNo         = @nErrNo         OUTPUT
               ,@c_ErrMsg        = @cErrMsg        OUTPUT
         END
         
         SET @cOutField01 = @cSKU  
         SET @cOutField02 = '1. ' + @c_oFieled01
         SET @cOutField03 = '2. ' + @c_oFieled02
         SET @cOutField04 = '3. ' + @c_oFieled03
         SET @cOutField05 = '4. ' + @c_oFieled04
         SET @cOutField06 = '5. ' + @c_oFieled05
         SET @cOutField07 = ''   -- To Loc
      END
      GOTO Step_5_Fail
   END

   -- Reset qty scanned    -- (james01)
   SET @nQtyScanned = 0
   SET @cPrevSKU = ''
   
   SELECT 
      @nTotalQtyExpected = ISNULL(SUM(QtyExpected), 0), 
      @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE  ReceiptKey   = @cReceiptKey
         AND StorerKey    = @cStorerKey
         AND @cCartonID IN (UserDefine01, UserDefine08)
   /*
   SET @nTotalCartonQty = 0
   IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                   WHERE  ReceiptKey   = @cReceiptKey
                   AND StorerKey    = @cStorerKey
                   AND UserDefine01 = @cCartonID
                   AND SKU          = @cSKU  
                   AND UserDefine08 = '' ) 
   BEGIN
   
      SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine01 = @cCartonID
   END
   ELSE
   BEGIN
      SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine08 = @cCartonID
   END
   */
   -- Prepare Next Screen Variable  
   SET @cOutField01 = @cCartonID  
   SET @cOutField02 = ''
   SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
   SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
   SET @cOutField05 = @cConditionCode
   SET @cOutField06 = @cDefaultPieceRecvQTY
   SET @cOutField07 = RTRIM(CAST ( @nTotalQtyReceived AS NVARCHAR(5))) 
   --SET @cOutField08 = RTRIM(CAST ( @nTotalCartonQty AS NVARCHAR(5)))
   SET @cOutField08 = RTRIM(CAST ( @nQtyExpected AS NVARCHAR(5)))
   SET @cOutField09 = @nTotalCartonQty 
   SET @cOutField10 = @nTotalQtyExpected 

      
/*
   -- (james01)
   IF rdt.RDTGetConfig( @nFunc, 'CtnRcvWithSuggestedLoc', @cStorerKey) <> '1' 
   BEGIN
      -- Get Total Carton Qty -- (ChewKP01)
      SET @nTotalCartonQty = 0
      IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                      WHERE  ReceiptKey   = @cReceiptKey
                      AND StorerKey    = @cStorerKey
                      AND UserDefine01 = @cCartonID
                      AND SKU          = @cSKU  
                      AND UserDefine08 = '' ) 
      BEGIN
      
         SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE  ReceiptKey   = @cReceiptKey
               AND StorerKey    = @cStorerKey
               AND UserDefine01 = @cCartonID
      END
      ELSE
      BEGIN
         SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE  ReceiptKey   = @cReceiptKey
               AND StorerKey    = @cStorerKey
               AND UserDefine08 = @cCartonID
      END
      
      -- Prepare Next Screen Variable  
      SET @cOutField01 = @cCartonID  
      SET @cOutField02 = ''
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField05 = @cConditionCode
      SET @cOutField06 = @cDefaultPieceRecvQTY
      SET @cOutField07 = RTRIM(CAST ( @nTotalQtyReceived AS NVARCHAR(5))) 
      SET @cOutField08 = RTRIM(CAST ( @nTotalCartonQty AS NVARCHAR(5)))
      SET @cOutField09 = RTRIM(CAST ( @nQtyExpected AS NVARCHAR(5)))
   END
   ELSE
   BEGIN
      SET @nTotalCartonQty = 0
      SET @nTotalASNQty = 0
      
      -- Total qty for current receipt + current carton (can contain multiple sku)
      SELECT @nTotalCartonQty = ISNULL(SUM(BeforeReceivedQty) ,0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE  ReceiptKey   = @cReceiptKey
            AND StorerKey    = @cStorerKey
            AND UserDefine01 = @cCartonID

      SELECT  @nQtyExpected = SUM(QtyExpected)  -- Total expected qty for carton + sku
             ,@nTotalQtyReceived = ISNULL(SUM(BeforeReceivedQty) ,0) -- Total qty received for carton + sku
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE  ReceiptKey   = @cReceiptKey
         AND StorerKey    = @cStorerKey
         AND UserDefine01 = @cCartonID
         AND SKU          = @cSKU
            
      -- Prepare Next Screen Variable  
      SET @cOutField01 = @cCartonID  
      SET @cOutField02 = ''
      SET @cOutField03 = SUBSTRING( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField04 = SUBSTRING( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField05 = @cConditionCode
      SET @cOutField06 = @cDefaultPieceRecvQTY
      SET @cOutField07 = RTRIM(CAST ( @nTotalQtyReceived AS NVARCHAR(5))) 
      SET @cOutField08 = RTRIM(CAST ( @nTotalCartonQty AS NVARCHAR(5)))
      SET @cOutField09 = RTRIM(CAST ( @nQtyExpected AS NVARCHAR(5)))
   END
   */
   -- GOTO Carton ID Screen  
   SET @nScn = 3104  
   SET @nStep = 5  

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
      Printer   = @cPrinter,   
      --UserName  = @cUserName,  
      InputKey  = @nInputKey,  
    
    
      V_Loc     = @cToLoc,
      V_ID      = @cToID,
      V_ReceiptKey = @cReceiptKey,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDesc,
      V_UOM        = @cUOM,  
      
      V_FromScn  = @nPrevScn,
      V_FromStep = @nPrevStp,
      
      V_Integer1 = @nTotalQtyReceived,
      V_Integer2 = @nTotalCartonQty,
      V_Integer3 = @nQtyExpected,
      V_Integer4 = @nQtyScanned,
      
      V_String1   = @cExternPOKey1,
      V_String2   = @cCartonID,
      V_String3   = @cConditionCode,
      V_String4   = @cQtyReceived,
      --V_String5   = @nTotalQtyReceived,
      --V_String6   = @nTotalCartonQty,
      V_String7   = @cExternPOKey2,
      V_String8   = @cDefaultPieceRecvQTY,
      --V_String9   = @nQtyExpected,
      --V_String10  = @nPrevScn,
      --V_String11  = @nPrevStp,
      --V_String12  = @nQtyScanned,
      V_String13  = @cPrevSKU,
   
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