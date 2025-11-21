SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: rdtfnc_ReceiveByUCC                                         */
/* Copyright      : IDS                                                         */
/*                                                                              */
/* Purpose: NIKE UCC Receive. 1 UCC 1 SKU. Last carton mix SKU.                 */
/*          Receive by PO.                                                      */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date         Rev   Author   Purposes                                         */
/* 27-Apr-2016  1.0   James    SOS367786 - Created                              */
/* 30-Sep-2016  1.1   Ung      Performance tuning                               */   
/* 09-Oct-2017  1.2   ChewKP   WMS-3162 Add ExtendedUpdateSP, ExtendedValidateSP*/
/*                             configs (ChewKP01)                               */
/* 11-Jan-2018  1.3   ChewKP   WMS3779 - Support UCC multi PO (ChewKP02)        */
/* 19-Oct-2018  1.4   Gan      Performance tuning                               */
/* 22-Apr-2019  1.5   ChewKP   WMS-8762 Add EventLog (ChewKP03)                 */
/********************************************************************************/

CREATE PROC [RDT].[rdtfnc_ReceiveByUCC] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variable
DECLARE
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX)


-- Define a variable
DECLARE  
   @nFunc        			INT,  
   @nScn         			INT,  
   @nStep        			INT,  
   @cLangCode    			NVARCHAR( 3),  
   @nInputKey    			INT,  
   @nMenu        			INT,  
   @cPrinter     			NVARCHAR(10),  
   @cUserName    			NVARCHAR(18),  
   @cStorerKey   			NVARCHAR(15),  
   @cFacility    			NVARCHAR( 5),  
   @cReceiptKey  			NVARCHAR( 10),  
   @cPOKey       			NVARCHAR( 10),  
   @cPOLineNumber       NVARCHAR( 5),  
   @cSKU         			NVARCHAR( 20),  
   @cQTY         			NVARCHAR( 10),  
   @cDefaultFromLoc     NVARCHAR( 10),  
   @cFromLoc            NVARCHAR( 10),  
   @cUCC                NVARCHAR( 20),
   @cSourcekey          NVARCHAR( 20), 
   @cStatus             NVARCHAR( 10), 
   @cUOM                NVARCHAR( 10), 
   @cReasonCode         NVARCHAR( 10), 
   @cReceiptLineNumber  NVARCHAR( 5), 
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
   @cCounter            NVARCHAR( 20),
   @cDataWindow         NVARCHAR( 50),
   @cTargetDB           NVARCHAR( 20),
   @cLabelPrinter       NVARCHAR( 10),
   @cPaperPrinter       NVARCHAR( 10),
   @cReportType         NVARCHAR( 10),
   @cPrintJobName       NVARCHAR( 60),
   @cNewUCC             NVARCHAR( 20),
   @nASNStatus          NVARCHAR( 10),
   @cLOT                NVARCHAR( 10),

   @nUCCQty             INT,
   @nTranCount          INT,
   @nQTY                INT, 
   @nCurRec             INT, 
   @nASNBalQty          INT,
   @bSuccess            INT,
   @nMultiSKU_UCC       INT,
   
   @cExtendedValidateSP NVARCHAR(30),   -- (ChewKP01)
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP01)
   @cOutputText1        NVARCHAR(20),   -- (ChewKP01) 
   @cOutputText2        NVARCHAR(20),   -- (ChewKP01) 
   @cOutputText3        NVARCHAR(20),   -- (ChewKP01) 
   @cOutputText4        NVARCHAR(20),   -- (ChewKP01) 
   @cOutputText5        NVARCHAR(20),   -- (ChewKP01) 
         
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

DECLARE
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),
   @c_oFieled13 NVARCHAR(20), @c_oFieled14 NVARCHAR(20),
   @c_oFieled15 NVARCHAR(20),
   @cDecodeLabelNo       NVARCHAR( 20)

DECLARE
   @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
   @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
   @cErrMsg5    NVARCHAR( 20)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer,
   @cUserName        = UserName,

   @cUCC             = V_UCC,
   @cSKU             = V_SKU,
   @nQTY             = V_Qty,
   @cExtendedValidateSP = V_String1, -- (ChewKP01)
   @cExtendedUpdateSP   = V_String2, -- (ChewKP01)

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

FROM   RDT.RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen  
IF @nFunc = 897  
BEGIN  
   IF @nStep = 0 GOTO Step_0   -- Func = 550. Menu  
   IF @nStep = 1 GOTO Step_1   -- Scn = 4520. ASN #  
   IF @nStep = 2 GOTO Step_2   -- Scn = 4521. EXT PALLET ID  
END  

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 897)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 4580
   SET @nStep = 1

   -- initialise all variable
   SET @cUCC = ''
 
   -- Init screen
   SET @cOutField01 = ''
   
   -- (ChewKP01) 
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''

    -- EventLog - Sign In Function
    EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign in function
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerKey,
     @nStep       = @nStep
END
GOTO Quit

/********************************************************************************
Step 1. screen = 4580
   CARTON      (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01

      -- Validate blank
      IF ISNULL( @cUCC, '') = '' 
      BEGIN  
         SET @nErrNo = 99451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Value required'  
         GOTO Step_1_Fail
      END  
      
      IF @cExtendedValidateSP <> ''
      BEGIN 
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cDropID, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility     NVARCHAR( 5),  ' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cUCC, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_1_Fail
            END
         END
      END
      ELSE
      BEGIN
         SELECT @cSourceKey = SourceKey,
                @nUCCQty = Qty,
                @cStatus = Status
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC

         IF @@ROWCOUNT = 0
         BEGIN  
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 99452, @cLangCode, 'DSP'), 7, 14) --CARTON ID DOES
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 99453, @cLangCode, 'DSP'), 7, 14) --NOT EXISTS
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
            END         

            GOTO Step_1_Fail
         END  

         IF ISNULL( @cStatus, '') > '0'
         BEGIN  
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 99454, @cLangCode, 'DSP'), 7, 14) --CARTON ID 
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 99455, @cLangCode, 'DSP'), 7, 14) --ALREADY 
            SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 99456, @cLangCode, 'DSP'), 7, 14) --RECEIVED 
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END         

            GOTO Step_1_Fail
         END  

         IF ISNULL( @cSourceKey, '') = '' 
         BEGIN  
            SET @nErrNo = 99461
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No asn found'  
            GOTO Step_1_Fail
         END  

         SET @cPOKey = SUBSTRING( @cSourceKey, 1, 10)
         SET @cPOLineNumber = SUBSTRING( @cSourceKey, 11, 5)
      
         SELECT @nASNStatus = R.Status
         FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
         JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
         WHERE RD.StorerKey = @cStorerKey
         AND   RD.POKey = @cPOKey
         AND   RD.POLineNumber = @cPOLineNumber

         -- Check if ASN populated
         IF ISNULL( @nASNStatus, '') = ''
         BEGIN  
            SET @nErrNo = 99457
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Asn not exists'  
            GOTO Step_1_Fail
         END  

         IF @nASNStatus = '9'
         BEGIN  
            SET @nErrNo = 99458
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Asn Closed'  
            GOTO Step_1_Fail
         END  
      END
      
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cDropID, @cOutPutText1 OUTPUT, @cOutPutText2 OUTPUT, @cOutPutText3 OUTPUT, @cOutPutText4 OUTPUT, @cOutPutText5 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile       INT,           ' +
               '@nFunc         INT,           ' +
               '@cLangCode     NVARCHAR( 3),  ' +
               '@nStep         INT,           ' +
               '@nInputKey     INT,           ' +
               '@cFacility        NVARCHAR( 5),' +
               '@cStorerKey    NVARCHAR( 15), ' +
               '@cDropID       NVARCHAR( 20), ' +
               '@cOutputText1  NVARCHAR( 20) OUTPUT, ' +
               '@cOutputText2  NVARCHAR( 20) OUTPUT, ' +
               '@cOutputText3  NVARCHAR( 20) OUTPUT, ' +
               '@cOutputText4  NVARCHAR( 20) OUTPUT, ' +
               '@cOutputText5  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo        INT           OUTPUT, ' +
               '@cErrMsg       NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cUCC, @cOutPutText1 OUTPUT, @cOutPutText2 OUTPUT, @cOutPutText3 OUTPUT, @cOutPutText4 OUTPUT, @cOutPutText5 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_1_Fail
            END
            
            SET @cOutField02 = @cOutputText1
            SET @cOutField03 = @cOutputText2
            SET @cOutField04 = @cOutputText3
            SET @cOutField05 = @cOutputText4
            SET @cOutField06 = @cOutputText5
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 0
         SET @nCurRec = 0

         SET @cDefaultFromLoc = ''
         SELECT @cDefaultFromLoc = rdt.RDTGetConfig( @nFunc, 'DefaultReceiptLoc', @cStorerKey) 

         SET @nMultiSKU_UCC = 0
         IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   UCCNo = @cUCC
                     GROUP BY UCCNO 
                     HAVING COUNT( DISTINCT SKU) > 1)
            SET @nMultiSKU_UCC = 1

         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''

         

         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN
         SAVE TRAN rdt_RECEIVEBYUCC

         DECLARE CUR_RECEIPT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT SourceKey, SKU, Qty
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         ORDER BY 1
         OPEN CUR_RECEIPT
         FETCH NEXT FROM CUR_RECEIPT INTO @cSourceKey, @cSKU, @nQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SET @cPOKey = SUBSTRING( @cSourceKey, 1, 10)
            SET @cPOLineNumber = SUBSTRING( @cSourceKey, 11, 5)

            SELECT TOP 1 
               @cReceiptKey   = R.ReceiptKey,
               @cFromLoc      = ToLoc,
               @cLottable01   = Lottable01,
               @cLottable02   = Lottable02,
               @cLottable03   = Lottable03,
               @dLottable04   = Lottable04,
               @cLottable06   = Lottable06,
               @cLottable07   = Lottable07,
               @cLottable08   = Lottable08,
               @cLottable09   = Lottable09,
               @cLottable10   = Lottable10,
               @cLottable11   = Lottable11,
               @cLottable12   = Lottable12,
               @dLottable13   = Lottable13,
               @dLottable14   = Lottable14,
               @dLottable15   = Lottable15,
               @cReasonCode   = ConditionCode
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN dbo.Receipt R WITH (NOLOCK) ON ( RD.ReceiptKey = R.ReceiptKey)
            WHERE RD.POKey = SUBSTRING( @cSourceKey, 1, 10)
            AND   RD.POLineNumber = SUBSTRING( @cSourceKey, 11, 5)
            AND   RD.SKU = @cSKU
            --AND   ( RD.QtyExpected - RD.BeforeReceivedQty) >= @nQty
            AND   R.Status = '0'
            --AND   FinalizeFlag <> 'Y'

            IF ISNULL( @cReceiptKey, '') = ''
            BEGIN
               SET @nErrNo = 99460
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No ASN found'  
               CLOSE CUR_RECEIPT
               DEALLOCATE CUR_RECEIPT
               GOTO RollBackTran
            END

            SELECT @cUOM = PackUOM3
            FROM dbo.SKU WITH (NOLOCK)
            JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE StorerKey = @cStorerKey
            AND   SKU = @cSKU
                     
            IF ISNULL( @cDefaultFromLoc, '') <> ''
               SET @cFromLoc = @cDefaultFromLoc

            

            -- Receive
            EXEC rdt.rdt_Receive_V7
               @nFunc         = @nFunc,
               @nMobile       = @nMobile,
               @cLangCode     = @cLangCode,
               @nErrNo        = @nErrNo OUTPUT,
               @cErrMsg       = @cErrMsg OUTPUT,
               @cStorerKey    = @cStorerKey,
               @cFacility     = @cFacility,
               @cReceiptKey   = @cReceiptKey,
               @cPOKey        = @cPoKey,  
               @cToLOC        = @cFromLoc,
               @cToID         = '',
               @cSKUCode      = @cSKU,
               @cSKUUOM       = @cUOM,
               @nSKUQTY       = @nQTY,
               @cUCC          = '',
               @cUCCSKU    = '',
               @nUCCQTY       = '',
               @cCreateUCC    = '',
               @cLottable01   = @cLottable01,
               @cLottable02   = @cLottable02,
               @cLottable03   = @cLottable03,
               @dLottable04   = @dLottable04,
               @dLottable05   = NULL,
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
               @nNOPOFlag     = 0,
               @cConditionCode = @cReasonCode,
               @cSubreasonCode = '', 
               @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

            IF @nErrNo <> 0
            BEGIN
               CLOSE CUR_RECEIPT
               DEALLOCATE CUR_RECEIPT
               GOTO RollBackTran
            END
            ELSE
            BEGIN
               -- Get LOT# from itrn to stamp into UCC table
               SELECT @cLOT = Lot
               FROM dbo.ITRN WITH (NOLOCK)
               WHERE SourceKey = @cReceiptKey + @cReceiptLineNumber
               AND   TranType = 'DP'
               AND   StorerKey = @cStorerKey

               SET @nCurRec = @nCurRec + 1

               IF @nCurRec = 1
                  SET @cOutField02 = LEFT( RTRIM( @cSKU) + REPLICATE( ' ', 16), 16) + 
                  RIGHT( REPLICATE( ' ', 4) +  RTRIM( CAST( @nQTY AS NVARCHAR( 3))), 4)

               IF @nCurRec = 2
                  SET @cOutField03 = LEFT( RTRIM( @cSKU) + REPLICATE( ' ', 16), 16) + 
                  RIGHT( REPLICATE( ' ', 4) +  RTRIM( CAST( @nQTY AS NVARCHAR( 3))), 4)

               IF @nCurRec = 3
                  SET @cOutField04 = LEFT( RTRIM( @cSKU) + REPLICATE( ' ', 16), 16) + 
                  RIGHT( REPLICATE( ' ', 4) +  RTRIM( CAST( @nQTY AS NVARCHAR( 3))), 4)

               IF @nCurRec = 4
                  SET @cOutField05 = LEFT( RTRIM( @cSKU) + REPLICATE( ' ', 16), 16) + 
                  RIGHT( REPLICATE( ' ', 4) +  RTRIM( CAST( @nQTY AS NVARCHAR( 3))), 4)

               IF @nCurRec = 5
                  SET @cOutField06 = LEFT( RTRIM( @cSKU) + REPLICATE( ' ', 16), 16) + 
                  RIGHT( REPLICATE( ' ', 4) +  RTRIM( CAST( @nQTY AS NVARCHAR( 3))), 4)
            END

            -- UCC contain multi SKU
            IF @nMultiSKU_UCC = 1
            BEGIN
               EXECUTE nspg_getkey
                  @KeyName       = 'NIKEUCC' ,
                  @fieldlength   = 19,    
                  @keystring     = @cCounter    Output,
                  @b_success     = @bSuccess    Output,
                  @n_err         = @nErrNo      Output,
                  @c_errmsg      = @cErrMsg     Output,
                  @b_resultset   = 0,
                  @n_batch       = 1

               IF @nErrNo <> 0 OR @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 99462
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Get ucc fail'  
                  CLOSE CUR_RECEIPT
                  DEALLOCATE CUR_RECEIPT
                  GOTO RollBackTran
               END

               SET @cNewUCC = 'N' + @cCounter

               -- Split multi sku UCC. Stamp userdefined09 with original UCC
               INSERT INTO dbo.UCC (UCCNO, STORERKEY, EXTERNKEY, SKU, QTY, SOURCEKEY, SOURCETYPE, 
               [Status], USERDEFINED09, Receiptkey, ReceiptLineNumber, Loc, Lot)
               SELECT @cNewUCC AS UCCNO, STORERKEY, EXTERNKEY, SKU, QTY, SOURCEKEY, SOURCETYPE, 
               '1' AS STATUS, @cUCC AS USERDEFINED09, @cReceiptKey AS ReceiptKey, 
               @cReceiptLineNumber AS ReceiptLineNumber, @cFromLoc AS Loc, @cLOT AS Lot
               FROM dbo.UCC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cUCC
               AND   SKU = @cSKU
               AND   SourceKey = @cSourceKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 99463
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Split ucc fail'  
                  CLOSE CUR_RECEIPT
                  DEALLOCATE CUR_RECEIPT
                  GOTO RollBackTran
               END

               -- Dispose old UCC
               UPDATE dbo.UCC WITH (ROWLOCK) SET 
                  [Status] = '6'
               WHERE StorerKey = @cStorerKey
               AND   UCCNo = @cUCC
               AND   SKU = @cSKU
               AND   [Status] = '0'
               AND   SourceKey = @cSourceKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 99464
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd ucc fail'  
                  CLOSE CUR_RECEIPT
                  DEALLOCATE CUR_RECEIPT
                  GOTO RollBackTran
               END
            END

            FETCH NEXT FROM CUR_RECEIPT INTO @cSourceKey, @cSKU, @nQty
         END
         CLOSE CUR_RECEIPT
         DEALLOCATE CUR_RECEIPT
     
         UPDATE dbo.UCC WITH (ROWLOCK) SET 
            LOT = @cLOT,
            Loc = @cFromLoc,
            [Status] = '1', 
            ReceiptKey = @cReceiptKey, 
            ReceiptLineNumber = @cReceiptLineNumber
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cUCC
         AND   [Status] = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 99465
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Rcv ctn fail'  
            GOTO RollBackTran
         END

         IF EXISTS ( SELECT 1 FROM rdt.RDTReport WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey
                     AND   ReportType = 'CUSTOMLBL')
         BEGIN
            -- Get printer info  
            SELECT @cLabelPrinter = Printer
            FROM rdt.rdtMobRec WITH (NOLOCK)  
            WHERE Mobile = @nMobile  

            -- Check label printer blank  
            IF @cLabelPrinter = ''  
            BEGIN  
               SET @nErrNo = 99466  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq  
               GOTO RollBackTran  
            END  

            -- Get report info  
            SET @cDataWindow = ''  
            SET @cTargetDB = ''  
            SET @cReportType = 'CUSTOMLBL'
            SET @cPrintJobName = 'PRINT_CUSTOMLBL'

            SELECT   
               @cDataWindow = ISNULL(RTRIM(DataWindow), ''),  
               @cTargetDB = ISNULL(RTRIM(TargetDB), '') 
            FROM RDT.RDTReport WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
               AND ReportType = @cReportType  

            IF @cDataWindow = ''
            BEGIN  
               SET @nErrNo = 99467  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP  
               GOTO RollBackTran  
            END  

            IF @cTargetDB = ''
            BEGIN  
               SET @nErrNo = 99468  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET  
               GOTO RollBackTran  
            END  

            -- Insert print job 
            SET @nErrNo = 0                    
            EXEC RDT.rdt_BuiltPrintJob                     
               @nMobile,                    
               @cStorerKey,                    
               @cReportType,                    
               @cPrintJobName,                    
               @cDataWindow,                    
               @cLabelPrinter,                    
               @cTargetDB,                    
               @cLangCode,                    
               @nErrNo  OUTPUT,                     
               @cErrMsg OUTPUT,                    
               @cUCC

            IF @nErrNo <> 0
               GOTO RollBackTran  
         END

         GOTO CommitTran

         RollBackTran:  
               ROLLBACK TRAN rdt_RECEIVEBYUCC  

         CommitTran:  
            WHILE @@TRANCOUNT > @nTranCount  
               COMMIT TRAN rdt_RECEIVEBYUCC

         IF @nErrNo = 0
         BEGIN
            -- Go to next screen  
            SET @nScn = @nScn + 1  
            SET @nStep = @nStep + 1  
         END
      END
      
     	-- EventLog - Sign In Function -- (ChewKP03)     
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '3', -- Sign in function    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerKey,  
         @cUCC        = @cUCC,     
         @nStep       = @nStep
         
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog - Sign Out Function
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

      SET @cOutField01 = ''

      SET @cUCC = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOutField01 = ''

      SET @cUCC = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 4581
   CARTON      (Field01)
   SKU, QTY    (Field02)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      SET @cOutField01 = ''

      SET @cUCC = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg,
      Func          = @nFunc,
      Step          = @nStep,
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility,
      Printer       = @cPrinter,
      -- UserName      = @cUserName,

      V_UCC        = @cUCC,
      V_SKU        = @cSKU,
      V_Qty        = @nQTY,
      
      V_String1    = @cExtendedValidateSP, -- (ChewKP01)
      V_String2    = @cExtendedUpdateSP, -- (ChewKP01)

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