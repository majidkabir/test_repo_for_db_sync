SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_ASN_Inquiry                                       */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: ASN Inquiry (SKU) - SOS#133215                                   */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2009-04-02 1.0  Vicky    Created                                          */
/* 2015-03-06 1.1  ChewKP   SOS#335124 Add ASN Infor (ChewKP01)              */
/* 2016-09-30 1.2  Ung      Performance tuning                               */
/* 2018-10-10 1.3  TungGH   Performance                                      */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_ASN_Inquiry](
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
   @b_success           INT,
   @cUOM                NVARCHAR(10),
   @nSKUCnt             INT,
   @cPackUOM            NVARCHAR(10)
  
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cReceiptKey         NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cDesc               NVARCHAR(60),
   @cTTLRecvQty         NVARCHAR(5),
   @cTTLQtyExpected     NVARCHAR(5),
   @cQtyReceived        NVARCHAR(5),
   @cQtyExpected        NVARCHAR(5),
   @cStatus             NVARCHAR(1),
   @cTotalCnt           NVARCHAR(5),
   @cRecordCnt          NVARCHAR(5),  
   @cRefNo              NVARCHAR(20), -- (ChewKP01)
   @cExtendedInfoSP     NVARCHAR(20), -- (ChewKP01)
   @n_Err               INT,          -- (ChewKP01)
   @cSQL                NVARCHAR(1000), -- (ChewKP01)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP01)
   @nRowCount           INT,            -- (ChewKP01)
   @cOutInfo01          NVARCHAR(60),   -- (ChewKP01) 
   @cOption             NVARCHAR(1),    -- (ChewKP01)

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

   @cReceiptKey      = V_ReceiptKey,
   @cSKU             = V_SKU, 
   @cUOM             = V_UOM, 
   @cDesc            = V_SkuDescr,  
   @cTTLRecvQty      = V_String1,
   @cTTLQtyExpected  = V_String2,     
   @cQtyReceived     = V_String3,
   @cQtyExpected     = V_String4,
   @cPackUOM         = V_String5,
   @cStatus          = V_String6, 
   @cTotalCnt        = V_String7,
   @cRecordCnt       = V_String8,
   @cExtendedInfoSP  = V_String9,  -- (ChewKP01) 


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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1631 -- ASN Inquiry (SKU)
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1630
   IF @nStep = 1 GOTO Step_1   -- Scn = 2000   ASN
   IF @nStep = 2 GOTO Step_2   -- Scn = 2001   ASN, TTL SCN Qty, TTL EXP Qty...
   IF @nStep = 3 GOTO Step_3   -- Scn = 2002   ASN, TTL SCN Qty, TTL EXP Qty...
   IF @nStep = 4 GOTO Step_4   -- Scn = 2003   ASN INFO -- (ChewKP01)
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1900)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2000
   SET @nStep = 1

   -- Init var
   SET @nSKUCnt = 0

   -- initialise all variable
   SET @cReceiptKey = ''
   SET @cRecordCnt = 0
   
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
      


   -- Prep next screen var   
   SET @cOutField01 = ''  -- Receiptkey
   SET @cOutField02 = ''  -- UOM
   SET @cOutField03 = ''  -- TTLRecvQty
   SET @cOutField04 = ''  -- TTLQtyExpected
   SET @cOutField05 = ''  -- SKU
   SET @cOutField06 = ''  -- SKU Desc
   SET @cOutField07 = ''  -- PackUOM
   SET @cOutField08 = ''  -- QtyReceived
   SET @cOutField09 = ''  -- QtyExpected
END
GOTO Quit

/********************************************************************************
Step 1. screen = 1900
   ASN (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cRefNo      = @cInField02
      
  

      -- Check ref no
      IF @cRefNo <> '' AND @cReceiptKey = ''
      BEGIN


         -- Get storer config
         DECLARE @cFieldName NVARCHAR(20)
         SET @cFieldName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)
         
         
         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cFieldName
         
         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE 
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE 
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
                              
            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 66710
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- RefNo
               GOTO Quit
            END
            
            DECLARE @tReceipt TABLE
            (
               RowRef     INT IDENTITY( 1, 1),
               ReceiptKey NVARCHAR( 10) NOT NULL
            )
   
            SET @cSQL = 
               ' SELECT ReceiptKey ' + 
               ' FROM dbo.Receipt WITH (NOLOCK) ' + 
               ' WHERE Facility = ' + QUOTENAME( @cFacility, '''') + 
                  ' AND ISNULL( ' + @cFieldName + CASE WHEN @cDataType IN ('int', 'float') THEN ',0)' ELSE ','''')' END + ' = ' + QUOTENAME( @cRefNo, '''') + 
                  --' AND Status <> ''9'' ' + 
               ' ORDER BY ReceiptKey ' 

           
   
            -- Get ASN by RefNo
            INSERT INTO @tReceipt (ReceiptKey)
            EXEC (@cSQL)
            SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
            IF @nErrNo <> 0
               GOTO Quit
   



            -- Check RefNo in ASN
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 66711
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- ContainerKey
               GOTO Quit
            END
            SET @cOutField03 = @cRefNo
   
            -- Only 1 ASN. Auto retrieve the ASN
            IF @nRowCount = 1
            BEGIN
               SELECT @cReceiptKey = ReceiptKey FROM @tReceipt
               SET @cOutField01 = @cReceiptKey
            END
   
  

            -- Multi ASN found, prompt user to select
            IF @nRowCount > 1
            BEGIN
               DECLARE
                  @cMsg1 NVARCHAR(20), @cMsg2 NVARCHAR(20), @cMsg3 NVARCHAR(20), @cMsg4 NVARCHAR(20), @cMsg5 NVARCHAR(20),
                  @cMsg6 NVARCHAR(20), @cMsg7 NVARCHAR(20), @cMsg8 NVARCHAR(20), @cMsg9 NVARCHAR(20), @cMsg  NVARCHAR(20)
               SELECT
                  @cMsg1 = '', @cMsg2 = '', @cMsg3 = '', @cMsg4 = '', @cMsg5 = '',
                  @cMsg6 = '', @cMsg7 = '', @cMsg8 = '', @cMsg9 = '', @cMsg = ''
   
               SELECT
                  @cMsg1 = CASE WHEN RowRef = 1 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg1 END,
                  @cMsg2 = CASE WHEN RowRef = 2 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg2 END,
                  @cMsg3 = CASE WHEN RowRef = 3 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg3 END,
                  @cMsg4 = CASE WHEN RowRef = 4 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg4 END,
                  @cMsg5 = CASE WHEN RowRef = 5 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg5 END,
                  @cMsg6 = CASE WHEN RowRef = 6 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg6 END,
                  @cMsg7 = CASE WHEN RowRef = 7 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg7 END,
                  @cMsg8 = CASE WHEN RowRef = 8 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg8 END,
                  @cMsg9 = CASE WHEN RowRef = 9 THEN CAST( RowRef AS NVARCHAR(2)) + '. ' + ReceiptKey ELSE @cMsg9 END
               FROM @tReceipt
   
               SET @cOutField01 = @cMsg1
               SET @cOutField02 = @cMsg2
               SET @cOutField03 = @cMsg3
               SET @cOutField04 = @cMsg4
               SET @cOutField05 = @cMsg5
               SET @cOutField06 = @cMsg6
               SET @cOutField07 = @cMsg7
               SET @cOutField08 = @cMsg8
               SET @cOutField09 = @cMsg9
               SET @cOutField10 = '' -- Option
               
               -- Go to Lookup
               SET @nScn = @nScn + 3
               SET @nStep = @nStep + 3
   
               GOTO Quit
            END
         END
      END

      --When ASN is blank
      IF @cReceiptKey = '' 
      BEGIN
         SET @nErrNo = 66701
         SET @cErrMsg = rdt.rdtgetmessage( 66701, @cLangCode, 'DSP') --ASN needed
         GOTO Step_1_Fail  
      END 

      --check diff facility
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 66702
         SET @cErrMsg = rdt.rdtgetmessage( 66702, @cLangCode, 'DSP') --Diff facility
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail    
      END

      --check diff storer
      IF NOT EXISTS ( SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorerkey)
      BEGIN
         SET @nErrNo = 66703
         SET @cErrMsg = rdt.rdtgetmessage( 66703, @cLangCode, 'DSP') --Diff storer
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail    
      END

      --check for ASN cancelled
      IF EXISTS ( SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 66704
         SET @cErrMsg = rdt.rdtgetmessage( 66704, @cLangCode, 'DSP') --ASN cancelled
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail    
      END

      --check if receiptkey exists
      IF NOT EXISTS (SELECT 1 
         FROM dbo.Receipt WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptkey)
      BEGIN
         SET @nErrNo = 66705
         SET @cErrMsg = rdt.rdtgetmessage( 66705, @cLangCode, 'DSP') --ASN not exists
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail  
      END
      ELSE
      BEGIN
         SELECT @cStatus = RTRIM(Status)
         FROM dbo.RECEIPT WITH (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey
          
         SELECT @cSKU = MIN(SKU), 
                @cTTLQtyExpected = RTRIM(CAST(ISNULL(SUM(QtyExpected),0) AS CHAR)),
                @cTTLRecvQty = CASE WHEN @cStatus = '9' 
                                     THEN RTRIM(CAST(ISNULL(SUM(QtyReceived),0) AS CHAR))
                                     ELSE RTRIM(CAST(ISNULL(SUM(BeforeReceivedQty),0) AS CHAR))
                               END
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey

         SELECT @cUOM = PACK.PackUOM3 
         FROM dbo.PACK PACK WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
         WHERE SKU.SKU = @cSKU
         AND SKU.StorerKey = @cStorerkey

         IF CAST(@cTTLQtyExpected AS INT) <> CAST(@cTTLRecvQty AS INT) 
         BEGIN
            -- Get Total Records that is not tally (by SKU)

            CREATE TABLE #TEMPCNT (QtyExpected INT, 
                                   QtyReceived INT, 
                                   BeforeReceivedQty INT)

            INSERT INTO #TEMPCNT (QtyExpected, QtyReceived, BeforeReceivedQty)
            SELECT SUM(QtyExpected), SUM(QtyReceived), SUM(BeforeReceivedQty)
            FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND RECEIPTKEY = @cReceiptkey
            GROUP BY SKU 

            IF @cStatus = '9'
            BEGIN
                SELECT @cTotalCnt = CAST(COUNT(*) AS CHAR)
                FROM #TEMPCNT WITH (NOLOCK)
                WHERE QtyExpected <> QtyReceived
            END
            ELSE
            BEGIN
                SELECT @cTotalCnt = CAST(COUNT(*) AS CHAR)
                FROM #TEMPCNT WITH (NOLOCK)
                WHERE QtyExpected <> BeforeReceivedQty
            END
            -- Avoid display first sku @cQty=@cQtyExpected
            DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
               SELECT SKU, RTRIM(CAST(ISNULL(SUM(QtyExpected),0) AS CHAR)), 
                      CASE WHEN @cStatus = '9' THEN RTRIM(CAST(ISNULL(SUM(QtyReceived),0) AS CHAR)) 
                           ELSE RTRIM(CAST(ISNULL(SUM(BeforeReceivedQty),0) AS CHAR)) 
                      END
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
               WHERE StorerKey = @cStorerkey
               AND RECEIPTKEY = @cReceiptkey
               AND SKU >= @cSKU
               GROUP BY SKU
               ORDER BY SKU

            OPEN CUR_RECEIPTDETAIL
            FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected, @cQtyReceived
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @cPackUOM = PACK.PackUOM3, 
                      @cDesc = SKU.Descr
               FROM dbo.PACK PACK WITH (NOLOCK) 
               JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
               WHERE SKU.SKU = @cSKU
               AND SKU.StorerKey = @cStorerkey
               
               IF CAST(@cQtyExpected AS INT) <> CAST(@cQtyReceived AS INT) 
               BEGIN
                  CLOSE CUR_RECEIPTDETAIL
                  DEALLOCATE CUR_RECEIPTDETAIL                    
                  GOTO Step_1_Next
               END
               ELSE
               BEGIN
                  FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected, @cQtyReceived
               END
            END
            CLOSE CUR_RECEIPTDETAIL       
            DEALLOCATE CUR_RECEIPTDETAIL   
         END
         ELSE
         BEGIN
            SELECT @cSKU = ''
            SELECT @cDesc = ''
            SELECT @cPackUOM = ''
            SELECT @cQtyReceived = '' 
            SELECT @cQtyExpected = ''
            SELECT @cRecordCnt = ''
            SELECT @cTotalCnt = ''

            SET @cOutField01 = @cReceiptkey
            SET @cOutField02 = @cUOM
            SET @cOutField03 = @cTTLRecvQty
            SET @cOutField04 = @cTTLQtyExpected 

            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            GOTO Tally_Continue
         END
      END

      Step_1_Next:  
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cRefNo, @cOutInfo01 OUTPUT,' +
            ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
         SET @cSQLParam =
            ' @nMobile      INT,           ' +
            ' @nFunc        INT,           ' +
            ' @cLangCode    NVARCHAR( 3),  ' +
            ' @nStep        INT,           ' +
            ' @nInputKey    INT,           ' +
            ' @cStorerKey   NVARCHAR( 15), ' +
            ' @cReceiptKey  NVARCHAR( 10), ' +
            ' @cRefNo       NVARCHAR( 10), ' +
            ' @cOutInfo01  NVARCHAR( 60)   OUTPUT, ' + 
            ' @nErrNo       INT            OUTPUT, ' +
            ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cRefNo, @cOutInfo01 OUTPUT, 
            @nErrNo      OUTPUT, @cErrMsg     OUTPUT

         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END

      
      --prepare next screen variable
      SET @cRecordCnt = RTRIM(CAST((CAST(@cRecordCnt AS INT) + 1) AS CHAR))
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cUOM
      SET @cOutField03 = @cTTLRecvQty
      SET @cOutField04 = @cTTLQtyExpected
      SET @cOutField05 = @cSKU
      SET @cOutField06 = SUBSTRING(@cDesc,1,20)
      SET @cOutField07 = @cPackUOM
      SET @cOutField08 = @cQtyReceived
      SET @cOutField09 = @cQtyExpected
      SET @cOutField10 =  RTRIM(@cRecordCnt) + '/' + @cTotalCnt
      SET @cOutField11 = @cOutInfo01 -- (ChewKP01) 
                  
      -- Go to next screen
      SET @nScn = @nScn + 2
      SET @nStep = @nStep + 2

      Tally_Continue:
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option

      SET @cRecordCnt = 0
      SET @cTotalCnt = 0
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptkey = ''
      SET @cRecordCnt = 0
      SET @cTotalCnt = 0

      -- Reset this screen var
      SET @cOutField01 = ''  -- Receiptkey
      SET @cOutField02 = ''  -- UOM
      SET @cOutField03 = ''  -- TTLRecvQty
      SET @cOutField04 = ''  -- TTLQtyExpected
      SET @cOutField05 = ''  -- SKU
      SET @cOutField06 = ''  -- SKU Desc
      SET @cOutField07 = ''  -- PackUOM
      SET @cOutField08 = ''  -- QtyReceived
      SET @cOutField09 = ''  -- QtyExpected
      SET @cOutField10 = ''  -- @cRecordCnt
  END
END
GOTO Quit

/********************************************************************************
Step 2. (screen = 1901) ASN, TTL SCN Qty, TTL EXP Qty
   ASN:          
                (Field01)  -- ASN
                (Field02)  -- UOM
   TTL SCN QTY: (Field03)
   TTL EXP QTY: (Field04)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 OR @nInputKey = 0 -- ENTER OR ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = '' -- RefNo -- (ChewKP01) 
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      SET @cRecordCnt = 0
      SET @cTotalCnt = 0

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Step 3. (screen = 1901) ASN, TTL SCN Qty, TTL EXP Qty...
   ASN:             99/99
                (Field01)  -- ASN
                (Field02)  -- UOM
   TTL SCN QTY: (Field03)
   TTL EXP QTY: (Field04)
   SKU:         
                (Field05)  -- SKU 
                (Field06)  -- SKU Descr
                (Field07)  -- UOM
   SCN QTY:     (Field08)  
   EXP QTY:     (Field09)              

   ENTER =  Next Page
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      --prepare next screen variable
      --SET @cRecordCnt = RTRIM(CAST((CAST(@cRecordCnt AS INT) + 1) AS CHAR))
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cUOM
      SET @cOutField03 = @cTTLRecvQty
      SET @cOutField04 = @cTTLQtyExpected
      SET @cOutField05 = @cSKU
      SET @cOutField06 = SUBSTRING(@cDesc,1,20)
      SET @cOutField07 = @cPackUOM
      SET @cOutField08 = @cQtyReceived
      SET @cOutField09 = @cQtyExpected
      SET @cOutField10 = RTRIM(@cRecordCnt) + '/' + @cTotalCnt

      DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT SKU, RTRIM(CAST(ISNULL(SUM(QtyExpected),0) AS CHAR)),
                CASE WHEN @cStatus = '9' THEN RTRIM(CAST(ISNULL(SUM(QtyReceived),0) AS CHAR)) 
                     ELSE RTRIM(CAST(ISNULL(SUM(BeforeReceivedQty),0) AS CHAR)) 
                END
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
         WHERE StorerKey = @cStorerkey
         AND RECEIPTKEY = @cReceiptkey
         AND SKU > @cSKU
         GROUP BY SKU
         ORDER BY SKU

      OPEN CUR_RECEIPTDETAIL
      FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected, @cQtyReceived
      WHILE @@FETCH_STATUS = 0
      BEGIN
          SELECT @cPackUOM = PACK.PackUOM3, 
                @cDesc = SKU.Descr 
         FROM dbo.PACK PACK WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
         WHERE SKU.SKU = @cSKU
         AND SKU.StorerKey = @cStorerkey
         
         IF CAST(@cQtyExpected AS INT) <> CAST(@cQtyReceived AS INT) 
         BEGIN
            CLOSE CUR_RECEIPTDETAIL
            DEALLOCATE CUR_RECEIPTDETAIL                    
            GOTO Step_3_Next
         END
         ELSE
         BEGIN
            FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @cSKU, @cQtyExpected, @cQtyReceived
         END
      END
      CLOSE CUR_RECEIPTDETAIL
      DEALLOCATE CUR_RECEIPTDETAIL

      -- Check if no next record found
      IF @@FETCH_STATUS = -1
      BEGIN
         SET @nErrNo = 66706
         SET @cErrMsg = rdt.rdtgetmessage( 66706, @cLangCode, 'DSP') --No next record
         GOTO Step_3_Fail  

      END

      Step_3_Next:
      BEGIN
         --prepare next screen variable
         SET @cRecordCnt = RTRIM(CAST((CAST(@cRecordCnt AS INT) + 1) AS CHAR))
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = @cUOM
         SET @cOutField03 = @cTTLRecvQty
         SET @cOutField04 = @cTTLQtyExpected
         SET @cOutField05 = @cSKU
         SET @cOutField06 = SUBSTRING(@cDesc,1,20)
         SET @cOutField07 = @cPackUOM
         SET @cOutField08 = @cQtyReceived
         SET @cOutField09 = @cQtyExpected
         SET @cOutField10 = RTRIM(@cRecordCnt) + '/' + @cTotalCnt
      END              
 
      -- Get next sku
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = '' -- RefNo -- (ChewKP01) 
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      SET @cRecordCnt = 0
      SET @cTotalCnt = 0

      -- go to previous screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END   
END
GOTO Quit

/********************************************************************************
Step 4. Screen = 2003. Refno Lookup
   INFO        (Field01)
   INFO        (Field02)
   INFO        (Field03)
   INFO        (Field04)
   INFO        (Field05)
   INFO        (Field06)
   INFO        (Field07)
   INFO        (Field08)
   INFO        (Field09)
   OPTION      (Field10, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField10

      -- Check blank
      IF @cOption = ''
      BEGIN
         SET @nErrNo = 66707
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option
         GOTO Quit
      END

      -- Check valid 
      IF @cOption NOT BETWEEN '1' AND '9'
      BEGIN
         SET @nErrNo = 66708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Quit
      END

      -- Check option selectable
      IF @cOption = '1' AND @cOutField01 = '' OR
         @cOption = '2' AND @cOutField02 = '' OR
         @cOption = '3' AND @cOutField03 = '' OR
         @cOption = '4' AND @cOutField04 = '' OR
         @cOption = '5' AND @cOutField05 = '' OR
         @cOption = '6' AND @cOutField06 = '' OR
         @cOption = '7' AND @cOutField07 = '' OR
         @cOption = '8' AND @cOutField08 = '' OR
         @cOption = '9' AND @cOutField09 = '' 
      BEGIN
         SET @nErrNo = 66709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an option
         GOTO Quit
      END
      
      -- Abstract ASN
      IF @cOption = '1' SET @cReceiptKey = SUBSTRING( @cOutField01, 4, 10) ELSE
      IF @cOption = '2' SET @cReceiptKey = SUBSTRING( @cOutField02, 4, 10) ELSE
      IF @cOption = '3' SET @cReceiptKey = SUBSTRING( @cOutField03, 4, 10) ELSE
      IF @cOption = '4' SET @cReceiptKey = SUBSTRING( @cOutField04, 4, 10) ELSE
      IF @cOption = '5' SET @cReceiptKey = SUBSTRING( @cOutField05, 4, 10) ELSE
      IF @cOption = '6' SET @cReceiptKey = SUBSTRING( @cOutField06, 4, 10) ELSE
      IF @cOption = '7' SET @cReceiptKey = SUBSTRING( @cOutField07, 4, 10) ELSE
      IF @cOption = '8' SET @cReceiptKey = SUBSTRING( @cOutField08, 4, 10) ELSE
      IF @cOption = '9' SET @cReceiptKey = SUBSTRING( @cOutField09, 4, 10)

      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = ''
      

      -- Go back to ASN/PO screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go back to ASN/PO screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg, 
       Func          = @nFunc,
       Step          = @nStep,            
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility, 
       Printer       = @cPrinter,    
       -- UserName      = @cUserName,

       V_Receiptkey  = @cReceiptkey,
       V_SKU         = @cSKU,  
       V_UOM         = @cUOM,
       V_SkuDescr    = @cDesc,
       V_String1     = @cTTLRecvQty,
       V_String2     = @cTTLQtyExpected,
       V_String3     = @cQtyReceived,
       V_String4     = @cQtyExpected,   
       V_String5     = @cPackUOM,  
       V_String6     = @cStatus,
       V_String7     = @cTotalCnt,
       V_String8     = @cRecordCnt,
       V_string9     = @cExtendedInfoSP, -- (ChewKP01)
  

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