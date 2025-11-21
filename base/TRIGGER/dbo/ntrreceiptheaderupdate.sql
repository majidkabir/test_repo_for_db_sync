SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Store Procedure:  ntrReceiptHeaderUpdate                                    */
/* Creation Date:                                                              */
/* Copyright: Maersk                                                           */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:  ReceiptHeader Update Trigger                                      */
/*                                                                             */
/* Input Parameters:                                                           */
/*                                                                             */
/* Output Parameters:  None                                                    */
/*                                                                             */
/* Return Status:  None                                                        */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Local Variables:                                                            */
/*                                                                             */
/* Called By:                                                                  */
/*                                                                             */
/* PVCS Version: 1.5                                                           */
/*                                                                             */
/* Version: 6.0                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/*                                                                             */
/* Updates:                                                                    */
/* Date         Author       Ver.   Purposes                                   */
/* 13-Nov-2002  RickyYee     1.0    Include SOS changes from Oct 1st-Oct 31st  */
/* 23-Dec-2002  Vicky        1.0    IDSTH PMTL Receipt Export                  */
/* 30-Dec-2002  RickyYee     1.0    Include changes from IDSHK for additional  */
/*                                  Unilever interface Receipt (SOS8270)       */
/* 20-Feb-2003  RickyYee     1.0    Fixed generation of interface record for   */
/*                                  GDSITF by removing checking of OWITF for   */
/*                                  the whole if stmt.                         */
/* 28-Feb-2003  RickyYee     1.0    Incude the interface for CDSRCP type       */
/* 06-Mar-2003  RickyYee     1.0    Include checking of status updated to '9'  */
/*                                  only when the openqty = 0 and              */
/*                                  sum(qtyreceived) for the asn > 0           */
/* 13-Mar-2003  Vicky        1.0    Changes made for NikeCN                    */ 
/* 21-Apr-2003  June         1.0    TBL HK (FBR10621)                          */
/* 05-May-2003  YokeBeen     1.0    Changes on TransmitLogKey2                 */
/* 04-Jun-2003  RickyYee     1.0    Branch 1.7.1 - Version5.1 with CDC changes */
/* 05-Jun-2003  YokeBeen     1.0    (From Branch 1.9.1.1) Merged for IDSTH -   */
/*                                  STBTH Interface (SOS10517)                 */
/* 24-Jul-2003  YokeBeen     1.0    IDSHK UHK (SOS12573)                       */
/* 29-Jul-2003  YokeBeen     1.0    (From Brance 1.11.1) IDSHK NIKE Project    */
/* 29-Jul-2003  Jeff         1.0    Modified for IDSHK NIKE Project (SOS12746) */
/* 30-Jul-2003  Vicky        1.0    Add in configkey to Generate ROICNo for    */
/*                                  NIKEHK (SOS12745)                          */
/* 15-Aug-2003  Jeff         1.0    Modified for IDSHK NIKE Project (SOS12797) */
/* 21-Aug-2003  Wally        1.0    Timing issue for TBL PIX (SOS13093)        */
/* 15-Sep-2003  Shong        1.0    Added "Insert Transmitlog" for Mandom      */
/*                                  IDSSG Interfac                             */
/* 06-Oct-2003  June         1.0    Remove OWRCPT table                        */
/* 13-Oct-2003  YokeBeen     1.0    Receipt Confirmation-NSC Project(SOS15351) */
/* 21-Oct-2003  YokeBeen     1.0    Changed for NSC Project (SOS15352)         */
/* 30-Jan-2004  RickyYee     1.0    Remove remark of the OWRCPT interface, as  */
/*                                  0 qty in the receiptdetail line has to be  */
/*                                  interface back to OW                       */
/* 16-Feb-2004  YokeBeen     1.0    Modified for NSC Project (SOS20000)        */
/* 16-Feb-2004  Wally        1.0    Fix ULP interface to include GRN type      */
/* 24-Feb-2004  YokeBeen     1.0    Modified for NSC Project (SOS20000)        */
/* 26-Feb-2004  Wally        1.0    MZP Receipt Confirmation Export (SOS20311) */
/* 01-Mar-2004  RickyYee     1.0    To add the modification done by Mary for   */
/*                                  UHK (FBR17218)                             */
/* 09-Mar-2004  June         1.0    NIKECN - Do not insert to trxlog if        */
/*                                  tablename is empty (SOS20744)              */
/* 18-Mar-2004  MaryVong     1.0    1) NZMM Trade Retrun Export (FBR19000)     */
/*                                  2) Remove extra variables declared         */
/* 05-Apr-2004  MaryVong     1.0    Modification for NZMM Trade Retrun Export  */
/* 12-Apr-2004  YokeBeen     1.0    Modification for IDSHK (SOS20555)          */
/* 27-Aug-2004  Wally        1.0    For June's changes on SOS25285             */
/* 30-Aug-2004  MaryVong     1.0    Add in WTC interface and modication        */
/*                                  (SOS25581)                                 */
/* 20-Sep-2004  YTWan        1.0    Jamo Receipt Comfirmation - Insert into    */
/*                                  Transmitlog2                               */
/* 14-Oct-2004  Wally        1.0    Nuance Outbound interface - Change to use  */
/*                                  Transmitlog3 (SOS27626)                    */
/* 03-Nov-2004  MaryVong     1.0    Merged C4ITF                               */
/* 26-Nov-2004  MaryVong     1.0    1) NZMMITF interface for rectype ='NORMAL' */
/*                                  and 'STD' with doctype = 'A'(SOS28043)     */ 
/*                                  2) Normal Goods received in NormalLocation */
/*                                  (SOS27580)                                 */
/* 28-Mar-2005  MaryVong     1.0    Close PO upon finalize receipt if the      */
/*                                  configkey 'ExtPOClose' is turn on          */
/*                                  (SOS33185)                                 */
/* 08-Apr-2005  June         1.0    SOS34204 - bug fixes                       */
/*                                  - include continue = '1' or '2'            */ 
/* (Feb,2005)   Ricky        1.0    To prevent the ASNstatus rollback to 0     */
/*                                  when 9                                     */
/* 04-May-2005  June         1.0    Bug fixes WTC ASN finalize error(SOS34573) */
/* 17-May-2005  MaryVong     1.0    IDSHK WTC -ASN Adjustment Export Interface */
/*                                  (SOS33183)                                 */
/* 17-Jun-2005  June         1.0    SOS37076 - add Valid RecType checking      */
/*                                  before creating "OWRCPT"                   */
/* 04-Jul-2005  Ung          1.0    Add RCPTLOG interface                      */
/* 07-Jul-2005  Vicky        1.0    Include Doctype as Key2 to be insert to    */
/*                                  transmitlog3 table when RCPTLOG turn on    */
/* 10-Oct-2005  MaryVong     1.0    SOS41481 CIBA - Receipt Confirm Export -   */
/*                                  Do not interface for RecType = 'KITTING'   */
/* 11-Jan-2006  MaryVong     1.0    SOS44990 PH WATSONS - Allow interface for  */
/*                                  rectype = 'NORMAL' and 'XDOCK'             */
/* 08-Dec-2005  Ung          1.0    To support RDT and re-number error code    */
/* 28-Apr-2006  Shong02      1.0    SOS50231- avoid error when bulk update     */
/* 06-Feb-2007  June         1.0    SOS66036 - Change NZTRDRET & NZRECPCFM     */
/*                                  to Transmitlog3 Table                      */
/* 27-Sep-2007  Shong        1.0    Close Multiple PO when ASNStatus changed   */
/*                                  SOS#87256                                  */
/* 02-Jul-2008  MaryVong     1.1    SOS#109780 VITAL Receipt Confirm Export -  */
/*                                  Add 'VRCPTLOG' configkey                   */
/* 25-Nov-2008  KC           1.2    Incorporate SQL2005 Std - WITH (NOLOCK)    */
/* 21-Jan-2009  Vanessa      1.3    SOS#126791 TransmitLog2.Key3=StorerKey     */
/*                                  for tablename='LORLRCP'  -- (Vanessa01)    */
/* 17-Mar-2009  TLTING       1.4    Change user_name() to SUSER_SNAME()        */
/* 22-Dec-2010  YokeBeen     1.5    SOS#198768 - Blocked interface on process  */
/*                                  of re-allocation with Configkey = 'GDSITF' */
/*                                  - (YokeBeen01)                             */
/* 22-May-2012  TLTING01     1.6    DM Integrity issue - Update editdate for   */
/*                                  status < '9'                               */
/* 01 Jun 2012  TLTING02     1.7    Add FinalizeDate                           */  
/* 06-Sep-2012  KHLim        1.8    Move up ArchiveCop (KH01)                  */
/* 30-Apr-2013  MCTang       1.9    Added new trigger point - RCPT2LOG for     */
/*                                  Alternate. (MC01)                          */
/* *************************************************************************** */
/* 08-Oct-2013  YokeBeen     1.3    Base on PVCS SQL2005_Unicode version 1.2.  */
/*                                  Insert for new trigger point "ADDASNLOG"   */
/*                                  - (YokeBeen02)                             */
/* 28-Oct-2013  TLTING       1.4    Review Editdate column update              */
/* 22-Nov-2013  YTWan        1.5    SOS#295094 - Nestle Wyeth HK - Request     */
/*                                  Create Receipt Cancellation TransmitLog    */
/*                                  (Wan01)                                    */
/* 06-Feb-2014  TLTING       1.6    ASNStatus Update not trigger to DM         */
/* 12-May-2015  MCTang       1.7    Enhance Generaic Trigger Interface (MC02)  */
/* 07-Apr-2016  NJOW01       1.8    Call custom trigger stored proc            */
/* 01-Mar-2017  TLTING       1.9    Remove Set Rowcount                        */
/* 01-Jun-2017  TLTING03     1.10   WMS-2047 WMS2GVT Inbound events            */
/* 27-Jul-2018  MCTang       1.11   Enhance Generaic Trigger Interface (MC03)  */
/* 26-JUL-2019  Wan02        1.12   WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for  */
/*                                  Channel                                    */
/* 23-JUL-2020  TLTING04     1.13   WMS-14128 Status LockDown period           */
/* 27-JUL-2020  WLChooi      1.14   WMS-14433 - New Extended Validation:       */
/*                                  ASNCloseExtendedValidation (WL01)          */
/* 26-AUG-2020  NJOW02       1.15   WMS-14941 update finalizedate upon close   */
/*                                  ASN by config                              */
/* 25-Nov-2020  WLChooi      1.16   WMS-15742 - Disable status update to 9 when*/
/*                                  openqty <= 0 (WL02)                        */
/* 27-Aug-2021  TLTING05     2.1    Extend ExternReceiptKey field length       */
/* 22-Mar-2023  CalvinKhor   2.2    Comment 'CONTINUE' as it prevents the logic*/
/*                                  below it to be executed (CLVN01)           */
/* 18-MAY-2023  NJOW03       2.3    WMS-22532 add config to disallow close asn */
/*                                  before finalize                            */
/* 03-AUG-2023  NJOW04       2.4    WMS-22772 When close ASN (ASNStatus=9) with*/
/*                                  partial received qty and status=9, prevent */
/*                                  reverse both status to 0 due to openqty > 0*/
/* 03-AUT-2023  NJOW04       2.5    DEVOPS Combine Script                      */
/* 02-NOV-2023  NJOW05       2.6    WMS-24047 update receiptdate upon close    */
/*                                  ASN by config                              */
/* 29-Jan-2024  Wan03        2.7    UWP-14379-Implement pre-save ASN standard  */
/*                                  validation check                           */
/*******************************************************************************/
CREATE   TRIGGER [dbo].[ntrReceiptHeaderUpdate]
ON  [dbo].[RECEIPT]
FOR UPDATE
AS
-- SOS27626 (ML) 14/10/04    Nuance Outbound interface - Change to use Trnasmitlog3
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_Success            int            -- Populated by calls to stored procedures - was the proc successful?
         , @n_err                int            -- Error number returned by stored procedure or this trigger
         , @n_err2               int            -- For Additional Error Detection
         , @c_errmsg             NVARCHAR(4000) -- Error message returned by stored procedure or this trigger   --WL01 Increase to NVARCHAR(4000) 
         , @n_continue           int
         , @n_starttcnt          int            -- Holds the current transaction count
         , @c_preprocess         NVARCHAR(250)  -- preprocess
         , @c_pstprocess         NVARCHAR(250)  -- post process
         , @n_cnt                int
         , @c_storerkey          NVARCHAR(15)   -- Added for IDSV5 by June 21.Jun.02
         , @c_facility           NVARCHAR(15)   -- Added for IDSV5 by June 21.Jun.02
         , @c_authority          NVARCHAR(1)    -- Added for IDSV5 by June 21.Jun.02
         , @c_ExtStatus          NVARCHAR(10)   -- Added for IDSV5 by June 21.Jun.02
         , @c_RecType            NVARCHAR(10)   -- Added for IDSV5 by June 21.Jun.02
         , @c_orderType          NVARCHAR(10)   -- Added for IDSTH by Ricky 27.Feb.03
         , @c_orderkey           NVARCHAR(10)   -- Added for IDSTH by Ricky 27.Feb.03
         , @c_receiptkey         NVARCHAR(10)
         , @c_currentreceipt     NVARCHAR(10)
         , @c_externreceiptkey   NVARCHAR(50)   --TLTING05

   DECLARE  @c_transmitlogkey    NVARCHAR(10)
          , @c_sourcekey         NVARCHAR(20)
          , @c_itrnkey           NVARCHAR(10)
          , @c_tablename         NVARCHAR(10)
          , @c_PoKey             NVARCHAR(18)
          , @c_ReceiptLine       NVARCHAR(5)
          , @c_ReceiptLine1      NVARCHAR(5)
          , @n_RowCnt            int
          , @c_ulpitf            NVARCHAR(1)
          , @c_NZMMITF           NVARCHAR(1)
          , @c_Long              NVARCHAR(10)
          , @c_ASNStatus         NVARCHAR(10)
          , @c_Status            NVARCHAR(10)
          , @c_DocType           NVARCHAR(1)
          , @c_NWITF             NVARCHAR(1)       -- Added for IDSHK-Nuance Watson by MaryVong on 02-Jun-2004
          , @c_warehouseRef      NVARCHAR(18) 
          , @c_warehouseRefinf   NVARCHAR(5)
          , @c_WTCITF            NVARCHAR(1)       -- Added for IDSHK-Watson Chemist by MaryVong on 18-Jun-2004
          , @c_C4ITF             NVARCHAR(1)       -- Added by MaryVong on 17-Aug-2004 (SOS25795-C4)
          , @c_authority_ExtPOClose NVARCHAR(1)    -- Added By MaryVong on 28-Mar-2005 (SOS33185)
          , @c_UpdatePOKey       NVARCHAR(10)      -- Added By MaryVong on 28-Mar-2005 (SOS33185)
          , @c_VRCPTLOGITF       NVARCHAR(1)       -- Added by MaryVong on 02-Jul-2008 (SOS109780)            
          , @c_RCPTLOGITF        NVARCHAR(1)       -- (MC01)
          , @c_RCPT2LOGITF       NVARCHAR(1)       -- (MC01)
          , @c_ADDASNLOG         NVARCHAR(1)       -- (YokeBeen02)
          , @c_StatusUpdated     CHAR(1)           -- (MC02) 
          , @c_COLUMN_NAME       VARCHAR(50)       -- (MC02) 
          , @c_ColumnsUpdated    VARCHAR(1000)     -- (MC02) 
          , @c_City              NVARCHAR(45)      -- TLTING03

          , @c_HoldChannel       NVARCHAR(1)       = '0' --(Wan02) 
          , @c_MarkASNLockdown   Nvarchar(1)  = '0'   --TLTING04
          , @c_CloseASNStatusUpdFinalizeDate NVARCHAR(30) --NJOW02
          , @c_CloseASNStatusUpdReceiptDate  NVARCHAR(30) --NJOW05
          , @c_DocTypeUpdReceiptDate         NVARCHAR(20) --NJOW05
          , @c_Option5                       NVARCHAR(MAX) --NJOW05
          , @c_ASNSkipStatusUpdate NVARCHAR(30)   --WL02
          , @c_DisallowCloseASNB4Finalize NVARCHAR(30) --NJOW03
          , @c_ASNStatus_From                NVARCHAR(10) = ''                      --(Wan03)
          , @c_ASNStatus_To                  NVARCHAR(10) = ''                      --(Wan03)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   SET @c_StatusUpdated = 'N'                      -- (MC02)

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
               WHERE INSERTED.ReceiptKey = DELETED.ReceiptKey
               AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' OR INSERTED.[ASNstatus] < '9' OR DELETED.[ASNstatus] < '9' )  ) 
         AND ( @n_continue = 1 or @n_continue = 2 )
         AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE  RECEIPT with (ROWLOCK)
      SET  EditDate = GETDATE(),
      EditWho    = Suser_Sname(),
      TrafficCop = NULL
      FROM RECEIPT, INSERTED
      WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
      AND   RECEIPT.Status < '9' 

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   /* #INCLUDE <TRRHU1.SQL> */

   DECLARE @b_ColumnsUpdated VARBINARY(1000)    --(MC02)
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()    --(MC02)

   --NJOW01
   IF @n_continue=1 or @n_continue=2          
   BEGIN      
      IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'ReceiptTrigger_SP')   -----> Current table trigger storerconfig
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
   
         EXECUTE dbo.isp_ReceiptTrigger_Wrapper ----->wrapper for current table trigger
                   'UPDATE'  -----> @c_Action can be INSERTE, UPDATE, DELETE
                 , @b_Success  OUTPUT  
                 , @n_Err      OUTPUT   
                 , @c_ErrMsg   OUTPUT  
   
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
                  ,@c_errmsg = 'ntrReceiptHeaderUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END  
         
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED
   
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END   
   
   --NJOW03
   IF (@n_continue=1 or @n_continue=2) AND UPDATE(ASNStatus)
   BEGIN
      SELECT @c_Storerkey = Storerkey, @c_Facility = Facility
      FROM INSERTED

      SELECT @b_success = 0
      
      EXECUTE nspGetRight 
         @c_Facility = @c_facility, -- facility
         @c_StorerKey = @c_StorerKey,  -- Storerkey
         @c_sku = null,          -- Sku
         @c_ConfigKey = 'DisallowCloseASNB4Finalize',        -- Configkey
         @b_Success = @b_success     OUTPUT,
         @c_authority = @c_DisallowCloseASNB4Finalize OUTPUT,
         @n_err = @n_err         OUTPUT,
         @c_errmsg = @c_errmsg   OUTPUT
         
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         SELECT @n_err = 60201
      END      
      
      IF @c_DisallowCloseASNB4Finalize = '1'
      BEGIN
         IF EXISTS(SELECT 1 
                   FROM INSERTED I 
                   JOIN DELETED D ON I.Receiptkey = D.Receiptkey
                   WHERE I.ASNStatus <> D.ASNStatus
                   AND I.ASNStatus = '9'
                   AND EXISTS(SELECT 1 
                              FROM RECEIPTDETAIL RD (NOLOCK)
                              WHERE RD.Receiptkey = I.Receiptkey
                              AND RD.FinalizeFlag <> 'Y'
                              AND RD.QtyExpected + RD.BeforeReceivedQty > 0))
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60200 --63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to close asn before finalize. (ntrReceiptHeaderUpdate)'          
         END                    
      END
      
      IF @n_Continue = 1                                                            --(Wan03) - START
      BEGIN
         SET @n_Cnt = 0
         SET @c_ASNStatus_From = ''
         SET @c_ASNStatus_To = ''

         SELECT @n_Cnt = 1
               ,@c_ASNStatus_From = d.ASNStatus
               ,@c_ASNStatus_To = i.ASNStatus
         FROM Inserted i
         JOIN Deleted  d ON i.ReceiptKey = d.Receiptkey
         OUTER APPLY dbo.fnc_GetAllowASNStatusChg(i.Facility, i.Storerkey, i.Doctype, i.Receiptkey, d.ASNStatus, i.ASNStatus) AASC
         WHERE i.ASNStatus <> d.ASNStatus 
         AND AASC.AllowChange = 0
         
         IF @n_Cnt = 1
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err=60261 --63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Disallow to change ASNStatus from ''' 
                           + @c_ASNStatus_From + ''' to ''' + @c_ASNStatus_To + ''''
                           +'. (ntrReceiptHeaderUpdate)'          
         END
      END                                                                           --(Wan03) - END
   END

   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF (@n_continue = 1 or @n_continue=2 )
      BEGIN
         DECLARE @c_billing NVARCHAR(30)
         SELECT @c_billing = NSQLValue FROM NSQLConfig WITH (NOLOCK) WHERE ConfigKey = 'WAREHOUSEBILLING'
         SELECT @c_billing = dbo.fnc_RTrim(@c_billing)
      END
      IF (@n_continue = 1 or @n_continue=2 ) AND @c_billing = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM INSERTED WHERE ContainerQty < BilledContainerQty )
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60201 --63800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Container Qty can not be reduced. (ntrReceiptHeaderUpdate)'
         END
      END

      -- Added for IDSV5 by June 21.Jun.02, (extract from IDSPH) *** Start
      IF @n_continue=1 or @n_continue=2
      BEGIN
         SELECT @c_Storerkey = Storerkey, @c_Facility = Facility
         FROM   Inserted

         SELECT @b_success = 0
         Execute nspGetRight @c_facility, -- facility
         @c_StorerKey,  -- Storerkey
         null,          -- Sku
         'RCPTRQD',        -- Configkey
         @b_success     output,
         @c_authority   output,
         @n_err         output,
         @c_errmsg      output
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60202
         END
         ELSE IF @c_authority = '1'
         BEGIN
            DECLARE @c_warehousereference NVARCHAR(18),
            @c_warehouseorigin NVARCHAR(6),
            @c_reasoncode      NVARCHAR(10),
            @c_salesmancode    NVARCHAR(10),
            @c_customercode    NVARCHAR(18),
            @c_value           NVARCHAR(10)
   
            SELECT @c_value = svalue
            FROM  storerconfig WITH (NOLOCK) JOIN inserted WITH (NOLOCK)
            ON    storerconfig.storerkey = inserted.storerkey
            WHERE storerconfig.configkey = 'RCPTRQD'
   
            IF @c_value <> '1' -- acsie checking: shouldn't be setup in the storerconfig
            BEGIN
               SELECT @c_warehousereference = warehousereference FROM INSERTED WITH (NOLOCK)
               SELECT @c_RecType = rectype FROM INSERTED WITH (NOLOCK)
   
               -- warehousereference should be integer if 'RPO' AND 'RRB'
               IF ISNUMERIC(@c_warehousereference) <> 1 AND @c_RecType IN ('RPO', 'RRB')
               BEGIN
                  SELECT @n_continue = 3, @n_err = 60203 --50000
                  SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Warehouse Reference. Expecting Number Value.'
               END
               -- warehouse origin should not be null when 'RRB'
               IF @n_continue <> 3
               BEGIN
                  SELECT @c_warehouseorigin = origincountry FROM INSERTED
                  IF ISNULL(@c_warehouseorigin, ' ') = ' ' AND @c_RecType = 'RRB'
                  BEGIN
                     SELECT @n_continue = 3, @n_err = 60204 --50000
                     SELECT @c_errmsg = 'VALIDATION ERROR: Warehouse Origin Required.'
                  END
               END
               -- warehouse origin set to 'BIC-01' when 'RPO'
               IF @n_continue <> 3
               BEGIN
                  IF @c_RecType = 'RPO'
                  BEGIN
                     UPDATE RECEIPT with (ROWLOCK)
                     SET  RECEIPT.origincountry = 'BIC-01'
                     FROM RECEIPT , INSERTED
                     WHERE RECEIPT.receiptkey = INSERTED.receiptkey
                  END
               END
   
               -- reasoncode, salesmancode, warehousereference should not be null when 'RET'
               IF @n_continue <> 3
               BEGIN
                  SELECT @c_reasoncode = asnreason, @c_salesmancode = vehiclenumber,
                  @c_customercode = carrierkey
                  FROM INSERTED
                  IF ISNULL(@c_warehousereference, ' ') = ' ' AND @c_RecType = 'RET'
                  BEGIN
                     SELECT @n_continue = 3, @n_err = 60205 --50000
                     SELECT @c_errmsg = 'VALIDATION ERROR: Warehouse Reference Required.'
                  END
                  IF ISNULL(@c_customercode, ' ') = ' ' AND @c_RecType = 'RET'
                  BEGIN
                     SELECT @n_continue = 3, @n_err = 60206 --50000
                     SELECT @c_errmsg = 'VALIDATION ERROR: Customer Code (Carrier) Required.'
                  END
                  IF ISNULL(@c_reasoncode, ' ') = ' ' AND @c_RecType = 'RET'
                  BEGIN
                     SELECT @n_continue = 3, @n_err = 60207 --50000
                     SELECT @c_errmsg = 'VALIDATION ERROR: ASN Reason Code Required.'
                  END
                  IF ISNULL(@c_salesmancode, ' ') = ' ' AND @c_RecType = 'RET'
                  BEGIN
                     SELECT @n_continue = 3, @n_err = 60208 --50000
                     SELECT @c_errmsg = 'VALIDATION ERROR: Salesman Code Required.'
                  END
               ELSE IF (SELECT COUNT(*)
               FROM CODELKUP WITH (NOLOCK)
               WHERE listname = 'SALESCODE'
               AND code = dbo.fnc_RTrim(dbo.fnc_LTrim(@c_salesmancode))) = 0 AND ISNULL(@c_salesmancode,' ') <> ' '
               BEGIN
                  SELECT @n_continue = 3, @n_err = 60209 --50000
                  SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Salesman Code.'
               END
   
               -- Date Modified 11/09/00
               -- BY: Gemma
               -- If 'RET', there should be no duplicate ref#
               IF  EXISTS(SELECT RECEIPT.warehousereference
                          FROM  RECEIPT WITH (NOLOCK), inserted
                          WHERE RECEIPT.receiptkey <> INSERTED.receiptkey
                          AND  INSERTED.warehousereference  = RECEIPT.Warehousereference)
                          AND  @c_RecType = 'RET'
               BEGIN
                  SELECT @n_continue = 3, @n_err = 60210 --50000
                  SELECT @c_errmsg = 'RECORD EXISTS: Warehouse Reference (PCM#) Existing...'
               END
            END
         END -- @c_value <> '1'
      END
   END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSPH) *** END
   --(Wan02) - START
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF UPDATE (HoldChannel)
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM  INSERTED WITH (NOLOCK)
                     JOIN  DELETED  WITH (NOLOCK) 
                           ON INSERTED.ReceiptKey = DELETED.ReceiptKey
                     CROSS APPLY dbo.fnc_SelectGetRight(INSERTED.Facility, INSERTED.Storerkey, '', 'ChannelInventoryMgmt') CFG
                     WHERE INSERTED.HoldChannel = '1'
                     AND   DELETED.HoldChannel = '0'
                     AND   CFG.Authority = '0'
                     )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 70010
            SET @c_errmsg  = CONVERT(char(5),@n_err)+': ASN with Channel Management turn off found'
                           + '. Disallow to hold channel. (ntrReceiptHeaderUpdate)'
         END 


         IF @n_continue = 1 or @n_continue=2
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM  INSERTED WITH (NOLOCK)
                        JOIN  DELETED  WITH (NOLOCK) 
                              ON INSERTED.ReceiptKey = DELETED.ReceiptKey
                        CROSS APPLY dbo.fnc_SelectGetRight(INSERTED.Facility, INSERTED.Storerkey, '','ASNDefaultHoldChannel') CFG
                        WHERE INSERTED.HoldChannel = '0'
                        AND   DELETED.HoldChannel = '1'
                        AND   INSERTED.ASNStatus < '9'
                        AND   CFG.Authority = '1'
                        )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 70020
               SET @c_errmsg  = CONVERT(char(5),@n_err)+': ASN Default Hold Channel is turn on'
                              + '. Disallow to unhold channel an open ASN. (ntrReceiptHeaderUpdate)'
            END 
         END

         IF @n_continue = 1 or @n_continue=2
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM  INSERTED WITH (NOLOCK)
                        JOIN  DELETED  WITH (NOLOCK) 
                              ON INSERTED.ReceiptKey = DELETED.ReceiptKey
                        JOIN  RECEIPTDETAIL RD WITH (NOLOCK)
                              ON INSERTED.ReceiptKey = RD.ReceiptKey
                        WHERE INSERTED.HoldChannel = '0'
                        AND   DELETED.HoldChannel = '1'
                        AND   INSERTED.ASNStatus < '9'
                        AND   RD.QtyReceived > 0
                        AND   RD.FinalizeFlag = 'Y'
                        --AND   RD.Channel_ID > 0
                        )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 70020
               SET @c_errmsg  = CONVERT(char(5),@n_err)+': Open ASN with Finalized ASN Line found'
                              + '. Disallow to unhold channel. (ntrReceiptHeaderUpdate)'
            END 
         END
           
         IF @n_continue = 1 or @n_continue=2
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM  INSERTED WITH (NOLOCK)
                        JOIN  DELETED  WITH (NOLOCK) 
                              ON INSERTED.ReceiptKey = DELETED.ReceiptKey
                        JOIN  RECEIPTDETAIL RD WITH (NOLOCK)
                              ON INSERTED.ReceiptKey = RD.ReceiptKey
                        WHERE INSERTED.HoldChannel = '1'
                        AND   DELETED.HoldChannel = '0'
                        AND   RD.QtyReceived > 0
                        AND   RD.FinalizeFlag = 'Y'
                        )
            BEGIN
               SET @n_continue = 3
               SET @n_err = 70030
               SET @c_errmsg  = CONVERT(char(5),@n_err)+': Finalized ASN Line found. Disallow to hold channel'
                              + '. (ntrReceiptHeaderUpdate)'
            END   
         END

         IF @n_continue = 1 or @n_continue=2
         BEGIN
            SET @c_receiptkey = ''
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1  
                        @c_receiptkey = INSERTED.Receiptkey 
                     ,  @c_HoldChannel= INSERTED.HoldChannel
               FROM  INSERTED WITH (NOLOCK)
               JOIN  DELETED  WITH (NOLOCK) 
                     ON INSERTED.ReceiptKey = DELETED.ReceiptKey
               WHERE INSERTED.ReceiptKey > @c_receiptkey
               AND   INSERTED.HoldChannel= '0'
               AND   DELETED.HoldChannel = '1'
               AND   EXISTS ( SELECT 1 
                              FROM RECEIPTDETAIL RD WITH (NOLOCK)
                              WHERE RD.ReceiptKey = INSERTED.ReceiptKey
                              AND   RD.QtyReceived  > 0 
                              AND   RD.FinalizeFlag = 'Y'
                              AND   RD.Channel_ID > 0
                            )
               AND   EXISTS ( SELECT 1
                              FROM ChannelInvHold HH WITH (NOLOCK)
                              WHERE HH.HoldType = 'ASN'
                              AND   HH.Sourcekey  = INSERTED.ReceiptKey
                            )
               ORDER BY INSERTED.ReceiptKey

               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               EXEC isp_ChannelInvHoldWrapper
                          @c_HoldType     = 'ASN'       
                        , @c_SourceKey    = @c_Receiptkey  
                        , @c_SourceLineNo = ''                                
                        , @c_Facility     = ''     
                        , @c_Storerkey    = ''     
                        , @c_Sku          = ''     
                        , @c_Channel      = ''     
                        , @c_C_Attribute01= ''     
                        , @c_C_Attribute02= ''     
                        , @c_C_Attribute03= ''     
                        , @c_C_Attribute04= ''     
                        , @c_C_Attribute05= ''     
                        , @n_Channel_ID   = 0     
                        , @c_Hold         = @c_HoldChannel     
                        , @c_Remarks      = ''      
                        , @b_Success      = @b_Success   OUTPUT
                        , @n_Err          = @n_Err       OUTPUT
                        , @c_ErrMsg       = @c_ErrMsg    OUTPUT

               IF @b_Success = 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 70040
                  SET @c_errmsg  = CONVERT(char(5),@n_err)+': Error Executing isp_ChannelInvHoldWrapper. (ntrReceiptHeaderUpdate)'
               END
            END
         END               
      END
   END
   --(Wan02) - END
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      -- Modify by ricky (Feb,2005) to prevent the ASNstatus rollback to 0 when 9 
      UPDATE RECEIPT with (ROWLOCK)
      SET  Status = '0', ASNStatus = '0'
      FROM RECEIPT , INSERTED, DELETED
      WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
      AND INSERTED.ReceiptKey = DELETED.ReceiptKey
      AND INSERTED.OpenQty > 0
      AND DELETED.Status = '9'
      --AND DELETED.ASNStatus <> '9'           
      AND INSERTED.ASNStatus <> '9' --NJOW04
      
   
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63801   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      
      SET @c_StatusUpdated = 'Y' -- (MC02)

   END

-- Added for IDSV5 by June 21.Jun.02, (extract from IDSSG) *** Start
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @b_success = 0

   Execute nspGetRight @c_facility, -- facility
   @c_StorerKey,  -- Storerkey
   null,          -- Sku
   'ASNSTRFACILITY', -- Configkey
   @b_success     output,
   @c_authority   output,
   @n_err         output,
   @c_errmsg      output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderupdate' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60211
   END
   ELSE IF @c_authority = '1'
   BEGIN
      -- Added By SHONG
      -- For Version 3.0 Convertion
      -- Date: 13th Jun 2001
      UPDATE RECEIPT with (ROWLOCK)
      SET Facility = STORER.Facility,
      TrafficCop = NULL
      FROM STORER WITH (NOLOCK), INSERTED WITH (NOLOCK)
      WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
      AND   RECEIPT.StorerKey = STORER.StorerKey
      AND  (INSERTED.Facility IS NULL)
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      -- END of add by shong
   END
END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSSG) *** END


IF @n_continue = 1 or @n_continue=2
BEGIN
   --WL02 START
   SELECT @b_success = 0, @c_ASNSkipStatusUpdate = ''
   Execute nspGetRight @c_Facility,  -- facility
                       @c_StorerKey,  -- Storerkey
                       null,          -- Sku
                       'ASNSkipStatusUpdate',     -- Configkey
                       @b_success     output,
                       @c_ASNSkipStatusUpdate  output,
                       @n_err         output,
                       @c_errmsg      output

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderupdate' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60260
   END
   ELSE 
   BEGIN
      IF ISNULL(@c_ASNSkipStatusUpdate,'') <> '1'
      BEGIN --WL02 END
         UPDATE  RECEIPT with (ROWLOCK)
            SET  Status = '9'
         FROM RECEIPT , INSERTED, DELETED
         WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
         AND INSERTED.ReceiptKey = DELETED.ReceiptKey
         AND INSERTED.OpenQty <= 0
         AND (SELECT SUM(QtyReceived) From Receiptdetail RD WITH (NOLOCK) WHERE RD.Receiptkey = INSERTED.RECEIPTKEY) > 0
      
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
   
         SET @c_StatusUpdated = 'Y' -- (MC02)
      END   --WL02
   END   --WL02

END -- @n_continue = 1 or @n_continue=2

-------------------- Interface ---------------------------------------------
IF @n_continue = 1 or @n_continue=2
BEGIN
   DECLARE @c_NIKEHKITF NVARCHAR(1)   
   DECLARE @c_TBLHKITF  NVARCHAR(1),
           @c_STBTHITF  NVARCHAR(1)

   /* Added By Vicky 09 Apr 2003 - For CDC Migration */
   -- Add by June 19.Aug.02
   -- ULP/CMC : FBR7252, 7251 & 7254
   -- SOS 8924 - to include partial receipt
   -- wally 13.dec.2002
   -- IF @N_CNT > 0 AND @n_err = 0
   SELECT @c_receiptkey = SPACE(10)

   WHILE 1 = 1
   BEGIN
      
      SELECT TOP 1 @c_storerkey  = RECEIPT.Storerkey,
             @c_receiptkey = RECEIPT.Receiptkey,
             @c_Facility   = RECEIPT.Facility,
             @c_ASNStatus  = RECEIPT.ASNStatus,
             @c_RecType    = RECEIPT.RecType,  
             @c_Status     = RECEIPT.Status,
             @c_DocType    = RECEIPT.DocType,
             @c_Facility   = RECEIPT.Facility, 
             @c_warehouseRef = RECEIPT.WAREHOUSEREFERENCE   
      FROM  Inserted WITH (NOLOCK), RECEIPT WITH (NOLOCK)
      WHERE INSERTED.ReceiptKey > @c_receiptkey
      AND   INSERTED.Receiptkey = RECEIPT.Receiptkey
      ORDER BY INSERTED.ReceiptKey

      IF @@ROWCOUNT = 0
         BREAK

      -- (Wan01) - START
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM  INSERTED WITH (NOLOCK)
                     JOIN  DELETED  WITH (NOLOCK) ON (INSERTED.ReceiptKey = DELETED.ReceiptKey)
                     WHERE INSERTED.Receiptkey = @c_receiptkey
                     AND   INSERTED.ASNStatus = 'CANC'
                     AND   INSERTED.ASNStatus <> DELETED.ASNStatus )
         BEGIN
            SET @b_success = 0
            SET @c_authority = 0
            Execute nspGetRight null,  -- facility
               @c_StorerKey,  -- Storerkey
               null,          -- Sku
               'RCPTCANLOG',  -- Configkey
               @b_success     output,
               @c_authority   output,
               @n_err         output,
               @c_errmsg      output

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
               SET @n_err = 60257
               BREAK
            END
            -- IF (@c_WTSITF = '1' AND @c_RecType = 'NORMAL' AND @c_doctype = 'A')
            IF @c_authority = '1' 
            BEGIN
               SET @c_TableName = 'RCPTCANLOG'

               EXEC ispGenTransmitLog3 @c_tablename, @c_receiptkey, @c_doctype, @c_storerkey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(CHAR(250),@n_err)
                  SET @n_err=60258 --63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey2 (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
               CONTINUE          
            END
         END
      END
      -- (Wan01) - END

      -- No interface when non-finalized receipt lines found 
      IF EXISTS(SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK) WHERE ReceiptKey = @c_ReceiptKey AND
                FinalizeFlag = 'N' 
                AND BeforeReceivedQty > 0) -- Add by June 13.May.2004 SOS23092
         CONTINUE

      -- No interface when finalized receipt lines not found 
      IF NOT EXISTS(SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK) WHERE ReceiptKey = @c_ReceiptKey AND
                FinalizeFlag = 'Y') 
         CONTINUE

      IF @n_continue = 1 or @n_continue=2
      BEGIN
         SELECT @b_success = 0
         Execute nspGetRight null,  -- facility
            @c_StorerKey,  -- Storerkey
            null,          -- Sku
            'NIKEHKITF',   -- Configkey
            @b_success     output,
            @c_NIKEHKITF   output,
            @n_err         output,
            @c_errmsg      output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60212
            BREAK
         END

         IF @c_NIKEHKITF = '1'
         BEGIN
            IF @c_RecType = 'NORMAL' 
            BEGIN
               EXEC ispGenTransmitLog 'NIKEHKRCPT', @c_ReceiptKey, '', '', ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60213 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to Generate transmitlog Record, TableName = NIKEHKRCPT (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- NIKEHKRCPT
            CONTINUE 
         END -- NIKEHKITF
         -- END -- SOS11009
      END -- continue 

      IF @n_continue = 1 or @n_continue=2
      BEGIN
         -- determine which setup to use   -- requested by Peter Goh.
         SELECT @b_success = 0
         Execute nspGetRight null,  -- facility
            @c_StorerKey,  -- Storerkey
            null,          -- Sku
            'ULPITF',         -- Configkey
            @b_success     output,
            @c_ulpitf   output,
            @n_err         output,
            @c_errmsg      output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60214
            break
         END
         ELSE
         BEGIN -- else BEGIN
            IF @c_ulpitf = '1'
            BEGIN -- @c_authority
               SELECT @c_ReceiptLine1 = SPACE(5)
               WHILE (1=1)
               BEGIN
                  
                  SELECT TOP 1 @c_ReceiptLine1 = RECEIPTDETAIL.RECEIPTLINENUMBER,
                         @c_PoKey = RECEIPTDETAIL.POKEY
                  FROM   RECEIPTDETAIL WITH (NOLOCK) 
                  WHERE  RECEIPTDETAIL.RECEIPTKEY = @c_ReceiptKey
                  AND    RECEIPTDETAIL.ReceiptLineNumber > @c_ReceiptLine1
                  AND    RECEIPTDETAIL.QtyReceived > 0
                  AND    RECEIPTDETAIL.FInalizeFlag IN ('Y', 'P')
                  ORDER BY RECEIPTDETAIL.ReceiptLineNumber

                  SELECT @n_RowCnt = @@ROWCOUNT

                  IF @n_RowCnt = 0
                     BREAK

                  IF @c_RecType in ('RET','GRN')
                     SELECT @c_tablename = 'ULPRM' -- Returns AND rejects
                  ELSE
                  BEGIN -- Normal ASN
                     IF @c_PoKey <> ''
                        SELECT @c_tablename = 'ULPPO' -- Receipt with PO
                     ELSE
                        SELECT @c_tablename = 'ULPIR' -- Receipt with Non-PO
                  END
   
                  EXEC ispGenTransmitLog @c_tablename, @c_ReceiptKey, @c_ReceiptLine1, '', ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
   
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60215 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to Generate transmitlog Record, TableName = '+ CONVERT(CHAR(10),@c_tablename) +' (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- While loop 2, Receipt Line 
               CONTINUE 
            END -- IF 'ULPITF' is ON
         END -- IF @b_success = 1 
      END -- Continue

      -- Added By SHONG on 15th Sep 2003
      -- For MANDOM Singapore Interface
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         IF EXISTS( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey
         AND ConfigKey = 'MDMITF' AND sValue = '1'   )
         BEGIN
            -- make sure all the lines was finalized
            IF @c_RecType = 'NORMAL' 
            BEGIN
               EXEC ispGenTransmitLog 'MDMRCPT', @c_ReceiptKey, '', @c_StorerKey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60216 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to Generate transmitlog Record, TableName = NIKEHKRCPT (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- @c_RecType = 'NORMAL' 
            CONTINUE 
         END -- MDMITF 
      END -- @n_continue = 1 or @n_continue=2

      -- SOS 20311: MXP Receipt Confirmation Upload
      -- start: 20311
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         IF EXISTS( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey
         AND ConfigKey = 'MXPITF' AND sValue = '1'   )
         BEGIN
            EXEC ispGenTransmitLog2 'MXPRCPT', @c_ReceiptKey, '', @c_StorerKey, ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60217 --63811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to Generate transmitlog2 Record, TableName = MXPRCPT (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
      -- END: 20311
      -- Start IDSHK FBR: Outbound - PIX Confirmation
      -- June 11.Apr.2003
      IF (@n_continue = 1 or @n_continue = 2)
      BEGIN
         IF EXISTS(SELECT StorerKey FROM STORERCONFIG S WITH (NOLOCK) 
                   WHERE  S.storerkey = @c_StorerKey AND S.configkey = 'TBLHKITF'
                   AND    S.svalue = '1') 
         BEGIN 
            
            SELECT @c_reasoncode = asnreason FROM INSERTED WITH (NOLOCK) where receiptkey = @c_ReceiptKey
            
            IF EXISTS (SELECT ReceiptKey 
                       FROM   RECEIPTDETAIL WITH (NOLOCK) 
                       JOIN   LOC WITH (NOLOCK) ON (RECEIPTDETAIL.TOLOC = LOC.LOC)
                       LEFT OUTER JOIN ID WITH (NOLOCK) ON (RECEIPTDETAIL.TOID = ID.ID)
                       WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
                         AND  RECEIPTDETAIL.FinalizeFlag = 'Y'
                         AND  ( (LOC.Locationflag = 'HOLD' OR LOC.Locationflag = 'DAMAGED' OR ID.Status = 'HOLD') OR
                              ( @c_RecType = 'TBLRCPADJ' AND 
                              ( dbo.fnc_RTrim(RECEIPTDETAIL.POkey) IS NULL OR dbo.fnc_RTrim(RECEIPTDETAIL.POkey) = ''))))
               AND @c_reasoncode <> '99'
            BEGIN
               IF @c_RecType <> 'NORMAL'
                  SELECT @c_tablename = 'TBLTRFIN'
               ELSE
                  SELECT @c_tablename = 'TBLASNFIN'
   
               EXEC ispGenTransmitLog2 @c_tablename, @c_ReceiptKey, '', '', ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60218 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
            ELSE -- SOS 27580 :Normal Goods Received in Normal Location (Interface Changes)
            BEGIN
               IF EXISTS (SELECT ReceiptKey 
                          FROM   RECEIPTDETAIL WITH (NOLOCK) 
                          JOIN   LOC WITH (NOLOCK) ON (RECEIPTDETAIL.TOLOC = LOC.LOC)
                          WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
                            AND  RECEIPTDETAIL.FinalizeFlag = 'Y'
                            AND  LOC.Locationflag <> 'HOLD' 
                            AND  LOC.Locationflag <> 'DAMAGED' 
                            AND  LOC.Status = 'OK'
                            AND  @c_RecType = 'NORMAL')
                  AND @c_reasoncode <> '99'
               BEGIN
                  IF @c_RecType <> 'NORMAL'
                     SELECT @c_tablename = 'TBLTRFIN'
                  ELSE
                     SELECT @c_tablename = 'TBLASNFIN'
      
                  EXEC ispGenTransmitLog2 @c_tablename, @c_ReceiptKey, '', '', ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
      
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60219 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
            END 
            CONTINUE 
         END -- configkey = 'TBLHKITF'
      END -- continue = 1

      IF (@n_continue = 1 or @n_continue = 2)
      BEGIN
         SELECT @c_STBTHITF = 0

         EXECUTE nspGetRight null,  -- facility
                @c_storerkey,          -- Storerkey
                 null,                 -- Sku
                'STBTHITF',            -- Configkey
                @b_success output,
                @c_STBTHITF output,
                @n_err output,
                @c_errmsg output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60220
         END
         ELSE IF @c_STBTHITF = '1'
         BEGIN
            SELECT @b_success = 1

            EXEC ispGenTransmitLog 'ASNCONF', @c_receiptkey, '', '', ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60221 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- Valid StorerConfig
      END -- continue 
      
      -- Added by MaryVong on 11-Mar-2004 (NZMM FBR19000 Trade Return Export) -Start
      -- When finalised, checking on the StorerConfig for Storerkey = 'NZMM' or 'SUSUMAS' if it is enabled
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         SELECT @c_NZMMITF = '0'
         EXECUTE nspGetRight 
               NULL, -- facility
               @c_storerkey,           -- Storerkey
               null,                   -- Sku
               'NZMMITF',              -- Configkey
               @b_success output,
               @c_NZMMITF output,
               @n_err output,
               @c_errmsg output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60222
         END
         ELSE IF @c_NZMMITF = '1' -- Valid StorerConfig (having setup for interface)
         BEGIN
            -- Modified by MaryVong on 13Oct2004 (SOS28043)
            -- Added interface for rectype = 'NORMAL' and 'STD' with doctype = 'A'
            IF @c_ASNStatus = '9' -- AND (@c_DocType = 'R')
            BEGIN
               -- Check if the RecType is setting for interface
               SELECT @c_Long = Long
               FROM  CODELKUP WITH (NOLOCK)
               WHERE ListName = 'RECTYPE'
               AND Code = @c_RecType

               IF @c_Long = 'ITF'
               BEGIN
                  IF @c_DocType = 'R' -- set for interface (Trade Return)
                     SELECT @c_tablename = 'NZTRDRET'
                  ELSE IF @c_DocType = 'A' -- set for interface (Normal and STD)
                     SELECT @c_tablename = 'NZRECPCFM'
                     
                  -- SOS66036 - Change to ispGenTransmitLog3
                  EXEC ispGenTransmitLog3 @c_tablename, @c_receiptkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60223 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END  -- @c_Long = 'ITF' 
            END -- @c_ASNStatus = '9'
         END -- Valid StorerConfig
      END -- @n_continue = 1 or @n_continue=2
      -- Added by MaryVong on 11-Mar-2004 (NZMM FBR19000 Trade Return Export) - End ------------------------------------------                  

      -- 16 Sept 2004 YTWan - FBR_JAMO006-Outbound-Receipt Confirmation - START
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         IF EXISTS( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey
                    AND ConfigKey = 'JAMORECCFMITF' AND sValue = '1' AND @c_RecType = 'NORMAL' AND @c_doctype = 'A'  )
         BEGIN
            EXEC ispGenTransmitLog2 'JAMORCPCFM', @c_receiptkey, '', @c_storerkey, ''
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60224 --63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey2 (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- Valid StorerConfig,  ReceiptType, Doctype
      END
      -- 16 Sept 2004 YTWan - FBR_JAMO006-Outbound-Receipt Confirmation - END

      -- Start : SOS31970 - Add by June 04.Feb.2005
      IF @n_continue = 1 or @n_continue=2
      BEGIN
         DECLARE @c_WTSITF NVARCHAR(1)
         SELECT @b_success = 0
         Execute nspGetRight null,  -- facility
            @c_StorerKey,  -- Storerkey
            null,          -- Sku
            'WTS-ITF',  -- Configkey
            @b_success     output,
            @c_WTSITF      output,
            @n_err         output,
            @c_errmsg      output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            SELECT @n_err = 60225
            BREAK
         END

         -- SOS44990 Allow interface for 'NORMAL' and 'XDOCK'
         -- IF (@c_WTSITF = '1' AND @c_RecType = 'NORMAL' AND @c_doctype = 'A')
         IF (@c_WTSITF = '1' AND (@c_RecType = 'NORMAL' OR @c_RecType = 'XDOCK') )
         BEGIN
            SELECT @c_externreceiptkey = dbo.fnc_LTrim(dbo.fnc_RTrim(INSERTED.ExternReceiptKey))
            FROM  Inserted WITH (NOLOCK)
            WHERE INSERTED.ReceiptKey = @c_receiptkey 

            EXEC ispGenTransmitLog2 'WTS-RCPT', @c_receiptkey, '', @c_externreceiptkey, ''
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60226 --63820   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey2 (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END            
         END
      END
      -- End : SOS31970
   END -- While Loop 1, Receipt Key 
   
END -- @n_continue = 1 or @n_continue=2

-- Added for IDSV5 by June 21.Jun.02, (extract from IDSHK) *** Start
IF @n_continue=1 or @n_continue=2
BEGIN
   DECLARE @c_GenRecDetailLog NVARCHAR(1)
   DECLARE @c_Interfaceflag NVARCHAR(1),
           @c_NikeReg       NVARCHAR(1),
           @c_PMTLRCP       NVARCHAR(1),
           @c_UserDefine10  NVARCHAR(30),
           @c_CDSRCP        NVARCHAR(1),
           @c_CNNIKEITF     NVARCHAR(1),
           @c_LorealItf     NVARCHAR(1),
           @c_CibaItf       NVARCHAR(1) -- SOS25285   
            
   -- Add by June 11.Mar.02
   IF UPDATE(ASNStatus)
   BEGIN
      If Exists(SELECT 1 From Inserted WHERE ASNStatus = '9')
      BEGIN
         SELECT @c_receiptkey = SPACE(10)

         WHILE 1 = 1
         BEGIN
            -- Get Storer Configuration -- One World Interface
            -- Is One World Interface Turn On?
             
            -- DECLARE @c_externreceiptkey NVARCHAR(20)
            SELECT TOP 1 @c_storerkey        = Inserted.Storerkey,
                   @c_receiptkey       = Inserted.Receiptkey,
                   @c_RecType          = INSERTED.RecType,
                   @c_externreceiptkey = dbo.fnc_LTrim(dbo.fnc_RTrim(INSERTED.ExternReceiptKey)),
                   @c_UserDefine10     = INSERTED.UserDefine10,
                   @c_POKey            = INSERTED.POKEY, 
                   @c_ASNStatus        = INSERTED.ASNStatus,
                   @c_RecType          = INSERTED.RecType,  
                   @c_Status           = INSERTED.Status,
                   @c_DocType          = INSERTED.DocType,
                   @c_Facility         = INSERTED.Facility, 
                   @c_warehouseRef     = INSERTED.WAREHOUSEREFERENCE   
            FROM Inserted WITH (NOLOCK)
            WHERE INSERTED.ReceiptKey > @c_receiptkey
            AND   INSERTED.ASNStatus = '9'
            ORDER BY ReceiptKey

            IF @@ROWCOUNT = 0
               BREAK

            -- Added by Ung on 13-Apr-2004 (RCPTLOG interface) - Start
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               -- DECLARE @c_RCPTLOGITF NVARCHAR( 1)   --(MC01)
               SELECT @c_RCPTLOGITF = 0, @b_success = 0

               EXECUTE nspGetRight NULL,  -- facility
                      @c_storerkey,       -- Storerkey
                      NULL,               -- Sku
                      'RCPTLOG',      -- Configkey
                      @b_success output,
                      @c_RCPTLOGITF output,
                      @n_err output,
                      @c_errmsg output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_RCPTLOGITF = '1'
               BEGIN
                  SELECT @b_success = 1                                                             
                     EXEC ispGenTransmitLog3 'RCPTLOG', @c_receiptkey, @c_DocType, @c_storerkey, '' -- Added in DocType to determine Return/Normal Receipt
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
      
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- Valid StorerConfig
            END -- continue 
            -- Added by Ung on 13-Apr-2004 (RCPTLOG interface) - End

            -- (MC01) - S
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN

               SELECT @c_RCPT2LOGITF = 0, @b_success = 0

               EXECUTE nspGetRight 
                      NULL,          -- facility
                      @c_storerkey,  -- Storerkey
                      NULL,          -- Sku
                      'RCPT2LOG',    -- Configkey
                      @b_success     output,
                      @c_RCPT2LOGITF output,
                      @n_err         output,
                      @c_errmsg      output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_RCPT2LOGITF = '1'
               BEGIN
                  SELECT @b_success = 1                                                             
                     EXEC ispGenTransmitLog3 'RCPT2LOG', @c_receiptkey, @c_DocType, @c_storerkey, '' 
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
      
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- IF @c_RCPT2LOGITF = '1'
            END -- IF (@n_continue = 1 or @n_continue = 2)
            -- (MC01) - E

            -- Added by MaryVong on 02-Jul-2008 (FBR#109780 VITAL Receipt Confirm interface) - Start
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               SELECT @c_VRCPTLOGITF = 0, @b_success = 0

               EXECUTE nspGetRight NULL,  -- facility
                      @c_storerkey,       -- Storerkey
                      NULL,               -- Sku
                      'VRCPTLOG',         -- Configkey
                      @b_success output,
                      @c_VRCPTLOGITF output,
                      @n_err output,
                      @c_errmsg output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
               END
               ELSE IF @c_VRCPTLOGITF = '1'
               BEGIN
                  SELECT @b_success = 1                                                             
                     EXEC ispGenVitalLog 'VRCPTLOG', @c_receiptkey, @c_DocType, @c_storerkey, '' -- Added in DocType to determine Return/Normal Receipt
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
      
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain VitalLogKey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
                  END
               END -- Valid StorerConfig
            END -- continue 
            -- Added by MaryVong on 02-Jul-2008 (FBR#109780 VITAL Receipt Confirm interface) - End

            -- Added by MaryVong on 02-Jun-2004 (IDSHK-Nuance Watson) - Start
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               SELECT @c_NWITF = 0, @b_success = 0

               EXECUTE nspGetRight NULL,  -- facility
                      @c_storerkey,       -- Storerkey
                      NULL,               -- Sku
                      'NWInterface',      -- Configkey
                      @b_success output,
                      @c_NWITF output,
                      @n_err output,
                      @c_errmsg output

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60227
               END
               ELSE IF @c_NWITF = '1'
               BEGIN
                  SELECT @b_success = 1
                  SELECT @c_warehouseRefinf = RIGHT(@c_warehouseRef,5)
                  IF @c_DocType <> 'R'
                  BEGIN
-- SOS27626          EXEC ispGenTransmitLog2 'NWASNCF', @c_receiptkey, @c_warehouseRefinf, @c_storerkey, ''
                     EXEC ispGenTransmitLog3 'NWASNCF', @c_receiptkey, @c_warehouseRefinf, @c_storerkey, ''        -- SOS27626
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                  END
                  ELSE
                  BEGIN
-- SOS27626          EXEC ispGenTransmitLog2 'NWRTWASNCF', @c_receiptkey, @c_warehouseRefinf, @c_storerkey, ''
                     EXEC ispGenTransmitLog3 'NWRTWASNCF', @c_receiptkey, @c_warehouseRefinf, @c_storerkey, ''     -- SOS27626
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                  END
      
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60228 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- Valid StorerConfig
            END -- continue 
            -- Added by MaryVong on 02-Jun-2004 (IDSHK-Nuance Watson) - End

            -- Added by MaryVong on 18-Jun-2004 (IDSHK-Watson Chemist) - Start
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               SELECT @c_WTCITF = 0, @b_success = 0 
      
               EXECUTE nspGetRight NULL,  -- facility
                      @c_storerkey,       -- Storerkey
                      NULL,               -- Sku
                      'WTCInterface',     -- Configkey
                      @b_success output,
                      @c_WTCITF output,
                      @n_err output,
                      @c_errmsg output
      
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60229
               END
               -- Remarked by MaryVong on 17-May-2005 (SOS33183)
               -- ELSE IF @c_WTCITF = '1' AND dbo.fnc_RTrim(@c_RecType) <> 'TRANSFER'  -- SOS25581
               ELSE IF @c_WTCITF = '1' 
               BEGIN
                  SELECT @b_success = 1
                  SELECT @c_warehouseRefinf = RIGHT(@c_warehouseRef,5)

                  IF dbo.fnc_RTrim(@c_RecType) = 'WTCADJ'  -- SOS33183
                  BEGIN
                     EXEC ispGenTransmitLog2 'WTCASNADJ', @c_receiptkey, @c_warehouseRefinf, @c_storerkey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
         
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60230 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END
                  ELSE IF dbo.fnc_RTrim(@c_RecType) <> 'TRANSFER'  -- SOS25581
                  BEGIN
                     EXEC ispGenTransmitLog2 'WTCASNCF', @c_receiptkey, @c_warehouseRefinf, @c_storerkey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
         
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60231 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END 
                  END -- ELSE IF dbo.fnc_RTrim(@c_RecType) <> 'TRANSFER'  -- SOS25581
                  
               END -- Valid StorerConfig
            END -- continue 
            -- Added by MaryVong on 18-Jun-2004 (IDSHK-Watson Chemist) - End

            -- Added by MaryVong on 17-Aug-2004 (SOS25795-C4) - Start
            IF (@n_continue = 1 or @n_continue = 2)
            BEGIN
               SELECT @c_C4ITF = 0, @b_success = 0 
      
               EXECUTE nspGetRight NULL,  -- facility
                      @c_storerkey,       -- Storerkey
                      NULL,               -- Sku
                      'C4ITF',            -- Configkey
                      @b_success output,
                      @c_C4ITF output,
                      @n_err output,
                      @c_errmsg output
      
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60232
               END
               ELSE IF @c_C4ITF = '1'
               BEGIN
                  SELECT @b_success = 1

                  EXEC ispGenTransmitLog2 'C4ASNCF', @c_receiptkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
      
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60233 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- Valid StorerConfig
            END -- continue 
            -- Added by MaryVong on 17-Aug-2004 (SOS25795-C4) - End

            -- Added By MaryVong on 28-Mar-2005 (SOS33185) - Start
            -- Upon finalize Receipt, check if only 1 PO involved: while ASNStatus='9',
            -- check if PO.ExternStatus equals to '9' (closed) then error; else
            -- update PO.ExternStatus = '9' (even if not fully received)
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               Execute nspGetRight NULL,  -- facility
                     @c_StorerKey,        -- Storerkey
                     NULL,                -- Sku
                     'ExtPOClose',        -- Configkey
                     @b_success                output,
                     @c_authority_ExtPOClose   output,
                     @n_err2                   output,
                     @c_errmsg                 output
      
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60234
               END
               ELSE IF @c_authority_ExtPOClose = '1'
               BEGIN
                  -- Only apply for cases with 1 PO
                  -- If PO is closed, prompt error message
                  -- Start : SOS34573, changed by June 04.May.2005 (bug fixed HK WTC finalize problem)
                  -- Begin : SHONG02 - Process on specific @c_ReceiptKey
                  -- SOS#87256
                  IF (SELECT COUNT( DISTINCT B.POKEY)             
                      FROM RECEIPTDETAIL WITH (NOLOCK) 
                      JOIN PO WITH (NOLOCK) ON RECEIPTDETAIL.POKey = PO.POKey 
                      LEFT OUTER JOIN RECEIPTDETAIL B WITH (NOLOCK) 
                                      ON B.StorerKey = PO.StorerKey     -- Shong Tune
                                      AND B.ExternReceiptKey = PO.ExternPOKey 
                                      AND B.Receiptkey <> @c_ReceiptKey                    
                      WHERE PO.ExternStatus = '9' 
                      AND   RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey) > 0 
                  -- End : SOS34573
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60235 --64101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PO Already Closed. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
                  ELSE      
                  BEGIN  
                     -- SOS#87256
                     -- Change to Multiple PO in 1 ASN 
                     -- Get POKey for update   
                     DECLARE C_UPDATE_POStatus CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
                        SELECT DISTINCT PO.POKey 
                        FROM RECEIPTDETAIL WITH (NOLOCK) 
                        JOIN PO WITH (NOLOCK) ON RECEIPTDETAIL.POKey = PO.POKey 
                        WHERE PO.ExternStatus = '0' 
                         AND  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey 
   
                     OPEN C_UPDATE_POStatus 

                     FETCH NEXT FROM C_UPDATE_POStatus INTO @c_UpdatePOKey 
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN 
                        -- Close the PO
                        UPDATE PO with (ROWLOCK)
                           SET ExternStatus = '9',
                           EditDate = GETDATE(),   --tlting
                           EditWho = SUSER_SNAME()
                         WHERE POKey = @c_UpdatePOKey
                           AND ExternStatus = '0'
                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60236 --64101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PO. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                        FETCH NEXT FROM C_UPDATE_POStatus INTO @c_UpdatePOKey 
                     END 
                     CLOSE C_UPDATE_POStatus
                     DEALLOCATE C_UPDATE_POStatus 
                  END    
                  -- End : SHONG02 - Process on specific @c_ReceiptKey
               END 
            END
            -- Added By MaryVong on 28-Mar-2005 (SOS33185) - End

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204
               -- Added by YokeBeen on 08-Apr-2004 - IDSHK (SOS#20555)
               SELECT @b_success = 0
   
               Execute nspGetRight NULL,        -- facility
                        @c_StorerKey,           -- Storerkey
                        NULL,                   -- Sku
                        'GenRecDetailLog',      -- Configkey
                        @b_success           output,
                        @c_GenRecDetailLog   output,
                        @n_err               output,
                        @c_errmsg            output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60237
                  BREAK
               END
               ELSE
               BEGIN -- else BEGIN
                  IF @c_GenRecDetailLog = '1'
                  BEGIN
                  IF @c_RecType = 'NORMAL' AND
                        EXISTS ( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)
                                 WHERE RECEIPTDETAIL.Receiptkey = @c_Receiptkey AND RECEIPTDETAIL.FINALIZEFLAG = 'Y' )
                     BEGIN
                        EXEC ispGenTransmitLog2 'GENRECPLOG', @c_ReceiptKey, '', @c_StorerKey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
   
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60238 --63812   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL' + CONVERT(CHAR(5),@n_err) + ': Unable to Generate transmitlog Record, TableName = NIKEHKRCPT (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                     END -- If Exists
                     CONTINUE 
                  END -- GENRECPLOG
               END -- GenRecDetailLog
               -- ENDed by YokeBeen on 08-Apr-2004 - IDSHK (SOS#20555)
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204
               -- Added By YokeBeen on 13-Oct-2003 For NIKE Regional (NSC) Project - (SOS#15351)
               -- Get Storer Configuration
               EXECUTE nspGetRight
                  NULL, -- Facility
                  @c_StorerKey,  -- Storerkey
                  NULL,          -- Sku
                  'NIKEREGITF',  -- Configkey
                  @b_success     OUTPUT,
                  @c_nikereg     OUTPUT,
                  @n_err         OUTPUT,
                  @c_errmsg      OUTPUT
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60239
                  BREAK 
               END
               ELSE IF @c_nikereg = '1'
               BEGIN 
                  SELECT @c_Interfaceflag = ''
      
                  IF @c_Userdefine10 = 'NSCITF' AND UPPER(@c_RecType) IN ('NORMAL', 'DIRECT')
                  BEGIN
                     -- check RecType
                     -- Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
                     -- Changed to trigger records into NSCLog table with 'NSCKEY'.
                     EXEC ispGenNSCLog 'NIKEREGRCP', @c_receiptkey, '', @c_storerkey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
      
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60240 --63805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Unable to Generate nsclog Record, TableName = NIKEREGRCP (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END
            -- Commented by YokeBeen on 14-Apr-2004 - Start
            -- No Return Receipt Interface is required for NSC Inventory Adjustment Outbound.
            -- This transaction will go under the Transfer Module.
   --                ELSE
   --                BEGIN
   --                   IF UPPER(@c_RecType) IN ('GRN', 'RETURNREC')
   --                   BEGIN -- check RecType
   --                      EXEC ispGenNSCLog 'NIKEREGTRN', @c_receiptkey, '', @c_storerkey, ''
   --                      , @b_success OUTPUT
   --                      , @n_err OUTPUT
   --                      , @c_errmsg OUTPUT
   --    
   --                      IF @b_success <> 1
   --                      BEGIN
   --                         SELECT @n_continue = 3
   --                         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --                         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Unable to Generate nsclog Record, TableName = NIKEREGTRN (ntrReceiptHeaderUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   --                      END
   --                      -- END Modified By YokeBeen on 20-Feb-2004 For NIKE Regional (NSC) Project (SOS#20000)
   --                   END -- check RecType
   --                END
            -- Commented by YokeBeen on 14-Apr-2004 - End
            --      CONTINUE --(CLVN01)
               END -- if @c_authority = '1'
               -------- SOS#15351 ---------------------------------------------------------------------------------
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204
               -- Added By Vicky 14 Nov 2002 For PMTL Receipt Export
               SELECT @b_success = 0
               Execute nspGetRight 
                        NULL, -- facility
                        @c_StorerKey,  -- Storerkey
                        null,          -- Sku
                        'PMTLRCP',        -- Configkey
                        @b_success     output,
                        @c_PMTLRCP     output,
                        @n_err         output,
                        @c_errmsg      output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60241
               END
               ELSE IF @c_PMTLRCP = '1'
               BEGIN --002
                  IF UPPER(@c_RecType) In ('NORMAL', 'RETURNREC')
                  BEGIN --004
                     EXEC ispGenTransmitLog 'PMTLRCP', @c_ReceiptKey, '', '', ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
   
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60242 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                  END -- Rectype
                  CONTINUE 
               END -- @c_PMTLRCP = 1 
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204 
               -------- PMTL Receipt Export -----------------------------------------------------------------------
               SELECT @b_success = 0, @c_CDSRCP = 0
               Execute nspGetRight null,  -- facility
                     @c_StorerKey,  -- Storerkey
                     null,          -- Sku
                     'CDSRCP',      -- Configkey
                     @b_success     output,
                     @c_CDSRCP      output,
                     @n_err         output,
                     @c_errmsg      output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60243
                  BREAK
               END
               ELSE
               BEGIN -- else BEGIN
                  IF @c_CDSRCP = '1'
                  BEGIN -- @c_authority
                     IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK)
                               WHERE ORDERKEY = @c_POKey AND TYPE = '7')
                     BEGIN
                        EXEC ispGenTransmitLog 'CDSRCP', @c_ReceiptKey, '', '', ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
      
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60244 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                     END -- Exist in Order Table 
                     CONTINUE 
                  END -- @c_authority
               END -- @b_success
               -------- CDS Receipt Export -----------------------------------------------------------------------
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204
               -- IDSCN FBR: ec outbound batch sub-inventory transfer (start)
               -- wally 04.dec.2002
               SELECT @b_success = 0, @c_CDSRCP = 0
               Execute nspGetRight null,  -- facility
                     @c_StorerKey,  -- Storerkey
                     null,          -- Sku
                     'CNNIKEITF',   -- Configkey
                     @b_success     output,
                     @c_CNNIKEITF      output,
                     @n_err         output,
                     @c_errmsg      output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60245
                  BREAK
               END
               ELSE
               BEGIN -- else BEGIN
                  IF @c_CNNIKEITF = '1' AND 
                     EXISTS( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK) WHERE RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
                             AND RECEIPTDETAIL.FinalizeFlag = 'Y')
                  BEGIN
                     if @c_RecType = 'TF'
                     BEGIN
                        SELECT @c_tablename = 'TFR'
                     END
                     ELSE IF @c_RecType = 'NORMAL'
                     BEGIN
                        
                        SELECT @c_tablename = 'NIKERCV'
                     END
                     ELSE IF @c_asnstatus = '5'  --to send to transmitlog when choose 'interface'of field asnstatus in return screen
                     BEGIN
                        SELECT @c_tablename = 'NIKERET'
                     END
         
                     IF @c_tablename IS NOT NULL -- SOS20744
                     BEGIN -- SOS20744
                        EXEC ispGenTransmitLog @c_tablename, @c_ReceiptKey, '', '', ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                     
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60246 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                     END -- SOS20744
                     CONTINUE 
                  END
               END
               -- IDSCN FBR: ec outbound NIKERET --------------------------------------------------------------
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204 
               --------  L'OREAL Receipt Export -----------------------------------------------------------------------
               SELECT @b_success = 0, @c_CDSRCP = 0
               Execute nspGetRight null,  -- facility
                     @c_StorerKey,  -- Storerkey
                     null,          -- Sku
                     'LOREALITF',      -- Configkey
                     @b_success     output,
                     @c_LorealItf   output,
                     @n_err         output,
                     @c_errmsg      output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60247
                  BREAK
               END
               ELSE
               BEGIN -- else BEGIN
                  IF @c_LorealItf = '1'
                  BEGIN -- @c_authority
                     EXEC ispGenTransmitLog2 'LORLRCP', @c_ReceiptKey, '', @c_StorerKey, '' -- (Vanessa01)
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
      
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60248 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                     CONTINUE 
                  END -- @c_authority
               END -- @b_success
               --------Complete L'OREAL Receipt Export -----------------------------------------------------------------------
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204 
               --------  Ciba Vision Receipt Export (SOS25285) -----------------------------------------------------------------------
               SELECT @b_success = 0, @c_CDSRCP = 0
               Execute nspGetRight null,  -- facility
                     @c_StorerKey,  -- Storerkey
                     null,          -- Sku
                     'CIBAITF',     -- Configkey
                     @b_success     output,
                     @c_CibaItf  output,
                     @n_err         output,
                     @c_errmsg      output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60249 
                  BREAK
               END
               ELSE
               BEGIN -- else BEGIN
                  IF @c_CibaItf = '1' AND @c_RecType <> 'KITTING'  -- SOS41481
                  BEGIN -- @c_authority
                     EXEC ispGenTransmitLog2 'CIBARCP', @c_ReceiptKey, '', '', ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
   
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60250 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                     CONTINUE
                  END -- @c_authority
               END -- @b_success
               --------Complete Ciba Vision Receipt Export (SOS25285)-----------------------------------------------------------------------
            END -- SOS34204

            -- Start : SOS34204
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
            -- End : SOS34204                
               -- !!! Cannot be Remarked as OW need the 0 Qty Receiptdetail line to be interface (ricky)
               -- Remark by June 06.Oct.03 (OWRCPT is added in ntrITRNAdd)
               -- determine which setup to use   -- requested by Peter Goh.
               IF EXISTS( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND
                          ConfigKey = 'OWITF' AND sValue = '1'
                          -- Start : SOS37076
                          AND (UPPER(@c_RecType) IN ('NORMAL', 'FULLIMRTN', 'PARTIMRTN', 'EXCHANGE', 'RETURN', 'JX', 'OJ')))
                          -- End : SOS37076
               BEGIN
                  SELECT @c_tablename = 'OWRCPT'
               END
   
               -- (YokeBeen01) - Start - Remarked on obsolete Configkey = 'GDSITF'
               -- IF EXISTS( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND
               --            ConfigKey = 'GDSITF' AND sValue = '1') /* END Add */
               -- BEGIN
               --    SELECT @c_tablename = 'RECEIPT'
               -- END
               -- (YokeBeen01) - End - Remarked on obsolete Configkey = 'GDSITF'
   
               -- added by DLIM 25th Sept 2002
               -- Is UNILEVER Interface enabled?
               IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_StorerKey
                           AND ConfigKey = 'ULVITF' AND sValue = '1')
               BEGIN
                  -- Modified by YokeBeen on 03-Nov-2002
                  -- To separate the Reject AND Return record(s) checking for Transmitlog2 record's creation.
                  -- Check for Order Reject if there's a corresponding order
                  -- Modified by YokeBeen on 24-Jul-2003 - (SOS#12573)
                  -- To have all the 'UR' AND 'UM' RecType being assigned for 'ULVRTN' as Tablename in TransmitLog2
                  -- Commented this part for not checking on ORDERS table.
                  -- IF EXISTS ( SELECT 1 FROM Orders WITH (NOLOCK) WHERE externOrderKey = @c_externreceiptkey
                  --                AND (@c_RecType IN ('UR')))
                  --    SELECT @c_tablename = 'ULVRTN'
   
                  -- Check for Returns if there's a corresponding order
                  IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE (RECEIPT.RecType = @c_RecType)
                              AND (@c_RecType IN ('UM', 'UR')))
                              SELECT @c_tablename = 'ULVRTN'
                  -- END Modified by YokeBeen on 24-Jul-2003 - (SOS#12573)
   
                  -- Start - Modified by YokeBeen on 18-Nov-2002 (FBR8624)
                  -- Check for PO Receipts AND Premium PO Receipts
                  -- START: Modified by MaryVong on 10-Dec-2003 (FBR#17218)
                  -- ASN not populated from PO, so take away linkage to PO. 
                     -- Use RECEIPTDETAIL.ExternPOKey instead of RECEIPTDETAIL.POKey
   
                  ELSE IF EXISTS ( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK) 
                          WHERE RECEIPTDETAIL.receiptkey = @c_receiptkey 
                            AND @c_RecType in ('NORMAL', 'UZ') 
                            AND RECEIPTDETAIL.ExternPOKey <> '' ) 
                     SELECT @c_tablename = 'ULVPO'
                  -- END: Modified by MaryVong on 10-Dec-2003 (FBR#17218)
   
                  -- Start - Added by YokeBeen on 18-Nov-2002 (FBR8625)
                  -- Check for Transfer Product from CPC (FBR8266)
                  ELSE IF EXISTS ( SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE (RECEIPT.RecType = @c_RecType)
                                AND (@c_RecType IN ('UT')))
                     SELECT @c_tablename = 'ULVTRF'
   
                  -- Check for Premium non-PO Receipts
      
                  -- START: Modified by MaryVong on 10-Dec-2003 (FBR#17218)
                  -- Use RECEIPTDETAIL.ExternPOKey instead of RECEIPTDETAIL.POKey
      
                  ELSE IF EXISTS ( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)
                                   WHERE RECEIPTDETAIL.receiptkey = @c_receiptkey
                                   AND RECEIPTDETAIL.ExternPOKey = ''
                                   AND @c_RecType IN ('UZ') )
                     SELECT @c_tablename = 'ULVNPO'
                  -- END - Added by YokeBeen on 18-Nov-2002
                  -- END: Modified by MaryVong on 10-Dec-2003 (FBR#17218)
         
                  -- Check for non-PO Receipts
                  ELSE IF NOT EXISTS ( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)
                                    WHERE RECEIPTDETAIL.receiptkey = @c_receiptkey
                                    AND RECEIPTDETAIL.POKey = ''
                                    AND @c_RecType IN ('TRANSFER') )
                     SELECT @c_tablename = 'ULVNPO'
               END -- ConfigKey = 'ULVITF'

               -- if it is trade return with type = 'UR' AND the storerconfig flag is turned on, disable the interface
               IF @c_tablename = 'ULVRTN' AND @c_RecType = 'UR'
               BEGIN
                  -- FBR 8465
                  -- check storerconfig to ensure that ULVPODITF (Disable Pick confirm, AND enable POD interface).
                  -- If value = '1', disable pick confirm
                  IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
                             JOIN STORERCONFIG WITH (NOLOCK) ON ( ORDERS.Consigneekey = STORERCONFIG.Storerkey
                             AND ORDERS.ExternOrderkey = @c_ExternReceiptkey
                             AND STORERCONFIG.Configkey = 'ULVPODITF' AND SValue = '1' ) )
                  BEGIN
                     SELECT @c_Tablename = 'NOITF' -- no interface
                  END
               END 
   
                  -- !!! Cannot be Remarked as OW need the 0 Qty Receiptdetail line to be interface (ricky)
               -- Remark by June 06.Oct.03 (OWRCPT is added in ntrITRNAdd)
               IF UPPER(@c_tablename) IN ('RECEIPT','OWRCPT','ULVRTN','ULVPO','ULVNPO','ULVTRF')
               BEGIN
                  SELECT @c_ReceiptLine = SPACE(5)   
                  WHILE (1=1)
                  BEGIN

                     -- Added By SHONG
                     -- Modified by DLIM for ULVITF Returns
                     -- !!! Cannot be Remarked as OW need the 0 Qty Receiptdetail line to be interface (ricky)
                     -- Remark by June 06.Oct.03 (OWRCPT is added in ntrITRNAdd)
                     IF UPPER(@c_RecType) In ('FULLIMRTN', 'PARTIMRTN', 'EXCHANGE', 'RETURN','UM','UR','NORMAL','TRANSFER','UZ','UT')
                     AND  UPPER(@c_tablename) In ('RECEIPT','OWRCPT','ULVRTN','ULVPO','ULVNPO','ULVTRF')
                     BEGIN
                        SELECT TOP 1 @c_ReceiptLine = RECEIPTLINENUMBER
                        FROM   RECEIPTDETAIL WITH (NOLOCK)
                        WHERE  RECEIPTKEY = @c_ReceiptKey
                        AND    ReceiptLineNumber > @c_ReceiptLine
                        ORDER BY RECEIPTLINENUMBER
                        SELECT @n_RowCnt = @@ROWCOUNT
                     END
                     ELSE
                     BEGIN
                        SELECT TOP 1 @c_ReceiptLine = RECEIPTLINENUMBER
                        FROM   RECEIPTDETAIL WITH (NOLOCK)
                        WHERE  RECEIPTKEY = @c_ReceiptKey
                        AND    ReceiptLineNumber > @c_ReceiptLine
                        AND    QtyReceived > 0
                        AND    FInalizeFlag = 'Y'
                        ORDER BY ReceiptLineNumber
         
                        SELECT @n_RowCnt = @@ROWCOUNT
                     END
         
                     IF @n_RowCnt = 0
                     BREAK
      
                     
                     -- Added by DLIM 25th Sept 2002
                     IF @c_tablename IN ('ULVRTN','ULVPO','ULVNPO','ULVTRF')
                     BEGIN
                        EXEC ispGenTransmitLog2 @c_tablename, @c_ReceiptKey, @c_ReceiptLine, @c_storerkey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
         
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60251 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                     END -- IF @c_tablename = 'ULVRTN'
      
                     IF NOT EXISTS ( SELECT Key1 FROM TransmitLog WITH (NOLOCK) WHERE TableName = @c_tablename
                     AND Key1 = @c_receiptkey AND Key2 = @c_ReceiptLine)
                     AND @c_tablename NOT IN ('ULVRTN','ULVPO','ULVNPO','ULVTRF')
                     BEGIN
                        SELECT @b_success=1
   
                        EXEC ispGenTransmitLog @c_tablename, @c_ReceiptKey, @c_ReceiptLine, '', ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
      
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60252 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        END
                     END --  Transmitlog  
                  END -- While loop 2
               END -- IF Tablename = 'RECEIPT' or....
            END -- SOS34204

            --WL01 START
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               DECLARE @c_ASNCloseValidationRules  NVARCHAR(30)
                     , @c_SQL                      NVARCHAR(4000)
                     , @c_ReceiptLineNumber        NVARCHAR(5) = ''  
  
               SELECT @c_ASNCloseValidationRules = SC.sValue  
               FROM STORERCONFIG SC (NOLOCK)  
               JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname  
               WHERE SC.StorerKey = @c_StorerKey  
               AND SC.Configkey = 'ASNCloseExtendedValidation'  
  
               IF ISNULL(@c_ASNCloseValidationRules,'') <> ''  
               BEGIN  
                  EXEC isp_ASN_ExtendedValidation @cReceiptKey = @c_ReceiptKey,  
                                                  @cASNValidationRules=@c_ASNCloseValidationRules,  
                                                  @nSuccess=@b_Success OUTPUT, @cErrorMsg=@c_ErrMsg OUTPUT,  
                                                  @c_ReceiptLineNumber = @c_ReceiptLineNumber
  
                  IF @b_Success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3
                     --SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60253   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to EXEC isp_ASN_ExtendedValidation. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END  
               END  
               ELSE     
               BEGIN  
                  SELECT @c_ASNCloseValidationRules = SC.sValue      
                  FROM STORERCONFIG SC (NOLOCK)   
                  WHERE SC.StorerKey = @c_StorerKey   
                  AND SC.Configkey = 'ASNCloseExtendedValidation'      
              
                  IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_ASNCloseValidationRules) AND type = 'P')            
                  BEGIN            
                     SET @c_SQL = 'EXEC ' + @c_ASNCloseValidationRules + ' @c_ReceiptKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '            
                                + ',@c_ReceiptLineNumber '                         
                     EXEC sp_executesql @c_SQL,            
                              N'@c_ReceiptKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT  
                              ,@c_ReceiptLineNumber NVARCHAR(5)',                          
                              @c_ReceiptKey,            
                              @b_Success OUTPUT,            
                              @n_Err OUTPUT,            
                              @c_ErrMsg OUTPUT,  
                              @c_ReceiptLineNumber                                        
  
                     IF @b_Success <> 1       
                     BEGIN      
                        SELECT @n_continue = 3
                        --SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60254   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to EXEC ' + @c_ASNCloseValidationRules + '. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END           
                  END    
               END--ISNULL(@cASNValidationRules,'') <> ''              
            END--WL01 END
            
            --NJOW02  
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 0, @c_CloseASNStatusUpdFinalizeDate = ''
               Execute nspGetRight @c_Facility,  -- facility
                     @c_StorerKey,  -- Storerkey
                     null,          -- Sku
                     'CloseASNStatusUpdFinalizeDate',     -- Configkey
                     @b_success     output,
                     @c_CloseASNStatusUpdFinalizeDate  output,
                     @n_err         output,
                     @c_errmsg      output
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
                  SELECT @n_err = 60250 
                  BREAK
               END               
               ELSE
               BEGIN -- else BEGIN
                  IF @c_CloseASNStatusUpdFinalizeDate = '1' 
                  BEGIN
                     UPDATE RECEIPT WITH (ROWLOCK)
                     SET  FinalizeDate = GETDATE(),
                          TrafficCop   = NULL
                     WHERE Receiptkey = @c_receiptkey
                     SELECT @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                        BREAK
                     END                     
                  END
               END            
            END                        

            --NJOW05
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SET @c_CloseASNStatusUpdReceiptDate = ''
               SET @c_DocTypeUpdReceiptDate = 'A,R,X'
               SET @c_Option5 = ''
               
               SELECT @c_CloseASNStatusUpdReceiptDate = SC.Authority,
                      @c_Option5 = SC.Option5
               FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey,'','CloseASNStatusUpdReceiptDate') AS SC
       
               IF @c_CloseASNStatusUpdReceiptDate = '1' 
               BEGIN                
                  SELECT @c_DocTypeUpdReceiptDate = dbo.fnc_GetParamValueFromString ('@c_DocTypeUpdReceiptDate', @c_option5, @c_DocTypeUpdReceiptDate)
                
                  UPDATE RECEIPT WITH (ROWLOCK)
                  SET  ReceiptDate = GETDATE(),
                       TrafficCop   = NULL
                  WHERE Receiptkey = @c_receiptkey
                  AND DocType IN (SELECT Value
                                  FROM STRING_SPLIT(@c_DocTypeUpdReceiptDate,','))                                  
                  
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63806   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     BREAK
                  END                    
               END
            END                        
         END -- While Loop 1
      END -- ASNStatus = '9'

      -- (YokeBeen02) - Start
      IF (@n_continue = 1 or @n_continue = 2)
      BEGIN
         SELECT @c_ADDASNLOG = 0, @b_success = 0

         EXECUTE nspGetRight 
                NULL,          -- facility
                @c_storerkey,  -- Storerkey
                NULL,          -- Sku
                'ADDASNLOG',    -- Configkey
                @b_success     output,
                @c_ADDASNLOG   output,
                @n_err         output,
                @c_errmsg      output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE IF @c_ADDASNLOG = '1'
         BEGIN
            IF EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE Listname = 'ADDASNLOG' AND CODE = 'ASNStatusChange' AND STORERKEY = @c_storerkey AND SHORT = @c_ASNStatus)
            BEGIN
               SELECT @b_success = 1                                                             
                  EXEC ispGenTransmitLog3 'ADDASNLOG', @c_receiptkey, @c_DocType, @c_storerkey, '' 
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
                  SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- Record is found in CODELKUP
         END -- IF @c_ADDASNLOG = '1'
      END -- IF (@n_continue = 1 or @n_continue = 2)
      -- (YokeBeen02) - End
   END -- Update ASNStatus - END Add by June 11.Mar.02
END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSHK) *** END

IF (@n_continue = 1 or @n_continue = 2)
BEGIN
   SELECT @c_currentreceipt = ''
   WHILE (1=1)
   BEGIN -- while
      SELECT @c_currentreceipt = min(i.receiptkey)
      from inserted i WITH (NOLOCK)
      JOIN storerconfig s WITH (NOLOCK) on i.storerkey = s.storerkey  AND s.configkey = 'CNNIKEITF'  AND S.svalue = '1'
      WHERE i.receiptkey > @c_currentreceipt
      AND  i.asnstatus = '5'

      if @@rowcount = 0 or @c_currentreceipt is null
      break

      EXEC ispGenTransmitLog @c_tablename, @c_currentreceipt, '', '', ''
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
   
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=60253 --63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END -- WHILE
END
------- END Interface --------------

IF (@n_continue = 1 or @n_continue=2 ) AND @c_billing  = '1'
BEGIN
   DECLARE @c_containertype      NVARCHAR(20),
   @n_containerqty               int,
   @n_billedcontainerqty         int,
   @n_qtytobill                  int

   SELECT @c_receiptkey = master.dbo.fnc_GetCharASCII(14)
   IF EXISTS (SELECT 1 FROM INSERTED
              WHERE ContainerQty > BilledContainerQty
              AND IsNull(dbo.fnc_RTrim(ContainerType), '') <> ''
              AND ContainerQty is not NULL )
   BEGIN
      WHILE @n_continue = 1 or @n_continue=2
      BEGIN
         
         SELECT TOP 1 @c_containertype = dbo.fnc_RTrim(ContainerType),
                @n_containerqty  = ContainerQty,
                @n_billedcontainerqty = BilledContainerQty,
                @c_receiptkey = ReceiptKey,
                @c_storerkey = StorerKey
         FROM INSERTED
         WHERE ReceiptKey > @c_receiptkey
         AND ContainerQty > BilledContainerQty
         AND IsNull(dbo.fnc_RTrim(ContainerType), '') <> ''
         AND ContainerQty is not NULL
         ORDER BY ReceiptKey

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

         IF @n_cnt = 0 BREAK
         IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @c_receiptkey AND QtyReceived > 0 )
         BEGIN
            CONTINUE
         END
         SELECT @n_qtytobill = @n_containerqty - @n_billedcontainerqty
         EXECUTE nspBillContainer
                      @c_sourcetype    = 'ASN'
         ,            @c_sourcekey     = @c_receiptkey
         ,            @c_containertype = @c_containertype
         ,            @n_containerqty  = @n_qtytobill
         ,            @c_storerkey     = @c_storerkey
         ,            @b_Success       = @b_Success   OUTPUT
         ,            @n_err           = @n_err       OUTPUT
         ,            @c_errmsg        = @c_errmsg    OUTPUT
         IF not @b_Success = 1  SELECT @n_continue = 3
         IF @n_continue = 1 or @n_continue=2
         BEGIN
            UPDATE RECEIPT with (ROWLOCK)
            SET BilledContainerQty = ContainerQty
            WHERE ReceiptKey = @c_receiptkey
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update BilledContainerQty On Table RECEIPT fail. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
      END -- while loop
   END  -- if exists any records
END  -- generate charges, billing = 1 

-- Added By Vicky 30 July 2003 For NIKEHK Generate ROICNo
IF @n_continue = 1 or @n_continue=2
BEGIN --001
   Declare @c_roicno NVARCHAR(1), @cnt int, @ncnt int

   SELECT @b_success = 0

   Execute nspGetRight @c_Facility, -- facility
   @c_StorerKey,  -- Storerkey
   null,          -- Sku
   'GENROICNO',         -- Configkey
   @b_success     output,
   @c_roicno      output,
   @n_err         output,
   @c_errmsg      output

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
      SELECT @n_err = 60254
   END
   ELSE IF @c_roicno = '1'
   BEGIN --002
      SELECT @c_storerkey = Inserted.Storerkey,
            @c_receiptkey = Inserted.Receiptkey,
            @c_RecType    = INSERTED.RecType,
            @c_warehouseref = INSERTED.Warehousereference
      FROM Inserted WITH (NOLOCK)
      WHERE INSERTED.ReceiptKey = @c_receiptkey
      ORDER BY ReceiptKey

      IF EXISTS(SELECT ReceiptKey FROM RECEIPTDETAIL WITH (NOLOCK)
                WHERE Receiptkey = @c_receiptkey
                AND FinalizeFlag = 'Y')
      BEGIN
         SELECT @ncnt = COUNT(*)
         FROM RECEIPTDETAIL WITH (NOLOCK)
         WHERE FinalizeFlag <> 'Y'
         AND Receiptkey = @c_receiptkey
         AND Storerkey = @c_storerkey
         AND Beforereceivedqty > 0

         IF @n_cnt > 0
         BEGIN --003
            IF UPPER(@c_RecType) = 'NORMAL'
            BEGIN --004
               IF @c_warehouseref = '' Or @c_warehouseref IS NULL
               BEGIN
                  SELECT @c_warehouseref=''
                  SELECT @b_success=1
   
                  EXECUTE nspg_getkey
                  'ROICNo'
                  ,10
                  , @c_warehouseref OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  IF NOT @b_success=1
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @n_err = 60255
                  END
                  ELSE
                  BEGIN
                     UPDATE RECEIPT with (ROWLOCK)
                     SET Warehousereference = @c_warehouseref
                     WHERE Receiptkey = @c_receiptkey
                  END -- Update
               END --  roic
            END -- Rectype
         END --003
         ELSE
         BEGIN
            SELECT @ncnt = COUNT(*)
            FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE FinalizeFlag = 'Y'
            AND Receiptkey = @c_receiptkey
            AND Storerkey = @c_storerkey
            AND Beforereceivedqty > 0
   
            IF @ncnt > 0
            BEGIN --003
               IF UPPER(@c_RecType) = 'NORMAL'
               BEGIN --004
                  IF @c_warehouseref = '' Or @c_warehouseref IS NULL
                  BEGIN
                     SELECT @c_warehouseref=''
                     SELECT @b_success=1
   
                     EXECUTE nspg_getkey
                     'ROICNo'
                     ,10
                     , @c_warehouseref OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT
                     IF NOT @b_success=1
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @n_err = 60256
                     END
                     ELSE
                     BEGIN
                        UPDATE RECEIPT with (ROWLOCK)
                        SET Warehousereference = @c_warehouseref
                        WHERE Receiptkey = @c_receiptkey
                     END -- Update
                  END --  roic
               END -- Rectype
            END --004
         END -- ELSE
      END --003
   END --002
END --001
-- END add

IF ( @n_continue = 1 or @n_continue=2) AND NOT UPDATE(EditDate)
BEGIN
   UPDATE  RECEIPT with (ROWLOCK)
   SET  EditDate = GETDATE(),
   EditWho = SUSER_SNAME(),
   TrafficCop = NULL
   FROM RECEIPT,
   INSERTED
   WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
   AND RECEIPT.Status = '9'            --tlting01   
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   END
END

-- TLTING04
IF @n_continue = 1 or @n_continue=2
BEGIN
   SET @c_MarkASNLockdown = '0'
  EXECUTE nspGetRight 
          NULL,          -- facility
          @c_storerkey,  -- Storerkey
          NULL,          -- Sku
          'ASNSTATUSLOCKDOWN',    -- Configkey
          @b_success     output,
          @c_MarkASNLockdown   output,
          @n_err         output,
          @c_errmsg      output  
   IF @c_MarkASNLockdown = '1' 
   BEGIN 
      -- TLTING04         
      IF exists ( Select 1 from HolidayDetail  (NOLOCK) Where HolidayDescr like '%Financial LockDown%'  
               AND UserDefine01  = @c_storerkey  
               AND datepart(MONTH , HolidayDate) = datepart(MONTH , getdate() )  
               AND getdate() >= userdefine04 and getdate() <= userdefine05)                  
      AND
      Exists ( SELECT  1
               FROM RECEIPT, INSERTED, DELETED
               WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
               AND DELETED.ReceiptKey = INSERTED.ReceiptKey
               AND RECEIPT.ASNStatus = '9'   
               AND DELETED.ASNStatus <> RECEIPT.ASNStatus     )  
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63825   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. This is Financial LockDown period. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         
      END
   END
END   

--tlting02
IF @n_continue = 1 or @n_continue=2
BEGIN
   UPDATE  RECEIPT with (ROWLOCK)
   SET  FinalizeDate = GETDATE(),
        TrafficCop   = NULL
   FROM RECEIPT, INSERTED, DELETED
   WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
   AND DELETED.ReceiptKey = INSERTED.ReceiptKey
   AND RECEIPT.Status = '9' 
   AND DELETED.Status <> RECEIPT.Status              
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err) --, @n_err=63805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table RECEIPT. (ntrReceiptHeaderUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   END
END

END

-- tlting03 - JR WMS-2047 event track
IF (@n_continue = 1 OR @n_continue = 2)
BEGIN
  SET @b_success = 0
  SET @c_authority = ''
  
   EXECUTE nspGetRight NULL,  -- facility
          @c_storerkey,     -- Storerkey
          NULL,         -- Sku
          'GVTITF',         -- Configkey
          @b_success output,
          @c_authority output,
          @n_err output,
          @c_errmsg output
          
  IF @b_success <> 1
  BEGIN
    SELECT @n_continue = 3, @c_errmsg = 'ntrReceiptHeaderUpdate' + RTrim(@c_errmsg)
      SELECT @n_err = 60265
  END
  ELSE IF @c_authority = '1'
  BEGIN   
       SELECT @c_ReceiptKey = SPACE(10)
     WHILE 1=1
     BEGIN
        SELECT TOP 1 @c_ReceiptKey = RECEIPT.RECEIPTKEY        
          FROM RECEIPT WITH (NOLOCK), INSERTED, DELETED
          WHERE RECEIPT.ReceiptKey = INSERTED.ReceiptKey
          AND DELETED.ReceiptKey = INSERTED.ReceiptKey
          AND RECEIPT.Status = '9' 
          AND DELETED.Status <> RECEIPT.Status 
        AND RECEIPT.RECEIPTKEY > @c_ReceiptKey         
        Order by RECEIPT.RECEIPTKEY
        IF @@ROWCOUNT = 0
        BEGIN
           BREAK
        END
        SET @c_City = ''   
          SELECT @b_success=1  

          IF NOT EXISTS ( SELECT 1 FROM dbo.DocStatusTrack WITH (NOLOCK) WHERE TableName = 'ASNSTS'  
                        AND DocumentNo = @c_ReceiptKey AND DOCStatus = '9' )  
          BEGIN  
            SELECT @c_City = facility.City 
            FROM   facility (NOLOCK)  
            WHERE facility.facility = @c_facility
             
             -- finalised
            EXEC ispGenDocStatusLog 'ASNSTS', @c_storerkey, @c_ReceiptKey, @c_City, '','9'
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
      
              IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=60266                 
               SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                           ': Insert Failed On Table DocStatusTrack(ASNSTS). (ntrReceiptHeaderUpdate)'+'('+  
                           'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'                                
            END 
         END -- not exists  
     END -- While
  END     
END

/********************************************************/  
/* Interface Trigger Points Calling Process - (Start)   */  
/********************************************************/  
--MC02 - S
IF @n_continue = 1 OR @n_continue = 2   
BEGIN 

   DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT  DISTINCT INS.ReceiptKey 
   FROM    INSERTED INS 
   JOIN    ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
   WHERE   ITC.SourceTable = 'RECEIPT'  
   AND     ITC.sValue      = '1' 
   UNION                                                                                           
   SELECT DISTINCT IND.ReceiptKey                                                                    
   FROM   INSERTED IND                                                                             
   JOIN   ITFTriggerConfig ITC WITH (NOLOCK)                                                       
   ON     ITC.StorerKey   = 'ALL'                                                                  
   JOIN   StorerConfig STC WITH (NOLOCK)                                                           
   ON     STC.StorerKey   = IND.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'   
   WHERE  ITC.SourceTable = 'RECEIPT'                                                               
   AND    ITC.sValue      = '1'                                                                    

   OPEN Cur_Itf_TriggerPoints
   FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_ReceiptKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_ColumnsUpdated = ''    

      -- MC03 - S
      IF UPDATE(ASNStatus)
      BEGIN
         IF @c_ColumnsUpdated = ''
         BEGIN
            SET @c_ColumnsUpdated = 'ASNStatus'
         END
         ELSE
         BEGIN
            SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'ASNStatus'
         END
      END

      IF UPDATE(Status) OR @c_StatusUpdated = 'Y' 
      BEGIN
         IF @c_ColumnsUpdated = ''
         BEGIN
            SET @c_ColumnsUpdated = 'Status'
         END
         ELSE
         BEGIN
            SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'Status'
         END
      END
      /*
      DECLARE Cur_ColUpdated CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT  COLUMN_NAME FROM dbo.fnc_GetUpdatedColumns('RECEIPT', @b_ColumnsUpdated) 
      OPEN    Cur_ColUpdated  
      FETCH NEXT FROM Cur_ColUpdated INTO @c_COLUMN_NAME
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  

         IF @c_ColumnsUpdated = ''
         BEGIN
            SET @c_ColumnsUpdated = @c_COLUMN_NAME
         END
         ELSE
         BEGIN
            SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + @c_COLUMN_NAME
         END

         FETCH NEXT FROM Cur_ColUpdated INTO @c_COLUMN_NAME
      END -- WHILE @@FETCH_STATUS <> -1  
      CLOSE Cur_ColUpdated  
      DEALLOCATE Cur_ColUpdated 

      IF @c_StatusUpdated = 'Y' 
      BEGIN
         IF @c_ColumnsUpdated = ''
         BEGIN
            SET @c_ColumnsUpdated = 'STATUS'
         END
         ELSE
         BEGIN
            SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'STATUS'
         END
      END
      */
      -- MC03 - E

      EXECUTE dbo.isp_ITF_ntrReceipt
               @c_TriggerName    = 'ntrReceiptHeaderUpdate'
             , @c_SourceTable    = 'RECEIPT'  
             , @c_ReceiptKey     = @c_ReceiptKey  
             , @c_ColumnsUpdated = @c_ColumnsUpdated        
             , @b_Success        = @b_Success   OUTPUT  
             , @n_err            = @n_err       OUTPUT  
             , @c_errmsg         = @c_errmsg    OUTPUT  

      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @c_ReceiptKey
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE Cur_Itf_TriggerPoints
   DEALLOCATE Cur_Itf_TriggerPoints
END
--MC02 - E
/********************************************************/  
/* Interface Trigger Points Calling Process - (End)     */  
/********************************************************/  

/* #INCLUDE <TRRHU2.SQL> */
IF @n_continue=3  -- Error Occured - Process AND Return
BEGIN
   -- To support RDT - start
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
   -- To support RDT - end
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrReceiptHeaderUpdate'
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
END

GO