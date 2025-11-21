SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/
/* Store procedure: rdtfnc_VASActivities                                         */
/* Copyright      : Maersk WMS                                                   */
/*                                                                               */
/* Purpose: Execute VAS Operation                                                */
/*                                                                               */
/* Version: 1.1                                                                  */
/*                                                                               */
/* Date       Rev  Author      Purposes                                          */
/* 2024-02-27 1.0  NLT013      Create   first version (UWP-15257)                */
/* 2024-08-14 1.1  LJQ006      Update   Outbound VAS (FCR-657)                   */
/* 2024-11-15 1.2  CYU027      Update   Outbound VAS (FCR-1057)                  */
/*********************************************************************************/

CREATE   PROCEDURE [rdt].[rdtfnc_VASActivities] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_Success           INT,
   @n_Err               INT,
   @c_ErrMsg            NVARCHAR( 250),
   @nInforMsgNo         INT,
   @cInforMsg           NVARCHAR(20),

   @cOption             NVARCHAR( 1),
   @cSQL                NVARCHAR( MAX),
   @cSQLParam           NVARCHAR( MAX),
   @nRowCount           INT,

-- Session variable
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,
   @cUserName           NVARCHAR( 18),
   @cStorerGroup        NVARCHAR( 20),
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cPrinter            NVARCHAR( 10),
   @cPrinter_Paper      NVARCHAR( 10),
   @nCurrentFuncID      INT, 

   @cReceiptKey         NVARCHAR( 10),
   @cReceiptLineNo      NVARCHAR( 5),
   @cServiceType        NVARCHAR( 20),
   @cReason             NVARCHAR( 10),
   @cUnit               NVARCHAR( 10),
   @cWKOrderUdef01      NVARCHAR( 18),
   @cWKOrderUdef02      NVARCHAR( 18),
   @cSKU                NVARCHAR( 20),
   @cID                 NVARCHAR( 18),
   @cGenerateCharges    NVARCHAR( 10),
   @cVASFlag            NVARCHAR( 1),                 --Y Need VAS Operation. N No need VAS operation

   @cOVASFlag           NVARCHAR( 1),                 -- Y: Outbound VAS. N: Inbound VAS
   @cOrderKey           NVARCHAR( 18),                -- Pick Order Key
   @cOrderLineNumber    NVARCHAR( 5),                 -- Pick Order Line Number
   @cPickSKU            NVARCHAR( 20),                -- Pick SKU
   @cStorerOfOrder      NVARCHAR( 15),                   -- Storer Key queried from pick detail

   @cACTVASWO           NVARCHAR( 30),

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
   @cVasCode1           NVARCHAR( 20),
   @cVasCode2           NVARCHAR( 20),
   @cVasCode3           NVARCHAR( 20),
   @cVasCode4           NVARCHAR( 20),
   @cVasCode5           NVARCHAR( 20),
   @cVasDesc1           NVARCHAR( 250),
   @cVasDesc2           NVARCHAR( 250),
   @cVasDesc3           NVARCHAR( 250),
   @cVasDesc4           NVARCHAR( 250),
   @cVasDesc5           NVARCHAR( 250),
   @cSUSR1              NVARCHAR( 20),

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerGroup = StorerGroup,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,
   @cPrinter_Paper = Printer_Paper,

   @cStorerKey  = V_StorerKey,
   @cSKU        = V_SKU,
   @cID         = V_ID,

   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,

   @cReceiptKey          = V_String1,
   @cReceiptLineNo       = V_String2,
   @cServiceType         = V_String3,
   @cReason              = V_String4,
   @cUnit                = V_String5,
   @cWKOrderUdef01       = V_String6,
   @cWKOrderUdef02       = V_String7,
   @cACTVASWO            = V_String8,
   @cOVASFlag            = V_String9, -- Outbound VAS flag state
   @cOrderKey            = V_String10,
   @cOrderLineNumber     = V_String11,
   @cPickSKU             = V_String12,
   @cVasCode1            = V_String13,
   @cVasCode2            = V_String14,
   @cVasCode3            = V_String15,
   @cVasCode4            = V_String16,
   @cVasCode5            = V_String17,
   @cVasDesc1            = V_String18,
   @cVasDesc2            = V_String19,
   @cVasDesc3            = V_String20,
   @cVasDesc4            = V_String21,
   @cVasDesc5            = V_String22,
   @cSUSR1               = V_String23,

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
FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

-- Screen constant
DECLARE
   @nStep_ID               INT,     @nScn_ID             INT,
   @nStep_LIST             INT,     @nScn_LIST           INT,
   @nStep_VASCode          INT,     @nScn_VASCode        INT

SELECT
   @nStep_ID               = 1,  @nScn_ID             = 6360,
   @nStep_LIST             = 2,  @nScn_LIST           = 6361,
   @nStep_VASCode          = 3,  @nScn_VASCode        = 6362

SELECT @nCurrentFuncID = 1157

-- Redirect to respective screen
IF @nFunc = @nCurrentFuncID
BEGIN
   IF @nStep = 0                GOTO Step_0         -- Func = 1157. Menu
   IF @nStep = @nStep_ID        GOTO Step_ID        -- Scn  = 6360. ID
   IF @nStep = @nStep_LIST      GOTO Step_LIST      -- Scn  = 6361. VAS List
   IF @nStep = @nStep_VASCode   GOTO Step_VASCode   -- Scn  = 6362. Enter/Scan VAS Code
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1157. Menu
   @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   -- EventLog
   EXEC rdt.rdt_STD_EventLog
      @cActionType = '1', -- Sign-in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey

   -- Init var (due to var pass out by decodeSP, GetReceiveInfoSP is not reset)
   SELECT @cID = '', @cSKU = '', 
      @cLottable01 = '', @cLottable02 = '', @cLottable03 = '', @dLottable04 = 0,  @dLottable05 = 0,
      @cLottable06 = '', @cLottable07 = '', @cLottable08 = '', @cLottable09 = '', @cLottable10 = '',
      @cLottable11 = '', @cLottable12 = '', @dLottable13 = 0,  @dLottable14 = 0,  @dLottable15 = 0
   SELECT   @cVasCode1            = '',
            @cVasCode2            = '',
            @cVasCode3            = '',
            @cVasCode4            = '',
            @cVasCode5            = '',
            @cVasDesc1            = '',
            @cVasDesc2            = '',
            @cVasDesc3            = '',
            @cVasDesc4            = '',
            @cVasDesc5            = ''
   -- Prepare next screen var
   SET @cOutField01 = '' -- ID

   -- Set the entry point
   SET @nScn = @nScn_ID
   SET @nStep = @nStep_ID
END
GOTO Quit


/********************************************************************************
Step_ID (Step1). Scn = 6360. ID screen
   ID           (field01, input)
********************************************************************************/
Step_ID:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cID = @cInField01

     -- Check if the ID is NULL or empty
      IF (@cID = '' OR @cID IS NULL)
      BEGIN
         SET @nErrNo = 211701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
         GOTO Step_ID_Fail
      END
      
      -- FCR-657 Modified by LJQ006
      -- Check if the Pallet ID exists in the pickdetail DropID or PalletID field in the Picked Status
      SELECT @nRowCount = COUNT(*)
      FROM dbo.PICKDETAIL WITH(NOLOCK)
      WHERE (DropID = @cID OR ID = @cID)



      IF @nRowCount > 0
      -- add validation of storer key and it's error message
      -- cause combined message is too long to display on RDT
      BEGIN
         SELECT 
            @nRowCount = COUNT(1)
         FROM dbo.PICKDETAIL WITH(NOLOCK)
         WHERE (DropID = @cID OR (DropId IS NULL AND ID = @cID))
         AND Storerkey <> @cStorerKey
         AND Status = 5

         IF @nRowCount > 0
         BEGIN 
            SET @nErrNo = 211721
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Storer Key
            GOTO Step_ID_Fail
         END

         SELECT
            @nRowCount = COUNT(1)
         FROM dbo.PICKDETAIL WITH(NOLOCK)
         WHERE DropID IS NOT NULL
         AND DropID <> @cID
         AND ID = @cID
         AND StorerKey = @cStorerKey
         AND Status = 5

         IF @nRowCount > 0
         BEGIN
            -- consolidation validating (pallet move)
            SELECT
               @nRowCount = COUNT(1)
            FROM rdt.rdtSTDEventlog rse WITH(NOLOCK)
            INNER JOIN dbo.PICKDETAIL pd WITH(NOLOCK) ON rse.Orderkey = pd.OrderKey
            WHERE FunctionID = '1813'
            AND ToID = @cID

            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 211722
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Please Use Drop ID Instead
               GOTO Step_ID_Fail
            END

            -- for drop id moves to ToID 
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cOrderLineNumber = OrderLineNumber,
               @cPickSKU = SKU
            FROM dbo.PICKDETAIL WITH(NOLOCK)
            WHERE DropID <> @cID 
            AND ID = @cID
            AND Storerkey = @cStorerKey
            AND Status = 5
            SET @nRowCount = @@ROWCOUNT
         END
         ELSE
         BEGIN
            SELECT TOP 1
               @cOrderKey = OrderKey,
               @cOrderLineNumber = OrderLineNumber,
               @cPickSKU = SKU
            FROM dbo.PICKDETAIL WITH(NOLOCK)
            WHERE (DropID = @cID OR (DropId IS NULL AND ID = @cID))
            AND Storerkey = @cStorerKey
            AND Status = 5
            SET @nRowCount = @@ROWCOUNT
         END

         -- Add err message on checking if the ID exists in pickdetail
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 211718
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID not exists
            GOTO Step_ID_Fail
         END

         -- Set flag (Optional, only if using Step_VASCode), jump to Step_VASCode or a new step for outbound VAS scenario
         IF @nRowCount > 0
         BEGIN
            SET @cOVASFlag = 1
         END

         -- RDT StorerConfig 'ACTVASWO'  
         SET @cACTVASWO = rdt.RDTGetConfig (@nCurrentFuncID, 'ACTVASWO', @cStorerKey )  
         
         IF ISNULL(RTRIM(@cACTVASWO),'') = '0'  
         BEGIN  
            SET @nErrNo = 211715
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP' ) --RDT Storer Config ACTVASWO not configured
            GOTO Step_VASCode_Fail
         END

         SELECT TOP 1
            @cSUSR1 = LTRIM(RTRIM(s.SUSR1))
         FROM dbo.STORER s (NOLOCK)
                 JOIN dbo.ORDERS (NOLOCK) o ON o.consigneekey = s.storerkey
         WHERE o.OrderKey = @cOrderKey
         
         IF @@rowcount = 0
            SET @cSUSR1 = ''
         

         IF @cOVASFlag = 1 AND ISNULL(@cSUSR1,'') <> ''-- OUTBOUND ONLY
         BEGIN
            --Prepare Vas Code List For Next Screen, Start

            DECLARE @vasList TABLE
            (
               Code NVARCHAR( 30),
               Description NVARCHAR( 250),
               RowRef INT IDENTITY(1,1) NOT NULL
            )

            INSERT INTO @vasList (Code, Description)
            SELECT TOP 5 CODE2, Description
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE Storerkey     = @cStorerKey
              AND Code         = @cSUSR1
              AND LISTNAME     = 'VASPROFILE'
            ORDER BY CODE2

            SELECT @cVasCode1 = Code, @cVasDesc1 = Description FROM @vasList WHERE RowRef = 1
            SELECT @cVasCode2 = Code, @cVasDesc2 = Description FROM @vasList WHERE RowRef = 2
            SELECT @cVasCode3 = Code, @cVasDesc3 = Description FROM @vasList WHERE RowRef = 3
            SELECT @cVasCode4 = Code, @cVasDesc4 = Description FROM @vasList WHERE RowRef = 4
            SELECT @cVasCode5 = Code, @cVasDesc5 = Description FROM @vasList WHERE RowRef = 5

            IF ISNULL(@cVasCode1, '') = ''
            BEGIN
               SET @nErrNo = 211723
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NO VAS activities for VAS Profile'
               GOTO Step_VASCode_Fail
            END

            IF ISNULL(@cVasCode1,'') <> '' SET @cOutField01 = '1.'+@cVasCode1+'-'+@cVasDesc1
            IF ISNULL(@cVasCode2,'') <> '' SET @cOutField02 = '2.'+@cVasCode2+'-'+@cVasDesc2
            IF ISNULL(@cVasCode3,'') <> '' SET @cOutField03 = '3.'+@cVasCode3+'-'+@cVasDesc3
            IF ISNULL(@cVasCode4,'') <> '' SET @cOutField04 = '4.'+@cVasCode4+'-'+@cVasDesc4
            IF ISNULL(@cVasCode5,'') <> '' SET @cOutField05 = '5.'+@cVasCode5+'-'+@cVasDesc5

            SET @nScn  = @nScn_LIST
            SET @nStep = @nStep_LIST

         END
         ELSE
         BEGIN

            -- Prepare next screen var
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''

            -- Go to next screen
            SET @nScn  = @nScn_VASCode
            SET @nStep = @nStep_VASCode
         END
         SET @cOutField06 = ''

         GOTO Quit
      END
      
      -- Check if the ID exists
      SELECT 
         @cVASFlag = ISNULL( dia.Lottable10, '-'),
         @cReceiptKey = rd.ExternReceiptKey,
         @cReceiptLineNo = rd.ExternLineNo,
         @cSKU = inv.Sku
      FROM RECEIPTDETAIL AS rd WITH(NOLOCK)
      INNER JOIN LOTxLOCxID AS inv WITH(NOLOCK)
         ON rd.StorerKey = inv.StorerKey
         AND rd.ToId = inv.Id
      INNER JOIN LOTATTRIBUTE AS dia WITH(NOLOCK)
         ON inv.Lot = dia.Lot
      WHERE inv.StorerKey = @cStorerKey
         AND inv.Id = @cID

      SELECT @nRowCount = @@ROWCOUNT

      IF @nRowCount = 0
     BEGIN
        SET @nErrNo = 211702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not Exist
         GOTO Step_ID_Fail
     END

     -- Check if it is marked as VAS Required
     IF @cVASFlag <> 'Y'
     BEGIN
        SET @nErrNo = 211703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID not Require VAS
         GOTO Step_ID_Fail
     END

     -- RDT StorerConfig 'ACTVASWO'  
      SET @cACTVASWO = rdt.RDTGetConfig (@nCurrentFuncID, 'ACTVASWO', @cStorerKey )  
      IF ISNULL(RTRIM(@cACTVASWO),'') = '0'  
      BEGIN  
         SET @nErrNo = 211715
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP' ) --RDT Storer Config ACTVASWO not configured
         GOTO Step_VASCode_Fail
      END

      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''

      -- Go to next screen
      SET @nScn  = @nScn_VASCode
      SET @nStep = @nStep_VASCode
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
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_ID_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = '' -- ID
      SET @cID         = ''

     -- Go back to current screen again
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID
   END
END
GOTO Quit

/********************************************************************************
Step 2. scn = 6422
      List of VAS Activities
      1.VAS-Desc       (field01)
      2.VAS-Desc       (field02)
      3.VAS-Desc       (field03)
      4.VAS-Desc       (field04)
      5.VAS-Desc       (field05)
      OPTION:        (field06 INPUT)
********************************************************************************/
Step_LIST:
BEGIN

   IF @nInputKey = 1
   BEGIN

      --SELECT VAS CODE, start

      DECLARE @dFlag int
      IF @cInField06 NOT IN ('1','2','3','4','5')
      BEGIN
         SET @dFlag = 1
      END
      ELSE
      BEGIN
         SET @cSql =
                 'IF @cVasCode' + @cInField06 + ' <> '''' '
                    + '  SET @cOutField01 = @cVasCode' + @cInField06 +' '
                    + 'ELSE '
                    + '  SET @dFlag = 1'

         SET @cSQLParam =
                 '@cVasCode1      NVARCHAR( 60),      ' +
                 '@cVasCode2      NVARCHAR( 60),      ' +
                 '@cVasCode3      NVARCHAR( 60),      ' +
                 '@cVasCode4      NVARCHAR( 60),      ' +
                 '@cVasCode5      NVARCHAR( 60),      ' +
                 '@cOutField01    NVARCHAR( 60) OUTPUT,'+
                 '@dFlag          INT           OUTPUT'

         EXEC sp_ExecuteSQL @cSql, @cSQLParam,
              @cVasCode1, @cVasCode2,
              @cVasCode3, @cVasCode4,
              @cVasCode5, @cOutField01 OUTPUT, @dFlag OUTPUT
      END

      IF @dFlag = 1
      BEGIN
         SET @nErrNo = 211725
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidVasCode
         GOTO Step_List_Fail
      END
      --SELECT VAS CODE, end

      --Vas compeleted List
      DECLARE @compeletList TABLE
      (
        Code NVARCHAR( 20),
        RowRef INT IDENTITY(1,1) NOT NULL
      )

      INSERT INTO @compeletList
      SELECT DISTINCT(wod.Type+'-'+ck.Description)
         FROM dbo.WorkOrder wo WITH(NOLOCK)
            INNER JOIN dbo.WorkOrderDetail wod WITH(NOLOCK)
               ON wo.StorerKey     = wod.StorerKey
               AND wo.WorkOrderKey = wod.WorkOrderKey
         LEFT JOIN CODELKUP ck WITH(NOLOCK) ON wod.Type = code2 AND ck.Storerkey = @cStorerKey AND ck.Code = @cSUSR1 AND LISTNAME     = 'VASPROFILE'
      WHERE wo.Facility                               = @cFacility
         AND wo.StorerKey                             = @cStorerKey
         AND ISNULL(wo.ExternWorkOrderKey, '-1')      = @cOrderKey
         AND ISNULL(wod.ExternLineNo, '-1')           = @cOrderLineNumber
         AND ISNULL(wod.WkOrdUdef1, '-1')             = @cID
         AND wod.status                               = 9   -- compelet
      ORDER BY wod.Type+'-'+ck.Description

      IF EXISTS (
         SELECT 1 FROM @compeletList
      )
      BEGIN
         SET @cOutField04 = 'Vas Completed: '

         SELECT @cOutField05 = '1. '+Code FROM @compeletList WHERE RowRef = 1
         SELECT @cOutField06 = '2. '+Code FROM @compeletList WHERE RowRef = 2
         SELECT @cOutField07 = '3. '+Code FROM @compeletList WHERE RowRef = 3
         SELECT @cOutField08 = '4. '+Code FROM @compeletList WHERE RowRef = 4
         SELECT @cOutField09 = '5. '+Code FROM @compeletList WHERE RowRef = 5


      END

      --Vas compeleted List, end


      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @nScn  = @nScn_VASCode
      SET @nStep = @nStep_VASCode

   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = ''

      --Go back to previous screen
      SET @nScn  = @nScn_ID
      SET @nStep = @nStep_ID
   END
   GOTO Quit


   Step_List_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField06     = '' -- Option
   END
   GOTO Quit

END


/********************************************************************************
Step_VASCode (Step 3). Scn = 6362. VAS Code screen
   Scn/Enter VAS Code   (field01)
   Enter: Next Scan
   Press 0 to Done
   OPTION:  (field01, input)
********************************************************************************/
Step_VASCode:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @cServiceType     = @cInField01
      SET @cOption          = @cInField02

      SET @cWKOrderUdef01 = @CID
      SET @cGenerateCharges = 'YES'   --Always be YES

      --Check if VAS Code and Option are empty
      IF (@cServiceType IS NULL OR LEN(TRIM(@cServiceType)) = 0)
         OR 
         (@cOption IS NULL OR LEN(TRIM(@cOption)) = 0)
      BEGIN
         SET @nErrNo = 211726
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedOptionAndVasCode
         GOTO Step_VASCode_Fail
      END

      -- FCR-657 Modified by LJQ006
      -- OVAS scenario
      IF @cOVASFlag = 1
      BEGIN
         IF (@cServiceType IS NOT NULL AND LEN(TRIM(@cServiceType)) > 0)
         BEGIN
            -- Check if OVAS code master data were configured or not
            SELECT 
            @nRowCount = COUNT(1)
            FROM dbo.CODELKUP WITH(NOLOCK)
            WHERE Storerkey     = @cStorerKey
            AND LISTNAME     = @cACTVASWO
            AND Code         = @cServiceType
            AND UDF01        = @cFacility
            AND code2        = 'OVAS'
         END
            
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 211719
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OVAS Code Invalid
            GOTO Step_VASCode_Fail
         END

         -- Check option
         IF (@cOption IS NOT NULL AND LEN(TRIM(@cOption)) > 0)
         BEGIN
            IF @cOption <> '0'
            BEGIN
               SET @nErrNo = 211704
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP' ) --Invalida Option
               GOTO Step_VASCode_Fail
            END
         END

         IF (@cServiceType IS NOT NULL AND LEN(TRIM(@cServiceType)) > 0)
         BEGIN
            -- Create Work Order if everything is good
            EXEC rdt.rdt_CreateVASWorkOrder @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, 
               '', 
               '',
               @cOrderKey,
               @cOrderLineNumber,
               '',
               @cWKOrderUdef01,
               @cGenerateCharges,
               @cServiceType,
               @cPickSKU,
               @cACTVASWO,
               2,                     --1. Inbound    2. Outbound
               @nErrNo     OUTPUT,
               @cErrMsg    OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_VASCode_Fail
            END

            SET @nInforMsgNo = 211717
            SET @cInforMsg = rdt.rdtgetmessage( @nInforMsgNo, @cLangCode, 'DSP') --Create WorkOrder Success
            SET @cOutField03 = @cInforMsg
         END

         IF (@cOption IS NOT NULL AND TRIM(@cOption) = '0')
         BEGIN
            -- Finalize Work
            EXEC rdt.rdt_FinalizeVASWorkOrder @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, 
               @cWKOrderUdef01,
               @nErrNo     OUTPUT,
               @cErrMsg    OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_VASCode_Fail
            END

            -- Prepare prev screen var
            SET @cOutField01 = ''
            SET @cOVASFlag = ''
            -- Go back to previous screen
            SET @nScn  = @nScn_ID
            SET @nStep = @nStep_ID
            GOTO Quit
         END
         -- Prepare next screen var
         SET @cOutField01 = ''
         SET @cOutField02 = ''

         -- Go to next screen
         SET @nScn  = @nScn_VASCode
         SET @nStep = @nStep_VASCode  
         GOTO Quit  
      END
      
      --Check VAS Code
      IF (@cServiceType IS NOT NULL AND LEN(TRIM(@cServiceType)) > 0)
      BEGIN
         --Check if VAS code master data were configured or not
         SELECT 
            @nRowCount = COUNT(1)
         FROM dbo.CODELKUP WITH(NOLOCK)
         WHERE Storerkey     = @cStorerKey
            AND LISTNAME     = @cACTVASWO
            AND Code         = @cServiceType
            AND UDF01        = @cFacility

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 211706
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --VAS Code not Exist
            GOTO Step_VASCode_Fail
         END
      END

      -- Check option
      IF (@cOption IS NOT NULL AND LEN(TRIM(@cOption)) > 0)
      BEGIN
         IF @cOption <> '0'
         BEGIN
            SET @nErrNo = 211704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP' ) --Invalida Option
            GOTO Step_VASCode_Fail
         END
      END

      IF (@cServiceType IS NOT NULL AND LEN(TRIM(@cServiceType)) > 0)
      BEGIN
         -- Create Work Order if everything is good
         EXEC rdt.rdt_CreateVASWorkOrder @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, 
            @cReceiptKey, 
            @cReceiptLineNo,
            '',
            '',
            '',
            @cWKOrderUdef01,
            @cGenerateCharges,
            @cServiceType,
            @cSKU,
            @cACTVASWO,
            1,                     --1. Inbound    2. Outbound
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_VASCode_Fail
         END

         SET @nInforMsgNo = 211717
         SET @cInforMsg = rdt.rdtgetmessage( @nInforMsgNo, @cLangCode, 'DSP') --Create WorkOrder Success
         SET @cOutField03 = @cInforMsg
      END

      IF (@cOption IS NOT NULL AND TRIM(@cOption) = '0')
      BEGIN
         -- Finalize Work
         EXEC rdt.rdt_FinalizeVASWorkOrder @nFunc, @nMobile, @cLangCode, @cStorerKey, @cFacility, 
            @cWKOrderUdef01,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Step_VASCode_Fail
         END

         GOTO Step_ID_OR_LIST
      END
      
      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''

      -- Go to next screen
      SET @nScn  = @nScn_VASCode
      SET @nStep = @nStep_VASCode
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField06 = ''

      GOTO Step_ID_OR_LIST

   END


   Step_ID_OR_LIST:
   BEGIN
      IF @cOVASFlag = 1 AND ISNULL(@cSUSR1,'') <> ''
      BEGIN

         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         SET @cOutField05 = ''

         --GOTO LIST SCN
         IF ISNULL(@cVasCode1,'') <> '' SET @cOutField01 = '1. '+@cVasCode1+'-'+@cVasDesc1
         IF ISNULL(@cVasCode2,'') <> '' SET @cOutField02 = '2. '+@cVasCode2+'-'+@cVasDesc2
         IF ISNULL(@cVasCode3,'') <> '' SET @cOutField03 = '3. '+@cVasCode3+'-'+@cVasDesc3
         IF ISNULL(@cVasCode4,'') <> '' SET @cOutField04 = '4. '+@cVasCode4+'-'+@cVasDesc4
         IF ISNULL(@cVasCode5,'') <> '' SET @cOutField05 = '5. '+@cVasCode5+'-'+@cVasDesc5

         SET @nScn  = @nScn_LIST
         SET @nStep = @nStep_LIST

      END
      ELSE
      BEGIN
         --GOTO ID SCN
         SET @cOutField01 = ''

         --Go back to previous screen
         SET @nScn  = @nScn_ID
         SET @nStep = @nStep_ID

      END
   END

   GOTO Quit

   Step_VASCode_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01     = '' -- VAS Code, service type
      SET @cOutField02     = '' -- Option
      SET @cOutField03     = '' -- Information
      SET @cServiceType    = ''
      SET @cOption         = ''
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate     = GETDATE(),
      ErrMsg       = @cErrMsg,
      Func         = @nFunc,
      Step         = @nStep,
      Scn          = @nScn,
      Facility     = @cFacility,
      Printer      = @cPrinter,

      V_StorerKey  = @cStorerKey,
      V_ID         = @cID,
      V_SKU        = @cSKU,
      V_String1    = @cReceiptKey,
      V_String2    = @cReceiptLineNo,
      V_String3    = @cServiceType,
      V_String4    = @cReason,
      V_String5    = @cUnit,
      V_String6    = @cWKOrderUdef01,
      V_String7    = @cWKOrderUdef02,
      V_String8    = @cACTVASWO,
      V_String9    = @cOVASFlag, -- Outbound VAS flag state
      V_String10   = @cOrderKey,
      V_String11   = @cOrderLineNumber,
      V_String12   = @cPickSKU,
      V_String13   = @cVasCode1,
      V_String14   = @cVasCode2,
      V_String15   = @cVasCode3,
      V_String16   = @cVasCode4,
      V_String17   = @cVasCode5,
      V_String18   = @cVasDesc1,
      V_String19   = @cVasDesc2,
      V_String20   = @cVasDesc3,
      V_String21   = @cVasDesc4,
      V_String22   = @cVasDesc5,
      V_String23   = @cSUSR1,


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

     I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15 
   WHERE Mobile = @nMobile
END


GO