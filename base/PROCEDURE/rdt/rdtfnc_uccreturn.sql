SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Store procedure: rdtfnc_UCCReturn                                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: UCC Return                                                  */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2006-02-13 1.0  jwong      Created                                   */  
/* 2012-02-25 1.1  ChewKP     Bug Fixes (ChewKP01)                      */  
/* 2016-09-30 1.2  Ung        Performance tuning                        */    
/* 2018-10-26 1.3  Gan        Performance tuning                        */
/* 2024-10-08 1.4  JCH507     UWP-25454 Data convertion error at st6    */   
/* 2024-10-22 1.5  CYU027     FCR-759 Ucc & ID Length                   */
/************************************************************************/
CREATE PROC [RDT].[rdtfnc_UCCReturn] (  
@nMobile    int,  
@nErrNo     int  OUTPUT,  
@cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max  
)  
AS  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF     
   SET QUOTED_IDENTIFIER OFF  
  SET CONCAT_NULL_YIELDS_NULL OFF  
-- Define a variable  
DECLARE @nFunc     int,  
      @nScn        int,  
      @nStep       int,  
      @cLangCode   NVARCHAR(3),  
      @nMenu       int,  
      @nInputKey   NVARCHAR( 3),
      @cInField01  NVARCHAR(60),      @cInField02  NVARCHAR(60),
      @cInField03  NVARCHAR(60),      @cInField04  NVARCHAR(60),  
      @cInField05  NVARCHAR(60),      @cInField06  NVARCHAR(60),  
      @cInField07  NVARCHAR(60),      @cInField08  NVARCHAR(60),  
      @cInField09  NVARCHAR(60),      @cInField10  NVARCHAR(60),  
      @cInField011  NVARCHAR(60),     @cInField12  NVARCHAR(60),  
      @cInField013  NVARCHAR(60),     @cInField14  NVARCHAR(60),  
      @cInField015  NVARCHAR(60),       
      @cOutField01  NVARCHAR(60),      @cOutField02  NVARCHAR(60),     
      @cOutField03  NVARCHAR(60),      @cOutField04  NVARCHAR(60),     
      @cOutField05  NVARCHAR(60),      @cOutField06  NVARCHAR(60),     
      @cOutField07  NVARCHAR(60),      @cOutField08  NVARCHAR(60),     
      @cOutField09  NVARCHAR(60),      @cOutField10  NVARCHAR(60),     
      @cOutField11  NVARCHAR(60),      @cOutField12  NVARCHAR(60),     
      @cOutField13  NVARCHAR(60),      @cOutField14  NVARCHAR(60),     
      @cOutField15  NVARCHAR(60),     
      @b_success                       int,
      @n_err                           int,
      @c_errmsg                        NVARCHAR(215),
      @cWHRef                          NVARCHAR(18),
      @nAddNewUCCReturn                int,
      @cStorerKey                      NVARCHAR(15),
      @cFacility                       NVARCHAR(5),
      @nRowCount                       int,
      @cMUID                           NVARCHAR(18),
      @nDisAllowDuplicateIDsOnRFRcpt   int,
      @cUCCKey                         NVARCHAR(20),
      @cSKU                            NVARCHAR(20),
      @cDescr                          NVARCHAR(30),
      @cUOM                            NVARCHAR(10),
      @cPPK                            NVARCHAR(30),
      @cQTY                            NVARCHAR(5),
      @cLottable02                     NVARCHAR(10),
      @cToLoc                          NVARCHAR(10),
      @nRCDetByUCC                     int,
      @cPackKey                        NVARCHAR(10),
      @cReceiptKey                     NVARCHAR(10),
      @cReceiptLineNumber              NVARCHAR(5),
      @cNextReceiptLineNumber          NVARCHAR(5),
      @cCartonCnt                      NVARCHAR(2),
      @cTotalCartonCnt                 NVARCHAR(5),
      @cTotalPalletCnt                 NVARCHAR(5),
      @nCnt                            int,
      @cMaxCnt                         NVARCHAR(1),
      @cConfirm                        NVARCHAR(1),
      @cDocType                        NVARCHAR(10),
      @cASNStatus                      NVARCHAR(10),
      @cStatus                         NVARCHAR(10),
      @cUCCStatus                      NVARCHAR(10),
      @nCaseCntQty                     int,
      @nLocCount                       int,
      @nExpectedQty                    int,
      @nBeforeReceivedQty              int,
      @cExternKey                      NVARCHAR(20),
      @cTempToID                       NVARCHAR(18),
      @cTempToLoc                      NVARCHAR(10),
      @cTariffkey                      NVARCHAR(10),
      @cXML                            NVARCHAR(4000), -- To allow double byte data for e.g. SKU desc
      @cDecodeSP                       NVARCHAR( 20),
      @cSQL                            NVARCHAR(MAX),
      @cSQLParam                       NVARCHAR(MAX),
      @cIDBarcode                      NVARCHAR(100),
      @cUserDefine08                   NVARCHAR( 30),
      @cUserDefine09                   NVARCHAR( 30),
      @cNotFinalizeRD                  NVARCHAR(1),
      @cFinalizeLineNumber             NVARCHAR(5)


-- Getting Mobile information  
SELECT @nFunc        = Func,
      @nScn          = Scn,
      @nStep         = Step,
      @nInputKey     = InputKey,
      @cLangCode     = Lang_code,
      @nMenu         = Menu,
      @cFacility     = Facility,
      @cStorerKey    = StorerKey,
      @cDecodeSP     = V_String1,
      @cUserDefine08 = V_String2,
      @cUserDefine09 = V_String3,
        
      @cInField01 = I_Field01,      @cInField02 = I_Field02,  
      @cInField03 = I_Field03,      @cInField04 = I_Field04,  
      @cInField05 = I_Field05,      @cInField06 = I_Field06,  
      @cInField07 = I_Field07,      @cInField08 = I_Field08,  
      @cInField09 = I_Field09,      @cInField10 = I_Field10,  
      @cInField011 = I_Field11,     @cInField12 = I_Field12,  
      @cInField013 = I_Field13,     @cInField14 = I_Field14,  
      @cInField015 = I_Field15,  
        
      @cOutField01 = O_Field01,      @cOutField02 = O_Field02,  
      @cOutField03 = O_Field03,      @cOutField04 = O_Field04,  
      @cOutField05 = O_Field05,      @cOutField06 = O_Field06,  
      @cOutField07 = O_Field07,      @cOutField08 = O_Field08,  
      @cOutField09 = O_Field09,      @cOutField10 = O_Field10,  
      @cOutField10 = O_Field10,      @cOutField12 = O_Field12,  
      @cOutField13 = O_Field13,      @cOutField14 = O_Field14,  
      @cOutField15 = O_Field15  
      FROM   RDTMOBREC (NOLOCK)  
      WHERE Mobile = @nMobile

SET @cDecodeSP  = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
IF @cDecodeSP = '0'
   SET @cDecodeSP = ''
  
-- Load session variable  
DECLARE @iDoc INT  
DECLARE @tSessionVar TABLE  
(  
   VarName SYSNAME,   
   Value   NVARCHAR( 60)  
)  
  
SELECT @cXML = XML FROM RDTSessionData WHERE Mobile = @nMobile  
EXEC sp_xml_preparedocument @iDoc OUTPUT, @cXML  
INSERT INTO @tSessionVar  
SELECT VarName, Value  
FROM OPENXML (@idoc, '/Root/Variable', 1) -- attribute centric mapping  
   WITH (VarName SYSNAME,  
         Value   NVARCHAR( 60))  
EXEC sp_xml_removedocument @iDoc  
  
SELECT @cMUID            = Value FROM @tSessionVar WHERE VarName = '@cMUID'  
SELECT @cSKU             = Value FROM @tSessionVar WHERE VarName = '@cSKU'  
SELECT @cDescr           = Value FROM @tSessionVar WHERE VarName = '@cDescr'  
SELECT @cUOM             = Value FROM @tSessionVar WHERE VarName = '@cUOM'  
SELECT @cUCCKey          = Value FROM @tSessionVar WHERE VarName = '@cUCCKey'  
SELECT @cPPK             = Value FROM @tSessionVar WHERE VarName = '@cPPK'  
SELECT @cQTY             = Value FROM @tSessionVar WHERE VarName = '@cQTY'  
SELECT @cToLoc           = Value FROM @tSessionVar WHERE VarName = '@cToLoc'  
SELECT @cReceiptKey      = Value FROM @tSessionVar WHERE VarName = '@cReceiptKey'  
SELECT @cReceiptLineNumber   = Value FROM @tSessionVar WHERE VarName = '@cReceiptLineNumber'  
SELECT @cCartonCnt       = Value FROM @tSessionVar WHERE VarName = '@cCartonCnt'  
SELECT @cTotalCartonCnt  = Value FROM @tSessionVar WHERE VarName = '@cTotalCartonCnt'  
SELECT @cMaxCnt          = Value FROM @tSessionVar WHERE VarName = '@cMaxCnt'  
SELECT @cTotalPalletCnt  = Value FROM @tSessionVar WHERE VarName = '@cTotalPalletCnt'  
SELECT @cPackKey         = Value FROM @tSessionVar WHERE VarName = '@cPackKey'  
SELECT @cExternKey         = Value FROM @tSessionVar WHERE VarName = '@cExternKey'  
SELECT @cTariffkey         = Value FROM @tSessionVar WHERE VarName = '@cTariffkey'  
  
-- Session screen  
DECLARE @tSessionScrn TABLE  
(  
   Typ       NVARCHAR( 10),   
   X         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
   Y         NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
   Length    NVARCHAR( 4),    -- size 4 is needed bcoz of 'NULL'  
   [ID]      NVARCHAR( 10),   
   [Default] NVARCHAR( 60),   
   Value     NVARCHAR( 60),   
   [NewID]   NVARCHAR( 10)  
)  
  
-- Redirect to respective screen  
IF @nStep = 0 GOTO Step_0   -- Menu. Func = 553  
IF @nStep = 1 GOTO Step_1   -- Scn = 976  
IF @nStep = 2 GOTO Step_2   -- Scn = 977  
IF @nStep = 3 GOTO Step_3   -- Scn = 978  
IF @nStep = 4 GOTO Step_4   -- Scn = 979  
IF @nStep = 5 GOTO Step_5   -- Scn = 980  
IF @nStep = 6 GOTO Step_6   -- Scn = 981  
IF @nStep = 7 GOTO Step_7   -- Scn = 982  
IF @nStep = 8 GOTO Step_8   -- Scn = 983  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step 0. Called from menu (func = 553)  
   @nStep = 0  
********************************************************************************/  
Step_0:  
BEGIN  
   IF EXISTS (SELECT 1 FROM RDTSessionData WHERE Mobile = @nMobile)  
      UPDATE RDTSessionData SET XML = '' WHERE Mobile = @nMobile  
   ELSE  
      INSERT INTO RDTSessionData (Mobile) VALUES (@nMobile)  
  
   SET @nScn = 976  
   SET @nStep = 1  
     
   SET @cMUID         = ''  
   SET @cSKU          = ''  
   SET @cDescr        = ''  
   SET @cUOM          = ''  
   SET @cUCCKey       = ''  
   SET @cPPK          = ''  
  
   SET @cQTY          = ''  
   SET @cToLoc        = ''  
   SET @cReceiptKey   = ''  
   SET @cCartonCnt    = '0'  
   SET @cTotalCartonCnt = ''  
   SET @cMaxCnt = '0'  
   SET @cTotalPalletCnt = '0'
   SET @cUserDefine08 = ''
   SET @cUserDefine09 = ''
END  
  
GOTO Quit  
  
  
/********************************************************************************  
Step 1. screen (scn = 976)  
   ASN#:  
(Step 0 screen)  
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
               SELECT @cExternKey = ISNULL(ExternReceiptKey,''), @cStatus = Status,   
                  @cDocType = DocType, @cASNStatus = ASNStatus FROM dbo.RECEIPT (NOLOCK)   
                  WHERE StorerKey = @cStorerKey AND RECEIPTKEY = @cReceiptKey  
--                SET @cExternKey = ISNULL(@cExternKey,'')  
                 
               IF ISNULL(LTRIM(RTRIM(@cDocType)),'') <> 'R'   
                  BEGIN  
                     SET @cErrMsg = rdt.rdtgetmessage( 61117, @cLangCode, 'DSP') --61117 Wrong DocType  
                     GOTO Step_1_Fail        
                  END  
        
               IF ISNULL(LTRIM(RTRIM(@cASNStatus)),'') = '9' OR ISNULL(LTRIM(RTRIM(@cStatus)),'') = '9'   
                  BEGIN  
                     SET @cErrMsg = rdt.rdtgetmessage( 61118, @cLangCode, 'DSP') --61118 ASN Closed  
                     GOTO Step_1_Fail        
                  END  
        
               IF ISNULL(LTRIM(RTRIM(@cASNStatus)),'') = 'CANC'   
                  BEGIN  
                     SET @cErrMsg = rdt.rdtgetmessage( 61119, @cLangCode, 'DSP') --61119 ASN Cancelled  
                     GOTO Step_1_Fail        
                  END  
  
               IF EXISTS (SELECT 1 FROM RDT.NSQLCONFIG (NOLOCK)   
                  WHERE CONFIGKEY = 'DefaultToLoc' AND NSQLValue = '1')  
                  SELECT @cToLoc = SVALUE FROM RDT.STORERCONFIG (NOLOCK)   
                     WHERE StorerKey = @cStorerKey AND CONFIGKEY = 'DefaultToLoc'  
  
                  GOTO Step_1_Next                     
            END  
         ELSE  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61102, @cLangCode, 'DSP') --61102 ASN# Not Found  
               GOTO Step_1_Fail        
            END  
   END  
     
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nFunc = @nMenu  
      SET @nScn  = @nMenu  
      SET @nStep = 0  
      SET @cOutField01 = ''  
  
      -- Delete session data  
      DELETE RDTSessionData WHERE Mobile = @nMobile  
  
      GOTO Quit  
   END  
     
   Step_1_Next:  
   BEGIN  
      SET @nScn  = 977  
      SET @nStep = 2  
      IF ISNULL(LTRIM(RTRIM(@cToLoc)),'') <> ''  
         BEGIN  
            SET @cOutField01 = @cToLoc  
            SET @cOutField02 = ''  
            SET @cOutField03 = ''  
            SET @cOutField04 = ''  
            SET @cOutField05 = ''  
            SET @cOutField06 = ''  
            SET @cOutField07 = ''  
            SET @cOutField08 = ''  
            SET @cOutField09 = ''  
            SET @cCartonCnt  = '0'  
            SET @cMaxCnt = '0'  
            SET @cTotalPalletCnt = '0'  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
         END  
      ELSE  
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
            SET @cCartonCnt  = '0'  
            SET @cMaxCnt = '0'  
            SET @cTotalPalletCnt = '0'  
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
Step 2. screen (scn = 977)  
   ToLoc: xxxxx  
   MUID#: xxxxx  
  
   Total Ctn: xx  
********************************************************************************/  
Step_2:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cToLoc = @cInField01  
      SET @cMUID  = @cInField02  
      SET @cTotalCartonCnt = @cInField03  
  
      SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue FROM dbo.NSQLConfig (NOLOCK)  
      WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'  
  
      IF ISNULL(LTRIM(RTRIM(@cToLoc)),'')= ''   --ToLoc is blank  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61103, @cLangCode, 'DSP') --61103 ToLoc Required  
            SET @cToLoc = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_2_Fail        
         END     
  
      IF NOT EXISTS(SELECT 1 FROM dbo.LOC (NOLOCK)    --check if toloc is within valid facility or not  
         WHERE LOC = @cToLoc AND FACILITY = @cFacility)  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61104, @cLangCode, 'DSP') --61104 Loc not in fac  
            SET @cToLoc = ''  
            GOTO Step_2_Fail        
         END     
           
      IF ISNULL(LTRIM(RTRIM(@cMUID)),'') = '' --MUID is blank  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61105, @cLangCode, 'DSP') --61105 MUID# Required  
            SET @cMUID = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 2  
            GOTO Step_2_Fail        
         END

      IF @cDecodeSP <> ''
      BEGIN
         SET @cIDBarcode = @cInField02
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SELECT @cSKU = ''

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, ' +
                        ' @cIDBarcode         OUTPUT,' +
                        ' @cUserDefine08      OUTPUT,' +
                        ' @cUserDefine09      OUTPUT,' +
                        ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'

            SET @cSQLParam =
                    ' @nMobile              INT,           ' +
                    ' @nFunc                INT,           ' +
                    ' @cLangCode            NVARCHAR( 3),  ' +
                    ' @nStep                INT,           ' +
                    ' @nInputKey            INT,           ' +
                    ' @cStorerKey           NVARCHAR( 15), ' +
                    ' @cIDBarcode           NVARCHAR( 2000)   OUTPUT, ' +
                    ' @cUserDefine08        NVARCHAR(30)      OUTPUT,' +
                    ' @cUserDefine09        NVARCHAR(30)      OUTPUT,' +
                    ' @nErrNo               INT               OUTPUT, ' +
                    ' @cErrMsg              NVARCHAR( 20)     OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey,
                 @cIDBarcode       OUTPUT,
                 @cUserDefine08    OUTPUT,
                 @cUserDefine09    OUTPUT,
                 @nErrNo           OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_2_Fail

            SET @cMUID = @cIDBarcode

         END
      END

  
      IF EXISTS( SELECT [ID]    -- check if toloc is valid  
         FROM dbo.LOTxLOCxID LOTxLOCxID (NOLOCK)  
         INNER JOIN dbo.LOC LOC (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)  
         WHERE [ID] = @cMUID  
         AND QTY > 0  
         AND LOC.Facility = @cFacility)  
         BEGIN  
            IF ISNULL(@nDisAllowDuplicateIDsOnRFRcpt,0) <> 1   --allow duplicate muid or not  
               BEGIN  
                  EXEC rdt.rdtSetFocusField @nMobile, 1  
                  SET @cErrMsg = rdt.rdtgetmessage( 61106, @cLangCode, 'DSP') --61106 Duplicate MUID  
                  SET @cMUID = ''  
                  GOTO Step_2_Fail        
               END                  
         END  
  
      SELECT @nLocCount = COUNT(LOC) FROM dbo.LOTXLOCXID (NOLOCK)    --check if MUID is tight to one loc  
         WHERE ID = @cMUID AND STORERKEY = @cStorerKey  
      IF @nLocCount > 1  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61120, @cLangCode, 'DSP') --61120 MUID Not Tight  
            SET @cTotalCartonCnt = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Step_2_Fail        
         END       
        
      SELECT @cTempToLoc = TOLOC FROM dbo.RECEIPTDETAIL (NOLOCK)   
         WHERE STORERKEY = @cStorerKey AND TOID = @cMUID   
      IF ISNULL(LTRIM(RTRIM(@cTempToLoc)),'') <> ''   --if receiptdetail line found,   
         BEGIN  
            IF @cTempToLoc <> @cToLoc   --if both toloc not same, error  
               BEGIN  
                  SET @cErrMsg = rdt.rdtgetmessage( 61120, @cLangCode, 'DSP') --61120 MUID Not Tight  
                  SET @cTotalCartonCnt = ''  
                  EXEC rdt.rdtSetFocusField @nMobile, 3  
                  GOTO Step_2_Fail        
               END                    
         END  
                    
      IF ISNULL(LTRIM(RTRIM(@cTotalCartonCnt)),0) <= 0  OR LTRIM(RTRIM(@cTotalCartonCnt)) = '' OR ISNUMERIC(@cTotalCartonCnt) = 0   --Total Carton is blank or zero or not numeric  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61107, @cLangCode, 'DSP') --61107 Invalid carton  
            SET @cTotalCartonCnt = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
            GOTO Step_2_Fail        
         END       
      GOTO Step_2_Next  
   END  
     
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 976  
      SET @nStep = 1  
      SET @cOutField01 = @cReceiptKey  
      GOTO QUIT  
   END  
  
   Step_2_Next:  
      BEGIN  
         SET @nScn  = 978  
         SET @nStep = 3  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
         SET @cMaxCnt = '0'  
         GOTO QUIT  
      END  
  
   Step_2_Fail:  
      BEGIN  
         SET @cOutField01 = @cToLoC  
         SET @cOutField02 = @cMUID  
         SET @cOutField03 = @cTotalCartonCnt  
      END  
END  
GOTO Quit  
  
/********************************************************************************  
Step 3. screen (scn = 978)  
  
   UCC#: xxxxx  
  
   Sku/UPC:  
   Desc:  
   PPK:  
   Qty:      UOM  
  
   Ctn: xx/xx  
********************************************************************************/  
Step_3:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
   BEGIN  
      SET @cUCCKey = @cInField01  
        
      IF ISNULL(LTRIM(RTRIM(@cUCCKey)),'') = ''  
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( 61108, @cLangCode, 'DSP') --61108 UCC# Required
         SET @cUCCKey = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step_3_Fail
      END


      IF @cDecodeSP <> ''
      BEGIN
         SET @cIDBarcode = @cInField01
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, ' +
                        ' @cIDBarcode         OUTPUT,' +
                        ' @cUserDefine08      OUTPUT,' +
                        ' @cUserDefine09      OUTPUT,' +
                        ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'

            SET @cSQLParam =
                    ' @nMobile              INT,           ' +
                    ' @nFunc                INT,           ' +
                    ' @cLangCode            NVARCHAR( 3),  ' +
                    ' @nStep                INT,           ' +
                    ' @nInputKey            INT,           ' +
                    ' @cStorerKey           NVARCHAR( 15), ' +
                    ' @cIDBarcode           NVARCHAR( 2000)   OUTPUT, ' +
                    ' @cUserDefine08        NVARCHAR(30)      OUTPUT,' +
                    ' @cUserDefine09        NVARCHAR(30)      OUTPUT,' +
                    ' @nErrNo               INT               OUTPUT, ' +
                    ' @cErrMsg              NVARCHAR( 20)     OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey,
                 @cIDBarcode       OUTPUT,
                 @cUserDefine08    OUTPUT,
                 @cUserDefine09    OUTPUT,
                 @nErrNo           OUTPUT, @cErrMsg     OUTPUT

            IF @nErrNo <> 0
               GOTO Step_3_Fail

            SET @cUCCKey = @cIDBarcode

         END
      END
  
      SELECT @nCnt = COUNT(UCCNo), @cUCCStatus = Status FROM dbo.UCC (NOLOCK)   
         WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCKey GROUP BY Status  
  
      IF ISNULL(@nCnt,0) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61109, @cLangCode, 'DSP') --61109 UCC# Not Found  
            SET @cUCCKey = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_3_Fail        
         END  
  
      IF ISNULL(@nCnt,0) > 1  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61110, @cLangCode, 'DSP') --61110 Multi Sku/ UCC  
            SET @cUCCKey = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_3_Fail        
         END     
  
      IF LTRIM(RTRIM(@cUCCStatus)) = '1'  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61112, @cLangCode, 'DSP') --61112 UCC# Scanned  
               SET @cUCCKey = ''  
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO Step_3_Fail                                 
            END           
  
      IF LTRIM(RTRIM(@cUCCStatus)) <> '0' AND LTRIM(RTRIM(@cUCCStatus)) <> '9'   --check if UCC status closed or shipped  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61121, @cLangCode, 'DSP') --61121 Invalid UCC  
            SET @cUCCKey = ''  
            EXEC rdt.rdtSetFocusField @nMobile, 1  
            GOTO Step_3_Fail        
         END  
        
      IF EXISTS (SELECT 1 FROM dbo.UCC (NOLOCK)   
         WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCKey)  
         BEGIN           
            SELECT @cSKU = SKU, @cQTY = Qty FROM dbo.UCC (NOLOCK)  
               WHERE StorerKey = @cStorerKey AND UCCNo = @cUCCKey         
  
            SELECT @cDescr = DESCR, @cPPK = PREPACKINDICATOR, @cTariffkey = Tariffkey   
        FROM dbo.SKU (NOLOCK)  
               WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
            SELECT @cUOM = UOM, @cPackKey = PACKKEY FROM dbo.RECEIPTDETAIL (NOLOCK)  
               WHERE StorerKey = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND SKU = @cSKU                       
  
            SELECT @nCaseCntQty = PACK.CASECNT FROM dbo.PACK PACK (NOLOCK)   
               WHERE PACKKEY = @cPackKey  
                                               
            IF @nCaseCntQty <> CAST(@cQTY AS INT)   --received by UPC  
               BEGIN  
                  SET @nScn  = 983  
                  SET @nStep = 8  
                  GOTO QUIT                                
               END     
  
            SET @cCartonCnt = CAST(@cCartonCnt AS INT) + 1  
            IF CAST(@cCartonCnt AS INT) > CAST(@cTotalCartonCnt AS INT)  
               BEGIN  
                  SET @cErrMsg = rdt.rdtgetmessage( 61111, @cLangCode, 'DSP') --61111 >Max No of CTN  
                  SET @cUCCKey = ''  
                  SET @cCartonCnt = CAST(@cCartonCnt AS INT) - 1     
                  SET @cMaxCnt = '1'                          
                  EXEC rdt.rdtSetFocusField @nMobile, 1  
                  GOTO Step_3_Fail        
               END   
                 
            GOTO Step_3_Next    
         END  
         ELSE  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61112, @cLangCode, 'DSP') --61112 UCC# Scanned  
  
               SET @cUCCKey = ''  
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO Step_3_Fail                                 
            END           
   END  
     
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 977  
      SET @nStep = 2  
      IF  @cMaxCnt = '1'  
         BEGIN  
            SET @cOutField01 = @cToLoc  
            SET @cOutField02 = @cMUID  
            SET @cOutField03 = @cTotalCartonCnt  
            SET @cMaxCnt = '0'  
            EXEC rdt.rdtSetFocusField @nMobile, 3  
         END  
      ELSE  
         IF CAST(@cCartonCnt AS INT) < CAST(@cTotalCartonCnt AS INT) AND CAST(@cCartonCnt AS INT) > 0  
            BEGIN   --carton < total cartons  
               SET @nScn  = 982  
               SET @nStep = 7  
               SET @cOutField01 = ''  
               EXEC rdt.rdtSetFocusField @nMobile, 1  
               GOTO QUIT  
            END  
         IF CAST(@cCartonCnt AS INT) = CAST(@cTotalCartonCnt AS INT) AND CAST(@cCartonCnt AS INT) > 0  
            BEGIN   --carton = total cartons  
               SET @cOutField01 = @cToLoc  
               SET @cOutField02 = ''  
               SET @cOutField03 = ''  
               SET @cOutField04 = ''  
               SET @cOutField05 = ''  
               SET @cOutField06 = ''  
               SET @cOutField07 = ''  
               SET @cOutField08 = ''  
               SET @cOutField09 = ''  
               SET @cMUID = ''  
               SET @cUCCKey = ''  
               SET @cSKU = ''  
               SET @cDescr = ''  
               SET @cPPK = ''  
               SET @cQTY = ''  
               SET @cUOM = ''  
               SET @cCartonCnt = '0'  
               SET @cTotalCartonCnt = ''  
               SET @cTotalPalletCnt = CAST(@cTotalPalletCnt AS int) + 1                 
               EXEC rdt.rdtSetFocusField @nMobile, 2  
               GOTO QUIT  
            END  
         ELSE  
            BEGIN  
               SET @cOutField01 = @cToLoc  
               EXEC rdt.rdtSetFocusField @nMobile, 2  
               GOTO QUIT  
            END  
   END  
  
   Step_3_Next:  
      BEGIN  
         SET @nScn  = 979  
         SET @nStep = 4  
         SET @cOutField01 = @cUCCKey  
         SET @cOutField02 = ''  
         SET @cOutField03 = @cSKU  
         SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
         SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
         SET @cOutField06 = @cPPK  
         SET @cOutField07 = LTRIM(RTRIM(@cUOM))  
         SET @cOutField08 = LTRIM(RTRIM(@cQTY))  
         SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
         SET @cReceiptLineNumber = ''  
         SET @cTempToID = ''  
         SET @cTempToLoc = ''  
         GOTO QUIT  
      END  
  
   Step_3_Fail:  
      SET @cOutField03 = ''      
END  
GOTO Quit  
  
/********************************************************************************  
Step 4. screen (scn = 979)  
  
   UCC#: xxxxx  
  
   Sku/UPC:  
   Desc:  
   PPK:  
   Qty: xxxxx UOM  
  
   Ctn: xx/xx  
********************************************************************************/  
Step_4:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
         SET ROWCOUNT 1     
         SELECT @cReceiptLineNumber = RD.RECEIPTLINENUMBER,   
            @cTempToLoc = ToLoc, @cTempToID = ToID   
            FROM dbo.RECEIPT R (NOLOCK)   
            INNER JOIN dbo.RECEIPTDETAIL RD (NOLOCK)   
            ON R.STORERKEY = RD.STORERKEY AND R.RECEIPTKEY = RD.RECEIPTKEY   
            WHERE R.STORERKEY = @cStorerKey AND R.RECEIPTKEY = @cReceiptKey AND SKU = @cSKU  
            AND QtyExpected > 0 AND QtyExpected > BeforeReceivedQty  
         SET ROWCOUNT 0  
  
         IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)),'') <> ''  --if receipt detail line found  
            IF @cTempToLoc = @cToLoc   --check if same loc first, if not same loc, insert new line  
               IF @cTempToID = @cMUID OR @cTempToID = '' --if same loc, check if same pallet id  
                  GOTO Process_4_1   -- same pallet ID, update beforereceivedqty only  
               ELSE  
                  GOTO Process_4_2   -- diff pallet ID, insert new line  
            ELSE  
               GOTO Process_4_2   --diff loc, insert new line  
         ELSE  
            GOTO Process_4_2   -- if receipt detail line not found, insert new line  
  
         Process_4_1:  
            BEGIN  
               UPDATE dbo.UCC WITH (ROWLOCK)   
                  SET RECEIPTKEY = @cReceiptKey,   
                  Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                  RECEIPTLINENUMBER = @cReceiptLineNumber, STATUS = '1', LOC = @cToLoc,ID = @cMUID   
                  WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
  
               UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)  
                  SET BeforeReceivedQty = BeforeReceivedQty + CAST(@cQTY AS INT),   
                  TOLOC = @cToLoc, ToID = @cMUID    
                  WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey   
                  AND RECEIPTLINENUMBER = @cReceiptLineNumber  
               GOTO Step_4_Next  
            END  
  
         Process_4_2:  
            BEGIN  
               SELECT @cReceiptLineNumber = RECEIPTLINENUMBER FROM dbo.RECEIPTDETAIL (NOLOCK)   
                  WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND   
                  BEFORERECEIVEDQTY > QTYEXPECTED AND SKU = @cSKU AND TOID = @cMUID  
               IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> ''  
                  GOTO Process_4_2_1  
               ELSE  
                  GOTO Process_4_2_2  
  
               Process_4_2_1:  
               BEGIN   --begin for Process_4_2_1  
                  UPDATE dbo.UCC WITH (ROWLOCK)   
                     SET RECEIPTKEY = @cReceiptKey,   
                     Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                     RECEIPTLINENUMBER = @cReceiptLineNumber, STATUS = '1', LOC = @cToLoc,ID = @cMUID   
                     WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
                    
                  UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)   
                     SET BEFORERECEIVEDQTY = BEFORERECEIVEDQTY + CAST(@cQTY AS INT),   
                     TOLOC = @cToLoc, ToID = @cMUID   
                     WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND  
                     RECEIPTLINENUMBER = @cReceiptLineNumber        
                  GOTO Step_4_Next           
               END   --end for Process_4_2_1  
                 
               Process_4_2_2:  
               BEGIN   --begin for Process_4_2_2  
                  SELECT @cReceiptLineNumber = MAX(RECEIPTLINENUMBER) FROM dbo.RECEIPTDETAIL (NOLOCK)   
                     WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey  
                  IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') = ''  
  
                     GOTO Process_4_2_2_1   --if this is first receiptdetail, receiptlinenumber = '00001'  
                  ELSE  
                     GOTO Process_4_2_2_2   --if already have receiptdetail line, no matter what receiptdetail line, use max(receiptdetail)  
  
                  Process_4_2_2_1:  
                  BEGIN  
                     SET @cNextReceiptLineNumber = '00001'  
  
                     UPDATE dbo.UCC WITH (ROWLOCK)   
                        SET RECEIPTKEY = @cReceiptKey,   
                        Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                        RECEIPTLINENUMBER = @cNextReceiptLineNumber, STATUS = '1', LOC = @cToLoc,ID = @cMUID   
                        WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
                    
                     INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber,   
                        ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, Status, DateReceived,    
                        QtyExpected, QtyAdjusted, QtyReceived, UOM, PackKey, VesselKey, VoyageKey, XdockKey,    
                        ContainerKey, ToLoc, ToLot, ToId, ConditionCode, Lottable01, Lottable02, Lottable03,    
                        Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, Cube, GrossWgt, NetWgt, OtherUnit1,    
                        OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate, AddDate, AddWho, EditDate, EditWho,    
                        TrafficCop, ArchiveCop, TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode,    
                        FinalizeFlag, DuplicateFrom, BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag,    
                        POLineNumber, LoadKey, ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04,    
                        UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10) VALUES             
                     (@cReceiptKey, @cNextReceiptLineNumber, '', '', @cStorerKey, '', @cSKU, '', '', '0',  GetDate(),   
                        0, 0,  0, @cUOM, @cPackKey, '', '', '', '', @cToLoc, '', @cMUID, 'OK', '', '', '',   
                        NULL, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, GetDate(), GetDate(), Suser_Sname(), GetDate(), Suser_Sname(),   
                        NULL, NULL, @cTariffkey, 0, 0, '', 'N', NULL, @cQty, NULL, NULL, 'N', '', NULL, NULL, '', '',   
                        '', '', '', NULL, NULL, @cUserDefine08, @cUserDefine09, '')
                  END  
  
                  Process_4_2_2_2:  
                  BEGIN   --begin Process_4_2_2_2  
                     SELECT @nExpectedQty = QtyExpected, @nBeforeReceivedQty = BeforeReceivedQty   
                        FROM dbo.RECEIPTDETAIL (NOLOCK)   
                        WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey   
                        AND RECEIPTLINENUMBER = @cReceiptLineNumber  
     
                     SET @cNextReceiptLineNumber = CAST(@cReceiptLineNumber AS INT) + 1  
                     SET @cNextReceiptLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(NVARCHAR(5), @cNextReceiptLineNumber ) ) , 5)  
  
                     UPDATE dbo.UCC WITH (ROWLOCK)   
                        SET RECEIPTKEY = @cReceiptKey,   
                        Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                        RECEIPTLINENUMBER = @cNextReceiptLineNumber, STATUS = '1', LOC = @cToLoc,ID = @cMUID   
                        WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
    
                     INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber,   
                        ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, Status, DateReceived,    
                        QtyExpected, QtyAdjusted, QtyReceived, UOM, PackKey, VesselKey, VoyageKey, XdockKey,    
                        ContainerKey, ToLoc, ToLot, ToId, ConditionCode, Lottable01, Lottable02, Lottable03,    
                        Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, Cube, GrossWgt, NetWgt, OtherUnit1,    
                        OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate, AddDate, AddWho, EditDate, EditWho,    
                        TrafficCop, ArchiveCop, TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode,    
                        FinalizeFlag, DuplicateFrom, BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag,    
                        POLineNumber, LoadKey, ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04,    
                        UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)              
                     SELECT @cReceiptKey, @cNextReceiptLineNumber, ISNULL(ExternReceiptKey, ''), ISNULL(ExternLineNo, ''),   
                        @cStorerKey, ISNULL(POKey, ''), @cSKU, '', '', '0',  GetDate(),   
                        0, 0,  0, @cUOM, @cPackKey, ISNULL(VesselKey, ''), ISNULL(VoyageKey, ''), ISNULL(XdockKey, ''),   
                        ISNULL(ContainerKey, ''), @cToLoc, ISNULL(ToLot, ''), @cMUID, ISNULL(ConditionCode, 'OK'), '', '', '',   
                        NULL, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, GetDate(),    
                        GetDate(), AddWho, GetDate(), EditWho, NULL, NULL, @cTariffkey, 0, 0, ISNULL(SubReasonCode, ''),    
                        'N', NULL, @cQty, NULL, NULL, 'N', '', NULL, NULL, '', '',   
                        '', '', '', NULL, NULL, @cUserDefine08, @cUserDefine09, ''
                        FROM dbo.RECEIPTDETAIL (NOLOCK)  
                        WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey   
                        AND ReceiptLineNumber = @cReceiptLineNumber  
                  END   --end for Process_4_2_2_2  
               END   --end for Process_4_2_2  
               GOTO Step_4_Next  
            END  
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 977  
      SET @nStep = 2  
      SET @cOutField01 = @cToLoc  
      SET @cOutField02 = @cMUID  
      SET @cOutField03 = @cTotalCartonCnt  
      EXEC rdt.rdtSetFocusField @nMobile, 3  
      GOTO Quit  
   END  
  
   Step_4_Next:
   --AUTO Finalize
   SET @cNotFinalizeRD = rdt.RDTGetConfig( @nFunc, 'RDT_NotFinalizeReceiptDetail', @cStorerKey)
   IF @cNotFinalizeRD = '0'
   BEGIN
      SET @cFinalizeLineNumber = CASE WHEN ISNULL(@cNextReceiptLineNumber,'') <> '' THEN @cNextReceiptLineNumber ELSE @cReceiptLineNumber END
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                                                 QTYReceived = BeforeReceivedQTY,
                                                 FinalizeFlag = 'Y',
                                                 EditDate = GETDATE(),
                                                 EditWho = SUSER_SNAME()
      WHERE ReceiptKey = @cReceiptKey
         AND ReceiptLineNumber = @cFinalizeLineNumber
   END
   --AUTO Finalize END


   BEGIN
      SET @nScn  = 978
      SET @nStep = 3
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))
      GOTO Quit
   END
  
   Step_4_Fail:  
      BEGIN  
         SET @cOutField08 = ''  
         GOTO QUIT  
      END  
END  
  
/********************************************************************************  
Step 5. screen (scn = 980)  
  
   UCC#: xxxxx  
  
   Sku/UPC:  
   Desc:  
   PPK:  
   Qty: xxxxx UOM  
  
   Ctn: xx/xx  
********************************************************************************/  
Step_5:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
         SET @cSKU = @cInField03  
  
         IF ISNULL(LTRIM(RTRIM(@cSKU)),'') = ''  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61113, @cLangCode, 'DSP') --61113 sku required  
               SET @cSKU = ''  
               GOTO Step_5_Fail        
            END     
  
         IF NOT EXISTS (SELECT 1 FROM dbo.SKU (NOLOCK)   
            WHERE STORERKEY = @cStorerkey AND SKU = @cSKU)  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61114, @cLangCode, 'DSP') --61114 invalid sku  
               SET @cSKU = ''  
               GOTO Step_5_Fail       
            END     
  
         IF EXISTS(SELECT 1 FROM dbo.UCC (NOLOCK)   
            WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey)  
            BEGIN  
               IF NOT EXISTS (SELECT 1 FROM dbo.UCC (NOLOCK)   
                  WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU)  
                  BEGIN  
        SET @cErrMsg = rdt.rdtgetmessage( 61115, @cLangCode, 'DSP') --61115 SKU Not Match  
                     SET @cSKU = ''  
                     GOTO Step_5_Fail        
                  END    
            END  
           
         SELECT @cDescr = DESCR, @cPPK = PREPACKINDICATOR, @cTariffkey = Tariffkey  
            FROM dbo.SKU (NOLOCK)  
            WHERE StorerKey = @cStorerKey AND SKU = @cSKU  
  
         SELECT @cUOM = UOM, @cPackKey = PACKKEY FROM dbo.RECEIPTDETAIL (NOLOCK)  
            WHERE StorerKey = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND SKU = @cSKU                       
  
         GOTO Step_5_Next                       
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 978  
      SET @nStep = 3  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
      EXEC rdt.rdtSetFocusField @nMobile, 1  
      GOTO Quit  
   END  
  
   Step_5_Next:  
   BEGIN  
      SET @nScn  = 981  
      SET @nStep = 6  
      SET @cOutField01 = @cUCCKey  
      SET @cOutField02 = ''  
      SET @cOutField03 = @cSKU  
      SET @cOutField04 = SUBSTRING(LTRIM(RTRIM(@cDescr)),1,10)  
      SET @cOutField05 = SUBSTRING(LTRIM(RTRIM(@cDescr)),11,20)  
      SET @cOutField06 = @cPPK  
      SET @cOutField07 = LTRIM(RTRIM(@cUOM))  
      SET @cOutField08 = ''  
      SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
      SET @cReceiptLineNumber = ''  
      SET @cTempToID = ''  
      SET @cTempToLoc= ''  
      GOTO Quit  
   END  
  
   Step_5_Fail:  
      BEGIN  
         SET @cOutField02 = ''  
         GOTO QUIT  
      END  
END  
  
  
/********************************************************************************  
Step 6. screen (scn = 981)  
  
   UCC#: xxxxx  
  
   Sku/UPC:  
   Desc:  
   PPK:  
   Qty: xxxxx UOM  
  
   Ctn: xx/xx  
********************************************************************************/  
Step_6:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
         SET @cQty = @cInField08 

         --V1.4
         IF ISNUMERIC(@cQTY) = 0  
         BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( 61116, @cLangCode, 'DSP') --61116 invalid qty  
            SET @cQty = ''  
            GOTO Step_6_Fail        
         END
         --V1.4 END   
  
         IF CAST(@cQTY AS INT) <= 0 --OR ISNUMERIC(@cQTY) = 0  --V1.4
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 61116, @cLangCode, 'DSP') --61116 invalid qty  
               SET @cQty = ''  
               GOTO Step_6_Fail        
            END     
  
         SELECT @nExpectedQty = QtyExpected, @nBeforeReceivedQty = BeforeReceivedQty,   
            @cReceiptLineNumber = RECEIPTLINENUMBER, @cTempToLoc = ToLoc, @cTempToID = ToID   
            FROM dbo.RECEIPTDETAIL (NOLOCK)   
            WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND SKU = @cSKU   
            AND QtyExpected > 0 AND QtyExpected > BeforeReceivedQty   --check to see if we still have available  
                                                                      --balance b/f we open a new line    
         IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)),'') <> '' --same sku, still has balance left on receiptdetail line  
            IF @cTempToLoc = @cToLoc --same loc, update only  
               IF @cTempToID = @cMUID OR @cTempToID = ''    
                  GOTO Process_6_1   --same palletid or blank palletid, update only  
               ELSE  
                  GOTO Process_6_2   --diff palletid, insert new  
            ELSE  
                  GOTO Process_6_2   --diff loc, insert new  
         ELSE           
            GOTO Process_6_2   --same sku or not still need to open a new receiptdetail line  
  
         Process_6_1:  
            BEGIN  
               UPDATE dbo.UCC WITH (ROWLOCK)   
                  SET STATUS = '6', Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                  LOC = @cToLoc, ID = @cMUID, ReceiptKey = @cReceiptKey, ReceiptLineNumber = @cReceiptLineNumber   
            WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
  
               UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)  
                  SET BeforeReceivedQty = QtyExpected,   
                  TOLOC = @cToLoc, ToID = @cMUID    
                  WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey   
                  AND RECEIPTLINENUMBER = @cReceiptLineNumber  
  
               SELECT @cReceiptLineNumber = MAX(ReceiptLineNumber) FROM dbo.RECEIPTDETAIL (NOLOCK)   
                  WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey   --in case there r many lines  
               IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)),'') = ''  
                  SET @cReceiptLineNumber = '00000'  
               SET @cNextReceiptLineNumber = CAST(@cReceiptLineNumber AS INT) + 1  
               SET @cNextReceiptLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(NVARCHAR(5), @cNextReceiptLineNumber ) ) , 5)  
  
               INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber,   
                  ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, Status, DateReceived,    
                  QtyExpected, QtyAdjusted, QtyReceived, UOM, PackKey, VesselKey, VoyageKey, XdockKey,    
                  ContainerKey, ToLoc, ToLot, ToId, ConditionCode, Lottable01, Lottable02, Lottable03,    
                  Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, Cube, GrossWgt, NetWgt, OtherUnit1,    
                  OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate, AddDate, AddWho, EditDate, EditWho,    
                  TrafficCop, ArchiveCop, TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode,    
                  FinalizeFlag, DuplicateFrom, BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag,    
                  POLineNumber, LoadKey, ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04,    
                  UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)              
               SELECT @cReceiptKey, @cNextReceiptLineNumber, ISNULL(ExternReceiptKey, ''), ISNULL(ExternLineNo, ''),   
                  @cStorerKey, ISNULL(POKey, ''), @cSKU, '', '', '0',  GetDate(),   
                  0, 0,  0, @cUOM, @cPackKey, ISNULL(VesselKey, ''), ISNULL(VoyageKey, ''), ISNULL(XdockKey, ''),   
                  ISNULL(ContainerKey, ''), @cToLoc, ISNULL(ToLot, ''), @cMUID, ISNULL(ConditionCode, 'OK'), '', '', '',   
                  NULL, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, GetDate(),    
                  GetDate(), AddWho, GetDate(), EditWho, NULL, NULL, @cTariffKey, 0, 0, ISNULL(SubReasonCode, ''),    
                  'N', NULL, @cQty - (@nExpectedQty - @nBeforeReceivedQty), NULL, NULL, 'N', '', NULL, NULL, '', '',   
                  '', '', '', NULL, NULL, @cUserDefine08, @cUserDefine09, ''
                  FROM dbo.RECEIPTDETAIL (NOLOCK)  
                  WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey   
                  AND ReceiptLineNumber = @cReceiptLineNumber  
               GOTO Step_6_Next  
            END  
        
         Process_6_2:  
            BEGIN              
               SELECT @cReceiptLineNumber = RECEIPTLINENUMBER FROM dbo.RECEIPTDETAIL (NOLOCK)   
                  WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND      
                  BEFORERECEIVEDQTY > QTYEXPECTED AND SKU = @cSKU AND TOID = @cMUID     
               IF ISNULL(LTRIM(RTRIM(@cReceiptLineNumber)), '') <> '' --check if over-received, same sku, same pallet id, then update only  
                  GOTO Process_6_2_1  
               ELSE  
                  GOTO Process_6_2_2                 
  
               Process_6_2_1:  
               BEGIN   --begin for Process_6_2_1  
                  UPDATE dbo.UCC WITH (ROWLOCK)   
                     SET STATUS = '6', Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                     LOC = @cToLoc, ID = @cMUID, ReceiptKey = @cReceiptKey, ReceiptLineNumber = @cReceiptLineNumber   
                     WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
                    
                  UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)   
                     SET BEFORERECEIVEDQTY = BEFORERECEIVEDQTY + CAST(@cQTY AS INT),   
                     TOLOC = @cToLoc, ToID = @cMUID   
                     WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey AND  
                     RECEIPTLINENUMBER = @cReceiptLineNumber           
                  GOTO Step_6_Next         
               END     --end for Process_6_2_1   
  
               Process_6_2_2:  
               BEGIN --begin for Process_6_2_2       
                  SELECT @cReceiptLineNumber = MAX(RECEIPTLINENUMBER) FROM dbo.RECEIPTDETAIL (NOLOCK)   
                     WHERE STORERKEY = @cStorerKey AND RECEIPTKEY = @cReceiptKey  
  
                  SET @cNextReceiptLineNumber = CAST(@cReceiptLineNumber AS INT) + 1  
                  SET @cNextReceiptLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(NVARCHAR(5), @cNextReceiptLineNumber ) ) , 5)  
  
                  UPDATE dbo.UCC WITH (ROWLOCK)   
                     SET STATUS = '6', Sourcetype = 'RECEIPT', ExternKey = @cExternKey,   
                     LOC = @cToLoc, ID = @cMUID, ReceiptKey = @cReceiptKey, ReceiptLineNumber = @cReceiptLineNumber   
                     WHERE STORERKEY = @cStorerkey AND UCCNO = @cUCCKey AND SKU = @cSKU  
  
                  INSERT INTO dbo.RECEIPTDETAIL(ReceiptKey, ReceiptLineNumber,   
                     ExternReceiptKey, ExternLineNo, StorerKey, POKey, Sku, AltSku, Id, Status, DateReceived,    
                     QtyExpected, QtyAdjusted, QtyReceived, UOM, PackKey, VesselKey, VoyageKey, XdockKey,    
                     ContainerKey, ToLoc, ToLot, ToId, ConditionCode, Lottable01, Lottable02, Lottable03,    
                     Lottable04, Lottable05, CaseCnt, InnerPack, Pallet, Cube, GrossWgt, NetWgt, OtherUnit1,    
                     OtherUnit2, UnitPrice, ExtendedPrice, EffectiveDate, AddDate, AddWho, EditDate, EditWho,    
                     TrafficCop, ArchiveCop, TariffKey, FreeGoodQtyExpected, FreeGoodQtyReceived, SubReasonCode,    
                     FinalizeFlag, DuplicateFrom, BeforeReceivedQty, PutawayLoc, ExportStatus, SplitPalletFlag,    
                     POLineNumber, LoadKey, ExternPoKey, UserDefine01, UserDefine02, UserDefine03, UserDefine04,    
                     UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)              
                  SELECT @cReceiptKey, @cNextReceiptLineNumber, ISNULL(ExternReceiptKey, ''), ISNULL(ExternLineNo, ''),   
                     @cStorerKey, ISNULL(POKey, ''), @cSKU, '', '', '0',  GetDate(),   
                     0, 0,  0, @cUOM, @cPackKey, ISNULL(VesselKey, ''), ISNULL(VoyageKey, ''), ISNULL(XdockKey, ''),   
                     ISNULL(ContainerKey, ''), @cToLoc, ISNULL(ToLot, ''), @cMUID, ISNULL(ConditionCode, 'OK'), '', '', '',   
                     NULL, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, GetDate(),    
                     GetDate(), AddWho, GetDate(), EditWho, NULL, NULL, @cTariffKey, 0, 0, ISNULL(SubReasonCode, ''),    
                     'N', NULL, @cQty, NULL, NULL, 'N', '', NULL, NULL, '', '',   
                     '', '', '', NULL, NULL, @cUserDefine08, @cUserDefine09, ''
                     FROM dbo.RECEIPTDETAIL (NOLOCK)  
                     WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey   
                     AND ReceiptLineNumber = @cReceiptLineNumber  
               END   --end for Process_6_2_2  
               GOTO Step_6_Next  
            END  
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
      SET @nScn  = 978  
      SET @nStep = 3  
      SET @cOutField01 = @cUCCKey  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
      EXEC rdt.rdtSetFocusField @nMobile, 2  
      GOTO Quit  
   END  
  
   Step_6_Next:
   --AUTO Finalize
   SET @cNotFinalizeRD = rdt.RDTGetConfig( @nFunc, 'RDT_NotFinalizeReceiptDetail', @cStorerKey)
   IF @cNotFinalizeRD = '0'
   BEGIN
      SET @cFinalizeLineNumber = CASE WHEN ISNULL(@cNextReceiptLineNumber,'') <> '' THEN @cNextReceiptLineNumber ELSE @cReceiptLineNumber END
      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET
                                                 QTYReceived = BeforeReceivedQTY,
                                                 FinalizeFlag = 'Y',
                                                 EditDate = GETDATE(),
                                                 EditWho = SUSER_SNAME()
      WHERE ReceiptKey = @cReceiptKey
        AND ReceiptLineNumber = @cFinalizeLineNumber
   END
   --AUTO Finalize END

   BEGIN  
      SET @nScn  = 978  
      SET @nStep = 3  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      SET @cOutField05 = ''  
      SET @cOutField06 = ''  
      SET @cOutField07 = ''  
      SET @cOutField08 = ''  
      SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
      GOTO Quit  
   END  
  
   Step_6_Fail:  
      BEGIN  
         SET @cOutField02 = ''  
         GOTO QUIT  
      END  
END  
  
GOTO QUIT  
  
/********************************************************************************  
Step 7. screen (scn = 982)  
   (Y/N):  
********************************************************************************/  
Step_7:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
         SET @cConfirm = @cInField01  
         IF @cConfirm <> '1' AND @cConfirm <> '2'  
            BEGIN  
               SET @cErrMsg = rdt.rdtgetmessage( 4, @cLangCode, 'DSP') --Invalid Option  
               SET @cConfirm = ''  
               GOTO Step_7_Fail        
            END  
         IF @cConfirm = '1'   --exit back to step 2 screen  
            BEGIN  
               SET @nScn  = 977  
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
               SET @cMUID = ''  
               SET @cUCCKey = ''  
               SET @cSKU = ''  
               SET @cDescr = ''  
               SET @cPPK = ''  
               SET @cQTY = ''  
               SET @cUOM = ''  
               SET @cCartonCnt = '0'  
               SET @cTotalCartonCnt = ''  
               SET @cTotalPalletCnt = CAST (@cTotalCartonCnt AS int) + 1  
               EXEC rdt.rdtSetFocusField @nMobile, 2  
               GOTO Quit  
            END  
         IF @cConfirm = '2'  
            BEGIN  
               SET @nScn  = 978  
               SET @nStep = 3  
               SET @cOutField01 = ''  
               SET @cOutField02 = ''  
               SET @cOutField03 = ''  
               SET @cOutField04 = ''  
               SET @cOutField05 = ''  
               SET @cOutField06 = ''  
               SET @cOutField07 = ''  
               SET @cOutField08 = ''  
               SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
               EXEC rdt.rdtSetFocusField @nMobile, 3  
               GOTO Quit  
            END  
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
   BEGIN  
         SET @nScn  = 978  
         SET @nStep = 3  
         SET @cOutField01 = ''  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
         EXEC rdt.rdtSetFocusField @nMobile, 3  
         GOTO Quit  
   END  
/*  
   Step_4_Next:  
   BEGIN  
      SET @nScn  = 980  
      SET @nStep = 5  
      SET @cOutField01 = ''  
      SET @cOutField02 = ''  
      SET @cOutField03 = ''  
      SET @cOutField04 = ''  
      GOTO Quit  
   END  
*/  
   Step_7_Fail:  
   BEGIN  
      SET @cOutField01 = ''  
   END  
  
END  
  
GOTO Quit  
  
/********************************************************************************  
Step 8. screen (scn = 983)  
UCC Qty is NOT valid  
  
Receive by UPC  
********************************************************************************/  
Step_8:  
BEGIN  
  
   IF @nInputKey = 1     -- Yes OR Send / Esc OR No  
      BEGIN  
SET @nScn  = 980  
         SET @nStep = 5  
         SET @cOutField01 = @cUCCKey  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO QUIT                                
      END  
           
   IF @nInputKey = 0 -- Esc OR No  
      BEGIN  
         SET @nScn  = 980  
         SET @nStep = 5  
         SET @cOutField01 = @cUCCKey  
         SET @cOutField02 = ''  
         SET @cOutField03 = ''  
         SET @cOutField04 = ''  
         SET @cOutField05 = ''  
         SET @cOutField06 = ''  
         SET @cOutField07 = ''  
         SET @cOutField08 = ''  
         SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
         EXEC rdt.rdtSetFocusField @nMobile, 2  
         GOTO QUIT                                
--         SET @nScn  = 978  
--         SET @nStep = 3  
--         SET @cOutField01 = ''  
--         SET @cOutField02 = ''  
--         SET @cOutField03 = ''  
--         SET @cOutField04 = ''  
--         SET @cOutField05 = ''  
--         SET @cOutField06 = ''  
--         SET @cOutField07 = ''  
--         SET @cOutField08 = ''  
--         SET @cOutField09 = LTRIM(RTRIM(@cCartonCnt)) + '/' + LTRIM(RTRIM(@cTotalCartonCnt))  
--         EXEC rdt.rdtSetFocusField @nMobile, 2  
--         GOTO QUIT                                
      END  
END  
  
GOTO Quit  
  
  
  
Quit:  
BEGIN  
  
   UPDATE RDTMOBREC WITH (ROWLOCK) SET   
   EditDate = GETDATE(),   
   ErrMsg = @cErrMsg   , Func = @nFunc,  
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
   v_String1 = @cDecodeSP,
   V_String2 = @cUserDefine08,
   V_String3 = @cUserDefine09
  
   WHERE Mobile = @nMobile  
  
   -- Save session variable  
   SET @cXML =   
      '<Variable VarName="@cMUID"         Value = "' + IsNULL( @cMUID, '')         + '"/>' +    
      '<Variable VarName="@cSKU"         Value = "' + IsNULL( @cSKU, '')         + '"/>' +    
      '<Variable VarName="@cDescr"         Value = "' + IsNULL( @cDescr, '')         + '"/>' +    
      '<Variable VarName="@cUOM"         Value = "' + IsNULL( @cUOM, '')         + '"/>' +    
      '<Variable VarName="@cUCCKey"          Value = "' + IsNULL( @cUCCKey, '')          + '"/>' +    
      '<Variable VarName="@cPPK"     Value = "' + IsNULL( @cPPK, '')     + '"/>' +    
      '<Variable VarName="@cQTY"         Value = "' + IsNULL( @cQTY, '')         + '"/>' +    
      '<Variable VarName="@cToLoc"        Value = "' + IsNULL( @cToLoc, '')        + '"/>' +    
      '<Variable VarName="@cReceiptKey"         Value = "' + IsNULL( @cReceiptKey, '')         + '"/>' +    
      '<Variable VarName="@cReceiptLineNumber"         Value = "' + IsNULL( @cReceiptLineNumber, '')         + '"/>' +    
      '<Variable VarName="@cCartonCnt"        Value = "' + IsNULL( @cCartonCnt, '')        + '"/>' +  
      '<Variable VarName="@cTotalCartonCnt"        Value = "' + IsNULL( @cTotalCartonCnt, '')        + '"/>' +  
      '<Variable VarName="@cPackkey"        Value = "' + IsNULL( @cPackkey, '')        + '"/>' +  
      '<Variable VarName="@cMaxCnt"        Value = "' + IsNULL( @cMaxCnt, '')        + '"/>' +  
      '<Variable VarName="@cExternKey"        Value = "' + IsNULL( @cExternKey, '')        + '"/>' +  
      '<Variable VarName="@cTariffkey"        Value = "' + IsNULL( @cTariffkey, '')        + '"/>'   
  
   -- Save session screen  
   IF EXISTS( SELECT 1 FROM @tSessionScrn)  
   BEGIN  
      DECLARE @curScreen CURSOR  
      DECLARE  
         @cTyp     NVARCHAR( 10),   
         @cX       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'  
         @cY       NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'  
         @cLength  NVARCHAR( 4),   -- size 4 is needed bcoz of 'NULL'  
         @cFieldID NVARCHAR( 10),   
         @cDefault NVARCHAR( 60),   
         @cValue   NVARCHAR( 60),   
         @cNewID   NVARCHAR( 10)  
  
      SET @curScreen = CURSOR FOR   
         SELECT Typ, X, Y, Length, [ID], [Default], Value, [NewID] FROM @tSessionScrn  
      OPEN @curScreen  
      FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         SELECT @cXML = @cXML +   
            '<Screen ' +   
               CASE WHEN @cTyp     IS NULL THEN '' ELSE 'Typ="'     + @cTyp     + '" ' END +   
               CASE WHEN @cX       IS NULL THEN '' ELSE 'X="'       + @cX       + '" ' END +   
               CASE WHEN @cY       IS NULL THEN '' ELSE 'Y="'       + @cY       + '" ' END +   
               CASE WHEN @cLength  IS NULL THEN '' ELSE 'Length="'  + @cLength  + '" ' END +   
               CASE WHEN @cFieldID IS NULL THEN '' ELSE 'ID="'      + @cFieldID + '" ' END +   
               CASE WHEN @cDefault IS NULL THEN '' ELSE 'Default="' + @cDefault + '" ' END +   
               CASE WHEN @cValue   IS NULL THEN '' ELSE 'Value="'   + @cValue   + '" ' END +   
               CASE WHEN @cNewID   IS NULL THEN '' ELSE 'NewID="'   + @cNewID   + '" ' END +   
            '/>'  
         FETCH NEXT FROM @curScreen INTO @cTyp, @cX, @cY, @cLength, @cFieldID, @cDefault, @cValue, @cNewID  
      END  
      CLOSE @curScreen  
      DEALLOCATE @curScreen  
   END  
  
   -- Note: UTF-8 is multi byte (1 to 6 bytes) encoding. Use UTF-16 for double byte  
   SET @cXML =   
      '<?xml version="1.0" encoding="UTF-16"?>' +   
      '<Root>' +   
         @cXML +   
      '</Root>'  
   UPDATE RDTSessionData SET XML = @cXML WHERE Mobile = @nMobile  
  
END  

GO