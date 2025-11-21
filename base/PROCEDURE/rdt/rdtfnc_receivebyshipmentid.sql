SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdtfnc_ReceiveByShipmentID                          */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Receive by carton no                                        */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2013-02-27 1.0  James    SOS271073 Created                           */   
/* 2016-09-30 1.1  Ung      Performance tuning                          */
/* 2018-11-13 1.2  TungGH   Performance                                 */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdtfnc_ReceiveByShipmentID] (    
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max    
) AS    
    
SET NOCOUNT ON    
SET ANSI_NULLS OFF    
SET QUOTED_IDENTIFIER OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE @b_Success      INT,     
   @cExtendedInfoSP     NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),    
   @cSQL                NVARCHAR(1000),     
   @cSQLParam           NVARCHAR(1000)    
    
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
   @cUserName   NVARCHAR(18),    
   @cPrinter    NVARCHAR(10),    
    
   @cLoadKey      NVARCHAR( 10),  
   @cConsigneeKey NVARCHAR( 15),  
   @cReceiptKey   NVARCHAR( 10),  
   @cPOKey        NVARCHAR( 10),  
   @cToLOC        NVARCHAR( 10),  
   @cLOC          NVARCHAR( 10),  
   @cSKU          NVARCHAR( 20),  
   @cUOM          NVARCHAR( 10),  
   @cID           NVARCHAR( 18),  
   @cSKUDesc      NVARCHAR( 60),  
   @cLottable01   NVARCHAR( 18),  
   @cLottable02   NVARCHAR( 18),  
   @cLottable03   NVARCHAR( 18),  
   @cLottable04   NVARCHAR( 16),  
   @cLottable05   NVARCHAR( 16),  
   @cOption       NVARCHAR( 1), 
   @cPrefUOM      NVARCHAR( 1), 
   @cTempQty      NVARCHAR( 5), 
   @cCartonNo     NVARCHAR( 20), 
   @cLabelNo      NVARCHAR( 20), 
   @cTempSKU      NVARCHAR( 20),   
   @cShipmentID         NVARCHAR( 20),
   @cReceiptStatus      NVARCHAR( 10),
   @cReceiptFacility    NVARCHAR( 5),   
   @cReceiptLineNumber  NVARCHAR( 5), 
   @cDocType            NVARCHAR( 1), 
   
   @nQty                   INT, 
   @nExpQTY                INT, 
   @nSUM_B4ReceivedQty     INT, 
   @nSUM_QtyExpected       INT, 
   @nTranCount             INT, 
   @nSKUCnt                INT, 
   @nSum_QtyExp            INT, 
   @nCheckExp              INT, 
   @nCheckB4Rcv            INT, 
   @nReceiptKey_Cnt        INT, 
   @nDefaultReceivingQty   INT, 

   @c_RCPTLOGITF           NVARCHAR( 1),
   @n_err                  INT,  
   @c_errmsg               NVARCHAR( 250),  

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
   @nFunc       = Func,    
   @nScn        = Scn,    
   @nStep       = Step,    
   @nInputKey   = InputKey,    
   @nMenu       = Menu,    
   @cLangCode   = Lang_code,    
    
   @cStorerKey  = StorerKey,    
   @cFacility   = Facility,    
   @cUserName   = UserName,    
   @cPrinter    = Printer,    

   @cReceiptKey = V_ReceiptKey,  
   @cPOKey      = V_POKey,  
   @cToLOC      = V_Loc,  
   @cSKU        = V_SKU,  
   @cUOM        = V_UOM,  
   @cID         = V_ID,  
   @cSKUDesc    = V_SKUDescr,     

   @cLottable01 = V_Lottable01, 
   @cLottable02 = V_Lottable02, 
   @cLottable03 = V_Lottable03, 
   @cLottable04 = V_Lottable04, 
   @cLottable05 = V_Lottable05, 
    
   @cShipmentID      = V_String1, 
   @cExtendedInfoSP  = V_String2,    
   @cCartonNo        = V_String3,    
   
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
    
FROM RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc = 589    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 589    
   IF @nStep = 1 GOTO Step_1   -- Scn = 3540. Shipment ID    
   IF @nStep = 2 GOTO Step_2   -- Scn = 3541. Carton No, To Loc    
   IF @nStep = 3 GOTO Step_3   -- Scn = 3542. SKU   
   IF @nStep = 4 GOTO Step_4   -- Scn = 3543. Qty   
   IF @nStep = 5 GOTO Step_5   -- Scn = 3544. Option   
   IF @nStep = 6 GOTO Step_6   -- Scn = 3545. Option   
   IF @nStep = 7 GOTO Step_7   -- Scn = 3546. Confirm Receive   
   
END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Called from menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Set the entry point    
   SET @nScn = 3540    
   SET @nStep = 1    

   SELECT @cPrefUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA  
   FROM RDT.rdtMobRec M WITH (NOLOCK)  
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)  
   WHERE M.Mobile = @nMobile  

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = '' 
      
   -- Logging    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign in function    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep   
    
   -- Prep next screen var    
   SET @cShipmentID = ''    
   SET @cOutField01 = ''  -- ShipmentID    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Screen = 3540    
   ShipmentID   (Field01, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cShipmentID = @cInField01      
    
      -- Check blank    
      IF ISNULL(@cShipmentID, '') = ''
      BEGIN  
         SET @nErrNo = 80401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ship ID req'  
         GOTO Step_1_Fail  
      END  

      SET @cReceiptStatus = ''
      SET @cReceiptFacility = ''
      
      -- Check valid    
      SELECT @cReceiptStatus = ASNStatus, 
             @cReceiptFacility = Facility
      FROM dbo.Receipt WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   UserDefine02 = @cShipmentID
      AND   ASNStatus <> '9'
      
      IF @@ROWCOUNT = 0
      BEGIN    
         SET @nErrNo = 80402    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ASN Not Found    
         GOTO Step_1_Fail    
      END
      /*
      IF ISNULL(@cReceiptStatus, '') = '9'
      BEGIN    
         SET @nErrNo = 80403    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ASN is closed    
         GOTO Step_1_Fail    
      END    
      */
      -- Validate ASN in different facility  
      IF @cFacility <> @cReceiptFacility  
      BEGIN  
         SET @nErrNo = 80404    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Wrong Facility    
         GOTO Step_1_Fail    
      END  
      
      -- Get default to loc
      SET @cToLOC = ''
      SET @cToLOC = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
      SET @cToLOC = CASE WHEN ISNULL(@cToLOC, '') IN ('0', '') THEN '' ELSE @cToLOC END
      
      -- Prep next screen var    
      SET @cOutField01 = @cShipmentID    
      SET @cOutField02 = ''            -- Carton No
      SET @cOutField03 = @cToLOC       -- To Loc
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Logging    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign Out function    
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep    
    
      -- Back to menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
      SET @cOutField01 = '' -- Clean up for menu option    

      -- Reset any carton no scanned
      UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET 
         V_String3 = ''
      WHERE Mobile = @nMobile
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cShipmentID = ''    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 2. Screen 3541    
   ShipmentID        (Field01)    
   Carton No         (Field02, input)    
   To Location       (Field03, input)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cShipmentID = @cOutField01    
      SET @cCartonNo = @cInField02    
      SET @cToLOC = @cInField03    

      -- Check blank    
      IF ISNULL(@cCartonNo, '') = ''    
      BEGIN    
         SET @nErrNo = 80405    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Carton Is req    
         GOTO Step_2_Fail    
      END    

      -- Prevent 2 user scanning same carton no
      IF EXISTS (SELECT 1 FROM rdt.rdtMobRec WITH (NOLOCK) 
                 WHERE Func = @nFunc
                 AND   UserName <> @cUserName
                 AND   V_String3 = @cCartonNo
                 AND   Step > 0)
      BEGIN    
         SET @nErrNo = 80426    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Double Scan    
         GOTO Step_2_Fail    
      END    

      IF LEN( RTRIM( @cCartonNo)) >= 16
         SET @cCartonNo = SUBSTRING(@cCartonNo, 1, 15)
      
      -- Check blank    
      IF ISNULL(@cToLOC, '') = ''    
      BEGIN    
         SET @nErrNo = 80406    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC is req    
         GOTO Step_2_Fail    
      END    

      -- Check invalid LOC
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC)
      BEGIN
         SET @nErrNo = 80421    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
         GOTO Step_2_Fail
      END
      
       -- Check different facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cToLOC
            AND FACILITY = @cFacility)
      BEGIN
         SET @nErrNo = 80422
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff facility'
         GOTO Step_2_Fail
      END  

      -- If find more than 1 ASN has not closed, prompt error 
      SET @nReceiptKey_Cnt = 0
      SELECT @nReceiptKey_Cnt = COUNT( DISTINCT R.ReceiptKey) 
      FROM dbo.Receipt R WITH (NOLOCK) 
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
      AND   R.UserDefine02 = @cShipmentID
      AND   R.ASNStatus <> '9'
      AND   RD.UserDefine01 = @cCartonNo
      
      IF ISNULL(@nReceiptKey_Cnt, 0) > 1
      BEGIN
         SET @nErrNo = 80423
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DUP OPEN ASN'
         GOTO Step_2_Fail
      END 

      -- Could have > 1 ASN with shipmentid+cartonno
      -- but at any one time only can have 1 open ASN
      -- so select those ASN which still open
      SET @cReceiptKey = ''
      SET @cReceiptStatus = ''
      SET @cDocType = ''
      SELECT @cReceiptKey = R.ReceiptKey, 
             @cReceiptStatus = R.Status, 
             @cDocType = R.DocType   
      FROM dbo.Receipt R WITH (NOLOCK) 
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
      WHERE R.StorerKey = @cStorerKey
      AND   R.UserDefine02 = @cShipmentID
      AND   RD.UserDefine01 = @cCartonNo
      AND   R.ASNStatus <> '9'

      IF ISNULL(@cReceiptKey, '') = ''    
      BEGIN    
         SET @nErrNo = 80407    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Not Found     
         GOTO Step_2_Fail    
      END    

      IF ISNULL(@cReceiptStatus, '') = '9'
      BEGIN    
         SET @nErrNo = 80408    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ASN is closed    
         GOTO Step_2_Fail    
      END    

      -- Check if carton is already finalized then prompt error
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   ReceiptKey = @cReceiptKey
                     AND   Userdefine01 = @cCartonNo
                     AND   FinalizeFlag = 'N')
      BEGIN
         SET @nErrNo = 80427
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Carton Closed'
         GOTO Step_2_Fail
      END
      
      IF EXISTS (SELECT 1 FROM dbo.Receipt WITH (NOLOCK) 
                 WHERE StorerKey = @cStorerKey
                 AND   UserDefine02 = @cShipmentID
                 AND   ReceiptKey = @cReceiptKey
                 AND   ASNStatus = '0')
      BEGIN
         SET @nTranCount = @@TRANCOUNT

         BEGIN TRAN
         SAVE TRAN UPD_RCPT
      
         UPDATE dbo.Receipt WITH (ROWLOCK) SET 
            ASNSTATUS = 'StartREC', 
            Userdefine07 = GETDATE() 
         WHERE ReceiptKey = @cReceiptKey
         AND   StorerKey = @cStorerKey
         AND   UserDefine02 = @cShipmentID
         AND   ASNStatus = '0'      -- only upd when asnstatus = '0' (open)
         
         IF @@ERROR <> 0
         BEGIN    
            ROLLBACK TRAN UPD_RCPT
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN
            
            SET @nErrNo = 80409    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ASN Fail     
            GOTO Step_2_Fail    
         END 

         -- Insert transmitlog3 here
         SELECT @c_RCPTLOGITF = 0, @b_success = 0    

         EXECUTE nspGetRight 
               NULL,     -- facility    
               @cstorerkey,           -- Storerkey    
               NULL,                  -- Sku    
               'RCPTSTRLOG',          -- Configkey    
               @b_success output,    
               @c_RCPTLOGITF output,    
               @n_err output,    
               @c_errmsg output    

         IF @b_success <> 1    
         BEGIN    
            SET @nErrNo = 80424    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getright fail     
            GOTO Step_2_Fail    
         END    
         ELSE IF @c_RCPTLOGITF = '1'    
         BEGIN    
            SELECT @b_success = 1                                                                 
            EXEC ispGenTransmitLog3 'RCPTSTRLOG', @cReceiptKey, @cDocType, @cStorerkey, '' -- Added in DocType to determine Return/Normal Receipt    
            , @b_success OUTPUT    
            , @n_err OUTPUT    
            , @c_errmsg OUTPUT    
        
            IF @b_success <> 1    
            BEGIN    
               SET @nErrNo = 80425    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TR3 Fail     
               GOTO Step_2_Fail    
            END    
         END
         
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
      END
      
      SET @nSKUCnt = 0
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   Userdefine01 = @cCartonNo
      AND   FinalizeFlag <> 'Y'
      
      SET @cSKU = ''
      
      -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
      IF @nSKUCnt = 1
      BEGIN
         SET @cSKU = ''
         SET @nSum_QtyExp = 0
         
         SELECT @cSKU = SKU, 
                @nSum_QtyExp = ISNULL(SUM( QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
         GROUP BY SKU

         IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
         BEGIN
            EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSum_QtyExp OUTPUT
         END
            
         -- Prepare next screen var    
         SET @cOutField01 = @cShipmentID
         SET @cOutField02 = @cCartonNo
         SET @cOutField03 = @cReceiptKey
         SET @cOutField04 = @cSKU            -- SKU
         SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
         SET @cOutField06 = @nSum_QtyExp
         
         -- Go to Qty screen directly
         SET @nScn  = @nScn + 2    
         SET @nStep = @nStep + 2    
         
         GOTO Quit
      END

      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
      
      -- Go to next screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare prev screen var    
      SET @cOutField01 = ''    
      
      SET @cShipmentID = ''    
 
      -- Go to prev screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_2_Fail:    
   BEGIN
      -- Get default to loc
      SET @cToLOC = ''
      SET @cToLOC = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
      SET @cToLOC = CASE WHEN ISNULL(@cToLOC, '') IN ('0', '') THEN '' ELSE @cToLOC END

      SET @cOutField01 = @cShipmentID    
      SET @cOutField02 = ''         -- Carton No
      SET @cOutField03 = @cToLOC    -- ToLOC  
      
      SET @cCartonNo = ''    
   END
END    
GOTO Quit    

/********************************************************************************    
Step 3. Screen 3492    
   Shipment ID    (Field01)    
   Carton No      (Field02)    
   ASN            (Field02)    
   SKU            (Field03, input)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cTempSKU = @cInField04
       
      IF ISNULL(@cTempSKU, '') = ''
      BEGIN    
         SET @nErrNo = 80410    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Is req    
         GOTO Step_3_Fail    
      END    

      SET @nSKUCnt = 0
      EXEC [RDT].[rdt_GETSKUCNT]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cTempSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 80411
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cTempSKU      OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT
      
      SET @cSKU = @cTempSKU

      SET @cExtendedInfo = ''
      
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
                
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT'    
            SET @cSQLParam =    
               '@cLoadKey      NVARCHAR( 10), ' +    
               '@cConsigneeKey NVARCHAR( 15), ' +    
               '@cLabelNo      NVARCHAR( 20), ' +    
               '@cStorer       NVARCHAR( 15), ' +      
               '@cSKU          NVARCHAR( 20), ' +      
               '@nExpQTY       INT,       ' +      
               '@cExtendedInfo NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT    
         END    
      END    

      IF NOT EXISTS (SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   SKU = @cSKU)
      BEGIN
         SET @nSKUCnt = 2
      END
      ELSE
      BEGIN
         SET @nSKUCnt = 0
         SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
         
         -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
         IF @nSKUCnt = 1
         BEGIN
            SET @cSKU = ''
            SET @nSum_QtyExp = 0
            
            SELECT @cSKU = SKU, 
                   @nSum_QtyExp = ISNULL(SUM( QtyExpected), 0)
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   ReceiptKey = @cReceiptKey
            AND   Userdefine01 = @cCartonNo
            AND   FinalizeFlag <> 'Y'
            GROUP BY SKU

            IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
            BEGIN
               EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSum_QtyExp OUTPUT
            END
         END
      END

      SET @nDefaultReceivingQty = rdt.RDTGetConfig( @nFunc, 'DefaultReceivingQty', @cStorerKey)
         
      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
      SET @cOutField06 = CASE WHEN @nSKUCnt > 1 THEN CASE WHEN @nDefaultReceivingQty > 0 THEN @nDefaultReceivingQty ELSE '' END
                         ELSE @nSum_QtyExp END     -- Qty
      
      -- Go to next screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1   
   END

   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Get default to loc
      SET @cToLOC = ''
      SET @cToLOC = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey)
      SET @cToLOC = CASE WHEN ISNULL(@cToLOC, '') IN ('0', '') THEN '' ELSE @cToLOC END
      
      -- Prep next screen var    
      SET @cOutField01 = @cShipmentID    
      SET @cOutField02 = ''            -- Carton No
      SET @cOutField03 = @cToLOC       -- To Loc
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN
      SET @nSKUCnt = 0
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   Userdefine01 = @cCartonNo
      AND   FinalizeFlag <> 'Y'
      
      SET @cSKU = ''
      
      -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
      IF @nSKUCnt = 1
      BEGIN
         SELECT @cSKU = SKU 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
      END

      SET @cExtendedInfo = ''
      
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
                
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT'    
            SET @cSQLParam =    
               '@cLoadKey      NVARCHAR( 10), ' +    
               '@cConsigneeKey NVARCHAR( 15), ' +    
               '@cLabelNo      NVARCHAR( 20), ' +    
               '@cStorer       NVARCHAR( 15), ' +      
               '@cSKU          NVARCHAR( 20), ' +      
               '@nExpQTY       INT,       ' +      
               '@cExtendedInfo NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT    
         END    
      END    
   
      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
   END
END
GOTO Quit

/********************************************************************************    
Step 4. Screen 3493    
   Shipment ID    (Field01)    
   Carton No      (Field02)    
   ASN            (Field03)    
   SKU            (Field04)    
   Qty            (Field05, input)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cTempQty = @cInField06
       
      IF ISNULL(@cTempQty, '') = '' SET @cTempQty = '0' -- Blank taken as zero
      IF RDT.rdtIsValidQTY( @cTempQty, 0) = 0           -- Allow zero qty 
      BEGIN
         SET @nErrNo = 80412
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid QTY'
         GOTO Step_4_Fail
      END

      -- Check if carton is already finalized then prompt error
      IF NOT EXISTS (SELECT 1 
                     FROM dbo.ReceiptDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   ReceiptKey = @cReceiptKey
                     AND   Userdefine01 = @cCartonNo
                     AND   FinalizeFlag = 'N')
      BEGIN
         SET @nErrNo = 80428
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Carton Closed'
         GOTO Step_4_Fail
      END
                     
                     
      SET @nQty = CAST( @cTempQty AS INT)
      
      -- Put zero direct goto next screen
      -- Because sometimes user might press wrongly (New SKU option) 
      -- and accidentally come back this screen
      IF @nQty > 0
      BEGIN
         EXEC ispInditexConvertQTY 'ToBaseQTY', @cStorerkey, @cSKU, @nQty OUTPUT
         
         -- Confirm receive
         EXEC rdt.rdt_ReceiveByShipmentID_Confirm
               @nFunc          = @nFunc
              ,@nMobile        = @nMobile
              ,@cLangCode      = @cLangCode
              ,@cFacility      = @cFacility
              ,@cReceiptKey    = @cReceiptKey
              ,@cStorerKey     = @cStorerKey
              ,@cSKU           = @cSKU
              ,@cExternPOKey   = ''
              ,@cToLoc         = @cToLoc
              ,@cToID          = ''
              ,@cCartonId      = @cCartonNo 
              ,@nQtyReceived   = @nQty
              ,@cConditionCode = ''
              ,@nErrNo         = @nErrNo OUTPUT
              ,@cErrMsg        = @cErrMsg OUTPUT

         IF @nErrno <> 0
         BEGIN
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') 
             GOTO Step_4_Fail
         END
      END
      
      -- Check if SKU has stock on hand already
      SELECT TOP 1 @cLOC = LLi.LOC 
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
--      JOIN dbo.CodeLkUp CLK WITH (NOLOCK) 
--         ON (LOC.HostWHCode = CLK.Code AND LLI.StorerKey = CLK.StorerKey AND CLK.UDF01 = @nFunc)
      WHERE LOC.Facility = @cFacility
      AND   LOC.HostWHCode = 'ITX-AVA'
      AND   LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cSKU
      AND   (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
--      AND   CLK.ListName = 'HostWHCode'

      -- No stock then display as 'NEW'
      IF ISNULL(@cLOC, '') = ''
         SET @cLOC = 'NEW'

      -- If sku already in inventory then show the loc with the lest stock
      -- Not filter by the sku itself
      IF ISNULL(@cLOC, '') <> ''
      BEGIN
         SELECT TOP 1 @cLOC = LLI.LOC 
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
         WHERE LLI.StorerKey = @cStorerKey
         AND   EXISTS (SELECT 1 FROM dbo.LOTxLOCxID LLI2 WITH (NOLOCK) 
                       JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI2.LOC = LOC.LOC)
--                       JOIN dbo.CodeLkUp CLK WITH (NOLOCK) 
--                          ON (LOC.HostWHCode = CLK.Code AND LLI.StorerKey = CLK.StorerKey AND CLK.UDF01 = @nFunc)
                       WHERE LLI.LOC = LOC.LOC
                       AND   LOC.Facility = @cFacility
                       AND   LOC.HostWHCode = 'ITX-AVA'
                       AND   LLI2.StorerKey = @cStorerKey
                       AND   LLI2.SKU = @cSKU)
                       --      AND   CLK.ListName = 'HostWHCode')
         GROUP BY LLI.LOC
         ORDER BY SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
      END
      
      SET @cOutField01 = @cLOC
      SET @cOutField02 = ''
      
      -- Go to next screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1   
   END

   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @nSKUCnt = 0
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   Userdefine01 = @cCartonNo
      AND   FinalizeFlag <> 'Y'
      
      SET @cSKU = ''
      
      -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
      IF @nSKUCnt = 1
      BEGIN
         SELECT @cSKU = SKU  
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
      END

      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
 
      -- Go to prev screen    
      SET @nScn  = @nScn - 1    
      SET @nStep = @nStep - 1    
   END    
   GOTO Quit    
    
   Step_4_Fail:    
   BEGIN
      SET @nSKUCnt = 0
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   Userdefine01 = @cCartonNo
      AND   FinalizeFlag <> 'Y'
      
      -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
      IF @nSKUCnt = 1
      BEGIN
         SET @cSKU = ''
         SET @nSum_QtyExp = 0
         
         SELECT @cSKU = SKU, 
                @nSum_QtyExp = ISNULL(SUM( QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
         GROUP BY SKU

         IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
         BEGIN
            EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSum_QtyExp OUTPUT
         END
      END

      SET @cExtendedInfo = ''
      
      -- Extended info    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cExtendedInfo = ''    
                
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +     
               ' @cLoadKey, @cConsigneeKey, @cLabelNo, @cStorer, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT'    
            SET @cSQLParam =    
               '@cLoadKey      NVARCHAR( 10), ' +    
               '@cConsigneeKey NVARCHAR( 15), ' +    
               '@cLabelNo      NVARCHAR( 20), ' +    
               '@cStorer       NVARCHAR( 15), ' +      
               '@cSKU          NVARCHAR( 20), ' +      
               '@nExpQTY       INT,       ' +      
               '@cExtendedInfo NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @cLoadKey, @cConsigneeKey, @cLabelNo, @cStorerKey, @cSKU, @nExpQTY, @cExtendedInfo OUTPUT    
         END    
      END    

      SET @nDefaultReceivingQty = rdt.RDTGetConfig( @nFunc, 'DefaultReceivingQty', @cStorerKey)
      
      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
      SET @cOutField06 = CASE WHEN @nSKUCnt > 1 THEN CASE WHEN @nDefaultReceivingQty > 0 THEN @nDefaultReceivingQty ELSE '' END 
                         ELSE @nSum_QtyExp END     -- Qty
   END
END
GOTO Quit

/********************************************************************************    
Step 5. Screen 3544    
   To LOC           (Field01)    
   Option           (Field01, Input)    
********************************************************************************/    
Step_5:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField02
    
      IF ISNULL(@cOption, '') = '' 
      BEGIN
         SET @nErrNo = 80413    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req 
         GOTO Step_5_Fail    
      END 

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 80414    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option    
         GOTO Step_5_Fail    
      END 

      IF @cOption = '1'
      BEGIN
         SET @nSKUCnt = 0
         SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
         
         SET @cSKU = ''
         
         -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
         IF @nSKUCnt = 1
         BEGIN
            SELECT @cSKU = SKU  
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   ReceiptKey = @cReceiptKey
            AND   Userdefine01 = @cCartonNo
            AND   FinalizeFlag <> 'Y'
         END

         -- Prepare next screen var    
         SET @cOutField01 = @cShipmentID
         SET @cOutField02 = @cCartonNo
         SET @cOutField03 = @cReceiptKey
         SET @cOutField04 = @cSKU            -- SKU
         SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
         
         -- Go to SKU screen    
         SET @nScn  = @nScn - 2    
         SET @nStep = @nStep - 2    
      END
      
      IF @cOption = '2'
      BEGIN
         GOTO Step_5_ESC
      END
   END

   IF @nInputKey = 0 -- ESC    
   BEGIN    
      Step_5_ESC:
      -- Check if carton in this receipt detail already audited
      -- then goto screen 6 directly
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Receipt R WITH (NOLOCK) 
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) 
         WHERE R.StorerKey = @cStorerKey
         AND   R.ReceiptKey = @cReceiptKey
         AND   R.UserDefine02 = @cShipmentID
         AND   RD.UserDefine01 = @cCartonNo
         AND   RD.Status = '0'
         AND   RD.FinalizeFlag <> 'Y')
      BEGIN
--         IF NOT EXISTS (SELECT 1 
--            FROM dbo.Receipt R WITH (NOLOCK) 
--            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) 
--            WHERE R.StorerKey = @cStorerKey
--            AND   R.ReceiptKey = @cReceiptKey
--            AND   R.UserDefine02 = @cShipmentID
--            AND   RD.UserDefine01 = @cCartonNo
--            AND   RD.FinalizeFlag <> 'Y'
--            HAVING ISNULL( SUM( QtyExpected), 0) <> ISNULL( SUM( BeforeReceivedQty), 0))
--         BEGIN
            IF rdt.RDTGetConfig( @nFunc, 'RCPTAutoFinalizeByCarton', @cStorerKey) = '1'
            BEGIN
               -- Preset the screen & step here
               -- assume we are at screen 7
               SET @nScn  = @nScn + 2    
               SET @nStep = @nStep + 2    

               GOTO FINALIZE_CARTON
            END

            -- Prepare next screen var    
            SET @cOutField01 = @cCartonNo
            SET @cOutField02 = ''
            
            -- Go to confirm receive carton screen    
            SET @nScn  = @nScn + 2    
            SET @nStep = @nStep + 2    
            
            GOTO Quit
--         END
      END
      
      SELECT @cSKU = RD.SKU, 
             @nSUM_B4ReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0), 
             @nSUM_QtyExpected = ISNULL( SUM( QtyExpected), 0) 
      FROM dbo.Receipt R WITH (NOLOCK) 
      JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) 
      WHERE R.StorerKey = @cStorerKey
      AND   R.ReceiptKey = @cReceiptKey
      AND   R.UserDefine02 = @cShipmentID
      AND   RD.UserDefine01 = @cCartonNo
      AND   RD.Status <> '1'
      AND   RD.FinalizeFlag <> 'Y'
      GROUP BY RD.SKU 
      ORDER BY RD.SKU 

      IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
      BEGIN
         EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSUM_B4ReceivedQty OUTPUT
      END
      
      IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
      BEGIN
         EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSUM_QtyExpected OUTPUT
      END
         
      -- Prepare next screen var    
      SET @cOutField01 = @cCartonNo
      SET @cOutField02 = @cSKU
      SET @cOutField03 = @nSUM_B4ReceivedQty
      SET @cOutField04 = @nSUM_QtyExpected
      SET @cOutField05 = ''

      -- Go to next screen    
      SET @nScn  = @nScn + 1    
      SET @nStep = @nStep + 1    
   END    
   GOTO Quit    
    
   Step_5_Fail:    
   BEGIN
      SET @cOption = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************    
Step 6. Screen 3545    
   CARTON NO      (Field01)    
   SKU            (Field02)    
   SCA QTY        (Field03)
   EXP QTY        (Field04)
   OPTION         (Field05, input)
********************************************************************************/    
Step_6:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cSKU = @cOutField02  
      SET @cOption = @cInField05  
      
      IF ISNULL(@cOption, '') = '' 
      BEGIN
         SET @nErrNo = 80413    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req 
         GOTO Step_6_Fail    
      END 

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 80414    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option    
         GOTO Step_6_Fail    
      END 

      IF @cOption = '1'
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         
         BEGIN TRAN
         SAVE TRAN UPD_RCPT
      
         UPDATE RD WITH (ROWLOCK) SET 
            STATUS = '1'
         FROM dbo.Receipt R 
         JOIN dbo.ReceiptDetail RD ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.ReceiptKey = @cReceiptKey
         AND   R.StorerKey = @cStorerKey
         AND   R.UserDefine02 = @cShipmentID
         AND   RD.FinalizeFlag <> 'Y'
         AND   RD.Status <> '1'      
         AND   RD.UserDefine01 = @cCartonNo
         AND   RD.SKU = @cSKU
         
         IF @@ERROR <> 0
         BEGIN    
            ROLLBACK TRAN UPD_RCPT
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN
            
            SET @nErrNo = 80417    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ASN Fail     
            GOTO Step_6_Fail    
         END 

         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

            -- Check if carton in this receipt detail has no more discrepancy and all audited
            -- then goto screen 6 directly
         IF NOT EXISTS (SELECT 1 
            FROM dbo.Receipt R WITH (NOLOCK) 
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) 
            WHERE R.StorerKey = @cStorerKey
            AND   R.ReceiptKey = @cReceiptKey
            AND   R.UserDefine02 = @cShipmentID
            AND   RD.UserDefine01 = @cCartonNo
            AND   RD.Status = '0'
            AND   RD.FinalizeFlag = 'N')
         BEGIN
         
            IF rdt.RDTGetConfig( @nFunc, 'RCPTAutoFinalizeByCarton', @cStorerKey) = '1'
            BEGIN
               -- Preset the screen & step here
               -- assume we are at screen 7
               SET @nScn  = @nScn + 1    
               SET @nStep = @nStep + 1    
               
               GOTO FINALIZE_CARTON
            END
            
            -- Prepare next screen var    
            SET @cOutField01 = @cCartonNo
            SET @cOutField02 = ''
            
            -- Go to confirm receive carton screen    
            SET @nScn  = @nScn + 1    
            SET @nStep = @nStep + 1    
            
            GOTO Quit
         END
      
         SELECT @cSKU = RD.SKU, 
                @nSUM_B4ReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0), 
                @nSUM_QtyExpected = ISNULL( SUM( QtyExpected), 0) 
         FROM dbo.Receipt R WITH (NOLOCK) 
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) 
         WHERE R.StorerKey = @cStorerKey
         AND   R.ReceiptKey = @cReceiptKey
         AND   R.UserDefine02 = @cShipmentID
         AND   RD.UserDefine01 = @cCartonNo
         AND   RD.Status <> '1'
         AND   RD.FinalizeFlag <> 'Y'
         GROUP BY RD.SKU 
         ORDER BY RD.SKU 

         IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
         BEGIN
            EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSUM_B4ReceivedQty OUTPUT
         END

         IF ISNULL(rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorerKey), '') <> ''
         BEGIN
            EXEC ispInditexConvertQTY 'ToDispQTY', @cStorerkey, @cSKU, @nSUM_QtyExpected OUTPUT
         END
            
         -- Prepare next screen var    
         SET @cOutField01 = @cCartonNo
         SET @cOutField02 = @cSKU
         SET @cOutField03 = @nSUM_B4ReceivedQty
         SET @cOutField04 = @nSUM_QtyExpected
         SET @cOutField05 = ''
      END
      
      IF @cOption = '2'
      BEGIN
         GOTO Step_6_ESC  
      END
   END
   
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      Step_6_ESC:
      SET @nSKUCnt = 0
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   Userdefine01 = @cCartonNo
      AND   FinalizeFlag <> 'Y'
      
      SET @cSKU = ''
      
      -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
      IF @nSKUCnt = 1
      BEGIN
         SELECT @cSKU = SKU  
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
      END

      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END
      
      -- Go to next screen    
      SET @nScn  = @nScn - 3    
      SET @nStep = @nStep - 3    
   END
   GOTO Quit
   
   Step_6_Fail:    
   BEGIN
      SET @cOption = ''
      SET @cOutField05 = ''
   END
END
GOTO Quit

/********************************************************************************    
Step 7. Screen 3496    
   Confirm       (Field01)    
   OPT           (Field02, input)    
********************************************************************************/    
Step_7:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cOption = @cInField02  
      
      IF ISNULL(@cOption, '') = '' 
      BEGIN
         SET @nErrNo = 80418    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Option req 
         GOTO Step_7_Fail    
      END 

      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 80419    
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Invalid Option    
         GOTO Step_7_Fail    
      END 

      IF @cOption = '1'
      BEGIN
         FINALIZE_CARTON:
         SET @nTranCount = @@TRANCOUNT
         
         BEGIN TRAN
         SAVE TRAN UPD_RCPT
         
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT ReceiptLineNumber 
         FROM dbo.Receipt R WITH (NOLOCK) 
         JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
         WHERE R.StorerKey = @cStorerKey 
         AND   R.ReceiptKey = @cReceiptKey
         AND   R.UserDefine02 = @cShipmentID
         AND   RD.UserDefine01 = @cCartonNo
         AND   RD.Status = '1'            -- Audited
         AND   RD.FinalizeFlag <> 'Y'     -- not finalize
         
         OPEN CUR_LOOP
         FETCH NEXT FROM CUR_LOOP INTO @cReceiptLineNumber
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
               QtyReceived = BeforeReceivedQty, 
               FinalizeFlag = 'Y'
            WHERE ReceiptKey = @cReceiptKey
            AND   ReceiptLineNumber = @cReceiptLineNumber

            IF @@ERROR <> 0
            BEGIN    
               ROLLBACK TRAN UPD_RCPT
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN
               
               SET @nErrNo = 80420    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Rcpt Ctn Fail   
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Step_7_Fail    
            END 
         
            FETCH NEXT FROM CUR_LOOP INTO @cReceiptLineNumber
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
         
         WHILE @@TRANCOUNT > @nTranCount  
            COMMIT TRAN

         -- Prep next screen var    
         SET @cShipmentID = ''    
         SET @cOutField01 = ''  -- ShipmentID   

         -- Go to screen 1
         SET @nScn  = @nScn - 6    
         SET @nStep = @nStep - 6  
         
         GOTO Quit
      END
      
      IF @cOption = '2'
      BEGIN
         GOTO Step_7_ESC
      END
   END
   
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      Step_7_ESC:
      
      SET @nSKUCnt = 0
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM dbo.ReceiptDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   Userdefine01 = @cCartonNo
      AND   FinalizeFlag <> 'Y'
      
      SET @cSKU = ''
      
      -- If only 1 SKU in a carton then default the sku and qty (sum(expectedqty))
      IF @nSKUCnt = 1
      BEGIN
         SELECT @cSKU = SKU  
         FROM dbo.ReceiptDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   Userdefine01 = @cCartonNo
         AND   FinalizeFlag <> 'Y'
      END

      -- Prepare next screen var    
      SET @cOutField01 = @cShipmentID
      SET @cOutField02 = @cCartonNo
      SET @cOutField03 = @cReceiptKey
      SET @cOutField04 = @cSKU            -- SKU
      SET @cOutField05 = CASE WHEN ISNULL( @cExtendedInfo, '') <> '' THEN @cExtendedInfo ELSE '' END

      -- Go to next screen  
      SET @nScn  = @nScn - 4    
      SET @nStep = @nStep - 4   
   END
   GOTO Quit    
    
   Step_7_Fail:    
   BEGIN
      SET @cOption = ''
      SET @cOutField02 = ''
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
      Func   = @nFunc,    
      Step   = @nStep,    
      Scn    = @nScn,    
    
      StorerKey  = @cStorerKey,    
      Facility   = @cFacility,    
      -- UserName   = @cUserName,    
      Printer    = @cPrinter,    
    
      V_ReceiptKey = @cReceiptKey,  
      V_POKey      = @cPOKey,  
      V_Loc        = @cToLOC,  
      V_SKU        = @cSKU,  
      V_UOM        = @cUOM,  
      V_ID         = @cID,  
      V_SKUDescr   = @cSKUDesc,   
      
      V_Lottable01 = @cLottable01, 
      V_Lottable02 = @cLottable02, 
      V_Lottable03 = @cLottable03, 
      V_Lottable04 = @cLottable04, 
      V_Lottable05 = @cLottable05, 
  
      V_String1    = @cShipmentID, 
      V_String2    = @cExtendedInfoSP, 
      V_String3    = @cCartonNo,    

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