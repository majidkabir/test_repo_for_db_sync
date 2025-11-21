SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure:  nspRFRC01                                             */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:  RF Receive 01                                                 */
/*                                                                         */
/* Input Parameters:                                                       */
/*                                                                         */
/* Output Parameters:  None                                                */
/*                                                                         */
/* Return Status:  None                                                    */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 2.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.   Purposes                                  */
/* 22-Apr-2003  Shong            Add back LFDM Customization that missing  */
/*                               after version 5.0 convertion (SOS10770)   */
/* 24-Sep_2003  June             Remove checking on Work Order# in         */
/*                               configkey 'LFDMLabel' (SOS15116)          */
/* 04-Nov-2003  Shong            SOS# Swap lottables for IDSMY             */
/* 30-Apr-2004  June             Bug fix for DisallowduplicateID(SOS22596) */
/* 26-May-2004  Shong            To modify RF Receiving program to be able */
/*                               validate on lottable02 to make sure no    */
/*                               duplicate (SOS20205)                      */
/* 14-Jan-2005  YTWan            C4 RFNormal &  Xdock Receiving            */
/* 03-Feb-2005  YTWan            Sku Enquiry feature for C4                */
/* 18-Feb-2005  MaryVong         Update Receipt Date for Lottable05 for    */
/*                               records being Finalized (SOS28761)        */
/* 17-Jun-2005  UngDH            SOS# 36848 C4MY Update UserDefine10 =     */
/*                               EditWho, only for receiving. Finalize     */
/*                               should not overwrite the UserDefine10     */
/* 07-Jul-2005  UngDH            SOS 36845 Auto populate C4RFXDOCK loc     */
/* 27-May-2005  UngDH            Created (duplicate from nspRFRC01)        */
/* 05-Oct-2005  UngDH            SOS 40951 key valid date on lottable04    */
/*                               but err msg prompted (misuse of convert())*/
/* 07-Dec-2005 UngDH            SOS# 43730 Added storer config for RDT    */
/*   "RDT_FinalizeReceiptDetail"               */
/* 15-Feb-2006  UngDH            SOS# 46199 change the behavior of storer  */
/*                               config "RDT_FinalizeReceiptDetail" to     */
/*                               default as auto finalize if not setup     */
/* 19-Jun-2006  UngDH            Rollback changes of SOS28761              */
/* 06-Jul-2006  UngDH            SOS54328 SKU.SUSR4 sometimes contain non  */
/*                               numeric, when it does not use for the     */
/*                               purpose of tolerance%                     */
/* 04-Nov-2007  Shong            Changing the Receipt Line Lookup Logic    */
/*                               Not allow overwriten for 2nd receipt for  */
/*                               Same SKU (SHONG001)                       */
/* 12-Nov-2007  Vicky            To prevent QtyExpected to have NULL value,*/
/*                               use ISNULL function                       */
/* 19-Now-2007  Shong            Change Variable @n_variance to float      */
/*                               Otherwise the calculation will be wrong.  */
/* 27-Nov-2007  James            Bug fix - prevent SUSR1 to have conversion*/
/*                               error when calc shell life                */
/* 11-Jul-2008  Shong            Bug fix - QtyExpected & BeforeReceivedQty */
/* 14-Jul-2008  Shong            Fixing the CURSOR_RECEIPT bug for Lottable*/
/*                               04 Statement SHONG002                     */
/*                               when over received (SHONG002)             */
/* 17-Jul-2008  Shong            Wrong Expected Qty (SHONG003)             */
/* 05-Aug-2008  Leong            SOS# 111949 - Copy UserDefine 01 - 10     */
/* 23-Sep-2008  KC        1.2    SOS# 115735 - Pass facility to nspGetRight*/
/* 22-Dec-2008  Leong01   1.3    Bug fix for SOS# 115735 and SOS#126781    */
/* 28-Apr-2009  Vicky     1.4    SOS#105912 - Fix exact match receiptline  */
/*                               with same ToID and Lottables              */
/*                               Bug fix on 'DisAllowDuplicateSerialNo'    */
/*                               Configkey check, should filter by Storer  */
/*                               SOS#137512 - To copy Externkeys and POkey */
/*                               when copy lines                           */
/*                               (Vicky01)                                 */
/* 28-May-2009  James     1.5    SOS137640 Auto hold by lot if             */
/*                               sku.receiptholdcode = 'HMCE'              */
/* 01-Jun-2009  James     1.6    SOS133226 Gen Lot2 with ASN_ASNLineno     */
/*                               when 'GenLot2withASN_ASNLineNo' turned on */
/*                               (james01)                                 */
/* 16-Jun-2009  Rick Liew 1.7    SOS#96737 - Remove hardcoding for         */
/*                                Configkey C4RFXDOCK (Rick01              */
/* 29-Jun-2009  Shong     1.8    Fixed Receipt Line Lookup Logic           */
/* 17-Jul-2009  Vicky     1.9    Bug Fix  (Vicky02)                        */
/* 24-Jul-2009  James     2.0    Bug fix (james02)                         */
/* 18-Jul-2009  Vicky     2.1    SOS#142253 - Add in new StorerConfigkey   */
/*                               for XDock Process to copy Lottable03      */
/*                               - Add in Receipt.DocType for C4RFXDOCK    */
/*                                 Configkey (Vicky03)                     */
/* 15-Mar-2010  Vanessa   2.2    SOS#164544 Allow QTY in decimal and       */
/*                               DefaultLOC -- (Vanessa01)              */
/* 17-Jun-2010  SPChin    2.3    SOS#177773 - Set default ConditionCode    */
/* 05-Jul-2010  Vicky     2.4    SOS#178988 - Only look at Lottable03 when */
/*                               offset (Vicky04)                          */
/* 22-Jul-2010  Leong     2.5    SOS#182721 - Match Lottable03 when split  */
/*                                            detail line                  */
/* 24-Jul-2010  Vicky     2.6    Recalculate OpenQTY & Update ASNStatus if */
/*                               Finalize from RDT Flag is turned on       */
/*                               (Vicky07)                                 */
/* 13-Aug-2010  Audrey    2.7    SOS#185727 - Add in checking on POKEY     */
/*                                                             (ang01)     */
/* 19-Aug-2010  Shong     2.8    If qtyreceived < qtyexpected in one of the*/
/*                               RD line, not allow finalize               */
/* 02-Sep-2010  Shong     2.9    Revise QtyExpected Updating  (SHONG004)   */
/* 06-Jan-2011  ChewKP    3.0    SOS#189788 Match Receiving by ID only     */
/*                               (ChewKP01)                                */
/* 27-Oct-2011  Shong     3.1    Fixing Qty Expected SHONG005              */
/* 01-Nov-2011  Shong     3.2    Fixing Qty Expected (james03)             */
/* 14-Mar-2012  Ung       3.3    SOS238181 Fix QTYExpected reduced from    */
/*                               parent but not increase to itself         */
/* 29-Jun-2012  Ung       3.4    SOS248941 Fix var not initialize (ung01)  */
/* 12-Apr-2013  James     3.5    Bug fix on Lottable04 filter (james04)    */
/* 02-OCT-2013  James     3.6    Bug fix on Lottable04 filter (james05)    */
/* 26-Nov-2013  TLTING    3.7    Change user_name() to SUSER_SNAME()       */
/* 13-Aug-2014  SPChin    3.8    SOS318197 - Bug Fixed                     */
/* 25-Aug-2014  Leong     3.9    SOS# 319429 - Revise check ID logic.      */
/* 04-SEP-2014  James     4.0    Add AltSKU when INSERT new line (james06) */
/* 22-SEP-2014  SPChin    4.1    SOS315152 Add ISNULL Checking             */
/* 02-Oct-2014  Ung       4.2    SOS317798 Futher fix on SOS177773         */
/* 16-Jan-2015  CSCHONG   5.0    New lottable 05 to 15 (CS01)              */
/* 07-Sep-2015  NJOW01    5.1    350966-skip hold id if auto hold id is    */
/*                               enabled at asn finalize.                  */
/* 16-Aug-2017  JihHaur   5.2    IN00436436 Null value in ReceiptPOLineNumber*/
/*                               causing QtyExpected, ReceivedQty become null*/
/* 24-Jan-2017  Ung       5.3    Fix recompile due to date format different*/
/* 08-Feb-2018  SWT01     5.4    Adding Paramater Variable to Calling SP   */
/* 05-May-2019  LZG       5.5    INC0683477 Extend the length of @c_command*/
/*                               to fix exception (ZG01)                   */
/***************************************************************************/
CREATE PROC [dbo].[nspRFRC01]
     @c_sendDelimiter    NVARCHAR(1)
   , @c_ptcid            NVARCHAR(5)
   , @c_userid           NVARCHAR(10)
   , @c_taskId           NVARCHAR(10)
   , @c_databasename     NVARCHAR(30)
   , @c_appflag          NVARCHAR(2)
   , @c_recordType       NVARCHAR(2)
   , @c_server           NVARCHAR(30)
   , @c_receiptkey       NVARCHAR(10)
   , @c_storerkey        NVARCHAR(15)
   , @c_prokey           NVARCHAR(10)
   , @c_sku              NVARCHAR(30)
   , @c_lottable01       NVARCHAR(18)
   , @c_lottable02       NVARCHAR(18)
   , @c_lottable03       NVARCHAR(18)
   , @c_lottable04       NVARCHAR(30)
   , @c_lottable05       NVARCHAR(30)
   , @c_Lottable06       NVARCHAR(30)   = ''
   , @c_Lottable07       NVARCHAR(30)   = ''
   , @c_Lottable08       NVARCHAR(30)   = ''
   , @c_Lottable09       NVARCHAR(30)   = ''
   , @c_Lottable10       NVARCHAR(30)   = ''
   , @c_Lottable11       NVARCHAR(30)   = ''
   , @c_Lottable12       NVARCHAR(30)   = ''
   , @d_Lottable13       DATETIME       = NULL
   , @d_Lottable14       DATETIME       = NULL
   , @d_Lottable15       DATETIME       = NULL
   , @c_lot              NVARCHAR(10)
   , @c_pokey            NVARCHAR(10)
   , @n_qty              Float    -- (Vanessa01)
   , @c_uom              NVARCHAR(10)
   , @c_packkey          NVARCHAR(10)
   , @c_loc              NVARCHAR(10)
   , @c_id               NVARCHAR(18)
   , @c_holdflag         NVARCHAR(10)
   , @c_other1           NVARCHAR(20)
   , @c_other2           NVARCHAR(20)
   , @c_other3           NVARCHAR(20)
   , @c_outstring        NVARCHAR(255)  OUTPUT
   , @b_Success          int        OUTPUT
   , @n_err              int        OUTPUT
   , @c_errmsg           NVARCHAR(250)  OUTPUT
 AS
 BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   -- Shong001
--   DECLARE @cCursorStatement NVARCHAR(8000)
   DECLARE @cCursorStatement NVARCHAR(MAX)   -- Vicky01
         , @c_CursorReceiptDetail nvarchar(MAX) -- SOS#182721
         , @c_ExecArguments       nvarchar(MAX) -- SOS#183324
         , @d_lottable04       DATETIME
         , @d_lottable05       DATETIME

   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF LEFT(@c_taskId,2) = 'DS'
   BEGIN
        SELECT @b_debug = CAST(SUBSTRING(@c_taskId, 3, 1) as int)
   END
   IF @b_debug = 1
   BEGIN
      SELECT  @c_receiptkey "@c_receiptkey",  @c_storerkey "@c_storerkey",
              @c_prokey "@c_prokey",          @c_sku "@c_sku",
              @c_lottable01 "@c_lottable01",  @c_lottable02 "@c_lottable02",
              @c_lottable03 "@c_lottable03",  @c_lottable04 "@c_lottable04",
              @c_lottable05 "@c_lottable05",  @c_lot "@c_lot",
              @c_pokey "@c_pokey",            @n_qty "@n_qty",
              @c_uom "@c_uom",                @c_packkey "@c_packkey",
              @c_loc "@c_loc",                @c_id "@c_id",
              @c_holdflag "@c_holdflag"
   END
   DECLARE  @n_continue int        ,  /* continuation flag
                                           1=Continue
                     2=failed but continue processsing
                                           3=failed do not continue processing
                                           4=successful but skip furthur processing */
            @n_starttcnt int        , -- Holds the current transaction count
            @c_preprocess NVARCHAR(250) , -- preprocess
            @c_pstprocess NVARCHAR(250) , -- post process
            @n_err2 int               -- For Additional Error Detection
   /* Declare RF Specific Variables */
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int
   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"
   SELECT @n_returnrecs=1
   /* RC01 Specific Variables */
   DECLARE  @c_itrnkey               NVARCHAR(10),
            @n_toqty                 int,
            @c_NoDuplicateIdsAllowed NVARCHAR(10),
            @c_tariffkey             NVARCHAR(10),
            @c_ReceiptLineNumber     NVARCHAR(5),
            @c_prevlinenumber        NVARCHAR(5),
            @c_multiline             NVARCHAR(1)

   SELECT @c_prevlinenumber = master.dbo.fnc_GetCharASCII(14), @c_multiline = '0'

   /* 29-Nov-2004 YTWan RF Xdock Receiving - START */
   /* Declare Variable */
   Declare @c_configkey NVARCHAR(10),
           @c_sValue NVARCHAR(10),
           @c_externlineno  NVARCHAR(20),
           @c_externreceiptkey NVARCHAR(20),
           @c_polineno NVARCHAR(5),
           @c_externpokey NVARCHAR(20),
           @c_origreceiptlineno NVARCHAR(5)

   Declare @c_InventoryHoldKey NVARCHAR(10),   --(james01)
           @c_CodeLKUp         NVARCHAR(30),
           @c_Reason           NVARCHAR(255)

   DECLARE @cOpenQtyCalc       NVARCHAR(1) -- (Vicky07)
   DECLARE @cAltSKU            NVARCHAR(20) --(james06)

   SET @cOpenQtyCalc = 'N' -- (Vicky07)
   BEGIN TRAN

  /* 29-Nov-2004 YTWan RF Xdock Receiving - END */

   /*
      SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - start

      Storer config 'RDT_FinalizeReceiptDetail'
      ON  = beheave like base receiving (receive into QTYReceived, FinalizedFlag = 'Y')
      OFF = beheave like IDS  receiving (receive into BeforeReceivedQty, FinalizeFlag = 'N')

      RDT_FinalizeReceiptDetail should work regardless of Allow_OverReceipt and ByPassTolerance:
      RDT_FinalizeReceiptDetail = ON (base)
         Allow_OverReceipt, ByPassTolerance = handle in ntrReceiptDetailAdd and ntrReceiptDetailUpdate
      RDT_FinalizeReceiptDetail = OFF (IDS)
         Allow_OverReceipt, ByPassTolerance = handle in nspRFRC01
   */

   DECLARE @cRDT_NotFinalizeReceiptDetail NVARCHAR( 1)
   DECLARE @cAllow_OverReceipt            NVARCHAR( 1)
   DECLARE @cByPassTolerance              NVARCHAR( 1)
   DECLARE @nTolerancePercentage          INT
   DECLARE @cReceiptInspectionLoc         NVARCHAR(10) -- SHONG001
   DECLARE @cDuplicateFrom                NVARCHAR( 5) -- SHONG001
   DECLARE @cMatchID_Lot                  NVARCHAR( 1) -- Vicky01
   DECLARE @cGenLot2withASN_ASNLineNo     NVARCHAR( 1) -- james01
   DECLARE @cCopyKeys                     NVARCHAR( 1) -- Vicky01

   DECLARE @cDocType                      NVARCHAR( 1), -- Vicky02
           @cXD_Lot3                      NVARCHAR( 1), -- Vicky02
           @cMatch_Lot3                   NVARCHAR( 1), -- Vicky04
           @cMatchID                      NVARCHAR( 1)  -- (ChewKP01)

   SET @cRDT_NotFinalizeReceiptDetail = '0' -- Default to finalize
   SET @cAllow_OverReceipt = '0'
   SET @cByPassTolerance = '0'
   SET @nTolerancePercentage = 0

   SET @cMatchID_Lot = '0' -- Vicky01
   SET @cGenLot2withASN_ASNLineNo = '0' -- james01
   SET @cXD_Lot3 = '0' -- Vicky02

   SET @cMatch_Lot3 = '0' -- Vicky04
   SET @cMatchID = '0' -- (ChewKP01)

   -- Storer config 'RDT_FinalizeReceiptDetail'
   -- SOS46199 Default to auto finalize
   SELECT @cRDT_NotFinalizeReceiptDetail = CASE WHEN SValue = '1' THEN '1' ELSE '0' END -- 0=Finalize, 1=Not finalize
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'RDT_NotFinalizeReceiptDetail'

   -- SOS#115735 Retrieve faciity to pass into nspGetRight - S
   DECLARE @cFacility NVARCHAR(5)

   SELECT @cFacility = Facility,
          @cDocType = DocType -- (Vicky03)
         FROM RECEIPT (NOLOCK)
         WHERE ReceiptKey = @c_prokey
   -- SOS#115735 Retrieve faciity to pass into nspGetRight - E

   -- Storer config 'Allow_OverReceipt'
   EXECUTE nspGetRight
      --NULL, -- Facility
      @cFacility, -- SOS#115735
      @c_storerkey,
      @c_sku,
      'Allow_OverReceipt',
      @b_success             OUTPUT,
      @cAllow_OverReceipt    OUTPUT,
      @n_err2                OUTPUT,
      @c_errmsg              OUTPUT
   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60039
      SET @c_errmsg = 'nspGetRight Allow_OverReceipt (nspRFRC01)'
   END

   -- Storer config 'ByPassTolerance'
   EXECUTE nspGetRight
      --NULL, -- Facility
      @cFacility, -- SOS#115735
      @c_storerkey, -- Leong01
      NULL,
      'ByPassTolerance',
      @b_success           OUTPUT,
      @cByPassTolerance    OUTPUT,
      @n_err2              OUTPUT,
      @c_errmsg            OUTPUT
 IF @b_success <> 1
   BEGIN
      SET @n_err = 60040
      SET @n_continue = 3
      SET @c_errmsg = 'nspGetRight ByPassTolerance (nspRFRC01)'
   END

   /* Pick up value of RF Duplicate Serial from StorerConfig */
   Declare @c_NoDuplicateSerialNoAllowed NVARCHAR(10)

   SELECT @c_NoDuplicateSerialNoAllowed = LTrim(RTrim(sValue))
   FROM StorerCONFIG (NOLOCK)
   WHERE ConfigKey = 'DisAllowDuplicateSerialNo'
   AND   StorerKey = @c_storerkey -- Vicky01

   -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - end

   -- Vicky01 - Start
   SELECT @cMatchID_Lot = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'MatchID_Lot'

   SELECT @cCopyKeys = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'CopyRecvKeys'
   -- Vicky01 - End

   -- (ChewKP01)
   SELECT @cMatchID = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'MatchByID'


   -- james01 - Start
   SELECT @cGenLot2withASN_ASNLineNo = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'GenLot2withASN_ASNLineNo'

   -- Vicky02 - Start
   SELECT @cXD_Lot3 = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'XDLot3'
   -- Vicky02 - End

   -- Vicky04 - Start
   SELECT @cMatch_Lot3 = CASE WHEN SValue = '1' THEN '1' ELSE '0' END
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_storerkey
     AND ConfigKey = 'MatchLot3'
   -- Vicky04 - End

 IF @b_debug = 1
 BEGIN
    SELECT @cMatchID_Lot '@cMatchID_Lot'
    SELECT @cMatch_Lot3 '@cMatch_Lot3'
 END

   -- If lottable02 has no value then no need to have pre populate lottable in place
   -- and this configkey has to be turned off
   IF ISNULL(RTRIM(@c_lottable02), '') = ''
      SET @cGenLot2withASN_ASNLineNo = '0'
   -- james01 - End

   /*---------------------------------------------------------*/
   /* Customize for LFDM Only - To include the check digit    */
   /* for validation                                          */
   /*---------------------------------------------------------*/
   IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_storerkey AND
           ConfigKey = 'LFDMLabel' AND sValue = '1')
BEGIN
    -- Modifieded by Jacob
    -- Date : 16-10-2000
    -- Check Batch Number
    -- Modify by SHONG on 22-OCT-2003
    -- Swap to Lottalble02
      IF UPPER(LEFT(@c_lottable02, 1)) = "B"  -- modified by Jacob from <> "B"
         SELECT @c_lottable02 = SubString(@c_Lottable02, 2, LEN(@c_Lottable02))

    -- Remark by June 18.Sep.03 (SOS15116)
    /*
    -- Check Work Order Number
    IF UPPER(LEFT(@c_lottable02, 2)) <> "WO"
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err=65102
       SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Work Order Number (nspRFRC01)"
    END
    ELSE
    BEGIN
      SELECT @c_lottable02 = SubString(@c_Lottable02, 3, LEN(@c_Lottable02))
    END
    */

      IF UPPER(LEFT(@c_id, 2)) <> "LF"
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err=60001 -- 65103
         SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Pallet ID (nspRFRC01)"
      END
      ELSE
      BEGIN
         IF IsNumeric( SubString( @c_id, 3, LEN(@c_id) ) ) = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=60002 -- 65103
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Pallet ID, Not a Numeric (nspRFRC01)"
         END
      END
      -- Check Work Order Number
      IF @c_uom IS NULL OR RTrim(@c_uom) = ''
      BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=60003 -- 65104
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": UOM Cannot be BLANK (nspRFRC01)"
      END
   END
   -- End of Customization For LFDM

   -- user sometimes key in reason code to hold although there is no particular condition that requires it.
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF ISNULL(RTrim(@c_holdflag),'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT CODE FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'ASNREASON' AND CODE = @c_holdflag)
         BEGIN
            SELECT @n_continue=3
            SELECT @n_err=60004 -- 65414
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Reason Code is Invalid. (nspRFRC01)"
         END
      END

      IF ISNULL(RTRIM(@c_holdflag),'') = '' OR RTRIM(@c_holdflag) = '' --SOS#177773
      BEGIN
         SELECT @c_holdflag = 'OK'
      END

   END -- @n_continue

   /* Validate the location provided, if any*/
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        IF ISNULL(RTrim(@c_LOC),'') <> ''
        BEGIN
             IF NOT EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE Loc = @c_loc)
BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err=60005 -- 65101
                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Location (nspRFRC01)"
             END
        END
   END

    -- (Vicky03) - Start - Get Lottable03 for XDock Receipts
    IF @cDocType = 'X' AND @cXD_Lot3 = '1'
    BEGIN
       SELECT TOP 1 @c_lottable03 = RTRIM(Lottable03)
       FROM RECEIPTDETAIL WITH (NOLOCK)
       WHERE ReceiptKey = @c_prokey
    END
    -- (Vicky03) - End - Get Lottable03 for XDock Receipts

   /* do date conversions */
   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lottable04)) IS NULL
   BEGIN
      SELECT @d_lottable04 = NULL
   END
   ELSE
   BEGIN
       SELECT @d_lottable04 = rdt.rdtConvertToDate( @c_lottable04)


   END

   IF dbo.fnc_LTrim(dbo.fnc_RTrim(@d_lottable05)) IS NULL
   BEGIN
        SELECT @d_lottable05 = DATEADD( DD, DATEDIFF( DD, 0, GETDATE()), 0) -- Today date without time portion
   END
   ELSE
   BEGIN
        SELECT @d_lottable05 = rdt.rdtConvertToDate( @c_lottable05)
   END

   -- end dated 07 Jan 2002
   /* Pick up value of RF Duplicate Ids from NSQLCONFIG */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        SELECT @c_NoDuplicateIdsAllowed = ( SELECT LTrim(RTrim(NSQLValue))
                                     FROM NSQLCONFIG (NOLOCK)
                                     WHERE NSQLCONFIG.ConfigKey = "DisAllowDuplicateIdsOnRFRcpt")
   END
   /* Start Main Processing */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        IF @c_prokey = "PALBLDDONE"
        BEGIN
             GOTO STARTPUTAWAY
        END
   END
   /* If Duplicate Id and Duplicate Ids are not allowed, do not continue */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
        IF @c_NoDuplicateIdsAllowed = "1" and ISNULL(RTrim(@c_id),'') <> ''
        BEGIN
             -- Changed by June 30.Apr.2004 SOS22596
             -- IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE ID = @c_id)
             -- IF EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_id) -- SOS# 319429
             IF EXISTS ( SELECT [ID]
                         FROM dbo.LOTxLOCxID LOTxLOCxID WITH (NOLOCK)
                         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC)
                         WHERE [ID] = @c_id
                         AND QTY > 0
                         AND LOC.Facility = @cFacility ) -- SOS# 319429
             BEGIN
                  SELECT @n_continue = 3
                  /* Trap SQL Server Error */
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60006 --65131   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": This is a duplicate Pallet ID. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                  /* End Trap SQL Server Error */
             END
        END
END


   DECLARE @c_dummy1 NVARCHAR(10), @c_dummy2 NVARCHAR(10)
   /* Calculate Sku Supercession */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        IF ISNULL(RTrim(@c_sku),'') <> '' AND ISNULL(RTrim(@c_StorerKey),'') <> ''
        BEGIN
             SELECT @b_success = 0
             EXECUTE nspg_GETSKU1
                   @c_StorerKey  = @c_StorerKey,
                   @c_sku        = @c_sku     OUTPUT,
                   @b_success    = @b_success OUTPUT,
                   @n_err        = @n_err     OUTPUT,
                   @c_errmsg     = @c_errmsg  OUTPUT,
                   @c_packkey    = @c_dummy1  OUTPUT,
                   @c_uom        = @c_dummy2  OUTPUT

             IF NOT @b_success = 1
             BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 60030
             END
             ELSE IF @b_debug = 1
             BEGIN
SELECT @c_sku "@c_sku after nspGetSku"
         END
        END
   END

   -- SHONG001
   -- Make sure only select all the sku information once!
   -- Consolidate all the select statement
   DECLARE  @c_lottable01label NVARCHAR(18),
            @c_lottable02label NVARCHAR(18),
            @c_lottable03label NVARCHAR(18),
            @c_lottable04label NVARCHAR(18),
            @c_lottable05label NVARCHAR(18),
            @c_OnReceiptCopyPackKey NVARCHAR(10)
   DECLARE  @n_InShelfLife int

   IF @n_continue=1 OR @n_continue=2
   BEGIN
   IF ISNULL(RTrim(@c_sku),'') <> '' AND ISNULL(RTrim(@c_StorerKey),'') <> ''
       BEGIN
          SELECT @c_lottable01label = Lottable01Label,
                 @c_lottable02label = Lottable02Label,
                 @c_lottable03label = Lottable03Label,
                 @c_lottable04label = Lottable04Label,
                 @c_lottable05label = Lottable05Label,
                 @c_OnReceiptCopyPackKey = OnReceiptCopyPackKey,
                 @nTolerancePercentage =
                     CASE
                        WHEN SKU.SUSR4 IS NOT NULL AND IsNumeric( SKU.SUSR4) = 1
                        --THEN CAST( SKU.SUSR4 AS INT)               --SOS318197
                        THEN Convert(Int, CONVERT(Float, SKU.SUSR4)) --SOS318197
                        ELSE 0
                     END,
                 @cReceiptInspectionLoc = ReceiptInspectionLoc,
                 @c_Tariffkey = TariffKey,
                 @n_InShelfLife =
                     CASE -- edit by james on 27/11/2007
                        WHEN SKU.SUSR1 IS NOT NULL AND IsNumeric( SKU.SUSR1) = 1
                        --THEN CAST( SKU.SUSR1 AS INT)               --SOS318197
                        THEN Convert(Int, CONVERT(Float, SKU.SUSR1)) --SOS318197
                        ELSE 0
                     END
--                 CASE WHEN SUSR1 IS NOT NULL THEN Convert(Int, SUSR1) ELSE 0 END
          FROM  SKU (NOLOCK)
          WHERE Sku = @c_sku
          AND   StorerKey = @c_storerkey

       END

      IF @c_lottable04label = 'GENEXPDATE'
      BEGIN
         SELECT @d_lottable04 = Convert(datetime, '31 dec 2099', 106)
      END
   END

   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        SELECT @c_taskid = CONVERT(NVARCHAR(18), CONVERT(int,( RAND() * 2147483647)) )
   END
   /* End Calculate Next Task ID */

   /* Validate Lottables */

   IF (@n_continue=1 OR @n_continue=2) AND SUBSTRING(@c_other2,1,3) <> 'RGR'
   BEGIN
      IF ISNULL(@c_lottable01label,'') <> '' AND ISNULL(@c_lottable01,'') = ''
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err=60007 -- 65103
         SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + @c_Lottable01Label + " Required (nspRFRC01)"
      END
      ELSE
      BEGIN
         IF ISNULL(@c_lottable02label,'') <> '' AND ISNULL(@c_lottable02,'') = ''
         BEGIN
            SELECT @n_continue=3
            SELECT @n_err=60008 --65103
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + @c_Lottable02Label + " Required (nspRFRC01)"
         END
         ELSE
         BEGIN
            IF ISNULL(@c_lottable03label,'') <> '' AND ISNULL(@c_lottable03,'') = ''
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=60009 -- 65103
               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + @c_Lottable03Label + " Required (nspRFRC01)"
            END
            ELSE
            BEGIN
               IF ISNULL(@c_lottable04label,'') <> '' AND ISNULL(@d_lottable04,'') = ''
               BEGIN
                  SELECT @n_continue=3
                  SELECT @n_err=60010 -- 65103
                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + @c_Lottable04Label + " Required (nspRFRC01)"
               END
            END
   END
      END

      IF  @c_NoDuplicateSerialNoAllowed = '1' AND (@n_continue = 1 OR @n_continue = 2)
     BEGIN
         IF @c_lottable01label = 'SERIALNO'
         BEGIN
            IF EXISTS(SELECT 1 FROM LOTATTRIBUTE (NOLOCK) WHERE SKU = @c_sku AND StorerKey = @c_storerkey
                      AND Lottable01 = @c_Lottable01)
            BEGIN
                SELECT @n_continue=3
                SELECT @n_err=60031 -- 65103
                SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + " Serial No " + RTrim(@c_Lottable01) + " Already Exists. (nspRFRC01)"
            END
         END
         IF @c_lottable02label = 'SERIALNO'
         BEGIN
            IF EXISTS(SELECT 1 FROM LOTATTRIBUTE (NOLOCK) WHERE SKU = @c_sku AND StorerKey = @c_storerkey
        AND Lottable02 = @c_Lottable02)
            BEGIN
                SELECT @n_continue=3
                SELECT @n_err=60031 -- 65103
                SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + " Serial No " + RTrim(@c_Lottable02) + " Already Exists. (nspRFRC01)"
            END
         END
         IF @c_lottable03label = 'SERIALNO'
         BEGIN
            IF EXISTS(SELECT 1 FROM LOTATTRIBUTE (NOLOCK) WHERE SKU = @c_sku AND StorerKey = @c_storerkey
                      AND Lottable03 = @c_Lottable03)
            BEGIN
                SELECT @n_continue=3
                SELECT @n_err=60031 -- 65103
                SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": " + " Serial No " + RTrim(@c_Lottable03) + " Already Exists. (nspRFRC01)"
            END
         END
      END
   END

   /* End Validate Lottables */
   /* Validate Storer&Sku or Lot */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ISNULL(RTrim(@c_LOT),'') = ''
      BEGIN
         IF ISNULL(RTrim(@c_StorerKey),'') = '' OR ISNULL(RTrim(@c_SKU),'') = ''
         BEGIN
            SELECT @n_continue=3
            SELECT @n_err=60012 -- 65102
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Storer or Sku (nspRFRC01)"
         END
      END
   END
   /* End Validate Storer&Sku or Lot */
   /* Validate ID */
  IF ( @n_continue = 1 or @n_continue = 2)
   BEGIN
        IF ISNULL(RTrim(@c_id),'') <> ''
        BEGIN
             /* DS: Reject if the ID already has a product for another storer*/
             IF EXISTS ( SELECT * FROM LOTxLOCxID (NOLOCK)
                          WHERE ID = @c_id and QTY > 0
                            and (StorerKey < @c_StorerKey OR StorerKey > @c_StorerKey) )
             BEGIN
          SELECT @n_continue = 3
                  /* Trap SQL Server Error */
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60013 -- 65127   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": ID is used by another Storer. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                  /* End Trap SQL Server Error */
             END
        END
   END
   /* End validate ID */
   /* Validate Packkey*/
   IF @n_continue=1 OR @n_continue=2
   BEGIN
     SELECT @b_success = 0
     EXECUTE nspGetPack
             @c_storerkey   = @c_storerkey,
             @c_sku         = @c_sku,
             @c_lot         = @c_lot,
             @c_loc         = @c_loc,
             @c_id          = @c_id,
             @c_packkey     = @c_packkey      OUTPUT,
             @b_success     = @b_success      OUTPUT,
             @n_err         = @n_err          OUTPUT,
             @c_errmsg      = @c_errmsg       OUTPUT
      IF NOT @b_success = 1
      BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 60032
      END
   END
   /* End Validate Packkey */
   /* Validate Qty */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @n_Qty = 0
      BEGIN
          SELECT @n_continue=3
          SELECT @n_err=60014 -- 65104
          SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Qty (nspRFRC01)"
      END
      ELSE
      BEGIN
          IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_storerkey AND
                    ConfigKey = 'C4RFXDOCK' AND sValue = '1' AND @cDocType = 'X')  -- (Vicky03)
          BEGIN
               --SELECT @c_uom = PACKUOM1 FROM PACK (NOLOCK) WHERE Packkey = @c_packkey
               SELECT @c_configkey = 'C4RFXDOCK', @c_sValue = '1'

               -- 1 Feb 2005 YTWAN - Enquiry Sku without Verify ASN# For C4MY - START
               IF @c_prokey = 'NOASN'
               BEGIN
                   SELECT @n_continue=3
                   SELECT @n_err=60015 -- 65100
                   SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": NO ASN#. SKU Enquiry is turn on (nspRFRC01)"
                   GOTO PUTAWAYEND
               END
               -- 1 Feb 2005 YTWAN - Enquiry Sku without Verify ASN# For C4MY - END
          END

          SELECT @b_success = 0
          EXECUTE nspUOMCONV
               @n_fromqty    = @n_qty,
               @c_fromuom    = @c_uom,
               @c_touom      = "",
               @c_packkey    = @c_packkey,
               @n_toqty      = @n_toqty      OUTPUT,
               @b_Success    = @b_Success    OUTPUT,
               @n_err        = @n_err        OUTPUT,
               @c_errmsg     = @c_errmsg     OUTPUT
          IF NOT @b_success = 1
          BEGIN
               SELECT @n_continue=3
               SELECT @n_err = 60033
          END

          SELECT @n_qty = FLOOR(@n_qty) -- (Vanessa01)
          SELECT @n_toqty = FLOOR(@n_toqty) -- (Vanessa01)
      END
   END
   /* End Validate Qty */
   /* Default Location */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
        IF ISNULL(RTrim(@c_LOC),'') = ''
        BEGIN
             SELECT @c_loc = "UNKNOWN"
        END

      -- SOS 36845 Auto populate C4RFXDOCK loc - start
      IF @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' and @cDocType = 'X' -- (Vicky03)
      BEGIN
         DECLARE @cPOType NVARCHAR( 10)

         -- C4LGMY, only XDOCK and FT ASN is received thru RF
         -- ASN:PO = 1:1. Receipt.POKey always have POKey
         -- ReceiptDetail.ToLOC is hardcode to XDOCK / FT when populate PO into ASN
         -- POKey is not visible on C4LGMY prompt.ini. Internally POKey pass in as 'NOPO'
         SELECT @cPOType = PO.POType
         FROM ReceiptDetail RD (NOLOCK) INNER JOIN PO (NOLOCK) ON RD.POKey = PO.POKey
         WHERE RD.ReceiptKey = @c_prokey

     -- (Rick01) - Start
     /*
         IF @cPOType IS NULL OR (@cPOType <> '5' AND @cPOType <> '6' AND @cPOType <> '8' AND @cPOType <> '8A')
         BEGIN
            SELECT @n_continue=3
            SELECT @n_err=60038
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": C4RFXDOCK fail to auto populate XDOCK / FT LOC  (nspRFRC01)"
         END
         ELSE
         BEGIN
            IF @cPOType = '5' OR @cPOType = '6'
               SET @c_loc = 'XDOCK'
            IF @cPOTYPE = '8' OR @cPOType = '8A'
               SET @c_loc = 'FT'
         END
         */
   IF @cPOType IS NULL SET @cPOType = ''
         SELECT @c_LOC = ISNULL(C4MYRECLOC.Short, '')
         FROM CODELKUP WITH (NOLOCK)
   LEFT OUTER JOIN CODELKUP C4MYRECLOC (NOLOCK) ON  C4MYRECLOC.Code = RTRIM(LTRIM(CAST(CODELKUP.Notes AS NVARCHAR(250))))
                  AND C4MYRECLOC.Listname = 'C4MYRECLOC'
         WHERE CODELKUP.Code = @cPOType
   AND   CODELKUP.Listname = 'POTYPE'

   IF @c_LOC IS NULL OR @c_LOC = ''
   BEGIN
            SELECT @n_continue=3
            SELECT @n_err=60038
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": C4RFXDOCK fail to auto populate XDOCK / FT LOC  (nspRFRC01)"
   END
   -- (Rick01) - End
      END
      -- SOS 36845 Auto populate C4RFXDOCK loc - end

   END
      /* End Default Location */
 -- Customize for Hong Kong
 -- By SHONG
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
       IF ISNULL(RTrim(@c_holdflag),'') <> '' AND RTrim(@c_holdflag) <> 'OK'
       BEGIN
         SELECT @c_loc = @cReceiptInspectionLoc
       END
   END
   /* End Default Location */
   /* PO Number */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
        IF ISNULL(RTrim(@c_POKey),'') = ''
        BEGIN
             SELECT @n_continue=3
             SELECT @n_err=60016 -- 65105
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad POKey (nspRFRC01)"
        END
   END

   /* 29-Nov-2004 YTWan RF Xdock Receiving - START */
   /* Check Qty */
   SELECT @c_externreceiptkey  = '', @c_externlineno = '', @c_polineno = '', @c_externpokey = ''

   IF (@n_continue=1 OR @n_continue=2) AND (@c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X')  -- (Vicky03)
   BEGIN
      -- C4 will send a unique sku in the PO and then populate to ASN
      -- Get the Original line from receiptdetail for receiptdetail insertion if apply
      SET ROWCOUNT 1
      SELECT @c_pokey             = POKey,
             @c_origreceiptlineno = receiptlinenumber,
             @c_externreceiptkey  = ExternReceiptkey,
             @c_externlineno      = ExternLineNo,
             @c_polineno          = POLineNumber,
             @c_externpokey       = ExternPOKey
      FROM RECEIPTDETAIL (NOLOCK)
      WHERE  Receiptkey = @c_prokey
      AND    Storerkey  = @c_storerkey
      AND    Sku        = @c_sku

      SET ROWCOUNT 0


      IF EXISTS (SELECT 1
                  FROM RECEIPTDETAIL (NOLOCK)
                  WHERE  (Receiptkey   = @c_prokey)
                  AND    (POLineNumber = @c_polineno)
                  AND    (Storerkey    = @c_storerkey)
                AND    (Sku       = @c_sku)
                  GROUP BY Receiptkey, POLineNumber, Finalizeflag
 HAVING  (SUM(QtyExpected - BeforeReceivedQty) < @n_toQty
                  OR      Finalizeflag = 'Y'))
      BEGIN
          SELECT @n_continue=3
          SELECT @n_err=60017 -- 65115
          SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+ ": Qty Received > Qty Expected OR Record has been finalized (nspRFRC01)"
      END
   END
   /* 29-Nov-2004 YTWan RF Xdock Receiving - END */
-- (Vicky01) - Start
   ELSE
   BEGIN
      IF (@n_continue=1 OR @n_continue=2) AND (@cCopyKeys = '1')
      BEGIN
         SET ROWCOUNT 1
           --SOS#183324 Start
--         SELECT @c_pokey             = POKey,
--    --            @c_origreceiptlineno = receiptlinenumber,
--                @c_externreceiptkey  = ExternReceiptkey,
--                @c_externlineno      = ExternLineNo,
--                @c_polineno          = POLineNumber,
--                @c_externpokey       = ExternPOKey
--         FROM RECEIPTDETAIL (NOLOCK)
--       WHERE  Receiptkey = @c_prokey
--         AND    Storerkey  = @c_storerkey
--         AND    Sku        = @c_sku

    IF  @c_pokey = 'NOPO' OR ISNULL(RTRIM(@c_pokey), '') = '' --ang01
    BEGIN
         SET @c_CursorReceiptDetail = ''
         SET @c_ExecArguments = ''
         SET @c_CursorReceiptDetail = ' SELECT @c_pokey            = POKey, ' +
                                      '        @c_externreceiptkey = ExternReceiptkey, ' +
                                      '        @c_externlineno     = ExternLineNo, ' +
                                      '        @c_polineno         = POLineNumber, ' +
                                      '        @c_externpokey      = ISNULL(RTRIM(ExternPOKey),'''') ' +
                                      ' FROM RECEIPTDETAIL (NOLOCK) ' +
                                      ' WHERE  Receiptkey = N''' + RTRIM(@c_prokey) + ''' ' +
                                      ' AND    Storerkey  = N''' + RTRIM(@c_storerkey) + ''' ' +
                                      ' AND    Sku        = N''' + RTRIM(@c_sku) + ''' '  +
                                      ' AND    BeforeReceivedQTY < QtyExpected '  --ang01

         IF @cMatch_Lot3 = '1' AND ISNULL(RTRIM(@c_lottable03),'') <> ''
         BEGIN
            SET @c_CursorReceiptDetail = RTRIM(@c_CursorReceiptDetail) +
               ' AND    Lottable03 = N''' + RTRIM(@c_lottable03) + ''' '
         END

         SET @c_ExecArguments = N'@c_pokey             NVARCHAR(10) OUTPUT, '
                                + '@c_externreceiptkey NVARCHAR(20) OUTPUT, '
                                + '@c_externlineno     NVARCHAR(20) OUTPUT, '
                                + '@c_polineno         NVARCHAR(5)  OUTPUT, '
                                + '@c_externpokey      NVARCHAR(20) OUTPUT '

         EXEC sp_ExecuteSql @c_CursorReceiptDetail
                           , @c_ExecArguments
                           , @c_pokey            OUTPUT
                           , @c_externreceiptkey OUTPUT
                           , @c_externlineno     OUTPUT
                           , @c_polineno         OUTPUT
                           , @c_externpokey      OUTPUT
         --SOS#183324 End
         SET ROWCOUNT 0
       END
      END
      ELSE IF  @c_pokey <> 'NOPO' AND ISNULL(RTRIM(@c_pokey), '') <> ''  --ang01 start
      BEGIN
         SET @c_CursorReceiptDetail = ''
         SET @c_ExecArguments = ''
         SET @c_CursorReceiptDetail = 'SELECT  @c_externreceiptkey = ExternReceiptkey, ' +
                                      '        @c_externlineno     = ExternLineNo, ' +
                                      '        @c_polineno         = POLineNumber, ' +
                                      '        @c_externpokey      = ISNULL(RTRIM(ExternPOKey),'''') ' +
                                      ' FROM RECEIPTDETAIL (NOLOCK) ' +
     ' WHERE  Receiptkey = N''' + RTRIM(@c_prokey) + ''' ' +
                                      ' AND    Storerkey  = N''' + RTRIM(@c_storerkey) + ''' ' +
                                      ' AND    Sku        = N''' + RTRIM(@c_sku) + ''' '   +
                                      ' AND    POKey        = N''' + RTRIM(@c_pokey) + ''' '


         IF @cMatch_Lot3 = '1' AND ISNULL(RTRIM(@c_lottable03),'') <> ''
         BEGIN
            SET @c_CursorReceiptDetail = RTRIM(@c_CursorReceiptDetail) +
               ' AND    Lottable03 = N''' + RTRIM(@c_lottable03) + ''' '
         END

         SET @c_ExecArguments = N'@c_externreceiptkey NVARCHAR(20) OUTPUT, '
                                + '@c_externlineno     NVARCHAR(20) OUTPUT, '
                                + '@c_polineno         NVARCHAR(5)  OUTPUT, '
                                + '@c_externpokey      NVARCHAR(20) OUTPUT '

         EXEC sp_ExecuteSql @c_CursorReceiptDetail
                           , @c_ExecArguments
                         --  , @c_pokey            OUTPUT
                           , @c_externreceiptkey OUTPUT
                      , @c_externlineno     OUTPUT
                           , @c_polineno         OUTPUT
                           , @c_externpokey      OUTPUT
         --ang01 End
         SET ROWCOUNT 0
      END
END
-- (Vicky01) - End

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      /* NoPO  or NOPDO (NOPDO is spanish for no PO) */
      IF LTrim(RTrim(@c_pokey)) = "NOPO"  or LTrim(RTrim(@c_pokey)) = "NOPDO"
      BEGIN
         SELECT @c_pokey = ""
      END
      ELSE
         /* New PO */
         IF LTrim(RTrim(@c_pokey)) = "NEW"
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspg_getkey
                       "PO",
                       10,
                       @c_pokey    OUTPUT,
                       @b_success  OUTPUT,
                       @n_err      OUTPUT,
                       @c_errmsg   OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue=3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60018 -- 65106   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Getting PO key failed . (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
            END
            ELSE
            BEGIN
               INSERT PO (POKey, StorerKey) VALUES (@c_pokey, @c_storerkey)
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                    SELECT @n_continue = 3
                    /* Trap SQL Server Error */
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60019 -- 65107   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On PO. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                    GOTO QUIT
                    /* End Trap SQL Server Error */
               END
               ELSE
   BEGIN
                  /* DS: Added PODetail insert */
                  IF @c_prokey = "NOASN"
                  BEGIN
                      INSERT PODETAIL
                           ( POKey, POLineNumber, StorerKey, Sku,
                             QtyReceived, PackKey, UOM )
                      VALUES
                           ( @c_pokey , '00001', @c_storerkey, @c_sku,
                             @n_toqty, @c_packkey, @c_uom )
                  END
                  ELSE
                  BEGIN
                      INSERT PODETAIL
                           ( POKey, POLineNumber, StorerKey, Sku,
                             QtyReceived, PackKey, UOM )
                      VALUES ( @c_pokey , '00001', @c_storerkey, @c_sku,
 0, @c_packkey, @c_uom )
                  END
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                      SELECT @n_continue = 3
                      /* Trap SQL Server Error */
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60020 -- 65111   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                      SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On PODetail. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                      GOTO QUIT
                      /* End Trap SQL Server Error */
                  END
               END
            END
         END
         ELSE
         /* POKey is entered*/
         BEGIN
            /* Reject Invalid POKey */
            IF NOT EXISTS (SELECT * FROM PODetail WHERE POKey = @c_pokey )
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=60016 -- 65112
               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad POKey (nspRFRC01)"
            END
            ELSE
               IF @c_prokey = 'NOASN'
               BEGIN
                  /* DS: Update PODetail if NOASN is entered */
                  UPDATE PODetail
                  SET QtyReceived = QtyReceived + @n_toqty
                  WHERE StorerKey = @c_storerkey
                  and Sku = @c_sku
                  and POKey = @c_pokey
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     /* Trap SQL Server Error */
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60020 -- 65113   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On PODetail. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                     GOTO QUIT
                     /* End Trap SQL Server Error */
                  END
               END
               ELSE
               BEGIN
                  /*--------------------- Customisation For IDS HK -----------------------*/
                  /*  06/12/2001 - FBR 001 - Receiving via Reason Code           */
                  /*----------------------------------------------------------------------*/
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN -- @n_continue
                     DECLARE @n_ttlorderedqty  int,
                        @n_ttlreceivedqty      int,
                        @n_tempqty             int,
                        @n_variance            float -- Change from int to float by SHONG on 19th Nov 2007

         SET @n_variance = @nTolerancePercentage -- SOS54328 SKU.SUSR4 might contain non numeric value

                        SELECT @n_ttlorderedqty = SUM(QtyOrdered),
                               @n_ttlreceivedqty = SUM(QtyReceived)
                               -- SOS54328 SKU.SUSR4 might contain non numeric value
                      -- @n_variance = CONVERT(int, (CASE WHEN SKU.Susr4 IS NULL OR LTrim(RTrim(SKU.Susr4)) = ''
                               --                              THEN '0'
                               --                              ELSE SKU.Susr4
                               --                              END))
                        FROM PODETAIL (NOLOCK), SKU (NOLOCK)
                        WHERE POKey = @c_pokey
                        AND PODETAIL.StorerKey = SKU.StorerKey
                        AND PODETAIL.StorerKey = @c_storerkey
                        AND PODETAIL.Sku = SKU.Sku
                        AND PODETAIL.Sku = @c_sku
                        -- GROUP BY SKU.Susr4 -- SOS54328 SKU.SUSR4 might contain non numeric value

                     IF @n_variance <> 0
                        BEGIN
                           IF (@n_ttlreceivedqty + @n_toqty) > (@n_ttlorderedqty * (1 + (@n_variance / 100.00)))
                           BEGIN
                            --   IF NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE ListName = 'ASNREASON'
                            --   AND Code = @c_holdflag) OR @c_holdflag IS NULL
                            -- no need to validate, we've done it already
                              IF ISNULL(RTrim(@c_holdflag),'') = '' -- only need to ensure holdcode exists
                              BEGIN
                                 SELECT @n_continue=3
                                 SELECT @n_err=60021 -- 65414
                                 SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Please Key in a Valid Reason Code For OverReceiving (nspRFRC01)"
                              END
                           END
               END -- @n_variance
                  END -- @n_continue
               END
       END
   END
   /* End PO Number */

  -- HK Customization, Check Shelf Life
  -- we will be looking at Incoming Shelf Life (SKU.SUSR1).
  -- If the product is due to expire, Reason code has to be entered.
  -- jeff

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
-- Customization -- If SKU.Lottable04label = 'GENEXPDATE' , then default the exp_date (lottable04) = Receiving date (lottable05) + 10 years
      IF @c_lottable04label = 'EXP_DATE' -- check only if lottable04label is expiry date.
      BEGIN
         IF @n_InShelfLife > 0
         BEGIN
            -- Receiptdate + inshelflife <= expiry date
            IF DATEADD (day, @n_InShelfLife, getdate()) > @d_lottable04
            BEGIN
            -- IF NOT EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE ListName = 'ASNREASON'
             --   AND Code = @c_holdflag) OR @c_holdflag IS NULL
               IF ISNULL(RTrim(@c_holdflag),'') = 'OK'
               BEGIN
                     SELECT @n_continue=3
                     SELECT @n_err=60022 -- 65414
                     SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Product is due to expire. Reason code required (nspRFRC01)"
               END  -- reasoncode
            END
         END -- @n_shelflife
      END -- @c_lottable04label
   END -- @n_continue
   -- End of customization, check shelf life
      /* PRO Number */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
        IF ISNULL(RTrim(@c_prokey),'') = ''
        BEGIN
             SELECT @n_continue=3
             SELECT @n_err=60023 -- 65114
             SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad PROKey (nspRFRC01)"
        END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
        /* New */
        IF LTrim(RTrim(@c_prokey)) = "NEW"
        BEGIN
       SELECT @b_success = 0
            EXECUTE nspg_getkey
                    "RECEIPT"
                    , 10
                    , @c_prokey   OUTPUT
                    , @b_success  OUTPUT
                    , @n_err      OUTPUT
                    , @c_errmsg   OUTPUT
            IF NOT @b_success = 1
      BEGIN
       SELECT @n_continue=3
               SELECT @n_err = 60034
            END
            ELSE
            BEGIN
               /* Add Receipt Header */
               INSERT RECEIPT (ReceiptKey, StorerKey) VALUES (@c_prokey, @c_storerkey)
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                    SELECT @n_continue = 3
                    /* Trap SQL Server Error */
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60024 -- 65115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On RECEIPT. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
          GOTO QUIT
                    /* End Trap SQL Server Error */
               END
            END
            /* Add Receipt Detail */
            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @c_ReceiptLineNumber = '00001'
               INSERT RECEIPTDETAIL
                    (
                         ReceiptKey,
                         ReceiptLineNumber,
                         StorerKey,
                         POKey,
                         Sku,
                         QtyExpected,
                         QtyAdjusted,
                         QtyReceived,
                         ToLoc,
                         ToId,
                         ConditionCode,
                         Lottable01,
                         Lottable02,
                         Lottable03,
                         Lottable04,
                         Lottable05,
                         Packkey,
                         Uom,
                         TariffKey,
                         FinalizeFlag
                   )
                   VALUES
                   (
                        @c_prokey,                       /* ReceiptKey                   */
                        @c_ReceiptLineNumber,            /* ReceiptLineNumber            */
                        @c_storerkey,                    /* StorerKey                    */
                        @c_pokey,                        /* POKey                        */
                        @c_sku,                          /* Sku                          */
                        0,                               /* QtyExpected                  */
                        0,                               /* QtyAdjusted                  */
                        @n_toqty,                        /* QtyReceived                  */
                        @c_loc,                          /* ToLoc                        */
                        @c_id,                           /* ToId                         */
                        ISNULL(LTrim(RTrim(@c_holdflag)), 'OK'), /* ConditionCode        */
                        @c_lottable01,                   /* Lottable01                   */
--                        @c_lottable02,                   /* Lottable02                   */     (james01)
                        CASE WHEN @cGenLot2withASN_ASNLineNo = '1' THEN
                        ISNULL(RTRIM(@c_prokey), '') + '_' +ISNULL(RTRIM(@c_ReceiptLineNumber), '') ELSE @c_lottable02 END,                   /* Lottable02                   */
                        @c_lottable03,                   /* Lottable03                   */
                        @d_lottable04,                   /* Lottable04                   */
                        @d_lottable05,                   /* Lottable05         */
                        @c_packkey,                      /* UOM                          */
                        @c_uom,                          /* TariffKey                    */
                        @c_tariffkey,
                        'Y'
                   )
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                    SELECT @n_continue = 3
           /* Trap SQL Server Error */
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60024 -- 65116   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On RECEIPT. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                    GOTO QUIT
               /* End Trap SQL Server Error */
               END
               ELSE
               BEGIN
                    SELECT @n_continue = 4
                    /* Warning By NB: Do not change this n_continue flag without checking the */
                  /* consequences on the workdown process later in this module! */
               END
            END
         END
      END

      IF @n_continue = 1 or @n_continue = 2
      BEGIN
           /* No ASN */
         IF @c_prokey = "NOASN"
         BEGIN
            /* 2001/10/01 CS IDSHK FBR061 populate lottable02 as current date if it is not specified */
            IF  LTrim(RTrim(@c_lottable02)) = '' or LTrim(RTrim(@c_lottable02)) IS  NULL
              SELECT @c_lottable02 = convert(NVARCHAR(8), getdate(), 112)  -- YYYYMMDD

            SELECT @b_success = 0
            EXECUTE nspItrnAddDeposit
               @n_ItrnSysId    = NULL,
               @c_StorerKey    = @c_storerkey,
               @c_Sku          = @c_sku,
               @c_Lot          = @c_lot,
               @c_ToLoc        = @c_loc,
               @c_ToID         = @c_id,
               @c_Status       = @c_holdflag,
               @c_lottable01   = @c_lottable01,
               @c_lottable02   = @c_lottable02,
               @c_lottable03   = @c_lottable03,
               @d_lottable04   = @d_lottable04,
               @d_lottable05   = @d_lottable05,
               @c_lottable06   = '',               --(CS01)
               @c_lottable07   = '',               --(CS01)
               @c_lottable08   = '',               --(CS01)
               @c_lottable09   = '',               --(CS01)
               @c_lottable10   = '',               --(CS01)
               @c_lottable11   = '',               --(CS01)
               @c_lottable12   = '',               --(CS01)
               @d_lottable13   = '',               --(CS01)
               @d_lottable14   = '',               --(CS01)
               @d_lottable15   = '',               --(CS01)
               @n_casecnt      = 0,
               @n_innerpack    = 0,
               @n_qty          = @n_qty,
               @n_pallet       = 0,
               @f_cube         = 0,
               @f_grosswgt     = 0,
               @f_netwgt       = 0,
               @f_otherunit1   = 0,
               @f_otherunit2   = 0,
               @c_SourceKey    = @c_taskid,
               @c_SourceType   = "nspRFRC01",
               @c_PackKey      = @c_packkey,
               @c_UOM          = @c_uom,
               @b_UOMCalc      = 1,
               @d_EffectiveDate= NULL,
               @c_itrnkey      = @c_itrnkey  OUTPUT,
               @b_Success      = @b_success  OUTPUT,
               @n_err          = @n_err      OUTPUT,
               @c_errmsg       = @c_errmsg   OUTPUT
               
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
            ELSE
            BEGIN
               SELECT @n_continue = 4
            END
         END
      END
      /* End PRO Number */
      /* Increment RECEIPTDETAIL.QtyReceived */
      /* However, Need to get the converted qty first based on packkey */
      /* Convert qty based on packkey */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
           SELECT @n_qty = @n_toqty
      END
      /* End Convert qty based on packkey */
      /* Make sure that the ASN number exists! */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
           IF NOT EXISTS (select 1 from receipt (NOLOCK)
                          where receiptkey = @c_prokey and StorerKey = @c_Storerkey )
           BEGIN
                SELECT @n_continue=3
                SELECT @n_err=60035 -- 65121
     SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Mismatch between Storer and ASN (nspRFRC01)"
           END
      END
      /* End Make sure that the ASN number exists! */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
--          IF @b_debug = 1
--          BEGIN
--             SELECT *
--             FROM RECEIPTDETAIL (NOLOCK)
--             WHERE ReceiptKey = @c_prokey
--             AND StorerKey = @c_storerkey
--             AND SKU = @c_sku
--             AND POKey = @c_pokey
--          END
         DECLARE @b_cursor_receipts_open int
         SELECT  @b_cursor_receipts_open = 0
         /* 29-Nov-2004 YTWan RF Xdock Receiving - START */
         DECLARECURSOR_RECEIPTS:

         SET @cCursorStatement = 'DECLARE CURSOR_RECEIPTS SCROLL CURSOR FOR SELECT '

         -- Vicky01 - Start
         IF @cMatchID_Lot = '1' OR @cMatch_Lot3 = '1' OR @cMatchID = '1' -- (Vicky04)  -- (ChewKP01)
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' SUM(QtyExpected) AS QtyExpected, '
         END
         ELSE
         -- Vicky01 - End
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' (SELECT SUM(RD.QtyExpected) FROM RECEIPTDETAIL RD(NOLOCK)
                           WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey
                           AND   ISNULL(RD.POKEY, '''') = ISNULL(RECEIPTDETAIL.POKEY, '''')
                           AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''')
                           AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS QtyExpected, '
         END

         IF @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' (SELECT SUM(RD.QtyReceived) FROM RECEIPTDETAIL RD (NOLOCK)
                              WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey
                              AND   ISNULL(RD.POKEY, '''') = ISNULL(RECEIPTDETAIL.POKEY, '''')
                              AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''')
                              AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS ReceivedQty, '
         END
         ELSE IF @cMatchID_Lot = '1' OR @cMatch_Lot3 = '1' OR @cMatchID = '1' -- (Vicky04)  -- (ChewKP01)
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' SUM(BeforeReceivedQty) AS BeforeReceivedQty, '
         END
         ELSE
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' (SELECT SUM(RD.BeforeReceivedQty) FROM RECEIPTDETAIL RD (NOLOCK)
                              WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey
                              AND   ISNULL(RD.POKEY, '''') = ISNULL(RECEIPTDETAIL.POKEY, '''')
                              AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''')
                              AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS BeforeReceivedQty, '
         END


         SET @cCursorStatement = RTrim(@cCursorStatement) +
                '       Receiptlinenumber, ' +
                '       DuplicateFrom      ' +
                'FROM RECEIPTDETAIL (NOLOCK) ' +
                'WHERE ReceiptKey = N''' + RTrim(@c_prokey) + ''' ' +
                'AND RECEIPTDETAIL.StorerKey = N''' + RTrim(@c_storerkey) + ''' ' +
                'AND RECEIPTDETAIL.SKU =  N''' + RTrim(@c_sku) + ''' ' +
                'AND RECEIPTDETAIL.FinalizeFlag <> ''Y'' '


         IF RTrim(@c_pokey) IS NOT NULL AND RTrim(@c_pokey) <> ''
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                     ' AND POKey   =  N''' + RTrim(@c_pokey) + ''' '
         END

         IF @c_OnReceiptCopyPackKey = '1'
         BEGIN
            SET @c_lottable01 = @c_packkey
         END
         -- (Vicky04) - Start
         ELSE IF @cMatch_Lot3 = '1'
         BEGIN
              IF @b_debug = 1
              BEGIN
                SELECT @cMatch_Lot3 '@cMatch_Lot3'
                SELECT @c_lottable03 '@c_lottable03'
              END

            IF ( RTrim(@c_lottable03) IS NOT NULL AND RTrim(@c_lottable03) <> '' )
            BEGIN
                SET @cCursorStatement = RTrim(@cCursorStatement) +
                  ' AND Lottable03 = N''' + ISNULL(RTrim(@c_lottable03), '') + ''' '
            END
         END
         -- (Vicky04) - End
         -- Vicky01 - Start
         ELSE IF @cMatchID_Lot = '1' AND -- (ChewKP01)
                 (( RTrim(@c_lottable01) IS NOT NULL AND RTrim(@c_lottable01) <> '' ) OR
                 ( RTrim(@c_lottable02) IS NOT NULL AND RTrim(@c_lottable02) <> '' ) OR
                 ( RTrim(@c_lottable03) IS NOT NULL AND RTrim(@c_lottable03) <> '' ))
         BEGIN

                  SET @cCursorStatement = RTrim(@cCursorStatement) +
                  ' AND Lottable01 = N''' + ISNULL(RTrim(@c_lottable01), '') + ''' ' + -- (Vicky02)
                  ' AND Lottable02 = N''' + ISNULL(RTrim(@c_lottable02), '') + ''' ' + -- (Vicky02)
                  ' AND Lottable03 = N''' + ISNULL(RTrim(@c_lottable03), '') + ''' '   -- (Vicky02)
         END
         ELSE IF @cMatchID = '0' AND -- (ChewKP01)
                 (( RTrim(@c_lottable01) IS NOT NULL AND RTrim(@c_lottable01) <> '' ) OR
                 ( RTrim(@c_lottable02) IS NOT NULL AND RTrim(@c_lottable02) <> '' ) OR
                 ( RTrim(@c_lottable03) IS NOT NULL AND RTrim(@c_lottable03) <> '' ))
         BEGIN

            SET @cCursorStatement = RTrim(@cCursorStatement) +
                  ' AND 1 = CASE WHEN (Lottable01 = '''' AND Lottable02 = '''' AND Lottable03='''' AND Lottable04 IS NULL) THEN 1 ' +
                  ' WHEN BeforeReceivedQty = 0 AND FinalizeFlag <> ''Y'' THEN 1 ' +
                  ' WHEN BeforeReceivedQty > 0 AND ' +
                  ' Lottable01 = N''' + ISNULL(RTrim(@c_lottable01), '') + ''' AND ' +
                  ' Lottable02 = N''' + ISNULL(RTrim(@c_lottable02), '') + ''' AND ' +
                  ' Lottable03 = N''' + ISNULL(RTrim(@c_lottable03), '') + ''' AND '   -- (james04)
                  --' Lottable04 = CASE WHEN N''' + @d_lottable04   + ''' IS NOT NULL THEN N''' + CONVERT(NVARCHAR(20), @d_lottable04,112) + ''' ELSE Lottable04 END ' +

            -- (james05)
            IF ISNULL( @d_lottable04, '') = ''
               SET @cCursorStatement = RTrim(@cCursorStatement) + ' ISNULL(Lottable04, N'''') = ISNULL(Lottable04, N'''') THEN 1 ELSE 2 END '
            ELSE
               SET @cCursorStatement = RTrim(@cCursorStatement) + ' Lottable04 = N''' + CONVERT(NVARCHAR(20), @d_lottable04,112) + ''' THEN 1 ELSE 2 END '

         END

         IF @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
         BEGIN
            -- SHONG002 Fixing Bugs
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' AND ( Lottable04 IS NULL OR (Lottable04 IS NOT NULL AND Lottable04 = ''' + CONVERT(NVARCHAR(20), @d_lottable04,112) + ''')) '
         END
         -- comment by james04
--         ELSE IF ( @d_lottable04 IS NOT NULL AND CONVERT(NVARCHAR(20), @d_lottable04, 112) <> '19000101' AND @cMatchID = '0')  -- (ChewKP01)
--         BEGIN
--            SET @cCursorStatement = RTrim(@cCursorStatement) +
--                CASE WHEN @d_lottable04 IS NOT NULL
--                     THEN ' AND Lottable04 = N''' + CONVERT(NVARCHAR(20), @d_lottable04,112)   + ''' '
--                     ELSE ' AND Lottable04 IS NULL '
--                END
--         END

         IF RTrim(@c_loc) IS NOT NULL AND RTrim(@c_loc) <> ''
         BEGIN
           -- Vicky01 - Start
           IF @cMatchID_Lot = '1' OR @cMatchID = '1' -- (ChewKP01)
           BEGIN
               SET @cCursorStatement = RTrim(@cCursorStatement) +
                        ' AND TOLOC =  N''' + RTrim(@c_loc) + ''''
           END
           ELSE
           -- Vicky01 - End
           BEGIN
               SET @cCursorStatement = RTrim(@cCursorStatement) +
                        ' AND 1 = CASE WHEN BeforeReceivedQty = 0 OR TOLOC =  N''' + RTrim(@c_loc) + ''' THEN 1 ELSE 2 END '
           END
         END


         If @b_debug = 1
         BEGIN
           sELECT '@c_id', @c_id
         END

         IF RTrim(@c_id) IS NOT NULL AND RTrim(@c_id) <> ''
         BEGIN
          -- Vicky01 - Start
           IF @cMatchID_Lot = '1'  OR @cMatchID = '1' -- (ChewKP01)
           BEGIN
               SET @cCursorStatement = RTrim(@cCursorStatement) +
                        ' AND TOID =  N''' + RTrim(@c_id) + ''' '
           END
           ELSE
           -- Vicky01 - End
           BEGIN
               SET @cCursorStatement = RTrim(@cCursorStatement) +
                        ' AND 1 = CASE WHEN BeforeReceivedQty = 0 OR TOID =  N''' + RTrim(@c_id) + ''' THEN 1 ELSE 2 END'
           END
         END

         -- Vicky01 - Start
         IF @cMatchID_Lot = '1' OR @cMatch_Lot3 = '1' OR @cMatchID = '1' -- (Vicky04)  -- (ChewKP01)
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                ' GROUP BY Receiptlinenumber,  DuplicateFrom ' +
                ' ORDER BY CASE WHEN SUM(QtyExpected) - SUM(BeforeReceivedQty) > 0 ' +
                ' THEN SUM(QtyExpected) - SUM(BeforeReceivedQty) ELSE 999999999 END, Receiptlinenumber '
         END
         ELSE
         BEGIN
            SET @cCursorStatement = RTrim(@cCursorStatement) +
                        ' ORDER BY CASE WHEN QtyExpected - BeforeReceivedQty > 0 THEN QtyExpected - BeforeReceivedQty ELSE 999999999 END, Receiptlinenumber '
         END
         -- Vicky01 - End

         IF @b_debug = 1  OR @b_debug = 2
         BEGIN
            PRINT @cCursorStatement
         END

         EXEC ( @cCursorStatement )
         --PRINT @cCursorStatement
         --RETURN

         /* Evaluate Errors From Declaring Cursor */
         SELECT @n_err = @@ERROR
         IF @n_err = 16915 /* Cursor Already Exists So Close, Deallocate And Try Again! */
         BEGIN
            CLOSE CURSOR_RECEIPTS
            DEALLOCATE CURSOR_RECEIPTS
            SET @b_cursor_receipts_open = 0
            GOTO DECLARECURSOR_RECEIPTS
         END
         /* END Evaluate Errors From Declaring Cursor */
         OPEN CURSOR_RECEIPTS
         SELECT @n_err = @@ERROR
         /* Evaluate Errors From Opening Cursor */
         IF @n_err = 16905 /* Cursor Already Opened! */
         BEGIN
            CLOSE CURSOR_RECEIPTS
            DEALLOCATE CURSOR_RECEIPTS
            SET @b_cursor_receipts_open = 0
            GOTO DECLARECURSOR_RECEIPTS
         END
         /* End Evaluate Errors From Opening Cursor */
         IF @n_err = 0
         BEGIN
            SELECT @b_cursor_receipts_open = 1
         END

         DECLARE @n_QtyTotal    int
         DECLARE @n_QtyExpected int
         DECLARE @n_QtyReceived int
         DECLARE @n_QtyDue      int
         DECLARE @nBorrowQTYExpected int

         DECLARE   @cUserDefine01          NVARCHAR( 30) --SOS# 111949 Start
             , @cUserDefine02          NVARCHAR( 30)
             , @cUserDefine03          NVARCHAR( 30)
             , @cUserDefine04          NVARCHAR( 30)
             , @cUserDefine05          NVARCHAR( 30)
             , @dtUserDefine06         DATETIME
             , @dtUserDefine07         DATETIME
             , @cUserDefine08          NVARCHAR( 30)
             , @cUserDefine09          NVARCHAR( 30)
             , @cUserDefine10          NVARCHAR( 30)--SOS# 111949 End

         IF @@CURSOR_ROWS = 0
         BEGIN
--             -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - start
--             IF @cRDT_NotFinalizeReceiptDetail = '1' -- IDS receiving style
--             BEGIN
--                IF @cAllow_OverReceipt = '0'
--                   SELECT
--                      @n_continue = 3,
--                      @n_err = 60041,
--                      @c_errmsg = 'Over receipt not allow (nspRFRC01)'
--                ELSE
--                   IF @cByPassTolerance = '0'
--                      -- Do not need to further calculate tolerance percentage, since it is base on ExptectedQTY
--             -- and we have ExptectedQTY = 0 here.
--                      SELECT
--                         @n_continue = 3,
--                         @n_err = 60042,
--                         @c_errmsg = 'Tolerance exceeded (nspRFRC01)'
--             END
            -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - end

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               IF @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1'  AND @cDocType = 'X' -- (Vicky03)
               BEGIN
                 /* Insert RECEIPTDETAIL */
                SELECT @c_ReceiptLineNumber = SUBSTRING(LTrim(STR(CONVERT(int, ISNULL(MAX(ReceiptLineNumber), "0")) + 1 + 100000)),2,5)
                  FROM RECEIPTDETAIL (NOLOCK)
                  WHERE ReceiptKey = @c_prokey

                  INSERT RECEIPTDETAIL
                   (
                   ReceiptKey,
                   ReceiptLineNumber,
                   StorerKey,
                   POKey,
                   Sku,
                   QtyExpected,
                   QtyAdjusted,
                   QtyReceived,
                   ToLoc,
                   ToId,
                   ConditionCode,
                   Lottable01,
                   Lottable02,
                   Lottable03,
                   Lottable04,
                   Lottable05,
                   Packkey,
                   Uom,
                   TariffKey,
                   FinalizeFlag,
                   BeforeReceivedQty,
                   ExternReceiptkey,
                   ExternLineNo,
                   POLineNumber,
                   ExternPOKEy,
                   UserDefine10
                   )
                  VALUES
                   (
                   @c_prokey,                       /* ReceiptKey                   */
                   @c_ReceiptLineNumber,            /* ReceiptLineNumber            */
                   @c_storerkey,                    /* StorerKey                    */
                   @c_pokey,                        /* POKey                        */
                   @c_sku,                          /* Sku                 */
                   CASE                             /* QtyExpected                  */
                     WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' THEN ISNULL(@n_qty, 0)  -- (Vicky03)
                     ELSE 0
                   END,
                   0,                               /* QtyAdjusted                  */
                   CASE                             /* QtyReceived                  */
                     WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN 0
                     ELSE @n_qty
                   END,
                   @c_loc,                          /* ToLoc                        */
                   @c_id,                           /* ToId                         */
                   ISNULL(LTrim(RTrim(@c_holdflag)), 'OK'),                     /* ConditionCode                */
                   @c_lottable01,                   /* Lottable01                   */
--                   @c_lottable02,                   /* Lottable02                   */      (james01)
                   CASE WHEN @cGenLot2withASN_ASNLineNo = '1' THEN
                   ISNULL(RTRIM(@c_prokey), '') + '_' + ISNULL(RTRIM(@c_ReceiptLineNumber), '') ELSE @c_lottable02 END,                   /* Lottable02                   */
                   @c_lottable03,                   /* Lottable03                   */
                   @d_lottable04,                   /* Lottable04                   */
                   @d_lottable05,                   /* Lottable05                   */
                   @c_packkey,                      /* UOM                          */
                   @c_uom,        /* TariffKey                    */
                   @c_tariffkey,
                   CASE                     /* FinalizeFlag                 */
                     WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN 'N'
                     ELSE 'Y' -- this is to finalize that particular receiptdetail ( to ensure entry into the inventory)
                   END,
                   CASE                             /* BeforeReceivedQty            */
                     WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN @n_Qty
                     ELSE 0
                   END,
                   @c_externreceiptkey,
                   @c_ExternLineNo,
                   @c_polineno,
                   @c_externpokey,
                   CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' THEN suser_sname() END  -- (Vicky03)
                   )
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60024 -- 65122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On RECEIPT. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                    GOTO QUIT
                  END

               END -- @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1'
               ELSE
               BEGIN
                  DECLARE @cReceiptLine     NVARCHAR(5),
                          @nTotalExpected   int,
                          @nQtyToTake       int,
                @nTotalReceived   int


                  SET @n_QtyTotal = @n_Qty
                  SET @nQtyToTake = 0
                  SET @nTotalExpected = 0
                  SET @nTotalReceived = 0

                  IF @b_debug = 2
                  BEGIN
                     SELECT ReceiptLineNumber,
                            CASE WHEN QtyExpected - BeforeReceivedQty > 0
                                 THEN QtyExpected - BeforeReceivedQty
                                 ELSE 0
                            END As QtyExpected,
                            ExternLineNo, POLineNumber, ExternReceiptkey, ExternPOKey
                     FROM   RECEIPTDETAIL (NOLOCK)
                     WHERE  ReceiptKey = @c_prokey
                     AND    StorerKey  = @c_StorerKey
                     AND    SKU        = @c_SKU
                     AND    POKey      = @c_POKey
                     ORDER BY CASE WHEN QtyExpected - BeforeReceivedQty > 0
                                   THEN QtyExpected - BeforeReceivedQty ELSE 999999999
                              END,
                              Receiptlinenumber

                  END

                  -- Get the Qty Expected from Other Receipt Line for same SKU
                  -- SOS#182721 Start
                  SET @c_CursorReceiptDetail = ''
                  SET @c_CursorReceiptDetail = 'DECLARE C_RECEIPTDETAIL CURSOR FAST_FORWARD READ_ONLY FOR ' +
                        ' SELECT ReceiptLineNumber, ' +
                        '       (SELECT SUM(RD.QtyExpected) ' +
                        '          FROM RECEIPTDETAIL RD(NOLOCK) ' +
                        '          WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey ' +
                        '          AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''') ' +
                        '          AND   ISNULL(RD.POKey, '''')        = ISNULL(RECEIPTDETAIL.POKey, '''')  ' +-- SHONG003
                        '          AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS QtyExpected, ' +
                        '       (SELECT SUM(RD.BeforeReceivedQty) FROM RECEIPTDETAIL RD (NOLOCK) ' +
                        '          WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey ' +
                        '          AND   ISNULL(RD.POKey, '''')        = ISNULL(RECEIPTDETAIL.POKey, '''') ' +-- SHONG003
                        '          AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''') ' +
                        '          AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS QtyReceived, ' +
                        '          ExternLineNo, POLineNumber, ExternReceiptkey, ExternPOKey, ' +
                        '        CASE WHEN QtyExpected - BeforeReceivedQty > 0 ' +
                        '             THEN QtyExpected - BeforeReceivedQty ELSE 0 ' +
                        '        END, ' +
                        '        UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, ' + --SOS# 111949
                        '        UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, AltSKU ' +  --SOS# 111949
                        ' FROM   RECEIPTDETAIL (NOLOCK) ' +
                        ' WHERE  ReceiptKey = N''' + RTRIM(@c_prokey) + ''' ' +
                        ' AND    StorerKey  = N''' + RTRIM(@c_storerkey) + ''' ' +
                        ' AND SKU        = N''' + RTRIM(@c_sku) + ''' ' +
                        ' AND    POKey      = N''' + RTRIM(@c_POKey) + ''' '

                  IF @cMatch_Lot3 = 1 AND ISNULL(RTRIM(@c_lottable03),'') <> ''
                  BEGIN
                     SET @c_CursorReceiptDetail = RTRIM(@c_CursorReceiptDetail) +
                        ' AND    Lottable03 = N''' + RTRIM(@c_lottable03) + ''' '
                  END

                  SET @c_CursorReceiptDetail = RTRIM(@c_CursorReceiptDetail) +
                        ' ORDER BY CASE WHEN QtyExpected - BeforeReceivedQty > 0 ' +
                        '               THEN QtyExpected - BeforeReceivedQty ELSE 999999999 ' +
                        '          END, ' +
                        '          Receiptlinenumber '

                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_CursorReceiptDetail '@c_ReceiptDetailCursor'
                  END

                  EXEC (@c_CursorReceiptDetail)

                  -- DECLARE C_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  -- SELECT ReceiptLineNumber,
                  --       (SELECT SUM(RD.QtyExpected)
                  --          FROM RECEIPTDETAIL RD(NOLOCK)
                  --          WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey
                  --          AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''')
                  --          AND   ISNULL(RD.POKey, '''')        = ISNULL(RECEIPTDETAIL.POKey, '''') -- SHONG003
                  --          AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS QtyExpected,
                  --       (SELECT SUM(RD.BeforeReceivedQty) FROM RECEIPTDETAIL RD (NOLOCK)
                  --          WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey
                  --          AND   ISNULL(RD.POKey, '''')        = ISNULL(RECEIPTDETAIL.POKey, '''') -- SHONG003
                  --          AND   ISNULL(RD.POLineNumber, '''') = ISNULL(RECEIPTDETAIL.POLineNumber, '''')
                  --          AND   RD.SKU          = RECEIPTDETAIL.SKU ) AS QtyReceived,
                  --        ExternLineNo, POLineNumber, ExternReceiptkey, ExternPOKey,
                  --        CASE WHEN QtyExpected - BeforeReceivedQty > 0
                  --             THEN QtyExpected - BeforeReceivedQty ELSE 0
                  --        END,
                  --        UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, --SOS# 111949
                  --        UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10  --SOS# 111949
                  -- FROM   RECEIPTDETAIL (NOLOCK)
                  -- WHERE  ReceiptKey = @c_prokey
                  -- AND    StorerKey  = @c_StorerKey
                  -- AND    SKU        = @c_SKU
                  -- AND    POKey      = @c_POKey
                  -- ORDER BY CASE WHEN QtyExpected - BeforeReceivedQty > 0
                  --               THEN QtyExpected - BeforeReceivedQty ELSE 999999999
                  --          END,
          --          Receiptlinenumber
        -- SOS#182721 End

                  OPEN C_RECEIPTDETAIL

                  FETCH NEXT FROM  C_RECEIPTDETAIL INTO @cReceiptLine, @nTotalExpected, @nTotalReceived,
                    @c_externlineno, @c_polineno, @c_externreceiptkey,
                    @c_externpokey, @n_QtyExpected,
                    @cUserDefine01, @cUserDefine02, @cUserDefine03, @cUserDefine04, @cUserDefine05, --SOS# 111949
                    @dtUserDefine06, @dtUserDefine07, @cUserDefine08, @cUserDefine09, @cUserDefine10, @cAltSKU --SOS# 111949

                  WHILE @@FETCH_STATUS <> -1 AND @n_QtyTotal > 0 AND (@nTotalExpected - @nTotalReceived) > 0
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @cReceiptLine '@cReceiptLine For Duplicate', @cAllow_OverReceipt '@cAllow_OverReceipt', @cByPassTolerance '@cByPassTolerance',
                               (@n_QtyTotal + @nTotalReceived) '@n_QtyTotal + @nTotalReceived',
                               @nTotalExpected '@nTotalExpected',
                               (@nTotalExpected * (1 + (@nTolerancePercentage * 0.01)))
                     END

                     IF @nTotalExpected >= ( @n_QtyTotal + @nTotalReceived )
                     BEGIN
                        SET @nQtyToTake = @n_QtyTotal
                        --SET @nTotalExpected = @nTotalExpected - @nTotalReceived  -- SHONG002
                        --SET @nTotalExpected = @nTotalExpected - (@nTotalReceived + @nQtyToTake) -- SHONG004
                        SET @nTotalExpected = @nTotalExpected - @nQtyToTake -- SHONG005
                     END
                     ELSE
                     BEGIN
                        IF @cAllow_OverReceipt = '0'
                        BEGIN
                           SELECT
                              @n_continue = 3,
                              @n_err = 60043,
                              @c_errmsg = 'Over receipt not allow (nspRFRC01)'
                           BREAK
                        END
                        ELSE
                        IF @cByPassTolerance = '0'
                        BEGIN
                           IF (@n_QtyTotal + @nTotalReceived) > (@nTotalExpected * (1 + (@nTolerancePercentage * 0.01)))
                           BEGIN
                              SELECT
                                 @n_continue = 3,
                                 @n_err = 60044,
                                 @c_errmsg = 'Tolerance exceeded (nspRFRC01)'
                           END
                           BREAK
                        END
                        -- SHONG002
                        -- SET @nQtyToTake = @nTotalExpected
                        SET @nTotalExpected = @nTotalExpected - @nTotalReceived  -- SHONG002
                        SET @nQtyToTake = @n_QtyTotal
                        IF @b_debug = 1
                        BEGIN
                           SELECT @nTotalExpected '@nTotalExpected', @nTotalReceived '@nTotalReceived'
                           SELECT @nQtyToTake '@nQtyToTake'
                        END

                     END

                     SET @n_QtyTotal = @n_QtyTotal - @nQtyToTake

                     IF @b_debug = 1
                     BEGIN
                        SELECT @n_QtyTotal '@n_QtyTotal'
                     END

                     UPDATE RECEIPTDETAIL
                     -- SHONG002
                     SET QtyExpected = QtyExpected - @nQtyToTake, TrafficCop = NULL --SHONG002/james (uncomment)
                     -- SET QtyExpected = QtyExpected - @nTotalExpected, TrafficCop = NULL --SHONG002
                     --SET QtyExpected = @nTotalExpected, TrafficCop = NULL -- SHONG004/james03 (comment)
                     WHERE ReceiptKey = @c_prokey
                     AND   ReceiptLineNumber = @cReceiptLine

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                       SELECT @n_continue = 3
                       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60024 -- 65122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                       SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                       GOTO QUIT
                     END

                     SET @cOpenQtyCalc = 'Y' -- (Vicky07)

                     IF @n_continue = 1 OR @n_continue = 2
                     BEGIN
                        /* Insert RECEIPTDETAIL */
                        SELECT @c_ReceiptLineNumber = SUBSTRING(LTrim(STR(CONVERT(int, ISNULL(MAX(ReceiptLineNumber), "0")) + 1 + 100000)),2,5)
                        FROM RECEIPTDETAIL (NOLOCK)
                        WHERE ReceiptKey = @c_prokey

                        INSERT RECEIPTDETAIL
                         (
                         ReceiptKey,        ReceiptLineNumber,    StorerKey,       POKey,
                         Sku,               QtyExpected,          QtyAdjusted,     QtyReceived,
                         ToLoc,             ToId,                 ConditionCode,   Lottable01,
                         Lottable02,        Lottable03,           Lottable04,      Lottable05,
                         Packkey,           Uom,                  TariffKey,       FinalizeFlag,
                         BeforeReceivedQty, ExternReceiptkey,     ExternLineNo,    POLineNumber,
                         ExternPOKey,       UserDefine10,       DuplicateFrom,
                         UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, --SOS# 111949
                         UserDefine06, UserDefine07, UserDefine08, UserDefine09, AltSKU) --SOS# 111949
                        VALUES
                         (
                         @c_prokey,                       /* ReceiptKey                   */
                         @c_ReceiptLineNumber,            /* ReceiptLineNumber            */
                         @c_storerkey,                    /* StorerKey                    */
                         @c_pokey,                        /* POKey                        */
                         @c_sku,                          /* Sku                          */
                         @nQtyToTake, -- QtyExpexted. SHONG004
                         --@nTotalExpected,
                         -- mary
                         --CASE WHEN ISNULL(@n_QtyExpected,0) >= @nQtyToTake
                         --       THEN ISNULL(@nQtyToTake, 0)
                         --     ELSE ISNULL(@nQtyToTake,0)
                         --END,               /* QtyExpected                  */
                         0,                               /* QtyAdjusted                  */
                         CASE                             /* QtyReceived                  */
                           WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN 0
                           ELSE ISNULL(@nQtyToTake, 0)
                         END,
                         @c_loc,                          /* ToLoc                        */
                         @c_id,                           /* ToId                         */
                          ISNULL(LTrim(RTrim(@c_holdflag)), 'OK'),  /* ConditionCode           */
                         @c_lottable01,                   /* Lottable01                   */
                        --       @c_lottable02,                   /* Lottable02                   */      (james01)
                        CASE WHEN @cGenLot2withASN_ASNLineNo = '1' THEN
                        ISNULL(RTRIM(@c_prokey), '') + '_' + ISNULL(RTRIM(@c_ReceiptLineNumber), '') ELSE @c_lottable02 END,                   /* Lottable02                   */
                         @c_lottable03,                   /* Lottable03                   */
                         @d_lottable04,                   /* Lottable04                   */
                         @d_lottable05,                   /* Lottable05                   */
                         @c_packkey,                      /* UOM                          */
                         @c_uom,                          /* TariffKey                    */
                         @c_tariffkey,
                         CASE                             /* FinalizeFlag                 */
                           WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN 'N'
                           ELSE 'Y' -- this is to finalize that particular receiptdetail ( to ensure entry into the inventory)
                         END,
                         ISNULL(@nQtyToTake, 0),                     /* BeforeReceivedQty            */
                         @c_externreceiptkey,
                         @c_ExternLineNo,
                         @c_polineno,
                         @c_externpokey,
                         CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                              THEN Suser_Sname()
                              ELSE @cUserDefine10 --SOS# 111949
                         END,
                         @cReceiptLine,                    /* DuplicateFrom                 */
                         @cUserDefine01, @cUserDefine02, @cUserDefine03, @cUserDefine04, @cUserDefine05,   --SOS# 111949
                         @dtUserDefine06, @dtUserDefine07, @cUserDefine08, @cUserDefine09, ISNULL(RTRIM(@cAltSKU),'')) --SOS# 111949, SOS315152
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                          SELECT @n_continue = 3
                          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60024 -- 65122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                          SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On RECEIPT. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                          GOTO QUIT
                        END
                        IF @b_debug = 1
                        BEGIN
                           SELECT @c_ReceiptLineNumber 'INSERT ReceiptDetail @c_ReceiptLineNumber A'
                        END
                     END -- @n_continue = 1 OR @n_continue = 2

                     FETCH NEXT FROM  C_RECEIPTDETAIL INTO @cReceiptLine,  @nTotalExpected, @nTotalReceived, @c_externlineno,
                                       @c_polineno, @c_externreceiptkey, @c_externpokey,  @n_QtyExpected,
                                                       @cUserDefine01, @cUserDefine02, @cUserDefine03, @cUserDefine04, @cUserDefine05, --SOS# 111949
                                                       @dtUserDefine06, @dtUserDefine07, @cUserDefine08, @cUserDefine09, @cUserDefine10, @cAltSKU--SOS# 111949
                  END -- WHILE
                  CLOSE C_RECEIPTDETAIL
                  DEALLOCATE C_RECEIPTDETAIL

                  IF  (@n_QtyTotal + @nTotalReceived) > @nTotalExpected

                  AND @n_QtyTotal > 0
                  AND (@n_continue = 1 OR @n_continue = 2)
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @cAllow_OverReceipt '@cAllow_OverReceipt', @cByPassTolerance '@cByPassTolerance',
                               (@n_QtyTotal + @nTotalReceived) '@n_QtyTotal + @nTotalReceived',
                                @nTotalExpected '@nTotalExpected',
                               (@nTotalExpected * (1 + (@nTolerancePercentage * 0.01)))
                     END

                     IF @cAllow_OverReceipt = '0'
                     BEGIN
                        SELECT
                           @n_continue = 3,
                           @n_err = 60043,
                           @c_errmsg = 'Over receipt not allow (nspRFRC01)'
                     END
                     ELSE
                     IF @cByPassTolerance = '0'
                     BEGIN
                        IF (@n_QtyTotal + @nTotalReceived) > (@nTotalExpected * (1 + (@nTolerancePercentage * 0.01)))
                        BEGIN
                           SELECT
                              @n_continue = 3,
                              @n_err = 60044,
                              @c_errmsg = 'Tolerance exceeded (nspRFRC01)'
                        END
                     END
                  END

                  IF (@n_continue = 1 OR @n_continue = 2) AND @n_QtyTotal > 0
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        SELECT @n_QtyTotal '@n_QtyTotal_2'
                        SELECT @n_QtyExpected '@n_QtyExpected'
                     END

                     IF ISNULL(@n_QtyTotal, 0) < ISNULL(@n_QtyExpected, 0)
                     BEGIN
                        SET @n_QtyExpected = @n_QtyTotal

                        IF @b_debug = 1
                        BEGIN
                           SELECT @n_QtyExpected '@n_QtyExpected_2'
                        END
                     END

                     /* Insert RECEIPTDETAIL */
                     SELECT @c_ReceiptLineNumber = SUBSTRING(LTrim(STR(CONVERT(int, ISNULL(MAX(ReceiptLineNumber), "0")) + 1 + 100000)),2,5)
                     FROM RECEIPTDETAIL (NOLOCK)
                     WHERE ReceiptKey = @c_prokey

                      INSERT RECEIPTDETAIL
                      (
                      ReceiptKey,        ReceiptLineNumber,    StorerKey,       POKey,
                      Sku,               QtyExpected,          QtyAdjusted,     QtyReceived,
                      ToLoc,             ToId,                 ConditionCode,   Lottable01,
                      Lottable02,        Lottable03,           Lottable04,      Lottable05,
                      Packkey,           Uom,                  TariffKey,       FinalizeFlag,
                      BeforeReceivedQty, ExternReceiptkey,     ExternLineNo,    POLineNumber,
                      ExternPOKEy,       UserDefine10,         DuplicateFrom,
                      UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, --SOS# 111949
                      UserDefine06, UserDefine07, UserDefine08, UserDefine09, AltSKU) --SOS# 111949
                     VALUES
                      (
                      @c_prokey,            /* ReceiptKey                   */
                      @c_ReceiptLineNumber,            /* ReceiptLineNumber            */
                      @c_storerkey,                    /* StorerKey                    */
                      @c_pokey,                        /* POKey                        */
                      @c_sku,                          /* Sku                          */
                      ISNULL(@n_QtyExpected, 0),       /* QtyExpected                  */
                      0,    /* QtyAdjusted                  */
                      CASE                             /* QtyReceived                  */
                        WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN 0
                        ELSE ISNULL(@n_QtyTotal, 0)
                      END,
                      @c_loc,                          /* ToLoc                        */
                      @c_id,                           /* ToId                         */
                      ISNULL(LTrim(RTrim(@c_holdflag)), 'OK'),  /* ConditionCode       */
                      @c_lottable01,                   /* Lottable01                   */
--                      @c_lottable02,                   /* Lottable02                   */      (james01)
                      CASE WHEN @cGenLot2withASN_ASNLineNo = '1' THEN
                      ISNULL(RTRIM(@c_prokey), '') + '_' + ISNULL(RTRIM(@c_ReceiptLineNumber), '') ELSE @c_lottable02 END,                   /* Lottable02                   */
                      @c_lottable03,                   /* Lottable03                   */
                      @d_lottable04,                   /* Lottable04                   */
                      @d_lottable05,                   /* Lottable05                   */
                      @c_packkey,                      /* UOM         */
                      @c_uom,                          /* TariffKey                    */
                      @c_tariffkey,
                      CASE                             /* FinalizeFlag                 */
                      WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN 'N'
                        ELSE 'Y' -- this is to finalize that particular receiptdetail ( to ensure entry into the inventory)
                      END,
                      @n_QtyTotal,                     /* BeforeReceivedQty            */
                      @c_externreceiptkey,
                      @c_ExternLineNo,
                      @c_polineno,
                      @c_externpokey,
                      CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                           THEN Suser_Sname()
                           ELSE @cUserDefine10 --SOS# 111949
                      END,
                      @cReceiptLine,                    /* DuplicateFrom                 */
                      @cUserDefine01, @cUserDefine02, @cUserDefine03, @cUserDefine04, @cUserDefine05,   --SOS# 111949
                      @dtUserDefine06, @dtUserDefine07, @cUserDefine08, @cUserDefine09, ISNULL(RTRIM(@cAltSKU),'')) --SOS# 111949, SOS315152

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                       SELECT @n_continue = 3
                       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60024 -- 65122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                       SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On RECEIPT. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                       GOTO QUIT
                     END

                     IF @b_debug = 1
                     BEGIN
                        SELECT 'INSERT ReceiptDetail 002'
                     END

                     UPDATE RECEIPTDETAIL
                        SET QtyExpected = QtyExpected - @n_QtyExpected, TrafficCop = NULL
                     WHERE ReceiptKey = @c_prokey
                     AND   ReceiptLineNumber = @cReceiptLine

                     SELECT @n_err = @@ERROR
                   IF @n_err <> 0
                     BEGIN
                       SELECT @n_continue = 3
                       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60024 -- 65122   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                       SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                       GOTO QUIT
                     END
                     SET @cOpenQtyCalc = 'Y' -- (Vicky07)

                  END -- @n_continue = 1 OR @n_continue = 2
               END --
            END
         END
         ELSE
         BEGIN
             /* Update RECEIPTDETAIL */
            SELECT @n_QtyTotal = @n_Qty
            WHILE (1=1)
            BEGIN
               FETCH NEXT FROM CURSOR_RECEIPTS
               INTO @n_QtyExpected, @n_QtyReceived, @c_receiptlinenumber, @cDuplicateFrom

               IF NOT @@FETCH_STATUS = 0
               BEGIN
                 BREAK
               END

--                IF @cDuplicateFrom IS NOT NULL AND @cDuplicateFrom <> ''
--            BEGIN
--                   SELECT @n_QtyExpected = QtyExpected - BeforeReceivedQty
--                   FROM   RECEIPTDETAIL (NOLOCK)
--                   WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @cDuplicateFrom
--                END

               --(ung01)
               SET @n_QtyExpected = ISNULL(@n_QtyExpected, 0)
               SET @n_QtyReceived = ISNULL(@n_QtyReceived, 0)

               SELECT @n_QtyDue = ISNULL(@n_QtyExpected, 0) - @n_QtyReceived

               IF @b_debug = 1
               BEGIN
                  SELECT @n_QtyDue '@n_QtyDue', @n_QtyExpected '@n_QtyExpected', @n_QtyReceived '@n_QtyReceived',
                         @n_QtyTotal '@n_QtyTotal'
               END

               IF @n_QtyDue <= 0
               BEGIN
                 /* This test necessary for when records are in the cursor where there is an overreceipt.*/
                 SELECT @n_qtydue = 0
                 CONTINUE
               END

               IF @n_QtyDue > @n_QtyTotal
                  BEGIN
                     SELECT @n_QtyDue = @n_QtyTotal
                  END


               -- SOS Tickey No 5581
               -- Added By SHONG
               -- Date: 17 May 2002
               -- Don't split the line if ID is provided
--                IF RTrim(@c_id) IS NOT NULL AND RTrim(@c_id) <> ''
--                BEGIN
--                    IF @n_QtyTotal > @n_QtyDue
--                    BEGIN
--                       SELECT @n_QtyDue = @n_QtyTotal
--                    END
--                END
               -- end of SOS ticket 5581

               -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - start
               IF @cRDT_NotFinalizeReceiptDetail = '1' -- IDS receiving style
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @cAllow_OverReceipt '@cAllow_OverReceipt', @cByPassTolerance '@cByPassTolerance', @nTolerancePercentage '@nTolerancePercentage'
                  END

                  -- Check if over receive
                  IF (@n_QtyTotal + @n_QtyReceived) > ISNULL(@n_QtyExpected, 0)
                  BEGIN
                     IF @cAllow_OverReceipt = '0'
                        CONTINUE -- over receipt not allow, try next line
                     ELSE
                        -- Check if bypass tolerance
                        IF @cByPassTolerance <> '1'
    -- Check if over tolerance %
                           IF (@n_QtyTotal + @n_QtyReceived) > (ISNULL(@n_QtyExpected, 0) * (1 + (@nTolerancePercentage * 0.01)))
                              CONTINUE -- over tolerance %, try next line
                  END
               END
               -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - end

               IF @n_QtyDue > 0
               BEGIN
                  UPDATE RECEIPTDETAIL
                  SET QtyReceived = CASE
                                       --WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' THEN QtyReceived
                                       WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN QtyReceived
                                       ELSE QtyReceived + @n_QtyDue
                                    END,
                     Toloc = @c_loc ,
                     Conditioncode = ISNULL(LTrim(RTrim(@c_holdflag)), 'OK'),
                     Lottable01 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                       THEN Lottable01 ELSE @c_lottable01 END,
                     Lottable02 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                       THEN Lottable02 ELSE @c_lottable02 END,
                     Lottable03 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                       THEN Lottable03 ELSE @c_lottable03 END,
                     Lottable04 = @d_lottable04,
                     Lottable05 = @d_lottable05,
                     -- SOS28761 (rollback)
                     -- Lottable05 = CASE WHEN FinalizeFlag = 'Y'
                     --                   THEN @d_lottable05 ELSE NULL END,
-- Commented by SHONG on 06-Aug-2008
--                     ToId       = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
--                                  THEN ToId ELSE @c_id END,
                     ToID         = ISNULL(@c_id, ''),
                     FinalizeFlag = CASE
                                       --WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' THEN FinalizeFlag
                                       WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN FinalizeFlag
                                       ELSE 'Y' -- this is to finalize that particular receiptdetail ( to ensure entry into the inventory)
                                    END,
                     BeforeReceivedQty = CASE
                        --WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' THEN BeforeReceivedQty + @n_QtyDue
                                            WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN BeforeReceivedQty + @n_QtyDue
                                            ELSE BeforeReceivedQty
                                         END,
                     QtyExpected       = CASE
                                            WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1'  AND @cDocType = 'X' AND @c_receiptlinenumber <> @c_origreceiptlineno  -- (Vicky03)
                                   THEN BeforeReceivedQty + @n_QtyDue
                                             ELSE QtyExpected
                                             END,
                     UserDefine10 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                         THEN Suser_Sname()
                                   ELSE UserDefine10
                                    END
                  WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @c_receiptlinenumber

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                    SELECT @n_continue = 3
                    SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60025 -- 65123   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                    GOTO QUIT
                  END
                  SET @cOpenQTYCalc = 'Y'

                  IF (@n_continue = 1) OR (@n_continue = 2)
                  BEGIN
                     IF @cDuplicateFrom IS NOT NULL AND @cDuplicateFrom <> ''
                     BEGIN
                        -- Calc QTYExpected to borrow
                        SET @nBorrowQTYExpected = 0
                        SELECT @nBorrowQTYExpected =
                           CASE WHEN (QtyExpected - BeforeReceivedQty) >= @n_QtyDue THEN @n_QtyDue
                                WHEN (QtyExpected - BeforeReceivedQty) > 0 AND @n_QtyDue > 0
                                THEN QtyExpected - BeforeReceivedQty
                           END
                        FROM ReceiptDetail WITH (NOLOCK)
                        WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @cDuplicateFrom

                        IF @nBorrowQTYExpected > 0
                        BEGIN
                           -- Reduce QTYExpected of parent
                           UPDATE RECEIPTDETAIL WITH (ROWLOCK) SET
                              QTYExpected = QTYExpected - @nBorrowQTYExpected
                           WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @cDuplicateFrom
                           SELECT @n_err = @@ERROR
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                              SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                              GOTO QUIT
                           END

                           -- Increase QTYExpected to itself
                           UPDATE RECEIPTDETAIL WITH (ROWLOCK) SET
                              QTYExpected = QTYExpected + @nBorrowQTYExpected
                           WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @c_receiptlinenumber
                           SELECT @n_err = @@ERROR
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                              SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                              GOTO QUIT
                           END
                        END
                        SET @cOpenQTYCalc = 'Y'
                     END
                  END
               END -- @n_QtyDue > 0
                  /* Let's keep little track */
               IF @c_PrevLineNumber <> @c_ReceiptLineNumber
               BEGIN
                  IF @c_PrevLineNumber <> master.dbo.fnc_GetCharASCII(14)
                  BEGIN
                   SELECT @c_multiline = "1"
                  END
                  SELECT @c_PrevLineNumber = @c_ReceiptLineNumber
               END
               SELECT @n_QtyTotal = @n_QtyTotal - @n_QtyDue

               IF @n_QtyTotal = 0
               BEGIN
                  BREAK
               END
            END
            IF @n_QtyTotal > 0
            BEGIN
            FETCH FIRST FROM CURSOR_RECEIPTS
               INTO @n_QtyExpected,
                     @n_QtyReceived, @c_receiptlinenumber, @cDuplicateFrom
               IF NOT @@FETCH_STATUS = 0
               BEGIN
                  SELECT @n_continue=3
                  SELECT @n_err=60025 -- 65124
                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Fetch Failed On RECEIPTDETAIL. (nspRFRC01)"
               END
               ELSE
               BEGIN
--                   IF @cDuplicateFrom IS NOT NULL AND @cDuplicateFrom <> ''
--                   BEGIN
--                      SELECT @n_QtyExpected = QtyExpected - BeforeReceivedQty
--                      FROM   RECEIPTDETAIL (NOLOCK)
--                      WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @cDuplicateFrom
--                   END

                  -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - start
                  IF @cRDT_NotFinalizeReceiptDetail = '1' -- IDS receiving style
                  BEGIN
                     IF @cAllow_OverReceipt = '0'
                        SELECT
                           @n_continue = 3,
                           @n_err = 60043,
                           @c_errmsg = 'Over receipt not allow (nspRFRC01)'
                     ELSE
                        IF @cByPassTolerance = '0'
                           IF (@n_QtyTotal + @n_QtyReceived) > (@n_QtyExpected * (1 + (@nTolerancePercentage * 0.01)))
                              SELECT
                                 @n_continue = 3,
                                 @n_err = 60044,
                                 @c_errmsg = 'Tolerance exceeded (nspRFRC01)'
                  END
                  -- SOS# 43730 Add storer config RDT_FinalizeReceiptDetail for RDT - end

                  IF (@n_continue = 1) OR (@n_continue = 2)
                  BEGIN

                     UPDATE RECEIPTDETAIL
                     SET QtyReceived = CASE
   --WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' THEN QtyReceived
                                          WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN QtyReceived
                                          ELSE QtyReceived + @n_QtyTotal
                                       END,
                        Toloc = @c_loc ,
                        Conditioncode = ISNULL(LTrim(RTrim(@c_holdflag)), 'OK'),
                        Lottable01 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                          THEN Lottable01 ELSE @c_lottable01 END,
                        Lottable02 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                          THEN Lottable02 ELSE @c_lottable02 END,
                        Lottable03 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
                                     THEN Lottable03 ELSE @c_lottable03 END,
                        Lottable04 = @d_lottable04,
                        Lottable05 = @d_lottable05,
--                        ToId       = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND @cDocType = 'X' -- (Vicky03)
--                                     THEN ToId ELSE @c_id END,
                        ToID         = ISNULL(@c_id, ''),
                        Finalizeflag = CASE
                                          --WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' THEN Finalizeflag
                                          WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN Finalizeflag
                                          ELSE 'Y'
                                       END,
                        BeforeReceivedQty = CASE
                  --WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' THEN BeforeReceivedQty + @n_QtyDue
                                      WHEN @cRDT_NotFinalizeReceiptDetail = '1' THEN BeforeReceivedQty + @n_QtyTotal --@n_QtyDue is always 0 here
                                               ELSE BeforeReceivedQty
                                            END,
                        QtyExpected       = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1'  AND @cDocType = 'X' AND @c_receiptlinenumber <> @c_origreceiptlineno  --(Vicky03)
                                             THEN BeforeReceivedQty + @n_QtyDue
                                             ELSE QtyExpected
                                             END,
                        UserDefine10 = CASE WHEN @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1'  AND @cDocType = 'X' -- (Vicky03)
                                            THEN Suser_Sname()
                                            ELSE UserDefine10
                                       END
                     WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @c_receiptlinenumber

                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                      SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err) --, @n_err=60025 -- 65125   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                      SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                      GOTO QUIT
                     END
                     SET @cOpenQtyCalc = 'Y' -- (Vicky07)

                     IF (@n_continue = 1) OR (@n_continue = 2)
                     BEGIN
                        IF @cDuplicateFrom IS NOT NULL AND @cDuplicateFrom <> ''
                        BEGIN
                           -- Calc QTYExpected to borrow
                           SET @nBorrowQTYExpected = 0
                           SELECT @nBorrowQTYExpected =
                              CASE WHEN (QtyExpected - BeforeReceivedQty) >= @n_QtyTotal THEN @n_QtyTotal
                                   WHEN (QtyExpected - BeforeReceivedQty) > 0 AND @n_QtyTotal > 0
                                   THEN QtyExpected - BeforeReceivedQty
                              END
                           FROM ReceiptDetail WITH (NOLOCK)
                           WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @cDuplicateFrom

                           IF @nBorrowQTYExpected > 0
                           BEGIN
                              -- Reduce QTYExpected of parent
                              UPDATE RECEIPTDETAIL WITH (ROWLOCK) SET
                                 QTYExpected = QTYExpected - @nBorrowQTYExpected
                              WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @cDuplicateFrom
                              SELECT @n_err = @@ERROR
                              IF @n_err <> 0
                              BEGIN
                                  SELECT @n_continue = 3
                                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                                  GOTO QUIT
                              END

                              -- Increase QTYExpected to itself
                              UPDATE RECEIPTDETAIL WITH (ROWLOCK) SET
                                 QTYExpected = QTYExpected + @nBorrowQTYExpected
                              WHERE RECEIPTKEY = @c_prokey and ReceiptLineNumber = @c_receiptlinenumber
                              SELECT @n_err = @@ERROR
                              IF @n_err <> 0
                              BEGIN
                                  SELECT @n_continue = 3
                                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On RECEIPTDETAIL. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                                  GOTO QUIT
                              END
                           END
                           SET @cOpenQtyCalc = 'Y' -- (Vicky07)
                        END
                     END
                  END

                  /* Let's keep little track */
                  IF @c_PrevLineNumber <> @c_ReceiptLineNumber
                  BEGIN
                     IF @c_PrevLineNumber <> master.dbo.fnc_GetCharASCII(14)
                     BEGIN
                      SELECT @c_multiline = "1"
                     END
                     SELECT @c_PrevLineNumber = @c_ReceiptLineNumber
                  END
               END
            END
         END
         IF @b_cursor_receipts_open = 1
         BEGIN
            CLOSE CURSOR_RECEIPTS
            DEALLOCATE CURSOR_RECEIPTS
            SET @b_cursor_receipts_open = 0
         END

         IF @c_configkey = 'C4RFXDOCK' AND @c_sValue = '1' AND
            @c_PrevLineNumber <> @c_OrigReceiptLineNo AND @cDocType = 'X' -- (Vicky03)

         BEGIN
            UPDATE RECEIPTDETAIL
            SET    QtyExpected = QtyExpected - @n_Qty,
                   Trafficcop = NULL
            WHERE  Receiptkey = @c_prokey
            AND    ReceiptlineNumber = @c_OrigReceiptLineNo

            SET @cOpenQtyCalc = 'Y' -- (Vicky07)

         END
         /* 29-Nov-2004 YTWan RF Xdock Receiving - END */
      END
      /* Place the product on hold if dictated by the SKU table*/
      /* However, Place the product on hold only if IDs are used */
      IF @n_continue = 4 and ISNULL(RTrim(@c_id),'') <> ''
      BEGIN
           SELECT @n_continue = 1
      END

      IF ( @n_continue = 1 or @n_continue = 2) and ISNULL(RTrim(@c_id),'') <> ''
      BEGIN
          DECLARE @c_holdcode NVARCHAR(10)

           IF ISNULL(@cRDT_NotFinalizeReceiptDetail,'0') = '0' --NJOW01
              OR NOT EXISTS(
                              SELECT 1
                              FROM RECEIPT R (NOLOCK)
                              JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
                              JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku             
                              JOIN CODELKUP CL (NOLOCK) ON SKU.RECEIPTHOLDCODE = CL.CODE  
                              WHERE CL.Listname = 'INVHOLD'            
                              AND 1 = CASE WHEN R.DocType = 'R' AND ISNULL(CL.UDF02,'') = 'EXCL_RTN' THEN 2 ELSE 1 END  
                              AND R.Receiptkey = @c_Prokey
                              AND RD.Sku = @c_Sku
                              AND CONVERT(NVARCHAR(20), CL.Notes) IN('AUTOHOLDID','AUTOHOLDLOTTABLE02')
                           )
            BEGIN  
              SELECT @c_holdcode = receiptholdcode
                   FROM SKU (NOLOCK)
                   WHERE STORERKEY = @c_storerkey
                   AND SKU = @c_sku
              IF ISNULL(RTrim(@c_holdcode),'') <> ''
              BEGIN
                   SELECT @b_success = 0
                   EXECUTE nspInventoryHold
                        ""
                        , ""
                        , @c_id
                        , @c_holdcode
                        , "1"
                        , @b_Success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                   IF @b_success <> 1
                   BEGIN
                      SELECT @n_continue=3
                      SELECT @n_err = 60036
                   END
              END
           END 
      END

      -- SOS137640 Auto hold by lot if sku.receiptholdcode = 'HMCE'   (james01)
      -- when finalize only
      IF @cRDT_NotFinalizeReceiptDetail = '1' AND ( @n_continue = 1 or @n_continue = 2)
      BEGIN
         IF EXISTS (SELECT 1
            FROM  ReceiptDetail RD WITH (NOLOCK)
            JOIN SKU SKU (NOLOCK) ON (RD.STORERKEY = SKU.STORERKEY AND RD.SKU = SKU.SKU)
            JOIN CODELKUP CL (NOLOCK) ON (SKU.RECEIPTHOLDCODE = CL.CODE)
            WHERE RD.ReceiptKey = SUBSTRING(@c_Lottable02, 1, 10)
               AND RD.SKU = @c_sku
--               AND CL.CODE = 'HMCE'  --(james02)
               AND CONVERT(NVARCHAR(20), CL.Notes) = 'LOT')
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM InventoryHold WITH (NOLOCK)
               WHERE StorerKey = @c_storerkey
                  AND SKU = @c_sku
                  AND Lottable02 = @c_lottable02)
            BEGIN
               SELECT @b_success = 1

               --(james02)
               SELECT @c_CodeLKUp = CL.CODE
               FROM  ReceiptDetail RD WITH (NOLOCK)
               JOIN SKU SKU (NOLOCK) ON (RD.STORERKEY = SKU.STORERKEY AND RD.SKU = SKU.SKU)
               JOIN CODELKUP CL (NOLOCK) ON (SKU.RECEIPTHOLDCODE = CL.CODE)
               WHERE RD.ReceiptKey = SUBSTRING(@c_Lottable02, 1, 10)
                  AND RD.SKU = @c_sku
      --AND CL.CODE = 'HMCE'  (james02)
                  AND CONVERT(NVARCHAR(20), CL.Notes) = 'LOT'

               SET @c_Reason = 'AUTO HOLD on RECEIPT for REASON = ' + ISNULL(RTRIM(@c_CodeLKUp), '')      --(james02)

               EXEC nspInventoryHoldWrapper
                  '',               -- lot
                  '',               -- loc
                  '',               -- id
                  @c_StorerKey,     -- storerkey
                  @c_SKU,           -- sku
                  '',               -- lottable01
                  @c_Lottable02,    -- lottable02
                  '',               -- lottable03
                  NULL,             -- lottable04
                  NULL,             -- lottable05
                  '',               -- lottable06   --(CS01)
                  '',               -- lottable07   --(CS01)
                  '',               -- lottable08   --(CS01)
                  '',               -- lottable09   --(CS01)
                  '',               -- lottable10   --(CS01)
                  '',               -- lottable11   --(CS01)
                  '',               -- lottable12   --(CS01)
                  NULL,             -- lottable13   --(CS01)
                  NULL,             -- lottable14   --(CS01)
                  NULL,             -- lottable15   --(CS01)
                  @c_CodeLKUp,      -- status   (james02)
                  '1',              -- hold
                  @b_success OUTPUT,
                  @n_err OUTPUT,
                  @c_errmsg OUTPUT,
                  @c_Reason   -- remark   (james02)

               IF NOT @b_success = 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60046
                  SET @c_errmsg = 'InsInvHKeyFail (nspRFRC01)' --(james02)
               END
            END
         END
      END   -- End auto hold by lot (james01)

      /* Generate putaway Task Record                            */
      STARTPUTAWAY:
      IF @n_continue = 4 and ISNULL(RTrim(@c_id),'') <> ''
      BEGIN
           SELECT @n_continue = 1
      END
 -- Pallet id will not be in the system as it is generated by ASN.
      /* Verify that the palletid is recogzined in the system */
 --     IF @n_continue = 1 or @n_continue = 2
 --     BEGIN
 --          IF NOT EXISTS(SELECT * FROM ID WHERE ID = @c_id)
 --          BEGIN
 --               SELECT @n_continue = 3
 --               SELECT @n_err = 65130
 --               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Pallet ID Is Not In Inventory"
 --          END
 --     END
      /* End Verify that the palletid is recogzined in the system */
      /* Figure out whether or not now is the time to generate putaway task */
      IF ( @n_continue = 1 or @n_continue = 2) and ISNULL(RTrim(@c_id),'') <> ''
      BEGIN
           DECLARE @c_CreatePATaskOnRFReceipt NVARCHAR(10), @c_calculateputawaylocation NVARCHAR(10),
                    @c_newtaskdetailkey NVARCHAR(10)
           /* Pickup the putaway generation flag from the storer table */
           IF @n_continue = 1 or @n_continue = 2
           BEGIN
                IF ISNULL(RTrim(@c_StorerKey),'') <> ''
                BEGIN
                     SELECT @c_CreatePATaskOnRFReceipt = CreatePATaskOnRFReceipt,
                              @c_CalculatePutawayLocation = CalculatePutAwayLocation
                     FROM STORER (nolock)
                     WHERE STORERKEY = @c_storerkey

                     IF @c_CreatePATaskOnRFReceipt = "0" -- Do not generate putaway task
                     BEGIN
                                GOTO PUTAWAYEND
                     END
                     IF @c_CreatePATaskOnRFReceipt = "1" -- If QTYReceived = PalletPackQty,Generate PutawayTask
                   BEGIN
                       IF @c_prokey = "PALBLDDONE"
                       BEGIN
                           GOTO DOPUTAWAY
                   END
                       IF @n_toqty > 0 and ISNULL(RTrim(@c_packkey),'') <> ''
                       BEGIN
                            IF @n_toqty >= (SELECT pallet FROM PACK(nolock) WHERE PACKKEY = @c_packkey and pallet > 0)
                            BEGIN
                                 GOTO DOPUTAWAY
                            END
                            ELSE
                            BEGIN
                                 GOTO PUTAWAYEND
                            END
                       END
                       ELSE
                       BEGIN
                            GOTO PUTAWAYEND
                       END
                     END
                     IF @c_CreatePATaskOnRFReceipt = "2" -- If ProKey="PALBLDDONE", Generate PutawayTask
                     BEGIN
                        IF @c_prokey = "PALBLDDONE"
                        BEGIN
                            GOTO DOPUTAWAY
                        END
                        ELSE
                        BEGIN
                            GOTO PUTAWAYEND
                        END
                     END
                     -- Modified for HK. Putaway when pallet id exist, since every pallets received regardless of the quantity needs to be putaway.
                     IF @c_CreatePATaskOnRFReceipt = "3"
                     BEGIN
                        IF @c_id <> ''
                        BEGIN
                           GOTO DOPUTAWAY
                        END
                        ELSE
                        BEGIN
                           GOTO PUTAWAYEND
                        END
                     END
                     GOTO PUTAWAYEND
                END
                ELSE
                BEGIN
                     GOTO PUTAWAYEND
                END
           END
      END
      /* End figure out whether or not now is the time to generate putaway task */
      DOPUTAWAY:
      IF ( @n_continue = 1 or @n_continue = 2) and ISNULL(RTrim(@c_id),'') <> ''
      BEGIN
           /* DS: Do not generate new PA task for the ID if previous one is not completed */
           IF EXISTS ( SELECT * FROM TASKDETAIL
                        WHERE TaskType = 'PA' and FromId = @c_id
                          and Status <> '9' )
           BEGIN
              SELECT @n_continue = 4
           END
      END
 IF ( @n_continue = 1 or @n_continue = 2) and ISNULL(RTrim(@c_id),'') <> ''
      BEGIN
           /* calculate Put Away Capacity & get Put Away Logic */
           DECLARE @n_putawaycapacity int,
                @c_putcode NVARCHAR(30),
                @c_sourcekey NVARCHAR(30),
                @c_sourcetype NVARCHAR(30)
           SELECT @c_sourcekey = "", @c_sourcetype = "", @n_putawaycapacity = 0
           IF @c_prokey <> "NOASN" and @c_prokey <> "PALBLDDONE"
           BEGIN
                SELECT @c_sourcetype = "RECEIPTDETAIL"
                SET ROWCOUNT 1
                SELECT @c_sourcekey = @c_prokey + receiptdetail.receiptlinenumber
                     FROM RECEIPTDETAIL
                     WHERE RECEIPTKEY = @c_prokey and TOID = @c_id
                SET ROWCOUNT 0
                IF ISNULL(RTrim(@c_sourcekey),'') = ''
                BEGIN
                   SELECT @c_sourcekey = ""
                END
           END
           IF @c_CalculatePutAwayLocation = "1" -- Calculate the actual TO LOCATION Now!
           BEGIN
     /* Pickup the putaway code */
               IF ISNULL(RTrim(@c_sku),'') <> ''
               BEGIN
                     SELECT @n_putawaycapacity = @n_toqty * StdCube,
                            @c_putcode = PutCode
                          FROM SKU
                  WHERE StorerKey = @c_storerkey
                               AND Sku = @c_sku
                END
                IF ISNULL(RTrim(@c_putcode),'') = ''
                BEGIN
                     SELECT @c_putcode = "nspPASTD"
                END
                /* execute PutCode */
                --DECLARE @c_command NVARCHAR(255)
                DECLARE @c_command NVARCHAR(400)      -- ZG01
                SELECT @c_command = "EXECUTE "+LTrim(RTrim(@c_putcode))+" @c_userid= "+"'"+RTrim(@c_userid)+"'"+","+"
                       @c_storerkey='"+RTrim(@c_storerkey)+"',@c_lot='"+RTrim(@c_lot)+"',@c_sku='"+RTrim(@c_sku)+"',
                       @c_id='"+RTrim(@c_id)+"',@c_fromloc='"+RTRIM (@c_loc)+"',@n_qty="+ RTrim(CONVERT(NVARCHAR(15),@n_qty)) +
                       ",@c_uom='" + RTrim(@c_uom) + "',@c_packkey='" + RTrim(@c_packkey)+"', @n_putawaycapacity=" + RTrim(CONVERT(NVARCHAR(15),@n_putawaycapacity))

             EXEC(@c_command)
                IF NOT @@ERROR = 0
                BEGIN
                 SELECT @n_continue = 3
                     SELECT @n_err = 60027 -- 65128
                     SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad PutCode. (nspRFRC01)"
                END
                /* Get putaway location from cursor */
                IF @n_continue=1 OR @n_continue=2
                BEGIN
                     DECLARE @c_toloc NVARCHAR(30)
                     SELECT @c_toloc = SPACE(30)
                    /* fetch target location */
                     OPEN CURSOR_TOLOC
                     IF ABS(@@CURSOR_ROWS) = 0
                     BEGIN
                          CLOSE CURSOR_TOLOC
                          DEALLOCATE CURSOR_TOLOC
                          SELECT @n_continue = 3
                          SELECT @n_err = 60028 -- 65129
                          SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Cursor. (nspRFRC01)"
                     END
                     ELSE
                     BEGIN
                          FETCH NEXT
                               FROM CURSOR_TOLOC
                               INTO @c_toloc
                               IF NOT @@FETCH_STATUS = 0
                               BEGIN
                         SELECT @n_continue = 3
                                    SELECT @n_err = 60005 -- 65131
                                    SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Bad Location. (nspRFRC01)"
                               END
                          CLOSE CURSOR_TOLOC
                          DEALLOCATE CURSOR_TOLOC
                     END
                     /* Place putaway location in TASKDETAIL table */
                     IF ISNULL(RTRIM(@c_toloc),'') = ''
                     BEGIN
                        SELECT @c_toloc = ""
                     END
                     /* We will place a task in the table EVEN THOUGH THE */
                     /* location may not have been calculated!            */
                     /* Generate the next taskdetailkey */
                     SELECT @b_success = 1
                     EXECUTE   nspg_getkey
                     "TaskDetailKey"
                     , 10
                     , @c_newtaskdetailkey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @n_err = 60037
                     END
                     /* End Get The Key */
                     IF @n_continue = 1 or @n_continue = 2
                     BEGIN
                          INSERT TASKDETAIL
                               (
                               TaskDetailKey
                               ,TaskType
                               ,Storerkey
                               ,Sku
                               ,Lot
                               ,FromLoc
                               ,FromID
                               ,ToLoc
                               ,ToId
                               ,UOM
                               ,UOMQTY
                               ,QTY
                               ,Sourcekey
                               ,Sourcetype
                               )
                               VALUES
                               (
                                @c_newtaskdetailkey
                               ,"PA"
                               ,@c_storerkey
                               ,@c_sku
                               ,@c_lot
                               ,@c_loc
                               ,@c_id
                               ,@c_toLoc
                               ,@c_id
                               ,"6"
                               ,0
                               ,0
                               ,@c_sourcekey
                               ,@c_sourcetype
                               )
                          SELECT @n_err = @@ERROR
                          IF @n_err <> 0
                          BEGIN
                               SELECT @n_continue = 3
                               /* Trap SQL Server Error */
                               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60029 -- 65132   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On TaskDetail. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                               GOTO QUIT
          /* End Trap SQL Server Error */
                          END
                     END
                     /* End Place putaway location in TASKDETAIL table */
                END
                /* End Get putaway location from cursor */
           END
           ELSE
           BEGIN
           IF @c_CalculatePutAwayLocation = "2" --  Simply place ID in taskdetail table. Putaway Location Will Be Calculated Later
                BEGIN
                     SELECT @c_toloc = ""
                     /* Generate the next taskdetailkey */
                     SELECT @b_success = 1
                     EXECUTE   nspg_getkey
                            "TaskDetailKey"
                          , 10
                          , @c_newtaskdetailkey OUTPUT
                          , @b_success OUTPUT
                          , @n_err OUTPUT
                          , @c_errmsg OUTPUT
                     IF NOT @b_success = 1
                     BEGIN
                          SELECT @n_continue = 3
                   SELECT @n_err = 60037
                     END
                     /* End Get The Key */
                     IF @n_continue = 1 or @n_continue = 2
                     BEGIN
                      INSERT TASKDETAIL
                            (
                               TaskDetailKey
                              ,TaskType
                              ,Storerkey
                              ,Sku
                              ,Lot
                              ,FromLoc
                              ,FromID
                              ,ToLoc
                              ,ToId
                              ,UOM
                              ,UOMQTY
                              ,QTY
                              ,Sourcekey
                              ,Sourcetype
                               )
                               VALUES
                               (
                                @c_newtaskdetailkey
                               ,"PA"
                               ,@c_storerkey
                               ,@c_sku
                               ,@c_lot
                               ,@c_loc
                               ,@c_id
                               ,@c_toLoc
                               ,@c_id
                               ,"6"
                               ,0
                               ,0
                               ,@c_sourcekey
                               ,@c_sourcetype
                               )
                          SELECT @n_err = @@ERROR
                          IF @n_err <> 0
                          BEGIN
                               SELECT @n_continue = 3
                               /* Trap SQL Server Error */
                               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60029 -- 65133   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                               SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Insert Failed On TaskDetail. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                               GOTO QUIT
                               /* End Trap SQL Server Error */
                END
                     END
                END
           END  /* End IF @c_CalculatePutAwayLocation = 1 */
      END
      PUTAWAYEND:
      /* End Generate putaway Task Record */
      /* If we have updated more than 1 line let's report it */
      IF @c_multiline = "1"
      BEGIN
           SELECT @c_ReceiptLineNumber = "MANY"
      END
       -- jeff
      /* Set RF Return Record */
      IF @n_continue=3
      BEGIN
           IF @c_retrec="01"
           BEGIN
                SELECT @c_retrec="09"
           END
      END
      ELSE
      BEGIN
           IF @c_retrec = "" or @c_retrec = "09"
           BEGIN
            SELECT @c_retrec="01"
           END
      END
      /* End Set RF Return Record */
      /* Construct RF Return String */
      SELECT @c_outstring =   @c_ptcid
                 + @c_senddelimiter
                 + RTrim(@c_userid)           + @c_senddelimiter
                 + RTrim(@c_taskid)           + @c_senddelimiter
                 + RTrim(@c_databasename)     + @c_senddelimiter
                 + RTrim(@c_appflag)          + @c_senddelimiter
                 + RTrim(@c_retrec)           + @c_senddelimiter
                 + RTrim(@c_server)           + @c_senddelimiter
                 + RTrim(@c_prokey)           + @c_senddelimiter
                 + RTrim(@c_ReceiptLineNumber)+ @c_senddelimiter
                 + RTrim(@c_errmsg)

      IF @c_ptcid <> 'RDT'
         SELECT RTrim(@c_outstring)

      /* End Construct RF Return String */
      /* End Main Processing */
      /* Return Statement */

QUIT:
      IF @b_cursor_receipts_open = 1
      BEGIN
         CLOSE CURSOR_RECEIPTS
         DEALLOCATE CURSOR_RECEIPTS
         SET @b_cursor_receipts_open = 0
      END

      -- (Vicky07) - Start
      IF @n_continue=1 OR @n_continue= 2
      BEGIN
         IF @cOpenQtyCalc = 'Y' AND ISNULL(@cRDT_NotFinalizeReceiptDetail,'0') = '0'
         BEGIN
            UPDATE RECEIPT
              SET OpenQty = (SELECT SUM(QtyExpected) - SUM(QtyReceived)
                             FROM RECEIPTDETAIL
                             WHERE ReceiptKey = @c_ProKey)
            WHERE ReceiptKey = @c_ProKey

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                /* Trap SQL Server Error */
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60047 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On Receipt. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                /* End Trap SQL Server Error */
            END

            IF ISNULL(@cRDT_NotFinalizeReceiptDetail,'0') = '0'
            BEGIN
--                 (Shong)
--                IF EXISTS(SELECT 1 FROM RECEIPT (NOLOCK)
--                      WHERE ReceiptKey = @c_ProKey
--                        AND OpenQty = 0)
--                BEGIN
              IF NOT EXISTS (
              SELECT COUNT(DISTINCT SKU)
              FROM RECEIPTDETAIL WITH (NOLOCK)
              WHERE ReceiptKey = @c_ProKey
              GROUP BY SKU
           HAVING SUM(QtyReceived) < SUM(QtyExpected))
              BEGIN
                    UPDATE RECEIPT
                      SET ASNStatus = '9'
                    WHERE ReceiptKey = @c_ProKey AND OpenQty <= 0
              END
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                   SELECT @n_continue = 3
                   /* Trap SQL Server Error */
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60048 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                   SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Update Failed On Receipt. (nspRFRC01)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
                   /* End Trap SQL Server Error */
               END

            END
         END
      END
      -- (Vicky07) - End

      IF @n_continue=3  -- Error Occured - Process And Return
      BEGIN
        SELECT @b_success = 0
        IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
        BEGIN
             ROLLBACK TRAN
        END
        ELSE
        BEGIN
             WHILE @@TRANCOUNT > @n_starttcnt
             BEGIN
               COMMIT TRAN
             END
        END
        execute nsp_logerror @n_err2, @c_errmsg, "nspRFRC01"
        RAISERROR (@n_err, 10, 1) WITH SETERROR
      END
      ELSE
      BEGIN
        /* Error Did Not Occur , Return Normally */
        SELECT @b_success = 1
        WHILE @@TRANCOUNT > @n_starttcnt
        BEGIN
             COMMIT TRAN
        END
        RETURN
       END
      /* End Return Statement */
END

GO