SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Inquiry which UCC not yet received                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2006-08-16 1.0  UngDH      Created                                   */
/* 2008-09-02 1.1  Vicky      Modify to cater for SQL2005 (Vicky01)     */ 
/* 2016-09-30 1.2  Ung        Performance tuning                        */
/* 2018-11-21 1.3  TungGH     Performance                               */   
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCInboundInquiry] (
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
   @i           INT, 
   @cOrderKey   NVARCHAR( 10), 
   @cOrderLineNumber NVARCHAR( 5)

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

   @cReceiptKey NVARCHAR( 10), 
   @cTotalUCC   NVARCHAR( 5), 
   @cScanUCC    NVARCHAR( 5), 
   @nRemainUCC  INT, 
   @nCurrentRec INT, 
   @cUCC        NVARCHAR( 20), 
   @cQTY        NVARCHAR( 5), 
   @cLOC        NVARCHAR( 10), 
   
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
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cReceiptKey = V_String1, 
   @cTotalUCC   = V_String2, 
   @cScanUCC    = V_String3, 
   @cLOC        = V_LOC, 
   @cUCC        = V_UCC, 
   @cQTY        = V_QTY, 

   @nRemainUCC  = V_Integer1,
   @nCurrentRec = V_Integer2,
      
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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 574  -- UCC Outbound inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = UCC Outbound inquiry
   IF @nStep = 1 GOTO Step_1   -- Scn = 696. ASN
   IF @nStep = 2 GOTO Step_2   -- Scn = 697. ASN, Counter, UCC, QTY, 
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 574. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 696
   SET @nStep = 1

   -- Initiate var
   SET @cReceiptKey = ''
   SET @cTotalUCC = ''
   SET @cScanUCC = ''
   SET @nRemainUCC = 0
   SET @nCurrentRec = 0
   SET @cLOC = ''
   SET @cUCC = ''
   SET @cQTY = ''

   -- Init screen
   SET @cOutField01 = '' -- LoadKey
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 696. ASN screen
   ReceiptKey (field01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
         
      -- Validate blank
      IF @cInField01 = '' OR @cInField01 IS NULL
      BEGIN
         SET @nErrNo = 62251
         SET @cErrMsg = rdt.rdtgetmessage( 62251, @cLangCode,'DSP') --ASN needed
         GOTO Step_1_Fail
      END
      
      -- Get ASN info
      IF NOT EXISTS( SELECT 1
         FROM dbo.Receipt (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey)
      BEGIN
         SET @nErrNo = 62252
         SET @cErrMsg = rdt.rdtgetmessage( 62252, @cLangCode,'DSP') -- Invalid ASN
         GOTO Step_1_Fail
      END

      -- Get total UCC
      SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
      FROM dbo.ReceiptDetail RD (NOLOCK)
         INNER JOIN dbo.PODetail PODetail (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
      WHERE RD.ReceiptKey = @cReceiptKey

      -- Get UCC scanned
      SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
      FROM dbo.ReceiptDetail RD (NOLOCK)
         INNER JOIN dbo.PODetail PODetail (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
      WHERE RD.ReceiptKey = @cReceiptKey
         AND BeforeReceivedQty > 0 -- Received

      -- Calc remain UCC
      SET @nRemainUCC = CAST( @cTotalUCC AS INT) - CAST( @cScanUCC AS INT)

      IF @nRemainUCC = 0
      BEGIN
         SET @cUCC = ''
         SET @cQTY = ''
         SET @cLOC = ''
         SET @nCurrentRec = 0
      END
      ELSE
      BEGIN
         -- Get 1st remain UCC
         SELECT DISTINCT TOP 1 
            @cUCC = IsNull( RTRIM(PODetail.UserDefine01), ''), -- (Vicky01)
            @cLOC = RD.ToLOC
         FROM dbo.ReceiptDetail RD (NOLOCK)
            INNER JOIN dbo.PODetail PODetail (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         WHERE RD.ReceiptKey = @cReceiptKey
            AND BeforeReceivedQty = 0 -- not yet received
         ORDER BY 1
         
         -- Get QTY
         SELECT @cQTY = IsNULL( SUM( RD.QTYExpected), 0)
         FROM dbo.ReceiptDetail RD (NOLOCK)
            INNER JOIN dbo.PODetail PODetail (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         WHERE RD.ReceiptKey = @cReceiptKey
            AND IsNull( RTRIM(PODetail.UserDefine01), '') = @cUCC -- (Vicky01)

         SET @nCurrentRec = 1
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cTotalUCC
      SET @cOutField03 = @cScanUCC
      SET @cOutField04 = CAST( @nRemainUCC AS NVARCHAR( 5))
      SET @cOutField05 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nRemainUCC AS NVARCHAR( 5))
      SET @cOutField06 = @cUCC
      SET @cOutField07 = @cQTY
      SET @cOutField08 = @cLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END
   
   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptKey = ''
      SET @cOutField01 = '' -- ReceiptKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 697. UCC screen
   ReceiptKey (field01)
   Total      (field02)
   Scan       (field03)
   Remain     (field04)
   Counter    (field05)
   UCC        (field06)
   QTY        (field07)
   LOC        (field08)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @nRemainUCC = 0
         GOTO Quit

      IF @nCurrentRec = @nRemainUCC
      BEGIN
         SET @nCurrentRec = 0
         SET @cUCC = ''
      END

      -- Get next remain UCC
      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT
            IsNull( RTRIM(PODetail.UserDefine01), ''),  -- (Vicky01)
            RD.ToLOC
         FROM dbo.ReceiptDetail RD (NOLOCK)
            INNER JOIN dbo.PODetail PODetail (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         WHERE RD.ReceiptKey = @cReceiptKey
            AND BeforeReceivedQty = 0 -- not yet received
         ORDER BY 1
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCC, @cLOC

      SET @i = 1
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @i > @nCurrentRec BREAK
         SET @i = @i + 1
         FETCH NEXT FROM @curUCC INTO @cUCC, @cLOC
      END

      -- Get QTY
      SELECT @cQTY = IsNULL( SUM( RD.QTYExpected), 0)
      FROM dbo.ReceiptDetail RD (NOLOCK)
         INNER JOIN dbo.PODetail PODetail (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
      WHERE RD.ReceiptKey = @cReceiptKey
         AND IsNull( RTRIM(PODetail.UserDefine01), '') = @cUCC -- (Vicky01)
            
      -- Prepare current screen var
      SET @nCurrentRec = @nCurrentRec + 1
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cTotalUCC
      SET @cOutField03 = @cScanUCC
      SET @cOutField04 = CAST( @nRemainUCC AS NVARCHAR( 5))
      SET @cOutField05 = CAST( @nCurrentRec AS NVARCHAR( 5)) + '/' + CAST( @nRemainUCC AS NVARCHAR( 5))
      SET @cOutField06 = @cUCC
      SET @cOutField07 = @cQTY
      SET @cOutField08 = @cLOC      

      -- Remain in current screen
      -- SET @nScn = @nScn + 1
      -- SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN     
      -- Reset prev screen var
      SET @cReceiptKey = ''
      SET @cOutField01 = @cReceiptKey

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
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

      V_String1   = @cReceiptKey, 
      V_String2   = @cTotalUCC,
      V_String3   = @cScanUCC,  
      V_LOC       = @cLOC, 
      V_UCC       = @cUCC, 
      V_QTY       = @cQTY, 
      
      V_Integer1  = @nRemainUCC, 
      V_Integer2  = @nCurrentRec,

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