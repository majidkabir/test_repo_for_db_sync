SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/ 
/* Store Procedure:  ntrReceiptDetailUpdate                                 */ 
/* Creation Date:                                                           */ 
/* Copyright: Maersk                                                        */ 
/* Written by:                                                              */ 
/*                                                                          */ 
/* Purpose:  ReceiptDetailUpdate Trigger                                    */ 
/*                                                                          */ 
/* Input Parameters:                                                        */ 
/*                                                                          */ 
/* Output Parameters:  None                                                 */ 
/*                                                                          */ 
/* Return Status:  None                                                     */ 
/*                                                                          */ 
/* Usage:                                                                   */ 
/*                                                                          */ 
/* Local Variables:                                                         */ 
/*                                                                          */ 
/* Called By:                                                               */ 
/*                                                                          */ 
/* PVCS Version: 1.20                                                       */ 
/*                                                                          */ 
/* Version: 6.0                                                             */ 
/*                                                                          */ 
/* Data Modifications:                                                      */ 
/*                                                                          */ 
/* Updates:                                                                 */ 
/* Date         Author    Ver.  Purposes                                    */ 
/* 07-Aug-2002  Vicky            Add more SQL error checking                */ 
/* 11-Sep-2002  RickyYee         Setup DefaultLottable_Returns to Facility  */ 
/*                               level (SOS33412)                           */ 
/* 17-Oct-2002  RickyYee         To solve the performance impact to the     */ 
/*                               finalize receipt (SOS8270)                 */ 
/* 07-Nov-2002  RickyYee         To default the oldest lottable05 when the  */ 
/*                               DefaultLottable_Returns key is turn on     */ 
/* 13-Mar-2003  Vicky            Changes made for NikeCN                    */ 
/* 14-Mar-2003  Shong            China Performance Tuning                   */ 
/* 18-Mar-2003  Shong            Lottable03 not updated                     */ 
/* 28-Mar-2003  June             If Allow_OverReceipt flag is on, check qty */ 
/*                               received against tolerance (SOS10549)      */ 
/* 21-Apr-2003  June             Obtain facility value for nspg_getright    */ 
/*                               for configure flag 'allow_overreceipt'     */ 
/* 21-Apr-2003  Vicky            Checking for Rectype when update Nike      */ 
/*                               China Sub-inv code (lottable03)            */ 
/* 24-Apr-2003  Vicky            New configkey to By pass tolerance when    */ 
/*                               doing over receiving (SOS10856)            */ 
/* 25-Apr-2003  June             Changes -> from Userdefine10 to            */ 
/*                               Receipt.Userdefine10 (SOS10724)            */ 
/* 08-May-2003  Vicky            Get PopulateSubInv from                    */ 
/*                               Facility.Userdefine10                      */ 
/* 04-Jun-2003  RickyYee         Branch 1.12.1.2 & 1.6.1.2 - Version 5.1    */ 
/*                               with CDC Changes and SOS11138              */ 
/* 12-Jun-2003  Shong            Performance Tuning                         */ 
/* 17-Jul-2003  June             Change lottable05 to date format(SOS12281) */ 
/* 04-Dec-2003  Shong            Added (NOLOCK) Into All Select Statement   */ 
/* 18-Feb-2004  Shong            Thailand Performance Tuning                */ 
/* 19-Feb-2004  Shong            Add more SQL error checking                */ 
/* 02-Apr-2004  Wally            UCC Receiving                              */ 
/* 21-Apr-2004  Wally            UCC Enhancement                            */ 
/* 26-Apr-2004  Shong            Bug Fixed                                  */ 
/* 29-Apr-2004  MaryVong         NZMM - Add ReturnReason configkey if       */ 
/*                               doctype='R'                                */ 
/* 11-May-2004  June             Do not prompt error if no value return for */ 
/*                               ispGetOldestLot                            */ 
/* 18-May-2004  Shong            Location Validation                        */ 
/* 14-Jul-2004  Wally            For UCCTracking: do not insert blank UCCs  */ 
/* 19-Jul-2004  Shong            Only default Lottable03 (NIKE CN Sub-Inv   */ 
/*                               Code) when Lottable03 is BLANK             */ 
/* 07-Sep-2004  Wally            Update datereceived column with getdate()  */ 
/* 01-Apr-2005  MaryVong         Setup DefaultLottable_Returns to Facility  */ 
/*                               level (SOS33412)                           */ 
/* 18-Apr-2005  MaryVong         Create Receipt Date for Lottable05 after   */ 
/*                               Finalized (SOS28761)                       */ 
/* 31-May-2005  UngDH            To support RDT                             */ 
/* 03-Aug-2006  UngDH            If UCC storer config on, update UCC table  */ 
/*                               upon finalize                              */ 
/* 24-Apr-2007  Shong            Performance Tuning                         */ 
/* 17-May-2007  June             SOS76025 : bug fixes null return from      */ 
/*                               ispGetOldestLot                            */ 
/* 18-Dec-2007  Shong            Remove Decimal Point for SUSR4 and SUSR1   */ 
/*                               if user included .00 at the back (SHONG001)*/ 
/* 09-Apr-2008  Shong            Performance Tuning When UCC Configflag ON  */ 
/*                               SOS#103630                                 */ 
/* 24-Sep-2008  KC        1.1    SOS# 115735 Pass facility to nspGetRight   */ 
/*                               for configkey 'ByPassTolerance'            */ 
/* 17-Mar-2009  TLTING    1.2   Change user_name() to SUSER_SNAME()         */ 
/* 12-Apr-2010  NJOW01    1.3   Skip update receipt.openqty if QtyExpected  */ 
/*                              and QtyReceived Qty fields are not modified */ 
/*                              SOS#167038                                  */ 
/* 06-Oct-2011  tlting01  1.4   Not allow change qtyreceived & qtyexpected  */ 
/*                              after ASNStatus ='9' SOS226641              */ 
/* 22-May-2012  TLTING02  1.5   DM Integrity issue - Update editdate for    */ 
/*                              status < '9'                                */ 
/* 06-Sep-2012  KHLim     1.6   Move up ArchiveCop (KH01)                   */ 
/* 21-Feb-2013  TLTING03  1.6   Avoid duplicate UCC insert, when regenerate */ 
/* 08-Apr-2013  KHLim     1.7   update UCC.qty even when Status = '1'(KH02) */ 
/* 02-Jun-2013  MCTang    1.8   SOS#280456 Add 'LOTCHGLOG' (MC01)           */ 
/* 31-Jul-2013  SHONG     1.9   Added New StorerConfig AddUCCFromUDF01      */ 
/*                              to Insert into UCC from UserDefine01 when   */ 
/*                              finalize                                    */ 
/* 17-Oct-2013  Shong     2.0   Dead Lock Patches                           */ 
/* 20-Nov-2012  Ung       2.1   SOS256003 UCC receive into multi RD         */ 
/*                              Disable check RD QTY > SUM UCC QTY          */ 
/* 28-Oct-2013  TLTING    2.2   Review Editdate column update               */ 
/* 02-Dec-2013  Ung       2.3   Prevent duplicate UCC rec in AddUCCFromUDF01*/ 
/* 10-Jan-2014  YTWan     2.4   SOS#298639 - Washington - Finalize by       */ 
/*                              Receipt Line (Wan01)                        */ 
/* 28-May-2014  TLTING03  2.4   Bug fix                                     */ 
/* 02-May-2014 NJOW02     2.5   309551-Cofigure codelkup to exclude lottable*/ 
/*                              label checking by document type.            */ 
/* 21-Oct-2014  CSCHONG   2.6   Merge in YTWAN 2.4 version                  */ 
/* 02-May-2014  Shong     2.7   Added Lottables 06-15                       */ 
/* 08-OCT-2014  CSCHONG   2.8   Add in lottable06 until 15 checking again   */ 
/*                              sku.lottablelabel (CS01)                    */ 
/* 10-Feb-2015  NJOW03    2.9   332903-add setting to Allow_OverReceipt     */ 
/*                              '2' allow for trade return only doctype=R   */ 
/*                              '3' allow for normal asn only doctype=A     */ 
/*                              '4' allow for xdock only doctype=X          */ 
/* 26-Apr-2015  Leong     3.0   Bug fix (Leong01).                          */ 
/* 31-Mar-2015  CSCHONG   3.1   SOS#337342 avoid invalid sku to be add (CS01) */ 
/* 08-Sep-2015  James     3.2   Revamp error no                             */ 
/* 26-Oct-2015  YTWan     3.3   SOS#353512 - Project Merlion - GW FRR       */ 
/*                              Suggested Putaway Location (Wan02)          */ 
/* 22-Jan-2015  TKLIM     3.4   New StorerConfig PopulatePalletLabel (TK02) */ 
/* 02-Aug-2016  Ung       3.5   IN00110559 Enable trigger pass out error    */ 
/* 10-Oct-2016  NJOW04    3.6   WMS-492 allow set storerconfig option to    */ 
/*                              exclude allow_overreceipt                   */ 
/* 03-May-2017  NJOW05    3.7   WMS-1798 Allow config to call custom sp     */ 
/* 15-May-2017  Ung       3.8   WMS-1817 Add serial no                      */ 
/* 06-Jul-2017  NJOW06    3.9   WMS-2291 Retrun include receipt type 'RGR'  */ 
/*                              for extract oldest lot5 by matching lot1-4  */ 
/* 28-Sep-2018  TLTING05  4.0   Perfroamnce tune                            */ 
/* 30-Jul-2017  Barnett   4.0   FBR-2352 Logic change on Insert PrintLabel  */ 
/*                              record (BL01)                               */ 
/* 08-Aug-2018  JihHaur   4.1   INC0366341 cannot insert new palletlabel    */ 
/*                              record (JH01)                               */ 
/* 18-sEP-2018  James     4.1   WMS-6326 Change SerialNoCapture config      */ 
/*                              Allow svalue 1 or 2 only                    */ 
/* 07-Feb-2018  SWT02     4.2   Channel Management                          */ 
/* 14-Nov-2018  ChewKP    4.3   WMS-6931 Update UCC.Status by LooseUCC      */ 
/*                              setup (ChewKP01)                            */ 
/* 04-APR-2019  CSCHONG   4.4   WMS-8345 new config ASNNoCheckSerialNoCapture*/      
/*                              to by pass serialnochecking (CS02)           */  
/* ************************************************************************ */ 
/* 14-May-2019  YokeBeen  1.20  WMS-8202 - Base on PVCS EXCEED_TG_V7        */ 
/*                              version 1.19. Auto set ASNStatus = '1' upon */ 
/*                              Receiving Starts - (YokeBeen01)             */ 
/* 27-Sep-2019  James     1.21  WMS-10434 Enhance ReceiptSerialNo qty       */ 
/*                              tally comparison (james01)                  */ 
/* 23-JUL-2019  Wan03     4.4   ChannelInventoryMgmt use fnc_SelectGetRight*/
/* 12-Dec-2019  James     4.5   WMS-11215 Add config to bypass receiptserial*/
/*                              checking (james02)                          */
/* 13-Jan-2020  NJOW07    4.6   WMS-11719 add storerconfig to copy receiptkey*/
/*                              to lottable when finalize ASN               */
/* 26-Mar-2020  NJOW09    4.8   WMS-12665 add config to copy receiptdetail  */
/*                              field to lottable when finalize asn         */
/* 15-Apr-2020  NJOW10    4.9   WMS-12880 add offset to ReturnDefaultLottable05*/ 
/* 09-Jun-2020  NJOW11    5.0   WMS-13612 add new column support for        */
/*                              CopyRecDetValueToLottable.                  */
/* 13-Jul-2020  NJOW12    5.1   WMS-14228 storerconfig add facility         */
/* 01-Jun-2021  NJOW13    5.2   WMS-16944 additional from ASNStatus change  */
/*                              to status 1 by codelkup                     */
/* 27-Aug-2021  TLTING06  5.3   Extend ExternReceiptKey field length        */
/* 14-Mar-2022  James     5.4   Fix RDT error no & message (james03)        */
/* 04-Aug-2022  WLChooi   5.5   WMS-20405 - Add ReceiptType 'VFEGRN' (WL01) */
/* 04-Aug-2022  WLChooi   5.5   DevOps Combine Script                       */
/* 16-Dec-2022  SPChin    5.6   JSM-99648 - Add Validation of FinalizeFlag  */
/* 29-Mar-2023  James     5.7   WMS-21943 Add UCCNo to SerialNo (james02)   */
/* 03-Aug-2023  NJOW14    5.8   WMS-23298 Update lot to serialno            */
/* 10-Nov-2023  TLTING07  5.9   Deadlock tune update UCC                    */
/* 15-Mar-2024  Wan04     6.0   UWP-16968-Post PalletType to Inventory When */
/*                              Finalize                                    */
/* 12-Dec-2024  Wan05     6.1   UWP-28399-INC7516794 - Non Serialize process*/
/****************************************************************************/ 
 
CREATE   TRIGGER [dbo].[ntrReceiptDetailUpdate] 
ON  [dbo].[RECEIPTDETAIL] 
FOR UPDATE 
AS 
IF @@ROWCOUNT = 0 
BEGIN 
   RETURN 
END 
 
SET NOCOUNT ON 
SET ANSI_NULLS OFF 
SET QUOTED_IDENTIFIER OFF 
SET CONCAT_NULL_YIELDS_NULL OFF 
 
DECLARE 
         @b_Success            int            -- Populated by calls to stored procedures - was the proc successful? 
       , @n_err                int            -- Error number returned by stored procedure or this trigger 
       , @n_err2               int            -- For Additional Error Detection 
       , @c_errmsg             NVARCHAR(250)  -- Error message returned by stored procedure or this trigger 
       , @n_continue           int 
       , @n_starttcnt          int            -- Holds the current transaction count 
       , @c_preprocess         NVARCHAR(250)  -- preprocess 
       , @c_pstprocess         NVARCHAR(250)  -- post process 
       , @n_cnt                int 
       , @c_authority          NVARCHAR(1)    -- Added by June 25.Jun.02 for IDSV5 
       , @c_DefaultLottable_Returns   NVARCHAR(1) -- Added by June 25.Jun.02 for IDSV5 
       , @c_DeftLot_Returns_Opt1 NVARCHAR(50)   --NJOW10
       , @c_StorerKey          NVARCHAR(15) 
       , @c_sku                NVARCHAR(20) 
       , @c_facility           NVARCHAR(5) 
       , @c_bypasstolerance    NVARCHAR(1) 
 
DECLARE  @c_CatchWeightFlag    NVARCHAR(1), 
         @c_authority_OverRcp  NVARCHAR(1), 
         @c_authority_ucc      NVARCHAR(1), 
         @c_PopulateSubInv     NVARCHAR(1), 
         @c_UCCTrackingFlag    NVARCHAR(1), 
         @c_AddUCCFromUDF01    NVARCHAR(10), 
         @c_ExternReceiptKey   NVARCHAR(50),       --TLTING06
         @c_DisallowInValidSKU NVARCHAR(1),         --(CS01) 
         @c_SkuStatus          NVARCHAR(10),        --(CS01) 
         @c_skustatusFlag      NVARCHAR(60)         --(CS01)  
 
DECLARE  @c_ReservePAloc       NVARCHAR(10)         --(Wan02)  
       , @c_PutAwayLoc         NVARCHAR(10)         --(Wan02) 
       , @c_Option1            NVARCHAR(30)   --NJOW04 
       , @c_Option2            NVARCHAR(30)   --NJOW04 
       , @c_Option3            NVARCHAR(30)   --NJOW04 
       , @c_Option4            NVARCHAR(30)   --NJOW04 
       , @c_Option5            NVARCHAR(2000) --NJOW04 
       , @c_SQL                NVARCHAR(2000) --NJOW04 
       , @c_SQLParam           NVARCHAR(2000) -- (james02)
       , @c_ByPassReceiptSerialQtyTallyChk   NVARCHAR( 30)  -- (james02)
    
SET @c_AddUCCFromUDF01   = '0' 
SET @c_UCCTrackingFlag   = '0' 
 
DECLARE @c_UCCNo               NVARCHAR(20) 
DECLARE @c_StorerConfig_UCC    NVARCHAR( 1) 
DECLARE @cUCCQTY               INT 
 
DECLARE @c_PODLottable01       NVARCHAR(18) 
      , @c_RECLottable01       NVARCHAR(18) 
      , @c_PODLottable02       NVARCHAR(18) 
      , @c_RECLottable02       NVARCHAR(18) 
      , @c_PODLottable03       NVARCHAR(18) 
      , @c_RECLottable03       NVARCHAR(18) 
      , @d_PODLottable04       DateTime 
      , @d_RECLottable04       DateTime 
      , @d_PODLottable05       DateTime 
      , @d_RECLottable05       DateTime 
      , @c_TransmitlogKey      NVARCHAR(10) 
      , @c_LOTCHGLOG           CHAR(1) 
      , @c_ReceiptKey          NVARCHAR(10) 
      , @c_ReceiptLineNumber   NVARCHAR(5) 
      , @c_PopPalletLabel      NVARCHAR(10)     --TK02 
      , @c_DelFinalizeFlag     NVARCHAR(10)     --TK02 
      , @c_DelToID             NVARCHAR(10)     --TK02 
      , @c_SerialNoCapture     NVARCHAR(1) 
      , @c_loseUCC             NVARCHAR(1) -- (ChewKP01)  
      , @c_ASNNoCheckSerialNoCapture NVARCHAR(1)   --CS02 
      , @c_CopyReceiptkeyToLottable      NVARCHAR(30)  --NJOW07
      , @c_CopyReceiptkeyToLottable_opt1 NVARCHAR(50) --NJOW07
      , @c_CopyReceiptkeyToLottable_opt2 NVARCHAR(50) --NJOW07
      , @c_CopyRecDetValueToLottable      NVARCHAR(30) --NJOW09
      , @c_CopyRecDetValueToLottable_opt1 NVARCHAR(50) --NJOW09
      , @c_CopyRecDetValueToLottable_opt2 NVARCHAR(50) --NJOW09
      , @c_CopyRecDetValue                NVARCHAR(30) --NJOW09
      , @n_SeqNo                          INT          --NJOW09
      , @c_FromColValue                   NVARCHAR(30) --NJOW09
      , @c_ToColValue                     NVARCHAR(30) --NJOW09
      , @c_Userdefine01                   NVARCHAR(30) --NJOW09
      , @c_Userdefine02                   NVARCHAR(30) --NJOW09
      , @c_Userdefine03                   NVARCHAR(30) --NJOW09
      , @c_Userdefine04                   NVARCHAR(30) --NJOW09
      , @c_Userdefine05                   NVARCHAR(30) --NJOW09
      , @d_Userdefine06                   DATETIME     --NJOW09
      , @d_Userdefine07                   DATETIME     --NJOW09
      , @c_Userdefine08                   NVARCHAR(30) --NJOW09
      , @c_Userdefine09                   NVARCHAR(30) --NJOW09
      , @c_Userdefine10                   NVARCHAR(30) --NJOW09
      , @c_ASNFizUpdLotToSerialNo         NVARCHAR(30) --NJOW14
      , @c_PalletType                     NVARCHAR(10) = ''                         --(Wan04) 
--NJOW11      
DECLARE @c_AltSku                         NVARCHAR(20)
      , @c_ContainerKey                   NVARCHAR(18)
      , @c_ExternPoKey                    NVARCHAR(20)
      , @c_POLineNumber                   NVARCHAR(5)
      , @n_UCC_RowRef                     bigINT

SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT 
 
 
IF UPDATE(ArchiveCop)      --KH01 
BEGIN 
   SELECT @n_continue = 4 
   GOTO QUIT 
END 
 
--TLTING02 
IF ( @n_continue=1 or @n_continue=2 ) AND NOT UPDATE(EditDate) 
BEGIN 
   UPDATE RECEIPTDETAIL WITH (ROWLOCK) 
   SET EditDate = GETDATE(), 
       EditWho  = SUSER_SNAME(), 
       TrafficCop = NULL 
   FROM RECEIPTDETAIL, DELETED, INSERTED 
   WHERE RECEIPTDETAIL.ReceiptKey  = DELETED.ReceiptKey  AND RECEIPTDETAIL.ReceiptLineNumber = DELETED.ReceiptLineNumber 
   AND RECEIPTDETAIL.ReceiptKey = INSERTED.ReceiptKey  AND RECEIPTDETAIL.ReceiptLineNumber = INSERTED.ReceiptLineNumber 
 
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
 
   IF @n_err <> 0 
   BEGIN 
      SELECT @n_continue = 3 
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=94208 
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Failed On Table RECEIPTDETAIL. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
      GOTO QUIT 
   END 
END 
 
IF UPDATE(TrafficCop) 
BEGIN 
   SELECT @n_continue = 4 
   GOTO QUIT 
END 
 
/* #INCLUDE <TRRDU1.SQL> */ 
 
--NJOW05 
IF @n_continue=1 or @n_continue=2           
BEGIN       
   IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action 
              JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey     
              JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue 
              WHERE  s.configkey = 'ReceiptDetailTrigger_SP')   -----> Current table trigger storerconfig 
   BEGIN             
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL 
         DROP TABLE #INSERTED 
 
      SELECT *  
      INTO #INSERTED 
      FROM INSERTED 
        
      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL 
         DROP TABLE #DELETED 
 
      SELECT *  
      INTO #DELETED 
      FROM DELETED 
 
      EXECUTE dbo.isp_ReceiptDetailTrigger_Wrapper ----->wrapper for current table trigger 
                'UPDATE'  -----> @c_Action can be INSERT, UPDATE, DELETE 
              , @b_Success  OUTPUT   
              , @n_Err      OUTPUT    
              , @c_ErrMsg   OUTPUT   
 
      IF @b_success <> 1   
      BEGIN   
         SELECT @n_continue = 3   
               ,@c_errmsg = 'ntrReceiptDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name 
      END   
       
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL 
         DROP TABLE #INSERTED 
 
      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL 
         DROP TABLE #DELETED 
   END 
END       
 
/*--------->>>>> Start FBRC03-1 <<<<<-----------*/ 
/* Author: Shong    */ 
/* Date: 04.20.2000    */ 
/*----------------------------------------------*/ 
-- Check if inserted QtyReceived > then deleted QtyReceived 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF UPDATE(QtyReceived) 
   BEGIN 
      IF EXISTS(SELECT 1 FROM INSERTED WHERE BeforeReceivedQty < QtyReceived) 
      BEGIN 
         UPDATE RECEIPTDETAIL WITH (ROWLOCK) 
         SET RECEIPTDETAIL.BeforeReceivedQty = INSERTED.QtyReceived, 
         TrafficCop = NULL 
         FROM   RECEIPTDETAIL, INSERTED, DELETED 
         WHERE  RECEIPTDETAIL.BeforeReceivedQty < INSERTED.QtyReceived 
         AND    RECEIPTDETAIL.ReceiptKey  = INSERTED.ReceiptKey 
         AND    RECEIPTDETAIL.ReceiptLineNumber = INSERTED.ReceiptLineNumber 
         AND    RECEIPTDETAIL.ReceiptKey  = DELETED.ReceiptKey 
         AND    RECEIPTDETAIL.ReceiptLineNumber = DELETED.ReceiptLineNumber 
         AND    INSERTED.QtyReceived > 0 
 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0 
         BEGIN 
            SELECT @n_continue = 3 
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60051 
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Failed On Table RECEIPTDETAIL. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
            GOTO QUIT 
         END 
      END 
   END 
END 
 
/*--------->>>>> END FBRC03-1 <<<<<----------*/ 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF EXISTS(SELECT 1 
             FROM INSERTED, DELETED 
             WHERE INSERTED.ReceiptKey  = DELETED.ReceiptKey  AND INSERTED.ReceiptLineNumber = DELETED.ReceiptLineNumber 
             AND DELETED.QtyReceived > 0 
             AND ( INSERTED.POKey <> DELETED.POKey  OR INSERTED.SKU <> DELETED.SKU OR INSERTED.Storerkey <> DELETED.Storerkey 
             OR (INSERTED.FinalizeFlag <> DELETED.FinalizeFlag AND DELETED.FinalizeFlag = 'Y')) --JSM-99648 
             )   
   BEGIN 
      SELECT @n_continue=3 
      SELECT @n_err=60052 
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)  
                       + ': Columns ''PO, SKU, STORER, FinalizeFlag'' may not be edited when QtyReceived > 0. Update on table ''ReceiptDetail'' rejected. (ntrReceiptDetailUpdate)' --JSM-99648 
      GOTO QUIT 
   END 
END 
 
 /*CS01 Start*/ 
IF (@n_continue = 1 OR @n_continue = 2) 
BEGIN 
   SET @c_skustatusFlag = '0' 
      
   SELECT @c_StorerKey = INSERTED.Storerkey , 
          @c_Sku = INSERTED.SKU, 
          @c_skustatusFlag = C.UDF01 
   FROM   SKU S WITH (NOLOCK) 
   JOIN CODELKUP C WITH (NOLOCK) ON UPPER(c.code)=UPPER(s.skustatus) 
   JOIN INSERTED WITH (NOLOCK) ON S.Storerkey = INSERTED.Storerkey 
   AND   S.SKU = INSERTED.SKU 
   WHERE C.listname='SKUStatus' 
 
   IF @c_skustatusFlag = ''  
   BEGIN 
      SET @c_skustatusFlag = '0' 
   END 
        
   SELECT @b_success = 0   
   EXECUTE nspGetRight null,    
         @c_StorerKey,     
         @c_Sku,       
         'DisallowReceiveInactiveSku',    
         @b_success         output,   
         @c_DisallowInvalidSku output,   
         @n_err          output,   
         @c_errmsg         output 
 
   IF @b_success <> 1   
   BEGIN 
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg)   
      SELECT @n_err = 60083  
   END   
   ELSE IF @c_DisallowInvalidSku = '1'   
   BEGIN   
         IF @c_skustatusFlag = '1' 
         BEGIN  
         SELECT @n_continue = 3          
         SELECT @c_errmsg = 'The status for SKU : ' + @c_sku + ' is INACTIVE.Insert Fail'    
         SELECT @n_err = 60084   
      END 
   END   
END 
   /*CS01 End*/   
 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF UPDATE(QtyReceived) 
   BEGIN 
      IF EXISTS(SELECT 1 
                FROM INSERTED, DELETED 
                WHERE INSERTED.ReceiptKey  = DELETED.ReceiptKey  AND INSERTED.ReceiptLineNumber = DELETED.ReceiptLineNumber 
                AND INSERTED.QtyReceived < DELETED.QtyReceived 
      ) 
      BEGIN 
         SELECT @n_continue=3 
         SELECT @n_err=60053 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)  
                          + ': Column ''QtyReceived'' may not be reduced. Update on table ''ReceiptDetail'' rejected. (ntrReceiptDetailUpdate)' 
      END 
   END 
END 
 
-- Added By SHONG on 18-May-2004 
-- Check Valid Location 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF EXISTS(SELECT 1  FROM INSERTED 
             LEFT OUTER JOIN LOC WITH (NOLOCK) ON (INSERTED.ToLOC = LOC.LOC) 
             WHERE FinalizeFlag = 'Y' 
             AND   LOC.LOC IS NULL ) 
   BEGIN 
      SELECT @n_continue=3 
      SELECT @n_err=60054 
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ' Invalid Location! Update on table ReceiptDetail Rejected. (ntrReceiptDetailUpdate)' 
      GOTO QUIT 
   END 
END 
-- Location Validation Completed 
 
-- (SWT02) 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF EXISTS(SELECT 1  
             FROM INSERTED
             INNER JOIN RECEIPT RH (NOLOCK) ON (INSERTED.Receiptkey = RH.Receiptkey)                                 --(Wan03)
             CROSS APPLY fnc_SelectGetRight (RH.Facility, INSERTED.Storerkey, '', 'ChannelInventoryMgmt') SC         --(Wan03) 
             --INNER JOIN StorerConfig SC WITH (NOLOCK)                                                              --(Wan03)         
             --     ON (SC.StorerKey = INSERTED.StorerKey AND SC.ConfigKey='ChannelInventoryMgmt' AND SC.SValue='1') --(Wan03)
             WHERE INSERTED.FinalizeFlag = 'Y'
             AND  (INSERTED.Channel IS NULL OR INSERTED.Channel = '' ) 
             AND  SC.Authority = '1')                                                                                --(Wan03)  
   BEGIN 
      SELECT @n_continue=3 
      SELECT @n_err=94215 
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ' Channel Cannot be BLANK. (ntrReceiptDetailUpdate)' 
      GOTO QUIT 
   END 
END 
-- Channel Management Validation Completed 
 
IF @n_continue=1 or @n_continue=2                                                   --(Wan04) - START
BEGIN 
   IF EXISTS(SELECT 1  
             FROM INSERTED
             INNER JOIN RECEIPT RH (NOLOCK) ON (INSERTED.Receiptkey = RH.Receiptkey) 
             JOIN dbo.Facility f (NOLOCK) ON RH.Facility = f.Facility
             WHERE INSERTED.FinalizeFlag = 'Y'
             AND  ((INSERTED.PalletType IS NULL OR INSERTED.PalletType = '') OR
                   (INSERTED.ToID IS NULL OR INSERTED.ToID = ''))
             AND  f.PalletTypeInUse = 'Yes')                                                                                   
   BEGIN 
      SELECT @n_continue=3 
      SELECT @n_err=94218
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Pallet Type And/OR To ID Cannot be BLANK. (ntrReceiptDetailUpdate)' 
      GOTO QUIT 
   END 
END                                                                                 --(Wan04) - END

-- tlting01 6-Oct 2011 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF UPDATE(QtyExpected) OR UPDATE(QtyReceived) OR UPDATE(BeforeReceivedQty) 
   BEGIN 
      IF EXISTS(SELECT 1  FROM RECEIPT WITH (NOLOCK) 
                JOIN INSERTED ON (INSERTED.RECEIPTKey = RECEIPT.RECEIPTKey) 
                WHERE RECEIPT.ASNStatus = '9' 
                ) 
      BEGIN 
         SELECT @n_continue=3 
         SELECT @n_err=94209 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ' Receipt Closed! Update on table ReceiptDetail Rejected. (ntrReceiptDetailUpdate)' 
         GOTO QUIT 
      END 
   END 
END 
 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF UPDATE(QtyReceived) OR UPDATE(BeforeReceivedQty) 
   BEGIN 
      IF EXISTS(SELECT 1  FROM Transmitlog3 WITH (NOLOCK) 
                JOIN INSERTED ON (INSERTED.RECEIPTKey = Transmitlog3.Key1) 
            WHERE Transmitlog3.TABLENAME = 'RCPTLOG' 
                ) 
      BEGIN 
         SELECT @n_continue=3 
         SELECT @n_err=60064 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ' Transmitlog Already Generated! Receiving Rejected. (ntrReceiptDetailUpdate)' 
         GOTO QUIT 
      END 
   END 
END 
 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   UPDATE RECEIPTDETAIL WITH (ROWLOCK) 
   SET RECEIPTDETAIL.QtyAdjusted = RECEIPTDETAIL.QtyAdjusted - DELETED.QtyExpected + INSERTED.QtyExpected, 
     -- EditDate = GETDATE(),       -- tlting02   duplicate update 
     -- EditWho=SUSER_SNAME(),      -- tlting02 
      TrafficCop =NULL 
   FROM RECEIPTDETAIL, DELETED, INSERTED 
   WHERE RECEIPTDETAIL.ReceiptKey  = DELETED.ReceiptKey  AND RECEIPTDETAIL.ReceiptLineNumber = DELETED.ReceiptLineNumber 
   AND RECEIPTDETAIL.ReceiptKey = INSERTED.ReceiptKey  AND RECEIPTDETAIL.ReceiptLineNumber = INSERTED.ReceiptLineNumber 
 
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
   IF @n_err <> 0 
   BEGIN 
      SELECT @n_continue = 3 
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60055 
      SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Failed On Table RECEIPTDETAIL. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                       + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
      GOTO QUIT 
   END 
END 
 
IF @n_continue = 1 or @n_continue=2 
BEGIN 
   -- Modify By SHONG on 12th Jun 2003 
   -- Performance Tuning 
    -- 17-Oct-2013 Shong (Dead lock) 
   IF UPDATE(QtyReceived) 
      AND EXISTS(SELECT 1 FROM INSERTED (NOLOCK) WHERE POKEY IS NOT NULL AND POKEY <> '' ) 
   BEGIN 
      UPDATE PODETAIL WITH (ROWLOCK) 
      SET PODETAIL.QtyReceived = PODETAIL.QtyReceived - DELETED.QtyReceived + INSERTED.QtyReceived, 
         EditDate = GETDATE(),   --tlting 
         EditWho = SUSER_SNAME() 
      FROM PODETAIL, DELETED, INSERTED 
      WHERE  PODETAIL.POKey = INSERTED.POKey 
      AND PODETAIL.POLineNumber = INSERTED.POLineNumber 
      AND PODETAIL.POKey = DELETED.POKey 
      AND PODETAIL.POLineNumber = DELETED.POLineNumber 
      -- END of Modification (SHONG) 
 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
      IF @n_err <> 0 
      BEGIN 
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update Failed On Table PODETAIL. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
         GOTO QUIT 
      END 
   END 
END 
 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   SELECT @b_success = 0 
   EXECUTE nspGetRight null,  -- facility 
         null,    -- Storerkey 
         null,    -- Sku 
         'CATCHWEIGHT', -- Configkey 
         @b_success     OUTPUT, 
         @c_CatchWeightFlag  OUTPUT, 
         @n_err2         OUTPUT, 
         @c_errmsg       OUTPUT 
 
   IF @b_success <> 1 
   BEGIN 
      SELECT @n_err = 60057 -- @n_err2 
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
      GOTO QUIT 
   END 
END 
 
--MC01 - S 
IF @n_continue=1 or @n_continue=2 
BEGIN 
   IF UPDATE(Lottable01) OR UPDATE(Lottable02) OR UPDATE(Lottable03) OR UPDATE(Lottable04) OR UPDATE(Lottable05) 
   BEGIN 
      SELECT @c_Storerkey = Storerkey 
      FROM  INSERTED 
 
      SELECT @b_success = 0 
      EXECUTE  nspGetRight 
               null,          -- facility 
               @c_Storerkey,  -- Storerkey 
               null, 
               'LOTCHGLOG',   -- Configkey 
               @b_success     OUTPUT, 
               @c_LOTCHGLOG   OUTPUT, 
               @n_err2        OUTPUT, 
               @c_errmsg      OUTPUT 
 
      IF @b_success <> 1 
      BEGIN 
         SELECT @n_err = 60085 -- @n_err2 
         SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
         GOTO QUIT 
      END  --IF @b_success <> 1 
      ELSE IF @c_LOTCHGLOG = '1' 
      BEGIN 
         SET @c_PODLottable01 = '' 
         SET @c_PODLottable02 = '' 
         SET @c_PODLottable03 = '' 
         SET @d_PODLottable04 = '' 
         SET @d_PODLottable05 = '' 
 
         DECLARE C_Detail_Rec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PODETAIL.Lottable01 
              , PODETAIL.Lottable02 
              , PODETAIL.Lottable03 
              , PODETAIL.Lottable04 
              , PODETAIL.Lottable05 
              , INSERTED.Lottable01 
              , INSERTED.Lottable02 
              , INSERTED.Lottable03 
              , INSERTED.Lottable04 
              , INSERTED.Lottable05 
              , INSERTED.ReceiptKey 
              , INSERTED.ReceiptLineNumber 
         FROM INSERTED 
         JOIN DELETED ON (INSERTED.ReceiptKey = DELETED.ReceiptKey 
                          AND INSERTED.ReceiptLineNumber = DELETED.ReceiptLineNumber) 
         JOIN PODETAIL WITH (NOLOCK) ON (PODETAIL.POKey = INSERTED.POKey 
                                         AND PODETAIL.POLineNumber = INSERTED.POLineNumber 
                                         AND PODETAIL.POKey = DELETED.POKey 
                                         AND PODETAIL.POLineNumber = DELETED.POLineNumber) 
         WHERE INSERTED.FinalizeFlag <> 'Y' 
         ORDER BY INSERTED.ReceiptKey 
                , INSERTED.ReceiptLineNumber 
 
         OPEN C_Detail_Rec 
 
         FETCH NEXT FROM C_Detail_Rec INTO @c_PODLottable01 
                                         , @c_PODLottable02 
                                         , @c_PODLottable03 
                                         , @d_PODLottable04 
                                         , @d_PODLottable05 
                                         , @c_RECLottable01 
                                         , @c_RECLottable02 
                                         , @c_RECLottable03 
                                         , @d_RECLottable04 
                                         , @d_RECLottable05 
                                         , @c_ReceiptKey 
                                         , @c_ReceiptLineNumber 
 
         WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 or @n_continue=2) 
         BEGIN 
            IF (ISNULL(@c_PODLottable01,'') <> ISNULL(@c_RECLottable01,'')) 
               OR (ISNULL(@c_PODLottable02,'') <> ISNULL(@c_RECLottable02,'')) 
               OR (ISNULL(@c_PODLottable03,'') <> ISNULL(@c_RECLottable03,'')) 
               OR (ISNULL(@d_PODLottable04,'') <> ISNULL(@d_RECLottable04,'')) 
               OR (ISNULL(@d_PODLottable05,'') <> ISNULL(@d_RECLottable05,'')) 
            BEGIN 
               SELECT @c_TransmitlogKey = '' 
               SELECT @b_success = 1 
 
               EXECUTE nspg_getkey 
                       'TransmitlogKey3' 
                     , 10 
                     , @c_TransmitlogKey OUTPUT 
                     , @b_success OUTPUT 
                     , @n_err OUTPUT 
                     , @c_errmsg OUTPUT 
 
               IF @b_success <> 1 
               BEGIN 
                  SELECT @n_err = 60086 -- @n_err2 
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
                  GOTO QUIT 
               END 
               ELSE 
               BEGIN 
                  INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag) 
                  VALUES  (@c_TransmitlogKey, 'LOTCHGLOG', @c_ReceiptKey, @c_ReceiptLineNumber, @c_StorerKey, '0') 
 
                  SELECT @n_err= @@Error 
 
                  IF NOT @n_err=0 
                  BEGIN 
                     SELECT @n_continue=3 
                     SELECT @n_err=60087 
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)+':  Unable to obtain transmitlogkey (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
      GOTO QUIT 
                  END 
               END 
            END 
 
            FETCH NEXT FROM C_Detail_Rec INTO @c_PODLottable01 
                                            , @c_PODLottable02 
                                            , @c_PODLottable03 
                                            , @d_PODLottable04 
                                            , @d_PODLottable05 
                                            , @c_RECLottable01 
                                            , @c_RECLottable02 
                                            , @c_RECLottable03 
                                            , @d_RECLottable04 
                                            , @d_RECLottable05 
                                            , @c_ReceiptKey 
                                            , @c_ReceiptLineNumber 
         END -- While 
      END --ELSE IF @c_LOTCHGLOG = '1' 
   END --IF UPDATE(Lottable02) OR UPDATE(Lottable04) 
END 
--MC01 - E 

--CS02 Start      
      
  -- Get ASNNoCheckSerialNoCapture storer config      
  SET @c_ASNNoCheckSerialNoCapture = '0'      
         IF @n_continue=1 or @n_continue=2      
         BEGIN      
            SELECT @b_success = 0      
            EXECUTE nspGetRight null,     -- facility      
               @c_StorerKey,             -- Storerkey      
               '',                        -- Sku      
               'ASNNoCheckSerialNoCapture', -- Configkey      
               @b_success                    output,      
               @c_ASNNoCheckSerialNoCapture  output,      
               @n_err                        output,      
               @c_errmsg                     output      
            IF @b_success <> 1      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @n_err = 60101      
               SELECT @c_errmsg = 'NSQL60101: nspGetRigth ASNNoCheckSerialNoCapture (ntrReceiptDetailUpdate)'      
            END      
         END      
      
--CS02 End 

IF @n_continue = 1 or @n_continue=2 
BEGIN 
   DECLARE 
   @n_ItrnSysId   int, 
   @c_LOT         NVARCHAR(10), 
   @c_ToLoc       NVARCHAR(10), 
   @c_ToID        NVARCHAR(18), 
   @c_Status      NVARCHAR(10), 
   @c_Lottable01  NVARCHAR(18), 
   @c_Lottable02  NVARCHAR(18), 
   @c_Lottable03  NVARCHAR(18), 
   @d_Lottable04  datetime, 
   @d_Lottable05  datetime, 
   @c_lottable06  NVARCHAR(30), 
   @c_lottable07  NVARCHAR(30), 
   @c_lottable08  NVARCHAR(30), 
   @c_lottable09  NVARCHAR(30), 
   @c_lottable10  NVARCHAR(30), 
   @c_lottable11  NVARCHAR(30), 
   @c_lottable12  NVARCHAR(30), 
   @d_lottable13  datetime, 
   @d_lottable14  datetime, 
   @d_lottable15  datetime, 
   @n_casecnt     int, 
   @n_innerpack   int, 
   @n_Qty         int, 
   @n_pallet      int, 
   @f_cube        float, 
   @f_grosswgt    float, 
   @f_netwgt      float, 
   @f_otherunit1  float, 
   @f_otherunit2  float, 
   @c_packkey     NVARCHAR(10), 
   @c_uom         NVARCHAR(10) , 
   @c_SourceKey   NVARCHAR(15), 
   @c_SourceType  NVARCHAR(30), 
   @d_EffectiveDate datetime, 
   @c_pokey        NVARCHAR(18) , 
   @c_FinalizeFlag NVARCHAR(1) 
 
   -- Added By Shong 1st Aug 
   DECLARE @c_Lottable01Label  NVARCHAR(20), 
        @c_Lottable02Label     NVARCHAR(20), 
        @c_Lottable03Label     NVARCHAR(20), 
        @c_Lottable04Label     NVARCHAR(20), 
        @c_Lottable05Label     NVARCHAR(20), 
        @c_Lottable06Label     NVARCHAR(20), 
        @c_Lottable07Label     NVARCHAR(20), 
        @c_Lottable08Label     NVARCHAR(20), 
        @c_Lottable09Label     NVARCHAR(20), 
        @c_Lottable10Label     NVARCHAR(20), 
        @c_Lottable11Label     NVARCHAR(20), 
        @c_Lottable12Label     NVARCHAR(20), 
        @c_Lottable13Label     NVARCHAR(20), 
        @c_Lottable14Label     NVARCHAR(20), 
        @c_Lottable15Label     NVARCHAR(20), 
        @c_RecType             NVARCHAR(10), 
        @c_ExternLineNo        NVARCHAR(20), 
        @n_TotQtyReceived      int, 
        @c_CopyPackKey         NVARCHAR(1), 
        @n_QtyExpected         int, 
        @c_authority_02        NVARCHAR(1), 
        @n_IncomingShelfLife   Bigint,        --tlting03 
        @c_SubReasonCode       NVARCHAR(10), 
        @n_TolerancePerc       Bigint,        --tlting03 
        @c_authority_ExpReason NVARCHAR(1), 
        @c_authority_RetReason NVARCHAR(1),   -- Added By MaryVong on 29-Apr-2004 (NZMM) 
        @c_DocType             NVARCHAR(1),   -- Added By MaryVong on 29-Apr-2004 (NZMM) 
        @c_Channel             NVARCHAR(20),  -- (SWT02) 
        @n_Channel_ID          BIGINT, -- (SWT02) 
        @n_SerialNoTotQtyReceived      INT     -- (james01) 
 
   DECLARE C_RECEIPTLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT INSERTED.ReceiptKey, 
            INSERTED.ReceiptLineNumber, 
            NULL, 
            INSERTED.StorerKey, 
            INSERTED.SKU, 
            '', 
            INSERTED.ToLoc, 
            INSERTED.ToID, 
            INSERTED.ConditionCode, 
            INSERTED.Lottable01, 
            INSERTED.Lottable02, 
            INSERTED.Lottable03, 
            INSERTED.Lottable04, 
            INSERTED.Lottable05, 
            INSERTED.Lottable06, 
            INSERTED.Lottable07, 
            INSERTED.Lottable08, 
            INSERTED.Lottable09, 
            INSERTED.Lottable10, 
            INSERTED.Lottable11, 
            INSERTED.Lottable12, 
            INSERTED.Lottable13, 
            INSERTED.Lottable14, 
            INSERTED.Lottable15, 
            INSERTED.casecnt, 
            INSERTED.innerpack, 
            INSERTED.QtyReceived - DELETED.QtyReceived, 
            INSERTED.QtyReceived, 
            INSERTED.QtyExpected, 
            INSERTED.pallet, 
            INSERTED.cube, 
            INSERTED.grosswgt, 
            INSERTED.netwgt, 
            INSERTED.otherunit1, 
            INSERTED.otherunit2, 
            INSERTED.packkey, 
            INSERTED.uom , 
            INSERTED.ReceiptKey  + INSERTED.ReceiptLineNumber, 
            'ntrReceiptDetailUpdate', 
            INSERTED.EffectiveDate, 
            0, 
            0, 
            ' ', 
            INSERTED.pokey , 
            INSERTED.FinalizeFlag, 
            SKU.Lottable01Label, 
            SKU.Lottable02Label, 
            SKU.Lottable03Label, 
            SKU.Lottable04Label, 
            SKU.Lottable05Label, 
            SKU.Lottable06Label, 
            SKU.Lottable07Label, 
            SKU.Lottable08Label, 
            SKU.Lottable09Label, 
            SKU.Lottable10Label, 
            SKU.Lottable11Label, 
            SKU.Lottable12Label, 
            SKU.Lottable13Label, 
            SKU.Lottable14Label, 
            SKU.Lottable15Label, 
            RECEIPT.RecType, 
            RECEIPT.DocType,     -- Added By MaryVong on 29-Apr-2004 (NZMM) 
            RECEIPT.Facility, 
            -- (SHONG001) Remove decimal point 
            -- TLTING03 
            CASE WHEN SKU.SUSR1 IS NOT NULL AND IsNumeric(SKU.SUSR1) = 1 
                 THEN Convert(BigINT, CONVERT(Float, SKU.SUSR1)) 
                 ELSE 0 
            END, 
            INSERTED.SubReasonCode, 
            INSERTED.ExternLineNo, 
            -- (SHONG001) Remove decimal point 
            CASE WHEN SKU.SUSR4 IS NOT NULL AND IsNumeric(SKU.SUSR4) = 1 
                 THEN Convert(BigINT, CONVERT(Float, SKU.SUSR4)) 
                 ELSE 0 
            END, 
            SKU.OnReceiptCopyPackkey, 
            DELETED.FinalizeFlag,    --(TK02) 
            DELETED.ToID,   --(TK02) 
            SKU.SerialNoCapture , 
            INSERTED.Channel,  --(SWT02) 
            RECEIPTDETAIL.Userdefine01, --NJOW09
            RECEIPTDETAIL.Userdefine02, --NJOW09
            RECEIPTDETAIL.Userdefine03, --NJOW09
            RECEIPTDETAIL.Userdefine04, --NJOW09
            RECEIPTDETAIL.Userdefine05, --NJOW09
            RECEIPTDETAIL.Userdefine06, --NJOW09
            RECEIPTDETAIL.Userdefine07, --NJOW09
            RECEIPTDETAIL.Userdefine08, --NJOW09
            RECEIPTDETAIL.Userdefine09, --NJOW09
            RECEIPTDETAIL.Userdefine10,  --NJOW09                        
            RECEIPTDETAIL.ExternReceiptKey, --NJOW11 
            RECEIPTDETAIL.AltSku, --NJOW11
            RECEIPTDETAIL.ContainerKey, --NJOW11
            RECEIPTDETAIL.ExternPoKey, --NJOW11
            RECEIPTDETAIL.POLineNumber --NJOW11 
          , INSERTED.PalletType                                                     --(Wan04)                            
      FROM INSERTED 
      JOIN DELETED ON (INSERTED.ReceiptKey  = DELETED.ReceiptKey AND INSERTED.ReceiptLineNumber = DELETED.ReceiptLineNumber) 
      JOIN SKU WITH (NOLOCK) ON (INSERTED.SKU = SKU.SKU AND INSERTED.StorerKey = SKU.StorerKey) 
      JOIN RECEIPT WITH (NOLOCK) ON (RECEIPT.ReceiptKey = INSERTED.ReceiptKey AND RECEIPT.ReceiptKey = DELETED.ReceiptKey) 
      JOIN RECEIPTDETAIL WITH (NOLOCK) ON INSERTED.Receiptkey = RECEIPTDETAIL.Receiptkey AND INSERTED.ReceiptLineNumber = RECEIPTDETAIL.ReceiptLineNumber --NJOW09      
      WHERE (INSERTED.QtyReceived - DELETED.QtyReceived > 0  OR INSERTED.BeforeReceivedQty - DELETED.BeforeReceivedQty > 0 ) 
      AND   INSERTED.FinalizeFlag = 'Y' 
      ORDER BY INSERTED.ReceiptKey ,INSERTED.ReceiptLineNumber 
 
   OPEN C_RECEIPTLINE 
 
   FETCH NEXT FROM C_RECEIPTLINE INTO 
       @c_ReceiptKey              ,@c_ReceiptLineNumber       ,@n_ItrnSysId          ,@c_StorerKey 
      ,@c_Sku                     ,@c_LOT                     ,@c_ToLoc 
      ,@c_ToID                    ,@c_Status                  ,@c_Lottable01 
      ,@c_Lottable02              ,@c_Lottable03              ,@d_Lottable04 
      ,@d_Lottable05              ,@c_Lottable06              ,@c_Lottable07 
      ,@c_Lottable08              ,@c_Lottable09              ,@c_Lottable10 
      ,@c_Lottable11              ,@c_Lottable12              ,@d_Lottable13 
      ,@d_Lottable14              ,@d_Lottable15 
      ,@n_casecnt                 ,@n_innerpack 
      ,@n_Qty                     ,@n_TotQtyReceived          ,@n_QtyExpected 
      ,@n_pallet                  ,@f_cube                ,@f_grosswgt 
      ,@f_netwgt                  ,@f_otherunit1              ,@f_otherunit2 
      ,@c_packkey                 ,@c_uom                     ,@c_SourceKey 
      ,@c_SourceType              ,@d_EffectiveDate           ,@b_Success 
      ,@n_err                     ,@c_errmsg                  ,@c_pokey 
      ,@c_FinalizeFlag            ,@c_Lottable01Label         ,@c_Lottable02Label 
      ,@c_Lottable03Label         ,@c_Lottable04Label         ,@c_Lottable05Label 
      ,@c_Lottable06Label         ,@c_Lottable07Label         ,@c_Lottable08Label 
      ,@c_Lottable09Label         ,@c_Lottable10Label         ,@c_Lottable11Label 
      ,@c_Lottable12Label         ,@c_Lottable13Label         ,@c_Lottable14Label 
      ,@c_Lottable15Label 
      ,@c_RecType                 ,@c_DocType                 ,@c_Facility 
      ,@n_IncomingShelfLife       ,@c_SubReasonCode           ,@c_ExternLineNo 
      ,@n_TolerancePerc           ,@c_CopyPackKey             ,@c_DelFinalizeFlag   ,@c_DelToID      --(TK02) 
      ,@c_SerialNoCapture         ,@c_Channel  -- (SWT02) 
      ,@c_Userdefine01, @c_Userdefine02, @c_Userdefine03, @c_Userdefine04, @c_Userdefine05  --NJOW09       
      ,@d_Userdefine06, @d_Userdefine07, @c_Userdefine08, @c_Userdefine09, @c_Userdefine10  --NJOW09
      ,@c_ExternReceiptKey, @c_AltSku, @c_ContainerKey, @c_ExternPoKey, @c_POLineNumber --NJOW11 
      ,@c_PalletType                                                                --(Wan04)            
 
   WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 or @n_continue=2) 
   BEGIN 
      /* added to bypass the whole SP if FinalizeFlag = 'N' */ 
      IF @c_FinalizeFlag = 'Y' 
      BEGIN 
         IF @c_CatchWeightFlag = '1' 
         BEGIN 
            IF EXISTS (SELECT 1 FROM LOTxIDDETAIl WITH (NOLOCK), INSERTED 
                       WHERE LOTxIDDetail.ReceiptKey  = @c_ReceiptKey 
                       and LOTxIDDetail.ReceiptLineNumber = @c_ReceiptLineNumber ) 
            BEGIN 
               SELECT @f_grosswgt = @f_grosswgt + @n_Qty * TareWeight 
               FROM  SKU WITH (NOLOCK) 
               WHERE SKU.StorerKey = @c_storerkey 
               AND SKU.SKU = @c_sku 
               AND SKU.IOFlag in ('I', 'B') 
            END 
         END -- @c_CatchWeightFlag = '1' 
 
         -- Serial no 
         IF @c_SerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY 
         AND @c_ASNNoCheckSerialNoCapture = '0'  --CS02
         BEGIN 
            -- (james01) 
            SELECT @n_SerialNoTotQtyReceived = INSERTED.QtyReceived 
            FROM INSERTED     
            JOIN SKU WITH (NOLOCK) ON (INSERTED.SKU = SKU.SKU AND INSERTED.StorerKey = SKU.StorerKey)     
            WHERE INSERTED.ReceiptKey = @c_ReceiptKey 
            AND   INSERTED.ReceiptLineNumber = @c_ReceiptLineNumber 
            AND   INSERTED.FinalizeFlag = 'Y'     
            AND   SKU.SerialNoCapture IN ( '1', '2') 
                  
            -- (james02)
            SELECT @b_success = 0 
            EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
               @c_StorerKey,    -- Storerkey 
               null,    -- Sku 
               'BYPASSRECEIPTSERIALQTYTALLYCHK', -- Configkey 
               @b_success     OUTPUT, 
               @c_ByPassReceiptSerialQtyTallyChk  OUTPUT, 
               @n_err2         OUTPUT, 
               @c_errmsg       OUTPUT 
 
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_err = 94217 -- @n_err2 
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
               GOTO QUIT 
            END 

            IF @c_ByPassReceiptSerialQtyTallyChk <> '1'
            BEGIN
               -- If it is a SP then exec as stored proc
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = @c_ByPassReceiptSerialQtyTallyChk AND type = 'P')
               BEGIN
                  SET @c_SQL = 'EXEC ' + RTRIM( @c_ByPassReceiptSerialQtyTallyChk) +
                     ' @cDocNo, @cDocLineNo, @cDocType, @cSKU, @nQty, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @c_SQLParam =
                     '@cDocNo          NVARCHAR( 10), ' +
                     '@cDocLineNo      NVARCHAR( 5),  ' +
                     '@cDocType        NVARCHAR( 1),  ' +
                     '@cSKU            NVARCHAR( 20), ' +
                     '@nQty            INT,           ' +
                     '@nErrNo          INT           OUTPUT, ' +
                     '@cErrMsg         NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @c_SQL, @c_SQLParam,
                     @c_ReceiptKey, @c_ReceiptLineNumber, @c_DocType, @c_Sku, @n_SerialNoTotQtyReceived, @n_err OUTPUT, @c_errmsg OUTPUT

                  IF @n_err <> 0
                     GOTO Quit
               END
               ELSE
               BEGIN
                  -- Check ReceiptSerialNo.QTY tally ReceiptDetail     
                  IF (SELECT ISNULL( SUM( QTY), 0)      
                     FROM dbo.ReceiptSerialNo WITH (NOLOCK)      
                     WHERE ReceiptKey = @c_ReceiptKey      
                       AND ReceiptLineNumber = @c_ReceiptLineNumber) <> @n_SerialNoTotQtyReceived      
                  BEGIN   
                     SELECT @n_continue = 3 
                     SELECT @n_err = 94211 
                     SELECT @c_errmsg = 'NSQL94211: ReceiptSerialNo QTY not tally (line=' + @c_ReceiptLineNumber + ')' 
                     BREAK 
                  END
               END 
            END
         END 
          
         -- Default Lottable 01 Start 
         IF @c_CopyPackKey = '1' 
         BEGIN 
            SELECT @c_Lottable01 = @c_PackKey 
         END 
 
         IF @c_Lottable01Label = 'GEN_WEEK' AND @d_Lottable04 IS NOT NULL 
         BEGIN 
            SELECT @c_Lottable01 = convert(char(4), datepart(year, @d_Lottable04)) 
                  + (replicate('0', 2-len(convert(char(2), datepart(wk, @d_Lottable04)))) 
                  + convert(char(2), datepart(wk, @d_Lottable04))) 
         END 
         -- Default Lottable 01 END 
         -- Default Lottable02 Start 
 
         -- This customization is for HK use. It looks at Lottable02Label = 'GDS_BATCH' 
         -- 2001/10/01 CS IDSHK FBR061 populate Lottable02 as current date if it is not specified 
         IF @c_Lottable02Label = 'GDS_BATCH' 
         BEGIN 
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02)) = '' or dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02)) IS  NULL 
            BEGIN 
               SELECT @c_Lottable02 = convert(char(8), getdate(), 112) -- YYYYMMDD 
            END 
         END 
         -- 10.1.99 WALLY 
 
         SELECT @b_success = 0 
         EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
               @c_StorerKey,  -- Storerkey 
               @c_Sku,           -- Sku 
               'Update Lot04 to Lot03', -- Configkey 
               @b_success     output, 
            @c_authority_02   output, 
               @n_err2         output, 
               @c_errmsg      output 
 
         IF @b_success <> 1 
         BEGIN 
            SELECT @n_err = 60070 -- @n_err2 
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
            BREAK 
         END 
         ELSE IF @c_authority_02 = '1' 
         BEGIN 
            IF @c_Lottable02Label = 'GEN_WEEK' AND @d_Lottable04 IS NOT NULL 
            BEGIN 
               SELECT @c_Lottable02 = convert(char(4), datepart(year, @d_Lottable04)) 
                     + (replicate('0', 2-len(convert(char(2), datepart(wk, @d_Lottable04)))) 
                     + convert(char(2), datepart(wk, @d_Lottable04))) 
            END 
         END 
         -- Default Lottable02 END 
 
         -- Start : SOS76025 - Move down 
         /* 
         -- SOS28761 
         -- IF @c_Lottable05Label = 'RCP_DATE' AND (@d_Lottable05 IS NULL) 
         IF @d_Lottable05 IS NULL 
         BEGIN 
            SELECT @d_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112)) 
         END 
         */ 
         -- End: SOS76025 - Move down 
 
         IF @c_RecType <> 'GRN' AND @c_Lottable03Label  = 'SUB-INV' 
         BEGIN 
            SELECT @b_success = 0 
            EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
                    @c_StorerKey,      -- Storerkey 
                    @c_Sku,            -- Sku 
                    'PopulateSubInv',       -- Configkey 
                    @b_success     output, 
                    @c_PopulateSubInv   output, 
                    @n_err2        output, 
                    @c_errmsg      output 
 
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_err = 60071 -- @n_err2 
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
            END 
            ELSE 
 
            IF @c_PopulateSubInv = '1' 
            BEGIN 
               -- populate subinventory codes on Lottable03 before finalizing. 
               -- Modify By SHONG on 13-Mar-2003 
               -- Performance Issues 
               -- 19-JUL-2004 By Shong, Only Default Lottable03 if it's BLANK 
               IF dbo.fnc_RTrim(@c_Lottable03) IS NULL OR dbo.fnc_RTrim(@c_Lottable03) = '' 
               BEGIN 
                  SELECT @c_Lottable03 = ISNULL(Facility.Userdefine10, '') 
                  FROM   FACILITY WITH (NOLOCK) 
                  WHERE  Facility = @c_Facility 
               END 
            END 
         END 

         --NJOW07 S         
         SELECT @b_success = 0 
         EXECUTE nspGetRight 
                 @c_Facility = @c_Facility,  -- facility --NJOW12
                 @c_Storerkey = @c_StorerKey,      -- Storerkey 
                 @c_Sku = @c_Sku,            -- Sku 
                 @c_configkey = 'CopyReceiptkeyToLottable',  -- Configkey 
                 @b_Success = @b_success     output, 
                 @c_Authority = @c_CopyReceiptkeyToLottable  output, 
                 @n_err = @n_err2        output, 
                 @c_errmsg = @c_errmsg      OUTPUT,
                 @c_Option1 = @c_CopyReceiptkeyToLottable_opt1 OUTPUT,
                 @c_Option2 = @c_CopyReceiptkeyToLottable_opt2 OUTPUT
 
         IF @b_success <> 1 
         BEGIN 
            SELECT @n_err = 60071 -- @n_err2 
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
         END 
         ELSE IF @c_CopyReceiptkeyToLottable IN('01','02','03','06','07','08','09','10','11','12')
         BEGIN                       
            SELECT @c_SQL = N'SELECT @c_Lottable' + LTRIM(RTRIM(@c_CopyReceiptkeyToLottable)) + ' = RTRIM(@c_Receiptkey) + ''' + RTRIM(LTRIM(ISNULL(@c_CopyReceiptkeyToLottable_opt1,'')))  + '''' +
                   CASE WHEN @c_CopyReceiptkeyToLottable_opt2 = 'RECEIPTLINENUMBER' THEN ' LTRIM(RTRIM(@c_ReceiptLineNumber)) '
                        WHEN @c_CopyReceiptkeyToLottable_opt2 = 'EXTERNLINENO' THEN ' LTRIM(RTRIM(ISNULL(@c_ExternLineNo,''''))) '
                   ELSE ''
                   END
                                                                                            
            EXEC sp_executesql @c_SQL,
            N'@c_Lottable01 NVARCHAR(18) OUTPUT, @c_Lottable02 NVARCHAR(18) OUTPUT, @c_Lottable03 NVARCHAR(18) OUTPUT, @c_Lottable06 NVARCHAR(30) OUTPUT, @c_Lottable07 NVARCHAR(30) OUTPUT,  
              @c_Lottable08 NVARCHAR(30) OUTPUT, @c_Lottable09 NVARCHAR(30) OUTPUT, @c_Lottable10 NVARCHAR(30) OUTPUT, @c_Lottable11 NVARCHAR(30) OUTPUT, @c_Lottable12 NVARCHAR(30) OUTPUT,
              @c_Receiptkey NVARCHAR(10), @c_ReceiptLineNumber NVARCHAR(5), @c_ExternLineNo NVARCHAR(20) ',
              @c_Lottable01 OUTPUT,                             
              @c_Lottable02 OUTPUT,                             
              @c_Lottable03 OUTPUT,                             
              @c_Lottable06 OUTPUT,                             
              @c_Lottable07 OUTPUT,                             
              @c_Lottable08 OUTPUT,                             
              @c_Lottable09 OUTPUT,                             
              @c_Lottable10 OUTPUT,                             
              @c_Lottable11 OUTPUT,                             
              @c_Lottable12 OUTPUT,                             
              @c_Receiptkey,
              @c_ReceiptLineNumber,
              @c_ExternLineNo
         END 
         --NJOW07 E
          
         --NJOW09 S         
         SELECT @b_success = 0 
         EXECUTE nspGetRight 
                 @c_Facility = @c_Facility,  -- facility --NJOW12
                 @c_Storerkey = @c_StorerKey,      -- Storerkey 
                 @c_Sku = @c_Sku,            -- Sku 
                 @c_configkey = 'CopyRecDetValueToLottable',  -- Configkey 
                 @b_Success = @b_success     output, 
                 @c_Authority = @c_CopyRecDetValueToLottable output, 
                 @n_err = @n_err2        output, 
                 @c_errmsg = @c_errmsg      OUTPUT,
                 @c_Option1 = @c_CopyRecDetValueToLottable_opt1 OUTPUT, --From receiptdetail field e.g. receiptkey, packkey, toid
                 @c_Option2 = @c_CopyRecDetValueToLottable_opt2 OUTPUT --to lottable field except datetime field e.g. lottable01, lottable08, lottable09
 
         IF @b_success <> 1 
         BEGIN 
            SELECT @n_err = 60072 -- @n_err2 
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
         END 
         ELSE IF @c_CopyRecDetValueToLottable ='1' AND ISNULL(@c_CopyRecDetValueToLottable_opt1,'') <> '' AND ISNULL(@c_CopyRecDetValueToLottable_opt2,'') <> ''
         BEGIN     
            DECLARE cur_RECDETVAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT SeqNo, ColValue
               FROM dbo.fnc_DelimSplit(',', @c_CopyRecDetValueToLottable_opt1)
               ORDER BY SeqNo

            OPEN cur_RECDETVAL    
         
            FETCH NEXT FROM cur_RECDETVAL INTO @n_SeqNo, @c_FromColValue 
            
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
            BEGIN                  
               SET @c_ToColValue = ''

               SELECT @c_ToColvalue = ColValue
               FROM dbo.fnc_DelimSplit(',', @c_CopyRecDetValueToLottable_opt2)
               WHERE SeqNo = @n_SeqNo
               
               IF @@ROWCOUNT = 0 OR @c_ToColvalue NOT IN('LOTTABLE01','LOTTABLE02','LOTTABLE03','LOTTABLE06','LOTTABLE07','LOTTABLE08','LOTTABLE09','LOTTABLE10','LOTTABLE11','LOTTABLE12', 
                                                          'USERDEFINE01','USERDEFINE02','USERDEFINE03','USERDEFINE04','USERDEFINE05','USERDEFINE08','USERDEFINE09','USERDEFINE10')
                  GOTO NEXT_SEQ
 
               SET @c_CopyRecDetValue = ''
               
               SELECT @c_CopyRecDetValue =
               CASE WHEN @c_FromColValue = 'RECEIPTKEY' THEN
                      @c_Receiptkey
                    WHEN @c_FromColValue = 'RECEIPTLINENUMBER' THEN
                      @c_ReceiptLineNumber
                    WHEN @c_FromColValue = 'TOLOC' THEN
                      @c_ToLoc
                    WHEN @c_FromColValue = 'TOID' THEN
                      @c_ToID
                    WHEN @c_FromColValue = 'LOTTABLE01' THEN
                      @c_Lottable01
                    WHEN @c_FromColValue = 'LOTTABLE02' THEN
                      @c_Lottable02
                    WHEN @c_FromColValue = 'LOTTABLE03' THEN
                      @c_Lottable03
                    WHEN @c_FromColValue = 'LOTTABLE04' THEN
                      CONVERT(NVARCHAR, @d_Lottable04, 120)
                    WHEN @c_FromColValue = 'LOTTABLE05' THEN
                      CONVERT(NVARCHAR, @d_Lottable05, 120)
                    WHEN @c_FromColValue = 'LOTTABLE06' THEN
                      @c_Lottable06
                    WHEN @c_FromColValue = 'LOTTABLE07' THEN
                      @c_Lottable07
                    WHEN @c_FromColValue = 'LOTTABLE08' THEN
                      @c_Lottable08
                    WHEN @c_FromColValue = 'LOTTABLE09' THEN
                      @c_Lottable09
                    WHEN @c_FromColValue = 'LOTTABLE10' THEN
                      @c_Lottable10
                    WHEN @c_FromColValue = 'LOTTABLE11' THEN
                      @c_Lottable11
                    WHEN @c_FromColValue = 'LOTTABLE12' THEN
                      @c_Lottable12
                    WHEN @c_FromColValue = 'LOTTABLE13' THEN
                      CONVERT(NVARCHAR, @d_Lottable13, 120)
                    WHEN @c_FromColValue = 'LOTTABLE14' THEN
                      CONVERT(NVARCHAR, @d_Lottable14, 120)
                    WHEN @c_FromColValue = 'LOTTABLE15' THEN
                      CONVERT(NVARCHAR, @d_Lottable15, 120)
                    WHEN @c_FromColValue = 'PACKKEY' THEN
                      @c_packkey
                    WHEN @c_FromColValue = 'UOM' THEN
                      @c_UOM
                    WHEN @c_FromColValue = 'POKEY' THEN
                      @c_pokey
                    WHEN @c_FromColValue = 'RECTYPE' THEN
                      @c_RecType
                    WHEN @c_FromColValue = 'DOCTYPE' THEN
                      @c_DocType
                    WHEN @c_FromColValue = 'EXTERNLINENO' THEN
                      @c_ExternLineNo
                    WHEN @c_FromColValue = 'EXTERNRECEIPTKEY' THEN --NJOW11           
                      @c_ExternReceiptkey
                    WHEN @c_FromColValue = 'ALTSKU' THEN --NJOW11           
                      @c_AltSku
                    WHEN @c_FromColValue = 'CONTAINERKEY' THEN --NJOW11           
                      @c_Containerkey
                    WHEN @c_FromColValue = 'EXTERNPOKEY' THEN --NJOW11           
                      @c_ExternPoKey
                    WHEN @c_FromColValue = 'POLINENUMBER' THEN --NJOW11           
                      @c_POLineNumber                       
                    WHEN @c_FromColValue = 'STORERKEY' THEN --NJOW11                                
                      @c_Storerkey
                    WHEN @c_FromColValue = 'SKU' THEN --NJOW11                                
                      @c_Sku
                    WHEN @c_FromColValue = '<EMPTY>' THEN
                      ''
                    ELSE 'INVALID'
               END
               
               IF @c_CopyRecDetValue = 'INVALID'
                  GOTO NEXT_SEQ         
                                   
               SELECT @c_SQL = N'SELECT @c_' + LTRIM(RTRIM(@c_ToColvalue)) + ' = RTRIM(ISNULL(@c_CopyRecDetValue,'''')) '
                                                                                               
               EXEC sp_executesql @c_SQL,
               N'@c_Lottable01 NVARCHAR(18) OUTPUT, @c_Lottable02 NVARCHAR(18) OUTPUT, @c_Lottable03 NVARCHAR(18) OUTPUT, @c_Lottable06 NVARCHAR(30) OUTPUT, @c_Lottable07 NVARCHAR(30) OUTPUT,  
                 @c_Lottable08 NVARCHAR(30) OUTPUT, @c_Lottable09 NVARCHAR(30) OUTPUT, @c_Lottable10 NVARCHAR(30) OUTPUT, @c_Lottable11 NVARCHAR(30) OUTPUT, @c_Lottable12 NVARCHAR(30) OUTPUT,
                 @c_Userdefine01 NVARCHAR(30) OUTPUT, @c_Userdefine02 NVARCHAR(30) OUTPUT, @c_Userdefine03 NVARCHAR(30) OUTPUT, @c_Userdefine04 NVARCHAR(30) OUTPUT, @c_Userdefine05 NVARCHAR(30) OUTPUT,
                 @c_Userdefine08 NVARCHAR(30) OUTPUT, @c_Userdefine09 NVARCHAR(30) OUTPUT, @c_Userdefine10 NVARCHAR(30) OUTPUT, @c_CopyRecDetValue NVARCHAR(30) ',
                 @c_Lottable01 OUTPUT,                             
                 @c_Lottable02 OUTPUT,                             
                 @c_Lottable03 OUTPUT,                             
                 @c_Lottable06 OUTPUT,                             
                 @c_Lottable07 OUTPUT,                             
                 @c_Lottable08 OUTPUT,                             
                 @c_Lottable09 OUTPUT,                             
                 @c_Lottable10 OUTPUT,                             
                 @c_Lottable11 OUTPUT,                             
                 @c_Lottable12 OUTPUT,
                 @c_Userdefine01 OUTPUT,
                 @c_Userdefine02 OUTPUT,
                 @c_Userdefine03 OUTPUT,
                 @c_Userdefine04 OUTPUT,
                 @c_Userdefine05 OUTPUT,
                 @c_Userdefine08 OUTPUT,
                 @c_Userdefine09 OUTPUT,
                 @c_Userdefine10 OUTPUT,
                 @c_CopyRecDetValue                                              
                                                  
               NEXT_SEQ:
               
               FETCH NEXT FROM cur_RECDETVAL INTO @n_SeqNo, @c_FromColValue               
            END
            CLOSE cur_RECDETVAL
            DEALLOCATE cur_RECDETVAL                                                                                    
         END 
         --NJOW09 E         
 
         IF @c_Lottable03Label = 'RCP_DATE' AND ( dbo.fnc_RTrim(@c_Lottable03) IS NULL OR  dbo.fnc_RTrim(@c_Lottable03) = '') 
         BEGIN 
            SELECT @c_Lottable03 = CONVERT(CHAR(10), GETDATE(), 21)  /* yyyy-mm-dd */ 
         END 
 
         IF @c_Lottable04Label = 'GENEXPDATE' AND (@d_Lottable04 IS NULL OR @d_Lottable04 = '19000101') 
         BEGIN 
            SELECT @d_Lottable04 = Convert(datetime, '31 dec 2099', 106)   /* yyyy-mm-dd */ 
         END 
 
         -- Added for IDSV5 by June 25.Jun.02, (extract from IDSHK) *** Start 
         IF @n_continue=1 or @n_continue=2 
         BEGIN 
            SELECT @b_success = 0 
            EXECUTE nspGetRight @c_Facility,        -- facility --NJOW12
                  @c_StorerKey,              -- Storerkey 
                  @c_Sku,                    -- Sku 
                  'DefaultLottable_Returns', -- Configkey 
                  @b_success                   output, 
                  @c_DefaultLottable_Returns   output, 
                  @n_err2                      output, 
                  @c_errmsg                    OUTPUT, 
                  @c_DeftLot_Returns_Opt1      output --NJOW10
 
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_err = 60072 -- @n_err2 
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
            END 
 
            IF @c_RecType <> 'NORMAL' AND @c_RecType <> 'RPO' AND @c_RecType <> 'RRB' AND @c_RecType <> 'TBLRRP' 
               AND  @c_DefaultLottable_Returns = '1' 
            BEGIN 
               IF LEN( ISNULL(RTRIM(@c_Lottable01),'') + ISNULL(RTRIM(@c_Lottable02),'') + 
                       ISNULL(RTRIM(@c_Lottable03),'') + ISNULL(RTRIM(@c_Lottable06),'') + 
                       ISNULL(RTRIM(@c_Lottable07),'') + ISNULL(RTRIM(@c_Lottable08),'') + 
                       ISNULL(RTRIM(@c_Lottable09),'') + ISNULL(RTRIM(@c_Lottable10),'') + 
                       ISNULL(RTRIM(@c_Lottable11),'') + ISNULL(RTRIM(@c_Lottable12),'') ) = 0 
               AND  @d_Lottable13 IS NULL 
               AND  @d_Lottable14 IS NULL 
               AND  @d_Lottable15 IS NULL 
               BEGIN 
                  EXEC ispGetOldestLot 
                       @c_RecType  -- Leong01 
                  ,    @c_Facility 
                  ,    @c_StorerKey 
                  ,    @c_SKU 
                  ,    @c_Lottable01  OUTPUT 
                  ,    @c_Lottable02  OUTPUT 
                  ,    @c_Lottable03  OUTPUT 
                  ,    @d_Lottable04  OUTPUT 
                  ,    @d_Lottable05  OUTPUT 
                  ,    @c_lottable06  OUTPUT 
                  ,    @c_lottable07  OUTPUT 
                  ,    @c_lottable08  OUTPUT 
                  ,    @c_lottable09  OUTPUT 
                  ,    @c_lottable10  OUTPUT 
                  ,    @c_lottable11  OUTPUT 
                  ,    @c_lottable12  OUTPUT 
                  ,    @d_lottable13  OUTPUT 
                  ,    @d_lottable14  OUTPUT 
                  ,    @d_lottable15  OUTPUT 
                  ,    @b_Success     OUTPUT 
                  ,    @n_err2        OUTPUT 
                  ,    @c_errmsg      OUTPUT 

                  --NJOW10
                  IF ISNUMERIC(@c_DeftLot_Returns_Opt1) = 1 AND @d_Lottable05 <> '1900-01-01' AND @d_Lottable05 IS NOT NULL
                  BEGIN
                      SET @d_Lottable05 = DATEADD(Day, CAST(@c_DeftLot_Returns_Opt1 AS INT), @d_Lottable05)
                  END                                 
               END 
            END 
         END -- @n_continue=1 or @n_continue=2 
 
         -- Start : SOS76025 - Move from top 
         IF @c_Lottable05Label = 'RCP_DATE' AND (@d_Lottable05 IS NULL) 
         BEGIN 
            SELECT @d_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112)) 
         END 
         -- End: SOS76025 
 
         IF @c_DefaultLottable_Returns = '1' -- Added for IDSV5 by June 25.Jun.02, (extract from IDSHK) 
         BEGIN 
            -- SOS 3333 for HK 
            -- for all return receipts (ERR, GRN types), the receipt date (Lottable05) of each sku will be defaulted to 1 day 
            -- before the oldest date in the system with the same lot01, lot02, lot03, lot04. 
            IF @c_RecType in ('ERR','GRN','RGR','VFEGRN') and @c_Lottable05Label = 'RCP_DATE'  --NJOW06   --WL01
            BEGIN 
               IF @d_Lottable04 <= '01/01/1900' OR @d_Lottable04 IS NULL 
               BEGIN 
                  -- Change by June 10.Jul.03 SOS12281 
                  -- select @d_Lottable05 = isnull(min(lotattribute.Lottable05),getdate()) 
                  SELECT @d_Lottable05 = isnull(min(lotattribute.Lottable05), CONVERT(DATETIME, CONVERT(CHAR(20), getdate(), 106))) 
                  FROM lotattribute WITH (NOLOCK) 
                  WHERE sku = @c_sku 
                  AND storerkey = @c_storerkey 
                  AND Lottable01 = @c_Lottable01 
                  AND Lottable02 = @c_Lottable02 
                  AND Lottable03 = @c_Lottable03 
               END 
               ELSE 
               BEGIN 
                  -- Change by June 10.Jul.03 SOS12281 
                  -- select @d_Lottable05 = isnull(min(lotattribute.Lottable05),getdate()) 
                  SELECT @d_Lottable05 = isnull(min(lotattribute.Lottable05), CONVERT(DATETIME, CONVERT(CHAR(20), getdate(), 106))) 
                  FROM lotattribute WITH (NOLOCK) 
                  WHERE sku = @c_sku 
                  AND storerkey = @c_storerkey 
                  AND Lottable01 = @c_Lottable01 
                  AND Lottable02 = @c_Lottable02 
                  AND Lottable03 = @c_Lottable03 
                  AND convert(char(8), Lottable04) = convert(char(8), @d_Lottable04) 
               END 
               
               --NJOW10
               IF ISNUMERIC(@c_DeftLot_Returns_Opt1) = 1 AND @d_Lottable05 <> '1900-01-01' AND @d_Lottable05 IS NOT NULL AND @@ROWCOUNT > 0
               BEGIN
                  SET @d_Lottable05 = DATEADD(Day, CAST(@c_DeftLot_Returns_Opt1 AS INT), @d_Lottable05)
               END                                                              
            END    -- END SOS 3333             
         END   -- Added for IDSV5 by June 25.Jun.02, (extract from IDSHK) 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable01Label)) > '' AND (@c_Lottable01 IS NULL OR @c_Lottable01 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE01' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60088 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable01 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable01Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02Label)) > '' AND (@c_Lottable02 IS NULL OR @c_Lottable02 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE02' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60089 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable02 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable02Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable03Label)) > '' AND (@c_Lottable03 IS NULL OR @c_Lottable03 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE03' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60090 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable03 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable03Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable04Label)) > '' AND (@d_Lottable04 <= '01/01/1900' OR @d_Lottable04 IS NULL) 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE04' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60091 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable04 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable04Label)) + ' REQUIRED' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable05Label)) > '' AND (@d_Lottable05 <= '01/01/1900' OR @d_Lottable05 IS NULL) 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE05' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60092 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable05 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable05Label)) + ' REQUIRED' 
               BREAK 
            END 
         END 
 
         /*CS01 start*/ 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable06Label)) > '' AND (@c_Lottable06 IS NULL OR @c_Lottable06 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE06' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60093 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable06 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable06Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable07Label)) > '' AND (@c_Lottable07 IS NULL OR @c_Lottable07 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE07' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60094 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable07 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable07Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable08Label)) > '' AND (@c_Lottable08 IS NULL OR @c_Lottable08 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE08' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60095 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable08 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable08Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable09Label)) > '' AND (@c_Lottable09 IS NULL OR @c_Lottable09 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE09' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60096 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable09 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable09Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable10Label)) > '' AND (@c_Lottable10 IS NULL OR @c_Lottable10 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE10' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60097 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable10 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable10Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable11Label)) > '' AND (@c_Lottable11 IS NULL OR @c_Lottable11 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE11' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60098 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable11 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable11Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable12Label)) > '' AND (@c_Lottable12 IS NULL OR @c_Lottable12 = '') 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE12' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60099 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable12 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable12Label)) + ' REQUIRED!' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable13Label)) > '' AND (@d_Lottable13 <= '01/01/1900' OR @d_Lottable13 IS NULL) 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE13' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60100 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable13 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable13Label)) + ' REQUIRED' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable14Label)) > '' AND (@d_Lottable14 <= '01/01/1900' OR @d_Lottable14 IS NULL) 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE14' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 94201 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable14 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable14Label)) + ' REQUIRED' 
               BREAK 
            END 
         END 
 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable15Label)) > '' AND (@d_Lottable15 <= '01/01/1900' OR @d_Lottable15 IS NULL) 
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'EXLOTLBCHK' AND Storerkey = @c_Storerkey AND Code = 'LOTTABLE15' AND CHARINDEX(@c_DocType, Long) > 0) --NJOW02 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 94202 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Lottable15 = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lottable15Label)) + ' REQUIRED' 
               BREAK 
            END 
         END 
         /*CS01 End*/ 
 
         SELECT @b_success = 0 
         EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
               @c_StorerKey,  -- Storerkey 
               @c_SKU,           -- Sku 
               'ExpiredReason',        -- Configkey 
               @b_success               output, 
               @c_authority_ExpReason   output, 
               @n_err2                  output, 
               @c_errmsg                output 
 
         IF @b_success <> 1 
         BEGIN 
            SELECT @n_err = 60073 -- @n_err2 
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
            BREAK 
         END 
         ELSE IF @c_authority_ExpReason = '1' 
         BEGIN 
            -- Added for IDSV5 by June 25.Jun.02, (Extract from IDSHK) *** 
            -- Reasoncode required for receipt of expired products 
            -- Check for Incoming Shelf Life. This is based on the column SUSR1 in SKU table. 
            -- If the column is not blank, calculate the incoming shelf life, and prompt for reason code if it exceeded the shelf life. 
            -- This however, is based on whether the column Lottable04Label is setup as EXP_DATE. 
            -- check during finalize. 
            IF @c_Lottable04Label = 'EXP_DATE' AND @n_IncomingShelfLife > 0 AND @c_FinalizeFlag = 'Y' 
            BEGIN 
               IF DATEADD (day, @n_IncomingShelfLife, Getdate() ) > @d_Lottable04 AND 
                  (dbo.fnc_RTrim(@c_SubReasonCode) IS NULL OR dbo.fnc_RTrim(@c_SubReasonCode) = '' ) 
               BEGIN 
                  SELECT @n_continue=3 
                  SELECT @n_err=60058 
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Product is due to expire for Detail Line: ' 
                        + ISNULL(RTrim(@c_ReceiptLineNumber),'') + '. Sub-Reason code required ((ntrReceiptDetailUpdate))' 
                  BREAK 
               END 
            END 
         END  -- END - Reasoncode required for receipt of expired products 
 
         SELECT @b_success = 0 
 
         SELECT @c_Option1 = '', @c_Option2 = '', @c_Option3 = '', @c_Option4 = '', @c_Option5 = '' --NJOW04 
         Execute nspGetRight @c_facility, 
               @c_storerkey, 
               @c_sku, 
               'Allow_OverReceipt', -- Configkey 
               @b_success             output, 
               @c_authority_OverRcp   output, 
               @n_err2                output, 
               @c_errmsg              output, 
               @c_Option1             output,  --NJOW04 
               @c_Option2             output, --NJOW04 
               @c_Option3             output,  --NJOW04 
               @c_Option4             output,  --NJOW04 
               @c_Option5             output  --NJOW04 
 
         IF @b_success <> 1 
         BEGIN 
            SELECT @n_err = 60074 -- @n_err2 
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
            BREAK 
         END 
         ELSE -- Success = 1 
         BEGIN 
            --IF @c_authority_OverRcp <> '1' 
            IF (ISNULL(@c_authority_OverRcp,'0') IN('0','')) OR (@c_authority_OverRcp = '2' AND @c_DocType <> 'R') --NJOW03 
               OR (@c_authority_OverRcp = '3' AND @c_DocType <> 'A') OR (@c_authority_OverRcp = '4' AND @c_DocType <> 'X')--NJOW03 
            BEGIN 
               IF @n_TotQtyReceived > @n_QtyExpected 
               BEGIN 
                  SELECT @n_continue = 3 
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60059 
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Insert Failed on Table ReceiptDetail (ntrReceiptDetailUpdate) - CANNOT RECEIVE MORE THAN EXPECTED...' 
                  BREAK 
               END 
            END 
            ELSE 
            BEGIN -- Allow OverReceipt 
               --NJOW04 
               IF ISNULL(@c_Option5,'') <> '' 
               BEGIN 
                  SET @n_cnt = 0 
                  IF LEFT(LTRIM(@c_Option5),4) <> 'AND ' 
                     SET @c_Option5 = 'AND ' + LTRIM(RTRIM(@c_Option5)) 
                     
                  SET @c_SQL = N'SELECT @n_cnt = COUNT(1)  
                              FROM RECEIPT (NOLOCK) 
                              JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey                                                                  
                              WHERE RECEIPT.Receiptkey = @c_Receiptkey  
                              AND RECEIPTDETAIL.ReceiptLineNumber = @c_ReceiptLineNumber ' + RTRIM(@c_Option5) 
                                  
                  EXEC sp_executesql @c_SQL, 
                       N'@n_cnt INT OUTPUT, @c_Receiptkey NVARCHAR(10), @c_ReceiptLineNumber NVARCHAR(5)',  
                       @n_cnt OUTPUT, 
                       @c_ReceiptKey, 
                       @c_ReceiptLineNumber 
                                     
                  IF @n_cnt = 0      
                  BEGIN 
                     IF @n_TotQtyReceived > @n_QtyExpected 
                     BEGIN 
                        SELECT @n_continue = 3 
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60059 --63702   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                        SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err) + ': Insert Failed on Table ReceiptDetail (ntrReceiptDetailUpdate) - CANNOT RECEIVE MORE THAN EXPECTED...' 
                        BREAK 
                     END 
                  END 
               END 
                
               SELECT @b_success = 0 
 
               EXECUTE nspGetRight 
                     --null, -- Facility SOS# 115735 
                     @c_facility, -- SOS#115735 
                     @c_storerkey, 
                     null, 
                     'ByPassTolerance', 
                     @b_success           output, 
                     @c_bypasstolerance   output, 
                     @n_err2              output, 
                     @c_errmsg            output 
 
               IF @b_success <> 1 
               BEGIN 
                  SELECT @n_err = 60075 -- @n_err2 
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
               END 
               ELSE -- Success = 1 
               IF @c_bypasstolerance <> '1' 
               BEGIN 
                  IF (@n_TotQtyReceived) > (@n_QtyExpected * (1 + (@n_TolerancePerc * 0.01))) 
                  BEGIN 
                     SELECT @n_continue = 3 
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60060 
                     SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err) + ': Insert Failed on Table ReceiptDetail (ntrReceiptDetailUpdate) - Qty Received More Exceed Tolerance ...' 
                     BREAK 
                  END 
               END 
            END 
         END  -- END Check Tolerance n Over receive 
 
         -- Added By MaryVong on 29-Apr-2004 (NZMM) 
         -- Set SubReasonCode to mandotary if DocType = Return 
         SELECT @b_success = 0 
         EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
               @c_StorerKey,      -- Storerkey 
               null,              -- Sku 
               'ReturnReason',    -- Configkey 
               @b_success              output, 
               @c_authority_RetReason  output, 
               @n_err2                 output, 
               @c_errmsg               output 
 
         IF @b_success <> 1 
         BEGIN 
            SELECT @n_err = 60076 -- @n_err2 
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUPdate' + dbo.fnc_RTrim(@c_errmsg) 
            BREAK 
         END 
         ELSE IF @c_authority_RetReason = '1' 
         BEGIN 
            IF @c_DocType = 'R' AND (dbo.fnc_RTrim(@c_SubReasonCode) = '' OR dbo.fnc_RTrim(@c_SubReasonCode) IS NULL) 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60061 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': VALIDATION ERROR: ASN Detail Sub-Reason Code Required.' 
               BREAK 
            END 
         END  -- END Set SubReasonCode to mandotary if DocType = Return 
 
         -- Added By Jeff for NIKECN 4.Feb.2003 -> Upon finalize Receipt, update the UCC table records = '9' 
         IF @n_continue = 1 OR @n_Continue = 2 
         BEGIN 
            SELECT @b_success = 0 
            EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
                  @c_StorerKey,        -- Storerkey 
                  @c_Sku,              -- Sku 
                  'UPDATEUCC',         -- Configkey 
                  @b_success         output, 
                  @c_authority_ucc   output, 
                  @n_err2            output, 
                  @c_errmsg          output 
 
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
               SELECT @n_err = 60077 
            END 
            ELSE 
            IF @c_authority_ucc = '1' 
                  AND EXISTS ( SELECT 1 from  UCC (NOLOCK) WHERE UCC.SourceKey = @c_SourceKey AND UCC.UCCNo = @c_ExternLineNo AND UCC.Status = '0' ) 
            BEGIN 
               UPDATE UCC 
               SET STATUS = '2', 
                  EditDate = GETDATE(),   --tlting 
                  EditWho = SUSER_SNAME() 
               FROM UCC WITH (NOLOCK) 
               WHERE UCC.SourceKey = @c_SourceKey 
               AND UCC.UCCNo       = @c_ExternLineNo 
               AND UCC.Status = '0' 
 
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
               IF @n_err <> 0 
               BEGIN 
                  SELECT @n_continue = 3 
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60062 
                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err) + ': Update Failed On Table UCC. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
               END 
            END 
         END -- @n_continue = 1 OR @n_Continue = 2 
 
         UPDATE RECEIPTDETAIL WITH (ROWLOCK) 
            SET Lottable01 = @c_Lottable01, 
                Lottable02 = @c_Lottable02, 
                Lottable03 = @c_Lottable03, 
                Lottable04 = @d_Lottable04, 
                Lottable05 = @d_Lottable05, 
                Lottable06 = @c_Lottable06, 
                Lottable07 = @c_Lottable07, 
                Lottable08 = @c_Lottable08, 
                Lottable09 = @c_Lottable09, 
                Lottable10 = @c_Lottable10, 
                Lottable11 = @c_Lottable11, 
                Lottable12 = @c_Lottable12, 
                Lottable13 = @d_Lottable13, 
                Lottable14 = @d_Lottable14, 
                Lottable15 = @d_Lottable15, 
                BeforeReceivedQty = CASE WHEN BeforeReceivedQty < @n_TotQtyReceived THEN 
                                         @n_TotQtyReceived 
                                    ELSE BeforeReceivedQty 
                                    END, 
                DateReceived = GETDATE(), --SOS 26930 
                TrafficCop = NULL, 
                EditDate = GETDATE(),   --tlting 
                EditWho = SUSER_SNAME(),
                Userdefine01 = @c_Userdefine01, --NJOW09 S
                Userdefine02 = @c_Userdefine02, 
                Userdefine03 = @c_Userdefine03, 
                Userdefine04 = @c_Userdefine04, 
                Userdefine05 = @c_Userdefine05,
                Userdefine06 = @d_Userdefine06, 
                Userdefine07 = @d_Userdefine07, 
                Userdefine08 = @c_Userdefine08, 
                Userdefine09 = @c_Userdefine09, 
                Userdefine10 = @c_Userdefine10  --NJOW09 E                               
         WHERE RECEIPTDETAIL.Receiptkey = @c_ReceiptKey 
         AND   RECEIPTDETAIL.RECEIPTLINENUMBER = @c_ReceiptLineNumber 
 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0 
         BEGIN 
            SELECT @n_continue = 3 
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60063 
            SELECT @c_errmsg = 'NSQL'  +CONVERT(char(5),@n_err) + ': Update Failed On Table RECEIPTDETAIL. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
            BREAK 
         END 
 
         -- Get UCC storer config 
         IF @n_continue=1 or @n_continue=2 
         BEGIN 
            SELECT @b_success = 0 
            EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
                  @c_StorerKey,       -- Storerkey 
                  '',                 -- Sku 
                  'UCC',              -- Configkey 
                  @b_success          output, 
                  @c_StorerConfig_UCC output, 
                  @n_err              output, 
                  @c_errmsg           output 
 
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err = 60080 
               SELECT @c_errmsg = 'NSQL60080: nspGetRigth UCC (ntrReceiptDetailUpdate)' 
               BREAK 
            END 
         END 
 
         -- Check UCC QTY vs ReceiptDetail.QTYReceived 
         IF (@n_continue = 1 OR @n_continue = 2) AND @c_StorerConfig_UCC = '1' 
         BEGIN 
            SET @cUCCQTY = 0 
 
            SELECT @cUCCQTY = IsNULL( SUM( UCC.QTY), 0) 
            FROM UCC WITH (NOLOCK, INDEX(IX_UCC_Receipt)) -- SOS#103630 
            WHERE Receiptkey = @c_ReceiptKey 
              AND ReceiptLineNumber = @c_ReceiptLineNumber 
              AND Status = '1' -- 1-Received 
 
/* SOS256003 
            -- Both lose QTY and UCC can receive on the same ReceiptDetail line. When user modify ReceiptDetail from workstation, 
            -- UCC table is not updated. So make sure QTY receive >= UCC QTY. Greater means we have lose QTY also 
            IF @cUCCQTY > @n_QTY 
            BEGIN 
               SELECT @n_continue = 3 
               SELECT @n_err =  
               SELECT @c_errmsg= 'NSQL60081: ReceiveDetail.QTY < UCC.QTY (ntrReceiptDetailUpdate)' 
               BREAK 
            END 
*/ 
         END 
 
         --TK02 - End 
         IF (@n_continue = 1 OR @n_continue = 2) And (@c_FinalizeFlag = 'Y' OR @c_DelFinalizeFlag = 'Y') 
         BEGIN 
            SELECT @b_success = 0 
             
            EXECUTE nspGetRight @c_Facility, --NJOW12
                     @c_StorerKey, 
                     '', 
                     'PopulatePalletLabel', 
                     @b_success              output, 
                     @c_PopPalletLabel  output, 
                     @n_err                  output, 
                     @c_errmsg               output 
          
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailAdd' + dbo.fnc_RTrim(@c_errmsg) 
               SELECT @n_err = 94207 
            END 
            ELSE IF @c_PopPalletLabel = '1' 
            BEGIN 
               --Delete the old record in PalletLabel 
               IF @c_DelToID <> @c_ToID 
               BEGIN 
                  IF EXISTS (SELECT 1 FROM PalletLabel (NOLOCK) WHERE ID = @c_DelToID AND Status NOT IN ('X','9')) 
                  BEGIN 
                     UPDATE PalletLabel WITH (ROWLOCK) SET Status = 'X' WHERE ID = @c_DelToID AND Status NOT IN ('X','9') 
                  END 
               END 
 
                --(BL01) Start 
               IF @c_FinalizeFlag = 'Y' 
               BEGIN 
                  --Only insert when not exist. 
                  --IF NOT EXISTS (SELECT 1 FROM PalletLabel (NOLOCK) WHERE ID = @c_ToID AND Status NOT IN ('X','9'))  --(JH01) 
                  --BEGIN 
                     --Insert the required pallet label data for later putaway and print processing. 
                     --Delete old record   (JH01) Start          
                     Delete From PalletLabel WHERE ID = @c_ToID   
                     INSERT INTO PalletLabel (ID, Tablename, HDKey, DTKey, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10)  
                     VALUES (@c_ToID, 'RECEIPT', @c_ReceiptKey, @c_ReceiptLineNumber, '','','','','',  '','','','','') 
                  --END 
                  --(JH01)  End 
               END 
 
               --IF @c_FinalizeFlag = 'Y' 
               --BEGIN 
               --   --Only insert when not exist. 
               --   IF EXISTS (SELECT 1 FROM PalletLabel (NOLOCK) WHERE ID = @c_ToID AND Status NOT IN ('X','9')) 
               --   BEGIN 
               --      --set old record to x 
               --      UPDATE PalletLabel WITH (ROWLOCK) SET Status = 'X' WHERE ID = @c_ToID AND Status NOT IN ('X','9') 
               --   END 
 
               --   --Insert the required pallet label data for later putaway and print processing. 
               --    INSERT INTO PalletLabel (ID, Tablename, HDKey, DTKey, Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10)  
               --      VALUES (@c_ToID, 'RECEIPT', @c_ReceiptKey, @c_ReceiptLineNumber, '','','','','',  '','','','','') 
               --END  
               ---- (BL01) END 
            END 
         END 
         --TK02 - End 
 
         IF (@n_continue = 1 OR @n_continue = 2) And @c_FinalizeFlag = 'Y' 
         BEGIN 
            EXECUTE nspItrnAddDeposit 
                  @n_ItrnSysId    = @n_ItrnSysId ,  
                  @c_StorerKey    = @c_StorerKey , 
                  @c_Sku          = @c_Sku       , 
                  @c_Lot          = @c_LOT       , 
                  @c_ToLoc        = @c_ToLoc     , 
                  @c_ToID         = @c_ToID      , 
                  @c_Status       = @c_Status    , 
                  @c_lottable01   = @c_Lottable01, 
                  @c_lottable02   = @c_Lottable02, 
                  @c_lottable03   = @c_Lottable03, 
                  @d_lottable04   = @d_Lottable04, 
                  @d_lottable05   = @d_Lottable05, 
                  @c_lottable06   = @c_lottable06, 
                  @c_lottable07   = @c_lottable07, 
                  @c_lottable08   = @c_lottable08, 
                  @c_lottable09   = @c_lottable09, 
                  @c_lottable10   = @c_lottable10, 
                  @c_lottable11   = @c_lottable11, 
                  @c_lottable12   = @c_lottable12, 
                  @d_lottable13   = @d_lottable13, 
                  @d_lottable14   = @d_lottable14, 
                  @d_lottable15   = @d_lottable15, 
                  @c_Channel      = @c_Channel,  -- (SWT02) 
                  @n_Channel_ID   = @n_Channel_ID OUTPUT, -- (SWT02)  
                  @c_PalletType   = @c_PalletType,                                  -- (Wan04)            
                  @n_casecnt      = @n_casecnt , 
                  @n_innerpack    = @n_innerpack , 
                  @n_qty          = @n_Qty       , 
                  @n_pallet       = @n_pallet    , 
                  @f_cube         = @f_cube      , 
                  @f_grosswgt     = @f_grosswgt  , 
                  @f_netwgt       = @f_netwgt    , 
                  @f_otherunit1   = @f_otherunit1, 
                  @f_otherunit2   = @f_otherunit2, 
                  @c_SourceKey    = @c_SourceKey, 
                  @c_SourceType   = @c_SourceType, 
                  @c_PackKey      = @c_packkey, 
                  @c_UOM          = @c_uom, 
                  @b_UOMCalc      = 0, 
                  @d_EffectiveDate= @d_EffectiveDate, 
                  @c_itrnkey      = '', 
                  @b_Success      = @b_Success    OUTPUT, 
                  @n_err          = @n_err        OUTPUT, 
                  @c_errmsg       = @c_errmsg     OUTPUT 
             
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_continue=3 
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) 
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Failed in nspItrnAdddeposit (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
               BREAK 
            END 
            ELSE 
            BEGIN 
               SELECT @b_success = 0 
               EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
                     @c_StorerKey,        -- Storerkey 
                     '',                  -- Sku 
                     'UCCTracking',       -- Configkey 
                     @b_success         output, 
                     @c_UCCTrackingFlag output, 
                     @n_err             output, 
                     @c_errmsg          output 
 
               IF @b_success <> 1 
               BEGIN 
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
                  SELECT @n_err = 60079 
                  BREAK 
               END 
 
               SELECT @b_success = 0 
               EXECUTE nspGetRight @c_Facility,     -- facility --NJOW12
                     @c_StorerKey,           -- Storerkey 
                     '',                     -- Sku 
                     'AddUCCFromColUDF01',   -- Configkey 
                     @b_success           output, 
                     @c_AddUCCFromUDF01   output, 
                     @n_err               output, 
                     @c_errmsg            output 
 
               IF @b_success <> 1 
               BEGIN 
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
                  SELECT @n_err = 60081 
                  BREAK 
               END 
 
               /**17 March 2004 WANYT Timberland FBR#:20676 - RF Receiving - START**/ 
               IF @c_UCCTrackingFlag = '1' OR @c_AddUCCFromUDF01 = '1' 
               BEGIN 
                  SELECT TOP 1 
                         @c_UCCNo = CASE WHEN @c_UCCTrackingFlag = '1' THEN ExternLineNo 
                                         WHEN @c_AddUCCFromUDF01 = '1' THEN UserDefine01 
                                         ELSE '' 
                                         END, 
                         @c_ExternReceiptKey = ISNULL(ExternReceiptKey,'') 
                  FROM RECEIPTDETAIL WITH (NOLOCK) 
                  WHERE Receiptkey = @c_ReceiptKey 
                  AND   ReceiptLineNumber = @c_ReceiptLineNumber 
 
                  IF ISNULL(RTRIM(@c_UCCNo), '') <> '' 
                  BEGIN 
                     SELECT TOP 1 
                            @c_LOT = Lot, 
                            @n_Qty = qty 
                     FROM ITRN WITH (NOLOCK) 
                     WHERE SourceType = @c_SourceType 
                     AND   SourceKey  = @c_SourceKey 
 
                     IF EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) 
                                WHERE Receiptkey = @c_ReceiptKey 
                                 AND  ReceiptLineNumber = @c_ReceiptLineNumber ) 
                                 -- AND  Status = '0')   -- tlting03 avoid duplicate UCC, when regenerate 
                     BEGIN 
                        UPDATE UCC WITH (ROWLOCK) 
                        SET Lot = @c_lot, 
                            Loc = @c_toloc, 
                            ID  = @c_toid, 
                            Qty = @n_qty, 
                            -- Status = '1'     --KH02 
                            [Status] = CASE WHEN [Status] = '0' THEN '1' ELSE [Status] END, --KH02 
                            EditDate = GETDATE(),   --tlting 
                            EditWho = SUSER_SNAME() 
                        WHERE Receiptkey = @c_ReceiptKey 
                        AND   ReceiptLineNumber = @c_ReceiptLineNumber 
                        -- AND   Status = '0'   --KH02 
                        AND   [Status] < '2'    --KH02 
                     END 
                     ELSE 
                     BEGIN 
                        -- 
                        IF EXISTS( SELECT 1 
                           FROM UCC WITH (NOLOCK) 
                           WHERE UCCNo = @c_UCCNo 
                              AND StorerKey = @c_StorerKey 
                              AND SKU = @c_SKU 
                              AND LOT = @c_LOT 
                              AND LOC = @c_ToLOC 
                              AND ID = @c_ToID 
                              AND Status = '1') 
                         BEGIN
                           -- tlting07
                           DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                              SELECT UCC_RowRef 
                              FROM UCC (NOLOCK)
                              WHERE UCCNo = @c_UCCNo                                                                                                                                                                                                               
                                 AND StorerKey = @c_StorerKey                                                                                                                                                                                                      
                                 AND SKU = @c_SKU                                                                                                                                                                                                                  
                                 AND LOT = @c_LOT                                                                                                                                                                                                                  
                                 AND LOC = @c_ToLOC                                                                                                                                                                                                                
                                 AND ID = @c_ToID                                                                                                                                                                                                                  
                                 AND Status = '1'   
 
                           OPEN CUR_UCC 
            
                           FETCH NEXT FROM CUR_UCC INTO @n_UCC_RowRef
 
                           WHILE @@FETCH_STATUS = 0 
                           BEGIN  
   
                              UPDATE UCC WITH (ROWLOCK) SET                                                                                                                                                                                                                                   
                                 QTY = QTY + @n_QTY                                                                                                                                                                                                                
                              WHERE UCCNo = @c_UCCNo                                                                                                                                                                                                               
                                 AND UCC_RowRef  = @n_UCC_RowRef                                                                                                                                                                                                     
                                 AND Status = '1'    
                                 SET @n_err = @@ERROR 
 
                                 IF @n_err <> 0 
                                 BEGIN 
                                    SET @n_continue = 3   
                                    SET @c_errmsg = CONVERT(CHAR(250),@n_err) 
                                    SET @n_err = 94305 
                                    SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err)  
                                                   + ': Failed Update on table UCC. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE = '  
                                                   + LTrim(RTrim(@c_errmsg)) + ' ) ' 
                                 END 
                                 FETCH NEXT FROM CUR_UCC INTO @n_UCC_RowRef
                              END -- WHILE CUR_UCC 
                              CLOSE CUR_UCC 
                              DEALLOCATE CUR_UCC 
                              -- END tlting07 
                           END
                        ELSE 
                           INSERT INTO UCC 
                                 (UCCNo,     Storerkey, 
                                  Sku,       Qty, 
                                  Status,    Lot,        Loc, 
                                  ID,        ExternKey,  Receiptkey, 
                                  ReceiptLineNumber,     Sourcekey,   Sourcetype) 
                           VALUES 
                                (@c_UCCNo,   @c_storerkey, @c_sku, 
                                 @n_qty,     '1',          @c_lot, 
                                 @c_toloc,   @c_toid,      @c_ExternReceiptKey, 
                                 @c_ReceiptKey,    @c_ReceiptLineNumber, 
                                 @c_SourceKey,     @c_SourceType) 
                     END 
 
                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
                     IF @n_err <> 0 
                     BEGIN 
                        SELECT @n_continue = 3 
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60066 
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update failed on table UCC. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
                     END 
                  END -- ISNULL(RTRIM(@c_UCCNo), '') <> '' 
               END -- IF @c_UCCTrackingFlag = '1' OR @c_AddUCCFromUDF01 = '1' 
               /**17 March 2004 WANYT Timberland FBR#:20676 - RF Receiving - END**/ 
 
               -- Update UCC table after finalize 
               -- SOS#103630 
               IF @c_StorerConfig_UCC = '1' AND @cUCCQTY > 0 
               BEGIN 
                  -- SOS#103630 -- Ignore this checking, using the cUCCQty > 0 
                  -- Performance Tuning 
                  --             IF EXISTS(SELECT 1 FROM UCC WITH (NOLOCK) 
                  --                        WHERE Receiptkey = @c_ReceiptKey 
                  --                          AND  ReceiptLineNumber = @c_ReceiptLineNumber 
                  --                          AND  Status = '1') 
                  --             BEGIN 
                  -- Get the LOT from ITrn record (LOT only generated after ITrn add deposit 
                  SELECT TOP 1 @c_LOT = Lot 
                  FROM ITRN WITH (NOLOCK) 
                  WHERE SourceType = @c_SourceType -- 'ntrReceiptDetailUpdate' 
                    AND SourceKey  = @c_SourceKey -- ReceiptKey + ReceiptLineNumber 
                   
                  SET @c_loseUCC = ''                    
                  SELECT @c_loseUCC = LoseUCC 
                  FROM dbo.Loc WITH (NOLOCK)  
                  WHERE Loc = @c_toloc 
                  AND Facility = @c_Facility 
 
                  -- Workstation can change ToLOC and ToID on ReceiptDetail after UCC being received 
                  -- So overwrite the LOC and ID on UCC table too 
                  UPDATE UCC WITH (ROWLOCK) 
                     SET Lot = @c_lot, 
                         Loc = @c_toloc, 
                         ID  = @c_toid, 
                         Status = CASE WHEN  @c_loseUCC = '1' THEN '6' ELSE '1' END, -- (ChewKP01)  
                         EditDate = GETDATE(),   --tlting 
                         EditWho = SUSER_SNAME() 
                  WHERE  Receiptkey = @c_ReceiptKey 
                     AND ReceiptLineNumber = @c_ReceiptLineNumber 
                     --AND Status = '1' -- 1-Received 
 
                  IF @@ERROR <> 0 
                  BEGIN 
                     SELECT @n_continue = 3 
                     SELECT @n_err = 60082 
                     SELECT @c_errmsg = 'NSQL60082: Update failed on UCC table. (ntrReceiptDetailUpdate)' 
                  END 
               END 
            END -- Itrn Add Successful 
 
             --(Wan01) - START 
            SET @b_success = 0 
            SET @c_authority = '' 
            EXECUTE nspGetRight @c_Facility,  -- facility --NJOW12
                  @c_StorerKey,        -- Storerkey 
                  '',                  -- Sku 
                  'RCPTDETLOG',        -- Configkey 
                  @b_success         output, 
                  @c_authority       output, 
                  @n_err             output, 
                  @c_errmsg          output 
 
            IF @b_success = 0 
            BEGIN 
               SET @n_continue = 3 
               SET @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
               SET @n_err = 60083 
               BREAK 
            END 
 
            IF @c_authority = '1' 
            BEGIN 
               EXEC ispGenTransmitLog3 'RCPTDETLOG', @c_receiptkey, @c_ReceiptLineNumber, @c_storerkey, '' 
                     , @b_success OUTPUT 
                     , @n_err OUTPUT 
                     , @c_errmsg OUTPUT 
 
               IF @b_success <> 1 
               BEGIN 
                  SET @n_continue = 3 
                  SET @c_errmsg = CONVERT(CHAR(250),@n_err) 
                  SET @n_err=60258 
                  SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Unable to obtain transmitlogkey3 (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE='  
                                + RTrim(@c_errmsg) + ' ) ' 
               END 
               --CONTINUE 
            END 
 
            --(Wan01) - END 
         END -- @n_continue = 1 OR @n_continue = 2 
 
         -- Serial no 
         IF (@n_continue = 1 OR @n_continue = 2) AND @c_SerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY 
         BEGIN 
            DECLARE @c_SerialNoKey NVARCHAR(10) 
            DECLARE @c_SerialNo NVARCHAR( 30) 
            DECLARE @n_SerialQTY INT 
            DECLARE @curSNo CURSOR  
            DECLARE @c_SerialUCCNo  NVARCHAR( 20)

            --NJOW14 S
            SELECT @b_success = 0          
            SELECT @c_ASNFizUpdLotToSerialNo = ''
            EXECUTE nspGetRight @c_Facility,  -- facility 
                  @c_StorerKey,           -- Storerkey 
                  '',                     -- Sku 
                  'ASNFizUpdLotToSerialNo',   -- Configkey 
                  @b_success                  output, 
                  @c_ASNFizUpdLotToSerialNo   output, 
                  @n_err                      output, 
                  @c_errmsg                   output 
                   
            IF @b_success <> 1 
            BEGIN 
               SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptDetailUpdate' + dbo.fnc_RTrim(@c_errmsg) 
               SELECT @n_err = 60084 
               BREAK 
            END 

            IF @c_ASNFizUpdLotToSerialNo IN ( '1', '2' )                            --(Wan05)
            BEGIN
               SELECT TOP 1 @c_LOT = Lot                                           
               FROM ITRN WITH (NOLOCK)                                             
               WHERE SourceType = @c_SourceType -- 'ntrReceiptDetailUpdate'        
               AND SourceKey  = @c_SourceKey -- ReceiptKey + ReceiptLineNumber                
            END      
            --NJOW14 E            
            
            -- Loop ReceiptSerialNo 
            SET @curSNo = CURSOR FOR 
               SELECT SerialNo, QTY, UCCNo 
               FROM dbo.ReceiptSerialNo WITH (NOLOCK) 
               WHERE ReceiptKey = @c_ReceiptKey   
               AND ReceiptLineNumber = @c_ReceiptLineNumber 
 
            OPEN @curSNo 
            
            FETCH NEXT FROM @curSNo INTO @c_SerialNo, @n_SerialQTY, @c_SerialUCCNo 
 
            WHILE @@FETCH_STATUS = 0 
            BEGIN             
               -- Get SerialNo info 
               SET @c_SerialNoKey = '' 
               SELECT @c_SerialNoKey = SerialNoKey  
               FROM dbo.SerialNo (NOLOCK) 
               WHERE SerialNo = @c_SerialNo 
               AND StorerKey = @c_StorerKey 
               AND SKU = @c_SKU 
 
               IF @c_SerialNoKey <> '' 
               BEGIN 
                  -- Update SerialNo (for return) 
                  UPDATE dbo.SerialNo WITH (ROWLOCK) 
                  SET QTY = @n_SerialQTY, 
                      Status = '1', --1=Received 
                      ID = @c_ToID,  
                      EditDate = GETDATE(),   
                      EditWho = SUSER_SNAME(),
                      Lot = CASE WHEN @c_ASNFizUpdLotToSerialNo IN('1','2') THEN @c_Lot ELSE Lot END --(Wan05)--NJOW14
                  WHERE SerialNoKey = @c_SerialNoKey 
 
                  IF @@ERROR <> 0 
                  BEGIN 
                     SELECT @n_continue = 3 
                     SELECT @n_err = 94212 
                     SELECT @c_errmsg = 'NSQL94212: Update SerialNo table fail (ntrReceiptDetailUpdate)' 
                  END 
               END 
               ELSE 
               BEGIN 
                  -- Get SerialNoKey 
                  EXECUTE nspg_getkey 
                         'SerialNo' 
                        ,10 
                        ,@c_SerialNoKey OUTPUT 
                        ,@b_Success     OUTPUT 
                        ,@n_Err         OUTPUT 
                        ,@c_ErrMsg      OUTPUT 
 
                  IF @b_Success <> 1 
                  BEGIN 
                     SELECT @n_continue = 3 
                     SELECT @n_err = 94213 
                     SELECT @c_errmsg = 'NSQL94213: GetKey fail. (ntrReceiptDetailUpdate)' 
                  END 
                   
                  -- Insert SerialNo 
                  IF @c_ASNFizUpdLotToSerialNo IN ('1', '2')                        --(Wan05) --NJOW14
                  BEGIN
                     INSERT INTO dbo.SerialNo (SerialNoKey, StorerKey, SKU, SerialNo, QTY, Status, ID, OrderKey, OrderLineNumber, UCCNo, Lot) 
                     VALUES (@c_SerialNoKey, @c_StorerKey, @c_SKU, @c_SerialNo, @n_SerialQTY, '1', @c_ToID, '', '', @c_SerialUCCNo, @c_Lot) 
                  END
                  ELSE
                  BEGIN
                     INSERT INTO dbo.SerialNo (SerialNoKey, StorerKey, SKU, SerialNo, QTY, Status, ID, OrderKey, OrderLineNumber, UCCNo) 
                     VALUES (@c_SerialNoKey, @c_StorerKey, @c_SKU, @c_SerialNo, @n_SerialQTY, '1', @c_ToID, '', '', @c_SerialUCCNo) 
                  END
 
                  IF @@ERROR <> 0 
                  BEGIN 
                     SELECT @n_continue = 3 
                     SELECT @n_err = 94214 
                     SELECT @c_errmsg = 'NSQL94214: Insert SerialNo table fail (ntrReceiptDetailUpdate)' 
                  END 
               END 
 
               -- Insert ITrnSerialNo 
               EXEC ispItrnSerialNoDeposit 
                    @c_TranType    = 'DP' 
                  , @c_StorerKey   = @c_StorerKey 
                  , @c_SKU         = @c_SKU 
                  , @c_SerialNo    = @c_SerialNo 
                  , @n_QTY         = @n_SerialQTY 
                  , @c_SourceKey   = @c_SourceKey 
                  , @c_SourceType  = @c_SourceType 
                  , @b_Success     = @b_Success OUTPUT   
                  , @n_Err         = @n_Err     OUTPUT   
                  , @c_ErrMsg      = @c_ErrMsg  OUTPUT   
 
               IF @b_Success <> 1 
               BEGIN 
                  SELECT @n_continue = 3 
               END 
    
               FETCH NEXT FROM @curSNo INTO @c_SerialNo, @n_SerialQTY, @c_SerialUCCNo 
            END 
         END          
      END -- FinalizeFlag = 'Y' 
 
      FETCH NEXT FROM C_RECEIPTLINE INTO 
                      @c_ReceiptKey              ,@c_ReceiptLineNumber       ,@n_ItrnSysId ,@c_StorerKey 
                     ,@c_Sku                     ,@c_LOT                     ,@c_ToLoc 
                     ,@c_ToID                    ,@c_Status                  ,@c_Lottable01 
                     ,@c_Lottable02              ,@c_Lottable03              ,@d_Lottable04 
                     ,@d_Lottable05              ,@c_Lottable06              ,@c_Lottable07 
                     ,@c_Lottable08           ,@c_Lottable09              ,@c_Lottable10 
                     ,@c_Lottable11              ,@c_Lottable12              ,@d_Lottable13 
                     ,@d_Lottable14              ,@d_Lottable15 
                     ,@n_casecnt                 ,@n_innerpack 
                     ,@n_Qty                     ,@n_TotQtyReceived          ,@n_QtyExpected 
                     ,@n_pallet                  ,@f_cube                    ,@f_grosswgt 
                     ,@f_netwgt                  ,@f_otherunit1              ,@f_otherunit2 
                     ,@c_packkey                 ,@c_uom                     ,@c_SourceKey 
                     ,@c_SourceType              ,@d_EffectiveDate           ,@b_Success 
                     ,@n_err                     ,@c_errmsg                  ,@c_pokey 
                     ,@c_FinalizeFlag            ,@c_Lottable01Label         ,@c_Lottable02Label 
                     ,@c_Lottable03Label         ,@c_Lottable04Label         ,@c_Lottable05Label 
                     ,@c_Lottable06Label         ,@c_Lottable07Label         ,@c_Lottable08Label 
                     ,@c_Lottable09Label         ,@c_Lottable10Label         ,@c_Lottable11Label 
                     ,@c_Lottable12Label         ,@c_Lottable13Label         ,@c_Lottable14Label 
                     ,@c_Lottable15Label 
                     ,@c_RecType                 ,@c_DocType                 ,@c_Facility 
                     ,@n_IncomingShelfLife       ,@c_SubReasonCode           ,@c_ExternLineNo 
                     ,@n_TolerancePerc           ,@c_CopyPackKey             ,@c_DelFinalizeFlag   ,@c_DelToID      --(TK02) 
                     ,@c_SerialNoCapture         ,@c_Channel  -- (SWT02) 
                     ,@c_Userdefine01, @c_Userdefine02, @c_Userdefine03, @c_Userdefine04, @c_Userdefine05  --NJOW09       
                     ,@d_Userdefine06, @d_Userdefine07, @c_Userdefine08, @c_Userdefine09, @c_Userdefine10  --NJOW09                     
                     ,@c_ExternReceiptKey, @c_AltSku, @c_ContainerKey, @c_ExternPoKey, @c_POLineNumber --NJOW11
                     ,@c_PalletType                                                 --(Wan04)                                     
   END -- While 
END -- @n_continue = 1 or @n_continue=2 
 
--(Wan02) - START 
IF @n_Continue = 1 OR @n_Continue = 2 
BEGIN 
   DECLARE CUR_RCPT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT  
          RECEIPT.Facility 
         ,RECEIPT.Storerkey 
         ,RECEIPT.ReceiptKey 
   FROM INSERTED  
   JOIN DELETED ON (INSERTED.ReceiptKey  = DELETED.ReceiptKey) 
                AND(INSERTED.ReceiptLineNumber = DELETED.ReceiptLineNumber) 
   JOIN RECEIPT WITH (NOLOCK) ON (RECEIPT.Receiptkey = INSERTED.Receiptkey) 
  
   OPEN CUR_RCPT 
   FETCH NEXT FROM CUR_RCPT INTO @c_Facility 
                              ,  @c_Storerkey 
                              ,  @c_ReceiptKey 
  
   WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2) 
   BEGIN 
      SET @c_ReservePAloc = '0' 
      EXECUTE nspGetRight 
               @c_Facility       -- Facility 
            ,  @c_StorerKey      -- Storer 
            ,  NULL              -- Sku 
            ,  'ReservePAloc'    -- ConfigKey 
            ,  @b_success        OUTPUT  
            ,  @c_ReservePAloc   OUTPUT  
            ,  @n_err            OUTPUT  
            ,  @c_errmsg         OUTPUT 
 
      IF @b_Success <> 1  
      BEGIN 
         SET @n_continue = 3 
         SET @c_errmsg = CONVERT(CHAR(250),@n_err) 
         SET @n_err = 94203 
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err) + ': Retrieve Failed On GetRight - ReservePAloc. (ntrReceiptDetailDelete) ( SQLSvr MESSAGE = '  
                       + LTrim(RTrim(@c_errmsg)) + ' ) ' 
      END 
 
      IF @c_ReservePAloc = '1' AND (@n_continue = 1 OR @n_continue = 2) 
      BEGIN 
         DECLARE CUR_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT INSERTED.ReceiptLineNumber 
               ,INSERTED.PutawayLoc 
               ,INSERTED.ToID 
               ,INSERTED.QtyReceived 
         FROM INSERTED 
         JOIN DELETED ON (INSERTED.ReceiptKey  = DELETED.ReceiptKey) 
                      AND(INSERTED.ReceiptLineNumber = DELETED.ReceiptLineNumber) 
         WHERE INSERTED.ReceiptKey = @c_Receiptkey 
         AND   INSERTED.FinalizeFlag = 'Y' 
         AND   DELETED.FinalizeFlag = 'Y' 
         AND   INSERTED.QtyReceived > 0 
         AND   INSERTED.PutawayLoc <> DELETED.PutawayLoc 
   
         OPEN CUR_DET 
         FETCH NEXT FROM CUR_DET INTO @c_ReceiptLineNumber 
                                    , @c_PutawayLoc 
                                    , @c_ToID 
                                    , @n_TotQtyReceived 
 
         WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2) 
         BEGIN 
            SET @c_Lot = '' 
            SELECT @c_Lot = Lot 
            FROM ITRN WITH (NOLOCK) 
            WHERE Sourcekey = RTRIM(@c_ReceiptKey) + RTRIM(@c_ReceiptLineNumber) 
            AND TranType = 'DP' 
            AND SourceType IN ( 'ntrReceiptDetailAdd', 'ntrReceiptDetailUpdate' ) 
 
            IF @c_Lot <> '' 
            BEGIN 
               IF EXISTS ( SELECT 1 
                           FROM DELETED  
                           WHERE DELETED.Receiptkey = @c_ReceiptKey 
                           AND DELETED.ReceiptLineNumber = @c_ReceiptLineNumber  
                           AND ISNULL(DELETED.PutawayLoc,'') <> '' 
                         ) 
               BEGIN 
                  UPDATE LOTxLOCxID WITH (ROWLOCK) 
                  SET PendingMoveIn = PendingMoveIn - DELETED.QtyReceived 
                  FROM DELETED  
                  JOIN LOTxLOCxID ON (LOTxLOCxID.Lot = @c_Lot) 
                                  AND(LOTxLOCxID.Loc = DELETED.PutawayLoc) 
                                  AND(LOTxLOCxID.ID  = DELETED.ToID) 
                  WHERE DELETED.Receiptkey = @c_ReceiptKey 
                  AND DELETED.ReceiptLineNumber = @c_ReceiptLineNumber 
 
                  SET @n_err = @@ERROR 
 
                  IF @n_err <> 0 
                  BEGIN 
                     SET @n_continue = 3 
                     SET @c_errmsg = CONVERT(CHAR(250),@n_err)   
                     SET @n_err = 94204 
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err)  
                                   + ': Update failed on table LOTxLOCxID. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE = '  
                                   + LTrim(RTrim(@c_errmsg)) + ' ) ' 
                  END 
               END 
 
               IF ISNULL(@c_PutaWayLoc,'') <> '' AND (@n_Continue = 1 OR @n_Continue = 2) 
               BEGIN 
                  IF NOT EXISTS ( SELECT 1 
                                  FROM LOTxLOCxID WITH (NOLOCK) 
                                  WHERE Lot = @c_Lot 
                                  AND   Loc = @c_PutaWayLoc 
                                  AND   Id = @c_ToID 
                                ) 
                  BEGIN 
                     INSERT INTO LOTxLOCxID (Storerkey, Sku, Lot, Loc, ID, Qty, PendingMoveIn) 
                     VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_PutaWayLoc, @c_ToID, 0, @n_TotQtyReceived) 
 
                     SET @n_err = @@ERROR 
 
                     IF @n_err <> 0 
                     BEGIN 
                        SET @n_continue = 3   
                        SET @c_errmsg = CONVERT(CHAR(250),@n_err) 
                        SET @n_err = 94205 
                        SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err)  
                                      + ': Insert failed on table LOTxLOCxID. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE = '  
                                      + LTrim(RTrim(@c_errmsg)) + ' ) ' 
                     END 
                  END 
                  ELSE 
                  BEGIN 
                     UPDATE LOTxLOCxID WITH (ROWLOCK) 
                     SET PendingMoveIn = PendingMoveIn + @n_TotQtyReceived 
                     WHERE LOTxLOCxID.Lot = @c_Lot 
                     AND   LOTxLOCxID.Loc = @c_PutaWayLoc 
                     AND   LOTxLOCxID.ID  = @c_ToID 
       
                     SET @n_err = @@ERROR 
 
                     IF @n_err <> 0 
                     BEGIN 
                        SET @n_continue = 3   
                        SET @c_errmsg = CONVERT(CHAR(250),@n_err) 
                        SET @n_err = 94206 
              SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5) ,@n_err) 
                                      + ': Update failed on table LOTxLOCxID. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE = '  
                                      + LTrim(RTrim(@c_errmsg)) + ' ) ' 
                     END 
                  END 
               END 
            END -- @c_Lot <> '' 
 
            FETCH NEXT FROM CUR_DET INTO @c_ReceiptLineNumber 
                                       , @c_PutawayLoc 
                                       , @c_ToID 
                                       , @n_TotQtyReceived 
         END -- WHILE CUR_DET 
         CLOSE CUR_DET 
         DEALLOCATE CUR_DET 
      END  --@c_ReservePAloc = '1' 
 
      FETCH NEXT FROM CUR_RCPT INTO @c_Facility 
                                 ,  @c_Storerkey 
                                 ,  @c_ReceiptKey 
   END -- WHILE CUR_RCPT 
   CLOSE CUR_RCPT 
   DEALLOCATE CUR_RCPT 
END   --@n_Continue = 1 
--(Wan02) - ENd 
 
IF @n_continue = 1 or @n_continue=2 
BEGIN 
   IF EXISTS(SELECT 1 FROM CASEMANIFEST WITH (NOLOCK) 
             JOIN   DELETED ON (CASEMANIFEST.ExpectedReceiptKey = DELETED.ReceiptKey) 
             WHERE  CASEMANIFEST.Status <> '9' ) 
   BEGIN 
      UPDATE    CASEMANIFEST 
      SET       ExpectedReceiptKey  = INSERTED.ReceiptKey , 
                StorerKey           = INSERTED.StorerKey, 
                Sku                 = INSERTED.SKU, 
                ExpectedPOKey       = INSERTED.POKey, 
                EditDate = GETDATE(),   --tlting 
                EditWho = SUSER_SNAME() 
      FROM      CASEMANIFEST WITH (NOLOCK), INSERTED, DELETED 
      WHERE     CASEMANIFEST.ExpectedReceiptKey     = DELETED.ReceiptKey 
      AND  CASEMANIFEST.StorerKey             = DELETED.StorerKey 
      AND  CASEMANIFEST.SKU                   = DELETED.SKU 
      AND  CASEMANIFEST.ExpectedPOKey         = DELETED.POKey 
      AND  CASEMANIFEST.Status                <> '9' 
      AND ( 
      NOT INSERTED.ReceiptKey   = DELETED.ReceiptKey 
      OR   NOT INSERTED.StorerKey   = DELETED.StorerKey 
      OR   NOT INSERTED.SKU         = DELETED.SKU 
      OR   NOT INSERTED.POKey       = DELETED.POKey ) 
 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
      IF @n_err <> 0 
      BEGIN 
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60067 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update failed on table CASEMANIFEST. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
      END 
   END 
END 
 
IF @n_continue = 1 or @n_continue=2 
BEGIN 
   IF UPDATE(QtyExpected) OR UPDATE(QtyReceived) --NJOW01 
   BEGIN 
      DECLARE @n_deletedcount int 
      SELECT @n_deletedcount = (SELECT count(1) FROM DELETED) 
 
      IF @n_deletedcount = 1 
      BEGIN 
         UPDATE RECEIPT 
         SET  OpenQty = RECEIPT.OpenQty - (DELETED.QtyExpected - DELETED.QtyReceived) + (INSERTED.QtyExpected - INSERTED.QtyReceived), 
              EditDate = GETDATE(),   --tlting 
              EditWho = SUSER_SNAME() 
         FROM RECEIPT, 
              INSERTED, 
              DELETED 
         WHERE RECEIPT.ReceiptKey  = INSERTED.ReceiptKey 
         AND INSERTED.ReceiptKey  = DELETED.ReceiptKey 
 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
      END 
      ELSE 
      BEGIN 
         UPDATE RECEIPT SET RECEIPT.OpenQty 
             = (RECEIPT.Openqty 
             - 
             (SELECT Sum(DELETED.QtyExpected - DELETED.QtyReceived) FROM DELETED 
              WHERE DELETED.ReceiptKey  = RECEIPT.ReceiptKey ) 
             + 
             (SELECT Sum(INSERTED.QtyExpected - INSERTED.QtyReceived) FROM INSERTED 
              WHERE INSERTED.ReceiptKey  = RECEIPT.ReceiptKey ) 
             ), 
             EditDate = GETDATE(),   --tlting 
             EditWho = SUSER_SNAME() 
         FROM RECEIPT,DELETED,INSERTED 
         WHERE RECEIPT.ReceiptKey  IN (SELECT DISTINCT ReceiptKey FROM DELETED) 
         AND RECEIPT.ReceiptKey  = DELETED.ReceiptKey 
         AND RECEIPT.ReceiptKey  = INSERTED.ReceiptKey 
         AND INSERTED.ReceiptKey  = DELETED.ReceiptKey 
         AND INSERTED.RECEIPTLineNumber = DELETED.RECEIPTLineNumber 
 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
      END 
 
      IF @n_err <> 0 
      BEGIN 
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update failed on table RECEIPT. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
      END 
      ELSE IF @n_cnt = 0 
      BEGIN 
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=94210 
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Zero rows affected updating table RECEIPT. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
      END 
   END 
END 
 
-- (YokeBeen01) - Start 
IF @n_continue = 1 or @n_continue=2 
BEGIN 
   IF UPDATE(BeforeReceivedQty)  
   BEGIN 
      IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) 
                   JOIN INSERTED ON (INSERTED.RECEIPTKey = RECEIPT.RECEIPTKey) 
                  WHERE (RECEIPT.ASNStatus = '0'
                        OR RECEIPT.ASNStatus IN (SELECT Code FROM CODELKUP(NOLOCK) 
                                                 WHERE Listname = 'ASNSTSTO1'
                                                 AND Storerkey = RECEIPT.Storerkey)) --NJOW13
                    AND INSERTED.BeforeReceivedQty > 0) 
      BEGIN 
         UPDATE RECEIPT WITH (ROWLOCK)  
            SET ASNStatus = '1' 
              , EditDate = GETDATE() 
              , EditWho = SUSER_SNAME() 
           FROM RECEIPT 
           JOIN INSERTED ON (RECEIPT.ReceiptKey  = INSERTED.ReceiptKey) 
           WHERE (RECEIPT.ASNStatus = '0' 
                 OR RECEIPT.ASNStatus IN (SELECT Code FROM CODELKUP(NOLOCK) 
                                          WHERE Listname = 'ASNSTSTO1'
                                          AND Storerkey = RECEIPT.Storerkey)) --NJOW13 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
 
         IF @n_err <> 0 
         BEGIN 
            SELECT @n_continue=3 
            SELECT @n_err = 94216 
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) + ': Update failed on table RECEIPT. (ntrReceiptDetailUpdate) ( SQLSvr MESSAGE=' 
                             + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) ' 
         END 
      END  -- IF record exists  
   END  -- IF UPDATE(BeforeReceivedQty) 
END  -- IF @n_continue = 1 or @n_continue=2 
-- (YokeBeen01) - End 
 
/*========================= END customise =============================== */ 
/* #INCLUDE <TRRDU2.SQL> */ 
 
QUIT: 
 
IF @n_continue=3  -- Error Occured - Process And Return 
BEGIN 
   DECLARE @n_IsRDT INT 
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT 
 
   IF @n_IsRDT = 1 
   BEGIN 
      -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here 
      -- Instead we commit and raise an error back to parent, let the parent decide 
 
      -- Commit until the level we begin with 
      WHILE @@TRANCOUNT > @n_starttcnt 
         COMMIT TRAN 
 
      -- Raise error with severity = 10, instead of the default severity 16. 
      -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger 
      RAISERROR (@n_err, 10, 1) WITH SETERROR 
 
      -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten 
   END 
   ELSE 
   BEGIN 
 
   IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt 
   BEGIN 
      ROLLBACK TRAN 
   END 
   ELSE 
   BEGIN 
      -- Else (parent have begin tran) commit even have error, and let the parent decide to rollback or commit instead, 
      -- by raising an error (the raiserror statement below) back to the parent 
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN 
         COMMIT TRAN 
      END 
   END 
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrReceiptDetailUpdate' 
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
   RETURN 
   END 
END 
ELSE 
BEGIN 
   WHILE @@TRANCOUNT > @n_starttcnt 
   BEGIN 
      COMMIT TRAN 
   END 
   RETURN 
END 

GO